// Direct assembly of the production engine/tables through their real proof.
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { assembleNativeSource } from "./assemble-native-source.mjs";
import { compilerProfileDefinitions } from "./compiler-profile.mjs";
import { restoreMemoryMapLimit } from "./restore-memory-map-limit.mjs";
import { omitGrammarDisplacements } from "./omit-grammar-displacements.mjs";

const exportMap = Object.assign({}, ...[
  "atom-runtime-symbols.json", "atom-cpm-source-symbols.json",
  "atom-cpm-program-symbols.json", "atom-cpm-adapters-symbols.json",
  "atom-resolver-symbols.json", "atom-memory-symbols.json",
  "atom-state-symbols.json", "atom-tokenizer-symbols.json",
  "atom-grammar-symbols.json", "atom-diagnostic-symbols.json",
].map(name => JSON.parse(readFileSync(new URL(`../asm/${name}`, import.meta.url), "utf8"))));
const proofExports = {
  ParserPeekReady: "LGPEEKRD", ParserTake: "LGTAKE", ParserTakeFailure: "LGTAKEER",
  HybridLL1MeasuredStart: "LGMEAS", HybridLL1MeasuredEnd: "LGMEASEN",
  MockTokenStream: "LGTOKENS", MockTokenStreamEnd: "LGTOKEND",
  ProofStart: "LGSTART", ProofFailure: "LGFAIL", ProofStatus: "LGSTATUS",
  MockTokenCursor: "LGCURSOR", MockPeekFailure: "LGPEEKFL",
  ProofExpectedSP: "LGSP", ProofEnd: "LGEND",
};

export async function assembleNativeGrammarProof() {
  const profile = { AggregateCallSlices: 0, TargetStreamingOutput: 0 };
  const derived = compilerProfileDefinitions(profile);
  const publishedDefinitions = {
    NativeStreamingSource: 0, SegmentedOutput: 0, ...profile,
    CompilerDiagnosticReturns: derived.CompilerDiagnosticReturns,
    CompilerDiagnosticBranches: derived.CompilerDiagnosticBranches,
  };
  const result = omitGrammarDisplacements(restoreMemoryMapLimit(await assembleNativeSource({
    root: fileURLToPath(new URL("../", import.meta.url)),
    entry: "asm/vertical-slice/stage7-ll1-engine-proof.asm",
    definitions: { ...publishedDefinitions, ...derived },
    exportMap: { ...exportMap, ...proofExports },
    requiredExports: ["HybridLL1Parse", "HybridLL1EngineEnd", "HybridLL1TablesEnd", "ProofStart", "ProofEnd"],
  })));
  return { ...result, symbols: { ...result.symbols, ...publishedDefinitions } };
}
