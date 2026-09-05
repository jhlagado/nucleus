import assert from "node:assert/strict";
import test from "node:test";
import { omitGrammarDisplacements } from "./omit-grammar-displacements.mjs";

test("grammar-private EQU filtering leaves the generation and unrelated names intact", () => {
  const result = Object.freeze({
    symbols: Object.freeze({ LLOFR0: 0, LLOFR46: 19, LLOFP81: 193, LLOFPHI: 198, LLOFPEND: 194, LLOFP82: 9, Public: 42 }),
    addresses: Object.freeze({ Public: 42 }), generation: Object.freeze({}), hex: "unchanged",
  });
  const filtered = omitGrammarDisplacements(result);
  assert.deepEqual(filtered.symbols, { LLOFP82: 9, Public: 42 });
  assert.equal(result.symbols.LLOFR46, 19);
  assert.equal(filtered.generation, result.generation);
  assert.equal(filtered.addresses, result.addresses);
  assert.equal(filtered.hex, result.hex);
});

test("unrelated dictionaries pass through without replacement", () => {
  const result = { symbols: { Public: 42 }, addresses: { Public: 42 } };
  assert.equal(omitGrammarDisplacements(result), result);
});

test("private grammar labels cannot be silently hidden as equates", () => {
  assert.throws(() => omitGrammarDisplacements({
    symbols: { LLOFPHI: 42 }, addresses: { LLOFPHI: 42 },
  }), /must be an EQU, not an address: LLOFPHI/);
});
