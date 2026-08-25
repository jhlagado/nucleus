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

const wordAt = (memory: Uint8Array, address: number): number =>
  memory[address]! | (memory[address + 1]! << 8);

const fcbName = (memory: Uint8Array, address: number): string =>
  String.fromCharCode(...memory.slice(address + 1, address + 12));

const installDefaultFcb = (
  memory: Uint8Array,
  address: number,
  name: string,
): void => {
  const [stem = "", extension = ""] = name.toUpperCase().split(".");
  memory.fill(0, address, address + 36);
  memory.fill(0x20, address + 1, address + 12);
  memory.set(
    Array.from(stem.padEnd(8, " ").slice(0, 8), (byte) => byte.charCodeAt(0)),
    address + 1,
  );
  memory.set(
    Array.from(extension.padEnd(3, " ").slice(0, 3), (byte) =>
      byte.charCodeAt(0),
    ),
    address + 9,
  );
};

const storageFile = (payload: Uint8Array): Uint8Array => {
  const file = new Uint8Array(
    Math.max(128, Math.ceil((payload.length + 2) / 128) * 128),
  );
  word(file, 0, payload.length);
  file.set(payload, 2);
  return file;
};

const storagePayload = (file: Uint8Array): Uint8Array =>
  file.slice(2, 2 + (file[0]! | (file[1]! << 8)));

class ProofBdos {
  public dma = 0x0080;
  public failWriteRecord: number | undefined;
  public randomWrites = 0;

  public constructor(public readonly files: Map<string, Uint8Array>) {}

  public dispatch(runtime: ReturnType<typeof createZ80Runtime>): void {
    const memory = runtime.hardware.memory;
    const fcb = (runtime.cpu.d << 8) | runtime.cpu.e;
    const name = fcbName(memory, fcb);
    const operation = runtime.cpu.c;
    if (operation === 26) {
      this.dma = fcb;
      runtime.cpu.a = 0;
      return;
    }
    if (operation === 15) {
      runtime.cpu.a = this.files.has(name) ? 0 : 0xff;
      return;
    }
    if (operation === 16) {
      runtime.cpu.a = 0;
      return;
    }
    if (operation === 22) {
      if (this.files.has(name)) {
        runtime.cpu.a = 0xff;
      } else {
        this.files.set(name, new Uint8Array());
        runtime.cpu.a = 0;
      }
      return;
    }
    if (operation !== 33 && operation !== 34) {
      throw new Error(`unexpected proof BDOS function ${operation}`);
    }
    const record =
      memory[fcb + 33]! | (memory[fcb + 34]! << 8) | (memory[fcb + 35]! << 16);
    const offset = record * 128;
    const file = this.files.get(name);
    if (operation === 33) {
      if (file === undefined || offset + 128 > file.length) {
        runtime.cpu.a = 1;
      } else {
        memory.set(file.slice(offset, offset + 128), this.dma);
        runtime.cpu.a = 0;
      }
      return;
    }
    this.randomWrites += 1;
    if (this.failWriteRecord === record) {
      this.failWriteRecord = undefined;
      runtime.cpu.a = 2;
      return;
    }
    const length = offset + 128;
    const grown =
      file === undefined || file.length < length
        ? new Uint8Array(length)
        : file.slice();
    if (file !== undefined) grown.set(file);
    grown.set(memory.slice(this.dma, this.dma + 128), offset);
    this.files.set(name, grown);
    runtime.cpu.a = 0;
  }
}

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
  memory[0x0005] = 0xc9;
  memory[0x005d] = 0x20;
  memory[0x006d] = 0x20;
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

