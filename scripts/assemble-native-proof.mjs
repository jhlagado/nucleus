// Historical proofs use their own canonical ATOM parts and immutable profiles.
// Compatibility applies to returned names only, never to assembly input.
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { assembleNativeSource } from "./assemble-native-source.mjs";
import { nativeEarlyProofProfiles } from "./native-early-proof-profiles.mjs";
import { nativeSliceProofProfiles } from "./native-slice-proof-profiles.mjs";
import { nativeStageProofProfiles } from "./native-stage-proof-profiles.mjs";
import { compilerProfileDefinitions } from "./compiler-profile.mjs";
import { restoreMemoryMapLimit } from "./restore-memory-map-limit.mjs";
import { omitTokenizerDisplacements } from "./omit-tokenizer-displacements.mjs";
import { omitGrammarDisplacements } from "./omit-grammar-displacements.mjs";
import { omitCpmPublisherExtents } from "./omit-cpm-publisher-extents.mjs";
import { omitStageProofOffsets } from "./omit-stage-proof-offsets.mjs";
import { omitSliceProofOffsets } from "./omit-slice-proof-offsets.mjs";

const profiles = Object.freeze({
  ...nativeEarlyProofProfiles, ...nativeSliceProofProfiles, ...nativeStageProofProfiles,
});
const exportMap = Object.assign({}, ...[
  "runtime", "cpm-source", "cpm-program", "cpm-adapters", "resolver", "memory",
  "state", "tokenizer", "grammar", "host", "diagnostic", "frontend", "backend",
  "services", "compiler", "compiler-proof", "early-proof", "slice-proof", "stage-proof",
].map(name => JSON.parse(readFileSync(new URL(`../asm/atom-${name}-symbols.json`, import.meta.url), "utf8"))));

export const isNativeProofEntry = entry => Object.hasOwn(profiles, entry);

export async function assembleNativeProof(entry) {
  if (!isNativeProofEntry(entry)) throw new Error(`Unsupported native proof entry: ${entry}`);
  const published = profiles[entry];
  const choices = {
    DebugHooks: 0, NativeStreamingSource: 0, SegmentedOutput: 0,
    TargetStreamingOutput: 0, AggregateCallSlices: 0, Stage7LL1: 0,
    LegacyCompilerSlices: 0, LegacyEncoders: 0,
    RuntimeProofServices: 0, RuntimePacketGateway: 0,
    ...published,
  };
  const definitions = { ...choices, ...compilerProfileDefinitions(choices) };
  const result = omitCpmPublisherExtents(omitGrammarDisplacements(omitTokenizerDisplacements(
    restoreMemoryMapLimit(await assembleNativeSource({
      root: fileURLToPath(new URL("../", import.meta.url)),
      entry: `asm/vertical-slice/${entry}`, definitions, exportMap,
    })),
  )));
  return omitSliceProofOffsets(omitStageProofOffsets({
    ...result, symbols: { ...published, ...result.symbols },
  }));
}
