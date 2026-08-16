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
    path.join(rewriteDirectory, "r3-directories-proof.asm"),
    { emitHex: true, emitD8m: true, registerContracts: "strict" },
  );
  expect(
    result.diagnostics.filter(({ severity }) => severity === "error"),
  ).toEqual([]);
  const hex = result.artifacts.find((artifact) => artifact.kind === "hex");
  const d8m = result.artifacts.find((artifact) => artifact.kind === "d8m");
  if (hex?.kind !== "hex" || d8m?.kind !== "d8m") {
    throw new Error("AZM omitted R3 directory proof artifacts");
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
  while (!runtime.isHalted() && instructions < 200_000) {
    runtime.step();
    instructions += 1;
  }
  expect(runtime.isHalted(), entryName).toBe(true);
  return runtime.hardware.memory[image.symbols.ProofStatus ?? -1];
};

describe("ground-up rewrite declaration directories", () => {
  it.each([
    ["ProofRecordsFields", 0xc1],
    ["ProofFieldDuplicate", 0xc2],
    ["ProofFieldCapacity", 0xc3],
    ["ProofRecordCapacity", 0xc3],
    ["ProofRecordEmpty", 0xca],
    ["ProofRoutinesParameters", 0xc5],
    ["ProofRoutineDuplicate", 0xc2],
    ["ProofRoutineCapacity", 0xc6],
    ["ProofRoutineDuplicateAtCapacity", 0xc6],
    ["ProofParameterCapacity", 0xc7],
    ["ProofParameterDuplicateAtCapacity", 0xc2],
    ["ProofSuffixes", 0xc3],
    ["ProofSuffixOpenShape", 0xc9],
    ["ProofSuffixConcreteThenOpen", 0xcb],
  ] as const)("executes %s", (entry, expected) => {
    expect(run(entry)).toBe(expected);
  });

  it("locks every independent directory account", () => {
    const symbols = image.symbols;
    expect({
      records: symbols.RewriteRecordCapacity,
      recordWidth: symbols.RewriteRecordEntrySize,
      fields: symbols.RewriteFieldCapacity,
      fieldWidth: symbols.RewriteFieldEntrySize,
      routines: symbols.RewriteRoutineCapacity,
      routineWidth: symbols.RewriteRoutineEntrySize,
      parameters: symbols.RewriteParameterCapacity,
      parameterWidth: symbols.RewriteParameterEntrySize,
      suffixes: symbols.RewriteSuffixCapacity,
      suffixWidth: symbols.RewriteSuffixEntrySize,
      workspace:
        (symbols.RewriteWorkspaceEnd ?? 0) - (symbols.RewriteStateBase ?? 0),
    }).toEqual({
      records: 5,
      recordWidth: 2,
      fields: 12,
      fieldWidth: 6,
      routines: 4,
      routineWidth: 8,
      parameters: 16,
      parameterWidth: 4,
      suffixes: 4,
      suffixWidth: 4,
      workspace: 3_425,
    });
  });
});
