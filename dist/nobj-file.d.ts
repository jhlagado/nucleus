import type { NobjSequentialOutput, NobjSpool, NobjSpoolFactory } from "./nobj.js";
/** Append-only file spool with bounded sequential reads. */
export declare class NodeFileNobjSpool implements NobjSpool {
    #private;
    constructor(directory: string, chunkBytes?: number);
    get byteLength(): number;
    append(bytes: Uint8Array): void;
    chunks(): Iterable<Uint8Array>;
    clear(): void;
}
export declare const nodeFileNobjSpoolFactory: (directory: string, chunkBytes?: number) => NobjSpoolFactory;
/**
 * Sequential file destination that replaces the published NOBJ only after
 * COMMIT has been written and synchronized.
 */
export declare class NodeFileNobjOutput implements NobjSequentialOutput {
    #private;
    constructor(destination: string);
    write(bytes: Uint8Array): void;
    commit(): void;
    abort(): void;
}
