; Correctness-first typed scalar declarations and expressions.
;
; Expression results return metadata in A and, when constant, a value in HL.
; The low two metadata bits are ScalarType*, and ScalarMetaConstant marks an
; exact compile-time value. Runtime expressions are emitted as a checked
; postfix stream of 16-bit carriers; u8 and boolean carriers have a zero high
; byte. The declared type, not the carrier, controls width and compatibility.

.routine out A,B,HL,carry,zero clobbers sign,parity,halfCarry,C,DE
TypedMatchForwardName:
            LD   A,(FWORD)
            OR   A
            RET  Z
            LD   HL,FWNAMPTR
            JP   TKRECEQ

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
TypedNameEqualsMain:
            LD   HL,NAMEMAIN
            LD   B,4
            JP   TKNAMEEQ

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedRetainDeclarationName:
            CALL TypedNameEqualsMain
            JR   C,TypedDuplicateNameFailure
            CALL TypedMatchForwardName
            JR   C,TypedDuplicateNameFailure
TypedRetainDeclarationNameReady:
            LD   HL,DCNAMPTR
            CALL TKRETAIN
            LD   DE,DCNAMPOS
            CALL DGCOPYTK
            OR   A
            RET

TypedDuplicateNameFailure:
            CALL DGINLINE
            .db  DGDUPNAM

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
TypedRejectCurrentOrdinaryName:
            CALL SymbolFindCurrent
            JR   C,TypedDuplicateNameFailure
            CALL TypedNameEqualsMain
            JR   C,TypedDuplicateNameFailure
            OR   A
            RET

.if AggregateCallSlices
; Carry identifies a source routine or predefined binding with the current
; spelling. Routine-scope declarations may shadow program symbols, but these
; callable and system names stay protected.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
Stage7CurrentNameIsRoutineOrPredefined:
            CALL Stage7FindRoutineCurrent
            SCF
            RET  Z
            CALL TypedNameEqualsMain
            RET  C
            JP   Stage8MatchPredefinedCurrent
.endif

; Restore the retained declaration spelling as the current name token.
.routine out A,HL clobbers carry,zero,sign,parity,halfCarry
TypedRestoreDeclarationToken:
            LD   HL,(DCNAMPTR)
.if NativeStreamingSource
            JP   SARESTOK
.else
            LD   (TNLEXPTR),HL
            LD   A,(DCNAMLEN)
            LD   (TNLEN),A
            RET
.endif

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedPrepareCurrentWord:
            CALL TypedRestoreDeclarationToken
            PUSH BC
            PUSH DE
            LD   HL,DCNAMPOS
            CALL DGRESTTK
.if AggregateCallSlices
.if TargetStreamingOutput
.if DebugHooks
            OUT  (DTDECL),A
.endif
.endif
.endif
.if AggregateCallSlices
            CALL Stage7RejectCurrentDeclarationName
            JR   NC,TypedPrepareCurrentRoutineClear
            POP  DE
            POP  BC
            RET
TypedPrepareCurrentRoutineClear:
.endif
            POP  DE
            POP  BC
            JP   SymbolPrepareCurrentWord
.if AggregateCallSlices
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
TypedPrepareRoutineWord:
            CALL TypedRestoreDeclarationToken
            LD   HL,DCNAMPOS
            CALL DGRESTTK
.if TargetStreamingOutput
.if DebugHooks
            OUT  (DTDECL),A
.endif
.endif
            CALL Stage7CurrentNameIsRoutineOrPredefined
            JP   C,TypedDuplicateNameFailure
            JP   SymbolPrepareRoutineWord
.endif

; Emit one expression operation followed by a complete program address.
.if AggregateCallSlices
.routine in A,BC out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
TypedEmitOperationBC:
            PUSH BC
            CALL TypedEmitOperation
            POP  HL
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   TypedEmitWord
.endif

; Retain an operator that ParserPeek has already returned, then consume that
; cached token without asking ParserTake to peek a second time. Store the zero
; empty-lookahead marker before DEC restores the same $FF, carry-clear,
; zero-clear result that this helper has always returned.
.routine in A out A,carry,zero clobbers sign,parity,halfCarry
TypedTakeOperator:
            LD   (EXOP),A
            XOR  A
            LD   (PSLOOK),A
            DEC  A
            RET
; Push one pending binary-expression context into the bounded compiler stack.
; Retaining the operator source offset is necessary because a nested operation
; may replace the global offset before the outer operation is reduced.
.routine in A out A,HL,carry,zero clobbers sign,parity,halfCarry,B,C,DE,IX,IY
TypedExpressionAddress:
            LD   E,A
            ADD  A,A
            ADD  A,E
            ADD  A,A
            ADD  A,A
            ADD  A,E
            LD   E,A
            LD   D,0
            LD   HL,EXSTKBAS
            ADD  HL,DE
            RET

TypedExpressionPush:
            LD   A,(EXSTKDEP)
            CP   EXSTKCAP
            JR   NC,TypedExpressionStackFull
            CALL TypedExpressionAddress
            EX   DE,HL
            LD   HL,EXSAVE
            LD   BC,EXSTKESZ
            LDIR
            LD   HL,EXSTKDEP
            INC  (HL)
            LD   A,(HL)
            OR   A
            RET

TypedExpressionStackFull:
            CALL DGINLINE
            .db  DGEXPCAP

; Store A/HL as the pending left result before pushing it.
.if TargetStreamingOutput
; The three production left-associative loops have one saved AF above their
; caller. Retain this helper's continuation in DE while consuming that AF,
; then restore the continuation before falling through to TypedSaveLeft.
.routine noreturn
TypedTakeOperatorSaveLeft:
            POP  DE
            CALL TypedTakeOperator
            POP  AF
            PUSH DE
.endif
.routine in A,HL out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedSaveLeft:
.if AggregateCallSlices
            CALL TypedRequireComposable
.if CompilerDiagnosticReturns
            RET  C
.endif
.endif
            LD   (EXLMETA),A
            LD   (EXLVAL),HL
            JR   TypedExpressionPush

; Save the right result, then restore the most recent left result.
.routine in A,HL out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedRestoreOperands:
.if AggregateCallSlices
            CALL TypedRequireComposable
.if CompilerDiagnosticReturns
            RET  C
.endif
.endif
            LD   (EXRMETA),A
            LD   (EXRVAL),HL
            ; Every reduction follows TypedSaveLeft. Keep the defensive test so
            ; a future parser change cannot turn a broken invariant into a
            ; wrapped address beyond CompilerWorkspaceEnd.
            LD   HL,EXSTKDEP
            LD   A,(HL)
            OR   A
            JR   Z,TypedExpressionStackUnderflow
            DEC  A
            LD   (HL),A
            CALL TypedExpressionAddress
            LD   DE,EXSAVE
            LD   BC,EXSAVESZ
            LDIR
            LD   (EXLPOSPT),HL
            OR   A
            RET
TypedExpressionStackUnderflow:
            CALL DGINLINE
            .db  DGINTOP

TypedValueRangeFailure:
            LD   HL,EXVALPOS
            JR   TypedRangeFailureAtPosition
TypedLeftRangeFailure:
            LD   HL,(EXLPOSPT)
TypedRangeFailureAtPosition:
            CALL DGRESTTK
TypedRangeFailure:
            CALL DGINLINE
            .db  DGINTRNG
TypedTypeFailure:
            CALL DGINLINE
            .db  DGTYPMIS
TypedDivisionFailure:
            LD   B,C                     ; statically selected divide width
            LD   C,DGDIVZER
            JR   TypedCheckedFault
TypedNarrowFailure:
            LD   B,TYU8           ; u8(...) always has u8 result type
            LD   C,DGNAR
TypedCheckedFault:
            LD   A,(EXSUPFLT)
            OR   A
            JR   NZ,TypedSuppressedFault
            LD   A,C
            JP   DGSET
TypedSuppressedFault:
            LD   A,B
            LD   HL,0
            OR   MTCONST
            RET

; Resolve two integer operands. The four source metadata/value cells are live.
; C returns u8 or u16. Exact constants adopt the typed peer or expected type.
.routine out A,carry,zero clobbers sign,parity,halfCarry
TypedLeftTypeIsBoolean:
            LD   A,(EXLMETA)
            AND  MTTYPMSK
            CP   TYBOOL
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry
TypedDeclarationScalarType:
            LD   A,(DCINFO)
            AND  MTTYPMSK
            RET

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedResolveIntegerPair:
            CALL TypedLeftTypeIsBoolean
            JR   Z,TypedTypeFailure
            LD   D,A
            LD   A,(EXRMETA)
            AND  MTTYPMSK
            CP   TYBOOL
            JR   Z,TypedTypeFailure
            LD   E,A
            LD   A,D
            OR   A
            JR   NZ,TypedResolveLeftTyped
            LD   A,E
            OR   A
            JR   NZ,TypedResolveExactLeft
            LD   A,(EXEXPTYP)
            AND  MTTYPMSK
            CP   TYBOOL
            JR   Z,TypedResolveBothExactDefault
            OR   A
            JR   NZ,TypedResolveBothExactSelected
