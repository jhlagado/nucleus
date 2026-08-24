import { type NucleusTarget } from "./compiler.js";
export interface NucleusRunOptions {
    readonly input?: Uint8Array | readonly number[];
    /** Supplies another input byte after the optional buffered input is exhausted. */
    readonly readInput?: () => number | undefined;
    /** Observes each byte after the program writes it successfully. */
    readonly writeOutput?: (value: number) => void;
    readonly storageInput?: Uint8Array | readonly number[];
    readonly storageOutput?: Uint8Array | readonly number[];
    readonly packetService?: (slot: number, packet: Uint8Array) => number | void;
    readonly ioRead?: (port: number) => number;
    readonly ioWrite?: (port: number, value: number) => void;
    readonly maxInstructions?: number;
    readonly maxCycles?: number;
}
interface NucleusRunCommon {
    readonly instructions: number;
    readonly cycles: number;
    readonly loaderInstructions: number;
    readonly loaderCycles: number;
    readonly programInstructions: number;
    readonly programCycles: number;
    readonly output: Uint8Array;
    readonly storageOutput: Uint8Array;
    readonly memory: Uint8Array;
    /** One image-window snapshot per physical bank for a banked target. */
    readonly banks?: readonly Uint8Array[];
}
export interface NucleusRunSuccess extends NucleusRunCommon {
    readonly success: true;
    readonly outcome: "success";
}
export interface NucleusRunProgramFailure extends NucleusRunCommon {
    readonly success: false;
    readonly outcome: "unhandledFailure" | "trap";
    readonly trapReason: number;
    readonly trapOffset: number;
    readonly errorCode: number;
}
export interface NucleusRunLoaderFailure extends NucleusRunCommon {
    readonly success: false;
    readonly outcome: "loaderFailure";
    readonly loaderOutcome: number;
    readonly status: number;
    readonly recordOrdinal: number;
}
export interface NucleusRunLimitFailure extends NucleusRunCommon {
    readonly success: false;
    readonly outcome: "executionLimit";
    readonly phase: "loader" | "program";
    readonly programCounter: number;
}
export type NucleusRunResult = NucleusRunSuccess | NucleusRunProgramFailure | NucleusRunLoaderFailure | NucleusRunLimitFailure;
/**
 * Load one committed NOBJ with the standalone Z80 consumer, then execute
 * it through the Node reference program-service adapter.
 */
export declare const runNucleusNobj: (object: Uint8Array, target?: NucleusTarget, options?: NucleusRunOptions) => NucleusRunResult;
export {};
