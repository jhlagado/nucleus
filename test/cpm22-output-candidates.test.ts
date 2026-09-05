import { assembleAtomSource } from "../scripts/atom-source.mjs";
import { assembleNativeCpmProof } from "../scripts/assemble-native-cpm.mjs";
import { createZ80Runtime, parseIntelHex } from "@jhlagado/debug80-runtime";
import { describe, expect, it } from "vitest";

const symbolsFor = async (name: string): Promise<Record<string, number>> =>
  (await assembleAtomSource(`vertical-slice/${name}`)).symbols;

describe("native Nucleus CP/M output candidates", () => {
  it("measures the direct sink against the existing NOBJ producer and materializer", async () => {
    const [direct, producer, consumer] = await Promise.all([
      assembleNativeCpmProof("cpm22-direct-output-proof.asm").then(proof => proof.symbols),
      symbolsFor("native-target-mon3-compiler.asm"),
      symbolsFor("nobj-consumer-flat-proof.asm"),
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
    // Includes a full compiler assembly through emulated native ATOM.
  }, 300_000);

  it("applies direct IMAGE and PATCH operations only inside the selected flat image", async () => {
    const { hex, symbols } = await assembleNativeCpmProof(
      "cpm22-direct-output-proof.asm",
    );
    const memory = parseIntelHex(hex).memory;
    const wordGuard = symbols.CpmDirectTranslateWord;
    // The named constants must retain immediate CP opcodes and the last
    // admitted address, $64FF; parentheses must not become indirect operands.
    expect([...memory.slice(wordGuard, wordGuard + 3)]).toEqual([0x7d, 0xfe, 0xff]);
    expect([...memory.slice(wordGuard + 5, wordGuard + 8)]).toEqual([0x7c, 0xfe, 0x64]);
    const runtime = createZ80Runtime(
      {
        memory,
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
      expect(runtime.cpu.pc).toBe(returnAddress + 1);
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
