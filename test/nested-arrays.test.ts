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

const execute = (built: NucleusCompileSuccess) =>
  executeCommittedNobj(built.nobj, {
    maxInstructions: 80_000,
    maxCycles: 800_000,
    halted: true,
    initialSp: 0x6ff0,
    expectedSp: 0x6ff0,
    expectedIx: 0,
    writes: [
      { at: services.writeOutputByte, bytes: outputService },
      { at: services.success, bytes: terminal(1) },
      { at: services.unhandledFailure, bytes: terminal(2) },
      { at: services.trap, bytes: terminal(3) },
    ],
  });

const compile = (source: string) =>
  compileNucleus([{ name: "nested.nu", source }], { services });

describe("nested fixed arrays", () => {
  it("forms outermost-first rows and reuses ordinary row operations", async () => {
    const source = [
      "var grid as u8[3][2] = [[1, 2], [3, 4], [5, 6]]",
      "var single as u8[1][2] = [[7, 8]]",
      "sub clearRow(row as u8[2])",
      "row[0] = 0",
      "row[1] = 0",
      "end",
      "sub inspect(rows as u8[][2]) fails",
      "writeOutputByte(u8(rows.length)) else fail",
      "writeOutputByte(u8(rows[0].length)) else fail",
      "rows[0][0] = rows[0][0] + 10",
      "end",
      "sub main() fails",
      "grid[0] = grid[1]",
      "clearRow(grid[2])",
      "inspect(grid) else fail",
      "inspect(single) else fail",
      "writeOutputByte(grid[0][0]) else fail",
      "writeOutputByte(single[0][0]) else fail",
      "end",
      "",
    ].join("\n");
    const built = await compile(source);
    if (!built.success) throw new Error(JSON.stringify(built));
    const executed = execute(built);
    expect(executed.memory[statusAddress]).toBe(1);
    expect(
      Array.from(executed.memory.slice(outputBase, outputBase + 6)),
    ).toEqual([3, 2, 1, 2, 13, 17]);
  });

  it("initializes nested record, array and bounded-string trees", async () => {
    const source = [
      "record Pair",
      "values as u8[2]",
      "end",
      "var table as Pair[1][2] = [[([1, 2]), ([3, 4])]]",
      'var textRows as string[4][2] = ["a", "bc"]',
      "sub main() fails",
      "writeOutputByte(table[0][1].values[0]) else fail",
      "writeOutputByte(textRows[1][1]) else fail",
      "end",
      "",
    ].join("\n");
    const built = await compile(source);
    if (!built.success) throw new Error(JSON.stringify(built));
    const executed = execute(built);
    expect(executed.memory[statusAddress]).toBe(1);
    expect(Array.from(executed.memory.slice(outputBase, outputBase + 2))).toEqual(
      [3, "c".charCodeAt(0)],
    );
  });

  it("keeps normal and instrumented banked nested-array artifacts identical", async () => {
    const parts = [
      {
        name: "library.nu",
        source: [
          "sub last(rows as u8[][2]) as u8",
          "return rows[rows.length - 1][1]",
          "end",
          "",
        ].join("\n"),
      },
      {
        name: "main.nu",
        source: [
          "var grid as u8[2][2] = [[1, 2], [3, 4]]",
          "var observed as u8",
          "sub main()",
          "observed = last(grid)",
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
    expect(traced.materialized.banks).toEqual(normal.materialized.banks);
    expect(traced.debugMapping?.maps.map(({ bank }) => bank)).toEqual([0, 1]);
  });

  it.each([
    {
      source:
        "var grid as u8[2][2] = [[1], [2, 3]]\nsub main()\nend\n",
      diagnostic: { code: 79, offset: 26, line: 1, column: 27 },
    },
    {
      source:
        "var grid as u8[2][2] = [[1, 2, 3], [4, 5]]\nsub main()\nend\n",
      diagnostic: { code: 79, offset: 29, line: 1, column: 30 },
    },
  ])(
    "rejects an incorrect inner initializer count",
    async ({ source, diagnostic }) => {
      const built = await compile(source);
      expect(built.success).toBe(false);
      if (built.success) return;
      expect(built.diagnostic).toEqual({
        ...diagnostic,
        sourcePart: 1,
        sourceName: "nested.nu",
      });
    },
  );

  it("applies the structured-initializer depth limit to nested arrays", async () => {
    const source = [
      "record Box",
      "value as u8[1][1][1][1]",
      "end",
      "var box as Box = ([[[[1]]]])",
      "sub main()",
      "end",
      "",
    ].join("\n");
    const built = await compile(source);
    expect(built.success).toBe(false);
    if (built.success) return;
    expect(built.diagnostic).toEqual({
      code: 77,
      sourcePart: 1,
      sourceName: "nested.nu",
      offset: 60,
      line: 4,
      column: 22,
    });
  });

  it.each([
    {
      source: "sub bad(value as u8[2][])\nend\nsub main()\nend\n",
      diagnostic: { code: 83, offset: 23, line: 1, column: 24 },
    },
    {
      source: "sub bad(value as u8[][])\nend\nsub main()\nend\n",
      diagnostic: { code: 83, offset: 22, line: 1, column: 23 },
    },
    {
      source: "sub bad(value as u8[3][][2])\nend\nsub main()\nend\n",
      diagnostic: { code: 83, offset: 23, line: 1, column: 24 },
    },
    {
      source: "var bad as u8[][2]\nsub main()\nend\n",
      diagnostic: { code: 83, offset: 14, line: 1, column: 15 },
    },
  ])(
    "rejects an inner open dimension or open-view storage",
    async ({ source, diagnostic }) => {
      const built = await compile(source);
      expect(built.success).toBe(false);
      if (built.success) return;
      expect(built.diagnostic).toEqual({
        ...diagnostic,
        sourcePart: 1,
        sourceName: "nested.nu",
      });
    },
  );

  it("accepts four concrete dimensions and rejects the fifth", async () => {
    const accepted = await compile(
      "var value as u8[1][1][1][1] = [[[[1]]]]\nsub main()\nend\n",
    );
    expect(accepted.success).toBe(true);

    const source =
      "var value as u8[1][1][1][1][1]\nsub main()\nend\n";
    const rejected = await compile(source);
    expect(rejected.success).toBe(false);
    if (rejected.success) return;
    expect(rejected.diagnostic).toEqual({
      code: 76,
      sourcePart: 1,
      sourceName: "nested.nu",
      offset: 29,
      line: 1,
      column: 30,
    });
  });

  it("requires an exact nested row type for an open-row parameter", async () => {
    const source = [
      "var wrong as u8[3][3]",
      "sub inspect(rows as u8[][2])",
      "end",
      "sub main()",
      "inspect(wrong)",
      "end",
      "",
    ].join("\n");
    const built = await compile(source);
    expect(built.success).toBe(false);
    if (built.success) return;
    expect(built.diagnostic).toEqual({
      code: 60,
      sourcePart: 1,
      sourceName: "nested.nu",
      offset: 79,
      line: 5,
      column: 14,
    });
  });

  it("shares nested row types in the eight-entry dynamic-type table", async () => {
    const declarations = [
      "var grid as u8[2][2]",
      "var one as u8[1]",
      "var three as u8[3]",
      "var four as u8[4]",
      "var five as u8[5]",
      "var six as u8[6]",
      "var seven as u8[7]",
    ];
    const accepted = await compile(
      [...declarations, "sub main()", "end", ""].join("\n"),
    );
    expect(accepted.success).toBe(true);

    const source = [
      ...declarations,
      "var eight as u8[8]",
      "sub main()",
      "end",
      "",
    ].join("\n");
    const rejected = await compile(source);
    expect(rejected.success).toBe(false);
    if (rejected.success) return;
    expect(rejected.diagnostic.code).toBe(76);
    expect(rejected.diagnostic.line).toBe(8);
  });

  it.each([
    ["g[3][0]", 44, 18],
    ["g[0][2]", 47, 21],
  ])(
    "rejects a constant index outside either dimension",
    async (path, offset, column) => {
      const source = [
        "var g as u8[3][2]",
        "sub main()",
        `var x as u8 = ${path}`,
        "end",
        "",
      ].join("\n");
      const built = await compile(source);
      expect(built.success).toBe(false);
      if (built.success) return;
      expect(built.diagnostic).toEqual({
        code: 61,
        sourcePart: 1,
        sourceName: "nested.nu",
        offset,
        line: 3,
        column,
      });
    },
  );

  it.each([
    ["row", "g[row][0]"],
    ["column", "g[0][column]"],
  ])(
    "traps a dynamic index outside each dimension",
    async (name, path) => {
      const source = [
        "var g as u8[3][2] = [[1, 2], [3, 4], [5, 6]]",
        "sub main() fails",
        `var ${name} as u8 = readInputByte() else fail`,
        `writeOutputByte(${path}) else fail`,
        "end",
        "",
      ].join("\n");
      const built = await compile(source);
      if (!built.success) throw new Error(JSON.stringify(built));
      const executed = executeCommittedNobj(built.nobj, {
        maxInstructions: 80_000,
        maxCycles: 800_000,
        halted: true,
        initialSp: 0x6ff0,
        expectedSp: 0x6ff0,
        expectedIx: 0,
        writes: [
          { at: services.readInputByte, bytes: [0x3e, 3, 0xb7, 0xc9] },
          { at: services.writeOutputByte, bytes: outputService },
          { at: services.success, bytes: terminal(1) },
          { at: services.unhandledFailure, bytes: terminal(2) },
          { at: services.trap, bytes: terminal(3) },
        ],
      });
      expect(executed.memory[statusAddress]).toBe(3);
      expect(executed.memory[outputLength]).toBe(0);
    },
  );
});
