import { parseIntelHex } from "@jhlagado/debug80-runtime";
import { debugCompilerHex, debugCompilerSymbols, normalCompilerHex, normalCompilerSymbols, } from "./generated-compiler-images.js";
export const productionCompilerImages = {
    normal: { hex: normalCompilerHex, symbols: normalCompilerSymbols },
    debug: { hex: debugCompilerHex, symbols: debugCompilerSymbols },
};
// This symbol is intentionally absent from the package export map. Tests use
// it to run a replacement image beside the production compiler without adding
// compiler selection to Host API 1 or the CLI.
export const nucleusCompilerImages = Symbol("nucleusCompilerImages");
const loadedImages = new WeakMap();
export const loadNucleusCompilerImage = async (pair, debugHooks) => {
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
