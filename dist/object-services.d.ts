export declare const NUCLEUS_OBJECT_ABI_VERSION = 1;
export declare const NUCLEUS_OBJECT_REQUEST_SIZE = 16;
export declare const NucleusObjectRequest: {
    readonly size: 0;
    readonly abi: 1;
    readonly operation: 2;
    readonly flags: 3;
    readonly handle: 4;
    readonly pointer: 6;
    readonly length: 8;
    readonly offset: 10;
    readonly result: 14;
};
export declare const NucleusObjectOperation: {
    readonly openRead: 0;
    readonly beginWrite: 1;
    readonly read: 2;
    readonly write: 3;
    readonly rewind: 4;
    readonly seek: 5;
    readonly close: 6;
    readonly commit: 7;
    readonly abort: 8;
};
export declare const NucleusSystemStatus: {
    readonly success: 0;
    readonly invalid: 1;
    readonly unavailable: 2;
    readonly notFound: 3;
    readonly capacity: 4;
    readonly access: 5;
    readonly storage: 6;
    readonly conflict: 7;
    readonly cancelled: 8;
    readonly unsupported: 9;
};
export type NucleusSystemStatusCode = (typeof NucleusSystemStatus)[keyof typeof NucleusSystemStatus];
export interface NodeNamedObjectServicesOptions {
    readonly maxHandles?: number;
}
/** Filesystem-backed reference provider for named-object services ABI 1. */
export declare class NodeNamedObjectServices {
    #private;
    constructor(root: string, options?: NodeNamedObjectServicesOptions);
    get openHandleCount(): number;
    /** Execute one request in Z80 memory and return its canonical status. */
    dispatch(memory: Uint8Array, request: number): NucleusSystemStatusCode;
    abortAll(): void;
}
