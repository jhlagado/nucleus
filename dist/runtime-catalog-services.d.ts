import { type RuntimeImageProvider, type RuntimeServiceAddresses } from "./nobj.js";
import { type NucleusSystemStatusCode } from "./object-services.js";
export declare const NUCLEUS_RUNTIME_CATALOG_ABI_VERSION = 1;
export declare const NUCLEUS_RUNTIME_CATALOG_REQUEST_SIZE = 22;
export declare const NucleusRuntimeCatalogOperation: {
    readonly code: 0;
    readonly initial: 1;
};
export declare const NucleusRuntimeCatalogRequest: {
    readonly size: 0;
    readonly abi: 1;
    readonly operation: 2;
    readonly flags: 3;
    readonly bank: 4;
    readonly reservedByte: 5;
    readonly identity: 6;
    readonly expectedLength: 8;
    readonly contextPointer: 10;
    readonly offset: 12;
    readonly pointer: 14;
    readonly capacity: 16;
    readonly result: 18;
    readonly reservedWord: 20;
};
/** Reference provider for the Z80 runtime-catalogue chunk ABI. */
export declare class NodeRuntimeCatalogServices {
    readonly provider: RuntimeImageProvider;
    readonly services: RuntimeServiceAddresses;
    constructor(provider: RuntimeImageProvider, services: RuntimeServiceAddresses);
    dispatch(memory: Uint8Array, request: number): NucleusSystemStatusCode;
}
