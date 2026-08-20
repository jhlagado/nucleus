import { createHash } from "node:crypto";

import { createZ80Runtime, parseIntelHex } from "@jhlagado/debug80-runtime";

import {
  debugCompilerHex,
  debugCompilerSymbols,
  nativeCompilerHex,
  nativeCompilerSymbols,
  nativeDebugCompilerHex,
  nativeDebugCompilerSymbols,
  normalCompilerHex,
  normalCompilerSymbols,
} from "./generated-compiler-images.js";

import {
  materializeNobj,
  MemoryNobjSpool,
  NobjGenerationSink,
  NobjGenerationStore,
  parseNobj,
  type MaterializedNobj,
  type NobjBegin,
  type NobjCommitMetadata,
  type NobjMap,
  type NobjSequentialOutput,
  type NobjSpoolFactory,
  type RuntimeLinkContext,
  type RuntimeServiceAddresses,
} from "./nobj.js";
import { loadCanonicalRuntimeProvider } from "./nucleus-runtime.js";
import {
  commitNobjAdapterGeneration,
  commitNobjAdapterGenerationTo,
  type NobjAdapterImageByte,
} from "./proof.js";
import {
  isNucleusDebugPort,
  NucleusDebugCollector,
  sourcePartBytes,
  type NucleusDebugMapping,
  type NucleusDebugTraceSymbols,
  type NucleusLoadedSourcePart,
} from "./d8.js";
import {
  NativeRetainedNameStore,
  nativeRetainedNameByteCapacity,
  nativeRetainedNameEntryCapacity,
} from "./native-retained-names.js";

const SOURCE_BASE = normalCompilerSymbols.SourceBase ?? 0x5000;
const SOURCE_LIMIT = normalCompilerSymbols.SourceLimit ?? 0x5800;
const TARGET_DESCRIPTOR = 0x9e00;
const PART_BANKS = TARGET_DESCRIPTOR + 0x10;
const NATIVE_LAUNCH_DESCRIPTOR = TARGET_DESCRIPTOR + 0x20;
const NATIVE_LAUNCH_RESULT = TARGET_DESCRIPTOR + 0x30;
const RETURN_SENTINEL = 0x9fff;
const STACK_TOP = 0xff00;
const RUNTIME_IDENTITY = 9;
const TARGET_DESCRIPTOR_SIZE = 15;
const TARGET_MAP_SIZE = 0x28;
const MAX_SOURCE_PARTS = 8;
const DEFAULT_INSTRUCTION_LIMIT = 10_000_000;
const DEFAULT_CYCLE_LIMIT = 100_000_000;

export const nucleusCompilerCapacities = {
  sourceParts: MAX_SOURCE_PARTS,
  sourcePartBytes: 0xffff,
  /** Compatibility resident-source adapter only; native compilation streams. */
  compatibilitySourceWindowBytes: SOURCE_LIMIT - SOURCE_BASE,
  nativeSourceChunkBytes:
    (nativeCompilerSymbols.NativeSourceChunkLimit ?? 0x7800) -
    (nativeCompilerSymbols.NativeSourceChunkBase ?? 0x7500),
  nativeTokenCacheBytes:
    (nativeCompilerSymbols.NativeSourceTokenLimit ?? 0x7500) -
    (nativeCompilerSymbols.NativeSourceTokenBase ?? 0x7000),
  nativeRetainedNameEntries: nativeRetainedNameEntryCapacity,
  nativeRetainedNameBytes: nativeRetainedNameByteCapacity,
  sourceDescriptorBytesPerPart: 5,
  targetBanks: 4,
  instructionLimit: DEFAULT_INSTRUCTION_LIMIT,
  cycleLimit: DEFAULT_CYCLE_LIMIT,
} as const;

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
  packetService: 0x7021,
};

export interface NucleusSourcePart {
  readonly name: string;
  readonly source: string | Uint8Array;
}

export interface NucleusFlatTarget {
  readonly imageBase?: number;
  readonly imageCapacity?: number;
  readonly imageFill?: number;
  readonly writableBase?: number;
  readonly writableCapacity?: number;
  readonly establishStack?: boolean;
  readonly services?: RuntimeServiceAddresses;
}

export interface NucleusBankedTarget extends NucleusFlatTarget {
  readonly bankCount: number;
  readonly entryBank: number;
  readonly partBanks: readonly number[];
}

export type NucleusTarget = NucleusFlatTarget | NucleusBankedTarget;

export interface NucleusCompileOptions {
  readonly debugMap?: boolean;
  readonly compilerIoWrite?: (port: number, value: number) => void;
}

export interface NucleusStreamingCompileOptions {
  readonly debugMap?: boolean;
  readonly compilerIoWrite?: (port: number, value: number) => void;
  readonly spoolFactory?: NobjSpoolFactory;
  readonly lowMemoryPatchValidation?: boolean;
  readonly signal?: AbortSignal;
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
  readonly debugMapping?: NucleusDebugMapping;
}

export interface NucleusCompileFailure extends CompileMetrics {
  readonly success: false;
  readonly diagnostic: NucleusDiagnostic;
}

export type NucleusCompileResult =
  NucleusCompileSuccess | NucleusCompileFailure;

export interface NucleusStreamingCompileSuccess extends CompileMetrics {
  readonly success: true;
  readonly object: NobjCommitMetadata;
  readonly debugMapping?: NucleusDebugMapping;
}

export type NucleusStreamingCompileResult =
  NucleusStreamingCompileSuccess | NucleusCompileFailure;

const hexByte = (value: number): string =>
  (value & 0xff).toString(16).toUpperCase().padStart(2, "0");

const intelHexRecord = (
  address: number,
  recordType: number,
  bytes: Uint8Array,
): string => {
  const header = [bytes.length, address >>> 8, address, recordType];
  let sum = 0;
  let body = "";
  for (const value of [...header, ...bytes]) {
    sum = (sum + value) & 0xff;
    body += hexByte(value);
  }
  return `:${body}${hexByte(-sum)}`;
};

/** Convert a successful flat-target compile into a Debug80-loadable Intel HEX image. */
export const writeNucleusIntelHex = (result: NucleusCompileSuccess): string => {
  const image = result.materialized.flatImage;
  if (image === undefined) {
    throw new Error("Intel HEX output requires a flat Nucleus target");
  }
  const { imageBase } = result.materialized.parsed.begin;
  const usedLength = result.materialized.parsed.map.banks[0]?.usedLength ?? 0;
  const lines: string[] = [];
  for (let offset = 0; offset < usedLength; offset += 16) {
    lines.push(
      intelHexRecord(
        imageBase + offset,
        0,
        image.slice(offset, Math.min(offset + 16, usedLength)),
      ),
    );
  }
  lines.push(intelHexRecord(0, 1, new Uint8Array()));
  return `${lines.join("\n")}\n`;
};

