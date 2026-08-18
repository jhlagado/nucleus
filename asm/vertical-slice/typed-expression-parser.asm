; Correctness-first typed scalar declarations and expressions.
;
; Expression results return metadata in A and, when constant, a value in HL.
; The low two metadata bits are ScalarType*, and ScalarMetaConstant marks an
; exact compile-time value. Runtime expressions are emitted as a checked
; postfix stream of 16-bit carriers; u8 and boolean carriers have a zero high
; byte. The declared type, not the carrier, controls width and compatibility.

.routine out A,B,HL,carry,zero clobbers sign,parity,halfCarry,C,DE
TypedMatchForwardName:
            LD   A,(ForwardOrdinal)
            OR   A
            RET  Z
            LD   HL,ForwardNamePointer
            JP   TokenNameRecordEquals

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
TypedNameEqualsMain:
            LD   HL,NameMain
            LD   B,4
            JP   TokenNameEquals

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedRetainDeclarationName:
            CALL TypedNameEqualsMain
            JR   C,TypedDuplicateNameFailure
            CALL TypedMatchForwardName
            JR   C,TypedDuplicateNameFailure
TypedRetainDeclarationNameReady:
            LD   HL,DeclarationNamePointer
            CALL TokenRetainNameAtHL
            LD   DE,DeclarationNamePosition
            CALL CompilerCopyTokenPosition
            OR   A
            RET

TypedDuplicateNameFailure:
            CALL SetDiagInline
            .db  DiagnosticDuplicateName

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
TypedRejectCurrentOrdinaryName:
            CALL SymbolFindCurrent
            JR   C,TypedDuplicateNameFailure
            CALL TypedNameEqualsMain
            JR   C,TypedDuplicateNameFailure
            OR   A
            RET

; Restore the retained declaration spelling as the current name token.
.routine out A,HL
TypedRestoreDeclarationToken:
            LD   HL,(DeclarationNamePointer)
            LD   (TokenLexemePointer),HL
            LD   A,(DeclarationNameLength)
            LD   (TokenLength),A
            RET

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedPrepareCurrentWord:
            CALL TypedRestoreDeclarationToken
            PUSH BC
            PUSH DE
            LD   HL,DeclarationNamePosition
            CALL CompilerRestoreTokenPosition
.if AggregateCallSlices
.if TargetStreamingOutput
.if DebugHooks
            OUT  (DebugTraceDeclarationPort),A
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
            LD   (ExpressionOperator),A
            XOR  A
            LD   (ParserLookaheadKind),A
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
            LD   HL,ExpressionStackBase
            ADD  HL,DE
            RET

TypedExpressionPush:
            LD   A,(ExpressionStackDepth)
            CP   ExpressionStackCapacity
            JR   NC,TypedExpressionStackFull
            CALL TypedExpressionAddress
            EX   DE,HL
            LD   HL,ExpressionSavedState
            LD   BC,ExpressionStackEntrySize
            LDIR
            LD   HL,ExpressionStackDepth
            INC  (HL)
            LD   A,(HL)
            OR   A
            RET

TypedExpressionStackFull:
            CALL SetDiagInline
            .db  DiagnosticExpressionCapacity

; Store A/HL as the pending left result before pushing it.
.routine in A,HL out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedSaveLeft:
.if AggregateCallSlices
            CALL TypedRequireComposable
.if CompilerDiagnosticReturns
            RET  C
.endif
.endif
            LD   (ExpressionLeftMeta),A
            LD   (ExpressionLeftValue),HL
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
            LD   (ExpressionRightMeta),A
            LD   (ExpressionRightValue),HL
            ; Every reduction follows TypedSaveLeft. Keep the defensive test so
            ; a future parser change cannot turn a broken invariant into a
            ; wrapped address beyond CompilerWorkspaceEnd.
            LD   HL,ExpressionStackDepth
            LD   A,(HL)
            OR   A
            JR   Z,TypedExpressionStackUnderflow
            DEC  A
            LD   (HL),A
            CALL TypedExpressionAddress
            LD   DE,ExpressionSavedState
            LD   BC,ExpressionSavedStateSize
            LDIR
            LD   (ExpressionLeftPositionPointer),HL
            OR   A
            RET
TypedExpressionStackUnderflow:
            CALL SetDiagInline
            .db  DiagnosticInternalOperation

TypedValueRangeFailure:
            LD   HL,ExpressionValuePosition
            JR   TypedRangeFailureAtPosition
TypedLeftRangeFailure:
            LD   HL,(ExpressionLeftPositionPointer)
TypedRangeFailureAtPosition:
            CALL CompilerRestoreTokenPosition
TypedRangeFailure:
            CALL SetDiagInline
            .db  DiagnosticIntegerRange
TypedTypeFailure:
            CALL SetDiagInline
            .db  DiagnosticTypeMismatch
TypedDivisionFailure:
            LD   B,C                     ; statically selected divide width
            LD   C,DiagnosticDivisionZero
            JR   TypedCheckedFault
TypedNarrowFailure:
            LD   B,ScalarTypeU8           ; u8(...) always has u8 result type
            LD   C,DiagnosticNarrowing
TypedCheckedFault:
            LD   A,(ExpressionSuppressFault)
            OR   A
            JR   NZ,TypedSuppressedFault
            LD   A,C
            JP   CompilerSetDiagnostic
TypedSuppressedFault:
            LD   A,B
            LD   HL,0
            OR   ScalarMetaConstant
            RET

; Resolve two integer operands. The four source metadata/value cells are live.
; C returns u8 or u16. Exact constants adopt the typed peer or expected type.
.routine out A,carry,zero clobbers sign,parity,halfCarry
TypedLeftTypeIsBoolean:
            LD   A,(ExpressionLeftMeta)
            AND  ScalarMetaTypeMask
            CP   ScalarTypeBoolean
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry
TypedDeclarationScalarType:
            LD   A,(DeclarationInfo)
            AND  ScalarMetaTypeMask
            RET

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedResolveIntegerPair:
            CALL TypedLeftTypeIsBoolean
            JR   Z,TypedTypeFailure
            LD   D,A
            LD   A,(ExpressionRightMeta)
            AND  ScalarMetaTypeMask
            CP   ScalarTypeBoolean
            JR   Z,TypedTypeFailure
            LD   E,A
            LD   A,D
            OR   A
            JR   NZ,TypedResolveLeftTyped
            LD   A,E
            OR   A
            JR   NZ,TypedResolveExactLeft
            LD   A,(ExpressionExpectedType)
            AND  ScalarMetaTypeMask
            CP   ScalarTypeBoolean
            JR   Z,TypedResolveBothExactDefault
            OR   A
            JR   NZ,TypedResolveBothExactSelected
