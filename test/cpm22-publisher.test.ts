import path from "node:path";
import { fileURLToPath } from "node:url";

import { compile } from "@jhlagado/azm/compile";
import { createZ80Runtime, parseIntelHex } from "@jhlagado/debug80-runtime";
import { beforeAll, describe, expect, it } from "vitest";

const directory = path.dirname(fileURLToPath(import.meta.url));
const verticalSlice = path.join(directory, "..", "asm", "vertical-slice");

let proofImage: Uint8Array;
let symbols: Record<string, number>;

const word = (memory: Uint8Array, address: number, value: number): void => {
  memory[address] = value & 0xff;
  memory[address + 1] = value >>> 8;
};

const fcbName = (memory: Uint8Array, address: number): string =>
  String.fromCharCode(...memory.slice(address + 1, address + 12));

class PublisherBdos {
  public readonly events: string[] = [];
  public dma = 0x0080;
  public failWriteCall: number | undefined;
  public failRenameCall: number | undefined;
  public writes = 0;
  public renames = 0;
  private readonly cursors = new Map<number, number>();

  public constructor(public readonly files = new Map<string, Uint8Array>()) {}

  public dispatch(runtime: ReturnType<typeof createZ80Runtime>): void {
    const memory = runtime.hardware.memory;
    const fcb = (runtime.cpu.d << 8) | runtime.cpu.e;
    const operation = runtime.cpu.c;
    const name = fcbName(memory, fcb);
    this.events.push(`${operation}:${name}`);
    runtime.cpu.ix = 0xdead;
    runtime.cpu.iy = 0xbeef;

    if (operation === 26) {
      this.dma = fcb;
      runtime.cpu.a = 0;
      return;
    }
    if (operation === 15) {
      runtime.cpu.a = this.files.has(name) ? 0 : 0xff;
      this.cursors.set(fcb, 0);
      return;
    }
    if (operation === 16) {
      runtime.cpu.a = 0;
      return;
    }
    if (operation === 19) {
      runtime.cpu.a = this.files.delete(name) ? 0 : 0xff;
      return;
    }
    if (operation === 22) {
      if (this.files.has(name)) {
        runtime.cpu.a = 0xff;
      } else {
        this.files.set(name, new Uint8Array());
        this.cursors.set(fcb, 0);
        runtime.cpu.a = 0;
      }
      return;
    }
    if (operation === 21) {
      this.writes += 1;
      if (this.failWriteCall === this.writes) {
        runtime.cpu.a = 1;
        return;
      }
      const file = this.files.get(name);
      if (file === undefined) {
        runtime.cpu.a = 0xff;
        return;
      }
      const cursor = this.cursors.get(fcb) ?? 0;
      const grown = new Uint8Array(Math.max(file.length, cursor + 128));
      grown.set(file);
      grown.set(memory.slice(this.dma, this.dma + 128), cursor);
      this.files.set(name, grown);
      this.cursors.set(fcb, cursor + 128);
      runtime.cpu.a = 0;
      return;
    }
    if (operation === 23) {
      this.renames += 1;
      if (this.failRenameCall === this.renames) {
        runtime.cpu.a = 0xff;
        return;
      }
      const replacement = fcbName(memory, fcb + 16);
      const file = this.files.get(name);
      if (file === undefined || this.files.has(replacement)) {
        runtime.cpu.a = 0xff;
      } else {
        this.files.delete(name);
        this.files.set(replacement, file);
        runtime.cpu.a = 0;
      }
      return;
    }
    throw new Error(`unexpected publisher BDOS function ${operation}`);
  }
}

beforeAll(async () => {
  const assembled = await compile(
    path.join(verticalSlice, "cpm22-publisher-proof.asm"),
    {
      emitHex: true,
      emitD8m: true,
      registerContracts: "strict",
      registerContractsInterfaces: [
        path.join(verticalSlice, "expression-generated-z80.asmi"),
        path.join(verticalSlice, "cpm22-publisher.asmi"),
      ],
    },
  );
  expect(
    assembled.diagnostics.filter(({ severity }) => severity === "error"),
  ).toEqual([]);
  const hex = assembled.artifacts.find(({ kind }) => kind === "hex");
  const map = assembled.artifacts.find(({ kind }) => kind === "d8m");
  if (hex?.kind !== "hex" || map?.kind !== "d8m") {
    throw new Error("AZM omitted CP/M publisher proof artifacts");
  }
  proofImage = parseIntelHex(hex.text).memory;
  symbols = Object.fromEntries(
    map.json.symbols.flatMap((entry) => {
      const value = entry.address ?? entry.value;
      return value === undefined ? [] : [[entry.name, value]];
    }),
  );
});

