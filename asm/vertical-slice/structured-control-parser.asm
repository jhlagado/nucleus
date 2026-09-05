; Bounded structured-control parser layered over typed scalar expressions.
; Parser frames live only during source checking. Z80 emission reuses their
; workspace after the complete semantic transcript has been published.

.if HybridLL1Full
.else
.routine out A,carry,zero clobbers sign,parity,halfCarry,HL
ControlReset:
            XOR  A
            LD   (CTDEP),A
.if AggregateCallSlices
            RET
.else
            LD   (CTNXLBL),A
            RET
.endif
.endif

.routine in A out A,DE,HL,carry,zero clobbers sign,parity,halfCarry
ControlFrameAddress:
            LD   L,A
            LD   H,0
            ADD  HL,HL
            LD   E,L
            LD   D,H
            ADD  HL,HL
            ADD  HL,HL
            ADD  HL,DE
            LD   DE,CFBAS
            ADD  HL,DE
            OR   A
            RET

; A is ControlKind*. Return the new frame base in HL.
.routine in A out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B,C
ControlPushFrame:
            LD   B,A
            LD   A,(CTDEP)
            CP   CFCAP
            JR   NC,ControlCapacityFailure
            INC  A
            LD   (CTDEP),A
            DEC  A
            CALL ControlFrameAddress
            LD   (HL),B
            INC  HL
            LD   B,CFSZ-1
            XOR  A
ControlClearFrame:
            LD   (HL),A
            INC  HL
            DJNZ ControlClearFrame
            LD   DE,CFCTR-CFSZ
            ADD  HL,DE
            DEC  (HL)                    ; cleared zero -> ControlNoCounter
            LD   DE,-CFCTR
            ADD  HL,DE
            OR   A
            RET
ControlCapacityFailure:
            CALL DGINLINE
            .db  DGCTLCAP

.routine out A,DE,HL,carry,zero clobbers sign,parity,halfCarry
ControlTopFrame:
            LD   A,(CTDEP)
            OR   A
            JR   Z,ControlLoopFailure
            DEC  A
            JR   ControlFrameAddress

.routine in B out A,DE,HL,carry,zero clobbers sign,parity,halfCarry
ControlTopFrameField:
            CALL ControlTopFrame
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   E,B
            LD   D,0
            ADD  HL,DE
            OR   A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,HL
ControlPopFrame:
            LD   HL,CTDEP
            LD   A,(HL)
            OR   A
            JR   Z,ControlLoopFailure
            DEC  (HL)
            XOR  A
            RET

.if HybridLL1Full
.routine out A,C,DE,HL,carry,zero clobbers sign,parity,halfCarry,B
ControlAllocateExit:
            LD   B,CFEXIT
.endif
.routine in B out A,C,DE,HL,carry,zero clobbers sign,parity,halfCarry
ControlAllocateInto:
            LD   A,(CTNXLBL)
.if AggregateCallSlices
            CP   S7CTLLIM
.else
            ; Ordinal 31 is the retained routine entry.
            CP   CRLBL
.endif
            JR   NC,ControlLabelFailure
            LD   C,A
            INC  A
            LD   (CTNXLBL),A
            CALL ControlTopFrameField
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   (HL),C
            RET

.if HybridLL1Full
.routine in B out A,C,DE,HL,carry,zero clobbers sign,parity,halfCarry,B
HybridLL1PushFlowFrameAndLabelA:
            CALL HybridLL1PushFlowFrame
.if CompilerDiagnosticReturns
            RET  C
.endif
.routine out A,B,C,DE,HL,carry,zero clobbers sign,parity,halfCarry
ControlAllocateLabelA:
            LD   B,CFLBLA
.if TargetStreamingOutput
            JR   ControlAllocateInto
.else
            JP   ControlAllocateInto
.endif
.endif

ControlLabelFailure:
            CALL DGINLINE
            .db  DGCLBCAP
ControlLoopFailure:
            CALL DGINLINE
            .db  DXLOOP

; Emit operation D followed by byte C.
.routine in C,D out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
ControlEmitOperationByte:
            LD   A,D
            CALL SemanticSinkOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,C
            JP   SemanticSinkPut

.routine in C out A,carry,zero clobbers sign,parity,halfCarry,B,D,DE,HL
ControlEmitLabel:
            LD   D,SMCTLLBL
            JR   ControlEmitOperationByte
.routine in C out A,carry,zero clobbers sign,parity,halfCarry,B,D,DE,HL
ControlEmitBranchFalse:
            LD   D,SMBRFALS
            JR   ControlEmitOperationByte
.routine in C out A,carry,zero clobbers sign,parity,halfCarry,B,D,DE,HL
ControlEmitJump:
            LD   D,SMJUMP
            JR   ControlEmitOperationByte

