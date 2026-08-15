import { parseIntelHex } from "@jhlagado/debug80-runtime";
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
export declare const productionCompilerImages: NucleusCompilerImagePair;
export declare const nucleusCompilerImages: unique symbol;
export interface NucleusCompilerImageSelection {
    readonly [nucleusCompilerImages]?: NucleusCompilerImagePair;
}
export declare const loadNucleusCompilerImage: (pair: NucleusCompilerImagePair, debugHooks: boolean) => Promise<LoadedNucleusCompilerImage>;
