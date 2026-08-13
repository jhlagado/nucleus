import type { createZ80Runtime } from "@jhlagado/debug80-runtime";
import type { NucleusSourcePart } from "./compiler.js";
import type { NobjBegin, ParsedNobj } from "./nobj.js";
import type { NobjAdapterImageByte } from "./proof.js";
type CompilerCpu = ReturnType<typeof createZ80Runtime>["cpu"];
export declare const nucleusDebugPorts: {
    readonly source: 216;
    readonly declaration: 217;
    readonly contextPush: 218;
    readonly contextPop: 219;
    readonly routine: 220;
    readonly semanticStart: 221;
    readonly semanticEnd: 222;
    readonly imageByte: 223;
};
export declare const isNucleusDebugPort: (port: number) => boolean;
export interface NucleusLoadedSourcePart {
    readonly id: number;
    readonly name: string;
    readonly start: number;
    readonly end: number;
    readonly bytes: Uint8Array;
}
export interface NucleusD8Segment {
    readonly start: number;
    readonly end: number;
    readonly line: number;
    readonly column: number;
    readonly kind: "code";
    readonly confidence: "high";
    readonly lstLine: number;
    readonly lstTextId: number;
}
export interface NucleusD8Symbol {
    readonly name: string;
    readonly address: number;
    readonly line: number;
    readonly kind: "label";
    readonly scope: "global";
}
export interface NucleusD8DebugMap {
    readonly format: "d8-debug-map";
    readonly version: 1;
    readonly arch: "z80";
    readonly addressWidth: 16;
    readonly endianness: "little";
    readonly files: Readonly<Record<string, {
        readonly meta: {
            readonly lineCount: number;
        };
        readonly segments?: readonly NucleusD8Segment[];
        readonly symbols?: readonly NucleusD8Symbol[];
    }>>;
    readonly lstText: readonly string[];
    readonly segmentDefaults: {
        readonly kind: "code";
        readonly confidence: "high";
    };
    readonly symbolDefaults: {
        readonly kind: "label";
        readonly scope: "global";
    };
    readonly memory: {
        readonly segments: readonly {
            readonly name: string;
            readonly start: number;
            readonly end: number;
            readonly kind: "rom" | "banked";
            readonly bank: number;
        }[];
    };
    readonly generator: {
        readonly name: "Nucleus";
        readonly tool: "nucleus";
    };
}
export interface NucleusD8BankMap {
    readonly bank: number;
    readonly map: NucleusD8DebugMap;
}
export interface NucleusDebugMapping {
    readonly maps: readonly NucleusD8BankMap[];
    readonly sourceMarks: number;
    readonly declarationMarks: number;
    readonly semanticOperations: number;
    readonly imageBytes: number;
}
export declare const nucleusD8OutputPaths: (requestedPath: string, mapping: NucleusDebugMapping) => readonly {
    bank: number;
    path: string;
    map: NucleusD8DebugMap;
}[];
export interface NucleusDebugTraceSymbols {
    readonly sourcePartId: number;
    readonly tokenStartOffset: number;
    readonly tokenStartLine: number;
    readonly tokenStartColumn: number;
    readonly sinkCursor: number;
    readonly semanticPayloadBase: number;
    readonly semanticReadCursor: number;
    readonly declarationNamePointer: number;
    readonly declarationNameLength: number;
    readonly stage7CurrentRoutine: number;
    readonly stage7RoutineTableBase: number;
    readonly stage7RoutineEntrySize: number;
}
export declare class NucleusDebugCollector {
    #private;
    constructor(memory: Uint8Array, parts: readonly NucleusLoadedSourcePart[], symbols: NucleusDebugTraceSymbols);
    collect(port: number, cpu: CompilerCpu): void;
    finish(parsed: ParsedNobj, begin: NobjBegin, expectedImages: readonly NobjAdapterImageByte[]): NucleusDebugMapping;
}
export declare const sourcePartBytes: (part: NucleusSourcePart) => Uint8Array;
export {};
