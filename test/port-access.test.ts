import { describe, expect, it } from "vitest";

import {
  compileNucleus,
  defaultNucleusServices,
  type NucleusCompileSuccess,
} from "../src/compiler.js";
import { executeCommittedNobj } from "../src/proof.js";

const statusAddress = 0x7200;
const services = {
  ...defaultNucleusServices,
  success: 0x7180,
  unhandledFailure: 0x7188,
  trap: 0x7190,
};

const terminal = (status: number): readonly number[] => [
  0x3e,
  status,
  0x32,
  statusAddress & 0xff,
  statusAddress >>> 8,
  0x76,
];

const execute = (
  built: NucleusCompileSuccess,
  ioRead: (port: number) => number,
  ioWrite: (port: number, value: number) => void,
  bankSwitch?: { port: number; windowBase: number; windowCapacity: number },
) =>
  executeCommittedNobj(
    built.nobj,
    {
      maxInstructions: 100_000,
      maxCycles: 1_000_000,
      halted: true,
      initialSp: 0x6ff0,
      expectedSp: 0x6ff0,
      writes: [
        { at: services.success, bytes: terminal(1) },
        { at: services.unhandledFailure, bytes: terminal(2) },
        { at: services.trap, bytes: terminal(3) },
      ],
    },
    { ioRead, ioWrite, bankSwitch },
  );

const contains = (bytes: Uint8Array, sequence: readonly number[]): boolean =>
  bytes.some((_, index) =>
    sequence.every((byte, offset) => bytes[index + offset] === byte),
  );

