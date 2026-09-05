export function omitStageProofOffsets<T extends {
  symbols: Record<string, number>;
  addresses: Record<string, number>;
}>(result: T): T;
