import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { parseIntelHex } from "@jhlagado/debug80-runtime";
import { beforeAll, describe, expect, it } from "vitest";
import { assembleNativeImportResolver } from "../scripts/assemble-native-import-resolver.mjs";
import { nativeImportResolverHex, nativeImportResolverSymbols } from "../src/generated-native-import-resolver.js";

let fresh: Awaited<ReturnType<typeof assembleNativeImportResolver>>;
beforeAll(async () => { fresh = await assembleNativeImportResolver(); });

const sha256 = (value: Uint8Array | string): string =>
  createHash("sha256").update(value).digest("hex");

const exactImage = {
  start: 0x8000,
  end: 0x8c0d,
  bytes: 3_085,
  byteSha256: "85866b1eb0adbd65206979ced75c0fe81432d6daecb1b9aaba4729de09108dac",
  symbols: 317,
  symbolSha256: "43d57e4d14df4b9e2350fb1899d2be2553b81c85a29c8447916158c3a80918aa",
  addresses: 155,
  addressSha256: "5d4eeb0bf02c4e7a741f9e74623d3f521ae8efabc61b458825e6c1ce367b7b4c",
} as const;

describe("standalone native import resolver source preservation", () => {
  it("builds the production resolver without loading the legacy adapter", () => {
    // A real module-resolution guard, not an assembler mock: the subprocess
    // runs the generator entry with both source-adaptation modules unavailable.
    const refusal = "legacy source adapter is unavailable";
    const loader = `export async function resolve(specifier, context, nextResolve) {
    if (specifier.endsWith("atom-source.mjs") || specifier.endsWith("atom-source-translation.mjs")) throw new Error(${JSON.stringify(refusal)});
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
    expect(produced).toEqual({ hex: nativeImportResolverHex, symbols: nativeImportResolverSymbols });
    // The generator serializes insertion order. Value equality alone missed
    // the stale artifact when native ATOM changed the dictionary ordering.
    expect(JSON.stringify(produced.symbols)).toBe(JSON.stringify(nativeImportResolverSymbols));
  }, 35_000);

  it.each(["fresh native source", "bundled image"])("preserves the exact current bytes and public symbols: %s", variant => {
    const actual = variant === "bundled image"
      ? { hex: nativeImportResolverHex, symbols: nativeImportResolverSymbols }
      : fresh;
    const parsed = parseIntelHex(actual.hex);
    const ranges = parsed.writeRanges ?? [];
    expect(ranges[0]?.start).toBe(exactImage.start);
    expect(ranges.at(-1)?.end).toBe(exactImage.end);
    expect(ranges.every((range, index) => index === 0 || ranges[index - 1]!.end === range.start)).toBe(true);
    const bytes = parsed.memory.slice(exactImage.start, exactImage.end);
    expect(bytes).toHaveLength(exactImage.bytes);
    expect(sha256(bytes)).toBe(exactImage.byteSha256);
    expect(Object.keys(actual.symbols)).toHaveLength(exactImage.symbols);
    expect(sha256(JSON.stringify(actual.symbols))).toBe(exactImage.symbolSha256);
  });

  it("preserves all address labels and sends native source unchanged to ATOM", () => {
    expect(Object.keys(fresh.addresses)).toHaveLength(exactImage.addresses);
    expect(sha256(JSON.stringify(fresh.addresses))).toBe(exactImage.addressSha256);
    expect(fresh.generation.highWater).toBe(exactImage.end);
    expect(fresh.generation.finalCursor).toBe(exactImage.end);
    for (const part of fresh.project.parts) {
      const original = new TextDecoder().decode(part.originalBytes);
      expect(new TextDecoder().decode(part.compilerBytes)).toBe(
        original.replace(/^%INCLUDE[^\r\n]*/gm, line => " ".repeat(line.length)),
      );
    }
  });
});