TypedResolveBothExactDefault:
            LD   A,(ExpressionLeftMeta)
            LD   C,A
            LD   A,(ExpressionRightMeta)
            OR   C
            AND  ScalarMetaNegative
            RRCA
            OR   ScalarTypeU16
            LD   C,A
            JR   TypedResolveValidateBothExact
TypedResolveBothExactSelected:
            LD   C,A
TypedResolveValidateBothExact:
            LD   HL,(ExpressionLeftValue)
            LD   A,(ExpressionLeftMeta)
            CALL TypedConvertConstant
            JR   C,TypedLeftRangeFailure
            LD   HL,(ExpressionRightValue)
            LD   A,(ExpressionRightMeta)
            CALL TypedConvertConstant
            JP   C,TypedValueRangeFailure
            RET
TypedResolveExactLeft:
            LD   C,E
            LD   HL,(ExpressionLeftValue)
            LD   A,(ExpressionLeftMeta)
            CALL TypedConvertConstant
            JP   C,TypedLeftRangeFailure
TypedResolveDone:
            RET
TypedResolveLeftTyped:
            LD   A,E
            OR   A
            JR   NZ,TypedResolveBothTyped
            LD   C,D
            LD   HL,(ExpressionRightValue)
            LD   A,(ExpressionRightMeta)
            CALL TypedConvertConstant
            JP   C,TypedValueRangeFailure
            RET
TypedResolveBothTyped:
            LD   A,D
            CP   E
            JR   Z,TypedResolveUseLeftType
            CP   ScalarTypeU16
            JR   Z,TypedResolveU16CheckRight
            LD   A,E
            CP   ScalarTypeU16
            JR   NZ,TypedResolveI16
            LD   A,D
            JR   TypedResolveU16Check
TypedResolveI16:
            LD   A,D
            CP   ScalarTypeI8
            JR   Z,TypedResolveI16PromoteLeft
            LD   A,E
            CP   ScalarTypeI8
            JR   NZ,TypedResolveI16Ready ; u8 with i16 needs no carrier change
            LD   C,0                     ; promote the right carrier
            JR   TypedResolveI16Promote
TypedResolveI16PromoteLeft:
            LD   C,1                     ; promote the left carrier
TypedResolveI16Promote:
            LD   A,SemanticPromoteI8Pair
            CALL ParserEmitOperationC
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,C
            OR   A
            LD   HL,ExpressionRightValue
            JR   Z,TypedResolveI16PromoteConstant
            LD   HL,ExpressionLeftValue
TypedResolveI16PromoteConstant:
            LD   A,(HL)
            RLCA
            SBC  A,A
            INC  HL
            LD   (HL),A
TypedResolveI16Ready:
            LD   C,ScalarTypeI16
            OR   A
            RET
TypedResolveUseLeftType:
            LD   C,D
            OR   A
            RET
TypedResolveU16CheckRight:
            LD   A,E
TypedResolveU16Check:
            CP   ScalarTypeU8
            JP   NZ,TypedTypeFailure
TypedResolveU16:
            LD   C,ScalarTypeU16
            OR   A
            RET

.routine in A,D out A,D,carry,zero clobbers sign,parity,halfCarry
TypedRequireScalarSymbolClass:
            AND  SymbolRecordTypeFlag+SymbolAggregateFlag
            JP   NZ,TypedTypeFailure
            LD   A,D
            AND  SymbolClassMask
            RET

; Return constant in A when both operands are constant.
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedBothConstant:
            LD   A,(ExpressionLeftMeta)
            LD   HL,ExpressionRightMeta
            AND  (HL)
            AND  ScalarMetaConstant
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
            LD   HL,(ExpressionLeftValue)
            LD   DE,(ExpressionRightValue)
            RET

; Reduce +, -, *, /, integer and, or, xor. ExpressionOperator holds the token.
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedReduceIntegerBinary:
            CALL TypedResolveIntegerPair
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(ExpressionOperator)
            CP   TokenPlus
            JR   Z,TypedReduceAdd
            CP   TokenMinus
            JR   Z,TypedReduceSubtract
            CP   TokenStar
            JR   Z,TypedReduceMultiply
            CP   TokenSlash
            JP   Z,TypedReduceDivide
            CP   TokenMod
            JP   Z,TypedReduceModulo
            CP   TokenAnd
            JR   Z,TypedReduceAnd
            CP   TokenXor
            JR   Z,TypedReduceXor
TypedReduceOr:
            LD   D,SemanticOr8
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
            LD   D,SemanticXor8
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
            LD   D,SemanticAnd8
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
            JP   TypedReduceIntegerConstantDone
TypedReduceAdd:
            LD   D,SemanticAdd8
            CALL TypedPrepareConstantBinary
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   Z,TypedReduceIntegerMeta
            ADD  HL,DE
            JR   TypedReduceAddSubtractDone
TypedReduceSubtract:
            LD   D,SemanticSubtract8
            CALL TypedPrepareConstantBinary
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   Z,TypedReduceIntegerMeta
            OR   A
            SBC  HL,DE
TypedReduceAddSubtractDone:
            JP   TypedReduceIntegerConstantDone
TypedReduceMultiply:
            LD   D,SemanticMultiply8
            CALL TypedPrepareConstantBinary
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   Z,TypedReduceIntegerMeta
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
            JP   TypedReduceIntegerConstantDone
TypedReduceDivide:
            LD   D,SemanticDivide8
            JR   TypedReduceDivisionSelect
TypedReduceModulo:
            LD   D,SemanticModulo8
TypedReduceDivisionSelect:
            LD   A,C
            AND  ScalarTypeSignedFlag
            JR   Z,TypedReduceDivision
            LD   A,SemanticDivideSigned
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
            LD   A,(ExpressionOperator)
            CP   TokenMod
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
            LD   HL,(ExpressionOperatorOffset)
            CALL TypedEmitWord
