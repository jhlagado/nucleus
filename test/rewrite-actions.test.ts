import path from "node:path";

import { compile } from "@jhlagado/azm/compile";
import { createZ80Runtime, parseIntelHex } from "@jhlagado/debug80-runtime";
import { beforeAll, describe, expect, it } from "vitest";

import {
  decodeRewriteActionProgram,
  rewriteActionEscapes,
  rewriteActionInstructions,
  rewriteActionPrograms,
} from "../src/rewrite-actions-internal.js";

const rewriteDirectory = path.resolve(import.meta.dirname, "../asm/rewrite");

interface Image {
  readonly hex: string;
  readonly symbols: Readonly<Record<string, number>>;
}

let image: Image;

beforeAll(async () => {
  const result = await compile(
    path.join(rewriteDirectory, "r3-action-machine-proof.asm"),
    { emitHex: true, emitD8m: true, registerContracts: "strict" },
  );
  expect(
    result.diagnostics.filter(({ severity }) => severity === "error"),
  ).toEqual([]);
  const hex = result.artifacts.find((artifact) => artifact.kind === "hex");
  const d8m = result.artifacts.find((artifact) => artifact.kind === "d8m");
  if (hex?.kind !== "hex" || d8m?.kind !== "d8m") {
    throw new Error("AZM omitted R3 action-machine proof artifacts");
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
}, 15_000);

const run = (entryName: string): number => {
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
  expect(runtime.isHalted(), entryName).toBe(true);
  return runtime.hardware.memory[image.symbols.ProofStatus ?? -1] ?? 0;
};

describe("ground-up rewrite front action machine", () => {
  it.each([
    ["ProofActionProgram", 0xf1],
    ["ProofActionMismatch", 0xf2],
    ["ProofActionInvalid", 0xf3],
  ] as const)("executes %s", (entry, expected) => {
    expect(run(entry)).toBe(expected);
  });

  it("publishes one generated instruction and escape authority", () => {
    expect(
      rewriteActionInstructions.map(({ name, width }) => [name, width]),
    ).toEqual([
      ["End", 1],
      ["Expect", 3],
      ["Escape", 2],
      ["Raise", 2],
    ]);
    expect(rewriteActionEscapes).toEqual([
      { name: "ResetInitializer", target: "RewriteInitializerReset", id: 0 },
      {
        name: "BeginScalarConstant",
        target: "RewriteDeclarationBeginScalarConstant",
        id: 1,
      },
      {
        name: "FinishScalarConstant",
        target: "RewriteDeclarationFinishScalarConstant",
        id: 2,
      },
      { name: "CommitSymbol", target: "RewriteSymbolCommit", id: 3 },
      {
        name: "BeginAssert",
        target: "RewriteDeclarationBeginAssert",
        id: 4,
      },
      {
        name: "FinishAssert",
        target: "RewriteDeclarationFinishAssert",
        id: 5,
      },
      {
        name: "BeginProgram",
        target: "RewriteDeclarationBeginProgram",
        id: 6,
      },
      {
        name: "ParseOwnedType",
        target: "RewriteDeclarationParseOwnedType",
        id: 7,
      },
      {
        name: "FinishProgramBss",
        target: "RewriteDeclarationFinishProgramBss",
        id: 8,
      },
      {
        name: "FinishProgramScalar",
        target: "RewriteDeclarationFinishProgramScalar",
        id: 9,
      },
      {
        name: "BeginRecord",
        target: "RewriteDeclarationBeginRecord",
        id: 10,
      },
      {
        name: "BeginRecordField",
        target: "RewriteFieldPrepareCurrent",
        id: 11,
      },
      {
        name: "ParseRecordFieldType",
        target: "RewriteDeclarationParseRecordFieldType",
        id: 12,
      },
      {
        name: "FinishRecordField",
        target: "RewriteDeclarationFinishRecordField",
        id: 13,
      },
      {
        name: "FinishRecord",
        target: "RewriteDeclarationFinishRecord",
        id: 14,
      },
      {
        name: "BeginAggregateConstant",
        target: "RewriteDeclarationBeginAggregateConstant",
        id: 15,
      },
      {
        name: "FinishAggregateConstant",
        target: "RewriteDeclarationFinishAggregateConstant",
        id: 16,
      },
      {
        name: "FinishProgramAggregate",
        target: "RewriteDeclarationFinishProgramAggregate",
        id: 17,
      },
      {
        name: "FinishDirectRoutineHeader",
        target: "RewriteDeclarationFinishDirectRoutineHeader",
        id: 18,
      },
      {
        name: "FinishForwardRoutineHeader",
        target: "RewriteDeclarationFinishForwardRoutineHeader",
        id: 19,
      },
      {
        name: "OpenForwardBody",
        target: "RewriteDeclarationOpenForwardBody",
        id: 20,
      },
      {
        name: "RequireComplete",
        target: "RewriteDeclarationRequireComplete",
        id: 21,
      },
      {
        name: "CloseRoutineScope",
        target: "RewriteRoutineCloseScope",
        id: 22,
      },
      {
        name: "BeginLocal",
        target: "RewriteDeclarationBeginLocal",
        id: 23,
      },
      {
        name: "ParseLocalScalarType",
        target: "RewriteDeclarationParseLocalScalarType",
        id: 24,
      },
      {
        name: "EmitDefaultLocal",
        target: "RewriteDeclarationEmitDefaultLocal",
        id: 25,
      },
      {
        name: "CommitLocal",
        target: "RewriteDeclarationCommitLocal",
        id: 26,
      },
      {
        name: "FinishRuntimeLocalExpression",
        target: "RewriteDeclarationFinishRuntimeLocalExpression",
        id: 27,
      },
      {
        name: "EmitLocalStore",
        target: "RewriteDeclarationEmitLocalStore",
        id: 28,
      },
      {
        name: "BeginScalarAssignment",
        target: "RewriteStatementBeginScalarAssignment",
        id: 29,
      },
      {
        name: "FinishScalarAssignmentExpression",
        target: "RewriteStatementFinishScalarAssignmentExpression",
        id: 30,
      },
      {
        name: "EmitScalarAssignment",
        target: "RewriteStatementEmitScalarAssignment",
        id: 31,
      },
      {
        name: "ParseCallStatement",
        target: "RewriteStatementParseCall",
        id: 32,
      },
      {
        name: "ParseReturnValue",
        target: "RewriteStatementParseReturnValue",
        id: 33,
      },
      {
        name: "CommitBareReturn",
        target: "RewriteStatementCommitBareReturn",
        id: 34,
      },
      {
        name: "ParseFail",
        target: "RewriteStatementParseFail",
        id: 35,
      },
      {
        name: "FinishRoutine",
        target: "RewriteStatementFinishRoutine",
        id: 36,
      },
      { name: "BeginIf", target: "RewriteControlBeginIf", id: 37 },
      { name: "ParseBoolean", target: "RewriteControlParseBoolean", id: 38 },
      { name: "BeginIfBody", target: "RewriteControlBeginIfBody", id: 39 },
      { name: "BeginElseIf", target: "RewriteControlBeginElseIf", id: 40 },
      { name: "BeginElse", target: "RewriteControlBeginElse", id: 41 },
      { name: "FinishElse", target: "RewriteControlFinishElse", id: 42 },
      {
        name: "FinishIfClauses",
        target: "RewriteControlFinishIfClauses",
        id: 43,
      },
      { name: "EndIf", target: "RewriteControlEndIf", id: 44 },
      { name: "BeginWhile", target: "RewriteControlBeginWhile", id: 45 },
      {
        name: "BeginWhileBody",
        target: "RewriteControlBeginWhileBody",
        id: 46,
      },
      { name: "EndWhile", target: "RewriteControlEndWhile", id: 47 },
      { name: "EmitExit", target: "RewriteControlEmitExit", id: 48 },
      { name: "EmitContinue", target: "RewriteControlEmitContinue", id: 49 },
    ]);
    expect(rewriteActionPrograms.map(({ name, width }) => [name, width])).toEqual([
      ["ScalarConstant", 19],
      ["Assert", 11],
      ["ProgramBss", 21],
      ["ProgramScalarInitialized", 24],
      ["RecordBegin", 12],
      ["RecordField", 16],
      ["RecordEnd", 11],
      ["AggregateConstant", 24],
      ["ProgramAggregateInitialized", 24],
      ["RoutineDirectHeader", 9],
      ["RoutineForwardHeader", 12],
      ["RoutineForwardBody", 12],
      ["CompilationEnd", 6],
      ["RoutineEnd", 9],
      ["RoutineBodyEnd", 9],
      ["LocalDefault", 21],
      ["LocalInitializedExpression", 26],
      ["ScalarAssignment", 16],
      ["CallStatement", 9],
      ["ReturnValue", 9],
      ["BareReturn", 9],
      ["Fail", 9],
      ["IfHeader", 13],
      ["ElseIfHeader", 13],
      ["ElseHeader", 9],
      ["IfNoElseTail", 3],
      ["IfElseTail", 3],
      ["IfEnd", 9],
      ["WhileHeader", 13],
      ["WhileEnd", 9],
      ["Exit", 9],
      ["Continue", 9],
    ]);
    expect(image.symbols.RewriteActionEscapeDispatch).toBeDefined();
    expect({
      code:
        (image.symbols.RewriteActionCodeEnd ?? 0) -
        (image.symbols.RewriteActionCodeStart ?? 0),
      immutable:
        (image.symbols.RewriteActionImmutableEnd ?? 0) -
        (image.symbols.RewriteActionImmutableStart ?? 0),
      core:
        (image.symbols.RewriteCompilerCoreEnd ?? 0) -
        (image.symbols.RewriteCompilerCodeStart ?? 0),
      workspace:
        (image.symbols.RewriteWorkspaceEnd ?? 0) -
        (image.symbols.RewriteStateBase ?? 0),
    }).toEqual({ code: 227, immutable: 412, core: 11_806, workspace: 3_418 });
  });

  it("decodes exact boundaries and rejects malformed programs", () => {
    expect(
      decodeRewriteActionProgram(new Uint8Array([1, 32, 37, 2, 0, 0])),
    ).toEqual([0, 3, 5]);
    expect(() => decodeRewriteActionProgram(new Uint8Array([4]))).toThrow();
    expect(() =>
      decodeRewriteActionProgram(new Uint8Array([2, 50, 0])),
    ).toThrow();
    expect(() => decodeRewriteActionProgram(new Uint8Array([1, 32]))).toThrow();
    expect(() => decodeRewriteActionProgram(new Uint8Array([3, 50]))).toThrow();
    expect(() => decodeRewriteActionProgram(new Uint8Array([0, 0]))).toThrow();
  });
});
