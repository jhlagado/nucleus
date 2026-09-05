/** Private build boundary, not part of the installed Nucleus host API. */
export function assembleNativeSource(options: {
  readonly root: string;
  readonly entry: string;
  readonly definitions?: Readonly<Record<string, number>>;
  readonly target?: { readonly start: number; readonly capacity: number };
  /** Public name -> exact native ATOM name. Missing conditional names are omitted. */
  readonly exportMap?: Readonly<Record<string, string>>;
  /** Final dictionary keys that must exist, including required mapped names. */
  readonly requiredExports?: readonly string[];
}): Promise<{
  readonly hex: string;
  readonly symbols: Readonly<Record<string, number>>;
  readonly addresses: Readonly<Record<string, number>>;
  readonly generation: {
    readonly highWater: number;
    readonly finalCursor: number;
    readonly images: readonly {
      readonly address: number;
      readonly bytes: readonly number[];
    }[];
    readonly patches: readonly {
      readonly address: number;
      readonly bytes: readonly number[];
    }[];
  };
  readonly project: {
    readonly parts: readonly {
      readonly logicalIdentity: string;
      readonly originalBytes: Uint8Array;
      readonly compilerBytes: Uint8Array;
    }[];
  };
  readonly instructions: number;
}>;