TypedResolveBothExactDefault:
            LD   A,(EXLMETA)
            LD   HL,EXRMETA
            OR   (HL)
            AND  MTNEG
            RRCA
            OR   TYU16
            LD   C,A
            JR   TypedResolveValidateBothExact
TypedResolveBothExactSelected:
            LD   C,A
TypedResolveValidateBothExact:
            LD   HL,(EXLVAL)
            LD   A,(EXLMETA)
            CALL TypedConvertConstant
            JR   C,TypedLeftRangeFailure
TypedResolveConvertRight:
            LD   HL,(EXRVAL)
            LD   A,(EXRMETA)
            CALL TypedConvertConstant
            JP   C,TypedValueRangeFailure
            RET
TypedResolveExactLeft:
            LD   C,E
            LD   HL,(EXLVAL)
            LD   A,(EXLMETA)
            CALL TypedConvertConstant
            JP   C,TypedLeftRangeFailure
TypedResolveDone:
            RET
TypedResolveLeftTyped:
            LD   A,E
            OR   A
            JR   NZ,TypedResolveBothTyped
            LD   C,D
            JR   TypedResolveConvertRight
TypedResolveBothTyped:
            LD   A,D
            CP   E
            JR   Z,TypedResolveUseLeftType
            CP   TYU16
            JR   Z,TypedResolveU16CheckRight
            LD   A,E
            CP   TYU16
            JR   NZ,TypedResolveI16
            LD   A,D
            JR   TypedResolveU16Check
TypedResolveI16:
            LD   A,D
            CP   TYI8
            JR   Z,TypedResolveI16PromoteLeft
            LD   A,E
            CP   TYI8
            JR   NZ,TypedResolveI16Ready ; u8 with i16 needs no carrier change
            LD   C,0                     ; promote the right carrier
            JR   TypedResolveI16Promote
TypedResolveI16PromoteLeft:
            LD   C,1                     ; promote the left carrier
TypedResolveI16Promote:
            LD   A,SMPRI8
            CALL ParserEmitOperationC
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,C
            OR   A
            LD   HL,EXRVAL
            JR   Z,TypedResolveI16PromoteConstant
            LD   HL,EXLVAL
TypedResolveI16PromoteConstant:
            LD   A,(HL)
            RLCA
            SBC  A,A
            INC  HL
            LD   (HL),A
TypedResolveI16Ready:
            LD   C,TYI16
            OR   A
            RET
TypedResolveUseLeftType:
            LD   C,D
            OR   A
            RET
TypedResolveU16CheckRight:
            LD   A,E
TypedResolveU16Check:
            CP   TYU8
            JP   NZ,TypedTypeFailure
TypedResolveU16:
            LD   C,TYU16
            OR   A
            RET

.routine in A,D out A,D,carry,zero clobbers sign,parity,halfCarry
TypedRequireScalarSymbolClass:
            AND  SYRECTYP+SYAGGFLG
            JP   NZ,TypedTypeFailure
            LD   A,D
            AND  SCMSK
            RET

; Return constant in A when both operands are constant.
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedBothConstant:
            LD   A,(EXLMETA)
            LD   HL,EXRMETA
            AND  (HL)
            AND  MTCONST
            RET

; Emit a width-selected binary operation. D=u8 ordinal; the u16 ordinal is next.
.routine in C,D out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedEmitWidthOperation:
            LD   A,C
            AND  2
            RRCA
            ADD  A,D
            JP   TypedEmitOperation

; Emit the selected operation, then retain both values only when the pair is
; compile-time constant. Carry reports emission failure; zero reports dynamic.
.routine in C,D out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedPrepareConstantBinary:
            CALL TypedEmitWidthOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL TypedBothConstant
            RET  Z
            LD   HL,(EXLVAL)
            LD   DE,(EXRVAL)
            RET

; Reduce +, -, *, /, integer and, or, xor. ExpressionOperator holds the token.
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedReduceIntegerBinary:
            CALL TypedResolveIntegerPair
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(EXOP)
            SUB  TNMIN
            JR   Z,TypedReduceSubtract
            DEC  A
            JR   Z,TypedReduceAdd
            DEC  A
            JR   Z,TypedReduceMultiply
            CP   TNSLASH-TNSTAR
            JR   Z,TypedReduceDivide
            CP   TOKENAND-TNSTAR
            JR   Z,TypedReduceAnd
            SUB  TOKENXOR-TNSTAR
            JR   Z,TypedReduceXor
            DEC  A
            JR   Z,TypedReduceModulo
TypedReduceOr:
            LD   D,SMOR8
            CALL TypedPrepareConstantBinary
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,C
            RET  Z
            LD   A,L
            OR   E
            LD   L,A
            LD   A,H
            OR   D
            JR   TypedReduceBitwiseConstantDone
TypedReduceXor:
            LD   D,SMXOR8
            CALL TypedPrepareConstantBinary
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,C
            RET  Z
            LD   A,L
            XOR  E
            LD   L,A
            LD   A,H
            XOR  D
            JR   TypedReduceBitwiseConstantDone
TypedReduceAnd:
            LD   D,SMAND8
            CALL TypedPrepareConstantBinary
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,C
            RET  Z
            LD   A,L
            AND  E
            LD   L,A
            LD   A,H
            AND  D
TypedReduceBitwiseConstantDone:
            LD   H,A
            JR   TypedReduceIntegerConstantDone
TypedReduceAdd:
            LD   D,SMADD8
            CALL TypedPrepareConstantBinary
.if CompilerDiagnosticReturns
            RET  C
.endif
            JR   Z,TypedReduceIntegerMeta
            ADD  HL,DE
            JR   TypedReduceAddSubtractDone
TypedReduceSubtract:
            LD   D,SMSUB8
            CALL TypedPrepareConstantBinary
.if CompilerDiagnosticReturns
            RET  C
.endif
            JR   Z,TypedReduceIntegerMeta
            OR   A
            SBC  HL,DE
TypedReduceAddSubtractDone:
            JR   TypedReduceIntegerConstantDone
TypedReduceMultiply:
            LD   D,SMMUL8
            CALL TypedPrepareConstantBinary
.if CompilerDiagnosticReturns
            RET  C
.endif
            JR   Z,TypedReduceIntegerMeta
            ; Constant multiplication modulo 65536, using sixteen shift/add
            ; steps.
            PUSH BC
            LD   BC,0
            LD   A,16
TypedReduceMultiplyLoop:
            SRL  D
            RR   E
            JR   NC,TypedReduceMultiplySkip
            PUSH HL
            ADD  HL,BC
            LD   B,H
            LD   C,L
            POP  HL
TypedReduceMultiplySkip:
            ADD  HL,HL
            DEC  A
            JR   NZ,TypedReduceMultiplyLoop
            LD   H,B
            LD   L,C
            POP  BC
.routine in C,HL out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedReduceIntegerConstantDone:
TypedMaskResultWidth:
            BIT  1,C
            JR   NZ,TypedReduceIntegerConstantMeta
            LD   H,0
TypedReduceIntegerConstantMeta:
            LD   A,C
            OR   MTCONST
            RET
TypedReduceIntegerMeta:
            LD   A,C
            OR   A
            RET
TypedReduceDivide:
            LD   D,SMDIV8
            JR   TypedReduceDivisionSelect
TypedReduceModulo:
            LD   D,SMMOD8
TypedReduceDivisionSelect:
            LD   A,C
            AND  TYSGNFLG
            JR   Z,TypedReduceDivision
            LD   A,SMDIVSGN
            CALL TypedEmitOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            BIT  1,C
            LD   A,$40
            JR   NZ,TypedReduceDivisionSignedMode
            LD   A,$C0
TypedReduceDivisionSignedMode:
            LD   D,A
            LD   A,(EXOP)
            CP   TOKENMOD
            LD   A,D
            JR   NZ,TypedReduceDivisionSignedModeReady
            OR   1
TypedReduceDivisionSignedModeReady:
            CALL TypedEmitByte
.if CompilerDiagnosticReturns
            RET  C
.endif
            JR   TypedReduceDivisionPosition
TypedReduceDivision:
            CALL TypedEmitWidthOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
TypedReduceDivisionPosition:
            LD   HL,(EXOPOFF)
            CALL TypedEmitWord
.if CompilerDiagnosticReturns
            RET  C
.endif
            ; A divisor known to be zero is invalid even when the dividend is
            ; dynamic. The fault helper also implements constant short-circuit
            ; suppression, so the unevaluated Boolean arm remains admissible.
            LD   A,(EXRMETA)
            RLCA
            JR   NC,TypedReduceDivideFold
            LD   HL,(EXRVAL)
            LD   A,H
            OR   L
            JP   Z,TypedDivisionFailure
TypedReduceDivideFold:
            CALL TypedBothConstant
            JR   Z,TypedReduceIntegerMeta
            ; The earlier exact-divisor check proves DE is nonzero here.
            ; Constant unsigned division uses a bounded subtraction loop.
            LD   DE,(EXRVAL)
            LD   HL,(EXLVAL)
            PUSH BC
            LD   A,C
            AND  TYSGNFLG
            JR   Z,TypedReduceDivideUnsignedReady
            BIT  1,C
            JR   NZ,TypedReduceDivideSignedReady
            BIT  7,L
            JR   Z,TypedReduceDivideSignedRight8
            LD   H,$FF
