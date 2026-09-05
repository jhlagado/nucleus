// Source-authored, late EQU offsets remain in ATOM's generation. The historical
// proof dictionary did not contain these private names; no input is rewritten.
const privateNames = new Set([
  "P7CSTLEO",
  "P7CSTIDO",
  "P7DCAREO",
  "P7BCAREO",
  "P7WREREO",
  "P7SARCAO",
  "P7RTCAPO",
  "P7PACAPO",
  "P7ROWASO",
  "P7ROFASO",
  "P7ROAASO",
  "P7ROSASO",
  "P7ACSINO",
  "P7ACWTYO",
  "P7ACSRUO",
  "P7ACSTYO",
  "P7ROCREO",
]);

export function omitStageProofOffsets(result) {
  const present = Object.keys(result.symbols).filter(name => privateNames.has(name));
  if (present.length === 0) return result;
  for (const name of present) {
    if (Object.hasOwn(result.addresses, name)) {
      throw new Error(`Private stage proof offset must be an EQU, not an address: ${name}`);
    }
  }
  return { ...result, symbols: Object.fromEntries(Object.entries(result.symbols)
    .filter(([name]) => !privateNames.has(name))) };
}
