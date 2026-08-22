import { mkdtemp, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";

import { describe, expect, it } from "vitest";

import { compileNucleusTo, defaultNucleusServices } from "../src/compiler.js";
import type { NobjSequentialOutput } from "../src/nobj.js";
import { executeCommittedNobj } from "../src/proof.js";
import { resolveNucleusImports } from "../src/source-imports.js";

const statusAddress = 0x7200;
const outputLength = statusAddress + 1;
const outputBase = outputLength + 1;
const inputLength = 0x7280;
const inputCursor = inputLength + 1;
const inputBase = inputCursor + 1;

const services = {
  ...defaultNucleusServices,
  readInputByte: 0x7080,
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

const inputService: readonly number[] = [
  0x3a,
  inputCursor & 0xff,
  inputCursor >>> 8,
  0x4f,
  0x3a,
  inputLength & 0xff,
  inputLength >>> 8,
  0xb9,
  0x28,
  0x0e,
  0x06,
  0x00,
  0x21,
  inputBase & 0xff,
  inputBase >>> 8,
  0x09,
  0x0c,
  0x79,
  0x32,
  inputCursor & 0xff,
  inputCursor >>> 8,
  0x7e,
  0xb7,
  0xc9,
  0x3e,
  0x01,
  0x37,
  0xc9,
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

const compileEntry = async (
  source: string,
  debugMap = true,
  hostTransport: "direct" | "mon3" = "direct",
) => {
  const root = await mkdtemp(path.join(tmpdir(), "nucleus-library-"));
  await writeFile(path.join(root, "main.nu"), source);
  const parts = await resolveNucleusImports({ root, entry: "main.nu" });
  const chunks: Uint8Array[] = [];
  let committed = false;
  const output: NobjSequentialOutput = {
    write(bytes) {
      chunks.push(bytes.slice());
    },
    commit() {
      committed = true;
    },
    abort() {
      chunks.length = 0;
    },
  };
  const built = await compileNucleusTo(
    parts,
    { services, imageCapacity: 0x4000 },
    output,
    { debugMap, hostTransport },
  );
  return {
    parts,
    built,
    committed,
    nobj: Uint8Array.from(chunks.flatMap((chunk) => [...chunk])),
  };
};

const execute = (nobj: Uint8Array, input: readonly number[] = []) =>
  executeCommittedNobj(nobj, {
    maxInstructions: 500_000,
    maxCycles: 5_000_000,
    halted: true,
    initialSp: 0x6ff0,
    expectedSp: 0x6ff0,
    writes: [
      { at: services.readInputByte, bytes: inputService },
      { at: services.writeOutputByte, bytes: outputService },
      { at: services.success, bytes: terminal(1) },
      { at: services.unhandledFailure, bytes: terminal(2) },
      { at: services.trap, bytes: terminal(3) },
      { at: inputLength, bytes: [input.length, 0, ...input] },
    ],
  });

describe("bundled Nucleus console library", () => {
  it("keeps the introductory program executable and observable", async () => {
    const source = await readFile(
      new URL("../examples/hello.nu", import.meta.url),
      "utf8",
    );
    const { built, committed, nobj } = await compileEntry(source, true, "mon3");
    if (!built.success) throw new Error(JSON.stringify(built));
    expect(committed).toBe(true);
    expect(built.debugMapping?.semanticBytes).toBe(367);
    const result = execute(nobj);
    const expected = Buffer.from("Total: 42\n", "ascii");
    expect(result.memory[statusAddress]).toBe(1);
    expect(result.memory[outputLength]).toBe(expected.length);
    expect(
      Array.from(result.memory.slice(outputBase, outputBase + expected.length)),
    ).toEqual(Array.from(expected));
  }, 15_000);

  it("prints strings and LF-terminated lines through the text module", async () => {
    const { parts, built, committed, nobj } = await compileEntry(
      [
        '//% import "console/output.nu"',
        "sub main() fails",
        'printString("ready") else fail',
        "printNewline() else fail",
        'printLine("go") else fail',
        "end",
        "",
      ].join("\n"),
      true,
      "mon3",
    );
    expect(parts.map((part) => part.name)).toEqual([
      "@nucleus/console/char.nu",
      "@nucleus/console/output.nu",
      "main.nu",
    ]);
    if (!built.success) throw new Error(JSON.stringify(built));
    expect(committed).toBe(true);
    expect(built.debugMapping?.semanticBytes).toBe(188);
    const result = execute(nobj);
    const expected = Buffer.from("ready\ngo\n", "ascii");
    expect(result.memory[statusAddress]).toBe(1);
    expect(result.memory[outputLength]).toBe(expected.length);
    expect(
      Array.from(result.memory.slice(outputBase, outputBase + expected.length)),
    ).toEqual(Array.from(expected));
  }, 15_000);

  it("discovers and formats the selective 8-bit output modules", async () => {
    const { parts, built, committed, nobj } = await compileEntry(
      [
        '//% import "console/i8.nu"',
        "sub main() fails",
        "printU8(255) else fail",
        "printI8(-128) else fail",
        "end",
        "",
      ].join("\n"),
    );
    expect(parts.map((part) => part.name)).toEqual([
      "@nucleus/console/char.nu",
      "@nucleus/console/u8.nu",
      "@nucleus/console/i8.nu",
      "main.nu",
    ]);
    if (!built.success) throw new Error(JSON.stringify(built));
    expect(committed).toBe(true);
    expect(built.debugMapping?.semanticBytes).toBe(263);
    const result = execute(nobj);
    const expected = Buffer.from("255-128", "ascii");
    expect(result.memory[statusAddress]).toBe(1);
    expect(result.memory[outputLength]).toBe(expected.length);
    expect(
      Array.from(result.memory.slice(outputBase, outputBase + expected.length)),
    ).toEqual(Array.from(expected));
  }, 15_000);

  it("formats both 16-bit signednesses, including the signed minimum", async () => {
    const { parts, built, committed, nobj } = await compileEntry(
      [
        '//% import "console/i16.nu"',
        "sub main() fails",
        "printU16(65535) else fail",
        "printI16(-32768) else fail",
        "end",
        "",
      ].join("\n"),
    );
    expect(parts.map((part) => part.name)).toEqual([
      "@nucleus/console/char.nu",
      "@nucleus/console/u16.nu",
      "@nucleus/console/i16.nu",
      "main.nu",
    ]);
    if (!built.success) throw new Error(JSON.stringify(built));
    expect(committed).toBe(true);
    expect(built.debugMapping?.semanticBytes).toBe(291);
    const result = execute(nobj);
    const expected = Buffer.from("65535-32768", "ascii");
    expect(result.memory[statusAddress]).toBe(1);
    expect(result.memory[outputLength]).toBe(expected.length);
    expect(
      Array.from(result.memory.slice(outputBase, outputBase + expected.length)),
    ).toEqual(Array.from(expected));
  }, 15_000);

  it("implements the settled LF, EOF, exact-fill, and drain behavior", async () => {
    const successBuild = await compileEntry(
      [
        '//% import "console/input.nu"',
        'var line as string[3] = ""',
        "sub main() fails",
        "var index as u8",
        "readLine(line) else fail",
        "writeOutputByte(line.length) else fail",
        "for index = 0 until line.length",
        "writeOutputByte(line[index]) else fail",
        "end",
        "end",
        "",
      ].join("\n"),
    );
    expect(successBuild.parts.map((part) => part.name)).toEqual([
      "@nucleus/console/input.nu",
      "main.nu",
    ]);
    if (!successBuild.built.success) {
      throw new Error(JSON.stringify(successBuild.built));
    }
    expect(successBuild.built.debugMapping?.semanticBytes).toBe(341);
    expect(successBuild.committed).toBe(true);
    const successes = [
      { input: [10], output: [0], consumed: 1 },
      { input: [65], output: [1, 65], consumed: 1 },
      { input: [65, 0, 66, 10], output: [3, 65, 0, 66], consumed: 4 },
    ] as const;
    for (const sample of successes) {
      const result = execute(successBuild.nobj, sample.input);
      expect(result.memory[statusAddress]).toBe(1);
      expect(result.memory[outputLength]).toBe(sample.output.length);
      expect(
        Array.from(
          result.memory.slice(outputBase, outputBase + sample.output.length),
        ),
      ).toEqual(sample.output);
      expect(result.memory[inputCursor]).toBe(sample.consumed);
    }

    const failureBuild = await compileEntry(
      [
        '//% import "console/input.nu"',
        'var line as string[3] = ""',
        "sub main() fails",
        "var code as u8",
        "readLine(line) handle code",
        "writeOutputByte(code) else fail",
        "return",
        "end",
        "writeOutputByte(0) else fail",
        "end",
        "",
      ].join("\n"),
    );
    if (!failureBuild.built.success) {
      throw new Error(JSON.stringify(failureBuild.built));
    }
    expect(failureBuild.committed).toBe(true);
    const failures = [
      { input: [], error: 1, consumed: 0 },
      { input: [65, 66, 67, 68, 69, 10], error: 5, consumed: 6 },
      { input: [65, 66, 67, 68, 69], error: 5, consumed: 5 },
    ] as const;
    for (const sample of failures) {
      const result = execute(failureBuild.nobj, sample.input);
      expect(result.memory[statusAddress]).toBe(1);
      expect(result.memory[outputLength]).toBe(1);
      expect(result.memory[outputBase]).toBe(sample.error);
      expect(result.memory[inputCursor]).toBe(sample.consumed);
    }
  }, 30_000);
});
