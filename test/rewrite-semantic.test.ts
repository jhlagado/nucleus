import path from "node:path";

import { compile } from "@jhlagado/azm/compile";
import { createZ80Runtime, parseIntelHex } from "@jhlagado/debug80-runtime";
import { describe, expect, it } from "vitest";

import { nucleusSemanticOperationKeys } from "../src/d8-internal.js";
import {
  assertRewriteSemanticOperationKeys,
  rewriteSemanticOperationKeys,
  rewriteSemanticOperationMaximumWidth,
  rewriteSemanticOperations,
  rewriteSemanticTracePolicy,
} from "../src/rewrite-semantic-operations-internal.js";

const rewriteDirectory = path.resolve(import.meta.dirname, "../asm/rewrite");

interface AssembledImage {
  readonly hex: string;
  readonly symbols: Readonly<Record<string, number>>;
}

const assembleProof = async (): Promise<AssembledImage> => {
  const source = path.join(rewriteDirectory, "r2-semantic-proof.asm");
  const result = await compile(source, {
    emitHex: true,
    emitD8m: true,
    registerContracts: "strict",
  });
  const errors = result.diagnostics.filter(
    ({ severity }) => severity === "error",
  );
  expect(errors).toEqual([]);
  const hex = result.artifacts.find((artifact) => artifact.kind === "hex");
  const d8m = result.artifacts.find((artifact) => artifact.kind === "d8m");
  if (hex?.kind !== "hex" || d8m?.kind !== "d8m") {
    throw new Error("AZM omitted R2 semantic proof artifacts");
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

const runEntry = (
  image: AssembledImage,
  entryName: string,
  captureTrace = false,
): {
  readonly memory: Uint8Array;
  readonly ports: readonly number[];
  readonly keys: readonly number[];
  readonly instructions: number;
  readonly cycles: number;
} => {
  const parsed = parseIntelHex(image.hex);
  const entry = image.symbols[entryName];
  if (entry === undefined) throw new Error(`missing ${entryName}`);
  const ports: number[] = [];
  const keys: number[] = [];
  let runtime: ReturnType<typeof createZ80Runtime>;
  runtime = createZ80Runtime(
    { ...parsed, memory: parsed.memory.slice(), startAddress: entry },
    entry,
    {
      write: (port) => {
        ports.push(port);
        if (captureTrace && (port & 0xff) === 0xdd) {
          const memory = runtime.hardware.memory;
          const cursorAddress = image.symbols.RewriteSemanticReadCursor ?? -1;
          const payload = image.symbols.RewriteSemanticPayloadBase ?? -1;
          const cursor =
            (memory[cursorAddress] ?? 0) |
            ((memory[cursorAddress + 1] ?? 0) << 8);
          keys.push(cursor - payload);
        }
      },
    },
  );
  let instructions = 0;
  let cycles = 0;
  while (!runtime.isHalted() && instructions < 200_000) {
    const step = runtime.step();
    instructions += 1;
    cycles += step.cycles ?? 0;
  }
  expect(runtime.isHalted(), entryName).toBe(true);
  return { memory: runtime.hardware.memory, ports, keys, instructions, cycles };
};

describe("ground-up rewrite semantic authority", () => {
  it("generates one complete fixed-width operation authority", async () => {
    const image = await assembleProof();
    expect({
      semanticBytes:
        (image.symbols.RewriteSemanticCodeEnd ?? 0) -
        (image.symbols.RewriteSemanticCodeStart ?? 0),
      operationBytes:
        (image.symbols.RewriteOperationImmutableEnd ?? 0) -
        (image.symbols.RewriteOperationImmutableStart ?? 0),
      coreBytes:
        (image.symbols.RewriteCompilerCoreEnd ?? 0) -
        (image.symbols.RewriteCompilerCodeStart ?? 0),
      workspaceBytes:
        (image.symbols.RewriteWorkspaceEnd ?? 0) -
        (image.symbols.RewriteStateBase ?? 0),
    }).toEqual({
      semanticBytes: 224,
      operationBytes: 606,
      coreBytes: 10_752,
      workspaceBytes: 3_414,
    });
    expect(rewriteSemanticOperations).toHaveLength(101);
    expect(rewriteSemanticOperationMaximumWidth).toBe(10);
    expect(image.symbols.RewriteSemanticOperandCapacity).toBe(
      rewriteSemanticOperationMaximumWidth - 1,
    );
    expect(rewriteSemanticOperations.map(({ id }) => id)).toEqual(
      Array.from(
        { length: rewriteSemanticOperations.length },
        (_, index) => index + 1,
      ),
    );
    expect(
      new Set(rewriteSemanticOperations.map(({ name }) => name)).size,
    ).toBe(rewriteSemanticOperations.length);
    expect(
      rewriteSemanticOperations.every(
        ({ width, operands }) =>
          width ===
          1 + operands.reduce((sum, operand) => sum + operand.width, 0),
      ),
    ).toBe(true);
    expect(
      rewriteSemanticOperations.every(
        ({ trace }) => trace === "operation-start",
      ),
    ).toBe(true);
    expect(rewriteSemanticTracePolicy).toBe("operation-start");
    for (const name of ["CallSource", "CallService"] as const) {
      const operation = rewriteSemanticOperations.find(
        (candidate) => candidate.name === name,
      );
      expect(operation?.stack).toMatchObject({
        in: "dynamic",
        out: "dynamic",
        encoded: 0xff,
      });
    }
    expect(image.symbols.RewriteSemanticStackDynamic).toBe(15);

    const widths = image.symbols.RewriteSemanticOperationWidthTable ?? -1;
    const descriptors =
      image.symbols.RewriteSemanticOperationDescriptorTable ?? -1;
    const sourceKinds = { none: 0, direct: 1, enclosing: 2 } as const;
    for (const [index, operation] of rewriteSemanticOperations.entries()) {
      const descriptor = descriptors + index * 5;
      expect(image.symbols[`RewriteSemantic${operation.name}`]).toBe(
        operation.id,
      );
      const memory = parseIntelHex(image.hex).memory;
      expect(memory[widths + index], operation.name).toBe(operation.width);
      expect(memory[descriptor], operation.name).toBe(operation.width);
      expect(memory[descriptor + 1] & 0x0f, operation.name).toBe(
        operation.operands.length,
      );
      expect((memory[descriptor + 1] >>> 4) & 3, operation.name).toBe(
        sourceKinds[operation.source],
      );
      expect((memory[descriptor + 1] >>> 6) & 1, operation.name).toBe(0);
      expect(memory[descriptor + 1] >>> 7, operation.name).toBe(
        operation.backend.kind === "escape" ? 1 : 0,
      );
      expect(memory[descriptor + 2], operation.name).toBe(
        operation.operands.reduce(
          (bits, operand, operandIndex) =>
            bits | (operand.kind === "word" ? 1 << operandIndex : 0),
          0,
        ),
      );
      expect(memory[descriptor + 3], operation.name).toBe(
        operation.backend.index,
      );
      expect(memory[descriptor + 4], operation.name).toBe(
        operation.stack.encoded,
      );
      for (const operand of operation.operands) {
        expect(
          operand.offset + operand.width,
          `${operation.name}.${operand.name}`,
        ).toBeLessThanOrEqual(
          image.symbols.RewriteSemanticOperandCapacity ?? 0,
        );
        expect(operand.recordOffset).toBe(operand.offset + 1);
      }
    }

    const producerOffsets = [
      ["ProofLiteral16Value", "RewriteSemanticLiteral16OperandValueOffset"],
      [
        "ProofCallSourceSelector",
        "RewriteSemanticCallSourceOperandSelectorOffset",
      ],
      [
        "ProofCallSourceArgumentWords",
        "RewriteSemanticCallSourceOperandArgumentWordsOffset",
      ],
      [
        "ProofCallSourceResultType",
        "RewriteSemanticCallSourceOperandResultTypeOffset",
      ],
      [
        "ProofCallSourceRoutineFlags",
        "RewriteSemanticCallSourceOperandRoutineFlagsOffset",
      ],
      [
        "ProofCallSourceSourceOffset",
        "RewriteSemanticCallSourceOperandSourceOffsetOffset",
      ],
      [
        "ProofCallSourceCallMode",
        "RewriteSemanticCallSourceOperandCallModeOffset",
      ],
      [
        "ProofCallSourceHandlerLabel",
        "RewriteSemanticCallSourceOperandHandlerLabelOffset",
      ],
      [
        "ProofCallSourceRetained",
        "RewriteSemanticCallSourceOperandRetainedCarriersOffset",
      ],
      [
        "ProofBeginHandlerLocalLabel",
        "RewriteSemanticBeginHandlerLocalOperandLabelOffset",
      ],
      [
        "ProofBeginHandlerLocalInfo",
        "RewriteSemanticBeginHandlerLocalOperandSymbolInfoOffset",
      ],
      [
        "ProofBeginHandlerLocalOffset",
        "RewriteSemanticBeginHandlerLocalOperandOffsetOffset",
      ],
    ] as const;
    for (const [field, generatedOffset] of producerOffsets) {
      const operandBase = field.startsWith("ProofLiteral16")
        ? "ProofLiteral16Operands"
        : field.startsWith("ProofCallSource")
          ? "ProofCallSourceOperands"
          : "ProofBeginHandlerLocalOperands";
      expect(
        (image.symbols[field] ?? -1) - (image.symbols[operandBase] ?? -1),
        field,
      ).toBe(image.symbols[generatedOffset]);
      const recordOffset = generatedOffset.replace("Operand", "RecordOperand");
      expect(image.symbols[recordOffset], recordOffset).toBe(
        (image.symbols[generatedOffset] ?? -1) + 1,
      );
    }
  }, 15_000);

  it("decodes exact operation boundaries and rejects every corruption", () => {
    const operationId = (name: string): number => {
      const id = rewriteSemanticOperations.find(
        (operation) => operation.name === name,
      )?.id;
      if (id === undefined) throw new Error(`missing ${name}`);
      return id;
    };
    const payload = Uint8Array.of(
      operationId("ForCleanup"),
      operationId("Literal16"),
      0x34,
      0x12,
      operationId("CallSource"),
      2,
      3,
      1,
      0,
      0x78,
      0x56,
      2,
      4,
      1,
      operationId("BeginHandlerLocal"),
      4,
      5,
      6,
    );
    expect(rewriteSemanticOperationKeys(payload, 4)).toEqual([0, 1, 4, 14]);
    expect(() =>
      assertRewriteSemanticOperationKeys(payload, 4, [0, 2, 4, 14]),
    ).toThrow("expected operation boundary 1");
    expect(() => rewriteSemanticOperationKeys(payload, 3)).toThrow(
      "expected decoded end 14",
    );
    expect(() =>
      rewriteSemanticOperationKeys(payload.subarray(0, -1), 4),
    ).toThrow("extends beyond the transcript payload");
    for (const operation of [0, rewriteSemanticOperations.length + 1, 255]) {
      expect(() =>
        rewriteSemanticOperationKeys(Uint8Array.of(operation), 1),
      ).toThrow("is invalid");
    }
  });

  it("retains every active production record width and hot exact-fill cost", () => {
    const widths = new Map<string, number>(
      rewriteSemanticOperations.map(({ name, width }) => [name, width]),
    );
    const checked = new Set<string>();
    const expectWidth = (width: number, names: readonly string[]): void => {
      for (const name of names) {
        expect(widths.get(name), name).toBe(width);
        checked.add(name);
      }
    };
    expectWidth(1, [
      "Add8",
      "Subtract8",
      "Multiply8",
      "And8",
      "Or8",
      "Xor8",
      "Negate8",
      "Not8",
      "Add16",
      "Subtract16",
      "Multiply16",
      "And16",
      "Or16",
      "Xor16",
      "Negate16",
      "Not16",
      "NotBoolean",
      "BeginBooleanAnd",
      "BeginBooleanOr",
      "EndBoolean",
      "ForCleanup",
      "ReturnScalar",
      "ReturnAggregate",
      "LoadIndirect8",
      "LoadIndirect16",
      "StoreIndirect8",
      "StoreIndirect16",
      "ReturnFailableScalar",
      "ReturnFailableAggregate",
    ]);
    expectWidth(2, [
      "DeclareLocalU8",
      "LoadLocalU8",
      "StoreLocalU8",
      "DeclareLocal16",
      "LoadLocal16",
      "StoreLocal16",
      "Compare8",
      "Compare16",
      "CompareBoolean",
      "ControlLabelDirect",
      "ControlLabelEnclosing",
      "BranchFalse",
      "JumpDirect",
      "JumpEnclosing",
      "LoadParameter8",
      "LoadParameter16",
      "StoreParameter8",
      "StoreParameter16",
      "EndGeneralRoutineDirect",
      "EndGeneralRoutineEnclosing",
      "LoadParameterAlias",
      "SkipHandler",
      "EndFailableRoutineDirect",
      "EndFailableRoutineEnclosing",
      "EndHandler",
      "OpenStringCapacity",
      "OpenArrayLength",
      "PromoteI8Pair",
    ]);
    expectWidth(3, [
      "DefineProgramU8",
      "LoadProgramU8",
      "StoreProgramU8",
      "Literal16",
      "LoadProgram16",
      "Divide8",
      "Divide16",
      "Modulo8",
      "Modulo16",
      "NarrowU8",
      "StoreProgram16",
      "ForSetup",
      "LoadProgramAlias",
      "SelectField",
      "FailRoutine",
      "FailMain",
      "LoadReadOnlyAlias",
      "PrepareOpenStringDirect",
      "PrepareOpenStringForward",
      "ArrayLength",
      "BeginCallableMain",
      "LoadBssU8",
      "LoadBss16",
    ]);
    expectWidth(4, [
      "DefineProgram16",
      "ForTest",
      "BeginGeneralRoutine",
      "BindParameter",
      "BeginHandlerLocal",
      "StringLength",
      "StringIndex",
      "OpenStringLength",
      "OpenStringIndex",
      "PrepareOpenArrayDirect",
      "PrepareOpenArrayForward",
      "OpenStringResize",
      "DivideSigned",
    ]);
    expectWidth(5, ["CopyAggregate", "BeginHandlerProgram", "ConvertInteger"]);
    expectWidth(6, ["OpenArrayIndex"]);
    expectWidth(7, ["SelectIndex", "CallService"]);
    expectWidth(9, ["ForNext"]);
    expectWidth(10, ["CallSource"]);

    expect(widths.size).toBe(101);
    expect([...checked].sort()).toEqual([...widths.keys()].sort());
    expect(
      (widths.get("Literal16") ?? 0) + (widths.get("StoreProgram16") ?? 0),
    ).toBe(6);

    const sourceClass = (name: string): string | undefined =>
      rewriteSemanticOperations.find((operation) => operation.name === name)
        ?.source;
    expect(sourceClass("JumpDirect")).toBe("direct");
    expect(sourceClass("JumpEnclosing")).toBe("enclosing");
    expect(sourceClass("ControlLabelDirect")).toBe("direct");
    expect(sourceClass("ControlLabelEnclosing")).toBe("enclosing");
    expect(sourceClass("EndGeneralRoutineDirect")).toBe("direct");
    expect(sourceClass("EndGeneralRoutineEnclosing")).toBe("enclosing");
    expect(sourceClass("EndFailableRoutineDirect")).toBe("direct");
    expect(sourceClass("EndFailableRoutineEnclosing")).toBe("enclosing");
  });

  it("matches the frozen production width of every producer-active record", () => {
    const replacementWidth = (name: string): number => {
      const width = rewriteSemanticOperations.find(
        (operation) => operation.name === name,
      )?.width;
      if (width === undefined) throw new Error(`missing ${name}`);
      return width;
    };
    const cases: readonly {
      readonly name: string;
      readonly productionOperation: number;
      readonly firstOperand?: number;
      readonly secondOperand?: number;
    }[] = [
      { name: "DefineProgramU8", productionOperation: 20 },
      { name: "DeclareLocalU8", productionOperation: 22 },
      { name: "LoadProgramU8", productionOperation: 24 },
      { name: "LoadLocalU8", productionOperation: 25 },
      { name: "StoreProgramU8", productionOperation: 28 },
      { name: "StoreLocalU8", productionOperation: 29 },
      { name: "DefineProgram16", productionOperation: 32 },
      { name: "DeclareLocal16", productionOperation: 33 },
      { name: "Literal16", productionOperation: 34 },
      { name: "LoadProgram16", productionOperation: 35 },
      { name: "LoadLocal16", productionOperation: 36 },
      { name: "Add8", productionOperation: 37 },
      { name: "Add16", productionOperation: 38 },
      { name: "Subtract8", productionOperation: 39 },
      { name: "Subtract16", productionOperation: 40 },
      { name: "Multiply8", productionOperation: 41 },
      { name: "Multiply16", productionOperation: 42 },
      { name: "Divide8", productionOperation: 43 },
      { name: "Divide16", productionOperation: 44 },
      { name: "Negate8", productionOperation: 45 },
      { name: "Negate16", productionOperation: 46 },
      { name: "Not8", productionOperation: 47 },
      { name: "Not16", productionOperation: 48 },
      { name: "NotBoolean", productionOperation: 49 },
      { name: "And8", productionOperation: 50 },
      { name: "And16", productionOperation: 51 },
      { name: "Or8", productionOperation: 52 },
      { name: "Or16", productionOperation: 53 },
      { name: "Xor8", productionOperation: 54 },
      { name: "Xor16", productionOperation: 55 },
      { name: "Modulo8", productionOperation: 56 },
      { name: "Modulo16", productionOperation: 57 },
      { name: "Compare8", productionOperation: 58 },
      { name: "Compare16", productionOperation: 59 },
      { name: "CompareBoolean", productionOperation: 60 },
      { name: "NarrowU8", productionOperation: 61 },
      { name: "StoreProgram16", productionOperation: 62 },
      { name: "StoreLocal16", productionOperation: 63 },
      { name: "BeginBooleanAnd", productionOperation: 64 },
      { name: "BeginBooleanOr", productionOperation: 65 },
      { name: "EndBoolean", productionOperation: 66 },
      { name: "ControlLabelDirect", productionOperation: 67 },
      { name: "ControlLabelEnclosing", productionOperation: 67 },
      { name: "BranchFalse", productionOperation: 68 },
      { name: "JumpDirect", productionOperation: 69 },
      { name: "JumpEnclosing", productionOperation: 69 },
      { name: "ForSetup", productionOperation: 70 },
      { name: "ForTest", productionOperation: 71 },
      { name: "ForNext", productionOperation: 72 },
      { name: "ForCleanup", productionOperation: 73 },
      { name: "LoadParameter8", productionOperation: 75 },
      { name: "LoadParameter16", productionOperation: 76 },
      { name: "ReturnScalar", productionOperation: 78 },
      { name: "StoreParameter8", productionOperation: 79 },
      { name: "StoreParameter16", productionOperation: 80 },
      { name: "BeginGeneralRoutine", productionOperation: 82 },
      { name: "BindParameter", productionOperation: 83 },
      { name: "CallSource", productionOperation: 84 },
      {
        name: "CallService",
        productionOperation: 84,
        firstOperand: 0x80,
      },
      { name: "ReturnAggregate", productionOperation: 85 },
      { name: "EndGeneralRoutineDirect", productionOperation: 86 },
      { name: "EndGeneralRoutineEnclosing", productionOperation: 86 },
      { name: "LoadProgramAlias", productionOperation: 87 },
      { name: "LoadParameterAlias", productionOperation: 88 },
      { name: "SelectField", productionOperation: 89 },
      { name: "SelectIndex", productionOperation: 90 },
      { name: "LoadIndirect8", productionOperation: 91 },
      { name: "LoadIndirect16", productionOperation: 92 },
      { name: "StoreIndirect8", productionOperation: 93 },
      { name: "StoreIndirect16", productionOperation: 94 },
      { name: "CopyAggregate", productionOperation: 95 },
      { name: "StringLength", productionOperation: 96 },
      { name: "StringIndex", productionOperation: 97 },
      { name: "FailRoutine", productionOperation: 98 },
      { name: "FailMain", productionOperation: 99 },
      { name: "ReturnFailableScalar", productionOperation: 100 },
      { name: "ReturnFailableAggregate", productionOperation: 101 },
      { name: "EndFailableRoutineDirect", productionOperation: 102 },
      { name: "EndFailableRoutineEnclosing", productionOperation: 102 },
      { name: "SkipHandler", productionOperation: 103 },
      {
        name: "BeginHandlerProgram",
        productionOperation: 104,
        secondOperand: 4,
      },
      { name: "BeginHandlerLocal", productionOperation: 104 },
      { name: "EndHandler", productionOperation: 105 },
      { name: "BeginCallableMain", productionOperation: 106 },
      { name: "LoadReadOnlyAlias", productionOperation: 107 },
      { name: "OpenStringLength", productionOperation: 108 },
      { name: "OpenStringIndex", productionOperation: 109 },
      {
        name: "PrepareOpenStringDirect",
        productionOperation: 110,
        firstOperand: 0,
      },
      {
        name: "PrepareOpenStringForward",
        productionOperation: 110,
        firstOperand: 1,
      },
      {
        name: "PrepareOpenArrayDirect",
        productionOperation: 110,
        firstOperand: 2,
      },
      {
        name: "PrepareOpenArrayForward",
        productionOperation: 110,
        firstOperand: 3,
      },
      { name: "OpenStringCapacity", productionOperation: 111 },
      { name: "OpenStringResize", productionOperation: 112 },
      { name: "ArrayLength", productionOperation: 113 },
      { name: "OpenArrayLength", productionOperation: 114 },
      { name: "OpenArrayIndex", productionOperation: 115 },
      { name: "ConvertInteger", productionOperation: 116 },
      { name: "DivideSigned", productionOperation: 117 },
      { name: "PromoteI8Pair", productionOperation: 118 },
    ];
    const freshStorageOperations = new Set(["LoadBssU8", "LoadBss16"]);
    const frozenOperations = rewriteSemanticOperations.filter(
      ({ name }) => !freshStorageOperations.has(name),
    );
    expect(cases).toHaveLength(frozenOperations.length);
    expect(cases.map(({ name }) => name).sort()).toEqual(
      frozenOperations.map(({ name }) => name).sort(),
    );
    for (const {
      name,
      productionOperation,
      firstOperand,
      secondOperand,
    } of cases) {
      const payload = new Uint8Array(replacementWidth(name));
      payload[0] = productionOperation;
      if (firstOperand !== undefined) payload[1] = firstOperand;
      if (secondOperand !== undefined) payload[2] = secondOperand;
      expect(nucleusSemanticOperationKeys(payload, 1), name).toEqual([0]);
    }
  });

  it("validates before dispatch and emits exact semantic trace events", async () => {
    const image = await assembleProof();
    const result = runEntry(image, "ProofSemanticStart", true);
    expect(result.memory[image.symbols.ProofStatus ?? -1]).toBe(0xa5);
    expect(result.memory[image.symbols.RewriteSemanticBufferBase ?? -1]).toBe(
      4,
    );
    expect(result.keys).toEqual([0, 1, 4, 14]);
    expect(result.ports.map((port) => port & 0xff)).toEqual([
      0xdd, 0xdd, 0xdd, 0xdd, 0xde,
    ]);
    expect({
      instructions: result.instructions,
      cycles: result.cycles,
    }).toEqual({ instructions: 488, cycles: 6_964 });
  });

  it("distinguishes exact fill, first overflow, and clean recovery", async () => {
    const image = await assembleProof();
    const result = runEntry(image, "ProofSemanticCapacity");
    expect(result.memory[image.symbols.ProofStatus ?? -1]).toBe(0xa6);
    expect(result.memory[image.symbols.ProofExactFillCount ?? -1]).toBe(128);
    expect(result.memory[image.symbols.DiagnosticCode ?? -1]).toBe(0);
    expect(result.memory[image.symbols.RewriteSemanticBufferBase ?? -1]).toBe(
      1,
    );
    expect({
      instructions: result.instructions,
      cycles: result.cycles,
    }).toEqual({ instructions: 10_874, cycles: 113_305 });
  });

  it("rejects a multi-byte record atomically when only three bytes remain", async () => {
    const image = await assembleProof();
    const result = runEntry(image, "ProofSemanticAtomicOverflow");
    expect(result.memory[image.symbols.ProofStatus ?? -1]).toBe(0xa8);
    expect(result.memory[image.symbols.RewriteSemanticBufferBase ?? -1]).toBe(
      127,
    );
  });

  it("distinguishes operation-count 255 from the first rejected count", async () => {
    const image = await assembleProof();
    const result = runEntry(image, "ProofSemanticCountCapacity");
    expect(result.memory[image.symbols.ProofStatus ?? -1]).toBe(0xa9);
    expect(result.memory[image.symbols.RewriteSemanticBufferBase ?? -1]).toBe(
      255,
    );
  });

  it.each([
    "ProofSemanticInvalidOrdinal",
    "ProofSemanticTruncated",
    "ProofSemanticTrailing",
  ])("rejects corrupted transcript boundary %s", async (entry) => {
    const image = await assembleProof();
    const result = runEntry(image, entry);
    expect(result.memory[image.symbols.ProofStatus ?? -1]).toBe(0xa7);
    expect(result.memory[image.symbols.DiagnosticCode ?? -1]).toBe(67);
    expect(result.ports).toEqual([]);
  });
});
