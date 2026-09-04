import { parseIntelHex } from "@jhlagado/debug80-runtime";
import { assembleAtomSource } from "../scripts/atom-source.mjs";

import type {
  RuntimeImage,
  RuntimeImageProvider,
  RuntimeLinkContext,
  RuntimeServiceAddresses,
} from "./nobj.js";
import { NobjError } from "./nobj.js";

const helperIdentitySymbols = {
  ActivationPush: "NucleusRuntimeActivationPushOffset",
  ActivationPop: "NucleusRuntimeActivationPopOffset",
  ActivationClaim: "NucleusRuntimeActivationClaimOffset",
  ActivationRelease: "NucleusRuntimeActivationReleaseOffset",
  CheckArrayIndex: "NucleusRuntimeCheckArrayIndexOffset",
  CheckStringLength: "NucleusRuntimeCheckStringLengthOffset",
  CheckStringIndex: "NucleusRuntimeCheckStringIndexOffset",
  CheckAggregateRegion: "NucleusRuntimeCheckAggregateRegionOffset",
  InitializeBss: "NucleusRuntimeInitializeBssOffset",
  MultiplyU8: "NucleusRuntimeMultiplyU8Offset",
  MultiplyU16: "NucleusRuntimeMultiplyU16Offset",
  DivideU16: "NucleusRuntimeDivideU16Offset",
  ModuloU16: "NucleusRuntimeModuloU16Offset",
  CompareU16: "NucleusRuntimeCompareU16Offset",
  ResizeString: "NucleusRuntimeResizeStringOffset",
  ConvertInteger: "NucleusRuntimeConvertIntegerOffset",
  CompareSigned: "NucleusRuntimeCompareSignedOffset",
  DivideSigned: "NucleusRuntimeDivideSignedOffset",
  SignedLoopStep: "NucleusRuntimeSignedLoopStepOffset",
  RuntimePromoteI8Pair: "NucleusRuntimePromoteI8PairOffset",
  PacketServiceGateway: "NucleusRuntimePacketServiceGatewayOffset",
} as const;

const serviceOrder = [
  "readInputByte",
  "writeOutputByte",
  "readStorageByte",
  "rewindStorageInput",
  "writeStorageByte",
  "seekStorageOutput",
  "success",
  "unhandledFailure",
  "trap",
  "farCall",
  "farJump",
  "packetService",
] as const satisfies readonly (keyof RuntimeServiceAddresses)[];

const runtimeVectorLength = serviceOrder.length * 3;
const runtimeStateLength = 41;
const runtimeProgramDataBaseOffset = 37;
const runtimeProgramDataCapacityOffset = 39;

export const defaultRuntimeLinkContext: RuntimeLinkContext = {
  runtimeBase: 0x6800,
  writableBase: 0x7800,
  writableCapacity: 0x1000,
  writableStateBase: 0x7824,
  vectorBase: 0x7800,
  programDataBase: 0x784d,
  programDataCapacity: 0x0800,
  readOnlyBase: 0x6adc,
  readOnlyCapacity: 0x0800,
  services: {
    readInputByte: 0x9000,
    writeOutputByte: 0x9003,
    readStorageByte: 0x9006,
    rewindStorageInput: 0x9009,
    writeStorageByte: 0x900c,
    seekStorageOutput: 0x900f,
    success: 0x9012,
    unhandledFailure: 0x9015,
    trap: 0x9018,
    farCall: 0x901b,
    farJump: 0x901e,
    packetService: 0x9021,
  },
};

const checkedWord = (name: string, value: number): void => {
  if (!Number.isInteger(value) || value < 0 || value > 0xffff) {
    throw new NobjError(`${name} is outside 0..65535`);
  }
};

const checkedRegion = (
  name: string,
  base: number,
  capacity: number,
  allowEmpty = false,
): void => {
  checkedWord(`${name} base`, base);
  checkedWord(`${name} capacity`, capacity);
  if (!allowEmpty && capacity === 0)
    throw new NobjError(`${name} capacity is zero`);
  if (base + capacity > 0x10000) {
    throw new NobjError(`${name} crosses the Z80 address space`);
  }
};