interface CompilerImage {
  readonly program: ReturnType<typeof parseIntelHex>;
  readonly symbols: Readonly<Record<string, number>>;
}

const compilerImages = new Map<boolean, Promise<CompilerImage>>();
const nativeCompilerImages = new Map<boolean, Promise<CompilerImage>>();

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

const loadCompilerImage = async (
  debugHooks: boolean,
): Promise<CompilerImage> => {
  let pending = compilerImages.get(debugHooks);
  if (pending === undefined) {
    pending = (async () => {
      const hex = debugHooks ? debugCompilerHex : normalCompilerHex;
      const symbols = debugHooks ? debugCompilerSymbols : normalCompilerSymbols;
      return { program: parseIntelHex(hex), symbols };
    })();
    compilerImages.set(debugHooks, pending);
  }
  return pending;
};

const validateNativeHostVector = (image: CompilerImage): void => {
  const base = symbol(image.symbols, "HostVectorBase");
  const end = symbol(image.symbols, "HostVectorEnd");
  const bytes = image.program.memory;
  const expectedHeader = [0x4e, 0x48, 0, 1, 8, 14, 0, 0] as const;
  if (end - base < expectedHeader.length + 14 * 3) {
    throw new Error("Nucleus native host vector is truncated");
  }
  for (let offset = 0; offset < expectedHeader.length; offset += 1) {
    if (bytes[base + offset] !== expectedHeader[offset]) {
      throw new Error("Nucleus native host vector header is incompatible");
    }
  }
  for (let entry = 0; entry < 14; entry += 1) {
    if (bytes[base + 8 + entry * 3] !== 0xc3) {
      throw new Error("Nucleus native host vector entry is not a JP");
    }
  }
};

const loadNativeCompilerImage = async (
  debugHooks: boolean,
): Promise<CompilerImage> => {
  let pending = nativeCompilerImages.get(debugHooks);
  if (pending === undefined) {
    pending = Promise.resolve().then(() => {
      const image = {
        program: parseIntelHex(
          debugHooks ? nativeDebugCompilerHex : nativeCompilerHex,
        ),
        symbols: debugHooks
          ? nativeDebugCompilerSymbols
          : nativeCompilerSymbols,
      };
      validateNativeHostVector(image);
      return image;
    });
    nativeCompilerImages.set(debugHooks, pending);
  }
  return pending;
};

const compilerImageFingerprint = (image: CompilerImage): string => {
  const hash = createHash("sha256");
  hash.update(image.program.memory);
  hash.update(
    JSON.stringify(
      Object.entries(image.symbols).sort(([left], [right]) =>
        left.localeCompare(right),
      ),
    ),
  );
  return hash.digest("hex");
};

export const nucleusCompilerInfo = async (): Promise<{
  readonly hostApiVersion: 1;
  readonly languageVersion: "0.1";
  readonly runtimeIdentity: 9;
  readonly normalImageSha256: string;
  readonly debugImageSha256: string;
  readonly capacities: typeof nucleusCompilerCapacities;
  readonly targets: {
    readonly flat: true;
    readonly banked: true;
    readonly maxBanks: 4;
  };
}> => {
  const [normal, debug] = await Promise.all([
    loadNativeCompilerImage(false),
    loadNativeCompilerImage(true),
  ]);
  return {
    hostApiVersion: 1,
    languageVersion: "0.1",
    runtimeIdentity: RUNTIME_IDENTITY,
    normalImageSha256: compilerImageFingerprint(normal),
    debugImageSha256: compilerImageFingerprint(debug),
    capacities: nucleusCompilerCapacities,
    targets: { flat: true, banked: true, maxBanks: 4 },
  };
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
  sourceBase: number,
  sourceLimit: number,
  requestedBanks?: readonly number[],
): { partBanks: number[]; loaded: NucleusLoadedSourcePart[] } => {
  if (parts.length < 1 || parts.length > MAX_SOURCE_PARTS) {
    throw new RangeError(
      `Nucleus source requires 1..${MAX_SOURCE_PARTS} parts`,
    );
  }
  const encoded = parts.map(sourcePartBytes);
  const loaded: NucleusLoadedSourcePart[] = [];
  let sourceCursor = sourceBase + parts.length * 5;
  for (let index = 0; index < encoded.length; index += 1) {
    const bytes = encoded[index] ?? new Uint8Array();
    const descriptor = sourceBase + index * 5;
    const end = sourceCursor + bytes.length;
    if (end > sourceLimit) {
      throw new RangeError(
        "Nucleus source parts exceed the 2 KiB host source window",
      );
    }
    memory[descriptor] = index + 1;
    writeWord(memory, descriptor + 1, sourceCursor);
    writeWord(memory, descriptor + 3, end);
    memory.set(bytes, sourceCursor);
    loaded.push({
      id: index + 1,
      name: parts[index]?.name ?? `part-${index + 1}.nu`,
      start: sourceCursor,
      end,
      bytes,
    });
    sourceCursor = end;
  }
  const partBanks = requestedBanks?.slice() ?? encoded.map(() => 0);
  if (partBanks.length !== encoded.length) {
    throw new RangeError("Nucleus target partBanks must match source parts");
  }
  return { partBanks, loaded };
};

const prepareNativeSource = (
  parts: readonly NucleusSourcePart[],
  requestedBanks?: readonly number[],
): {
  bytes: Uint8Array[];
  loaded: NucleusLoadedSourcePart[];
  partBanks: number[];
} => {
  if (parts.length < 1 || parts.length > MAX_SOURCE_PARTS) {
    throw new RangeError(
      `Nucleus source requires 1..${MAX_SOURCE_PARTS} parts`,
    );
  }
  const bytes = parts.map(sourcePartBytes);
  const partBanks = requestedBanks?.slice() ?? bytes.map(() => 0);
  if (partBanks.length !== bytes.length) {
    throw new RangeError("Nucleus target partBanks must match source parts");
  }
  const loaded = bytes.map((partBytes, index) => ({
    id: index + 1,
    name: parts[index]?.name ?? `part-${index + 1}.nu`,
    start: 0,
    end: 0,
    bytes: partBytes,
  }));
  return { bytes, loaded, partBanks };
};

