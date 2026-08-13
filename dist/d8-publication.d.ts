import { type NucleusDebugMapping } from "./d8.js";
export declare const existingNucleusD8OutputPaths: (requestedPath: string) => Promise<string[]>;
/** Atomically replace the complete flat-or-banked D8 sidecar group. */
export declare const publishNucleusD8Outputs: (requestedPath: string, mapping: NucleusDebugMapping) => Promise<readonly string[]>;
