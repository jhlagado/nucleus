export declare const nucleusSourceFileCapacity = 255;
export declare const nucleusSourceByteCapacity = 65535;
export interface NucleusSourceFile {
    readonly name: string;
    readonly source: string | Uint8Array;
    readonly bank?: number;
}
export interface NucleusSourceBundleFile {
    readonly name: string;
    readonly start: number;
    readonly end: number;
    readonly addedNewline: boolean;
    readonly bank: number;
    readonly byteLength: number;
    readonly sha256: string;
}
export interface NucleusSourcePlacementRange {
    readonly start: number;
    readonly end: number;
    readonly bank: number;
}
export interface NucleusSourceBundle {
    readonly bytes: Uint8Array;
    readonly byteLength: number;
    readonly sha256: string;
    readonly files: readonly NucleusSourceBundleFile[];
    readonly placement: readonly NucleusSourcePlacementRange[];
}
export interface NucleusMappedSourcePosition {
    readonly name: string;
    readonly offset: number;
    readonly line: number;
    readonly column: number;
    readonly synthetic: boolean;
}
export declare class NucleusSourceBundleError extends Error {
    constructor(message: string);
}
export declare const prepareNucleusSourceBundle: (sources: readonly NucleusSourceFile[]) => NucleusSourceBundle;
export declare const mapNucleusSourceBundleOffset: (bundle: NucleusSourceBundle, offset: number) => NucleusMappedSourcePosition;
