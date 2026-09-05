import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { parseIntelHex } from "@jhlagado/debug80-runtime";
import { beforeAll, describe, expect, it } from "vitest";
import { assembleNativeImportResolver } from "../scripts/assemble-native-import-resolver.mjs";
import { nativeImportResolverHex, nativeImportResolverSymbols } from "../src/generated-native-import-resolver.js";

// Captured from the checked-in image at 4972e3a, with address-only exports
// taken from fresh ATOM assembly after exact byte/coverage/symbol comparison.
const baseline = JSON.parse(readFileSync(new URL(
  "./fixtures/native-import-resolver-baseline.json", import.meta.url,
), "utf8")) as {
  revision: string;
  hex: string;
  symbols: Record<string, number>;
  addresses: Record<string, number>;
  highWater: number;
  finalCursor: number;
  segments: { start: number; end: number; hex: string; sha256: string }[];
};
let fresh: Awaited<ReturnType<typeof assembleNativeImportResolver>>;
beforeAll(async () => { fresh = await assembleNativeImportResolver(); });

const writtenAddresses = (ranges: readonly { start: number; end: number }[]) =>
  ranges.flatMap(({ start, end }) => Array.from({ length: end - start }, (_, i) => start + i));

describe("standalone native import resolver source preservation", () => {
  it("builds the production resolver without loading the legacy adapter", () => {
    // A real module-resolution guard, not an assembler mock: the subprocess
    // runs the generator entry with both source-adaptation modules unavailable.
    const refusal = "legacy source adapter is unavailable";
    const loader = `export async function resolve(specifier, context, nextResolve) {
      const resolved = await nextResolve(specifier, context);
      if (resolved.url.endsWith("/scripts/atom-source.mjs") ||
          resolved.url.endsWith("/scripts/atom-source-translation.mjs")) {
        throw new Error(${JSON.stringify(refusal)});
      }
      return resolved;
    }`;
    const route = new URL("../scripts/assemble-image-source.mjs", import.meta.url).href;
    const legacy = new URL("../scripts/atom-source.mjs", import.meta.url).href;
    const source = fileURLToPath(new URL(
      "../asm/vertical-slice/native-import-resolver-tool.asm", import.meta.url,
    ));
    const script = `
      let blocked = false;
      try { await import(${JSON.stringify(legacy)}); }
      catch (error) {
        if (error.message !== ${JSON.stringify(refusal)}) throw error;
        blocked = true;
      }
      if (!blocked) throw new Error("legacy-module guard was not active");
      const { assembleImageSource } = await import(${JSON.stringify(route)});
      process.stdout.write(JSON.stringify(await assembleImageSource(${JSON.stringify(source)})));
    `;
    const produced = JSON.parse(execFileSync(process.execPath, [
      "--no-warnings", "--experimental-loader", `data:text/javascript,${encodeURIComponent(loader)}`,
      "--input-type=module", "--eval", script,
    ], { encoding: "utf8", timeout: 30_000, maxBuffer: 1024 * 1024 })) as {
      hex: string; symbols: Record<string, number>;
    };
    expect(produced).toEqual({ hex: baseline.hex, symbols: baseline.symbols });
    expect(produced).toEqual({ hex: nativeImportResolverHex, symbols: nativeImportResolverSymbols });
    // The generator serializes insertion order. Value equality alone missed
    // the stale artifact when native ATOM changed the dictionary ordering.
    expect(JSON.stringify(produced.symbols)).toBe(JSON.stringify(nativeImportResolverSymbols));
  }, 35_000);

  it.each(["fresh native source", "bundled image"])("preserves the fixed bytes and public symbols: %s", variant => {
    expect(baseline.revision).toBe("4972e3ae51f0166d7322a96cf508ec6fff4e0964");
    const actual = variant === "bundled image"
      ? { hex: nativeImportResolverHex, symbols: nativeImportResolverSymbols }
      : fresh;
    const parsed = parseIntelHex(actual.hex);
    expect(writtenAddresses(parsed.writeRanges ?? [])).toEqual(writtenAddresses(baseline.segments));
    expect(baseline.segments.map(({ start, end }) => ({ start, end }))).toEqual([
      { start: 0x8000, end: 0x8bf0 },
    ]);
    for (const segment of baseline.segments) {
      const bytes = parsed.memory.slice(segment.start, segment.end);
      expect(Buffer.from(bytes).toString("hex")).toBe(segment.hex);
      expect(createHash("sha256").update(bytes).digest("hex")).toBe(segment.sha256);
    }
    expect(Object.keys(actual.symbols)).toHaveLength(312);
    expect(actual.symbols).toEqual(baseline.symbols);
  });

  it("preserves all address labels and sends native source unchanged to ATOM", () => {
    expect(Object.keys(fresh.addresses)).toHaveLength(153);
    expect(fresh.addresses).toEqual(baseline.addresses);
    expect(fresh.generation.highWater).toBe(baseline.highWater);
    expect(fresh.generation.finalCursor).toBe(baseline.finalCursor);
    expect(fresh.generation.highWater).toBe(0x8bf0);
    for (const part of fresh.project.parts) {
      const original = new TextDecoder().decode(part.originalBytes);
      expect(new TextDecoder().decode(part.compilerBytes)).toBe(
        original.replace(/^%INCLUDE[^\r\n]*/gm, line => " ".repeat(line.length)),
      );
    }
  });
});
