import { describe, expect, it } from "vitest";

import {
  compileNucleus,
  defaultNucleusServices,
  writeNucleusIntelHex,
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

const farCallService: readonly number[] = [
  0x32, 0x40, 0x70, 0x22, 0x42, 0x70, 0xe1, 0x22, 0x44, 0x70, 0x3a, 0x46, 0x70,
  0x32, 0x47, 0x70, 0x3a, 0x40, 0x70, 0x32, 0x46, 0x70, 0xd3, 0x7f, 0x21, 0x20,
  0x70, 0xe5, 0x2a, 0x42, 0x70, 0xe9, 0xf5, 0x3a, 0x47, 0x70, 0x32, 0x46, 0x70,
  0xd3, 0x7f, 0xf1, 0xed, 0x5b, 0x44, 0x70, 0xd5, 0xc9,
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

const compile = (source: string) =>
  compileNucleus([{ name: "signed.nu", source }], { services });

const expectOutput = async (source: string, expected: readonly number[]) => {
  const built = await compile(source);
  if (!built.success) throw new Error(JSON.stringify(built));
  const executed = execute(built);
  expect(executed.memory[statusAddress]).toBe(1);
  expect(
    Array.from(executed.memory.slice(outputBase, outputBase + expected.length)),
  ).toEqual(expected);
  expect(executed.memory[outputLength]).toBe(expected.length);
};

describe("signed integers", () => {
  it.each([
    ["i8", "-128", true],
    ["i8", "127", true],
    ["i8", "-129", false],
    ["i8", "128", false],
    ["i16", "-32768", true],
    ["i16", "32767", true],
    ["i16", "-32769", false],
    ["i16", "32768", false],
    ["u8", "-1", false],
    ["u16", "-1", false],
  ])("checks the %s boundary %s", async (type, value, accepted) => {
    const built = await compile(
      `var value as ${type} = ${value}\nsub main()\nend\n`,
    );
    expect(built.success).toBe(accepted);
    if (!accepted && !built.success) {
      expect(built.diagnostic).toMatchObject({
        code: 61,
        sourcePart: 1,
        sourceName: "signed.nu",
        line: 1,
      });
    }
  });

  it("distinguishes negative exact values from positive bit patterns", async () => {
    const source = [
      "var signed as i16 = -1",
      "var bits as u16 = $FFFF",
      "var small as i8 = i8(-1)",
      "sub main() fails",
      "if signed = -1",
      "writeOutputByte(1) else fail",
      "end",
      "if bits = 65535",
      "writeOutputByte(2) else fail",
      "end",
      "if small = -1",
      "writeOutputByte(3) else fail",
      "end",
      "end",
      "",
    ].join("\n");
    await expectOutput(source, [1, 2, 3]);

    const rejected = await compile(
      "var value as i8 = i8($FF)\nsub main()\nend\n",
    );
    expect(rejected).toMatchObject({
      success: false,
      diagnostic: { code: 63, line: 1, column: 25 },
    });
  });

  it("executes signed arithmetic, bitwise operations and comparisons", async () => {
    const checks = [
      "i8(127) + 1 = -128",
      "i8(-128) - 1 = 127",
      "i8(-16) * 4 = -64",
      "-i8(-128) = -128",
      "not i8(0) = -1",
      "(i8(-8) and i8(3)) = 0",
      "(i8(-8) or i8(3)) = -5",
      "(i8(-8) xor i8(3)) = -5",
      "i16(-32768) < -1",
      "i8(-1) < 0",
      "i8(127) > -128",
      "i16(-1) <> 0",
    ];
    const lines = ["sub main() fails"];
    checks.forEach((check, index) => {
      lines.push(`if ${check}`);
      lines.push(`writeOutputByte(${index + 1}) else fail`);
      lines.push("end");
    });
    lines.push("end", "");
    await expectOutput(
      lines.join("\n"),
      checks.map((_, index) => index + 1),
    );
  });

  it("binds not as a unary operator", async () => {
    const source = [
      "sub main() fails",
      "if not i8(0) <> -2",
      "writeOutputByte(1) else fail",
      "end",
      "if not (i8(0) = -2)",
      "writeOutputByte(2) else fail",
      "end",
      "end",
      "",
    ].join("\n");
    await expectOutput(source, [1, 2]);
  });

  it("resolves routine bindings before shadowed program bindings", async () => {
    const source = [
      "var value as u8 = 9",
      "var copy as u8 = 8",
      "sub choose(value as u8) as u8",
      "var copy as u8 = value",
      "return copy",
      "end",
      "sub main() fails",
      "var value as u8 = 3",
      "writeOutputByte(choose(value)) else fail",
      "writeOutputByte(copy) else fail",
      "end",
      "",
    ].join("\n");
    await expectOutput(source, [3, 8]);

    const duplicate = await compile(
      [
        "sub work(value as u8)",
        "var value as u8",
        "end",
        "sub main()",
        "end",
        "",
      ].join("\n"),
    );
    expect(duplicate).toMatchObject({
      success: false,
      diagnostic: { code: 55, line: 2, column: 5 },
    });
  });

  it("selects every constant and runtime comparison truth-table cell", async () => {
    const operators = ["=", "<>", "<", "<=", ">", ">="] as const;
    const truthByOperator = [
      [true, false, false],
      [false, true, true],
      [false, true, false],
      [true, true, false],
      [false, false, true],
      [true, false, true],
    ] as const;
    const cases = [
      {
        declarations: [] as string[],
        operands: ["u16(255)", "u16(256)", "u16(255)"] as const,
      },
      {
        declarations: [] as string[],
        operands: ["i16(-1)", "i16(1)", "i16(-1)"] as const,
      },
      {
        declarations: [
          "var lower as u16 = 255",
          "var upper as u16 = 256",
          "var equal as u16 = 255",
        ],
        operands: ["lower", "upper", "equal"] as const,
      },
      {
        declarations: [
          "var lower as i16 = -1",
          "var upper as i16 = 1",
          "var equal as i16 = -1",
        ],
        operands: ["lower", "upper", "equal"] as const,
      },
    ] as const;

    for (const { declarations, operands } of cases) {
      const relations = [
        [operands[0], operands[2]],
        [operands[0], operands[1]],
        [operands[1], operands[0]],
      ] as const;
      for (const operatorStart of [0, 3]) {
        const lines = [...declarations, "sub main() fails"];
        let output = 1;
        operators
          .slice(operatorStart, operatorStart + 3)
          .forEach((operator, relativeOperatorIndex) => {
            const operatorIndex = operatorStart + relativeOperatorIndex;
            relations.forEach(([left, right], relationIndex) => {
              const comparison = `${left} ${operator} ${right}`;
              const condition = truthByOperator[operatorIndex][relationIndex]
                ? comparison
                : `not (${comparison})`;
              lines.push(`if ${condition}`);
              lines.push(`writeOutputByte(${output}) else fail`);
              lines.push("end");
              output += 1;
            });
          });
        lines.push("end", "");
        await expectOutput(
          lines.join("\n"),
          Array.from({ length: 9 }, (_, index) => index + 1),
        );
      }
    }
  });

  it("uses truncation toward zero and a dividend-signed remainder", async () => {
    const checks = [
      "i16(7) / 3 = 2",
      "i16(-7) / 3 = -2",
      "i16(7) / -3 = -2",
      "i16(-7) / -3 = 2",
      "i16(7) mod 3 = 1",
      "i16(-7) mod 3 = -1",
      "i16(7) mod -3 = 1",
      "i16(-7) mod -3 = -1",
      "i8(-128) / -1 = -128",
      "i16(-32768) / -1 = -32768",
      "i16(-32768) mod -1 = 0",
    ];
    const lines = ["sub main() fails"];
    checks.forEach((check, index) => {
      lines.push(`if ${check}`);
      lines.push(`writeOutputByte(${index + 1}) else fail`);
      lines.push("end");
    });
    lines.push("end", "");
    await expectOutput(
      lines.join("\n"),
      checks.map((_, index) => index + 1),
    );
  });

  it("matches signed division and remainder semantics for runtime values", async () => {
    const source = [
      "var dividend as i16 = -7",
      "var divisor as i16 = 3",
      "var minimum as i16 = -32768",
      "var negativeThree as i16 = -3",
      "sub main() fails",
      "if dividend / divisor = -2 and dividend mod divisor = -1",
      "writeOutputByte(1) else fail",
      "end",
      "if minimum / negativeThree = 10922 and minimum mod negativeThree = -2",
      "writeOutputByte(2) else fail",
      "end",
      "end",
      "",
    ].join("\n");
    await expectOutput(source, [1, 2]);
  });

  it("supports every explicit integer conversion family", async () => {
    const source = [
      "var u8value as u8 = 7",
      "var u16value as u16 = 7",
      "var i8value as i8 = -7",
      "var i16value as i16 = -7",
      "sub main() fails",
      "writeOutputByte(u8(u8value)) else fail",
      "writeOutputByte(u8(u16(u8value))) else fail",
      "writeOutputByte(u8(i8(u8value))) else fail",
      "writeOutputByte(u8(i16(u8value))) else fail",
      "writeOutputByte(u8(u16value)) else fail",
      "writeOutputByte(u8(u16(u16value))) else fail",
      "writeOutputByte(u8(i8(u16value))) else fail",
      "writeOutputByte(u8(i16(u16value))) else fail",
      "writeOutputByte(u8(i8value + 14)) else fail",
      "writeOutputByte(u8(u16(i8value + 14))) else fail",
      "writeOutputByte(u8(i8(i8value) + 14)) else fail",
      "writeOutputByte(u8(i16(i8value) + 14)) else fail",
      "writeOutputByte(u8(i16value + 14)) else fail",
      "writeOutputByte(u8(u16(i16value + 14))) else fail",
      "writeOutputByte(u8(i8(i16value) + 14)) else fail",
      "writeOutputByte(u8(i16(i16value) + 14)) else fail",
      "end",
      "",
    ].join("\n");
    await expectOutput(
      source,
      Array.from({ length: 16 }, () => 7),
    );
  });

  it("traps dynamic conversion failures before storing the destination", async () => {
    const source = [
      "var source as i16 = -1",
      "var destination as u8 = 42",
      "sub main()",
      "destination = u8(source)",
      "end",
      "",
    ].join("\n");
    const built = await compile(source);
    if (!built.success) throw new Error(JSON.stringify(built));
    const executed = execute(built);
    expect(executed.memory[statusAddress]).toBe(3);
    expect(executed.memory[built.materialized.parsed.map.bssBase - 1]).toBe(42);
  });

  it("checks dynamic conversion boundaries and negative i8 promotion", async () => {
    const accepted = [
      "var unsignedWord as u16 = 32767",
      "var signedWord as i16 = 32767",
      "var signedLow as i16 = -128",
      "var signedHigh as i16 = 127",
      "var unsignedByte as u16 = 255",
      "var signedByte as i8 = 127",
      "var negativeByte as i8 = -128",
      "var promoted as i16",
      "sub main() fails",
      "promoted = negativeByte",
      "if i16(unsignedWord) = 32767",
      "writeOutputByte(1) else fail",
      "end",
      "if u16(signedWord) = 32767",
      "writeOutputByte(2) else fail",
      "end",
      "if i8(signedLow) = -128 and i8(signedHigh) = 127",
      "writeOutputByte(3) else fail",
      "end",
      "if u8(unsignedByte) = 255 and u8(signedByte) = 127",
      "writeOutputByte(4) else fail",
      "end",
      "if promoted = -128",
      "writeOutputByte(5) else fail",
      "end",
      "end",
      "",
    ].join("\n");
    await expectOutput(accepted, [1, 2, 3, 4, 5]);

    for (const [sourceType, value, destinationType] of [
      ["u16", "32768", "i16"],
      ["i16", "-1", "u16"],
      ["i16", "-129", "i8"],
      ["i16", "128", "i8"],
      ["u16", "256", "u8"],
      ["i8", "-1", "u8"],
    ] as const) {
      const source = [
        `var source as ${sourceType} = ${value}`,
        `var destination as ${destinationType}`,
        "sub main()",
        `destination = ${destinationType}(source)`,
        "end",
        "",
      ].join("\n");
      const built = await compile(source);
      if (!built.success) throw new Error(JSON.stringify(built));
      const executed = execute(built);
      expect(
        executed.memory[statusAddress],
        `${sourceType} ${value} to ${destinationType}`,
      ).toBe(3);
    }
  });

  it("keeps signed flat and banked target artifacts identical with tracing enabled", async () => {
    const parts = [
      {
        name: "signed.nu",
        source: [
          "var value as i16 = -300",
          "sub main() fails",
          "var counter as i8",
          "for counter = -1 to 1",
          "value = value + counter",
          "end",
          "writeOutputByte(u8(value + 300)) else fail",
          "end",
          "",
        ].join("\n"),
      },
    ] as const;
    const flatNormal = await compileNucleus(parts, { services });
    const flatDebug = await compileNucleus(
      parts,
      { services },
      { debugMap: true },
    );
    expect(flatNormal.success).toBe(true);
    expect(flatDebug.success).toBe(true);
    if (!flatNormal.success || !flatDebug.success) return;
    expect(flatDebug.nobj).toEqual(flatNormal.nobj);
    expect(writeNucleusIntelHex(flatDebug)).toBe(
      writeNucleusIntelHex(flatNormal),
    );
    expect(flatDebug.materialized.flatImage).toEqual(
      flatNormal.materialized.flatImage,
    );

    const banked = {
      bankCount: 2,
      entryBank: 1,
      partBanks: [1],
      services: { ...services, farCall: 0x7000, farJump: 0x7080 },
    } as const;
    const bankNormal = await compileNucleus(parts, banked);
    const bankDebug = await compileNucleus(parts, banked, { debugMap: true });
    expect(bankNormal.success).toBe(true);
    expect(bankDebug.success).toBe(true);
    if (!bankNormal.success || !bankDebug.success) return;
    expect(bankDebug.nobj).toEqual(bankNormal.nobj);
    expect(bankDebug.materialized.banks).toEqual(bankNormal.materialized.banks);
  }, 30_000);

  it("stores, passes and returns signed scalar values", async () => {
    const source = [
      "record Pair",
      "small as i8",
      "word as i16",
      "end",
      "var before as u8 = 85",
      "var pair as Pair = (-7, -300)",
      "var values as i16[2] = [-1, 32767]",
      "var after as u8 = 170",
      "sub recurse(value as i8, depth as u8) as i8",
      "if depth = 0",
      "return value",
      "end",
      "return recurse(value, depth - 1)",
      "end",
      "sub main() fails",
      "if pair.small = -7",
      "writeOutputByte(1) else fail",
      "end",
      "if pair.word = -300",
      "writeOutputByte(2) else fail",
      "end",
      "if values[0] = -1",
      "writeOutputByte(3) else fail",
      "end",
      "if recurse(-9, 2) = -9",
      "writeOutputByte(4) else fail",
      "end",
      "end",
      "",
    ].join("\n");
    const built = await compile(source);
    if (!built.success) throw new Error(JSON.stringify(built));
    const executed = execute(built);
    expect(executed.memory[statusAddress]).toBe(1);
    expect(
      Array.from(executed.memory.slice(outputBase, outputBase + 4)),
    ).toEqual([1, 2, 3, 4]);
    const data = built.materialized.parsed.map.bssBase - 9;
    expect(executed.memory[data]).toBe(85);
    expect(executed.memory[data + 1]).toBe(0xf9);
    expect(Array.from(executed.memory.slice(data + 2, data + 4))).toEqual([
      0xd4, 0xfe,
    ]);
    expect(executed.memory[data + 8]).toBe(170);
  });

  it("admits signed indexes and counted loops across zero", async () => {
    const source = [
      "var values as u8[4] = [10, 20, 30, 40]",
      "sub main() fails",
      "var index as i8 = 2",
      "var i as i16",
      "var j as i16",
      "writeOutputByte(values[index]) else fail",
      "for i = -2 to 2",
      "writeOutputByte(u8(i + 2)) else fail",
      "end",
      "for j = 2 to -2 step -2",
      "writeOutputByte(u8(j + 2)) else fail",
      "end",
      "end",
      "",
    ].join("\n");
    await expectOutput(source, [30, 0, 1, 2, 3, 4, 4, 2, 0]);
  });

  it("rejects a compile-time negative index and traps a dynamic one", async () => {
    const rejected = await compile(
      "var values as u8[4]\nsub main()\nvar value as u8 = values[-1]\nend\n",
    );
    expect(rejected).toMatchObject({
      success: false,
      diagnostic: { code: 61, sourcePart: 1, sourceName: "signed.nu", line: 3 },
    });

    const source = [
      "var values as u8[256]",
      "var result as u8 = 42",
      "sub main()",
      "var index as i8 = -1",
      "result = values[index]",
      "end",
      "",
    ].join("\n");
    const built = await compileNucleus([{ name: "signed.nu", source }], {
      services,
      writableCapacity: 0x2000,
    });
    if (!built.success) throw new Error(JSON.stringify(built));
    const executed = execute(built);
    expect(executed.memory[statusAddress]).toBe(3);
    expect(executed.memory[built.materialized.parsed.map.bssBase - 1]).toBe(42);
  });

  it("rejects Boolean/integer mixing and the disallowed common-type pairs", async () => {
    const expressions = [
      "true + 1",
      "+true",
      "-true",
      "u8(true)",
      "u16(true)",
      "u16(1) + i8(1)",
      "u16(1) + i16(1)",
      "i16(1) + u16(1)",
    ];
    for (const expression of expressions) {
      const built = await compile(
        `sub main()\nvar value as i16 = ${expression}\nend\n`,
      );
      expect(built.success, expression).toBe(false);
      if (!built.success) {
        expect(built.diagnostic).toMatchObject({ code: 60, sourcePart: 1 });
      }
    }
  });

  it("applies value-preserving implicit widening in every scalar position", async () => {
    const source = [
      "const negative = -7",
      "const positive = 100",
      "var byteValue as u8 = positive",
      "var signedByte as i8 = negative",
      "var unsignedWord as u16",
      "var signedWordFromByte as i16",
      "var signedWordFromSignedByte as i16",
      "sub widenByte(value as u8) as i16",
      "return value",
      "end",
      "sub widenSigned(value as i8) as i16",
      "return value",
      "end",
      "sub main() fails",
      "var modularByte as u8 = 1",
      "var modularWord as u16 = 1",
      "unsignedWord = byteValue",
      "signedWordFromByte = byteValue",
      "signedWordFromSignedByte = signedByte",
      "modularByte = -modularByte",
      "modularWord = -modularWord",
      "if unsignedWord = 100 and signedWordFromByte = 100 and signedWordFromSignedByte = -7",
      "writeOutputByte(1) else fail",
      "end",
      "if widenByte(byteValue) = 100 and widenSigned(signedByte) = -7",
      "writeOutputByte(2) else fail",
      "end",
      "if byteValue + signedByte = 93 and byteValue + signedWordFromSignedByte = 93",
      "writeOutputByte(3) else fail",
      "end",
      "if modularByte = $FF and modularWord = $FFFF",
      "writeOutputByte(4) else fail",
      "end",
      "end",
      "",
    ].join("\n");
    await expectOutput(source, [1, 2, 3, 4]);
  });

  it("preserves signed values through failable success and handling", async () => {
    const source = [
      "sub choose(value as i8, reject as boolean) as i8 fails",
      "if reject",
      "fail 7",
      "end",
      "return value",
      "end",
      "sub main() fails",
      "var result as i8 = 0",
      "var code as u8",
      "result = choose(-9, false) else fail",
      "writeOutputByte(u8(i16(result) + 9)) else fail",
      "result = choose(4, true) handle code",
      "writeOutputByte(code) else fail",
      "return",
      "end",
      "end",
      "",
    ].join("\n");
    await expectOutput(source, [0, 7]);
  });

  it("keeps signed metadata distinct across all aggregate ordinals and banks", async () => {
    const declarations = Array.from(
      { length: 8 },
      (_, index) => `var a${index + 1} as i8[${index + 1}]`,
    ).join("\n");
    const ordinalProof = await compile(`${declarations}\nsub main()\nend\n`);
    expect(ordinalProof.success).toBe(true);

    const parts = [
      {
        name: "library.nu",
        source: [
          "record Box",
          "value as i16",
          "end",
          "const shared as Box = (-300)",
          "sub read() as i16",
          "return shared.value",
          "end",
          "sub negative() as i8",
          "return -1",
          "end",
          "",
        ].join("\n"),
      },
      {
        name: "main.nu",
        source: [
          "var observed as u8",
          "sub main()",
          "if read() = -300 and negative() = -1",
          "observed = 1",
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
    const executed = executeCommittedNobj(
      built.nobj,
      {
        maxInstructions: 60_000,
        maxCycles: 600_000,
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
    expect(executed.memory[built.materialized.parsed.map.bssBase]).toBe(1);
  });

  it("accepts signed indexes for fixed arrays and every live open view", async () => {
    const source = [
      "var bytes as u8[4] = [10, 20, 30, 40]",
      'var text as string[4] = "ABCD"',
      "sub readViews(items as u8[], word as string[]) fails",
      "var small as i8 = 1",
      "var wide as i16 = 2",
      "writeOutputByte(items[small]) else fail",
      "writeOutputByte(word[wide]) else fail",
      "end",
      "sub main() fails",
      "var wide as i16 = 3",
      "writeOutputByte(bytes[wide]) else fail",
      "writeOutputByte(text[i8(0)]) else fail",
      "readViews(bytes, text) else fail",
      "end",
      "",
    ].join("\n");
    await expectOutput(source, [40, 65, 20, 67]);
  });

  it("rejects negative signed indexes before open-view reads or writes", async () => {
    for (const [declaration, parameter, expression] of [
      ["var bytes as u8[4]", "items as u8[]", "items[index]"],
      ['var text as string[4] = "ABCD"', "word as string[]", "word[index]"],
    ] as const) {
      const source = [
        declaration,
        "var destination as u8 = 42",
        `sub read(${parameter})`,
        "var index as i16 = -1",
        `destination = ${expression}`,
        "end",
        "sub main()",
        `read(${declaration.includes("bytes") ? "bytes" : "text"})`,
        "end",
        "",
      ].join("\n");
      const built = await compile(source);
      if (!built.success) throw new Error(JSON.stringify(built));
      const executed = execute(built);
      const map = built.materialized.parsed.map;
      const stateBase = map.vectorBase + map.vectorLength;
      expect(executed.memory[statusAddress]).toBe(3);
      expect(executed.memory[stateBase + 1]).toBe(1);
      expect(
        executed.memory[stateBase + 3] | (executed.memory[stateBase + 4] << 8),
      ).toBe(source.indexOf("index]"));
      expect(executed.memory[built.materialized.parsed.map.bssBase - 1]).toBe(
        42,
      );
    }
  });

  it("executes signed counted-loop forms at both width boundaries", async () => {
    const source = [
      "sub main() fails",
      "var small as i8",
      "var wide as i16",
      "for small = -128 to -126",
      "writeOutputByte(u8(i16(small) + 128)) else fail",
      "end",
      "for small = 127 to 125 step -1",
      "writeOutputByte(u8(small)) else fail",
      "end",
      "for wide = -2 until 2",
      "if wide = -1",
      "continue",
      "end",
      "writeOutputByte(u8(wide + 2)) else fail",
      "end",
      "for wide = 2 to -2 step -1",
      "if wide = 0",
      "exit",
      "end",
      "writeOutputByte(u8(wide)) else fail",
      "end",
      "for wide = 1 until 1",
      "writeOutputByte(99) else fail",
      "end",
      "end",
      "",
    ].join("\n");
    await expectOutput(source, [0, 1, 2, 127, 126, 125, 0, 2, 3, 2, 1]);
  });

  it("uses the programmer's declared integer type for each counted-loop counter", async () => {
    const source = [
      "sub main() fails",
      "var byte as u8",
      "var word as u16",
      "var signedByte as i8",
      "var signedWord as i16",
      "for byte = 1 to 2",
      "writeOutputByte(byte) else fail",
      "end",
      "for word = 255 to 257",
      "writeOutputByte(u8(word - 255)) else fail",
      "end",
      "for signedByte = -1 to 1",
      "writeOutputByte(u8(i16(signedByte) + 1)) else fail",
      "end",
      "for signedWord = -100 to 100 step 100",
      "writeOutputByte(u8(signedWord + 100)) else fail",
      "end",
      "end",
      "",
    ].join("\n");
    await expectOutput(source, [1, 2, 0, 1, 2, 0, 1, 2, 0, 100, 200]);
  });

  it("requires counted-loop starts and bounds to assign to the counter type", async () => {
    const source = [
      "sub main()",
      "var counter as u8",
      "var bound as u16 = 10",
      "for counter = 0 to bound",
      "end",
      "end",
      "",
    ].join("\n");
    const rejected = await compile(source);
    expect(rejected).toMatchObject({
      success: false,
      diagnostic: {
        code: 60,
        sourcePart: 1,
        sourceName: "signed.nu",
        offset: source.indexOf("\n", source.lastIndexOf("bound")),
        line: 4,
        column: 25,
      },
    });
  });

  it("accepts folded step magnitudes and keeps direction explicit", async () => {
    const source = [
      "const magnitude = 1",
      "sub main() fails",
      "var counter as i16",
      "for counter = 0 to 4 step 1 + 1",
      "writeOutputByte(u8(counter)) else fail",
      "end",
      "for counter = 2 to 0 step -magnitude",
      "writeOutputByte(u8(counter)) else fail",
      "end",
      "end",
      "",
    ].join("\n");
    await expectOutput(source, [0, 2, 4, 2, 1, 0]);

    const invalid = [
      "sub main()",
      "var counter as i16",
      "var amount as i16 = 1",
      "for counter = 1 to 0 step amount",
      "end",
      "end",
      "",
    ].join("\n");
    const rejected = await compile(invalid);
    expect(rejected).toMatchObject({
      success: false,
      diagnostic: {
        code: 74,
        sourcePart: 1,
        sourceName: "signed.nu",
        offset: invalid.lastIndexOf("amount"),
        line: 4,
        column: 27,
      },
    });

    const negativeMagnitude = [
      "const backwards = -1",
      "sub main()",
      "var counter as i16",
      "for counter = 1 to 0 step backwards",
      "end",
      "end",
      "",
    ].join("\n");
    expect(await compile(negativeMagnitude)).toMatchObject({
      success: false,
      diagnostic: {
        code: 74,
        sourcePart: 1,
        sourceName: "signed.nu",
        offset: negativeMagnitude.lastIndexOf("backwards"),
        line: 4,
        column: 27,
      },
    });
  });

  it("accepts complete-width signed steps that land exactly on the opposite endpoint", async () => {
    const source = [
      "sub main() fails",
      "var byte as i8",
      "var word as i16",
      "var visits as u8 = 0",
      "for byte = -128 to 127 step 255",
      "visits = visits + 1",
      "if byte = 127",
      "exit",
      "end",
      "end",
      "for byte = 127 to -128 step -255",
      "visits = visits + 1",
      "if byte = -128",
      "exit",
      "end",
      "end",
      "for word = -32768 to 32767 step 65535",
      "visits = visits + 1",
      "if word = 32767",
      "exit",
      "end",
      "end",
      "for word = 32767 to -32768 step -65535",
      "visits = visits + 1",
      "if word = -32768",
      "exit",
      "end",
      "end",
      "writeOutputByte(visits) else fail",
      "end",
      "",
    ].join("\n");
    await expectOutput(source, [8]);
  });

  it.each([
    ["i8", "0", "127", "256"],
    ["i8", "0", "-128", "-256"],
    ["i16", "0", "32767", "65535"],
    ["i16", "0", "-32768", "-65535"],
  ])(
    "ends a %s loop from %s to %s before step %s crosses its bound",
    async (type, start, bound, step) => {
      const source = [
        "sub main() fails",
        `var counter as ${type}`,
        `for counter = ${start} to ${bound} step ${step}`,
        "writeOutputByte(1) else fail",
        "end",
        "end",
        "",
      ].join("\n");
      await expectOutput(source, [1]);
    },
  );

  it("retains explicitly typed signed constants and folds promoted i8 values", async () => {
    const source = [
      "const negative = i16(-1)",
      "const positive = i16(7)",
      "assert negative < i16(0)",
      "assert positive = i16(7)",
      "assert i8(-1) < i16(0)",
      "assert i8(-1) + u8(1) = i16(0)",
      "var narrowedNegative as i8 = negative",
      "var narrowedPositive as u8 = positive",
      "sub main() fails",
      "if narrowedNegative = i8(-1) and narrowedPositive = u8(7)",
      "writeOutputByte(1) else fail",
      "end",
      "end",
      "",
    ].join("\n");
    await expectOutput(source, [1]);
  });

  it.each([
    ["i8", "120", "127", "10"],
    ["i8", "-120", "-128", "-10"],
    ["i16", "32760", "32767", "10"],
    ["i16", "-32760", "-32768", "-10"],
  ])(
    "ends an %s loop before an overflowing overshoot from %s toward %s by %s",
    async (type, start, bound, step) => {
      const source = [
        "sub main() fails",
        `var counter as ${type}`,
        `for counter = ${start} to ${bound} step ${step}`,
        "writeOutputByte(1) else fail",
        "end",
        "end",
        "",
      ].join("\n");
      await expectOutput(source, [1]);
    },
  );

  it("fills the semantic transcript with signed conversion and promotion operations", async () => {
    const source = (assignments: number): string =>
      [
        "const k = 1",
        "var byte as u8 = 1",
        "var out as i16 = 0",
        "sub main()",
        "out = i16(byte)",
        "out = byte + out",
        ...Array.from({ length: assignments }, () => "out=k"),
        "while false",
        "end",
        "end",
        "",
      ].join("\n");
    const exact = await compileNucleus(
      [{ name: "signed-transcript.nu", source: source(79) }],
      {},
      { debugMap: true },
    );
    expect(exact.success).toBe(true);
    if (!exact.success) return;
    expect(exact.debugMapping?.semanticOperations).toBe(171);

    const overflow = await compileNucleus(
      [{ name: "signed-transcript.nu", source: source(80) }],
      {},
      { debugMap: true },
    );
    expect(overflow).toMatchObject({
      success: false,
      diagnostic: {
        code: 40,
        sourcePart: 1,
        sourceName: "signed-transcript.nu",
        offset: 593,
        line: 89,
        column: 4,
      },
    });
    expect("debugMapping" in overflow).toBe(false);
  });

  it("retains division diagnostics and recovers on the following compile", async () => {
    const constant = await compile(
      "var bad as i16 = i16(-7) / 0\nsub main()\nend\n",
    );
    expect(constant).toMatchObject({
      success: false,
      diagnostic: {
        code: 62,
        sourcePart: 1,
        sourceName: "signed.nu",
        offset: 27,
        line: 1,
        column: 28,
      },
    });

    const source = [
      "var divisor as i16 = 0",
      "var destination as i16 = 42",
      "sub main()",
      "destination = i16(-7) mod divisor",
      "end",
      "",
    ].join("\n");
    const built = await compile(source);
    if (!built.success) throw new Error(JSON.stringify(built));
    const executed = execute(built);
    expect(executed.memory[statusAddress]).toBe(3);
    const destination = built.materialized.parsed.map.bssBase - 2;
    expect(
      Array.from(executed.memory.slice(destination, destination + 2)),
    ).toEqual([42, 0]);

    const recovered = await compile(
      "var i8value as u8 = 1\nvar i16value as u8 = 2\nsub main()\nend\n",
    );
    expect(recovered.success).toBe(true);
  });
});
