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
  const expectedDynamicDivisionStart =
    image.symbols.ProofExpectedDynamicDivisionSemantics ?? -1;
  const expectedDynamicDivisionEnd =
    image.symbols.ProofExpectedDynamicDivisionSemanticsEnd ?? -1;
  const expectedPathStart = image.symbols.ProofExpectedPathSemantics ?? -1;
  const expectedPathEnd = image.symbols.ProofExpectedPathSemanticsEnd ?? -1;
  const expectedPostfixAssignmentStart =
    image.symbols.ProofExpectedPostfixAssignmentSemantics ?? -1;
  const expectedPostfixAssignmentEnd =
    image.symbols.ProofExpectedPostfixAssignmentSemanticsEnd ?? -1;
  const expectedCallStart = image.symbols.ProofExpectedCallSemantics ?? -1;
  const expectedCallEnd = image.symbols.ProofExpectedCallSemanticsEnd ?? -1;
  const expectedAssignmentStart =
    image.symbols.ProofExpectedScalarAssignmentSemantics ?? -1;
  const expectedAssignmentEnd =
    image.symbols.ProofExpectedScalarAssignmentSemanticsEnd ?? -1;
  const expectedCallStatementStart =
    image.symbols.ProofExpectedCallStatementSemantics ?? -1;
  const expectedCallStatementEnd =
    image.symbols.ProofExpectedCallStatementSemanticsEnd ?? -1;
  const expectedRoutineExitStart =
    image.symbols.ProofExpectedRoutineExitSemantics ?? -1;
  const expectedRoutineExitEnd =
    image.symbols.ProofExpectedRoutineExitSemanticsEnd ?? -1;
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
    expectedDynamicDivisionSemantics: Array.from(
      memory.slice(expectedDynamicDivisionStart, expectedDynamicDivisionEnd),
    ),
    expectedPathSemantics: Array.from(
      memory.slice(expectedPathStart, expectedPathEnd),
    ),
    expectedPostfixAssignmentSemantics: Array.from(
      memory.slice(
        expectedPostfixAssignmentStart,
        expectedPostfixAssignmentEnd,
      ),
    ),
    expectedCallSemantics: Array.from(
      memory.slice(expectedCallStart, expectedCallEnd),
    ),
    expectedAssignmentSemantics: Array.from(
      memory.slice(expectedAssignmentStart, expectedAssignmentEnd),
    ),
    expectedCallStatementSemantics: Array.from(
      memory.slice(expectedCallStatementStart, expectedCallStatementEnd),
    ),
    expectedRoutineExitSemantics: Array.from(
      memory.slice(expectedRoutineExitStart, expectedRoutineExitEnd),
    ),
  };
};

