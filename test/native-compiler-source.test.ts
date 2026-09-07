import { readFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { parseIntelHex } from "@jhlagado/debug80-runtime";
import { describe, expect, it } from "vitest";
import { assembleNativeCompiler } from "../scripts/assemble-native-compiler.mjs";
import {
  debugCompilerHex, debugCompilerSymbols,
  mon3CompilerHex, mon3CompilerSymbols,
  mon3DebugCompilerHex, mon3DebugCompilerSymbols,
  nativeCompilerHex, nativeCompilerSymbols,
  nativeDebugCompilerHex, nativeDebugCompilerSymbols,
  normalCompilerHex, normalCompilerSymbols,
} from "../src/generated-compiler-images.js";

interface PublishedProfile {
  name: string;
  entry: string;
  hex: string;
  symbols: Record<string, number>;
}

const profiles: PublishedProfile[] = [
  { name: "normal", entry: "flat-target-z80-slice-proof.asm",
    hex: normalCompilerHex, symbols: { ...normalCompilerSymbols } },
  { name: "debug", entry: "flat-target-debug-z80-slice-proof.asm",
    hex: debugCompilerHex, symbols: { ...debugCompilerSymbols } },
  { name: "native", entry: "native-target-compiler.asm",
    hex: nativeCompilerHex, symbols: { ...nativeCompilerSymbols } },
  { name: "nativeDebug", entry: "native-target-debug-compiler.asm",
    hex: nativeDebugCompilerHex, symbols: { ...nativeDebugCompilerSymbols } },
  { name: "mon3", entry: "native-target-mon3-compiler.asm",
    hex: mon3CompilerHex, symbols: { ...mon3CompilerSymbols } },
  { name: "mon3Debug", entry: "native-target-mon3-debug-compiler.asm",
    hex: mon3DebugCompilerHex, symbols: { ...mon3DebugCompilerSymbols } },
];

const coverage = (hex: string) => (parseIntelHex(hex).writeRanges ?? [])
  .flatMap(({ start, end }) => Array.from({ length: end - start }, (_, index) => start + index));

async function assembleProfile(entry: string) {
  try { return await assembleNativeCompiler(entry); }
  catch (error) {
    // ATOM errors also contain a very large service trace. Keep the exact
    // source/statement diagnostic visible instead of flooding the test report.
    const failure = error as Error & { diagnostic?: unknown; native?: unknown };
    throw new Error(`${failure.message}: ${JSON.stringify({
      diagnostic: failure.diagnostic, native: failure.native,
    })}`);
  }
}

describe("canonical native compiler production sources", () => {
  it("pins all six generated production profiles", () => {
    expect(profiles.map(({ name, entry }) => [name, entry])).toEqual([
      ["normal", "flat-target-z80-slice-proof.asm"],
      ["debug", "flat-target-debug-z80-slice-proof.asm"],
      ["native", "native-target-compiler.asm"],
      ["nativeDebug", "native-target-debug-compiler.asm"],
      ["mon3", "native-target-mon3-compiler.asm"],
      ["mon3Debug", "native-target-mon3-debug-compiler.asm"],
    ]);
  });

  for (const { name, entry, hex, symbols } of profiles) {
    it(`${name}: preserves every sparse byte and public binding from real source`, async () => {
      const fresh = await assembleProfile(entry);
      console.info(`Native ATOM assembly ${name}: ${fresh.instructions} instructions`);
      expect(fresh.hex).toBe(hex);
      expect(fresh.symbols).toEqual(symbols);
      expect(coverage(fresh.hex)).toEqual(coverage(hex));

      const identities = fresh.project.parts.map(part => part.logicalIdentity);
      expect(new Set(identities).size).toBe(identities.length);
      expect(identities).toContain(`asm/vertical-slice/${entry}`);
      for (const leaf of [
        "flat-target-compiler-image.asmi", "compiler-production-state.asmi",
        "source-adapter.asm", "loop-tokenizer.asm", "loop-keywords.asmi",
        "compiler-diagnostics.asm", "loop-semantic-sink.asm", "loop-symbols.asm",
        "loop-parser.asm", "typed-expression-parser.asm", "aggregate-parser.asm",
        "aggregate-call-parser.asm", "stage7-ll1-actions.asm",
        "loop-z80-sink.asm", "target-output.asm", "typed-expression-z80.asm",
        "structured-control-z80.asm", "aggregate-call-z80.asm", "aggregate-z80.asm",
      ]) expect(identities).toContain(`asm/vertical-slice/${leaf}`);
      if (name.startsWith("mon3")) {
        for (const leaf of [
          "native-system-service-region.asm", "native-nobj-writer.asm",
          "native-system-services.asm",
        ]) expect(identities).toContain(`asm/vertical-slice/${leaf}`);
      }
      for (const part of fresh.project.parts) {
        // No test-only assembly clone or translated input can stand in for a
        // canonical source. Only ATOM's own line masking may change its bytes.
        expect(part.logicalIdentity).toMatch(/^(asm|grammar)\//);
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

  it("uses the ordinary image and executable proof routes with legacy assembly unavailable", () => {
    const refusal = "legacy compiler assembly unavailable";
    const sourceRoot = new URL("../src/", import.meta.url).href;
    const loader = `export async function resolve(specifier, context, nextResolve) {
    if (specifier.endsWith("atom-source.mjs") || specifier.endsWith("atom-source-translation.mjs")) throw new Error(${JSON.stringify(refusal)});
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
    const imageRoute = new URL("../scripts/assemble-image-source.mjs", import.meta.url).href;
    const source = fileURLToPath(new URL(
      "../asm/vertical-slice/flat-target-z80-slice-proof.asm", import.meta.url,
    ));
    const proof = new URL("../src/proof.ts", import.meta.url).href;
    const manifest = fileURLToPath(new URL("../proofs/flat-target-z80-slice-proof.json", import.meta.url));
    const script = `
      process.on("uncaughtException", error => {
        process.stderr.write(JSON.stringify({
          message: error.message, diagnostic: error.diagnostic, native: error.native,
        }) + "\\n");
        process.exit(1);
      });
      let blocked = false;
      try { await import(${JSON.stringify(legacy)}); }
      catch (error) {
        if (error.message !== ${JSON.stringify(refusal)}) throw error;
        blocked = true;
      }
      if (!blocked) throw new Error("legacy guard inactive");
      const { assembleImageSource } = await import(${JSON.stringify(imageRoute)});
      const image = await assembleImageSource(${JSON.stringify(source)});
      const { runProofManifest } = await import(${JSON.stringify(proof)});
      const outcome = await runProofManifest(${JSON.stringify(manifest)});
      process.stdout.write(JSON.stringify({
        image, proofSymbols: outcome.symbols,
        proofStatus: outcome.memory[outcome.symbols.ProofStatus],
        proofCase: outcome.memory[outcome.symbols.ProofCase],
        hasCommittedObject: outcome.nobj !== undefined,
      }));
    `;
    const observed = JSON.parse(execFileSync(process.execPath, [
      "--no-warnings", "--experimental-transform-types",
      "--experimental-loader", `data:text/javascript,${encodeURIComponent(loader)}`,
      "--input-type=module", "--eval", script,
    // This runs two native assemblies plus the proof's linked-runtime work
    // (165.4 seconds measured locally). Guest execution budgets stay in the
    // manifest; this allowance is for slower CI hosts and parallel build jobs.
    ], { encoding: "utf8", timeout: 360_000, maxBuffer: 2 * 1024 * 1024 }));
    const normal = profiles.find(profile => profile.name === "normal")!;
    expect(observed).toEqual({
      image: { hex: normal.hex, symbols: normal.symbols },
      proofSymbols: normal.symbols, proofStatus: 0xa5, proofCase: 0,
      hasCommittedObject: true,
    });
  }, 370_000);
});
