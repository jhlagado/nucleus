import path from "node:path";
import { fileURLToPath } from "node:url";

import { compile } from "@jhlagado/azm/compile";
import { createZ80Runtime, parseIntelHex } from "@jhlagado/debug80-runtime";
import { describe, expect, it } from "vitest";

const directory = path.dirname(fileURLToPath(import.meta.url));
const verticalSlice = path.join(directory, "..", "asm", "vertical-slice");

const symbolsFor = async (
  name: string,
  interfaces: readonly string[],
): Promise<Record<string, number>> => {
  const assembled = await compile(path.join(verticalSlice, name), {
    emitD8m: true,
    registerContracts: "strict",
    registerContractsInterfaces: [...interfaces],
  });
  expect(
    assembled.diagnostics.filter(({ severity }) => severity === "error"),
  ).toEqual([]);
  const map = assembled.artifacts.find(({ kind }) => kind === "d8m");
  if (map?.kind !== "d8m") throw new Error(`AZM omitted ${name}'s map`);
  return Object.fromEntries(
    map.json.symbols.flatMap((entry) => {
      const value = entry.address ?? entry.value;
      return value === undefined ? [] : [[entry.name, value]];
    }),
  );
};

describe("native Nucleus CP/M output candidates", () => {
  it("measures the direct sink against the existing NOBJ producer and materializer", async () => {
    const expression = path.join(
      verticalSlice,
      "expression-generated-z80.asmi",
    );
    const [direct, producer, consumer] = await Promise.all([
      symbolsFor("cpm22-direct-output-proof.asm", [expression]),
      symbolsFor("native-target-mon3-compiler.asm", [
        expression,
        path.join(verticalSlice, "mon3-host-services.asmi"),
      ]),
      symbolsFor("nobj-consumer-flat-proof.asm", [
        path.join(verticalSlice, "nobj-consumer-platform.asmi"),
      ]),
    ]);

    const directSink =
      direct.CpmDirectOutputCodeEnd - direct.CpmDirectOutputCodeStart;
    const nobjProducer =
      producer.NativeNobjWriterCodeEnd - producer.NativeNobjWriterCodeStart;
    const nobjMaterializer =
      consumer.NobjConsumerCodeEnd - consumer.NobjConsumerCodeStart;

    expect(directSink).toBe(288);
    expect(nobjProducer).toBe(1_312);
    expect(nobjMaterializer).toBe(2_425);
    expect(nobjProducer + nobjMaterializer - directSink).toBe(3_449);
    expect(direct.CpmDirectWorkspaceEnd - direct.CpmDirectMapPointer).toBe(18);
    expect(
      consumer.NobjConsumerWorkspaceEnd - consumer.NobjConsumerWorkspaceBase,
    ).toBe(381);
  });

  it("applies direct IMAGE and PATCH operations only inside the selected flat image", async () => {
    const assembled = await compile(
      path.join(verticalSlice, "cpm22-direct-output-proof.asm"),
      {
        emitHex: true,
        emitD8m: true,
        registerContracts: "strict",
        registerContractsInterfaces: [
          path.join(verticalSlice, "expression-generated-z80.asmi"),
        ],
      },
    );
    expect(
      assembled.diagnostics.filter(({ severity }) => severity === "error"),
    ).toEqual([]);
    const hex = assembled.artifacts.find(({ kind }) => kind === "hex");
    const map = assembled.artifacts.find(({ kind }) => kind === "d8m");
    if (hex?.kind !== "hex" || map?.kind !== "d8m") {
      throw new Error("AZM omitted direct-output proof artifacts");
    }
    const symbols = Object.fromEntries(
      map.json.symbols.flatMap((entry) => {
        const value = entry.address ?? entry.value;
        return value === undefined ? [] : [[entry.name, value]];
      }),
    );
    const runtime = createZ80Runtime(
      {
        memory: parseIntelHex(hex.text).memory,
        startAddress: symbols.CpmDirectBegin,
      },
      symbols.CpmDirectBegin,
    );
    const returnAddress = 0x3f00;
    const stack = 0xe300;
    runtime.hardware.memory[returnAddress] = 0x76;
    const run = (entry: number): { instructions: number; carry: number } => {
      runtime.hardware.memory[stack] = returnAddress & 0xff;
      runtime.hardware.memory[stack + 1] = returnAddress >>> 8;
      runtime.cpu.sp = stack;
      runtime.cpu.pc = entry;
      runtime.cpu.halted = false;
      let instructions = 0;
      while (!runtime.isHalted() && instructions < 40_000) {
        runtime.step();
        instructions += 1;
      }
      expect(runtime.isHalted()).toBe(true);
      expect(runtime.cpu.sp).toBe(stack + 2);
      return { instructions, carry: runtime.cpu.flags.C };
    };

    expect(run(symbols.CpmDirectBegin).carry).toBe(0);
    expect(
      runtime.hardware.memory.subarray(0x7800, 0xd500).every((byte) => byte === 0),
    ).toBe(true);

    runtime.cpu.a = 0x12;
    runtime.cpu.c = 0;
    runtime.cpu.h = 0x08;
    runtime.cpu.l = 0;
    expect(run(symbols.CpmDirectImageByte).carry).toBe(0);
    expect(runtime.hardware.memory[0x7800]).toBe(0x12);

    runtime.cpu.a = 0x34;
    runtime.cpu.c = 0;
    runtime.cpu.h = 0x08;
    runtime.cpu.l = 0;
    expect(run(symbols.CpmDirectPatchByte).carry).toBe(0);
    expect(runtime.hardware.memory[0x7800]).toBe(0x34);

    runtime.cpu.c = 0;
    runtime.cpu.d = 0x64;
    runtime.cpu.e = 0xfe;
    runtime.cpu.h = 0xab;
    runtime.cpu.l = 0xcd;
    expect(run(symbols.CpmDirectPatchWord).carry).toBe(0);
    expect(Array.from(runtime.hardware.memory.slice(0xd4fe, 0xd500))).toEqual([
      0xcd,
      0xab,
    ]);

    runtime.cpu.c = 0;
    runtime.cpu.d = 0x64;
    runtime.cpu.e = 0xff;
    runtime.cpu.h = 0x55;
    runtime.cpu.l = 0x66;
    expect(run(symbols.CpmDirectPatchWord).carry).toBe(1);
    expect(Array.from(runtime.hardware.memory.slice(0xd4fe, 0xd500))).toEqual([
      0xcd,
      0xab,
    ]);

    runtime.cpu.a = 0xee;
    runtime.cpu.c = 1;
    runtime.cpu.h = 0x08;
    runtime.cpu.l = 0;
    expect(run(symbols.CpmDirectImageByte).carry).toBe(1);
    expect(runtime.hardware.memory[0x7800]).toBe(0x34);
  });
});
