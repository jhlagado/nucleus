import type { NucleusSourcePart } from "./compiler.js";
export declare const parseNucleusImportHeader: (sourceName: string, source: Uint8Array) => readonly string[];
export interface ResolveNucleusImportsOptions {
    readonly root: string;
    readonly entry: string;
}
export declare const resolveNucleusImports: (options: ResolveNucleusImportsOptions) => Promise<readonly NucleusSourcePart[]>;