TypedReduceDivideSignedRight8:
            BIT  7,E
            JR   Z,TypedReduceDivideSignedReady
            LD   D,$FF
TypedReduceDivideSignedReady:
            LD   B,0
            LD   C,B
            BIT  7,H
            JR   Z,TypedReduceDivideDividendReady
            SET  0,C
            CALL TypedNegateConstantHL
TypedReduceDivideDividendReady:
            BIT  7,D
            JR   Z,TypedReduceDivideSignsReady
            SET  1,C
            EX   DE,HL
            CALL TypedNegateConstantHL
            EX   DE,HL
TypedReduceDivideSignsReady:
            PUSH BC
            JR   TypedReduceDivideCoreReady
TypedReduceDivideUnsignedReady:
            LD   B,A                     ; unsigned-class test leaves A=0
            LD   C,A
            PUSH BC
TypedReduceDivideCoreReady:
            LD   C,B                     ; both selector paths establish B=0
TypedReduceDivideLoop:
            OR   A
            SBC  HL,DE
            JR   C,TypedReduceDivideDone
            INC  BC
            JR   TypedReduceDivideLoop
TypedReduceDivideDone:
            ADD  HL,DE
            POP  DE
            LD   A,(EXOP)
            CP   TOKENMOD
            JR   Z,TypedReduceDivideModuloSign
            LD   H,B
            LD   L,C
            LD   A,E
            RRCA
            XOR  E
            AND  1
            JR   TypedReduceDivideApplySign
TypedReduceDivideModuloSign:
            LD   A,E
            AND  1
TypedReduceDivideApplySign:
            JR   Z,TypedReduceDivideResultReady
            CALL TypedNegateConstantHL
TypedReduceDivideResultReady:
            POP  BC
            OR   A
            JP   TypedReduceIntegerConstantDone

; Primary expressions.
TypedParsePrimary:
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            PUSH AF
            PUSH BC
            LD   DE,EXVALPOS
            CALL DGCOPYTK
            POP  BC
            POP  AF
            CP   TNNUM
            JR   Z,TypedPrimaryNumber
            CP   TNCHAR
            JR   Z,TypedPrimaryCharacter
            CP   TNNAME
            JR   Z,TypedPrimaryName
            CP   TNLPAR
            JP   Z,TypedPrimaryParen
            SUB  TNTRUE
            CP   2
            JR   C,TypedPrimaryBooleanToken
            INC  B                       ; successful keyword match leaves B=0
            CP   TOKENU8-TNTRUE+$100
            JR   Z,TypedPrimaryConvertB
            INC  B
            CP   TOKENU16-TNTRUE+$100
            JR   NZ,TypedPrimarySignedConvert
TypedPrimaryConvertB:
            LD   A,B
            JP   TypedPrimaryConvertInteger
TypedPrimarySignedConvert:
            SUB  TOKENI8-TNTRUE
            CP   2
            JP   NC,ParserExpectedScalar
            ADD  A,TYI8
            JP   TypedPrimaryConvertInteger
TypedPrimaryNumber:
            LD   H,B
            LD   L,C
            LD   B,MTCONST+TYEXACT
            JR   TypedPrimaryEmitTypedConstant
TypedPrimaryCharacter:
            LD   H,B                     ; punctuation scan exhausts B
            LD   L,C
            JR   TypedPrimaryU8Constant
TypedPrimaryBooleanToken:
            XOR  1
            LD   L,A
            LD   H,B                     ; successful keyword match leaves B=0
TypedPrimaryBooleanConstant:
            LD   B,MTCONST+TYBOOL
            JR   TypedPrimaryEmitTypedConstant
TypedPrimaryU8Constant:
            LD   B,MTCONST+TYU8
TypedPrimaryEmitTypedConstant:
            PUSH BC
            PUSH HL
            LD   A,SMLIT16
            CALL TypedEmitOperation
            POP  HL
.if CompilerDiagnosticBranches
            JR   C,TypedPrimaryEmitTypedConstantFailure
.endif
            PUSH HL
            LD   A,(EXEXPTYP)
            CP   TYI8
            JR   NZ,TypedPrimaryConstantCanonical
            LD   H,0
TypedPrimaryConstantCanonical:
            CALL TypedEmitWord
            POP  HL
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,B
            OR   A
            RET
.if CompilerDiagnosticBranches
TypedPrimaryEmitTypedConstantFailure:
            POP  BC
            RET
.endif
TypedPrimaryName:
.if AggregateCallSlices
            CALL Stage8MatchPredefinedCurrent
            JR   NC,TypedPrimaryOrdinaryName
            CP   P8CONST
            JP   NC,Stage8TypedPrimaryConstant
            CP   P8PORT
            JP   Z,Stage8TypedPrimaryService
            LD   C,A
            AND  $FD                     ; readInput/readStorage map to zero
            JP   NZ,TypedTypeFailure
            LD   A,C
            JP   Stage8TypedPrimaryService
TypedPrimaryOrdinaryName:
            CALL Stage7FindRoutineCurrent
            JP   Z,Stage7TypedPrimaryRoutine
            CALL SymbolLookupCurrent
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   D,A
            AND  SYAGGFLG
            JP   NZ,Stage7TypedPrimaryAggregateSymbol
            LD   A,D
            JR   TypedPrimaryNameResolved
.endif
.if AggregateCallSlices
            ; The retained routine table handles scalar calls above.
.else
            CALL TypedMatchForwardName
            JR   C,TypedPrimaryScalarCall
.endif
TypedPrimaryVariableName:
            CALL SymbolLookupCurrent
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   D,A
TypedPrimaryNameResolved:
            AND  MTTYPMSK
            LD   E,A
            LD   A,D
            CALL TypedRequireScalarSymbolClass
.if CompilerDiagnosticReturns
            RET  C
.endif
            JR   Z,TypedPrimaryConstantName
            RRCA
            RRCA
            CP   SCPAR/4
            JR   Z,TypedPrimaryParameterName
            ADD  A,SMLDPU8-1
            BIT  1,E
            JR   Z,TypedPrimaryProgramSelected
            ADD  A,SMLDP16-SMLDPU8
TypedPrimaryProgramSelected:
            BIT  3,D
            JR   NZ,TypedPrimaryEmitLoad
.if AggregateCallSlices
            PUSH DE
            CALL TypedEmitOperationBC
            POP  DE
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,E
            OR   A
            RET
.else
            JR   TypedPrimaryEmitLoad
.endif
TypedPrimaryParameterName:
            LD   A,SMLDPAR8
            BIT  1,E
            JR   Z,TypedPrimaryEmitLoad
            INC  A
TypedPrimaryEmitLoad:
            PUSH DE
            PUSH BC
            CALL TypedEmitOperation
            POP  BC
            POP  DE
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,C
            PUSH DE
            CALL TypedEmitByte
            POP  DE
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,E
            OR   A
            RET
TypedPrimaryConstantName:
            LD   H,B
            LD   L,C
            LD   B,D
            SET  7,B
.if AggregateCallSlices
            JP   TypedPrimaryEmitTypedConstant
.else
            JR   TypedPrimaryEmitTypedConstant
.endif

; Parse one call to the retained scalar forward. The outer call position stays
; on the compiler stack while a nested argument call is parsed.
.if AggregateCallSlices
            ; Kept only for the pre-aggregate expression proof layouts.
.else
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedPrimaryScalarCall:
            LD   HL,(TNSTOFF)
            PUSH HL
            CALL ParserExpectLeft
.if CompilerDiagnosticBranches
            JR   C,TypedPrimaryCallFailure
.endif
            LD   A,(EXEXPTYP)
            LD   B,A
            LD   A,(FWPARTYP)
            LD   C,A
            PUSH BC
            LD   (EXEXPTYP),A
            CALL TypedParseOr
.if CompilerDiagnosticBranches
            JR   C,TypedPrimaryCallContextFailure
.endif
            LD   D,A
            PUSH DE
            PUSH HL
            CALL ParserExpectRight
.if CompilerDiagnosticBranches
            JR   C,TypedPrimaryCallRightFailure
.endif
            POP  HL
            POP  DE
            POP  BC
            LD   A,B
            LD   (EXEXPTYP),A
            LD   A,C
            LD   E,A
            LD   A,D
            CALL TypedCheckAssignable
.if CompilerDiagnosticBranches
            JR   C,TypedPrimaryCallFailure
.endif
            POP  HL
            PUSH HL
            LD   A,SMCALLSC
            CALL TypedEmitOperation
.if CompilerDiagnosticBranches
            JR   C,TypedPrimaryCallEmitFailure
.endif
            LD   A,(FWORD)
            CALL TypedEmitByte
.if CompilerDiagnosticBranches
            JR   C,TypedPrimaryCallEmitFailure
.endif
            LD   A,(FWRESTYP)
            CALL TypedEmitByte
