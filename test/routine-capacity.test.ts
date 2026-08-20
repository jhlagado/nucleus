import { describe, expect, it } from "vitest";

import {
  compileNucleus,
  defaultNucleusServices,
  type NucleusCompileSuccess,
} from "../src/compiler.js";
import { executeCommittedNobj } from "../src/proof.js";

const statusAddress = 0x7200;
const services = {
  ...defaultNucleusServices,
  success: 0x7180,
  unhandledFailure: 0x7188,
  trap: 0x7190,
  farCall: 0x7000,
  farJump: 0x7080,
};

const terminal = (status: number): readonly number[] => [
  0x3e,
  status,
  0x32,
  statusAddress & 0xff,
  statusAddress >>> 8,
  0x76,
];

// Proof-only one-level far-call adapter. The production ABI supplies A=bank
// and HL=target. Port $7F selects the visible bank in the proof runner.
const farCallService: readonly number[] = [
  0x32, 0x40, 0x70, 0x22, 0x42, 0x70, 0xe1, 0x22, 0x44, 0x70, 0x3a, 0x46, 0x70,
  0x32, 0x47, 0x70, 0x3a, 0x40, 0x70, 0x32, 0x46, 0x70, 0xd3, 0x7f, 0x21, 0x20,
  0x70, 0xe5, 0x2a, 0x42, 0x70, 0xe9, 0xf5, 0x3a, 0x47, 0x70, 0x32, 0x46, 0x70,
  0xd3, 0x7f, 0xf1, 0xed, 0x5b, 0x44, 0x70, 0xd5, 0xc9,
];

const routineSource = Array.from({ length: 16 }, (_, index) =>
  [`sub r${index}() as u8`, `return ${index + 1}`, "end"].join("\n"),
).join("\n");

const execute = (built: NucleusCompileSuccess, banked = false) =>
  executeCommittedNobj(
    built.nobj,
    {
      maxInstructions: 40_000,
      maxCycles: 400_000,
      halted: true,
      initialSp: 0x6ff0,
      expectedSp: 0x6ff0,
      expectedIx: 0,
      writes: [
        ...(banked ? [{ at: services.farCall, bytes: farCallService }] : []),
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

describe("expanded source-routine capacity", () => {
  it("resolves main label 31 and local routine labels 32, 43, and 47", async () => {
    const source = [
      "var observed as u8",
      routineSource,
      "sub main()",
      "observed = r0() + r11() + r15()",
      "end",
      "",
    ].join("\n");
    const built = await compileNucleus([{ name: "main.nu", source }], {
      services,
    });
    if (!built.success) throw new Error(JSON.stringify(built));
    const executed = execute(built);
    expect(executed.memory[statusAddress]).toBe(1);
    expect(executed.memory[built.materialized.parsed.map.bssBase]).toBe(29);
  });

  it("preserves full labels 43 and 47 in cross-bank source-call fixups", async () => {
    const parts = [
      { name: "library.nu", source: `${routineSource}\n` },
      {
        name: "main.nu",
        source: [
          "var observed as u8",
          "sub main()",
          "observed = r11() + r15()",
          "end",
          "",
        ].join("\n"),
      },
    ] as const;
    const built = await compileNucleus(parts, {
      bankCount: 2,
      entryBank: 0,
      partBanks: [1, 0],
      services,
    });
    if (!built.success) throw new Error(JSON.stringify(built));
    const executed = execute(built, true);
    expect(executed.memory[statusAddress]).toBe(1);
    expect(executed.memory[built.materialized.parsed.map.bssBase]).toBe(28);
    expect(executed.selectedBank).toBe(0);
  });

  it("accepts exactly twenty-six retained parameters", async () => {
    const routines = Array.from({ length: 13 }, (_, index) =>
      [`sub p${index}(x as u8, y as u8)`, "end"].join("\n"),
    ).join("\n");
    const built = await compileNucleus([
      {
        name: "parameters.nu",
        source: `${routines}\nsub main()\nend\n`,
      },
    ]);
    expect(built.success).toBe(true);
  });
});
