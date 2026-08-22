export declare const NUCLEUS_PROJECT_V1_SCHEMA = "nucleus-project/v1";
export declare const NUCLEUS_PROJECT_V2_SCHEMA = "nucleus-project/v2";
export declare const NUCLEUS_PROJECT_SCHEMA = "nucleus-project/v1";
export interface NucleusProjectOutputs {
    readonly nobj: string;
    readonly hex?: string;
    readonly d8?: string;
}
interface NucleusProjectBase {
    readonly root?: string;
    readonly target: string;
    readonly outputs: NucleusProjectOutputs;
}
export interface NucleusProjectV1 extends NucleusProjectBase {
    readonly schema: typeof NUCLEUS_PROJECT_V1_SCHEMA;
    readonly sources: readonly string[];
}
export interface NucleusProjectV2 extends NucleusProjectBase {
    readonly schema: typeof NUCLEUS_PROJECT_V2_SCHEMA;
    readonly entry: string;
    readonly sourceBanks?: Readonly<Record<string, number>>;
}
export type NucleusProject = NucleusProjectV1 | NucleusProjectV2;
export declare const parseNucleusProject: (text: string) => NucleusProject;
export {};
