import { type RuntimeImageProvider, type RuntimeLinkContext } from "./nobj.js";
/** Validate the addresses that select and initialize a linked runtime image. */
export declare const validateRuntimeLinkContext: (context: RuntimeLinkContext) => void;
/** Pre-linked runtime images shipped with the Node harness. */
export declare const bundledRuntimeProvider: RuntimeImageProvider;
/** Runtime placements pre-linked into the published Node package. */
export declare const bundledRuntimeCatalog: {
    name: "node-default" | "node-loaded-4000" | "node-loaded-9000" | "cpm22-loaded" | "test-banked" | "test-high";
    runtimeBase: 32771 | 16387 | 2051 | 61443;
    writableStateBase: 36900 | 16420 | 24612 | 22564 | 20516;
    packetService: 28705 | 296 | 28870;
}[];
