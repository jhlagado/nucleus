; Structured statement lowering for the replacement front end. Control and
; fallthrough state use a bounded compiler-side stack; emitted branches retain
; dense label ordinals and never depend on the compiler's assembled address.

.routine in A out A,DE,HL clobbers carry,zero,sign,parity,halfCarry
RewriteControlFrameAddress:
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
            RET

.routine noreturn
RewriteControlCapacityFailure:
            LD   A,DiagnosticControlCapacity
            JP   RewriteRaiseDiagnostic

.routine noreturn
RewriteControlLabelCapacityFailure:
            LD   A,DiagnosticControlLabelCapacity
            JP   RewriteRaiseDiagnostic

.routine noreturn
RewriteControlExpectedLoopFailure:
            LD   A,DiagnosticExpectedLoop
            JP   RewriteRaiseDiagnostic

; B is RewriteControlKind*. The enclosing sequence bit and a cleared frame are
; published only after the exact depth boundary has been accepted.
.routine in B out A,carry,zero,HL clobbers sign,parity,halfCarry,B,C,D,DE
RewriteControlPushFrame:
            LD   A,(RewriteControlDepth)
            CP   RewriteControlFrameCapacity
            JP   NC,RewriteControlCapacityFailure
            PUSH AF
            LD   E,A
            LD   D,0
            LD   HL,RewriteControlFlowStackBase
            ADD  HL,DE
            LD   A,(RewriteControlSequenceFallsThrough)
            LD   (HL),A
            POP  AF
            PUSH BC
            CALL RewriteControlFrameAddress
            POP  BC
            LD   (HL),B
            INC  HL
            LD   B,RewriteControlFrameSize-1
            XOR  A
_RewriteControlClearFrame:
            LD   (HL),A
            INC  HL
            DJNZ _RewriteControlClearFrame
            LD   HL,RewriteControlDepth
            INC  (HL)
            XOR  A
            RET

.routine out A,carry,zero,HL clobbers sign,parity,halfCarry,D,DE
RewriteControlTopFrame:
            LD   A,(RewriteControlDepth)
            OR   A
            JP   Z,RewriteControlExpectedLoopFailure
            DEC  A
            JP   RewriteControlFrameAddress

.routine in B out A,carry,zero,HL clobbers sign,parity,halfCarry,D,DE
RewriteControlTopField:
            CALL RewriteControlTopFrame
            LD   E,B
            LD   D,0
            ADD  HL,DE
            XOR  A
            RET

; The frame has already contributed its compound result when B is nonzero.
.routine in B out A,carry,zero clobbers sign,parity,halfCarry,B,D,DE,HL
RewriteControlPopCombine:
            LD   HL,RewriteControlDepth
            DEC  (HL)
            LD   A,(HL)
            LD   E,A
            LD   D,0
            LD   HL,RewriteControlFlowStackBase
            ADD  HL,DE
            LD   A,(HL)
            AND  B
            LD   (RewriteControlSequenceFallsThrough),A
            OR   A
            RET

; Loops conservatively fall through, so their completed body summary is not
; combined with the enclosing sequence.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,D,DE,HL
RewriteControlPopRestore:
            LD   B,1
            JP   RewriteControlPopCombine

; B selects the destination byte inside the current frame and C receives the
; allocated control label.
.routine in B out A,C,carry,zero,HL clobbers sign,parity,halfCarry,D,DE
RewriteControlAllocateLabel:
            LD   A,(RewriteControlNextLabel)
            CP   RewriteControlLabelLimit
            JP   NC,RewriteControlLabelCapacityFailure
            LD   C,A
            INC  A
            LD   (RewriteControlNextLabel),A
            CALL RewriteControlTopField
            LD   (HL),C
            XOR  A
            RET

; A is one one-byte-label semantic operation and C is its dense label ordinal.
.routine in A,C out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteControlEmitLabelOperation:
            LD   B,A
            LD   A,C
            LD   (RewriteSemanticOperandArea),A
            LD   A,B
            LD   HL,RewriteSemanticOperandArea
            JP   RewriteSemanticAppend