.if CompilerDiagnosticReturns
            RET  C
.endif
            ; A divisor known to be zero is invalid even when the dividend is
            ; dynamic. The fault helper also implements constant short-circuit
            ; suppression, so the unevaluated Boolean arm remains admissible.
            LD   A,(ExpressionRightMeta)
            RLCA
            JR   NC,TypedReduceDivideFold
            LD   HL,(ExpressionRightValue)
            LD   A,H
            OR   L
            JP   Z,TypedDivisionFailure
TypedReduceDivideFold:
            CALL TypedBothConstant
            JR   Z,TypedReduceIntegerMeta
            ; The earlier exact-divisor check proves DE is nonzero here.
            ; Constant unsigned division uses a bounded subtraction loop.
            LD   DE,(ExpressionRightValue)
            LD   HL,(ExpressionLeftValue)
            PUSH BC
            LD   A,C
            AND  ScalarTypeSignedFlag
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
            LD   C,0
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
            LD   B,0
            PUSH BC
            JR   TypedReduceDivideCoreReady
TypedReduceDivideUnsignedReady:
            LD   BC,0
            PUSH BC
TypedReduceDivideCoreReady:
            LD   BC,0
TypedReduceDivideLoop:
            OR   A
            SBC  HL,DE
            JR   C,TypedReduceDivideDone
            INC  BC
            JR   TypedReduceDivideLoop
TypedReduceDivideDone:
            ADD  HL,DE
            POP  DE
            LD   A,(ExpressionOperator)
            CP   TokenMod
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
.routine in C,HL out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedReduceIntegerConstantDone:
TypedMaskResultWidth:
            BIT  1,C
            JR   NZ,TypedReduceIntegerConstantMeta
            LD   H,0
TypedReduceIntegerConstantMeta:
            LD   A,C
            OR   ScalarMetaConstant
            RET
TypedReduceIntegerMeta:
            LD   A,C
            OR   A
            RET

; Primary expressions.
TypedParsePrimary:
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            PUSH AF
            PUSH BC
            LD   DE,ExpressionValuePosition
            CALL CompilerCopyTokenPosition
            POP  BC
            POP  AF
            CP   TokenNumber
            JR   Z,TypedPrimaryNumber
            CP   TokenCharacter
            JR   Z,TypedPrimaryCharacter
            CP   TokenTrue
            JR   Z,TypedPrimaryTrue
            CP   TokenFalse
            JR   Z,TypedPrimaryFalse
            CP   TokenName
            JR   Z,TypedPrimaryName
            CP   TokenLeftParen
            JP   Z,TypedPrimaryParen
            CP   TokenU8
            JP   Z,TypedPrimaryNarrow
            CP   TokenU16
            JP   Z,TypedPrimaryWiden
            SUB  TokenI8
            CP   2
            JP   NC,ParserExpectedScalar
            ADD  A,ScalarTypeI8
            JP   TypedPrimaryConvertInteger
TypedPrimaryNumber:
            LD   H,B
            LD   L,C
            LD   B,ScalarMetaConstant+ScalarTypeExact
            JR   TypedPrimaryEmitTypedConstant
TypedPrimaryCharacter:
            LD   H,0
            LD   L,C
            JR   TypedPrimaryU8Constant
TypedPrimaryTrue:
            LD   HL,1
            JR   TypedPrimaryBooleanConstant
TypedPrimaryFalse:
            LD   HL,0
TypedPrimaryBooleanConstant:
            LD   B,ScalarMetaConstant+ScalarTypeBoolean
            JR   TypedPrimaryEmitTypedConstant
TypedPrimaryU8Constant:
            LD   B,ScalarMetaConstant+ScalarTypeU8
TypedPrimaryEmitTypedConstant:
            PUSH BC
            PUSH HL
            LD   A,SemanticLiteral16
            CALL TypedEmitOperation
            POP  HL
.if CompilerDiagnosticBranches
            JR   C,TypedPrimaryEmitTypedConstantFailure
.endif
            PUSH HL
            LD   A,(ExpressionExpectedType)
            CP   ScalarTypeI8
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
            CP   Stage8PredefinedConstantBase
            JP   NC,Stage8TypedPrimaryConstant
            LD   B,A
            AND  $FD                     ; readInput/readStorage map to zero
            JP   NZ,TypedTypeFailure
            LD   A,B
            JP   Stage8TypedPrimaryService
TypedPrimaryOrdinaryName:
            CALL Stage7FindRoutineCurrent
            JP   Z,Stage7TypedPrimaryRoutine
            CALL SymbolLookupCurrent
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   D,A
            AND  SymbolAggregateFlag
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
            AND  ScalarMetaTypeMask
            LD   E,A
            LD   A,D
            CALL TypedRequireScalarSymbolClass
.if CompilerDiagnosticReturns
            RET  C
.endif
            JR   Z,TypedPrimaryConstantName
            RRCA
            RRCA
            CP   SymbolClassParameter/4
            JR   Z,TypedPrimaryParameterName
            ADD  A,SemanticLoadProgramU8-1
            BIT  1,E
            JR   Z,TypedPrimaryProgramSelected
            ADD  A,SemanticLoadProgram16-SemanticLoadProgramU8
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
            LD   A,SemanticLoadParameter8
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
            LD   HL,(TokenStartOffset)
            PUSH HL
            CALL ParserExpectLeft
.if CompilerDiagnosticBranches
            JR   C,TypedPrimaryCallFailure
.endif
            LD   A,(ExpressionExpectedType)
            LD   B,A
            LD   A,(ForwardParameterType)
            LD   C,A
            PUSH BC
            LD   (ExpressionExpectedType),A
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
            LD   (ExpressionExpectedType),A
            LD   A,C
            LD   E,A
            LD   A,D
            CALL TypedCheckAssignable
.if CompilerDiagnosticBranches
            JR   C,TypedPrimaryCallFailure
.endif
            POP  HL
            PUSH HL
            LD   A,SemanticCallScalar
            CALL TypedEmitOperation
.if CompilerDiagnosticBranches
            JR   C,TypedPrimaryCallEmitFailure