const createProof = (files?: Map<string, Uint8Array>) => {
  const memory = proofImage.slice();
  const sentinel = 0x3f00;
  const stack = 0xe300;
  memory.set([0xd3, 0xe1, 0xc9], 0x0005);
  memory[sentinel] = 0x76;
  const bdos = new PublisherBdos(files);
  let runtime!: ReturnType<typeof createZ80Runtime>;
  runtime = createZ80Runtime(
    { memory, startAddress: symbols.CpmPublishPrepare! },
    symbols.CpmPublishPrepare!,
    { write: () => bdos.dispatch(runtime) },
  );
  const activeMemory = runtime.hardware.memory;
  const call = (
    name: string,
    setup?: (active: typeof runtime) => void,
  ): { a: number; carry: number; instructions: number; tStates: number } => {
    word(activeMemory, stack, sentinel);
    runtime.cpu.sp = stack;
    runtime.cpu.pc = symbols[name]!;
    runtime.cpu.halted = false;
    setup?.(runtime);
    let instructions = 0;
    let tStates = 0;
    while (!runtime.isHalted() && instructions < 100_000) {
      tStates += runtime.step().cycles ?? 0;
      instructions += 1;
    }
    expect(runtime.isHalted(), `${name} did not return`).toBe(true);
    expect(runtime.cpu.sp).toBe(stack + 2);
    return {
      a: runtime.cpu.a,
      carry: runtime.cpu.flags.C,
      instructions,
      tStates,
    };
  };
  return { bdos, call, memory: activeMemory };
};

