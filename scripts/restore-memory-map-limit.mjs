// Output metadata only. Z80 source declares the last address, not a wrapped
// representation of the host's mathematical exclusive address-space limit.
export function restoreMemoryMapLimit(result) {
  const last = result.generation.symbols.find(symbol => symbol.name === "MMLAST");
  if (last === undefined) return result;
  if (!Number.isInteger(last.value) || last.value < 0 || last.value > 0xffff) {
    throw new RangeError("Native memory-map last address is outside 0..65535");
  }
  if (result.symbols.AddressSpaceLimit !== last.value || Object.hasOwn(result.symbols, "MMLAST")) {
    throw new Error("Native memory-map limit requires its explicit output-name mapping");
  }
  return { ...result, symbols: { ...result.symbols, AddressSpaceLimit: last.value + 1 } };
}
