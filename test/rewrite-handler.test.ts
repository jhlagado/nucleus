import path from "node:path";

import { compile } from "@jhlagado/azm/compile";
import { createZ80Runtime, parseIntelHex } from "@jhlagado/debug80-runtime";
import { beforeAll, describe, expect, it } from "vitest";

const source = path.resolve(
  import.meta.dirname,
  "../asm/rewrite/r5-handler-proof.asm",
);

const assemble = async () => {
  const result = await compile(source, {
    emitHex: true,
    emitD8m: true,
    registerContracts: "strict",
  });
  expect(
    result.diagnostics.filter(({ severity }) => severity === "error"),
  ).toEqual([]);
  const hex = result.artifacts.find((artifact) => artifact.kind === "hex");
  expect(hex?.kind).toBe("hex");
  const d8m = result.artifacts.find((artifact) => artifact.kind === "d8m");
  if (hex?.kind !== "hex" || d8m?.kind !== "d8m") {
    throw new Error("missing handler proof artifacts");
  }
  return {
    image: parseIntelHex(hex.text),
    symbols: Object.fromEntries(
      d8m.json.symbols.flatMap((entry) => {
        const value = entry.address ?? entry.value;
        return value === undefined ? [] : [[entry.name, value]];
      }),
    ),
  };
};

type Assembled = Awaited<ReturnType<typeof assemble>>;

let assembled: Assembled;

beforeAll(async () => {
  assembled = await assemble();
}, 30_000);

const run = async (entryName: string) => {
  const { image, symbols } = assembled;
  const entry = symbols[entryName] ?? 0;
  const runtime = createZ80Runtime(
    { ...image, memory: image.memory.slice(), startAddress: entry },
    entry,
  );
  let instructions = 0;
  let cycles = 0;
  while (!runtime.isHalted() && instructions < 1_000_000) {
    const step = runtime.step();
    instructions += 1;
    cycles += step.cycles ?? 0;
  }
  return { runtime, symbols, instructions, cycles };
};

describe("ground-up rewrite local handlers", () => {
  it("publishes local, initialized-program, and BSS handler records", async () => {
    const { runtime, symbols, instructions, cycles } = await run("ProofHandlers");
    const memory = runtime.hardware.memory;
    expect({
      status: memory[symbols.ProofStatus ?? 0],
      depth: memory[symbols.RewriteControlDepth ?? 0],
      labels: memory[symbols.RewriteControlNextLabel ?? 0],
      pending: memory[symbols.RewritePendingFailure ?? 0],
      operations: memory[symbols.RewriteSemanticBufferBase ?? 0],
    }).toEqual({ status: 0xd0, depth: 0, labels: 6, pending: 0, operations: 16 });
    expect(runtime.isHalted()).toBe(true);
    const count = memory[symbols.RewriteSemanticBufferBase ?? 0];
    const start = symbols.RewriteSemanticPayloadBase ?? 0;
    const cursor = symbols.RewriteSemanticSinkCursor ?? 0;
    const end = memory[cursor] | (memory[cursor + 1] << 8);
    expect(count).toBe(16);
    expect(Array.from(memory.slice(start, end))).toMatchSnapshot();
    expect({ instructions, cycles }).toEqual({
      instructions: 50_329,
      cycles: 453_215,
    });
  });

  it.each([
    ["ProofHandlerUnknown", 0xd1, 57, 56],
    ["ProofHandlerWrongType", 0xd2, 60, 72],
    ["ProofHandlerConstant", 0xd3, 60, 71],
    ["ProofHandlerInfallible", 0xd4, 87, 52],
    ["ProofHandlerDoubleConsumer", 0xd5, 87, 74],
    ["ProofHandlerLocalInitializer", 0xd6, 87, 84],
    ["ProofHandlerActiveCounter", 0xd7, 36, 83],
    ["ProofHandlerMissingName", 0xd8, 130, 55],
  ] as const)(
    "rejects %s with exact frozen provenance",
    async (entry, status, diagnostic, offset) => {
      const { runtime, symbols } = await run(entry);
      const memory = runtime.hardware.memory;
      const diagnosticOffset = symbols.DiagnosticOffset ?? 0;
      expect({
        status: memory[symbols.ProofStatus ?? 0],
        diagnostic: memory[symbols.DiagnosticCode ?? 0],
        part: memory[symbols.DiagnosticPartId ?? 0],
        offset:
          memory[diagnosticOffset] | (memory[diagnosticOffset + 1] << 8),
      }).toEqual({ status, diagnostic, part: 1, offset });
    },
  );

  it("routes exit and continue through an intervening handler frame", async () => {
    const { runtime, symbols, instructions, cycles } = await run(
      "ProofHandlerLoopTransfers",
    );
    const memory = runtime.hardware.memory;
    expect({
      status: memory[symbols.ProofStatus ?? 0],
      depth: memory[symbols.RewriteControlDepth ?? 0],
      labels: memory[symbols.RewriteControlNextLabel ?? 0],
      operations: memory[symbols.RewriteSemanticBufferBase ?? 0],
      instructions,
      cycles,
    }).toEqual({
      status: 0xd9,
      depth: 0,
      labels: 6,
      operations: 15,
      instructions: 32_991,
      cycles: 295_034,
    });
  });
});
