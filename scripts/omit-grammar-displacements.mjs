import { readFileSync } from "node:fs";

// The explicit grammar map bounds this list. These source-authored EQU values
// remain in ATOM's generation; only the historical public dictionary omits them.
const grammarNames = JSON.parse(readFileSync(new URL("../asm/atom-grammar-symbols.json", import.meta.url), "utf8"));
const privateNames = new Set([
  ...Object.keys(grammarNames).flatMap(name => {
    const row = /^HybridLL1Row(\d+)$/.exec(name);
    const production = /^HybridLL1Production(\d+)$/.exec(name);
    return row ? [`LLOFR${row[1]}`] : production ? [`LLOFP${production[1]}`] : [];
  }),
  "LLOFPHI", "LLOFPEND",
]);

export function omitGrammarDisplacements(result) {
  const present = Object.keys(result.symbols).filter(name => privateNames.has(name));
  if (present.length === 0) return result;
  for (const name of present) {
    if (Object.hasOwn(result.addresses, name)) {
      throw new Error(`Private grammar displacement must be an EQU, not an address: ${name}`);
    }
  }
  return { ...result, symbols: Object.fromEntries(Object.entries(result.symbols)
    .filter(([name]) => !privateNames.has(name))) };
}
