import { createZ80Runtime, parseIntelHex } from "@jhlagado/debug80-runtime";
import { describe, expect, it } from "vitest";
import { assembleAtomSource } from "../scripts/atom-source.mjs";

interface RelocatedImage {
  readonly origin: number;
  readonly memory: Uint8Array;
  readonly addresses: ReadonlyMap<string, number>;
  readonly values: ReadonlyMap<string, number>;
  readonly physicalEnd: number;
  readonly writeRanges: readonly { start: number; end: number }[];
}

const assembleAt = async (origin: number): Promise<RelocatedImage> => {
  const entry = "vertical-slice/native-target-compiler.asm";
  const result = await assembleAtomSource(entry, {
    target: { start: origin, capacity: Math.min(0xffff, 0x10000 - origin) },
    overrides: new Map([
      [
        entry,
        [
          "DebugHooks .equ 0",
          "NativeStreamingSource .equ 0",
          '.include "target-memory-map.asmi"',
          '.include "nucleus-runtime-identity.asmi"',
          "TargetSinkImageByte .equ $5F00",
          "TargetSinkBegin .equ $5F00",
          "TargetSinkPatchByte .equ $5F00",
          "TargetSinkRuntimeImage .equ $5F00",
          "TargetSinkRuntimeInitialImage .equ $5F00",
          "TargetSinkPatchWord .equ $5F00",
          "TargetSinkMapFlat .equ $5F00",
          "TargetSinkCommit .equ $5F00",
          "TargetSinkMapBanked .equ $5F00",
          "TargetSinkAbort .equ $5F00",
          `.org $${origin.toString(16)}`,
          '.include "flat-target-compiler-image.asmi"',
          "",
        ].join("\n"),
      ],
    ]),
  });
  const program = parseIntelHex(result.hex);
  if (program.writeRanges === undefined)
    throw new Error("Relocation image has no initialized-address map");
  return {
    origin,
    memory: program.memory,
    addresses: new Map(Object.entries(result.addresses)),
    values: new Map(Object.entries(result.symbols)),
    physicalEnd: result.generation.highWater,
    writeRanges: program.writeRanges,
  };
};

const wordAt = (memory: Uint8Array, address: number): number =>
  (memory[address] ?? 0) | ((memory[address + 1] ?? 0) << 8);

const executeDiagnosticAt = (image: RelocatedImage): void => {
  const entry = image.addresses.get("CompileTargetAggregateCallParts");
  const diagnostic = image.values.get("DiagnosticCode");
  expect(entry).toBeDefined();
  expect(diagnostic).toBeDefined();
  if (entry === undefined || diagnostic === undefined) return;

  const memory = image.memory.slice();
  const trampoline = 0x5e00;
  const result = 0x5d10;
  const parts = 0x7100;
  const source = 0x7200;
  const descriptor = 0x7300;
  const sourceBytes = new TextEncoder().encode(
    "var value as u8 = -1\nsub main()\nend\n",
  );
  const sourceEnd = source + sourceBytes.length;
  memory[0x5f00] = 0xc9; // RET for every unused target-sink callback.
  memory.set(
    [1, source & 0xff, source >>> 8, sourceEnd & 0xff, sourceEnd >>> 8],
    parts,
  );
  memory.set(sourceBytes, source);
  memory.set(
    [
      0x31,
      0x00,
      0x5d, // LD SP,$5D00
      0x3e,
      0x01, // LD A,1
      0x21,
      parts & 0xff,
      parts >>> 8, // LD HL,parts
      0xdd,
      0x21,
      descriptor & 0xff,
      descriptor >>> 8, // LD IX,descriptor
      0xcd,
      entry & 0xff,
      entry >>> 8, // CALL relocated compiler
      0x3e,
      0x00, // LD A,0 (preserves returned carry)
      0xce,
      0x00, // ADC A,0
      0x32,
      result & 0xff,
      result >>> 8, // LD (result),A
      0x76, // HALT
    ],
    trampoline,
  );
  const runtime = createZ80Runtime(
    { memory, startAddress: trampoline },
    trampoline,
  );
  const runtimeMemory = (runtime.hardware as unknown as { memory: Uint8Array })
    .memory;
  let instructions = 0;
  while (!runtime.isHalted() && instructions < 200_000) {
    runtime.step();
    instructions += 1;
  }
  expect(runtime.isHalted(), `execution at $${image.origin.toString(16)}`).toBe(
    true,
  );
  expect(
    runtimeMemory[result],
    `origin $${image.origin.toString(16)}, PC $${runtime
      .getPC()
      .toString(16)}, diagnostic ${runtimeMemory[diagnostic]}`,
  ).toBe(1);
  expect(runtimeMemory[diagnostic]).toBe(95);
  expect(runtime.cpu.sp).toBe(0x5d00);
};

