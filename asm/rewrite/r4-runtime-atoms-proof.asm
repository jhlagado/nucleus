; R4 runtime scalar-expression proof. Semantic records and source text are
; data; every
; compiler-executed instruction uses an ordinary Z80 mnemonic.

CompilerWorkBase    .equ $B000
SourceBase          .equ $7000
SourceLimit         .equ $8200
RewriteAdapterBase  .equ $D000
RewriteAdapterLimit .equ $D100
DebugHooks          .equ 0

            .org $1000
ProofRuntimeAtoms:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,1
            LD   HL,ProofPartsAccepted
            CALL RewriteSourceInitializeParts
            CALL ProofRunScalarConstant
            CALL ProofRunProgramScalar
            CALL ProofRunProgramBss
            CALL ProofRunDirectHeader
            LD   B,7
ProofRuntimeLocalLoop:
            PUSH BC
            CALL ProofRunLocalInitializedExpression
            POP  BC
            DJNZ ProofRuntimeLocalLoop
            LD   A,(RewriteCurrentLocalOffset)
            CP   12
            JP   NZ,ProofFailure
            LD   A,4
            LD   B,RewriteScalarTypeU8
            LD   C,1
            CALL ProofCheckLocal
            LD   A,5
            LD   B,RewriteScalarTypeU16
            LD   C,2
            CALL ProofCheckLocal
            LD   A,6
            LD   B,RewriteScalarTypeI16
            LD   C,4
            CALL ProofCheckLocal
            LD   A,7
            LD   B,RewriteScalarTypeU8
            LD   C,6
            CALL ProofCheckLocal
            LD   A,8
            LD   B,RewriteScalarTypeU16
            LD   C,7
            CALL ProofCheckLocal
            LD   A,9
            LD   B,RewriteScalarTypeI16
            LD   C,9
            CALL ProofCheckLocal
            LD   A,10
            LD   B,RewriteScalarTypeBoolean
            LD   C,11
            CALL ProofCheckLocal
            CALL RewriteSemanticValidate
            LD   A,(RewriteSemanticBufferBase)
            CP   22
            JP   NZ,ProofFailure
            LD   HL,RewriteSemanticPayloadBase
            LD   DE,ProofExpectedSemantics
            LD   B,ProofExpectedSemanticsEnd-ProofExpectedSemantics
ProofRuntimeSemanticLoop:
            LD   A,(DE)
            CP   (HL)
            JP   NZ,ProofFailure
            INC  DE
            INC  HL
            DJNZ ProofRuntimeSemanticLoop
            LD   DE,(RewriteSemanticSinkCursor)
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            CALL ProofRunRoutineEnd
            LD   A,(RewriteSymbolCount)
            CP   3
            JP   NZ,ProofFailure
            CALL ProofRunDirectHeader
            CALL ProofRunRoutineEnd
            CALL ProofRunCompilationEnd
            LD   A,$C0
            LD   (ProofStatus),A
            HALT

ProofRuntimeExpressions:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,1
            LD   HL,ProofPartsExpressions
            CALL RewriteSourceInitializeParts
            CALL ProofRunDirectHeader
            LD   B,12
ProofRuntimeExpressionLocalLoop:
            PUSH BC
            CALL ProofRunLocalInitializedExpression
            POP  BC
            DJNZ ProofRuntimeExpressionLocalLoop
            LD   A,(RewriteCurrentLocalOffset)
            CP   23
            JP   NZ,ProofFailure
            CALL RewriteSemanticValidate
            LD   A,(RewriteSemanticBufferBase)
            CP   79
            JP   NZ,ProofFailure
            LD   HL,RewriteSemanticPayloadBase
            LD   DE,ProofExpectedExpressionSemantics
            LD   BC,ProofExpectedExpressionSemanticsEnd-ProofExpectedExpressionSemantics
ProofRuntimeExpressionSemanticLoop:
            LD   A,B
            OR   C
            JR   Z,ProofRuntimeExpressionSemanticDone
            LD   A,(DE)
            CP   (HL)
            JP   NZ,ProofFailure
            INC  DE
            INC  HL
            DEC  BC
            JR   ProofRuntimeExpressionSemanticLoop
ProofRuntimeExpressionSemanticDone:
            LD   DE,(RewriteSemanticSinkCursor)
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            CALL ProofRunRoutineEnd
            CALL ProofRunDirectHeader
            CALL ProofRunRoutineEnd
            CALL ProofRunCompilationEnd
            LD   A,$C4
            LD   (ProofStatus),A
            HALT

ProofRuntimePaths:
            LD   SP,$FF00
            CALL RewriteReset
            CALL ProofInstallPathMetadata
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,1
            LD   HL,ProofPartsPaths
            CALL RewriteSourceInitializeParts
            CALL ProofRunDirectHeader
            LD   B,9
ProofRuntimePathLocalLoop:
            PUSH BC
            CALL ProofRunLocalInitializedExpression
            POP  BC
            DJNZ ProofRuntimePathLocalLoop
            LD   A,(RewriteCurrentLocalOffset)
            CP   24
            JP   NZ,ProofFailure
            CALL RewriteSemanticValidate
            LD   A,(RewriteSemanticBufferBase)
            CP   63
            JP   NZ,ProofFailure
            LD   HL,RewriteSemanticPayloadBase
            LD   DE,ProofExpectedPathSemantics
            LD   BC,ProofExpectedPathSemanticsEnd-ProofExpectedPathSemantics
ProofRuntimePathSemanticLoop:
            LD   A,B
            OR   C
            JR   Z,ProofRuntimePathSemanticDone
            LD   A,(DE)
            CP   (HL)
            JP   NZ,ProofFailure
            INC  DE
            INC  HL
            DEC  BC
            JR   ProofRuntimePathSemanticLoop
ProofRuntimePathSemanticDone:
            LD   DE,(RewriteSemanticSinkCursor)
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   A,$C9
            LD   (ProofStatus),A
            HALT

ProofRuntimeCalls:
            LD   SP,$FF00
            CALL RewriteReset
            CALL ProofInstallPathMetadata
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,1
            LD   HL,ProofPartsCalls
            CALL RewriteSourceInitializeParts
            CALL ProofRunDirectHeader
            CALL ProofRunRoutineEnd
            CALL ProofRunDirectHeader
            CALL ProofRunRoutineEnd
            CALL ProofRunDirectHeader
            CALL ProofRunRoutineEnd
            CALL ProofRunDirectHeader
            LD   B,5
ProofRuntimeCallLocalLoop:
            PUSH BC
            CALL ProofRunLocalInitializedExpression
            POP  BC
            DJNZ ProofRuntimeCallLocalLoop
            CALL RewriteSemanticValidate
            LD   A,(RewriteSemanticBufferBase)
            CP   30
            JP   NZ,ProofFailure
            LD   HL,RewriteSemanticPayloadBase
            LD   DE,ProofExpectedCallSemantics
            LD   BC,ProofExpectedCallSemanticsEnd-ProofExpectedCallSemantics
ProofRuntimeCallSemanticLoop:
            LD   A,B
            OR   C
            JR   Z,ProofRuntimeCallSemanticDone
            LD   A,(DE)
            CP   (HL)
            JP   NZ,ProofFailure
            INC  DE
            INC  HL
            DEC  BC
            JR   ProofRuntimeCallSemanticLoop
ProofRuntimeCallSemanticDone:
            LD   DE,(RewriteSemanticSinkCursor)
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   A,$CA
            LD   (ProofStatus),A
            HALT

; Writable postfix targets retain one alias carrier across a failable right
; call. The same path engine selects fixed/open array elements, bounded/open
; string bytes, open-string length, and an exact aggregate representation.
ProofRuntimePostfixAssignments:
            LD   SP,$FF00
            CALL RewriteReset
            CALL ProofInstallPathMetadata
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,1
            LD   HL,ProofPartsPostfixAssignments
            CALL RewriteSourceInitializeParts
            CALL ProofRunForwardHeader
            CALL ProofRunDirectHeader
            XOR  A
            LD   (RewriteSemanticBufferBase),A
            LD   HL,RewriteSemanticPayloadBase
            LD   (RewriteSemanticSinkCursor),HL
            LD   B,6
_ProofRuntimePostfixAssignmentLoop:
            PUSH BC
            CALL ProofRunScalarAssignment
            POP  BC
            DJNZ _ProofRuntimePostfixAssignmentLoop
            CALL ProofRunLocalInitializedExpression
            CALL RewriteSemanticValidate
            LD   A,(RewriteSemanticBufferBase)
            CP   ProofExpectedPostfixAssignmentOperationCount
            JP   NZ,ProofFailure
            LD   HL,RewriteSemanticPayloadBase
            LD   DE,ProofExpectedPostfixAssignmentSemantics
            LD   BC,ProofExpectedPostfixAssignmentSemanticsEnd-ProofExpectedPostfixAssignmentSemantics
_ProofRuntimePostfixAssignmentCompare:
            LD   A,B
            OR   C
            JR   Z,_ProofRuntimePostfixAssignmentDone
            LD   A,(DE)
            CP   (HL)
            JP   NZ,ProofFailure
            INC  DE
            INC  HL
            DEC  BC
            JR   _ProofRuntimePostfixAssignmentCompare
_ProofRuntimePostfixAssignmentDone:
            LD   DE,(RewriteSemanticSinkCursor)
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   A,$E7
            LD   (ProofStatus),A
            HALT

ProofRuntimeMainCall:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,1
            LD   HL,ProofPartsMainCall
            CALL RewriteSourceInitializeParts
            CALL ProofRunDirectHeader
            CALL ProofRunLocalInitializedExpression
            CALL RewriteSemanticValidate
            LD   A,(RewriteSemanticBufferBase)
            CP   3
            JP   NZ,ProofFailure
            LD   A,(RewriteSemanticPayloadBase+6)
            CP   RewriteCallModePropagateMain
            JP   NZ,ProofFailure
            LD   A,(RewriteCurrentLocalOffset)
            CP   1
            JP   NZ,ProofFailure
            LD   A,$CB
            LD   (ProofStatus),A
            HALT

; Four source-call frames are the exact accepted nesting boundary. The proof
; observes both transcript validation and complete compiler-frame release.
ProofRuntimeCallDepth:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,1
            LD   HL,ProofPartsCallDepth
            CALL RewriteSourceInitializeParts
            CALL ProofRunForwardHeader
            CALL ProofRunDirectHeader
            CALL ProofRunLocalInitializedExpression
            CALL RewriteSemanticValidate
            LD   A,(RewriteSemanticBufferBase)
            CP   7
            JP   NZ,ProofFailure
            LD   A,(RewriteCallDepth)
            OR   A
            JP   NZ,ProofFailure
            LD   A,$CC
            LD   (ProofStatus),A
            HALT

; Concrete aggregate routine results can bind directly to open string/array
; formals. Both dynamic calls and both preparation records are compared byte
; for byte so the concrete capacities/counts cannot be replaced by wildcards.
ProofRuntimeCallTransientViews:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,1
            LD   HL,ProofPartsCallTransientViews
            CALL RewriteSourceInitializeParts
            CALL ProofRunForwardHeader
            CALL ProofRunForwardHeader
            CALL ProofRunForwardHeader
            CALL ProofRunDirectHeader
            CALL ProofRunLocalInitializedExpression
            CALL RewriteSemanticValidate
            LD   A,(RewriteSemanticBufferBase)
            CP   7
            JP   NZ,ProofFailure
            LD   HL,RewriteSemanticPayloadBase
            LD   DE,ProofExpectedCallTransientSemantics
            LD   B,ProofExpectedCallTransientSemanticsEnd-ProofExpectedCallTransientSemantics