.if CompilerDiagnosticBranches
            JR   C,TypedPrimaryCallEmitFailure
.endif
            POP  HL
            PUSH HL
            CALL TypedEmitWord
.if CompilerDiagnosticBranches
            JR   C,TypedPrimaryCallEmitFailure
.endif
            POP  HL
            LD   A,(FWRESTYP)
            OR   A
            RET
TypedPrimaryCallEmitFailure:
            POP  HL
            SCF
            RET
TypedPrimaryCallRightFailure:
            POP  HL
            POP  DE
TypedPrimaryCallContextFailure:
            POP  BC
            LD   A,B
            LD   (EXEXPTYP),A
TypedPrimaryCallFailure:
            POP  HL
            SCF
            RET
.endif
.if AggregateCallSlices
; A failable invocation remains consumable only while it is the complete,
; untouched expression. Preserve the expression result while checking that no
; pending direct failure is being enclosed by another expression form.
.routine in A,HL out A,HL,carry,zero clobbers sign,parity,halfCarry,BC,DE,IX,IY
TypedRequireComposable:
            LD   C,A
            LD   A,(S8DIRFBL)
            OR   A
            JP   NZ,HybridLL1FailureContext
            LD   A,C
            RET

.endif
TypedPrimaryParen:
            CALL TypedParseOr
.if CompilerDiagnosticReturns
            RET  C
.endif
            PUSH AF
            PUSH HL
            CALL ParserExpectRight
.if CompilerDiagnosticBranches
            JR   C,TypedPrimaryParenFailure
.endif
            POP  HL
            POP  AF
.if AggregateCallSlices
            JR   TypedRequireComposable
.else
            RET
.endif
.if CompilerDiagnosticBranches
TypedPrimaryParenFailure:
            POP  HL
            POP  AF
            SCF
            RET
.endif

TypedPrimaryConvertInteger:
            LD   C,A
            LD   HL,(TNSTOFF)
            LD   (EXOPOFF),HL
            PUSH AF                       ; destination type
            PUSH HL                       ; conversion trap position
            LD   A,C
            ; Parse the parenthesized operand under the conversion's expected
            ; type, then restore the enclosing expectation before continuing.
            LD   C,A
            LD   A,(EXEXPTYP)
            LD   B,A
            PUSH BC
            LD   A,C
            LD   (EXEXPTYP),A
            CALL ParserExpectLeft
.if CompilerDiagnosticBranches
            JR   C,TypedPrimaryConversionFailure
.endif
            CALL TypedParseOr
.if CompilerDiagnosticBranches
            JR   C,TypedPrimaryConversionFailure
.endif
            LD   D,A
            PUSH DE
            PUSH HL
            CALL ParserExpectRight
.if CompilerDiagnosticBranches
            JR   C,TypedPrimaryConversionRightFailure
.endif
            POP  HL
            POP  DE
            POP  BC
            LD   A,B
            LD   (EXEXPTYP),A
            LD   A,D
.if AggregateCallSlices
            CALL TypedRequireComposable
.if CompilerDiagnosticBranches
            JR   C,TypedPrimaryConvertContextFailure
.endif
.endif
.if CompilerDiagnosticBranches
            JR   TypedPrimaryConversionReady
TypedPrimaryConversionRightFailure:
            POP  HL
            POP  DE
TypedPrimaryConversionFailure:
            POP  BC
            LD   A,B
            LD   (EXEXPTYP),A
            JR   TypedPrimaryConvertContextFailure
TypedPrimaryConversionReady:
.endif
            LD   D,A
            LD   B,H
            LD   C,L
            POP  HL
            LD   (EXOPOFF),HL
            POP  AF
            PUSH AF                       ; destination type
            LD   H,B
            LD   L,C
            LD   A,D
            CALL TypedRequireIntegerMeta
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   D,A
            POP  AF
            LD   C,A
            LD   A,D
            AND  MTCONST
            JR   Z,TypedPrimaryDynamicConvert
            LD   A,D
            CALL TypedConvertConstant
            JR   NC,TypedPrimaryConstantConvertReady
            LD   B,C
            JP   TypedNarrowFailure
TypedPrimaryConstantConvertReady:
            JP   TypedReduceIntegerConstantMeta
TypedPrimaryDynamicConvert:
            LD   A,D
            AND  MTTYPMSK
            CP   C
            JR   Z,TypedPrimaryDynamicConvertDone
            CP   TYU8
            JR   NZ,TypedPrimaryDynamicConvertEmit
            BIT  1,C
            JR   NZ,TypedPrimaryDynamicConvertDone
TypedPrimaryDynamicConvertEmit:
.if AggregateCallSlices
            LD   HL,(EXOPOFF)
            CALL TypedEmitIntegerConversionOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
.else
            LD   A,SMNARU8
            CALL TypedEmitOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,(EXOPOFF)
            CALL TypedEmitWord
.if CompilerDiagnosticReturns
            RET  C
.endif
.endif
TypedPrimaryDynamicConvertDone:
            LD   A,C
            OR   A
            RET
.if CompilerDiagnosticBranches
TypedPrimaryConvertContextFailure:
            POP  HL
            POP  AF
            SCF
            RET
.endif

; Publish a checked integer conversion from source metadata D to destination
; type C. HL is the source position used if the generated range check traps.
.routine in C,D,HL out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL,IX,IY
TypedEmitIntegerConversionOperation:
            LD   (EXOPOFF),HL
            LD   A,SMCVTINT
            PUSH BC
            PUSH DE
            CALL TypedEmitOperation
            POP  DE
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,D
            AND  MTTYPMSK
            CALL TypedEmitByte
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,C
            CALL TypedEmitByte
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,(EXOPOFF)
            JP   TypedEmitWord

; Check and fold one explicit constant integer conversion. A is source
; metadata, C is the destination type, and HL is the source payload.
.routine in A,C,HL out A,C,D,HL,carry,zero clobbers sign,parity,halfCarry,B,E,IX,IY
TypedConvertConstant:
            LD   D,A
            AND  MTTYPMSK
            BIT  4,A
            JR   Z,TypedConvertSourceExactOrUnsigned
            RRA
            JR   NC,TypedConvertSourceI16
TypedConvertSourceI8:
            BIT  7,L
            JR   Z,TypedConvertSourceExactOrUnsigned
            LD   H,$FF
            JR   TypedConvertNegative
TypedConvertSourceI16:
            BIT  7,H
            JR   NZ,TypedConvertNegative
TypedConvertSourceExactOrUnsigned:
            LD   A,D
            AND  MTNEG
            JR   Z,TypedConvertNonnegative
TypedConvertNegative:
            BIT  4,C
            JR   Z,TypedConvertConstantFailure
            BIT  1,C
            JR   NZ,TypedConvertDone
            INC  H
            JR   NZ,TypedConvertConstantFailure
            BIT  7,L
            JR   Z,TypedConvertConstantFailure
            JR   TypedConvertDone
TypedConvertNonnegative:
            BIT  1,C
            JR   NZ,TypedConvertPositiveWord
            LD   A,H
            OR   A
            JR   NZ,TypedConvertConstantFailure
            BIT  4,C
            JR   Z,TypedConvertDone
            BIT  7,L
            JR   NZ,TypedConvertConstantFailure
            JR   TypedConvertDone
TypedConvertPositiveWord:
            BIT  4,C
            JR   Z,TypedConvertDone
            BIT  7,H
            JR   NZ,TypedConvertConstantFailure
TypedConvertDone:
            OR   A
            RET
TypedConvertConstantFailure:
            SCF
            RET

.routine in A out A,D,carry,zero clobbers sign,parity,halfCarry
TypedRequireIntegerMeta:
            LD   D,A
            AND  MTTYPMSK
            CP   TYBOOL
            JP   Z,TypedTypeFailure
            AND  TYBASMSK
            CP   3
            JP   NC,TypedTypeFailure
            LD   A,D
            OR   A
            RET

; Unary +, -, and not bind above multiplicative operators.
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedParseUnary:
            CALL PSPEEK
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TNPLUS
            JR   Z,TypedUnaryPlus
            CP   TNMIN
            JR   Z,TypedUnaryMinus
            CP   TOKENNOT
            JP   Z,TypedUnaryNot
            JP   TypedParsePrimary
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedUnaryPlus:
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL TypedParseUnary
.if CompilerDiagnosticReturns
            RET  C
.endif
.if AggregateCallSlices
            CALL TypedRequireComposable
.if CompilerDiagnosticReturns
            RET  C
.endif
.endif
            JR   TypedRequireIntegerMeta
TypedUnaryMinus:
            CALL TypedUnaryPlus
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   D,A
            AND  MTTYPMSK
            JR   NZ,TypedUnaryMinusTyped
            LD   A,SMNEG16
            CALL TypedEmitUnaryOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,D
            AND  MTNEG
            JR   NZ,TypedUnaryMinusExactWasNegative
            LD   A,H
            CP   $80
            JR   C,TypedUnaryMinusExactNegate
            JP   NZ,TypedValueRangeFailure
            LD   A,L
            OR   A
            JP   NZ,TypedValueRangeFailure