const executePrefetchSelectorsAt = (
  image: RelocatedImage,
  prefetchedOperations: readonly number[],
): void => {
  const entry = image.addresses.get("TypedPrefetchFirstOperand");
  const cursor = image.values.get("SemanticReadCursor");
  const operationBase = image.values.get("SemanticDefineProgramU8");
  const operationCount = image.values.get("TypedOperationCount");
  expect(entry).toBeDefined();
  expect(cursor).toBeDefined();
  expect(operationBase).toBeDefined();
  expect(operationCount).toBe(104);
  if (
    entry === undefined ||
    cursor === undefined ||
    operationBase === undefined ||
    operationCount === undefined
  ) {
    return;
  }

  const prefetched = new Set(prefetchedOperations);
  const returnAddress = 0x5d00;
  const stackPointer = 0x5cfe;
  const operandAddress = 0x5d10;
  const operand = 0xa5;
  for (let index = 0; index < operationCount; index += 1) {
    const memory = image.memory.slice();
    memory[returnAddress] = 0x76; // HALT after the helper's RET.
    memory[stackPointer] = returnAddress & 0xff;
    memory[stackPointer + 1] = returnAddress >>> 8;
    memory[operandAddress] = operand;
    memory[cursor] = operandAddress & 0xff;
    memory[cursor + 1] = operandAddress >>> 8;
    const runtime = createZ80Runtime({ memory, startAddress: entry }, entry);
    runtime.cpu.sp = stackPointer;
    runtime.cpu.a = index;
    runtime.cpu.c = 0xff;
    runtime.cpu.flags.C = 1;
    let instructions = 0;
    while (!runtime.isHalted() && instructions < 100) {
      runtime.step();
      instructions += 1;
    }
    const runtimeMemory = (
      runtime.hardware as unknown as { memory: Uint8Array }
    ).memory;
    const operation = operationBase + index;
    const shouldPrefetch = prefetched.has(operation);
    expect(runtime.isHalted(), `prefetch selector ${index}`).toBe(true);
    expect(runtime.cpu.c, `prefetch selector ${index} index`).toBe(index);
    expect(runtime.cpu.flags.C, `prefetch selector ${index} carry`).toBe(0);
    expect(
      wordAt(runtimeMemory, cursor),
      `prefetch selector ${index} cursor`,
    ).toBe(operandAddress + (shouldPrefetch ? 1 : 0));
    if (shouldPrefetch) {
      expect(runtime.cpu.a, `prefetch selector ${index} operand`).toBe(operand);
    }
  }
};

