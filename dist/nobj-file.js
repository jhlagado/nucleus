import { closeSync, fsyncSync, openSync, readSync, renameSync, unlinkSync, writeSync, } from "node:fs";
import { basename, dirname, join } from "node:path";
let temporaryOrdinal = 0;
const temporaryPath = (directory, stem) => {
    temporaryOrdinal += 1;
    return join(directory, `.${stem}.${process.pid}.${temporaryOrdinal}.tmp`);
};
/** Append-only file spool with bounded sequential reads. */
export class NodeFileNobjSpool {
    #path;
    #chunkBytes;
    #descriptor;
    #byteLength = 0;
    constructor(directory, chunkBytes = 4096) {
        if (!Number.isInteger(chunkBytes) || chunkBytes < 1) {
            throw new RangeError("NOBJ spool chunk size must be a positive integer");
        }
        this.#path = temporaryPath(directory, "nobj-spool");
        this.#chunkBytes = chunkBytes;
    }
    get byteLength() {
        return this.#byteLength;
    }
    append(bytes) {
        const descriptor = this.#open();
        let offset = 0;
        while (offset < bytes.length) {
            const written = writeSync(descriptor, bytes, offset, bytes.length - offset);
            if (written === 0)
                throw new Error("NOBJ spool write made no progress");
            offset += written;
        }
        this.#byteLength += bytes.length;
    }
    *chunks() {
        if (this.#byteLength === 0)
            return;
        const descriptor = this.#open();
        let position = 0;
        while (position < this.#byteLength) {
            const length = Math.min(this.#chunkBytes, this.#byteLength - position);
            const chunk = new Uint8Array(length);
            const read = readSync(descriptor, chunk, 0, length, position);
            if (read !== length)
                throw new Error("NOBJ spool read was truncated");
            position += read;
            yield chunk;
        }
    }
    clear() {
        if (this.#descriptor !== undefined) {
            closeSync(this.#descriptor);
            this.#descriptor = undefined;
        }
        this.#byteLength = 0;
        try {
            unlinkSync(this.#path);
        }
        catch (error) {
            if (errorCode(error) !== "ENOENT")
                throw error;
        }
    }
    #open() {
        this.#descriptor ??= openSync(this.#path, "wx+", 0o600);
        return this.#descriptor;
    }
}
export const nodeFileNobjSpoolFactory = (directory, chunkBytes = 4096) => () => new NodeFileNobjSpool(directory, chunkBytes);
/**
 * Sequential file destination that replaces the published NOBJ only after
 * COMMIT has been written and synchronized.
 */
export class NodeFileNobjOutput {
    #destination;
    #temporary;
    #descriptor;
    #finished = false;
    constructor(destination) {
        this.#destination = destination;
        this.#temporary = temporaryPath(dirname(destination), basename(destination));
    }
    write(bytes) {
        const descriptor = this.#openForWrite();
        let offset = 0;
        while (offset < bytes.length) {
            const written = writeSync(descriptor, bytes, offset, bytes.length - offset);
            if (written === 0)
                throw new Error("NOBJ file write made no progress");
            offset += written;
        }
    }
    commit() {
        const descriptor = this.#requireOpen();
        fsyncSync(descriptor);
        closeSync(descriptor);
        this.#descriptor = undefined;
        renameSync(this.#temporary, this.#destination);
        this.#finished = true;
    }
    abort() {
        if (this.#finished)
            return;
        if (this.#descriptor !== undefined) {
            closeSync(this.#descriptor);
            this.#descriptor = undefined;
        }
        try {
            unlinkSync(this.#temporary);
        }
        catch (error) {
            if (errorCode(error) !== "ENOENT")
                throw error;
        }
    }
    #requireOpen() {
        if (this.#descriptor === undefined || this.#finished) {
            throw new Error("NOBJ file generation is not open");
        }
        return this.#descriptor;
    }
    #openForWrite() {
        if (this.#finished)
            throw new Error("NOBJ file generation is not open");
        this.#descriptor ??= openSync(this.#temporary, "wx", 0o600);
        return this.#descriptor;
    }
}
const errorCode = (error) => typeof error === "object" && error !== null && "code" in error
    ? error.code
    : undefined;