.routine in C out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteControlEmitLabelDirect:
            LD   A,RewriteSemanticControlLabelDirect
            JP   RewriteControlEmitLabelOperation

.routine in C out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteControlEmitLabelEnclosing:
            LD   A,RewriteSemanticControlLabelEnclosing
            JP   RewriteControlEmitLabelOperation

.routine in C out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteControlEmitBranchFalse:
            LD   A,RewriteSemanticBranchFalse
            JP   RewriteControlEmitLabelOperation

.routine in C out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteControlEmitJumpDirect:
            LD   A,RewriteSemanticJumpDirect
            JP   RewriteControlEmitLabelOperation

.routine in C out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteControlEmitJumpEnclosing:
            LD   A,RewriteSemanticJumpEnclosing
            JP   RewriteControlEmitLabelOperation

; Parse one complete Boolean condition. A failable call cannot act as a
; condition even when its success result is Boolean.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteControlParseBoolean:
            LD   A,RewriteScalarTypeBoolean
            CALL RewriteExpressionEvaluateRuntime
            LD   C,RewriteScalarTypeBoolean
            CALL RewriteExpressionCheckRuntimeAssignable
            LD   A,(RewritePendingFailure)
            OR   A
            JP   NZ,RewriteStatementFailureContext
            XOR  A
            RET

; Record whether every completed if clause is non-fallthrough.
.routine out A,carry,zero,HL clobbers sign,parity,halfCarry,B,D,DE
RewriteControlRecordIfClause:
            LD   A,(RewriteControlSequenceFallsThrough)
            OR   A
            RET  Z
            LD   B,RewriteControlFrameCounter
            CALL RewriteControlTopField
            LD   (HL),0
            XOR  A
            RET

.routine out A,carry,zero,HL clobbers sign,parity,halfCarry,B,C,D,DE
RewriteControlBeginIf:
            LD   B,RewriteControlKindIf
            CALL RewriteControlPushFrame
            LD   B,RewriteControlFrameExit
            CALL RewriteControlAllocateLabel
            LD   B,RewriteControlFrameLabelA
            CALL RewriteControlAllocateLabel
            LD   B,RewriteControlFrameCounter
            CALL RewriteControlTopField
            LD   (HL),1
            XOR  A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteControlBeginIfBody:
            LD   B,RewriteControlFrameLabelA
            CALL RewriteControlTopField
            LD   C,(HL)
            CALL RewriteControlEmitBranchFalse
            LD   A,1
            LD   (RewriteControlSequenceFallsThrough),A
            XOR  A
            RET

; `elseif` and `else` both close the previous clause. A is nonzero when a new
; condition label is required for `elseif`.
.routine in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteControlBeginBranchClause:
            PUSH AF
            CALL RewriteControlRecordIfClause
            LD   B,RewriteControlFrameExit
            CALL RewriteControlTopField
            LD   C,(HL)
            CALL RewriteControlEmitJumpDirect
            LD   B,RewriteControlFrameLabelA
            CALL RewriteControlTopField
            LD   C,(HL)
            CALL RewriteControlEmitLabelDirect
            POP  AF
            OR   A
            JR   Z,_RewriteControlBeginElseReady
            LD   B,RewriteControlFrameLabelA
            JP   RewriteControlAllocateLabel
_RewriteControlBeginElseReady:
            LD   A,1
            LD   (RewriteControlSequenceFallsThrough),A
            XOR  A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteControlBeginElseIf:
            LD   A,1
            JP   RewriteControlBeginBranchClause

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteControlBeginElse:
            XOR  A
            JP   RewriteControlBeginBranchClause