export const validateRuntimeLinkContext = (
  context: RuntimeLinkContext,
): void => {
  checkedWord("runtime base", context.runtimeBase);
  checkedRegion("writable", context.writableBase, context.writableCapacity);
  checkedWord("writable state base", context.writableStateBase);
  checkedWord("vector base", context.vectorBase);
  checkedRegion(
    "program data",
    context.programDataBase,
    context.programDataCapacity,
    true,
  );
  checkedRegion(
    "read-only data",
    context.readOnlyBase,
    context.readOnlyCapacity,
    true,
  );
  const writableEnd = context.writableBase + context.writableCapacity;
  const vectorEnd = context.vectorBase + serviceOrder.length * 3;
  if (
    context.writableStateBase < context.writableBase ||
    context.writableStateBase >= writableEnd
  ) {
    throw new NobjError("writable state base is outside writable storage");
  }
  if (context.vectorBase < context.writableBase || vectorEnd > writableEnd) {
    throw new NobjError("vector table is outside writable storage");
  }
  if (context.vectorBase !== context.writableBase) {
    throw new NobjError("runtime vector base differs from writable base");
  }
  if (context.writableStateBase !== context.vectorBase + runtimeVectorLength) {
    throw new NobjError("runtime state does not follow the vector table");
  }
  if (
    context.programDataBase !==
    context.writableStateBase + runtimeStateLength
  ) {
    throw new NobjError("program data does not follow runtime state");
  }
  if (context.programDataBase + context.programDataCapacity > writableEnd) {
    throw new NobjError("program data exceeds writable storage");
  }
  for (const service of serviceOrder) {
    checkedWord(`${service} service address`, context.services[service]);
  }
};

const hexWord = (value: number): string =>
  `$${value.toString(16).padStart(4, "0")}`;

const contextAssembly = (context: RuntimeLinkContext): string => `
RuntimeLinkBase             .equ ${hexWord(context.runtimeBase)}
RuntimeWritableStateBase    .equ ${hexWord(context.writableStateBase)}
RuntimeProgramDataBase      .equ ${hexWord(context.programDataBase)}
RuntimeProgramDataCapacity  .equ ${hexWord(context.programDataCapacity)}
RuntimeReadOnlyBase         .equ ${hexWord(context.readOnlyBase)}
RuntimeReadOnlyCapacity     .equ ${hexWord(context.readOnlyCapacity)}
RuntimePacketService        .equ ${hexWord(context.services.packetService)}
StateBase          .equ RuntimeWritableStateBase
RunState           .equ StateBase+$00
TrapNumber         .equ StateBase+$01
TrapRoutine        .equ StateBase+$02
TrapOffset         .equ StateBase+$03
TrapError          .equ StateBase+$05
ActivationDepth    .equ StateBase+$06
ActivationLimit    .equ StateBase+$07
ScalarSlot         .equ StateBase+$08
CurrentBank        .equ ScalarSlot
ActivationArena    .equ StateBase+$09
ActivationCapacity .equ 8
RootSP             .equ ActivationArena+ActivationCapacity
RootIX             .equ RootSP+2
FarReturnArena     .equ RootIX+2
FarReturnCapacity  .equ ActivationCapacity*2
RuntimeProgramDataBaseState .equ FarReturnArena+FarReturnCapacity
RuntimeProgramDataCapacityState .equ RuntimeProgramDataBaseState+2
StateEnd           .equ RuntimeProgramDataCapacityState+2

RunReady           .equ 1
RunSucceeded       .equ 2
RunTrapped         .equ 3

GeneratedRoDataBase       .equ RuntimeReadOnlyBase
GeneratedRoDataCapacity   .equ RuntimeReadOnlyCapacity

AggregateCallSlices .equ 1
ComparisonEqual        .equ 0
ComparisonNotEqual     .equ 1
ComparisonLess         .equ 2
ComparisonLessEqual    .equ 3
ComparisonGreater      .equ 4
ComparisonGreaterEqual .equ 5
`;

const vectorBytes = (
  services: RuntimeServiceAddresses,
  packetServiceGateway: number,
): Uint8Array => {
  const bytes = new Uint8Array(serviceOrder.length * 3);
  serviceOrder.forEach((name, index) => {
    const address =
      name === "packetService" ? packetServiceGateway : services[name];
    bytes[index * 3] = 0xc3;
    bytes[index * 3 + 1] = address & 0xff;
    bytes[index * 3 + 2] = address >>> 8;
  });
  return bytes;
};

