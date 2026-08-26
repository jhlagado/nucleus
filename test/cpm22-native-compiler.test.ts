import path from "node:path";
import { fileURLToPath } from "node:url";

import { compile } from "@jhlagado/azm/compile";
import { createZ80Runtime, parseIntelHex } from "@jhlagado/debug80-runtime";
import { beforeAll, describe, expect, it } from "vitest";

const directory = path.dirname(fileURLToPath(import.meta.url));
const verticalSlice = path.join(directory, "..", "asm", "vertical-slice");

let compilerImage: Uint8Array;
let symbols: Record<string, number>;

const canonicalName = (name: string): string => {
  const [stem = "", extension = ""] = name.toUpperCase().split(".");
  return `${stem.padEnd(8, " ").slice(0, 8)}${extension.padEnd(3, " ").slice(0, 3)}`;
};

const fcbName = (memory: Uint8Array, address: number): string =>
  String.fromCharCode(...memory.slice(address + 1, address + 12));

const installFcb = (
  memory: Uint8Array,
  address: number,
  name?: string,
): void => {
  memory.fill(0, address, address + 36);
  memory.fill(0x20, address + 1, address + 12);
  if (name !== undefined) {
    memory.set(Buffer.from(canonicalName(name)), address + 1);
  }
};

const installCommand = (memory: Uint8Array, tail = ""): void => {
  const arguments_ = tail.trim().split(/ +/).filter(Boolean);
  installFcb(memory, 0x005c, arguments_[0] ?? "INPUT.NU");
  installFcb(memory, 0x006c, arguments_[1] ?? "OUTPUT.COM");
  const bytes = Buffer.from(tail);
  memory[0x0080] = bytes.length;
  memory.set(bytes, 0x0081);
};

const cpmTextFile = (source: string): Uint8Array => {
  const bytes = Buffer.from(source);
  const records = Math.ceil((bytes.length + 1) / 128);
  const file = new Uint8Array(records * 128).fill(0x1a);
  file.set(bytes);
  return file;
};

const word = (memory: Uint8Array, address: number, value: number): void => {
  memory[address] = value & 0xff;
  memory[address + 1] = value >>> 8;
};

class NativeCompilerBdos {
  public readonly console: number[] = [];
  public readonly events: string[] = [];
  public dma = 0x0080;
  public failWriteCall: number | undefined;
  public writes = 0;
  private readonly cursors = new Map<number, number>();

  public constructor(public readonly files = new Map<string, Uint8Array>()) {}

  public dispatch(runtime: ReturnType<typeof createZ80Runtime>): void {
    const memory = runtime.hardware.memory;
    const fcb = (runtime.cpu.d << 8) | runtime.cpu.e;
    const operation = runtime.cpu.c;
    const name = fcbName(memory, fcb);
    this.events.push(`${operation}:${name}:${fcb.toString(16)}`);

    let result = 0;
    if (operation === 2) {
      this.console.push(runtime.cpu.e);
    } else if (operation === 9) {
      let cursor = fcb;
      while (memory[cursor] !== 0x24) {
        this.console.push(memory[cursor]!);
        cursor = (cursor + 1) & 0xffff;
      }
    } else if (operation === 26) {
      this.dma = fcb;
    } else if (operation === 15) {
      this.cursors.set(fcb, 0);
      result = this.files.has(name) ? 0 : 0xff;
    } else if (operation === 16) {
      result = 0;
    } else if (operation === 19) {
      result = this.files.delete(name) ? 0 : 0xff;
    } else if (operation === 20) {
      const file = this.files.get(name);
      const cursor = this.cursors.get(fcb) ?? 0;
      if (file === undefined || cursor + 128 > file.length) {
        result = 1;
      } else {
        memory.set(file.slice(cursor, cursor + 128), this.dma);
        this.cursors.set(fcb, cursor + 128);
      }
    } else if (operation === 21) {
      this.writes += 1;
      const file = this.files.get(name);
      if (this.failWriteCall === this.writes) {
        result = 1;
      } else if (file === undefined) {
        result = 0xff;
      } else {
        const cursor = this.cursors.get(fcb) ?? 0;
        const grown = new Uint8Array(Math.max(file.length, cursor + 128));
        grown.set(file);
        grown.set(memory.slice(this.dma, this.dma + 128), cursor);
        this.files.set(name, grown);
        this.cursors.set(fcb, cursor + 128);
      }
    } else if (operation === 22) {
      if (this.files.has(name)) {
        result = 0xff;
      } else {
        this.files.set(name, new Uint8Array());
        this.cursors.set(fcb, 0);
      }
    } else if (operation === 23) {
      const replacement = fcbName(memory, fcb + 16);
      const file = this.files.get(name);
      if (file === undefined || this.files.has(replacement)) {
        result = 0xff;
      } else {
        this.files.delete(name);
        this.files.set(replacement, file);
      }
    } else if (operation === 33) {
      const file = this.files.get(name);
      const record =
        memory[fcb + 33]! |
        (memory[fcb + 34]! << 8) |
        (memory[fcb + 35]! << 16);
      const offset = record * 128;
      if (file === undefined || offset + 128 > file.length) {
        result = 1;
      } else {
        memory.set(file.slice(offset, offset + 128), this.dma);
      }
    } else {
      throw new Error(`unexpected native-compiler BDOS function ${operation}`);
    }

    runtime.cpu.a = result;
    runtime.cpu.b = 0x12;
    runtime.cpu.c = 0x34;
    runtime.cpu.d = 0x56;
    runtime.cpu.e = 0x78;
    runtime.cpu.h = 0x9a;
    runtime.cpu.l = 0xbc;
    runtime.cpu.ix = 0xdead;
    runtime.cpu.iy = 0xbeef;
  }

