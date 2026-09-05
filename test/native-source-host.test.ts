import { createZ80Runtime, parseIntelHex } from "@jhlagado/debug80-runtime";
import { beforeAll, describe, expect, it } from "vitest";
import { assembleNativeTokenizerHostProof } from "../scripts/assemble-native-tokenizer.mjs";

import {
  nativeCompilerHex as bundledHex,
  nativeCompilerSymbols as bundledSymbols,
} from "../src/generated-compiler-images.js";

describe.each(["bundled compiler", "fresh native tokenizer"] as const)("%s source-host adapters", variant => {
  let nativeCompilerHex: string;
  let nativeCompilerSymbols: Readonly<Record<string, number>>;
  beforeAll(async () => {
    if (variant === "bundled compiler") {
      nativeCompilerHex = bundledHex;
      nativeCompilerSymbols = bundledSymbols;
    } else {
      const fresh = await assembleNativeTokenizerHostProof();
      nativeCompilerHex = fresh.hex;
      nativeCompilerSymbols = fresh.symbols;
    }
  });
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
    expectedStack = 0x9e02,
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
    expect(runtime.getPC()).toBe(sentinel + 1);
    expect(runtime.cpu.sp).toBe(expectedStack);
    return runtime;
  };

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
        abortStack + 2,
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
      abortStack + 2,
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
      abortStack + 2,
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

  it.each([1, 3, 7])("tokenizes overwritten %i-byte windows with exact multipart positions", chunkSize => {
    let memory = parseIntelHex(nativeCompilerHex).memory.slice();
    const chunkBase = address("NativeSourceChunkBase");
    const chunkLimit = address("NativeSourceChunkLimit");
    const tokenBase = address("NativeSourceTokenBase");
    const parts = ["Player <= $f\r\n//x", "until"];
    const events: { kind: number; part: number; text?: string }[] = [];
    parts.forEach((source, index) => {
      const part = index + 1;
      events.push({ kind: 1, part });
      for (let offset = 0; offset < source.length; offset += chunkSize) {
        events.push({ kind: 0, part, text: source.slice(offset, offset + chunkSize) });
      }
      events.push({ kind: 2, part });
    });
    events.push({ kind: 3, part: 0 });
    let eventIndex = 0;
    const provide = (port: number, active: ReturnType<typeof createZ80Runtime>) => {
      expect(port).toBe(address("NativeHostSourceNextChunkPort"));
      const event = events[eventIndex++];
      if (!event) throw new Error("requested source after end-unit");
      // Every provider call invalidates the preceding window, including
      // end-part. A stale-pointer tokenizer cannot pass the NAME assertion.
      active.hardware.memory.fill(0xcc, chunkBase, chunkLimit);
      active.cpu.a = event.kind;
      active.cpu.c = event.part;
      active.cpu.flags.C = 0;
      if (event.text !== undefined) {
        active.hardware.memory.set(Buffer.from(event.text, "ascii"), chunkBase);
        active.cpu.h = chunkBase >>> 8;
        active.cpu.l = chunkBase & 0xff;
        active.cpu.d = 0;
        active.cpu.e = event.text.length;
      }
    };
    memory[tokenBase - 1] = 0x5a;
    memory[chunkLimit] = 0xa5;
    writeWord(memory, address("CompilerAbortSp"), 0x9d00);
    writeWord(memory, 0x9d00, 0x9f00);
    memory = runEntry(memory, "SourceInitializeParts", active => {
      active.cpu.a = parts.length;
    }, provide).hardware.memory;
    const readWord = (name: string) =>
      memory[address(name)]! | (memory[address(name) + 1]! << 8);
    const expected = [
      ["TokenName", 1, 0, 1, 1],
      ["TokenLessEqual", 1, 7, 1, 8],
      ["TokenNumber", 1, 10, 1, 11],
      ["TokenNewline", 1, 12, 1, 13],
      ["TokenUntil", 2, 0, 1, 1],
      ["TokenNewline", 2, 5, 1, 6],
      ["TokenEof", 2, 5, 1, 6],
    ] as const;
    for (const [kind, part, offset, line, column] of expected) {
      const result = runEntry(memory, "TokenizerNext", () => undefined, provide);
      memory = result.hardware.memory;
      expect(result.cpu.flags.C).toBe(0);
      expect(result.cpu.a).toBe(address(kind));
      expect(memory[address("SourcePartId")]).toBe(part);
      expect([readWord("TokenStartOffset"), readWord("TokenStartLine"), readWord("TokenStartColumn")])
        .toEqual([offset, line, column]);
      if (kind === "TokenName") {
        const pointer = readWord("TokenLexemePointer");
        expect(Buffer.from(memory.slice(pointer, pointer + memory[address("TokenLength")]!))
          .toString("ascii")).toBe("Player");
      }
      if (kind === "TokenNumber") expect(result.cpu.b * 256 + result.cpu.c).toBe(15);
      expect(memory[tokenBase - 1]).toBe(0x5a);
      expect(memory[chunkLimit]).toBe(0xa5);
      expect(memory[address("DiagnosticCode")]).toBe(0);
    }
    expect(eventIndex).toBe(events.length);
    runEntry(memory, "TokenizerNext", () => undefined, () => {
      throw new Error("EOF must not refill a consumed unit");
    });
  });
});
