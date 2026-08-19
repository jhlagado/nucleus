import { type MaterializedNobj, type RuntimeServiceAddresses } from "./nobj.js";
import { type NucleusDebugMapping } from "./d8.js";
export declare const nucleusCompilerCapacities: {
    readonly sourceParts: 8;
    readonly sourceWindowBytes: number;
    readonly sourceDescriptorBytesPerPart: 5;
    readonly targetBanks: 4;
    readonly instructionLimit: 5000000;
    readonly cycleLimit: 50000000;
};
export declare const defaultNucleusServices: RuntimeServiceAddresses;
export interface NucleusSourcePart {
    readonly name: string;
    readonly source: string | Uint8Array;
}
export interface NucleusFlatTarget {
    readonly imageBase?: number;
    readonly imageCapacity?: number;
    readonly imageFill?: number;
    readonly writableBase?: number;
    readonly writableCapacity?: number;
    readonly establishStack?: boolean;
    readonly services?: RuntimeServiceAddresses;
}
export interface NucleusBankedTarget extends NucleusFlatTarget {
    readonly bankCount: number;
    readonly entryBank: number;
    readonly partBanks: readonly number[];
}
export type NucleusTarget = NucleusFlatTarget | NucleusBankedTarget;
export interface NucleusCompileOptions {
    readonly debugMap?: boolean;
    readonly compilerIoWrite?: (port: number, value: number) => void;
}
export interface NucleusDiagnostic {
    readonly code: number;
    readonly sourcePart: number;
    readonly sourceName?: string;
    readonly offset: number;
    readonly line: number;
    readonly column: number;
}
interface CompileMetrics {
    readonly instructions: number;
    readonly cycles: number;
}
export interface NucleusCompileSuccess extends CompileMetrics {
    readonly success: true;
    readonly nobj: Uint8Array;
    readonly materialized: MaterializedNobj;
    readonly debugMapping?: NucleusDebugMapping;
}
export interface NucleusCompileFailure extends CompileMetrics {
    readonly success: false;
    readonly diagnostic: NucleusDiagnostic;
}
export type NucleusCompileResult = NucleusCompileSuccess | NucleusCompileFailure;
/** Convert a successful flat-target compile into a Debug80-loadable Intel HEX image. */
export declare const writeNucleusIntelHex: (result: NucleusCompileSuccess) => string;
export declare const nucleusCompilerInfo: () => Promise<{
    readonly hostApiVersion: 1;
    readonly languageVersion: "0.1";
    readonly runtimeIdentity: 9;
    readonly normalImageSha256: string;
    readonly debugImageSha256: string;
    readonly capacities: typeof nucleusCompilerCapacities;
    readonly targets: {
        readonly flat: true;
        readonly banked: true;
        readonly maxBanks: 4;
    };
}>;
export declare const compileNucleus: (parts: readonly NucleusSourcePart[], target?: NucleusTarget, options?: NucleusCompileOptions) => Promise<NucleusCompileResult>;
export {};
