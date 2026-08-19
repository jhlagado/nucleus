import type { NucleusTarget } from "./compiler.js";
export declare const NUCLEUS_TARGET_PROFILE_SCHEMA = "nucleus-target/v1";
export interface NucleusConfigurationIssue {
    readonly path: string;
    readonly message: string;
}
export declare class NucleusConfigurationError extends Error {
    readonly issues: readonly NucleusConfigurationIssue[];
    readonly code = "NUCLEUS_CONFIGURATION";
    constructor(message: string, issues: readonly NucleusConfigurationIssue[]);
}
export declare const nucleusTargetServiceNames: readonly ["readInputByte", "writeOutputByte", "readStorageByte", "rewindStorageInput", "writeStorageByte", "seekStorageOutput", "success", "unhandledFailure", "trap", "farCall", "farJump", "packetService"];
export interface ValidateNucleusTargetOptions {
    readonly requireServices?: boolean;
    readonly sourcePartCount?: number;
}
export declare const validateNucleusTarget: (value: unknown, options?: ValidateNucleusTargetOptions) => readonly NucleusConfigurationIssue[];
export declare const assertNucleusTarget: (value: unknown, options?: ValidateNucleusTargetOptions) => NucleusTarget;
export declare const parseNucleusTargetProfile: (text: string, options?: ValidateNucleusTargetOptions) => NucleusTarget;
