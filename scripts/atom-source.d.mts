/** Private development/build adapter. Not part of the installed host API. */
export function assembleAtomSource(
  entry: string,
  options?: { overrides?: Map<string, string>; target?: { start: number; capacity: number } },
): Promise<{
  hex: string;
  symbols: Record<string, number>;
  addresses: Record<string, number>;
  generation: { highWater: number; finalCursor: number };
  instructions: number;
}>;
