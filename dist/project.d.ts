export declare const NUCLEUS_PROJECT_SCHEMA = "nucleus-project/v1";
export interface NucleusProjectOutputs {
    readonly nobj: string;
    readonly hex?: string;
    readonly d8?: string;
}
export interface NucleusProject {
    readonly schema: typeof NUCLEUS_PROJECT_SCHEMA;
    readonly root?: string;
    readonly sources: readonly string[];
    readonly target: string;
    readonly outputs: NucleusProjectOutputs;
}
export declare const parseNucleusProject: (text: string) => NucleusProject;
