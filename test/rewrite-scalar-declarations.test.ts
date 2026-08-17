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
    path.join(rewriteDirectory, "r3-scalar-declarations-proof.asm"),
    { emitHex: true, emitD8m: true, registerContracts: "strict" },
  );
  expect(
    result.diagnostics.filter(({ severity }) => severity === "error"),
  ).toEqual([]);
  const hex = result.artifacts.find((artifact) => artifact.kind === "hex");
  const d8m = result.artifacts.find((artifact) => artifact.kind === "d8m");
  if (hex?.kind !== "hex" || d8m?.kind !== "d8m") {
    throw new Error("AZM omitted R3 scalar-declaration proof artifacts");
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

describe("ground-up rewrite generated scalar declarations", () => {
  it.each([
    ["ProofScalarDeclarations", 0xc6],
    ["ProofScalarDeclarationDiagnostics", 0xc7],
    ["ProofProgramVariables", 0xc8],
    ["ProofProgramVariableDiagnostics", 0xc9],
  ] as const)("executes %s", (entry, expected) => {
    const result = run(entry);
    expect(
      result.status,
      `${entry} case ${result.proofCase}, diagnostic ${result.diagnosticCode}@${result.diagnosticOffset}`,
    ).toBe(expected);
  });

  it("locks the generated programs, declaration code, and execution cost", () => {
    const accepted = run("ProofScalarDeclarations");
    const diagnostics = run("ProofScalarDeclarationDiagnostics");
    expect({
      instructions: accepted.instructions,
      cycles: accepted.cycles,
    }).toEqual({ instructions: 21_626, cycles: 197_193 });
    expect({
      cases: diagnostics.proofCase,
      instructions: diagnostics.instructions,
      cycles: diagnostics.cycles,
    }).toEqual({ cases: 5, instructions: 16_946, cycles: 165_730 });
    const programs = run("ProofProgramVariables");
    const programDiagnostics = run("ProofProgramVariableDiagnostics");
    expect({
      instructions: programs.instructions,
      cycles: programs.cycles,
    }).toEqual({ instructions: 35_102, cycles: 324_986 });
    expect({
      cases: programDiagnostics.proofCase,
      instructions: programDiagnostics.instructions,
      cycles: programDiagnostics.cycles,
    }).toEqual({ cases: 7, instructions: 28_686, cycles: 276_397 });
    expect({
      actions:
        (image.symbols.RewriteActionCodeEnd ?? 0) -
        (image.symbols.RewriteActionCodeStart ?? 0),
      declarations:
        (image.symbols.RewriteFrontDeclarationCodeEnd ?? 0) -
        (image.symbols.RewriteFrontDeclarationCodeStart ?? 0),
      actionData:
        (image.symbols.RewriteActionImmutableEnd ?? 0) -
        (image.symbols.RewriteActionImmutableStart ?? 0),
      core:
        (image.symbols.RewriteCompilerCoreEnd ?? 0) -
        (image.symbols.RewriteCompilerCodeStart ?? 0),
      workspace:
        (image.symbols.RewriteWorkspaceEnd ?? 0) -
        (image.symbols.RewriteStateBase ?? 0),
    }).toEqual({
      actions: 230,
      declarations: 1_528,
      actionData: 240,
      core: 17_676,
      workspace: 3_938,
    });
  });
});
