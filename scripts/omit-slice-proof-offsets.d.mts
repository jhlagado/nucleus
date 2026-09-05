export function omitSliceProofOffsets<T extends {
  readonly symbols: Readonly<Record<string, number>>;
  readonly addresses: Readonly<Record<string, number>>;
}>(result: T): T;
