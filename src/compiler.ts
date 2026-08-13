import path from "node:path";
import { fileURLToPath } from "node:url";

import { compile } from "@jhlagado/azm/compile";
import { createZ80Runtime, parseIntelHex } from "@jhlagado/debug80-runtime";

import {
  materializeNobj,
  parseNobj,
  type MaterializedNobj,
  type NobjBegin,
  type NobjMap,
  type RuntimeLinkContext,
  type RuntimeServiceAddresses,
} from "./nobj.js";
import { commitNobjAdapterGeneration } from "./proof.js";

const SOURCE_BASE = 0x5000;
const SOURCE_LIMIT = 0x5800;
const TARGET_DESCRIPTOR = 0x9e00;
const PART_BANKS = TARGET_DESCRIPTOR + 0x10;
const RETURN_SENTINEL = 0x9fff;
const STACK_TOP = 0xff00;
const RUNTIME_IDENTITY = 4;
const TARGET_DESCRIPTOR_SIZE = 15;
const TARGET_MAP_SIZE = 0x28;
const MAX_SOURCE_PARTS = 8;
const DEFAULT_INSTRUCTION_LIMIT = 5_000_000;
const DEFAULT_CYCLE_LIMIT = 50_000_000;

export const defaultNucleusServices: RuntimeServiceAddresses = {
  readInputByte: 0x7000,
  writeOutputByte: 0x7003,
  readStorageByte: 0x7006,
  rewindStorageInput: 0x7009,
  writeStorageByte: 0x700c,
  seekStorageOutput: 0x700f,
  success: 0x7012,
  unhandledFailure: 0x7015,
  trap: 0x7018,
  farCall: 0x701b,
  farJump: 0x701e,
};

export interface NucleusSourcePart {
  readonly name: string;
  readonly source: string | Uint8Array;
}

export interface NucleusFlatTarget {
  readonly imageBase?: number;
  readonly imageCapacity?: number;
  readonly writableBase?: number;
  readonly writableCapacity?: number;
  readonly establishStack?: boolean;
  readonly services?: RuntimeServiceAddresses;
}

export interface NucleusDiagnostic {
  readonly code: number;
  readonly sourcePart: number;
  readonly sourceName?: string;
  readonly offset: number;
  readonly line: number;
  readonly column: number;
}

interface CompileMetrics {
  readonly instructions: number;
  readonly cycles: number;
}

export interface NucleusCompileSuccess extends CompileMetrics {
  readonly success: true;
  readonly nobj: Uint8Array;
  readonly materialized: MaterializedNobj;
}

export interface NucleusCompileFailure extends CompileMetrics {
  readonly success: false;
  readonly diagnostic: NucleusDiagnostic;
}

export type NucleusCompileResult =
  NucleusCompileSuccess | NucleusCompileFailure;

interface CompilerImage {
  readonly program: ReturnType<typeof parseIntelHex>;
  readonly symbols: Readonly<Record<string, number>>;
}

let compilerImage: Promise<CompilerImage> | undefined;

const compilerSourceDirectory = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../asm/vertical-slice",
);

const symbol = (
  symbols: Readonly<Record<string, number>>,
  name: string,
): number => {
  const wanted = name.toLowerCase();
  for (const [candidate, value] of Object.entries(symbols)) {
    if (candidate.toLowerCase() === wanted) return value;
  }
  throw new Error(`Nucleus compiler image is missing symbol ${name}`);
};

const loadCompilerImage = async (): Promise<CompilerImage> => {
  compilerImage ??= (async () => {
    const source = path.join(
      compilerSourceDirectory,
      "flat-target-z80-slice-proof.asm",
    );
    const assembled = await compile(source, {
      emitBin: false,
      emitHex: true,
      emitD8m: true,
      registerContracts: "strict",
      registerContractsInterfaces: [
        path.join(compilerSourceDirectory, "expression-generated-z80.asmi"),
      ],
    });
    const errors = assembled.diagnostics.filter(
      ({ severity }) => severity === "error",
    );
    if (errors.length > 0) {
      throw new Error(
        `Nucleus compiler assembly failed\n${errors
          .map(
            ({ sourceName, line, column, message }) =>
              `${sourceName ?? source}:${line ?? "?"}:${column ?? "?"} ${message}`,
          )
          .join("\n")}`,
      );
    }
    const hex = assembled.artifacts.find((artifact) => artifact.kind === "hex");
    const debugMap = assembled.artifacts.find(
      (artifact) => artifact.kind === "d8m",
    );
    if (hex?.kind !== "hex" || debugMap?.kind !== "d8m") {
      throw new Error("AZM omitted the Nucleus compiler HEX or symbol map");
    }
    const symbols = Object.fromEntries(
      debugMap.json.symbols.flatMap((entry) => {
        const value = entry.address ?? entry.value;
        return value === undefined ? [] : [[entry.name, value] as const];
      }),
    );
    return { program: parseIntelHex(hex.text), symbols };
  })();
  return compilerImage;
};

