import { assembleNativeCpmProof } from "../scripts/assemble-native-cpm.mjs";
import { createZ80Runtime, parseIntelHex } from "@jhlagado/debug80-runtime";
import { describe, expect, it } from "vitest";

import { bundledRuntimeProvider } from "../src/runtime-catalog.js";

describe("native Nucleus CP/M runtime provider", () => {
  it("copies only the exact linked runtime and patches its initialized bounds", async () => {
    const { hex, symbols } = await assembleNativeCpmProof(
      "cpm22-runtime-provider-proof.asm",
    );
    const memory = parseIntelHex(hex).memory;
    const runtime = createZ80Runtime(
      { memory, startAddress: symbols.CpmDirectBegin },
      symbols.CpmDirectBegin,
    );
    const sentinel = 0x5a00;
    const stack = 0xe300;
    runtime.hardware.memory[sentinel] = 0x76;
    const call = (
      entry: string,
      setup?: (active: typeof runtime) => void,
    ): { a: number; carry: number } => {
      runtime.hardware.memory[stack] = sentinel & 0xff;
      runtime.hardware.memory[stack + 1] = sentinel >>> 8;
      runtime.cpu.sp = stack;
      runtime.cpu.pc = symbols[entry];
      runtime.cpu.halted = false;
      setup?.(runtime);
      let instructions = 0;
      while (!runtime.isHalted() && instructions < 50_000) {
        runtime.step();
        instructions += 1;
      }
      expect(runtime.isHalted(), `${entry} did not return`).toBe(true);
      expect(runtime.cpu.pc).toBe(sentinel + 1);
      expect(runtime.cpu.sp).toBe(stack + 2);
      return { a: runtime.cpu.a, carry: runtime.cpu.flags.C };
    };

    expect(call("CpmDirectBegin")).toEqual({ a: 0, carry: 0 });
    expect(
      call("CpmDirectRuntimeImage", (active) => {
        active.cpu.a = 0;
        active.cpu.b = 732 >>> 8;
        active.cpu.c = 732 & 0xff;
        active.cpu.d = 0;
        active.cpu.e = 10;
        active.cpu.h = 0x08;
        active.cpu.l = 0x03;
        active.cpu.ix = symbols.CpmRuntimeProofContext;
      }),
    ).toEqual({ a: 0, carry: 0 });
    expect(runtime.hardware.memory.slice(0x7803, 0x7803 + 732)).toEqual(
      runtime.hardware.memory.slice(
        symbols.CpmEmbeddedRuntime,
        symbols.CpmEmbeddedRuntimeEnd,
      ),
    );

    expect(
      call("CpmDirectRuntimeInitial", (active) => {
        active.cpu.a = 0;
        active.cpu.b = 0;
        active.cpu.c = 77;
        active.cpu.d = 0;
        active.cpu.e = 10;
        active.cpu.h = 0x58;
        active.cpu.l = 0;
        active.cpu.ix = symbols.CpmRuntimeProofContext;
      }),
    ).toEqual({ a: 0, carry: 0 });

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
    const expected = bundledRuntimeProvider.get(10, context);
    expect(expected).toBeDefined();
    expect(runtime.hardware.memory.slice(0xc800, 0xc800 + 77)).toEqual(
      expected!.initialBytes,
    );

    expect(
      call("CpmDirectRuntimeImage", (active) => {
        active.cpu.a = 0;
        active.cpu.b = 732 >>> 8;
        active.cpu.c = 732 & 0xff;
        active.cpu.d = 0;
        active.cpu.e = 9;
        active.cpu.h = 0x08;
        active.cpu.l = 0x03;
        active.cpu.ix = symbols.CpmRuntimeProofContext;
      }),
    ).toEqual({ a: 95, carry: 1 });

    expect(
      symbols.CpmRuntimeProviderCodeEnd - symbols.CpmRuntimeProviderCodeStart,
    ).toBe(127);
    expect(symbols.CpmEmbeddedRuntimeEnd - symbols.CpmEmbeddedRuntime).toBe(
      732,
    );
    expect(symbols.CpmEmbeddedInitialEnd - symbols.CpmEmbeddedInitial).toBe(77);
  });
});
