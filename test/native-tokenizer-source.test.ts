import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { parseIntelHex } from "@jhlagado/debug80-runtime";
import { beforeAll, describe, expect, it } from "vitest";
import {
  assembleNativeCompilerStateProfile, assembleNativeLoopZ80State,
  assembleNativeTokenizerHostProof, assembleNativeTokenizerTrace,
} from "../scripts/assemble-native-tokenizer.mjs";

type Image = Awaited<ReturnType<typeof assembleNativeTokenizerTrace>>;
type Baseline = {
  revision: string; symbols: Record<string, number>; addresses: Record<string, number>;
  highWater: number; finalCursor: number;
  segments: { start: number; end: number; hex: string; sha256: string }[];
};
const readBaseline = <T>(name: string): T => JSON.parse(readFileSync(
  new URL(`./fixtures/native-tokenizer/${name}-baseline.json`, import.meta.url), "utf8",
)) as T;
const historicalRevision = "a023f7ed237dc7dd9d9e530b553876e53d65f8c1";
const currentStreaming = {
  start: 0, end: 1615,
  sha256: "abc1cbd61593603ba37ef1a3a0fb9199785a8dd89a7208bcb2ec7f875e9398db",
  symbolHash: "dc0526709842d00606a0f28f63c6f6df5f2a67f7ee11fadede82ff3e3fc5792d",
  addressHash: "f80b445b4f7718399ae0845002f559f2e1cf5aa71730c483f5935e2f78d6373d",
};
const currentStateProfiles = {
  "loop-n1-s0-t0": { symbols: 661,
    symbolHash: "7f9425cf5bb533e4e5f02bcdc36465b56b4dbcec56db46988f90cd2ecb513cd9" },
  "loop-n1-s0-t1": { symbols: 780,
    symbolHash: "c1ecf55c8dad3e5fddc64409c783cddbe68a412ccc0016ca4bfc5c2f1f0b1753" },
  "loop-n1-s1-t0": { symbols: 685,
    symbolHash: "6ef064aad79eb4f2afd143afb2fe692660e59c1192cc230894d27381e50a14db" },
  "loop-n1-s1-t1": { symbols: 804,
    symbolHash: "983845479a670ac927572f1f6728d083720fead445d690384b35bc50108a6088" },
} as const;
const trace = readBaseline<Baseline>("trace");
const host = readBaseline<Baseline>("host");
const state = readBaseline<{
  revision: string; profiles: Record<string, Baseline & {
    configuration: { legacy: boolean; native: number; segmented: number; target: number };
    hex: string;
  }>;
}>("state");
const z80 = readBaseline<Baseline & { hex: string }>("z80-state");
const addresses = (ranges: readonly { start: number; end: number }[]) =>
  ranges.flatMap(({ start, end }) => Array.from({ length: end - start }, (_, i) => start + i));
const dictionaryHash = (dictionary: Record<string, number>) => createHash("sha256")
  .update(JSON.stringify(Object.entries(dictionary).sort(([left], [right]) =>
    left.localeCompare(right))))
  .digest("hex");

