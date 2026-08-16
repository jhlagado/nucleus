; R5 scalar statement actions. Assignment targets retain an explicit symbol
; class, storage segment, scalar type, and full payload. No address bit is
; interpreted as metadata.

; The current token is the assignment NAME. Retain a writable scalar target
; until the complete right-hand expression and line have been validated.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteStatementBeginScalarAssignment:
            CALL RewriteSymbolFindCurrent
            JR   NC,RewriteStatementUnknownName
            LD   DE,RewriteSymbolClass
            ADD  HL,DE
            LD   A,(HL)
            CP   RewriteSymbolClassProgram
            JR   Z,_RewriteStatementAssignmentClassReady
            CP   RewriteSymbolClassLocal
            JR   Z,_RewriteStatementAssignmentClassReady
            CP   RewriteSymbolClassParameter
            JR   NZ,RewriteStatementAssignmentTypeFailure
_RewriteStatementAssignmentClassReady:
            LD   (RewriteStatementTargetClass),A
            INC  HL
            LD   A,(HL)
            LD   (RewriteCurrentType),A
            AND  RewriteTypeIdentityMask
            OR   A
            JR   Z,RewriteStatementAssignmentTypeFailure
            CP   RewriteFirstOwnedTypeId
            JR   NC,RewriteStatementAssignmentTypeFailure
            INC  HL
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            LD   (RewriteStatementTargetPayload),DE
            INC  HL
            LD   A,(HL)
            LD   (RewriteStatementTargetStorage),A
            XOR  A
            RET

RewriteStatementUnknownName:
            LD   A,DiagnosticUnknownName
            JP   RewriteRaiseDiagnostic

RewriteStatementAssignmentTypeFailure:
            LD   A,DiagnosticTypeMismatch
            JP   RewriteRaiseDiagnostic

; Parse and type-check the right-hand side. Failable calls are consumed before
; the generated action program validates the terminating newline.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteStatementFinishScalarAssignmentExpression:
            LD   A,(RewriteCurrentType)
            CALL RewriteExpressionEvaluateRuntime
            LD   B,A
            LD   A,(RewriteCurrentType)
            LD   C,A
            LD   A,B
            CALL RewriteExpressionCheckRuntimeAssignable
            JP   RewriteCallConsumeLocalFailure

; Emit the store only after the complete statement line has succeeded. Program
; payloads are words; activation payloads are the published byte offsets.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteStatementEmitScalarAssignment:
            LD   A,(RewriteStatementTargetClass)
            CP   RewriteSymbolClassProgram
            JR   Z,_RewriteStatementEmitProgramStore
            CP   RewriteSymbolClassLocal
            LD   A,RewriteSemanticStoreLocalU8
            JR   Z,_RewriteStatementEmitActivationStore
            LD   A,RewriteSemanticStoreParameter8
_RewriteStatementEmitActivationStore:
            LD   B,A
            LD   A,(RewriteStatementTargetPayload)
            LD   (RewriteSemanticOperandArea),A
            LD   A,(RewriteCurrentType)
            BIT  1,A
            LD   A,B
            JR   Z,_RewriteStatementEmitStoreReady
            LD   A,(RewriteStatementTargetClass)
            CP   RewriteSymbolClassLocal
            LD   A,RewriteSemanticStoreParameter16
            JR   NZ,_RewriteStatementEmitStoreReady
            LD   A,RewriteSemanticStoreLocal16
            JR   _RewriteStatementEmitStoreReady
_RewriteStatementEmitProgramStore:
            LD   DE,(RewriteStatementTargetPayload)
            LD   (RewriteSemanticOperandArea),DE
            LD   A,(RewriteStatementTargetStorage)
            CP   RewriteSymbolStorageBss
            JR   Z,_RewriteStatementEmitBssStore
            CP   RewriteSymbolStorageInitialized
            JR   NZ,RewriteStatementAssignmentTypeFailure
            LD   A,(RewriteCurrentType)
            BIT  1,A
            LD   A,RewriteSemanticStoreProgramU8
            JR   Z,_RewriteStatementEmitStoreReady
            LD   A,RewriteSemanticStoreProgram16
            JR   _RewriteStatementEmitStoreReady
_RewriteStatementEmitBssStore:
            LD   A,(RewriteCurrentType)
            BIT  1,A
            LD   A,RewriteSemanticStoreBssU8
            JR   Z,_RewriteStatementEmitStoreReady
            LD   A,RewriteSemanticStoreBss16
_RewriteStatementEmitStoreReady:
            LD   HL,RewriteSemanticOperandArea
            JP   RewriteSemanticAppend
