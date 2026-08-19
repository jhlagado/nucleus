import { createHash } from "node:crypto";

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

const execute = (built: NucleusCompileSuccess) =>
  executeCommittedNobj(built.nobj, {
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
  });

const expectRoutineFlow = async (
  name: string,
  source: string,
  expected: { readonly offset: number; readonly line: number; readonly column: number },
): Promise<void> => {
  const result = await compileNucleus([{ name, source }]);
  expect(result).toMatchObject({
    success: false,
    diagnostic: {
      code: 75,
      sourcePart: 1,
      sourceName: name,
      ...expected,
    },
  });
};

const sha256 = (value: string | Uint8Array): string =>
  createHash("sha256").update(value).digest("hex");

describe("literal while true fallthrough", () => {
  it("executes a value routine whose literal-true loop returns", async () => {
    const source = [
      "sub run() as u8",
      "while true",
      "return 1",
      "end",
      "end",
      "sub main() fails",
      "writeOutputByte(run()) else fail",
      "end",
      "",
    ].join("\n");
    const built = await compileNucleus([{ name: "run.nu", source }], {
      services,
    });
    if (!built.success) throw new Error(JSON.stringify(built));
    const executed = execute(built);
    expect(executed.memory[statusAddress]).toBe(1);
    expect(executed.memory[outputLength]).toBe(1);
    expect(executed.memory[outputBase]).toBe(1);
  });

  it("accepts a compile-only non-returning literal-true routine", async () => {
    const source = [
      "sub run() as u8",
      "while true",
      "continue",
      "end",
      "end",
      "sub main()",
      "end",
      "",
    ].join("\n");
    expect((await compileNucleus([{ name: "continue.nu", source }])).success).toBe(
      true,
    );
  });

  it("counts exits that target the literal-true loop", async () => {
    await expectRoutineFlow(
      "exit.nu",
      "sub run() as u8\nwhile true\nexit\nend\nend\nsub main()\nend\n",
      { offset: 39, line: 5, column: 4 },
    );
    await expectRoutineFlow(
      "if-exit.nu",
      "sub run() as u8\nwhile true\nif true\nexit\nend\nend\nend\nsub main()\nend\n",
      { offset: 51, line: 7, column: 4 },
    );
    await expectRoutineFlow(
      "unreachable-exit.nu",
      "sub run() as u8\nwhile true\nreturn 1\nexit\nend\nend\nsub main()\nend\n",
      { offset: 48, line: 6, column: 4 },
    );
  });

  it("does not count exits that target nested loops", async () => {
    const sources = [
      [
        "nested-while.nu",
        [
          "sub run() as u8",
          "while true",
          "while true",
          "exit",
          "end",
          "return 1",
          "end",
          "end",
          "sub main()",
          "end",
          "",
        ].join("\n"),
      ],
      [
        "nested-for.nu",
        [
          "sub run() as u8",
          "var i as u8",
          "while true",
          "for i = 0 until 1",
          "exit",
          "end",
          "return 1",
          "end",
          "end",
          "sub main()",
          "end",
          "",
        ].join("\n"),
      ],
    ] as const;
    for (const [name, source] of sources) {
      expect((await compileNucleus([{ name, source }])).success).toBe(true);
    }
  });

  it("keeps every nonliteral condition and every for loop conservative", async () => {
    const cases = [
      [
        "parenthesized.nu",
        "sub run() as u8\nwhile (true)\nreturn 1\nend\nend\nsub main()\nend\n",
        { offset: 45, line: 5, column: 4 },
      ],
      [
        "not-false.nu",
        "sub run() as u8\nwhile not false\nreturn 1\nend\nend\nsub main()\nend\n",
        { offset: 48, line: 5, column: 4 },
      ],
      [
        "boolean-expression.nu",
        "sub run() as u8\nwhile true and true\nreturn 1\nend\nend\nsub main()\nend\n",
        { offset: 52, line: 5, column: 4 },
      ],
      [
        "named.nu",
        "const Always = true\nsub run() as u8\nwhile Always\nreturn 1\nend\nend\nsub main()\nend\n",
        { offset: 65, line: 6, column: 4 },
      ],
      [
        "dynamic.nu",
        "sub run() as u8\nvar flag as boolean = true\nwhile flag\nreturn 1\nend\nend\nsub main()\nend\n",
        { offset: 70, line: 6, column: 4 },
      ],
      [
        "for.nu",
        "sub run() as u8\nvar i as u8\nfor i = 0 until 1\nreturn 1\nend\nend\nsub main()\nend\n",
        { offset: 62, line: 6, column: 4 },
      ],
    ] as const;
    for (const [name, source, position] of cases) {
      await expectRoutineFlow(name, source, position);
    }
  });

  it("keeps an existing trailing-return artifact byte-identical to 0.3 baseline", async () => {
    const source = [
      "sub run() as u8",
      "while true",
      "return 1",
      "end",
      "return 0",
      "end",
      "sub main() fails",
      "writeOutputByte(run()) else fail",
      "end",
      "",
    ].join("\n");
    const built = await compileNucleus(
      [{ name: "existing.nu", source }],
      {},
      { debugMap: true },
    );
    if (!built.success) throw new Error(JSON.stringify(built));
    expect(sha256(built.nobj)).toBe(
      "82a8704ddafc8dd097483021aff36fa9211d8ad9b426c66f3fd1fe977fa6f4ca",
    );
    expect(sha256(writeNucleusIntelHex(built))).toBe(
      "0855072388953c7b2e1548e8d745434158c8ad517623ab4d73bef8fc68352238",
    );
    expect(sha256(built.materialized.flatImage ?? new Uint8Array())).toBe(
      "546c4e6feda52e26db9a5a44f1cc6985087de35e549e4bb65caae7b0c9eef6f9",
    );
    expect(built.materialized.parsed.map.banks[0]?.usedLength).toBe(1_051);
    expect(built.debugMapping).toMatchObject({
      semanticOperations: 15,
      sourceMarks: 9,
      imageBytes: 247,
    });
  });

  it("clears every reused while mode at capacity and between compilations", async () => {
    const nested = [
      "sub run() as u8",
      ...Array.from({ length: 8 }, () => "while true"),
      "exit",
      ...Array.from({ length: 8 }, () => "end"),
      "end",
      "sub main()",
      "end",
      "",
    ].join("\n");
    expect((await compileNucleus([{ name: "capacity.nu", source: nested }])).success).toBe(
      true,
    );

    await expectRoutineFlow(
      "after-capacity.nu",
      "sub run() as u8\nvar flag as boolean = true\nwhile flag\nreturn 1\nend\nend\nsub main()\nend\n",
      { offset: 70, line: 6, column: 4 },
    );
    expect(
      (
        await compileNucleus([
          { name: "recovered.nu", source: "sub main()\nend\n" },
        ])
      ).success,
    ).toBe(true);
  });
});
