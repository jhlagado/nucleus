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
}, {
    readonly name: "BeginProgram";
    readonly target: "RewriteDeclarationBeginProgram";
    readonly id: 6;
}, {
    readonly name: "ParseOwnedType";
    readonly target: "RewriteDeclarationParseOwnedType";
    readonly id: 7;
}, {
    readonly name: "FinishProgramBss";
    readonly target: "RewriteDeclarationFinishProgramBss";
    readonly id: 8;
}, {
    readonly name: "FinishProgramScalar";
    readonly target: "RewriteDeclarationFinishProgramScalar";
    readonly id: 9;
}, {
    readonly name: "BeginRecord";
    readonly target: "RewriteDeclarationBeginRecord";
    readonly id: 10;
}, {
    readonly name: "BeginRecordField";
    readonly target: "RewriteFieldPrepareCurrent";
    readonly id: 11;
}, {
    readonly name: "ParseRecordFieldType";
    readonly target: "RewriteDeclarationParseRecordFieldType";
    readonly id: 12;
}, {
    readonly name: "FinishRecordField";
    readonly target: "RewriteDeclarationFinishRecordField";
    readonly id: 13;
}, {
    readonly name: "FinishRecord";
    readonly target: "RewriteDeclarationFinishRecord";
    readonly id: 14;
}, {
    readonly name: "BeginAggregateConstant";
    readonly target: "RewriteDeclarationBeginAggregateConstant";
    readonly id: 15;
}, {
    readonly name: "FinishAggregateConstant";
    readonly target: "RewriteDeclarationFinishAggregateConstant";
    readonly id: 16;
}, {
    readonly name: "FinishProgramAggregate";
    readonly target: "RewriteDeclarationFinishProgramAggregate";
    readonly id: 17;
}, {
    readonly name: "FinishDirectRoutineHeader";
    readonly target: "RewriteDeclarationFinishDirectRoutineHeader";
    readonly id: 18;
}, {
    readonly name: "FinishForwardRoutineHeader";
    readonly target: "RewriteDeclarationFinishForwardRoutineHeader";
    readonly id: 19;
}, {
    readonly name: "OpenForwardBody";
    readonly target: "RewriteDeclarationOpenForwardBody";
    readonly id: 20;
}, {
    readonly name: "RequireComplete";
    readonly target: "RewriteDeclarationRequireComplete";
    readonly id: 21;
}, {
    readonly name: "CloseRoutineScope";
    readonly target: "RewriteRoutineCloseScope";
    readonly id: 22;
}, {
    readonly name: "BeginLocal";
    readonly target: "RewriteDeclarationBeginLocal";
    readonly id: 23;
}, {
    readonly name: "ParseLocalScalarType";
    readonly target: "RewriteDeclarationParseLocalScalarType";
    readonly id: 24;
}, {
    readonly name: "EmitDefaultLocal";
    readonly target: "RewriteDeclarationEmitDefaultLocal";
    readonly id: 25;
}, {
    readonly name: "CommitLocal";
    readonly target: "RewriteDeclarationCommitLocal";
    readonly id: 26;
}, {
    readonly name: "FinishRuntimeLocalExpression";
    readonly target: "RewriteDeclarationFinishRuntimeLocalExpression";
    readonly id: 27;
}, {
    readonly name: "EmitLocalStore";
    readonly target: "RewriteDeclarationEmitLocalStore";
    readonly id: 28;
}, {
    readonly name: "BeginScalarAssignment";
    readonly target: "RewriteStatementBeginScalarAssignment";
    readonly id: 29;
}, {
    readonly name: "FinishScalarAssignmentExpression";
    readonly target: "RewriteStatementFinishScalarAssignmentExpression";
    readonly id: 30;
}, {
    readonly name: "EmitScalarAssignment";
    readonly target: "RewriteStatementEmitScalarAssignment";
    readonly id: 31;
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
}, {
    readonly name: "ProgramBss";
    readonly steps: readonly [{
        readonly instruction: "Expect";
        readonly operands: readonly ["TokenVar", "DiagnosticExpectedTopLevel"];
        readonly id: 1;
        readonly width: 3;
    }, {
        readonly instruction: "Expect";
        readonly operands: readonly ["TokenName", "DiagnosticExpectedName"];
        readonly id: 1;
        readonly width: 3;
    }, {
        readonly instruction: "Escape";
        readonly operands: readonly ["RewriteActionEscapeBeginProgram"];
        readonly id: 2;
        readonly width: 2;
    }, {
        readonly instruction: "Expect";
        readonly operands: readonly ["TokenAs", "DiagnosticExpectedAs"];
        readonly id: 1;
        readonly width: 3;
    }, {
        readonly instruction: "Escape";
        readonly operands: readonly ["RewriteActionEscapeParseOwnedType"];
        readonly id: 2;
        readonly width: 2;
    }, {
        readonly instruction: "Escape";
        readonly operands: readonly ["RewriteActionEscapeFinishProgramBss"];
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
    readonly width: 21;
}, {
    readonly name: "ProgramScalarInitialized";
    readonly steps: readonly [{
        readonly instruction: "Expect";
        readonly operands: readonly ["TokenVar", "DiagnosticExpectedTopLevel"];
        readonly id: 1;
        readonly width: 3;
    }, {
        readonly instruction: "Expect";
        readonly operands: readonly ["TokenName", "DiagnosticExpectedName"];
        readonly id: 1;
        readonly width: 3;
    }, {
        readonly instruction: "Escape";
        readonly operands: readonly ["RewriteActionEscapeBeginProgram"];
        readonly id: 2;
        readonly width: 2;
    }, {
        readonly instruction: "Expect";
        readonly operands: readonly ["TokenAs", "DiagnosticExpectedAs"];
        readonly id: 1;
        readonly width: 3;
    }, {
        readonly instruction: "Escape";
        readonly operands: readonly ["RewriteActionEscapeParseOwnedType"];
        readonly id: 2;
        readonly width: 2;
    }, {
        readonly instruction: "Expect";
        readonly operands: readonly ["TokenEquals", "DiagnosticExpectedEqual"];
        readonly id: 1;
        readonly width: 3;
    }, {
        readonly instruction: "Escape";
        readonly operands: readonly ["RewriteActionEscapeFinishProgramScalar"];
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
    readonly width: 24;
}, {
    readonly name: "RecordBegin";
    readonly steps: readonly [{
        readonly instruction: "Expect";
        readonly operands: readonly ["TokenRecord", "DiagnosticExpectedTopLevel"];
        readonly id: 1;
        readonly width: 3;
    }, {
        readonly instruction: "Expect";
        readonly operands: readonly ["TokenName", "DiagnosticExpectedName"];
        readonly id: 1;
        readonly width: 3;
    }, {
        readonly instruction: "Escape";
        readonly operands: readonly ["RewriteActionEscapeBeginRecord"];
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
    readonly width: 12;
}, {
    readonly name: "RecordField";
    readonly steps: readonly [{
        readonly instruction: "Expect";
        readonly operands: readonly ["TokenName", "DiagnosticExpectedName"];
        readonly id: 1;
        readonly width: 3;
    }, {
        readonly instruction: "Escape";
        readonly operands: readonly ["RewriteActionEscapeBeginRecordField"];
        readonly id: 2;
        readonly width: 2;
    }, {
        readonly instruction: "Expect";
        readonly operands: readonly ["TokenAs", "DiagnosticExpectedAs"];
        readonly id: 1;
        readonly width: 3;
    }, {
        readonly instruction: "Escape";
        readonly operands: readonly ["RewriteActionEscapeParseRecordFieldType"];
        readonly id: 2;
        readonly width: 2;
    }, {
        readonly instruction: "Escape";
        readonly operands: readonly ["RewriteActionEscapeFinishRecordField"];
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
    readonly width: 16;
}, {
    readonly name: "RecordEnd";
    readonly steps: readonly [{
        readonly instruction: "Expect";
        readonly operands: readonly ["TokenEnd", "DiagnosticExpectedEnd"];
        readonly id: 1;
        readonly width: 3;
    }, {
        readonly instruction: "Escape";
        readonly operands: readonly ["RewriteActionEscapeFinishRecord"];
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
    readonly width: 11;
}, {
    readonly name: "AggregateConstant";
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
        readonly operands: readonly ["RewriteActionEscapeBeginAggregateConstant"];
        readonly id: 2;
        readonly width: 2;
    }, {
        readonly instruction: "Expect";
        readonly operands: readonly ["TokenAs", "DiagnosticExpectedAs"];
        readonly id: 1;
        readonly width: 3;
    }, {
        readonly instruction: "Escape";
        readonly operands: readonly ["RewriteActionEscapeParseOwnedType"];
        readonly id: 2;
        readonly width: 2;
    }, {
        readonly instruction: "Expect";
        readonly operands: readonly ["TokenEquals", "DiagnosticExpectedEqual"];
        readonly id: 1;
        readonly width: 3;
    }, {
        readonly instruction: "Escape";
        readonly operands: readonly ["RewriteActionEscapeFinishAggregateConstant"];
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
    readonly width: 24;
}, {
    readonly name: "ProgramAggregateInitialized";
    readonly steps: readonly [{
        readonly instruction: "Expect";
        readonly operands: readonly ["TokenVar", "DiagnosticExpectedTopLevel"];
        readonly id: 1;
        readonly width: 3;
    }, {
        readonly instruction: "Expect";
        readonly operands: readonly ["TokenName", "DiagnosticExpectedName"];
        readonly id: 1;
        readonly width: 3;
    }, {
        readonly instruction: "Escape";
        readonly operands: readonly ["RewriteActionEscapeBeginProgram"];
        readonly id: 2;
        readonly width: 2;
    }, {
        readonly instruction: "Expect";
        readonly operands: readonly ["TokenAs", "DiagnosticExpectedAs"];
        readonly id: 1;
        readonly width: 3;
    }, {
        readonly instruction: "Escape";
        readonly operands: readonly ["RewriteActionEscapeParseOwnedType"];
        readonly id: 2;
        readonly width: 2;
    }, {
        readonly instruction: "Expect";
        readonly operands: readonly ["TokenEquals", "DiagnosticExpectedEqual"];
        readonly id: 1;
        readonly width: 3;
    }, {
        readonly instruction: "Escape";
        readonly operands: readonly ["RewriteActionEscapeFinishProgramAggregate"];
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
    readonly width: 24;
}, {
    readonly name: "RoutineDirectHeader";
    readonly steps: readonly [{
        readonly instruction: "Expect";
        readonly operands: readonly ["TokenSub", "DiagnosticExpectedTopLevel"];
        readonly id: 1;
        readonly width: 3;
    }, {
        readonly instruction: "Expect";
        readonly operands: readonly ["TokenName", "DiagnosticExpectedName"];
        readonly id: 1;
        readonly width: 3;
    }, {
        readonly instruction: "Escape";
        readonly operands: readonly ["RewriteActionEscapeFinishDirectRoutineHeader"];
        readonly id: 2;
        readonly width: 2;
    }, {
        readonly instruction: "End";
        readonly operands: readonly [];
        readonly id: 0;
        readonly width: 1;
    }];
    readonly width: 9;
}, {
    readonly name: "RoutineForwardHeader";
    readonly steps: readonly [{
        readonly instruction: "Expect";
        readonly operands: readonly ["TokenForward", "DiagnosticExpectedTopLevel"];
        readonly id: 1;
        readonly width: 3;
    }, {
        readonly instruction: "Expect";
        readonly operands: readonly ["TokenSub", "DiagnosticExpectedTopLevel"];
        readonly id: 1;
        readonly width: 3;
    }, {
        readonly instruction: "Expect";
        readonly operands: readonly ["TokenName", "DiagnosticExpectedName"];
        readonly id: 1;
        readonly width: 3;
    }, {
        readonly instruction: "Escape";
        readonly operands: readonly ["RewriteActionEscapeFinishForwardRoutineHeader"];
        readonly id: 2;
        readonly width: 2;
    }, {
        readonly instruction: "End";
        readonly operands: readonly [];
        readonly id: 0;
        readonly width: 1;
    }];
    readonly width: 12;
}, {
    readonly name: "RoutineForwardBody";
    readonly steps: readonly [{
        readonly instruction: "Expect";
        readonly operands: readonly ["TokenSub", "DiagnosticExpectedTopLevel"];
        readonly id: 1;
        readonly width: 3;
    }, {
        readonly instruction: "Expect";
        readonly operands: readonly ["TokenName", "DiagnosticExpectedName"];
        readonly id: 1;
        readonly width: 3;
    }, {
        readonly instruction: "Escape";
        readonly operands: readonly ["RewriteActionEscapeOpenForwardBody"];
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
    readonly width: 12;
}, {
    readonly name: "CompilationEnd";
    readonly steps: readonly [{
        readonly instruction: "Expect";
        readonly operands: readonly ["TokenEof", "DiagnosticExpectedTopLevel"];
        readonly id: 1;
        readonly width: 3;
    }, {
        readonly instruction: "Escape";
        readonly operands: readonly ["RewriteActionEscapeRequireComplete"];
        readonly id: 2;
        readonly width: 2;
    }, {
        readonly instruction: "End";
        readonly operands: readonly [];
        readonly id: 0;
        readonly width: 1;
    }];
    readonly width: 6;
}, {
    readonly name: "RoutineEnd";
    readonly steps: readonly [{
        readonly instruction: "Expect";
        readonly operands: readonly ["TokenEnd", "DiagnosticExpectedEnd"];
        readonly id: 1;
        readonly width: 3;
    }, {
        readonly instruction: "Expect";
        readonly operands: readonly ["TokenNewline", "DiagnosticExpectedLine"];
        readonly id: 1;
        readonly width: 3;
    }, {
        readonly instruction: "Escape";
        readonly operands: readonly ["RewriteActionEscapeCloseRoutineScope"];
        readonly id: 2;
        readonly width: 2;
    }, {
        readonly instruction: "End";
        readonly operands: readonly [];
        readonly id: 0;
        readonly width: 1;
    }];
    readonly width: 9;
}, {
    readonly name: "LocalDefault";
    readonly steps: readonly [{
        readonly instruction: "Expect";
        readonly operands: readonly ["TokenVar", "DiagnosticExpectedTopLevel"];
        readonly id: 1;
        readonly width: 3;
    }, {
        readonly instruction: "Expect";
        readonly operands: readonly ["TokenName", "DiagnosticExpectedName"];
        readonly id: 1;
        readonly width: 3;
    }, {
        readonly instruction: "Escape";
        readonly operands: readonly ["RewriteActionEscapeBeginLocal"];
        readonly id: 2;
        readonly width: 2;
    }, {
        readonly instruction: "Expect";
        readonly operands: readonly ["TokenAs", "DiagnosticExpectedAs"];
        readonly id: 1;
        readonly width: 3;
    }, {
        readonly instruction: "Escape";
        readonly operands: readonly ["RewriteActionEscapeParseLocalScalarType"];
        readonly id: 2;
        readonly width: 2;
    }, {
        readonly instruction: "Escape";
        readonly operands: readonly ["RewriteActionEscapeEmitDefaultLocal"];
        readonly id: 2;
        readonly width: 2;
    }, {
        readonly instruction: "Expect";
        readonly operands: readonly ["TokenNewline", "DiagnosticExpectedLine"];
        readonly id: 1;
        readonly width: 3;
    }, {
        readonly instruction: "Escape";
        readonly operands: readonly ["RewriteActionEscapeCommitLocal"];
        readonly id: 2;
        readonly width: 2;
    }, {
        readonly instruction: "End";
        readonly operands: readonly [];
        readonly id: 0;
        readonly width: 1;
    }];
    readonly width: 21;
}, {
    readonly name: "LocalInitializedExpression";
    readonly steps: readonly [{
        readonly instruction: "Expect";
        readonly operands: readonly ["TokenVar", "DiagnosticExpectedTopLevel"];
        readonly id: 1;
        readonly width: 3;
    }, {
        readonly instruction: "Expect";
        readonly operands: readonly ["TokenName", "DiagnosticExpectedName"];
        readonly id: 1;
        readonly width: 3;
    }, {
        readonly instruction: "Escape";
        readonly operands: readonly ["RewriteActionEscapeBeginLocal"];
        readonly id: 2;
        readonly width: 2;
    }, {
        readonly instruction: "Expect";
        readonly operands: readonly ["TokenAs", "DiagnosticExpectedAs"];
        readonly id: 1;
        readonly width: 3;
    }, {
        readonly instruction: "Escape";
        readonly operands: readonly ["RewriteActionEscapeParseLocalScalarType"];
        readonly id: 2;
        readonly width: 2;
    }, {
        readonly instruction: "Expect";
        readonly operands: readonly ["TokenEquals", "DiagnosticExpectedEqual"];
        readonly id: 1;
        readonly width: 3;
    }, {
        readonly instruction: "Escape";
        readonly operands: readonly ["RewriteActionEscapeFinishRuntimeLocalExpression"];
        readonly id: 2;
        readonly width: 2;
    }, {
        readonly instruction: "Expect";
        readonly operands: readonly ["TokenNewline", "DiagnosticExpectedLine"];
        readonly id: 1;
        readonly width: 3;
    }, {
        readonly instruction: "Escape";
        readonly operands: readonly ["RewriteActionEscapeEmitLocalStore"];
        readonly id: 2;
        readonly width: 2;
    }, {
        readonly instruction: "Escape";
        readonly operands: readonly ["RewriteActionEscapeCommitLocal"];
        readonly id: 2;
        readonly width: 2;
    }, {
        readonly instruction: "End";
        readonly operands: readonly [];
        readonly id: 0;
        readonly width: 1;
    }];
    readonly width: 26;
}, {
    readonly name: "ScalarAssignment";
    readonly steps: readonly [{
        readonly instruction: "Expect";
        readonly operands: readonly ["TokenName", "DiagnosticExpectedName"];
        readonly id: 1;
        readonly width: 3;
    }, {
        readonly instruction: "Escape";
        readonly operands: readonly ["RewriteActionEscapeBeginScalarAssignment"];
        readonly id: 2;
        readonly width: 2;
    }, {
        readonly instruction: "Expect";
        readonly operands: readonly ["TokenEquals", "DiagnosticExpectedEqual"];
        readonly id: 1;
        readonly width: 3;
    }, {
        readonly instruction: "Escape";
        readonly operands: readonly ["RewriteActionEscapeFinishScalarAssignmentExpression"];
        readonly id: 2;
        readonly width: 2;
    }, {
        readonly instruction: "Expect";
        readonly operands: readonly ["TokenNewline", "DiagnosticExpectedLine"];
        readonly id: 1;
        readonly width: 3;
    }, {
        readonly instruction: "Escape";
        readonly operands: readonly ["RewriteActionEscapeEmitScalarAssignment"];
        readonly id: 2;
        readonly width: 2;
    }, {
        readonly instruction: "End";
        readonly operands: readonly [];
        readonly id: 0;
        readonly width: 1;
    }];
    readonly width: 16;
}];
export declare const decodeRewriteActionProgram: (bytes: Uint8Array) => readonly number[];
