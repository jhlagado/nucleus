; R5 scalar statement actions. Assignment targets retain an explicit symbol
; class, storage segment, scalar type, and full payload. No address bit is
; interpreted as metadata.

; C is a local activation offset. Reject a source write or nested counted-loop
; reuse while that exact local is the counter of an active `for` frame.
.routine in C out A,carry,zero clobbers sign,parity,halfCarry,B,D,DE,HL
RewriteControlCheckActiveCounter:
            LD   A,(RewriteControlDepth)
            OR   A
            RET  Z
_RewriteControlCheckCounterNext:
            DEC  A
            PUSH AF
            LD   L,A
            LD   H,0
            ADD  HL,HL
            LD   E,L
            LD   D,H
            ADD  HL,HL
            ADD  HL,HL
            ADD  HL,DE
            LD   DE,RewriteControlFrameBase
            ADD  HL,DE
            LD   A,(HL)
            CP   RewriteControlKindFor
            JR   NZ,_RewriteControlCheckCounterContinue
            LD   DE,RewriteControlFrameCounter
            ADD  HL,DE
            LD   A,(HL)
            CP   C
            JR   Z,_RewriteControlActiveCounterFailure
_RewriteControlCheckCounterContinue:
            POP  AF
            OR   A
            JR   NZ,_RewriteControlCheckCounterNext
            RET
_RewriteControlActiveCounterFailure:
            POP  AF
            LD   A,DiagnosticActiveCounter
            JP   RewriteRaiseDiagnostic

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
            LD   A,(RewriteStatementTargetClass)
            CP   RewriteSymbolClassLocal
            JR   NZ,_RewriteStatementAssignmentTargetReady
            LD   C,E
            CALL RewriteControlCheckActiveCounter
_RewriteStatementAssignmentTargetReady:
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

; The current NAME begins a source or predefined-service call statement.
; Result-bearing calls retain their declared result metadata exactly as the
; frozen compiler does; the backend recipe decides whether a statement result
; needs a carrier. Immediate `else fail` uses the same pending-call operand as
; expression initializers.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteStatementParseCall:
            LD   DE,(TokenStartOffset)
            LD   (RewriteExpressionAtomOffset),DE
            XOR  A
            LD   (RewriteExpressionExpectedType),A
            CALL RewriteExpressionBeginRuntime
            CALL RewriteRoutineFindCurrent
            JR   C,_RewriteStatementParseSourceCall
            CALL RewritePredefinedFindCurrent
            JP   NC,RewriteStatementUnknownName
            CP   6
            JP   NC,RewriteStatementUnknownName
            CALL RewriteCallParseService
            JP   RewriteCallConsumeLocalFailure
_RewriteStatementParseSourceCall:
            CALL RewriteCallParseSource
            JP   RewriteCallConsumeLocalFailure

; Successful and failed routine exits share the same streaming fallthrough
; summary. A terminal statement can occur before later unreachable source;
; later ordinary statements never restore this byte to one.
.routine out A,carry,zero clobbers sign,parity,halfCarry
RewriteStatementMarkNoFallthrough:
            XOR  A
            LD   (RewriteControlSequenceFallsThrough),A
            RET

.routine noreturn
RewriteStatementFailureContext:
            LD   A,DiagnosticFailureContext
            JP   RewriteRaiseDiagnostic

.routine noreturn
RewriteStatementRoutineFlowFailure:
            LD   A,DiagnosticRoutineFlow
            JP   RewriteRaiseDiagnostic

; Append one routine-end operation. A selects direct source attribution when
; nonzero and enclosing attribution when zero. The operand is the active
; result type, including exact/zero for result-free routines and main.
.routine in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteStatementEmitRoutineEnd:
            LD   B,A
            LD   A,(RewriteCurrentRoutineResultType)
            LD   (RewriteSemanticOperandArea),A
            LD   A,(RewriteCurrentRoutineFlags)
            AND  RewriteRoutineFlagFails
            LD   A,B
            JR   Z,_RewriteStatementGeneralRoutineEnd
            OR   A
            LD   A,RewriteSemanticEndFailableRoutineEnclosing
            JR   Z,_RewriteStatementRoutineEndReady
            LD   A,RewriteSemanticEndFailableRoutineDirect
            JR   _RewriteStatementRoutineEndReady
_RewriteStatementGeneralRoutineEnd:
            OR   A
            LD   A,RewriteSemanticEndGeneralRoutineEnclosing
            JR   Z,_RewriteStatementRoutineEndReady
            LD   A,RewriteSemanticEndGeneralRoutineDirect