.endif
            LD   A,(ForwardOrdinal)
            CALL TypedEmitByte
.if CompilerDiagnosticBranches
            JR   C,TypedPrimaryCallEmitFailure
.endif
            LD   A,(ForwardResultType)
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
            LD   A,(ForwardResultType)
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
            LD   (ExpressionExpectedType),A
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
            LD   A,(Stage8DirectFailable)
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

TypedPrimaryNarrow:
            LD   A,ScalarTypeU8
            JR   TypedPrimaryConvertInteger
TypedPrimaryWiden:
            LD   A,ScalarTypeU16
            JR   TypedPrimaryConvertInteger
TypedPrimaryConvertInteger:
            LD   C,A
            LD   HL,(TokenStartOffset)
            LD   (ExpressionOperatorOffset),HL
            PUSH AF                       ; destination type
            PUSH HL                       ; conversion trap position
            LD   A,C
            ; Parse the parenthesized operand under the conversion's expected
            ; type, then restore the enclosing expectation before continuing.
            LD   C,A
            LD   A,(ExpressionExpectedType)
            LD   B,A
            PUSH BC
            LD   A,C
            LD   (ExpressionExpectedType),A
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
            LD   (ExpressionExpectedType),A
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
            LD   (ExpressionExpectedType),A
            JR   TypedPrimaryConvertContextFailure
TypedPrimaryConversionReady:
.endif
            LD   D,A
            LD   B,H
            LD   C,L
            POP  HL
            LD   (ExpressionOperatorOffset),HL
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
            AND  ScalarMetaConstant
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
            AND  ScalarMetaTypeMask
            CP   C
            JR   Z,TypedPrimaryDynamicConvertDone
            CP   ScalarTypeU8
            JR   NZ,TypedPrimaryDynamicConvertEmit
            BIT  1,C
            JR   NZ,TypedPrimaryDynamicConvertDone
TypedPrimaryDynamicConvertEmit:
.if AggregateCallSlices
            LD   HL,(ExpressionOperatorOffset)
            CALL TypedEmitIntegerConversionOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
.else
            LD   A,SemanticNarrowU8
            CALL TypedEmitOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,(ExpressionOperatorOffset)
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
            LD   (ExpressionOperatorOffset),HL
            LD   A,SemanticConvertInteger
            PUSH BC
            PUSH DE
            CALL TypedEmitOperation
            POP  DE
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,D
            AND  ScalarMetaTypeMask
            CALL TypedEmitByte
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,C
            CALL TypedEmitByte
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,(ExpressionOperatorOffset)
            JP   TypedEmitWord

; Check and fold one explicit constant integer conversion. A is source
; metadata, C is the destination type, and HL is the source payload.
.routine in A,C,HL out A,C,D,HL,carry,zero clobbers sign,parity,halfCarry,B,E,IX,IY
TypedConvertConstant:
            LD   D,A
            AND  ScalarMetaTypeMask
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
            AND  ScalarMetaNegative
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
            AND  ScalarMetaTypeMask
            CP   ScalarTypeBoolean
            JP   Z,TypedTypeFailure
            AND  ScalarTypeBaseMask
            CP   3
            JP   NC,TypedTypeFailure
            LD   A,D
            OR   A
            RET

; Unary + and - bind above multiplicative operators.
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedParseUnary:
            CALL ParserPeek
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TokenPlus
            JR   Z,TypedUnaryPlus
            CP   TokenMinus
            JR   Z,TypedUnaryMinus
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
            JP   TypedRequireIntegerMeta
TypedUnaryMinus:
            CALL TypedUnaryPlus
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   D,A
            AND  ScalarMetaTypeMask
            JR   NZ,TypedUnaryMinusTyped
            LD   A,SemanticNegate16
            CALL TypedEmitUnaryOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,D
            AND  ScalarMetaNegative
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
            LD   A,ScalarMetaConstant+ScalarTypeExact
            RET  Z
            OR   ScalarMetaNegative
            RET
TypedUnaryMinusExactWasNegative:
            CALL TypedNegateConstantHL
            LD   A,ScalarMetaConstant+ScalarTypeExact
            OR   A
            RET
TypedUnaryMinusTyped:
            LD   A,D
            AND  ScalarMetaTypeMask
TypedUnaryMinusResolved:
            LD   C,A
            AND  2
            RRCA
            ADD  A,SemanticNegate8
TypedUnaryMinusEmit:
            CALL TypedEmitUnaryOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,D
            AND  ScalarMetaConstant
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
.routine in HL out A,HL,carry,zero clobbers sign,parity,halfCarry
TypedNegateConstantHL:
            XOR  A
            SUB  L
            LD   L,A
            LD   A,0
            SBC  A,H
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
            CALL ParserPeek
.if CompilerDiagnosticBranches
            JR   C,TypedMultiplicativePeekFailure
.endif
            CP   TokenStar
            JR   Z,TypedMultiplicativeOperator
            CP   TokenSlash
            JR   Z,TypedMultiplicativeOperator
            CP   TokenMod
            JR   NZ,TypedMultiplicativeDone
TypedMultiplicativeOperator:
            CALL TypedTakeOperator
.if CompilerDiagnosticBranches
            JR   C,TypedMultiplicativePeekFailure
.endif
            LD   HL,(TokenStartOffset)
            LD   (ExpressionOperatorOffset),HL
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
            CALL ParserPeek
.if CompilerDiagnosticBranches
            JR   C,TypedAdditivePeekFailure
.endif
            CP   TokenPlus
            JR   Z,TypedAdditiveOperator
            CP   TokenMinus
            JR   NZ,TypedAdditiveDone
TypedAdditiveOperator:
            CALL TypedTakeOperator
.if CompilerDiagnosticBranches
            JR   C,TypedAdditivePeekFailure
.endif
            POP  AF
            CALL TypedSaveLeft
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
            LD   C,ComparisonEqual
            CP   TokenEquals
            SCF
            RET  Z
            SUB  TokenLess
            CP   TokenNotEqual-TokenLess+1
            RET  NC
            INC  A
            INC  A
            CP   ComparisonGreaterEqual+1
            JR   NZ,TypedComparisonTokenSelected
            LD   A,ComparisonNotEqual
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
            CALL ParserPeek
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
            CALL ParserPeek
