export interface SourcePart {
    ordinal: number;
    stableIdentity: string;
    diagnosticName: string;
    bytes: Uint8Array;
}
export declare function parseSourceManifest(text: string): string[];
export declare function buildSourceParts(manifest: string, readSource: (name: string) => Uint8Array): SourcePart[];