  public text(): string {
    return Buffer.from(this.console).toString();
  }
}

beforeAll(async () => {
  const assembled = await compile(
    path.join(verticalSlice, "cpm22-native-compiler.asm"),
    {
      emitHex: true,
      emitD8m: true,
      registerContracts: "strict",
      registerContractsInterfaces: [
        path.join(verticalSlice, "expression-generated-z80.asmi"),
        path.join(verticalSlice, "cpm22-bdos-call.asmi"),
      ],
    },
  );
  expect(
    assembled.diagnostics.filter(({ severity }) => severity === "error"),
  ).toEqual([]);
  const hex = assembled.artifacts.find(({ kind }) => kind === "hex");
  const map = assembled.artifacts.find(({ kind }) => kind === "d8m");
  if (hex?.kind !== "hex" || map?.kind !== "d8m") {
    throw new Error("AZM omitted native CP/M compiler artifacts");
  }
  compilerImage = parseIntelHex(hex.text).memory;
  symbols = Object.fromEntries(
    map.json.symbols.flatMap((entry) => {
      const value = entry.address ?? entry.value;
      return value === undefined ? [] : [[entry.name, value]];
    }),
  );
});

const createCompiler = (
  source: string,
  oldOutput?: Uint8Array,
  extraFiles?: ReadonlyMap<string, Uint8Array>,
): {
  bdos: NativeCompilerBdos;
  compileOnce: (
    replacementSource?: string,
    tail?: string,
  ) => {
    a: number;
    instructions: number;
    tStates: number;
  };
  memory: Uint8Array;
} => {
  const files = new Map<string, Uint8Array>([
    [canonicalName("INPUT.NU"), cpmTextFile(source)],
  ]);
  if (oldOutput !== undefined) {
    files.set(canonicalName("OUTPUT.COM"), oldOutput);
  }
  for (const [name, bytes] of extraFiles ?? []) {
    files.set(canonicalName(name), bytes);
  }
  const bdos = new NativeCompilerBdos(files);
  const memory = compilerImage.slice();
  memory.set([0xd3, 0xe1, 0xc9], 0x0005);
  const sentinel = 0xe500;
  const stack = 0xef3b;
  memory.fill(0xa5, 0xe400, 0xf000);
  memory[sentinel] = 0x76;
  let runtime!: ReturnType<typeof createZ80Runtime>;
  runtime = createZ80Runtime({ memory, startAddress: 0x0100 }, 0x0100, {
    write: (port) => (port & 0xff) === 0xe1 && bdos.dispatch(runtime),
  });

  const compileOnce = (replacementSource?: string, tail = "") => {
    if (replacementSource !== undefined) {
      files.set(canonicalName("INPUT.NU"), cpmTextFile(replacementSource));
    }
    installCommand(runtime.hardware.memory, tail);
    word(runtime.hardware.memory, stack, sentinel);
    const highMemory = runtime.hardware.memory.slice(0xe400, 0xf000);
    runtime.cpu.sp = stack;
    runtime.cpu.pc = 0x0100;
    runtime.cpu.halted = false;
    let instructions = 0;
    let tStates = 0;
    while (!runtime.isHalted() && instructions < 8_000_000) {
      tStates += runtime.step().cycles ?? 0;
      instructions += 1;
    }
    expect(runtime.isHalted(), "native compiler did not return to CP/M").toBe(
      true,
    );
    expect(runtime.cpu.sp).toBe(stack + 2);
    expect(runtime.hardware.memory.slice(0xe400, 0xf000)).toEqual(highMemory);
    return { a: runtime.cpu.a, instructions, tStates };
  };

  return { bdos, compileOnce, memory: runtime.hardware.memory };
};

