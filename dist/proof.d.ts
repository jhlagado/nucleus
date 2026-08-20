import { NobjGenerationStore, type MaterializedNobj, type NobjBegin, type NobjCommitMetadata, type NobjMap, type NobjSequentialOutput, type NobjSpoolFactory, type ParsedNobj, type RuntimeLinkContext } from "./nobj.js";
interface NobjProofManifest {
    readonly adapter: {
        readonly at: string;
        readonly lengthAt: string;
        readonly maxBytes: number;
    };
    readonly begin: NobjBegin;
    readonly map: NobjMap;
    readonly runtimeLinkContext?: RuntimeLinkContext;
    /** Materialize the committed object without entering it. */
    readonly materializeOnly?: boolean;
    readonly execution: {
        readonly maxInstructions: number;
        readonly maxCycles: number;
        readonly halted: boolean;
        readonly initialSp?: number;
        readonly expectedSp?: number;
        readonly expectedIx?: number;
        readonly expectedIy?: number;
        readonly writes?: readonly {
            readonly at: number;
            readonly bytes: readonly number[];
        }[];
    };
    readonly observations?: readonly NobjObservation[];
    readonly bankSwitch?: {
        readonly port: number;
        readonly windowBase: number;
        readonly windowCapacity: number;
    };
}
interface NobjObservation {
    readonly at: number;
    readonly width: "u8" | "u16";
    readonly equals: number;
    readonly bank?: number;
}
export interface NobjAdapterGeneration {
    readonly name: string;
    readonly producerMemory: Uint8Array;
    readonly start: number;
    readonly length: number;
    readonly maxBytes: number;
    readonly begin: NobjBegin;
    readonly map: NobjMap;
    readonly runtimeLinkContext?: RuntimeLinkContext;
    readonly store?: NobjGenerationStore;
    readonly spoolFactory?: NobjSpoolFactory;
    readonly lowMemoryPatchValidation?: boolean;
    readonly onImageByte?: (image: NobjAdapterImageByte) => void;
}
export interface NobjAdapterImageByte {
    readonly bank: number;
    readonly address: number;
    readonly value: number;
}
export interface ProofRegion {
    readonly name: string;
    readonly start: number;
    readonly end: number;
    readonly bytes: number;
}
export interface ProofExtent {
    readonly name: string;
    readonly bytes: number;
}
export interface ProofOutcome {
    readonly name: string;
    readonly instructions: number;
    readonly cycles: number;
    readonly recentProgramCounters: readonly number[];
    readonly regions: readonly ProofRegion[];
    readonly extents: readonly ProofExtent[];
    readonly symbols: Readonly<Record<string, number>>;
    readonly memory: Uint8Array;
    readonly nobj?: NobjExecutionOutcome;
}
export interface NobjExecutionOutcome {
    readonly serialized: Uint8Array;
    readonly parsed: ParsedNobj;
    readonly materialized: MaterializedNobj;
    readonly memory: Uint8Array;
    readonly instructions: number;
    readonly cycles: number;
    readonly selectedBank: number;
}
export declare class ProofFailure extends Error {
    constructor(message: string);
}
export declare function runProofManifest(manifestFile: string): Promise<ProofOutcome>;
export declare const commitNobjAdapterGeneration: (generation: NobjAdapterGeneration) => Promise<Uint8Array>;
export declare const commitNobjAdapterGenerationTo: (generation: NobjAdapterGeneration, output: NobjSequentialOutput) => Promise<NobjCommitMetadata>;
export declare const executeCommittedNobj: (serialized: Uint8Array, execution: {
    readonly maxInstructions: number;
    readonly maxCycles: number;
    readonly halted: boolean;
    readonly initialSp?: number;
    readonly expectedSp?: number;
    readonly expectedIx?: number;
    readonly expectedIy?: number;
    readonly writes?: readonly {
        readonly at: number;
        readonly bytes: readonly number[];
    }[];
}, options?: {
    readonly observations?: readonly NobjObservation[] | undefined;
    readonly bankSwitch?: NobjProofManifest["bankSwitch"];
    readonly ioRead?: ((port: number) => number) | undefined;
    readonly ioWrite?: ((port: number, value: number) => void) | undefined;
}) => NobjExecutionOutcome;
export {};
