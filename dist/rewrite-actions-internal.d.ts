export interface RewriteActionInstruction {
    readonly id: number;
    readonly name: string;
    readonly operands: readonly string[];
    readonly width: number;
}
export declare const rewriteActionInstructions: readonly RewriteActionInstruction[];
export declare const rewriteActionEscapes: readonly [{
    readonly name: "ResetInitializer";
    readonly target: "RewriteInitializerReset";
    readonly id: 0;
}];
export declare const decodeRewriteActionProgram: (bytes: Uint8Array) => readonly number[];
