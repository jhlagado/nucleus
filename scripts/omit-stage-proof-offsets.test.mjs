import { strict as assert } from "node:assert";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { omitStageProofOffsets } from "./omit-stage-proof-offsets.mjs";
import { nativeStageProofProfiles } from "./native-stage-proof-profiles.mjs";

const names = [
  "P7CSTLEO",
  "P7CSTIDO",
  "P7DCAREO",
  "P7BCAREO",
  "P7WREREO",
  "P7SARCAO",
  "P7RTCAPO",
  "P7PACAPO",
  "P7ROWASO",
  "P7ROFASO",
  "P7ROAASO",
  "P7ROSASO",
  "P7ACSINO",
  "P7ACWTYO",
  "P7ACSRUO",
  "P7ACSTYO",
  "P7ROCREO",
];

test("only the seventeen explicit late EQU offsets are hidden, without mutation", () => {
  const generation = {};
  const symbols = Object.freeze({
    ...Object.fromEntries(names.map((name, index) => [name, index])),
    P7CSTLEP: 1234, P7CSTLEO_EXTRA: 99, ProofExpectedOffset: 5678,
  });
  const addresses = Object.freeze({ P7CSTLEP: 1234, ProofExpectedOffset: 5678 });
  const source = Object.freeze({ symbols, addresses, generation, hex: ":00000001FF\n" });
  const result = omitStageProofOffsets(source);
  assert.deepEqual(result.symbols, {
    P7CSTLEP: 1234, P7CSTLEO_EXTRA: 99, ProofExpectedOffset: 5678,
  });
  assert.equal(result.addresses, addresses);
  assert.equal(result.generation, generation);
  assert.equal(result.hex, source.hex);
  assert.equal(Object.keys(source.symbols).length, 20);
});

test("every private offset rejects a conflicting address", () => {
  for (const name of names) {
    assert.throws(() => omitStageProofOffsets({
      symbols: { [name]: 1 }, addresses: { [name]: 1 },
    }), /must be an EQU/);
  }
});

test("unrelated results remain identical", () => {
  const source = { symbols: { P7OTHER: 1 }, addresses: { P7OTHER: 1 } };
  assert.equal(omitStageProofOffsets(source), source);
});

test("private offsets are derived from the real source labels, and the profile is immutable", () => {
  const body = readFileSync(new URL("../asm/vertical-slice/stage7-aggregate-proof-body.asm", import.meta.url), "utf8");
  const declarations = [...body.matchAll(/^([A-Z][A-Z0-9]+) EQU ([A-Z][A-Z0-9]+)-([A-Z][A-Z0-9]+)$/gm)];
  assert.deepEqual(declarations.map(match => match[1]), names);
  for (const [declaration, , point, source] of declarations) {
    assert.ok(body.indexOf(point + ":") < body.indexOf(declaration));
    assert.ok(body.indexOf(source + ":") < body.indexOf(declaration));
    assert.ok(body.includes(point + ":"));
    assert.ok(body.includes(source + ":"));
  }
  assert.equal(Object.keys(nativeStageProofProfiles).length, 4);
  assert.ok(Object.isFrozen(nativeStageProofProfiles));
  for (const profile of Object.values(nativeStageProofProfiles)) {
    assert.ok(Object.isFrozen(profile));
    assert.equal(Object.keys(profile).length, 13);
    assert.equal(profile.HybridLL1Full, 1);
    assert.equal(profile.CompilerNonlocalDiagnostics, 0);
    assert.equal(profile.CompilerDiagnosticReturns, 1);
    assert.equal(profile.CompilerDiagnosticBranches, 1);
    assert.equal(Object.hasOwn(profile, "DebugHooks"), false);
  }
});