describe("ground-up rewrite runtime scalar expressions", () => {
  it("publishes literal, constant, activation, initialized, and BSS carriers", () => {
    expect(run("ProofRuntimeAtoms")).toMatchObject({
      status: 0xc0,
      diagnostic: 0,
      instructions: 63_543,
      cycles: 579_406,
    });
  });

  it("reduces complete scalar precedence expressions into exact operations", () => {
    const result = run("ProofRuntimeExpressions");
    expect(result.semanticOperations).toBe(79);
    expect(result.semantics).toEqual(result.expectedExpressionSemantics);
    expect(result).toMatchObject({
      status: 0xc4,
      diagnostic: 0,
      instructions: 126_417,
      cycles: 1_140_839,
    });
  });

  it("publishes a runtime divide when the divisor is a dynamic carrier", () => {
    const result = run("ProofRuntimeDynamicDivision");
    expect(result.semanticOperations).toBe(5);
    expect(result.semantics).toEqual(result.expectedDynamicDivisionSemantics);
    expect(result).toMatchObject({
      status: 0xeb,
      diagnostic: 0,
      localOffset: 6,
    });
  });

  it("iterates record, fixed/open array, and bounded/open string postfixes", () => {
    const result = run("ProofRuntimePaths");
    expect(result.semanticOperations).toBe(63);
    expect(result.semantics).toEqual(result.expectedPathSemantics);
    expect(result).toMatchObject({
      status: 0xc9,
      diagnostic: 0,
      localOffset: 24,
      instructions: 108_795,
      cycles: 972_105,
    });
  });

  it("assigns through fixed/open postfixes and retains the target across failure", () => {
    const result = run("ProofRuntimePostfixAssignments");
    expect(result.semanticOperations).toBe(35);
    expect(result.semantics).toEqual(
      result.expectedPostfixAssignmentSemantics,
    );
    expect(result).toMatchObject({
      status: 0xe7,
      diagnostic: 0,
      instructions: 65_870,
      cycles: 589_209,
    });
  });

  it("publishes nested source, service, failable, and open-view calls", () => {
    const result = run("ProofRuntimeCalls");
    expect(result.semanticOperations).toBe(30);
    expect(result.semantics).toEqual(result.expectedCallSemantics);
    expect(result).toMatchObject({
      status: 0xca,
      diagnostic: 0,
      localOffset: 15,
      instructions: 98_441,
      cycles: 886_447,
    });
  });

  it("selects the distinct main failure-propagation mode", () => {
    expect(run("ProofRuntimeMainCall")).toMatchObject({
      status: 0xcb,
      diagnostic: 0,
      semanticOperations: 3,
      localOffset: 1,
      instructions: 12_192,
      cycles: 111_600,
    });
  });

  it("accepts exactly four nested source-call frames and releases them", () => {
    expect(run("ProofRuntimeCallDepth")).toMatchObject({
      status: 0xcc,
      diagnostic: 0,
      semanticOperations: 7,
      localOffset: 1,
      instructions: 22_737,
      cycles: 204_604,
    });
  });

  it("passes concrete aggregate routine results through open views", () => {
    expect(run("ProofRuntimeCallTransientViews")).toMatchObject({
      status: 0xcd,
      diagnostic: 0,
      semanticOperations: 7,
      localOffset: 2,
      instructions: 40_009,
      cycles: 362_980,
    });
  });

  it("resolves the current routine for a recursive source call", () => {
    expect(run("ProofRuntimeRecursiveCall")).toMatchObject({
      status: 0xce,
      diagnostic: 0,
      semanticOperations: 4,
      localOffset: 2,
      instructions: 14_334,
      cycles: 130_998,
    });
  });

  it("publishes scalar stores for explicit program, local, and parameter targets", () => {
    const result = run("ProofRuntimeScalarAssignments");
    expect(result.semanticOperations).toBe(15);
    expect(result.semantics).toEqual(result.expectedAssignmentSemantics);
    expect(result).toMatchObject({
      status: 0xcf,
      diagnostic: 0,
      instructions: 39_078,
      cycles: 352_515,
    });
  });

  it.each([
    ["ProofRuntimeAssignmentUnknown", 0xd6, 57, 11],
    ["ProofRuntimeAssignmentConstant", 0xd7, 60, 23],
    ["ProofRuntimeAssignmentMismatch", 0xd8, 60, 31],
  ] as const)(
    "preserves the frozen scalar-assignment diagnostic at %s",
    (entry, status, diagnostic, offset) => {
      expect(run(entry)).toMatchObject({ status, diagnostic, part: 1, offset });
    },
  );

  it.each([
    ["ProofRuntimeAssignmentReadOnlyAggregate", 0xe8, 94],
    ["ProofRuntimeAssignmentFixedStringLength", 0xe9, 60],
    ["ProofRuntimeAssignmentOpenWhole", 0xea, 60],
  ] as const)(
    "preserves the frozen postfix-assignment diagnostic at %s",
    (entry, status, diagnostic) => {
      expect(run(entry)).toMatchObject({ status, diagnostic, part: 1 });
    },
  );

  it("publishes success, failure, bare, main, and enclosing routine exits", () => {
    const result = run("ProofRuntimeRoutineExits");
    expect(result.semanticOperations).toBe(14);
    expect(result.semantics).toEqual(result.expectedRoutineExitSemantics);
    expect(result).toMatchObject({
      status: 0xde,
      diagnostic: 0,
      instructions: 35_141,
      cycles: 318_199,
    });
  });

  it("returns an exact aggregate alias without copying its representation", () => {
    expect(run("ProofRuntimeAggregateReturn")).toMatchObject({
      status: 0xe4,
      diagnostic: 0,
      semanticOperations: 3,
      instructions: 10_017,
      cycles: 92_670,
    });
  });

  it("rejects a failable invocation as a success return expression", () => {
    expect(run("ProofRuntimeReturnFailableCall")).toMatchObject({
      status: 0xe5,
      diagnostic: 87,
      part: 1,
    });
  });

  it.each([
    ["ProofRuntimeBareValueReturn", 0xdf, 75],
    ["ProofRuntimeValueInVoidReturn", 0xe0, 75],
    ["ProofRuntimeFailInfallible", 0xe1, 87],
    ["ProofRuntimeValueFallthrough", 0xe2, 75],
    ["ProofRuntimeFailWrongType", 0xe3, 60],
  ] as const)(
    "preserves the frozen routine-exit diagnostic at %s",
    (entry, status, diagnostic) => {
      expect(run(entry)).toMatchObject({ status, diagnostic, part: 1 });
    },
  );

  it("publishes source and service call statements with immediate propagation", () => {
    const result = run("ProofRuntimeCallStatements");
    expect(result.semanticOperations).toBe(5);
    expect(result.semantics).toEqual(result.expectedCallStatementSemantics);
    expect(result).toMatchObject({
      status: 0xd9,
      diagnostic: 0,
      instructions: 28_193,
      cycles: 253_671,
    });
  });

  it.each([
    ["ProofRuntimeCallStatementUnknown", 0xda, 57, 11],
    ["ProofRuntimeCallStatementMissingElse", 0xdb, 87, 44],
    ["ProofRuntimeCallStatementInfallibleElse", 0xdc, 87, 39],
  ] as const)(
    "preserves the frozen call-statement diagnostic at %s",
    (entry, status, diagnostic, offset) => {
      expect(run(entry)).toMatchObject({ status, diagnostic, part: 1, offset });
    },
  );

  it.each([
    ["ProofRuntimeCallMissingConsumer", 0xd0, 87],
    ["ProofRuntimeCallInfallibleElse", 0xd1, 87],
    ["ProofRuntimeCallGroupedFailure", 0xd2, 87],
    ["ProofRuntimeCallConvertedFailure", 0xd3, 87],
    ["ProofRuntimeCallUnaryFailure", 0xd4, 87],
    ["ProofRuntimeCallStrayElse", 0xd5, 87],
    ["ProofRuntimeCallLiteralOpen", 0xd6, 130],
    ["ProofRuntimeCallNestedFailure", 0xd7, 87],
    ["ProofRuntimeCallDepthOverflow", 0xd8, 65],
    ["ProofRuntimeCallTooFew", 0xd9, 58],
    ["ProofRuntimeCallTooMany", 0xda, 134],
    ["ProofRuntimeCallWrongType", 0xdb, 60],
    ["ProofRuntimeCallIndexFailure", 0xdc, 87],
    ["ProofRuntimeCallBinaryFailure", 0xdd, 87],
  ] as const)(
    "preserves exact call/failure diagnostic provenance at %s",
    (entry, status, diagnostic) => {
      expect(run(entry)).toMatchObject({
        status,
        diagnostic,
        part: 1,
      });
    },
  );

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

  it.each([
    ["ProofRuntimePathCapacity", 0xca, 60],
    ["ProofRuntimePathRange", 0xcb, 61],
    ["ProofRuntimePathBooleanIndex", 0xcc, 60],
    ["ProofRuntimePathNegativeIndex", 0xcd, 61],
    ["ProofRuntimePathUnknownField", 0xce, 57],
  ] as const)(
    "preserves exact postfix diagnostic provenance at %s",
    (entry, status, diagnostic) => {
      expect(run(entry)).toMatchObject({ status, diagnostic, part: 1 });
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
      statements:
        (image.symbols.RewriteStatementCodeEnd ?? 0) -
        (image.symbols.RewriteStatementCodeStart ?? 0),
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
      operations: 105,
      escapes: 56,
      actionCode: 230,
      actionData: 240,
      expression: 3_984,
      statements: 717,
      declarations: 1_528,
      code: 16_168,
      immutable: 1_508,
      core: 17_676,
      workspace: 3_938,
    });
  });
});