const requireWord = (name: string, value: number): void => {
  if (!Number.isInteger(value) || value < 0 || value > 0xffff) {
    throw new RangeError(`${name} is outside 0..65535`);
  }
};

const writeWord = (
  memory: Uint8Array,
  address: number,
  value: number,
): void => {
  requireWord("word", value);
  memory[address] = value & 0xff;
  memory[address + 1] = value >>> 8;
};

const readWord = (memory: Uint8Array, address: number): number =>
  (memory[address] ?? 0) | ((memory[address + 1] ?? 0) << 8);

const prepareSource = (
  memory: Uint8Array,
  parts: readonly NucleusSourcePart[],
): number[] => {
  if (parts.length < 1 || parts.length > MAX_SOURCE_PARTS) {
    throw new RangeError(
      `Nucleus source requires 1..${MAX_SOURCE_PARTS} parts`,
    );
  }
  const encoded = parts.map(({ source }) =>
    typeof source === "string" ? new TextEncoder().encode(source) : source,
  );
  let sourceCursor = SOURCE_BASE + parts.length * 5;
  for (let index = 0; index < encoded.length; index += 1) {
    const bytes = encoded[index] ?? new Uint8Array();
    const descriptor = SOURCE_BASE + index * 5;
    const end = sourceCursor + bytes.length;
    if (end > SOURCE_LIMIT) {
      throw new RangeError(
        "Nucleus source parts exceed the 2 KiB host source window",
      );
    }
    memory[descriptor] = index + 1;
    writeWord(memory, descriptor + 1, sourceCursor);
    writeWord(memory, descriptor + 3, end);
    memory.set(bytes, sourceCursor);
    sourceCursor = end;
  }
  return encoded.map(() => 0);
};

const prepareTarget = (
  memory: Uint8Array,
  partBanks: readonly number[],
  target: NucleusFlatTarget,
): NobjBegin => {
  const imageBase = target.imageBase ?? 0x8000;
  const imageCapacity = target.imageCapacity ?? 0x1000;
  const writableBase = target.writableBase ?? 0x4000;
  const writableCapacity = target.writableCapacity ?? 0x1000;
  for (const [name, value] of [
    ["image base", imageBase],
    ["image capacity", imageCapacity],
    ["writable base", writableBase],
    ["writable capacity", writableCapacity],
  ] as const) {
    requireWord(name, value);
  }
  memory.fill(0, TARGET_DESCRIPTOR, TARGET_DESCRIPTOR + TARGET_DESCRIPTOR_SIZE);
  writeWord(memory, TARGET_DESCRIPTOR, RUNTIME_IDENTITY);
  writeWord(memory, TARGET_DESCRIPTOR + 2, imageBase);
  writeWord(memory, TARGET_DESCRIPTOR + 4, imageCapacity);
  writeWord(memory, TARGET_DESCRIPTOR + 6, writableBase);
  writeWord(memory, TARGET_DESCRIPTOR + 8, writableCapacity);
  memory[TARGET_DESCRIPTOR + 10] = target.establishStack === false ? 0 : 1;
  memory[TARGET_DESCRIPTOR + 11] = 1;
  memory[TARGET_DESCRIPTOR + 12] = 0;
  writeWord(memory, TARGET_DESCRIPTOR + 13, PART_BANKS);
  memory.set(partBanks, PART_BANKS);
  return {
    banked: false,
    runtimeIdentity: RUNTIME_IDENTITY,
    bankCount: 1,
    imageFill: 0xff,
    imageBase,
    imageCapacity,
  };
};

const capturedMap = (
  memory: Uint8Array,
  base: number,
  establishStack: boolean,
  partBanks: readonly number[],
): NobjMap => ({
  romMode: true,
  establishedStack: establishStack,
  entryBank: memory[base] ?? 0,
  entryAddress: readWord(memory, base + 1),
  writableBase: readWord(memory, base + 13),
  writableCapacity: readWord(memory, base + 15),
  vectorBase: readWord(memory, base + 17),
  vectorLength: readWord(memory, base + 19),
  initializedRunBase: readWord(memory, base + 21),
  initializedRunLength: readWord(memory, base + 23),
  bssBase: readWord(memory, base + 25),
  bssLength: readWord(memory, base + 27),
  stackRequirement: readWord(memory, base + 29),
  dataLoadBank: memory[base + 31] ?? 0,
  dataLoadAddress: readWord(memory, base + 32),
  dataLoadLength: readWord(memory, base + 34),
  partBanks,
  banks: [
    {
      usedLength: readWord(memory, base + 3),
      readOnlyBase: readWord(memory, base + 5),
      readOnlyLength: readWord(memory, base + 7),
      aggregateConstantBase: readWord(memory, base + 36),
      aggregateConstantLength: readWord(memory, base + 38),
    },
  ],
});

