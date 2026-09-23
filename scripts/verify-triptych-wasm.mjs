import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { createHash } from "node:crypto";

const require = createRequire(import.meta.url);
const modulePath =
  process.env.TRIPTYCH_WASM_MODULE ??
  "../triptych/dist/wasm/triptych_host_wasm.js";
const { TriptychCpu } = require(modulePath);

const {
  compileNucleus,
  createDebug80ExecutionAdapter,
  createTriptychWasmExecutionAdapter,
  writeNucleusIntelHex,
} = await import("../dist/index.js");

const source = [
  "sub main() fails",
  "  writeOutputByte('K') else fail",
  "end",
  "",
].join("\n");
const request = [{ name: "main.nu", source }];
const target = { imageBase: 0x100, imageCapacity: 0x1000 };

const reference = await compileNucleus(
  request,
  target,
  { executionAdapter: createDebug80ExecutionAdapter() },
);
const triptych = await compileNucleus(
  request,
  target,
  { executionAdapter: createTriptychWasmExecutionAdapter({ TriptychCpu }) },
);

assert.equal(reference.success, true);
assert.equal(triptych.success, true);
assert.equal(triptych.nobj.length, reference.nobj.length);
assert.deepEqual(triptych.nobj, reference.nobj);
assert.equal(
  triptych.materialized.flatImage.length,
  reference.materialized.flatImage.length,
);
assert.deepEqual(
  Array.from(triptych.materialized.flatImage),
  Array.from(reference.materialized.flatImage),
);

const hex = writeNucleusIntelHex(triptych);
const digest = createHash("sha256").update(hex).digest("hex");
console.log(
  JSON.stringify(
    {
      profile: "nucleus-compiler-triptych-wasm-v1",
      source: "sub main / writeOutputByte('K') / end",
      artifact: {
        nobjBytes: triptych.nobj.length,
        materializedBytes: triptych.materialized.flatImage.length,
        hexSha256: digest,
      },
      triptych: {
        instructions: triptych.instructions,
        cycles: triptych.cycles,
      },
      reference: {
        instructions: reference.instructions,
        cycles: reference.cycles,
      },
      result: "pass",
    },
    null,
    2,
  ),
);