.routine out A,carry,zero,HL clobbers sign,parity,halfCarry,B,D,DE
RewriteControlFinishElse:
            CALL RewriteControlRecordIfClause
            LD   B,RewriteControlFrameMode
            CALL RewriteControlTopField
            LD   (HL),1
            XOR  A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteControlFinishIfClauses:
            CALL RewriteControlRecordIfClause
            LD   B,RewriteControlFrameLabelA
            CALL RewriteControlTopField
            LD   C,(HL)
            JP   RewriteControlEmitLabelEnclosing

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteControlEndIf:
            LD   B,RewriteControlFrameExit
            CALL RewriteControlTopField
            LD   C,(HL)
            CALL RewriteControlEmitLabelEnclosing
            CALL RewriteControlTopFrame
            PUSH HL
            LD   DE,RewriteControlFrameCounter
            ADD  HL,DE
            LD   A,(HL)
            POP  HL
            LD   DE,RewriteControlFrameMode
            ADD  HL,DE
            AND  (HL)
            XOR  1
            LD   B,A
            JP   RewriteControlPopCombine

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteControlBeginWhile:
            LD   B,RewriteControlKindWhile
            CALL RewriteControlPushFrame
            LD   B,RewriteControlFrameLabelA
            CALL RewriteControlAllocateLabel
            LD   B,RewriteControlFrameContinue
            CALL RewriteControlTopField
            LD   (HL),C
            CALL RewriteControlEmitLabelDirect
            LD   B,RewriteControlFrameExit
            JP   RewriteControlAllocateLabel

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteControlBeginWhileBody:
            LD   B,RewriteControlFrameExit
            CALL RewriteControlTopField
            LD   C,(HL)
            CALL RewriteControlEmitBranchFalse
            LD   A,1
            LD   (RewriteControlSequenceFallsThrough),A
            XOR  A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteControlEndWhile:
            LD   B,RewriteControlFrameContinue
            CALL RewriteControlTopField
            LD   C,(HL)
            CALL RewriteControlEmitJumpEnclosing
            LD   B,RewriteControlFrameExit
            CALL RewriteControlTopField
            LD   C,(HL)
            CALL RewriteControlEmitLabelEnclosing
            JP   RewriteControlPopRestore

; Return the nearest enclosing while/for frame in HL.
.routine out A,carry,zero,HL clobbers sign,parity,halfCarry,B,C,D,DE
RewriteControlFindLoop:
            LD   A,(RewriteControlDepth)
            OR   A
            JP   Z,RewriteControlExpectedLoopFailure
_RewriteControlFindLoopNext:
            DEC  A
            PUSH AF
            CALL RewriteControlFrameAddress
            LD   A,(HL)
            CP   RewriteControlKindWhile
            JR   Z,_RewriteControlFindLoopFound
            CP   RewriteControlKindFor
            JR   Z,_RewriteControlFindLoopFound
            POP  AF
            OR   A
            JR   NZ,_RewriteControlFindLoopNext
            JP   RewriteControlExpectedLoopFailure
_RewriteControlFindLoopFound:
            POP  AF
            XOR  A
            RET

; A is RewriteControlFrameExit or RewriteControlFrameContinue.
.routine in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteControlEmitTransfer:
            LD   B,A
            PUSH BC
            CALL RewriteControlFindLoop
            POP  BC
            LD   E,B
            LD   D,0
            ADD  HL,DE
            LD   C,(HL)
            CALL RewriteControlEmitJumpDirect
            JP   RewriteStatementMarkNoFallthrough

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteControlEmitExit:
            LD   A,RewriteControlFrameExit
            JP   RewriteControlEmitTransfer

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteControlEmitContinue:
            LD   A,RewriteControlFrameContinue
            JP   RewriteControlEmitTransfer

; A handler frame is selected at the direct failable call, before its header
; destination is resolved. This preserves the frozen capacity/diagnostic
; order and patches only the declared call operands in the semantic stream.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteControlPrepareHandler:
            LD   B,RewriteControlKindHandler
            CALL RewriteControlPushFrame
            LD   B,RewriteControlFrameLabelA
            CALL RewriteControlAllocateLabel
            LD   B,RewriteControlFrameExit
            CALL RewriteControlAllocateLabel
            LD   HL,(RewritePendingCallModePointer)
            LD   (HL),RewriteCallModeHandle
            INC  HL
            PUSH HL
            LD   B,RewriteControlFrameLabelA
            CALL RewriteControlTopField
            LD   A,(HL)
            POP  HL
            LD   (HL),A
            INC  HL
            LD   A,(RewriteStatementRetainedCarriers)
            LD   (HL),A
            LD   A,2
            LD   (RewritePendingFailure),A
            RET

