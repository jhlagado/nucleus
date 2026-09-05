// Native, source-derived forward EQUs are implementation details, not new
// historical proof exports. Never alter generated writes or source input.
const privateNames = ["QTDIVPOS", "QTNARPOS", "QGIMGLEN", "QCLABPOS"];

export function omitSliceProofOffsets(result) {
  for (const name of privateNames) {
    if (Object.hasOwn(result.addresses, name)) {
      throw new Error(`Private slice offset must be an EQU, not an address: ${name}`);
    }
  }
  if (!privateNames.some(name => Object.hasOwn(result.symbols, name))) return result;
  return { ...result, symbols: Object.fromEntries(Object.entries(result.symbols)
    .filter(([name]) => !privateNames.includes(name))) };
}
