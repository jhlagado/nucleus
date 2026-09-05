// Immutable build choices for native compiler compositions, not source rewriting.
export function compilerProfileDefinitions({
  AggregateCallSlices,
  Stage7LL1,
  TargetStreamingOutput,
}) {
  // Older non-aggregate compositions never evaluate the Stage7 switch.
  if (Stage7LL1 === undefined && AggregateCallSlices === 0) Stage7LL1 = 0;
  for (const [name, value] of Object.entries({ AggregateCallSlices, Stage7LL1, TargetStreamingOutput })) {
    if (value !== 0 && value !== 1) {
      throw new TypeError(`${name} must be the numeric build flag 0 or 1`);
    }
  }
  const nonlocal = AggregateCallSlices & TargetStreamingOutput;
  return {
    HybridLL1Full: AggregateCallSlices & Stage7LL1,
    CompilerNonlocalDiagnostics: nonlocal,
    CompilerDiagnosticReturns: 1 - nonlocal,
    CompilerDiagnosticBranches: 1 - nonlocal,
  };
}