.if CompilerDiagnosticBranches
            JR   C,TypedComparisonStackFailure
.endif
            CALL TypedComparisonToken
            JR   C,TypedComparisonChained
            POP  HL
            POP  AF
            RET
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
            CALL SetDiagInline
            .db  DiagnosticComparisonChain
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedReduceComparison:
            LD   A,(ExpressionLeftMeta)
            AND  ScalarMetaTypeMask
            LD   D,A
            LD   A,(ExpressionRightMeta)
            AND  ScalarMetaTypeMask
            LD   E,A
            LD   A,D
            CP   ScalarTypeBoolean
            JR   NZ,TypedComparisonInteger
            LD   A,E
            CP   ScalarTypeBoolean
            JP   NZ,TypedTypeFailure
            LD   A,(ExpressionOperator)
            CP   ComparisonNotEqual+1
            JP   NC,TypedTypeFailure
            LD   D,0
            LD   A,SemanticCompareBoolean
            JR   TypedComparisonEmit
TypedComparisonInteger:
            CALL TypedResolveIntegerPair
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,C
            LD   D,A
            AND  ScalarTypeSignedFlag
            JR   NZ,TypedComparisonSigned
            LD   A,D
            LD   D,0
            AND  2
            RRCA
            ADD  A,SemanticCompare8
            JR   TypedComparisonEmit
TypedComparisonSigned:
            BIT  1,D
            LD   D,$80                    ; signed word selector flag
            JR   NZ,TypedComparisonSignedReady
            LD   D,$C0                    ; signed byte selector flag
TypedComparisonSignedReady:
            LD   A,SemanticCompare16
TypedComparisonEmit:
            PUSH DE
            CALL TypedEmitOperation
            POP  DE
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(ExpressionOperator)
            OR   D
            CALL TypedEmitByte
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL TypedBothConstant
            LD   A,ScalarTypeBoolean
            RET  Z
            LD   HL,(ExpressionLeftValue)
            LD   DE,(ExpressionRightValue)
            LD   A,C
            AND  ScalarTypeSignedFlag
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
            OR   A
            SBC  HL,DE
            ; Classify the relation as equal/less/greater (0/1/2), then use
            ; the dense comparison ordinal to select one Boolean table cell.
            ; The table contains language truth values, never code addresses.
            LD   D,0
            JR   Z,TypedComparisonRelationReady
            INC  D
            JR   C,TypedComparisonRelationReady
            INC  D
TypedComparisonRelationReady:
            LD   A,(ExpressionOperator)
            LD   E,A
            ADD  A,A
            ADD  A,E
            ADD  A,D
            LD   E,A
            LD   D,0
            LD   HL,TypedComparisonResults
            ADD  HL,DE
            LD   L,(HL)
            LD   H,0
TypedComparisonConstantDone:
            LD   A,ScalarMetaConstant+ScalarTypeBoolean
            OR   A
            RET

; `not` binds below comparisons and above `and`.
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedParseNot:
            CALL ParserPeek
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TokenNot
            JP   NZ,TypedParseComparison
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL TypedParseNot
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
            AND  ScalarMetaTypeMask
            LD   C,A
            CP   ScalarTypeBoolean
            LD   A,SemanticNotBoolean
            JR   Z,TypedNotEmit
            LD   A,C
            OR   A
            JR   NZ,TypedNotTypedInteger
            LD   A,(ExpressionExpectedType)
            CP   ScalarTypeU8
            JR   Z,TypedNotExactU8
            LD   C,ScalarTypeU16
            LD   A,SemanticNot16
            JR   TypedNotEmit
TypedNotExactU8:
            ; As with unary minus, validate the exact operand before applying
            ; the width-specific complement and masking the result.
            LD   A,D
            AND  ScalarMetaConstant
            JR   Z,TypedNotExactU8Ready
            LD   A,H
            OR   A
            JP   NZ,TypedValueRangeFailure
TypedNotExactU8Ready:
            LD   C,ScalarTypeU8
            LD   A,SemanticNot8
            JR   TypedNotEmit
TypedNotTypedInteger:
            CP   ScalarTypeU8
            LD   A,SemanticNot16
            JR   NZ,TypedNotEmit
            DEC  A
TypedNotEmit:
            CALL TypedEmitUnaryOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,D
            AND  ScalarMetaConstant
            LD   A,C
            RET  Z
            CP   ScalarTypeBoolean
            JR   NZ,TypedNotIntegerConstant
            LD   A,L
            XOR  1
            LD   L,A
            LD   H,0
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
            CALL TypedParseNot
.if CompilerDiagnosticReturns
            RET  C
.endif
TypedAndLoop:
            PUSH AF
            CALL ParserPeek
.if CompilerDiagnosticBranches
            JP   C,TypedBooleanPeekFailure
.endif
            CP   TokenAnd
            JP   NZ,TypedBooleanDone
            CALL TypedTakeOperator
.if CompilerDiagnosticBranches
            JP   C,TypedBooleanPeekFailure
.endif
            POP  AF
            CALL TypedSaveLeft
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL TypedLeftTypeIsBoolean
            JR   NZ,TypedAndParseRight
            LD   A,SemanticBeginBooleanAnd
            CALL TypedEmitOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   C,0
            CALL TypedBeginSuppression
TypedAndParseRight:
            CALL TypedParseNot
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
            CALL ParserPeek
.if CompilerDiagnosticBranches
            JR   C,TypedBooleanPeekFailure
.endif
            CP   TokenXor
            JR   Z,TypedOrOperator
            CP   TokenOr
            JR   NZ,TypedBooleanDone
.if AggregateCallSlices
            LD   A,(Stage8DirectFailable)
            OR   A
            JR   NZ,TypedOrFailureContext
            LD   A,TokenOr
.endif
TypedOrOperator:
            CALL TypedTakeOperator
.if CompilerDiagnosticBranches
            JR   C,TypedBooleanPeekFailure
.endif
            POP  AF
            CALL TypedSaveLeft
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(ExpressionOperator)
            CP   TokenXor
            JR   NZ,TypedOrBooleanLeft
            CALL TypedLeftTypeIsBoolean
            JP   Z,TypedTypeFailure
            JR   TypedOrParseRight
