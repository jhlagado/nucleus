import type { RuntimeImage, RuntimeImageProvider, RuntimeLinkContext } from "./nobj.js";
export declare const defaultRuntimeLinkContext: RuntimeLinkContext;
export declare const validateRuntimeLinkContext: (context: RuntimeLinkContext) => void;
export declare class CanonicalRuntimeImageProvider implements RuntimeImageProvider {
    #private;
    constructor(images: readonly {
        readonly context: RuntimeLinkContext;
        readonly image: RuntimeImage;
    }[]);
    get(identity: number, context: RuntimeLinkContext): RuntimeImage | undefined;
}
export declare const loadCanonicalRuntimeImage: (context?: RuntimeLinkContext) => Promise<RuntimeImage>;
export declare const loadCanonicalRuntimeProvider: (contexts?: readonly RuntimeLinkContext[]) => Promise<CanonicalRuntimeImageProvider>;
