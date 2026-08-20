import { createZ80Runtime, parseIntelHex } from "@jhlagado/debug80-runtime";
import { describe, expect, it } from "vitest";

import {
  nativeDebugCompilerSymbols,
  nativeCompilerHex,
  nativeCompilerSymbols,
} from "../src/generated-compiler-images.js";

const launchDescriptor = 0x9e20;
const launchResult = 0x9e30;
const targetDescriptor = 0x9e00;
const returnSentinel = 0x9fff;
const stackTop = 0xff00;

const address = (name: string): number => {
  const value = nativeCompilerSymbols[name];
  if (value === undefined)
    throw new Error(`missing native host symbol ${name}`);
  return value;
};

const writeWord = (memory: Uint8Array, at: number, value: number): void => {
  memory[at] = value & 0xff;
  memory[at + 1] = value >>> 8;
};

const runEntry = (
  runtime: ReturnType<typeof createZ80Runtime>,
  entry: number,
  ix = 0,
): void => {
  const memory = runtime.hardware.memory;
  memory[returnSentinel] = 0x76;
  writeWord(memory, stackTop, returnSentinel);
  runtime.cpu.sp = stackTop;
  runtime.cpu.pc = entry;
  runtime.cpu.ix = ix;
  runtime.cpu.halted = false;
  let instructions = 0;
  while (!runtime.isHalted() && instructions < 10_000) {
    runtime.step();
    instructions += 1;
  }
  expect(runtime.isHalted()).toBe(true);
};

const baseDescriptor = (memory: Uint8Array): void => {
  memory.fill(0, launchDescriptor, launchDescriptor + 14);
  memory[launchDescriptor] = 14;
  memory[launchDescriptor + 1] = 0;
  memory[launchDescriptor + 2] = 1;
  memory[launchDescriptor + 3] = 1;
  writeWord(memory, launchDescriptor + 4, 1);
  writeWord(memory, launchDescriptor + 6, targetDescriptor);
  writeWord(memory, launchDescriptor + 8, launchResult);
  writeWord(memory, launchDescriptor + 10, 1);
};

const runInvalidLaunch = (
  mutate: (memory: Uint8Array) => void,
): {
  readonly memory: Uint8Array;
  readonly a: number;
  readonly carry: number;
  readonly sp: number;
} => {
  const memory = parseIntelHex(nativeCompilerHex).memory.slice();
  baseDescriptor(memory);
  memory.fill(0xa5, launchResult, launchResult + 9);
  mutate(memory);
  memory[returnSentinel] = 0x76;
  writeWord(memory, stackTop, returnSentinel);
  const runtime = createZ80Runtime(
    { memory, startAddress: address("NucleusHostCompile") },
    address("NucleusHostCompile"),
    {
      write: (port) => {
        throw new Error(
          `invalid launch reached host port $${port.toString(16)}`,
        );
      },
    },
  );
  runtime.cpu.sp = stackTop;
  runtime.cpu.ix = launchDescriptor;
  let instructions = 0;
  while (!runtime.isHalted() && instructions < 1_000) {
    runtime.step();
    instructions += 1;
  }
  expect(runtime.isHalted()).toBe(true);
  return {
    memory: runtime.hardware.memory,
    a: runtime.cpu.a,
    carry: runtime.cpu.flags.C,
    sp: runtime.cpu.sp,
  };
};

