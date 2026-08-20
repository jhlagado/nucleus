import { describe, expect, it } from "vitest";

import { compileNucleus } from "../src/compiler.js";

const consoleInputModule = [
  "sub getChar() as u8 fails",
  "var value as u8",
  "value = readInputByte() else fail",
  "return value",
  "end",
  "sub readLine(destination as string[]) fails",
  "var value as u8",
  "var index as u8",
  "destination.length = 0",
  "value = getChar() else fail",
  "while value <> 10",
  "if u16(destination.length) = u16(destination.capacity)",
  "fail 1",
  "end",
  "index = destination.length",
  "destination.length = index + 1",
  "destination[index] = value",
  "value = getChar() else fail",
  "end",
  "end",
  "",
].join("\n");

const consoleOutputModule = [
  "sub printChar(value as u8) fails",
  "writeOutputByte(value) else fail",
  "end",
  "sub printString(text as string[]) fails",
  "var index as u8",
  "for index = 0 until text.length",
  "writeOutputByte(text[index]) else fail",
  "end",
  "end",
  "sub printNewline() fails",
  "writeOutputByte(10) else fail",
  "end",
  "sub printLine(text as string[]) fails",
  "printString(text) else fail",
  "printNewline() else fail",
  "end",
  "",
].join("\n");

const unsignedFormattingModule = [
  "sub printU8(value as u8) fails",
  "if value >= 100",
  "printChar('0' + value / 100) else fail",
  "end",
  "if value >= 10",
  "printChar('0' + value / 10 mod 10) else fail",
  "end",
  "printChar('0' + value mod 10) else fail",
  "end",
  "sub printU16(value as u16) fails",
  "printU8(u8(value)) else fail",
  "end",
  "",
].join("\n");

const signedFormattingModule = [
  "sub printI8(value as i8) fails",
  "printU8(u8(value)) else fail",
  "end",
  "sub printI16(value as i16) fails",
  "printU16(u16(value)) else fail",
  "end",
  "",
].join("\n");

const hexFormattingModule = [
  "sub printHex8(value as u8) fails",
  "printChar('0' + value mod 16) else fail",
  "end",
  "sub printHex16(value as u16) fails",
  "printHex8(u8(value)) else fail",
  "end",
  "",
].join("\n");

const emptyMain = "sub main()\nend\n";

const representativeOutputProgram = [
  "sub main() fails",
  'printLine("ready") else fail',
  "end",
  "",
].join("\n");

const representativeFormattingProgram = [
  "sub sum(left as u8, right as u8) as u16",
  "return u16(left) + u16(right)",
  "end",
  "sub report(value as u16) fails",
  "printU16(value) else fail",
  "printNewline() else fail",
  "end",
  "sub main() fails",
  "var total as u16 = 0",
  "total = sum(12, 30)",
  "report(total) else fail",
  "end",
  "",
].join("\n");

const chapter18Program = [
  "record Cell",
  "value as u8",
  "end",
  "var template as Cell = (1)",
  "var cells as Cell[4] = [(0), (0), (0), (0)]",
  "sub cellAt(index as u8) as Cell",
  "return cells[index]",
  "end",
  "sub setCell(cell as Cell, value as u8)",
  "cell.value = value",
  "end",
  "sub main()",
  "var index as u8",
  "var code as u8",
  "for index = 0 until 4",
  "cells[index] = template",
  "setCell(template, index + 1)",
  "end",
  "cells[0].value = cellAt(0).value",
  "if cells[0].value = 1",
  "writeOutputByte('Y') handle code",
  "return",
  "end",
  "elseif cells[0].value = 0",
  "writeOutputByte('N') handle code",
  "return",
  "end",
  "end",
  "end",
  "",
].join("\n");

describe("standard-library capacity gate", () => {
  it("measures semantic transcript use with the planned source modules", async () => {
    const cases = [
      ["console-output", [consoleOutputModule, emptyMain]],
      ["console-input", [consoleInputModule, emptyMain]],
      [
        "console-formatting",
        [consoleOutputModule, unsignedFormattingModule, emptyMain],
      ],
      [
        "console-signed-formatting",
        [
          consoleOutputModule,
          unsignedFormattingModule,
          signedFormattingModule,
          emptyMain,
        ],
      ],
      [
        "console-hex-formatting",
        [consoleOutputModule, hexFormattingModule, emptyMain],
      ],
      ["console-user", [consoleOutputModule, representativeOutputProgram]],
      [
        "console-formatting-user",
        [
          consoleOutputModule,
          unsignedFormattingModule,
          representativeFormattingProgram,
        ],
      ],
      ["console-chapter18", [consoleOutputModule, chapter18Program]],
      [
        "console-formatting-chapter18",
        [consoleOutputModule, unsignedFormattingModule, chapter18Program],
      ],
    ] as const;
    const measurements: Record<
      string,
      | { semanticBytes: number; remaining: number; operations: number }
      | { diagnostic: number; part: number; offset: number }
    > = {};
    for (const [name, sources] of cases) {
      const built = await compileNucleus(
        sources.map((source, index) => ({
          name: `${name}-${index}.nu`,
          source,
        })),
        { imageCapacity: 0x2000 },
        { debugMap: true },
      );
      if (!built.success) {
        measurements[name] = {
          diagnostic: built.diagnostic.code,
          part: built.diagnostic.sourcePart,
          offset: built.diagnostic.offset,
        };
        continue;
      }
      const semanticBytes = built.debugMapping?.semanticBytes ?? -1;
      measurements[name] = {
        semanticBytes,
        remaining: 511 - semanticBytes,
        operations: built.debugMapping?.semanticOperations ?? -1,
      };
    }
    expect(measurements).toEqual({
      "console-output": {
        operations: 39,
        remaining: 371,
        semanticBytes: 140,
      },
      "console-input": {
        operations: 57,
        remaining: 354,
        semanticBytes: 157,
      },
      "console-formatting": {
        operations: 80,
        remaining: 236,
        semanticBytes: 275,
      },
      "console-signed-formatting": {
        operations: 92,
        remaining: 182,
        semanticBytes: 329,
      },
      "console-hex-formatting": {
        operations: 54,
        remaining: 312,
        semanticBytes: 199,
      },
      "console-user": {
        operations: 42,
        remaining: 355,
        semanticBytes: 156,
      },
      "console-formatting-user": {
        operations: 103,
        remaining: 147,
        semanticBytes: 364,
      },
      "console-chapter18": {
        operations: 120,
        remaining: 114,
        semanticBytes: 397,
      },
      "console-formatting-chapter18": {
        diagnostic: 40,
        part: 3,
        offset: 482,
      },
    });
  });
});
