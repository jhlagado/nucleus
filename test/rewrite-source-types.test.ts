import path from "node:path";

import { compile } from "@jhlagado/azm/compile";
import { createZ80Runtime, parseIntelHex } from "@jhlagado/debug80-runtime";
import { beforeAll, describe, expect, it } from "vitest";

const rewriteDirectory = path.resolve(import.meta.dirname, "../asm/rewrite");

interface Image {
  readonly hex: string;
  readonly symbols: Readonly<Record<string, number>>;
}

let image: Image;

beforeAll(async () => {
  const result = await compile(
    path.join(rewriteDirectory, "r3-source-types-proof.asm"),
    { emitHex: true, emitD8m: true, registerContracts: "strict" },
  );
  expect(
    result.diagnostics.filter(({ severity }) => severity === "error"),
  ).toEqual([]);
  const hex = result.artifacts.find((artifact) => artifact.kind === "hex");
  const d8m = result.artifacts.find((artifact) => artifact.kind === "d8m");
  if (hex?.kind !== "hex" || d8m?.kind !== "d8m") {
    throw new Error("AZM omitted R3 source-type proof artifacts");
  }
  image = {
    hex: hex.text,
    symbols: Object.fromEntries(
      d8m.json.symbols.flatMap((entry) => {
        const value = entry.address ?? entry.value;
        return value === undefined ? [] : [[entry.name, value]];
      }),
    ),
  };
});

const run = (entryName: string) => {
  const parsed = parseIntelHex(image.hex);
  const entry = image.symbols[entryName];
  if (entry === undefined) throw new Error(`missing ${entryName}`);
  const runtime = createZ80Runtime(
    { ...parsed, memory: parsed.memory.slice(), startAddress: entry },
    entry,
  );
  let instructions = 0;
  let cycles = 0;
  while (!runtime.isHalted() && instructions < 2_000_000) {
    const step = runtime.step();
    instructions += 1;
    cycles += step.cycles ?? 0;
  }
  expect(runtime.isHalted(), entryName).toBe(true);
  return {
    status: runtime.hardware.memory[image.symbols.ProofStatus ?? -1] ?? 0,
    proofCase: runtime.hardware.memory[image.symbols.ProofCase ?? -1] ?? 0,
    diagnosticCode:
      runtime.hardware.memory[image.symbols.DiagnosticCode ?? -1] ?? 0,
    diagnosticOffset:
      (runtime.hardware.memory[image.symbols.DiagnosticOffset ?? -1] ?? 0) |
      ((runtime.hardware.memory[(image.symbols.DiagnosticOffset ?? -1) + 1] ??
        0) <<
        8),
    instructions,
    cycles,
  };
};

describe("ground-up rewrite source-type parser", () => {
  it.each([
    ["ProofSourceTypes", 0xc3],
    ["ProofSourceTypeDiagnostics", 0xc4],
    ["ProofSourceTypeCapacity", 0xc5],
  ] as const)("executes %s", (entry, expected) => {
    const result = run(entry);
    expect(
      result.status,
      `${entry} case ${result.proofCase}, diagnostic ${result.diagnosticCode}@${result.diagnosticOffset}`,
    ).toBe(expected);
  });

  it("locks the type grammar, exact capacity accounts, and execution cost", () => {
    const accepted = run("ProofSourceTypes");
    const diagnostics = run("ProofSourceTypeDiagnostics");
    const capacity = run("ProofSourceTypeCapacity");
    expect({
      cases: accepted.proofCase,
      instructions: accepted.instructions,
      cycles: accepted.cycles,
    }).toEqual({ cases: 17, instructions: 35_188, cycles: 319_406 });
    expect({
      cases: diagnostics.proofCase,
      instructions: diagnostics.instructions,
      cycles: diagnostics.cycles,
    }).toEqual({ cases: 20, instructions: 45_373, cycles: 434_041 });
    expect({
      cases: capacity.proofCase,
      instructions: capacity.instructions,
      cycles: capacity.cycles,
    }).toEqual({ cases: 9, instructions: 23_471, cycles: 211_469 });
    expect({
      parser:
        (image.symbols.RewriteSourceTypeCodeEnd ?? 0) -
        (image.symbols.RewriteSourceTypeCodeStart ?? 0),
      ownedTypes: image.symbols.RewriteOwnedTypeCapacity,
      suffixes: image.symbols.RewriteSuffixCapacity,
      core:
        (image.symbols.RewriteCompilerCoreEnd ?? 0) -
        (image.symbols.RewriteCompilerCodeStart ?? 0),
      workspace:
        (image.symbols.RewriteWorkspaceEnd ?? 0) -
        (image.symbols.RewriteStateBase ?? 0),
    }).toEqual({
      parser: 496,
      ownedTypes: 8,
      suffixes: 4,
      core: 6_041,
      workspace: 3_364,
    });
  });
});
