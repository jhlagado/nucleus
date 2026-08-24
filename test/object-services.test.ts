import { mkdtempSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";

import { describe, expect, it } from "vitest";

import {
  NodeNamedObjectServices,
  NUCLEUS_OBJECT_ABI_VERSION,
  NUCLEUS_OBJECT_REQUEST_SIZE,
  NucleusObjectOperation,
  NucleusObjectRequest,
  NucleusSystemStatus,
} from "../src/object-services.js";

const requestAt = 0x100;
const bytesAt = 0x200;

const writeWord = (memory: Uint8Array, at: number, value: number): void => {
  memory[at] = value & 0xff;
  memory[at + 1] = value >>> 8;
};

const readWord = (memory: Uint8Array, at: number): number =>
  memory[at]! | (memory[at + 1]! << 8);

const writeDword = (memory: Uint8Array, at: number, value: number): void => {
  writeWord(memory, at, value & 0xffff);
  writeWord(memory, at + 2, Math.floor(value / 0x10000));
};

const request = (
  memory: Uint8Array,
  operation: number,
  fields: {
    readonly handle?: number;
    readonly pointer?: number;
    readonly length?: number;
    readonly offset?: number;
  } = {},
): void => {
  memory.fill(0, requestAt, requestAt + NUCLEUS_OBJECT_REQUEST_SIZE);
  memory[requestAt + NucleusObjectRequest.size] =
    NUCLEUS_OBJECT_REQUEST_SIZE;
  memory[requestAt + NucleusObjectRequest.abi] = NUCLEUS_OBJECT_ABI_VERSION;
  memory[requestAt + NucleusObjectRequest.operation] = operation;
  writeWord(
    memory,
    requestAt + NucleusObjectRequest.handle,
    fields.handle ?? 0,
  );
  writeWord(
    memory,
    requestAt + NucleusObjectRequest.pointer,
    fields.pointer ?? 0,
  );
  writeWord(
    memory,
    requestAt + NucleusObjectRequest.length,
    fields.length ?? 0,
  );
  writeDword(
    memory,
    requestAt + NucleusObjectRequest.offset,
    fields.offset ?? 0,
  );
};

const put = (memory: Uint8Array, value: string, at = bytesAt): number => {
  const bytes = Buffer.from(value, "ascii");
  memory.set(bytes, at);
  return bytes.length;
};

const open = (
  services: NodeNamedObjectServices,
  memory: Uint8Array,
  name: string,
  operation: number = NucleusObjectOperation.openRead,
): number => {
  const length = put(memory, name);
  request(memory, operation, { pointer: bytesAt, length });
  expect(services.dispatch(memory, requestAt)).toBe(NucleusSystemStatus.success);
  return readWord(memory, requestAt + NucleusObjectRequest.handle);
};

describe("named-object services ABI 1", () => {
  it("reads bounded chunks, distinguishes EOF, and keeps independent cursors", () => {
    const root = mkdtempSync(path.join(tmpdir(), "nucleus-objects-"));
    writeFileSync(path.join(root, "source.nu"), "abcdef");
    const services = new NodeNamedObjectServices(root);
    const memory = new Uint8Array(0x10000);
    const first = open(services, memory, "source.nu");
    const second = open(services, memory, "source.nu");

    request(memory, NucleusObjectOperation.read, {
      handle: first,
      pointer: bytesAt,
      length: 4,
    });
    expect(services.dispatch(memory, requestAt)).toBe(0);
    expect(readWord(memory, requestAt + NucleusObjectRequest.result)).toBe(4);
    expect(Buffer.from(memory.subarray(bytesAt, bytesAt + 4)).toString()).toBe(
      "abcd",
    );

    request(memory, NucleusObjectOperation.read, {
      handle: first,
      pointer: bytesAt,
      length: 4,
    });
    expect(services.dispatch(memory, requestAt)).toBe(0);
    expect(readWord(memory, requestAt + NucleusObjectRequest.result)).toBe(2);
    request(memory, NucleusObjectOperation.read, {
      handle: first,
      pointer: bytesAt,
      length: 4,
    });
    expect(services.dispatch(memory, requestAt)).toBe(0);
    expect(readWord(memory, requestAt + NucleusObjectRequest.result)).toBe(0);

    request(memory, NucleusObjectOperation.read, {
      handle: second,
      pointer: bytesAt,
      length: 1,
    });
    expect(services.dispatch(memory, requestAt)).toBe(0);
    expect(memory[bytesAt]).toBe("a".charCodeAt(0));

    request(memory, NucleusObjectOperation.rewind, { handle: first });
    expect(services.dispatch(memory, requestAt)).toBe(0);
    request(memory, NucleusObjectOperation.read, {
      handle: first,
      pointer: bytesAt,
      length: 1,
    });
    expect(services.dispatch(memory, requestAt)).toBe(0);
    expect(memory[bytesAt]).toBe("a".charCodeAt(0));
    services.abortAll();
    expect(services.openHandleCount).toBe(0);
  });

  it("keeps tentative replacements private until commit and preserves old data on abort", () => {
    const root = mkdtempSync(path.join(tmpdir(), "nucleus-objects-"));
    const target = path.join(root, "program.nobj");
    writeFileSync(target, "old");
    const services = new NodeNamedObjectServices(root);
    const memory = new Uint8Array(0x10000);

    let handle = open(
      services,
      memory,
      "program.nobj",
      NucleusObjectOperation.beginWrite,
    );
    const length = put(memory, "discarded");
    request(memory, NucleusObjectOperation.write, {
      handle,
      pointer: bytesAt,
      length,
    });
    expect(services.dispatch(memory, requestAt)).toBe(0);
    expect(readFileSync(target, "utf8")).toBe("old");
    request(memory, NucleusObjectOperation.abort, { handle });
    expect(services.dispatch(memory, requestAt)).toBe(0);
    expect(readFileSync(target, "utf8")).toBe("old");

    handle = open(
      services,
      memory,
      "program.nobj",
      NucleusObjectOperation.beginWrite,
    );
    const replacementLength = put(memory, "new object");
    request(memory, NucleusObjectOperation.write, {
      handle,
      pointer: bytesAt,
      length: replacementLength,
    });
    expect(services.dispatch(memory, requestAt)).toBe(0);
    request(memory, NucleusObjectOperation.commit, { handle });
    expect(services.dispatch(memory, requestAt)).toBe(0);
    expect(readFileSync(target, "utf8")).toBe("new object");

    request(memory, NucleusObjectOperation.commit, { handle });
    expect(services.dispatch(memory, requestAt)).toBe(
      NucleusSystemStatus.invalid,
    );
  });

  it("supports 32-bit seek, zero-filled gaps, conflicts, and bounded handles", () => {
    const root = mkdtempSync(path.join(tmpdir(), "nucleus-objects-"));
    mkdirSync(path.join(root, "build"));
    const services = new NodeNamedObjectServices(root, { maxHandles: 1 });
    const memory = new Uint8Array(0x10000);
    const handle = open(
      services,
      memory,
      "build/large.bin",
      NucleusObjectOperation.beginWrite,
    );

    const nameLength = put(memory, "build/large.bin");
    request(memory, NucleusObjectOperation.beginWrite, {
      pointer: bytesAt,
      length: nameLength,
    });
    expect(services.dispatch(memory, requestAt)).toBe(
      NucleusSystemStatus.conflict,
    );

    request(memory, NucleusObjectOperation.seek, {
      handle,
      offset: 0x1_0002,
    });
    expect(services.dispatch(memory, requestAt)).toBe(0);
    put(memory, "Z");
    request(memory, NucleusObjectOperation.write, {
      handle,
      pointer: bytesAt,
      length: 1,
    });
    expect(services.dispatch(memory, requestAt)).toBe(0);
    request(memory, NucleusObjectOperation.commit, { handle });
    expect(services.dispatch(memory, requestAt)).toBe(0);

    const bytes = readFileSync(path.join(root, "build/large.bin"));
    expect(bytes.length).toBe(0x1_0003);
    expect(bytes[0x1_0001]).toBe(0);
    expect(bytes[0x1_0002]).toBe("Z".charCodeAt(0));
  });

  it("rejects malformed requests and root escapes without allocating handles", () => {
    const root = mkdtempSync(path.join(tmpdir(), "nucleus-objects-"));
    const services = new NodeNamedObjectServices(root);
    const memory = new Uint8Array(0x10000);

    const length = put(memory, "../outside.nu");
    request(memory, NucleusObjectOperation.openRead, {
      pointer: bytesAt,
      length,
    });
    expect(services.dispatch(memory, requestAt)).toBe(
      NucleusSystemStatus.invalid,
    );
    memory[requestAt + NucleusObjectRequest.abi] = 2;
    expect(services.dispatch(memory, requestAt)).toBe(
      NucleusSystemStatus.invalid,
    );
    expect(services.openHandleCount).toBe(0);
  });
});
