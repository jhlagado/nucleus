import { createZ80Runtime, parseIntelHex } from "@jhlagado/debug80-runtime";
import { beforeAll, describe, expect, it } from "vitest";
import { assembleNativeCpmProof } from "../scripts/assemble-native-cpm.mjs";

let proofImage: Uint8Array;
let symbols: Record<string, number>;

const word = (memory: Uint8Array, address: number, value: number): void => {
  memory[address] = value & 0xff;
  memory[address + 1] = value >>> 8;
};

const canonicalName = (name: string): string => {
  const [stem = "", extension = ""] = name.toUpperCase().split(".");
  return `${stem.padEnd(8, " ").slice(0, 8)}${extension.padEnd(3, " ").slice(0, 3)}`;
};

const fcbName = (memory: Uint8Array, address: number): string =>
  String.fromCharCode(...memory.slice(address + 1, address + 12));

const installFcb = (
  memory: Uint8Array,
  address: number,
  name: string,
): void => {
  memory.fill(0, address, address + 36);
  memory.set(Buffer.from(canonicalName(name)), address + 1);
};

const installTail = (memory: Uint8Array, tail: string): void => {
  const bytes = Buffer.from(tail);
  memory[0x0080] = bytes.length;
  memory.set(bytes, 0x0081);
};

const cpmTextFile = (bytes: Uint8Array): Uint8Array => {
  const records = Math.ceil((bytes.length + 1) / 128);
  const file = new Uint8Array(records * 128).fill(0x1a);
  file.set(bytes);
  return file;
};

const exactFile = (length: number, seed = 0): Uint8Array =>
  Uint8Array.from({ length }, (_, index) => {
    const value = (index * 37 + seed) & 0xff;
    return value === 0x1a ? 0x1b : value;
  });

class CommandBdos {
  public dma = 0x0080;
  public readonly calls: number[] = [];
  public readonly events: string[] = [];
  public readErrorFor: string | undefined;
  private readonly cursors = new Map<number, number>();

  public constructor(public readonly files: Map<string, Uint8Array>) {}

  public dispatch(runtime: ReturnType<typeof createZ80Runtime>): void {
    const memory = runtime.hardware.memory;
    const fcb = (runtime.cpu.d << 8) | runtime.cpu.e;
    const operation = runtime.cpu.c;
    const name = fcbName(memory, fcb);
    this.calls.push(operation);
    this.events.push(`${operation}:${name}:${fcb.toString(16)}`);
    runtime.cpu.ix = 0xdead;
    runtime.cpu.iy = 0xbeef;

    if (operation === 26) {
      this.dma = fcb;
      runtime.cpu.a = 0;
      return;
    }
    const file = this.files.get(name);
    if (operation === 15) {
      this.cursors.set(fcb, 0);
      runtime.cpu.a = file === undefined ? 0xff : 0;
      return;
    }
    if (operation === 20) {
      if (name === this.readErrorFor) {
        runtime.cpu.a = 2;
        return;
      }
      const cursor = this.cursors.get(fcb) ?? 0;
      if (file === undefined || cursor + 128 > file.length) {
        runtime.cpu.a = 1;
      } else {
        memory.set(file.slice(cursor, cursor + 128), this.dma);
        this.cursors.set(fcb, cursor + 128);
        runtime.cpu.a = 0;
      }
      return;
    }
    throw new Error(`unexpected command BDOS function ${operation}`);
  }
}

beforeAll(async () => {
  const assembled = await assembleNativeCpmProof(
    "cpm22-command-proof.asm",
  );
  proofImage = parseIntelHex(assembled.hex).memory;
  symbols = assembled.symbols;
});

