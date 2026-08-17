import { mkdtemp, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";

import { compile } from "@jhlagado/azm/compile";
import { createZ80Runtime, parseIntelHex } from "@jhlagado/debug80-runtime";
import { beforeAll, describe, expect, it } from "vitest";

import { rewriteSemanticOperations } from "../src/rewrite-semantic-operations-internal.js";

const rewriteDirectory = path.resolve(import.meta.dirname, "../asm/rewrite");

interface Image {
  readonly hex: string;
  readonly symbols: Readonly<Record<string, number>>;
}

let image: Image;

const imageFromArtifacts = (
  artifacts: Awaited<ReturnType<typeof compile>>["artifacts"],
): Image => {
  const hex = artifacts.find((artifact) => artifact.kind === "hex");
  const d8m = artifacts.find((artifact) => artifact.kind === "d8m");
  if (hex?.kind !== "hex" || d8m?.kind !== "d8m") {
    throw new Error("AZM omitted R5 compilation-unit proof artifacts");
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

beforeAll(async () => {
  const result = await compile(
    path.join(rewriteDirectory, "r5-compilation-unit-proof.asm"),
    { emitHex: true, emitD8m: true, registerContracts: "strict" },
  );
  expect(
    result.diagnostics.filter(({ severity }) => severity === "error"),
  ).toEqual([]);
  image = imageFromArtifacts(result.artifacts);
}, 300_000);

const run = (entryName: string, instructionLimit = 300_000) => {
  const parsed = parseIntelHex(image.hex);
  const entry = image.symbols[entryName];
  if (entry === undefined) throw new Error(`missing ${entryName}`);
  const runtime = createZ80Runtime(
    { ...parsed, memory: parsed.memory.slice(), startAddress: entry },
    entry,
  );
  let instructions = 0;
  let cycles = 0;
  while (!runtime.isHalted() && instructions < instructionLimit) {
    const step = runtime.step();
    instructions += 1;
    cycles += step.cycles ?? 0;
  }
  expect(runtime.isHalted(), entryName).toBe(true);
  return { memory: runtime.hardware.memory, instructions, cycles };
};

describe("ground-up rewrite compilation-unit driver", () => {
  it("parses a complete mixed program directly from source", () => {
    const { memory, instructions, cycles } = run("ProofCompilationUnit");
    expect(memory[image.symbols.ProofStatus ?? -1]).toBe(0xa5);
    expect({ instructions, cycles }).toEqual({
      instructions: 66_562,
      cycles: 601_854,
    });
    expect({
      symbols: memory[image.symbols.RewriteSymbolCount ?? -1],
      routines: memory[image.symbols.RewriteRoutineCount ?? -1],
      parameters: memory[image.symbols.RewriteParameterCount ?? -1],
      records: memory[image.symbols.RewriteRecordCount ?? -1],
      mainFlags: memory[image.symbols.RewriteMainFlags ?? -1],
    }).toEqual({
      symbols: 7,
      routines: 1,
      parameters: 1,
      records: 1,
      mainFlags:
        (image.symbols.RewriteRoutineFlagMain ?? 0) +
        (image.symbols.RewriteRoutineFlagFails ?? 0),
    });
    const initializedBase = image.symbols.RewriteStaticImageBase ?? -1;
    const constantBase = initializedBase + 4;
    expect(Array.from(memory.slice(constantBase, constantBase + 6))).toEqual([
      2,
      "h".charCodeAt(0),
      "i".charCodeAt(0),
      0,
      0,
      0,
    ]);
    expect(Array.from(memory.slice(initializedBase, initializedBase + 4))).toEqual([
      3,
      0,
      1,
      0,
    ]);

    const payload = image.symbols.RewriteSemanticPayloadBase ?? -1;
    const cursorAddress = image.symbols.RewriteSemanticSinkCursor ?? -1;
    const cursor = memory[cursorAddress] | (memory[cursorAddress + 1] << 8);
    const records: Array<{ name: string; bytes: number[] }> = [];
    for (let address = payload; address < cursor; ) {
      const operation = rewriteSemanticOperations[memory[address] - 1];
      if (operation === undefined) throw new Error("invalid semantic operation");
      records.push({
        name: operation.name,
        bytes: Array.from(memory.slice(address, address + operation.width)),
      });
      address += operation.width;
    }
    expect(records).toEqual([
      { name: "LoadParameter16", bytes: [45, 0] },
      { name: "LoadProgram16", bytes: [62, 0, 0] },
      { name: "Add16", bytes: [9] },
      { name: "ReturnScalar", bytes: [22] },
      { name: "EndGeneralRoutineEnclosing", bytes: [49, 18] },
      { name: "DeclareLocalU8", bytes: [30, 0] },
      { name: "Literal16", bytes: [61, 0, 0] },
      { name: "StoreLocalU8", bytes: [32, 0] },
      { name: "Literal16", bytes: [61, 2, 0] },
      {
        name: "CallSource",
        bytes: [105, 1, 18, 0, 128, 15, 1, 0, 0, 0],
      },
      { name: "StoreProgram16", bytes: [68, 0, 0] },
      { name: "EndFailableRoutineEnclosing", bytes: [52, 0] },
    ]);
  });

  it.each([
    ["ProofCompilationMissingMain", 37, 12],
    ["ProofCompilationIncompleteForward", 54, 35],
    ["ProofCompilationMalformedRecord", 82, 14],
    ["ProofCompilationTypedScalarConstant", 60, 14],
    ["ProofCompilationMissingForward", 57, 4],
  ] as const)(
    "retains exact compilation-unit diagnostic for %s",
    (entryName, diagnostic, offset) => {
      const { memory } = run(entryName, 100_000);
      const diagnosticOffset = image.symbols.DiagnosticOffset ?? -1;
      expect({
        diagnostic: memory[image.symbols.DiagnosticCode ?? -1],
        part: memory[image.symbols.DiagnosticPartId ?? -1],
        offset:
          memory[diagnosticOffset] | (memory[diagnosticOffset + 1] << 8),
      }).toEqual({ diagnostic, part: 1, offset });
    },
  );

  it("executes complete compilation units at separated compiler origins", async () => {
    const directory = await mkdtemp(
      path.join(os.tmpdir(), "nucleus-r5-compilation-unit-origin-"),
    );
    try {
      const relativeImage = path.relative(
        directory,
        path.join(rewriteDirectory, "compiler-image.asmi"),
      );
      for (const origin of [0, 0x8000]) {
        const sourcePath = path.join(
          directory,
          `compilation-unit-${origin.toString(16)}.asm`,
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
            "ProofRelocatedUnit:",
            " LD SP,$FF00",
            " CALL RewriteReset",
            " LD HL,ProofRelocatedFailure",
            " PUSH HL",
            " LD (CompilerAbortSp),SP",
            " LD A,1",
            " LD HL,ProofRelocatedParts",
            " CALL RewriteSourceInitializeParts",
            " CALL RewriteFrontParseCompilationUnit",
            " LD A,(RewriteSymbolCount)",
            " CP 1",
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
            'ProofRelocatedSource: .db "sub main()",10,"end",10,"var after as u8",10',
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
        const relocated = imageFromArtifacts(result.artifacts);
        const parsed = parseIntelHex(relocated.hex);
        const entry = relocated.symbols.ProofRelocatedUnit;
        const status = relocated.symbols.ProofRelocatedStatus;
        if (entry === undefined || status === undefined) {
          throw new Error("relocated compilation-unit symbols are incomplete");
        }
        const runtime = createZ80Runtime(
          { ...parsed, memory: parsed.memory.slice(), startAddress: entry },
          entry,
        );
        let instructions = 0;
        while (!runtime.isHalted() && instructions < 100_000) {
          runtime.step();
          instructions += 1;
        }
        expect(runtime.isHalted(), `origin $${origin.toString(16)}`).toBe(true);
        expect(runtime.hardware.memory[status]).toBe(0xa5);
      }
    } finally {
      await rm(directory, { recursive: true, force: true });
    }
  }, 300_000);

  it("locks the compilation-unit code account", () => {
    expect({
      driver:
        (image.symbols.RewriteFrontDriverCodeEnd ?? 0) -
        (image.symbols.RewriteFrontDriverCodeStart ?? 0),
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
      driver: 651,
      code: 16_105,
      immutable: 1_508,
      core: 17_613,
      workspace: 3_938,
    });
  });
});
