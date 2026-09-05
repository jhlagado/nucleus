// ATOM 802b5c2 publishes JavaScript without declarations. This is the narrow
// public API used by these tests; no private package modules are imported.
declare module "atom-z80" {
  interface AtomGeneration {
    readonly highWater: number;
    readonly symbols: readonly {
      readonly name: string;
      readonly value: number;
    }[];
  }

  export function assembleAtomProject(options: {
    readonly root: string;
    readonly entry: string;
    readonly target: { readonly start: number; readonly capacity: number };
  }): Promise<{ readonly generation: AtomGeneration }>;

  export function materializeAtomGeneration(generation: AtomGeneration): {
    readonly bytes: Uint8Array;
  };
}
