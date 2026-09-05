// Source-authored forward EQU values, not additional public host symbols.
// Leave ATOM's generation, sparse writes and source provenance untouched.
const privateNames = ["PBPFXLEN", "PBPFXPAD"];

export function omitCpmPublisherExtents(result) {
  for (const name of privateNames) {
    if (Object.hasOwn(result.addresses, name)) {
      throw new Error(`Private CP/M publisher extent must be an EQU, not an address: ${name}`);
    }
  }
  if (!privateNames.some(name => Object.hasOwn(result.symbols, name))) return result;
  return { ...result, symbols: Object.fromEntries(Object.entries(result.symbols)
    .filter(([name]) => !privateNames.includes(name))) };
}
