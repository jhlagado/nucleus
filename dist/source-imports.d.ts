import type { NucleusSourcePart } from "./compiler.js";
export declare const parseNucleusImportHeader: (sourceName: string, source: Uint8Array) => readonly string[];
export interface ResolveNucleusImportsOptions {
    readonly root: string;
    readonly entry: string;
}
export interface NucleusSourceDependency {
    readonly name: string;
    readonly imports: readonly string[];
    readonly byteLength: number;
    readonly sha256: string;
}
export interface NucleusResolvedImportGraph {
    readonly entry: string;
    readonly sources: readonly NucleusSourcePart[];
    readonly dependencies: readonly NucleusSourceDependency[];
}
export declare const resolveNucleusImportGraph: (options: ResolveNucleusImportsOptions) => Promise<NucleusResolvedImportGraph>;
export declare const resolveNucleusImports: (options: ResolveNucleusImportsOptions) => Promise<readonly NucleusSourcePart[]>;
