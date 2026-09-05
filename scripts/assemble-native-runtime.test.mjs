import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { parseIntelHex } from "@jhlagado/debug80-runtime";
import { assembleNativeRuntime } from "./assemble-native-runtime.mjs";

const catalogSource = await readFile(new URL("../src/generated-runtime-catalog.ts", import.meta.url), "utf8");
const catalog = JSON.parse(/^export const generatedRuntimeCatalog = ([\s\S]*) as const;$/m.exec(catalogSource)[1]);
const contextFor = profile => ({
  runtimeBase: profile.runtimeBase,
  writableStateBase: profile.stateBase,
  programDataBase: profile.stateBase + 41,
  programDataCapacity: 0,
  readOnlyBase: profile.runtimeBase + 732,
  readOnlyCapacity: 0,
  packetService: profile.packetService,
});

for (const profile of catalog) {
  test(`native runtime matches released ${profile.name} bytes, coverage and identities`, async () => {
    const result = await assembleNativeRuntime(contextFor(profile));
    const actual = parseIntelHex(result.hex);
    const expected = parseIntelHex(profile.hex);
    assert.deepEqual(actual.memory, expected.memory);
    assert.deepEqual(actual.writeRanges, expected.writeRanges);
    assert.equal(result.symbols.RuntimeCodeStart, profile.runtimeBase);
    assert.equal(result.symbols.RuntimeCodeEnd, profile.runtimeBase + profile.expectedLength);
    assert.equal(result.symbols.NucleusRuntimeIdentity, profile.identity);
    assert.equal(result.symbols.NucleusRuntimeExpectedLength, profile.expectedLength);
    assert.equal(result.symbols.NucleusRuntimeStateLength, profile.stateLength);
    assert.equal(result.symbols.NucleusRuntimeVectorLength, profile.vectorLength);
    assert.equal(result.symbols.StateEnd - result.symbols.StateBase, profile.stateLength);
    assert.equal(result.symbols.RunReady, profile.runReady);
    assert.equal(result.symbols.ActivationCapacity, profile.activationCapacity);
    for (const [name, offset] of Object.entries(profile.helperOffsets)) {
      assert.equal(result.addresses[name] - profile.runtimeBase, offset, name);
      assert.equal(result.symbols[`NucleusRuntime${name.replace(/^Runtime/, "")}Offset`], offset, name);
    }
    assert.equal(result.symbols.NucleusRuntimeRunStateOffset, profile.runStateOffset);
    assert.equal(result.symbols.NucleusRuntimeActivationLimitOffset, profile.activationLimitOffset);
    assert.equal(result.symbols.NucleusRuntimeCurrentBankOffset, profile.currentBankOffset);
    assert.equal(result.symbols.NucleusRuntimeProgramDataBaseOffset, profile.programDataBaseOffset);
    assert.equal(result.symbols.NucleusRuntimeProgramDataCapacityOffset, profile.programDataCapacityOffset);
    assert.equal(result.symbols.RootSP, profile.stateBase + 17);
    assert.equal(result.symbols.RootIX, profile.stateBase + 19);
    assert.equal(Object.hasOwn(result.symbols, "RTSTART"), false);
    assert.equal(Object.hasOwn(result.symbols, "RUNREADY"), false);
    for (const name of ["loop-z80-runtime.asm", "nucleus-runtime-identity.asmi"]) {
      const part = result.project.parts.find(part => part.logicalIdentity === name);
      assert.ok(part, name);
      assert.deepEqual(Buffer.from(part.originalBytes), await readFile(new URL(`../asm/vertical-slice/${name}`, import.meta.url)));
    }
  });
}

test("native runtime distinguishes wrapped end label from top-fitting physical end", async () => {
  const length = catalog[0].expectedLength;
  const result = await assembleNativeRuntime({ ...contextFor(catalog[0]), runtimeBase: 0x10000 - length, readOnlyBase: 0 });
  assert.equal(result.symbols.RuntimeCodeEnd, 0);
  assert.equal(result.generation.highWater, 0x10000);
  assert.equal(result.generation.finalCursor, 0x10000);
  const addresses = parseIntelHex(result.hex).writeRanges.flatMap(({ start, end }) =>
    Array.from({ length: end - start }, (_, offset) => start + offset));
  assert.deepEqual(addresses, Array.from({ length }, (_, offset) => 0x10000 - length + offset));
  await assert.rejects(assembleNativeRuntime({ ...contextFor(catalog[0]), runtimeBase: 0x10001 - length, readOnlyBase: 0 }), error => {
    assert.equal(error.name, "AtomAssemblyError");
    assert.equal(error.category, "output");
    return true;
  });
});

test("numeric context rejects out-of-range inputs instead of truncating them", async () => {
  for (const name of Object.keys(contextFor(catalog[0]))) {
    for (const value of [-1, 65536, 1.5, NaN]) {
      await assert.rejects(assembleNativeRuntime({ ...contextFor(catalog[0]), [name]: value }), new RegExp(`${name} is outside 0..65535`));
    }
  }
});
