export interface NativeRetainedName {
    readonly bytes: Uint8Array;
    readonly part: number;
    readonly offset: number;
}
export interface NativeRetainedNameUsage {
    readonly entries: number;
    readonly bytes: number;
}
export type NativeRetainedNameComparison = "equal" | "unequal" | "invalid";
export declare const nativeRetainedNameEntryCapacity = 1024;
export declare const nativeRetainedNameByteCapacity = 65535;
export declare class NativeRetainedNameStore {
    #private;
    constructor(entryCapacity?: number, byteCapacity?: number);
    retain(name: NativeRetainedName): number;
    get(handle: number): NativeRetainedName | undefined;
    compare(handle: number, bytes: Uint8Array): NativeRetainedNameComparison;
    clear(): void;
    usage(): NativeRetainedNameUsage;
}
