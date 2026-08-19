import { readFileSync } from "node:fs";

import { describe, expect, it } from "vitest";

import {
  compileNucleus,
  defaultNucleusServices,
  type NucleusCompileSuccess,
} from "../src/compiler.js";
import { executeCommittedNobj } from "../src/proof.js";

const statusAddress = 0x7200;
const services = {
  ...defaultNucleusServices,
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
      { at: services.success, bytes: terminal(1) },
      { at: services.unhandledFailure, bytes: terminal(2) },
      { at: services.trap, bytes: terminal(3) },
      ...writes,
    ],
  });

const carrierImmediateAddress = (
  built: NucleusCompileSuccess,
  sourceName: string,
  line: number,
  carrier: number,
): number => {
  const image = built.materialized.flatImage;
  if (image === undefined) throw new Error("expected a flat image");
  const map = built.debugMapping?.maps[0]?.map;
  const segments = map?.files?.[sourceName]?.segments?.filter(
    (segment) => segment.line === line,
  );
  if (segments === undefined) throw new Error("missing D8 statement segment");
  const matches: number[] = [];
  for (const segment of segments) {
    for (let address = segment.start; address + 3 < segment.end; address += 1) {
      const offset = address - built.materialized.parsed.begin.imageBase;
      if (
        image[offset] === 0x21 &&
        image[offset + 1] === (carrier & 0xff) &&
        image[offset + 2] === carrier >>> 8 &&
        image[offset + 3] === 0xe5
      ) {
        matches.push(address + 1);
      }
    }
  }
  expect(matches).toHaveLength(1);
  return matches[0] ?? -1;
};