const capturedContext = (
  memory: Uint8Array,
  base: number,
  services: RuntimeServiceAddresses,
): RuntimeLinkContext => ({
  runtimeBase: readWord(memory, base),
  writableBase: readWord(memory, base + 2),
  writableCapacity: readWord(memory, base + 4),
  writableStateBase: readWord(memory, base + 6),
  vectorBase: readWord(memory, base + 8),
  programDataBase: readWord(memory, base + 10),
  programDataCapacity: readWord(memory, base + 12),
  readOnlyBase: readWord(memory, base + 14),
  readOnlyCapacity: readWord(memory, base + 16),
  services,
});

export const compileNucleus = async (
  parts: readonly NucleusSourcePart[],
  target: NucleusFlatTarget = {},
): Promise<NucleusCompileResult> => {
  const image = await loadCompilerImage();
  const runtime = createZ80Runtime(
    { ...image.program, memory: image.program.memory.slice() },
    symbol(image.symbols, "CompileTargetAggregateCallParts"),
  );
  const memory = runtime.hardware.memory;
  const partBanks = prepareSource(memory, parts);
  const begin = prepareTarget(memory, partBanks, target);
  const adapterBase = symbol(image.symbols, "AdapterLogBase");
  writeWord(memory, symbol(image.symbols, "AdapterCursor"), adapterBase);
  for (const name of [
    "AdapterOpen",
    "AdapterCommitted",
    "AdapterAborted",
    "AdapterFailureCountdown",
    "AdapterMapFailure",
    "AdapterCommitFailure",
  ]) {
    memory[symbol(image.symbols, name)] = 0;
  }
  memory[RETURN_SENTINEL] = 0x76;
  writeWord(memory, STACK_TOP, RETURN_SENTINEL);
  runtime.cpu.sp = STACK_TOP;
  runtime.cpu.pc = symbol(image.symbols, "CompileTargetAggregateCallParts");
  runtime.cpu.a = parts.length;
  runtime.cpu.h = SOURCE_BASE >>> 8;
  runtime.cpu.l = SOURCE_BASE & 0xff;
  runtime.cpu.ix = TARGET_DESCRIPTOR;
  runtime.cpu.halted = false;

  let instructions = 0;
  let cycles = 0;
  while (!runtime.isHalted()) {
    if (
      instructions >= DEFAULT_INSTRUCTION_LIMIT ||
      cycles >= DEFAULT_CYCLE_LIMIT
    ) {
      throw new Error("Nucleus compiler exceeded its host execution limit");
    }
    const step = runtime.step();
    instructions += 1;
    cycles += step.cycles ?? 0;
  }

  if (runtime.cpu.flags.C !== 0) {
    const part = memory[symbol(image.symbols, "DiagnosticPartId")] ?? 0;
    return {
      success: false,
      diagnostic: {
        code: memory[symbol(image.symbols, "DiagnosticCode")] ?? 0,
        sourcePart: part,
        sourceName: parts[part - 1]?.name,
        offset: readWord(memory, symbol(image.symbols, "DiagnosticOffset")),
        line: readWord(memory, symbol(image.symbols, "DiagnosticLine")),
        column: readWord(memory, symbol(image.symbols, "DiagnosticColumn")),
      },
      instructions,
      cycles,
    };
  }
  if ((memory[symbol(image.symbols, "AdapterCommitted")] ?? 0) !== 1) {
    throw new Error(
      "Nucleus compiler returned success without committing output",
    );
  }
  const cursor = readWord(memory, symbol(image.symbols, "AdapterCursor"));
  const map = capturedMap(
    memory,
    symbol(image.symbols, "AdapterCapturedMap"),
    target.establishStack !== false,
    partBanks,
  );
  const runtimeLinkContext = capturedContext(
    memory,
    symbol(image.symbols, "AdapterCapturedContext"),
    target.services ?? defaultNucleusServices,
  );
  const nobj = await commitNobjAdapterGeneration({
    name: "nucleus-host-compile",
    producerMemory: memory,
    start: adapterBase,
    length: cursor - adapterBase,
    maxBytes: symbol(image.symbols, "AdapterLogLimit") - adapterBase,
    begin,
    map,
    runtimeLinkContext,
  });
  return {
    success: true,
    nobj,
    materialized: materializeNobj(parseNobj(nobj)),
    instructions,
    cycles,
  };
};
