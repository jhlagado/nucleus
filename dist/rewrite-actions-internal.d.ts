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
}, {
    readonly name: "BeginScalarConstant";
    readonly target: "RewriteDeclarationBeginScalarConstant";
    readonly id: 1;
}, {
    readonly name: "FinishScalarConstant";
    readonly target: "RewriteDeclarationFinishScalarConstant";
    readonly id: 2;
}, {
    readonly name: "CommitSymbol";
    readonly target: "RewriteSymbolCommit";
    readonly id: 3;
}, {
    readonly name: "BeginAssert";
    readonly target: "RewriteDeclarationBeginAssert";
    readonly id: 4;
}, {
    readonly name: "FinishAssert";
    readonly target: "RewriteDeclarationFinishAssert";
    readonly id: 5;
}];
export declare const rewriteActionPrograms: readonly [{
    readonly name: "ScalarConstant";
    readonly steps: readonly [{
        readonly instruction: "Expect";
        readonly operands: readonly ["TokenConst", "DiagnosticExpectedTopLevel"];
        readonly id: 1;
        readonly width: 3;
    }, {
        readonly instruction: "Expect";
        readonly operands: readonly ["TokenName", "DiagnosticExpectedName"];
        readonly id: 1;
        readonly width: 3;
    }, {
        readonly instruction: "Escape";
        readonly operands: readonly ["RewriteActionEscapeBeginScalarConstant"];
        readonly id: 2;
        readonly width: 2;
    }, {
        readonly instruction: "Expect";
        readonly operands: readonly ["TokenEquals", "DiagnosticExpectedEqual"];
        readonly id: 1;
        readonly width: 3;
    }, {
        readonly instruction: "Escape";
        readonly operands: readonly ["RewriteActionEscapeFinishScalarConstant"];
        readonly id: 2;
        readonly width: 2;
    }, {
        readonly instruction: "Expect";
        readonly operands: readonly ["TokenNewline", "DiagnosticExpectedLine"];
        readonly id: 1;
        readonly width: 3;
    }, {
        readonly instruction: "Escape";
        readonly operands: readonly ["RewriteActionEscapeCommitSymbol"];
        readonly id: 2;
        readonly width: 2;
    }, {
        readonly instruction: "End";
        readonly operands: readonly [];
        readonly id: 0;
        readonly width: 1;
    }];
    readonly width: 19;
}, {
    readonly name: "Assert";
    readonly steps: readonly [{
        readonly instruction: "Expect";
        readonly operands: readonly ["TokenAssert", "DiagnosticExpectedTopLevel"];
        readonly id: 1;
        readonly width: 3;
    }, {
        readonly instruction: "Escape";
        readonly operands: readonly ["RewriteActionEscapeBeginAssert"];
        readonly id: 2;
        readonly width: 2;
    }, {
        readonly instruction: "Escape";
        readonly operands: readonly ["RewriteActionEscapeFinishAssert"];
        readonly id: 2;
        readonly width: 2;
    }, {
        readonly instruction: "Expect";
        readonly operands: readonly ["TokenNewline", "DiagnosticExpectedLine"];
        readonly id: 1;
        readonly width: 3;
    }, {
        readonly instruction: "End";
        readonly operands: readonly [];
        readonly id: 0;
        readonly width: 1;
    }];
    readonly width: 11;
}];
export declare const decodeRewriteActionProgram: (bytes: Uint8Array) => readonly number[];
