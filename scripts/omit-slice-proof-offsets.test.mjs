import assert from "node:assert/strict";
import test from "node:test";
import { omitSliceProofOffsets } from "./omit-slice-proof-offsets.mjs";

test("slice filtering removes only four private constant keys without changing assembly", () => {
  const symbols = Object.freeze({ QTDIVPOS: 91, QTNARPOS: 87,
    QGIMGLEN: 24, QCLABPOS: 149, QTDIVOTHER: 7, ProofStart: 0x9000 });
  const result = Object.freeze({ symbols,
    addresses: Object.freeze({ ProofStart: 0x9000 }),
    generation: Object.freeze({ symbols: [] }), project: Object.freeze({ parts: [] }),
    hex: "unchanged" });
  const filtered = omitSliceProofOffsets(result);
  assert.deepEqual(filtered.symbols, { QTDIVOTHER: 7, ProofStart: 0x9000 });
  assert.equal(result.symbols, symbols);
  assert.equal(result.symbols.QTDIVPOS, 91);
  for (const key of ["addresses", "generation", "project", "hex"])
    assert.equal(filtered[key], result[key]);
});

test("unrelated proof results retain their identity", () => {
  const result = Object.freeze({ symbols: { QTDIVOTHER: 7 }, addresses: {} });
  assert.equal(omitSliceProofOffsets(result), result);
});

for (const name of ["QTDIVPOS", "QTNARPOS", "QGIMGLEN", "QCLABPOS"]) {
  test(`slice filtering refuses an address named ${name}`, () => {
    assert.throws(() => omitSliceProofOffsets({
      symbols: { [name]: 0x9000 }, addresses: { [name]: 0x9000 },
    }), new RegExp(`must be an EQU, not an address: ${name}`));
  });
}