const runCom = (file: Uint8Array) => {
  const memory = new Uint8Array(0x10000);
  memory.set(file, 0x0100);
  installFcb(memory, 0x005c);
  installFcb(memory, 0x006c);
  memory.set([0xd3, 0xe1, 0xc9], 0x0005);
  const sentinel = 0xe500;
  const stack = 0xe300;
  memory[sentinel] = 0x76;
  word(memory, stack, sentinel);
  let runtime!: ReturnType<typeof createZ80Runtime>;
  const bdos = new NativeCompilerBdos();
  runtime = createZ80Runtime({ memory, startAddress: 0x0100 }, 0x0100, {
    write: (port, value) => {
      if ((port & 0xff) === 0xe1) bdos.dispatch(runtime);
    },
  });
  runtime.cpu.sp = stack;
  let instructions = 0;
  let tStates = 0;
  while (!runtime.isHalted() && instructions < 1_000_000) {
    tStates += runtime.step().cycles ?? 0;
    instructions += 1;
  }
  expect(runtime.isHalted(), "generated COM did not return to CP/M").toBe(true);
  expect(runtime.cpu.sp).toBe(stack + 2);
  return { instructions, output: bdos.console, tStates };
};

const validSource = [
  "sub main() fails",
  "    writeOutputByte('O') else fail",
  "    writeOutputByte('K') else fail",
  "end",
  "",
].join("\n");