describe("native Z80 compiler-host launch shell", () => {
  it("keeps the compiler core unchanged and accounts for host code separately", () => {
    expect(
      nativeCompilerSymbols.CompilerCoreEnd -
        nativeCompilerSymbols.CompilerCodeStart,
    ).toBe(16_314);
    expect(
      nativeCompilerSymbols.HostVectorEnd -
        nativeCompilerSymbols.HostVectorBase,
    ).toBe(913);
    expect(
      nativeDebugCompilerSymbols.HostVectorEnd -
        nativeDebugCompilerSymbols.HostVectorBase,
    ).toBe(915);
    expect(
      nativeCompilerSymbols.NativeHostWorkspaceEnd -
        nativeCompilerSymbols.NativeHostWorkspaceBase,
    ).toBe(22);
  });

  it("rejects a malformed launch before opening a host generation", () => {
    const outcome = runInvalidLaunch((memory) => {
      memory[launchDescriptor + 13] = 1;
    });
    expect(
      Array.from(outcome.memory.slice(launchResult, launchResult + 9)),
    ).toEqual([2, 4, 0, 0, 0, 0, 0, 0, 0]);
    expect(outcome.a).toBe(2);
    expect(outcome.carry).toBe(1);
    expect(outcome.sp).toBe(stackTop + 2);
  });

  it("rejects a concurrent launch through the same exact result contract", () => {
    const outcome = runInvalidLaunch((memory) => {
      memory[address("NativeHostLaunchActive")] = 1;
    });
    expect(
      Array.from(outcome.memory.slice(launchResult, launchResult + 9)),
    ).toEqual([2, 4, 0, 0, 0, 0, 0, 0, 0]);
    expect(outcome.a).toBe(2);
    expect(outcome.carry).toBe(1);
    expect(outcome.sp).toBe(stackTop + 2);
  });

  it.each([
    ["ordinary", "NativeHostRuntimeImage", "NativeHostRuntimeImagePort", 0, 0],
    [
      "initial",
      "NativeHostRuntimeInitialImage",
      "NativeHostRuntimeInitialPort",
      1,
      95,
    ],
  ] as const)(
    "resumes a %s runtime request from the bounded mailbox",
    (_name, entryName, portName, operation, status) => {
      const memory = parseIntelHex(nativeCompilerHex).memory.slice();
      memory[returnSentinel] = 0x76;
      writeWord(memory, stackTop, returnSentinel);
      let runtime: ReturnType<typeof createZ80Runtime>;
      let calls = 0;
      runtime = createZ80Runtime(
        { memory, startAddress: address(entryName) },
        address(entryName),
        {
          write: (port, value) => {
            const live = runtime.hardware.memory;
            calls += 1;
            expect(port & 0xff).toBe(address(portName));
            expect(value).toBe(2);
            expect(live[address("NativeHostRuntimeOperation")]).toBe(operation);
            expect(live[address("NativeHostRuntimeBank")]).toBe(2);
            expect(
              live[address("NativeHostRuntimeLength")] |
                (live[address("NativeHostRuntimeLength") + 1]! << 8),
            ).toBe(0x1234);
            expect(
              live[address("NativeHostRuntimeIdentity")] |
                (live[address("NativeHostRuntimeIdentity") + 1]! << 8),
            ).toBe(9);
            expect(
              live[address("NativeHostRuntimeAddress")] |
                (live[address("NativeHostRuntimeAddress") + 1]! << 8),
            ).toBe(0x8003);
            expect(
              live[address("NativeHostRuntimeContext")] |
                (live[address("NativeHostRuntimeContext") + 1]! << 8),
            ).toBe(0x9000);
            expect(live[address("NativeHostRuntimePending")]).toBe(1);
            expect(live[address("NativeHostRuntimeStatus")]).toBe(0xff);
            expect(runtime.cpu.sp).toBe(stackTop);
            live[address("NativeHostRuntimeStatus")] = status;
          },
        },
      );
      runtime.cpu.sp = stackTop;
      runtime.cpu.a = 2;
      runtime.cpu.b = 0x12;
      runtime.cpu.c = 0x34;
      runtime.cpu.d = 0;
      runtime.cpu.e = 9;
      runtime.cpu.h = 0x80;
      runtime.cpu.l = 3;
      runtime.cpu.ix = 0x9000;
      let instructions = 0;
      while (!runtime.isHalted() && instructions < 100) {
        runtime.step();
        instructions += 1;
      }
      expect(runtime.isHalted()).toBe(true);
      expect(calls).toBe(1);
      expect(runtime.hardware.memory[address("NativeHostRuntimePending")]).toBe(
        0,
      );
      expect(runtime.cpu.a).toBe(status);
      expect(runtime.cpu.flags.C).toBe(status === 0 ? 0 : 1);
      expect(runtime.cpu.sp).toBe(stackTop + 2);
    },
  );

  it("reuses one host image after diagnostics, host failure, and explicit reset", () => {
    const memory = parseIntelHex(nativeCompilerHex).memory.slice();
    baseDescriptor(memory);
    let abortCalls = 0;
    let launchEnds = 0;
    let lowerActive = false;
    const runtime = createZ80Runtime(
      { memory, startAddress: address("NucleusHostInitialize") },
      address("NucleusHostInitialize"),
      {
        write: (port) => {
          switch (port & 0xff) {
            case address("NativeHostLaunchBeginPort"):
              expect(lowerActive).toBe(false);
              lowerActive = true;
              runtime.cpu.a = 0;
              runtime.cpu.flags.C = 0;
              return;
            case address("NativeHostLaunchEndPort"):
              expect(lowerActive).toBe(true);
              lowerActive = false;
              launchEnds += 1;
              runtime.cpu.a = 0;
              runtime.cpu.flags.C = 0;
              return;
            case address("NativeHostAbortPort"):
              abortCalls += 1;
              runtime.cpu.a = 0;
              runtime.cpu.flags.C = 0;
              return;
            default:
              throw new Error(`unexpected native host port ${port & 0xff}`);
          }
        },
      },
    );
    const live = runtime.hardware.memory;
    runEntry(runtime, address("NucleusHostInitialize"));

    const compilerEntry = address("CompileTargetAggregateCallParts");
    live[address("DiagnosticCode")] = 95;
    live[address("DiagnosticPartId")] = 1;
    writeWord(live, address("DiagnosticOffset"), 7);
    writeWord(live, address("DiagnosticLine"), 2);
    writeWord(live, address("DiagnosticColumn"), 3);
    live.set([0x3e, 95, 0x37, 0xc9], compilerEntry); // LD A,95 / SCF / RET
    runEntry(runtime, address("NucleusHostCompile"), launchDescriptor);
    expect(Array.from(live.slice(launchResult, launchResult + 9))).toEqual([
      1, 95, 1, 7, 0, 2, 0, 3, 0,
    ]);
    expect(abortCalls).toBe(0);

    const asyncStatus = address("NativeHostAsyncStatus");
    live.set(
      [0x3e, 4, 0x32, asyncStatus & 0xff, asyncStatus >>> 8, 0x37, 0xc9],
      compilerEntry,
    ); // LD A,4 / LD (async),A / SCF / RET
    runEntry(runtime, address("NucleusHostCompile"), launchDescriptor);
    expect(Array.from(live.slice(launchResult, launchResult + 9))).toEqual([
      2, 4, 0, 0, 0, 0, 0, 0, 0,
    ]);
    expect(abortCalls).toBe(0);

    live[address("NativeHostLaunchActive")] = 1;
    lowerActive = true;
    runEntry(runtime, address("NucleusHostReset"));
    expect(abortCalls).toBe(1);
    expect(
      Array.from(
        live.slice(
          address("NativeHostWorkspaceBase"),
          address("NativeHostWorkspaceEnd"),
        ),
      ),
    ).toEqual(
      new Array(
        address("NativeHostWorkspaceEnd") - address("NativeHostWorkspaceBase"),
      ).fill(0),
    );

    const committed = address("NativeHostLaunchCommitted");
    live.set(
      [0x3e, 1, 0x32, committed & 0xff, committed >>> 8, 0xaf, 0xc9],
      compilerEntry,
    ); // mark committed / XOR A / RET
    runEntry(runtime, address("NucleusHostCompile"), launchDescriptor);
    expect(Array.from(live.slice(launchResult, launchResult + 9))).toEqual(
      new Array(9).fill(0),
    );
    expect(launchEnds).toBe(4);
    expect(lowerActive).toBe(false);
    expect(live[address("NativeHostLaunchActive")]).toBe(0);
  });

  it("reports one failing shell-owned abort as a host storage failure", () => {
    const memory = parseIntelHex(nativeCompilerHex).memory.slice();
    baseDescriptor(memory);
    let abortCalls = 0;
    let lowerActive = false;
    const runtime = createZ80Runtime(
      { memory, startAddress: address("NucleusHostInitialize") },
      address("NucleusHostInitialize"),
      {
        write: (port) => {
          if ((port & 0xff) === address("NativeHostLaunchBeginPort")) {
            expect(lowerActive).toBe(false);
            lowerActive = true;
            runtime.cpu.a = 0;
            runtime.cpu.flags.C = 0;
            return;
          }
          if ((port & 0xff) === address("NativeHostAbortPort")) {
            abortCalls += 1;
            runtime.cpu.a = 97;
            runtime.cpu.flags.C = 1;
            return;
          }
          if ((port & 0xff) === address("NativeHostLaunchEndPort")) {
            expect(lowerActive).toBe(true);
            lowerActive = false;
            runtime.cpu.a = 0;
            runtime.cpu.flags.C = 0;
            return;
          }
          throw new Error(`unexpected native host port ${port & 0xff}`);
        },
      },
    );
    const live = runtime.hardware.memory;
    runEntry(runtime, address("NucleusHostInitialize"));
    live.set([0xaf, 0xc9], address("CompileTargetAggregateCallParts"));
    runEntry(runtime, address("NucleusHostCompile"), launchDescriptor);
    expect(abortCalls).toBe(1);
    expect(Array.from(live.slice(launchResult, launchResult + 9))).toEqual([
      2, 3, 0, 0, 0, 0, 0, 0, 0,
    ]);
    expect(runtime.cpu.a).toBe(2);
    expect(runtime.cpu.flags.C).toBe(1);
    expect(lowerActive).toBe(false);
    expect(live[address("NativeHostLaunchActive")]).toBe(0);
  });
});
