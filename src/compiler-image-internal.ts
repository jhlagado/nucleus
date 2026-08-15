import { parseIntelHex } from "@jhlagado/debug80-runtime";

import {
  debugCompilerHex,
  debugCompilerSymbols,
  normalCompilerHex,
  normalCompilerSymbols,
} from "./generated-compiler-images.js";

export interface NucleusCompilerImageDefinition {
  readonly hex: string;
  readonly symbols: Readonly<Record<string, number>>;
}

export interface NucleusCompilerImagePair {
  readonly normal: NucleusCompilerImageDefinition;
  readonly debug: NucleusCompilerImageDefinition;
}

export interface LoadedNucleusCompilerImage {
  readonly program: ReturnType<typeof parseIntelHex>;
  readonly symbols: Readonly<Record<string, number>>;
}

export const productionCompilerImages: NucleusCompilerImagePair = {
  normal: { hex: normalCompilerHex, symbols: normalCompilerSymbols },
  debug: { hex: debugCompilerHex, symbols: debugCompilerSymbols },
};

// This symbol is intentionally absent from the package export map. Tests use
// it to run a replacement image beside the production compiler without adding
// compiler selection to Host API 1 or the CLI.
export const nucleusCompilerImages = Symbol("nucleusCompilerImages");

export interface NucleusCompilerImageSelection {
  readonly [nucleusCompilerImages]?: NucleusCompilerImagePair;
}

const loadedImages = new WeakMap<
  NucleusCompilerImagePair,
  Map<boolean, Promise<LoadedNucleusCompilerImage>>
>();

export const loadNucleusCompilerImage = async (
  pair: NucleusCompilerImagePair,
  debugHooks: boolean,
): Promise<LoadedNucleusCompilerImage> => {
  let pairCache = loadedImages.get(pair);
  if (pairCache === undefined) {
    pairCache = new Map();
    loadedImages.set(pair, pairCache);
  }
  let pending = pairCache.get(debugHooks);
  if (pending === undefined) {
    const definition = debugHooks ? pair.debug : pair.normal;
    pending = Promise.resolve({
      program: parseIntelHex(definition.hex),
      symbols: definition.symbols,
    });
    pairCache.set(debugHooks, pending);
  }
  return await pending;
};
