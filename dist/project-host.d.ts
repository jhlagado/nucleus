import type { NucleusSourcePart, NucleusTarget } from "./compiler.js";
import { type NucleusBuildArtifactRequest, type NucleusBuildResult } from "./host.js";
import { type NucleusProject } from "./project.js";
import type { NucleusBuildOutputPaths } from "./publication.js";
import { type NucleusSourceDependency } from "./source-imports.js";
export interface PrepareNucleusProjectOptions {
    readonly targetProfile?: string;
    readonly requireServices?: boolean;
}
export interface PreparedNucleusProject {
    readonly projectPath: string;
    readonly project: NucleusProject;
    readonly root: string;
    readonly entry?: string;
    readonly sources: readonly NucleusSourcePart[];
    readonly dependencies: readonly NucleusSourceDependency[];
    readonly targetProfilePath: string;
    readonly target: NucleusTarget;
    readonly outputs: NucleusBuildOutputPaths;
}
export declare const prepareNucleusProject: (requestedProjectPath: string, options?: PrepareNucleusProjectOptions) => Promise<PreparedNucleusProject>;
export interface NucleusProjectCompiler {
    build(request: {
        readonly sources: readonly NucleusSourcePart[];
        readonly target: NucleusTarget;
        readonly artifacts: NucleusBuildArtifactRequest;
    }): Promise<NucleusBuildResult>;
}
export interface BuildNucleusProjectOptions extends PrepareNucleusProjectOptions {
    readonly artifacts?: NucleusBuildArtifactRequest;
    readonly compiler?: NucleusProjectCompiler;
}
export interface NucleusProjectBuild {
    readonly prepared: PreparedNucleusProject;
    readonly result: NucleusBuildResult;
}
export declare const buildNucleusProject: (projectPath: string, options?: BuildNucleusProjectOptions) => Promise<NucleusProjectBuild>;