; Retain one writable u8 destination in the handler frame. Program storage
; keeps its explicit initialized/BSS tag; activation storage keeps the exact
; byte offset. SymbolInfo uses the frozen class/type bit layout without
; borrowing any address bit.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteControlRetainHandlerDestination:
            CALL RewriteSymbolFindCurrent
            JP   NC,RewriteStatementUnknownName
            LD   DE,RewriteSymbolClass
            ADD  HL,DE
            LD   A,(HL)
            CP   RewriteSymbolClassProgram
            JR   Z,_RewriteControlHandlerClassReady
            CP   RewriteSymbolClassLocal
            JR   Z,_RewriteControlHandlerClassReady
            CP   RewriteSymbolClassParameter
            JP   NZ,RewriteStatementAssignmentTypeFailure
_RewriteControlHandlerClassReady:
            LD   B,A
            INC  HL
            LD   A,(HL)
            AND  RewriteTypeIdentityMask
            CP   RewriteScalarTypeU8
            JP   NZ,RewriteStatementAssignmentTypeFailure
            INC  HL
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            INC  HL
            LD   C,(HL)
            LD   A,B
            CP   RewriteSymbolClassLocal
            JR   NZ,_RewriteControlHandlerCounterReady
            PUSH BC
            PUSH DE
            LD   C,E
            CALL RewriteControlCheckActiveCounter
            POP  DE
            POP  BC
_RewriteControlHandlerCounterReady:
            LD   A,B
            ADD  A,A
            ADD  A,A
            OR   RewriteScalarTypeU8
            LD   B,A
            PUSH BC
            PUSH DE
            CALL RewriteControlTopFrame
            LD   DE,RewriteControlFrameCounter
            ADD  HL,DE
            POP  DE
            POP  BC
            LD   A,B
            AND  $0C
            RRCA
            RRCA
            LD   (HL),A
            INC  HL
            LD   (HL),B
            INC  HL
            LD   (HL),E
            INC  HL
            LD   (HL),D
            INC  HL
            INC  HL
            LD   (HL),C
            XOR  A
            RET

; Assignment and call statements admit propagation or a same-line handler.
; Local initializers continue to use RewriteCallConsumeLocalFailure and can
; therefore never reach this handler path.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteControlSelectStatementFailure:
            CALL RewriteParserPeek
            LD   B,A
            LD   A,(RewritePendingFailure)
            OR   A
            JR   NZ,_RewriteControlSelectPendingFailure
            LD   A,B
            CP   TokenElse
            JP   Z,RewriteCallFailureContext
            CP   TokenHandle
            JP   Z,RewriteCallFailureContext
            XOR  A
            RET
_RewriteControlSelectPendingFailure:
            LD   A,B
            CP   TokenElse
            JP   Z,RewriteCallConsumeLocalFailure
            CP   TokenHandle
            JP   NZ,RewriteCallFailureContext
            CALL RewriteControlPrepareHandler
            CALL RewriteParserTake
            LD   A,TokenName
            LD   C,DiagnosticExpectedName
            CALL RewriteCallTakeExpected
            JP   RewriteControlRetainHandlerDestination

