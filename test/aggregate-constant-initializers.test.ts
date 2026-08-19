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

const execute = (built: NucleusCompileSuccess, banked = false) =>
  executeCommittedNobj(
    built.nobj,
    {
      maxInstructions: 100_000,
      maxCycles: 1_000_000,
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
    banked
      ? {
          bankSwitch: {
            port: 0x7f,
            windowBase: 0x8000,
            windowCapacity: 0x1000,
          },
        }
      : undefined,
  );

describe("aggregate constants in static initializers", () => {
  it("copies earlier exact-type constants at whole and nested positions", async () => {
    const source = [
      "record Pair",
      "left as u8",
      "right as u16",
      "end",
      "const Origin as Pair = (7, 300)",
      "const Marker = 1",
      "var scratch as u8 = Marker",
      "const Clone as Pair = Origin",
      "const Rows as Pair[2] = [Origin, Clone]",
      "var target as Pair = Clone",
      "var copies as Pair[2] = Rows",
      "sub main() fails",
      "if scratch = 1 and target.left = 7 and target.right = 300 and copies[0].left = 7 and copies[1].right = 300",
      "writeOutputByte('Y') else fail",
      "end",
      "end",
      "",
    ].join("\n");
    const built = await compileNucleus([{ name: "copies.nu", source }], {
      imageCapacity: 0x2000,
      writableCapacity: 0x1000,
      services,
    });
    if (!built.success) throw new Error(JSON.stringify(built));
    const executed = execute(built);
    expect(executed.memory[statusAddress]).toBe(1);
    expect(executed.memory[outputLength]).toBe(1);
    expect(executed.memory[outputBase]).toBe("Y".charCodeAt(0));
  });

  it("copies the complete bounded-string representation", async () => {
    const source = [
      'const Banner as string[4] = "A\\0B"',
      "const Copy as string[4] = Banner",
      "var text as string[4] = Copy",
      "sub main() fails",
      "if text[2] = 'B'",
      "writeOutputByte('Y') else fail",
      "end",
      "end",
      "",
    ].join("\n");
    const built = await compileNucleus([{ name: "string-copy.nu", source }], {
      services,
    });
    if (!built.success) throw new Error(JSON.stringify(built));
    const executed = execute(built);
    expect(executed.memory[statusAddress]).toBe(1);
    expect(executed.memory[outputLength]).toBe(1);
    expect(executed.memory[outputBase]).toBe("Y".charCodeAt(0));
  });

  it("requires an earlier aggregate constant with exact type identity", async () => {
    const cases = [
      {
        name: "later.nu",
        code: 57,
        source: [
          "record Pair",
          "value as u8",
          "end",
          "const Copy as Pair = Later",
          "const Later as Pair = (1)",
          "sub main()",
          "end",
          "",
        ].join("\n"),
        needle: "Later",
        first: true,
      },
      {
        name: "wrong-type.nu",
        code: 60,
        source: [
          "record Pair",
          "value as u8",
          "end",
          "record Other",
          "value as u8",
          "end",
          "const Origin as Pair = (1)",
          "var copy as Other = Origin",
          "sub main()",
          "end",
          "",
        ].join("\n"),
        needle: "Origin",
        first: false,
      },
      {
        name: "variable.nu",
        code: 60,
        source: [
          "record Pair",
          "value as u8",
          "end",
          "var origin as Pair = (1)",
          "var copy as Pair = origin",
          "sub main()",
          "end",
          "",
        ].join("\n"),
        needle: "origin",
        first: false,
      },
    ] as const;

    for (const { name, code, source, needle, first } of cases) {
      const offset = first
        ? source.indexOf(needle)
        : source.lastIndexOf(needle);
      const preceding = source.slice(0, offset);
      const line = preceding.split("\n").length;
      const column = offset - preceding.lastIndexOf("\n");
      const result = await compileNucleus([{ name, source }]);
      expect(result).toMatchObject({
        success: false,
        diagnostic: {
          code,
          sourcePart: 1,
          sourceName: name,
          offset,
          line,
          column,
        },
      });
    }
  });

  it("copies a constant declared in an earlier source part and another bank", async () => {
    const parts = [
      {
        name: "library.nu",
        source: [
          "record Pair",
          "left as u8",
          "right as u16",
          "end",
          "const Origin as Pair = (7, 300)",
          "",
        ].join("\n"),
      },
      {
        name: "main.nu",
        source: [
          "const Clone as Pair = Origin",
          "var target as Pair = Clone",
          "sub main() fails",
          "if target.left = 7 and target.right = 300",
          "writeOutputByte('Y') else fail",
          "end",
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
    const executed = execute(built, true);
    expect(executed.memory[statusAddress]).toBe(1);
    expect(executed.memory[outputLength]).toBe(1);
    expect(executed.memory[outputBase]).toBe("Y".charCodeAt(0));
  });
});
