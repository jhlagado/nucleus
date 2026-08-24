import { NodeNamedObjectServices, type NucleusSystemStatusCode } from "./object-services.js";
export interface NativeImportResolverResult {
    readonly success: boolean;
    readonly status: NucleusSystemStatusCode;
    readonly instructions: number;
}
/**
 * Execute the prebuilt Z80 import resolver over named-object services.
 *
 * This is the Node platform binding beneath a genuine Z80 tool. It performs no
 * import parsing, dependency ordering, or SP1 serialization in TypeScript.
 */
export declare const runNativeImportResolver: (services: NodeNamedObjectServices, entry: string) => NativeImportResolverResult;