const runtimeStateBytes = (
  stateLength: number,
  runStateOffset: number,
  activationLimitOffset: number,
  programDataBaseOffset: number,
  programDataCapacityOffset: number,
  runReady: number,
  activationCapacity: number,
  context: RuntimeLinkContext,
): Uint8Array => {
  const bytes = new Uint8Array(stateLength);
  bytes[runStateOffset] = runReady;
  bytes[activationLimitOffset] = activationCapacity;
  bytes[programDataBaseOffset] = context.programDataBase & 0xff;
  bytes[programDataBaseOffset + 1] = context.programDataBase >>> 8;
  bytes[programDataCapacityOffset] = context.programDataCapacity & 0xff;
  bytes[programDataCapacityOffset + 1] = context.programDataCapacity >>> 8;
  return bytes;
};

const executableContextKey = (
  identity: number,
  context: RuntimeLinkContext,
): string =>
  JSON.stringify([
    identity,
    context.runtimeBase,
    context.writableStateBase,
    context.services.packetService,
  ]);

const resolvedImageForContext = (
  image: RuntimeImage,
  context: RuntimeLinkContext,
): RuntimeImage => {
  const packetServiceGateway = image.helperOffsets?.PacketServiceGateway;
  if (packetServiceGateway === undefined) {
    throw new NobjError("runtime catalog entry omits PacketServiceGateway");
  }
  const vectors = vectorBytes(
    context.services,
    context.runtimeBase + packetServiceGateway,
  );
  const state = image.initialBytes.slice(image.vectorBytes.length);
  if (state.length < runtimeStateLength) {
    throw new NobjError("runtime catalog entry has an obsolete state layout");
  }
  state[runtimeProgramDataBaseOffset] = context.programDataBase & 0xff;
  state[runtimeProgramDataBaseOffset + 1] = context.programDataBase >>> 8;
  state[runtimeProgramDataCapacityOffset] = context.programDataCapacity & 0xff;
  state[runtimeProgramDataCapacityOffset + 1] =
    context.programDataCapacity >>> 8;
  return {
    ...image,
    bytes: image.bytes.slice(),
    initialBytes: Uint8Array.from([...vectors, ...state]),
    vectorBytes: vectors,
    helperOffsets:
      image.helperOffsets === undefined
        ? undefined
        : { ...image.helperOffsets },
    currentBankOffset: image.currentBankOffset,
  };
};

export class CanonicalRuntimeImageProvider implements RuntimeImageProvider {
  readonly #images = new Map<string, RuntimeImage>();

  constructor(
    images: readonly {
      readonly context: RuntimeLinkContext;
      readonly image: RuntimeImage;
    }[],
  ) {
    for (const { context, image } of images) {
      this.#images.set(executableContextKey(image.identity, context), {
        ...image,
        bytes: image.bytes.slice(),
        initialBytes: image.initialBytes.slice(),
        vectorBytes: image.vectorBytes.slice(),
        helperOffsets:
          image.helperOffsets === undefined
            ? undefined
            : { ...image.helperOffsets },
        currentBankOffset: image.currentBankOffset,
      });
    }
  }

  get(identity: number, context: RuntimeLinkContext): RuntimeImage | undefined {
    validateRuntimeLinkContext(context);
    const image = this.#images.get(executableContextKey(identity, context));
    if (image === undefined) return undefined;
    return resolvedImageForContext(image, context);
  }
}

