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
    path.join(rewriteDirectory, "r3-aggregate-initializers-proof.asm"),
    { emitHex: true, emitD8m: true, registerContracts: "strict" },
  );
  expect(
    result.diagnostics.filter(({ severity }) => severity === "error"),
  ).toEqual([]);
  const hex = result.artifacts.find((artifact) => artifact.kind === "hex");
  const d8m = result.artifacts.find((artifact) => artifact.kind === "d8m");
  if (hex?.kind !== "hex" || d8m?.kind !== "d8m") {
    throw new Error("AZM omitted R3 aggregate-initializer proof artifacts");
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
}, 300_000);

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
  while (!runtime.isHalted() && instructions < 500_000) {
    const step = runtime.step();
    cycles += step.cycles ?? 0;
    instructions += 1;
  }
  expect(runtime.isHalted(), entryName).toBe(true);
  const memory = runtime.hardware.memory;
  const diagnosticOffset = image.symbols.DiagnosticOffset ?? -1;
  return {
    status: memory[image.symbols.ProofStatus ?? -1],
    diagnostic: memory[image.symbols.DiagnosticCode ?? -1],
    part: memory[image.symbols.DiagnosticPartId ?? -1],
    offset: memory[diagnosticOffset] | (memory[diagnosticOffset + 1] << 8),
    instructions,
    cycles,
  };
};

describe("ground-up rewrite recursive aggregate initializers", () => {
  it("constructs nested records, arrays, strings, and both static segments", () => {
    const executed = run("ProofAggregateInitializers");
    expect(executed).toMatchObject({ status: 0xe0, diagnostic: 0 });
    expect({
      instructions: executed.instructions,
      cycles: executed.cycles,
    }).toEqual({ instructions: 40_791, cycles: 372_970 });
  });

  it.each([
    ["ProofInitializerShapeDiagnostic", 0xe1, 78, 19],
    ["ProofInitializerCountDiagnostic", 0xe2, 79, 21],
    ["ProofInitializerStringDiagnostic", 0xe3, 80, 23],
    ["ProofInitializerDepthDiagnostic", 0xe4, 77, 130],
    ["ProofInitializerScalarConstantDiagnostic", 0xe5, 60, 14],
  ] as const)(
    "preserves the frozen diagnostic at %s",
    (entry, status, diagnostic, offset) => {
      expect(run(entry)).toMatchObject({
        status,
        diagnostic,
        part: 1,
        offset,
      });
    },
  );

  it.each([
    ["ProofInitializerProgramPreflightDiagnostic", 0xe6, 81],
    ["ProofInitializerReadOnlyPreflightDiagnostic", 0xe7, 93],
  ] as const)(
    "preflights the complete destination before malformed input in %s",
    (entry, status, diagnostic) => {
      expect(run(entry)).toMatchObject({ status, diagnostic, part: 1 });
    },
  );

  it("locks the generated programs and exact replacement accounts", () => {
    expect({
      escapes: image.symbols.RewriteActionEscapeCount,
      actionCode:
        (image.symbols.RewriteActionCodeEnd ?? 0) -
        (image.symbols.RewriteActionCodeStart ?? 0),
      actionData:
        (image.symbols.RewriteActionImmutableEnd ?? 0) -
        (image.symbols.RewriteActionImmutableStart ?? 0),
      code:
        (image.symbols.RewriteCompilerCodeEnd ?? 0) -
        (image.symbols.RewriteCompilerCodeStart ?? 0),
      immutable:
        (image.symbols.RewriteCompilerImmutableEnd ?? 0) -
        (image.symbols.RewriteCompilerImmutableStart ?? 0),
      core:
        (image.symbols.RewriteCompilerCoreEnd ?? 0) -
        (image.symbols.RewriteCompilerCodeStart ?? 0),
      workspace:
        (image.symbols.RewriteWorkspaceEnd ?? 0) -
        (image.symbols.RewriteStateBase ?? 0),
    }).toEqual({
      escapes: 56,
      actionCode: 230,
      actionData: 240,
      code: 16_105,
      immutable: 1_508,
      core: 17_613,
      workspace: 3_938,
    });
  });
});