TypedUnaryMinusExactNegate:
            CALL TypedNegateConstantHL
            LD   A,H
            OR   L
            LD   A,MTCONST+TYEXACT
            RET  Z
            OR   MTNEG
            RET
TypedUnaryMinusExactWasNegative:
            CALL TypedNegateConstantHL
            LD   A,MTCONST+TYEXACT
            OR   A
            RET
TypedUnaryMinusTyped:
            LD   A,D
            AND  MTTYPMSK
TypedUnaryMinusResolved:
            LD   C,A
            AND  2
            RRCA
            ADD  A,SMNEG8
TypedUnaryMinusEmit:
            CALL TypedEmitUnaryOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,D
            AND  MTCONST
            LD   A,C
            RET  Z
            CALL TypedNegateConstantHL
            JP   TypedMaskResultWidth

.routine in A,BC,DE,HL out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedEmitUnaryOperation:
            PUSH BC
            PUSH DE
            PUSH HL
            CALL TypedEmitOperation
            POP  HL
            POP  DE
            POP  BC
            RET
.routine in HL out A,HL clobbers carry,zero,sign,parity,halfCarry
TypedNegateConstantHL:
            XOR  A
            SUB  L
            LD   L,A
            SBC  A,A
            SUB  H
            LD   H,A
            RET
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedParseMultiplicative:
            CALL TypedParseUnary
.if CompilerDiagnosticReturns
            RET  C
.endif
TypedMultiplicativeLoop:
            PUSH AF
            PUSH HL
            CALL PSPEEK
.if CompilerDiagnosticBranches
            JR   C,TypedMultiplicativePeekFailure
.endif
            CP   TNSTAR
            JR   Z,TypedMultiplicativeOperator
            CP   TNSLASH
            JR   Z,TypedMultiplicativeOperator
            CP   TOKENMOD
            JR   NZ,TypedMultiplicativeDone
TypedMultiplicativeOperator:
            CALL TypedTakeOperator
.if CompilerDiagnosticBranches
            JR   C,TypedMultiplicativePeekFailure
.endif
            LD   HL,(TNSTOFF)
            LD   (EXOPOFF),HL
            POP  HL
            POP  AF
            CALL TypedSaveLeft
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL TypedParseUnary
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL TypedRestoreOperands
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL TypedReduceIntegerBinary
.if CompilerDiagnosticReturns
            RET  C
.endif
            JR   TypedMultiplicativeLoop
TypedMultiplicativeDone:
            POP  HL
            POP  AF
            RET
.if CompilerDiagnosticBranches
TypedMultiplicativePeekFailure:
            POP  HL
            POP  AF
            SCF
            RET
.endif

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedParseAdditive:
            CALL TypedParseMultiplicative
.if CompilerDiagnosticReturns
            RET  C
.endif
TypedAdditiveLoop:
            PUSH AF
            CALL PSPEEK
.if CompilerDiagnosticBranches
            JR   C,TypedAdditivePeekFailure
.endif
            CP   TNPLUS
            JR   Z,TypedAdditiveOperator
            CP   TNMIN
            JR   NZ,TypedAdditiveDone
TypedAdditiveOperator:
.if TargetStreamingOutput
            CALL TypedTakeOperatorSaveLeft
.else
            CALL TypedTakeOperator
.if CompilerDiagnosticBranches
            JR   C,TypedAdditivePeekFailure
.endif
            POP  AF
            CALL TypedSaveLeft
.endif
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL TypedParseMultiplicative
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL TypedRestoreOperands
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL TypedReduceIntegerBinary
.if CompilerDiagnosticReturns
            RET  C
.endif
            JR   TypedAdditiveLoop
TypedAdditiveDone:
            POP  AF
            RET
.if CompilerDiagnosticBranches
TypedAdditivePeekFailure:
            POP  AF
            SCF
            RET
.endif

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedComparisonToken:
            LD   C,RCEQ
            CP   TNEQ
            SCF
            RET  Z
            SUB  TNLT
            CP   TNNOTEQ-TNLT+1
            RET  NC
            INC  A
            INC  A
            CP   RCGE+1
            JR   NZ,TypedComparisonTokenSelected
            LD   A,RCNE
TypedComparisonTokenSelected:
            LD   C,A
TypedComparisonTokenYes:
            SCF
            RET

TypedParseComparison:
            CALL TypedParseAdditive
.if CompilerDiagnosticReturns
            RET  C
.endif
            PUSH AF
            PUSH HL
            CALL PSPEEK
.if CompilerDiagnosticBranches
            JR   C,TypedComparisonStackFailure
.endif
            CALL TypedComparisonToken
            JR   NC,TypedComparisonNone
            LD   A,C
            CALL TypedTakeOperator
.if CompilerDiagnosticBranches
            JR   C,TypedComparisonStackFailure
.endif
            POP  HL
            POP  AF
            CALL TypedSaveLeft
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL TypedParseAdditive
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL TypedRestoreOperands
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL TypedReduceComparison
.if CompilerDiagnosticReturns
            RET  C
.endif
            PUSH AF
            PUSH HL
            CALL PSPEEK
.if CompilerDiagnosticBranches
            JR   C,TypedComparisonStackFailure
.endif
            CALL TypedComparisonToken
            JR   C,TypedComparisonChained
TypedComparisonNone:
            POP  HL
            POP  AF
            RET
.if CompilerDiagnosticBranches
TypedComparisonStackFailure:
            POP  HL
            POP  AF
            SCF
            RET
.endif
TypedComparisonChained:
            POP  HL
            POP  AF
            CALL DGINLINE
            .db  DGCMPCHN
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedReduceComparison:
            LD   A,(EXRMETA)
            AND  MTTYPMSK
            LD   E,A
            LD   A,(EXLMETA)
            AND  MTTYPMSK
            CP   TYBOOL
            JR   NZ,TypedComparisonInteger
            LD   A,E
            SUB  TYBOOL
            JP   NZ,TypedTypeFailure
            LD   A,(EXOP)
            CP   RCNE+1
            JP   NC,TypedTypeFailure
            LD   D,A                     ; successful Boolean test leaves A=0
            LD   A,SMCMPBL
            JR   TypedComparisonEmit
TypedComparisonInteger:
            CALL TypedResolveIntegerPair
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,C
            LD   D,A
            AND  TYSGNFLG
            JR   NZ,TypedComparisonSigned
            LD   D,A                     ; unsigned-class test leaves A=0
            LD   A,C
            AND  2
            RRCA
            ADD  A,SMCMP8
            JR   TypedComparisonEmit
TypedComparisonSigned:
            BIT  1,D
            LD   D,$80                    ; signed word selector flag
            JR   NZ,TypedComparisonSignedReady
            LD   D,$C0                    ; signed byte selector flag
TypedComparisonSignedReady:
            LD   A,SMCMP16
TypedComparisonEmit:
            PUSH DE
            CALL TypedEmitOperation
            POP  DE
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(EXOP)
            OR   D
            CALL TypedEmitByte
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL TypedBothConstant
            LD   A,TYBOOL
            RET  Z
            LD   HL,(EXLVAL)
            LD   DE,(EXRVAL)
            LD   A,C
            AND  TYSGNFLG
            JR   Z,TypedComparisonConstantSubtract
            BIT  1,C
            JR   Z,TypedComparisonConstantSigned8
            LD   A,H
            XOR  $80
            LD   H,A
            LD   A,D
            XOR  $80
            LD   D,A
            JR   TypedComparisonConstantSubtract
TypedComparisonConstantSigned8:
            LD   A,L
            XOR  $80
            LD   L,A
            LD   A,E
            XOR  $80
            LD   E,A
TypedComparisonConstantSubtract:
            XOR  A
            SBC  HL,DE
            ; Classify the relation as equal/less/greater (0/1/2), then use
            ; the dense comparison ordinal to select one Boolean table cell.
            ; The table contains language truth values, never code addresses.
            LD   D,A                     ; XOR established A=0
            JR   Z,TypedComparisonRelationReady
            INC  D
            JR   C,TypedComparisonRelationReady
            INC  D
TypedComparisonRelationReady:
            LD   A,(EXOP)
            LD   E,A
            ADD  A,A
            ADD  A,E
            ADD  A,D
            LD   E,A
            LD   D,0
            LD   HL,KWCMPRES
            ADD  HL,DE
            LD   L,(HL)
            LD   H,D
TypedComparisonConstantDone:
            LD   A,MTCONST+TYBOOL
            OR   A
            RET

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedParseComparisonEntry:
            JP   TypedParseComparison

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedUnaryNot:
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL TypedParseUnary
.if CompilerDiagnosticReturns
            RET  C
.endif
.if AggregateCallSlices
            CALL TypedRequireComposable
.if CompilerDiagnosticReturns
            RET  C
.endif
.endif
            LD   D,A
            AND  MTTYPMSK
            LD   C,A
            CP   TYBOOL
            LD   A,SMNOTBL
            JR   Z,TypedNotEmit
            LD   A,C
            OR   A
            JR   NZ,TypedNotTypedInteger
            LD   A,(EXEXPTYP)
            CP   TYU8
            JR   Z,TypedNotExactU8
            LD   C,TYU16
            LD   A,SMNOT16
            JR   TypedNotEmit