_ProofRuntimeCallTransientLoop:
            LD   A,(DE)
            CP   (HL)
            JP   NZ,ProofFailure
            INC  DE
            INC  HL
            DJNZ _ProofRuntimeCallTransientLoop
            LD   DE,(RewriteSemanticSinkCursor)
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   A,(RewriteCurrentLocalOffset)
            CP   2
            JP   NZ,ProofFailure
            LD   A,$CD
            LD   (ProofStatus),A
            HALT

; A direct routine is visible throughout its own body. This distinguishes
; recursion from lookup that sees only previously completed routines.
ProofRuntimeRecursiveCall:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,1
            LD   HL,ProofPartsRecursiveCall
            CALL RewriteSourceInitializeParts
            CALL ProofRunDirectHeader
            CALL ProofRunLocalInitializedExpression
            CALL RewriteSemanticValidate
            LD   A,(RewriteSemanticBufferBase)
            CP   4
            JP   NZ,ProofFailure
            LD   HL,RewriteSemanticPayloadBase
            LD   DE,ProofExpectedRecursiveCallSemantics
            LD   B,ProofExpectedRecursiveCallSemanticsEnd-ProofExpectedRecursiveCallSemantics
_ProofRuntimeRecursiveCallLoop:
            LD   A,(DE)
            CP   (HL)
            JP   NZ,ProofFailure
            INC  DE
            INC  HL
            DJNZ _ProofRuntimeRecursiveCallLoop
            LD   DE,(RewriteSemanticSinkCursor)
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   A,(RewriteCallDepth)
            OR   A
            JP   NZ,ProofFailure
            LD   A,$CE
            LD   (ProofStatus),A
            HALT

; Scalar assignment statements share the runtime expression engine and retain
; each destination's explicit storage segment. The transcript distinguishes
; BSS, local, and parameter stores without tagging an address bit.
ProofRuntimeScalarAssignments:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,1
            LD   HL,ProofPartsScalarAssignments
            CALL RewriteSourceInitializeParts
            CALL ProofRunProgramScalar
            CALL ProofRunProgramBss
            CALL ProofRunDirectHeader
            CALL ProofRunLocalDefault
            LD   B,5
_ProofRuntimeScalarAssignmentLoop:
            PUSH BC
            CALL ProofRunScalarAssignment
            POP  BC
            DJNZ _ProofRuntimeScalarAssignmentLoop
            CALL RewriteSemanticValidate
            LD   A,(RewriteSemanticBufferBase)
            CP   ProofExpectedScalarAssignmentOperationCount
            JP   NZ,ProofFailure
            LD   HL,RewriteSemanticPayloadBase
            LD   DE,ProofExpectedScalarAssignmentSemantics
            LD   B,ProofExpectedScalarAssignmentSemanticsEnd-ProofExpectedScalarAssignmentSemantics
_ProofRuntimeScalarAssignmentCompare:
            LD   A,(DE)
            CP   (HL)
            JP   NZ,ProofFailure
            INC  DE
            INC  HL
            DJNZ _ProofRuntimeScalarAssignmentCompare
            LD   DE,(RewriteSemanticSinkCursor)
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   A,$CF
            LD   (ProofStatus),A
            HALT

ProofRuntimeAssignmentUnknown:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofExpectedDiagnosticReturn
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,DiagnosticUnknownName
            LD   (ProofExpectedDiagnostic),A
            LD   A,$D6
            LD   (ProofExpectedStatus),A
            LD   HL,11
            LD   (ProofExpectedOffset),HL
            LD   A,1
            LD   HL,ProofPartsAssignmentUnknown
            CALL RewriteSourceInitializeParts
            CALL ProofRunDirectHeader
            CALL ProofRunScalarAssignment
            JP   ProofFailure

ProofRuntimeAssignmentConstant:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofExpectedDiagnosticReturn
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,DiagnosticTypeMismatch
            LD   (ProofExpectedDiagnostic),A
            LD   A,$D7
            LD   (ProofExpectedStatus),A
            LD   HL,23
            LD   (ProofExpectedOffset),HL
            LD   A,1
            LD   HL,ProofPartsAssignmentConstant
            CALL RewriteSourceInitializeParts
            CALL ProofRunScalarConstant
            CALL ProofRunDirectHeader
            CALL ProofRunScalarAssignment
            JP   ProofFailure

ProofRuntimeAssignmentMismatch:
            LD   HL,ProofPartsAssignmentMismatch
            LD   BC,(DiagnosticTypeMismatch<<8)|$D8
            LD   DE,31
ProofArmAssignmentDiagnostic:
            LD   SP,$FF00
            PUSH BC
            PUSH DE
            PUSH HL
            CALL RewriteReset
            POP  HL
            POP  DE
            POP  BC
            LD   A,B
            LD   (ProofExpectedDiagnostic),A
            LD   A,C
            LD   (ProofExpectedStatus),A
            LD   (ProofExpectedOffset),DE
            LD   (RewriteSymbolCompareEntry),HL
            LD   HL,ProofExpectedDiagnosticReturn
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,1
            LD   HL,(RewriteSymbolCompareEntry)
            CALL RewriteSourceInitializeParts
            CALL ProofRunProgramBss
            CALL ProofRunDirectHeader
            CALL ProofRunScalarAssignment
            JP   ProofFailure

ProofRuntimeCallStatements:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,1
            LD   HL,ProofPartsCallStatements
            CALL RewriteSourceInitializeParts
            CALL ProofRunDirectHeader
            CALL ProofRunRoutineEnd
            CALL ProofRunDirectHeader
            CALL ProofRunRoutineEnd
            CALL ProofRunDirectHeader
            LD   B,3
_ProofRuntimeCallStatementLoop:
            PUSH BC
            CALL ProofRunCallStatement
            POP  BC
            DJNZ _ProofRuntimeCallStatementLoop
            CALL RewriteSemanticValidate
            LD   A,(RewriteSemanticBufferBase)
            CP   ProofExpectedCallStatementOperationCount
            JP   NZ,ProofFailure
            LD   HL,RewriteSemanticPayloadBase
            LD   DE,ProofExpectedCallStatementSemantics
            LD   B,ProofExpectedCallStatementSemanticsEnd-ProofExpectedCallStatementSemantics
_ProofRuntimeCallStatementCompare:
            LD   A,(DE)
            CP   (HL)
            JP   NZ,ProofFailure
            INC  DE
            INC  HL
            DJNZ _ProofRuntimeCallStatementCompare
            LD   DE,(RewriteSemanticSinkCursor)
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   A,$D9
            LD   (ProofStatus),A
            HALT

ProofRuntimeCallStatementUnknown:
            LD   HL,ProofPartsCallStatementUnknown
            LD   BC,(DiagnosticUnknownName<<8)|$DA
            LD   DE,11
            JP   ProofArmCallStatementDiagnostic

ProofRuntimeCallStatementMissingElse:
            LD   HL,ProofPartsCallStatementMissingElse
            LD   BC,(DiagnosticFailureContext<<8)|$DB
            LD   DE,44
            JR   ProofArmCallStatementDiagnostic

ProofRuntimeCallStatementInfallibleElse:
            LD   HL,ProofPartsCallStatementInfallibleElse
            LD   BC,(DiagnosticFailureContext<<8)|$DC
            LD   DE,39
ProofArmCallStatementDiagnostic:
            LD   SP,$FF00
            PUSH BC
            PUSH DE
            PUSH HL
            CALL RewriteReset
            POP  HL
            POP  DE
            POP  BC
            LD   A,B
            LD   (ProofExpectedDiagnostic),A
            LD   A,C
            LD   (ProofExpectedStatus),A
            LD   (ProofExpectedOffset),DE
            LD   (RewriteSymbolCompareEntry),HL
            LD   HL,ProofExpectedDiagnosticReturn
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,1
            LD   HL,(RewriteSymbolCompareEntry)
            CALL RewriteSourceInitializeParts
            CALL RewriteParserPeek
            CP   TokenSub
            JR   NZ,_ProofCallStatementSkipFirstRoutine
            CALL ProofRunDirectHeader
            CALL RewriteParserPeek
            CP   TokenEnd
            JR   NZ,_ProofCallStatementCallReady
            CALL ProofRunRoutineEnd
            CALL ProofRunDirectHeader
_ProofCallStatementCallReady:
            CALL ProofRunCallStatement
            JP   ProofFailure
_ProofCallStatementSkipFirstRoutine:
            JP   ProofFailure

; Scalar success returns, explicit failure, bare return, and routine closing
; share one active result/effect summary. The exact transcript distinguishes
; direct exits from the enclosing closing `end`.
ProofRuntimeRoutineExits:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,1
            LD   HL,ProofPartsRoutineExits
            CALL RewriteSourceInitializeParts
            CALL ProofRunDirectHeader
            CALL ProofRunReturnValue
            CALL ProofRunRoutineBodyEnd
            CALL ProofRunDirectHeader
            CALL ProofRunReturnValue
            CALL ProofRunRoutineBodyEnd
            CALL ProofRunDirectHeader
            CALL ProofRunFail
            CALL ProofRunRoutineBodyEnd
            CALL ProofRunDirectHeader
            CALL ProofRunBareReturn
            CALL ProofRunRoutineBodyEnd
            CALL ProofRunDirectHeader
            CALL ProofRunFail
            CALL ProofRunRoutineBodyEnd
            CALL RewriteSemanticValidate
            LD   A,(RewriteSemanticBufferBase)
            CP   ProofExpectedRoutineExitOperationCount
            JP   NZ,ProofFailure
            LD   HL,RewriteSemanticPayloadBase
            LD   DE,ProofExpectedRoutineExitSemantics
            LD   B,ProofExpectedRoutineExitSemanticsEnd-ProofExpectedRoutineExitSemantics
_ProofRuntimeRoutineExitCompare:
            LD   A,(DE)
            CP   (HL)
            JP   NZ,ProofFailure
            INC  DE
            INC  HL
            DJNZ _ProofRuntimeRoutineExitCompare
            LD   DE,(RewriteSemanticSinkCursor)
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   A,(RewriteControlSequenceFallsThrough)
            OR   A
            JP   NZ,ProofFailure
            LD   A,$DE
            LD   (ProofStatus),A
            HALT

; Aggregate results retain one opaque alias carrier and exact referent type.
ProofRuntimeAggregateReturn:
            LD   SP,$FF00
            CALL RewriteReset
            CALL ProofInstallPathMetadata
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,1
            LD   HL,ProofPartsAggregateReturn
            CALL RewriteSourceInitializeParts
            CALL ProofRunDirectHeader
            CALL ProofRunReturnValue
            CALL ProofRunRoutineBodyEnd
            CALL RewriteSemanticValidate
            LD   A,(RewriteSemanticBufferBase)
            CP   3
            JP   NZ,ProofFailure
            LD   HL,RewriteSemanticPayloadBase
            LD   DE,ProofExpectedAggregateReturnSemantics
            LD   B,ProofExpectedAggregateReturnSemanticsEnd-ProofExpectedAggregateReturnSemantics
