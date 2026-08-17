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

beforeAll(async () => {
  const result = await compile(
    path.join(rewriteDirectory, "r5-front-driver-proof.asm"),
    { emitHex: true, emitD8m: true, registerContracts: "strict" },
  );
  expect(
    result.diagnostics.filter(({ severity }) => severity === "error"),
  ).toEqual([]);
  const hex = result.artifacts.find((artifact) => artifact.kind === "hex");
  const d8m = result.artifacts.find((artifact) => artifact.kind === "d8m");
  if (hex?.kind !== "hex" || d8m?.kind !== "d8m") {
    throw new Error("AZM omitted R5 front-driver proof artifacts");
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

describe("ground-up rewrite source-driven routine body", () => {
  it("parses a complete nested routine body from source", () => {
    const parsed = parseIntelHex(image.hex);
    const entry = image.symbols.ProofFrontDriver;
    if (entry === undefined) throw new Error("missing ProofFrontDriver");
    const runtime = createZ80Runtime(
      { ...parsed, memory: parsed.memory.slice(), startAddress: entry },
      entry,
    );
    let instructions = 0;
    let cycles = 0;
    while (!runtime.isHalted() && instructions < 250_000) {
      const step = runtime.step();
      instructions += 1;
      cycles += step.cycles ?? 0;
    }
    expect(runtime.isHalted()).toBe(true);
    const memory = runtime.hardware.memory;
    expect(memory[image.symbols.ProofStatus ?? -1]).toBe(0xa5);
    expect({ instructions, cycles }).toEqual({
      instructions: 48_328,
      cycles: 432_026,
    });
    const payload = image.symbols.RewriteSemanticPayloadBase ?? -1;
    const cursorAddress = image.symbols.RewriteSemanticSinkCursor ?? -1;
    const cursor = memory[cursorAddress] | (memory[cursorAddress + 1] << 8);
    const records: Array<{ name: string; bytes: number[] }> = [];
    for (let address = payload; address < cursor; ) {
      const id = memory[address];
      const operation = rewriteSemanticOperations[id - 1];
      if (operation === undefined) throw new Error(`invalid operation ${id}`);
      records.push({
        name: operation.name,
        bytes: Array.from(memory.slice(address, address + operation.width)),
      });
      address += operation.width;
    }
    expect(records).toEqual([
      { name: "DeclareLocal16", bytes: [33, 0] },
      { name: "Literal16", bytes: [61, 0, 0] },
      { name: "StoreLocal16", bytes: [38, 0] },
      { name: "DeclareLocalU8", bytes: [30, 2] },
      { name: "Literal16", bytes: [61, 0, 0] },
      { name: "StoreLocalU8", bytes: [32, 2] },
      { name: "ControlLabelDirect", bytes: [39, 0] },
      { name: "Literal16", bytes: [61, 1, 0] },
      { name: "BranchFalse", bytes: [41, 1] },
      { name: "LoadLocal16", bytes: [34, 0] },
      { name: "Literal16", bytes: [61, 0, 0] },
      { name: "Compare16", bytes: [36, 128] },
      { name: "BranchFalse", bytes: [41, 3] },
      { name: "Literal16", bytes: [61, 1, 0] },
      { name: "StoreLocal16", bytes: [38, 0] },
      { name: "JumpDirect", bytes: [42, 2] },
      { name: "ControlLabelDirect", bytes: [39, 3] },
      { name: "Literal16", bytes: [61, 0, 0] },
      { name: "BranchFalse", bytes: [41, 4] },
      { name: "JumpDirect", bytes: [42, 0] },
      { name: "JumpDirect", bytes: [42, 2] },
      { name: "ControlLabelDirect", bytes: [39, 4] },
      {
        name: "CallSource",
        bytes: [105, 0, 0, 0, 1, 127, 0, 3, 5, 0],
      },
      { name: "SkipHandler", bytes: [53, 6] },
      { name: "BeginHandlerLocal", bytes: [90, 5, 9, 2] },
      { name: "Literal16", bytes: [61, 2, 0] },
      { name: "StoreLocal16", bytes: [38, 0] },
      { name: "EndHandler", bytes: [54, 6] },
      { name: "JumpDirect", bytes: [42, 1] },
      { name: "ControlLabelEnclosing", bytes: [40, 2] },
      { name: "JumpEnclosing", bytes: [43, 0] },
      { name: "ControlLabelEnclosing", bytes: [40, 1] },
      { name: "EndFailableRoutineDirect", bytes: [51, 0] },
      { name: "EndFailableRoutineEnclosing", bytes: [52, 0] },
    ]);
  });

  it.each([
    ["ProofFrontLateLocal", 58, 18],
    ["ProofFrontMissingEnd", 58, 11],
    ["ProofFrontWhileElse", 140, 38],
    ["ProofFrontRoutineAssignment", 133, 27],
    ["ProofFrontVariableCall", 135, 24],
  ] as const)(
    "retains exact source diagnostics for %s",
    (entryName, diagnostic, offset) => {
      const parsed = parseIntelHex(image.hex);
      const entry = image.symbols[entryName];
      if (entry === undefined) throw new Error(`missing ${entryName}`);
      const runtime = createZ80Runtime(
        { ...parsed, memory: parsed.memory.slice(), startAddress: entry },
        entry,
      );
      let instructions = 0;
      while (!runtime.isHalted() && instructions < 100_000) {
        runtime.step();
        instructions += 1;
      }
      expect(runtime.isHalted()).toBe(true);
      const memory = runtime.hardware.memory;
      const diagnosticOffset = image.symbols.DiagnosticOffset ?? -1;
      expect({
        diagnostic: memory[image.symbols.DiagnosticCode ?? -1],
        part: memory[image.symbols.DiagnosticPartId ?? -1],
        offset:
          memory[diagnosticOffset] | (memory[diagnosticOffset + 1] << 8),
      }).toEqual({ diagnostic, part: 1, offset });
    },
  );

  it("executes the source-driven grammar at separated compiler origins", async () => {
    const directory = await mkdtemp(
      path.join(os.tmpdir(), "nucleus-r5-front-driver-origin-"),
    );
    try {
      const imageInclude = path.join(rewriteDirectory, "compiler-image.asmi");
      const relativeImage = path.relative(directory, imageInclude);
      for (const origin of [0, 0x8000]) {
        const sourcePath = path.join(
          directory,
          `front-driver-${origin.toString(16)}.asm`,
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
            "ProofRelocatedFrontDriver:",
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
            " CALL RewriteFrontParseRoutineBody",
            " CALL RewriteParserPeek",
            " OR A",
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
            "ProofRelocatedSource: .db \"sub main()\",10,\"return\",10,\"end\",10",
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
          throw new Error("AZM omitted relocated front-driver artifacts");
        }
        const symbols = Object.fromEntries(
          d8m.json.symbols.flatMap((entry) => {
            const value = entry.address ?? entry.value;
            return value === undefined ? [] : [[entry.name, value]];
          }),
        );
        const parsed = parseIntelHex(hex.text);
        const entry = symbols.ProofRelocatedFrontDriver;
        const status = symbols.ProofRelocatedStatus;
        if (entry === undefined || status === undefined) {
          throw new Error("relocated front-driver symbols are incomplete");
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
  }, 45_000);
});