const debugTraceSymbols = (image: CompilerImage): NucleusDebugTraceSymbols => ({
  sourcePartId: symbol(image.symbols, "SourcePartId"),
  tokenStartOffset: symbol(image.symbols, "TokenStartOffset"),
  tokenStartLine: symbol(image.symbols, "TokenStartLine"),
  tokenStartColumn: symbol(image.symbols, "TokenStartColumn"),
  sinkCursor: symbol(image.symbols, "SinkCursor"),
  semanticPayloadBase: symbol(image.symbols, "SemanticPayloadBase"),
  semanticReadCursor: symbol(image.symbols, "SemanticReadCursor"),
  declarationNamePointer: symbol(image.symbols, "DeclarationNamePointer"),
  declarationNameLength: symbol(image.symbols, "DeclarationNameLength"),
  stage7CurrentRoutine: symbol(image.symbols, "Stage7CurrentRoutine"),
  stage7RoutineTableBase: symbol(image.symbols, "Stage7RoutineTableBase"),
  stage7RoutineEntrySize: symbol(image.symbols, "Stage7RoutineEntrySize"),
});

const isBankedTarget = (target: NucleusTarget): target is NucleusBankedTarget =>
  Object.prototype.hasOwnProperty.call(target, "bankCount");

const flatTargetUsesRomMode = (target: NucleusFlatTarget): boolean => {
  const imageBase = target.imageBase ?? 0x8000;
  const imageEnd = imageBase + (target.imageCapacity ?? 0x1000);
  const writableBase = target.writableBase ?? 0x4000;
  const writableEnd = writableBase + (target.writableCapacity ?? 0x1000);
  return !(writableBase >= imageBase && writableEnd <= imageEnd);
};

const prepareTarget = (
  memory: Uint8Array,
  partBanks: readonly number[],
  target: NucleusTarget,
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
  const imageFill = target.imageFill ?? 0xff;
  if (!Number.isInteger(imageFill) || imageFill < 0 || imageFill > 0xff) {
    throw new RangeError("Nucleus target image fill is outside 0..255");
  }
  memory.fill(0, TARGET_DESCRIPTOR, TARGET_DESCRIPTOR + TARGET_DESCRIPTOR_SIZE);
  writeWord(memory, TARGET_DESCRIPTOR, RUNTIME_IDENTITY);
  writeWord(memory, TARGET_DESCRIPTOR + 2, imageBase);
  writeWord(memory, TARGET_DESCRIPTOR + 4, imageCapacity);
  writeWord(memory, TARGET_DESCRIPTOR + 6, writableBase);
  writeWord(memory, TARGET_DESCRIPTOR + 8, writableCapacity);
  memory[TARGET_DESCRIPTOR + 10] = target.establishStack === false ? 0 : 1;
  const bankCount = isBankedTarget(target) ? target.bankCount : 1;
  const entryBank = isBankedTarget(target) ? target.entryBank : 0;
  if (
    !Number.isInteger(bankCount) ||
    bankCount < (isBankedTarget(target) ? 2 : 1) ||
    bankCount > 4
  ) {
    throw new RangeError(
      "Nucleus target bankCount is outside its supported range",
    );
  }
  if (!Number.isInteger(entryBank) || entryBank < 0 || entryBank >= bankCount) {
    throw new RangeError("Nucleus target entryBank is outside the bank count");
  }
  for (const bank of partBanks) {
    if (!Number.isInteger(bank) || bank < 0 || bank >= bankCount) {
      throw new RangeError(
        "Nucleus source part bank is outside the bank count",
      );
    }
  }
  memory[TARGET_DESCRIPTOR + 11] = bankCount;
  memory[TARGET_DESCRIPTOR + 12] = entryBank;
  writeWord(memory, TARGET_DESCRIPTOR + 13, PART_BANKS);
  memory.set(partBanks, PART_BANKS);
  return {
    banked: bankCount > 1,
    runtimeIdentity: RUNTIME_IDENTITY,
    bankCount,
    imageFill,
    imageBase,
    imageCapacity,
  };
};

const capturedMap = (
  memory: Uint8Array,
  symbols: Readonly<Record<string, number>>,
  begin: NobjBegin,
  target: NucleusFlatTarget,
  partBanks: readonly number[],
): NobjMap => {
  const address = (name: string): number => symbol(symbols, name);
  const value = (name: string): number => readWord(memory, address(name));
  const romMode = flatTargetUsesRomMode(target);
  const vectorLength = address("NucleusRuntimeVectorLength");
  const stateLength = address("NucleusRuntimeStateLength");
  const staticLength = value("StaticImageLength");
  const initializedLength = vectorLength + stateLength + staticLength;
  const readOnlyLength = value("TargetReadOnlyLength");
  const aggregateLength = value("TargetContextRoDataCapacity");
  return {
    romMode,
    establishedStack: target.establishStack !== false,
    entryBank: 0,
    entryAddress: begin.imageBase,
    writableBase: value("TargetWritableBase"),
    writableCapacity: value("TargetWritableCapacity"),
    vectorBase: value("TargetWritableBase"),
    vectorLength,
    initializedRunBase: value("TargetWritableBase"),
    initializedRunLength: initializedLength,
    bssBase: value("TargetBssBase"),
    bssLength: value("ProgramBssLength"),
    stackRequirement: address("TargetStackRequirement"),
    dataLoadBank: 0,
    dataLoadAddress: romMode
      ? value("TargetReadOnlyBase")
      : value("TargetWritableBase"),
    dataLoadLength: initializedLength,
    partBanks,
    banks: [
      {
        usedLength: (value("EmitCursor") - begin.imageBase) & 0xffff,
        readOnlyBase: readOnlyLength === 0 ? 0 : value("TargetReadOnlyBase"),
        readOnlyLength,
        aggregateConstantBase:
          aggregateLength === 0 ? 0 : value("TargetContextRoDataBase"),
        aggregateConstantLength: aggregateLength,
      },
    ],
  };
};

const capturedContext = (
  map: NobjMap,
  begin: NobjBegin,
  staticLength: number,
  services: RuntimeServiceAddresses,
): RuntimeLinkContext => ({
  runtimeBase: begin.imageBase + 3,
  writableBase: map.writableBase,
  writableCapacity: map.writableCapacity,
  writableStateBase: map.vectorBase + map.vectorLength,
  vectorBase: map.vectorBase,
  programDataBase: map.bssBase - staticLength,
  programDataCapacity: staticLength + map.bssLength,
  readOnlyBase:
    map.banks.length === 1 ? (map.banks[0]?.aggregateConstantBase ?? 0) : 0,
  readOnlyCapacity:
    map.banks.length === 1 ? (map.banks[0]?.aggregateConstantLength ?? 0) : 0,
  services,
});