_ProofRuntimeAggregateReturnCompare:
            LD   A,(DE)
            CP   (HL)
            JP   NZ,ProofFailure
            INC  DE
            INC  HL
            DJNZ _ProofRuntimeAggregateReturnCompare
            LD   DE,(RewriteSemanticSinkCursor)
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   A,$E4
            LD   (ProofStatus),A
            HALT

ProofRuntimeBareValueReturn:
            LD   HL,ProofPartsBareValueReturn
            LD   BC,(DiagnosticRoutineFlow<<8)|$DF
            LD   DE,ProofBareValueReturnAnchor-ProofSourceBareValueReturn
            LD   A,0
            JP   ProofArmRoutineExitDiagnostic
ProofRuntimeValueInVoidReturn:
            LD   HL,ProofPartsValueInVoidReturn
            LD   BC,(DiagnosticRoutineFlow<<8)|$E0
            LD   DE,ProofValueInVoidReturnAnchor-ProofSourceValueInVoidReturn
            LD   A,1
            JP   ProofArmRoutineExitDiagnostic
ProofRuntimeFailInfallible:
            LD   HL,ProofPartsFailInfallible
            LD   BC,(DiagnosticFailureContext<<8)|$E1
            LD   DE,ProofFailInfallibleAnchor-ProofSourceFailInfallible
            LD   A,2
            JP   ProofArmRoutineExitDiagnostic
ProofRuntimeValueFallthrough:
            LD   HL,ProofPartsValueFallthrough
            LD   BC,(DiagnosticRoutineFlow<<8)|$E2
            LD   DE,ProofValueFallthroughAnchor-ProofSourceValueFallthrough
            LD   A,3
            JP   ProofArmRoutineExitDiagnostic
ProofRuntimeFailWrongType:
            LD   HL,ProofPartsFailWrongType
            LD   BC,(DiagnosticTypeMismatch<<8)|$E3
            LD   DE,ProofFailWrongTypeAnchor-ProofSourceFailWrongType
            LD   A,2
            JP   ProofArmRoutineExitDiagnostic
ProofRuntimeReturnFailableCall:
            LD   SP,$FF00
            CALL RewriteReset
            LD   A,DiagnosticFailureContext
            LD   (ProofExpectedDiagnostic),A
            LD   A,$E5
            LD   (ProofExpectedStatus),A
            LD   HL,ProofReturnFailableCallAnchor-ProofSourceReturnFailableCall
            LD   (ProofExpectedOffset),HL
            LD   HL,ProofExpectedDiagnosticReturn
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,1
            LD   HL,ProofPartsReturnFailableCall
            CALL RewriteSourceInitializeParts
            CALL ProofRunForwardHeader
            CALL ProofRunDirectHeader
            CALL ProofRunReturnValue
            JP   ProofFailure
ProofArmRoutineExitDiagnostic:
            LD   (ProofExpectedForwardCount),A
            LD   A,B
            LD   (ProofExpectedDiagnostic),A
            LD   A,C
            LD   (ProofExpectedStatus),A
            LD   (ProofExpectedOffset),DE
            PUSH HL
            CALL RewriteReset
            POP  DE
            LD   HL,ProofExpectedDiagnosticReturn
            PUSH HL
            LD   (CompilerAbortSp),SP
            EX   DE,HL
            LD   A,1
            CALL RewriteSourceInitializeParts
            CALL ProofRunDirectHeader
            LD   A,(ProofExpectedForwardCount)
            OR   A
            JR   Z,_ProofRoutineExitBare
            DEC  A
            JR   Z,_ProofRoutineExitValue
            DEC  A
            JR   Z,_ProofRoutineExitFail
            CALL ProofRunRoutineBodyEnd
            JP   ProofFailure
_ProofRoutineExitBare:
            CALL ProofRunBareReturn
            JP   ProofFailure
_ProofRoutineExitValue:
            CALL ProofRunReturnValue
            JP   ProofFailure
_ProofRoutineExitFail:
            CALL ProofRunFail
            JP   ProofFailure

; Install five owned types, two nominal record layouts, four fields, one BSS
; aggregate root, and one read-only aggregate constant. These blocks are
; metadata fixtures, not instructions.
.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
ProofInstallPathMetadata:
            LD   HL,ProofPathTypeDescriptors
            LD   DE,RewriteTypeTableBase
            LD   BC,ProofPathTypeDescriptorsEnd-ProofPathTypeDescriptors
            LDIR
            LD   HL,ProofPathTypeExtents
            LD   DE,RewriteTypeExtentBase
            LD   BC,ProofPathTypeExtentsEnd-ProofPathTypeExtents
            LDIR
            LD   HL,ProofPathRecords
            LD   DE,RewriteRecordTableBase
            LD   BC,ProofPathRecordsEnd-ProofPathRecords
            LDIR
            LD   HL,ProofPathFields
            LD   DE,RewriteFieldTableBase
            LD   BC,ProofPathFieldsEnd-ProofPathFields
            LDIR
            LD   HL,ProofPathRootSymbols
            LD   DE,RewriteSymbolTableBase
            LD   BC,ProofPathRootSymbolsEnd-ProofPathRootSymbols
            LDIR
            LD   A,5
            LD   (RewriteTypeCount),A
            LD   A,2
            LD   (RewriteRecordCount),A
            LD   A,4
            LD   (RewriteFieldCount),A
            LD   A,2
            LD   (RewriteSymbolCount),A
            LD   HL,39
            LD   (RewriteStaticBssLength),HL
            XOR  A
            RET

ProofRuntimeMismatch:
            LD   HL,ProofPartsMismatch
            LD   BC,(DiagnosticTypeMismatch<<8)|$C1
            LD   DE,31
            JP   ProofArmRuntimeDiagnostic
ProofRuntimeSelfReference:
            LD   HL,ProofPartsSelfReference
            LD   BC,(DiagnosticUnknownName<<8)|$C2
            LD   DE,25
            JP   ProofArmRuntimeDiagnostic
ProofRuntimeTrailingToken:
            LD   HL,ProofPartsTrailingToken
            LD   BC,(DiagnosticExpectedLine<<8)|$C3
            LD   DE,27
            JP   ProofArmRuntimeDiagnostic
ProofRuntimeDivisionZero:
            LD   HL,ProofPartsDivisionZero
            LD   BC,(DiagnosticDivisionZero<<8)|$C5
            LD   DE,29
            JP   ProofArmRuntimeDiagnostic
ProofRuntimeBooleanXor:
            LD   HL,ProofPartsBooleanXor
            LD   BC,(DiagnosticTypeMismatch<<8)|$C6
            LD   DE,52
            JP   ProofArmRuntimeDiagnostic
ProofRuntimeComparisonChain:
            LD   HL,ProofPartsComparisonChain
            LD   BC,(DiagnosticComparisonChain<<8)|$C7
            LD   DE,45
            JP   ProofArmRuntimeDiagnostic
ProofRuntimeMixedWords:
            LD   HL,ProofPartsMixedWords
            LD   BC,(DiagnosticTypeMismatch<<8)|$C8
            LD   DE,51
            JP   ProofArmRuntimeDiagnostic

ProofRuntimePathCapacity:
            LD   HL,ProofPartsPathCapacity
            LD   BC,(DiagnosticTypeMismatch<<8)|$CA
            LD   DE,ProofPathCapacityName-ProofSourcePathCapacity
            JP   ProofArmPathDiagnostic
ProofRuntimePathRange:
            LD   HL,ProofPartsPathRange
            LD   BC,(DiagnosticIntegerRange<<8)|$CB
            LD   DE,ProofPathRangeValue-ProofSourcePathRange
            JP   ProofArmPathDiagnostic
ProofRuntimePathBooleanIndex:
            LD   HL,ProofPartsPathBooleanIndex
            LD   BC,(DiagnosticTypeMismatch<<8)|$CC
            LD   DE,ProofPathBooleanClose-ProofSourcePathBooleanIndex
            JP   ProofArmPathDiagnostic
ProofRuntimePathNegativeIndex:
            LD   HL,ProofPartsPathNegativeIndex
            LD   BC,(DiagnosticIntegerRange<<8)|$CD
            LD   DE,ProofPathNegativeValue-ProofSourcePathNegativeIndex
            JP   ProofArmPathDiagnostic
ProofRuntimePathUnknownField:
            LD   HL,ProofPartsPathUnknownField
            LD   BC,(DiagnosticUnknownName<<8)|$CE
            LD   DE,ProofPathUnknownFieldName-ProofSourcePathUnknownField
            JP   ProofArmPathDiagnostic

ProofRuntimeCallMissingConsumer:
            LD   HL,ProofPartsCallMissingConsumer
            LD   BC,(DiagnosticFailureContext<<8)|$D0
            LD   DE,ProofCallMissingConsumerAnchor-ProofSourceCallMissingConsumer
            LD   A,1
            JP   ProofArmCallDiagnostic
ProofRuntimeCallInfallibleElse:
            LD   HL,ProofPartsCallInfallibleElse
            LD   BC,(DiagnosticFailureContext<<8)|$D1
            LD   DE,ProofCallInfallibleElseAnchor-ProofSourceCallInfallibleElse
            LD   A,1
            JP   ProofArmCallDiagnostic
ProofRuntimeCallGroupedFailure:
            LD   HL,ProofPartsCallGroupedFailure
            LD   BC,(DiagnosticFailureContext<<8)|$D2
            LD   DE,ProofCallGroupedFailureAnchor-ProofSourceCallGroupedFailure
            LD   A,1
            JP   ProofArmCallDiagnostic
ProofRuntimeCallConvertedFailure:
            LD   HL,ProofPartsCallConvertedFailure
            LD   BC,(DiagnosticFailureContext<<8)|$D3
            LD   DE,ProofCallConvertedFailureAnchor-ProofSourceCallConvertedFailure
            LD   A,1
            JP   ProofArmCallDiagnostic
ProofRuntimeCallUnaryFailure:
            LD   HL,ProofPartsCallUnaryFailure
            LD   BC,(DiagnosticFailureContext<<8)|$D4
            LD   DE,ProofCallUnaryFailureAnchor-ProofSourceCallUnaryFailure
            LD   A,1
            JP   ProofArmCallDiagnostic
ProofRuntimeCallStrayElse:
            LD   HL,ProofPartsCallStrayElse
            LD   BC,(DiagnosticFailureContext<<8)|$D5
            LD   DE,ProofCallStrayElseAnchor-ProofSourceCallStrayElse
            LD   A,1
            JP   ProofArmCallDiagnostic
ProofRuntimeCallLiteralOpen:
            LD   HL,ProofPartsCallLiteralOpen
            LD   BC,(DiagnosticExpectedName<<8)|$D6
            LD   DE,ProofCallLiteralOpenAnchor-ProofSourceCallLiteralOpen
            LD   A,1
            JP   ProofArmCallDiagnostic
ProofRuntimeCallNestedFailure:
            LD   HL,ProofPartsCallNestedFailure
            LD   BC,(DiagnosticFailureContext<<8)|$D7
            LD   DE,ProofCallNestedFailureAnchor-ProofSourceCallNestedFailure
            LD   A,2
            JP   ProofArmCallDiagnostic
ProofRuntimeCallDepthOverflow:
            LD   HL,ProofPartsCallDepthOverflow
            LD   BC,(DiagnosticExpressionCapacity<<8)|$D8
            LD   DE,ProofCallDepthOverflowAnchor-ProofSourceCallDepthOverflow
            LD   A,1
            JP   ProofArmCallDiagnostic