; Return the nearest enclosing while/for frame in HL. A syntactic exit marks
; the particular while frame it targets; continues and counted loops retain
; their existing state.
.routine out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B,C
ControlFindLoop:
            LD   A,(CTDEP)
            OR   A
            JR   Z,ControlLoopFailure
ControlFindLoopNext:
            DEC  A
            PUSH AF
            CALL ControlFrameAddress
            LD   A,(HL)
            CP   CKWHILE
            JR   Z,ControlFindLoopFound
            CP   CKFOR
            JR   Z,ControlFindLoopFound
            POP  AF
            OR   A
            JR   NZ,ControlFindLoopNext
            JR   ControlLoopFailure
ControlFindLoopFound:
            LD   E,A
            LD   A,(DCINFO)
            ADD  A,E
            CP   CKWHILE+TNEXIT
            JR   NZ,ControlFindLoopReady
            PUSH HL
            LD   DE,CFMODE
            ADD  HL,DE
            LD   (HL),0
            POP  HL
ControlFindLoopReady:
            POP  AF
            OR   A
            RET

; C is a local byte offset. Reject a source write or nested counter reuse while
; that exact local is the counter of any active counted loop.
.routine in C out A,carry,zero clobbers sign,parity,halfCarry,B,D,DE,HL
ControlCheckActiveCounter:
            LD   A,(CTDEP)
            OR   A
            RET  Z
ControlCheckCounterNext:
            DEC  A
            PUSH AF
            CALL ControlFrameAddress
            LD   A,(HL)
            CP   CKFOR
            JR   NZ,ControlCheckCounterContinue
            LD   DE,CFCTR
            ADD  HL,DE
            LD   A,(HL)
            CP   C
            JR   Z,ControlActiveCounterFailure
ControlCheckCounterContinue:
            POP  AF
            OR   A
            JR   NZ,ControlCheckCounterNext
            RET
ControlActiveCounterFailure:
            POP  AF
            CALL DGINLINE
            .db  DGACTCTR

.if HybridLL1Full
.else
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
StructuredParseBooleanHeader:
            LD   A,TYBOOL
            CALL TypedExpressionBeginRuntime
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   E,TYBOOL
            CALL TypedCheckAssignable
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   ParserExpectLine

; Parse an if/elseif/else chain. TokenIf has already been consumed.
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
StructuredParseIf:
            LD   A,CKIF
            CALL ControlPushFrame
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   B,CFEXIT
            CALL ControlAllocateInto
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   B,CFLBLA
            CALL ControlAllocateInto
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   DE,CFCTR-1
            ADD  HL,DE
            LD   (HL),1
StructuredParseIfCondition:
            CALL StructuredParseBooleanHeader
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ControlTopFrame
            INC  HL
            LD   C,(HL)
            CALL ControlEmitBranchFalse
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL TypedParseStatements
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL StructuredRecordIfClause
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL PSPEEK
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TNELSEIF
            JR   Z,StructuredParseElseIf
            CP   TNELSE
            JR   Z,StructuredParseElse
            CP   TOKENEND
            JP   NZ,ParserExpectedScalar
            CALL ControlTopFrame
            INC  HL
            LD   C,(HL)
            CALL ControlEmitLabel
.if CompilerDiagnosticReturns
            RET  C
.endif
            JR   StructuredParseIfEnd
StructuredParseElseIf:
            CALL StructuredEmitFrameExitAndLabel
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   B,CFLBLA
            CALL ControlAllocateInto
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            JR   StructuredParseIfCondition
StructuredParseElse:
            CALL StructuredEmitFrameExitAndLabel
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectLine
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL TypedParseStatements
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL StructuredRecordIfClause
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   B,CFMODE
            CALL ControlTopFrameField
            LD   (HL),1
            CALL PSPEEK
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TOKENEND
            JP   NZ,ParserExpectedScalar
StructuredParseIfEnd:
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectLine
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   B,CFEXIT
            CALL ControlTopFrameField
            LD   C,(HL)
            CALL ControlEmitLabel
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   B,CFCTR
            CALL ControlTopFrameField
            PUSH HL
            LD   A,(HL)
            POP  HL
            LD   DE,CFMODE-CFCTR
            ADD  HL,DE
            AND  (HL)
            XOR  1
            PUSH AF
            CALL ControlPopFrame
            POP  AF
            RET

.routine out A,C,DE,HL,carry,zero clobbers sign,parity,halfCarry,B
StructuredEmitFrameExitAndLabel:
            LD   B,CFEXIT
            CALL ControlTopFrameField
            LD   C,(HL)
            CALL ControlEmitJump
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ControlTopFrame
            INC  HL
            LD   C,(HL)
            JP   ControlEmitLabel
.endif

.routine out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B
StructuredRecordIfClause:
            LD   B,CFCTR
            CALL ControlTopFrameField
            LD   A,(CTFALLS)
            OR   A
            RET  Z
            LD   (HL),0
            XOR  A
            RET