const capturedBankedMap = (
  memory: Uint8Array,
  symbols: Readonly<Record<string, number>>,
  begin: NobjBegin,
  target: NucleusBankedTarget,
  partBanks: readonly number[],
): NobjMap => {
  const address = (name: string): number => symbol(symbols, name);
  const startupLength = readWord(memory, address("TargetStartupLength"));
  const staticLength = readWord(memory, address("StaticImageLength"));
  const vectorLength = address("NucleusRuntimeVectorLength");
  const stateLength = address("NucleusRuntimeStateLength");
  const runtimeLength = address("NucleusRuntimeExpectedLength");
  const initializedLength = vectorLength + stateLength + staticLength;
  const cursors = address("AdapterCapturedBankCursors");
  const remaining = address("AdapterCapturedBankRemaining");
  const roLengths = address("AdapterCapturedBankRoLengths");
  const banks = Array.from({ length: target.bankCount }, (_, bank) => {
    const cursor = readWord(memory, cursors + bank * 2);
    const bankRemaining = readWord(memory, remaining + bank * 2);
    const usedLength = (cursor - begin.imageBase) & 0xffff;
    if (usedLength + bankRemaining !== begin.imageCapacity) {
      throw new Error(
        `Nucleus bank ${bank} cursor/capacity state is inconsistent`,
      );
    }
    const aggregateLength = readWord(memory, roLengths + bank * 2);
    let aggregateConstantBase = begin.imageBase + 3 + runtimeLength;
    if (bank === target.entryBank) {
      aggregateConstantBase += startupLength + initializedLength;
    }
    const entryReadOnlyBase =
      bank === target.entryBank
        ? begin.imageBase + 3 + runtimeLength + startupLength
        : 0;
    return {
      usedLength,
      readOnlyBase:
        bank === target.entryBank
          ? entryReadOnlyBase
          : aggregateLength === 0
            ? 0
            : aggregateConstantBase,
      readOnlyLength:
        (bank === target.entryBank ? initializedLength : 0) + aggregateLength,
      aggregateConstantBase: aggregateLength === 0 ? 0 : aggregateConstantBase,
      aggregateConstantLength: aggregateLength,
    };
  });
  return {
    romMode: true,
    establishedStack: target.establishStack !== false,
    entryBank: target.entryBank,
    entryAddress: begin.imageBase,
    writableBase: target.writableBase ?? 0x4000,
    writableCapacity: target.writableCapacity ?? 0x1000,
    vectorBase: target.writableBase ?? 0x4000,
    vectorLength,
    initializedRunBase: target.writableBase ?? 0x4000,
    initializedRunLength: initializedLength,
    bssBase: readWord(memory, address("TargetBssBase")),
    bssLength: readWord(memory, address("ProgramBssLength")),
    stackRequirement: address("TargetStackRequirement"),
    dataLoadBank: target.entryBank,
    dataLoadAddress: banks[target.entryBank]?.readOnlyBase ?? 0,
    dataLoadLength: initializedLength,
    partBanks,
    banks,
  };
};

const nativeMapRequest = (memory: Uint8Array, request: number): NobjMap => {
  const byte = (offset: number): number => memory[request + offset] ?? 0;
  const word = (offset: number): number => readWord(memory, request + offset);
  if (byte(0) !== 1) throw new Error("native MAP request revision is invalid");
  const flags = byte(1);
  if ((flags & ~3) !== 0) throw new Error("native MAP flags are invalid");
  const entryBank = byte(2);
  const entryAddress = word(3);
  const imageBase = word(5);
  const imageCapacity = word(7);
  const writableBase = word(9);
  const writableCapacity = word(11);
  const vectorLength = word(13);
  const initializedRunLength = word(15);
  const bssBase = word(17);
  const bssLength = word(19);
  const stackRequirement = word(21);
  const dataLoadBank = byte(23);
  const dataLoadAddress = word(24);
  const dataLoadLength = word(26);
  const partCount = byte(28);
  const partBanksPointer = word(29);
  const bankCount = byte(31);
  const bankStatePointer = word(32);
  const runtimeLength = word(34);
  const startupLength = word(36);
  const romMode = (flags & 1) !== 0;
  const partBanks = Array.from(
    memory.slice(partBanksPointer, partBanksPointer + partCount),
  );
  const banks = Array.from({ length: bankCount }, (_, bank) => {
    const state = bankStatePointer + bank * 6;
    const cursor = readWord(memory, state);
    const remaining = readWord(memory, state + 2);
    const aggregateConstantLength = readWord(memory, state + 4);
    const usedLength = (cursor - imageBase) & 0xffff;
    if (usedLength + remaining !== imageCapacity) {
      throw new Error(`native MAP bank ${bank} state is inconsistent`);
    }
    const afterRuntime = imageBase + 3 + runtimeLength;
    const isEntry = bank === entryBank;
    const readOnlyBase = isEntry ? afterRuntime + startupLength : afterRuntime;
    const entryInitializedLength =
      isEntry && romMode ? initializedRunLength : 0;
    const readOnlyLength = entryInitializedLength + aggregateConstantLength;
    const aggregateConstantBase = readOnlyBase + entryInitializedLength;
    return {
      usedLength,
      readOnlyBase: readOnlyLength === 0 ? 0 : readOnlyBase,
      readOnlyLength,
      aggregateConstantBase:
        aggregateConstantLength === 0 ? 0 : aggregateConstantBase,
      aggregateConstantLength,
    };
  });
  return {
    romMode,
    establishedStack: (flags & 2) !== 0,
    entryBank,
    entryAddress,
    writableBase,
    writableCapacity,
    vectorBase: writableBase,
    vectorLength,
    initializedRunBase: writableBase,
    initializedRunLength,
    bssBase,
    bssLength,
    stackRequirement,
    dataLoadBank,
    dataLoadAddress,
    dataLoadLength,
    partBanks,
    banks,
  };
};

const nativeRuntimeContext = (
  memory: Uint8Array,
  pointer: number,
  services: RuntimeServiceAddresses,
): RuntimeLinkContext => ({
  runtimeBase: readWord(memory, pointer),
  writableBase: readWord(memory, pointer + 2),
  writableCapacity: readWord(memory, pointer + 4),
  writableStateBase: readWord(memory, pointer + 6),
  vectorBase: readWord(memory, pointer + 8),
  programDataBase: readWord(memory, pointer + 10),
  programDataCapacity: readWord(memory, pointer + 12),
  readOnlyBase: readWord(memory, pointer + 14),
  readOnlyCapacity: readWord(memory, pointer + 16),
  services,
});

