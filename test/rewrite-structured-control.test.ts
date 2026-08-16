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
    path.join(rewriteDirectory, "r5-structured-control-proof.asm"),
    { emitHex: true, emitD8m: true, registerContracts: "strict" },
  );
  expect(
    result.diagnostics.filter(({ severity }) => severity === "error"),
  ).toEqual([]);
  const hex = result.artifacts.find((artifact) => artifact.kind === "hex");
  const d8m = result.artifacts.find((artifact) => artifact.kind === "d8m");
  if (hex?.kind !== "hex" || d8m?.kind !== "d8m") {
    throw new Error("AZM omitted R5 structured-control proof artifacts");
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
  while (!runtime.isHalted() && instructions < 200_000) {
    const step = runtime.step();
    instructions += 1;
    cycles += step.cycles ?? 0;
  }
  expect(runtime.isHalted(), entryName).toBe(true);
  const memory = runtime.hardware.memory;
  const offsetAddress = image.symbols.DiagnosticOffset ?? -1;
  return {
    status: memory[image.symbols.ProofStatus ?? -1],
    diagnostic: memory[image.symbols.DiagnosticCode ?? -1],
    part: memory[image.symbols.DiagnosticPartId ?? -1],
    offset: memory[offsetAddress] | (memory[offsetAddress + 1] << 8),
    instructions,
    cycles,
  };
};

describe("ground-up rewrite structured control", () => {
  it.each([
    ["ProofStructuredControl", 0xe8, 0, 0, 0],
    ["ProofStructuredNonBoolean", 0xe9, 60, 1, 15],
    ["ProofStructuredExitOutsideLoop", 0xea, 72, 1, 11],
    ["ProofStructuredContinueOutsideLoop", 0xeb, 72, 1, 11],
    ["ProofStructuredFrameCapacity", 0xec, 68, 1, 75],
    ["ProofStructuredLabelCapacity", 0xed, 69, 1, 11],
    ["ProofCountedLoop", 0xf0, 0, 0, 0],
    ["ProofCountedActiveAssignment", 0xf1, 36, 1, 38],
    ["ProofCountedNestedCounter", 0xf2, 36, 1, 42],
    ["ProofCountedWrongCounter", 0xf3, 57, 1, 15],
    ["ProofCountedZeroStep", 0xf4, 74, 1, 43],
    ["ProofCountedVariants", 0xf5, 0, 0, 0],
    ["ProofCountedBooleanCounter", 0xf6, 73, 1, 35],
    ["ProofCountedNonconstantStep", 0xf7, 74, 1, 62],
    ["ProofCountedIncompatibleStart", 0xf8, 61, 1, 31],
    ["ProofCountedNestedTransfers", 0xf9, 0, 0, 0],
    ["ProofCountedNegativeNamedStep", 0xfa, 74, 1, 64],
    ["ProofCountedFailableStart", 0xfb, 87, 1, 80],
    ["ProofCountedFailableBound", 0xfc, 87, 1, 81],
    ["ProofCountedAggregateStep", 0xfd, 74, 1, 70],
    ["ProofCountedMissingBound", 0xfe, 58, 1, 33],
    ["ProofCountedProgramCounter", 0xef, 73, 1, 27],
  ] as const)(
    "executes %s with exact diagnostic provenance",
    (entry, status, diagnostic, part, offset) => {
      expect(run(entry)).toMatchObject({ status, diagnostic, part, offset });
    },
  );

  it("locks the complete four-type counted-loop compilation account", () => {
    expect(run("ProofCountedVariants")).toMatchObject({
      instructions: 57_852,
      cycles: 524_762,
    });
  });

  it("executes the full-address escape directory at separated compiler origins", async () => {
    const directory = await mkdtemp(
      path.join(os.tmpdir(), "nucleus-r5-control-origin-"),
    );
    try {
      const imageInclude = path.join(rewriteDirectory, "compiler-image.asmi");
      const relativeImage = path.relative(directory, imageInclude);
      for (const origin of [0, 0x8000]) {
        const sourcePath = path.join(
          directory,
          `structured-${origin.toString(16)}.asm`,
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
            "ProofRelocatedControl:",
            " LD SP,$FF00",
            " CALL RewriteReset",
            " LD HL,ProofRelocatedFailure",
            " PUSH HL",
            " LD (CompilerAbortSp),SP",
            " LD A,1",
            " LD HL,ProofRelocatedParts",
            " CALL RewriteSourceInitializeParts",
            " LD HL,RewriteActionProgramRoutineDirectHeader",
            " CALL RewriteActionRun",
            " LD HL,RewriteActionProgramIfHeader",
            " CALL RewriteActionRun",
            " LD A,(RewriteControlDepth)",
            " CP 1",
            " JP NZ,ProofRelocatedFailure",
            " LD A,(RewriteControlNextLabel)",
            " CP 2",
            " JP NZ,ProofRelocatedFailure",
            " LD A,$A5",
            " LD (ProofRelocatedStatus),A",
            " HALT",
            "ProofRelocatedFailure:",
            " LD A,$FF",
            " LD (ProofRelocatedStatus),A",
            " HALT",
            "ProofRelocatedStatus: .db 0",
            ".org $5000",
            "ProofRelocatedSource: .db \"sub main()\",10,\"if true\",10",
            "ProofRelocatedSourceEnd:",
            ".org $5900",
            "ProofRelocatedParts: .db 1",
            " .dw ProofRelocatedSource,ProofRelocatedSourceEnd",
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
          throw new Error("AZM omitted relocated structured-control artifacts");
        }
        const symbols = Object.fromEntries(
          d8m.json.symbols.flatMap((entry) => {
            const value = entry.address ?? entry.value;
            return value === undefined ? [] : [[entry.name, value]];
          }),
        );
        const parsed = parseIntelHex(hex.text);
        const entry = symbols.ProofRelocatedControl;
        const status = symbols.ProofRelocatedStatus;
        if (entry === undefined || status === undefined) {
          throw new Error("relocated proof symbols are incomplete");
        }
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
        expect(runtime.hardware.memory[status]).toBe(0xa5);
      }
    } finally {
      await rm(directory, { recursive: true, force: true });
    }
  }, 45_000);
});
