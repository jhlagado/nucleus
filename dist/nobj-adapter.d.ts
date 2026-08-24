import { NobjGenerationStore, type NobjBegin, type NobjCommitMetadata, type NobjMap, type NobjSequentialOutput, type NobjSpoolFactory, type RuntimeImageProvider, type RuntimeLinkContext } from "./nobj.js";
export interface NobjAdapterGeneration {
    readonly name: string;
    readonly producerMemory: Uint8Array;
    readonly start: number;
    readonly length: number;
    readonly maxBytes: number;
    readonly begin: NobjBegin;
    readonly map: NobjMap;
    readonly runtimeLinkContext: RuntimeLinkContext;
    readonly runtimeProvider: RuntimeImageProvider;
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
export declare const commitNobjAdapterGeneration: (generation: NobjAdapterGeneration) => Uint8Array;
export declare const commitNobjAdapterGenerationTo: (generation: NobjAdapterGeneration, output: NobjSequentialOutput) => Promise<NobjCommitMetadata>;
