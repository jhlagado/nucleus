import { mkdtemp, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";

import { compile } from "@jhlagado/azm/compile";
import { createZ80Runtime, parseIntelHex } from "@jhlagado/debug80-runtime";
import { beforeAll, describe, expect, it } from "vitest";

const rewriteDirectory = path.resolve(import.meta.dirname, "../asm/rewrite");

interface Image {
  readonly hex: string;
  readonly symbols: Readonly<Record<string, number>>;
}

let image: Image;

beforeAll(async () => {
  const result = await compile(
    path.join(rewriteDirectory, "r7-target-layout-proof.asm"),
    { emitHex: true, emitD8m: true, registerContracts: "strict" },
  );
  expect(
    result.diagnostics.filter(({ severity }) => severity === "error"),
  ).toEqual([]);
  const hex = result.artifacts.find((artifact) => artifact.kind === "hex");
  const d8m = result.artifacts.find((artifact) => artifact.kind === "d8m");
  if (hex?.kind !== "hex" || d8m?.kind !== "d8m") {
    throw new Error("AZM omitted R7 target-layout proof artifacts");
  }
  image = {
    hex: hex.text,
    symbols: Object.fromEntries(
      d8m.json.symbols.flatMap((entry) => {
        const value = entry.address ?? entry.value;
        return value === undefined ? [] : [[entry.name, value]];
      }),
    ),
  };
}, 30_000);

const run = (entryName: string) => {
  const parsed = parseIntelHex(image.hex);
  const entry = image.symbols[entryName];
  if (entry === undefined) throw new Error(`missing ${entryName}`);
  const runtime = createZ80Runtime(
    { ...parsed, memory: parsed.memory.slice(), startAddress: entry },
    entry,
  );
  let instructions = 0;
  let cycles = 0;
  while (!runtime.isHalted() && instructions < 50_000) {
    const step = runtime.step();
    instructions += 1;
    cycles += step.cycles ?? 0;
  }
  expect(runtime.isHalted(), entryName).toBe(true);
  return { memory: runtime.hardware.memory, instructions, cycles };
};

describe("ground-up rewrite target layout", () => {
  it("classifies ROM, loaded, exact-end, and banked layouts", () => {
    const { memory, instructions, cycles } = run("ProofTargetLayouts");
    expect(memory[image.symbols.ProofTargetStatus ?? -1]).toBe(0xb0);
    expect({ instructions, cycles }).toEqual({
      instructions: 425,
      cycles: 7_000,
    });
  });

  it("publishes one append-only image/patch transaction and one commit", () => {
    const { memory } = run("ProofTargetOutputTransaction");
    const adapter = image.symbols.AdapterLogBase ?? -1;
    const cursor = image.symbols.AdapterCursor ?? -1;
    expect({
      status: memory[image.symbols.ProofTargetStatus ?? -1],
      open: memory[image.symbols.AdapterOpen ?? -1],
      committed: memory[image.symbols.AdapterCommitted ?? -1],
      aborted: memory[image.symbols.AdapterAborted ?? -1],
      length: (memory[cursor] | (memory[cursor + 1] << 8)) - adapter,
      records: Array.from(memory.slice(adapter, adapter + 15)),
    }).toEqual({
      status: 0xb2,
      open: 0,
      committed: 1,
      aborted: 0,
      length: 15,
      records: [1, 1, 0x23, 0x81, 1, 0, 0xaa, 2, 0, 0x10, 0x80, 2, 0, 0x56, 0x34],
    });
  });

  it.each([
    "ProofTargetOutputAppendFailure",
    "ProofTargetOutputCommitFailure",
  ] as const)("aborts %s exactly once without commit", (entryName) => {
    const { memory } = run(entryName);
    expect({
      diagnostic: memory[image.symbols.DiagnosticCode ?? -1],
      open: memory[image.symbols.AdapterOpen ?? -1],
      committed: memory[image.symbols.AdapterCommitted ?? -1],
      aborted: memory[image.symbols.AdapterAborted ?? -1],
    }).toEqual({ diagnostic: 97, open: 0, committed: 0, aborted: 1 });
  });

  it("recovers with a committed generation after an aborted generation", () => {
    const { memory } = run("ProofTargetOutputRecovery");
    const adapter = image.symbols.AdapterLogBase ?? -1;
    const cursor = image.symbols.AdapterCursor ?? -1;
    expect({
      status: memory[image.symbols.ProofTargetStatus ?? -1],
      open: memory[image.symbols.AdapterOpen ?? -1],
      committed: memory[image.symbols.AdapterCommitted ?? -1],
      aborted: memory[image.symbols.AdapterAborted ?? -1],
      length: (memory[cursor] | (memory[cursor + 1] << 8)) - adapter,
      record: Array.from(memory.slice(adapter, adapter + 7)),
    }).toEqual({
      status: 0xb3,
      open: 0,
      committed: 1,
      aborted: 1,
      length: 7,
      record: [1, 0, 0, 0x80, 1, 0, 0xbb],
    });
  });

  it("makes catch-side abort idempotent", () => {
    const { memory } = run("ProofTargetOutputAbortIdempotent");
    expect({
      open: memory[image.symbols.AdapterOpen ?? -1],
      committed: memory[image.symbols.AdapterCommitted ?? -1],
      aborted: memory[image.symbols.AdapterAborted ?? -1],
    }).toEqual({ open: 0, committed: 0, aborted: 1 });
  });

  it("admits the exact adapter boundary and rejects its first extra byte atomically", () => {
    const { memory } = run("ProofTargetOutputCapacity");
    const limit = image.symbols.AdapterLogLimit ?? -1;
    const cursor = image.symbols.AdapterCursor ?? -1;
    expect({
      diagnostic: memory[image.symbols.DiagnosticCode ?? -1],
      open: memory[image.symbols.AdapterOpen ?? -1],
      committed: memory[image.symbols.AdapterCommitted ?? -1],
      aborted: memory[image.symbols.AdapterAborted ?? -1],
      cursor: memory[cursor] | (memory[cursor + 1] << 8),
      finalRecord: Array.from(memory.slice(limit - 7, limit)),
    }).toEqual({
      diagnostic: 97,
      open: 0,
      committed: 0,
      aborted: 1,
      cursor: limit,
      finalRecord: [1, 1, 0xff, 0x8f, 1, 0, 0xcc],
    });
  });

  it.each([
    ["ProofTargetInvalidIdentity", 95],
    ["ProofTargetInvalidPartBank", 95],
    ["ProofTargetPartialOverlap", 95],
    ["ProofTargetZeroCapacity", 96],
    ["ProofTargetWrappedRegion", 96],
    ["ProofTargetBankedLoaded", 95],
  ] as const)("rejects %s before publication", (entryName, diagnostic) => {
    const { memory } = run(entryName);
    expect(memory[image.symbols.DiagnosticCode ?? -1]).toBe(diagnostic);
  });

  it("accepts a valid descriptor immediately after a rejected one", () => {
    const { memory } = run("ProofTargetFailureThenRecovery");
    expect(memory[image.symbols.ProofTargetStatus ?? -1]).toBe(0xb1);
  });

  it("executes descriptor validation at separated compiler origins", async () => {
    const directory = await mkdtemp(
      path.join(os.tmpdir(), "nucleus-r7-target-layout-origin-"),
    );
    try {
      const relativeImage = path.relative(
        directory,
        path.join(rewriteDirectory, "compiler-image.asmi"),
      );
      for (const origin of [0, 0x8000]) {
        const sourcePath = path.join(
          directory,
          `target-layout-${origin.toString(16)}.asm`,
        );
        await writeFile(
          sourcePath,
          [
            "CompilerWorkBase .equ $6000",
            "SourceBase .equ $5000",
            "SourceLimit .equ $5800",
            "RewriteAdapterBase .equ $D000",
            "RewriteAdapterLimit .equ $D100",
            "DebugHooks .equ 0",
            `.org $${origin.toString(16)}`,
            `.include ${JSON.stringify(relativeImage)}`,
            ".org $F000",
            "ProofRelocatedTarget:",
            " LD SP,$FF00",
            " CALL RewriteReset",
            " LD HL,ProofRelocatedTargetFailure",
            " PUSH HL",
            " LD (CompilerAbortSp),SP",
            " LD IX,ProofRelocatedDescriptor",
            " LD A,2",
            " CALL RewriteTargetValidateDescriptor",
            " LD A,(RewriteTargetLayoutMode)",
            " CP RewriteTargetLayoutRom",
            " JP NZ,ProofRelocatedTargetFailure",
            " LD HL,(RewriteTargetDescriptorPointer)",
            " LD DE,ProofRelocatedDescriptor",
            " OR A",
            " SBC HL,DE",
            " JP NZ,ProofRelocatedTargetFailure",
            " LD A,$A7",
            " LD (ProofRelocatedTargetStatus),A",
            " HALT",
            "ProofRelocatedTargetFailure:",
            " LD A,$FF",
            " LD (ProofRelocatedTargetStatus),A",
            " HALT",
            "ProofRelocatedTargetStatus: .db 0",
            "ProofRelocatedBanks: .db 0,0",
            "ProofRelocatedDescriptor:",
            " .dw NucleusRuntimeIdentity,$8000,$1000,$4000,$1000",
            " .db 1,1,0",
            " .dw ProofRelocatedBanks",
            "",
          ].join("\n"),
          "utf8",
        );
        const result = await compile(sourcePath, {
          emitHex: true,
          emitD8m: true,
          registerContracts: "strict",
        });
        expect(
          result.diagnostics.filter(({ severity }) => severity === "error"),
        ).toEqual([]);
        const hex = result.artifacts.find((artifact) => artifact.kind === "hex");
        const d8m = result.artifacts.find((artifact) => artifact.kind === "d8m");
        if (hex?.kind !== "hex" || d8m?.kind !== "d8m") {
          throw new Error("AZM omitted relocated target-layout artifacts");
        }
        const symbols = Object.fromEntries(
          d8m.json.symbols.flatMap((entry) => {
            const value = entry.address ?? entry.value;
            return value === undefined ? [] : [[entry.name, value]];
          }),
        );
        const parsed = parseIntelHex(hex.text);
        const entry = symbols.ProofRelocatedTarget;
        if (entry === undefined) throw new Error("missing relocated target entry");
        const runtime = createZ80Runtime(
          { ...parsed, memory: parsed.memory.slice(), startAddress: entry },
          entry,
        );
        let instructions = 0;
        while (!runtime.isHalted() && instructions < 20_000) {
          runtime.step();
          instructions += 1;
        }
        expect(runtime.isHalted(), `origin $${origin.toString(16)}`).toBe(true);
        expect(runtime.hardware.memory[symbols.ProofRelocatedTargetStatus ?? -1]).toBe(
          0xa7,
        );
      }
    } finally {
      await rm(directory, { recursive: true, force: true });
    }
  }, 30_000);

  it("locks the planner and whole-compiler accounts", () => {
    expect({
      planner:
        (image.symbols.RewriteTargetCodeEnd ?? 0) -
        (image.symbols.RewriteTargetCodeStart ?? 0),
      code:
        (image.symbols.RewriteCompilerCodeEnd ?? 0) -
        (image.symbols.RewriteCompilerCodeStart ?? 0),
      immutable:
        (image.symbols.RewriteCompilerImmutableEnd ?? 0) -
        (image.symbols.RewriteCompilerImmutableStart ?? 0),
      core:
        (image.symbols.RewriteCompilerCoreEnd ?? 0) -
        (image.symbols.RewriteCompilerCodeStart ?? 0),
      workspace:
        (image.symbols.RewriteWorkspaceEnd ?? 0) -
        (image.symbols.RewriteStateBase ?? 0),
      adapter:
        (image.symbols.RewriteAdapterCodeEnd ?? 0) -
        (image.symbols.RewriteAdapterCodeStart ?? 0),
    }).toEqual({
      planner: 312,
      code: 16_257,
      immutable: 1_508,
      core: 17_765,
      workspace: 3_938,
      adapter: 187,
    });
  });
});