TypedNotExactU8:
            ; As with unary minus, validate the exact operand before applying
            ; the width-specific complement and masking the result.
            LD   A,D
            AND  MTCONST
            JR   Z,TypedNotExactU8Ready
            LD   A,H
            OR   A
            JP   NZ,TypedValueRangeFailure
TypedNotExactU8Ready:
            LD   C,TYU8
            LD   A,SMNOT8
            JR   TypedNotEmit
TypedNotTypedInteger:
            CP   TYU8
            LD   A,SMNOT16
            JR   NZ,TypedNotEmit
            DEC  A
TypedNotEmit:
            CALL TypedEmitUnaryOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,D
            AND  MTCONST
            LD   A,C
            RET  Z
            CP   TYBOOL
            JR   NZ,TypedNotIntegerConstant
            LD   A,L
            XOR  1
            LD   L,A
            JP   TypedReduceIntegerConstantMeta
TypedNotIntegerConstant:
            LD   A,L
            CPL
            LD   L,A
            LD   A,H
            CPL
            LD   H,A
            JP   TypedMaskResultWidth

; Boolean short circuit is represented by prefix/suffix operations so the
; Z80 backend can branch around the right operand. Integer and/or use the
; ordinary postfix reduction.
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedParseAnd:
            CALL TypedParseComparisonEntry
.if CompilerDiagnosticReturns
            RET  C
.endif
TypedAndLoop:
            PUSH AF
            CALL PSPEEK
.if CompilerDiagnosticBranches
            JP   C,TypedBooleanPeekFailure
.endif
            CP   TOKENAND
.if TargetStreamingOutput
            JR   NZ,TypedBooleanDone
.else
            JP   NZ,TypedBooleanDone
.endif
.if TargetStreamingOutput
            CALL TypedTakeOperatorSaveLeft
.else
            CALL TypedTakeOperator
.if CompilerDiagnosticBranches
            JP   C,TypedBooleanPeekFailure
.endif
            POP  AF
            CALL TypedSaveLeft
.endif
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL TypedLeftTypeIsBoolean
            JR   NZ,TypedAndParseRight
            LD   C,0
            CALL TypedBeginBooleanSuppression
.if CompilerDiagnosticReturns
            RET  C
.endif
TypedAndParseRight:
            CALL TypedParseComparisonEntry
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL TypedRestoreOperands
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL TypedLeftTypeIsBoolean
            JR   NZ,TypedAndInteger
            CALL TypedReduceBoolean
.if CompilerDiagnosticReturns
            RET  C
.endif
            JR   TypedAndLoop
TypedAndInteger:
            CALL TypedReduceIntegerBinary
.if CompilerDiagnosticReturns
            RET  C
.endif
            JR   TypedAndLoop

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedParseOr:
            CALL TypedParseAnd
.if CompilerDiagnosticReturns
            RET  C
.endif
TypedOrLoop:
            PUSH AF
            CALL PSPEEK
.if CompilerDiagnosticBranches
            JR   C,TypedBooleanPeekFailure
.endif
            CP   TOKENXOR
            JR   Z,TypedOrOperator
            CP   TOKENOR
            JR   NZ,TypedBooleanDone
.if AggregateCallSlices
            LD   A,(S8DIRFBL)
            OR   A
            JR   NZ,TypedOrFailureContext
            LD   A,TOKENOR
.endif
TypedOrOperator:
.if TargetStreamingOutput
            CALL TypedTakeOperatorSaveLeft
.else
            CALL TypedTakeOperator
.if CompilerDiagnosticBranches
            JR   C,TypedBooleanPeekFailure
.endif
            POP  AF
            CALL TypedSaveLeft
.endif
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(EXOP)
            CP   TOKENXOR
            JR   NZ,TypedOrBooleanLeft
            CALL TypedLeftTypeIsBoolean
            JP   Z,TypedTypeFailure
            JR   TypedOrParseRight
TypedOrBooleanLeft:
            CALL TypedLeftTypeIsBoolean
            JR   NZ,TypedOrParseRight
            LD   C,1
            CALL TypedBeginBooleanSuppression
.if CompilerDiagnosticReturns
            RET  C
.endif
TypedOrParseRight:
            CALL TypedParseAnd
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL TypedRestoreOperands
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL TypedLeftTypeIsBoolean
            JR   NZ,TypedOrInteger
            CALL TypedReduceBoolean
.if CompilerDiagnosticReturns
            RET  C
.endif
            JR   TypedOrLoop
TypedBooleanDone:
            POP  AF
            RET
.if AggregateCallSlices
TypedOrFailureContext:
            CALL HybridLL1FailureContext
.endif
.if CompilerDiagnosticBranches
TypedBooleanPeekFailure:
            POP  AF
            SCF
            RET
.endif
TypedOrInteger:
            CALL TypedReduceIntegerBinary
.if CompilerDiagnosticReturns
            RET  C
.endif
            JR   TypedOrLoop

.routine in C out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedBeginBooleanSuppression:
            LD   A,C
            ADD  A,SMBGAND
            CALL TypedEmitOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
.routine in C out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedBeginSuppression:
            LD   A,(EXLMETA)
            RLCA
            RET  NC
            LD   A,(EXLVAL)
            XOR  C
            RET  NZ
            LD   HL,EXSUPFLT
            INC  (HL)
            RET
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedReduceBoolean:
            LD   A,(EXRMETA)
            AND  MTTYPMSK
            CP   TYBOOL
            JP   NZ,TypedTypeFailure
            LD   A,SMENDBL
            CALL TypedEmitOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL TypedBothConstant
            LD   A,TYBOOL
            RET  Z
            LD   HL,(EXRVAL)
            LD   A,(EXOP)
            CP   TOKENAND
            LD   A,(EXLVAL)
            JR   Z,TypedBooleanConstantAnd
            OR   L
            JR   TypedBooleanConstantReady
TypedBooleanConstantAnd:
            AND  L
TypedBooleanConstantReady:
            LD   L,A
TypedBooleanConstant:
            JP   TypedComparisonConstantDone

; Assignment compatibility resolves exact constants and the value-preserving
; unsigned/signed widening family. A/HL is the expression; E is destination.
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedCheckAssignable:
            LD   D,A
            AND  MTTYPMSK
            JR   NZ,TypedAssignableTyped
            LD   A,E
            CP   TYBOOL
            JP   Z,TypedTypeFailure
            LD   C,E
            LD   A,D
            CALL TypedConvertConstant
            JP   C,TypedValueRangeFailure
            LD   A,D
            AND  MTCONST
            OR   C
            RET
TypedAssignableTyped:
            CP   E
            JR   Z,TypedAssignableSame
            CP   TYU8
            JR   Z,TypedAssignableFromU8
            CP   TYI8
            JP   NZ,TypedTypeFailure
            LD   A,E
            CP   TYI16
            JP   NZ,TypedTypeFailure
            LD   C,TYI16
            LD   HL,(EXVALPOS)
            PUSH DE
            CALL TypedEmitIntegerConversionOperation
            POP  DE
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,D
            AND  MTCONST
            JR   Z,TypedAssignableSame
            BIT  7,L
            JR   Z,TypedAssignableSame
            LD   H,$FF
            JR   TypedAssignableSame
TypedAssignableFromU8:
            LD   A,E
            CP   TYU16
            JR   Z,TypedAssignableSame
            CP   TYI16
            JP   NZ,TypedTypeFailure
TypedAssignableSame:
            LD   A,D
            AND  MTCONST
            OR   E
            RET

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedExpressionBeginRuntime:
            LD   (EXEXPTYP),A
.if AggregateCallSlices
            XOR  A
            LD   (S8DIRFBL),A
            LD   (S8CARR),A
            INC  A
.else
            LD   A,1
.endif
            JR   TypedExpressionBeginReset
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedExpressionBeginConstant:
            LD   (EXEXPTYP),A
            XOR  A
.routine in A out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedExpressionBeginReset:
            LD   (EXEMITON),A
            XOR  A
            LD   (EXSUPFLT),A
            LD   (EXSTKDEP),A
            JP   TypedParseOr

; Parse one scalar type and return ScalarType* in A.
.if HybridLL1Full
.else
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedParseType:
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TOKENU8
            JR   Z,TypedTypeU8
            CP   TOKENU16
            JR   Z,TypedTypeU16
            CP   TOKENI8
            JR   Z,TypedTypeI8
            CP   TOKENI16
            JR   Z,TypedTypeI16
            CP   TNBOOL
            JR   Z,TypedTypeBoolean
            CALL DGINLINE
            .db  DXTYP
TypedTypeU8:       LD A,TYU8
                   OR A
                   RET
TypedTypeU16:      LD A,TYU16
                   OR A
                   RET
TypedTypeI8:       LD A,TYI8
                   OR A
                   RET
TypedTypeI16:      LD A,TYI16
                   OR A
                   RET
