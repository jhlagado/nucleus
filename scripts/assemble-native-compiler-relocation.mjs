// Relocation qualification uses one unchanged canonical compiler composition.
// ATOM's target.start initializes its cursor; no ORG text is substituted.
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { assembleNativeSource } from "./assemble-native-source.mjs";
import { compilerProfileDefinitions } from "./compiler-profile.mjs";
import { restoreMemoryMapLimit } from "./restore-memory-map-limit.mjs";
import { omitTokenizerDisplacements } from "./omit-tokenizer-displacements.mjs";
import { omitGrammarDisplacements } from "./omit-grammar-displacements.mjs";

const exportMap = Object.assign({}, ...[
  "runtime", "cpm-source", "cpm-program", "cpm-adapters", "resolver", "memory",
  "state", "tokenizer", "grammar", "host", "diagnostic", "frontend", "backend",
  "services", "compiler", "compiler-proof",
].map(name => JSON.parse(readFileSync(new URL(`../asm/atom-${name}-symbols.json`, import.meta.url), "utf8"))));

export async function assembleNativeCompilerRelocation(origin) {
  if (!Number.isInteger(origin) || origin < 0 || origin > 0xffff) {
    throw new RangeError("Compiler origin must be a 16-bit integer address");
  }
  const definitions = {
    DebugHooks: 0, NativeStreamingSource: 0,
    SegmentedOutput: 1, TargetStreamingOutput: 1,
    LegacyCompilerSlices: 0, AggregateCallSlices: 1, Stage7LL1: 1,
    LegacyEncoders: 0,
    ...compilerProfileDefinitions({ AggregateCallSlices: 1, Stage7LL1: 1, TargetStreamingOutput: 1 }),
  };
  const result = omitGrammarDisplacements(omitTokenizerDisplacements(restoreMemoryMapLimit(
    await assembleNativeSource({
      root: fileURLToPath(new URL("../", import.meta.url)),
      entry: "test/fixtures/native-compiler-relocation/entry.asm",
      definitions, exportMap,
      target: { start: origin, capacity: Math.min(0xffff, 0x10000 - origin) },
      requiredExports: ["CompilerCodeStart", "CompilerCoreEnd", "CompileTargetAggregateCallParts"],
    }),
  )));
  return { ...result, symbols: { ...definitions, ...result.symbols } };
}