_RewriteStatementRoutineEndReady:
            LD   HL,RewriteSemanticOperandArea
            JP   RewriteSemanticAppend

; `return expression` is success-only. Scalar results use the ordinary
; assignability matrix; aggregate aliases require exact referent identity.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteStatementParseReturnValue:
            LD   A,(RewriteCurrentRoutineResultType)
            CALL RewriteExpressionEvaluateRuntime
            LD   B,A
            LD   A,(RewriteCurrentRoutineResultType)
            OR   A
            JP   Z,RewriteStatementRoutineFlowFailure
            LD   C,A
            CP   RewriteFirstOwnedTypeId
            JR   NC,_RewriteStatementReturnAggregateCheck
            LD   A,B
            CALL RewriteExpressionCheckRuntimeAssignable
            JR   _RewriteStatementReturnFailureCheck
_RewriteStatementReturnAggregateCheck:
            LD   A,B
            CP   C
            JP   NZ,RewriteStatementAssignmentTypeFailure
_RewriteStatementReturnFailureCheck:
            LD   A,(RewritePendingFailure)
            OR   A
            JP   NZ,RewriteStatementFailureContext
            LD   A,(RewriteCurrentRoutineResultType)
            CP   RewriteFirstOwnedTypeId
            LD   A,(RewriteCurrentRoutineFlags)
            LD   B,A
            LD   A,RewriteSemanticReturnScalar
            JR   C,_RewriteStatementReturnKindReady
            LD   A,RewriteSemanticReturnAggregate
_RewriteStatementReturnKindReady:
            BIT  0,B
            JR   Z,_RewriteStatementReturnAppend
            CP   RewriteSemanticReturnAggregate
            LD   A,RewriteSemanticReturnFailableScalar
            JR   NZ,_RewriteStatementReturnAppend
            LD   A,RewriteSemanticReturnFailableAggregate
_RewriteStatementReturnAppend:
            LD   HL,RewriteSemanticOperandArea
            CALL RewriteSemanticAppend
            JP   RewriteStatementMarkNoFallthrough

; Bare return is admitted only in result-free routines. It lowers through the
; same direct routine-end operation as the frozen compiler.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteStatementCommitBareReturn:
            CALL RewriteParserPeek
            LD   A,(RewriteCurrentRoutineResultType)
            OR   A
            JP   NZ,RewriteStatementRoutineFlowFailure
            LD   A,1
            CALL RewriteStatementEmitRoutineEnd
            JP   RewriteStatementMarkNoFallthrough

; The fail keyword's own source offset is retained before parsing its u8 code.
; Main selects the dedicated unhandled-error lowering operation.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteStatementParseFail:
            LD   A,(RewriteCurrentRoutineFlags)
            AND  RewriteRoutineFlagFails
            JP   Z,RewriteStatementFailureContext
            LD   DE,(TokenStartOffset)
            LD   (RewriteStatementExitSourceOffset),DE
            LD   A,RewriteScalarTypeU8
            CALL RewriteExpressionEvaluateRuntime
            LD   C,RewriteScalarTypeU8
            CALL RewriteExpressionCheckRuntimeAssignable
            LD   A,(RewritePendingFailure)
            OR   A
            JP   NZ,RewriteStatementFailureContext
            LD   DE,(RewriteStatementExitSourceOffset)
            LD   (RewriteSemanticOperandArea),DE
            LD   A,(RewriteCurrentRoutineFlags)
            AND  RewriteRoutineFlagMain
            LD   A,RewriteSemanticFailRoutine
            JR   Z,_RewriteStatementFailAppend
            LD   A,RewriteSemanticFailMain
_RewriteStatementFailAppend:
            LD   HL,RewriteSemanticOperandArea
            CALL RewriteSemanticAppend
            JP   RewriteStatementMarkNoFallthrough

; A closing end emits an enclosing-attributed routine end. A result-bearing
; body may close only when the structured fallthrough summary is false.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteStatementFinishRoutine:
            LD   A,(RewriteCurrentRoutineResultType)
            OR   A
            JR   Z,_RewriteStatementFinishRoutineEmit
            LD   A,(RewriteControlSequenceFallsThrough)
            OR   A
            JP   NZ,RewriteStatementRoutineFlowFailure
_RewriteStatementFinishRoutineEmit:
            XOR  A
            CALL RewriteStatementEmitRoutineEnd
            JP   RewriteRoutineCloseScope
