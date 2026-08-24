import type { NucleusD8DebugMap } from "./d8.js";
import { nucleusCompilerInfo, type NucleusCompileSuccess, type NucleusDiagnostic, type NucleusSourcePart, type NucleusTarget } from "./compiler.js";
import { type RuntimeImageProvider } from "./nobj.js";
import { type NucleusConfigurationIssue } from "./configuration.js";
export declare const NUCLEUS_HOST_API_VERSION = 1;
export interface NucleusBuildArtifactRequest {
    readonly hex?: boolean;
    readonly d8?: boolean;
}
export interface NucleusBuildRequest {
    readonly sources: readonly NucleusSourcePart[];
    readonly target?: NucleusTarget;
    readonly artifacts?: NucleusBuildArtifactRequest;
    /** Exercise the compiler through direct pseudo-ports or the MON3 RST gateway. */
    readonly hostTransport?: "direct" | "mon3";
    /** Supply pre-linked runtime images for target layouts outside the package catalogue. */
    readonly runtimeProvider?: RuntimeImageProvider;
}
export interface NucleusD8Artifact {
    readonly bank: number;
    readonly map: NucleusD8DebugMap;
    readonly json: string;
}
export interface NucleusBuildArtifacts {
    readonly nobj: Uint8Array;
    readonly hex?: string;
    readonly d8?: readonly NucleusD8Artifact[];
}
export interface NucleusBuildSuccess {
    readonly success: true;
    readonly artifacts: NucleusBuildArtifacts;
    readonly materialized: NucleusCompileSuccess["materialized"];
    readonly instructions: number;
    readonly cycles: number;
}
export interface NucleusBuildSourceFailure {
    readonly success: false;
    readonly kind: "source";
    readonly message: string;
    readonly diagnostic: NucleusDiagnostic;
    readonly instructions: number;
    readonly cycles: number;
}
export interface NucleusBuildConfigurationFailure {
    readonly success: false;
    readonly kind: "configuration";
    readonly message: string;
    readonly issues: readonly NucleusConfigurationIssue[];
}
export interface NucleusBuildExecutionFailure {
    readonly success: false;
    readonly kind: "execution";
    readonly message: string;
    readonly cause?: unknown;
}
export type NucleusBuildFailure = NucleusBuildSourceFailure | NucleusBuildConfigurationFailure | NucleusBuildExecutionFailure;
export type NucleusBuildResult = NucleusBuildSuccess | NucleusBuildFailure;
export declare class NucleusCompiler {
    info(): Promise<Awaited<ReturnType<typeof nucleusCompilerInfo>>>;
    build(request: NucleusBuildRequest): Promise<NucleusBuildResult>;
}
export declare const createNucleusCompiler: () => NucleusCompiler;
