import { type NucleusDebugMapping } from "./d8.js";
import { type NucleusPublicationInternalHooks } from "./publication-internal.js";
export declare const publishNucleusD8OutputsInternal: (requestedPath: string, mapping: NucleusDebugMapping, previousPaths: readonly string[], hooks?: NucleusPublicationInternalHooks) => Promise<readonly string[]>;
