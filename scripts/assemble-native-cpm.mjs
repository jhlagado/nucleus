// Canonical native CP/M proof entries. ATOM consumes the source unchanged.
// These aliases preserve returned build/test names; they never rewrite input.
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { assembleNativeSource } from "./assemble-native-source.mjs";

const root = fileURLToPath(new URL("../asm/", import.meta.url));
const exportMap = Object.assign({}, ...[
  "atom-runtime-symbols.json", "atom-cpm-source-symbols.json",
  "atom-cpm-program-symbols.json", "atom-cpm-adapters-symbols.json",
].map(name => JSON.parse(readFileSync(new URL(`../asm/${name}`, import.meta.url), "utf8"))));
Object.assign(exportMap, {
  CpmHostResidentLimit: "PRRESLIM", CpmHostWorkspaceLimit: "PRWKLIM",
});
const entries = new Set([
  "cpm22-command-proof.asm", "cpm22-direct-output-proof.asm",
  "cpm22-program-provider-proof.asm", "cpm22-runtime-provider-proof.asm",
  "cpm22-publisher-proof.asm",
]);

export async function assembleNativeCpmProof(entry) {
  if (!entries.has(entry)) throw new Error(`Unsupported native CP/M proof: ${entry}`);
  const result = await assembleNativeSource({
    root, entry: `vertical-slice/${entry}`, exportMap,
  });
  // Private derived layout constant, not part of the historical public names.
  const symbols = entry === "cpm22-program-provider-proof.asm"
    ? Object.fromEntries(Object.entries(result.symbols).filter(([name]) => name !== "PGCLRLEN"))
    : result.symbols;
  return { ...result, symbols };
}
