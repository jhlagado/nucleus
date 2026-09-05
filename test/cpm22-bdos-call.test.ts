import { createZ80Runtime, parseIntelHex } from "@jhlagado/debug80-runtime";
import { beforeAll, describe, expect, it } from "vitest";
import { assembleProviderProof } from "./fixtures/cpm-source-native/assemble.js";

let image: Uint8Array;
let symbols: Readonly<Record<string, number>>;
type Runtime = ReturnType<typeof createZ80Runtime>;

beforeAll(async () => {
  const proof = await assembleProviderProof();
  image = parseIntelHex(proof.hex).memory;
  symbols = proof.symbols;
});

const execute = (entry: string, setup: (runtime: Runtime) => void,
  bdos?: (runtime: Runtime) => void): Runtime => {
  const memory = image.slice();
  const stack = 0xe300;
  const sentinel = 0x3f00;
  memory[sentinel] = 0x76;
  memory[stack] = sentinel & 255;
  memory[stack + 1] = sentinel >>> 8;
  memory.fill(0xa5, stack - 32, stack - 8);
  memory.set([0xd3, 0xe1, 0xc9], 5);
  let runtime!: Runtime;
  runtime = createZ80Runtime({ memory, startAddress: symbols[entry]! }, symbols[entry]!, {
    write: () => {
      if (!bdos) throw new Error("FCB construction must not call BDOS");
      bdos(runtime);
    },
  });
  runtime.cpu.sp = stack;
  setup(runtime);
  let steps = 0;
  let minimumSp = stack;
  while (!runtime.isHalted() && steps++ < 1_000) {
    runtime.step();
    minimumSp = Math.min(minimumSp, runtime.cpu.sp);
  }
  expect(runtime.isHalted()).toBe(true);
  expect(runtime.cpu.pc).toBe(sentinel + 1);
  expect(runtime.cpu.sp).toBe(stack + 2);
  expect(minimumSp).toBeGreaterThanOrEqual(stack - 6);
  expect(runtime.hardware.memory.slice(stack - 32, stack - 8)).toEqual(new Uint8Array(24).fill(0xa5));
  return runtime;
};

describe("native CP/M BDOS and FCB leaf contracts", () => {
  it.each([{ carry: 0, zero: 1 }, { carry: 1, zero: 0 }])(
    "passes C/DE, preserves IX/IY and returns BDOS A/flags: %j", ({ carry, zero }) => {
      let calls = 0;
      const runtime = execute("CpmCallBdos", active => {
        active.cpu.c = 33;
        active.cpu.d = 0x51;
        active.cpu.e = 0xfa;
        active.cpu.ix = 0x1234;
        active.cpu.iy = 0x5678;
      }, active => {
        calls++;
        expect(active.cpu.c).toBe(33);
        expect((active.cpu.d << 8) | active.cpu.e).toBe(0x51fa);
        active.cpu.ix = 0xdead;
        active.cpu.iy = 0xbeef;
        active.cpu.b = 0x12;
        active.cpu.c = 0x34;
        active.cpu.d = 0x56;
        active.cpu.e = 0x78;
        active.cpu.h = 0x9a;
        active.cpu.l = 0xbc;
        active.cpu.a = 0x83;
        active.cpu.flags.C = carry;
        active.cpu.flags.Z = zero;
      });
      expect(calls).toBe(1);
      expect(runtime.cpu.ix).toBe(0x1234);
      expect(runtime.cpu.iy).toBe(0x5678);
      expect(runtime.cpu.a).toBe(0x83);
      expect(runtime.cpu.flags.C).toBe(carry);
      expect(runtime.cpu.flags.Z).toBe(zero);
      // Ordinary registers are deliberately clobbered, not accidentally saved.
      expect([runtime.cpu.b, runtime.cpu.c, runtime.cpu.d, runtime.cpu.e, runtime.cpu.h, runtime.cpu.l])
        .toEqual([0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc]);
    },
  );

  it.each([{ source: 0x5000, destination: 0x5100 }, { source: 0x50fa, destination: 0x51f9 }])(
    "copies all twelve name bytes and clears exactly twenty-four tail bytes: %j", ({ source, destination }) => {
      const name = Uint8Array.of(3, 0x41, 0x42, 0x43, 0, 0xff, 0x20, 0x58, 0x59, 0x4e, 0x55, 0x20);
      const runtime = execute("CpmBuildFcb", active => {
        const memory = active.hardware.memory;
        memory.fill(0x9d, source - 8, source + 20);
        memory.set(name, source);
        memory.fill(0xa5, destination - 8, destination + 44);
        active.cpu.h = source >>> 8;
        active.cpu.l = source & 255;
        active.cpu.d = destination >>> 8;
        active.cpu.e = destination & 255;
        active.cpu.ix = 0x1234;
        active.cpu.iy = 0x5678;
        active.cpu.flags.C = 1;
      });
      const memory = runtime.hardware.memory;
      expect(memory.slice(source, source + 12)).toEqual(name);
      expect(memory.slice(source - 8, source)).toEqual(new Uint8Array(8).fill(0x9d));
      expect(memory.slice(source + 12, source + 20)).toEqual(new Uint8Array(8).fill(0x9d));
      expect(memory.slice(destination, destination + 12)).toEqual(name);
      expect(memory.slice(destination + 12, destination + 36)).toEqual(new Uint8Array(24));
      expect(memory.slice(destination - 8, destination)).toEqual(new Uint8Array(8).fill(0xa5));
      expect(memory.slice(destination + 36, destination + 44)).toEqual(new Uint8Array(8).fill(0xa5));
      expect((runtime.cpu.h << 8) | runtime.cpu.l).toBe(source + 12);
      expect((runtime.cpu.d << 8) | runtime.cpu.e).toBe(destination + 36);
      expect([runtime.cpu.a, runtime.cpu.b, runtime.cpu.c]).toEqual([0, 0, 0]);
      expect(runtime.cpu.ix).toBe(0x1234);
      expect(runtime.cpu.iy).toBe(0x5678);
      expect(runtime.cpu.flags.C).toBe(0);
      expect(runtime.cpu.flags.Z).toBe(1);
    },
  );
});
