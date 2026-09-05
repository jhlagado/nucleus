export function compilerProfileDefinitions(profile: {
  AggregateCallSlices: number;
  Stage7LL1?: number;
  TargetStreamingOutput: number;
}): {
  HybridLL1Full: number;
  CompilerNonlocalDiagnostics: number;
  CompilerDiagnosticReturns: number;
  CompilerDiagnosticBranches: number;
};