ProofRuntimeCallTooFew:
            LD   HL,ProofPartsCallTooFew
            LD   BC,(DiagnosticExpectedScalar<<8)|$D9
            LD   DE,ProofCallTooFewAnchor-ProofSourceCallTooFew
            LD   A,1
            JP   ProofArmCallDiagnostic
ProofRuntimeCallTooMany:
            LD   HL,ProofPartsCallTooMany
            LD   BC,(DiagnosticExpectedRight<<8)|$DA
            LD   DE,ProofCallTooManyAnchor-ProofSourceCallTooMany
            LD   A,1
            JP   ProofArmCallDiagnostic
ProofRuntimeCallWrongType:
            LD   HL,ProofPartsCallWrongType
            LD   BC,(DiagnosticTypeMismatch<<8)|$DB
            LD   DE,ProofCallWrongTypeAnchor-ProofSourceCallWrongType
            LD   A,1
            JP   ProofArmCallDiagnostic
ProofRuntimeCallIndexFailure:
            LD   HL,ProofPartsCallIndexFailure
            LD   BC,(DiagnosticFailureContext<<8)|$DC
            LD   DE,ProofCallIndexFailureAnchor-ProofSourceCallIndexFailure
            LD   A,$81
            JP   ProofArmCallDiagnostic
ProofRuntimeCallBinaryFailure:
            LD   HL,ProofPartsCallBinaryFailure
            LD   BC,(DiagnosticFailureContext<<8)|$DD
            LD   DE,ProofCallBinaryFailureAnchor-ProofSourceCallBinaryFailure
            LD   A,1
            JP   ProofArmCallDiagnostic

ProofRuntimeAssignmentReadOnlyAggregate:
            LD   HL,ProofPartsAssignmentReadOnlyAggregate
            LD   BC,(DiagnosticReadOnlyAssignment<<8)|$E8
            LD   DE,ProofAssignmentReadOnlyTarget-ProofSourceAssignmentReadOnlyAggregate
            JP   ProofArmPostfixAssignmentDiagnostic
ProofRuntimeAssignmentFixedStringLength:
            LD   HL,ProofPartsAssignmentFixedStringLength
            LD   BC,(DiagnosticTypeMismatch<<8)|$E9
            LD   DE,ProofAssignmentFixedLengthName-ProofSourceAssignmentFixedStringLength
            JP   ProofArmPostfixAssignmentDiagnostic
ProofRuntimeAssignmentOpenWhole:
            LD   HL,ProofPartsAssignmentOpenWhole
            LD   BC,(DiagnosticTypeMismatch<<8)|$EA
            LD   DE,ProofAssignmentOpenWholeLine-ProofSourceAssignmentOpenWhole
            JP   ProofArmPostfixAssignmentDiagnostic

; HL source descriptor, B diagnostic, C status, DE exact offset. Aggregate
; path metadata is installed before the source-visible routine and assignment.
.routine noreturn
ProofArmPostfixAssignmentDiagnostic:
            LD   A,B
            LD   (ProofExpectedDiagnostic),A
            LD   A,C
            LD   (ProofExpectedStatus),A
            LD   (ProofExpectedOffset),DE
            PUSH HL
            CALL RewriteReset
            CALL ProofInstallPathMetadata
            POP  DE
            LD   HL,ProofExpectedDiagnosticReturn
            PUSH HL
            LD   (CompilerAbortSp),SP
            EX   DE,HL
            LD   A,1
            CALL RewriteSourceInitializeParts
            CALL ProofRunDirectHeader
            CALL ProofRunScalarAssignment
            JP   ProofFailure

; HL source descriptor, B diagnostic, C status, DE exact offset. Path metadata
; is installed after reset and before the source-visible routine is parsed.
.routine noreturn
ProofArmPathDiagnostic:
            LD   A,B
            LD   (ProofExpectedDiagnostic),A
            LD   A,C
            LD   (ProofExpectedStatus),A
            LD   (ProofExpectedOffset),DE
            PUSH HL
            CALL RewriteReset
            CALL ProofInstallPathMetadata
            POP  DE
            LD   HL,ProofExpectedDiagnosticReturn
            PUSH HL
            LD   (CompilerAbortSp),SP
            EX   DE,HL
            LD   A,1
            CALL RewriteSourceInitializeParts
            CALL ProofRunDirectHeader
            CALL ProofRunLocalInitializedExpression
            JP   ProofFailure

; HL source descriptor, B diagnostic, C status, DE exact offset.
.routine noreturn
ProofArmRuntimeDiagnostic:
            LD   A,B
            LD   (ProofExpectedDiagnostic),A
            LD   A,C
            LD   (ProofExpectedStatus),A
            LD   (ProofExpectedOffset),DE
            PUSH HL
            CALL RewriteReset
            POP  DE
            LD   HL,ProofExpectedDiagnosticReturn
            PUSH HL
            LD   (CompilerAbortSp),SP
            EX   DE,HL
            LD   A,1
            CALL RewriteSourceInitializeParts
            CALL ProofRunDirectHeader
            CALL ProofRunLocalInitializedExpression
            JP   ProofFailure

; HL source descriptor, B diagnostic, C status, DE exact offset, A number of
; retained forward signatures before the direct routine containing the local.
.routine noreturn
ProofArmCallDiagnostic:
            LD   (ProofExpectedForwardCount),A
            LD   A,B
            LD   (ProofExpectedDiagnostic),A
            LD   A,C
            LD   (ProofExpectedStatus),A
            LD   (ProofExpectedOffset),DE
            PUSH HL
            CALL RewriteReset
            LD   A,(ProofExpectedForwardCount)
            BIT  7,A
            CALL NZ,ProofInstallPathMetadata
            POP  DE
            LD   HL,ProofExpectedDiagnosticReturn
            PUSH HL
            LD   (CompilerAbortSp),SP
            EX   DE,HL
            LD   A,1
            CALL RewriteSourceInitializeParts
            LD   A,(ProofExpectedForwardCount)
            AND  $7F
            LD   B,A
            LD   C,0
_ProofArmCallForwardLoop:
            PUSH BC
            CALL ProofRunForwardHeader
            POP  BC
            DJNZ _ProofArmCallForwardLoop
            CALL ProofRunDirectHeader
            CALL ProofRunLocalInitializedExpression
            JP   ProofFailure

ProofExpectedDiagnosticReturn:
            LD   A,(DiagnosticCode)
            LD   B,A
            LD   A,(ProofExpectedDiagnostic)
            CP   B
            JP   NZ,ProofFailure
            LD   A,(DiagnosticPartId)
            CP   1
            JP   NZ,ProofFailure
            LD   HL,(DiagnosticOffset)
            LD   DE,(ProofExpectedOffset)
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   A,(ProofExpectedStatus)
            LD   (ProofStatus),A
            HALT

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunScalarConstant:
            LD   HL,RewriteActionProgramScalarConstant
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunProgramScalar:
            LD   HL,RewriteActionProgramProgramScalarInitialized
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunProgramBss:
            LD   HL,RewriteActionProgramProgramBss
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunDirectHeader:
            LD   HL,RewriteActionProgramRoutineDirectHeader
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunForwardHeader:
            LD   HL,RewriteActionProgramRoutineForwardHeader
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunLocalInitializedExpression:
            LD   HL,RewriteActionProgramLocalInitializedExpression
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunLocalDefault:
            LD   HL,RewriteActionProgramLocalDefault
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunScalarAssignment:
            LD   HL,RewriteActionProgramScalarAssignment
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunCallStatement:
            LD   HL,RewriteActionProgramCallStatement
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunReturnValue:
            LD   HL,RewriteActionProgramReturnValue
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunBareReturn:
            LD   HL,RewriteActionProgramBareReturn
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunFail:
            LD   HL,RewriteActionProgramFail
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunRoutineBodyEnd:
            LD   HL,RewriteActionProgramRoutineBodyEnd
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunRoutineEnd:
            LD   HL,RewriteActionProgramRoutineEnd
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunCompilationEnd:
            LD   HL,RewriteActionProgramCompilationEnd
            JP   RewriteActionRun

; A symbol ordinal, B exact type, C activation byte offset.
.routine in A,B,C out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ProofCheckLocal:
            PUSH BC
            CALL RewriteSymbolAddress
            POP  BC
            LD   DE,RewriteSymbolClass
            ADD  HL,DE
            LD   A,(HL)
            CP   RewriteSymbolClassLocal
            JP   NZ,ProofFailure
            INC  HL
            LD   A,(HL)
            CP   B
            JP   NZ,ProofFailure
            INC  HL
            LD   A,(HL)
            CP   C
            JP   NZ,ProofFailure
            INC  HL
            LD   A,(HL)
            OR   A
            JP   NZ,ProofFailure
            INC  HL
            LD   A,(HL)
            CP   RewriteSymbolStorageActivation
            JP   NZ,ProofFailure
            RET

ProofUnexpectedDiagnostic:
            LD   A,(DiagnosticCode)
            LD   (ProofStatus),A
            HALT
ProofFailure:
            LD   A,$FF
            LD   (ProofStatus),A
            HALT

            .include "compiler-image.asmi"

ProofStatus:             .db 0
ProofExpectedDiagnostic: .db 0
ProofExpectedStatus:     .db 0
ProofExpectedOffset:     .dw 0
ProofExpectedForwardCount: .db 0

ProofExpectedSemantics:
            .db RewriteSemanticDeclareLocalU8,1
            .db RewriteSemanticLoadParameter8,0
            .db RewriteSemanticStoreLocalU8,1
            .db RewriteSemanticDeclareLocal16,2
            .db RewriteSemanticLoadLocalU8,1
            .db RewriteSemanticStoreLocal16,2
            .db RewriteSemanticDeclareLocal16,4
            .db RewriteSemanticLiteral16,5,0
            .db RewriteSemanticStoreLocal16,4
            .db RewriteSemanticDeclareLocalU8,6
            .db RewriteSemanticLoadProgramU8,0,0
            .db RewriteSemanticStoreLocalU8,6
            .db RewriteSemanticDeclareLocal16,7
            .db RewriteSemanticLoadBss16,0,0
            .db RewriteSemanticStoreLocal16,7
            .db RewriteSemanticDeclareLocal16,9
            .db RewriteSemanticLiteral16,7,0
            .db RewriteSemanticConvertInteger,RewriteScalarTypeI8,RewriteScalarTypeI16
            .dw ProofSignedConversionToken-ProofSourceAccepted
            .db RewriteSemanticStoreLocal16,9
            .db RewriteSemanticDeclareLocalU8,11
            .db RewriteSemanticLiteral16,1,0
            .db RewriteSemanticStoreLocalU8,11
ProofExpectedSemanticsEnd:

