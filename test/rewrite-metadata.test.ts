import path from "node:path";

import { compile } from "@jhlagado/azm/compile";
import { createZ80Runtime, parseIntelHex } from "@jhlagado/debug80-runtime";
import { beforeAll, describe, expect, it } from "vitest";

const rewriteDirectory = path.resolve(import.meta.dirname, "../asm/rewrite");

interface AssembledImage {
  readonly hex: string;
  readonly symbols: Readonly<Record<string, number>>;
}

let image: AssembledImage;

beforeAll(async () => {
  const source = path.join(rewriteDirectory, "r3-metadata-proof.asm");
  const result = await compile(source, {
    emitHex: true,
    emitD8m: true,
    registerContracts: "strict",
  });
  expect(
    result.diagnostics.filter(({ severity }) => severity === "error"),
  ).toEqual([]);
  const hex = result.artifacts.find((artifact) => artifact.kind === "hex");
  const d8m = result.artifacts.find((artifact) => artifact.kind === "d8m");
  if (hex?.kind !== "hex" || d8m?.kind !== "d8m") {
    throw new Error("AZM omitted R3 metadata proof artifacts");
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
  while (!runtime.isHalted() && instructions < 100_000) {
    runtime.step();
    instructions += 1;
  }
  expect(runtime.isHalted(), entryName).toBe(true);
  return {
    memory: runtime.hardware.memory,
    instructions,
    status: runtime.hardware.memory[image.symbols.ProofStatus ?? -1],
  };
};

describe("ground-up rewrite type and symbol substrate", () => {
  it.each([
    ["ProofTypeMetadata", 0xb1],
    ["ProofTypeCapacity", 0xb2],
    ["ProofSymbols", 0xb3],
    ["ProofSymbolDuplicate", 0xb4],
    ["ProofSymbolCapacity", 0xb5],
  ] as const)("executes %s", (entry, expected) => {
    expect(run(entry).status).toBe(expected);
  });

  it("keeps complete pointers and exact bounded table accounts", () => {
    const symbols = image.symbols;
    expect(symbols.ProofNameAlpha).toBe(0x9000);
    expect(symbols.RewriteTypeDescriptorSize).toBe(4);
    expect(symbols.RewriteOwnedTypeCapacity).toBe(8);
    expect(symbols.RewriteSymbolEntrySize).toBe(8);
    expect(symbols.RewriteSymbolCapacity).toBe(16);
    expect(
      (symbols.RewriteMetadataCodeEnd ?? 0) -
        (symbols.RewriteMetadataCodeStart ?? 0),
    ).toBe(10_753);
    expect({
      code:
        (symbols.RewriteCompilerCodeEnd ?? 0) -
        (symbols.RewriteCompilerCodeStart ?? 0),
      immutable:
        (symbols.RewriteCompilerImmutableEnd ?? 0) -
        (symbols.RewriteCompilerImmutableStart ?? 0),
      core:
        (symbols.RewriteCompilerCoreEnd ?? 0) -
        (symbols.RewriteCompilerCodeStart ?? 0),
      workspace:
        (symbols.RewriteWorkspaceEnd ?? 0) - (symbols.RewriteStateBase ?? 0),
    }).toEqual({ code: 15_577, immutable: 2_202, core: 17_779, workspace: 3_425 });
  });
});