TypedOrBooleanLeft:
            CALL TypedLeftTypeIsBoolean
            JR   NZ,TypedOrParseRight
            LD   A,SemanticBeginBooleanOr
            CALL TypedEmitOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   C,1
            CALL TypedBeginSuppression
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
TypedBeginSuppression:
            LD   A,(ExpressionLeftMeta)
            RLCA
            RET  NC
            LD   A,(ExpressionLeftValue)
            XOR  C
            RET  NZ
            LD   HL,ExpressionSuppressFault
            INC  (HL)
            RET
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedReduceBoolean:
            LD   A,(ExpressionRightMeta)
            AND  ScalarMetaTypeMask
            CP   ScalarTypeBoolean
            JP   NZ,TypedTypeFailure
            LD   A,SemanticEndBoolean
            CALL TypedEmitOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL TypedBothConstant
            LD   A,ScalarTypeBoolean
            RET  Z
            LD   HL,ExpressionRightValue
            LD   A,(ExpressionOperator)
            CP   TokenAnd
            LD   A,(ExpressionLeftValue)
            JR   Z,TypedBooleanConstantAnd
            OR   (HL)
            JR   TypedBooleanConstantReady
TypedBooleanConstantAnd:
            AND  (HL)
TypedBooleanConstantReady:
            LD   L,A
            LD   H,0
TypedBooleanConstant:
            JP   TypedComparisonConstantDone

; Assignment compatibility resolves exact constants and the value-preserving
; unsigned/signed widening family. A/HL is the expression; E is destination.
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedCheckAssignable:
            LD   D,A
            AND  ScalarMetaTypeMask
            JR   NZ,TypedAssignableTyped
            LD   A,E
            CP   ScalarTypeBoolean
            JP   Z,TypedTypeFailure
            LD   C,E
            LD   A,D
            CALL TypedConvertConstant
            JP   C,TypedValueRangeFailure
            LD   A,D
            AND  ScalarMetaConstant
            OR   C
            RET
TypedAssignableTyped:
            CP   E
            JR   Z,TypedAssignableSame
            CP   ScalarTypeU8
            JR   Z,TypedAssignableFromU8
            CP   ScalarTypeI8
            JP   NZ,TypedTypeFailure
            LD   A,E
            CP   ScalarTypeI16
            JP   NZ,TypedTypeFailure
            LD   C,ScalarTypeI16
            LD   HL,(ExpressionValuePosition)
            PUSH DE
            CALL TypedEmitIntegerConversionOperation
            POP  DE
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,D
            AND  ScalarMetaConstant
            JR   Z,TypedAssignableSame
            BIT  7,L
            JR   Z,TypedAssignableSame
            LD   H,$FF
            JR   TypedAssignableSame
TypedAssignableFromU8:
            LD   A,E
            CP   ScalarTypeU16
            JR   Z,TypedAssignableSame
            CP   ScalarTypeI16
            JP   NZ,TypedTypeFailure
TypedAssignableSame:
            LD   A,D
            AND  ScalarMetaConstant
            OR   E
            RET

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedExpressionBeginRuntime:
            LD   (ExpressionExpectedType),A
.if AggregateCallSlices
            XOR  A
            LD   (Stage8DirectFailable),A
            LD   (Stage8RetainedCarriers),A
            INC  A
.else
            LD   A,1
.endif
            JR   TypedExpressionBeginReset
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedExpressionBeginConstant:
            LD   (ExpressionExpectedType),A
            XOR  A
.routine in A out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedExpressionBeginReset:
            LD   (ExpressionEmitEnabled),A
            XOR  A
            LD   (ExpressionSuppressFault),A
            LD   (ExpressionStackDepth),A
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
            CP   TokenU8
            JR   Z,TypedTypeU8
            CP   TokenU16
            JR   Z,TypedTypeU16
            CP   TokenI8
            JR   Z,TypedTypeI8
            CP   TokenI16
            JR   Z,TypedTypeI16
            CP   TokenBoolean
            JR   Z,TypedTypeBoolean
            CALL SetDiagInline
            .db  DiagnosticExpectedType
TypedTypeU8:       LD A,ScalarTypeU8
                   OR A
                   RET
TypedTypeU16:      LD A,ScalarTypeU16
                   OR A
                   RET
TypedTypeI8:       LD A,ScalarTypeI8
                   OR A
                   RET
TypedTypeI16:      LD A,ScalarTypeI16
                   OR A
                   RET
TypedTypeBoolean:  LD A,ScalarTypeBoolean
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
            AND  ScalarMetaTypeMask
            CP   ScalarTypeBoolean
            RET  Z
            CP   ScalarTypeI8
            JR   Z,TypedInferredConstantI8
            CP   ScalarTypeI16
            JR   Z,TypedInferredConstantI16
            LD   A,D
            AND  ScalarMetaNegative
            RET
TypedInferredConstantI8:
            BIT  7,L
            JR   TypedInferredConstantSign
TypedInferredConstantI16:
            BIT  7,H
TypedInferredConstantSign:
            LD   A,ScalarMetaNegative
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
            LD   A,SemanticDefineProgramU8
            JR   Z,TypedEmitProgramDefinitionOp
            LD   A,SemanticDefineProgram16
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
            LD   A,ScalarTypeExact
            CALL TypedExpressionBeginConstant
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL TypedRetainInferredConstantExpression
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(DeclarationInfo)
            OR   SymbolClassConstant
            LD   D,A
            LD   BC,(DeclarationPayload)
            CALL TypedPrepareCurrentWord
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   SymbolCommit

.routine in A,HL out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedRetainConstantExpression:
            LD   D,A
            LD   A,(DeclarationInfo)
            LD   E,A
            LD   A,D
            CALL TypedCheckAssignable
.if CompilerDiagnosticReturns
            RET  C
.endif
            AND  ScalarMetaConstant
            JP   Z,TypedTypeFailure
            LD   (DeclarationPayload),HL
            JP   ParserExpectLine

.routine in A,HL out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedRetainInferredConstantExpression:
            LD   D,A
            AND  ScalarMetaConstant
            JP   Z,TypedTypeFailure
            LD   A,D
            CALL TypedInferredConstantType
TypedRetainConstantTypeReady:
            LD   (DeclarationInfo),A
            LD   (DeclarationPayload),HL
            JP   ParserExpectLine