; Emit the success skip followed by the failure entry and error destination.
; The body begins with an independent fallthrough summary; success always
; reaches the common exit regardless of the body's own summary.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteControlEmitHandlerPrefix:
            LD   B,RewriteControlFrameExit
            CALL RewriteControlTopField
            LD   C,(HL)
            LD   A,RewriteSemanticSkipHandler
            CALL RewriteControlEmitLabelOperation
            CALL RewriteControlTopFrame
            PUSH HL
            LD   DE,RewriteControlFrameLabelA
            ADD  HL,DE
            LD   A,(HL)
            LD   (RewriteSemanticOperandArea),A
            LD   DE,RewriteControlFrameMode-RewriteControlFrameLabelA
            ADD  HL,DE
            LD   A,(HL)
            LD   (RewriteSemanticOperandArea+1),A
            INC  HL
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            LD   (RewriteSemanticOperandArea+2),DE
            INC  HL
            INC  HL
            LD   C,(HL)
            POP  HL
            LD   B,0
            PUSH BC
            LD   DE,RewriteControlFrameCounter
            ADD  HL,DE
            LD   A,(HL)
            CP   RewriteSymbolClassProgram
            JR   NZ,_RewriteControlEmitHandlerLocal
            POP  BC
            LD   A,C
            CP   RewriteSymbolStorageBss
            LD   A,RewriteSemanticBeginHandlerProgram
            JR   NZ,_RewriteControlEmitHandlerReady
            LD   A,RewriteSemanticBeginHandlerBss
            JR   _RewriteControlEmitHandlerReady
_RewriteControlEmitHandlerLocal:
            POP  BC
            LD   A,RewriteSemanticBeginHandlerLocal
_RewriteControlEmitHandlerReady:
            LD   HL,RewriteSemanticOperandArea
            CALL RewriteSemanticAppend
            XOR  A
            LD   (RewritePendingFailure),A
            LD   A,1
            LD   (RewriteControlSequenceFallsThrough),A
            XOR  A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteControlEndHandler:
            LD   B,RewriteControlFrameExit
            CALL RewriteControlTopField
            LD   C,(HL)
            LD   A,RewriteSemanticEndHandler
            CALL RewriteControlEmitLabelOperation
            JP   RewriteControlPopRestore

.routine noreturn
RewriteControlCounterFailure:
            LD   A,DiagnosticLoopCounter
            JP   RewriteRaiseDiagnostic

.routine noreturn
RewriteControlStepFailure:
            LD   A,DiagnosticLoopStep
            JP   RewriteRaiseDiagnostic

.routine noreturn
RewriteControlForBoundFailure:
            LD   A,DiagnosticExpectedScalar
            JP   RewriteRaiseDiagnostic

; The current token is the counted-loop counter name. Only an integer local is
; admitted, and its activation offset is also the active-counter identity.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteControlBeginForCounter:
            LD   DE,(TokenStartOffset)
            LD   (RewriteControlPendingSourceOffset),DE
            CALL RewriteSymbolFindCurrent
            JP   NC,RewriteStatementUnknownName
            LD   DE,RewriteSymbolClass
            ADD  HL,DE
            LD   A,(HL)
            CP   RewriteSymbolClassLocal
            JP   NZ,RewriteControlCounterFailure
            INC  HL
            LD   A,(HL)
            AND  RewriteTypeIdentityMask
            OR   A
            JP   Z,RewriteControlCounterFailure
            CP   RewriteScalarTypeBoolean
            JP   Z,RewriteControlCounterFailure
            CP   RewriteFirstOwnedTypeId
            JP   NC,RewriteControlCounterFailure
            LD   (RewriteControlPendingType),A
            INC  HL
            LD   C,(HL)
            LD   A,C
            LD   (RewriteControlPendingCounter),A
            CALL RewriteControlCheckActiveCounter
            XOR  A
            RET

; Parse the optional sign and one literal or earlier nonnegative named
; constant. B receives the direction bit and DE the nonzero magnitude.
.routine out A,B,DE,carry,zero clobbers sign,parity,halfCarry,C,HL
RewriteControlParseStep:
            XOR  A
            LD   (RewriteControlPendingMode),A
            CALL RewriteParserPeek
            CP   TokenPlus
            JR   Z,_RewriteControlStepConsumeSign
            CP   TokenMinus
            JR   NZ,_RewriteControlStepMagnitude
            LD   A,2
            LD   (RewriteControlPendingMode),A