const validateNativeTargetDescriptor = (
  memory: Uint8Array,
  pointer: number,
  begin: NobjBegin,
  target: NucleusTarget,
  partBanks: readonly number[],
): void => {
  if (
    readWord(memory, pointer) !== begin.runtimeIdentity ||
    readWord(memory, pointer + 2) !== begin.imageBase ||
    readWord(memory, pointer + 4) !== begin.imageCapacity ||
    readWord(memory, pointer + 6) !== (target.writableBase ?? 0x4000) ||
    readWord(memory, pointer + 8) !== (target.writableCapacity ?? 0x1000) ||
    (memory[pointer + 10] ?? 0) !== (target.establishStack === false ? 0 : 1) ||
    (memory[pointer + 11] ?? 0) !== begin.bankCount ||
    (memory[pointer + 12] ?? 0) !==
      (isBankedTarget(target) ? target.entryBank : 0)
  ) {
    throw new Error("native target descriptor differs from retained target");
  }
  const banksPointer = readWord(memory, pointer + 13);
  if (banksPointer + partBanks.length > memory.length) {
    throw new Error("native target part-bank array is outside memory");
  }
  for (let index = 0; index < partBanks.length; index += 1) {
    if ((memory[banksPointer + index] ?? -1) !== partBanks[index]) {
      throw new Error("native target part-bank mapping differs from source");
    }
  }
};