describe("bounded-string construction", () => {
  it("reads and forwards capacities and resizes through open views", async () => {
    const source = [
      'var text as string[8] = "abc"',
      "var concreteCapacity as u8",
      "var openCapacity as u8",
      "sub capacity(value as string[]) as u8",
      "return value.capacity",
      "end",
      "sub resize(value as string[], newLength as u8)",
      "openCapacity = value.capacity",
      "value.length = newLength",
      "end",
      "sub main()",
      "concreteCapacity = capacity(text)",
      "resize(text, 3)",
      "resize(text, 6)",
      "text[3] = 'X'",
      "resize(text, 2)",
      "resize(text, 6)",
      "resize(text, 4)",
      "end",
      "",
    ].join("\n");
    const built = await compileNucleus(
      [{ name: "resize.nu", source }],
      {
        services,
      },
      { debugMap: true },
    );
    if (!built.success) throw new Error(JSON.stringify(built));
    const segments =
      built.debugMapping?.maps[0]?.map.files["resize.nu"]?.segments ?? [];
    const bytesOnLine = (line: number): number =>
      segments
        .filter((segment) => segment.line === line)
        .reduce((sum, segment) => sum + segment.end - segment.start, 0);
    expect(bytesOnLine(8)).toBe(76);
    expect(bytesOnLine(9)).toBe(120);
    const executed = execute(built);
    expect(executed.memory[statusAddress]).toBe(1);
    const textAddress = built.materialized.parsed.map.bssBase - 10;
    expect(
      Array.from(executed.memory.slice(textAddress, textAddress + 10)),
    ).toEqual([4, "a".charCodeAt(0), "b".charCodeAt(0), 0, 0, 0, 0, 0, 0, 0]);
    expect(executed.memory[built.materialized.parsed.map.bssBase]).toBe(8);
    expect(executed.memory[built.materialized.parsed.map.bssBase + 1]).toBe(8);
  });

  it("forwards capacity and writable length through another open view", async () => {
    const source = [
      'var text as string[5] = "abc"',
      "var observed as u8",
      "sub resize(value as string[], newLength as u8)",
      "observed = value.capacity",
      "value.length = newLength",
      "end",
      "sub relay(value as string[], newLength as u8)",
      "resize(value, newLength)",
      "end",
      "sub main()",
      "relay(text, 2)",
      "end",
      "",
    ].join("\n");
    const built = await compileNucleus([{ name: "forward.nu", source }], {
      services,
    });
    if (!built.success) throw new Error(JSON.stringify(built));
    const executed = execute(built);
    const textAddress = built.materialized.parsed.map.bssBase - 7;
    expect(executed.memory[statusAddress]).toBe(1);
    expect(executed.memory[textAddress]).toBe(2);
    expect(executed.memory[built.materialized.parsed.map.bssBase]).toBe(5);
  });

  it("rejects writable length on a concrete string", async () => {
    const source = [
      'var text as string[3] = "abc"',
      "sub main()",
      "text.length = 4",
      "end",
      "",
    ].join("\n");
    const built = await compileNucleus([{ name: "range.nu", source }]);
    expect(built.success).toBe(false);
    if (built.success) return;
    expect(built.diagnostic).toEqual({
      code: 60,
      sourcePart: 1,
      sourceName: "range.nu",
      offset: 46,
      line: 3,
      column: 6,
    });
  });

  it("traps an oversized dynamic length before mutating the string", async () => {
    const source = [
      'var text as string[3] = "abc"',
      "var requested as u8 = 4",
      "var later as u8",
      "sub resize(value as string[], newLength as u8)",
      "value.length = newLength",
      "end",
      "sub main()",
      "resize(text, requested)",
      "later = 1",
      "end",
      "",
    ].join("\n");
    const built = await compileNucleus([{ name: "dynamic.nu", source }], {
      services,
    });
    if (!built.success) throw new Error(JSON.stringify(built));
    const textAddress = built.materialized.parsed.map.bssBase - 6;
    const executed = execute(built);
    expect(executed.memory[statusAddress]).toBe(3);
    expect(
      Array.from(executed.memory.slice(textAddress, textAddress + 5)),
    ).toEqual([3, "a".charCodeAt(0), "b".charCodeAt(0), "c".charCodeAt(0), 0]);
    expect(executed.memory[built.materialized.parsed.map.bssBase]).toBe(0);
    const stateBase =
      built.materialized.parsed.map.vectorBase +
      built.materialized.parsed.map.vectorLength;
    expect(executed.memory[stateBase + 1]).toBe(1);
    expect(
      (executed.memory[stateBase + 3] ?? 0) |
        ((executed.memory[stateBase + 4] ?? 0) << 8),
    ).toBe(source.indexOf("newLength", source.indexOf("value.length")));
  });

  it("supports the capacity-253 boundary and preserves the sealed byte", async () => {
    const source = [
      'var text as string[253] = ""',
      "sub prepare(value as string[])",
      "value.length = 253",
      "end",
      "sub main()",
      "prepare(text)",
      "end",
      "",
    ].join("\n");
    const built = await compileNucleus([{ name: "maximum.nu", source }], {
      services,
      establishStack: false,
    });
    if (!built.success) throw new Error(JSON.stringify(built));
    const executed = execute(built);
    const textAddress = built.materialized.parsed.map.bssBase - 255;
    expect(executed.memory[statusAddress]).toBe(1);
    expect(executed.memory[textAddress]).toBe(253);
    expect(executed.memory[textAddress + 254]).toBe(0);
  });

  it("rejects a corrupted old length before changing any representation byte", async () => {
    const source = [
      'var text as string[3] = "abc"',
      "var requested as u8 = 2",
      "var later as u8",
      "sub resize(value as string[], newLength as u8)",
      "value.length = newLength",
      "end",
      "sub main()",
      "resize(text, requested)",
      "later = 1",
      "end",
      "",
    ].join("\n");
    const built = await compileNucleus([{ name: "corrupt.nu", source }], {
      services,
    });
    if (!built.success) throw new Error(JSON.stringify(built));
    const map = built.materialized.parsed.map;
    const textAddress = map.bssBase - 6;
    const textLoadAddress =
      map.dataLoadAddress + textAddress - map.initializedRunBase;
    const executed = execute(built, [{ at: textLoadAddress, bytes: [255] }]);
    expect(executed.memory[statusAddress]).toBe(3);
    expect(
      Array.from(executed.memory.slice(textAddress, textAddress + 5)),
    ).toEqual([
      255,
      "a".charCodeAt(0),
      "b".charCodeAt(0),
      "c".charCodeAt(0),
      0,
    ]);
    expect(executed.memory[map.bssBase]).toBe(0);
  });

  it.each([
    {
      name: "capacity",
      body: "observed = value.capacity",
      call: "inspect(text)",
    },
    {
      name: "resize",
      body: "value.length = 2",
      call: "inspect(text)",
    },
  ])(
    "rejects a one-byte-truncated open carrier before $name effects",
    async ({ body, call }) => {
      const source = [
        'const text as string[3] = "abc"',
        "var observed as u8",
        "sub inspect(value as string[])",
        body,
        "end",
        "sub main()",
        call,
        "observed = 9",
        "end",
        "",
      ].join("\n");
      const built = await compileNucleus(
        [{ name: "boundary.nu", source }],
        { services },
        { debugMap: true },
      );
      if (!built.success) throw new Error(JSON.stringify(built));
      const map = built.materialized.parsed.map;
      const bank = map.banks[0];
      if (bank === undefined) throw new Error("missing flat bank map");
      const textAddress = bank.aggregateConstantBase;
      const readOnlyEnd = bank.readOnlyBase + bank.readOnlyLength;
      const truncatedCarrier = readOnlyEnd - 4;
      const immediate = carrierImmediateAddress(
        built,
        "boundary.nu",
        7,
        textAddress,
      );
      const executed = execute(built, [
        {
          at: immediate,
          bytes: [truncatedCarrier & 0xff, truncatedCarrier >>> 8],
        },
        { at: truncatedCarrier - 1, bytes: [0x55, 0, 0, 0, 0, 0x66] },
      ]);
      expect(textAddress + 5).toBe(readOnlyEnd);
      expect(truncatedCarrier + 5).toBe(readOnlyEnd + 1);
      expect(executed.memory[statusAddress]).toBe(3);
      expect(
        Array.from(
          executed.memory.slice(truncatedCarrier - 1, truncatedCarrier + 5),
        ),
      ).toEqual([0x55, 0, 0, 0, 0, 0x66]);
      expect(executed.memory[map.bssBase]).toBe(0);
    },
  );

  it("compiles clear and appendByte as an ordinary earlier source part", async () => {
    const library = readFileSync(
      new URL("../examples/text.nu", import.meta.url),
      "utf8",
    );
    const main = [
      'var first as string[3] = ""',
      'var full as string[1] = "Z"',
      "var firstResult as boolean",
      "var secondResult as boolean",
      "var fullResult as boolean",
      "sub main()",
      "firstResult = appendByte(first, 'A')",
      "secondResult = appendByte(first, 0)",
      "clear(first)",
      "firstResult = appendByte(first, 'B')",
      "fullResult = appendByte(full, 'Q')",
      "end",
      "",
    ].join("\n");
    const built = await compileNucleus(
      [
        { name: "text.nu", source: library },
        { name: "main.nu", source: main },
      ],
      { services },
    );
    if (!built.success) throw new Error(JSON.stringify(built));
    const executed = execute(built);
    const bss = built.materialized.parsed.map.bssBase;
    const firstAddress = bss - 8;
    const fullAddress = bss - 3;
    expect(executed.memory[statusAddress]).toBe(1);
    expect(
      Array.from(executed.memory.slice(firstAddress, firstAddress + 5)),
    ).toEqual([1, "B".charCodeAt(0), 0, 0, 0]);
    expect(
      Array.from(executed.memory.slice(fullAddress, fullAddress + 3)),
    ).toEqual([1, "Z".charCodeAt(0), 0]);
    expect(executed.memory[bss + 2]).toBe(0);
  });

  it("provides capacity as an optional ordinary source library", async () => {
    const library = readFileSync(
      new URL("../examples/text-capacity.nu", import.meta.url),
      "utf8",
    );
    const main = [
      'var small as string[2] = ""',
      'var large as string[17] = ""',
      "var observedSmall as u8",
      "var observedLarge as u8",
      "sub main()",
      "observedSmall = capacity(small)",
      "observedLarge = capacity(large)",
      "end",
      "",
    ].join("\n");
    const built = await compileNucleus(
      [
        { name: "text-capacity.nu", source: library },
        { name: "main.nu", source: main },
      ],
      { services },
    );
    if (!built.success) throw new Error(JSON.stringify(built));
    const executed = execute(built);
    expect(executed.memory[statusAddress]).toBe(1);
    const bss = built.materialized.parsed.map.bssBase;
    expect(executed.memory[bss]).toBe(2);
    expect(executed.memory[bss + 1]).toBe(17);
  });

  it("executes capacity and resize through a direct cross-bank open call", async () => {
    const parts = [
      {
        name: "text.nu",
        source: [
          "var observed as u8",
          "sub edit(value as string[])",
          "observed = value.capacity",
          "value.length = 4",
          "end",
          "",
        ].join("\n"),
      },
      {
        name: "main.nu",
        source: [
          'var text as string[5] = "abc"',
          "sub main()",
          "edit(text)",
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
    if (!built.success) throw new Error(JSON.stringify(built));
    const executed = executeCommittedNobj(
      built.nobj,
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
    const bss = built.materialized.parsed.map.bssBase;
    const textAddress = bss - 7;
    expect(executed.memory[statusAddress]).toBe(1);
    expect(executed.memory[bss]).toBe(5);
    expect(
      Array.from(executed.memory.slice(textAddress, textAddress + 7)),
    ).toEqual([
      4,
      "a".charCodeAt(0),
      "b".charCodeAt(0),
      "c".charCodeAt(0),
      0,
      0,
      0,
    ]);
  });

  it("fills the 511-byte semantic transcript exactly and rejects the first resize overflow", async () => {
    const source = (calls: number): string =>
      [
        'var text as string[3] = "abc"',
        "sub resize(value as string[])",
        "value.length = 2",
        "end",
        "sub main()",
        ...Array.from({ length: calls }, () => "resize(text)"),
        "end",
        "",
      ].join("\n");
    const exact = await compileNucleus(
      [{ name: "transcript.nu", source: source(30) }],
      {},
      { debugMap: true },
    );
    expect(exact.success).toBe(true);
    if (!exact.success) return;
    expect(exact.debugMapping?.semanticOperations).toBe(98);

    const overflow = await compileNucleus(
      [{ name: "transcript.nu", source: source(31) }],
      {},
      { debugMap: true },
    );
    expect(overflow).toMatchObject({
      success: false,
      diagnostic: {
        code: 40,
        sourcePart: 1,
        sourceName: "transcript.nu",
        line: 36,
        column: 12,
      },
    });
    expect("debugMapping" in overflow).toBe(false);

    const recovered = await compileNucleus(
      [{ name: "transcript.nu", source: source(1) }],
      {},
      { debugMap: true },
    );
    expect(recovered.success).toBe(true);
    if (recovered.success) {
      expect(recovered.debugMapping?.semanticOperations).toBe(11);
    }
  });

  it("does not reserve capacity as a record-field name", async () => {
    const source = [
      "record Box",
      "capacity as u8",
      "end",
      "var box as Box = (7)",
      "var observed as u8",
      "sub main()",
      "observed = box.capacity",
      "end",
      "",
    ].join("\n");
    const built = await compileNucleus([{ name: "field.nu", source }], {
      services,
    });
    if (!built.success) throw new Error(JSON.stringify(built));
    const executed = execute(built);
    expect(executed.memory[statusAddress]).toBe(1);
    expect(executed.memory[built.materialized.parsed.map.bssBase]).toBe(7);
  });

  it.each([
    {
      source: [
        'var text as string[3] = "a"',
        "sub change(value as string[])",
        "value.capacity = 3",
        "end",
        "sub main()",
        "change(text)",
        "end",
        "",
      ].join("\n"),
      code: 60,
      offset: 64,
      line: 3,
      column: 7,
    },
    {
      source:
        'var text as string[3] = "a"\nvar out as u8\nsub main()\nout = text.capacity\nend\n',
      code: 60,
      offset: 64,
      line: 4,
      column: 12,
    },
    {
      source: "var value as u8\nsub main()\nvalue.length = 0\nend\n",
      code: 135,
      offset: 32,
      line: 3,
      column: 6,
    },
    {
      source: "var value as u8\nsub main()\nvalue = value.capacity\nend\n",
      code: 87,
      offset: 40,
      line: 3,
      column: 14,
    },
  ])(
    "rejects invalid property use",
    async ({ source, code, offset, line, column }) => {
      const built = await compileNucleus([{ name: "invalid.nu", source }]);
      expect(built.success).toBe(false);
      if (built.success) return;
      expect(built.diagnostic).toEqual({
        code,
        sourcePart: 1,
        sourceName: "invalid.nu",
        offset,
        line,
        column,
      });
    },
  );
});