describe("complete native Nucleus-on-CP/M compiler transient", () => {
  it("compiles through BDOS, publishes exact bytes, and executes that COM", () => {
    const { bdos, compileOnce, memory } = createCompiler(validSource);
    const compiled = compileOnce();
    expect(compiled.a, bdos.text()).toBe(0);
    const output = bdos.files.get(canonicalName("OUTPUT.COM"));
    expect(output).toBeDefined();
    const prefixBytes =
      symbols.CpmEmbeddedPrefixEnd! - symbols.CpmEmbeddedPrefix!;
    expect(output!.slice(0, prefixBytes)).toEqual(
      memory.slice(symbols.CpmEmbeddedPrefix!, symbols.CpmEmbeddedPrefixEnd!),
    );
    expect(output!.slice(prefixBytes, 0x700).every((byte) => byte === 0)).toBe(
      true,
    );
    expect(output![0x700]).toBe(0xc3);
    const used =
      memory[symbols.CpmDirectUsedLength!]! |
      (memory[symbols.CpmDirectUsedLength! + 1]! << 8);
    expect(used).toBeGreaterThan(0);
    expect(output!.length).toBe((0x700 + used + 127) & ~127);
    expect(output!.slice(0x700, 0x700 + used)).toEqual(
      memory.slice(0x7800, 0x7800 + used),
    );
    expect(output!.slice(0x700 + used).every((byte) => byte === 0)).toBe(true);
    expect(bdos.files.has(canonicalName("OUTPUT.$$$"))).toBe(false);
    expect(bdos.files.has(canonicalName("OUTPUT.BAK"))).toBe(false);

    const executed = runCom(output!);
    expect(Buffer.from(executed.output).toString()).toBe("OK");
    expect(compiled).toEqual({ a: 0, instructions: 35_452, tStates: 964_080 });
    expect(executed).toEqual({
      instructions: 270,
      output: [0x4f, 0x4b],
      tStates: 3_240,
    });
  });

  it("rolls back a failed publication and compiles successfully afterward", () => {
    const old = new Uint8Array(128).fill(0xa5);
    const { bdos, compileOnce } = createCompiler(validSource, old);
    bdos.failWriteCall = 4;
    const failed = compileOnce();
    expect(failed.a).toBe(0);
    expect(bdos.files.get(canonicalName("OUTPUT.COM"))).toEqual(old);
    expect(bdos.files.has(canonicalName("OUTPUT.$$$"))).toBe(false);
    expect(bdos.files.has(canonicalName("OUTPUT.BAK"))).toBe(false);
    expect(bdos.text()).toContain("Nucleus error 61");

    bdos.failWriteCall = undefined;
    const recovered = compileOnce();
    expect(recovered.a, bdos.text()).toBe(0);
    expect(bdos.files.get(canonicalName("OUTPUT.COM"))).not.toEqual(old);
    expect(runCom(bdos.files.get(canonicalName("OUTPUT.COM"))!).output).toEqual(
      [0x4f, 0x4b],
    );
  });

  it("reports an exact source diagnostic and accepts the next command", () => {
    const { bdos, compileOnce } = createCompiler("sub main(\n");
    compileOnce();
    expect(bdos.text()).toContain("Nucleus error ");
    expect(bdos.text()).toContain(" P=01 O=000A L=0002 C=0001");
    expect(bdos.files.has(canonicalName("OUTPUT.COM"))).toBe(false);
    expect(bdos.files.has(canonicalName("OUTPUT.$$$"))).toBe(false);

    const recovered = compileOnce(validSource);
    expect(recovered.a, bdos.text()).toBe(0);
    expect(bdos.files.has(canonicalName("OUTPUT.COM"))).toBe(true);
  });

  it("retains multipart ordinals and offsets through a native plan", () => {
    const files = new Map<string, Uint8Array>([
      ["PARTS.LST", cpmTextFile("LIB.NU\nMAIN.NU\n")],
      ["LIB.NU", cpmTextFile("var value as u8\n")],
      ["MAIN.NU", cpmTextFile("sub main(\n")],
    ]);
    const { bdos, compileOnce } = createCompiler("", undefined, files);
    compileOnce(undefined, " parts.lst output.com @");
    expect(bdos.text(), bdos.events.join(" | ")).toContain(
      "Nucleus error 01 P=02 O=000A L=0002 C=0001",
    );
    expect(bdos.files.has(canonicalName("OUTPUT.COM"))).toBe(false);
  });

  it("fits every independently accounted code and workspace region", () => {
    expect(symbols.CompilerCoreEnd - symbols.CompilerCodeStart).toBe(16_314);
    expect(symbols.CompilerCoreEnd).toBe(0x40bd);
    expect(symbols.CpmHostVectorBase - symbols.CompilerCoreEnd).toBe(67);
    expect(
      symbols.CpmCompilerHostVectorEnd - symbols.CpmCompilerHostVectorStart,
    ).toBe(50);
    expect(
      symbols.CpmCompilerHostAdaptersEnd - symbols.CpmCompilerHostAdaptersStart,
    ).toBe(54);
    expect(symbols.CpmBdosCallCodeEnd - symbols.CpmBdosCallCodeStart).toBe(25);
    expect(
      symbols.CpmDirectOutputCodeEnd - symbols.CpmDirectOutputCodeStart,
    ).toBe(288);
    expect(
      symbols.CpmRuntimeProviderCodeEnd - symbols.CpmRuntimeProviderCodeStart,
    ).toBe(127);
    expect(symbols.CpmPublisherCodeEnd - symbols.CpmPublisherCodeStart).toBe(
      367,
    );
    expect(
      symbols.CpmSourceProviderCodeEnd - symbols.CpmSourceProviderCodeStart,
    ).toBe(722);
    expect(symbols.CpmCommandCodeEnd - symbols.CpmCommandCodeStart).toBe(630);
    expect(
      symbols.CpmCommandImmutableEnd - symbols.CpmCommandImmutableStart,
    ).toBe(27);
    expect(
      symbols.CpmCompilerSourceHostEnd - symbols.CpmCompilerSourceHostStart,
    ).toBe(399);
    expect(
      symbols.CpmCompilerStartupCodeEnd - symbols.CpmCompilerStartupCodeStart,
    ).toBe(173);
    expect(symbols.CpmEmbeddedPrefixEnd - symbols.CpmEmbeddedPrefix).toBe(876);
    expect(symbols.CpmEmbeddedRuntimeEnd - symbols.CpmEmbeddedRuntime).toBe(
      732,
    );
    expect(symbols.CpmEmbeddedInitialEnd - symbols.CpmEmbeddedInitial).toBe(77);
    expect(
      symbols.CpmCompilerImmutableEnd - symbols.CpmCompilerImmutableStart,
    ).toBe(73);
    expect(
      compilerImage
        .slice(symbols.CpmCompilerPartBanks!, symbols.CpmCompilerPartBanks! + 8)
        .every((byte) => byte === 0),
    ).toBe(true);
    expect(symbols.CpmCompilerResidentEnd).toBe(0x530c);
    expect(symbols.CpmHostResidentLimit - symbols.CpmCompilerResidentEnd).toBe(
      1_268,
    );
    expect(symbols.CpmCommandWorkspaceEnd).toBe(0x5e5b);
    expect(symbols.CpmHostWorkspaceLimit - symbols.CpmCommandWorkspaceEnd).toBe(
      421,
    );
    expect(symbols.CpmOutputBufferLimit - symbols.CpmOutputBufferBase).toBe(
      23_808,
    );
    expect(symbols.StackTop - symbols.StackFloor).toBe(3_840);
  });
});