const runNucleusCompilerNativeTo = async (
  parts: readonly NucleusSourcePart[],
  target: NucleusTarget,
  output: NobjSequentialOutput,
  options: NucleusStreamingCompileOptions,
): Promise<NucleusStreamingCompileResult> => {
  const debugHooks = options.debugMap === true;
  const image = await loadNativeCompilerImage(debugHooks);
  const prepared = prepareNativeSource(
    parts,
    isBankedTarget(target) ? target.partBanks : undefined,
  );
  let sourcePartIndex = 0;
  let sourceOffset = 0;
  let sourcePhase: "begin" | "bytes" | "end" | "unit" | "finished" = "begin";
  const retainedNames = new NativeRetainedNameStore();
  let materializedNameHandle: number | undefined;
  let nativeHostFailure: Error | undefined;
  let hostGenerationCancelled = false;
  let launchActive = false;
  let pendingHostWork: Promise<void> | undefined;
  let sink: NobjGenerationSink | undefined;
  let metadata: NobjCommitMetadata | undefined;
  let debugMapping: NucleusDebugMapping | undefined;
  const adapterImages: NobjAdapterImageByte[] = [];
  let collector: NucleusDebugCollector | undefined;
  let activeProvider:
    Awaited<ReturnType<typeof loadCanonicalRuntimeProvider>> | undefined;
  const provider = {
    get: (identity: number, context: RuntimeLinkContext) =>
      activeProvider?.get(identity, context),
  };
  const runtime = createZ80Runtime(
    { ...image.program, memory: image.program.memory.slice() },
    symbol(image.symbols, "CompileTargetAggregateCallParts"),
    {
      write: (port, value) => {
        const selectedPort = port & 0xff;
        const cpu = runtime.cpu;
        const memory = runtime.hardware.memory;
        const bc = (cpu.b << 8) | cpu.c;
        const de = (cpu.d << 8) | cpu.e;
        const hl = (cpu.h << 8) | cpu.l;
        const succeed = (): void => {
          cpu.flags.C = 0;
        };
        const fail = (diagnostic = 97): void => {
          cpu.a = diagnostic;
          cpu.flags.C = 1;
        };
        try {
          if (debugHooks && isNucleusDebugPort(selectedPort)) {
            collector?.collect(selectedPort, cpu);
            return;
          } else if (
            selectedPort === symbol(image.symbols, "NativeHostLaunchBeginPort")
          ) {
            if (options.signal?.aborted === true) {
              cpu.a = 6;
              cpu.flags.C = 1;
              return;
            }
            if (
              launchActive ||
              cpu.ix !== NATIVE_LAUNCH_DESCRIPTOR ||
              (memory[cpu.ix] ?? 0) !== 14 ||
              (memory[cpu.ix + 1] ?? 0) !== 0 ||
              (memory[cpu.ix + 2] ?? 0) !== 1 ||
              (memory[cpu.ix + 3] ?? 0) !== parts.length ||
              readWord(memory, cpu.ix + 4) !== 1 ||
              readWord(memory, cpu.ix + 6) !== TARGET_DESCRIPTOR ||
              readWord(memory, cpu.ix + 8) !== NATIVE_LAUNCH_RESULT ||
              readWord(memory, cpu.ix + 10) !== 1 ||
              (memory[cpu.ix + 12] ?? 0) !== (debugHooks ? 2 : 0) ||
              (memory[cpu.ix + 13] ?? 0) !== 0
            ) {
              cpu.a = 4;
              cpu.flags.C = 1;
              return;
            }
            try {
              validateNativeTargetDescriptor(
                memory,
                TARGET_DESCRIPTOR,
                begin,
                target,
                prepared.partBanks,
              );
            } catch {
              cpu.a = 4;
              cpu.flags.C = 1;
              return;
            }
            launchActive = true;
            succeed();
          } else if (
            selectedPort === symbol(image.symbols, "NativeHostLaunchEndPort")
          ) {
            if (
              !launchActive ||
              value > 2 ||
              (value === 0) !== (metadata !== undefined)
            ) {
              nativeHostFailure = new Error(
                "native Nucleus launch ended in an inconsistent state",
              );
              cpu.halted = true;
              return;
            }
            launchActive = false;
            succeed();
          } else if (
            selectedPort ===
            symbol(image.symbols, "NativeHostSourceNextChunkPort")
          ) {
            materializedNameHandle = undefined;
            const part = prepared.bytes[sourcePartIndex];
            if (sourcePhase === "unit") {
              cpu.a = 3;
              sourcePhase = "finished";
              succeed();
              return;
            }
            if (sourcePhase === "finished") {
              throw new Error(
                "native source provider requested end unit twice",
              );
            }
            if (part === undefined) {
              throw new Error("native source provider advanced past its unit");
            }
            cpu.c = sourcePartIndex + 1;
            if (sourcePhase === "begin") {
              cpu.a = 1;
              sourcePhase = part.length === 0 ? "end" : "bytes";
              succeed();
              return;
            }
            if (sourcePhase === "end") {
              cpu.a = 2;
              sourcePartIndex += 1;
              sourceOffset = 0;
              sourcePhase =
                sourcePartIndex === prepared.bytes.length ? "unit" : "begin";
              succeed();
              return;
            }
            const chunkBase = symbol(image.symbols, "NativeSourceChunkBase");
            const chunkLimit = symbol(image.symbols, "NativeSourceChunkLimit");
            const chunkLength = Math.min(
              chunkLimit - chunkBase,
              part.length - sourceOffset,
            );
            if (chunkLength <= 0) {
              throw new Error("native source provider produced an empty chunk");
            }
            memory.set(
              part.subarray(sourceOffset, sourceOffset + chunkLength),
              chunkBase,
            );
            sourceOffset += chunkLength;
            if (sourceOffset === part.length) sourcePhase = "end";
            cpu.a = 0;
            cpu.h = chunkBase >>> 8;
            cpu.l = chunkBase & 0xff;
            cpu.d = chunkLength >>> 8;
            cpu.e = chunkLength & 0xff;
            succeed();
          } else if (
            selectedPort === symbol(image.symbols, "NativeHostRetainNamePort")
          ) {
            const length = cpu.b;
            const partIndex = cpu.c - 1;
            const source = prepared.bytes[partIndex];
            const materialized =
              materializedNameHandle === undefined
                ? undefined
                : retainedNames.get(materializedNameHandle);
            const scratchBase = symbol(image.symbols, "NativeSourceTokenBase");
            if (
              materialized !== undefined &&
              hl === scratchBase &&
              length === materialized.bytes.length
            ) {
              let equal = true;
              for (let index = 0; equal && index < length; index += 1) {
                equal = memory[hl + index] === materialized.bytes[index];
              }
              if (equal) {
                cpu.h = materializedNameHandle! >>> 8;
                cpu.l = materializedNameHandle! & 0xff;
                cpu.a = 0;
                succeed();
                return;
              }
            }
            if (
              length === 0 ||
              source === undefined ||
              de + length > source.length ||
              hl + length > memory.length ||
              length > nativeRetainedNameByteCapacity
            ) {
              throw new Error(
                `native retained-name request is invalid (part=${cpu.c}, offset=${de}, length=${length}, pointer=${hl.toString(16)}, source=${source?.length ?? -1})`,
              );
            }
            for (let index = 0; index < length; index += 1) {
              if (memory[hl + index] !== source[de + index]) {
                throw new Error(
                  `native retained name differs from source (part=${cpu.c}, offset=${de}, length=${length}, pointer=${hl.toString(16)}, index=${index}, actual=${memory[hl + index]}, expected=${source[de + index]})`,
                );
              }
            }
            const handle = retainedNames.retain({
              bytes: source.slice(de, de + length),
              part: cpu.c,
              offset: de,
            });
            cpu.h = handle >>> 8;
            cpu.l = handle & 0xff;
            cpu.a = 0;
            succeed();
          } else if (
            selectedPort === symbol(image.symbols, "NativeHostCompareNamePort")
          ) {
            const length = cpu.b;
            const bytes =
              cpu.ix + length <= memory.length
                ? memory.subarray(cpu.ix, cpu.ix + length)
                : new Uint8Array();
            const comparison = retainedNames.compare(hl, bytes);
            if (comparison === "invalid" || bytes.length !== length) {
              throw new Error("native retained-name handle is invalid");
            }
            cpu.a = 0;
            cpu.flags.Z = comparison === "equal" ? 1 : 0;
            succeed();
          } else if (
            selectedPort ===
            symbol(image.symbols, "NativeHostMaterializeNamePort")
          ) {
            const retained = retainedNames.get(hl);
            const scratchBase = symbol(image.symbols, "NativeSourceTokenBase");
            const scratchLimit = symbol(
              image.symbols,
              "NativeSourceTokenLimit",
            );
            if (
              retained === undefined ||
              retained.bytes.length > scratchLimit - scratchBase
            ) {
              throw new Error("native retained-name handle is invalid");
            }
            memory.set(retained.bytes, scratchBase);
            materializedNameHandle = hl;
            cpu.h = scratchBase >>> 8;
            cpu.l = scratchBase & 0xff;
            cpu.b = retained.bytes.length;
            cpu.a = 0;
            succeed();
          } else if (
            selectedPort === symbol(image.symbols, "NativeHostTargetBeginPort")
          ) {
            try {
              validateNativeTargetDescriptor(
                memory,
                cpu.ix,
                begin,
                target,
                prepared.partBanks,
              );
            } catch {
              fail(95);
              return;
            }
            sink = new NobjGenerationSink(
              new NobjGenerationStore(),
              provider,
              options.spoolFactory ?? (() => new MemoryNobjSpool()),
              { lowMemoryPatchValidation: options.lowMemoryPatchValidation },
            );
            sink.begin(begin);
            succeed();
          } else if (
            selectedPort ===
            symbol(image.symbols, "NativeHostTargetImageBytePort")
          ) {
            sink?.image(cpu.c, hl, Uint8Array.of(value));
            if (collector !== undefined) {
              adapterImages.push({ bank: cpu.c, address: hl, value });
            }
            succeed();
          } else if (
            selectedPort ===
              symbol(image.symbols, "NativeHostRuntimeImagePort") ||
            selectedPort ===
              symbol(image.symbols, "NativeHostRuntimeInitialPort")
          ) {
            const requestOperation =
              memory[symbol(image.symbols, "NativeHostRuntimeOperation")] ??
              0xff;
            const requestBank =
              memory[symbol(image.symbols, "NativeHostRuntimeBank")] ?? 0xff;
            const requestLength = readWord(
              memory,
              symbol(image.symbols, "NativeHostRuntimeLength"),
            );
            const requestIdentity = readWord(
              memory,
              symbol(image.symbols, "NativeHostRuntimeIdentity"),
            );
            const requestAddress = readWord(
              memory,
              symbol(image.symbols, "NativeHostRuntimeAddress"),
            );
            const requestContext = readWord(
              memory,
              symbol(image.symbols, "NativeHostRuntimeContext"),
            );
            const requestStatus = symbol(
              image.symbols,
              "NativeHostRuntimeStatus",
            );
            const requestPending = symbol(
              image.symbols,
              "NativeHostRuntimePending",
            );
            const initial =
              selectedPort ===
              symbol(image.symbols, "NativeHostRuntimeInitialPort");
            if (
              memory[requestPending] !== 1 ||
              memory[requestStatus] !== 0xff ||
              requestOperation !== (initial ? 1 : 0) ||
              requestBank !== value ||
              requestLength !== bc ||
              requestIdentity !== de ||
              requestAddress !== hl ||
              requestContext !== cpu.ix
            ) {
              memory[requestStatus] = 95;
              return;
            }
            const context = nativeRuntimeContext(
              memory,
              requestContext,
              target.services ?? defaultNucleusServices,
            );
            pendingHostWork = (async () => {
              try {
                if (
                  activeProvider?.get(requestIdentity, context) === undefined
                ) {
                  const loadedProvider = await loadCanonicalRuntimeProvider([
                    context,
                  ]);
                  if (hostGenerationCancelled) return;
                  activeProvider = loadedProvider;
                }
                if (hostGenerationCancelled) return;
                if (initial) {
                  sink?.runtimeInitialImage(
                    requestBank,
                    requestAddress,
                    requestIdentity,
                    context,
                    requestLength,
                  );
                } else {
                  sink?.runtimeImage(
                    requestBank,
                    requestAddress,
                    requestIdentity,
                    context,
                    requestLength,
                  );
                }
                if (hostGenerationCancelled) return;
                memory[requestStatus] = 0;
              } catch {
                if (hostGenerationCancelled) return;
                memory[requestStatus] = 95;
              }
            })();
          } else if (
            selectedPort === symbol(image.symbols, "NativeHostPatchBytePort")
          ) {
            sink?.patch(cpu.c, hl, Uint8Array.of(value));
            succeed();
          } else if (
            selectedPort === symbol(image.symbols, "NativeHostPatchWordPort")
          ) {
            sink?.patch(cpu.c, de, Uint8Array.of(cpu.l, cpu.h));
            succeed();
          } else if (
            selectedPort === symbol(image.symbols, "NativeHostMapFlatPort") ||
            selectedPort === symbol(image.symbols, "NativeHostMapBankedPort")
          ) {
            sink?.map(nativeMapRequest(memory, cpu.ix));
            succeed();
          } else if (
            selectedPort === symbol(image.symbols, "NativeHostCommitPort")
          ) {
            if (collector !== undefined) {
              try {
                debugMapping = collector.finishStreaming(begin, adapterImages);
              } catch {
                memory[symbol(image.symbols, "NativeHostAsyncStatus")] = 4;
                cpu.a = 4;
                cpu.flags.C = 1;
                return;
              }
            }
            metadata = sink?.commitTo(output);
            succeed();
          } else if (
            selectedPort === symbol(image.symbols, "NativeHostAbortPort")
          ) {
            sink?.abort();
            succeed();
          } else {
            options.compilerIoWrite?.(selectedPort, value);
          }
        } catch (error) {
          const sourcePort = symbol(
            image.symbols,
            "NativeHostSourceNextChunkPort",
          );
          const materializePort = symbol(
            image.symbols,
            "NativeHostMaterializeNamePort",
          );
          if (selectedPort >= sourcePort && selectedPort <= materializePort) {
            nativeHostFailure =
              error instanceof Error ? error : new Error(String(error));
            cpu.a = 5;
            cpu.flags.C = 1;
          } else {
            fail();
          }
        }
      },
    },
  );
  const memory = runtime.hardware.memory;
  const begin = prepareTarget(memory, prepared.partBanks, target);
  if (debugHooks) {
    collector = new NucleusDebugCollector(
      memory,
      prepared.loaded,
      debugTraceSymbols(image),
      (handle, length) => {
        const retained = retainedNames.get(handle);
        return retained === undefined || retained.bytes.length !== length
          ? undefined
          : retained;
      },
    );
  }
  memory[RETURN_SENTINEL] = 0x76;
  writeWord(memory, STACK_TOP, RETURN_SENTINEL);
  memory.fill(0, NATIVE_LAUNCH_DESCRIPTOR, NATIVE_LAUNCH_DESCRIPTOR + 14);
  memory[NATIVE_LAUNCH_DESCRIPTOR] = 14;
  memory[NATIVE_LAUNCH_DESCRIPTOR + 1] = 0;
  memory[NATIVE_LAUNCH_DESCRIPTOR + 2] = 1;
  memory[NATIVE_LAUNCH_DESCRIPTOR + 3] = parts.length;
  writeWord(memory, NATIVE_LAUNCH_DESCRIPTOR + 4, 1);
  writeWord(memory, NATIVE_LAUNCH_DESCRIPTOR + 6, TARGET_DESCRIPTOR);
  writeWord(memory, NATIVE_LAUNCH_DESCRIPTOR + 8, NATIVE_LAUNCH_RESULT);
  writeWord(memory, NATIVE_LAUNCH_DESCRIPTOR + 10, 1);
  memory[NATIVE_LAUNCH_DESCRIPTOR + 12] = debugHooks ? 2 : 0;
  memory[NATIVE_LAUNCH_DESCRIPTOR + 13] = 0;
  memory.fill(0xa5, NATIVE_LAUNCH_RESULT, NATIVE_LAUNCH_RESULT + 9);
  let instructions = 0;
  let cycles = 0;
  runtime.cpu.sp = STACK_TOP;
  runtime.cpu.pc = symbol(image.symbols, "NucleusHostInitialize");
  runtime.cpu.halted = false;
  try {
    while (!runtime.isHalted()) {
      if (
        instructions >= DEFAULT_INSTRUCTION_LIMIT ||
        cycles >= DEFAULT_CYCLE_LIMIT
      ) {
        throw new Error(
          "Nucleus host initialization exceeded its execution limit",
        );
      }
      const step = runtime.step();
      instructions += 1;
      cycles += step.cycles ?? 0;
    }
    writeWord(memory, STACK_TOP, RETURN_SENTINEL);
    runtime.cpu.sp = STACK_TOP;
    runtime.cpu.pc = symbol(image.symbols, "NucleusHostCompile");
    runtime.cpu.ix = NATIVE_LAUNCH_DESCRIPTOR;
    runtime.cpu.halted = false;
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
      if (pendingHostWork !== undefined) {
        const pending = pendingHostWork;
        pendingHostWork = undefined;
        const signal = options.signal;
        if (signal === undefined) {
          await pending;
        } else if (signal.aborted) {
          hostGenerationCancelled = true;
          memory[symbol(image.symbols, "NativeHostRuntimeStatus")] = 6;
        } else {
          let abort: (() => void) | undefined;
          const cancelled = new Promise<"cancelled">((resolve) => {
            abort = () => resolve("cancelled");
            signal.addEventListener("abort", abort, { once: true });
          });
          const completed = await Promise.race([
            pending.then(() => "completed" as const),
            cancelled,
          ]);
          if (abort !== undefined) signal.removeEventListener("abort", abort);
          if (completed === "cancelled") {
            hostGenerationCancelled = true;
            memory[symbol(image.symbols, "NativeHostRuntimeStatus")] = 6;
          }
        }
      }
    }
    if (nativeHostFailure !== undefined) throw nativeHostFailure;
    const outcome = memory[NATIVE_LAUNCH_RESULT] ?? 0xff;
    const resultCode = memory[NATIVE_LAUNCH_RESULT + 1] ?? 0;
    if (
      runtime.cpu.a !== outcome ||
      runtime.cpu.flags.C !== (outcome === 0 ? 0 : 1)
    ) {
      throw new Error(
        "native Nucleus launch return differs from its result block",
      );
    }
    if (outcome === 2) {
      throw new Error(`native Nucleus host failed with status ${resultCode}`);
    }
    if (outcome === 1) {
      const part = memory[NATIVE_LAUNCH_RESULT + 2] ?? 0;
      return {
        success: false,
        diagnostic: {
          code: resultCode,
          sourcePart: part,
          sourceName: parts[part - 1]?.name,
          offset: readWord(memory, NATIVE_LAUNCH_RESULT + 3),
          line: readWord(memory, NATIVE_LAUNCH_RESULT + 5),
          column: readWord(memory, NATIVE_LAUNCH_RESULT + 7),
        },
        instructions,
        cycles,
      };
    }
    if (outcome !== 0) {
      throw new Error(
        `native Nucleus host returned invalid outcome ${outcome}`,
      );
    }
    if (metadata === undefined) {
      throw new Error("native Nucleus host returned without committing output");
    }
    return {
      success: true,
      object: metadata,
      ...(debugMapping === undefined ? {} : { debugMapping }),
      instructions,
      cycles,
    };
  } finally {
    hostGenerationCancelled = true;
    if (metadata === undefined) sink?.abort();
    launchActive = false;
    retainedNames.clear();
  }
};

