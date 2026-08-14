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

const execute = (
  built: NucleusCompileSuccess,
  writes: readonly {
    readonly at: number;
    readonly bytes: readonly number[];
  }[] = [],
) =>
  executeCommittedNobj(built.nobj, {
    maxInstructions: 30_000,
    maxCycles: 300_000,
    halted: true,
    writes: [
      { at: services.writeOutputByte, bytes: outputService },
      { at: services.success, bytes: terminal(1) },
      { at: services.unhandledFailure, bytes: terminal(2) },
      { at: services.trap, bytes: terminal(3) },
      ...writes,
    ],
  });

describe("open bounded-string parameters", () => {
  it("accepts, forwards, mutates and indexes concrete strings of different capacities", async () => {
    const source = [
      'const empty as string[1] = ""',
      'var small as string[5] = "H\\0i"',
      'const large as string[12] = "Nucleus"',
      "forward sub relay(text as string[]) fails",
      "sub emit(text as string[]) fails",
      "var i as u8",
      "for i = 0 until text.length",
      "writeOutputByte(text[i]) else fail",
      "end",
      "end",
      "sub change(text as string[], value as u8) as u16",
      "text[0] = value",
      "return 45",
      "end",
      "sub relay",
      "emit(text) else fail",
      "end",
      "sub mixed(prefix as u8, first as string[], marker as u16, second as string[], suffix as u8) fails",
      "writeOutputByte(prefix) else fail",
      "emit(first) else fail",
      "writeOutputByte(u8(marker)) else fail",
      "emit(second) else fail",
      "writeOutputByte(suffix) else fail",
      "end",
      "sub main() fails",
      "emit(empty) else fail",
      "change(small, 'Z')",
      "relay(small) else fail",
      "mixed('[', empty, change(small, 'Z'), large, ']') else fail",
      "end",
      "",
    ].join("\n");
    const built = await compileNucleus(
      [{ name: "open.nu", source }],
      { services },
      { debugMap: true },
    );
    if (!built.success) throw new Error(JSON.stringify(built));
    const executed = execute(built);
    expect(executed.memory[statusAddress]).toBe(1);
    const length = executed.memory[outputLength] ?? 0;
    expect(
      Array.from(executed.memory.slice(outputBase, outputBase + length)),
    ).toEqual([
      "Z".charCodeAt(0),
      0,
      "i".charCodeAt(0),
      "[".charCodeAt(0),
      "-".charCodeAt(0),
      ...new TextEncoder().encode("Nucleus"),
      "]".charCodeAt(0),
    ]);
  });

  it("uses the actual capacity when checking an open parameter", async () => {
    const source = [
      'var text as string[3] = "abc"',
      "sub inspect(value as string[])",
      "var length as u8 = value.length",
      "end",
      "sub main()",
      "inspect(text)",
      "end",
      "",
    ].join("\n");
    const built = await compileNucleus([{ name: "capacity.nu", source }], {
      services,
    });
    if (!built.success) throw new Error(JSON.stringify(built));
    const parsed = built.materialized.parsed;
    const textAddress = parsed.map.bssBase - 5;
    const textLoadAddress =
      parsed.map.dataLoadAddress + textAddress - parsed.map.initializedRunBase;
    const executed = execute(built, [{ at: textLoadAddress, bytes: [4] }]);
    expect(executed.memory[textAddress]).toBe(4);
    expect(executed.memory[statusAddress]).toBe(3);
  });

  it("preserves a maximum-capacity transient view through recursion", async () => {
    const payload = "x".repeat(253);
    const source = [
      `const text as string[253] = "${payload}"`,
      "sub getText() as string[253]",
      "return text",
      "end",
      "sub inspect(value as string[], depth as u8) fails",
      "if depth = 0",
      "writeOutputByte(value.length) else fail",
      "writeOutputByte(value[252]) else fail",
      "return",
      "end",
      "inspect(value, depth - 1) else fail",
      "end",
      "sub main() fails",
      "inspect(getText(), 3) else fail",
      "end",
      "",
    ].join("\n");
    const built = await compileNucleus(
      [{ name: "recursive-open.nu", source }],
      { services },
    );
    if (!built.success) throw new Error(JSON.stringify(built));
    const executed = execute(built);
    expect(executed.memory[statusAddress]).toBe(1);
    expect(
      Array.from(executed.memory.slice(outputBase, outputBase + 2)),
    ).toEqual([253, "x".charCodeAt(0)]);
  });

  it("allows an ordinary source routine named print", async () => {
    const source = [
      'const text as string[4] = "user"',
      "sub print(value as string[]) fails",
      "writeOutputByte(value.length) else fail",
      "end",
      "sub main() fails",
      "print(text) else fail",
      "end",
      "",
    ].join("\n");
    const built = await compileNucleus([{ name: "user-print.nu", source }], {
      services,
    });
    if (!built.success) throw new Error(JSON.stringify(built));
    const executed = execute(built);
    expect(executed.memory[statusAddress]).toBe(1);
    expect(executed.memory[outputBase]).toBe(4);
  });

  it("keeps normal and instrumented banked artifacts identical", async () => {
    const parts = [
      {
        name: "library.nu",
        source: [
          "sub lengthOf(text as string[]) as u8",
          "return text.length",
          "end",
          "",
        ].join("\n"),
      },
      {
        name: "main.nu",
        source: [
          'var text as string[7] = "banked"',
          "sub main()",
          "var length as u8 = lengthOf(text)",
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
  }, 30_000);

  it("rejects forwarding an open view across a bank boundary", async () => {
    const parts = [
      {
        name: "library.nu",
        source: [
          "sub consume(text as string[])",
          "var length as u8 = text.length",
          "end",
          "",
        ].join("\n"),
      },
      {
        name: "main.nu",
        source: [
          'var text as string[4] = "bank"',
          "sub relay(value as string[])",
          "consume(value)",
          "end",
          "sub main()",
          "relay(text)",
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

  it("retains exact-capacity bounded-string assignment", async () => {
    const source = [
      'var destination as string[5] = "xxxxx"',
      'var source as string[5] = "a\\0b"',
      "sub main()",
      "destination = source",
      "end",
      "",
    ].join("\n");
    const built = await compileNucleus([{ name: "exact-copy.nu", source }], {
      services,
    });
    if (!built.success) throw new Error(JSON.stringify(built));
    const executed = execute(built);
    expect(executed.memory[statusAddress]).toBe(1);
    const destination = built.materialized.parsed.map.bssBase - 14;
    expect(
      Array.from(executed.memory.slice(destination, destination + 7)),
    ).toEqual([3, "a".charCodeAt(0), 0, "b".charCodeAt(0), 0, 0, 0]);
  });

  it.each([
    {
      name: "open variable",
      source: "var bad as string[]\nsub main()\nend\n",
      code: 83,
      line: 1,
      column: 20,
    },
    {
      name: "open constant",
      source: 'const bad as string[] = ""\nsub main()\nend\n',
      code: 83,
      line: 1,
      column: 23,
    },
    {
      name: "open record field",
      source: "record Box\ntext as string[]\nend\nsub main()\nend\n",
      code: 83,
      line: 2,
      column: 17,
    },
    {
      name: "open array element",
      source: "var bad as string[][2]\nsub main()\nend\n",
      code: 83,
      line: 1,
      column: 22,
    },
    {
      name: "open result",
      source: "sub bad() as string[]\nend\nsub main()\nend\n",
      code: 83,
      line: 1,
      column: 22,
    },
    {
      name: "forward open result",
      source: "forward sub bad() as string[]\nsub bad\nend\nsub main()\nend\n",
      code: 83,
      line: 1,
      column: 30,
    },
    {
      name: "open local",
      source:
        "sub bad(text as string[])\nvar local as string[]\nend\nsub main()\nend\n",
      code: 59,
      line: 2,
      column: 14,
    },
    {
      name: "open assignment",
      source: [
        'var text as string[3] = "a"',
        "sub copy(destination as string[], source as string[])",
        "destination = source",
        "end",
        "sub main()",
        "copy(text, text)",
        "end",
        "",
      ].join("\n"),
      code: 60,
      line: 3,
      column: 21,
    },
    {
      name: "cross-capacity assignment",
      source: [
        'var small as string[3] = "a"',
        'var large as string[5] = "b"',
        "sub main()",
        "large = small",
        "end",
        "",
      ].join("\n"),
      code: 60,
      line: 4,
      column: 14,
    },
    {
      name: "open comparison",
      source: [
        'var text as string[3] = "a"',
        "sub same(first as string[], second as string[]) as boolean",
        "return first = second",
        "end",
        "sub main()",
        "end",
        "",
      ].join("\n"),
      code: 60,
      line: 3,
      column: 14,
    },
    {
      name: "concrete bounded-string comparison",
      source: [
        'var left as string[3] = "a"',
        'var right as string[3] = "b"',
        "sub main()",
        "var result as boolean = left = right",
        "end",
        "",
      ].join("\n"),
      code: 60,
      line: 4,
      column: 30,
    },
    {
      name: "removed print intrinsic",
      source: [
        'var text as string[3] = "a"',
        "sub main()",
        "print(text)",
        "end",
        "",
      ].join("\n"),
      code: 57,
      line: 3,
      column: 1,
    },
    {
      name: "direct string-literal argument",
      source: [
        "sub emit(text as string[])",
        "end",
        "sub main()",
        'emit("a")',
        "end",
        "",
      ].join("\n"),
      code: 130,
      line: 4,
      column: 6,
    },
  ])(
    "rejects $name with an exact diagnostic",
    async ({ source, code, line, column }) => {
      const sourceName = "invalid.nu";
      const built = await compileNucleus([{ name: sourceName, source }]);
      expect(built.success, source).toBe(false);
      if (built.success) return;
      expect(built.diagnostic).toMatchObject({
        code,
        sourcePart: 1,
        sourceName,
        offset:
          source
            .split("\n")
            .slice(0, line - 1)
            .reduce((total, value) => total + value.length + 1, 0) +
          column -
          1,
        line,
        column,
      });
    },
  );
});
