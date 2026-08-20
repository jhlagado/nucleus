import {
  closeSync,
  fsyncSync,
  openSync,
  readSync,
  renameSync,
  unlinkSync,
  writeSync,
} from "node:fs";
import { basename, dirname, join } from "node:path";

import type {
  NobjSequentialOutput,
  NobjSpool,
  NobjSpoolFactory,
} from "./nobj.js";

let temporaryOrdinal = 0;

const temporaryPath = (directory: string, stem: string): string => {
  temporaryOrdinal += 1;
  return join(directory, `.${stem}.${process.pid}.${temporaryOrdinal}.tmp`);
};

/** Append-only file spool with bounded sequential reads. */
export class NodeFileNobjSpool implements NobjSpool {
  readonly #path: string;
  readonly #chunkBytes: number;
  #descriptor: number | undefined;
  #byteLength = 0;

  constructor(directory: string, chunkBytes = 4096) {
    if (!Number.isInteger(chunkBytes) || chunkBytes < 1) {
      throw new RangeError("NOBJ spool chunk size must be a positive integer");
    }
    this.#path = temporaryPath(directory, "nobj-spool");
    this.#chunkBytes = chunkBytes;
  }

  get byteLength(): number {
    return this.#byteLength;
  }

  append(bytes: Uint8Array): void {
    const descriptor = this.#open();
    let offset = 0;
    while (offset < bytes.length) {
      const written = writeSync(
        descriptor,
        bytes,
        offset,
        bytes.length - offset,
      );
      if (written === 0) throw new Error("NOBJ spool write made no progress");
      offset += written;
    }
    this.#byteLength += bytes.length;
  }

  *chunks(): Iterable<Uint8Array> {
    if (this.#byteLength === 0) return;
    const descriptor = this.#open();
    let position = 0;
    while (position < this.#byteLength) {
      const length = Math.min(this.#chunkBytes, this.#byteLength - position);
      const chunk = new Uint8Array(length);
      const read = readSync(descriptor, chunk, 0, length, position);
      if (read !== length) throw new Error("NOBJ spool read was truncated");
      position += read;
      yield chunk;
    }
  }

  clear(): void {
    if (this.#descriptor !== undefined) {
      closeSync(this.#descriptor);
      this.#descriptor = undefined;
    }
    this.#byteLength = 0;
    try {
      unlinkSync(this.#path);
    } catch (error) {
      if (errorCode(error) !== "ENOENT") throw error;
    }
  }

  #open(): number {
    this.#descriptor ??= openSync(this.#path, "wx+", 0o600);
    return this.#descriptor;
  }
}

export const nodeFileNobjSpoolFactory =
  (directory: string, chunkBytes = 4096): NobjSpoolFactory =>
  () =>
    new NodeFileNobjSpool(directory, chunkBytes);

/**
 * Sequential file destination that replaces the published NOBJ only after
 * COMMIT has been written and synchronized.
 */
export class NodeFileNobjOutput implements NobjSequentialOutput {
  readonly #destination: string;
  readonly #temporary: string;
  #descriptor: number | undefined;
  #finished = false;

  constructor(destination: string) {
    this.#destination = destination;
    this.#temporary = temporaryPath(
      dirname(destination),
      basename(destination),
    );
  }

  write(bytes: Uint8Array): void {
    const descriptor = this.#openForWrite();
    let offset = 0;
    while (offset < bytes.length) {
      const written = writeSync(
        descriptor,
        bytes,
        offset,
        bytes.length - offset,
      );
      if (written === 0) throw new Error("NOBJ file write made no progress");
      offset += written;
    }
  }

  commit(): void {
    const descriptor = this.#requireOpen();
    fsyncSync(descriptor);
    closeSync(descriptor);
    this.#descriptor = undefined;
    renameSync(this.#temporary, this.#destination);
    this.#finished = true;
  }

  abort(): void {
    if (this.#finished) return;
    if (this.#descriptor !== undefined) {
      closeSync(this.#descriptor);
      this.#descriptor = undefined;
    }
    try {
      unlinkSync(this.#temporary);
    } catch (error) {
      if (errorCode(error) !== "ENOENT") throw error;
    }
  }

  #requireOpen(): number {
    if (this.#descriptor === undefined || this.#finished) {
      throw new Error("NOBJ file generation is not open");
    }
    return this.#descriptor;
  }

  #openForWrite(): number {
    if (this.#finished) throw new Error("NOBJ file generation is not open");
    this.#descriptor ??= openSync(this.#temporary, "wx", 0o600);
    return this.#descriptor;
  }
}

const errorCode = (error: unknown): unknown =>
  typeof error === "object" && error !== null && "code" in error
    ? error.code
    : undefined;
