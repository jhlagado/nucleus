import path from "node:path";

import { createZ80Runtime, parseIntelHex } from "@jhlagado/debug80-runtime";
import { describe, expect, it } from "vitest";

import {
  compileNucleus,
  compileNucleusTo,
  defaultNucleusServices,
  writeNucleusIntelHex,
} from "../src/compiler.js";
import type { NobjSequentialOutput } from "../src/nobj.js";
import { runProofManifest } from "../src/proof.js";

const proof = (name: string): string =>
  path.resolve(import.meta.dirname, "..", "proofs", `${name}.json`);

const expectValidIntelHexChecksums = (hex: string): void => {
  for (const line of hex.trim().split("\n")) {
    const bytes = Array.from({ length: (line.length - 1) / 2 }, (_, index) =>
      Number.parseInt(line.slice(index * 2 + 1, index * 2 + 3), 16),
    );
    expect(bytes.reduce((sum, value) => (sum + value) & 0xff, 0)).toBe(0);
  }
};

describe("emulator-backed compiler host", () => {
  it("distinguishes every keyword from a longer identifier", async () => {
    const keywords = [
      "var",
      "as",
      "u8",
      "u16",
      "boolean",
      "true",
      "false",
      "const",
      "or",
      "xor",
      "mod",
      "assert",
      "and",
      "not",
      "fail",
      "end",
      "sub",
      "fails",
      "for",
      "until",
      "forward",
      "return",
      "if",
      "elseif",
      "else",
      "while",
      "to",
      "step",
      "exit",
      "continue",
      "record",
      "string",
      "handle",
    ] as const;

    for (const keyword of keywords) {
      const exact = await compileNucleus([
        {
          name: "main.nu",
          source: `var ${keyword} as u8\nsub main()\nend\n`,
        },
      ]);
      expect(exact).toMatchObject({
        success: false,
        diagnostic: {
          code: 130,
          sourcePart: 1,
          sourceName: "main.nu",
          offset: 4,
          line: 1,
          column: 5,
        },
      });

      const longer = await compileNucleus([
        {
          name: "main.nu",
          source: `var ${keyword}x as u8\nsub main()\nend\n`,
        },
      ]);
      expect(longer.success).toBe(true);
    }
  }, 30_000);

  it("rejects an empty based literal at physical EOF", async () => {
    for (const prefix of ["%", "$"] as const) {
      const result = await compileNucleus([
        { name: "main.nu", source: `const x = ${prefix}` },
      ]);
      expect(result).toMatchObject({
        success: false,
        diagnostic: {
          code: 1,
          sourcePart: 1,
          sourceName: "main.nu",
          offset: 10,
          line: 1,
          column: 11,
        },
      });
    }
  }, 30_000);

  it("reports the full trace port without changing Z80 machine state", () => {
    const memory = new Uint8Array(0x10000);
    memory.set([0xd3, 0xd8, 0x76], 0x100);
    const writes: Array<{ port: number; value: number }> = [];
    const runtime = createZ80Runtime({ memory, startAddress: 0x100 }, 0x100, {
      write: (port, value) => writes.push({ port, value }),
    });
    runtime.cpu.a = 0x5a;
    runtime.cpu.b = 0x12;
    runtime.cpu.c = 0x34;
    runtime.cpu.d = 0x56;
    runtime.cpu.e = 0x78;
    runtime.cpu.h = 0x9a;
    runtime.cpu.l = 0xbc;
    runtime.cpu.ix = 0x2468;
    runtime.cpu.iy = 0x1357;
    runtime.cpu.sp = 0xff00;
    runtime.cpu.flags.S = 1;
    runtime.cpu.flags.Z = 0;
    runtime.cpu.flags.H = 1;
    runtime.cpu.flags.P = 0;
    runtime.cpu.flags.N = 1;
    runtime.cpu.flags.C = 1;
    const before = runtime.captureCpuState();

    runtime.step();

    const after = runtime.captureCpuState();
    expect(writes).toEqual([{ port: 0x5ad8, value: 0x5a }]);
    for (const register of [
      "a",
      "b",
      "c",
      "d",
      "e",
      "h",
      "l",
      "ix",
      "iy",
      "sp",
    ] as const) {
      expect(after[register]).toBe(before[register]);
    }
    expect(after.flags).toEqual(before.flags);
    expect(after.pc).toBe(0x102);
  });

  it("leaves generated-program use of every trace port as ordinary target I/O", async () => {
    const compile = await compileNucleus(
      [{ name: "main.nu", source: "sub main()\nend\n" }],
      {},
      { debugMap: true },
    );
    expect(compile.success).toBe(true);

    const memory = new Uint8Array(0x10000);
    memory.set(
      Array.from({ length: 8 }, (_, index) => [0xd3, 0xd8 + index]).flat(),
      0x100,
    );
    memory[0x110] = 0x76;
    const writes: Array<{ port: number; value: number }> = [];
    const runtime = createZ80Runtime({ memory, startAddress: 0x100 }, 0x100, {
      write: (port, value) => writes.push({ port, value }),
    });
    runtime.cpu.a = 0x5a;
    while (!runtime.isHalted()) runtime.step();

    expect(writes.map(({ port }) => port & 0xff)).toEqual([
      0xd8, 0xd9, 0xda, 0xdb, 0xdc, 0xdd, 0xde, 0xdf,
    ]);
  }, 30_000);

  it("matches the established flat-target NOBJ byte for byte", async () => {
    const baseline = await runProofManifest(
      proof("flat-target-z80-slice-proof"),
    );
    const result = await compileNucleus([
      {
        name: "main.nu",
        source: [
          "var value as u16 = 3",
          "var cleared as u8",
          "sub main()",
          "value = value * 2",
          "end",
          "",
        ].join("\n"),
      },
    ]);
    expect(result.success).toBe(true);
    if (!result.success) return;
    expect(result.nobj).toEqual(baseline.nobj?.serialized);
    const hex = writeNucleusIntelHex(result);
    expectValidIntelHexChecksums(hex);
    const loaded = parseIntelHex(hex);
    const imageBase = result.materialized.parsed.begin.imageBase;
    const usedLength = result.materialized.parsed.map.banks[0]?.usedLength ?? 0;
    expect(loaded.startAddress).toBe(imageBase);
    expect(loaded.memory.slice(imageBase, imageBase + usedLength)).toEqual(
      result.materialized.flatImage?.slice(0, usedLength),
    );
    expect(
      loaded.writeRanges?.reduce(
        (total, range) => total + range.end - range.start,
        0,
      ),
    ).toBe(usedLength);
  }, 30_000);

  it("streams the same committed NOBJ without returning materialized banks", async () => {
    const parts = [
      {
        name: "main.nu",
        source: "var value as u16 = 3\nsub main()\nvalue = value * 2\nend\n",
      },
    ];
    const conventional = await compileNucleus(parts);
    expect(conventional.success).toBe(true);
    if (!conventional.success) return;
    const chunks: Uint8Array[] = [];
    let committed = false;
    const output: NobjSequentialOutput = {
      write: (bytes) => chunks.push(bytes.slice()),
      commit: () => {
        committed = true;
      },
      abort: () => {
        throw new Error("unexpected streaming abort");
      },
    };
    const streamed = await compileNucleusTo(parts, {}, output);
    expect(streamed.success).toBe(true);
    if (!streamed.success) return;
    expect(committed).toBe(true);
    const bytes = Uint8Array.from(chunks.flatMap((chunk) => [...chunk]));
    expect(bytes).toEqual(conventional.nobj);
    expect(streamed.object.byteLength).toBe(conventional.nobj.length);
    expect(streamed.object.commit).toEqual(
      conventional.materialized.parsed.commit,
    );
    expect("nobj" in streamed).toBe(false);
    expect("materialized" in streamed).toBe(false);
  }, 30_000);

  it("matches the established banked-target NOBJ byte for byte", async () => {
    const baseline = await runProofManifest(
      proof("banked-target-z80-slice-proof"),
    );
    const library = [
      "record Box",
      "value as u8",
      "end",
      "var shared as Box = (4)",
      "var countdown as u8 = 1",
      "var result as u8",
      "const Lookup as u8[2] = [$76, 5]",
      "sub recursive()",
      "if countdown = 0",
      "return",
      "end",
      "countdown = countdown - 1",
      "recursive()",
      "end",
      "sub readBox(box as Box, add as u8) as u8",
      "return box.value + add",
      "end",
      "sub failRemote() fails",
      "fail 7",
      "end",
      "",
    ].join("\n");
    const main = [
      "sub main() fails",
      "var code as u8",
      "recursive()",
      "result = readBox(shared, 1)",
      "failRemote() handle code",
      "result = result + code",
      "end",
      "end",
      "",
    ].join("\n");
    const result = await compileNucleus(
      [
        { name: "library.nu", source: library },
        { name: "main.nu", source: main },
      ],
      {
        bankCount: 2,
        entryBank: 0,
        partBanks: [1, 0],
        services: {
          readInputByte: 0x70c0,
          writeOutputByte: 0x70c1,
          readStorageByte: 0x70c2,
          rewindStorageInput: 0x70c3,
          writeStorageByte: 0x70c4,
          seekStorageOutput: 0x70c5,
          success: 0x70a0,
          unhandledFailure: 0x70a1,
          trap: 0x70a2,
          farCall: 0x7000,
          farJump: 0x7080,
          packetService: 0x70c6,
        },
      },
    );
    expect(result.success).toBe(true);
    if (!result.success) return;
    expect(result.nobj).toEqual(baseline.nobj?.serialized);
  }, 30_000);

  it("matches the established entry-bank-one NOBJ and D8 identity", async () => {
    const baseline = await runProofManifest(
      proof("banked-target-entry1-z80-slice-proof"),
    );
    const parts = [
      {
        name: "main.nu",
        source: "var result as u8\nsub main()\nresult = 12\nend\n",
      },
    ] as const;
    const target = {
      bankCount: 2,
      entryBank: 1,
      partBanks: [1],
      services: {
        readInputByte: 0x70c0,
        writeOutputByte: 0x70c1,
        readStorageByte: 0x70c2,
        rewindStorageInput: 0x70c3,
        writeStorageByte: 0x70c4,
        seekStorageOutput: 0x70c5,
        success: 0x70a0,
        unhandledFailure: 0x70a1,
        trap: 0x70a2,
        farCall: 0x7000,
        farJump: 0x7080,
        packetService: 0x70c6,
      },
    } as const;

    const ordinary = await compileNucleus(parts, target);
    const traced = await compileNucleus(parts, target, { debugMap: true });

    expect(ordinary.success).toBe(true);
    expect(traced.success).toBe(true);
    if (!ordinary.success || !traced.success) return;
    expect(ordinary.nobj).toEqual(baseline.nobj?.serialized);
    expect(traced.nobj).toEqual(ordinary.nobj);
    expect(
      traced.debugMapping?.maps[1]?.map.files["main.nu"]?.symbols?.[0],
    ).toMatchObject({ name: "main" });
    expect(traced.debugMapping?.maps[1]?.map.memory.segments[0]?.bank).toBe(1);
  }, 30_000);

  it("returns the exact source-part diagnostic position", async () => {
    const parts = [
      { name: "model.nu", source: "var value as u8\n" },
      { name: "main.nu", source: "sub main()\nvalue = 300\nend\n" },
    ] as const;
    const result = await compileNucleus(parts);
    const traced = await compileNucleus(parts, {}, { debugMap: true });
    expect(result).toMatchObject({
      success: false,
      diagnostic: {
        code: 61,
        sourcePart: 2,
        sourceName: "main.nu",
        offset: 19,
        line: 2,
        column: 9,
      },
    });
    expect(result.success).toBe(false);
    if (result.success) return;
    expect(traced).toMatchObject({
      success: false,
      diagnostic: result.diagnostic,
    });
  }, 30_000);

  it("links target service addresses and materializes a high flat layout", async () => {
    const result = await compileNucleus(
      [{ name: "main.nu", source: "sub main()\nend\n" }],
      {
        imageBase: 0xf000,
        imageCapacity: 0x1000,
        writableBase: 0x5000,
        writableCapacity: 0x1000,
        services: { ...defaultNucleusServices, writeOutputByte: 0x1234 },
      },
    );
    expect(result.success).toBe(true);
    if (!result.success) return;

    const parsed = result.materialized.parsed;
    expect(parsed.map.vectorBase).toBe(0x5000);
    const image = result.materialized.flatImage ?? new Uint8Array();
    const loadOffset = parsed.map.dataLoadAddress - parsed.begin.imageBase;
    expect(Array.from(image.slice(loadOffset + 3, loadOffset + 6))).toEqual([
      0xc3, 0x34, 0x12,
    ]);
    const hex = writeNucleusIntelHex(result);
    expectValidIntelHexChecksums(hex);
    const loaded = parseIntelHex(hex);
    const usedLength = parsed.map.banks[0]?.usedLength ?? 0;
    expect(loaded.startAddress).toBe(0xf000);
    expect(loaded.memory.slice(0xf000, 0xf000 + usedLength)).toEqual(
      image.slice(0, usedLength),
    );
  }, 30_000);

  it("collects flat D8 ranges without changing the target artifact", async () => {
    const parts = [
      {
        name: "src/main.nu",
        source: [
          "const One = 1\r\n",
          "sub value() as u8\r\n",
          "return One\r\n",
          "end\r\n",
          "sub main()\r\n",
          "var result as u8 = value()\r\n",
          "result = result + One\r\n",
          "end\r\n",
        ].join(""),
      },
    ] as const;
    const ordinary = await compileNucleus(parts);
    const ordinaryCompilerWrites: Array<{ port: number; value: number }> = [];
    const traced = await compileNucleus(
      parts,
      {},
      {
        debugMap: true,
        compilerIoWrite: (port, value) =>
          ordinaryCompilerWrites.push({ port, value }),
      },
    );
    expect(ordinary.success).toBe(true);
    expect(traced.success).toBe(true);
    if (!ordinary.success || !traced.success) return;
    expect(traced.nobj).toEqual(ordinary.nobj);
    expect(traced.materialized.banks).toEqual(ordinary.materialized.banks);
    expect(writeNucleusIntelHex(traced)).toBe(writeNucleusIntelHex(ordinary));
    const mapping = traced.debugMapping;
    expect(mapping).toBeDefined();
    expect(mapping?.semanticOperations).toBeGreaterThan(1);
    expect(mapping?.declarationMarks).toBeGreaterThanOrEqual(2);
    expect(mapping?.imageBytes).toBe(187);
    expect(ordinaryCompilerWrites).toEqual([]);
    const file = mapping?.maps[0]?.map.files["src/main.nu"];
    expect(
      file?.segments?.every((segment) => segment.start < segment.end),
    ).toBe(true);
    expect(file?.segments?.some((segment) => segment.line === 7)).toBe(true);
    expect(file?.symbols?.map(({ name }) => name)).toEqual(["value", "main"]);
    expect(file?.segments?.some((segment) => segment.line === 1)).toBe(false);
  }, 30_000);

  it("keeps identical visible addresses separate by physical bank", async () => {
    const parts = [
      {
        name: "left.nu",
        source: "sub left() as u8\nreturn 7\nend\n",
      },
      {
        name: "right.nu",
        source: "sub right() as u8\nreturn 8\nend\n",
      },
      {
        name: "main.nu",
        source: [
          "sub main()",
          "var first as u8 = left()",
          "var second as u8 = right()",
          "end",
          "",
        ].join("\n"),
      },
    ] as const;
    const target = {
      bankCount: 3,
      entryBank: 0,
      partBanks: [1, 2, 0],
      imageBase: 0x8000,
      imageCapacity: 0x1000,
      writableBase: 0x4000,
      writableCapacity: 0x1000,
    } as const;
    const ordinary = await compileNucleus(parts, target);
    const traced = await compileNucleus(parts, target, { debugMap: true });
    expect(ordinary.success).toBe(true);
    expect(traced.success).toBe(true);
    if (!ordinary.success || !traced.success) return;
    expect(traced.nobj).toEqual(ordinary.nobj);
    expect(traced.debugMapping?.maps.map(({ bank }) => bank)).toEqual([
      0, 1, 2,
    ]);
    expect(
      traced.debugMapping?.maps[0]?.map.files["main.nu"]?.symbols?.[0]?.name,
    ).toBe("main");
    expect(
      traced.debugMapping?.maps[1]?.map.files["left.nu"]?.symbols?.[0]?.name,
    ).toBe("left");
    expect(
      traced.debugMapping?.maps[2]?.map.files["right.nu"]?.symbols?.[0]?.name,
    ).toBe("right");
    expect(
      traced.debugMapping?.maps[1]?.map.files["left.nu"]?.symbols?.[0]?.address,
    ).toBe(
      traced.debugMapping?.maps[2]?.map.files["right.nu"]?.symbols?.[0]
        ?.address,
    );
    expect(traced.debugMapping?.maps[1]?.map.memory.segments[0]?.bank).toBe(1);
    expect(traced.debugMapping?.maps[2]?.map.memory.segments[0]?.bank).toBe(2);
  }, 30_000);

  it("publishes no tentative D8 mapping after a failed compile", async () => {
    const source = [
      {
        name: "main.nu",
        source: "sub main()\nif true\nunknown()\nend\nend\n",
      },
    ];
    const ordinary = await compileNucleus(source);
    const result = await compileNucleus(source, {}, { debugMap: true });
    expect(result.success).toBe(false);
    expect(ordinary.success).toBe(false);
    if (!result.success && !ordinary.success) {
      expect(result.diagnostic).toEqual(ordinary.diagnostic);
    }
    expect(result.success).toBe(false);
    expect("debugMapping" in result).toBe(false);

    const recovered = await compileNucleus(
      [{ name: "next.nu", source: "sub main()\nend" }],
      {},
      { debugMap: true },
    );
    expect(recovered.success).toBe(true);
    if (!recovered.success) return;
    expect(
      recovered.debugMapping?.maps[0]?.map.files["next.nu"]?.symbols,
    ).toHaveLength(1);
  }, 30_000);

  it("preserves multipart identity across synthesized final newlines", async () => {
    const parts = [
      {
        name: "model.nu",
        source: "sub value() as u8\r\nreturn 7\r\nend",
      },
      {
        name: "main.nu",
        source: "sub main()\nvar result as u8 = value()\nend",
      },
    ] as const;
    const ordinary = await compileNucleus(parts);
    const traced = await compileNucleus(parts, {}, { debugMap: true });
    expect(traced.success).toBe(true);
    expect(ordinary.success).toBe(true);
    if (!ordinary.success || !traced.success) return;
    expect(traced.nobj).toEqual(ordinary.nobj);
    const map = traced.debugMapping?.maps[0]?.map;
    expect(map?.files["model.nu"]?.symbols?.[0]?.name).toBe("value");
    expect(map?.files["main.nu"]?.symbols?.[0]?.name).toBe("main");
    expect(
      map?.files["model.nu"]?.segments?.some(({ line }) => line === 2),
    ).toBe(true);
    expect(
      map?.files["main.nu"]?.segments?.some(({ line }) => line === 2),
    ).toBe(true);
  }, 30_000);

  it("balances nested source contexts across the complete structured surface", async () => {
    const source = [
      "var out as u8 = 0",
      "sub failer() as u8 fails",
      "fail 7",
      "end",
      "sub main() fails",
      "var code as u8",
      "var i as u8 = 0",
      "if false",
      "elseif true",
      "out = 1",
      "else",
      "out = 2",
      "end",
      "while out < 3",
      "out = out + 1",
      "end",
      "for i = 0 until 4",
      "if i = 1",
      "continue",
      "elseif i = 3",
      "exit",
      "end",
      "end",
      "for i = 1 to 0 step -1",
      "out = out + 1",
      "end",
      "out = failer() handle code",
      "out = code",
      "end",
      "writeOutputByte(out) else fail",
      "return",
      "end",
      "",
    ].join("\n");
    const result = await compileNucleus(
      [{ name: "structured.nu", source }],
      {},
      { debugMap: true },
    );
    expect(result.success).toBe(true);
    if (!result.success) return;
    const segments =
      result.debugMapping?.maps[0]?.map.files["structured.nu"]?.segments ?? [];
    for (const line of [3, 8, 9, 11, 14, 17, 18, 19, 20, 21, 24, 27, 30, 31]) {
      expect(segments.some((segment) => segment.line === line)).toBe(true);
    }
  }, 30_000);

  it("maps aggregate copies and field assignments to their own statements", async () => {
    const source = [
      "record Pair",
      "left as u8",
      "right as u8",
      "end",
      "var source as Pair = (1, 2)",
      "var destination as Pair",
      "sub main()",
      "destination = source",
      "destination.right = 3",
      "end",
      "",
    ].join("\n");
    const result = await compileNucleus(
      [{ name: "aggregate.nu", source }],
      {},
      { debugMap: true },
    );
    expect(result.success).toBe(true);
    if (!result.success) return;
    const segments =
      result.debugMapping?.maps[0]?.map.files["aggregate.nu"]?.segments ?? [];
    expect(segments.some(({ line }) => line === 8)).toBe(true);
    expect(segments.some(({ line }) => line === 9)).toBe(true);
    for (const declarationLine of [1, 2, 3, 5, 6]) {
      expect(segments.some(({ line }) => line === declarationLine)).toBe(false);
    }
  }, 30_000);

  it("does not invent an executable range for an empty construct body", async () => {
    const result = await compileNucleus(
      [
        {
          name: "empty.nu",
          source: "sub main()\nif true\nend\nend\n",
        },
      ],
      {},
      { debugMap: true },
    );
    expect(result.success).toBe(true);
    if (!result.success) return;
    const segments =
      result.debugMapping?.maps[0]?.map.files["empty.nu"]?.segments ?? [];
    expect(segments.some(({ line }) => line === 2)).toBe(true);
    expect(segments.some(({ line }) => line === 3)).toBe(false);
  }, 30_000);

  it("keeps transcript-boundary success and first overflow atomic under tracing", async () => {
    const source = (assignments: number): string =>
      [
        "const k = 1",
        "var out as u16 = 0",
        "sub main() fails",
        ...Array.from({ length: assignments }, () => "out=k"),
        "end",
        "",
      ].join("\n");
    const acceptedParts = [{ name: "capacity.nu", source: source(84) }];
    const ordinary = await compileNucleus(acceptedParts);
    const traced = await compileNucleus(acceptedParts, {}, { debugMap: true });
    expect(ordinary.success).toBe(true);
    expect(traced.success).toBe(true);
    if (!ordinary.success || !traced.success) return;
    expect(traced.nobj).toEqual(ordinary.nobj);
    expect(traced.debugMapping?.semanticOperations).toBe(170);

    const overflow = await compileNucleus(
      [{ name: "capacity.nu", source: source(85) }],
      {},
      { debugMap: true },
    );
    expect(overflow).toMatchObject({
      success: false,
      diagnostic: { code: 40, sourceName: "capacity.nu", line: 88, column: 6 },
    });
    expect("debugMapping" in overflow).toBe(false);
  }, 30_000);

  it("retains source attribution on forward-patched call bytes", async () => {
    const source = [
      "forward sub value() as u8",
      "sub caller() as u8",
      "return value()",
      "end",
      "sub value",
      "return 7",
      "end",
      "sub main()",
      "var result as u8 = caller()",
      "end",
      "",
    ].join("\n");
    const result = await compileNucleus(
      [{ name: "forward.nu", source }],
      {},
      { debugMap: true },
    );
    expect(result.success).toBe(true);
    if (!result.success) return;
    const segments =
      result.debugMapping?.maps[0]?.map.files["forward.nu"]?.segments ?? [];
    const mapped = (address: number): boolean =>
      segments.some(({ start, end }) => address >= start && address < end);
    expect(
      result.materialized.parsed.patches.some(({ address, bytes }) =>
        Array.from(
          { length: bytes.length },
          (_, offset) => address + offset,
        ).some(mapped),
      ),
    ).toBe(true);
    expect(segments.some(({ line }) => line === 3)).toBe(true);
  }, 30_000);
});
