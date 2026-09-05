// These source-authored forward EQU constants implement the existing keyword
// table. They are not additional public compiler symbols. Keep them in ATOM's
// generation and omit them only from the historical host dictionary.
const privateNames = ["KWDISP2", "KWDISP3", "KWDISP4", "KWDISP5", "KWDISP6", "KWDISP7", "KWDISP8"];

export function omitTokenizerDisplacements(result) {
  const present = privateNames.filter(name => Object.hasOwn(result.symbols, name));
  if (present.length === 0) return result;
  for (const name of present) {
    if (Object.hasOwn(result.addresses, name)) {
      throw new Error(`Private tokenizer displacement must be an EQU, not an address: ${name}`);
    }
  }
  return { ...result, symbols: Object.fromEntries(Object.entries(result.symbols)
    .filter(([name]) => !present.includes(name))) };
}