TypedTypeBoolean:  LD A,TYBOOL
                   OR A
                   RET
.endif

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedTypeWidth:
            AND  2
            RRCA
            INC  A
            RET

; A completed integer constant returns to the exact integer category. Only a
; Boolean retains a concrete type; a negative signed result retains its sign.
.routine in A,HL out A,carry,zero clobbers sign,parity,halfCarry,D
TypedInferredConstantType:
            LD   D,A
            AND  MTTYPMSK
            CP   TYBOOL
            RET  Z
            CP   TYI8
            JR   Z,TypedInferredConstantI8
            CP   TYI16
            JR   Z,TypedInferredConstantI16
            LD   A,D
            AND  MTNEG
            RET
TypedInferredConstantI8:
            BIT  7,L
            JR   TypedInferredConstantSign
TypedInferredConstantI16:
            BIT  7,H
TypedInferredConstantSign:
            LD   A,MTNEG
            RET  NZ
            XOR  A
            RET

; Emit a typed static program object. D=type, BC=offset, HL=value.
.if HybridLL1Full
.else
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedEmitProgramDefinition:
            LD   A,D
            BIT  1,A
            LD   A,SMDEFPU8
            JR   Z,TypedEmitProgramDefinitionOp
            LD   A,SMDEFP16
TypedEmitProgramDefinitionOp:
            PUSH BC
            PUSH DE
            PUSH HL
            CALL SemanticSinkOperation
            POP  HL
            POP  DE
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            PUSH BC
            PUSH DE
.if CompilerDiagnosticReturns
            PUSH HL
            LD   A,C
            CALL SemanticSinkPut
            POP  HL
.else
            LD   A,C
            CALL SemanticSinkPutPreserveHL
.endif
            POP  DE
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            PUSH DE
            LD   A,L
.if CompilerDiagnosticReturns
            PUSH HL
            CALL SemanticSinkPut
            POP  HL
.else
            CALL SemanticSinkPutPreserveHL
.endif
            POP  DE
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,D
            BIT  1,A
            JR   NZ,TypedEmitProgramDefinitionHigh
            OR   A
            RET
TypedEmitProgramDefinitionHigh:
            LD   A,H
            JP   SemanticSinkPut

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedParseConstantAfterName:
            CALL TypedRetainDeclarationName
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectEqual
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,TYEXACT
            CALL TypedExpressionBeginConstant
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL TypedRetainInferredConstantExpression
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(DCINFO)
            OR   SCCONST
            LD   D,A
            LD   BC,(DCPAY)
            CALL TypedPrepareCurrentWord
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   SymbolCommit

.routine in A,HL out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedRetainConstantExpression:
            LD   D,A
            LD   A,(DCINFO)
            LD   E,A
            LD   A,D
            CALL TypedCheckAssignable
.if CompilerDiagnosticReturns
            RET  C
.endif
            AND  MTCONST
            JP   Z,TypedTypeFailure
            LD   (DCPAY),HL
            JP   ParserExpectLine

.routine in A,HL out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedRetainInferredConstantExpression:
            LD   D,A
            AND  MTCONST
            JP   Z,TypedTypeFailure
            LD   A,D
            CALL TypedInferredConstantType
TypedRetainConstantTypeReady:
            LD   (DCINFO),A
            LD   (DCPAY),HL
            JP   ParserExpectLine

; Current token is the variable name.
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedParseProgramAfterVar:
            LD   A,(AGMODE)
            OR   A
            JP   NZ,AggregateParseProgramAfterVar
            CALL TypedRetainDeclarationName
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectAs
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL TypedParseType
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   (DCINFO),A
.if LegacyCompilerSlices
            ; Preserve the legacy initialized-array proof behind u8[...].
            CP   TYU8
            JR   NZ,TypedProgramScalar
            CALL PSPEEK
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TNLBRK
            JR   NZ,TypedProgramScalar
            LD   A,(NXPROG)
            LD   C,A
            LD   B,0
            LD   D,SIPU8
            CALL TypedPrepareCurrentWord
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   ParserParseArrayProgramAfterU8
.endif
TypedProgramScalar:
            CALL PSPEEK
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TNEQ
            JR   Z,TypedProgramExplicit
            LD   HL,0
            LD   A,(DCINFO)
            OR   MTCONST
            JR   TypedProgramHaveExpression
TypedProgramExplicit:
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(DCINFO)
            CALL TypedExpressionBeginConstant
.if CompilerDiagnosticReturns
            RET  C
.endif
TypedProgramHaveExpression:
            CALL TypedRetainConstantExpression
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(NXPROG)
            LD   C,A
            LD   B,0
            LD   (EXLVAL),BC
            PUSH BC
            LD   A,(DCINFO)
            OR   SCPROG
            LD   D,A
            CALL TypedPrepareCurrentWord
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL SymbolCommit
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   BC,(EXLVAL)
            LD   HL,(DCPAY)
            LD   A,(DCINFO)
            LD   D,A
            CALL TypedEmitProgramDefinition
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(DCINFO)
            CALL TypedTypeWidth
            LD   HL,NXPROG
            ADD  A,(HL)
            LD   (HL),A
            JP   TypedParseTopLevel

TypedParseTopLevel:
            CALL PSPEEK
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TOKENVAR
            JR   Z,TypedTopLevelVar
            CP   TNCONST
            JR   Z,TypedTopLevelConst
            CP   TNFWD
            JR   Z,TypedTopLevelForward
            CP   TOKENSUB
            JP   Z,TypedParseMain
            CP   TNREC
            JR   Z,TypedTopLevelRecord
            CALL DGINLINE
            .db  DXTOPLVL
TypedTopLevelVar:
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   E,TNNAME
            CALL PSEXPECT
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   TypedParseProgramAfterVar
TypedTopLevelConst:
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   E,TNNAME
            CALL PSEXPECT
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL TypedParseConstantAfterName
.if CompilerDiagnosticReturns
            RET  C
.endif
            JR   TypedParseTopLevel
TypedTopLevelForward:
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   TypedParseForwardAfterTake
TypedTopLevelRecord:
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   AggregateParseRecordAfterTake
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedParseTopLevelConstAfterTake:
            LD   E,TNNAME
            CALL PSEXPECT
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL TypedParseConstantAfterName
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   TypedParseTopLevel

; TokenForward has already been consumed. Nucleus 0.1 permits a bounded
; retained signature; this first Z80 increment supports one scalar
; parameter and one scalar result, with exact completion after main.
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedParseForwardAfterTake:
            LD   E,TOKENSUB
            CALL PSEXPECT
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   E,TNNAME
            CALL PSEXPECT
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(FWORD)
            OR   A
            JP   NZ,TypedDuplicateNameFailure
            CALL TypedRejectCurrentOrdinaryName
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserRetainForwardName
            CALL ParserExpectLeft
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   E,TNNAME
            CALL PSEXPECT
.if CompilerDiagnosticReturns
            RET  C
.endif
.if NativeStreamingSource
            LD   HL,FWNAMPTR
            CALL TKRECEQ
.else
            LD   HL,(FWNAMPTR)
            LD   A,(FWNAMLEN)
            LD   B,A
            CALL TKNAMEEQ
.endif
            JP   C,TypedDuplicateNameFailure
            CALL TypedRejectCurrentOrdinaryName
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserRetainForwardParameter
            CALL ParserExpectAs
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL TypedParseType
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   (FWPARTYP),A
            CALL ParserExpectRight
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectAs
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL TypedParseType
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   (FWRESTYP),A
            CALL ParserExpectLine
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,1
            LD   (FWORD),A
            XOR  A
            LD   (FWDONE),A
            JP   TypedParseTopLevel

TypedParseMain:
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
TypedParseMainAfterTake:
            CALL ParserExpectRoutineHeader
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,SMBGMAIN
            CALL SemanticSinkOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ControlReset
            LD   A,(SYCNT)
            LD   (CTGLBCNT),A
            XOR  A
            LD   (CRKIND),A
TypedParseLocals:
            CALL TypedParseLocalRun
.if CompilerDiagnosticReturns
            RET  C
.endif
TypedParseMainStatements:
            CALL TypedParseStatements
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   TypedParseEndMain

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedParseLocalDeclaration:
            LD   E,TNNAME
            CALL PSEXPECT
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL TypedRetainDeclarationName
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectAs
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL TypedParseType
.if CompilerDiagnosticReturns
            RET  C
.endif
            OR   SCLOC
            LD   (DCINFO),A
            LD   A,(NXLOCAL)
            LD   C,A
            LD   B,0
            LD   (DCPAY),BC
            PUSH BC
            LD   A,(DCINFO)
            LD   D,A
            CALL TypedPrepareCurrentWord
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(DCINFO)
            AND  MTTYPMSK
            CALL TypedEmitLocalDeclare
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL PSPEEK
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TNEQ
            JR   Z,TypedLocalExplicit
            LD   A,1
            LD   (EXEMITON),A
            LD   A,SMLIT16
            CALL TypedEmitOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,0
            CALL TypedEmitWord
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(DCINFO)
            AND  MTTYPMSK
            OR   MTCONST
            JR   TypedLocalHaveExpression