ProofExpectedExpressionSemantics:
            .db RewriteSemanticDeclareLocal16,5
            .db RewriteSemanticLoadParameter8,0
            .db RewriteSemanticLiteral16,2,0
            .db RewriteSemanticDivide8
            .dw ProofUnsignedDivideToken-ProofSourceExpressions
            .db RewriteSemanticLiteral16,2,0
            .db RewriteSemanticLiteral16,3,0
            .db RewriteSemanticMultiply16
            .db RewriteSemanticAdd16
            .db RewriteSemanticStoreLocal16,5

            .db RewriteSemanticDeclareLocal16,7
            .db RewriteSemanticLoadParameter8,1
            .db RewriteSemanticLoadParameter16,2
            .db RewriteSemanticPromoteI8Pair,1
            .db RewriteSemanticAdd16
            .db RewriteSemanticStoreLocal16,7

            .db RewriteSemanticDeclareLocal16,9
            .db RewriteSemanticLoadParameter16,2
            .db RewriteSemanticLoadParameter8,1
            .db RewriteSemanticPromoteI8Pair,0
            .db RewriteSemanticSubtract16
            .db RewriteSemanticStoreLocal16,9

            .db RewriteSemanticDeclareLocal16,11
            .db RewriteSemanticLoadParameter8,0
            .db RewriteSemanticLoadParameter8,1
            .db RewriteSemanticPromoteI8Pair,0
            .db RewriteSemanticAdd16
            .db RewriteSemanticStoreLocal16,11

            .db RewriteSemanticDeclareLocal16,13
            .db RewriteSemanticLoadParameter16,2
            .db RewriteSemanticNegate16
            .db RewriteSemanticLiteral16,2,0
            .db RewriteSemanticDivideSigned,$40
            .dw ProofSignedDivideToken-ProofSourceExpressions
            .db RewriteSemanticStoreLocal16,13

            .db RewriteSemanticDeclareLocalU8,15
            .db RewriteSemanticLoadParameter8,1
            .db RewriteSemanticLiteral16,3,0
            .db RewriteSemanticDivideSigned,$C1
            .dw ProofSignedModuloToken-ProofSourceExpressions
            .db RewriteSemanticStoreLocalU8,15

            .db RewriteSemanticDeclareLocalU8,16
            .db RewriteSemanticLoadParameter8,1
            .db RewriteSemanticLoadParameter8,0
            .db RewriteSemanticPromoteI8Pair,1
            .db RewriteSemanticCompare16,$82
            .db RewriteSemanticStoreLocalU8,16

            .db RewriteSemanticDeclareLocalU8,17
            .db RewriteSemanticLoadParameter8,4
            .db RewriteSemanticLiteral16,1,0
            .db RewriteSemanticCompareBoolean,0
            .db RewriteSemanticStoreLocalU8,17

            .db RewriteSemanticDeclareLocalU8,18
            .db RewriteSemanticLoadParameter8,0
            .db RewriteSemanticLiteral16,7,0
            .db RewriteSemanticAnd8
            .db RewriteSemanticLiteral16,1,0
            .db RewriteSemanticXor8
            .db RewriteSemanticStoreLocalU8,18

            .db RewriteSemanticDeclareLocalU8,19
            .db RewriteSemanticLoadParameter8,4
            .db RewriteSemanticBeginBooleanAnd
            .db RewriteSemanticLiteral16,1,0
            .db RewriteSemanticBeginBooleanOr
            .db RewriteSemanticLiteral16,1,0
            .db RewriteSemanticLiteral16,0,0
            .db RewriteSemanticDivide16
            .dw ProofSuppressedDivideToken-ProofSourceExpressions
            .db RewriteSemanticLiteral16,0,0
            .db RewriteSemanticCompare16,0
            .db RewriteSemanticEndBoolean
            .db RewriteSemanticEndBoolean
            .db RewriteSemanticStoreLocalU8,19

            .db RewriteSemanticDeclareLocal16,20
            .db RewriteSemanticLoadLocal16,5
            .db RewriteSemanticLiteral16,5,0
            .db RewriteSemanticModulo16
            .dw ProofUnsignedModuloToken-ProofSourceExpressions
            .db RewriteSemanticNot16
            .db RewriteSemanticStoreLocal16,20

            .db RewriteSemanticDeclareLocalU8,22
            .db RewriteSemanticLoadParameter8,4
            .db RewriteSemanticNotBoolean
            .db RewriteSemanticStoreLocalU8,22
ProofExpectedExpressionSemanticsEnd:

ProofExpectedPathSemantics:
            ; root.inner.values[1]
            .db RewriteSemanticDeclareLocal16,11
            .db RewriteSemanticLoadBssAlias,0,0
            .db RewriteSemanticSelectField,0,0
            .db RewriteSemanticSelectField,7,0
            .db RewriteSemanticLiteral16,1,0
            .db RewriteSemanticSelectIndex,3,0,2,0
            .dw ProofPathValuesIndex-ProofSourcePaths
            .db RewriteSemanticLoadIndirect16
            .db RewriteSemanticStoreLocal16,11

            ; root.items[1].values.length
            .db RewriteSemanticDeclareLocal16,13
            .db RewriteSemanticLoadBssAlias,0,0
            .db RewriteSemanticSelectField,13,0
            .db RewriteSemanticLiteral16,1,0
            .db RewriteSemanticSelectIndex,2,0,13,0
            .dw ProofPathItemsIndex-ProofSourcePaths
            .db RewriteSemanticSelectField,7,0
            .db RewriteSemanticArrayLength,3,0
            .db RewriteSemanticStoreLocal16,13

            ; root.inner.text[2]
            .db RewriteSemanticDeclareLocalU8,15
            .db RewriteSemanticLoadBssAlias,0,0
            .db RewriteSemanticSelectField,0,0
            .db RewriteSemanticSelectField,0,0
            .db RewriteSemanticLiteral16,2,0
            .db RewriteSemanticStringIndex,5
            .dw ProofPathTextIndex-ProofSourcePaths
            .db RewriteSemanticLoadIndirect8
            .db RewriteSemanticStoreLocalU8,15

            ; root.inner.text.length
            .db RewriteSemanticDeclareLocalU8,16
            .db RewriteSemanticLoadBssAlias,0,0
            .db RewriteSemanticSelectField,0,0
            .db RewriteSemanticSelectField,0,0
            .db RewriteSemanticStringLength,5
            .dw ProofPathTextLength-ProofSourcePaths
            .db RewriteSemanticStoreLocalU8,16

            ; xs.length + row[1]
            .db RewriteSemanticDeclareLocal16,17
            .db RewriteSemanticLoadParameterAlias,0
            .db RewriteSemanticOpenArrayLength,2
            .db RewriteSemanticLoadParameterAlias,9
            .db RewriteSemanticLiteral16,1,0
            .db RewriteSemanticSelectIndex,3,0,2,0
            .dw ProofPathRowIndex-ProofSourcePaths
            .db RewriteSemanticLoadIndirect16
            .db RewriteSemanticAdd16
            .db RewriteSemanticStoreLocal16,17

            ; xs[ix]
            .db RewriteSemanticDeclareLocal16,19
            .db RewriteSemanticLoadParameterAlias,0
            .db RewriteSemanticLoadParameter16,7
            .db RewriteSemanticConvertInteger,RewriteScalarTypeI16,RewriteScalarTypeU16+$80
            .dw ProofPathDynamicIndexName-ProofSourcePaths
            .db RewriteSemanticOpenArrayIndex,2,2,0
            .dw ProofPathDynamicIndex-ProofSourcePaths
            .db RewriteSemanticLoadIndirect16
            .db RewriteSemanticStoreLocal16,19

            ; text.length + ro.length
            .db RewriteSemanticDeclareLocalU8,21
            .db RewriteSemanticLoadParameterAlias,4
            .db RewriteSemanticOpenStringLength,6
            .dw ProofPathOpenTextLength-ProofSourcePaths
            .db RewriteSemanticLoadReadOnlyAlias,45,1
            .db RewriteSemanticStringLength,5
            .dw ProofPathReadOnlyLength-ProofSourcePaths
            .db RewriteSemanticAdd8
            .db RewriteSemanticStoreLocalU8,21

            .db RewriteSemanticDeclareLocalU8,22
            .db RewriteSemanticLoadParameterAlias,4
            .db RewriteSemanticOpenStringCapacity,6
            .db RewriteSemanticStoreLocalU8,22

            .db RewriteSemanticDeclareLocalU8,23
            .db RewriteSemanticLoadParameterAlias,4
            .db RewriteSemanticLiteral16,1,0
            .db RewriteSemanticOpenStringIndex,6
            .dw ProofPathOpenTextIndex-ProofSourcePaths
            .db RewriteSemanticLoadIndirect8
            .db RewriteSemanticStoreLocalU8,23
ProofExpectedPathSemanticsEnd:

ProofExpectedPostfixAssignmentOperationCount .equ 35
ProofExpectedPostfixAssignmentSemantics:
            ; root.inner.values[1] = maybe() else fail
            .db RewriteSemanticLoadBssAlias,0,0
            .db RewriteSemanticSelectField,0,0
            .db RewriteSemanticSelectField,7,0
            .db RewriteSemanticLiteral16,1,0
            .db RewriteSemanticSelectIndex,3,0,2,0
            .dw ProofPostfixFixedIndex-ProofSourcePostfixAssignments
            .db RewriteSemanticCallSource,0,0,RewriteScalarTypeU16,RewriteRoutineFlagFails+RewriteCallFlagKeepResult
            .dw ProofPostfixCall-ProofSourcePostfixAssignments
            .db RewriteCallModePropagateRoutine,0,1
            .db RewriteSemanticStoreIndirect16

            ; root.inner.text[2] = 65
            .db RewriteSemanticLoadBssAlias,0,0
            .db RewriteSemanticSelectField,0,0
            .db RewriteSemanticSelectField,0,0
            .db RewriteSemanticLiteral16,2,0
            .db RewriteSemanticStringIndex,5
            .dw ProofPostfixStringIndex-ProofSourcePostfixAssignments
            .db RewriteSemanticLiteral16,65,0
            .db RewriteSemanticStoreIndirect8

            ; xs[1] = 7
            .db RewriteSemanticLoadParameterAlias,0
            .db RewriteSemanticLiteral16,1,0
            .db RewriteSemanticOpenArrayIndex,2,2,0
            .dw ProofPostfixOpenArrayIndex-ProofSourcePostfixAssignments
            .db RewriteSemanticLiteral16,7,0
            .db RewriteSemanticStoreIndirect16

            ; text[1] = 66
            .db RewriteSemanticLoadParameterAlias,4
            .db RewriteSemanticLiteral16,1,0
            .db RewriteSemanticOpenStringIndex,6
            .dw ProofPostfixOpenStringIndex-ProofSourcePostfixAssignments
            .db RewriteSemanticLiteral16,66,0
            .db RewriteSemanticStoreIndirect8

            ; text.length = 3
            .db RewriteSemanticLoadParameterAlias,4
            .db RewriteSemanticLiteral16,3,0
            .db RewriteSemanticOpenStringResize,6
            .dw ProofPostfixResizeValue-ProofSourcePostfixAssignments

            ; root.inner = root.inner
            .db RewriteSemanticLoadBssAlias,0,0
            .db RewriteSemanticSelectField,0,0
            .db RewriteSemanticLoadBssAlias,0,0
            .db RewriteSemanticSelectField,0,0
            .db RewriteSemanticCopyAggregate,13,0
            .dw ProofPostfixCopySource-ProofSourcePostfixAssignments

            ; A following local call does not inherit the retained carrier.
            .db RewriteSemanticDeclareLocal16,7
            .db RewriteSemanticCallSource,0,0,RewriteScalarTypeU16,RewriteRoutineFlagFails+RewriteCallFlagKeepResult
            .dw ProofPostfixFreshCall-ProofSourcePostfixAssignments
            .db RewriteCallModePropagateRoutine,0,0
            .db RewriteSemanticStoreLocal16,7
