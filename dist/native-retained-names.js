export const nativeRetainedNameEntryCapacity = 1024;
export const nativeRetainedNameByteCapacity = 0xffff;
export class NativeRetainedNameStore {
    #entries = new Map();
    #entryCapacity;
    #byteCapacity;
    #nextHandle = 1;
    #usedBytes = 0;
    constructor(entryCapacity = nativeRetainedNameEntryCapacity, byteCapacity = nativeRetainedNameByteCapacity) {
        if (!Number.isInteger(entryCapacity) ||
            entryCapacity < 1 ||
            entryCapacity > 0xffff) {
            throw new RangeError("retained-name entry capacity must be 1..65535");
        }
        if (!Number.isInteger(byteCapacity) ||
            byteCapacity < 1 ||
            byteCapacity > 0xffff) {
            throw new RangeError("retained-name byte capacity must be 1..65535");
        }
        this.#entryCapacity = entryCapacity;
        this.#byteCapacity = byteCapacity;
    }
    retain(name) {
        const length = name.bytes.length;
        if (length < 1 ||
            this.#entries.size >= this.#entryCapacity ||
            length > this.#byteCapacity - this.#usedBytes ||
            this.#nextHandle > 0xffff) {
            throw new Error("native retained-name capacity exceeded");
        }
        const handle = this.#nextHandle;
        const bytes = name.bytes.slice();
        this.#entries.set(handle, { bytes, part: name.part, offset: name.offset });
        this.#nextHandle += 1;
        this.#usedBytes += length;
        return handle;
    }
    get(handle) {
        return this.#entries.get(handle);
    }
    compare(handle, bytes) {
        const retained = this.#entries.get(handle);
        if (retained === undefined)
            return "invalid";
        if (retained.bytes.length !== bytes.length)
            return "unequal";
        for (let index = 0; index < bytes.length; index += 1) {
            if (retained.bytes[index] !== bytes[index])
                return "unequal";
        }
        return "equal";
    }
    clear() {
        this.#entries.clear();
        this.#nextHandle = 1;
        this.#usedBytes = 0;
    }
    usage() {
        return { entries: this.#entries.size, bytes: this.#usedBytes };
    }
}