; TokenWhile has already been consumed.
.if HybridLL1Full
.else
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
StructuredParseWhile:
            LD   A,CKWHILE
            CALL ControlPushFrame
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   B,CFLBLA
            CALL ControlAllocateInto
.if CompilerDiagnosticReturns
            RET  C
.endif
            INC  HL
            LD   (HL),C
            LD   B,CFEXIT
            CALL ControlAllocateInto
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ControlTopFrame
            INC  HL
            LD   C,(HL)
            CALL ControlEmitLabel
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL StructuredParseBooleanHeader
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   B,CFEXIT
            CALL ControlTopFrameField
            LD   C,(HL)
            CALL ControlEmitBranchFalse
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL TypedParseStatements
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL PSPEEK
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TOKENEND
            JP   NZ,ParserExpectedScalar
            LD   B,CFCONT
            CALL ControlTopFrameField
            LD   C,(HL)
            CALL ControlEmitJump
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   B,CFEXIT
            CALL ControlTopFrameField
            LD   C,(HL)
            CALL ControlEmitLabel
.if CompilerDiagnosticReturns
            RET  C
.endif
StructuredCompleteLoop:
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectLine
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   ControlPopFrame

; Parse bare exit/continue. The token has already been consumed.
.routine in A out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
StructuredParseLoopTransfer:
            LD   (DCINFO),A
            CALL ControlFindLoop
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   DE,CFEXIT
            LD   A,(DCINFO)
            CP   TNEXIT
            JR   Z,StructuredLoopTransferSelected
            LD   DE,CFCONT
StructuredLoopTransferSelected:
            ADD  HL,DE
            LD   C,(HL)
            CALL ControlEmitJump
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   ParserExpectLine
.endif

; Parse one compile-time integer expression. B returns direction bit 1 and DE
; returns the nonzero magnitude.
.routine out A,B,DE,carry,zero clobbers sign,parity,halfCarry,C,HL
StructuredParseStep:
            CALL PSPEEK
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   B,0
            CP   TNPLUS
            JR   Z,StructuredStepTakeSign
            CP   TNMIN
            JR   NZ,StructuredStepExpression
            LD   B,2
StructuredStepTakeSign:
            PUSH BC
            CALL ParserTake
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
StructuredStepExpression:
            PUSH BC
            XOR  A
            CALL TypedExpressionBeginConstant
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   D,A
            AND  MTCONST
            JR   Z,StructuredStepFailure
            LD   A,D
            AND  MTTYPMSK
            CP   TYBOOL
            JR   Z,StructuredStepFailure
            LD   A,D
            CALL TypedInferredConstantType
            OR   A
            JR   NZ,StructuredStepFailure
            LD   A,H
            OR   L
            JR   Z,StructuredStepFailure
            EX   DE,HL
            OR   A
            RET
StructuredStepFailure:
            LD   HL,EXVALPOS
            CALL DGRESTTK
            CALL DGINLINE
            .db  DGLOPSTP

; TokenFor has already been consumed.
.if HybridLL1Full
.else
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
StructuredParseFor:
            LD   E,TNNAME
            CALL PSEXPECT
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,(TNSTOFF)
            LD   (EXCALOFF),HL
            CALL SymbolLookupCurrent
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   (DCINFO),A
            LD   (DCPAY),BC
            LD   D,A
            AND  SCMSK
            CP   SCLOC
            JP   NZ,StructuredCounterFailure
            LD   A,D
            AND  MTTYPMSK
            CP   TYBOOL
            JP   Z,StructuredCounterFailure
            CALL ControlCheckActiveCounter
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectEqual
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(DCINFO)
            AND  MTTYPMSK
            CALL TypedExpressionBeginRuntime
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   D,A
            LD   A,(DCINFO)
            AND  MTTYPMSK
            LD   E,A
            LD   A,D
            CALL TypedCheckAssignable
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TOKENTO
            LD   B,1
            JR   Z,StructuredForBound
            CP   TNUNT
            JP   NZ,StructuredCounterFailure
            LD   B,0
StructuredForBound:
            PUSH BC
            LD   A,(DCINFO)
            AND  MTTYPMSK
            CALL TypedExpressionBeginRuntime
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   D,A
            PUSH BC
            LD   A,(DCINFO)
            AND  MTTYPMSK
            LD   E,A
            LD   A,D
            CALL TypedCheckAssignable
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   DE,1
            PUSH BC
            PUSH DE
            CALL PSPEEK
            POP  DE
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TNSTEP
            JR   NZ,StructuredForStepReady
            PUSH BC
            CALL ParserTake
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            PUSH BC
            CALL StructuredParseStep
            LD   A,B
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            OR   B
            LD   B,A