ProofExpectedPostfixAssignmentSemanticsEnd:

; Exact call transcript. Every .db/.dw item is semantic data and the word
; operands are source-relative offsets, never assembled instruction addresses.
ProofExpectedCallSemantics:
            .db RewriteSemanticDeclareLocal16,7
            .db RewriteSemanticLiteral16,1,0
            .db RewriteSemanticLiteral16,2,0
            .db RewriteSemanticLiteral16,3,0
            .db RewriteSemanticCallSource,0,2,RewriteScalarTypeU16,RewriteCallFlagKeepResult
            .dw ProofCallSumNested-ProofSourceCalls
            .db RewriteCallModeInfallible,0,0
            .db RewriteSemanticCallSource,0,2,RewriteScalarTypeU16,RewriteCallFlagKeepResult
            .dw ProofCallSum-ProofSourceCalls
            .db RewriteCallModeInfallible,0,0
            .db RewriteSemanticStoreLocal16,7
            .db RewriteSemanticDeclareLocalU8,9
            .db RewriteSemanticLiteral16,3,0
            .db RewriteSemanticCallSource,1,1,RewriteScalarTypeU8,RewriteRoutineFlagFails+RewriteCallFlagKeepResult
            .dw ProofCallMaybe-ProofSourceCalls
            .db RewriteCallModePropagateRoutine,0,0
            .db RewriteSemanticStoreLocalU8,9
            .db RewriteSemanticDeclareLocalU8,10
            .db RewriteSemanticCallService,RewriteCallFlagKeepResult
            .dw ProofCallService-ProofSourceCalls
            .db RewriteCallModePropagateRoutine,0,0
            .db RewriteSemanticStoreLocalU8,10
            .db RewriteSemanticDeclareLocal16,11
            .db RewriteSemanticLoadReadOnlyAlias
            .dw 301
            .db RewriteSemanticPrepareOpenStringDirect,0,5
            .db RewriteSemanticLoadBssAlias
            .dw 0
            .db RewriteSemanticSelectField
            .dw 0
            .db RewriteSemanticSelectField
            .dw 7
            .db RewriteSemanticPrepareOpenArrayDirect,2
            .dw 3
            .db RewriteSemanticCallSource,2,4,RewriteScalarTypeU16,RewriteCallFlagKeepResult
            .dw ProofCallMeasure-ProofSourceCalls
            .db RewriteCallModeInfallible,0,0
            .db RewriteSemanticStoreLocal16,11
            .db RewriteSemanticDeclareLocal16,13
            .db RewriteSemanticLoadParameterAlias,0
            .db RewriteSemanticPrepareOpenStringForward,1,2
            .db RewriteSemanticLoadParameterAlias,3
            .db RewriteSemanticPrepareOpenArrayForward,3
            .dw 5
            .db RewriteSemanticCallSource,2,4,RewriteScalarTypeU16,RewriteCallFlagKeepResult
            .dw ProofCallMeasureForward-ProofSourceCalls
            .db RewriteCallModeInfallible,0,0
            .db RewriteSemanticStoreLocal16,13
ProofExpectedCallSemanticsEnd:

ProofExpectedCallTransientSemantics:
            .db RewriteSemanticDeclareLocal16,0
            .db RewriteSemanticCallSource,0,0,RewriteFirstOwnedTypeId,RewriteCallFlagKeepResult
            .dw ProofCallTransientText-ProofSourceCallTransientViews
            .db RewriteCallModeInfallible,0,0
            .db RewriteSemanticPrepareOpenStringDirect,0,5
            .db RewriteSemanticCallSource,1,0,RewriteFirstOwnedTypeId+1,RewriteCallFlagKeepResult
            .dw ProofCallTransientRow-ProofSourceCallTransientViews
            .db RewriteCallModeInfallible,0,0
            .db RewriteSemanticPrepareOpenArrayDirect,2
            .dw 3
            .db RewriteSemanticCallSource,2,4,RewriteScalarTypeU16,RewriteCallFlagKeepResult
            .dw ProofCallTransientMeasure-ProofSourceCallTransientViews
            .db RewriteCallModeInfallible,0,0
            .db RewriteSemanticStoreLocal16,0
ProofExpectedCallTransientSemanticsEnd:

ProofExpectedRecursiveCallSemantics:
            .db RewriteSemanticDeclareLocalU8,1
            .db RewriteSemanticLoadParameter8,0
            .db RewriteSemanticCallSource,0,1,RewriteScalarTypeU8,RewriteCallFlagKeepResult
            .dw ProofRecursiveCallName-ProofSourceRecursiveCall
            .db RewriteCallModeInfallible,0,0
            .db RewriteSemanticStoreLocalU8,1
ProofExpectedRecursiveCallSemanticsEnd:

ProofExpectedScalarAssignmentOperationCount .equ 15
ProofExpectedScalarAssignmentSemantics:
            .db RewriteSemanticDeclareLocal16,3
            .db RewriteSemanticLiteral16,0,0
            .db RewriteSemanticStoreLocal16,3
            .db RewriteSemanticLoadParameter8,0
            .db RewriteSemanticLiteral16,1,0
            .db RewriteSemanticAdd8
            .db RewriteSemanticStoreBss16,0,0
            .db RewriteSemanticLoadBss16,0,0
            .db RewriteSemanticStoreLocal16,3
            .db RewriteSemanticLiteral16,3,0
            .db RewriteSemanticStoreParameter8,0
            .db RewriteSemanticLoadParameter8,0
            .db RewriteSemanticStoreProgramU8,0,0
            .db RewriteSemanticLoadBss16,0,0
            .db RewriteSemanticStoreParameter16,1
ProofExpectedScalarAssignmentSemanticsEnd:

ProofExpectedCallStatementOperationCount .equ 5
ProofExpectedCallStatementSemantics:
            .db RewriteSemanticLiteral16,1,0
            .db RewriteSemanticCallSource,0,1,0,RewriteRoutineFlagFails
            .dw ProofCallStatementPing-ProofSourceCallStatements
            .db RewriteCallModePropagateMain,0,0
            .db RewriteSemanticLiteral16,2,0
            .db RewriteSemanticCallService,1
            .dw ProofCallStatementService-ProofSourceCallStatements
            .db RewriteCallModePropagateMain,0,0
            .db RewriteSemanticCallSource,1,0,0,0
            .dw ProofCallStatementDone-ProofSourceCallStatements
            .db RewriteCallModeInfallible,0,0
ProofExpectedCallStatementSemanticsEnd:

ProofExpectedRoutineExitOperationCount .equ 14
ProofExpectedRoutineExitSemantics:
            .db RewriteSemanticLiteral16,7,0
            .db RewriteSemanticReturnScalar
            .db RewriteSemanticEndGeneralRoutineEnclosing,RewriteScalarTypeU16
            .db RewriteSemanticLiteral16,3,0
            .db RewriteSemanticReturnFailableScalar
            .db RewriteSemanticEndFailableRoutineEnclosing,RewriteScalarTypeU8
            .db RewriteSemanticLiteral16,5,0
            .db RewriteSemanticFailRoutine
            .dw ProofRoutineFailAnchor-ProofSourceRoutineExits
            .db RewriteSemanticEndFailableRoutineEnclosing,RewriteScalarTypeU8
            .db RewriteSemanticEndGeneralRoutineDirect,RewriteScalarTypeExact
            .db RewriteSemanticEndGeneralRoutineEnclosing,RewriteScalarTypeExact
            .db RewriteSemanticLiteral16,9,0
            .db RewriteSemanticFailMain
            .dw ProofMainFailAnchor-ProofSourceRoutineExits
            .db RewriteSemanticEndFailableRoutineEnclosing,RewriteScalarTypeExact
ProofExpectedRoutineExitSemanticsEnd:

ProofExpectedAggregateReturnSemantics:
            .db RewriteSemanticLoadReadOnlyAlias
            .dw 301
            .db RewriteSemanticReturnAggregate
            .db RewriteSemanticEndGeneralRoutineEnclosing,RewriteFirstOwnedTypeId
ProofExpectedAggregateReturnSemanticsEnd:

            .org $7000
ProofSourceAccepted:
            .db "const five = 5",10
            .db "var initialized as u8 = 3",10
            .db "var reserved as u16",10
            .db "sub worker(input as u8)",10
            .db "var fromParameter as u8 = input",10
            .db "var widened as u16 = fromParameter",10
            .db "var fromConstant as i16 = five",10
            .db "var fromInitialized as u8 = initialized",10
            .db "var fromBss as u16 = reserved",10
            .db "var signed as i16 = "
ProofSignedConversionToken:
            .db "i8(7)",10
            .db "var flag as boolean = true",10
            .db "end",10
            .db "sub main()",10,"end",10
ProofSourceAcceptedEnd:
ProofSourceMismatch: .db "sub main()",10,"var x as boolean = 1",10
ProofSourceMismatchEnd:
ProofSourceSelfReference: .db "sub main()",10,"var x as u8 = x",10
ProofSourceSelfReferenceEnd:
ProofSourceTrailingToken: .db "sub main()",10,"var x as u8 = 1 2",10
ProofSourceTrailingTokenEnd:
ProofSourceDivisionZero: .db "sub main()",10,"var x as u8 = 1 / 0",10
ProofSourceDivisionZeroEnd:
ProofSourceBooleanXor:
            .db "sub worker(flag as boolean)",10
            .db "var x as boolean = flag xor true",10
ProofSourceBooleanXorEnd:
ProofSourceComparisonChain:
            .db "sub worker(a as u8)",10
            .db "var x as boolean = a < 2 < 3",10
ProofSourceComparisonChainEnd:
ProofSourceMixedWords:
            .db "sub worker(a as u16, b as i16)",10
            .db "var x as i16 = a + b",10
ProofSourceMixedWordsEnd:

ProofSourceExpressions:
            .db "sub worker(a as u8, c as i8, d as i16, flag as boolean)",10
            .db "var add as u16 = (a "
ProofUnsignedDivideToken:
            .db "/ 2) + (2 * 3)",10
            .db "var signedLeft as i16 = c + d",10
            .db "var signedRight as i16 = d - c",10
            .db "var mixed as i16 = a + c",10
            .db "var quotient as i16 = -d "
ProofSignedDivideToken:
            .db "/ i16(2)",10
            .db "var remainder as i8 = c "
ProofSignedModuloToken:
            .db "mod i8(3)",10
            .db "var compared as boolean = c < a",10
            .db "var same as boolean = flag = true",10
            .db "var logic as u8 = (a and 7) xor 1",10
            .db "var branch as boolean = flag and (true or (1 "
ProofSuppressedDivideToken:
            .db "/ 0 = 0))",10
            .db "var unary as u16 = not (add "
ProofUnsignedModuloToken:
            .db "mod 5)",10
            .db "var inverse as boolean = not flag",10
            .db "end",10
            .db "sub main()",10,"end",10
ProofSourceExpressionsEnd:

ProofSourcePaths:
            .db "sub work(xs as u16[], text as string[], ix as i16, row as u16[3])",10
            .db "var a as u16 = root.inner.values"
ProofPathValuesIndex:
            .db "[1]",10
            .db "var b as u16 = root.items"
ProofPathItemsIndex:
            .db "[1].values.length",10
            .db "var c as u8 = root.inner.text"
