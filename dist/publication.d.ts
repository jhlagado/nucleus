import type { NucleusBuildArtifacts, NucleusD8Artifact } from "./host.js";
export interface NucleusPublicationOutput {
    readonly path: string;
    readonly contents: string | Uint8Array;
}
export declare const nucleusD8ArtifactOutputs: (requestedPath: string, artifacts: readonly NucleusD8Artifact[]) => readonly NucleusPublicationOutput[];
/** Replace a related artifact set as one recoverable filesystem transaction. */
export declare const publishNucleusArtifactSet: (outputs: readonly NucleusPublicationOutput[], replacePaths?: readonly string[]) => Promise<readonly string[]>;
export interface NucleusBuildOutputPaths {
    readonly nobj: string;
    readonly hex?: string;
    readonly d8?: string;
}
export declare const publishNucleusBuildOutputs: (paths: NucleusBuildOutputPaths, artifacts: NucleusBuildArtifacts) => Promise<readonly string[]>;
