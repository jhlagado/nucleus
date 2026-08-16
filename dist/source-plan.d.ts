export interface NucleusSourcePlanPart {
    readonly bank: number;
    readonly path: string;
}
export declare class NucleusSourcePlanError extends Error {
    constructor(message: string);
}
export declare const parseNucleusSourcePlan: (source: string) => readonly NucleusSourcePlanPart[];
export declare const serializeNucleusSourcePlan: (parts: readonly NucleusSourcePlanPart[]) => string;
