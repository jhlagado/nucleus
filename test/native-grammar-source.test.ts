import { readFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { createZ80Runtime, parseIntelHex } from "@jhlagado/debug80-runtime";
import { beforeAll, describe, expect, it } from "vitest";
import { assembleNativeGrammarProof } from "../scripts/assemble-native-grammar.mjs";

// Captured by the previous ATOM path at 5764b04, before this wave's source edits.
const baseline = JSON.parse(readFileSync(new URL("./fixtures/native-grammar-baseline.json", import.meta.url), "utf8")) as {
  revision: string; hex: string; symbols: Record<string, number>;
  addresses: Record<string, number>; highWater: number; finalCursor: number;
  ranges: { start: number; end: number }[];
};
let fresh: Awaited<ReturnType<typeof assembleNativeGrammarProof>>;
beforeAll(async () => { fresh = await assembleNativeGrammarProof(); }, 30_000);

const covered = (ranges: readonly { start: number; end: number }[]) =>
  ranges.flatMap(({ start, end }) => Array.from({ length: end - start }, (_, i) => start + i));

describe("native Stage 7 engine and generated grammar", () => {
  it("preserves the frozen sparse bytes, every public key and address classification", () => {
    expect(baseline.revision).toBe("5764b04");
    expect(fresh.hex).toBe(baseline.hex);
    expect(covered(parseIntelHex(fresh.hex).writeRanges ?? [])).toEqual(covered(baseline.ranges));
    expect(Object.keys(fresh.symbols)).toHaveLength(949);
    expect(fresh.symbols).toEqual(baseline.symbols);
    expect(Object.keys(fresh.addresses)).toHaveLength(266);
    expect(fresh.addresses).toEqual(baseline.addresses);
    expect(fresh.generation.highWater).toBe(baseline.highWater);
    expect(fresh.generation.finalCursor).toBe(baseline.finalCursor);
    expect(fresh.symbols.HybridLL1EngineEnd! - fresh.symbols.HybridLL1Parse!).toBe(273);
    expect(fresh.symbols.HybridLL1TablesEnd! - fresh.symbols.HybridLL1RowDirectory!).toBe(933);
  });

  it("derives all 131 directory displacements from the actual labels", () => {
    const memory = parseIntelHex(fresh.hex).memory;
    const symbols = fresh.symbols;
    for (let row = 0; row < symbols.HybridLL1NonterminalCount!; row++) {
      const offset = symbols[`HybridLL1Row${row}`]! - symbols.HybridLL1Rows!;
      const high = row < symbols.HybridLL1HighRowStart! ? 0 : 256;
      expect(offset - high).toBeGreaterThanOrEqual(0);
      expect(offset - high).toBeLessThanOrEqual(255);
      expect(memory[symbols.HybridLL1RowDirectory! + 2 * row]).toBe(offset - high);
    }
    const split = symbols.HybridLL1ProductionSplit!;
    const count = symbols.HybridLL1ProductionCount!;
    for (let production = 0; production < count; production++) {
      const high = production >= split;
      const base = high ? symbols.HybridLL1ProductionsHigh! : symbols.HybridLL1Productions!;
      const directory = high ? symbols.HybridLL1ProductionDirectoryHigh! : symbols.HybridLL1ProductionDirectory!;
      expect(memory[directory + production - (high ? split : 0)])
        .toBe(symbols[`HybridLL1Production${production}`]! - base);
    }
    expect(memory[symbols.HybridLL1ProductionDirectory! + split])
      .toBe(symbols.HybridLL1ProductionsHigh! - symbols.HybridLL1Productions!);
    expect(memory[symbols.HybridLL1ProductionDirectoryHigh! + count - split])
      .toBe(symbols.HybridLL1ProductionsEnd! - symbols.HybridLL1ProductionsHigh!);

    const source = readFileSync(new URL("../grammar/stage7-tables.asmi", import.meta.url), "utf8");
    const equates = [...source.matchAll(/^(LLOF[A-Z0-9]+) EQU ([A-Z0-9]+)-([A-Z0-9]+)(-\$100)?$/gm)];
    expect(equates).toHaveLength(131);
    for (const [_, name] of equates) expect(fresh.symbols).not.toHaveProperty(name!);
  });

  it("executes the original capacity/failure proof and reaches its exact success halt", () => {
    const memory = parseIntelHex(fresh.hex).memory.slice();
    const symbols = fresh.symbols;
    const runtime = createZ80Runtime({ memory, startAddress: symbols.ProofStart! }, symbols.ProofStart!);
    let instructions = 0;
    while (!runtime.isHalted() && instructions++ < 100_000) runtime.step();
    expect(runtime.isHalted()).toBe(true);
    expect(runtime.cpu.pc).toBe(symbols.ProofFailure);
    expect(runtime.cpu.sp).toBe(symbols.StackTop);
    const observed = runtime.hardware.memory;
    expect(observed[symbols.ProofStatus!]).toBe(0xa5);
    expect(observed[symbols.DiagnosticCode!]).toBe(87);
    expect(observed[symbols.HybridLL1StackDepth!]).toBe(63);
    expect(observed[symbols.HybridLL1StackBase! + symbols.HybridLL1StackCapacity!]).toBe(0x5a);
  });

  it("keeps all native source bytes intact except official preprocessing masks", () => {
    expect(fresh.project.parts).toHaveLength(10);
    for (const part of fresh.project.parts) {
      expect(Buffer.from(part.originalBytes)).toEqual(readFileSync(
        new URL(`../${part.logicalIdentity}`, import.meta.url),
      ));
      const original = new TextDecoder().decode(part.originalBytes).split("\n");
      const compiled = new TextDecoder().decode(part.compilerBytes).split("\n");
      expect(compiled).toHaveLength(original.length);
      compiled.forEach((line, index) => {
        expect(line.length).toBe(original[index]!.length);
        if (line.trim()) expect(line).toBe(original[index]);
      });
      expect(part.originalBytes.length).toBeLessThanOrEqual(65535);
    }
  });

  it("runs the native helper and ordinary proof route with legacy assembly unavailable", () => {
    const refusal = "legacy grammar adapter unavailable";
    const sourceRoot = new URL("../src/", import.meta.url).href;
    const loader = `export async function resolve(specifier, context, nextResolve) {
      let resolved;
      try { resolved = await nextResolve(specifier, context); }
      catch (error) {
        // Execute the real TypeScript host sources in this isolated Node test.
        // Their published .js imports resolve to the corresponding source .ts.
        if (error.code !== "ERR_MODULE_NOT_FOUND" ||
            !context.parentURL?.startsWith(${JSON.stringify(sourceRoot)}) ||
            !specifier.endsWith(".js")) throw error;
        resolved = await nextResolve(specifier.slice(0, -3) + ".ts", context);
      }
      if (resolved.url.endsWith("/scripts/atom-source.mjs") ||
          resolved.url.endsWith("/scripts/atom-source-translation.mjs")) throw new Error(${JSON.stringify(refusal)});
      return resolved;
    }`;
    const legacy = new URL("../scripts/atom-source.mjs", import.meta.url).href;
    const helper = new URL("../scripts/assemble-native-grammar.mjs", import.meta.url).href;
    const proof = new URL("../src/proof.ts", import.meta.url).href;
    const manifest = fileURLToPath(new URL("../proofs/stage7-ll1-engine-proof.json", import.meta.url));
    const script = `
      let blocked = false;
      try { await import(${JSON.stringify(legacy)}); }
      catch (error) {
        if (error.message !== ${JSON.stringify(refusal)}) throw error;
        blocked = true;
      }
      if (!blocked) throw new Error("legacy guard inactive");
      const { assembleNativeGrammarProof } = await import(${JSON.stringify(helper)});
      const { hex, symbols, addresses } = await assembleNativeGrammarProof();
      const { runProofManifest } = await import(${JSON.stringify(proof)});
      const outcome = await runProofManifest(${JSON.stringify(manifest)});
      process.stdout.write(JSON.stringify({ hex, symbols, addresses,
        proofSymbols: outcome.symbols, proofStatus: outcome.memory[outcome.symbols.ProofStatus] }));
    `;
    const result = JSON.parse(execFileSync(process.execPath, [
      "--no-warnings", "--experimental-transform-types",
      "--experimental-loader", `data:text/javascript,${encodeURIComponent(loader)}`,
      "--input-type=module", "--eval", script,
    ], { encoding: "utf8", timeout: 30_000, maxBuffer: 1024 * 1024 }));
    expect(result).toEqual({ hex: baseline.hex, symbols: baseline.symbols,
      addresses: baseline.addresses, proofSymbols: baseline.symbols, proofStatus: 0xa5 });
  }, 35_000);
});
