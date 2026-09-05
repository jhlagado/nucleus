import assert from "node:assert/strict";
import test from "node:test";
import { omitTokenizerDisplacements } from "./omit-tokenizer-displacements.mjs";

test("private tokenizer EQU filtering changes only the public dictionary", () => {
  const symbols = Object.freeze({ KeywordTable: 0x100, KWDISP2: 7, KWDISP8: 184, KWDISP9: 99 });
  const result = Object.freeze({ symbols, addresses: Object.freeze({ KeywordTable: 0x100 }),
    generation: Object.freeze({ symbols: [{ name: "KWDISP2", value: 7 }] }), hex: "unchanged" });
  const filtered = omitTokenizerDisplacements(result);
  assert.deepEqual(filtered.symbols, { KeywordTable: 0x100, KWDISP9: 99 });
  assert.equal(result.symbols, symbols);
  assert.equal(result.symbols.KWDISP2, 7);
  assert.equal(filtered.addresses, result.addresses);
  assert.equal(filtered.generation, result.generation);
  assert.equal(filtered.hex, result.hex);
});

test("an unrelated assembly result passes through by identity", () => {
  const result = { symbols: { KeywordTable: 0x100 }, addresses: {} };
  assert.equal(omitTokenizerDisplacements(result), result);
});

test("filtering refuses to hide a private displacement defined as an address", () => {
  assert.throws(() => omitTokenizerDisplacements({
    symbols: { KWDISP2: 0x100 }, addresses: { KWDISP2: 0x100 },
  }), /must be an EQU, not an address: KWDISP2/);
});
