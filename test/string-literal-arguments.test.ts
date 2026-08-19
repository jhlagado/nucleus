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
    maxInstructions: 100_000,
    maxCycles: 1_000_000,
    halted: true,
    writes: [
      { at: services.writeOutputByte, bytes: outputService },
      { at: services.success, bytes: terminal(1) },
      { at: services.unhandledFailure, bytes: terminal(2) },
      { at: services.trap, bytes: terminal(3) },
    ],
  });

const bankedTarget = (partBanks: readonly number[]) => ({
  bankCount: 2,
  entryBank: 0,
  partBanks,
  imageBase: 0x8000,
  imageCapacity: 0x1000,
  writableBase: 0x4000,
  writableCapacity: 0x1000,
  services: { ...services, farCall: 0x7000, farJump: 0x7080 },
});

const bytesAt = (
  built: NucleusCompileSuccess,
  bank: number,
  address: number,
  length: number,
): readonly number[] => {
  const image = built.materialized.flatImage ?? built.materialized.banks[bank];
  if (image === undefined) throw new Error(`bank ${bank} is unavailable`);
  return Array.from(
    image.slice(
      address - built.materialized.parsed.begin.imageBase,
      address - built.materialized.parsed.begin.imageBase + length,
    ),
  );
};

describe("contextual string-literal arguments", () => {
  it("evaluates arguments left to right and gives every source site a stable distinct object", async () => {
    const source = [
      "var order as u8",
      "sub mark(value as u8) as u8",
      "order = order * 10 + value",
      "return value",
      "end",
      "sub observe(prefix as u8, text as string[], suffix as u8) fails",
      "writeOutputByte(prefix) else fail",
      "writeOutputByte(text.length) else fail",
      "writeOutputByte(text[0]) else fail",
      "text[0] = suffix",
      "end",
      "sub measure(text as string[]) as u8",
      "return text.length",
      "end",
      "sub main() fails",
      "var i as u8",
      "for i = 0 until 2",
      'observe(mark(1), "Hi", mark(2)) else fail',
      "end",
      'observe(mark(3), "Hi", mark(4)) else fail',
      "writeOutputByte(order) else fail",
      'writeOutputByte(measure("Z")) else fail',
      "end",
      "",
    ].join("\n");
    const built = await compileNucleus(
      [{ name: "identity.nu", source }],
      { services },
      { debugMap: true },
    );
    if (!built.success) throw new Error(JSON.stringify(built));
    const executed = execute(built);
    expect(executed.memory[statusAddress]).toBe(1);
    expect(
      Array.from(
        executed.memory.slice(
          outputBase,
          outputBase + (executed.memory[outputLength] ?? 0),
        ),
      ),
    ).toEqual([1, 2, 72, 1, 2, 2, 3, 2, 72, 146, 1]);
  });

  it("seals empty, embedded-zero, and maximum literals exactly", async () => {
    const maximum = "x".repeat(253);
    const source = [
      "sub take(value as string[])",
      "end",
      "sub main()",
      'take("")',
      'take("A\\0B")',
      `take("${maximum}")`,
      "end",
      "",
    ].join("\n");
    const built = await compileNucleus(
      [{ name: "bounds.nu", source }],
      {},
      { debugMap: true },
    );
    if (!built.success) throw new Error(JSON.stringify(built));
    const bank = built.materialized.parsed.map.banks[0];
    expect(bank?.aggregateConstantLength).toBe(3 + 5 + 255);
    const objects = bytesAt(
      built,
      0,
      bank?.aggregateConstantBase ?? 0,
      bank?.aggregateConstantLength ?? 0,
    );
    expect(objects.slice(0, 8)).toEqual([0, 0, 0, 3, 65, 0, 66, 0]);
    expect(objects.slice(8, 12)).toEqual([253, 120, 120, 120]);
    expect(objects.at(-1)).toBe(0);
  });

  it("retains named constants and emits literal aliases through the ordinary carrier", async () => {
    const source = [
      'const named as string[2] = "OK"',
      "sub take(value as string[])",
      "end",
      "sub main()",
      'take("Hi")',
      'take("")',
      "end",
      "",
    ].join("\n");
    const built = await compileNucleus(
      [{ name: "layout.nu", source }],
      {},
      { debugMap: true },
    );
    if (!built.success) throw new Error(JSON.stringify(built));
    const bank = built.materialized.parsed.map.banks[0];
    expect(
      bytesAt(
        built,
        0,
        bank?.aggregateConstantBase ?? 0,
        bank?.aggregateConstantLength ?? 0,
      ),
    ).toEqual([2, 79, 75, 0, 2, 72, 105, 0, 0, 0, 0]);
    const literalAddress = (bank?.aggregateConstantBase ?? 0) + 4;
    const callSegment = (built.debugMapping?.maps ?? [])[0]?.map.files?.[
      "layout.nu"
    ]?.segments?.find(({ line }) => line === 5);
    expect(callSegment).toBeDefined();
    const callBytes = bytesAt(
      built,
      0,
      callSegment?.start ?? 0,
      (callSegment?.end ?? 0) - (callSegment?.start ?? 0),
    );
    const alias = [
      0x21,
      literalAddress & 0xff,
      literalAddress >>> 8,
      0xe5,
    ];
    expect(
      callBytes.some((_, index) =>
        alias.every((byte, offset) => callBytes[index + offset] === byte),
      ),
    ).toBe(true);
  });

  it("places a same-bank literal in that bank and keeps traced output identical", async () => {
    const parts = [
      {
        name: "unused.nu",
        source: "sub unused()\nend\n",
      },
      {
        name: "main.nu",
        source: [
          "sub take(value as string[])",
          "end",
          "sub main()",
          'take("bank")',
          "end",
          "",
        ].join("\n"),
      },
    ] as const;
    const target = bankedTarget([1, 0]);
    const normal = await compileNucleus(parts, target);
    const traced = await compileNucleus(parts, target, { debugMap: true });
    expect(normal.success).toBe(true);
    expect(traced.success).toBe(true);
    if (!normal.success || !traced.success) return;
    expect(traced.nobj).toEqual(normal.nobj);
    const bank = normal.materialized.parsed.map.banks[0];
    expect(
      bytesAt(
        normal,
        0,
        bank?.aggregateConstantBase ?? 0,
        bank?.aggregateConstantLength ?? 0,
      ),
    ).toEqual([4, 98, 97, 110, 107, 0]);
    expect(normal.materialized.parsed.map.banks[1]?.aggregateConstantLength).toBe(
      0,
    );
  });

  it("rejects a literal passed across a bank boundary at the literal", async () => {
    const parts = [
      {
        name: "library.nu",
        source: "sub take(value as string[])\nend\n",
      },
      {
        name: "main.nu",
        source: 'sub main()\ntake("Hi")\nend\n',
      },
    ] as const;
    const built = await compileNucleus(parts, bankedTarget([1, 0]));
    expect(built.success).toBe(false);
    if (built.success) return;
    expect(built.diagnostic).toEqual({
      code: 95,
      sourcePart: 2,
      sourceName: "main.nu",
      offset: 16,
      line: 2,
      column: 6,
    });
  });

  it.each([
    {
      name: "first over-capacity literal",
      parameter: "string[]",
      literal: "x".repeat(254),
      code: 90,
    },
    { name: "scalar formal", parameter: "u8", literal: "x", code: 58 },
    {
      name: "concrete aggregate formal",
      parameter: "string[3]",
      literal: "x",
      code: 130,
    },
  ])("rejects $name at the offending argument", async ({ parameter, literal, code }) => {
    const source = [
      `sub take(value as ${parameter})`,
      "end",
      "sub main()",
      `take("${literal}")`,
      "end",
      "",
    ].join("\n");
    const built = await compileNucleus([{ name: "invalid.nu", source }]);
    expect(built.success).toBe(false);
    if (built.success) return;
    expect(built.diagnostic).toEqual({
      code,
      sourcePart: 1,
      sourceName: "invalid.nu",
      offset: source.indexOf(`"${literal}"`),
      line: 4,
      column: 6,
    });
  });

  it("does not admit literals as assignments or general expressions", async () => {
    const source = [
      'var text as string[3] = "a"',
      "sub main()",
      'text = "x"',
      "end",
      "",
    ].join("\n");
    const built = await compileNucleus([{ name: "assignment.nu", source }]);
    expect(built.success).toBe(false);
    if (built.success) return;
    expect(built.diagnostic).toEqual({
      code: 130,
      sourcePart: 1,
      sourceName: "assignment.nu",
      offset: source.indexOf('"x"'),
      line: 3,
      column: 8,
    });
  });

  it.each([
    { call: "take()", code: 130, relativeOffset: 5, column: 6 },
    { call: 'take("x", "y")', code: 134, relativeOffset: 8, column: 9 },
  ])(
    "retains exact wrong-arity diagnostics for $call",
    async ({ call, code, relativeOffset, column }) => {
      const source = [
        "sub take(value as string[])",
        "end",
        "sub main()",
        call,
        "end",
        "",
      ].join("\n");
      const built = await compileNucleus([{ name: "arity.nu", source }]);
      expect(built.success).toBe(false);
      if (built.success) return;
      expect(built.diagnostic).toEqual({
        code,
        sourcePart: 1,
        sourceName: "arity.nu",
        offset: source.indexOf(call) + relativeOffset,
        line: 4,
        column,
      });
    },
  );

  it("rolls back a failed literal compilation and succeeds identically afterward", async () => {
    const valid = [
      "sub take(value as string[])",
      "end",
      "sub main()",
      'take("ok")',
      "end",
      "",
    ].join("\n");
    const invalid = valid.replace('take("ok")', 'take("ok")\nmissing()');
    const before = await compileNucleus([{ name: "valid.nu", source: valid }]);
    const rejected = await compileNucleus([
      { name: "invalid.nu", source: invalid },
    ]);
    const recovered = await compileNucleus([
      { name: "valid.nu", source: valid },
    ]);
    expect(before.success).toBe(true);
    expect(rejected.success).toBe(false);
    expect(recovered.success).toBe(true);
    if (!before.success || !recovered.success) return;
    expect(recovered.nobj).toEqual(before.nobj);
  });

  it("keeps repeated flat literals within the existing transcript path", async () => {
    const calls = Array.from({ length: 16 }, () => 'take("")');
    const source = [
      "sub take(value as string[])",
      "end",
      "sub main()",
      ...calls,
      "end",
      "",
    ].join("\n");
    const built = await compileNucleus(
      [{ name: "transcript.nu", source }],
      {},
      { debugMap: true },
    );
    expect(built.success).toBe(true);
    if (!built.success) return;
    expect(built.debugMapping?.semanticOperations).toBe(53);
    expect(built.materialized.parsed.map.banks[0]?.aggregateConstantLength).toBe(
      48,
    );
  });
});
