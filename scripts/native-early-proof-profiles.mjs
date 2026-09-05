// Original, proof-visible build choices. Not all historical profiles expose
// every modern switch; preprocessor defaults must not add public symbols.
const small = Object.freeze({ NativeStreamingSource: 0 });
const first = Object.freeze({ ...small, AggregateCallSlices: 0 });
const loop = Object.freeze({
  ...first, SegmentedOutput: 0, TargetStreamingOutput: 0,
  LegacyCompilerSlices: 1, HybridLL1Full: 0,
  CompilerNonlocalDiagnostics: 0, CompilerDiagnosticReturns: 1,
  CompilerDiagnosticBranches: 1,
});
export const nativeEarlyProofProfiles = Object.freeze({
  "memory-map-proof.asm": small,
  "dispatcher-measurement.asm": small,
  "dispatcher-offset-direct-measurement.asm": small,
  "dispatcher-offset-trampoline-measurement.asm": small,
  "compiler-slice-proof.asm": first,
  "z80-slice-proof.asm": first,
  "loop-compiler-slice-proof.asm": loop,
  "loop-z80-slice-proof.asm": Object.freeze({
    ...loop, LegacyEncoders: 1, RuntimeProofServices: 1, RuntimePacketGateway: 0,
  }),
  "cpm22-compiler-layout-proof.asm": Object.freeze({
    DebugHooks: 0, NativeStreamingSource: 1, SegmentedOutput: 1,
    TargetStreamingOutput: 1, LegacyCompilerSlices: 0, AggregateCallSlices: 1,
    Stage7LL1: 1, LegacyEncoders: 0, HybridLL1Full: 1,
    CompilerNonlocalDiagnostics: 1, CompilerDiagnosticReturns: 0,
    CompilerDiagnosticBranches: 0,
  }),
});
