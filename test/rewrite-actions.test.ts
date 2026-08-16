import path from "node:path";

import { compile } from "@jhlagado/azm/compile";
import { createZ80Runtime, parseIntelHex } from "@jhlagado/debug80-runtime";
import { beforeAll, describe, expect, it } from "vitest";

import {
  decodeRewriteActionProgram,
  rewriteActionEscapes,
  rewriteActionInstructions,
} from "../src/rewrite-actions-internal.js";

const rewriteDirectory = path.resolve(import.meta.dirname, "../asm/rewrite");

interface Image {
  readonly hex: string;
  readonly symbols: Readonly<Record<string, number>>;
}

let image: Image;

beforeAll(async () => {
  const result = await compile(
    path.join(rewriteDirectory, "r3-action-machine-proof.asm"),
    { emitHex: true, emitD8m: true, registerContracts: "strict" },
  );
  expect(
    result.diagnostics.filter(({ severity }) => severity === "error"),
  ).toEqual([]);
  const hex = result.artifacts.find((artifact) => artifact.kind === "hex");
  const d8m = result.artifacts.find((artifact) => artifact.kind === "d8m");
  if (hex?.kind !== "hex" || d8m?.kind !== "d8m") {
    throw new Error("AZM omitted R3 action-machine proof artifacts");
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
}, 15_000);

const run = (entryName: string): number => {
  const parsed = parseIntelHex(image.hex);
  const entry = image.symbols[entryName];
  if (entry === undefined) throw new Error(`missing ${entryName}`);
  const runtime = createZ80Runtime(
    { ...parsed, memory: parsed.memory.slice(), startAddress: entry },
    entry,
  );
  let instructions = 0;
  while (!runtime.isHalted() && instructions < 100_000) {
    runtime.step();
    instructions += 1;
  }
  expect(runtime.isHalted(), entryName).toBe(true);
  return runtime.hardware.memory[image.symbols.ProofStatus ?? -1] ?? 0;
};

describe("ground-up rewrite front action machine", () => {
  it.each([
    ["ProofActionProgram", 0xf1],
    ["ProofActionMismatch", 0xf2],
    ["ProofActionInvalid", 0xf3],
  ] as const)("executes %s", (entry, expected) => {
    expect(run(entry)).toBe(expected);
  });

  it("publishes one generated instruction and escape authority", () => {
    expect(
      rewriteActionInstructions.map(({ name, width }) => [name, width]),
    ).toEqual([
      ["End", 1],
      ["Expect", 3],
      ["Escape", 2],
      ["Raise", 2],
    ]);
    expect(rewriteActionEscapes).toEqual([
      { name: "ResetInitializer", target: "RewriteInitializerReset", id: 0 },
    ]);
    expect(image.symbols.RewriteActionEscapeDispatch).toBeDefined();
    expect({
      code:
        (image.symbols.RewriteActionCodeEnd ?? 0) -
        (image.symbols.RewriteActionCodeStart ?? 0),
      immutable:
        (image.symbols.RewriteActionImmutableEnd ?? 0) -
        (image.symbols.RewriteActionImmutableStart ?? 0),
      core:
        (image.symbols.RewriteCompilerCoreEnd ?? 0) -
        (image.symbols.RewriteCompilerCodeStart ?? 0),
      workspace:
        (image.symbols.RewriteWorkspaceEnd ?? 0) -
        (image.symbols.RewriteStateBase ?? 0),
    }).toEqual({ code: 117, immutable: 4, core: 5_545, workspace: 3_363 });
  });

  it("decodes exact boundaries and rejects malformed programs", () => {
    expect(
      decodeRewriteActionProgram(new Uint8Array([1, 32, 37, 2, 0, 0])),
    ).toEqual([0, 3, 5]);
    expect(() => decodeRewriteActionProgram(new Uint8Array([4]))).toThrow();
    expect(() =>
      decodeRewriteActionProgram(new Uint8Array([2, 1, 0])),
    ).toThrow();
    expect(() => decodeRewriteActionProgram(new Uint8Array([1, 32]))).toThrow();
    expect(() => decodeRewriteActionProgram(new Uint8Array([3, 37]))).toThrow();
    expect(() => decodeRewriteActionProgram(new Uint8Array([0, 0]))).toThrow();
  });
});