describe("compiler origin independence", () => {
  it("relocates full-width code addresses at CP/M, high, and top-fitting origins", async () => {
    const baseline = await assembleAt(0x0000);
    expect(baseline).toBeDefined();

    const baselineStart = baseline.addresses.get("CompilerCodeStart");
    const baselineEnd = baseline.addresses.get("CompilerCoreEnd");
    expect(baselineStart).toBe(0);
    expect(baselineEnd).toBeGreaterThan(baselineStart ?? 0);
    if (baselineStart === undefined || baselineEnd === undefined) {
      return;
    }

    const coreBytes = baselineEnd - baselineStart;
    const topFittingOrigin = 0x10000 - coreBytes;
    const images = [
      baseline,
      ...(await Promise.all(
        [0x0100, 0x8000, topFittingOrigin].map(assembleAt),
      )),
    ];
    const prefetchAddress = baseline.addresses.get("TypedPrefetchBits");
    const prefetchedOperations = [
      20, 22, 32, 33, 34, 58, 59, 60, 67, 68, 69, 70, 71, 72, 74, 77, 82, 83,
      84, 86, 102, 103, 104, 105, 106, 110, 116, 117, 118, 122, 123,
    ];
    const prefetchBytes = new Array<number>(13).fill(0);
    for (const operation of prefetchedOperations) {
      const index = operation - 20;
      prefetchBytes[index >> 3] |= 1 << (index & 7);
    }
    expect(prefetchAddress).toBeDefined();
    if (prefetchAddress !== undefined) {
      expect(
        Array.from(
          baseline.memory.slice(
            prefetchAddress,
            prefetchAddress + prefetchBytes.length,
          ),
        ),
      ).toEqual(prefetchBytes);
    }
    const addressTables = [
      {
        name: "semantic operation",
        table: "TypedOperationTable",
        count: "TypedOperationCount",
      },
      {
        name: "LL(1) action",
        table: "HybridLL1ActionDirectory",
        count: "HybridLL1ActionCount",
      },
    ] as const;
    for (const relocated of images.slice(1)) {
      const delta = relocated.origin - baseline.origin;
      expect(relocated.addresses.get("CompilerCodeStart")).toBe(
        relocated.origin,
      );
      expect(relocated.addresses.get("CompilerCoreEnd")).toBe(
        (relocated.origin + coreBytes) & 0xffff,
      );
      expect(relocated.physicalEnd).toBe(relocated.origin + coreBytes);
      // Intel HEX decoding preserves individual record ranges. Prove exact
      // contiguous coverage without requiring the decoder to merge records.
      let initializedEnd = relocated.origin;
      for (const range of relocated.writeRanges) {
        expect(range.start).toBe(initializedEnd);
        expect(range.end).toBeGreaterThan(range.start);
        initializedEnd = range.end;
      }
      expect(initializedEnd).toBe(relocated.origin + coreBytes);
      expect(relocated.origin + coreBytes).toBeLessThanOrEqual(0x10000);
      if (prefetchAddress !== undefined) {
        const relocatedPrefetch = relocated.addresses.get("TypedPrefetchBits");
        expect(relocatedPrefetch).toBe(prefetchAddress + delta);
        if (relocatedPrefetch !== undefined) {
          expect(
            Array.from(
              relocated.memory.slice(
                relocatedPrefetch,
                relocatedPrefetch + prefetchBytes.length,
              ),
            ),
          ).toEqual(prefetchBytes);
        }
      }

      for (const [name, address] of baseline.addresses) {
        if (address >= baselineStart && address < baselineEnd) {
          expect(
            relocated.addresses.get(name),
            `${name} at $${relocated.origin.toString(16)}`,
          ).toBe(address + delta);
        }
      }

      for (const descriptor of addressTables) {
        const baselineTable = baseline.addresses.get(descriptor.table);
        const relocatedTable = relocated.addresses.get(descriptor.table);
        const count = baseline.values.get(descriptor.count);
        expect(baselineTable).toBeDefined();
        expect(relocatedTable).toBe(
          baselineTable === undefined ? undefined : baselineTable + delta,
        );
        expect(count).toBeGreaterThan(0);
        if (
          baselineTable === undefined ||
          relocatedTable === undefined ||
          count === undefined
        ) {
          continue;
        }
        for (let index = 0; index < count; index += 1) {
          const baselineHandler = wordAt(
            baseline.memory,
            baselineTable + index * 2,
          );
          const relocatedHandler = wordAt(
            relocated.memory,
            relocatedTable + index * 2,
          );
          expect(
            relocatedHandler,
            `${descriptor.name} ${index} at $${relocated.origin.toString(16)}`,
          ).toBe(baselineHandler + delta);
          expect(relocatedHandler).toBeGreaterThanOrEqual(relocated.origin);
          expect(relocatedHandler).toBeLessThan(relocated.origin + coreBytes);
        }
      }
    }
    for (const image of images) {
      executePrefetchSelectorsAt(image, prefetchedOperations);
      executeDiagnosticAt(image);
    }
  }, 300_000);
});