const createProof = (files = new Map<string, Uint8Array>()) => {
  const memory = proofImage.slice();
  const sentinel = 0x3f00;
  const stack = 0xe300;
  memory.set([0xd3, 0xe1, 0xc9], 0x0005);
  memory[sentinel] = 0x76;
  const bdos = new CommandBdos(files);
  let runtime!: ReturnType<typeof createZ80Runtime>;
  runtime = createZ80Runtime(
    { memory, startAddress: symbols.CpmCommandPrepare! },
    symbols.CpmCommandPrepare!,
    { write: () => bdos.dispatch(runtime) },
  );
  const activeMemory = runtime.hardware.memory;

  const call = (): {
    a: number;
    carry: number;
    instructions: number;
    tStates: number;
  } => {
    word(activeMemory, stack, sentinel);
    runtime.cpu.sp = stack;
    runtime.cpu.pc = symbols.CpmCommandPrepare!;
    runtime.cpu.halted = false;
    let instructions = 0;
    let tStates = 0;
    while (!runtime.isHalted() && instructions < 2_000_000) {
      tStates += runtime.step().cycles ?? 0;
      instructions += 1;
    }
    expect(runtime.isHalted(), "CpmCommandPrepare did not return").toBe(true);
    expect(runtime.cpu.pc).toBe(sentinel + 1);
    expect(runtime.cpu.sp).toBe(stack + 2);
    return {
      a: runtime.cpu.a,
      carry: runtime.cpu.flags.C,
      instructions,
      tStates,
    };
  };

  const prepare = (
    tail: string,
    defaultInput = "INPUT.NU",
    defaultOutput = "OUTPUT.COM",
  ) => {
    installFcb(activeMemory, 0x005c, defaultInput);
    installFcb(activeMemory, 0x006c, defaultOutput);
    installTail(activeMemory, tail);
    return call();
  };

  const descriptor = (index: number) => {
    const address = symbols.CpmSourcePartDescriptors! + index * 14;
    return {
      name: fcbName(activeMemory, address),
      length: activeMemory[address + 12]! | (activeMemory[address + 13]! << 8),
    };
  };

  const outputName = () =>
    fcbName(activeMemory, symbols.CpmCompilerOutputName!);
  const outputFormat = () => activeMemory[symbols.CpmCompilerOutputFormat!];
  const helpRequested = () => activeMemory[symbols.CpmCommandHelpRequested!];

  return {
    bdos,
    call,
    descriptor,
    helpRequested,
    memory: activeMemory,
    outputFormat,
    outputName,
    prepare,
  };
};

