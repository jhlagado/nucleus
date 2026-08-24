import { closeSync, existsSync, fsyncSync, openSync, readSync, realpathSync, renameSync, unlinkSync, writeSync, } from "node:fs";
import path from "node:path";
export const NUCLEUS_OBJECT_ABI_VERSION = 1;
export const NUCLEUS_OBJECT_REQUEST_SIZE = 16;
export const NucleusObjectRequest = {
    size: 0,
    abi: 1,
    operation: 2,
    flags: 3,
    handle: 4,
    pointer: 6,
    length: 8,
    offset: 10,
    result: 14,
};
export const NucleusObjectOperation = {
    openRead: 0,
    beginWrite: 1,
    read: 2,
    write: 3,
    rewind: 4,
    seek: 5,
    close: 6,
    commit: 7,
    abort: 8,
};
export const NucleusSystemStatus = {
    success: 0,
    invalid: 1,
    unavailable: 2,
    notFound: 3,
    capacity: 4,
    access: 5,
    storage: 6,
    conflict: 7,
    cancelled: 8,
    unsupported: 9,
};
const readWord = (memory, at) => memory[at] | (memory[at + 1] << 8);
const writeWord = (memory, at, value) => {
    memory[at] = value & 0xff;
    memory[at + 1] = value >>> 8;
};
const readDword = (memory, at) => readWord(memory, at) + readWord(memory, at + 2) * 0x10000;
const rangeIsValid = (memory, pointer, length) => pointer >= 0 && length >= 0 && pointer + length <= memory.length;
const errorCode = (error) => typeof error === "object" && error !== null && "code" in error
    ? String(error.code)
    : undefined;