_RewriteControlStepConsumeSign:
            CALL RewriteParserTake
_RewriteControlStepMagnitude:
            CALL RewriteParserTake
            CP   TokenNumber
            JR   Z,_RewriteControlStepNumber
            CP   TokenName
            JP   NZ,RewriteControlStepFailure
            CALL RewriteSymbolFindCurrent
            JR   C,_RewriteControlStepNamed
            CALL RewritePredefinedFindCurrent
            JP   NC,RewriteControlStepFailure
            CP   6
            JP   C,RewriteControlStepFailure
            SUB  5
            LD   E,A
            LD   D,0
            JR   _RewriteControlStepReady
_RewriteControlStepNamed:
            LD   BC,RewriteSymbolClass
            ADD  HL,BC
            LD   A,(HL)
            CP   RewriteSymbolClassConstant
            JP   NZ,RewriteControlStepFailure
            INC  HL
            LD   A,(HL)
            BIT  5,A
            JP   NZ,RewriteControlStepFailure
            AND  RewriteTypeIdentityMask
            CP   RewriteScalarTypeBoolean
            JP   Z,RewriteControlStepFailure
            CP   RewriteFirstOwnedTypeId
            JP   NC,RewriteControlStepFailure
            INC  HL
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            JR   _RewriteControlStepReady
_RewriteControlStepNumber:
            LD   D,B
            LD   E,C
_RewriteControlStepReady:
            LD   A,D
            OR   E
            JP   Z,RewriteControlStepFailure
            LD   A,(RewriteControlPendingMode)
            LD   B,A
            XOR  A
            RET

; Start and bound expressions are evaluated exactly once and left on the
; semantic value stack for ForSetup. Mode bit 0 is inclusive `to`; bit 1 is a
; negative step. Bits 2 and 3 are filled from counter width and signedness.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteControlParseForRange:
            LD   A,(RewriteControlPendingType)
            CALL RewriteExpressionEvaluateRuntime
            LD   B,A
            LD   A,(RewriteControlPendingType)
            LD   C,A
            LD   A,B
            CALL RewriteExpressionCheckRuntimeAssignable
            CALL RewriteParserTake
            CP   TokenTo
            LD   B,1
            JR   Z,_RewriteControlForBoundReady
            CP   TokenUntil
            JP   NZ,RewriteControlForBoundFailure
            LD   B,0
_RewriteControlForBoundReady:
            PUSH BC
            CALL RewriteParserPeek
            POP  BC
            LD   A,(RewritePendingFailure)
            OR   A
            JP   NZ,RewriteStatementFailureContext
            PUSH BC
            LD   A,(RewriteControlPendingType)
            CALL RewriteExpressionEvaluateRuntime
            LD   B,A
            LD   A,(RewriteControlPendingType)
            LD   C,A
            LD   A,B
            CALL RewriteExpressionCheckRuntimeAssignable
            POP  BC
            LD   A,(RewritePendingFailure)
            OR   A
            JP   NZ,RewriteStatementFailureContext
            LD   DE,1
            PUSH BC
            PUSH DE
            CALL RewriteParserPeek
            POP  DE
            POP  BC
            CP   TokenStep
            JR   NZ,_RewriteControlForStepReady
            PUSH BC
            CALL RewriteParserTake
            CALL RewriteControlParseStep
            LD   A,B
            POP  BC
            OR   B
            LD   B,A
_RewriteControlForStepReady:
            LD   A,B
            LD   (RewriteControlPendingMode),A
            LD   (RewriteControlPendingStep),DE
            XOR  A
            RET

