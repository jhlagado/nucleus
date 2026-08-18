import { readFileSync } from "node:fs";

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

describe("language tour", () => {
  it("executes the documented beginner program", async () => {
    const source = readFileSync(
      new URL("../examples/language-tour.nu", import.meta.url),
      "utf8",
    );
    const built = await compileNucleus(
      [{ name: "language-tour.nu", source }],
      { services },
    );
    if (!built.success) throw new Error(JSON.stringify(built));

    const executed = execute(built);
    expect(executed.memory[statusAddress]).toBe(1);
    expect(executed.memory[outputLength]).toBe(3);
    expect(
      new TextDecoder().decode(executed.memory.slice(outputBase, outputBase + 3)),
    ).toBe("OK!");

    const gridBase = built.materialized.parsed.map.bssBase - 12;
    expect(executed.memory[gridBase + 2]).toBe(19);
    expect(executed.memory[gridBase + 6]).toBe(40);
    expect(executed.memory[gridBase + 10]).toBe(61);
    expect(executed.memory[built.materialized.parsed.map.bssBase]).toBe(1);
  });
});
