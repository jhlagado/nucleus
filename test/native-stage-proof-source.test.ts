import { readFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { createZ80Runtime, parseIntelHex } from "@jhlagado/debug80-runtime";
import { describe, expect, it } from "vitest";
import { assembleNativeProof } from "../scripts/assemble-native-proof.mjs";
import { nativeStageProofProfiles } from "../scripts/native-stage-proof-profiles.mjs";

interface FrozenProof {
  entry: string;
  hex: string;
  symbols: Record<string, number>;
  addresses: Record<string, number>;
  definitions: Record<string, number>;
}

// Captured once from pristine 1cb0331 through its historical ATOM helper,
// before the source-name migration. This test never updates the fixture.
const baseline = JSON.parse(readFileSync(new URL(
  "./fixtures/native-stage-proof-baseline.json", import.meta.url,
), "utf8")) as { revision: string; assembler: string; profiles: FrozenProof[] };
const entries = [
  ["stage7-ll1-aggregate-call-z80-slice-proof.asm", 2520, 1636, 27498],
  ["stage8-failure-z80-slice-proof.asm", 2585, 1701, 29289],
  ["stage9-conformance-z80-slice-proof.asm", 2446, 1562, 27612],
  ["stage7-ll1-parser-coverage-proof.asm", 2289, 1405, 17387],
] as const;

describe("canonical native historical stage proofs", () => {
  it("pins all four pristine proof outputs and their published profiles", () => {
    expect(baseline.revision).toBe("1cb0331");
    expect(baseline.assembler).toBe("ATOM via frozen historical helper");
    expect(baseline.profiles.map(proof => proof.entry)).toEqual(entries.map(([entry]) => entry));
    for (const proof of baseline.profiles) {
      expect(nativeStageProofProfiles[proof.entry]).toEqual(proof.definitions);
    }
  });

  for (const [entry, symbols, addresses, bytes] of entries) {
    it(entry + ": preserves every byte, public binding, address class and proof program", async () => {
      const frozen = baseline.profiles.find(proof => proof.entry === entry)!;
      let fresh;
      try { fresh = await assembleNativeProof(entry); }
      catch (error) {
        const failed = error as Error & { diagnostic?: unknown; native?: unknown };
        throw new Error(failed.message + ": " + JSON.stringify({
          diagnostic: failed.diagnostic, native: failed.native,
        }));
      }
      expect(fresh.hex).toBe(frozen.hex);
      expect(fresh.symbols).toEqual(frozen.symbols);
      expect(fresh.addresses).toEqual(frozen.addresses);
      expect(Object.keys(fresh.symbols)).toHaveLength(symbols);
      expect(Object.keys(fresh.addresses)).toHaveLength(addresses);
      const loaded = parseIntelHex(fresh.hex);
      expect(loaded.writeRanges).toEqual(parseIntelHex(frozen.hex).writeRanges);
      expect((loaded.writeRanges ?? []).reduce((sum, range) =>
        sum + range.end - range.start, 0)).toBe(bytes);

      const identities = fresh.project.parts.map(part => part.logicalIdentity);
      expect(new Set(identities).size).toBe(identities.length);
      expect(identities).toContain("asm/vertical-slice/" + entry);
      for (const leaf of [
        "stage-proof-compiler.asmi", "memory-map.asmi", "loop-compiler-state.asmi",
        "aggregate-call-state.asmi", "loop-z80-state.asmi", "loop-parser.asm",
        "stage7-ll1-parser.asm", "stage7-ll1-actions.asm", "loop-z80-sink.asm",
        "typed-expression-z80.asm", "aggregate-z80.asm", "proof-z80-runtime.asm",
      ]) expect(identities).toContain("asm/vertical-slice/" + leaf);
      expect(identities).not.toContain("asm/vertical-slice/target-output.asm");
      for (const part of fresh.project.parts) {
        expect(part.logicalIdentity).toMatch(/^(asm|grammar)\//);
        expect(Buffer.from(part.originalBytes)).toEqual(readFileSync(
          new URL("../" + part.logicalIdentity, import.meta.url),
        ));
        expect(part.originalBytes.length).toBeLessThanOrEqual(65535);
        const source = new TextDecoder().decode(part.originalBytes).split("\n");
        const compiled = new TextDecoder().decode(part.compilerBytes).split("\n");
        expect(compiled).toHaveLength(source.length);
        compiled.forEach((line, index) => {
          expect(line.length).toBe(source[index]!.length);
          if (line.trim()) expect(line).toBe(source[index]);
        });
      }

      const start = fresh.symbols.ProofStart!;
      const machine = createZ80Runtime({ memory: loaded.memory.slice(), startAddress: start }, start);
      let executed = 0;
      while (!machine.isHalted() && executed++ < 5_000_000) machine.step();
      expect(machine.isHalted()).toBe(true);
      expect(machine.hardware.memory[fresh.symbols.ProofStatus!]).toBe(0xa5);
      expect(machine.hardware.memory[fresh.symbols.ProofCase!]).toBe(0);
      expect(machine.cpu.sp).toBe(fresh.symbols.StackTop);
    }, 90_000);
  }

  it("the ordinary coverage-proof route works with both legacy adapters blocked", () => {
    const refusal = "legacy stage proof adapter unavailable";
    const sourceRoot = new URL("../src/", import.meta.url).href;
    const loader = `export async function resolve(specifier, context, nextResolve) {
      // Refuse retired modules even after their files have been removed.
      if (specifier.endsWith("/scripts/atom-source.mjs") ||
          specifier.endsWith("/scripts/atom-source-translation.mjs")) {
        throw new Error(${JSON.stringify(refusal)});
      }
      let resolved;
      try { resolved = await nextResolve(specifier, context); }
      catch (error) {
        if (error.code !== "ERR_MODULE_NOT_FOUND" ||
            !context.parentURL?.startsWith(${JSON.stringify(sourceRoot)}) ||
            !specifier.endsWith(".js")) throw error;
        resolved = await nextResolve(specifier.slice(0, -3) + ".ts", context);
      }
      if (resolved.url.endsWith("/scripts/atom-source.mjs") ||
          resolved.url.endsWith("/scripts/atom-source-translation.mjs")) {
        throw new Error(${JSON.stringify(refusal)});
      }
      return resolved;
    }`;
    const legacy = new URL("../scripts/atom-source.mjs", import.meta.url).href;
    const proofModule = new URL("../src/proof.ts", import.meta.url).href;
    const manifest = fileURLToPath(new URL("../proofs/stage7-ll1-parser-coverage-proof.json", import.meta.url));
    const script = `
      let blocked = false;
      try { await import(${JSON.stringify(legacy)}); }
      catch (error) {
        if (error.message !== ${JSON.stringify(refusal)}) throw error;
        blocked = true;
      }
      if (!blocked) throw new Error("legacy guard inactive");
      const { runProofManifest } = await import(${JSON.stringify(proofModule)});
      const result = await runProofManifest(${JSON.stringify(manifest)});
      process.stdout.write(JSON.stringify({
        symbols: result.symbols,
        status: result.memory[result.symbols.ProofStatus],
        proofCase: result.memory[result.symbols.ProofCase],
      }));
    `;
    const actual = JSON.parse(execFileSync(process.execPath, [
      "--no-warnings", "--experimental-transform-types",
      "--experimental-loader", "data:text/javascript," + encodeURIComponent(loader),
      "--input-type=module", "--eval", script,
    ], { encoding: "utf8", timeout: 180_000, maxBuffer: 2 * 1024 * 1024 }));
    const frozen = baseline.profiles.find(proof => proof.entry === "stage7-ll1-parser-coverage-proof.asm")!;
    expect(actual).toEqual({ symbols: frozen.symbols, status: 0xa5, proofCase: 0 });
  }, 190_000); // Full compiler assembly in an isolated Node process.
});
