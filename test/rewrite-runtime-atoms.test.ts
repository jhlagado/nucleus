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
    path.join(rewriteDirectory, "r4-runtime-atoms-proof.asm"),
    { emitHex: true, emitD8m: true, registerContracts: "strict" },
  );
  expect(
    result.diagnostics.filter(({ severity }) => severity === "error"),
  ).toEqual([]);
  const hex = result.artifacts.find((artifact) => artifact.kind === "hex");
  const d8m = result.artifacts.find((artifact) => artifact.kind === "d8m");
  if (hex?.kind !== "hex" || d8m?.kind !== "d8m") {
    throw new Error("AZM omitted R4 runtime-expression proof artifacts");
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
});

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
  while (!runtime.isHalted() && instructions < 500_000) {
    const step = runtime.step();
    cycles += step.cycles ?? 0;
    instructions += 1;
  }
  expect(runtime.isHalted(), entryName).toBe(true);
  const memory = runtime.hardware.memory;
  const offsetAddress = image.symbols.DiagnosticOffset ?? -1;
  const semanticBase = image.symbols.RewriteSemanticPayloadBase ?? -1;
  const semanticCursorAddress = image.symbols.RewriteSemanticSinkCursor ?? -1;
  const semanticCursor =
    memory[semanticCursorAddress] | (memory[semanticCursorAddress + 1] << 8);
  const expectedExpressionStart =
    image.symbols.ProofExpectedExpressionSemantics ?? -1;
  const expectedExpressionEnd =
    image.symbols.ProofExpectedExpressionSemanticsEnd ?? -1;
  return {
    status: memory[image.symbols.ProofStatus ?? -1],
    diagnostic: memory[image.symbols.DiagnosticCode ?? -1],
    part: memory[image.symbols.DiagnosticPartId ?? -1],
    offset: memory[offsetAddress] | (memory[offsetAddress + 1] << 8),
    instructions,
    cycles,
    semanticOperations: memory[image.symbols.RewriteSemanticBufferBase ?? -1],
    localOffset: memory[image.symbols.RewriteCurrentLocalOffset ?? -1],
    semantics: Array.from(memory.slice(semanticBase, semanticCursor)),
    expectedExpressionSemantics: Array.from(
      memory.slice(expectedExpressionStart, expectedExpressionEnd),
    ),
  };
};

describe("ground-up rewrite runtime scalar expressions", () => {
  it("publishes literal, constant, activation, initialized, and BSS carriers", () => {
    expect(run("ProofRuntimeAtoms")).toMatchObject({
      status: 0xc0,
      diagnostic: 0,
      instructions: 64_488,
      cycles: 582_097,
    });
  });

  it("reduces complete scalar precedence expressions into exact operations", () => {
    const result = run("ProofRuntimeExpressions");
    expect(result.semanticOperations).toBe(79);
    expect(result.semantics).toEqual(result.expectedExpressionSemantics);
    expect(result).toMatchObject({
      status: 0xc4,
      diagnostic: 0,
      instructions: 126_748,
      cycles: 1_136_185,
    });
  });

  it.each([
    ["ProofRuntimeMismatch", 0xc1, 60, 31],
    ["ProofRuntimeSelfReference", 0xc2, 57, 25],
    ["ProofRuntimeTrailingToken", 0xc3, 129, 27],
    ["ProofRuntimeDivisionZero", 0xc5, 62, 29],
    ["ProofRuntimeBooleanXor", 0xc6, 60, 52],
    ["ProofRuntimeComparisonChain", 0xc7, 64, 45],
    ["ProofRuntimeMixedWords", 0xc8, 60, 51],
  ] as const)(
    "preserves the frozen atom diagnostic at %s",
    (entry, status, diagnostic, offset) => {
      expect(run(entry)).toMatchObject({ status, diagnostic, part: 1, offset });
    },
  );

  it("locks the runtime scalar-expression replacement accounts", () => {
    expect({
      operations: image.symbols.RewriteSemanticOperationCount,
      escapes: image.symbols.RewriteActionEscapeCount,
      actionCode:
        (image.symbols.RewriteActionCodeEnd ?? 0) -
        (image.symbols.RewriteActionCodeStart ?? 0),
      actionData:
        (image.symbols.RewriteActionImmutableEnd ?? 0) -
        (image.symbols.RewriteActionImmutableStart ?? 0),
      expression:
        (image.symbols.RewriteExpressionCodeEnd ?? 0) -
        (image.symbols.RewriteExpressionCodeStart ?? 0),
      declarations:
        (image.symbols.RewriteFrontDeclarationCodeEnd ?? 0) -
        (image.symbols.RewriteFrontDeclarationCodeStart ?? 0),
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
      operations: 101,
      escapes: 29,
      actionCode: 285,
      actionData: 261,
      expression: 2_380,
      declarations: 1_510,
      code: 7_604,
      immutable: 1_236,
      core: 8_840,
      workspace: 3_374,
    });
  });
});