const runNucleusCompiler = async (
  parts: readonly NucleusSourcePart[],
  target: NucleusTarget = {},
  options: NucleusCompileOptions = {},
  sequentialOutput?: NobjSequentialOutput,
  streamingOptions?: NucleusStreamingCompileOptions,
): Promise<NucleusCompileResult | NucleusStreamingCompileResult> => {
  if (sequentialOutput !== undefined && options.debugMap === true) {
    throw new Error("streaming NOBJ output does not yet support D8 collection");
  }
  const debugHooks = options.debugMap === true;
  const image = await loadCompilerImage(debugHooks);
  let debugCollectionActive = debugHooks;
  let collector: NucleusDebugCollector | undefined;
  const runtime = createZ80Runtime(
    { ...image.program, memory: image.program.memory.slice() },
    symbol(image.symbols, "CompileTargetAggregateCallParts"),
    {
      write: (port, value) => {
        if (debugCollectionActive && isNucleusDebugPort(port & 0xff)) {
          collector?.collect(port & 0xff, runtime.cpu);
          return;
        }
        options.compilerIoWrite?.(port, value);
      },
    },
  );
  const memory = runtime.hardware.memory;
  const sourceBase = symbol(image.symbols, "SourceBase");
  const sourceLimit = symbol(image.symbols, "SourceLimit");
  const prepared = prepareSource(
    memory,
    parts,
    sourceBase,
    sourceLimit,
    isBankedTarget(target) ? target.partBanks : undefined,
  );
  const partBanks = prepared.partBanks;
  const begin = prepareTarget(memory, partBanks, target);
  if (debugHooks) {
    collector = new NucleusDebugCollector(
      memory,
      prepared.loaded,
      debugTraceSymbols(image),
    );
  }
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
  runtime.cpu.h = sourceBase >>> 8;
  runtime.cpu.l = sourceBase & 0xff;
  runtime.cpu.ix = TARGET_DESCRIPTOR;
  runtime.cpu.halted = false;

  let instructions = 0;
  let cycles = 0;
  try {
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
  } finally {
    debugCollectionActive = false;
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
  const map = isBankedTarget(target)
    ? capturedBankedMap(memory, image.symbols, begin, target, partBanks)
    : capturedMap(memory, image.symbols, begin, target, partBanks);
  const runtimeLinkContext = capturedContext(
    map,
    begin,
    readWord(memory, symbol(image.symbols, "StaticImageLength")),
    target.services ?? defaultNucleusServices,
  );
  const adapterImages: NobjAdapterImageByte[] | undefined =
    collector === undefined ? undefined : [];
  const generation = {
    name: "nucleus-host-compile",
    producerMemory: memory,
    start: adapterBase,
    length: cursor - adapterBase,
    maxBytes: symbol(image.symbols, "AdapterLogLimit") - adapterBase,
    begin,
    map,
    runtimeLinkContext,
    ...(streamingOptions?.spoolFactory === undefined
      ? {}
      : { spoolFactory: streamingOptions.spoolFactory }),
    ...(streamingOptions?.lowMemoryPatchValidation === undefined
      ? {}
      : {
          lowMemoryPatchValidation: streamingOptions.lowMemoryPatchValidation,
        }),
    ...(adapterImages === undefined
      ? {}
      : {
          onImageByte: (imageByte: NobjAdapterImageByte) =>
            adapterImages.push(imageByte),
        }),
  };
  if (sequentialOutput !== undefined) {
    const object = await commitNobjAdapterGenerationTo(
      generation,
      sequentialOutput,
    );
    return { success: true, object, instructions, cycles };
  }
  const nobj = await commitNobjAdapterGeneration(generation);
  const parsed = parseNobj(nobj);
  const debugMapping = collector?.finish(parsed, begin, adapterImages ?? []);
  return {
    success: true,
    nobj,
    materialized: materializeNobj(parsed),
    ...(debugMapping === undefined ? {} : { debugMapping }),
    instructions,
    cycles,
  };
};

export const compileNucleus = async (
  parts: readonly NucleusSourcePart[],
  target: NucleusTarget = {},
  options: NucleusCompileOptions = {},
): Promise<NucleusCompileResult> =>
  (await runNucleusCompiler(parts, target, options)) as NucleusCompileResult;

/** Compile to a transactional sequential NOBJ destination without materializing it. */
export const compileNucleusTo = async (
  parts: readonly NucleusSourcePart[],
  target: NucleusTarget,
  output: NobjSequentialOutput,
  options: NucleusStreamingCompileOptions = {},
): Promise<NucleusStreamingCompileResult> =>
  runNucleusCompilerNativeTo(parts, target, output, options);
