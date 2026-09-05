import assert from "node:assert/strict";
import test from "node:test";
import { omitCpmPublisherExtents } from "./omit-cpm-publisher-extents.mjs";

test("publisher extent filtering changes only its two private dictionary keys", () => {
  const symbols = Object.freeze({ CpmEmbeddedPrefix: 0x5000,
    PBPFXLEN: 876, PBPFXPAD: 916, PBPFXOTHER: 17 });
  const result = Object.freeze({ symbols,
    addresses: Object.freeze({ CpmEmbeddedPrefix: 0x5000 }),
    generation: Object.freeze({ symbols: [{ name: "PBPFXLEN", value: 876 }] }),
    project: Object.freeze({ parts: [] }), hex: "unchanged" });
  const filtered = omitCpmPublisherExtents(result);
  assert.deepEqual(filtered.symbols, { CpmEmbeddedPrefix: 0x5000, PBPFXOTHER: 17 });
  assert.equal(result.symbols, symbols);
  assert.equal(result.symbols.PBPFXLEN, 876);
  assert.equal(result.symbols.PBPFXPAD, 916);
  for (const key of ["addresses", "generation", "project", "hex"]) {
    assert.equal(filtered[key], result[key]);
  }
});

test("assemblies without publisher extents pass through by identity", () => {
  const result = Object.freeze({ symbols: Object.freeze({ PBPFXOTHER: 1 }), addresses: {} });
  assert.equal(omitCpmPublisherExtents(result), result);
});

for (const name of ["PBPFXLEN", "PBPFXPAD"]) {
  test(`publisher filtering refuses an address named ${name}`, () => {
    assert.throws(() => omitCpmPublisherExtents({
      symbols: { [name]: 0x5000 }, addresses: { [name]: 0x5000 },
    }), new RegExp(`must be an EQU, not an address: ${name}`));
  });
}
