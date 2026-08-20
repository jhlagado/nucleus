import { type MaterializedNobj, type NobjCommitMetadata, type NobjSequentialOutput, type NobjSpoolFactory, type RuntimeServiceAddresses } from "./nobj.js";
import { type NucleusDebugMapping } from "./d8.js";
export declare const nucleusCompilerCapacities: {
    readonly sourceParts: 8;
    readonly sourcePartBytes: 65535;
    /** Compatibility resident-source adapter only; native compilation streams. */
    readonly compatibilitySourceWindowBytes: number;
    readonly nativeSourceChunkBytes: number;
    readonly nativeTokenCacheBytes: number;
    readonly nativeRetainedNameEntries: 1024;
    readonly nativeRetainedNameBytes: 65535;
    readonly sourceDescriptorBytesPerPart: 5;
    readonly targetBanks: 4;
    readonly instructionLimit: 10000000;
    readonly cycleLimit: 100000000;
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
export interface NucleusStreamingCompileOptions {
    readonly debugMap?: boolean;
    readonly compilerIoWrite?: (port: number, value: number) => void;
    readonly spoolFactory?: NobjSpoolFactory;
    readonly lowMemoryPatchValidation?: boolean;
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
export interface NucleusStreamingCompileSuccess extends CompileMetrics {
    readonly success: true;
    readonly object: NobjCommitMetadata;
    readonly debugMapping?: NucleusDebugMapping;
}
export type NucleusStreamingCompileResult = NucleusStreamingCompileSuccess | NucleusCompileFailure;
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
/** Compile to a transactional sequential NOBJ destination without materializing it. */
export declare const compileNucleusTo: (parts: readonly NucleusSourcePart[], target: NucleusTarget, output: NobjSequentialOutput, options?: NucleusStreamingCompileOptions) => Promise<NucleusStreamingCompileResult>;
export {};