describe("typed Z80 port access", () => {
  it.each([
    {
      line: "var x as u8 = readPort(true)",
      code: 60,
      relativeOffset: 27,
      column: 28,
    },
    {
      line: "var x as u8 = readPort(65536)",
      code: 1,
      relativeOffset: 23,
      column: 24,
    },
    {
      line: "writePort(1, true)",
      code: 60,
      relativeOffset: 17,
      column: 18,
    },
    {
      line: "writePort(1, 256)",
      code: 61,
      relativeOffset: 13,
      column: 14,
    },
    {
      line: "writePort(true, 1)",
      code: 60,
      relativeOffset: 14,
      column: 15,
    },
    {
      line: "var x as u8 = writePort(1, 2)",
      code: 60,
      relativeOffset: 14,
      column: 15,
    },
    {
      line: "var x as u8 = readPort()",
      code: 58,
      relativeOffset: 23,
      column: 24,
    },
    {
      line: "writePort(1)",
      code: 148,
      relativeOffset: 11,
      column: 12,
    },
    {
      line: "writePort(1, 2, 3)",
      code: 134,
      relativeOffset: 14,
      column: 15,
    },
  ])(
    "rejects invalid port call $line at the offending token",
    async ({ line, code, relativeOffset, column }) => {
      const source = ["sub main()", line, "end", ""].join("\n");
      const built = await compileNucleus([{ name: "invalid.nu", source }], {
        services,
      });
      expect(built.success).toBe(false);
      if (built.success) return;
      expect(built.diagnostic).toMatchObject({
        code,
        sourcePart: 1,
        sourceName: "invalid.nu",
        offset: source.indexOf(line) + relativeOffset,
        line: 2,
        column,
      });
    },
  );

  it("rejects a dynamic u16 output value at that argument", async () => {
    const source = [
      "sub main()",
      "var value as u16 = 1",
      "writePort(0, value)",
      "end",
      "",
    ].join("\n");
    const built = await compileNucleus([{ name: "wide-value.nu", source }], {
      services,
    });
    expect(built.success).toBe(false);
    if (built.success) return;
    expect(built.diagnostic).toMatchObject({
      code: 60,
      sourcePart: 1,
      sourceName: "wide-value.nu",
      offset: source.indexOf(")", source.lastIndexOf("value")),
      line: 3,
      column: 19,
    });
  });

  it("uses the full u16 BC address, preserves argument order, and emits exact Z80 I/O", async () => {
    const source = [
      "var order as u8",
      "sub markPort(value as u16) as u16",
      "order = order * 10 + 1",
      "return value",
      "end",
      "sub markValue(value as u8) as u8",
      "order = order * 10 + 2",
      "return value",
      "end",
      "sub main()",
      "var dynamicPort as u16 = $1234",
      "var dynamicValue as u8 = $5A",
      "var bytePort as u8 = 1",
      "var wide as u16 = readPort(markPort($FFFF))",
      "writePort(markPort(dynamicPort), markValue(dynamicValue))",
      "writePort(0, u8(wide))",
      "writePort(255, $55)",
      "readPort(bytePort)",
      "end",
      "",
    ].join("\n");
    const built = await compileNucleus([{ name: "ports.nu", source }], {
      services,
    });
    if (!built.success) throw new Error(JSON.stringify(built));

    const reads: number[] = [];
    const writes: Array<{ port: number; value: number }> = [];
    const executed = execute(
      built,
      (port) => {
        reads.push(port);
        return port === 0xffff ? 0xa5 : 0x33;
      },
      (port, value) => writes.push({ port, value }),
    );

    expect(executed.memory[statusAddress]).toBe(1);
    expect(reads).toEqual([0xffff, 1]);
    expect(writes).toEqual([
      { port: 0x1234, value: 0x5a },
      { port: 0, value: 0xa5 },
      { port: 255, value: 0x55 },
    ]);
    expect(executed.memory[built.materialized.parsed.map.bssBase]).toBe(112);

    const image =
      built.materialized.flatImage ??
      built.materialized.banks[built.materialized.parsed.map.entryBank];
    if (image === undefined) throw new Error("entry image unavailable");
    expect(contains(image, [0xc1, 0xed, 0x78, 0x6f, 0x26, 0x00, 0xe5])).toBe(
      true,
    );
    expect(contains(image, [0xc1, 0xed, 0x78])).toBe(true);
    expect(contains(image, [0xe1, 0x7d, 0xc1, 0xed, 0x79])).toBe(true);
  });

  it("works in a banked target without service-vector or runtime additions", async () => {
    const source = [
      "sub main()",
      "var value as u8 = readPort($ABCD)",
      "writePort($FEDC, value)",
      "end",
      "",
    ].join("\n");
    const built = await compileNucleus(
      [{ name: "banked-ports.nu", source }],
      {
        bankCount: 2,
        entryBank: 0,
        partBanks: [0],
        imageBase: 0x8000,
        imageCapacity: 0x1000,
        writableBase: 0x4000,
        writableCapacity: 0x1000,
        services: { ...services, farCall: 0x7000, farJump: 0x7080 },
      },
    );
    if (!built.success) throw new Error(JSON.stringify(built));
    const writes: Array<{ port: number; value: number }> = [];
    const executed = execute(
      built,
      (port) => (port === 0xabcd ? 0x7e : 0),
      (port, value) => {
        if (port !== 0x7f) writes.push({ port, value });
      },
      { port: 0x7f, windowBase: 0x8000, windowCapacity: 0x1000 },
    );
    expect(executed.memory[statusAddress]).toBe(1);
    expect(writes).toEqual([{ port: 0xfedc, value: 0x7e }]);
  });

  it("resets cleanly after a rejected compilation", async () => {
    const valid = [
      "sub main()",
      "var value as u8 = readPort(256)",
      "writePort(257, value)",
      "end",
      "",
    ].join("\n");
    const first = await compileNucleus([{ name: "reset.nu", source: valid }], {
      services,
    });
    if (!first.success) throw new Error(JSON.stringify(first));
    const rejected = await compileNucleus(
      [
        {
          name: "reset.nu",
          source: "sub main()\nwritePort(0, true)\nend\n",
        },
      ],
      { services },
    );
    expect(rejected.success).toBe(false);
    const recovered = await compileNucleus(
      [{ name: "reset.nu", source: valid }],
      { services },
    );
    if (!recovered.success) throw new Error(JSON.stringify(recovered));
    expect(recovered.nobj).toEqual(first.nobj);
  });
});
