export interface NucleusPublicationInternalOutput {
    readonly path: string;
    readonly contents: string | Uint8Array;
}
export interface NucleusPublicationInternalHooks {
    readonly beforePromote?: (path: string, index: number) => void | Promise<void>;
}
export declare const publishNucleusArtifactSetInternal: (outputs: readonly NucleusPublicationInternalOutput[], replacePaths?: readonly string[], hooks?: NucleusPublicationInternalHooks) => Promise<readonly string[]>;
