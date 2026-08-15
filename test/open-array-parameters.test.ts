import { describe, expect, it } from "vitest";

import {
  compileNucleus,
  defaultNucleusServices,
  type NucleusCompileSuccess,
} from "../src/compiler.js";
import { executeCommittedNobj } from "../src/proof.js";

const statusAddress = 0x7200;
const outputLength = statusAddress + 1;
const outputBase = outputLength + 1;
const services = {
  ...defaultNucleusServices,
  writeOutputByte: 0x7100,
  success: 0x7180,
  unhandledFailure: 0x7188,
  trap: 0x7190,
};

const terminal = (status: number): readonly number[] => [
  0x3e,
  status,
  0x32,
  statusAddress & 0xff,
  statusAddress >>> 8,
  0x76,
];

const outputService = [
  0x5f,
  0x3a,
  outputLength & 0xff,
  outputLength >>> 8,
  0x4f,
  0x06,
  0x00,
  0x21,
  outputBase & 0xff,
  outputBase >>> 8,
  0x09,
  0x7b,
  0x77,
  0x3a,
  outputLength & 0xff,
  outputLength >>> 8,
  0x3c,
  0x32,
  outputLength & 0xff,
  outputLength >>> 8,
  0xaf,
  0xc9,
];

// Proof-only one-level far-call adapter. It runs from always-visible RAM,
// selects the requested bank through port $7F, and restores the caller bank
// before returning. The production far-call ABI supplies A=bank and HL=target.
const farCallService: readonly number[] = [
  0x32, 0x40, 0x70, 0x22, 0x42, 0x70, 0xe1, 0x22, 0x44, 0x70, 0x3a, 0x46, 0x70,
  0x32, 0x47, 0x70, 0x3a, 0x40, 0x70, 0x32, 0x46, 0x70, 0xd3, 0x7f, 0x21, 0x20,
  0x70, 0xe5, 0x2a, 0x42, 0x70, 0xe9, 0xf5, 0x3a, 0x47, 0x70, 0x32, 0x46, 0x70,
  0xd3, 0x7f, 0xf1, 0xed, 0x5b, 0x44, 0x70, 0xd5, 0xc9,
];

const execute = (
  built: NucleusCompileSuccess,
  writes: readonly {
    readonly at: number;
    readonly bytes: readonly number[];
  }[] = [],
) =>
  executeCommittedNobj(built.nobj, {
    maxInstructions: 40_000,
    maxCycles: 400_000,
    halted: true,
    initialSp: 0x6ff0,
    expectedSp: 0x6ff0,
    expectedIx: 0,
    writes: [
      { at: services.writeOutputByte, bytes: outputService },
      { at: services.success, bytes: terminal(1) },
      { at: services.unhandledFailure, bytes: terminal(2) },
      { at: services.trap, bytes: terminal(3) },
      ...writes,
    ],
  });

