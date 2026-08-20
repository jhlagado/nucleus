import { createZ80Runtime, parseIntelHex } from "@jhlagado/debug80-runtime";
import { describe, expect, it } from "vitest";

import {
  nativeCompilerHex,
  nativeCompilerSymbols,
} from "../src/generated-compiler-images.js";

const address = (name: string): number => {
  const value = nativeCompilerSymbols[name];
  if (value === undefined) throw new Error(`missing native symbol ${name}`);
  return value;
};

const writeWord = (memory: Uint8Array, pointer: number, value: number): void => {
  memory[pointer] = value & 0xff;
  memory[pointer + 1] = value >>> 8;
};

const runEntry = (
  memory: Uint8Array,
  entry: string,
  configure: (runtime: ReturnType<typeof createZ80Runtime>) => void,
  write: (port: number, runtime: ReturnType<typeof createZ80Runtime>) => void,
): ReturnType<typeof createZ80Runtime> => {
  const sentinel = 0x9f00;
  const stack = 0x9e00;
  memory[sentinel] = 0x76;
  writeWord(memory, stack, sentinel);
  let runtime!: ReturnType<typeof createZ80Runtime>;
  runtime = createZ80Runtime(
    { memory, startAddress: address(entry) },
    address(entry),
    {
      write: (port) => write(port & 0xff, runtime),
    },
  );
  runtime.cpu.sp = stack;
  configure(runtime);
  let instructions = 0;
  while (!runtime.isHalted() && instructions < 20_000) {
    runtime.step();
    instructions += 1;
  }
  expect(
    runtime.isHalted(),
    `${entry} did not return (PC=$${runtime.getPC().toString(16)}, SP=$${runtime.cpu.sp.toString(16)})`,
  ).toBe(true);
  return runtime;
};

