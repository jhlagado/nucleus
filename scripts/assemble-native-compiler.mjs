// Production entry metadata and public output names. ATOM resolves each
// canonical source part directly; no input translation or numeric linking.
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { assembleNativeSource } from "./assemble-native-source.mjs";
import { compilerProfileDefinitions } from "./compiler-profile.mjs";
import { restoreMemoryMapLimit } from "./restore-memory-map-limit.mjs";
import { omitTokenizerDisplacements } from "./omit-tokenizer-displacements.mjs";
import { omitGrammarDisplacements } from "./omit-grammar-displacements.mjs";
import { omitCpmPublisherExtents } from "./omit-cpm-publisher-extents.mjs";

const exportMap = Object.assign({}, ...[
  "runtime", "cpm-source", "cpm-program", "cpm-adapters", "resolver", "memory",
  "state", "tokenizer", "grammar", "host", "diagnostic", "frontend", "backend",
  "services", "compiler", "compiler-proof",
].map(name => JSON.parse(readFileSync(new URL(`../asm/atom-${name}-symbols.json`, import.meta.url), "utf8"))));

const entries = new Map([
  ["flat-target-z80-slice-proof.asm", { debug: 0, host: "proof" }],
  ["flat-target-debug-z80-slice-proof.asm", { debug: 1, host: "proof" }],
  ["native-target-compiler.asm", { debug: 0, host: "direct" }],
  ["native-target-debug-compiler.asm", { debug: 1, host: "direct" }],
  ["native-target-mon3-compiler.asm", { debug: 0, host: "mon3" }],
  ["native-target-mon3-debug-compiler.asm", { debug: 1, host: "mon3" }],
  ["cpm22-native-compiler.asm", { debug: 0, host: "cpm" }],
]);
export const isNativeCompilerEntry = entry => entries.has(entry);

export async function assembleNativeCompiler(entry) {
  const profile = entries.get(entry);
  if (!profile) throw new Error(`Unsupported native compiler entry: ${entry}`);
  const definitions = {
    DebugHooks: profile.debug,
    NativeStreamingSource: profile.host === "proof" ? 0 : 1,
    SegmentedOutput: 1, TargetStreamingOutput: 1,
    LegacyCompilerSlices: 0, AggregateCallSlices: 1, Stage7LL1: 1,
    LegacyEncoders: 0,
    ...compilerProfileDefinitions({ AggregateCallSlices: 1, Stage7LL1: 1, TargetStreamingOutput: 1 }),
    ...(profile.host === "direct" || profile.host === "mon3"
      ? { Mon3HostTransport: profile.host === "mon3" ? 1 : 0 } : {}),
    ...(profile.host === "proof" ? { RuntimeProofServices: 1, RuntimePacketGateway: 0 } : {}),
  };
  const result = omitGrammarDisplacements(omitTokenizerDisplacements(restoreMemoryMapLimit(
    await assembleNativeSource({
      root: fileURLToPath(new URL("../", import.meta.url)),
      entry: `asm/vertical-slice/${entry}`, definitions, exportMap,
      requiredExports: ["CompilerCodeStart", "CompilerCoreEnd", "CompileTargetAggregateCallParts"],
    }),
  )));
  return omitCpmPublisherExtents({ ...result, symbols: { ...definitions, ...result.symbols } });
}
