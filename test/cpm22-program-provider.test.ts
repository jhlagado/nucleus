import path from "node:path";
import { fileURLToPath } from "node:url";

import { compile } from "@jhlagado/azm/compile";
import { createZ80Runtime, parseIntelHex } from "@jhlagado/debug80-runtime";
import { beforeAll, describe, expect, it } from "vitest";

import { bundledRuntimeProvider } from "../src/runtime-catalog.js";

const directory = path.dirname(fileURLToPath(import.meta.url));
const verticalSlice = path.join(directory, "..", "asm", "vertical-slice");

let image: Uint8Array;
let symbols: Record<string, number>;

const word = (memory: Uint8Array, address: number, value: number): void => {
  memory[address] = value & 0xff;
  memory[address + 1] = value >>> 8;
};

beforeAll(async () => {
  const assembled = await compile(
    path.join(verticalSlice, "cpm22-program-provider-proof.asm"),
    {
      emitHex: true,
      emitD8m: true,
      registerContracts: "strict",
      registerContractsInterfaces: [
        path.join(verticalSlice, "cpm22-program-provider.asmi"),
      ],
    },
  );
  expect(
    assembled.diagnostics.filter(({ severity }) => severity === "error"),
  ).toEqual([]);
  const hex = assembled.artifacts.find(({ kind }) => kind === "hex");
  const map = assembled.artifacts.find(({ kind }) => kind === "d8m");
  if (hex?.kind !== "hex" || map?.kind !== "d8m") {
    throw new Error("AZM omitted CP/M program-provider proof artifacts");
  }
  image = parseIntelHex(hex.text).memory;
  symbols = Object.fromEntries(
    map.json.symbols.flatMap((entry) => {
      const value = entry.address ?? entry.value;
      return value === undefined ? [] : [[entry.name, value]];
    }),
  );
});

const execute = (
  entry: number,
  setup?: (runtime: ReturnType<typeof createZ80Runtime>) => void,
): ReturnType<typeof createZ80Runtime> => {
  const memory = image.slice();
  const sentinel = 0x0700;
  const stack = 0xe300;
  memory[sentinel] = 0x76;
  word(memory, stack, sentinel);
  const runtime = createZ80Runtime({ memory, startAddress: entry }, entry);
  runtime.cpu.sp = stack;
  setup?.(runtime);
  let instructions = 0;
  while (!runtime.isHalted() && instructions < 2_000) {
    runtime.step();
    instructions += 1;
  }
  expect(runtime.isHalted()).toBe(true);
  expect(runtime.cpu.sp).toBe(stack + 2);
  return runtime;
};

