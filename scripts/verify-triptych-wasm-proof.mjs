import assert from "node:assert/strict";
import { createRequire } from "node:module";
import path from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const modulePath =
  process.env.TRIPTYCH_WASM_MODULE ??
  "../triptych/dist/wasm/triptych_host_wasm.js";
const { TriptychCpu } = require(modulePath);

const {
  createDebug80ExecutionAdapter,
  createTriptychWasmExecutionAdapter,
} = await import("../dist/index.js");
const { runProofManifest } = await import("../dist/proof.js");

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const proof = (name) => path.join(root, "proofs", `${name}.json`);
const referenceAdapter = createDebug80ExecutionAdapter();
const triptychAdapter = createTriptychWasmExecutionAdapter({ TriptychCpu });

const compare = async (name) => {
  const reference = await runProofManifest(proof(name), {
    executionAdapter: referenceAdapter,
  });
  const triptych = await runProofManifest(proof(name), {
    executionAdapter: triptychAdapter,
  });
  // Instruction counts are an implementation detail of the two CPU cores;
  // cycle totals and observable memory are the cross-host contract.
  assert.equal(triptych.cycles, reference.cycles);
  assert.deepEqual(Array.from(triptych.memory), Array.from(reference.memory));
  assert.deepEqual(triptych.symbols, reference.symbols);
  if (reference.nobj === undefined || triptych.nobj === undefined) {
    assert.equal(triptych.nobj, reference.nobj);
  } else {
    assert.deepEqual(Array.from(triptych.nobj.serialized), Array.from(reference.nobj.serialized));
    assert.deepEqual(Array.from(triptych.nobj.memory), Array.from(reference.nobj.memory));
    assert.equal(triptych.nobj.cycles, reference.nobj.cycles);
    assert.equal(triptych.nobj.selectedBank, reference.nobj.selectedBank);
  }
  return {
    name,
    instructions: {
      reference: reference.instructions,
      triptych: triptych.instructions,
    },
    cycles: triptych.cycles,
    nobj: triptych.nobj === undefined ? false : true,
  };
};

const results = [];
for (const name of [
  "memory-map-proof",
  "nobj-runner-proof",
  "banked-target-z80-slice-proof",
]) {
  results.push(await compare(name));
}

console.log(
  JSON.stringify(
    {
      profile: "nucleus-proof-triptych-wasm-v1",
      results,
      result: "pass",
    },
    null,
    2,
  ),
);
