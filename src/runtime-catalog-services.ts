import {
  type RuntimeImageProvider,
  type RuntimeLinkContext,
  type RuntimeServiceAddresses,
} from "./nobj.js";
import {
  NucleusSystemStatus,
  type NucleusSystemStatusCode,
} from "./object-services.js";

export const NUCLEUS_RUNTIME_CATALOG_ABI_VERSION = 1;
export const NUCLEUS_RUNTIME_CATALOG_REQUEST_SIZE = 22;

export const NucleusRuntimeCatalogOperation = {
  code: 0,
  initial: 1,
} as const;

export const NucleusRuntimeCatalogRequest = {
  size: 0,
  abi: 1,
  operation: 2,
  flags: 3,
  bank: 4,
  reservedByte: 5,
  identity: 6,
  expectedLength: 8,
  contextPointer: 10,
  offset: 12,
  pointer: 14,
  capacity: 16,
  result: 18,
  reservedWord: 20,
} as const;

const readWord = (memory: Uint8Array, at: number): number =>
  memory[at]! | (memory[at + 1]! << 8);

const writeWord = (memory: Uint8Array, at: number, value: number): void => {
  memory[at] = value & 0xff;
  memory[at + 1] = value >>> 8;
};

const within = (memory: Uint8Array, pointer: number, length: number): boolean =>
  pointer >= 0 && length >= 0 && pointer + length <= memory.length;

const contextFromMemory = (
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

/** Reference provider for the Z80 runtime-catalogue chunk ABI. */
export class NodeRuntimeCatalogServices {
  public constructor(
    readonly provider: RuntimeImageProvider,
    readonly services: RuntimeServiceAddresses,
  ) {}

  public dispatch(
    memory: Uint8Array,
    request: number,
  ): NucleusSystemStatusCode {
    if (!within(memory, request, NUCLEUS_RUNTIME_CATALOG_REQUEST_SIZE)) {
      return NucleusSystemStatus.invalid;
    }
    writeWord(memory, request + NucleusRuntimeCatalogRequest.result, 0);
    const flags = memory[request + NucleusRuntimeCatalogRequest.flags]!;
    const operation = memory[request + NucleusRuntimeCatalogRequest.operation]!;
    const bank = memory[request + NucleusRuntimeCatalogRequest.bank]!;
    const contextPointer = readWord(
      memory,
      request + NucleusRuntimeCatalogRequest.contextPointer,
    );
    const destination = readWord(
      memory,
      request + NucleusRuntimeCatalogRequest.pointer,
    );
    const capacity = readWord(
      memory,
      request + NucleusRuntimeCatalogRequest.capacity,
    );
    if (
      memory[request + NucleusRuntimeCatalogRequest.size] !==
        NUCLEUS_RUNTIME_CATALOG_REQUEST_SIZE ||
      memory[request + NucleusRuntimeCatalogRequest.abi] !==
        NUCLEUS_RUNTIME_CATALOG_ABI_VERSION ||
      operation > NucleusRuntimeCatalogOperation.initial ||
      (flags & ~1) !== 0 ||
      (flags === 0 && bank !== 0) ||
      memory[request + NucleusRuntimeCatalogRequest.reservedByte] !== 0 ||
      readWord(memory, request + NucleusRuntimeCatalogRequest.reservedWord) !==
        0 ||
      !within(memory, contextPointer, 18) ||
      !within(memory, destination, capacity)
    ) {
      return NucleusSystemStatus.invalid;
    }

    try {
      const identity = readWord(
        memory,
        request + NucleusRuntimeCatalogRequest.identity,
      );
      const expectedLength = readWord(
        memory,
        request + NucleusRuntimeCatalogRequest.expectedLength,
      );
      const offset = readWord(
        memory,
        request + NucleusRuntimeCatalogRequest.offset,
      );
      const image = this.provider.get(
        identity,
        contextFromMemory(memory, contextPointer, this.services),
      );
      if (image === undefined) return NucleusSystemStatus.unavailable;
      if (image.identity !== identity) return NucleusSystemStatus.invalid;

      const selected =
        operation === NucleusRuntimeCatalogOperation.code
          ? image.bytes
          : image.initialBytes.slice();
      if (selected.length !== expectedLength || offset > selected.length) {
        return NucleusSystemStatus.invalid;
      }
      if (operation === NucleusRuntimeCatalogOperation.initial && flags !== 0) {
        const currentBankOffset = image.currentBankOffset;
        if (currentBankOffset === undefined) {
          return NucleusSystemStatus.invalid;
        }
        const stateIndex = image.vectorBytes.length + currentBankOffset;
        if (stateIndex >= selected.length) return NucleusSystemStatus.invalid;
        selected[stateIndex] = bank;
      }
      const count = Math.min(capacity, selected.length - offset);
      memory.set(selected.subarray(offset, offset + count), destination);
      writeWord(memory, request + NucleusRuntimeCatalogRequest.result, count);
      return NucleusSystemStatus.success;
    } catch {
      return NucleusSystemStatus.invalid;
    }
  }
}