describe("native Nucleus CP/M generated-program provider", () => {
  it("has the fixed twelve-entry ABI and measured prefix accounting", () => {
    expect(symbols.CpmProgramPrefixStart).toBe(0x0100);
    expect(symbols.CpmProgramServiceVector).toBe(0x0120);
    expect(symbols.CpmProgramPacketVector).toBe(0x0141);
    expect(
      symbols.CpmProgramServiceVectorEnd - symbols.CpmProgramServiceVector,
    ).toBe(36);
    expect(
      symbols.CpmProgramProviderCodeEnd - symbols.CpmProgramProviderCodeStart,
    ).toBe(66);
    expect(
      symbols.CpmProgramProviderImmutableEnd -
        symbols.CpmProgramProviderImmutableStart,
    ).toBe(47);
    expect(symbols.CpmProgramPrefixEnd - symbols.CpmProgramPrefixStart).toBe(
      181,
    );
    expect(symbols.CpmProgramPrefixEnd).toBeLessThanOrEqual(0x0800);

    const destinations = [
      "CpmProgramReadInput",
      "CpmProgramWriteOutput",
      "CpmProgramReadStorage",
      "CpmProgramRewindStorage",
      "CpmProgramWriteStorage",
      "CpmProgramSeekStorage",
      "CpmProgramSuccess",
      "CpmProgramFailure",
      "CpmProgramTrap",
      "CpmProgramFarCall",
      "CpmProgramFarJump",
      "CpmProgramPacket",
    ];
    destinations.forEach((name, ordinal) => {
      const address = 0x0120 + ordinal * 3;
      expect(Array.from(image.slice(address, address + 3))).toEqual([
        0xc3,
        symbols[name]! & 0xff,
        symbols[name]! >>> 8,
      ]);
    });
  });

  it("enters the generated image and returns cleanly through success", () => {
    const runtime = execute(symbols.CpmProgramEntry!);
    expect(runtime.cpu.flags.C).toBe(0);
  });

  it("preserves the generated-program register set around BIOS console I/O", () => {
    const read = execute(symbols.CpmProgramReadInput!, (runtime) => {
      runtime.hardware.memory.set([0x3e, 0x00, 0xc9], 0xfa09);
      runtime.cpu.b = 0x12;
      runtime.cpu.c = 0x34;
      runtime.cpu.d = 0x56;
      runtime.cpu.e = 0x78;
      runtime.cpu.h = 0x9a;
      runtime.cpu.l = 0xbc;
      runtime.cpu.ix = 0x2468;
      runtime.cpu.iy = 0x1357;
    });
    expect(read.cpu.a).toBe(0);
    expect(read.cpu.flags.C).toBe(0);
    expect(read.cpu.flags.Z).toBe(1);
    expect([
      read.cpu.b,
      read.cpu.c,
      read.cpu.d,
      read.cpu.e,
      read.cpu.h,
      read.cpu.l,
      read.cpu.ix,
      read.cpu.iy,
    ]).toEqual([0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc, 0x2468, 0x1357]);

    const writes: Array<{ port: number; value: number }> = [];
    const memory = image.slice();
    const sentinel = 0x0700;
    const stack = 0xe300;
    memory[sentinel] = 0x76;
    word(memory, stack, sentinel);
    memory.set([0x79, 0xd3, 0xe0, 0xc9], 0xfa0c);
    const write = createZ80Runtime(
      { memory, startAddress: symbols.CpmProgramWriteOutput! },
      symbols.CpmProgramWriteOutput!,
      { write: (port, value) => writes.push({ port, value }) },
    );
    write.cpu.sp = stack;
    write.cpu.a = 0x5a;
    write.cpu.b = 0x12;
    write.cpu.c = 0x34;
    write.cpu.d = 0x56;
    write.cpu.e = 0x78;
    write.cpu.h = 0x9a;
    write.cpu.l = 0xbc;
    write.cpu.ix = 0x2468;
    write.cpu.iy = 0x1357;
    let instructions = 0;
    while (!write.isHalted() && instructions < 2_000) {
      write.step();
      instructions += 1;
    }
    expect(write.isHalted()).toBe(true);
    expect(write.cpu.sp).toBe(stack + 2);
    expect(writes).toEqual([{ port: 0x5ae0, value: 0x5a }]);
    expect(write.cpu.a).toBe(0);
    expect(write.cpu.flags.C).toBe(0);
    expect([
      write.cpu.b,
      write.cpu.c,
      write.cpu.d,
      write.cpu.e,
      write.cpu.h,
      write.cpu.l,
      write.cpu.ix,
      write.cpu.iy,
    ]).toEqual([0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc, 0x2468, 0x1357]);
  });

  it("reports unavailable storage and invalid flat-only transfers honestly", () => {
    for (const entry of [
      "CpmProgramReadStorage",
      "CpmProgramRewindStorage",
      "CpmProgramWriteStorage",
      "CpmProgramSeekStorage",
    ]) {
      const runtime = execute(symbols[entry]!);
      expect(runtime.cpu.a).toBe(4);
      expect(runtime.cpu.flags.C).toBe(1);
    }
    for (const entry of [
      "CpmProgramFarCall",
      "CpmProgramFarJump",
      "CpmProgramPacket",
    ]) {
      const runtime = execute(symbols[entry]!);
      expect(runtime.cpu.a).toBe(7);
      expect(runtime.cpu.flags.C).toBe(1);
    }
  });

  it("links the exact CP/M runtime and initialized vector image", () => {
    const context = {
      runtimeBase: 0x0803,
      writableBase: 0x5800,
      writableCapacity: 0x0d00,
      writableStateBase: 0x5824,
      vectorBase: 0x5800,
      programDataBase: 0x584d,
      programDataCapacity: 0x0cb3,
      readOnlyBase: 0,
      readOnlyCapacity: 0,
      services: {
        readInputByte: 0x0120,
        writeOutputByte: 0x0123,
        readStorageByte: 0x0126,
        rewindStorageInput: 0x0129,
        writeStorageByte: 0x012c,
        seekStorageOutput: 0x012f,
        success: 0x0132,
        unhandledFailure: 0x0135,
        trap: 0x0138,
        farCall: 0x013b,
        farJump: 0x013e,
        packetService: 0x0141,
      },
    };
    const runtime = bundledRuntimeProvider.get(10, context);
    expect(runtime).toBeDefined();
    expect(runtime!.bytes).toHaveLength(732);
    expect(runtime!.initialBytes).toHaveLength(77);
    for (let ordinal = 0; ordinal < 11; ordinal += 1) {
      expect(
        Array.from(runtime!.initialBytes.slice(ordinal * 3, ordinal * 3 + 3)),
      ).toEqual([0xc3, 0x20 + ordinal * 3, 0x01]);
    }
    const packetGateway = 0x0803 + runtime!.helperOffsets!.PacketServiceGateway;
    expect(Array.from(runtime!.initialBytes.slice(33, 36))).toEqual([
      0xc3,
      packetGateway & 0xff,
      packetGateway >>> 8,
    ]);
    expect(Array.from(runtime!.initialBytes.slice(73, 77))).toEqual([
      0x4d, 0x58, 0xb3, 0x0c,
    ]);
  });
});
