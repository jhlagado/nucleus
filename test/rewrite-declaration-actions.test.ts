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
    path.join(rewriteDirectory, "r3-declaration-actions-proof.asm"),
    { emitHex: true, emitD8m: true, registerContracts: "strict" },
  );
  expect(
    result.diagnostics.filter(({ severity }) => severity === "error"),
  ).toEqual([]);
  const hex = result.artifacts.find((artifact) => artifact.kind === "hex");
  const d8m = result.artifacts.find((artifact) => artifact.kind === "d8m");
  if (hex?.kind !== "hex" || d8m?.kind !== "d8m") {
    throw new Error("AZM omitted R3 declaration-action proof artifacts");
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
  while (!runtime.isHalted() && instructions < 200_000) {
    runtime.step();
    instructions += 1;
  }
  expect(runtime.isHalted(), entryName).toBe(true);
  return runtime.hardware.memory[image.symbols.ProofStatus ?? -1];
};

describe("ground-up rewrite declaration actions", () => {
  it.each([
    ["ProofForwardLifecycle", 0xd1],
    ["ProofForwardGlobalCollision", 0xd4],
    ["ProofForwardMissing", 0xd5],
    ["ProofForwardAlreadyComplete", 0xd4],
    ["ProofForwardIncomplete", 0xd6],
    ["ProofMissingMain", 0xdd],
    ["ProofForwardWithoutMain", 0xdd],
    ["ProofOrdinaryAndForwardMainIncomplete", 0xd6],
    ["ProofMainOutsideRoutineCapacity", 0xd2],
    ["ProofMainDuplicate", 0xd4],
    ["ProofForwardMainLifecycle", 0xd7],
    ["ProofForwardMainIncomplete", 0xd6],
    ["ProofForwardMainMissing", 0xd5],
    ["ProofForwardMainRepeated", 0xd5],
    ["ProofRoutineActionCapacityPrecedence", 0xd8],
    ["ProofParameterRoutineCollision", 0xd4],
    ["ProofParameterRoutineCaseDistinct", 0xd9],
    ["ProofForwardMixedParameterLayout", 0xda],
    ["ProofMainLocalOffsetReset", 0xdb],
    ["ProofParameterHeaderIsolation", 0xdc],
    ["ProofParameterHeaderDuplicate", 0xd4],
    ["ProofDeclarationAfterMain", 0xde],
    ["ProofPredefinedParameter", 0xd4],
    ["ProofRoutineSharedCollision", 0xd4],
    ["ProofDirectPublishBeforeClose", 0xd3],
  ] as const)("executes %s", (entry, expected) => {
    expect(run(entry)).toBe(expected);
  });
});
