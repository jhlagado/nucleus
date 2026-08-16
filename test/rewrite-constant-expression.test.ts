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
    path.join(rewriteDirectory, "r3-constant-expression-proof.asm"),
    { emitHex: true, emitD8m: true, registerContracts: "strict" },
  );
  expect(
    result.diagnostics.filter(({ severity }) => severity === "error"),
  ).toEqual([]);
  const hex = result.artifacts.find((artifact) => artifact.kind === "hex");
  const d8m = result.artifacts.find((artifact) => artifact.kind === "d8m");
  if (hex?.kind !== "hex" || d8m?.kind !== "d8m") {
    throw new Error("AZM omitted R3 constant-expression proof artifacts");
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
}, 30_000);

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
    actualMeta:
      runtime.hardware.memory[image.symbols.ProofActualMeta ?? -1] ?? 0,
    actualValue:
      (runtime.hardware.memory[image.symbols.ProofActualValue ?? -1] ?? 0) |
      ((runtime.hardware.memory[(image.symbols.ProofActualValue ?? -1) + 1] ??
        0) <<
        8),
    actualToken:
      runtime.hardware.memory[image.symbols.ProofActualToken ?? -1] ?? 0,
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

describe("ground-up rewrite constant-expression engine", () => {
  it.each([
    ["ProofExpressionValues", 0xc1],
    ["ProofExpressionDiagnostics", 0xc2],
  ] as const)("executes %s", (entry, expected) => {
    const result = run(entry);
    expect(
      result.status,
      `${entry} case ${result.proofCase}, meta ${result.actualMeta}, value ${result.actualValue}, token ${result.actualToken}, diagnostic ${result.diagnosticCode}@${result.diagnosticOffset}`,
    ).toBe(expected);
  });

  it("locks the expression accounts, full corpus, and strict execution cost", () => {
    const values = run("ProofExpressionValues");
    const diagnostics = run("ProofExpressionDiagnostics");
    expect({
      cases: values.proofCase,
      instructions: values.instructions,
      cycles: values.cycles,
    }).toEqual({ cases: 39, instructions: 379_501, cycles: 3_464_576 });
    expect({
      cases: diagnostics.proofCase,
      instructions: diagnostics.instructions,
      cycles: diagnostics.cycles,
    }).toEqual({ cases: 19, instructions: 40_253, cycles: 422_651 });
    expect({
      code:
        (image.symbols.RewriteExpressionCodeEnd ?? 0) -
        (image.symbols.RewriteExpressionCodeStart ?? 0),
      immutable:
        (image.symbols.RewriteExpressionImmutableEnd ?? 0) -
        (image.symbols.RewriteExpressionImmutableStart ?? 0),
      pendingCapacity: image.symbols.RewriteExpressionDepthCapacity,
      core:
        (image.symbols.RewriteCompilerCoreEnd ?? 0) -
        (image.symbols.RewriteCompilerCodeStart ?? 0),
      workspace:
        (image.symbols.RewriteWorkspaceEnd ?? 0) -
        (image.symbols.RewriteStateBase ?? 0),
    }).toEqual({
      code: 4_356,
      immutable: 48,
      pendingCapacity: 16,
      core: 16_510,
      workspace: 3_425,
    });
  });
});
