import { describe, expect, it } from "vitest";

import {
  compileNucleus,
  defaultNucleusServices,
  type NucleusCompileSuccess,
  type NucleusSourcePart,
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

const contains = (image: Uint8Array, bytes: readonly number[]): boolean =>
  image.some((_, start) =>
    bytes.every((byte, index) => image[start + index] === byte),
  );

const outputService: readonly number[] = [
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
    maxInstructions: 200_000,
    maxCycles: 2_000_000,
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

const compileSuccess = async (
  parts: readonly NucleusSourcePart[],
): Promise<NucleusCompileSuccess> => {
  const built = await compileNucleus(parts, { services });
  if (!built.success) throw new Error(JSON.stringify(built));
  return built;
};

const expectOutput = async (
  source: string,
  expected: readonly number[],
): Promise<void> => {
  const built = await compileSuccess([{ name: "select.nu", source }]);
  const run = execute(built);
  expect(run.memory[statusAddress]).toBe(1);
  expect(run.memory[outputLength]).toBe(expected.length);
  expect(Array.from(run.memory.slice(outputBase, outputBase + expected.length))).toEqual(
    expected,
  );
};

describe("select/case", () => {
  it("reports exact select syntax and type diagnostics", async () => {
    const cases = [
      ["no-case", "sub main()\nselect 1\nend\nend\n", 99, 20, 3, 1],
      ["outside", "sub main()\ncase 1\nend\n", 100, 11, 2, 1],
      ["after-local", "sub main()\nvar x as u8\ncase 1\nend\n", 100, 23, 3, 1],
      ["after-statement", "sub main()\nvar x as u8\nx = 1\ncase 1\nend\n", 100, 29, 4, 1],
      ["after-else", "sub main()\nselect 1\ncase 1\nelse\ncase 2\nend\nend\n", 100, 32, 5, 1],
      ["second-else", "sub main()\nselect 1\ncase 1\nelse\nelse\nend\nend\n", 100, 32, 5, 1],
      ["boolean-selector", "sub main()\nselect true\ncase 1\nend\nend\n", 60, 22, 2, 12],
      ["aggregate-selector", "var bytes as u8[1]\nsub main()\nselect bytes\ncase 1\nend\nend\n", 60, 42, 3, 13],
      ["nonconstant-case", "sub main()\nvar x as u8\nselect 1\ncase x\nend\nend\n", 60, 38, 4, 7],
      ["boolean-case", "sub main()\nselect 1\ncase true\nend\nend\n", 60, 29, 3, 10],
      ["range-case", "sub main()\nselect u8(1)\ncase 256\nend\nend\n", 61, 29, 3, 6],
      ["missing-comma", "sub main()\nselect 1\ncase 1 2\nend\nend\n", 129, 27, 3, 8],
      ["missing-newline", "sub main()\nselect 1\ncase 1 writePort(1, 1)\nend\nend\n", 129, 27, 3, 8],
      ["missing-end", "sub main()\nselect 1\ncase 1\n", 140, 27, 4, 1],
      ["missing-end-after-else", "sub main()\nselect 1\ncase 1\nelse\n", 140, 32, 5, 1],
      ["crlf", "sub main()\r\nselect 1\r\ncase 1 2\r\nend\r\nend\r\n", 129, 29, 3, 8],
    ] as const;
    for (const [name, source, code, offset, line, column] of cases) {
      const result = await compileNucleus([{ name: `${name}.nu`, source }]);
      expect(result).toMatchObject({
        success: false,
        diagnostic: {
          code,
          sourcePart: 1,
          sourceName: `${name}.nu`,
          offset,
          line,
          column,
        },
      });
    }
  });

  it("uses the existing control, label, fixup, and transcript capacities", async () => {
    const nested = (depth: number): string =>
      [
        "sub main()",
        ...Array.from({ length: depth }, () => ["select 0", "case 0"]).flat(),
        ...Array.from({ length: depth }, () => "end"),
        "end",
        "",
      ].join("\n");
    const clauses = (count: number): string =>
      [
        "sub main()",
        "select 0",
        ...Array.from({ length: count }, (_, index) => `case ${index}`),
        "end",
        "end",
        "",
      ].join("\n");
    const values = (count: number): string =>
      [
        "sub main()",
        "select 0",
        `case ${Array.from({ length: count }, (_, index) => index).join(", ")}`,
        "end",
        "end",
        "",
      ].join("\n");
    const labels = (count: number): string =>
      [
        "sub main()",
        ...Array.from({ length: 8 }, () => ["if false", "end"]).flat(),
        "select 0",
        ...Array.from({ length: count }, (_, index) => `case ${index}`),
        "end",
        "end",
        "",
      ].join("\n");
    for (const [name, source] of [
      ["depth-8", nested(8)],
      ["clauses-10", clauses(10)],
      ["labels-5", labels(5)],
    ] as const) {
      const accepted = await compileNucleus([{ name: `${name}.nu`, source }]);
      expect(accepted.success, name).toBe(true);
    }
    for (const [name, source, code, offset, line] of [
      ["depth-9", nested(9), 68, 139, 18],
      ["clauses-11", clauses(11), 70, 106, 16],
      ["labels-6", labels(6), 69, 159, 24],
      // Ninety-eight values fill the transcript but exhaust generated fixups;
      // the next value is the first semantic-transcript rejection.
      ["values-98", values(98), 70, 414, 6],
      ["values-99", values(99), 40, 410, 4],
    ] as const) {
      const rejected = await compileNucleus([{ name: `${name}.nu`, source }]);
      expect(rejected, name).toMatchObject({
        success: false,
        diagnostic: {
          code,
          sourcePart: 1,
          sourceName: `${name}.nu`,
          offset,
          line,
          column: 1,
        },
      });
    }
  });

  it("selects normalized integer cases in order and evaluates the selector once", async () => {
    const source = [
      "var observations as u8",
      "sub observed() as u8",
      "observations = observations + 1",
      "return 2",
      "end",
      "sub main() fails",
      "select observed()",
      "case 1",
      "writeOutputByte(1) else fail",
      "case 2, 3",
      "writeOutputByte(2) else fail",
      "else",
      "writeOutputByte(9) else fail",
      "end",
      "writeOutputByte(observations) else fail",
      "select u16(300)",
      "case 299",
      "writeOutputByte(3) else fail",
      "case 300",
      "writeOutputByte(4) else fail",
      "end",
      "select i8(-3)",
      "case -3",
      "writeOutputByte(5) else fail",
      "else",
      "writeOutputByte(6) else fail",
      "end",
      "end",
      "",
    ].join("\n");
    await expectOutput(source, [2, 1, 4, 5]);

    const ordering = [
      "sub main() fails",
      "select i16(-300)",
      "case 300, -300",
      "writeOutputByte(7) else fail",
      "end",
      "select 7",
      "case 7",
      "case 8",
      "writeOutputByte(8) else fail",
      "end",
      "select 10",
      "case 10",
      "writeOutputByte(10) else fail",
      "case 10",
      "writeOutputByte(11) else fail",
      "end",
      "select 99",
      "case 100",
      "writeOutputByte(12) else fail",
      "end",
      "end",
      "",
    ].join("\n");
    await expectOutput(ordering, [7, 10]);
  });

  it("preserves ownership and generated SP through nested control transfers", async () => {
    const source = [
      "sub selected(value as u8) as u8 fails",
      "select value",
      "case 0",
      "return 10",
      "case 1",
      "fail 21",
      "else",
      "select value + 1",
      "case 3",
      "return 30",
      "else",
      "return 40",
      "end",
      "end",
      "end",
      "sub main() fails",
      "var code as u8",
      "var i as u8",
      "var result as u8",
      "result = selected(0) else fail",
      "writeOutputByte(result) else fail",
      "selected(1) handle code",
      "writeOutputByte(code) else fail",
      "end",
      "while i < 4",
      "i = i + 1",
      "select i",
      "case 1",
      "continue",
      "case 3",
      "exit",
      "else",
      "if i = 2",
      "result = selected(i) else fail",
      "writeOutputByte(result) else fail",
      "end",
      "end",
      "end",
      "end",
      "",
    ].join("\n");
    await expectOutput(source, [10, 21, 30]);
  });

  it("nests under if, while, and both counted-loop forms", async () => {
    const source = [
      "sub main() fails",
      "var i as u8",
      "if true",
      "select 1",
      "case 1",
      "writeOutputByte(1) else fail",
      "end",
      "end",
      "for i = 0 until 2",
      "select i",
      "case 0",
      "writeOutputByte(2) else fail",
      "case 1",
      "writeOutputByte(3) else fail",
      "end",
      "end",
      "for i = 1 to 2",
      "select i",
      "case 1",
      "writeOutputByte(4) else fail",
      "case 2",
      "writeOutputByte(5) else fail",
      "end",
      "end",
      "end",
      "",
    ].join("\n");
    await expectOutput(source, [1, 2, 3, 4, 5]);
  });

  it("keeps banked normal and debug images identical and executes from the entry bank", async () => {
    const parts = [
      {
        name: "banked-select.nu",
        source: [
          "sub main() fails",
          "select u16(300)",
          "case 1, 300",
          "writeOutputByte(6) else fail",
          "else",
          "writeOutputByte(9) else fail",
          "end",
          "end",
          "",
        ].join("\n"),
      },
    ] as const;
    const target = {
      bankCount: 2,
      entryBank: 1,
      partBanks: [1],
      imageBase: 0x8000,
      imageCapacity: 0x1000,
      writableBase: 0x4000,
      writableCapacity: 0x1000,
      services: { ...services, farCall: 0x7000, farJump: 0x7080 },
    } as const;
    const ordinary = await compileNucleus(parts, target);
    const traced = await compileNucleus(parts, target, { debugMap: true });
    expect(ordinary.success).toBe(true);
    expect(traced.success).toBe(true);
    if (!ordinary.success || !traced.success) return;
    expect(traced.nobj).toEqual(ordinary.nobj);
    expect(traced.materialized.banks).toEqual(ordinary.materialized.banks);
    const segments =
      traced.debugMapping?.maps[1]?.map.files["banked-select.nu"]?.segments ?? [];
    expect(segments.map(({ line }) => line)).toEqual([1, 2, 3, 4, 6, 1]);
    const mappedBytes = (line: number): number =>
      segments
        .filter((segment) => segment.line === line)
        .reduce((sum, segment) => sum + segment.end - segment.start, 0);
    expect(mappedBytes(2)).toBe(4); // selector evaluation
    expect(mappedBytes(3)).toBe(26); // two ordered comparisons
    expect(mappedBytes(4)).toBe(27); // body plus its exit jump
    expect(mappedBytes(6)).toBe(23); // else body
    const image = ordinary.materialized.banks[1];
    if (image === undefined) throw new Error("entry-bank image unavailable");
    expect(contains(image, [0x21, 0x01, 0x00, 0xd1, 0xd5, 0xb7, 0xed, 0x52, 0xca])).toBe(
      true,
    );
    expect(contains(image, [0x21, 0x2c, 0x01, 0xd1, 0xd5, 0xb7, 0xed, 0x52, 0xca])).toBe(
      true,
    );
    const run = executeCommittedNobj(
      ordinary.nobj,
      {
        maxInstructions: 200_000,
        maxCycles: 2_000_000,
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
      },
      { bankSwitch: { port: 0x7f, windowBase: 0x8000, windowCapacity: 0x1000 } },
    );
    expect(run.memory[statusAddress]).toBe(1);
    expect(run.memory[outputLength]).toBe(1);
    expect(run.memory[outputBase]).toBe(6);
  });

  it("emits exact byte comparisons and linear 2, 4, and 8-case code", async () => {
    const baseline = await compileSuccess([
      { name: "empty.nu", source: "sub main()\nend\n" },
    ]);
    const baselineLength = baseline.materialized.parsed.map.banks[0]?.usedLength ?? 0;
    const deltas: number[] = [];
    for (const count of [2, 4, 8]) {
      const source = [
        "sub main()",
        "select u8(1)",
        ...Array.from({ length: count }, (_, index) => `case ${index}`),
        "end",
        "end",
        "",
      ].join("\n");
      const built = await compileSuccess([{ name: `select-${count}.nu`, source }]);
      deltas.push(
        (built.materialized.parsed.map.banks[0]?.usedLength ?? 0) - baselineLength,
      );
      if (count === 2) {
        const image = built.materialized.flatImage;
        if (image === undefined) throw new Error("flat image unavailable");
        expect(
          contains(image, [0x21, 0x01, 0x00, 0xd1, 0xd5, 0x7b, 0xbd, 0x00, 0xca]),
        ).toBe(true);
      }
    }
    expect(deltas).toEqual([41, 77, 149]);
  });

  it("keeps no-else select fallthrough-capable and accepts exhaustive returning flow", async () => {
    const missingElse = [
      "sub value(x as u8) as u8",
      "select x",
      "case 1",
      "return 1",
      "end",
      "end",
      "sub main()",
      "end",
      "",
    ].join("\n");
    const rejected = await compileNucleus([{ name: "flow.nu", source: missingElse }]);
    expect(rejected).toMatchObject({
      success: false,
      diagnostic: { code: 75, sourcePart: 1, line: 6, column: 4 },
    });

    const exhaustive = [
      "sub value(x as u8) as u8",
      "select x",
      "case 1",
      "return 1",
      "else",
      "return 2",
      "end",
      "end",
      "sub main() fails",
      "writeOutputByte(value(1)) else fail",
      "writeOutputByte(value(9)) else fail",
      "end",
      "",
    ].join("\n");
    await expectOutput(exhaustive, [1, 2]);
  });

  it("compiles multipart nested selection and recovers after a rejected selection", async () => {
    const bad = await compileNucleus([
      { name: "first.nu", source: "sub helper()\nend\n" },
      { name: "bad.nu", source: "sub main()\ncase 1\nend\n" },
    ]);
    expect(bad).toMatchObject({
      success: false,
      diagnostic: {
        code: 100,
        sourcePart: 2,
        sourceName: "bad.nu",
        offset: 11,
        line: 2,
        column: 1,
      },
    });

    const good = await compileSuccess([
      { name: "first.nu", source: "sub helper() as u8\nreturn 2\nend\n" },
      {
        name: "main.nu",
        source: [
          "sub main() fails",
          "select helper()",
          "case 2",
          "writeOutputByte(2) else fail",
          "end",
          "end",
          "",
        ].join("\n"),
      },
    ]);
    const run = execute(good);
    expect(run.memory[statusAddress]).toBe(1);
    expect(run.memory[outputBase]).toBe(2);
  });
});
