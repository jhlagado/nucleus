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

const paddedFile = (bytes: Uint8Array): Uint8Array => {
  const file = new Uint8Array(Math.ceil(bytes.length / 128) * 128);
  file.set(bytes);
  return file;
};

const installDescriptor = (
  memory: Uint8Array,
  ordinal: number,
  name: string,
  length: number,
): void => {
  const [stem = "", extension = ""] = name.toUpperCase().split(".");
  const address = symbols.CpmSourcePartDescriptors! + ordinal * 14;
  memory.fill(0, address, address + 14);
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
  word(memory, address + 12, length);
};

class SourceBdos {
  public dma = 0x0080;
  public readonly calls: number[] = [];
  private readonly cursors = new Map<number, number>();

  public constructor(public readonly files: Map<string, Uint8Array>) {}

  public dispatch(runtime: ReturnType<typeof createZ80Runtime>): void {
    const memory = runtime.hardware.memory;
    const fcb = (runtime.cpu.d << 8) | runtime.cpu.e;
    const operation = runtime.cpu.c;
    this.calls.push(operation);
    runtime.cpu.ix = 0xdead;
    runtime.cpu.iy = 0xbeef;
    if (operation === 26) {
      this.dma = fcb;
      runtime.cpu.a = 0;
      return;
    }
    const file = this.files.get(fcbName(memory, fcb));
    if (operation === 15) {
      this.cursors.set(fcb, 0);
      runtime.cpu.a = file === undefined ? 0xff : 0;
      return;
    }
    if (operation === 20) {
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
    if (operation === 33) {
      const record =
        memory[fcb + 33]! |
        (memory[fcb + 34]! << 8) |
        (memory[fcb + 35]! << 16);
      const offset = record * 128;
      if (file === undefined || offset + 128 > file.length) {
        runtime.cpu.a = 1;
      } else {
        memory.set(file.slice(offset, offset + 128), this.dma);
        runtime.cpu.a = 0;
      }
      return;
    }
    throw new Error(`unexpected source-provider BDOS function ${operation}`);
  }
}

beforeAll(async () => {
  const assembled = await compile(
    path.join(verticalSlice, "cpm22-source-provider-proof.asm"),
    {
      emitHex: true,
      emitD8m: true,
      registerContracts: "strict",
      registerContractsInterfaces: [
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
    throw new Error("AZM omitted CP/M source-provider proof artifacts");
  }
  proofImage = parseIntelHex(hex.text).memory;
  symbols = Object.fromEntries(
    map.json.symbols.flatMap((entry) => {
      const value = entry.address ?? entry.value;
      return value === undefined ? [] : [[entry.name, value]];
    }),
  );
});

const createProof = (parts: readonly { name: string; bytes: Uint8Array }[]) => {
  const memory = proofImage.slice();
  memory.set([0xd3, 0xe1, 0xc9], 0x0005);
  const sentinel = 0x3f00;
  const stack = 0xe300;
  memory[sentinel] = 0x76;
  const files = new Map(
    parts.map(({ name, bytes }) => {
      const [stem = "", extension = ""] = name.toUpperCase().split(".");
      return [
        `${stem.padEnd(8, " ").slice(0, 8)}${extension.padEnd(3, " ").slice(0, 3)}`,
        paddedFile(bytes),
      ] as const;
    }),
  );
  const bdos = new SourceBdos(files);
  let runtime!: ReturnType<typeof createZ80Runtime>;
  runtime = createZ80Runtime(
    { memory, startAddress: symbols.CpmSourceProviderBegin! },
    symbols.CpmSourceProviderBegin!,
    { write: () => bdos.dispatch(runtime) },
  );
  const activeMemory = runtime.hardware.memory;
  parts.forEach(({ name, bytes }, ordinal) =>
    installDescriptor(activeMemory, ordinal, name, bytes.length),
  );
  activeMemory[symbols.CpmSourcePartCount!] = parts.length;

  const call = (
    name: string,
    setup?: (active: typeof runtime) => void,
  ): {
    a: number;
    b: number;
    c: number;
    de: number;
    hl: number;
    carry: number;
    zero: number;
    instructions: number;
    tStates: number;
  } => {
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
      b: runtime.cpu.b,
      c: runtime.cpu.c,
      de: (runtime.cpu.d << 8) | runtime.cpu.e,
      hl: (runtime.cpu.h << 8) | runtime.cpu.l,
      carry: runtime.cpu.flags.C,
      zero: runtime.cpu.flags.Z,
      instructions,
      tStates,
    };
  };
  return { bdos, call, memory: activeMemory };
};

describe("native Nucleus CP/M source and retained-name provider", () => {
  it("streams exact one-based multipart events and resets for another command", () => {
    const first = Uint8Array.from({ length: 130 }, (_, index) => index);
    const second = Uint8Array.of(0xa1, 0xb2, 0xc3);
    const { call, memory } = createProof([
      { name: "FIRST.NU", bytes: first },
      { name: "SECOND.NU", bytes: second },
    ]);
    const run = () => {
      expect(call("CpmSourceProviderBegin")).toMatchObject({ a: 0, carry: 0 });
      const events = Array.from({ length: 9 }, () =>
        call("CpmSourceProviderNext"),
      );
      expect(events.map(({ a, c, de }) => [a, c, de])).toEqual([
        [1, 1, 0],
        [0, 1, 128],
        [0, 1, 2],
        [2, 1, 0],
        [1, 2, 0],
        [0, 2, 3],
        [2, 2, 0],
        [3, 0, 0],
        [1, 0, 0],
      ]);
      expect(events[8]).toMatchObject({ a: 1, carry: 1 });
      expect(memory.slice(0x7500, 0x7503)).toEqual(second);
    };
    run();
    run();
  });

  it("retains, compares, materializes, and reuses a cross-record name", () => {
    const source = new Uint8Array(256);
    source.set(Buffer.from("ABC"), 127);
    source.set(Buffer.from("XYZ"), 140);
    const { call, memory } = createProof([{ name: "NAME.NU", bytes: source }]);
    expect(call("CpmSourceProviderBegin")).toMatchObject({ a: 0, carry: 0 });
    const retained = call("CpmSourceProviderRetainName", (active) => {
      active.cpu.h = 0x75;
      active.cpu.l = 0;
      active.cpu.b = 3;
      active.cpu.c = 1;
      active.cpu.d = 0;
      active.cpu.e = 127;
    });
    expect(retained).toMatchObject({ hl: 1, b: 3, c: 1, de: 127, carry: 0 });

    memory.set(Buffer.from("ABC"), 0x7400);
    expect(
      call("CpmSourceProviderCompareName", (active) => {
        active.cpu.h = 0;
        active.cpu.l = 1;
        active.cpu.ix = 0x7400;
        active.cpu.b = 3;
      }),
    ).toMatchObject({ zero: 1, carry: 0 });
    memory[0x7402] = "X".charCodeAt(0);
    expect(
      call("CpmSourceProviderCompareName", (active) => {
        active.cpu.h = 0;
        active.cpu.l = 1;
        active.cpu.ix = 0x7400;
        active.cpu.b = 3;
      }),
    ).toMatchObject({ zero: 0, carry: 0 });

    const materialized = call("CpmSourceProviderMaterializeName", (active) => {
      active.cpu.h = 0;
      active.cpu.l = 1;
      active.cpu.c = 0x55;
      active.cpu.d = 0x12;
      active.cpu.e = 0x34;
    });
    expect(materialized).toMatchObject({ b: 3, c: 0x55, de: 0x1234, carry: 0 });
    expect(materialized).toMatchObject({ instructions: 321, tStates: 3_281 });
    expect(memory.slice(materialized.hl, materialized.hl + 3)).toEqual(
      Uint8Array.from(Buffer.from("ABC")),
    );
    expect(
      call("CpmSourceProviderRetainName", (active) => {
        active.cpu.h = 0x75;
        active.cpu.l = 0;
        active.cpu.b = 3;
        active.cpu.c = 1;
        active.cpu.d = 0;
        active.cpu.e = 140;
      }),
    ).toMatchObject({ hl: 2, carry: 0 });
    expect(
      call("CpmSourceProviderCompareName", (active) => {
        active.cpu.h = 0;
        active.cpu.l = 2;
        active.cpu.ix = materialized.hl;
        active.cpu.b = 3;
      }),
    ).toMatchObject({ zero: 0, carry: 0 });
    expect(memory.slice(materialized.hl, materialized.hl + 3)).toEqual(
      Uint8Array.from(Buffer.from("ABC")),
    );
    expect(
      call("CpmSourceProviderRetainName", (active) => {
        active.cpu.h = materialized.hl >>> 8;
        active.cpu.l = materialized.hl & 0xff;
        active.cpu.b = 3;
        active.cpu.c = 1;
        active.cpu.d = 0;
        active.cpu.e = 127;
      }),
    ).toMatchObject({ hl: 1, carry: 0 });
    expect(memory[symbols.CpmSourceRetainedCount!]).toBe(2);
  });

  it("materializes the maximum 255-byte name across three records", () => {
    const source = Uint8Array.from(
      { length: 300 },
      (_, index) => (index * 29) & 0xff,
    );
    const { call, memory } = createProof([{ name: "LONG.NU", bytes: source }]);
    expect(call("CpmSourceProviderBegin")).toMatchObject({ carry: 0 });
    expect(
      call("CpmSourceProviderRetainName", (active) => {
        active.cpu.h = 0x75;
        active.cpu.l = 0;
        active.cpu.b = 255;
        active.cpu.c = 1;
        active.cpu.d = 0;
        active.cpu.e = 1;
      }),
    ).toMatchObject({ hl: 1, carry: 0 });
    const materialized = call("CpmSourceProviderMaterializeName", (active) => {
      active.cpu.h = 0;
      active.cpu.l = 1;
    });
    expect(materialized).toMatchObject({ b: 255, carry: 0 });
    expect(memory.slice(materialized.hl, materialized.hl + 255)).toEqual(
      source.slice(1, 256),
    );
  });

  it("enforces retained-handle and exact source-position capacities", () => {
    const source = Uint8Array.of(0x41);
    const { call } = createProof([{ name: "CAP.NU", bytes: source }]);
    expect(call("CpmSourceProviderBegin")).toMatchObject({ carry: 0 });
    for (let handle = 1; handle <= 255; handle += 1) {
      expect(
        call("CpmSourceProviderRetainName", (active) => {
          active.cpu.h = 0x75;
          active.cpu.l = 0;
          active.cpu.b = 1;
          active.cpu.c = 1;
          active.cpu.d = 0;
          active.cpu.e = 0;
        }),
      ).toMatchObject({ hl: handle, carry: 0 });
    }
    expect(
      call("CpmSourceProviderRetainName", (active) => {
        active.cpu.h = 0x75;
        active.cpu.l = 0;
        active.cpu.b = 1;
        active.cpu.c = 1;
        active.cpu.d = 0;
        active.cpu.e = 0;
      }),
    ).toMatchObject({ a: 4, carry: 1 });
    for (const setup of [
      { length: 0, part: 1, offset: 0 },
      { length: 1, part: 0, offset: 0 },
      { length: 1, part: 1, offset: 1 },
    ]) {
      expect(
        call("CpmSourceProviderRetainName", (active) => {
          active.cpu.h = 0x75;
          active.cpu.l = 0;
          active.cpu.b = setup.length;
          active.cpu.c = setup.part;
          active.cpu.d = setup.offset >>> 8;
          active.cpu.e = setup.offset & 0xff;
        }),
      ).toMatchObject({ a: 1, carry: 1 });
    }
    for (const handle of [0, 0x0100]) {
      expect(
        call("CpmSourceProviderMaterializeName", (active) => {
          active.cpu.h = handle >>> 8;
          active.cpu.l = handle & 0xff;
        }),
      ).toMatchObject({ a: 1, carry: 1 });
    }
  });

  it("accepts exactly one through eight configured parts", () => {
    const { call, memory } = createProof([
      { name: "ONE.NU", bytes: Uint8Array.of(1) },
    ]);
    for (const count of [1, 8]) {
      memory[symbols.CpmSourcePartCount!] = count;
      expect(call("CpmSourceProviderBegin")).toMatchObject({ a: 0, carry: 0 });
    }
    for (const count of [0, 9]) {
      memory[symbols.CpmSourcePartCount!] = count;
      expect(call("CpmSourceProviderBegin")).toMatchObject({ a: 1, carry: 1 });
    }
  });

  it("reports storage failure when a preflighted source disappears", () => {
    const { bdos, call } = createProof([
      { name: "GONE.NU", bytes: Uint8Array.of(1) },
    ]);
    bdos.files.clear();
    expect(call("CpmSourceProviderBegin")).toMatchObject({ carry: 0 });
    expect(call("CpmSourceProviderNext")).toMatchObject({ a: 6, carry: 1 });
  });

  it("reports exact code and simultaneous workspace accounts", () => {
    expect(
      symbols.CpmSourceProviderCodeEnd! - symbols.CpmSourceProviderCodeStart!,
    ).toBe(722);
    expect(symbols.CpmBdosCallCodeEnd! - symbols.CpmBdosCallCodeStart!).toBe(
      25,
    );
    expect(
      symbols.CpmSourceWorkspaceEnd! - symbols.CpmSourceWorkspaceBase!,
    ).toBe(1_476);
    expect(symbols.CpmSourceWorkspaceEnd).toBeLessThanOrEqual(
      symbols.CpmHostWorkspaceLimit!,
    );
  });
});