const createStorageProof = (
  input: Uint8Array,
  output: Uint8Array,
): {
  runtime: ReturnType<typeof createZ80Runtime>;
  bdos: ProofBdos;
  call: (
    name: string,
    setup?: (runtime: ReturnType<typeof createZ80Runtime>) => void,
  ) => { a: number; carry: number; instructions: number; tStates: number };
} => {
  const memory = image.slice();
  installDefaultFcb(memory, 0x005c, "INPUT.NST");
  installDefaultFcb(memory, 0x006c, "OUTPUT.NST");
  memory.set([0xd3, 0xe1, 0xc9], 0x0005);
  const bdos = new ProofBdos(
    new Map([
      ["INPUT   NST", storageFile(input)],
      ["OUTPUT  NST", storageFile(output)],
    ]),
  );
  let runtime!: ReturnType<typeof createZ80Runtime>;
  runtime = createZ80Runtime(
    { memory, startAddress: symbols.CpmProgramInitialize! },
    symbols.CpmProgramInitialize!,
    { write: () => bdos.dispatch(runtime) },
  );
  const sentinel = 0x0700;
  const stack = 0xe300;
  runtime.hardware.memory[sentinel] = 0x76;
  const call = (
    name: string,
    setup?: (active: ReturnType<typeof createZ80Runtime>) => void,
  ): { a: number; carry: number; instructions: number; tStates: number } => {
    word(runtime.hardware.memory, stack, sentinel);
    runtime.cpu.sp = stack;
    runtime.cpu.pc = symbols[name]!;
    runtime.cpu.halted = false;
    setup?.(runtime);
    let instructions = 0;
    let tStates = 0;
    while (!runtime.isHalted() && instructions < 10_000) {
      tStates += runtime.step().cycles ?? 0;
      instructions += 1;
    }
    expect(
      runtime.isHalted(),
      `${name} did not return (PC=$${runtime.cpu.pc.toString(16)}, SP=$${runtime.cpu.sp.toString(16)}, C=${runtime.cpu.c})`,
    ).toBe(true);
    expect(runtime.cpu.sp).toBe(stack + 2);
    return {
      a: runtime.cpu.a,
      carry: runtime.cpu.flags.C,
      instructions,
      tStates,
    };
  };
  return { runtime, bdos, call };
};

