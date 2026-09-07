import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { assembleProviderProof, repositoryRoot } from "./fixtures/cpm-source-native/assemble.js";
import { createZ80Runtime, parseIntelHex } from "@jhlagado/debug80-runtime";
import { beforeAll, describe, expect, it } from "vitest";

let proofImage: Uint8Array;
let symbols: Record<string, number>;
let assembled: Awaited<ReturnType<typeof assembleProviderProof>>;

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
  assembled = await assembleProviderProof();
  proofImage = parseIntelHex(assembled.hex).memory;
  symbols = assembled.symbols;
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
    ix: number;
    iy: number;
    carry: number;
    zero: number;
    instructions: number;
    tStates: number;
    stackBytes: number;
  } => {
    const stackCanary = new Uint8Array(32).fill(0xa5);
    activeMemory.set(stackCanary, stack - 64);
    word(activeMemory, stack, sentinel);
    runtime.cpu.sp = stack;
    runtime.cpu.pc = symbols[name]!;
    runtime.cpu.halted = false;
    setup?.(runtime);
    let instructions = 0;
    let tStates = 0;
    let minimumSp = stack;
    while (!runtime.isHalted() && instructions < 100_000) {
      tStates += runtime.step().cycles ?? 0;
      instructions += 1;
      minimumSp = Math.min(minimumSp, runtime.cpu.sp);
    }
    expect(runtime.isHalted(), `${name} did not return`).toBe(true);
    expect(runtime.cpu.pc).toBe(sentinel + 1);
    expect(runtime.cpu.sp).toBe(stack + 2);
    expect(minimumSp).toBeGreaterThanOrEqual(stack - 32);
    expect(activeMemory.slice(stack - 64, stack - 32)).toEqual(stackCanary);
    return {
      a: runtime.cpu.a,
      b: runtime.cpu.b,
      c: runtime.cpu.c,
      de: (runtime.cpu.d << 8) | runtime.cpu.e,
      hl: (runtime.cpu.h << 8) | runtime.cpu.l,
      ix: runtime.cpu.ix,
      iy: runtime.cpu.iy,
      carry: runtime.cpu.flags.C,
      zero: runtime.cpu.flags.Z,
      instructions,
      tStates,
      stackBytes: stack - minimumSp,
    };
  };
  const begin = () => {
    expect(call("CpmSourceProviderBegin")).toMatchObject({ a: 0, carry: 0 });
    const first = call("CpmSourceProviderNext");
    expect(first).toMatchObject({ a: 0, c: 0, carry: 0 });
    return first;
  };
  return { bdos, begin, call, memory: activeMemory };
};