describe("native Nucleus CP/M command and preflight adapter", () => {
  it("accepts the default and named command forms with exact logical lengths", () => {
    const files = new Map([
      [canonicalName("INPUT.NU"), cpmTextFile(Buffer.from("print 1"))],
      [canonicalName("HELLO.NU"), cpmTextFile(Buffer.from("return"))],
    ]);
    const proof = createProof(files);

    const defaultCommand = proof.prepare("");
    expect(defaultCommand).toMatchObject({ a: 0, carry: 0 });
    expect(defaultCommand).toMatchObject({ instructions: 272, tStates: 3_098 });
    expect(proof.memory[symbols.CpmSourcePartCount!]).toBe(1);
    expect(proof.descriptor(0)).toEqual({
      name: canonicalName("INPUT.NU"),
      length: 7,
    });
    expect(proof.outputName()).toBe(canonicalName("OUTPUT.COM"));
    expect(proof.outputFormat()).toBe(0);

    const named = proof.prepare(" hello.nu made.com", "HELLO.NU", "MADE.COM");
    expect(named).toMatchObject({ a: 0, carry: 0 });
    expect(proof.descriptor(0)).toEqual({
      name: canonicalName("HELLO.NU"),
      length: 6,
    });
    expect(proof.outputName()).toBe(canonicalName("MADE.COM"));
  });

  it("derives one-argument names and accepts COM, BIN, and HEX outputs", () => {
    const files = new Map([
      [canonicalName("HELLO.NU"), cpmTextFile(Buffer.from("hello"))],
      [canonicalName("INPUT.NEW"), cpmTextFile(Buffer.from("new"))],
    ]);
    const proof = createProof(files);

    expect(proof.prepare(" HELLO", "HELLO", "IGNORED.COM")).toMatchObject({
      a: 0,
      carry: 0,
    });
    expect(proof.descriptor(0)).toEqual({
      name: canonicalName("HELLO.NU"),
      length: 5,
    });
    expect(proof.outputName()).toBe(canonicalName("HELLO.COM"));
    expect(proof.outputFormat()).toBe(0);

    expect(
      proof.prepare(" INPUT.NEW", "INPUT.NEW", "IGNORED.COM"),
    ).toMatchObject({ a: 0, carry: 0 });
    expect(proof.descriptor(0)).toEqual({
      name: canonicalName("INPUT.NEW"),
      length: 3,
    });
    expect(proof.outputName()).toBe(canonicalName("INPUT.COM"));

    expect(
      proof.prepare(" HELLO.NU HELLO.BIN", "HELLO.NU", "HELLO.BIN"),
    ).toMatchObject({ a: 0, carry: 0 });
    expect(proof.outputFormat()).toBe(1);
    expect(
      proof.prepare(" HELLO.NU HELLO.HEX", "HELLO.NU", "HELLO.HEX"),
    ).toMatchObject({ a: 0, carry: 0 });
    expect(proof.outputFormat()).toBe(2);
  });

  it("accepts the help form without opening a source", () => {
    const proof = createProof();
    expect(proof.prepare(" ?")).toMatchObject({ a: 0, carry: 0 });
    expect(proof.helpRequested()).toBe(1);
    expect(proof.bdos.calls).toEqual([]);
  });

  it("preserves embedded zeroes, honors text EOF, and accepts 65,535 bytes", () => {
    const logical = Uint8Array.of(1, 0, 2, 0, 3);
    const maximum = exactFile(65_535, 3);
    const files = new Map([
      [canonicalName("ZERO.NU"), cpmTextFile(logical)],
      [canonicalName("MAX.NU"), cpmTextFile(maximum)],
    ]);
    const proof = createProof(files);
    expect(
      proof.prepare(" ZERO.NU ZERO.COM", "ZERO.NU", "ZERO.COM"),
    ).toMatchObject({ a: 0, carry: 0 });
    expect(proof.descriptor(0).length).toBe(5);
    expect(proof.prepare(" MAX.NU MAX.COM", "MAX.NU", "MAX.COM")).toMatchObject(
      { a: 0, carry: 0 },
    );
    expect(proof.descriptor(0).length).toBe(65_535);
  });

  it("accepts an exact-record source at physical EOF", () => {
    const source = exactFile(128, 11);
    const proof = createProof(new Map([[canonicalName("RECORD.NU"), source]]));
    expect(
      proof.prepare(" RECORD.NU RECORD.COM", "RECORD.NU", "RECORD.COM"),
    ).toMatchObject({ a: 0, carry: 0 });
    expect(proof.descriptor(0).length).toBe(128);
  });

  it("rejects the first over-capacity byte without publishing a wrapped length", () => {
    const bytes = exactFile(65_536, 7);
    const proof = createProof(new Map([[canonicalName("HUGE.NU"), bytes]]));
    const address = symbols.CpmSourcePartDescriptors! + 12;
    proof.memory[address] = 0xa5;
    proof.memory[address + 1] = 0x5a;
    expect(
      proof.prepare(" HUGE.NU HUGE.COM", "HUGE.NU", "HUGE.COM"),
    ).toMatchObject({ a: 4, carry: 1 });
    expect(proof.memory.slice(address, address + 2)).toEqual(
      Uint8Array.of(0xa5, 0x5a),
    );
  });

  it.each([
    [" SOURCE.NU OUTPUT.TXT", "SOURCE.NU", "OUTPUT.TXT", 1],
    [" SOURCE.NU OUTPUT.COM EXTRA", "SOURCE.NU", "OUTPUT.COM", 1],
    [" ? EXTRA", "SOURCE.NU", "OUTPUT.COM", 1],
    [" SOURCE.NU OUTPUT.COM @", "SOURCE.NU", "OUTPUT.COM", 1],
    [" A:SOURCE.NU OUTPUT.COM", "SOURCE.NU", "OUTPUT.COM", 1],
    [" *.NU OUTPUT.COM", "SOURCE.NU", "OUTPUT.COM", 1],
    [" SAME.COM SAME.COM", "SAME.COM", "SAME.COM", 7],
  ])(
    "rejects malformed or conflicting command tail %s",
    (tail, input, output, status) => {
      const proof = createProof();
      expect(proof.prepare(tail, input, output)).toMatchObject({
        a: status,
        carry: 1,
      });
    },
  );

  it("distinguishes missing files and storage failure", () => {
    const proof = createProof();
    expect(
      proof.prepare(" MISSING.NU OUT.COM", "MISSING.NU", "OUT.COM"),
    ).toMatchObject({ a: 3, carry: 1 });

    proof.bdos.files.set(
      canonicalName("BROKEN.NU"),
      cpmTextFile(Buffer.from("x")),
    );
    proof.bdos.readErrorFor = canonicalName("BROKEN.NU");
    expect(
      proof.prepare(" BROKEN.NU OUT.COM", "BROKEN.NU", "OUT.COM"),
    ).toMatchObject({ a: 6, carry: 1 });
    proof.bdos.readErrorFor = undefined;
  });

  it("resets successfully after a rejected command", () => {
    const files = new Map([
      [canonicalName("GOOD.NU"), cpmTextFile(Buffer.from("ok"))],
    ]);
    const proof = createProof(files);
    expect(proof.prepare(" BAD.", "BAD", "OUTPUT.COM")).toMatchObject({
      a: 1,
      carry: 1,
    });
    expect(
      proof.prepare(" GOOD.NU GOOD.COM", "GOOD.NU", "GOOD.COM"),
    ).toMatchObject({ a: 0, carry: 0 });
    expect(proof.descriptor(0)).toEqual({
      name: canonicalName("GOOD.NU"),
      length: 2,
    });
  });

  it("keeps resident and workspace accounting inside the declared CP/M regions", () => {
    expect(symbols.CpmCommandCodeEnd! - symbols.CpmCommandCodeStart!).toBe(427);
    expect(
      symbols.CpmCommandImmutableEnd! - symbols.CpmCommandImmutableStart!,
    ).toBe(33);
    expect(
      symbols.CpmCommandWorkspaceEnd! - symbols.CpmCommandWorkspaceBase!,
    ).toBe(25);
    expect(symbols.CpmCommandWorkspaceEnd).toBeLessThanOrEqual(0x6000);
    expect(symbols.CpmCommandCodeEnd).toBeLessThanOrEqual(0x5800);
  });
});
