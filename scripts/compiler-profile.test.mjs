import assert from "node:assert/strict";
import test from "node:test";
import { compilerProfileDefinitions } from "./compiler-profile.mjs";

test("native compiler profiles preserve the eight historical flag combinations", () => {
  // Independent truth table: aggregate, Stage7, target => full grammar, nonlocal.
  const rows = [
    [0, 0, 0, 0, 0], [0, 0, 1, 0, 0],
    [0, 1, 0, 0, 0], [0, 1, 1, 0, 0],
    [1, 0, 0, 0, 0], [1, 0, 1, 0, 1],
    [1, 1, 0, 1, 0], [1, 1, 1, 1, 1],
  ];
  for (const [aggregate, stage7, target, full, nonlocal] of rows) {
    assert.deepEqual(compilerProfileDefinitions({
      AggregateCallSlices: aggregate, Stage7LL1: stage7, TargetStreamingOutput: target,
    }), {
      HybridLL1Full: full, CompilerNonlocalDiagnostics: nonlocal,
      CompilerDiagnosticReturns: nonlocal ? 0 : 1,
      CompilerDiagnosticBranches: nonlocal ? 0 : 1,
    });
  }
});

test("older profiles may omit Stage7; inputs remain unchanged", () => {
  const profile = Object.freeze({ AggregateCallSlices: 0, TargetStreamingOutput: 0 });
  assert.deepEqual(compilerProfileDefinitions(profile), {
    HybridLL1Full: 0, CompilerNonlocalDiagnostics: 0,
    CompilerDiagnosticReturns: 1, CompilerDiagnosticBranches: 1,
  });
  assert.equal(Object.hasOwn(profile, "Stage7LL1"), false);
});

test("profiles reject coercion and missing required switches", () => {
  const valid = { AggregateCallSlices: 1, Stage7LL1: 1, TargetStreamingOutput: 1 };
  for (const name of Object.keys(valid)) {
    for (const value of [true, false, "1", "0", null, -1, 2, NaN, Infinity]) {
      assert.throws(() => compilerProfileDefinitions({ ...valid, [name]: value }), TypeError);
    }
  }
  for (const name of ["AggregateCallSlices", "Stage7LL1", "TargetStreamingOutput"]) {
    const incomplete = { ...valid };
    delete incomplete[name];
    assert.throws(() => compilerProfileDefinitions(incomplete), TypeError);
  }
});