describe("fresh native tokenizer/state source preservation", () => {
  let resident: Image;
  let streaming: Image;
  beforeAll(async () => {
    resident = await assembleNativeTokenizerTrace();
    streaming = await assembleNativeTokenizerHostProof();
  });

  it.each(["resident", "streaming"] as const)("preserves exact %s bytes, sparse writes and every public symbol", variant => {
    const actual = variant === "resident" ? resident : streaming;
    const baseline = variant === "resident" ? trace : host;
    expect(baseline.revision).toBe(historicalRevision);
    const parsed = parseIntelHex(actual.hex);
    if (variant === "resident") {
      expect(addresses(parsed.writeRanges ?? [])).toEqual(addresses(baseline.segments));
      for (const segment of baseline.segments) {
        const bytes = parsed.memory.slice(segment.start, segment.end);
        expect(Buffer.from(bytes).toString("hex")).toBe(segment.hex);
        expect(createHash("sha256").update(bytes).digest("hex")).toBe(segment.sha256);
      }
      expect(actual.symbols).toEqual(baseline.symbols);
      expect(actual.addresses).toEqual(baseline.addresses);
      expect(actual.generation.highWater).toBe(baseline.highWater);
      expect(actual.generation.finalCursor).toBe(baseline.finalCursor);
    } else {
      expect(addresses(parsed.writeRanges ?? [])).toEqual(
        Array.from({ length: currentStreaming.end }, (_, index) => index),
      );
      const bytes = parsed.memory.slice(currentStreaming.start, currentStreaming.end);
      expect(createHash("sha256").update(bytes).digest("hex"))
        .toBe(currentStreaming.sha256);
      expect(dictionaryHash(actual.symbols)).toBe(currentStreaming.symbolHash);
      expect(dictionaryHash(actual.addresses)).toBe(currentStreaming.addressHash);
      expect(actual.generation.highWater).toBe(currentStreaming.end);
      expect(actual.generation.finalCursor).toBe(currentStreaming.end);
    }
    expect(Object.keys(actual.symbols)).toHaveLength(variant === "resident" ? 777 : 938);
    expect(Object.keys(actual.addresses)).toHaveLength(variant === "resident" ? 111 : 125);
  });

  it("preserves private forward keyword displacements in generation, not public exports", () => {
    for (const actual of [resident, streaming]) {
      const raw = (actual.generation as Image["generation"] & {
        symbols: { name: string; value: number }[];
      }).symbols;
      for (let length = 2; length <= 8; length++) {
        const name = `KWDISP${length}`;
        expect(raw.find(symbol => symbol.name === name)?.value).toBe(
          actual.symbols[`KeywordLength${length}`]! - (actual.symbols.KeywordLengthOffsets! + length - 2),
        );
        expect(actual.symbols).not.toHaveProperty(name);
        expect(actual.addresses).not.toHaveProperty(name);
      }
    }
  });

  it("uses actual canonical leaves, allowing only official preprocessing blanks", () => {
    for (const actual of [resident, streaming]) {
      const identities = actual.project.parts.map(part => part.logicalIdentity);
      const leaves = ["source-adapter.asm", "loop-tokenizer.asm", "loop-keywords.asmi"];
      if (actual === streaming) leaves.push("native-source-host.asm");
      for (const leaf of leaves) expect(identities).toContain(`asm/vertical-slice/${leaf}`);
      for (const part of actual.project.parts) {
        const disk = readFileSync(new URL(`../${part.logicalIdentity}`, import.meta.url));
        expect(Buffer.from(part.originalBytes)).toEqual(disk);
        expect(part.compilerBytes).toHaveLength(part.originalBytes.length);
        for (let i = 0; i < part.originalBytes.length; i++) {
          if (part.originalBytes[i] !== part.compilerBytes[i]) {
            expect(part.compilerBytes[i], `${part.logicalIdentity} byte ${i}`).toBe(32);
          }
        }
      }
    }
  });

  it("keeps the full historical plus eight-way state profile matrix", () => {
    const names = ["historical"];
    for (const native of [0, 1]) for (const segmented of [0, 1]) for (const target of [0, 1]) {
      const name = `loop-n${native}-s${segmented}-t${target}`;
      names.push(name);
      expect(state.profiles[name]?.configuration).toEqual({
        name, native, segmented, target, legacy: false,
      });
    }
    expect(Object.keys(state.profiles).sort()).toEqual(names.sort());
    expect(state.profiles.historical?.configuration).toEqual({
      name: "historical", native: 0, segmented: 0, target: 0, legacy: true,
    });
  });

  it.each(Object.entries(state.profiles))("preserves all canonical state values for %s", async (name, baseline) => {
    const actual = await assembleNativeCompilerStateProfile(baseline.configuration);
    expect(state.revision).toBe(historicalRevision);
    // Selection is a proof-only preprocessing flag, not a compiler ABI field.
    const { HistoricalCompilerState, ...symbols } = actual.symbols;
    expect(HistoricalCompilerState).toBe(Number(baseline.configuration.legacy ?? false));
    if (baseline.configuration.native === 1) {
      const expected = currentStateProfiles[name as keyof typeof currentStateProfiles];
      expect(expected).toBeDefined();
      expect(Object.keys(symbols)).toHaveLength(expected.symbols);
      expect(dictionaryHash(symbols)).toBe(expected.symbolHash);
      expect(actual.addresses).toEqual({});
      expect(actual.hex).toBe(":00000001FF\n");
    } else {
      expect(symbols).toEqual(baseline.symbols);
      expect(actual.addresses).toEqual(baseline.addresses);
      expect(actual.hex).toBe(baseline.hex);
    }
    expect(actual.generation.highWater).toBe(0);
    expect(actual.generation.finalCursor).toBe(0);
  });

  it("preserves the separate loop Z80 emission state from the canonical map", async () => {
    const actual = await assembleNativeLoopZ80State();
    expect(z80.revision).toBe(historicalRevision);
    expect(actual.symbols).toEqual({ ...z80.symbols, TargetStreamingOutput: 0 });
    expect(actual.addresses).toEqual(z80.addresses);
    expect(actual.hex).toBe(z80.hex);
    expect(actual.generation.highWater).toBe(0);
    expect(actual.generation.finalCursor).toBe(0);
  });

  it("builds both real tokenizer compositions with the translator unavailable", () => {
    const refusal = "legacy tokenizer source adapter is unavailable";
    const loader = `export async function resolve(specifier, context, nextResolve) {
    if (specifier.endsWith("atom-source.mjs") || specifier.endsWith("atom-source-translation.mjs")) throw new Error(${JSON.stringify(refusal)});
      const resolved = await nextResolve(specifier, context);
      if (resolved.url.endsWith("/scripts/atom-source.mjs") ||
          resolved.url.endsWith("/scripts/atom-source-translation.mjs")) {
        throw new Error(${JSON.stringify(refusal)});
      }
      return resolved;
    }`;
    const legacy = new URL("../scripts/atom-source.mjs", import.meta.url).href;
    const helper = new URL("../scripts/assemble-native-tokenizer.mjs", import.meta.url).href;
    const script = `
      let blocked = false;
      try { await import(${JSON.stringify(legacy)}); }
      catch (error) {
        if (error.message !== ${JSON.stringify(refusal)}) throw error;
        blocked = true;
      }
      if (!blocked) throw new Error("legacy guard not active");
      const m = await import(${JSON.stringify(helper)});
      const builds = [await m.assembleNativeTokenizerTrace(), await m.assembleNativeTokenizerHostProof()];
      process.stdout.write(JSON.stringify(builds.map(({hex,symbols,addresses}) => ({hex,symbols,addresses}))));
    `;
    const results = JSON.parse(execFileSync(process.execPath, [
      "--no-warnings", "--experimental-loader", `data:text/javascript,${encodeURIComponent(loader)}`,
      "--input-type=module", "--eval", script,
    ], { encoding: "utf8", timeout: 30_000, maxBuffer: 1024 * 1024 }));
    expect(results).toEqual([resident, streaming].map(({ hex, symbols, addresses }) => ({ hex, symbols, addresses })));
  }, 35_000);
});
