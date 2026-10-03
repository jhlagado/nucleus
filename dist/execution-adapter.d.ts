/**
 * The small machine surface needed by the Nucleus compiler host.
 *
 * The compiler image is a Z80 program, but compiler semantics do not belong to
 * an emulator package.  A host supplies an image parser and an execution
 * factory; the current Debug80 implementation is deliberately kept in the
 * default development adapter below so a Triptych native/WASM adapter can be
 * added without changing source preparation or NOBJ publication.
 */
export interface NucleusExecutionImage {
    readonly memory: Uint8Array;
    readonly startAddress: number;
    readonly writeRanges?: readonly {
        readonly start: number;
        readonly end: number;
    }[];
}
export interface NucleusExecutionFlags {
    C: number;
}
export interface NucleusExecutionCpu {
    a: number;
    b: number;
    c: number;
    d: number;
    e: number;
    h: number;
    l: number;
    ix: number;
    iy: number;
    sp: number;
    pc: number;
    halted: boolean;
    flags: NucleusExecutionFlags;
}
export interface NucleusExecutionRuntime {
    readonly hardware: {
        readonly memory: Uint8Array;
    };
    readonly cpu: NucleusExecutionCpu;
    step(): {
        readonly cycles?: number;
    };
    isHalted(): boolean;
}
export interface NucleusExecutionCreateOptions {
    readonly image: NucleusExecutionImage;
    readonly entry: number;
    readonly write?: (port: number, value: number) => void;
}
export interface NucleusExecutionAdapter {
    parseImage(hexText: string): NucleusExecutionImage;
    create(options: NucleusExecutionCreateOptions): NucleusExecutionRuntime;
}
/** The current reference adapter; production Triptych adapters replace this. */
export declare const createDebug80ExecutionAdapter: () => NucleusExecutionAdapter;