StructuredForStepReady:
            PUSH BC
            PUSH DE
            CALL ParserExpectLine
            POP  DE
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            PUSH BC
            PUSH DE
            LD   A,CKFOR
            CALL ControlPushFrame
            POP  DE
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            PUSH BC
            PUSH DE
            LD   B,CFLBLA
            CALL ControlAllocateInto
            POP  DE
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            PUSH BC
            PUSH DE
            LD   B,CFCONT
            CALL ControlAllocateInto
            POP  DE
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            PUSH BC
            PUSH DE
            LD   B,CFEXIT
            CALL ControlAllocateInto
            POP  DE
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            PUSH DE
            CALL ControlTopFrame
            POP  DE
            PUSH HL
            INC  HL
            INC  HL
            INC  HL
            INC  HL
            LD   A,(DCPAY)
            LD   (HL),A
            INC  HL
            LD   A,(DCINFO)
            AND  MTTYPMSK
            LD   C,A
            BIT  4,C
            JR   Z,StructuredForUnsignedMode
            SET  3,B
StructuredForUnsignedMode:
            BIT  1,A
            JR   Z,StructuredForModeReady
            SET  2,B
StructuredForModeReady:
            LD   A,B
            LD   (HL),A
            INC  HL
            LD   (HL),E
            INC  HL
            LD   (HL),D
            INC  HL
            LD   DE,(EXCALOFF)
            LD   (HL),E
            INC  HL
            LD   (HL),D
            POP  HL
            CALL StructuredEmitForSetup
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ControlTopFrame
            INC  HL
            LD   C,(HL)
            CALL ControlEmitLabel
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL StructuredEmitForTest
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL TypedParseStatements
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL PSPEEK
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TOKENEND
            JP   NZ,ParserExpectedScalar
            LD   B,CFCONT
            CALL ControlTopFrameField
            LD   C,(HL)
            CALL ControlEmitLabel
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL StructuredEmitForNext
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   B,CFEXIT
            CALL ControlTopFrameField
            LD   C,(HL)
            CALL ControlEmitLabel
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,SMFCLEAN
            CALL SemanticSinkOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   StructuredCompleteLoop
.endif
StructuredCounterFailure:
            CALL DGINLINE
            .db  DGLOPCTR

; Emit the fixed-width counted-loop records from the current frame.
.routine in A,HL out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
StructuredEmitForPrefix:
            PUSH HL
            CALL SemanticSinkOperation
            POP  HL
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   DE,CFCTR
            ADD  HL,DE
            LD   A,(HL)
.if CompilerDiagnosticReturns
            PUSH HL
            CALL SemanticSinkPut
            POP  HL
.else
            CALL SemanticSinkPutPreserveHL
.endif
.if CompilerDiagnosticReturns
            RET  C
.endif
            INC  HL
            RET

.routine in HL out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
StructuredEmitForSetup:
            LD   A,SMFORSET
            CALL StructuredEmitForPrefix
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(HL)
            JP   SemanticSinkPut

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
StructuredEmitForTest:
            CALL ControlTopFrame
            LD   A,SMFTEST
            CALL StructuredEmitForPrefix
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(HL)                  ; mode
.if CompilerDiagnosticReturns
            PUSH HL
            CALL SemanticSinkPut
            POP  HL
.else
            CALL SemanticSinkPutPreserveHL
.endif
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   B,CFEXIT
            CALL ControlTopFrameField
            LD   A,(HL)                  ; exit label
            JP   SemanticSinkPut
StructuredEmitFrameBytes:
            LD   A,(HL)
            PUSH BC
.if CompilerDiagnosticReturns
            PUSH HL
            CALL SemanticSinkPut
            POP  HL
.else
            CALL SemanticSinkPutPreserveHL
.endif
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            INC  HL
            DJNZ StructuredEmitFrameBytes
            RET

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
StructuredEmitForNext:
            CALL ControlTopFrame
            PUSH HL
            LD   A,SMFNEXT
            CALL SemanticSinkOperation
            POP  HL
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   DE,CFLBLA
            ADD  HL,DE
            LD   A,(HL)                  ; test label
.if CompilerDiagnosticReturns
            PUSH HL
            CALL SemanticSinkPut
            POP  HL
.else
            CALL SemanticSinkPutPreserveHL
.endif
.if CompilerDiagnosticReturns
            RET  C
.endif
            INC  HL                     ; continue label
            INC  HL                     ; exit label
            LD   A,(HL)
.if CompilerDiagnosticReturns
            PUSH HL
            CALL SemanticSinkPut
            POP  HL
.else
            CALL SemanticSinkPutPreserveHL
.endif
.if CompilerDiagnosticReturns
            RET  C
.endif
            INC  HL                     ; counter
            LD   B,6                    ; counter, mode, step, trap offset
            JR   StructuredEmitFrameBytes