; Publish a complete fixed-width counted-loop record from the current frame.
.routine in A,HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteControlEmitForPrefix:
            LD   B,A
            PUSH HL
            LD   DE,RewriteControlFrameCounter
            ADD  HL,DE
            LD   A,(HL)
            LD   (RewriteSemanticOperandArea),A
            INC  HL
            LD   A,(HL)
            LD   (RewriteSemanticOperandArea+1),A
            POP  HL
            LD   A,B
            LD   HL,RewriteSemanticOperandArea
            JP   RewriteSemanticAppend

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteControlBeginForBody:
            LD   B,RewriteControlKindFor
            CALL RewriteControlPushFrame
            LD   B,RewriteControlFrameLabelA
            CALL RewriteControlAllocateLabel
            LD   B,RewriteControlFrameContinue
            CALL RewriteControlAllocateLabel
            LD   B,RewriteControlFrameExit
            CALL RewriteControlAllocateLabel
            CALL RewriteControlTopFrame
            PUSH HL
            LD   DE,RewriteControlFrameCounter
            ADD  HL,DE
            LD   A,(RewriteControlPendingCounter)
            LD   (HL),A
            INC  HL
            LD   A,(RewriteControlPendingMode)
            LD   B,A
            LD   A,(RewriteControlPendingType)
            BIT  1,A
            JR   Z,_RewriteControlForModeWidthReady
            SET  2,B
_RewriteControlForModeWidthReady:
            BIT  4,A
            JR   Z,_RewriteControlForModeReady
            SET  3,B
_RewriteControlForModeReady:
            LD   (HL),B
            INC  HL
            LD   DE,(RewriteControlPendingStep)
            LD   (HL),E
            INC  HL
            LD   (HL),D
            INC  HL
            LD   DE,(RewriteControlPendingSourceOffset)
            LD   (HL),E
            INC  HL
            LD   (HL),D
            POP  HL
            LD   A,RewriteSemanticForSetup
            CALL RewriteControlEmitForPrefix
            LD   B,RewriteControlFrameLabelA
            CALL RewriteControlTopField
            LD   C,(HL)
            CALL RewriteControlEmitLabelDirect
            CALL RewriteControlTopFrame
            PUSH HL
            LD   DE,RewriteControlFrameCounter
            ADD  HL,DE
            LD   A,(HL)
            LD   (RewriteSemanticOperandArea),A
            INC  HL
            LD   A,(HL)
            LD   (RewriteSemanticOperandArea+1),A
            POP  HL
            LD   DE,RewriteControlFrameExit
            ADD  HL,DE
            LD   A,(HL)
            LD   (RewriteSemanticOperandArea+2),A
            LD   A,RewriteSemanticForTest
            LD   HL,RewriteSemanticOperandArea
            CALL RewriteSemanticAppend
            LD   A,1
            LD   (RewriteControlSequenceFallsThrough),A
            XOR  A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteControlEndFor:
            LD   B,RewriteControlFrameContinue
            CALL RewriteControlTopField
            LD   C,(HL)
            CALL RewriteControlEmitLabelEnclosing
            CALL RewriteControlTopFrame
            PUSH HL
            LD   DE,RewriteControlFrameLabelA
            ADD  HL,DE
            LD   A,(HL)
            LD   (RewriteSemanticOperandArea),A
            INC  HL
            INC  HL
            LD   A,(HL)
            LD   (RewriteSemanticOperandArea+1),A
            INC  HL
            LD   A,(HL)
            LD   (RewriteSemanticOperandArea+2),A
            INC  HL
            LD   A,(HL)
            LD   (RewriteSemanticOperandArea+3),A
            INC  HL
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            LD   (RewriteSemanticOperandArea+4),DE
            INC  HL
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            LD   (RewriteSemanticOperandArea+6),DE
            POP  HL
            LD   A,RewriteSemanticForNext
            LD   HL,RewriteSemanticOperandArea
            CALL RewriteSemanticAppend
            LD   B,RewriteControlFrameExit
            CALL RewriteControlTopField
            LD   C,(HL)
            CALL RewriteControlEmitLabelEnclosing
            LD   A,RewriteSemanticForCleanup
            LD   HL,RewriteSemanticOperandArea
            CALL RewriteSemanticAppend
            JP   RewriteControlPopRestore
