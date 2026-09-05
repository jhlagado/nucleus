// Native host-fragment qualification; name maps affect returned dictionaries only.
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { assembleNativeSource } from "./assemble-native-source.mjs";
import { restoreMemoryMapLimit } from "./restore-memory-map-limit.mjs";

const root = fileURLToPath(new URL("../", import.meta.url));
const exportMap = Object.assign({}, ...[
  "atom-runtime-symbols.json", "atom-cpm-source-symbols.json",
  "atom-cpm-program-symbols.json", "atom-cpm-adapters-symbols.json",
  "atom-memory-symbols.json", "atom-resolver-symbols.json",
  "atom-state-symbols.json", "atom-tokenizer-symbols.json",
  "atom-host-symbols.json",
].map(name => JSON.parse(readFileSync(new URL(`../asm/${name}`, import.meta.url), "utf8"))));

export async function assembleNativeHostBindings({ mon3, debug }) {
  if (![0, 1].includes(mon3) || ![0, 1].includes(debug)) {
    throw new TypeError("Host transport and debug flags must be numeric 0 or 1");
  }
  const definitions = {
    DebugHooks: debug, NativeStreamingSource: 1, Mon3HostTransport: mon3,
    AggregateCallSlices: 1, Stage7LL1: 1, LegacyCompilerSlices: 0,
    SegmentedOutput: 1, TargetStreamingOutput: 1,
  };
  const result = restoreMemoryMapLimit(await assembleNativeSource({
    root, entry: "test/fixtures/native-host-bindings/entry.asm",
    definitions, exportMap,
  }));
  return { ...result, symbols: { ...result.symbols, ...definitions } };
}

export async function assembleNativeCpmHostVector({ origin }) {
  if (origin !== 0x100 && origin !== 0x8013) {
    throw new RangeError("CP/M vector proof origin must be $0100 or $8013");
  }
  return assembleNativeSource({
    root, entry: "test/fixtures/native-host-bindings/cpm.asm",
    definitions: { CpmHighHostOrigin: Number(origin === 0x8013) }, exportMap,
  });
}
