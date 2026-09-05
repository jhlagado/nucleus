// Canonical tokenizer proof assembly. Maps affect returned names, never input.
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { assembleNativeSource } from "./assemble-native-source.mjs";
import { restoreMemoryMapLimit } from "./restore-memory-map-limit.mjs";
import { omitTokenizerDisplacements } from "./omit-tokenizer-displacements.mjs";

const root = fileURLToPath(new URL("../", import.meta.url));
const exportMap = Object.assign({}, ...[
  "atom-runtime-symbols.json", "atom-cpm-source-symbols.json",
  "atom-cpm-program-symbols.json", "atom-cpm-adapters-symbols.json",
  "atom-resolver-symbols.json",
  "atom-memory-symbols.json", "atom-state-symbols.json", "atom-tokenizer-symbols.json",
].map(name => JSON.parse(readFileSync(new URL(`../asm/${name}`, import.meta.url), "utf8"))));
const traceExports = {
  CompilerCodeStart: "TTCCODE", CompilerCodeEnd: "TTCEND",
  CompilerImmutableStart: "TTIDATA", CompilerImmutableEnd: "TTIEND",
  CompilerCoreEnd: "TTCOREND", CompilerSetDiagnostic: "TTDGSET",
  TokenizerTracePart1: "TTPART1", TokenizerTracePart1End: "TTP1END",
  TokenizerTracePart2: "TTPART2", TokenizerTracePart2End: "TTP2END",
  TokenizerTracePart3: "TTPART3", TokenizerTracePart3End: "TTP3END",
  TokenizerTraceParts: "TTPARTS", ProofStart: "TTSTART",
  TokenizerTraceNext: "TTNEXT", ProofFailure: "TTFAIL",
  TokenizerExpectedTrace: "TTEXPECT", ProofStatus: "TTSTATUS",
  ProofCase: "TTCASE", ProofEnd: "TTEND",
};
const common = {
  NativeStreamingSource: 0, SegmentedOutput: 0, TargetStreamingOutput: 0,
  LegacyCompilerSlices: 0, AggregateCallSlices: 1, Stage7LL1: 1,
};
async function assemble(entry, definitions, extra = {}) {
  const result = omitTokenizerDisplacements(restoreMemoryMapLimit(await assembleNativeSource({
    root, entry, definitions, exportMap: { ...exportMap, ...extra },
  })));
  return { ...result, symbols: { ...result.symbols, ...definitions } };
}
export const assembleNativeTokenizerTrace = () => assemble(
  "asm/vertical-slice/tokenizer-trace-proof.asm", common, traceExports,
);

// Test-only transport/diagnostic bridge, surrounding the actual production
// tokenizer, source adapter, native source host and canonical state/map.
export const assembleNativeTokenizerHostProof = () => assemble(
  "test/fixtures/native-tokenizer/host.asm",
  { ...common, NativeStreamingSource: 1, SegmentedOutput: 1,
    TargetStreamingOutput: 1, DebugHooks: 0 },
  {
    NativeHostSourceNextChunkPort: "THPCHUNK", NativeHostRetainNamePort: "THPRET",
    NativeHostCompareNamePort: "THPCMP", NativeHostMaterializeNamePort: "THPMAT",
    CompilerSetDiagnostic: "THDIAG", CompilerCopyPosition: "DGCOPYP",
    TokenizerHostProofStart: "THSTART", TokenizerHostProofEnd: "THEND",
  },
);

export const assembleNativeCompilerStateProfile = ({ legacy = false, native, segmented, target }) =>
  assemble("test/fixtures/native-tokenizer/state.asm", {
    ...common, DebugHooks: 0, NativeStreamingSource: native,
    SegmentedOutput: segmented, TargetStreamingOutput: target,
    HistoricalCompilerState: Number(legacy),
  });

export const assembleNativeLoopZ80State = () =>
  assemble("test/fixtures/native-tokenizer/z80-state.asm", { TargetStreamingOutput: 0 });