TypedLocalExplicit:
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(DCINFO)
            AND  MTTYPMSK
            CALL TypedExpressionBeginRuntime
.if CompilerDiagnosticReturns
            RET  C
.endif
TypedLocalHaveExpression:
            LD   D,A
            LD   A,(DCINFO)
            AND  MTTYPMSK
            LD   E,A
            LD   A,D
            CALL TypedCheckAssignable
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectLine
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(DCINFO)
            LD   D,A
            LD   A,(DCPAY)
            LD   C,A
            CALL TypedEmitStoreByInfo
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL SymbolCommit
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(DCINFO)
            AND  MTTYPMSK
            CALL TypedTypeWidth
            LD   HL,NXLOCAL
            ADD  A,(HL)
            LD   (HL),A
            OR   A
            RET

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedParseLocalRun:
            CALL PSPEEK
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TOKENVAR
            JR   Z,TypedParseLocalRunTake
            OR   A
            RET
TypedParseLocalRunTake:
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL TypedParseLocalDeclaration
.if CompilerDiagnosticReturns
            RET  C
.endif
            JR   TypedParseLocalRun
.endif

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedEmitLocalDeclare:
            BIT  1,A
            LD   A,SMDLCLU8
            JR   Z,TypedEmitLocalDeclareSelected
            LD   A,SMDECL16
TypedEmitLocalDeclareSelected:
            CALL SemanticSinkOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(NXLOCAL)
            JP   SemanticSinkPut

; D is symbol info and C its byte offset.
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedEmitStoreByInfo:
            LD   A,D
            AND  SCMSK
            RRCA
            RRCA
            JP   Z,TypedTypeFailure
            CP   SCPAR/4
            JR   Z,TypedStoreParameter
            ADD  A,SMSTPU8-1
            BIT  1,D
            JR   Z,TypedStoreSelected
            ADD  A,SMSTP16-SMSTPU8
            JR   TypedStoreSelected
TypedStoreParameter:
            LD   A,SMSTPAR8
            BIT  1,D
            JR   Z,TypedStoreSelected
            INC  A
TypedStoreSelected:
.if AggregateCallSlices
            BIT  3,D
            JP   Z,TypedEmitOperationBC
.endif
            JP   ParserEmitOperationC

.if HybridLL1Full
.else
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedParseStatements:
            LD   A,1
            LD   (CTFALLS),A
TypedParseStatementsContinue:
            CALL PSPEEK
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TOKENEND
            RET  Z
            CP   TNELSEIF
            RET  Z
            CP   TNELSE
            RET  Z
            CP   TNRET
            JR   Z,TypedStatementReturn
            LD   C,A
TypedStatementDispatch:
            LD   A,C
            CP   TOKENIF
            JR   Z,TypedStatementIf
            CP   TNWHILE
            JR   Z,TypedStatementWhile
            CP   TOKENFOR
            JR   Z,TypedStatementFor
            CP   TNEXIT
            JP   Z,TypedStatementTransfer
            CP   TNCONT
            JP   Z,TypedStatementTransfer
            CP   TNNAME
            JP   NZ,ParserExpectedScalar
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,KWWRTOUT
            LD   B,15
            CALL TKNAMEEQ
            JP   C,TypedParseWrite
.if AggregateCallSlices
            CALL Stage7FindRoutineCurrent
            JP   Z,Stage7ParseCallStatement
.endif
            CALL TypedParseAssignment
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   TypedParseStatementsContinue
TypedStatementIf:
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(CTFALLS)
            PUSH AF
            CALL StructuredParseIf
.if CompilerDiagnosticBranches
            JR   C,TypedStatementControlFailure
.endif
            LD   C,A
            POP  AF
            AND  C
            LD   (CTFALLS),A
            JP   TypedParseStatementsContinue
TypedStatementWhile:
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(CTFALLS)
            PUSH AF
            CALL StructuredParseWhile
            JR   TypedStatementLoopComplete
TypedStatementFor:
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(CTFALLS)
            PUSH AF
            CALL StructuredParseFor
TypedStatementLoopComplete:
.if CompilerDiagnosticBranches
            JR   C,TypedStatementControlFailure
.endif
            POP  AF
            LD   (CTFALLS),A
            JP   TypedParseStatementsContinue
.if CompilerDiagnosticBranches
TypedStatementControlFailure:
            POP  AF
            SCF
            RET
.endif
TypedStatementReturn:
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
.if AggregateCallSlices
            LD   A,(C7RESTYP)
            CP   AGDYNTYP
            JP   NC,Stage7ParseAggregateReturn
.endif
            LD   A,(CRKIND)
            CP   CRVAL
            JR   NZ,TypedRoutineFlowFailure
            LD   A,(CTRESTYP)
            CALL TypedExpressionBeginRuntime
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   D,A
            LD   A,(CTRESTYP)
            LD   E,A
            LD   A,D
            CALL TypedCheckAssignable
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectLine
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,SMRETSCA
            CALL SemanticSinkOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            XOR  A
            LD   (CTFALLS),A
            JP   TypedParseStatementsContinue
.endif
TypedRoutineFlowFailure:
            CALL DGINLINE
            .db  DGRTNFLW
.if HybridLL1Full
.else
TypedStatementTransfer:
            LD   (DCINFO),A
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(DCINFO)
            CALL StructuredParseLoopTransfer
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   TypedParseStatementsContinue
TypedParseWrite:
            LD   HL,(TNSTOFF)
            LD   (EXCALOFF),HL
            CALL ParserExpectLeft
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,TYU8
            CALL TypedExpressionBeginRuntime
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   E,TYU8
            CALL TypedCheckAssignable
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectRight
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,SMWRVU8
            CALL SemanticSinkOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,(EXCALOFF)
            LD   A,L
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
            LD   A,H
            CALL SemanticSinkPut
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectElseFailLine
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   TypedParseStatementsContinue

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedParseAssignment:
            CALL SymbolLookupCurrent
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   (DCINFO),A
            LD   (DCPAY),BC
            LD   D,A
.if AggregateCallSlices
            AND  SYAGGFLG
            JP   NZ,Stage7ParseAggregateAssignment
            LD   A,D
.endif
            AND  SYRECTYP+SYAGGFLG
            JP   NZ,TypedTypeFailure
            LD   A,D
            AND  SCMSK
            CP   SCLOC
            JR   NZ,TypedAssignmentCounterChecked
            CALL ControlCheckActiveCounter
.if CompilerDiagnosticReturns
            RET  C
.endif
TypedAssignmentCounterChecked:
            LD   A,D
            AND  SCMSK
            JP   Z,TypedTypeFailure
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
            LD   BC,(DCPAY)
            LD   A,(DCINFO)
            LD   D,A
            CALL TypedEmitStoreByInfo
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   ParserExpectLine

TypedParseEndMain:
            LD   E,TOKENEND
            CALL PSEXPECT
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectLine
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,SMENMAIN
            CALL SemanticSinkOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(FWORD)
            OR   A
            JR   NZ,TypedParseForwardCompletion
            LD   E,TOKENEOF
            JP   PSEXPECT

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedParseForwardCompletion:
            CALL PSPEEK
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TOKENSUB
            JP   NZ,TypedForwardIncomplete
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   D,DGFWDMIS
            CALL ParserExpectForwardName
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectLine
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(CTGLBCNT)
            LD   (SYCNT),A
            XOR  A
            LD   (NXLOCAL),A
            LD   HL,(FWPARPTR)
.if NativeStreamingSource
            CALL SAMATTOK
.else
            LD   (TNLEXPTR),HL
            LD   A,(FWPARLEN)
            LD   (TNLEN),A
.endif
            LD   A,(FWPARTYP)
            OR   SCPAR
            LD   D,A
            LD   BC,0
            CALL SymbolPrepareCurrentWord
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL SymbolCommit
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(FWPARTYP)
            CALL TypedTypeWidth
            LD   (NXLOCAL),A
            LD   A,CRVAL
            LD   (CRKIND),A
            LD   A,(FWRESTYP)
            LD   (CTRESTYP),A
            LD   A,1
            LD   (CTFALLS),A
            LD   A,SMBEGRTN
            CALL SemanticSinkOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(FWORD)
            CALL SemanticSinkPut
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(FWPARTYP)
            CALL SemanticSinkPut
.if CompilerDiagnosticReturns
            RET  C
.endif
TypedParseRoutineLocals:
            CALL TypedParseLocalRun
.if CompilerDiagnosticReturns
            RET  C
.endif
TypedParseRoutineStatements:
            CALL TypedParseStatements
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(CTFALLS)
            OR   A
            JP   NZ,TypedRoutineFlowFailure
            LD   E,TOKENEND
            CALL PSEXPECT
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectLine
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,SMENTRTN
            CALL SemanticSinkOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,1
            LD   (FWDONE),A
            LD   E,TOKENEOF
            JP   PSEXPECT
.endif
TypedForwardIncomplete:
            CALL DGINLINE
            .db  DGFWDINC

            .include "structured-control-parser.asm"
