// Published choices of the four historical packed-parser proofs. Addresses
// remain in canonical assembly; these immutable flags only select source.
import { compilerProfileDefinitions } from "./compiler-profile.mjs";

const profile = Object.freeze({
  NativeStreamingSource: 0,
  SegmentedOutput: 1,
  TargetStreamingOutput: 0,
  LegacyCompilerSlices: 0,
  AggregateCallSlices: 1,
  Stage7LL1: 1,
  ...compilerProfileDefinitions({
    AggregateCallSlices: 1, Stage7LL1: 1, TargetStreamingOutput: 0,
  }),
  LegacyEncoders: 0,
  RuntimeProofServices: 1,
  RuntimePacketGateway: 0,
});

export const nativeStageProofProfiles = Object.freeze({
  "stage7-ll1-aggregate-call-z80-slice-proof.asm": profile,
  "stage8-failure-z80-slice-proof.asm": profile,
  "stage9-conformance-z80-slice-proof.asm": profile,
  "stage7-ll1-parser-coverage-proof.asm": profile,
});
