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
    path.join(rewriteDirectory, "r3-static-storage-proof.asm"),
    { emitHex: true, emitD8m: true, registerContracts: "strict" },
  );
  expect(
    result.diagnostics.filter(({ severity }) => severity === "error"),
  ).toEqual([]);
  const hex = result.artifacts.find((artifact) => artifact.kind === "hex");
  const d8m = result.artifacts.find((artifact) => artifact.kind === "d8m");
  if (hex?.kind !== "hex" || d8m?.kind !== "d8m") {
    throw new Error("AZM omitted R3 static-storage proof artifacts");
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
}, 60_000);

const run = (entryName: string): number => {
  const parsed = parseIntelHex(image.hex);
  const entry = image.symbols[entryName];
  if (entry === undefined) throw new Error(`missing ${entryName}`);
  const runtime = createZ80Runtime(
    { ...parsed, memory: parsed.memory.slice(), startAddress: entry },
    entry,
  );
  let instructions = 0;
  while (!runtime.isHalted() && instructions < 500_000) {
    runtime.step();
    instructions += 1;
  }
  expect(runtime.isHalted(), entryName).toBe(true);
  return runtime.hardware.memory[image.symbols.ProofStatus ?? -1] ?? 0;
};

describe("ground-up rewrite static storage", () => {
  it.each([
    ["ProofStaticOrdering", 0xe1],
    ["ProofStaticProgramOverflow", 0xe2],
    ["ProofStaticReadOnlyOverflow", 0xe3],
    ["ProofStaticBssOverflow", 0xe4],
    ["ProofInitializerOverflow", 0xe5],
    ["ProofStaticZeroLength", 0xe6],
    ["ProofInitializerResetReuse", 0xe7],
    ["ProofStaticSymbolSegments", 0xe8],
  ] as const)("executes %s", (entry, expected) => {
    expect(run(entry)).toBe(expected);
  });

  it("locks the independent static accounts", () => {
    expect({
      initializerCapacity: image.symbols.RewriteInitializerCapacity,
      staticCapacity: image.symbols.RewriteStaticImageCapacity,
      symbolEntrySize: image.symbols.RewriteSymbolEntrySize,
      workspace:
        (image.symbols.RewriteWorkspaceEnd ?? 0) -
        (image.symbols.RewriteStateBase ?? 0),
    }).toEqual({
      initializerCapacity: 1_024,
      staticCapacity: 1_024,
      symbolEntrySize: 8,
      workspace: 3_935,
    });
  });
});