ProofPathTextIndex:
            .db "[2]",10
            .db "var d as u8 = root.inner.text."
ProofPathTextLength:
            .db "length",10
            .db "var e as u16 = xs.length + row"
ProofPathRowIndex:
            .db "[1]",10
            .db "var f as u16 = xs"
ProofPathDynamicIndex:
            .db "["
ProofPathDynamicIndexName:
            .db "ix"
            .db "]",10
            .db "var g as u8 = text."
ProofPathOpenTextLength:
            .db "length + ro."
ProofPathReadOnlyLength:
            .db "length",10
            .db "var h as u8 = text.capacity",10
            .db "var i as u8 = text"
ProofPathOpenTextIndex:
            .db "[1]",10
ProofSourcePathsEnd:

ProofSourcePostfixAssignments:
            .db "forward sub maybe() as u16 fails",10
            .db "sub work(xs as u16[], text as string[]) fails",10
            .db "root.inner.values"
ProofPostfixFixedIndex:
            .db "[1] = "
ProofPostfixCall:
            .db "maybe() else fail",10
            .db "root.inner.text"
ProofPostfixStringIndex:
            .db "[2] = 65",10
            .db "xs"
ProofPostfixOpenArrayIndex:
            .db "[1] = 7",10
            .db "text"
ProofPostfixOpenStringIndex:
            .db "[1] = 66",10
            .db "text.length = "
ProofPostfixResizeValue:
            .db "3",10
            .db "root.inner = "
ProofPostfixCopySource:
            .db "root.inner",10
            .db "var result as u16 = "
ProofPostfixFreshCall:
            .db "maybe() else fail",10
ProofSourcePostfixAssignmentsEnd:

ProofSourcePathCapacity:
            .db "sub work()",10,"var x as u8 = root.inner.text."
ProofPathCapacityName:
            .db "capacity",10
ProofSourcePathCapacityEnd:
ProofSourcePathRange:
            .db "sub work()",10,"var x as u16 = root.inner.values["
ProofPathRangeValue:
            .db "3]",10
ProofSourcePathRangeEnd:
ProofSourcePathBooleanIndex:
            .db "sub work()",10,"var x as u16 = root.inner.values[true"
ProofPathBooleanClose:
            .db "]",10
ProofSourcePathBooleanIndexEnd:
ProofSourcePathNegativeIndex:
            .db "sub work()",10,"var x as u16 = root.inner.values[-"
ProofPathNegativeValue:
            .db "1]",10
ProofSourcePathNegativeIndexEnd:
ProofSourcePathUnknownField:
            .db "sub work()",10,"var x as u8 = root."
ProofPathUnknownFieldName:
            .db "missing",10
ProofSourcePathUnknownFieldEnd:

ProofSourceCalls:
            .db "sub sum(a as u8, b as u16) as u16",10,"end",10
            .db "sub maybe(value as u8) as u8 fails",10,"end",10
            .db "sub measure(text as string[], values as u16[]) as u16",10,"end",10
            .db "sub work(text as string[], values as u16[]) fails",10
            .db "var a as u16 = "
ProofCallSum:
            .db "sum(1, "
ProofCallSumNested:
            .db "sum(2, 3))",10
            .db "var b as u8 = "
ProofCallMaybe:
            .db "maybe(3) else fail",10
            .db "var c as u8 = "
ProofCallService:
            .db "readInputByte() else fail",10
            .db "var d as u16 = "
ProofCallMeasure:
            .db "measure(ro, root.inner.values)",10
            .db "var e as u16 = "
ProofCallMeasureForward:
            .db "measure(text, values)",10
ProofSourceCallsEnd:

ProofSourceMainCall:
            .db "sub main() fails",10
            .db "var value as u8 = readInputByte() else fail",10
ProofSourceMainCallEnd:

; Call-boundary diagnostic sources. Labels identify the exact frozen token
; anchor; all bytes below are proof source text, never executable encodings.
ProofSourceCallDepth:
            .db "forward sub id(x as u8) as u8",10
            .db "sub work()",10
            .db "var x as u8 = id(id(id(id(1))))",10
ProofSourceCallDepthEnd:

ProofSourceCallTransientViews:
            .db "forward sub getText() as string[5]",10
            .db "forward sub getRow() as u16[3]",10
            .db "forward sub measure(text as string[], values as u16[]) as u16",10
            .db "sub work()",10
            .db "var x as u16 = "
ProofCallTransientMeasure:
            .db "measure("
ProofCallTransientText:
            .db "getText(), "
ProofCallTransientRow:
            .db "getRow())",10
ProofSourceCallTransientViewsEnd:

ProofSourceRecursiveCall:
            .db "sub recur(value as u8) as u8",10
            .db "var next as u8 = "
ProofRecursiveCallName:
            .db "recur(value)",10
ProofSourceRecursiveCallEnd:

ProofSourceScalarAssignments:
            .db "var ready as u8 = 1",10
            .db "var target as u16",10
            .db "sub work(value as u8, wide as u16)",10
            .db "var local as u16",10
            .db "target = value + 1",10
            .db "local = target",10
            .db "value = 3",10
            .db "ready = value",10
            .db "wide = target",10
ProofSourceScalarAssignmentsEnd:

ProofSourceAssignmentUnknown:
            .db "sub main()",10,"x = 2",10
ProofSourceAssignmentUnknownEnd:
ProofSourceAssignmentConstant:
            .db "const x = 1",10,"sub main()",10,"x = 2",10
ProofSourceAssignmentConstantEnd:
ProofSourceAssignmentMismatch:
            .db "var x as u8",10,"sub main()",10,"x = true",10
ProofSourceAssignmentMismatchEnd:

ProofSourceCallStatements:
            .db "sub ping(value as u8) fails",10,"end",10
            .db "sub done()",10,"end",10
            .db "sub main() fails",10
ProofCallStatementPing:
            .db "ping(1) else fail",10
ProofCallStatementService:
            .db "writeOutputByte(2) else fail",10
ProofCallStatementDone:
            .db "done()",10
ProofSourceCallStatementsEnd:

ProofSourceCallStatementUnknown:
            .db "sub main()",10,"missing()",10
ProofSourceCallStatementUnknownEnd:
ProofSourceCallStatementMissingElse:
            .db "sub ping() fails",10,"end",10
            .db "sub main() fails",10,"ping()",10
ProofSourceCallStatementMissingElseEnd:
ProofSourceCallStatementInfallibleElse:
            .db "sub done()",10,"end",10
            .db "sub main() fails",10,"done() else fail",10
ProofSourceCallStatementInfallibleElseEnd:

ProofSourceRoutineExits:
            .db "sub scalar() as u16",10,"return 7",10,"end",10
            .db "sub success() as u8 fails",10,"return 3",10,"end",10
            .db "sub failed() as u8 fails",10
ProofRoutineFailAnchor:
            .db "fail 5",10,"end",10
            .db "sub empty()",10,"return",10,"end",10
            .db "sub main() fails",10
ProofMainFailAnchor:
            .db "fail 9",10,"end",10
ProofSourceRoutineExitsEnd:

ProofSourceBareValueReturn:
            .db "sub bad() as u8",10,"return"
ProofBareValueReturnAnchor:
            .db 10
ProofSourceBareValueReturnEnd:
ProofSourceValueInVoidReturn:
            .db "sub bad()",10,"return 1"
ProofValueInVoidReturnAnchor:
            .db 10
ProofSourceValueInVoidReturnEnd:
ProofSourceFailInfallible:
            .db "sub bad()",10
ProofFailInfallibleAnchor:
            .db "fail 1",10
ProofSourceFailInfallibleEnd:
ProofSourceValueFallthrough:
            .db "sub bad() as u8 fails",10,"end"
ProofValueFallthroughAnchor:
            .db 10
ProofSourceValueFallthroughEnd:
ProofSourceFailWrongType:
            .db "sub bad() fails",10,"fail true"
ProofFailWrongTypeAnchor:
            .db 10
ProofSourceFailWrongTypeEnd:
ProofSourceAggregateReturn:
            .db "sub text() as string[5]",10,"return ro",10,"end",10
ProofSourceAggregateReturnEnd:
ProofSourceReturnFailableCall:
            .db "forward sub maybe() as u8 fails",10
            .db "sub bad() as u8 fails",10,"return maybe()"
ProofReturnFailableCallAnchor:
            .db 10
ProofSourceReturnFailableCallEnd:

ProofSourceCallMissingConsumer:
            .db "forward sub maybe() as u8 fails",10
            .db "sub work() fails",10
            .db "var x as u8 = maybe()"
ProofCallMissingConsumerAnchor:
            .db 10
ProofSourceCallMissingConsumerEnd:

ProofSourceCallInfallibleElse:
            .db "forward sub maybe() as u8 fails",10
            .db "sub work()",10
            .db "var x as u8 = maybe() "
ProofCallInfallibleElseAnchor:
            .db "else fail",10
ProofSourceCallInfallibleElseEnd:

ProofSourceCallGroupedFailure:
            .db "forward sub maybe() as u8 fails",10
            .db "sub work() fails",10
            .db "var x as u8 = (maybe()"
ProofCallGroupedFailureAnchor:
            .db ") else fail",10
ProofSourceCallGroupedFailureEnd:

ProofSourceCallConvertedFailure:
            .db "forward sub maybe() as u8 fails",10
            .db "sub work() fails",10
            .db "var x as u8 = u8(maybe()"
ProofCallConvertedFailureAnchor:
            .db ") else fail",10
ProofSourceCallConvertedFailureEnd:

ProofSourceCallUnaryFailure:
            .db "forward sub maybe() as u8 fails",10
            .db "sub work() fails",10
            .db "var x as i16 = -maybe("
ProofCallUnaryFailureAnchor:
            .db ") else fail",10
ProofSourceCallUnaryFailureEnd:

ProofSourceCallStrayElse:
            .db "forward sub pure() as u8",10
            .db "sub work() fails",10
            .db "var x as u8 = pure() "
ProofCallStrayElseAnchor:
            .db "else fail",10
ProofSourceCallStrayElseEnd:

ProofSourceCallLiteralOpen:
            .db "forward sub use(text as string[])",10
            .db "sub work()",10
            .db "var x as u8 = use("
ProofCallLiteralOpenAnchor:
            .db '"',"x",'"',")",10
ProofSourceCallLiteralOpenEnd:

ProofSourceCallNestedFailure:
            .db "forward sub maybe() as u8 fails",10
            .db "forward sub take(x as u8) as u8",10
            .db "sub work() fails",10
            .db "var x as u8 = take(maybe("
ProofCallNestedFailureAnchor:
            .db ")) else fail",10
ProofSourceCallNestedFailureEnd:

ProofSourceCallDepthOverflow:
            .db "forward sub id(x as u8) as u8",10
            .db "sub work()",10
            .db "var x as u8 = id(id(id(id("
ProofCallDepthOverflowAnchor:
            .db "id(1)))))",10
ProofSourceCallDepthOverflowEnd:

ProofSourceCallTooFew:
            .db "forward sub id(x as u8) as u8",10
            .db "sub work()",10
            .db "var x as u8 = id("
ProofCallTooFewAnchor:
            .db ")",10
ProofSourceCallTooFewEnd:

ProofSourceCallTooMany:
            .db "forward sub id(x as u8) as u8",10
            .db "sub work()",10
            .db "var x as u8 = id(1"