describe("native Nucleus CP/M source and retained-name provider", () => {
  it("assembles the exact current provider bytes and complete symbol surfaces", () => {
    const parsed = parseIntelHex(assembled.hex);
    const ranges = parsed.writeRanges ?? [];
    const bytes = Buffer.concat(ranges.map(({ start, end }) =>
      Buffer.from(parsed.memory.slice(start, end))));
    const hash = (value: Uint8Array) => createHash("sha256").update(value).digest("hex");
    expect(ranges[0]?.start).toBe(0x4100);
    expect(ranges.at(-1)?.end).toBe(0x4440);
    expect(ranges.every((range, index) => index === 0 || ranges[index - 1]!.end === range.start)).toBe(true);
    expect(bytes).toHaveLength(832);
    expect(hash(bytes)).toBe("60979b2f8175a8d05b1cc2a3eac6251e04b6916b635eff5496c6f6640e8ea6c0");
    expect(hash(bytes.subarray(0, 25))).toBe("e31ad64fb487c6476c87cbea9c80d14dd309b205adab0c012bcfd38beb073757");
    expect(hash(bytes.subarray(25))).toBe("42f617f46f0b38a05ca43f325df02ce3de181f27c3bc68e2246e9f660f390bf2");
    expect(Object.keys(symbols)).toHaveLength(224);
    expect(hash(Buffer.from(JSON.stringify(symbols)))).toBe("e2592651cdf520a98e30dbf9239d2aa51214ba55cef5a6d8e90e8766b8c072c4");
    expect(Object.keys(assembled.addresses)).toHaveLength(45);
    expect(hash(Buffer.from(JSON.stringify(assembled.addresses)))).toBe("2573055048892eedca856a701611be358703367704550c329010fcbfd4c82a5d");
    expect(assembled.generation.highWater).toBe(0x4440);
    expect(assembled.generation.finalCursor).toBe(0x4440);
    expect(assembled.project.parts.map(part => part.logicalIdentity.split("/").at(-1))).toEqual([
      "cpm22-target-memory-map.asmi", "cpm22-proof-context.asmi",
      "platform-services-abi.asmi", "cpm22-bdos-call.asm",
      "cpm22-source-provider.asm", "cpm22-source-provider-proof.asm",
    ]);
    for (const part of assembled.project.parts) {
      // Only official ATOM include handling changes compiler-visible headers.
      expect(new TextDecoder().decode(part.compilerBytes)).toBe(
        new TextDecoder().decode(part.originalBytes)
          .replace(/^%INCLUDE[^\r\n]*/gm, line => " ".repeat(line.length)),
      );
    }
    expect(assembled.addresses.CpmSourceProviderBegin).toBe(0x4119);
    expect(assembled.addresses.CpmSourceWorkspaceBase).toBeUndefined();
  });

  it("retains the actual map, service ABI, and configured part capacity", () => {
    expect(symbols.AddressSpaceLimit).toBe(0x10000);
    expect(symbols.NucleusServiceObject).toBe(0x91);
    expect(symbols.CpmSourceWorkspaceBase).toBe(0x5858);
    expect(symbols.CpmHostWorkspaceLimit).toBe(0x6000);

    // This transitional provider still reads the preflight descriptor array;
    // the compiler itself no longer sees source-part events or positions.
    const state = readFileSync(join(repositoryRoot, "asm/vertical-slice/aggregate-call-state.asmi"), "utf8");
    expect(state.split("\n").some(line => {
      const fields = line.split(";")[0]!.trim().split(/\s+/);
      return fields[0] === "SRCPARTS" && [".equ", "EQU"].includes(fields[1]!) &&
        fields.slice(2).join("") === String(symbols.SourcePartCapacity);
    })).toBe(true);
    expect(symbols.SourcePartCapacity).toBe(8);
  });

  it("streams exact concatenated bytes, inserted newlines, and one EOF", () => {
    const first = Uint8Array.from({ length: 130 }, (_, index) => index);
    const second = Uint8Array.of(0xa1, 0xb2, 0xc3);
    const { call, memory } = createProof([
      { name: "FIRST.NU", bytes: first },
      { name: "SECOND.NU", bytes: second },
    ]);
    const run = () => {
      expect(call("CpmSourceProviderBegin")).toMatchObject({ a: 0, carry: 0 });
      const chunks: Uint8Array[] = [];
      const events = Array.from({ length: 7 }, () => {
        const event = call("CpmSourceProviderNext");
        if (event.a === 0) chunks.push(memory.slice(event.hl, event.hl + event.de));
        return event;
      });
      expect(events.map(({ a, c, de }) => [a, c, de])).toEqual([
        [0, 0, 128],
        [0, 0, 2],
        [0, 0, 1],
        [0, 0, 3],
        [0, 0, 1],
        [1, 0, 0],
        [1, 0, 0],
      ]);
      expect(Buffer.concat(chunks)).toEqual(Buffer.concat([
        first, Uint8Array.of(10), second, Uint8Array.of(10),
      ]));
      expect(events[6]).toMatchObject({ a: 1, carry: 1 });
      expect(memory.slice(0x7500, 0x7503)).toEqual(second);
    };
    run();
    run();
  });

  it("does not duplicate final LF and gives an empty middle file one separator", () => {
    const expected = Buffer.from("A\n\nB\n");
    const { call, memory } = createProof([
      { name: "FIRST.NU", bytes: Buffer.from("A\n") },
      { name: "EMPTY.NU", bytes: new Uint8Array() },
      { name: "LAST.NU", bytes: Buffer.from("B\n") },
    ]);
    expect(call("CpmSourceProviderBegin")).toMatchObject({ a: 0, carry: 0 });
    const chunks: Uint8Array[] = [];
    for (;;) {
      const event = call("CpmSourceProviderNext");
      expect(event.c).toBe(0);
      if (event.a === 1) {
        expect(event).toMatchObject({ de: 0, carry: 0 });
        break;
      }
      expect(event).toMatchObject({ a: 0, carry: 0 });
      chunks.push(memory.slice(event.hl, event.hl + event.de));
    }
    expect(Buffer.concat(chunks)).toEqual(expected);
  });

  it("maps a retained global offset back to its owning CP/M file", () => {
    const second = Buffer.from("ABC\n");
    const { call, memory } = createProof([
      { name: "FIRST.NU", bytes: Buffer.from("X") },
      { name: "SECOND.NU", bytes: second },
    ]);
    expect(call("CpmSourceProviderBegin")).toMatchObject({ carry: 0 });
    expect(call("CpmSourceProviderNext")).toMatchObject({ a: 0, de: 1, carry: 0 });
    expect(call("CpmSourceProviderNext")).toMatchObject({ a: 0, de: 1, carry: 0 });
    const secondEvent = call("CpmSourceProviderNext");
    expect(secondEvent).toMatchObject({ a: 0, c: 0, de: 4, carry: 0 });
    const retained = call("CpmSourceProviderRetainName", (active) => {
      active.cpu.h = secondEvent.hl >>> 8;
      active.cpu.l = secondEvent.hl & 0xff;
      active.cpu.b = 3;
      active.cpu.c = 0;
      active.cpu.d = 0;
      active.cpu.e = 2;
    });
    expect(retained).toMatchObject({ hl: 1, carry: 0 });
    const materialized = call("CpmSourceProviderMaterializeName", (active) => {
      active.cpu.h = 0;
      active.cpu.l = 1;
    });
    expect(materialized).toMatchObject({ b: 3, carry: 0 });
    expect(memory.slice(materialized.hl, materialized.hl + 3)).toEqual(
      Uint8Array.from(Buffer.from("ABC")),
    );
  });

  it("retains, compares, materializes, and reuses a cross-record name", () => {
    const source = new Uint8Array(256);
    source.set(Buffer.from("ABC"), 127);
    source.set(Buffer.from("XYZ"), 140);
    const { begin, call, memory } = createProof([{ name: "NAME.NU", bytes: source }]);
    begin();
    const retained = call("CpmSourceProviderRetainName", (active) => {
      active.cpu.h = 0x75;
      active.cpu.l = 0;
      active.cpu.b = 3;
      active.cpu.c = 0;
      active.cpu.d = 0;
      active.cpu.e = 127;
    });
    expect(retained).toMatchObject({ hl: 1, b: 3, c: 0, de: 127, carry: 0 });

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
        active.cpu.c = 0;
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
        active.cpu.c = 0;
        active.cpu.d = 0;
        active.cpu.e = 127;
      }),
    ).toMatchObject({ hl: 1, carry: 0 });
    expect(memory[symbols.CpmSourceRetainedCount!]).toBe(2);
  });

  it.each([
    ["another global source position", 0, 257],
    ["past the parser's source end", 0, 0xffff],
  ])(
    "reuses unchanged materialized name identity at %s",
    (_name, part, offset) => {
      const source = new Uint8Array(256);
      source.set(Buffer.from("ABC"), 127);
      const { begin, call, memory } = createProof([
        { name: "FIRST.NU", bytes: source },
        { name: "SECOND.NU", bytes: Buffer.from("XYZ") },
      ]);
      begin();
      memory.set(Buffer.from("ABC"), 0x7500);
      const first = call("CpmSourceProviderRetainName", (active) => {
        active.cpu.h = 0x75;
        active.cpu.l = 0;
        active.cpu.b = 3;
        active.cpu.c = 0;
        active.cpu.d = 0;
        active.cpu.e = 127;
      });
      expect(first).toMatchObject({ hl: 1, carry: 0 });
      const materialized = call(
        "CpmSourceProviderMaterializeName",
        (active) => {
          active.cpu.h = 0;
          active.cpu.l = 1;
        },
      );
      const retained = call("CpmSourceProviderRetainName", (active) => {
        active.cpu.h = materialized.hl >>> 8;
        active.cpu.l = materialized.hl & 0xff;
        active.cpu.b = 3;
        active.cpu.c = part;
        active.cpu.d = offset >>> 8;
        active.cpu.e = offset & 0xff;
        active.cpu.ix = 0x1234;
        active.cpu.iy = 0x5678;
      });
      expect(retained).toMatchObject({
        hl: 1,
        b: 3,
        c: part,
        de: offset,
        ix: 0x1234,
        iy: 0x5678,
        carry: 0,
      });
      // Includes the proof BDOS shim, not a real operating system's own stack.
      expect(retained).toMatchObject({
        instructions: 368,
        tStates: 3_646,
        stackBytes: 28,
      });
      expect(memory[symbols.CpmSourceRetainedCount!]).toBe(1);
      const again = call("CpmSourceProviderMaterializeName", (active) => {
        active.cpu.h = retained.hl >>> 8;
        active.cpu.l = retained.hl & 0xff;
      });
      expect(memory.slice(again.hl, again.hl + 3)).toEqual(
        Uint8Array.from(Buffer.from("ABC")),
      );
    },
  );

  it.each([
    ["a different length", "AB", 127],
    ["modified scratch bytes", "XYZ", 140],
  ])(
    "does not reuse materialized identity for %s",
    (_name, spelling, offset) => {
      const source = new Uint8Array(256);
      source.set(Buffer.from("ABC"), 127);
      source.set(Buffer.from("XYZ"), 140);
      const { begin, call, memory } = createProof([
        { name: "NAME.NU", bytes: source },
      ]);
      begin();
      memory.set(Buffer.from("ABC"), 0x7500);
      call("CpmSourceProviderRetainName", (active) => {
        active.cpu.h = 0x75;
        active.cpu.l = 0;
        active.cpu.b = 3;
        active.cpu.c = 0;
        active.cpu.d = 0;
        active.cpu.e = 127;
      });
      const materialized = call(
        "CpmSourceProviderMaterializeName",
        (active) => {
          active.cpu.h = 0;
          active.cpu.l = 1;
        },
      );
      memory.set(Buffer.from(spelling), materialized.hl);
      const retained = call("CpmSourceProviderRetainName", (active) => {
        active.cpu.h = materialized.hl >>> 8;
        active.cpu.l = materialized.hl & 0xff;
        active.cpu.b = spelling.length;
        active.cpu.c = 0;
        active.cpu.d = offset >>> 8;
        active.cpu.e = offset & 0xff;
      });
      expect(retained).toMatchObject({ hl: 2, carry: 0 });
      const again = call("CpmSourceProviderMaterializeName", (active) => {
        active.cpu.h = 0;
        active.cpu.l = 2;
      });
      expect(again.b).toBe(spelling.length);
      expect(memory.slice(again.hl, again.hl + again.b)).toEqual(
        Uint8Array.from(Buffer.from(spelling)),
      );
    },
  );

  it.each([
    ["changed bytes", "XYZ", 3],
    ["changed length", "ABC", 2],
    ["empty name", "ABC", 0],
  ])(
    "does not bypass fresh-source bounds after materialization with %s",
    (_name, spelling, length) => {
      const source = Buffer.from("ABC");
      const { begin, call, memory } = createProof([
        { name: "NAME.NU", bytes: source },
      ]);
      begin();
      memory.set(source, 0x7500);
      call("CpmSourceProviderRetainName", (active) => {
        active.cpu.h = 0x75;
        active.cpu.l = 0;
        active.cpu.b = 3;
        active.cpu.c = 0;
        active.cpu.d = 0;
        active.cpu.e = 0;
      });
      const materialized = call(
        "CpmSourceProviderMaterializeName",
        (active) => {
          active.cpu.h = 0;
          active.cpu.l = 1;
        },
      );
      memory.set(Buffer.from(spelling), materialized.hl);
      const table = memory.slice(
        symbols.CpmSourceRetainedTable!,
        symbols.CpmSourceRetainedTableEnd!,
      );
      expect(
        call("CpmSourceProviderRetainName", (active) => {
          active.cpu.h = materialized.hl >>> 8;
          active.cpu.l = materialized.hl & 0xff;
          active.cpu.b = length;
          active.cpu.c = 0;
          active.cpu.d = 0xff;
          active.cpu.e = 0xff;
        }),
      ).toMatchObject({ a: 1, carry: 1 });
      expect(memory[symbols.CpmSourceRetainedCount!]).toBe(1);
      expect(
        memory.slice(
          symbols.CpmSourceRetainedTable!,
          symbols.CpmSourceRetainedTableEnd!,
        ),
      ).toEqual(table);
    },
  );

  it("preserves retained identities after a comparison read failure and retries successfully", () => {
    const source = Buffer.from("ABC");
    const { bdos, begin, call, memory } = createProof([
      { name: "NAME.NU", bytes: source },
    ]);
    begin();
    memory.set(source, 0x7500);
    call("CpmSourceProviderRetainName", (active) => {
      active.cpu.h = 0x75;
      active.cpu.l = 0;
      active.cpu.b = 3;
      active.cpu.c = 0;
      active.cpu.d = 0;
      active.cpu.e = 0;
    });
    const materialized = call("CpmSourceProviderMaterializeName", (active) => {
      active.cpu.h = 0;
      active.cpu.l = 1;
    });
    const files = new Map(bdos.files);
    bdos.files.clear();
    const table = memory.slice(
      symbols.CpmSourceRetainedTable!,
      symbols.CpmSourceRetainedTableEnd!,
    );
    const retain = () =>
      call("CpmSourceProviderRetainName", (active) => {
        active.cpu.h = materialized.hl >>> 8;
        active.cpu.l = materialized.hl & 0xff;
        active.cpu.b = 3;
        active.cpu.c = 0;
        active.cpu.d = 0xff;
        active.cpu.e = 0xff;
        active.cpu.ix = 0x1234;
        active.cpu.iy = 0x5678;
      });
    expect(retain()).toMatchObject({
      a: 6,
      carry: 1,
      b: 3,
      c: 0,
      de: 0xffff,
      ix: 0x1234,
      iy: 0x5678,
    });
    expect(memory[symbols.CpmSourceRetainedCount!]).toBe(1);
    expect(
      memory.slice(
        symbols.CpmSourceRetainedTable!,
        symbols.CpmSourceRetainedTableEnd!,
      ),
    ).toEqual(table);
    for (const [name, bytes] of files) bdos.files.set(name, bytes);
    expect(retain()).toMatchObject({ a: 0, hl: 1, carry: 0 });
    expect(memory[symbols.CpmSourceRetainedCount!]).toBe(1);
  });

  it("materializes the maximum 255-byte name across three records", () => {
    const source = Uint8Array.from(
      { length: 300 },
      (_, index) => (index * 29) & 0xff,
    );
    const { begin, call, memory } = createProof([{ name: "LONG.NU", bytes: source }]);
    begin();
    expect(
      call("CpmSourceProviderRetainName", (active) => {
        active.cpu.h = 0x75;
        active.cpu.l = 0;
        active.cpu.b = 255;
        active.cpu.c = 0;
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
    const { begin, call } = createProof([{ name: "CAP.NU", bytes: source }]);
    begin();
    for (let handle = 1; handle <= 255; handle += 1) {
      expect(
        call("CpmSourceProviderRetainName", (active) => {
          active.cpu.h = 0x75;
          active.cpu.l = 0;
          active.cpu.b = 1;
          active.cpu.c = 0;
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
        active.cpu.c = 0;
        active.cpu.d = 0;
        active.cpu.e = 0;
      }),
    ).toMatchObject({ a: 4, carry: 1 });
    for (const setup of [
      { length: 0, bank: 0, offset: 0 },
      { length: 1, bank: 1, offset: 0 },
      { length: 1, bank: 0, offset: 1 },
    ]) {
      expect(
        call("CpmSourceProviderRetainName", (active) => {
          active.cpu.h = 0x75;
          active.cpu.l = 0;
          active.cpu.b = setup.length;
          active.cpu.c = setup.bank;
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
    ).toBe(807);
    expect(symbols.CpmBdosCallCodeEnd! - symbols.CpmBdosCallCodeStart!).toBe(
      25,
    );
    expect(
      symbols.CpmSourceWorkspaceEnd! - symbols.CpmSourceWorkspaceBase!,
    ).toBe(1_479);
    expect(symbols.CpmSourceWorkspaceEnd).toBeLessThanOrEqual(
      symbols.CpmHostWorkspaceLimit!,
    );
  });
});