const statusForError = (error) => {
    switch (errorCode(error)) {
        case "ENOENT":
            return NucleusSystemStatus.notFound;
        case "EACCES":
        case "EPERM":
        case "EROFS":
            return NucleusSystemStatus.access;
        case "EMFILE":
        case "ENFILE":
        case "ENOSPC":
            return NucleusSystemStatus.capacity;
        default:
            return NucleusSystemStatus.storage;
    }
};
const within = (root, candidate) => {
    const relative = path.relative(root, candidate);
    return (relative === "" ||
        (relative !== ".." &&
            !relative.startsWith(`..${path.sep}`) &&
            !path.isAbsolute(relative)));
};
const requestHasZero = (memory, request, offsets) => offsets.every((offset) => memory[request + offset] === 0);
/** Filesystem-backed reference provider for named-object services ABI 1. */
export class NodeNamedObjectServices {
    #root;
    #maxHandles;
    #handles = new Map();
    #nextHandle = 1;
    #temporaryOrdinal = 0;
    constructor(root, options = {}) {
        this.#root = realpathSync(root);
        this.#maxHandles = options.maxHandles ?? 16;
        if (!Number.isInteger(this.#maxHandles) ||
            this.#maxHandles < 1 ||
            this.#maxHandles > 0xffff) {
            throw new RangeError("maxHandles must be in the range 1..65535");
        }
    }
    get openHandleCount() {
        return this.#handles.size;
    }
    /** Execute one request in Z80 memory and return its canonical status. */
    dispatch(memory, request) {
        if (!rangeIsValid(memory, request, NUCLEUS_OBJECT_REQUEST_SIZE)) {
            return NucleusSystemStatus.invalid;
        }
        writeWord(memory, request + NucleusObjectRequest.result, 0);
        if (memory[request + NucleusObjectRequest.size] !==
            NUCLEUS_OBJECT_REQUEST_SIZE ||
            memory[request + NucleusObjectRequest.abi] !==
                NUCLEUS_OBJECT_ABI_VERSION ||
            memory[request + NucleusObjectRequest.flags] !== 0) {
            return NucleusSystemStatus.invalid;
        }
        const operation = memory[request + NucleusObjectRequest.operation];
        const handleNumber = readWord(memory, request + NucleusObjectRequest.handle);
        const pointer = readWord(memory, request + NucleusObjectRequest.pointer);
        const length = readWord(memory, request + NucleusObjectRequest.length);
        const offset = readDword(memory, request + NucleusObjectRequest.offset);
        try {
            switch (operation) {
                case NucleusObjectOperation.openRead:
                case NucleusObjectOperation.beginWrite:
                    if (handleNumber !== 0 || offset !== 0 || length < 1 || length > 255) {
                        return NucleusSystemStatus.invalid;
                    }
                    return this.#open(memory, request, pointer, length, operation === NucleusObjectOperation.beginWrite);
                case NucleusObjectOperation.read:
                case NucleusObjectOperation.write:
                    if (offset !== 0 || !rangeIsValid(memory, pointer, length)) {
                        return NucleusSystemStatus.invalid;
                    }
                    return this.#transfer(memory, request, handleNumber, pointer, length, operation === NucleusObjectOperation.write);
                case NucleusObjectOperation.rewind:
                case NucleusObjectOperation.close:
                case NucleusObjectOperation.commit:
                case NucleusObjectOperation.abort:
                    if (pointer !== 0 ||
                        length !== 0 ||
                        offset !== 0 ||
                        !requestHasZero(memory, request, [14, 15])) {
                        return NucleusSystemStatus.invalid;
                    }
                    return this.#terminal(operation, handleNumber);
                case NucleusObjectOperation.seek:
                    if (pointer !== 0 || length !== 0) {
                        return NucleusSystemStatus.invalid;
                    }
                    return this.#seek(handleNumber, offset);
                default:
                    return NucleusSystemStatus.invalid;
            }
        }
        catch (error) {
            return statusForError(error);
        }
    }
    abortAll() {
        for (const [handle, state] of [...this.#handles]) {
            if (state.kind === "read") {
                try {
                    closeSync(state.descriptor);
                }
                catch {
                    // The handle table must still be recoverable after outer failure.
                }
                this.#handles.delete(handle);
            }
            else {
                this.#abort(handle, state);
            }
        }
    }
    #allocate(state) {
        if (this.#handles.size >= this.#maxHandles)
            return undefined;
        for (let attempts = 0; attempts < 0xffff; attempts += 1) {
            const candidate = this.#nextHandle;
            this.#nextHandle = candidate === 0xffff ? 1 : candidate + 1;
            if (!this.#handles.has(candidate)) {
                this.#handles.set(candidate, state);
                return candidate;
            }
        }
        return undefined;
    }
    #name(memory, pointer, length) {
        if (!rangeIsValid(memory, pointer, length))
            return undefined;
        const bytes = memory.subarray(pointer, pointer + length);
        if (bytes.some((byte) => byte < 0x20 || byte > 0x7e) ||
            bytes.includes(0x5c)) {
            return undefined;
        }
        const name = Buffer.from(bytes).toString("ascii");
        const normalized = path.posix.normalize(name);
        if (normalized === "." ||
            normalized === ".." ||
            normalized.startsWith("../") ||
            normalized.startsWith("/")) {
            return undefined;
        }
        return normalized;
    }
    #path(name, writing) {
        const candidate = path.resolve(this.#root, ...name.split("/"));
        if (!within(this.#root, candidate)) {
            throw Object.assign(new Error("object path escapes provider root"), {
                code: "EACCES",
            });
        }
        if (writing) {
            const parent = realpathSync(path.dirname(candidate));
            if (!within(this.#root, parent)) {
                throw Object.assign(new Error("object parent escapes provider root"), {
                    code: "EACCES",
                });
            }
            return candidate;
        }
        const physical = realpathSync(candidate);
        if (!within(this.#root, physical)) {
            throw Object.assign(new Error("object escapes provider root"), {
                code: "EACCES",
            });
        }
        return physical;
    }
    #open(memory, request, pointer, length, writing) {
        const name = this.#name(memory, pointer, length);
        if (name === undefined)
            return NucleusSystemStatus.invalid;
        const target = this.#path(name, writing);
        if (writing &&
            [...this.#handles.values()].some((state) => state.kind === "write" && state.target === target)) {
            return NucleusSystemStatus.conflict;
        }
        let state;
        if (writing) {
            let temporary;
            let descriptor;
            do {
                this.#temporaryOrdinal += 1;
                temporary = `${target}.nucleus-${process.pid}-${this.#temporaryOrdinal}.tmp`;
            } while (existsSync(temporary));
            descriptor = openSync(temporary, "wx+");
            state = {
                kind: "write",
                descriptor,
                target,
                temporary,
                cursor: 0,
                poisoned: false,
            };
        }
        else {
            state = { kind: "read", descriptor: openSync(target, "r"), cursor: 0 };
        }
        const handle = this.#allocate(state);
        if (handle === undefined) {
            if (state.kind === "read")
                closeSync(state.descriptor);
            else {
                closeSync(state.descriptor);
                unlinkSync(state.temporary);
            }
            return NucleusSystemStatus.capacity;
        }
        writeWord(memory, request + NucleusObjectRequest.handle, handle);
        return NucleusSystemStatus.success;
    }
    #transfer(memory, request, handleNumber, pointer, length, writing) {
        const state = this.#handles.get(handleNumber);
        if (state === undefined) {
            return NucleusSystemStatus.invalid;
        }
        if (state.kind === "write" &&
            (state.poisoned || state.descriptor === undefined)) {
            return NucleusSystemStatus.invalid;
        }
        if (writing && state.kind !== "write")
            return NucleusSystemStatus.invalid;
        if (length === 0)
            return NucleusSystemStatus.success;
        const bytes = memory.subarray(pointer, pointer + length);
        if (!writing) {
            const count = readSync(state.descriptor, bytes, 0, length, state.cursor);
            state.cursor += count;
            writeWord(memory, request + NucleusObjectRequest.result, count);
            return NucleusSystemStatus.success;
        }
        if (state.kind !== "write")
            return NucleusSystemStatus.invalid;
        const start = state.cursor;
        try {
            let written = 0;
            while (written < length) {
                const count = writeSync(state.descriptor, bytes, written, length - written, start + written);
                if (count === 0)
                    throw new Error("zero-byte object write");
                written += count;
            }
            state.cursor += written;
            writeWord(memory, request + NucleusObjectRequest.result, written);
            return NucleusSystemStatus.success;
        }
        catch (error) {
            state.poisoned = true;
            return statusForError(error);
        }
    }
    #seek(handleNumber, offset) {
        const state = this.#handles.get(handleNumber);
        if (state === undefined || (state.kind === "write" && state.poisoned)) {
            return NucleusSystemStatus.invalid;
        }
        state.cursor = offset;
        return NucleusSystemStatus.success;
    }
    #terminal(operation, handleNumber) {
        const state = this.#handles.get(handleNumber);
        if (state === undefined)
            return NucleusSystemStatus.invalid;
        if (operation === NucleusObjectOperation.rewind) {
            if (state.kind === "write" && state.poisoned) {
                return NucleusSystemStatus.invalid;
            }
            state.cursor = 0;
            return NucleusSystemStatus.success;
        }
        if (operation === NucleusObjectOperation.close) {
            if (state.kind !== "read")
                return NucleusSystemStatus.invalid;
            closeSync(state.descriptor);
            this.#handles.delete(handleNumber);
            return NucleusSystemStatus.success;
        }
        if (operation === NucleusObjectOperation.commit) {
            if (state.kind !== "write" || state.poisoned) {
                return NucleusSystemStatus.invalid;
            }
            if (state.descriptor !== undefined) {
                fsyncSync(state.descriptor);
                closeSync(state.descriptor);
                state.descriptor = undefined;
            }
            renameSync(state.temporary, state.target);
            this.#handles.delete(handleNumber);
            return NucleusSystemStatus.success;
        }
        if (operation === NucleusObjectOperation.abort && state.kind === "write") {
            return this.#abort(handleNumber, state);
        }
        return NucleusSystemStatus.invalid;
    }
    #abort(handleNumber, state) {
        this.#handles.delete(handleNumber);
        let status = NucleusSystemStatus.success;
        if (state.descriptor !== undefined) {
            try {
                closeSync(state.descriptor);
            }
            catch (error) {
                status = statusForError(error);
            }
        }
        try {
            if (existsSync(state.temporary))
                unlinkSync(state.temporary);
        }
        catch (error) {
            status = statusForError(error);
        }
        return status;
    }
}
