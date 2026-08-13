import type { NucleusDebugMapping } from "./d8.js";
export declare const existingNucleusD8OutputPaths: (requestedPath: string) => Promise<string[]>;
/** Replace the complete flat-or-banked D8 sidecar group with rollback. */
export declare const publishNucleusD8Outputs: (requestedPath: string, mapping: NucleusDebugMapping) => Promise<readonly string[]>;