ProofCallTooManyAnchor:
            .db ",2)",10
ProofSourceCallTooManyEnd:

ProofSourceCallWrongType:
            .db "forward sub id(x as u8) as u8",10
            .db "sub work()",10
            .db "var x as u8 = id(true"
ProofCallWrongTypeAnchor:
            .db ")",10
ProofSourceCallWrongTypeEnd:

ProofSourceCallIndexFailure:
            .db "forward sub maybe() as u8 fails",10
            .db "sub work() fails",10
            .db "var x as u16 = root.inner.values[maybe()"
ProofCallIndexFailureAnchor:
            .db "] else fail",10
ProofSourceCallIndexFailureEnd:

ProofSourceCallBinaryFailure:
            .db "forward sub maybe() as u8 fails",10
            .db "sub work() fails",10
            .db "var x as u8 = maybe() "
ProofCallBinaryFailureAnchor:
            .db "+ 1 else fail",10
ProofSourceCallBinaryFailureEnd:

ProofSourceAssignmentReadOnlyAggregate:
            .db "sub work()",10
ProofAssignmentReadOnlyTarget:
            .db "ro = ro",10
ProofSourceAssignmentReadOnlyAggregateEnd:
ProofSourceAssignmentFixedStringLength:
            .db "sub work()",10,"root.inner.text."
ProofAssignmentFixedLengthName:
            .db "length = 1",10
ProofSourceAssignmentFixedStringLengthEnd:
ProofSourceAssignmentOpenWhole:
            .db "sub work(text as string[])",10,"text = "
ProofAssignmentOpenWholeValue:
            .db "text"
ProofAssignmentOpenWholeLine:
            .db 10
ProofSourceAssignmentOpenWholeEnd:

            ; Descriptor and metadata fixtures live outside both the source
            ; corpus and the compiler workspace. Their full pointers also
            ; discriminate any accidental address narrowing.
            .org $9000
ProofPartsAccepted:      .db 1
                         .dw ProofSourceAccepted,ProofSourceAcceptedEnd
ProofPartsMismatch:      .db 1
                         .dw ProofSourceMismatch,ProofSourceMismatchEnd
ProofPartsSelfReference: .db 1
                         .dw ProofSourceSelfReference,ProofSourceSelfReferenceEnd
ProofPartsTrailingToken: .db 1
                         .dw ProofSourceTrailingToken,ProofSourceTrailingTokenEnd
ProofPartsDivisionZero:  .db 1
                         .dw ProofSourceDivisionZero,ProofSourceDivisionZeroEnd
ProofPartsBooleanXor:    .db 1
                         .dw ProofSourceBooleanXor,ProofSourceBooleanXorEnd
ProofPartsComparisonChain: .db 1
                         .dw ProofSourceComparisonChain,ProofSourceComparisonChainEnd
ProofPartsMixedWords:    .db 1
                         .dw ProofSourceMixedWords,ProofSourceMixedWordsEnd
ProofPartsExpressions:   .db 1
                         .dw ProofSourceExpressions,ProofSourceExpressionsEnd
ProofPartsPaths:         .db 1
                         .dw ProofSourcePaths,ProofSourcePathsEnd
ProofPartsPostfixAssignments: .db 1
                         .dw ProofSourcePostfixAssignments,ProofSourcePostfixAssignmentsEnd
ProofPartsPathCapacity:  .db 1
                         .dw ProofSourcePathCapacity,ProofSourcePathCapacityEnd
ProofPartsPathRange:     .db 1
                         .dw ProofSourcePathRange,ProofSourcePathRangeEnd
ProofPartsPathBooleanIndex: .db 1
                         .dw ProofSourcePathBooleanIndex,ProofSourcePathBooleanIndexEnd
ProofPartsPathNegativeIndex: .db 1
                         .dw ProofSourcePathNegativeIndex,ProofSourcePathNegativeIndexEnd
ProofPartsPathUnknownField: .db 1
                         .dw ProofSourcePathUnknownField,ProofSourcePathUnknownFieldEnd
ProofPartsCalls:          .db 1
                         .dw ProofSourceCalls,ProofSourceCallsEnd
ProofPartsMainCall:       .db 1
                         .dw ProofSourceMainCall,ProofSourceMainCallEnd
ProofPartsCallDepth:      .db 1
                         .dw ProofSourceCallDepth,ProofSourceCallDepthEnd
ProofPartsCallTransientViews: .db 1
                         .dw ProofSourceCallTransientViews,ProofSourceCallTransientViewsEnd
ProofPartsRecursiveCall: .db 1
                         .dw ProofSourceRecursiveCall,ProofSourceRecursiveCallEnd
ProofPartsScalarAssignments: .db 1
                         .dw ProofSourceScalarAssignments,ProofSourceScalarAssignmentsEnd
ProofPartsAssignmentUnknown: .db 1
                         .dw ProofSourceAssignmentUnknown,ProofSourceAssignmentUnknownEnd
ProofPartsAssignmentConstant: .db 1
                         .dw ProofSourceAssignmentConstant,ProofSourceAssignmentConstantEnd
ProofPartsAssignmentMismatch: .db 1
                         .dw ProofSourceAssignmentMismatch,ProofSourceAssignmentMismatchEnd
ProofPartsCallStatements: .db 1
                         .dw ProofSourceCallStatements,ProofSourceCallStatementsEnd
ProofPartsCallStatementUnknown: .db 1
                         .dw ProofSourceCallStatementUnknown,ProofSourceCallStatementUnknownEnd
ProofPartsCallStatementMissingElse: .db 1
                         .dw ProofSourceCallStatementMissingElse,ProofSourceCallStatementMissingElseEnd
ProofPartsCallStatementInfallibleElse: .db 1
                         .dw ProofSourceCallStatementInfallibleElse,ProofSourceCallStatementInfallibleElseEnd
ProofPartsRoutineExits:   .db 1
                         .dw ProofSourceRoutineExits,ProofSourceRoutineExitsEnd
ProofPartsBareValueReturn: .db 1
                         .dw ProofSourceBareValueReturn,ProofSourceBareValueReturnEnd
ProofPartsValueInVoidReturn: .db 1
                         .dw ProofSourceValueInVoidReturn,ProofSourceValueInVoidReturnEnd
ProofPartsFailInfallible: .db 1
                         .dw ProofSourceFailInfallible,ProofSourceFailInfallibleEnd
ProofPartsValueFallthrough: .db 1
                         .dw ProofSourceValueFallthrough,ProofSourceValueFallthroughEnd
ProofPartsFailWrongType: .db 1
                         .dw ProofSourceFailWrongType,ProofSourceFailWrongTypeEnd
ProofPartsAggregateReturn: .db 1
                         .dw ProofSourceAggregateReturn,ProofSourceAggregateReturnEnd
ProofPartsReturnFailableCall: .db 1
                         .dw ProofSourceReturnFailableCall,ProofSourceReturnFailableCallEnd
ProofPartsCallMissingConsumer: .db 1
                         .dw ProofSourceCallMissingConsumer,ProofSourceCallMissingConsumerEnd
ProofPartsCallInfallibleElse: .db 1
                         .dw ProofSourceCallInfallibleElse,ProofSourceCallInfallibleElseEnd
ProofPartsCallGroupedFailure: .db 1
                         .dw ProofSourceCallGroupedFailure,ProofSourceCallGroupedFailureEnd
ProofPartsCallConvertedFailure: .db 1
                         .dw ProofSourceCallConvertedFailure,ProofSourceCallConvertedFailureEnd
ProofPartsCallUnaryFailure: .db 1
                         .dw ProofSourceCallUnaryFailure,ProofSourceCallUnaryFailureEnd
ProofPartsCallStrayElse:  .db 1
                         .dw ProofSourceCallStrayElse,ProofSourceCallStrayElseEnd
ProofPartsCallLiteralOpen: .db 1
                         .dw ProofSourceCallLiteralOpen,ProofSourceCallLiteralOpenEnd
ProofPartsCallNestedFailure: .db 1
                         .dw ProofSourceCallNestedFailure,ProofSourceCallNestedFailureEnd
ProofPartsCallDepthOverflow: .db 1
                         .dw ProofSourceCallDepthOverflow,ProofSourceCallDepthOverflowEnd
ProofPartsCallTooFew:    .db 1
                         .dw ProofSourceCallTooFew,ProofSourceCallTooFewEnd
ProofPartsCallTooMany:   .db 1
                         .dw ProofSourceCallTooMany,ProofSourceCallTooManyEnd
ProofPartsCallWrongType: .db 1
                         .dw ProofSourceCallWrongType,ProofSourceCallWrongTypeEnd
ProofPartsCallIndexFailure: .db 1
                         .dw ProofSourceCallIndexFailure,ProofSourceCallIndexFailureEnd
ProofPartsCallBinaryFailure: .db 1
                         .dw ProofSourceCallBinaryFailure,ProofSourceCallBinaryFailureEnd
ProofPartsAssignmentReadOnlyAggregate: .db 1
                         .dw ProofSourceAssignmentReadOnlyAggregate,ProofSourceAssignmentReadOnlyAggregateEnd
ProofPartsAssignmentFixedStringLength: .db 1
                         .dw ProofSourceAssignmentFixedStringLength,ProofSourceAssignmentFixedStringLengthEnd
ProofPartsAssignmentOpenWhole: .db 1
                         .dw ProofSourceAssignmentOpenWhole,ProofSourceAssignmentOpenWholeEnd

; Path metadata fixtures. Each .db/.dw block is a type, record, field, or
; symbol table image and never executes as Z80 code.
ProofPathTypeDescriptors:
            .db RewriteTypeKindString,0
            .dw 5
            .db RewriteTypeKindArray,RewriteScalarTypeU16
            .dw 3
            .db RewriteTypeKindRecord,0
            .dw 0
            .db RewriteTypeKindArray,RewriteFirstOwnedTypeId+2
            .dw 2
            .db RewriteTypeKindRecord,1
            .dw 0
ProofPathTypeDescriptorsEnd:
ProofPathTypeExtents:
            .dw 7,6,13,26,39
ProofPathTypeExtentsEnd:
ProofPathRecords:
            .db 0,2,2,2
ProofPathRecordsEnd:
ProofPathFields:
            .dw ProofPathNameText
            .db 4,RewriteFirstOwnedTypeId
            .dw 0
            .dw ProofPathNameValues
            .db 6,RewriteFirstOwnedTypeId+1
            .dw 7
            .dw ProofPathNameInner
            .db 5,RewriteFirstOwnedTypeId+2
            .dw 0
            .dw ProofPathNameItems
            .db 5,RewriteFirstOwnedTypeId+3
            .dw 13
ProofPathFieldsEnd:
ProofPathRootSymbols:
            .dw ProofPathNameRoot
            .db 4,RewriteSymbolClassProgram,RewriteFirstOwnedTypeId+4
            .dw 0
            .db RewriteSymbolStorageBss
            .dw ProofPathNameReadOnly
            .db 2,RewriteSymbolClassConstant,RewriteFirstOwnedTypeId
            .dw 301
            .db RewriteSymbolStorageReadOnly
ProofPathRootSymbolsEnd:
ProofPathNameRoot:   .db "root"
ProofPathNameReadOnly: .db "ro"
ProofPathNameText:   .db "text"
ProofPathNameValues: .db "values"
ProofPathNameInner:  .db "inner"
ProofPathNameItems:  .db "items"
