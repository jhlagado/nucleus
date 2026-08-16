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
