import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { assembleNativeSource } from "./assemble-native-source.mjs";
import { restoreMemoryMapLimit } from "./restore-memory-map-limit.mjs";
import { compilerProfileDefinitions } from "./compiler-profile.mjs";

const root = fileURLToPath(new URL("../", import.meta.url));
const exportMap = Object.assign({}, ...[
  "atom-runtime-symbols.json", "atom-cpm-source-symbols.json",
  "atom-cpm-program-symbols.json", "atom-cpm-adapters-symbols.json",
  "atom-resolver-symbols.json", "atom-memory-symbols.json",
  "atom-state-symbols.json", "atom-tokenizer-symbols.json",
  "atom-diagnostic-symbols.json",
].map(name => JSON.parse(readFileSync(new URL(`../asm/${name}`, import.meta.url), "utf8"))));

export async function assembleNativeDiagnostics(nonlocal) {
  if (typeof nonlocal !== "boolean") throw new TypeError("nonlocal must be boolean");
  const base = {
    DebugHooks: 0, NativeStreamingSource: 0, SegmentedOutput: Number(nonlocal),
    TargetStreamingOutput: Number(nonlocal), LegacyCompilerSlices: 0,
    AggregateCallSlices: 1, Stage7LL1: 1,
  };
  const definitions = { ...base, ...compilerProfileDefinitions(base) };
  const result = restoreMemoryMapLimit(await assembleNativeSource({
    root, entry: "test/fixtures/native-diagnostics/entry.asm", definitions, exportMap,
    requiredExports: ["CompilerSetDiagnostic", "SetDiagInline",
      "CompilerCopyTokenPosition", "CompilerCopyPosition", "CompilerRestoreTokenPosition"],
  }));
  return { ...result, symbols: { ...result.symbols, ...definitions } };
}
