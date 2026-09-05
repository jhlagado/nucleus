import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import test from "node:test";
import { parseIntelHex } from "@jhlagado/debug80-runtime";
import { assembleNativeSource } from "./assemble-native-source.mjs";
import { restoreMemoryMapLimit } from "./restore-memory-map-limit.mjs";

const root = fileURLToPath(new URL("../", import.meta.url));
// Captured once from the old map sources, before the native-map conversion.
// Tests load this fixed artifact; they do not assemble or translate old source.
const baseline = JSON.parse(await readFile(
  new URL("./fixtures/native-memory-map-baseline.json", import.meta.url), "utf8",
));
const exportMap = Object.assign({}, ...await Promise.all([
  "atom-runtime-symbols.json", "atom-cpm-source-symbols.json",
  "atom-cpm-adapters-symbols.json", "atom-memory-symbols.json",
].map(async name => JSON.parse(await readFile(new URL(`../asm/${name}`, import.meta.url), "utf8")))));

test("memory-map baseline contains all five complete old profiles", () => {
  assert.equal(baseline.revision, "4972e3ae51f0166d7322a96cf508ec6fff4e0964");
  assert.deepEqual(Object.fromEntries(Object.entries(baseline.profiles).map(([name, profile]) =>
    [name, Object.keys(profile.symbols).length],
  )), { historical: 35, hosted: 37, "hosted-debug": 37, mon3: 39, cpm22: 54 });
  assert.deepEqual(baseline.profiles.historical.baselinePreprocessorSymbols, { NativeStreamingSource: 0 });
  assert.deepEqual(baseline.profiles.hosted.definitions, { DebugHooks: 0 });
  assert.deepEqual(baseline.profiles["hosted-debug"].definitions, { DebugHooks: 1 });
});

for (const [name, profile] of Object.entries(baseline.profiles)) {
  test(`native ${name} map preserves every constant and its full-width host limit`, async () => {
    const raw = await assembleNativeSource({
      root, entry: profile.entry, definitions: profile.definitions, exportMap,
      requiredExports: Object.keys(profile.symbols),
    });
    const last = raw.generation.symbols.filter(symbol => symbol.name === "MMLAST");
    assert.equal(last.length, 1);
    assert.equal(last[0].value, 0xffff);
    // This single mapped name has an explicit value conversion at the host
    // boundary. Neither the native constant nor its host endpoint wraps to zero.
    assert.equal(raw.symbols.AddressSpaceLimit, 0xffff);
    const result = restoreMemoryMapLimit(raw);
    assert.equal(raw.symbols.AddressSpaceLimit, 0xffff);
    assert.notEqual(result.symbols, raw.symbols);
    assert.deepEqual(result.symbols, profile.symbols);
    assert.equal(result.symbols.AddressSpaceLimit, 0x10000);
    assert.equal(Object.hasOwn(result.symbols, "MMLAST"), false);
    assert.deepEqual(result.addresses, {});
    for (const flag of Object.keys(profile.baselinePreprocessorSymbols)) {
      assert.equal(Object.hasOwn(result.symbols, flag), false, `${flag} is entry metadata, not a native constant`);
    }

    assert.deepEqual(result.generation.images, []);
    assert.deepEqual(result.generation.patches, []);
    assert.equal(result.generation.highWater, 0);
    assert.equal(result.generation.finalCursor, 0);
    assert.equal(result.hex, ":00000001FF\n");
    assert.deepEqual(parseIntelHex(result.hex).writeRanges, []);
    assert.ok(result.instructions > 0);
    assert.equal(result.project.parts.length, 1);
    const part = result.project.parts[0];
    assert.equal(part.logicalIdentity, profile.entry);
    assert.deepEqual(Buffer.from(part.originalBytes), await readFile(new URL(`../${profile.entry}`, import.meta.url)));
    assert.deepEqual(part.compilerBytes, part.originalBytes);
  });
}

const limitResult = (value, symbols = { AddressSpaceLimit: value }) => ({
  symbols,
  generation: { symbols: [{ name: "MMLAST", value }] },
});

test("memory-map limit rejects malformed native values before conversion", () => {
  for (const value of [-1, 65536, NaN, 1.5]) {
    assert.throws(() => restoreMemoryMapLimit(limitResult(value)), {
      name: "RangeError", message: "Native memory-map last address is outside 0..65535",
    });
  }
});

test("memory-map limit requires its exact mapped output and no private alias", () => {
  for (const symbols of [
    {}, { MMLAST: 0xffff }, { AddressSpaceLimit: 0 },
    { AddressSpaceLimit: 0xffff, MMLAST: 0xffff },
  ]) {
    assert.throws(() => restoreMemoryMapLimit(limitResult(0xffff, symbols)),
      /requires its explicit output-name mapping/);
  }
});

test("memory-map restoration leaves an unrelated result unchanged by identity", () => {
  const result = Object.freeze({
    symbols: Object.freeze({ PublicValue: 7 }),
    generation: Object.freeze({ symbols: Object.freeze([{ name: "OTHER", value: 7 }]) }),
  });
  assert.equal(restoreMemoryMapLimit(result), result);
});

test("memory-map restoration preserves frozen input while changing only the host limit", () => {
  const result = Object.freeze({
    symbols: Object.freeze({ AddressSpaceLimit: 0xffff, PublicValue: 7 }),
    generation: Object.freeze({
      symbols: Object.freeze([Object.freeze({ name: "MMLAST", value: 0xffff })]),
    }),
    addresses: Object.freeze({ PublicEntry: 0x100 }),
  });
  const restored = restoreMemoryMapLimit(result);
  assert.notEqual(restored, result);
  assert.notEqual(restored.symbols, result.symbols);
  assert.deepEqual(result.symbols, { AddressSpaceLimit: 0xffff, PublicValue: 7 });
  assert.deepEqual(restored.symbols, { AddressSpaceLimit: 0x10000, PublicValue: 7 });
  assert.equal(restored.generation, result.generation);
  assert.equal(restored.addresses, result.addresses);
});