describe("open array parameters", () => {
  it("reads a concrete array length after evaluating its carrier", async () => {
    const source = [
      "var values as u8[4] = [1, 2, 3, 4]",
      "var observed as u16",
      "sub main()",
      "observed = values.length",
      "end",
      "",
    ].join("\n");
    const built = await compileNucleus([{ name: "array-length.nu", source }], {
      services,
    });
    if (!built.success) throw new Error(JSON.stringify(built));
    const executed = execute(built);
    expect(executed.memory[statusAddress]).toBe(1);
    expect(executed.memory[built.materialized.parsed.map.bssBase]).toBe(4);
    expect(executed.memory[built.materialized.parsed.map.bssBase + 1]).toBe(0);
  });

  it("binds, forwards, measures, indexes and mutates arrays of different lengths", async () => {
    const source = [
      "var one as u8[1] = [7]",
      "var four as u8[4] = [1, 2, 3, 4]",
      "const seven as u8[7] = [10, 11, 12, 13, 14, 15, 16]",
      "sub sum(values as u8[]) as u16",
      "var total as u16 = 0",
      "var i as u16",
      "for i = 0 until values.length",
      "total = total + u16(values[i])",
      "end",
      "return total",
      "end",
      "sub fill(values as u8[], value as u8)",
      "var i as u16",
      "for i = 0 until values.length",
      "values[i] = value",
      "end",
      "end",
      "sub relay(prefix as u8, values as u8[], suffix as u16) fails",
      "writeOutputByte(prefix) else fail",
      "writeOutputByte(u8(values.length)) else fail",
      "writeOutputByte(values[values.length - 1]) else fail",
      "writeOutputByte(u8(suffix)) else fail",
      "end",
      "sub main() fails",
      "writeOutputByte(u8(one.length)) else fail",
      "writeOutputByte(u8(sum(one))) else fail",
      "writeOutputByte(u8(sum(four))) else fail",
      "relay('[', seven, ']') else fail",
      "fill(four, 9)",
      "writeOutputByte(four[0]) else fail",
      "writeOutputByte(four[3]) else fail",
      "end",
      "",
    ].join("\n");
    const built = await compileNucleus([{ name: "open-array.nu", source }], {
      services,
    });
    if (!built.success) throw new Error(JSON.stringify(built));
    const executed = execute(built);
    expect(executed.memory[statusAddress]).toBe(1);
    const length = executed.memory[outputLength] ?? 0;
    expect(
      Array.from(executed.memory.slice(outputBase, outputBase + length)),
    ).toEqual([1, 7, 10, "[".charCodeAt(0), 7, 16, "]".charCodeAt(0), 9, 9]);
  });

  it("admits every live concrete-array element category with exact identity", async () => {
    const source = [
      "record Point",
      "x as u16",
      "end",
      "var bytes as u8[2] = [1, 2]",
      "var words as u16[2] = [3, 4]",
      "var points as Point[2] = [(5), (6)]",
      'var texts as string[4][2] = ["a", "b"]',
      "sub useBytes(values as u8[])",
      "var n as u16 = values.length",
      "end",
      "sub useWords(values as u16[])",
      "var n as u16 = values.length",
      "end",
      "sub usePoints(values as Point[])",
      "var n as u16 = values.length",
      "end",
      "sub useTexts(values as string[4][])",
      "var n as u16 = values.length",
      "end",
      "sub main()",
      "useBytes(bytes)",
      "useWords(words)",
      "usePoints(points)",
      "useTexts(texts)",
      "end",
      "",
    ].join("\n");
    const built = await compileNucleus([{ name: "categories.nu", source }], {
      services,
    });
    expect(built.success).toBe(true);
  });

  it("scales scalar and aggregate elements by their exact concrete extent", async () => {
    const source = [
      "record Point",
      "value as u16",
      "tag as u8",
      "end",
      "var words as u16[2] = [1, 2]",
      "var points as Point[2] = [(3, 4), (5, 6)]",
      'var texts as string[4][2] = ["a", "b"]',
      "sub change(wordItems as u16[], pointItems as Point[], textItems as string[4][])",
      "wordItems[1] = 513",
      "pointItems[1].tag = 7",
      "textItems[1][0] = 'Z'",
      "end",
      "sub main() fails",
      "change(words, points, texts)",
      "writeOutputByte(u8(words[1] mod 256)) else fail",
      "writeOutputByte(u8(words[1] / 256)) else fail",
      "writeOutputByte(points[1].tag) else fail",
      "writeOutputByte(texts[1][0]) else fail",
      "writeOutputByte(u8(words[0])) else fail",
      "writeOutputByte(points[0].tag) else fail",
      "writeOutputByte(texts[0][0]) else fail",
      "end",
      "",
    ].join("\n");
    const built = await compileNucleus([{ name: "scaling.nu", source }], {
      services,
    });
    if (!built.success) throw new Error(JSON.stringify(built));
    const executed = execute(built);
    expect(executed.memory[statusAddress]).toBe(1);
    expect(
      Array.from(executed.memory.slice(outputBase, outputBase + 7)),
    ).toEqual([1, 2, 7, "Z".charCodeAt(0), 1, 4, "a".charCodeAt(0)]);
  });

  it("retains u16 counts through sequential and recursive forwarding", async () => {
    const source = [
      "var observed as u16",
      "var values as u8[1]",
      "sub capture(items as u8[], depth as u8)",
      "if depth = 0",
      "observed = items.length",
      "return",
      "end",
      "capture(items, depth - 1)",
      "end",
      "sub main()",
      "capture(values, 2)",
      "end",
      "",
    ].join("\n");
    const built = await compileNucleus([{ name: "count.nu", source }], {
      services,
    });
    if (!built.success) throw new Error(JSON.stringify(built));
    const image = built.materialized.flatImage;
    if (!image) throw new Error("expected flat image");
    const pattern = [0x21, 0x01, 0x00, 0xe5, 0xd5];
    const matches: number[] = [];
    for (let index = 0; index <= image.length - pattern.length; index += 1) {
      if (pattern.every((byte, offset) => image[index + offset] === byte)) {
        matches.push(index);
      }
    }
    expect(matches).toHaveLength(1);
    const retainedWord =
      built.materialized.parsed.begin.imageBase + matches[0] + 1;
    const observed = built.materialized.parsed.map.bssBase;
    for (const count of [1, 255, 256, 65_535]) {
      const executed = execute(
        built,
        count === 1
          ? []
          : [{ at: retainedWord, bytes: [count & 0xff, count >>> 8] }],
      );
      expect(executed.memory[statusAddress]).toBe(1);
      expect(Array.from(executed.memory.slice(observed, observed + 2))).toEqual(
        [count & 0xff, count >>> 8],
      );
    }
  });

  it("binds concrete arrays on both sides of the byte-sized count boundary", async () => {
    const source = [
      "var one as u8[1]",
      "var seven as u8[7]",
      "var twoFiftyFive as u8[255]",
      "var twoFiftySix as u8[256]",
      "sub report(values as u8[]) fails",
      "writeOutputByte(u8(values.length mod 256)) else fail",
      "writeOutputByte(u8(values.length / 256)) else fail",
      "end",
      "sub main() fails",
      "report(one) else fail",
      "report(seven) else fail",
      "report(twoFiftyFive) else fail",
      "report(twoFiftySix) else fail",
      "end",
      "",
    ].join("\n");
    const built = await compileNucleus([{ name: "wide-count.nu", source }], {
      establishStack: false,
      services,
    });
    if (!built.success) throw new Error(JSON.stringify(built));
    const executed = execute(built);
    expect(executed.memory[statusAddress]).toBe(1);
    expect(
      Array.from(executed.memory.slice(outputBase, outputBase + 8)),
    ).toEqual([1, 0, 7, 0, 255, 0, 0, 1]);
  });

  it("executes the largest concrete array admitted by the object-capacity proof", async () => {
    const source = [
      "var values as u8[1024]",
      "sub main() fails",
      "writeOutputByte(u8(values.length mod 256)) else fail",
      "writeOutputByte(u8(values.length / 256)) else fail",
      "end",
      "",
    ].join("\n");
    const built = await compileNucleus([{ name: "largest-array.nu", source }], {
      establishStack: false,
      services,
    });
    if (!built.success) throw new Error(JSON.stringify(built));
    const executed = execute(built);
    expect(executed.memory[statusAddress]).toBe(1);
    expect(
      Array.from(executed.memory.slice(outputBase, outputBase + 2)),
    ).toEqual([0, 4]);
  });

  it("checks destination length before a failable copy mutates it", async () => {
    const source = [
      "var short as u8[2] = [9, 8]",
      "var long as u8[3] = [1, 2, 3]",
      "sub copy(source as u8[], destination as u8[]) fails",
      "var i as u16 = 0",
      "if source.length > destination.length",
      "fail 5",
      "end",
      "while i < source.length",
      "destination[i] = source[i]",
      "i = i + 1",
      "end",
      "end",
      "sub main() fails",
      "var code as u8",
      "copy(long, short) handle code",
      "writeOutputByte(code) else fail",
      "writeOutputByte(short[0]) else fail",
      "end",
      "copy(short, long) else fail",
      "writeOutputByte(long[0]) else fail",
      "writeOutputByte(long[1]) else fail",
      "writeOutputByte(long[2]) else fail",
      "end",
      "",
    ].join("\n");
    const built = await compileNucleus([{ name: "copy.nu", source }], {
      services,
    });
    if (!built.success) throw new Error(JSON.stringify(built));
    const executed = execute(built);
    expect(executed.memory[statusAddress]).toBe(1);
    expect(
      Array.from(executed.memory.slice(outputBase, outputBase + 5)),
    ).toEqual([5, 9, 9, 8, 3]);
  });

  it("traps an open-array index at the retained bound before a read", async () => {
    const source = [
      "var sourceValues as u8[3] = [1, 2, 3]",
      "sub lookupValue(values as u8[], index as u16) as u8",
      "return values[index]",
      "end",
      "sub main() fails",
      "writeOutputByte(lookupValue(sourceValues, 3)) else fail",
      "end",
      "",
    ].join("\n");
    const built = await compileNucleus(
      [{ name: "bounds.nu", source }],
      { services },
      { debugMap: true },
    );
    if (!built.success) throw new Error(JSON.stringify(built));
    const executed = execute(built);
    expect(executed.memory[statusAddress]).toBe(3);
    expect(executed.memory[outputLength]).toBe(0);
    expect(
      built.debugMapping?.maps[0]?.map.files?.["bounds.nu"]?.segments?.some(
        ({ line, kind }) => line === 3 && kind === "code",
      ),
    ).toBe(true);
  });

  it("checks a constant open-array index against the retained bound", async () => {
    const source = [
      "var sourceValues as u8[3] = [1, 2, 3]",
      "sub lookupValue(values as u8[]) as u8",
      "return values[3]",
      "end",
      "sub main() fails",
      "writeOutputByte(lookupValue(sourceValues)) else fail",
      "end",
      "",
    ].join("\n");
    const built = await compileNucleus(
      [{ name: "constant-bounds.nu", source }],
      { services },
      { debugMap: true },
    );
    if (!built.success) throw new Error(JSON.stringify(built));
    const executed = execute(built);
    expect(executed.memory[statusAddress]).toBe(3);
    expect(executed.memory[outputLength]).toBe(0);
    expect(
      built.debugMapping?.maps[0]?.map.files?.[
        "constant-bounds.nu"
      ]?.segments?.some(({ line, kind }) => line === 3 && kind === "code"),
    ).toBe(true);
  });

  it("evaluates an aggregate-returning call before producing concrete .length", async () => {
    const source = [
      "var calls as u8",
      "var observed as u16",
      "var values as u8[4] = [1, 2, 3, 4]",
      "sub get() as u8[4]",
      "calls = calls + 1",
      "return values",
      "end",
      "sub main()",
      "observed = get().length",
      "end",
      "",
    ].join("\n");
    const built = await compileNucleus([{ name: "effect.nu", source }], {
      services,
    });
    if (!built.success) throw new Error(JSON.stringify(built));
    const executed = execute(built);
    const bss = built.materialized.parsed.map.bssBase;
    expect(executed.memory[statusAddress]).toBe(1);
    expect(Array.from(executed.memory.slice(bss, bss + 3))).toEqual([1, 4, 0]);
  });

  it("binds complete array fields and transient aliases without losing their count", async () => {
    const source = [
      "record Holder",
      "items as u8[3]",
      "length as u16",
      "end",
      "var holder as Holder = ([4, 5, 6], 99)",
      "sub selected() as u8[3]",
      "return holder.items",
      "end",
      "sub measure(values as u8[]) as u16",
      "return values.length",
      "end",
      "sub main() fails",
      "writeOutputByte(u8(measure(holder.items))) else fail",
      "writeOutputByte(u8(measure(selected()))) else fail",
      "writeOutputByte(u8(holder.length)) else fail",
      "end",
      "",
    ].join("\n");
    const built = await compileNucleus([{ name: "complete-view.nu", source }], {
      services,
    });
    if (!built.success) throw new Error(JSON.stringify(built));
    const executed = execute(built);
    expect(executed.memory[statusAddress]).toBe(1);
    expect(
      Array.from(executed.memory.slice(outputBase, outputBase + 3)),
    ).toEqual([3, 3, 99]);
  });

  it("keeps normal and instrumented banked open-array artifacts identical", async () => {
    const parts = [
      {
        name: "library.nu",
        source: [
          "var observed as u8",
          "sub last(values as u8[]) as u8",
          "return values[values.length - 1]",
          "end",
          "",
        ].join("\n"),
      },
      {
        name: "main.nu",
        source: [
          "var values as u8[4] = [1, 2, 3, 4]",
          "sub main()",
          "observed = last(values)",
          "end",
          "",
        ].join("\n"),
      },
    ] as const;
    const target = {
      bankCount: 2,
      entryBank: 0,
      partBanks: [1, 0],
      imageBase: 0x8000,
      imageCapacity: 0x1000,
      writableBase: 0x4000,
      writableCapacity: 0x1000,
      services: { ...services, farCall: 0x7000, farJump: 0x7080 },
    } as const;
    const normal = await compileNucleus(parts, target);
    const traced = await compileNucleus(parts, target, { debugMap: true });
    expect(normal.success).toBe(true);
    expect(traced.success).toBe(true);
    if (!normal.success || !traced.success) return;
    expect(traced.nobj).toEqual(normal.nobj);
    expect(traced.debugMapping?.maps.map(({ bank }) => bank)).toEqual([0, 1]);
    const executed = executeCommittedNobj(
      normal.nobj,
      {
        maxInstructions: 40_000,
        maxCycles: 400_000,
        halted: true,
        initialSp: 0x6ff0,
        expectedSp: 0x6ff0,
        expectedIx: 0,
        writes: [
          { at: 0x7000, bytes: farCallService },
          { at: 0x7046, bytes: [0] },
          { at: services.success, bytes: terminal(1) },
          { at: services.unhandledFailure, bytes: terminal(2) },
          { at: services.trap, bytes: terminal(3) },
        ],
      },
      {
        bankSwitch: { port: 0x7f, windowBase: 0x8000, windowCapacity: 0x1000 },
      },
    );
    expect(executed.memory[statusAddress]).toBe(1);
    expect(executed.memory[normal.materialized.parsed.map.bssBase]).toBe(4);
  }, 30_000);

  it("rejects forwarding an open array across a bank boundary", async () => {
    const parts = [
      {
        name: "library.nu",
        source: [
          "sub consume(values as u8[])",
          "var length as u16 = values.length",
          "end",
          "",
        ].join("\n"),
      },
      {
        name: "main.nu",
        source: [
          "var values as u8[4] = [1, 2, 3, 4]",
          "sub relay(value as u8[])",
          "consume(value)",
          "end",
          "sub main()",
          "relay(values)",
          "end",
          "",
        ].join("\n"),
      },
    ] as const;
    const built = await compileNucleus(parts, {
      bankCount: 2,
      entryBank: 0,
      partBanks: [1, 0],
      imageBase: 0x8000,
      imageCapacity: 0x1000,
      writableBase: 0x4000,
      writableCapacity: 0x1000,
      services: { ...services, farCall: 0x7000, farJump: 0x7080 },
    });
    expect(built.success).toBe(false);
    if (built.success) return;
    expect(built.diagnostic).toEqual({
      code: 95,
      sourcePart: 2,
      sourceName: "main.nu",
      offset: 73,
      line: 3,
      column: 14,
    });
  });

  it.each([
    {
      source: "var bad as u8[]\nsub main()\nend\n",
      diagnostic: { code: 83, offset: 14, line: 1, column: 15 },
    },
    {
      source: "const bad as u8[] = [1]\nsub main()\nend\n",
      diagnostic: { code: 83, offset: 16, line: 1, column: 17 },
    },
    {
      source: "record Bad\nitems as u8[]\nend\nsub main()\nend\n",
      diagnostic: { code: 83, offset: 24, line: 2, column: 14 },
    },
    {
      source: "sub bad() as u8[]\nend\nsub main()\nend\n",
      diagnostic: { code: 83, offset: 16, line: 1, column: 17 },
    },
    {
      source:
        "sub bad(values as u8[])\nvar local as u8[]\nend\nsub main()\nend\n",
      diagnostic: { code: 129, offset: 39, line: 2, column: 16 },
    },
    {
      source: "var bad as u8[][2]\nsub main()\nend\n",
      diagnostic: { code: 83, offset: 14, line: 1, column: 15 },
    },
  ])(
    "rejects open-array ownership or result placement with exact diagnostics",
    async ({ source, diagnostic }) => {
      const sourceName = "invalid.nu";
      const built = await compileNucleus([{ name: sourceName, source }]);
      expect(built.success, source).toBe(false);
      if (built.success) return;
      expect(built.diagnostic).toEqual({
        ...diagnostic,
        sourcePart: 1,
        sourceName,
      });
    },
  );

  it("rejects element mismatches, rebinding and concrete formals", async () => {
    const cases = [
      [
        "var words as u16[2] = [1, 2]",
        "sub take(values as u8[])",
        "end",
        "sub main()",
        "take(words)",
        "end",
        "",
      ].join("\n"),
      [
        'var text as string[3] = "abc"',
        "sub take(values as u8[])",
        "end",
        "sub main()",
        "take(text)",
        "end",
        "",
      ].join("\n"),
      [
        "var bytes as u8[2] = [1, 2]",
        "sub take(text as string[])",
        "end",
        "sub main()",
        "take(bytes)",
        "end",
        "",
      ].join("\n"),
      [
        "record Left",
        "value as u8",
        "end",
        "record Right",
        "value as u8",
        "end",
        "var values as Left[1] = [(1)]",
        "sub take(items as Right[])",
        "end",
        "sub main()",
        "take(values)",
        "end",
        "",
      ].join("\n"),
      [
        "var bytes as u8[2] = [1, 2]",
        "sub take(values as u8[2])",
        "end",
        "sub relay(values as u8[])",
        "take(values)",
        "end",
        "sub main()",
        "relay(bytes)",
        "end",
        "",
      ].join("\n"),
      [
        "var bytes as u8[2] = [1, 2]",
        "sub bad(left as u8[], right as u8[])",
        "left = right",
        "end",
        "sub main()",
        "bad(bytes, bytes)",
        "end",
        "",
      ].join("\n"),
      [
        "var bytes as u8[2] = [1, 2]",
        "sub bad(values as u8[])",
        "values.length = 1",
        "end",
        "sub main()",
        "bad(bytes)",
        "end",
        "",
      ].join("\n"),
    ];
    for (const source of cases) {
      const built = await compileNucleus([{ name: "mismatch.nu", source }]);
      expect(built.success, source).toBe(false);
    }
  });

  it("fills the semantic transcript exactly with an array-length operation", async () => {
    const source = (assignments: number): string =>
      [
        "const k = 1",
        "var data as u8[3] = [1, 2, 3]",
        "var out as u16 = 0",
        "sub main() fails",
        "out = data.length",
        ...Array.from({ length: assignments }, () => "out=k"),
        "while false",
        "end",
        "end",
        "",
      ].join("\n");
    const exact = await compileNucleus(
      [{ name: "transcript.nu", source: source(81) }],
      {},
      { debugMap: true },
    );
    expect(exact.success).toBe(true);
    if (!exact.success) return;
    expect(exact.debugMapping?.semanticOperations).toBe(172);

    const overflow = await compileNucleus(
      [{ name: "transcript.nu", source: source(82) }],
      {},
      { debugMap: true },
    );
    expect(overflow).toMatchObject({
      success: false,
      diagnostic: {
        code: 40,
        sourcePart: 1,
        sourceName: "transcript.nu",
        offset: 603,
        line: 89,
        column: 4,
      },
    });
    expect("debugMapping" in overflow).toBe(false);

    const recovered = await compileNucleus(
      [{ name: "transcript.nu", source: source(0) }],
      {},
      { debugMap: true },
    );
    expect(recovered.success).toBe(true);
    if (recovered.success) {
      expect(recovered.debugMapping?.semanticOperations).toBe(10);
    }
  }, 30_000);

  it("does not consume extra aggregate-type entries for contextual views", async () => {
    const parameters = Array.from(
      { length: 8 },
      (_, index) => `p${index + 1} as string[${index + 1}][]`,
    ).join(", ");
    const accepted = await compileNucleus([
      {
        name: "types.nu",
        source: `sub use(${parameters})\nend\nsub main()\nend\n`,
      },
    ]);
    expect(accepted.success).toBe(true);

    const rejected = await compileNucleus([
      {
        name: "types.nu",
        source: `sub use(${parameters}, overflow as string[9][])\nend\nsub main()\nend\n`,
      },
    ]);
    expect(rejected.success).toBe(false);
    if (rejected.success) return;
    expect(rejected.diagnostic.code).toBe(76);
  });
});