; Current token is the variable name.
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedParseProgramAfterVar:
            LD   A,(AggregateMode)
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
            LD   (DeclarationInfo),A
.if LegacyCompilerSlices
            ; Preserve the legacy initialized-array proof behind u8[...].
            CP   ScalarTypeU8
            JR   NZ,TypedProgramScalar
            CALL ParserPeek
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TokenLeftBracket
            JR   NZ,TypedProgramScalar
            LD   A,(NextProgramSlot)
            LD   C,A
            LD   B,0
            LD   D,SymbolInfoProgramU8
            CALL TypedPrepareCurrentWord
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   ParserParseArrayProgramAfterU8
.endif
TypedProgramScalar:
            CALL ParserPeek
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TokenEquals
            JR   Z,TypedProgramExplicit
            LD   HL,0
            LD   A,(DeclarationInfo)
            OR   ScalarMetaConstant
            JR   TypedProgramHaveExpression
TypedProgramExplicit:
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(DeclarationInfo)
            CALL TypedExpressionBeginConstant
.if CompilerDiagnosticReturns
            RET  C
.endif
TypedProgramHaveExpression:
            CALL TypedRetainConstantExpression
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(NextProgramSlot)
            LD   C,A
            LD   B,0
            LD   (ExpressionLeftValue),BC
            PUSH BC
            LD   A,(DeclarationInfo)
            OR   SymbolClassProgram
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
            LD   BC,(ExpressionLeftValue)
            LD   HL,(DeclarationPayload)
            LD   A,(DeclarationInfo)
            LD   D,A
            CALL TypedEmitProgramDefinition
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(DeclarationInfo)
            CALL TypedTypeWidth
            LD   HL,NextProgramSlot
            ADD  A,(HL)
            LD   (HL),A
            JP   TypedParseTopLevel

TypedParseTopLevel:
            CALL ParserPeek
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TokenVar
            JR   Z,TypedTopLevelVar
            CP   TokenConst
            JR   Z,TypedTopLevelConst
            CP   TokenForward
            JR   Z,TypedTopLevelForward
            CP   TokenSub
            JP   Z,TypedParseMain
            CP   TokenRecord
            JR   Z,TypedTopLevelRecord
            CALL SetDiagInline
            .db  DiagnosticExpectedTopLevel
TypedTopLevelVar:
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   E,TokenName
            CALL ParserExpect
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   TypedParseProgramAfterVar
TypedTopLevelConst:
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   E,TokenName
            CALL ParserExpect
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
            LD   E,TokenName
            CALL ParserExpect
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
            LD   E,TokenSub
            CALL ParserExpect
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   E,TokenName
            CALL ParserExpect
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(ForwardOrdinal)
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
            LD   E,TokenName
            CALL ParserExpect
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,(ForwardNamePointer)
            LD   A,(ForwardNameLength)
            LD   B,A
            CALL TokenNameEquals
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
            LD   (ForwardParameterType),A
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
            LD   (ForwardResultType),A
            CALL ParserExpectLine
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,1
            LD   (ForwardOrdinal),A
            XOR  A
            LD   (ForwardCompleted),A
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
            LD   A,SemanticBeginMain
            CALL SemanticSinkOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ControlReset
            LD   A,(SymbolCount)
            LD   (ControlGlobalSymbolCount),A
            XOR  A
            LD   (ControlRoutineKind),A
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
            LD   E,TokenName
            CALL ParserExpect
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
            OR   SymbolClassLocal
            LD   (DeclarationInfo),A
            LD   A,(NextLocalSlot)
            LD   C,A
            LD   B,0
            LD   (DeclarationPayload),BC
            PUSH BC
            LD   A,(DeclarationInfo)
            LD   D,A
            CALL TypedPrepareCurrentWord
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(DeclarationInfo)
            AND  ScalarMetaTypeMask
            CALL TypedEmitLocalDeclare
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserPeek
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TokenEquals
            JR   Z,TypedLocalExplicit
            LD   A,1
            LD   (ExpressionEmitEnabled),A
            LD   A,SemanticLiteral16
            CALL TypedEmitOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,0
            CALL TypedEmitWord
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(DeclarationInfo)
            AND  ScalarMetaTypeMask
            OR   ScalarMetaConstant
            JR   TypedLocalHaveExpression
TypedLocalExplicit:
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(DeclarationInfo)
            AND  ScalarMetaTypeMask
            CALL TypedExpressionBeginRuntime
.if CompilerDiagnosticReturns
            RET  C
.endif
TypedLocalHaveExpression:
            LD   D,A
            LD   A,(DeclarationInfo)
            AND  ScalarMetaTypeMask
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
            LD   A,(DeclarationInfo)
            LD   D,A
            LD   A,(DeclarationPayload)
            LD   C,A
            CALL TypedEmitStoreByInfo
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL SymbolCommit
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(DeclarationInfo)
            AND  ScalarMetaTypeMask
            CALL TypedTypeWidth
            LD   HL,NextLocalSlot
            ADD  A,(HL)
            LD   (HL),A
            OR   A
            RET

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedParseLocalRun:
            CALL ParserPeek
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TokenVar
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
            LD   A,SemanticDeclareLocalU8
            JR   Z,TypedEmitLocalDeclareSelected
            LD   A,SemanticDeclareLocal16
TypedEmitLocalDeclareSelected:
            CALL SemanticSinkOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(NextLocalSlot)
            JP   SemanticSinkPut

; D is symbol info and C its byte offset.
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedEmitStoreByInfo:
            LD   A,D
            AND  SymbolClassMask
            RRCA
            RRCA
            JP   Z,TypedTypeFailure
            CP   SymbolClassParameter/4
            JR   Z,TypedStoreParameter
            ADD  A,SemanticStoreProgramU8-1
            BIT  1,D
            JR   Z,TypedStoreSelected
            ADD  A,SemanticStoreProgram16-SemanticStoreProgramU8
            JR   TypedStoreSelected
TypedStoreParameter:
            LD   A,SemanticStoreParameter8
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
            LD   (ControlSequenceFallsThrough),A
