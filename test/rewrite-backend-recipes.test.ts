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

const imageFromArtifacts = (
  artifacts: Awaited<ReturnType<typeof compile>>["artifacts"],
): Image => {
  const hex = artifacts.find((artifact) => artifact.kind === "hex");
  const d8m = artifacts.find((artifact) => artifact.kind === "d8m");
  if (hex?.kind !== "hex" || d8m?.kind !== "d8m") {
    throw new Error("AZM omitted R6 backend-recipe proof artifacts");
  }
  return {
    hex: hex.text,
    symbols: Object.fromEntries(
      d8m.json.symbols.flatMap((entry) => {
        const value = entry.address ?? entry.value;
        return value === undefined ? [] : [[entry.name, value]];
      }),
    ),
  };
};

let image: Image;

beforeAll(async () => {
  const result = await compile(
    path.join(rewriteDirectory, "r6-backend-recipes-proof.asm"),
    { emitHex: true, emitD8m: true, registerContracts: "strict" },
  );
  expect(
    result.diagnostics.filter(({ severity }) => severity === "error"),
  ).toEqual([]);
  image = imageFromArtifacts(result.artifacts);
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
  while (!runtime.isHalted() && instructions < 300_000) {
    const step = runtime.step();
    instructions += 1;
    cycles += step.cycles ?? 0;
  }
  expect(runtime.isHalted(), entryName).toBe(true);
  return { memory: runtime.hardware.memory, instructions, cycles };
};

describe("ground-up rewrite backend recipes", () => {
  it("emits byte-identical target code for the first 38 scalar operations", () => {
    const { memory, instructions, cycles } = run("ProofBackendRecipes");
    expect(memory[image.symbols.ProofStatus ?? -1]).toBe(0xa5);
    expect({ instructions, cycles }).toEqual({
      instructions: 10_794,
      cycles: 95_008,
    });
    const output = image.symbols.ProofBackendOutput ?? -1;
    const expected = image.symbols.ProofExpectedBackend ?? -1;
    const expectedEnd = image.symbols.ProofExpectedBackendEnd ?? -1;
    expect(expectedEnd - expected).toBe(242);
    expect(Array.from(memory.slice(output, output + 242))).toEqual(
      Array.from(memory.slice(expected, expectedEnd)),
    );
  });

  it("reports exact target-capacity failure at the first rejected byte", () => {
    const { memory } = run("ProofBackendCapacity");
    const output = image.symbols.ProofBackendOutput ?? -1;
    const cursor = image.symbols.RewriteBackendOutputCursor ?? -1;
    expect({
      diagnostic: memory[image.symbols.DiagnosticCode ?? -1],
      cursor: memory[cursor] | (memory[cursor + 1] << 8),
      bytes: Array.from(memory.slice(output, output + 4)),
    }).toEqual({
      diagnostic: 96,
      cursor: output + 3,
      bytes: [0x21, 0x34, 0x12, 0],
    });
  });

  it("reports escape capacity failure at the first placeholder operand", () => {
    const { memory } = run("ProofBackendEscapeCapacity");
    const output = image.symbols.ProofBackendOutput ?? -1;
    const cursor = image.symbols.RewriteBackendOutputCursor ?? -1;
    expect({
      diagnostic: memory[image.symbols.DiagnosticCode ?? -1],
      cursor: memory[cursor] | (memory[cursor + 1] << 8),
      bytes: Array.from(memory.slice(output, output + 5)),
    }).toEqual({
      diagnostic: 96,
      cursor: output + 4,
      bytes: [0xe1, 0x7c, 0xb7, 0x28, 0],
    });
  });

  it("reports address capacity failure after the admitted low byte", () => {
    const { memory } = run("ProofBackendAddressCapacity");
    const output = image.symbols.ProofBackendOutput ?? -1;
    const cursor = image.symbols.RewriteBackendOutputCursor ?? -1;
    expect({
      diagnostic: memory[image.symbols.DiagnosticCode ?? -1],
      cursor: memory[cursor] | (memory[cursor + 1] << 8),
      bytes: Array.from(memory.slice(output, output + 3)),
    }).toEqual({
      diagnostic: 96,
      cursor: output + 2,
      bytes: [0x3a, 0x12, 0],
    });
  });

  it("emits byte-identical conversion and division escape paths", () => {
    const { memory, instructions, cycles } = run("ProofBackendEscapes");
    expect(memory[image.symbols.ProofStatus ?? -1]).toBe(0xa5);
    expect({ instructions, cycles }).toEqual({
      instructions: 6_432,
      cycles: 61_338,
    });
    expect(
      (image.symbols.ProofExpectedEscapesEnd ?? 0) -
        (image.symbols.ProofExpectedEscapes ?? 0),
    ).toBe(232);
  });

  it("emits the full-address far-jump trap ending across banks", () => {
    const { memory, instructions, cycles } = run("ProofBackendBankedTrap");
    expect(memory[image.symbols.ProofStatus ?? -1]).toBe(0xa5);
    expect({ instructions, cycles }).toEqual({
      instructions: 1_359,
      cycles: 14_940,
    });
  });

  it("emits full-width initialized, BSS, read-only, and indirect addresses", () => {
    const { memory, instructions, cycles } = run("ProofBackendAddresses");
    expect(memory[image.symbols.ProofStatus ?? -1]).toBe(0xa5);
    expect({ instructions, cycles }).toEqual({
      instructions: 4_183,
      cycles: 38_193,
    });
    expect(
      (image.symbols.ProofExpectedAddressesEnd ?? 0) -
        (image.symbols.ProofExpectedAddresses ?? 0),
    ).toBe(84);
  });

  it("uses complete recipe addresses at separated compiler origins", async () => {
    const directory = await mkdtemp(
      path.join(os.tmpdir(), "nucleus-r6-backend-recipe-origin-"),
    );
    try {
      const relativeImage = path.relative(
        directory,
        path.join(rewriteDirectory, "compiler-image.asmi"),
      );
      for (const origin of [0, 0x8000]) {
        const sourcePath = path.join(
          directory,
          `backend-recipe-${origin.toString(16)}.asm`,
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
            "ProofRelocatedRecipe:",
            " LD SP,$FF00",
            " CALL RewriteReset",
            " LD HL,ProofRelocatedFailure",
            " PUSH HL",
            " LD (CompilerAbortSp),SP",
            " LD HL,ProofRelocatedOutput",
            " LD DE,ProofRelocatedOutput+$80",
            " LD IX,ProofRelocatedContext",
            " CALL RewriteBackendInitialize",
            " LD HL,$1234",
            " LD (RewriteSemanticOperandArea),HL",
            " LD A,RewriteSemanticLiteral16",
            " CALL RewriteBackendDispatchOperation",
            " LD HL,$1234",
            " LD (RewriteSemanticOperandArea+RewriteSemanticNarrowU8OperandSourceOffsetOffset),HL",
            " LD A,RewriteSemanticNarrowU8",
            " CALL RewriteBackendDispatchOperation",
            " LD HL,ProofRelocatedOutput",
            " LD A,(HL)",
            " CP $21",
            " JP NZ,ProofRelocatedFailure",
            " INC HL",
            " LD A,(HL)",
            " CP $34",
            " JP NZ,ProofRelocatedFailure",
            " INC HL",
            " LD A,(HL)",
            " CP $12",
            " JP NZ,ProofRelocatedFailure",
            " INC HL",
            " LD A,(HL)",
            " CP $E5",
            " JP NZ,ProofRelocatedFailure",
            " INC HL",
            " LD A,(HL)",
            " CP $E1",
            " JP NZ,ProofRelocatedFailure",
            " LD A,$A5",
            " LD (ProofRelocatedStatus),A",
            " HALT",
            "ProofRelocatedFailure:",
            " LD A,$FF",
            " LD (ProofRelocatedStatus),A",
            " HALT",
            "ProofRelocatedStatus: .db 0",
            "ProofRelocatedContext:",
            " .dw $9000,$A000,$A100,$F100,$B000,$B800,$C000",
            " .db 0,0",
            "ProofRelocatedOutput: .ds $80",
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
        const relocated = imageFromArtifacts(result.artifacts);
        const parsed = parseIntelHex(relocated.hex);
        const entry = relocated.symbols.ProofRelocatedRecipe;
        const status = relocated.symbols.ProofRelocatedStatus;
        if (entry === undefined || status === undefined) {
          throw new Error("relocated backend-recipe symbols are incomplete");
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
  }, 60_000);

  it("locks the runtime-call and Boolean-fixup recipe account", () => {
    expect({
      engine:
        (image.symbols.RewriteBackendCodeEnd ?? 0) -
        (image.symbols.RewriteBackendCodeStart ?? 0),
      recipes:
        (image.symbols.RewriteBackendRecipeDataEnd ?? 0) -
        (image.symbols.RewriteBackendRecipeDirectory ?? 0),
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
    }).toEqual({
      engine: 978,
      recipes: 684,
      code: 13_181,
      immutable: 2_148,
      core: 15_329,
      workspace: 3_425,
    });
  });
});