describe("native Nucleus CP/M generated-program provider", () => {
  it("has the fixed twelve-entry ABI and measured prefix accounting", () => {
    expect(symbols.CpmProgramPrefixStart).toBe(0x0100);
    expect(symbols.CpmProgramServiceVector).toBe(0x0107);
    expect(symbols.CpmProgramPacketVector).toBe(0x0128);
    expect(
      symbols.CpmProgramServiceVectorEnd - symbols.CpmProgramServiceVector,
    ).toBe(36);
    expect(
      symbols.CpmProgramProviderCodeEnd - symbols.CpmProgramProviderCodeStart,
    ).toBe(686);
    expect(
      symbols.CpmProgramProviderImmutableEnd -
        symbols.CpmProgramProviderImmutableStart,
    ).toBe(47);
    expect(symbols.CpmProgramPrefixEnd - symbols.CpmProgramPrefixStart).toBe(
      859,
    );
    expect(
      symbols.CpmProgramProviderWorkspaceEnd -
        symbols.CpmProgramProviderWorkspaceStart,
    ).toBe(83);
    expect(symbols.CpmProgramRecordCache).toBe(0x0080);
    expect(
      symbols.CpmProgramRecordCacheEnd - symbols.CpmProgramRecordCache,
    ).toBe(128);
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
      const address = 0x0107 + ordinal * 3;
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

  it("implements exact byte storage, rewind, overwrite, append, seek, and EOF", () => {
    const { runtime, bdos, call } = createStorageProof(
      Uint8Array.of(0, 0x41, 0xff),
      Uint8Array.of(0x10, 0x20),
    );
    expect(call("CpmProgramInitialize")).toMatchObject({ a: 0, carry: 0 });
    expect(runtime.hardware.memory[symbols.CpmProgramStorageState!]).toBe(3);
    expect(call("CpmProgramReadStorage")).toMatchObject({ a: 0, carry: 0 });
    expect(call("CpmProgramReadStorage")).toMatchObject({ a: 0x41, carry: 0 });
    expect(call("CpmProgramReadStorage")).toMatchObject({ a: 0xff, carry: 0 });
    expect(call("CpmProgramReadStorage")).toMatchObject({ a: 1, carry: 1 });
    expect(call("CpmProgramRewindStorage")).toMatchObject({ a: 0, carry: 0 });
    expect(call("CpmProgramReadStorage")).toMatchObject({ a: 0, carry: 0 });

    expect(
      call("CpmProgramWriteStorage", (active) => {
        active.cpu.a = 0x30;
      }),
    ).toMatchObject({ a: 0, carry: 0 });
    expect(
      call("CpmProgramSeekStorage", (active) => {
        active.cpu.h = 0;
        active.cpu.l = 1;
      }),
    ).toMatchObject({ a: 0, carry: 0 });
    expect(
      call("CpmProgramWriteStorage", (active) => {
        active.cpu.a = 0x99;
      }),
    ).toMatchObject({ a: 0, carry: 0 });
    expect(
      call("CpmProgramSeekStorage", (active) => {
        active.cpu.h = 0;
        active.cpu.l = 4;
      }),
    ).toMatchObject({ a: 4, carry: 1 });
    expect(storagePayload(bdos.files.get("OUTPUT  NST")!)).toEqual(
      Uint8Array.of(0x10, 0x99, 0x30),
    );
  });

  it("keeps a failed append logically atomic and retries the same cursor", () => {
    const initial = Uint8Array.from({ length: 126 }, (_, index) => index);
    const { runtime, bdos, call } = createStorageProof(
      new Uint8Array(),
      initial,
    );
    call("CpmProgramInitialize");
    bdos.failWriteRecord = 0;
    expect(
      call("CpmProgramWriteStorage", (active) => {
        active.cpu.a = 0xaa;
      }),
    ).toMatchObject({ a: 4, carry: 1 });
    expect(
      wordAt(runtime.hardware.memory, symbols.CpmProgramOutputCursor!),
    ).toBe(126);
    expect(
      wordAt(runtime.hardware.memory, symbols.CpmProgramOutputLength!),
    ).toBe(126);
    expect(storagePayload(bdos.files.get("OUTPUT  NST")!)).toEqual(initial);

    expect(
      call("CpmProgramWriteStorage", (active) => {
        active.cpu.a = 0xbb;
      }),
    ).toMatchObject({ a: 0, carry: 0 });
    expect(storagePayload(bdos.files.get("OUTPUT  NST")!)).toEqual(
      Uint8Array.from([...initial, 0xbb]),
    );
  });

  it("refuses to alias a live input file as mutable output storage", () => {
    const { runtime, bdos, call } = createStorageProof(
      Uint8Array.of(1, 2),
      Uint8Array.of(3, 4),
    );
    installDefaultFcb(runtime.hardware.memory, 0x006c, "INPUT.NST");
    call("CpmProgramInitialize");
    expect(runtime.hardware.memory[symbols.CpmProgramStorageState!]).toBe(1);
    expect(
      call("CpmProgramWriteStorage", (active) => {
        active.cpu.a = 0x55;
      }),
    ).toMatchObject({ a: 4, carry: 1 });
    expect(storagePayload(bdos.files.get("INPUT   NST")!)).toEqual(
      Uint8Array.of(1, 2),
    );
  });

  it("maps the final readable byte without 16-bit physical wrap and rejects growth past u16", () => {
    const { runtime, bdos, call } = createStorageProof(
      new Uint8Array(),
      new Uint8Array(),
    );
    call("CpmProgramInitialize");
    call("CpmProgramPrepareLogicalRecord", (active) => {
      active.cpu.ix = symbols.CpmProgramOutputFcb!;
      active.cpu.h = 0xff;
      active.cpu.l = 0xfe;
    });
    const fcb = symbols.CpmProgramOutputFcb!;
    expect(
      Array.from(runtime.hardware.memory.slice(fcb + 33, fcb + 36)),
    ).toEqual([0, 2, 0]);
    expect((runtime.cpu.h << 8) | runtime.cpu.l).toBe(
      symbols.CpmProgramRecordCache,
    );

    word(runtime.hardware.memory, symbols.CpmProgramOutputCursor!, 0xffff);
    word(runtime.hardware.memory, symbols.CpmProgramOutputLength!, 0xffff);
    const writes = bdos.randomWrites;
    expect(
      call("CpmProgramWriteStorage", (active) => {
        active.cpu.a = 0x5a;
      }),
    ).toMatchObject({ a: 4, carry: 1 });
    expect(bdos.randomWrites).toBe(writes);
    expect(
      wordAt(runtime.hardware.memory, symbols.CpmProgramOutputCursor!),
    ).toBe(0xffff);
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
        readInputByte: 0x0107,
        writeOutputByte: 0x010a,
        readStorageByte: 0x010d,
        rewindStorageInput: 0x0110,
        writeStorageByte: 0x0113,
        seekStorageOutput: 0x0116,
        success: 0x0119,
        unhandledFailure: 0x011c,
        trap: 0x011f,
        farCall: 0x0122,
        farJump: 0x0125,
        packetService: 0x0128,
      },
    };
    const runtime = bundledRuntimeProvider.get(10, context);
    expect(runtime).toBeDefined();
    expect(runtime!.bytes).toHaveLength(732);
    expect(runtime!.initialBytes).toHaveLength(77);
    for (let ordinal = 0; ordinal < 11; ordinal += 1) {
      expect(
        Array.from(runtime!.initialBytes.slice(ordinal * 3, ordinal * 3 + 3)),
      ).toEqual([0xc3, 0x07 + ordinal * 3, 0x01]);
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
