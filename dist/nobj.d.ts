/** Strict Nucleus Object Stream Format 0.1 encoding and materialization. */
export declare const NobjKind: {
    readonly begin: 1;
    readonly image: 2;
    readonly patch: 3;
    readonly map: 4;
    readonly commit: 5;
};
export declare const NOBJ_MAJOR_VERSION = 0;
export declare const NOBJ_MINOR_VERSION = 1;
export declare const NOBJ_MAP_REVISION = 1;
export declare const NOBJ_MAX_RECORDS = 65535;
export declare const NOBJ_MAX_DATA_BYTES = 65532;
export interface NobjBegin {
    readonly banked: boolean;
    readonly runtimeIdentity: number;
    readonly bankCount: number;
    readonly imageFill: number;
    readonly imageBase: number;
    readonly imageCapacity: number;
}
export interface NobjImageRecord {
    readonly bank: number;
    readonly address: number;
    readonly bytes: Uint8Array;
}
export interface NobjBankMap {
    readonly usedLength: number;
    readonly readOnlyBase: number;
    readonly readOnlyLength: number;
    readonly aggregateConstantBase: number;
    readonly aggregateConstantLength: number;
}
export interface NobjMap {
    readonly romMode: boolean;
    readonly establishedStack: boolean;
    readonly entryBank: number;
    readonly entryAddress: number;
    readonly writableBase: number;
    readonly writableCapacity: number;
    readonly vectorBase: number;
    readonly vectorLength: number;
    readonly initializedRunBase: number;
    readonly initializedRunLength: number;
    readonly bssBase: number;
    readonly bssLength: number;
    readonly stackRequirement: number;
    readonly dataLoadBank: number;
    readonly dataLoadAddress: number;
    readonly dataLoadLength: number;
    readonly partBanks: readonly number[];
    readonly banks: readonly NobjBankMap[];
}
export interface NobjCommit {
    readonly recordCount: number;
    readonly entryBank: number;
    readonly entryAddress: number;
    readonly crc16: number;
}
export interface ParsedNobj {
    readonly serialized: Uint8Array;
    readonly begin: NobjBegin;
    readonly images: readonly NobjImageRecord[];
    readonly patches: readonly NobjImageRecord[];
    readonly map: NobjMap;
    readonly commit: NobjCommit;
}
export interface MaterializedNobj {
    readonly parsed: ParsedNobj;
    readonly banks: readonly Uint8Array[];
    readonly flatImage?: Uint8Array;
}
export interface RuntimeImage {
    readonly identity: number;
    readonly bytes: Uint8Array;
    readonly initialBytes: Uint8Array;
    readonly vectorBytes: Uint8Array;
    readonly helperOffsets?: Readonly<Record<string, number>>;
    readonly currentBankOffset?: number;
}
export interface RuntimeServiceAddresses {
    readonly readInputByte: number;
    readonly writeOutputByte: number;
    readonly readStorageByte: number;
    readonly rewindStorageInput: number;
    readonly writeStorageByte: number;
    readonly seekStorageOutput: number;
    readonly success: number;
    readonly unhandledFailure: number;
    readonly trap: number;
    readonly farCall: number;
    readonly farJump: number;
    readonly packetService: number;
}
export interface RuntimeLinkContext {
    readonly runtimeBase: number;
    readonly writableBase: number;
    readonly writableCapacity: number;
    readonly writableStateBase: number;
    readonly vectorBase: number;
    readonly programDataBase: number;
    readonly programDataCapacity: number;
    readonly readOnlyBase: number;
    readonly readOnlyCapacity: number;
    readonly services: RuntimeServiceAddresses;
}
export interface RuntimeImageProvider {
    get(identity: number, context: RuntimeLinkContext): RuntimeImage | undefined;
}
/** Sequential storage used independently for image and patch records. */
export interface NobjSpool {
    readonly byteLength: number;
    append(bytes: Uint8Array): void;
    chunks(): Iterable<Uint8Array>;
    clear(): void;
}
export type NobjSpoolFactory = () => NobjSpool;
export declare class MemoryNobjSpool implements NobjSpool {
    #private;
    get byteLength(): number;
    append(bytes: Uint8Array): void;
    chunks(): Iterable<Uint8Array>;
    clear(): void;
}
export declare class NobjError extends Error {
    constructor(message: string);
}
/** Atomic reference to the most recently validated committed generation. */
export declare class NobjGenerationStore {
    #private;
    get current(): Uint8Array | undefined;
    publish(serialized: Uint8Array): ParsedNobj;
}
export declare const crc16CcittFalse: (bytes: Uint8Array) => number;
export declare class NobjGenerationSink {
    #private;
    constructor(store: NobjGenerationStore, provider: RuntimeImageProvider, spoolFactory?: NobjSpoolFactory);
    get imageSpoolHighWater(): number;
    get patchSpoolHighWater(): number;
    begin(begin: NobjBegin): void;
    image(bank: number, address: number, bytes: Uint8Array): void;
    runtimeImage(bank: number, address: number, identity: number, context: RuntimeLinkContext, expectedLength: number): void;
    runtimeInitialImage(bank: number, address: number, identity: number, context: RuntimeLinkContext, expectedLength: number): void;
    patch(bank: number, address: number, bytes: Uint8Array): void;
    map(map: NobjMap): void;
    commit(): Uint8Array;
    abort(): void;
}
export declare const parseNobj: (serialized: Uint8Array) => ParsedNobj;
export declare const materializeNobj: (parsed: ParsedNobj) => MaterializedNobj;
