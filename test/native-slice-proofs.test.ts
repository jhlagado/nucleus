import { readFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { assembleNativeProof } from "../scripts/assemble-native-proof.mjs";
import { nativeSliceProofProfiles } from "../scripts/native-slice-proof-profiles.mjs";

interface FrozenProfile {
  name: string;
  entry: string;
  hex: string;
  symbols: Record<string, number>;
  addresses: Record<string, number>;
  highWater: number;
  finalCursor: number;
}

// Captured once through ATOM from pristine 1cb0331, before native composition.
// No runtime Git lookup, regeneration, or translated fixture source is used.
const baseline = JSON.parse(readFileSync(
  new URL("./fixtures/native-slice-proof-baseline.json", import.meta.url), "utf8",
)) as { revision: string; profiles: FrozenProfile[] };
const matrix = [
  ["typed-expression", 1725, 1068, 1, 0],
  ["aggregate", 1622, 965, 0, 0],
  ["structured-control", 1685, 1028, 1, 0],
  ["array", 1476, 844, 1, 1],
  ["call", 1465, 833, 1, 1],
  ["expression", 1669, 1009, 1, 1],
] as const;

describe("canonical native historical compiler slices", () => {
  it("pins the complete frozen six-profile matrix and immutable published choices", () => {
    expect(baseline.revision).toBe("1cb0331");
    expect(baseline.profiles.map(profile => [
      profile.name, Object.keys(profile.symbols).length,
      Object.keys(profile.addresses).length,
      profile.symbols.LegacyCompilerSlices, profile.symbols.LegacyEncoders,
    ])).toEqual(matrix);
    expect(Object.keys(nativeSliceProofProfiles)).toEqual(
      matrix.map(([name]) => `${name}-z80-slice-proof.asm`),
    );
    expect(Object.isFrozen(nativeSliceProofProfiles)).toBe(true);
    for (const [name, , , legacyCompiler, legacyEncoders] of matrix) {
      const flags = nativeSliceProofProfiles[`${name}-z80-slice-proof.asm`]!;
      expect(Object.isFrozen(flags)).toBe(true);
      expect(flags).toEqual({
        NativeStreamingSource: 0, SegmentedOutput: 0, TargetStreamingOutput: 0,
        LegacyCompilerSlices: legacyCompiler, AggregateCallSlices: 0,
        HybridLL1Full: 0, CompilerNonlocalDiagnostics: 0,
        CompilerDiagnosticReturns: 1, CompilerDiagnosticBranches: 1,
        LegacyEncoders: legacyEncoders, RuntimeProofServices: 1,
        RuntimePacketGateway: 0,
      });
    }
  });

  for (const [name, symbolCount, addressCount] of matrix) {
    it(`${name}: preserves sparse bytes, address classes, extents and all public bindings`, async () => {
      const frozen = baseline.profiles.find(profile => profile.name === name)!;
      let fresh: Awaited<ReturnType<typeof assembleNativeProof>>;
      try { fresh = await assembleNativeProof(frozen.entry); }
      catch (error) {
        const failure = error as Error & { diagnostic?: unknown; native?: unknown };
        throw new Error(`${failure.message}: ${JSON.stringify({
          diagnostic: failure.diagnostic, native: failure.native,
        })}`);
      }
      console.info(`Native ${name}: ${fresh.instructions} ATOM instructions`);
      expect(fresh.hex).toBe(frozen.hex);
      expect(fresh.symbols).toEqual(frozen.symbols);
      expect(fresh.addresses).toEqual(frozen.addresses);
      expect(Object.keys(fresh.symbols)).toHaveLength(symbolCount);
      expect(Object.keys(fresh.addresses)).toHaveLength(addressCount);
      expect(fresh.generation.highWater).toBe(frozen.highWater);
      expect(fresh.generation.finalCursor).toBe(frozen.finalCursor);
      const privateOffsets: Record<string, readonly [string, string][]> = {
        "typed-expression": [
          ["QTDIVPOS", "TypedNestedDivideOuter"],
          ["QTNARPOS", "TypedNestedNarrowOuter"],
        ],
        aggregate: [["QGIMGLEN", "AggregateExpectedImageEnd"]],
        "structured-control": [["QCLABPOS", "StructuredLabelCapacityPoint"]],
      };
      const offsetBases: Record<string, string> = {
        QTDIVPOS: "TypedNestedDivideTrapSource",
        QTNARPOS: "TypedNestedNarrowTrapSource",
        QGIMGLEN: "AggregateExpectedImage",
        QCLABPOS: "StructuredLabelCapacitySource",
      };
      const raw = fresh.generation as typeof fresh.generation & {
        symbols: readonly { name: string; value: number }[];
      };
      for (const [key, end] of privateOffsets[name] ?? []) {
        expect(raw.symbols.find(symbol => symbol.name === key)?.value).toBe(
          frozen.symbols[end]! - frozen.symbols[offsetBases[key]!]!,
        );
        expect(fresh.symbols).not.toHaveProperty(key);
        expect(fresh.addresses).not.toHaveProperty(key);
      }

      const identities = fresh.project.parts.map(part => part.logicalIdentity);
      expect(new Set(identities).size).toBe(identities.length);
      for (const file of [
        frozen.entry, `${name}-slice-proof-sources.asm`, `${name}-slice-proof-driver.asm`,
        "memory-map.asmi", "loop-compiler-state.asmi", "loop-z80-state.asmi",
        "source-adapter.asm", "loop-tokenizer.asm", "loop-keywords.asmi",
        "loop-semantic-sink.asm", "loop-symbols.asm", "compiler-diagnostics.asm",
        "loop-parser-body.asm", "loop-z80-sink.asm", "loop-z80-runtime.asm",
      ]) expect(identities).toContain(`asm/vertical-slice/${file}`);
      expect(identities).not.toContain("asm/vertical-slice/compiler-profile-legacy.asmi");
      for (const part of fresh.project.parts) {
        expect(part.logicalIdentity).toMatch(/^asm\//);
        expect(Buffer.from(part.originalBytes)).toEqual(readFileSync(
          new URL(`../${part.logicalIdentity}`, import.meta.url),
        ));
        expect(part.originalBytes.length).toBeLessThanOrEqual(65535);
        expect(part.compilerBytes.length).toBe(part.originalBytes.length);
        const original = new TextDecoder().decode(part.originalBytes).split("\n");
        const compiled = new TextDecoder().decode(part.compilerBytes).split("\n");
        expect(compiled).toHaveLength(original.length);
        compiled.forEach((line, index) => {
          expect(line.length).toBe(original[index]!.length);
          if (line.trim()) expect(line).toBe(original[index]);
        });
      }
    }, 90_000);
  }

  it("executes the ordinary recursive-call proof with the legacy adapter unavailable", () => {
    const refusal = "historical proof adapter unavailable";
    const sourceRoot = new URL("../src/", import.meta.url).href;
    const loader = `export async function resolve(specifier, context, nextResolve) {
      if (/\\/scripts\\/atom-source(?:-translation)?\\.mjs$/.test(specifier))
        throw new Error(${JSON.stringify(refusal)});
      let resolved;
      try { resolved = await nextResolve(specifier, context); }
      catch (error) {
        if (error.code !== "ERR_MODULE_NOT_FOUND" ||
            !context.parentURL?.startsWith(${JSON.stringify(sourceRoot)}) ||
            !specifier.endsWith(".js")) throw error;
        resolved = await nextResolve(specifier.slice(0, -3) + ".ts", context);
      }
      if (resolved.url.endsWith("/scripts/atom-source.mjs") ||
          resolved.url.endsWith("/scripts/atom-source-translation.mjs"))
        throw new Error(${JSON.stringify(refusal)});
      return resolved;
    }`;
    const legacy = new URL("../scripts/atom-source.mjs", import.meta.url).href;
    const proof = new URL("../src/proof.ts", import.meta.url).href;
    const manifest = fileURLToPath(new URL("../proofs/call-z80-slice-proof.json", import.meta.url));
    const script = `
      let blocked = false;
      try { await import(${JSON.stringify(legacy)}); }
      catch (error) {
        if (error.message !== ${JSON.stringify(refusal)}) throw error;
        blocked = true;
      }
      if (!blocked) throw new Error("legacy guard inactive");
      const { runProofManifest } = await import(${JSON.stringify(proof)});
      const outcome = await runProofManifest(${JSON.stringify(manifest)});
      process.stdout.write(JSON.stringify({
        symbols: outcome.symbols,
        status: outcome.memory[outcome.symbols.ProofStatus],
        case: outcome.memory[outcome.symbols.ProofCase],
      }));
    `;
    const observed = JSON.parse(execFileSync(process.execPath, [
      "--no-warnings", "--experimental-transform-types", "--experimental-loader",
      `data:text/javascript,${encodeURIComponent(loader)}`,
      "--input-type=module", "--eval", script,
    ], { encoding: "utf8", timeout: 120_000, maxBuffer: 2 * 1024 * 1024 }));
    expect(observed).toEqual({
      symbols: baseline.profiles.find(profile => profile.name === "call")!.symbols,
      status: 0xa5, case: 0,
    });
  }, 130_000);
});