export const loadCanonicalRuntimeImage = async (
  context: RuntimeLinkContext = defaultRuntimeLinkContext,
): Promise<RuntimeImage> => {
  validateRuntimeLinkContext(context);
  // Development-only link proof. Installed consumers use runtime-catalog.ts.
  // Source adaptation preserves names; native ATOM resolves all addresses.
  const entry = "vertical-slice/nucleus-target-runtime-link.asm";
  const assembled = await assembleAtomSource(entry, {
    overrides: new Map([
      [
        "vertical-slice/nucleus-runtime-link-context.asmi",
        contextAssembly(context),
      ],
      [
        entry,
        `.include "nucleus-runtime-link-context.asmi"\n` +
          `.org RuntimeLinkBase\nRuntimeCodeStart:\n` +
          `.include "target-z80-runtime.asm"\nRuntimeCodeEnd:\n`,
      ],
    ]),
  }).catch((cause: unknown) => {
    throw new NobjError(
      `canonical runtime link failed: ${cause instanceof Error ? cause.message : String(cause)}`,
    );
  });
  const symbol = (name: string): number => {
    const wanted = name.toLowerCase();
    for (const [candidate, value] of Object.entries(assembled.symbols)) {
      if (candidate.toLowerCase() === wanted) return value;
    }
    throw new NobjError(`canonical runtime link omitted ${name}`);
  };
  const start = symbol("RuntimeCodeStart");
  const end = symbol("RuntimeCodeEnd");
  const expectedLength = symbol("NucleusRuntimeExpectedLength");
  if (start !== context.runtimeBase || end - start !== expectedLength) {
    throw new NobjError(
      `canonical runtime linked length mismatch: ${end - start}, expected ${expectedLength}`,
    );
  }
  const vectorLength = symbol("NucleusRuntimeVectorLength");
  const stateLength = symbol("NucleusRuntimeStateLength");
  const runStateOffset = symbol("RunState") - symbol("StateBase");
  const activationLimitOffset = symbol("ActivationLimit") - symbol("StateBase");
  const currentBankOffset = symbol("CurrentBank") - symbol("StateBase");
  const programDataBaseOffset =
    symbol("RuntimeProgramDataBaseState") - symbol("StateBase");
  const programDataCapacityOffset =
    symbol("RuntimeProgramDataCapacityState") - symbol("StateBase");
  if (
    runStateOffset !== symbol("NucleusRuntimeRunStateOffset") ||
    activationLimitOffset !== symbol("NucleusRuntimeActivationLimitOffset") ||
    currentBankOffset !== symbol("NucleusRuntimeCurrentBankOffset") ||
    programDataBaseOffset !== symbol("NucleusRuntimeProgramDataBaseOffset") ||
    programDataCapacityOffset !==
      symbol("NucleusRuntimeProgramDataCapacityOffset")
  ) {
    throw new NobjError("canonical runtime writable-state offset mismatch");
  }
  const writableEnd = context.writableBase + context.writableCapacity;
  if (end > 0x10000) {
    throw new NobjError("canonical runtime crosses the Z80 address space");
  }
  if (context.vectorBase !== context.writableBase) {
    throw new NobjError("runtime vector base differs from writable base");
  }
  if (context.writableStateBase !== context.vectorBase + vectorLength) {
    throw new NobjError("runtime state does not follow the vector table");
  }
  if (context.programDataBase !== context.writableStateBase + stateLength) {
    throw new NobjError("program data does not follow runtime state");
  }
  if (context.programDataBase + context.programDataCapacity > writableEnd) {
    throw new NobjError("program data exceeds writable storage");
  }
  if (context.readOnlyCapacity > 0 && context.readOnlyBase < end) {
    throw new NobjError("read-only data overlaps the linked runtime");
  }
  const helperOffsets: Record<string, number> = {};
  for (const [helper, identitySymbol] of Object.entries(
    helperIdentitySymbols,
  )) {
    const offset = symbol(helper) - start;
    if (offset !== symbol(identitySymbol)) {
      throw new NobjError(
        `canonical runtime helper offset mismatch: ${helper}`,
      );
    }
    helperOffsets[helper] = offset;
  }
  const linkedVectors = vectorBytes(
    context.services,
    symbol("PacketServiceGateway"),
  );
  if (linkedVectors.length !== vectorLength) {
    throw new NobjError("canonical runtime vector-layout mismatch");
  }
  const linkedState = runtimeStateBytes(
    stateLength,
    runStateOffset,
    activationLimitOffset,
    programDataBaseOffset,
    programDataCapacityOffset,
    symbol("RunReady"),
    symbol("ActivationCapacity"),
    context,
  );
  if (linkedState.length !== stateLength) {
    throw new NobjError("canonical runtime initial-state length mismatch");
  }
  if (symbol("StateEnd") - symbol("StateBase") !== stateLength) {
    throw new NobjError("canonical runtime writable-state layout mismatch");
  }
  return {
    identity: symbol("NucleusRuntimeIdentity"),
    bytes: parseIntelHex(assembled.hex).memory.slice(start, end),
    initialBytes: Uint8Array.from([...linkedVectors, ...linkedState]),
    vectorBytes: linkedVectors,
    helperOffsets,
    currentBankOffset,
  };
};

export const loadCanonicalRuntimeProvider = async (
  contexts: readonly RuntimeLinkContext[] = [defaultRuntimeLinkContext],
): Promise<CanonicalRuntimeImageProvider> =>
  new CanonicalRuntimeImageProvider(
    await Promise.all(
      contexts.map(async (context) => ({
        context,
        image: await loadCanonicalRuntimeImage(context),
      })),
    ),
  );