describe("native Nucleus CP/M transactional COM publisher", () => {
  it("publishes the exact prefix, zero gap, patched image, and final padding", () => {
    const old = Uint8Array.from({ length: 128 }, (_, index) => index);
    const { bdos, call, memory } = createProof(new Map([["OUTPUT  COM", old]]));

    expect(call("CpmPublishPrepare")).toMatchObject({ a: 0, carry: 0 });
    expect(call("CpmDirectBegin")).toMatchObject({ a: 0, carry: 0 });
    const generated = Uint8Array.from(
      { length: 130 },
      (_, index) => (index * 37) & 0xff,
    );
    memory.set(generated, 0x7800);
    memory[0x5a00 + 31] = 1;
    word(memory, 0x5a00 + 32, 0x0800 + generated.length);
    expect(
      call("CpmDirectMap", (active) => {
        active.cpu.ix = 0x5a00;
      }),
    ).toMatchObject({ a: 0, carry: 0 });
    const result = call("CpmDirectCommit");
    expect(result, bdos.events.join(" | ")).toMatchObject({ a: 0, carry: 0 });

    const published = bdos.files.get("OUTPUT  COM");
    expect(published).toBeDefined();
    expect(published!.length).toBe(0x800);
    expect(published!.slice(0, 859)).toEqual(
      memory.slice(symbols.CpmEmbeddedPrefix!, symbols.CpmEmbeddedPrefixEnd!),
    );
    expect(published!.slice(859, 0x700).every((byte) => byte === 0)).toBe(true);
    expect(published!.slice(0x700, 0x700 + generated.length)).toEqual(
      generated,
    );
    expect(
      published!.slice(0x700 + generated.length).every((byte) => byte === 0),
    ).toBe(true);
    expect(bdos.files.has("OUTPUT  $$$")).toBe(false);
    expect(bdos.files.has("OUTPUT  BAK")).toBe(false);
    expect(result).toMatchObject({ instructions: 1_273, tStates: 70_245 });
  });

  it("publishes the maximum admitted image and supports a later command", () => {
    const { bdos, call, memory } = createProof();
    const publish = (length: number, first: number, last: number): void => {
      expect(call("CpmPublishPrepare")).toMatchObject({ a: 0, carry: 0 });
      expect(call("CpmDirectBegin")).toMatchObject({ a: 0, carry: 0 });
      memory[0x7800] = first;
      memory[0x7800 + length - 1] = last;
      memory[0x5a00 + 31] = 1;
      word(memory, 0x5a00 + 32, 0x0800 + length);
      expect(
        call("CpmDirectMap", (active) => {
          active.cpu.ix = 0x5a00;
        }),
      ).toMatchObject({ a: 0, carry: 0 });
      expect(call("CpmDirectCommit")).toMatchObject({ a: 0, carry: 0 });
    };

    publish(0x5d00, 0x11, 0xee);
    const maximum = bdos.files.get("OUTPUT  COM");
    expect(maximum?.length).toBe(0x6400);
    expect(maximum?.[0x0700]).toBe(0x11);
    expect(maximum?.[0x63ff]).toBe(0xee);

    publish(1, 0x7a, 0x7a);
    const replacement = bdos.files.get("OUTPUT  COM");
    expect(replacement?.length).toBe(0x0780);
    expect(replacement?.[0x0700]).toBe(0x7a);
    expect(bdos.files.has("OUTPUT  $$$")).toBe(false);
    expect(bdos.files.has("OUTPUT  BAK")).toBe(false);
  });

  it("retains the old COM when a record write fails", () => {
    const old = Uint8Array.from({ length: 128 }, () => 0xa5);
    const { bdos, call, memory } = createProof(new Map([["OUTPUT  COM", old]]));
    bdos.failWriteCall = 4;
    expect(call("CpmPublishPrepare")).toMatchObject({ a: 0, carry: 0 });
    expect(call("CpmDirectBegin")).toMatchObject({ a: 0, carry: 0 });
    memory[0x7800] = 0x5a;
    memory[0x5a00 + 31] = 1;
    word(memory, 0x5a00 + 32, 0x0801);
    expect(
      call("CpmDirectMap", (active) => {
        active.cpu.ix = 0x5a00;
      }),
    ).toMatchObject({ a: 0, carry: 0 });
    expect(call("CpmDirectCommit")).toMatchObject({ a: 97, carry: 1 });
    expect(bdos.files.get("OUTPUT  COM")).toEqual(old);
    expect(bdos.files.has("OUTPUT  $$$")).toBe(false);
    expect(bdos.files.has("OUTPUT  BAK")).toBe(false);
    expect(call("CpmDirectAbort")).toMatchObject({ a: 0, carry: 0 });
  });

  it("restores the old COM when the final temporary rename fails", () => {
    const old = Uint8Array.from({ length: 128 }, () => 0x3c);
    const { bdos, call, memory } = createProof(new Map([["OUTPUT  COM", old]]));
    bdos.failRenameCall = 2;
    expect(call("CpmPublishPrepare")).toMatchObject({ a: 0, carry: 0 });
    expect(call("CpmDirectBegin")).toMatchObject({ a: 0, carry: 0 });
    memory[0x7800] = 0xc3;
    memory[0x5a00 + 31] = 1;
    word(memory, 0x5a00 + 32, 0x0801);
    expect(
      call("CpmDirectMap", (active) => {
        active.cpu.ix = 0x5a00;
      }),
    ).toMatchObject({ a: 0, carry: 0 });
    expect(call("CpmDirectCommit")).toMatchObject({ a: 97, carry: 1 });
    expect(bdos.files.get("OUTPUT  COM")).toEqual(old);
    expect(bdos.files.has("OUTPUT  $$$")).toBe(false);
    expect(bdos.files.has("OUTPUT  BAK")).toBe(false);
  });

  it("refuses reserved names and abort never deletes an unreserved file", () => {
    for (const reserved of ["OUTPUT  $$$", "OUTPUT  BAK"]) {
      const marker = Uint8Array.from({ length: 128 }, () => 0x69);
      const { bdos, call } = createProof(new Map([[reserved, marker]]));
      expect(call("CpmPublishPrepare")).toMatchObject({ a: 97, carry: 1 });
      expect(call("CpmDirectAbort")).toMatchObject({ a: 0, carry: 0 });
      expect(bdos.files.get(reserved)).toEqual(marker);
    }
  });

  it("aborts a prepared transaction without changing the selected output", () => {
    const old = Uint8Array.from({ length: 128 }, () => 0x4d);
    const { bdos, call } = createProof(new Map([["OUTPUT  COM", old]]));
    expect(call("CpmPublishPrepare")).toMatchObject({ a: 0, carry: 0 });
    expect(call("CpmDirectAbort")).toMatchObject({ a: 0, carry: 0 });
    expect(bdos.files.get("OUTPUT  COM")).toEqual(old);
    expect(bdos.files.has("OUTPUT  $$$")).toBe(false);
    expect(bdos.files.has("OUTPUT  BAK")).toBe(false);
  });

  it("reports measured resident code and mutable workspace", () => {
    expect(symbols.CpmPublisherCodeEnd! - symbols.CpmPublisherCodeStart!).toBe(
      389,
    );
    expect(
      symbols.CpmPublisherWorkspaceEnd! - symbols.CpmPublisherWorkspaceStart!,
    ).toBe(38);
    expect(symbols.CpmPublisherWorkspaceStart).toBe(
      symbols.CpmDirectWorkspaceEnd,
    );
    expect(symbols.CpmPublisherCodeEnd).toBeLessThanOrEqual(
      symbols.CpmHostResidentLimit!,
    );
    expect(symbols.CpmPublisherWorkspaceEnd).toBeLessThanOrEqual(
      symbols.CpmHostWorkspaceLimit!,
    );
  });
});