describe("native Z80 source-host adapters", () => {
  it.each([
    ["SourceHostNextChunk", "NativeHostSourceNextChunkPort"],
    ["SourceHostRetainCurrentName", "NativeHostRetainNamePort"],
    ["SourceHostCompareCurrentName", "NativeHostCompareNamePort"],
    ["SourceHostMaterializeName", "NativeHostMaterializeNamePort"],
  ] as const)(
    "unwinds a returning %s provider failure as a host outcome",
    (entry, portName) => {
      const memory = parseIntelHex(nativeCompilerHex).memory.slice();
      const diagnostic = address("DiagnosticCode");
      const abortStack = 0x9d00;
      const sentinel = 0x9f00;
      memory[sentinel] = 0x76;
      writeWord(memory, abortStack, sentinel);
      writeWord(memory, address("CompilerAbortSp"), abortStack);
      memory[diagnostic] = 0xa5;

      const runtime = runEntry(
        memory,
        entry,
        () => undefined,
        (port, active) => {
          expect(port).toBe(address(portName));
          active.cpu.a = 5;
          active.cpu.flags.C = 1;
        },
      );
      const resultMemory = runtime.hardware.memory;
      expect(resultMemory[address("SourceHostStatus")]).toBe(5);
      expect(resultMemory[diagnostic]).toBe(0xa5);
      expect(runtime.cpu.flags.C).toBe(1);
    },
  );

  it("clears stale token-pinning state before the first refill of a later launch", () => {
    let memory = parseIntelHex(nativeCompilerHex).memory.slice();
    memory = runEntry(
      memory,
      "SourcePinBeginToken",
      () => undefined,
      () => {
        throw new Error("pin begin must not call the provider");
      },
    ).hardware.memory;
    expect(memory[address("SourcePinScratchCursor")]).toBe(1);

    const abortStack = 0x9d00;
    const sentinel = 0x9f00;
    memory[sentinel] = 0x76;
    writeWord(memory, abortStack, sentinel);
    writeWord(memory, address("CompilerAbortSp"), abortStack);
    memory = runEntry(
      memory,
      "SourceHostNextChunk",
      () => undefined,
      (_port, active) => {
        active.cpu.a = 5;
        active.cpu.flags.C = 1;
      },
    ).hardware.memory;
    expect(memory[address("SourcePinScratchCursor")]).toBe(1);
    expect(memory[address("SourceHostStatus")]).toBe(5);

    const chunk = address("NativeSourceChunkBase");
    const tokenBase = address("NativeSourceTokenBase");
    const chunkLimit = address("NativeSourceChunkLimit");
    memory[tokenBase - 1] = 0x5a;
    memory[chunkLimit] = 0xa5;
    memory[chunk] = 10;
    let event = 0;

    const runtime = runEntry(
      memory,
      "SourceInitializeParts",
      (active) => {
        active.cpu.a = 1;
      },
      (port, active) => {
        expect(port).toBe(address("NativeHostSourceNextChunkPort"));
        active.cpu.c = 1;
        active.cpu.flags.C = 0;
        if (event === 0) {
          active.cpu.a = 1;
        } else {
          active.cpu.a = 0;
          active.cpu.h = chunk >>> 8;
          active.cpu.l = chunk & 0xff;
          active.cpu.d = 0;
          active.cpu.e = 1;
        }
        event += 1;
      },
    );

    expect(event).toBe(2);
    expect(runtime.hardware.memory[address("SourcePinScratchCursor")]).toBe(0);
    expect(runtime.hardware.memory[address("SourcePinScratchCursor") + 1]).toBe(
      0,
    );
    expect(runtime.hardware.memory[address("SourceHostStatus")]).toBe(0);
    expect(runtime.hardware.memory[tokenBase - 1]).toBe(0x5a);
    expect(runtime.hardware.memory[chunkLimit]).toBe(0xa5);
  });

  it("records an invalid source event as a host failure rather than a diagnostic", () => {
    const memory = parseIntelHex(nativeCompilerHex).memory.slice();
    const abortStack = 0x9d00;
    const sentinel = 0x9f00;
    memory[sentinel] = 0x76;
    writeWord(memory, abortStack, sentinel);
    writeWord(memory, address("CompilerAbortSp"), abortStack);
    memory[address("DiagnosticCode")] = 0xa5;

    const runtime = runEntry(
      memory,
      "SourceStreamBeginPart",
      () => undefined,
      (_port, active) => {
        active.cpu.a = 0;
        active.cpu.c = 1;
        active.cpu.d = 0;
        active.cpu.e = 1;
        active.cpu.flags.C = 0;
      },
    );
    expect(runtime.hardware.memory[address("SourceHostStatus")]).toBe(4);
    expect(runtime.hardware.memory[address("DiagnosticCode")]).toBe(0xa5);
    expect(runtime.cpu.flags.C).toBe(1);
  });

  it("does not confuse a valid chunk ending at $ffff with consumed end-unit", () => {
    const memory = parseIntelHex(nativeCompilerHex).memory.slice();
    writeWord(memory, address("SourceCursor"), 0xffff);
    writeWord(memory, address("SourceEnd"), 0xffff);
    writeWord(memory, address("SourcePinScratchCursor"), 0);
    memory[address("SourceProviderPartId")] = 1;
    memory[address("SourcePartId")] = 1;
    memory[address("SourcePartsRemaining")] = 0;
    let calls = 0;

    const runtime = runEntry(
      memory,
      "SourcePeek",
      () => undefined,
      (port, active) => {
        expect(port).toBe(address("NativeHostSourceNextChunkPort"));
        calls += 1;
        active.cpu.a = 2;
        active.cpu.c = 1;
        active.cpu.flags.C = 0;
      },
    );
    expect(calls).toBe(1);
    expect(runtime.cpu.flags.C).toBe(1);
    expect(runtime.hardware.memory[address("SourceProviderPartId")]).toBe(1);
  });

  it("consumes end-unit exactly once regardless of incoming zero", () => {
    let memory = parseIntelHex(nativeCompilerHex).memory.slice();
    memory[address("SourceProviderPartId")] = 1;
    let calls = 0;
    memory = runEntry(
      memory,
      "SourceStreamFinishUnit",
      (active) => {
        active.cpu.flags.Z = 1;
      },
      (port, active) => {
        expect(port).toBe(address("NativeHostSourceNextChunkPort"));
        calls += 1;
        active.cpu.a = 3;
        active.cpu.flags.C = 0;
      },
    ).hardware.memory;
    expect(calls).toBe(1);
    expect(memory[address("SourceProviderPartId")]).toBe(0);

    runEntry(
      memory,
      "SourceStreamFinishUnit",
      (active) => {
        active.cpu.flags.Z = 0;
      },
      () => {
        throw new Error("consumed end-unit must not be requested again");
      },
    );
    expect(calls).toBe(1);
  });
});