TypedParseStatementsContinue:
            CALL ParserPeek
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TokenEnd
            RET  Z
            CP   TokenElseIf
            RET  Z
            CP   TokenElse
            RET  Z
            CP   TokenReturn
            JR   Z,TypedStatementReturn
            LD   C,A
TypedStatementDispatch:
            LD   A,C
            CP   TokenIf
            JR   Z,TypedStatementIf
            CP   TokenWhile
            JR   Z,TypedStatementWhile
            CP   TokenFor
            JR   Z,TypedStatementFor
            CP   TokenExit
            JP   Z,TypedStatementTransfer
            CP   TokenContinue
            JP   Z,TypedStatementTransfer
            CP   TokenName
            JP   NZ,ParserExpectedScalar
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,NameWriteOutputByte
            LD   B,15
            CALL TokenNameEquals
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
            LD   A,(ControlSequenceFallsThrough)
            PUSH AF
            CALL StructuredParseIf
.if CompilerDiagnosticBranches
            JR   C,TypedStatementControlFailure
.endif
            LD   C,A
            POP  AF
            AND  C
            LD   (ControlSequenceFallsThrough),A
            JP   TypedParseStatementsContinue
TypedStatementWhile:
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(ControlSequenceFallsThrough)
            PUSH AF
            CALL StructuredParseWhile
            JR   TypedStatementLoopComplete
TypedStatementFor:
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(ControlSequenceFallsThrough)
            PUSH AF
            CALL StructuredParseFor
TypedStatementLoopComplete:
.if CompilerDiagnosticBranches
            JR   C,TypedStatementControlFailure
.endif
            POP  AF
            LD   (ControlSequenceFallsThrough),A
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
            LD   A,(Stage7CurrentResultType)
            CP   AggregateFirstDynamicTypeId
            JP   NC,Stage7ParseAggregateReturn
.endif
            LD   A,(ControlRoutineKind)
            CP   ControlRoutineValue
            JR   NZ,TypedRoutineFlowFailure
            LD   A,(ControlResultType)
            CALL TypedExpressionBeginRuntime
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   D,A
            LD   A,(ControlResultType)
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
            LD   A,SemanticReturnScalar
            CALL SemanticSinkOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            XOR  A
            LD   (ControlSequenceFallsThrough),A
            JP   TypedParseStatementsContinue
.endif
TypedRoutineFlowFailure:
            CALL SetDiagInline
            .db  DiagnosticRoutineFlow
.if HybridLL1Full
.else
TypedStatementTransfer:
            LD   (DeclarationInfo),A
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(DeclarationInfo)
            CALL StructuredParseLoopTransfer
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   TypedParseStatementsContinue
TypedParseWrite:
            LD   HL,(TokenStartOffset)
            LD   (ExpressionCallOffset),HL
            CALL ParserExpectLeft
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,ScalarTypeU8
            CALL TypedExpressionBeginRuntime
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   E,ScalarTypeU8
            CALL TypedCheckAssignable
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectRight
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,SemanticWriteValueU8
            CALL SemanticSinkOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,(ExpressionCallOffset)
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
            LD   (DeclarationInfo),A
            LD   (DeclarationPayload),BC
            LD   D,A
.if AggregateCallSlices
            AND  SymbolAggregateFlag
            JP   NZ,Stage7ParseAggregateAssignment
            LD   A,D
.endif
            AND  SymbolRecordTypeFlag+SymbolAggregateFlag
            JP   NZ,TypedTypeFailure
            LD   A,D
            AND  SymbolClassMask
            CP   SymbolClassLocal
            JR   NZ,TypedAssignmentCounterChecked
            CALL ControlCheckActiveCounter
.if CompilerDiagnosticReturns
            RET  C
.endif
TypedAssignmentCounterChecked:
            LD   A,D
            AND  SymbolClassMask
            JP   Z,TypedTypeFailure
            CALL ParserExpectEqual
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(DeclarationInfo)
            AND  ScalarMetaTypeMask
            CALL TypedExpressionBeginRuntime
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   D,A
            LD   A,(DeclarationInfo)
            AND  ScalarMetaTypeMask
            LD   E,A
            LD   A,D
            CALL TypedCheckAssignable
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   BC,(DeclarationPayload)
            LD   A,(DeclarationInfo)
            LD   D,A
            CALL TypedEmitStoreByInfo
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   ParserExpectLine

TypedParseEndMain:
            LD   E,TokenEnd
            CALL ParserExpect
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectLine
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,SemanticEndMain
            CALL SemanticSinkOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(ForwardOrdinal)
            OR   A
            JR   NZ,TypedParseForwardCompletion
            LD   E,TokenEof
            JP   ParserExpect

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TypedParseForwardCompletion:
            CALL ParserPeek
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TokenSub
            JP   NZ,TypedForwardIncomplete
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   D,DiagnosticForwardMismatch
            CALL ParserExpectForwardName
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectLine
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(ControlGlobalSymbolCount)
            LD   (SymbolCount),A
            XOR  A
            LD   (NextLocalSlot),A
            LD   HL,(ForwardParameterPointer)
            LD   (TokenLexemePointer),HL
            LD   A,(ForwardParameterLength)
            LD   (TokenLength),A
            LD   A,(ForwardParameterType)
            OR   SymbolClassParameter
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
            LD   A,(ForwardParameterType)
            CALL TypedTypeWidth
            LD   (NextLocalSlot),A
            LD   A,ControlRoutineValue
            LD   (ControlRoutineKind),A
            LD   A,(ForwardResultType)
            LD   (ControlResultType),A
            LD   A,1
            LD   (ControlSequenceFallsThrough),A
            LD   A,SemanticBeginRoutine
            CALL SemanticSinkOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(ForwardOrdinal)
            CALL SemanticSinkPut
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(ForwardParameterType)
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
            LD   A,(ControlSequenceFallsThrough)
            OR   A
            JP   NZ,TypedRoutineFlowFailure
            LD   E,TokenEnd
            CALL ParserExpect
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectLine
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,SemanticEndTypedRoutine
            CALL SemanticSinkOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,1
            LD   (ForwardCompleted),A
            LD   E,TokenEof
            JP   ParserExpect
.endif
TypedForwardIncomplete:
            CALL SetDiagInline
            .db  DiagnosticForwardIncomplete

            .include "structured-control-parser.asm"
