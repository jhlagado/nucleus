export interface NativeRetainedName {
  readonly bytes: Uint8Array;
  readonly part: number;
  readonly offset: number;
}

export interface NativeRetainedNameUsage {
  readonly entries: number;
  readonly bytes: number;
}

export type NativeRetainedNameComparison = "equal" | "unequal" | "invalid";

export const nativeRetainedNameEntryCapacity = 1024;
export const nativeRetainedNameByteCapacity = 0xffff;

export class NativeRetainedNameStore {
  readonly #entries = new Map<number, NativeRetainedName>();
  readonly #entryCapacity: number;
  readonly #byteCapacity: number;
  #nextHandle = 1;
  #usedBytes = 0;

  constructor(
    entryCapacity = nativeRetainedNameEntryCapacity,
    byteCapacity = nativeRetainedNameByteCapacity,
  ) {
    if (
      !Number.isInteger(entryCapacity) ||
      entryCapacity < 1 ||
      entryCapacity > 0xffff
    ) {
      throw new RangeError("retained-name entry capacity must be 1..65535");
    }
    if (
      !Number.isInteger(byteCapacity) ||
      byteCapacity < 1 ||
      byteCapacity > 0xffff
    ) {
      throw new RangeError("retained-name byte capacity must be 1..65535");
    }
    this.#entryCapacity = entryCapacity;
    this.#byteCapacity = byteCapacity;
  }

  retain(name: NativeRetainedName): number {
    const length = name.bytes.length;
    if (
      length < 1 ||
      this.#entries.size >= this.#entryCapacity ||
      length > this.#byteCapacity - this.#usedBytes ||
      this.#nextHandle > 0xffff
    ) {
      throw new Error("native retained-name capacity exceeded");
    }
    const handle = this.#nextHandle;
    const bytes = name.bytes.slice();
    this.#entries.set(handle, { bytes, part: name.part, offset: name.offset });
    this.#nextHandle += 1;
    this.#usedBytes += length;
    return handle;
  }

  get(handle: number): NativeRetainedName | undefined {
    return this.#entries.get(handle);
  }

  compare(handle: number, bytes: Uint8Array): NativeRetainedNameComparison {
    const retained = this.#entries.get(handle);
    if (retained === undefined) return "invalid";
    if (retained.bytes.length !== bytes.length) return "unequal";
    for (let index = 0; index < bytes.length; index += 1) {
      if (retained.bytes[index] !== bytes[index]) return "unequal";
    }
    return "equal";
  }

  clear(): void {
    this.#entries.clear();
    this.#nextHandle = 1;
    this.#usedBytes = 0;
  }

  usage(): NativeRetainedNameUsage {
    return { entries: this.#entries.size, bytes: this.#usedBytes };
  }
}
