// Published build choices of the six historical compiler proofs. These flags
// select existing code; they do not rewrite source or supply numeric addresses.
import { compilerProfileDefinitions } from "./compiler-profile.mjs";

function profile(legacyCompiler, legacyEncoders) {
  return Object.freeze({
    NativeStreamingSource: 0,
    SegmentedOutput: 0,
    TargetStreamingOutput: 0,
    LegacyCompilerSlices: legacyCompiler,
    AggregateCallSlices: 0,
    ...compilerProfileDefinitions({
      AggregateCallSlices: 0, TargetStreamingOutput: 0,
    }),
    LegacyEncoders: legacyEncoders,
    RuntimeProofServices: 1,
    RuntimePacketGateway: 0,
  });
}

export const nativeSliceProofProfiles = Object.freeze({
  "typed-expression-z80-slice-proof.asm": profile(1, 0),
  "aggregate-z80-slice-proof.asm": profile(0, 0),
  "structured-control-z80-slice-proof.asm": profile(1, 0),
  "array-z80-slice-proof.asm": profile(1, 1),
  "call-z80-slice-proof.asm": profile(1, 1),
  "expression-z80-slice-proof.asm": profile(1, 1),
});
