; R3 constant mode of the replacement precedence-climbing expression engine.
;
; A result is A=RewriteScalarType* (or exact plus RewriteTypeMetaNegative),
; HL=value, DE=source byte offset. The engine is deliberately independent of
; compiler origin and retains complete word values and positions. Runtime
; emission will reuse the parser and type resolution in R4.

; Carry returns B=dense operator and C=precedence for token A.
.routine in A out A,B,C,carry,zero clobbers sign,parity,halfCarry,D,DE,HL
RewriteExpressionFindOperator:
            LD   E,A
            LD   HL,RewriteExpressionOperatorTable
            LD   B,RewriteExpressionOperatorCount
            LD   C,0
_RewriteExpressionFindOperatorLoop:
            LD   A,(HL)
            CP   E
            JR   Z,_RewriteExpressionFindOperatorFound
            INC  HL
            INC  HL
            INC  C
            DJNZ _RewriteExpressionFindOperatorLoop
            OR   A
            RET
_RewriteExpressionFindOperatorFound:
            INC  HL
            LD   B,C
            LD   C,(HL)
            SCF
            RET

; A is the expected type, or exact/zero when the surrounding context supplies
; none. The caller decides whether the completed result is assignable.
.routine in A out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B,C
RewriteExpressionEvaluateConstant:
            LD   (RewriteExpressionExpectedType),A
            XOR  A
            LD   (RewriteExpressionDepth),A
            LD   (RewriteExpressionSuppressFault),A
            LD   B,A
            LD   C,A
            CALL RewriteExpressionParsePrecedence
            RET

; B is the comparison-used flag for this recursive level and C is the minimum
; admitted binary precedence. The two-byte local preserves both through calls.
.routine in B,C out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B,C
RewriteExpressionParsePrecedence:
            PUSH IX
            LD   IX,0
            ADD  IX,SP
            PUSH BC
            CALL RewriteExpressionParsePrefix
            OR   A
_RewriteExpressionPrecedenceLoop:
            PUSH DE
            PUSH HL
            PUSH AF
            CALL RewriteParserPeek
            CALL RewriteExpressionFindOperator
            JP   NC,_RewriteExpressionPrecedenceDoneSaved
            LD   A,C
            CP   (IX-2)
            JP   C,_RewriteExpressionPrecedenceDoneSaved
            LD   A,B
            CP   RewriteExpressionOpEqual
            JR   C,_RewriteExpressionComparisonReady
            CP   RewriteExpressionOpAnd
            JR   NC,_RewriteExpressionComparisonReady
            LD   A,(IX-1)
            OR   A
            JP   NZ,_RewriteExpressionComparisonFailure
            INC  (IX-1)
_RewriteExpressionComparisonReady:
            POP  AF
            POP  HL
            POP  DE
            LD   (RewriteExpressionLeftMeta),A
            LD   (RewriteExpressionLeftValue),HL
            LD   (RewriteExpressionLeftOffset),DE
            ; Mark a statically skipped Boolean arm in precedence bit seven.
            ; The suppress counter is recursive, so nested short circuits are
            ; restored without a second expression-state stack.
            LD   A,(RewriteExpressionLeftMeta)
            AND  RewriteTypeIdentityMask
            CP   RewriteScalarTypeBoolean
            JR   NZ,_RewriteExpressionNoShortCircuit
            LD   A,B
            CP   RewriteExpressionOpAnd
            JR   Z,_RewriteExpressionShortCircuitAnd
            CP   RewriteExpressionOpOr
            JR   NZ,_RewriteExpressionNoShortCircuit
            LD   A,(RewriteExpressionLeftValue)
            OR   A
            JR   Z,_RewriteExpressionNoShortCircuit
            JR   _RewriteExpressionBeginShortCircuit
_RewriteExpressionShortCircuitAnd:
            LD   A,(RewriteExpressionLeftValue)
            OR   A
            JR   NZ,_RewriteExpressionNoShortCircuit
_RewriteExpressionBeginShortCircuit:
            LD   A,(RewriteExpressionSuppressFault)
            INC  A
            LD   (RewriteExpressionSuppressFault),A
            SET  7,C
_RewriteExpressionNoShortCircuit:
            LD   A,(RewriteExpressionLeftMeta)
            PUSH DE
            PUSH HL
            PUSH AF
            PUSH BC
            CALL RewriteParserTake
            POP  BC
            LD   A,(RewriteExpressionDepth)
            CP   RewriteExpressionDepthCapacity
            JP   NC,_RewriteExpressionCapacityFailure
            INC  A
            LD   (RewriteExpressionDepth),A
            LD   HL,(TokenStartOffset)
            PUSH HL
            PUSH BC
            LD   A,C
            AND  $7F
            INC  A
            LD   C,A
            LD   B,0
            CALL RewriteExpressionParsePrecedence
            LD   (RewriteExpressionRightMeta),A
            LD   (RewriteExpressionRightValue),HL
            LD   (RewriteExpressionRightOffset),DE
            POP  BC
            LD   HL,RewriteExpressionDepth
            DEC  (HL)
            BIT  7,C
            JR   Z,_RewriteExpressionShortCircuitRestored
            LD   HL,RewriteExpressionSuppressFault
            DEC  (HL)
            RES  7,C
_RewriteExpressionShortCircuitRestored:
            POP  HL
            LD   (RewriteExpressionOperatorOffset),HL
            POP  AF
            POP  HL
            POP  DE
            PUSH DE
            CALL RewriteExpressionApplyBinary
            POP  DE
            OR   A
            JP   _RewriteExpressionPrecedenceLoop
_RewriteExpressionPrecedenceDoneSaved:
            POP  AF
            POP  HL
            POP  DE
_RewriteExpressionPrecedenceDone:
            POP  BC
            POP  IX
            OR   A
            RET

_RewriteExpressionCapacityFailure:
            LD   A,DiagnosticExpressionCapacity
            JP   RewriteRaiseDiagnostic
_RewriteExpressionComparisonFailure:
            LD   A,DiagnosticComparisonChain
            JP   RewriteRaiseDiagnostic

.routine out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B,C
RewriteExpressionParsePrefix:
            CALL RewriteParserPeek
            CP   TokenPlus
            JR   Z,_RewriteExpressionPrefixInteger
            CP   TokenMinus
            JR   Z,_RewriteExpressionPrefixInteger
            CP   TokenNot
            JR   Z,_RewriteExpressionPrefixNot
            JP   RewriteExpressionParsePrimary
_RewriteExpressionPrefixInteger:
            LD   B,A
            LD   C,7
            JR   _RewriteExpressionPrefixOperator
_RewriteExpressionPrefixNot:
            LD   B,A
            LD   C,3
_RewriteExpressionPrefixOperator:
            LD   DE,(TokenStartOffset)
            PUSH DE
            PUSH BC
            CALL RewriteParserTake
            POP  BC
            PUSH BC
            LD   B,0
            CALL RewriteExpressionParsePrecedence
            LD   (RewriteExpressionRightOffset),DE
            POP  BC
            POP  DE
            JP   RewriteExpressionApplyUnary

.routine out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B,C
RewriteExpressionParsePrimary:
            CALL RewriteParserTake
            LD   DE,(TokenStartOffset)
            CP   TokenNumber
            JR   Z,_RewriteExpressionPrimaryNumber
            CP   TokenCharacter
            JR   Z,_RewriteExpressionPrimaryCharacter
            CP   TokenTrue
            JR   Z,_RewriteExpressionPrimaryTrue
            CP   TokenFalse
            JR   Z,_RewriteExpressionPrimaryFalse
            CP   TokenName
            JR   Z,_RewriteExpressionPrimaryName
            CP   TokenLeftParen
            JR   Z,_RewriteExpressionPrimaryParenthesized
            SUB  TokenU8
            CP   4
            JR   C,_RewriteExpressionPrimaryConversion
            LD   A,DiagnosticExpectedScalar
            JP   RewriteRaiseDiagnostic
_RewriteExpressionPrimaryNumber:
            LD   H,B
            LD   L,C
            XOR  A
            RET
_RewriteExpressionPrimaryCharacter:
            LD   H,0
            LD   L,C
            LD   A,RewriteScalarTypeU8
            RET
_RewriteExpressionPrimaryTrue:
            LD   HL,1
            LD   A,RewriteScalarTypeBoolean
            RET
_RewriteExpressionPrimaryFalse:
            LD   HL,0
            LD   A,RewriteScalarTypeBoolean
            RET

_RewriteExpressionPrimaryName:
            CALL RewriteSymbolFindCurrent
            JP   NC,_RewriteExpressionUnknownName
            LD   DE,RewriteSymbolClass
            ADD  HL,DE
            LD   A,(HL)
            CP   RewriteSymbolClassConstant
            JP   NZ,RewriteExpressionTypeFailure
            INC  HL
            LD   A,(HL)
            LD   D,A
            AND  RewriteTypeIdentityMask
            CP   RewriteFirstOwnedTypeId
            JP   NC,RewriteExpressionTypeFailure
            INC  HL
            LD   E,(HL)
            INC  HL
            LD   H,(HL)
            LD   L,E
            LD   A,D
            LD   DE,(TokenStartOffset)
            RET
_RewriteExpressionUnknownName:
            LD   A,DiagnosticUnknownName
            JP   RewriteRaiseDiagnostic

_RewriteExpressionPrimaryParenthesized:
            PUSH DE
            LD   B,0
            LD   C,0
            CALL RewriteExpressionParsePrecedence
            LD   (RewriteExpressionRightMeta),A
            LD   (RewriteExpressionRightValue),HL
            LD   (RewriteExpressionRightOffset),DE
            CALL RewriteParserTake
            CP   TokenRightParen
            JP   NZ,_RewriteExpressionExpectedRight
            POP  DE
            LD   A,(RewriteExpressionRightMeta)
            LD   HL,(RewriteExpressionRightValue)
            RET

_RewriteExpressionPrimaryConversion:
            ; Token offsets 0..3 map to u8,u16,i8,i16 identities.
            CP   2
            JR   C,_RewriteExpressionConversionUnsigned
            ADD  A,$0F
            JR   _RewriteExpressionConversionTypeReady
_RewriteExpressionConversionUnsigned:
            INC  A
_RewriteExpressionConversionTypeReady:
            PUSH AF
            PUSH DE
            CALL RewriteParserTake
            CP   TokenLeftParen
            JP   NZ,_RewriteExpressionExpectedLeft
            LD   A,(RewriteExpressionExpectedType)
            PUSH AF
            XOR  A
            LD   (RewriteExpressionExpectedType),A
            LD   B,A
            LD   C,A
            CALL RewriteExpressionParsePrecedence
            LD   (RewriteExpressionRightMeta),A
            LD   (RewriteExpressionRightValue),HL
            LD   (RewriteExpressionRightOffset),DE
            POP  AF
            LD   (RewriteExpressionExpectedType),A
            CALL RewriteParserTake
            CP   TokenRightParen
            JP   NZ,_RewriteExpressionExpectedRight
            POP  DE
            POP  BC
            LD   A,(RewriteExpressionRightMeta)
            AND  RewriteTypeIdentityMask
            CP   RewriteScalarTypeBoolean
            JP   Z,RewriteExpressionTypeFailure
            LD   A,(RewriteExpressionRightMeta)
            LD   HL,(RewriteExpressionRightValue)
            LD   C,B
            PUSH DE
            CALL RewriteExpressionConvertConstant
            POP  DE
            JP   C,RewriteExpressionNarrowFailure
            LD   A,C
            RET

_RewriteExpressionExpectedLeft:
            LD   A,DiagnosticExpectedLeft
            JP   RewriteRaiseDiagnostic
_RewriteExpressionExpectedRight:
            LD   A,DiagnosticExpectedRight
            JP   RewriteRaiseDiagnostic

; B is the consumed prefix token, A/HL is its operand, and DE is the prefix
; source offset retained by the caller.
.routine in A,B,DE,HL out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B,C
RewriteExpressionApplyUnary:
            LD   C,A
            LD   A,B
            CP   TokenPlus
            JR   Z,_RewriteExpressionUnaryPlus
            CP   TokenMinus
            JR   Z,_RewriteExpressionUnaryMinus
            LD   A,C
            PUSH DE
            CALL RewriteExpressionResolveSingleIntegerOrBoolean
            POP  DE
            JP   C,RewriteExpressionRangeFailureAtDE
            CP   RewriteScalarTypeBoolean
            JR   Z,_RewriteExpressionUnaryNotBoolean
            LD   C,A
            LD   A,L
            CPL
            LD   L,A
            LD   A,H
            CPL
            LD   H,A
            CALL RewriteExpressionMaskWidth
            LD   A,C
            RET
_RewriteExpressionUnaryNotBoolean:
            LD   A,L
            XOR  1
            LD   L,A
            LD   H,0
            LD   A,RewriteScalarTypeBoolean
            RET
_RewriteExpressionUnaryPlus:
            LD   A,C
            CALL RewriteExpressionRequireInteger
            RET
_RewriteExpressionUnaryMinus:
            LD   A,C
            CALL RewriteExpressionRequireInteger
            LD   C,A
            AND  RewriteTypeIdentityMask
            JR   NZ,_RewriteExpressionUnaryMinusTyped
            LD   A,C
            AND  RewriteTypeMetaNegative
            JR   NZ,_RewriteExpressionUnaryMinusExactNegative
            LD   A,H
            CP   $80
            JR   C,_RewriteExpressionUnaryMinusExactApply
            JP   NZ,RewriteExpressionRangeFailureAtDE
            LD   A,L
            OR   A
            JP   NZ,RewriteExpressionRangeFailureAtDE
_RewriteExpressionUnaryMinusExactApply:
            CALL RewriteExpressionNegateHL
            LD   A,H
            OR   L
            RET  Z
            LD   A,RewriteTypeMetaNegative
            RET
_RewriteExpressionUnaryMinusExactNegative:
            CALL RewriteExpressionNegateHL
            XOR  A
            RET
_RewriteExpressionUnaryMinusTyped:
            CALL RewriteExpressionNegateHL
            LD   A,C
            CALL RewriteExpressionMaskWidth
            LD   A,C
            RET

; Exact integers adopt the expected integer type or their signedness default.
.routine in A,HL out A,HL,carry,zero clobbers sign,parity,halfCarry,C,D,E
RewriteExpressionResolveSingleIntegerOrBoolean:
            LD   D,A
            AND  RewriteTypeIdentityMask
            CP   RewriteScalarTypeBoolean
            RET  Z
            OR   A
            JR   NZ,_RewriteExpressionResolveSingleTyped
            LD   A,(RewriteExpressionExpectedType)
            AND  RewriteTypeIdentityMask
            CP   RewriteScalarTypeBoolean
            JR   Z,_RewriteExpressionResolveSingleDefault
            OR   A
            JR   NZ,_RewriteExpressionResolveSingleSelected
_RewriteExpressionResolveSingleDefault:
            LD   A,D
            AND  RewriteTypeMetaNegative
            LD   C,RewriteScalarTypeU16
            JR   Z,_RewriteExpressionResolveSingleConvert
            LD   C,RewriteScalarTypeI16
            JR   _RewriteExpressionResolveSingleConvert
_RewriteExpressionResolveSingleSelected:
            LD   C,A
_RewriteExpressionResolveSingleConvert:
            LD   A,D
            CALL RewriteExpressionConvertConstant
            RET  C
            LD   A,C
            RET
_RewriteExpressionResolveSingleTyped:
            LD   A,D
            RET

; A/HL/DE is the left result, B is a dense operator, and the right result is
; retained in RewriteExpressionRight*. The source position returned in DE is
; preserved by the precedence engine around this call.
.routine in A,B,DE,HL out A,HL,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE
RewriteExpressionApplyBinary:
            LD   (RewriteExpressionLeftMeta),A
            LD   (RewriteExpressionLeftValue),HL
            LD   (RewriteExpressionLeftOffset),DE
            LD   A,B
            LD   (RewriteExpressionOperator),A
            CP   RewriteExpressionOpEqual
            JP   NC,_RewriteExpressionApplyComparisonOrLogic
            CALL RewriteExpressionResolveIntegerPair
            LD   A,(RewriteExpressionOperator)
            CP   RewriteExpressionOpAdd
            JP   Z,_RewriteExpressionBinaryAdd
            CP   RewriteExpressionOpSubtract
            JP   Z,_RewriteExpressionBinarySubtract
            CP   RewriteExpressionOpMultiply
            JP   Z,_RewriteExpressionBinaryMultiply
            JP   _RewriteExpressionBinaryDivide

_RewriteExpressionApplyComparisonOrLogic:
            CP   RewriteExpressionOpAnd
            JR   NC,_RewriteExpressionApplyLogic
            JP   _RewriteExpressionApplyComparison
_RewriteExpressionApplyLogic:
            CP   RewriteExpressionOpXor
            JR   NZ,_RewriteExpressionApplyBooleanOrIntegerLogic
            LD   A,(RewriteExpressionLeftMeta)
            AND  RewriteTypeIdentityMask
            CP   RewriteScalarTypeBoolean
            JP   Z,RewriteExpressionTypeFailureAtOperator
            JR   _RewriteExpressionApplyIntegerLogic
_RewriteExpressionApplyBooleanOrIntegerLogic:
            LD   A,(RewriteExpressionLeftMeta)
            AND  RewriteTypeIdentityMask
            CP   RewriteScalarTypeBoolean
            JR   NZ,_RewriteExpressionApplyIntegerLogic
            LD   A,(RewriteExpressionRightMeta)
            AND  RewriteTypeIdentityMask
            CP   RewriteScalarTypeBoolean
            JP   NZ,RewriteExpressionTypeFailureAtRight
            LD   A,(RewriteExpressionOperator)
            CP   RewriteExpressionOpAnd
            LD   A,(RewriteExpressionLeftValue)
            JR   Z,_RewriteExpressionBooleanAnd
            LD   C,A
            LD   A,(RewriteExpressionRightValue)
            OR   C
            JR   _RewriteExpressionBooleanDone
_RewriteExpressionBooleanAnd:
            LD   C,A
            LD   A,(RewriteExpressionRightValue)
            AND  C
_RewriteExpressionBooleanDone:
            AND  1
            LD   L,A
            LD   H,0
            LD   A,RewriteScalarTypeBoolean
            RET
_RewriteExpressionApplyIntegerLogic:
            CALL RewriteExpressionResolveIntegerPair
            LD   HL,(RewriteExpressionLeftValue)
            LD   DE,(RewriteExpressionRightValue)
            LD   A,(RewriteExpressionOperator)
            CP   RewriteExpressionOpAnd
            JR   Z,_RewriteExpressionIntegerAnd
            CP   RewriteExpressionOpOr
            JR   Z,_RewriteExpressionIntegerOr
            LD   A,L
            XOR  E
            LD   L,A
            LD   A,H
            XOR  D
            LD   H,A
            JP   _RewriteExpressionIntegerBinaryDone
_RewriteExpressionIntegerAnd:
            LD   A,L
            AND  E
            LD   L,A
            LD   A,H
            AND  D
            LD   H,A
            JR   _RewriteExpressionIntegerBinaryDone
_RewriteExpressionIntegerOr:
            LD   A,L
            OR   E
            LD   L,A
            LD   A,H
            OR   D
            LD   H,A
            JR   _RewriteExpressionIntegerBinaryDone

_RewriteExpressionBinaryAdd:
            LD   HL,(RewriteExpressionLeftValue)
            LD   DE,(RewriteExpressionRightValue)
            ADD  HL,DE
            JR   _RewriteExpressionIntegerBinaryDone
_RewriteExpressionBinarySubtract:
            LD   HL,(RewriteExpressionLeftValue)
            LD   DE,(RewriteExpressionRightValue)
            OR   A
            SBC  HL,DE
            JR   _RewriteExpressionIntegerBinaryDone
_RewriteExpressionBinaryMultiply:
            LD   HL,(RewriteExpressionLeftValue)
            LD   DE,(RewriteExpressionRightValue)
            PUSH BC
            LD   BC,0
            LD   A,16
_RewriteExpressionMultiplyLoop:
            SRL  D
            RR   E
            JR   NC,_RewriteExpressionMultiplySkip
            PUSH HL
            ADD  HL,BC
            LD   B,H
            LD   C,L
            POP  HL
_RewriteExpressionMultiplySkip:
            ADD  HL,HL
            DEC  A
            JR   NZ,_RewriteExpressionMultiplyLoop
            LD   H,B
            LD   L,C
            POP  BC
_RewriteExpressionIntegerBinaryDone:
            LD   A,C
            CALL RewriteExpressionMaskWidth
            LD   A,C
            RET

_RewriteExpressionBinaryDivide:
            LD   HL,(RewriteExpressionRightValue)
            LD   A,H
            OR   L
            JR   NZ,_RewriteExpressionDivisionReady
            LD   A,(RewriteExpressionSuppressFault)
            OR   A
            JR   Z,_RewriteExpressionDivisionZeroFailure
            LD   HL,0
            LD   A,C
            RET
_RewriteExpressionDivisionZeroFailure:
            LD   HL,(RewriteExpressionRightOffset)
            LD   (TokenStartOffset),HL
            LD   A,DiagnosticDivisionZero
            JP   RewriteRaiseDiagnostic
_RewriteExpressionDivisionReady:
            LD   DE,(RewriteExpressionRightValue)
            LD   HL,(RewriteExpressionLeftValue)
            PUSH BC
            LD   A,C
            AND  RewriteScalarTypeSignedFlag
            JR   Z,_RewriteExpressionDivideUnsignedReady
            LD   A,C
            BIT  1,A
            JR   NZ,_RewriteExpressionDivideSignedReady
            BIT  7,L
            JR   Z,_RewriteExpressionDivideSignedRight8
            LD   H,$FF
_RewriteExpressionDivideSignedRight8:
            BIT  7,E
            JR   Z,_RewriteExpressionDivideSignedReady
            LD   D,$FF
_RewriteExpressionDivideSignedReady:
            LD   C,0
            BIT  7,H
            JR   Z,_RewriteExpressionDivideDividendReady
            SET  0,C
            CALL RewriteExpressionNegateHL
_RewriteExpressionDivideDividendReady:
            BIT  7,D
            JR   Z,_RewriteExpressionDivideSignsReady
            SET  1,C
            EX   DE,HL
            CALL RewriteExpressionNegateHL
            EX   DE,HL
_RewriteExpressionDivideSignsReady:
            LD   B,0
            PUSH BC
            JR   _RewriteExpressionDivideCoreReady
_RewriteExpressionDivideUnsignedReady:
            LD   BC,0
            PUSH BC
_RewriteExpressionDivideCoreReady:
            LD   BC,0
_RewriteExpressionDivideLoop:
            OR   A
            SBC  HL,DE
            JR   C,_RewriteExpressionDivideDone
            INC  BC
            JR   _RewriteExpressionDivideLoop
_RewriteExpressionDivideDone:
            ADD  HL,DE
            POP  DE
            LD   A,(RewriteExpressionOperator)
            CP   RewriteExpressionOpModulo
            JR   Z,_RewriteExpressionDivideModuloSign
            LD   H,B
            LD   L,C
            LD   A,E
            RRCA
            XOR  E
            AND  1
            JR   _RewriteExpressionDivideApplySign
_RewriteExpressionDivideModuloSign:
            LD   A,E
            AND  1
_RewriteExpressionDivideApplySign:
            JR   Z,_RewriteExpressionDivideResultReady
            CALL RewriteExpressionNegateHL
_RewriteExpressionDivideResultReady:
            POP  BC
            JP   _RewriteExpressionIntegerBinaryDone

_RewriteExpressionApplyComparison:
            LD   A,(RewriteExpressionLeftMeta)
            AND  RewriteTypeIdentityMask
            CP   RewriteScalarTypeBoolean
            JR   NZ,_RewriteExpressionCompareInteger
            LD   A,(RewriteExpressionRightMeta)
            AND  RewriteTypeIdentityMask
            CP   RewriteScalarTypeBoolean
            JP   NZ,RewriteExpressionTypeFailureAtRight
            LD   A,(RewriteExpressionOperator)
            CP   RewriteExpressionOpEqual
            JR   Z,_RewriteExpressionCompareBooleanReady
            CP   RewriteExpressionOpNotEqual
            JP   NZ,RewriteExpressionTypeFailureAtRight
_RewriteExpressionCompareBooleanReady:
            LD   HL,(RewriteExpressionLeftValue)
            LD   DE,(RewriteExpressionRightValue)
            OR   A
            SBC  HL,DE
            LD   D,0
            JR   Z,_RewriteExpressionComparisonRelationReady
            INC  D
            JR   _RewriteExpressionComparisonRelationReady
_RewriteExpressionCompareInteger:
            CALL RewriteExpressionResolveIntegerPair
            CALL RewriteExpressionCompareRelation
_RewriteExpressionComparisonRelationReady:
            LD   A,(RewriteExpressionOperator)
            CP   RewriteExpressionOpEqual
            JR   Z,_RewriteExpressionComparisonEqual
            CP   RewriteExpressionOpNotEqual
            JR   Z,_RewriteExpressionComparisonNotEqual
            CP   RewriteExpressionOpLess
            JR   Z,_RewriteExpressionComparisonLess
            CP   RewriteExpressionOpLessEqual
            JR   Z,_RewriteExpressionComparisonLessEqual
            CP   RewriteExpressionOpGreater
            JR   Z,_RewriteExpressionComparisonGreater
            LD   A,D
            CP   1
            JR   NZ,_RewriteExpressionComparisonTrue
            JR   _RewriteExpressionComparisonFalse
_RewriteExpressionComparisonEqual:
            LD   A,D
            OR   A
            JR   Z,_RewriteExpressionComparisonTrue
            JR   _RewriteExpressionComparisonFalse
_RewriteExpressionComparisonNotEqual:
            LD   A,D
            OR   A
            JR   NZ,_RewriteExpressionComparisonTrue
            JR   _RewriteExpressionComparisonFalse
_RewriteExpressionComparisonLess:
            LD   A,D
            CP   1
            JR   Z,_RewriteExpressionComparisonTrue
            JR   _RewriteExpressionComparisonFalse
_RewriteExpressionComparisonLessEqual:
            LD   A,D
            CP   2
            JR   NZ,_RewriteExpressionComparisonTrue
            JR   _RewriteExpressionComparisonFalse
_RewriteExpressionComparisonGreater:
            LD   A,D
            CP   2
            JR   Z,_RewriteExpressionComparisonTrue
_RewriteExpressionComparisonFalse:
            LD   HL,0
            LD   A,RewriteScalarTypeBoolean
            RET
_RewriteExpressionComparisonTrue:
            LD   HL,1
            LD   A,RewriteScalarTypeBoolean
            RET

; D returns 0 equal, 1 less, 2 greater for the resolved integer operands.
.routine in C out A,C,D,carry,zero clobbers sign,parity,halfCarry,E,HL
RewriteExpressionCompareRelation:
            LD   HL,(RewriteExpressionLeftValue)
            LD   DE,(RewriteExpressionRightValue)
            LD   A,C
            AND  RewriteScalarTypeSignedFlag
            JR   Z,_RewriteExpressionCompareSubtract
            BIT  1,C
            JR   Z,_RewriteExpressionCompareSignedByte
            LD   A,H
            XOR  $80
            LD   H,A
            LD   A,D
            XOR  $80
            LD   D,A
            JR   _RewriteExpressionCompareSubtract
_RewriteExpressionCompareSignedByte:
            LD   A,L
            XOR  $80
            LD   L,A
            LD   A,E
            XOR  $80
            LD   E,A
_RewriteExpressionCompareSubtract:
            OR   A
            SBC  HL,DE
            LD   D,0
            RET  Z
            INC  D
            RET  C
            INC  D
            RET

; A is source metadata, C is destination integer type, and HL is the source
; carrier. Successful byte results are canonical with H=0.
.routine in A,C,HL out A,C,HL,carry,zero clobbers sign,parity,halfCarry,D,E
RewriteExpressionConvertConstant:
            LD   D,A
            AND  RewriteTypeIdentityMask
            CP   RewriteScalarTypeBoolean
            JR   Z,_RewriteExpressionConvertFailure
            CP   RewriteScalarTypeI8
            JR   Z,_RewriteExpressionConvertSourceI8
            CP   RewriteScalarTypeI16
            JR   Z,_RewriteExpressionConvertSourceI16
            OR   A
            JR   NZ,_RewriteExpressionConvertNonnegative
            LD   A,D
            AND  RewriteTypeMetaNegative
            JR   Z,_RewriteExpressionConvertNonnegative
            JR   _RewriteExpressionConvertNegative
_RewriteExpressionConvertSourceI8:
            BIT  7,L
            JR   Z,_RewriteExpressionConvertNonnegative
            LD   H,$FF
            JR   _RewriteExpressionConvertNegative
_RewriteExpressionConvertSourceI16:
            BIT  7,H
            JR   Z,_RewriteExpressionConvertNonnegative
_RewriteExpressionConvertNegative:
            BIT  4,C
            JR   Z,_RewriteExpressionConvertFailure
            BIT  1,C
            JR   NZ,_RewriteExpressionConvertDone
            INC  H
            JR   NZ,_RewriteExpressionConvertFailure
            BIT  7,L
            JR   Z,_RewriteExpressionConvertFailure
            JR   _RewriteExpressionConvertDone
_RewriteExpressionConvertNonnegative:
            BIT  1,C
            JR   NZ,_RewriteExpressionConvertPositiveWord
            LD   A,H
            OR   A
            JR   NZ,_RewriteExpressionConvertFailure
            BIT  4,C
            JR   Z,_RewriteExpressionConvertDone
            BIT  7,L
            JR   NZ,_RewriteExpressionConvertFailure
            JR   _RewriteExpressionConvertDone
_RewriteExpressionConvertPositiveWord:
            BIT  4,C
            JR   Z,_RewriteExpressionConvertDone
            BIT  7,H
            JR   NZ,_RewriteExpressionConvertFailure
_RewriteExpressionConvertDone:
            BIT  1,C
            JR   NZ,_RewriteExpressionConvertSuccess
            LD   H,0
_RewriteExpressionConvertSuccess:
            OR   A
            RET
_RewriteExpressionConvertFailure:
            SCF
            RET

; Convert either retained operand to destination type C. These entries precede
; the pair resolver so strict AZM contracts are available at every call site.
.routine in C out A,C,carry,zero clobbers sign,parity,halfCarry,D,DE,HL
RewriteExpressionConvertLeft:
            LD   A,(RewriteExpressionLeftMeta)
            LD   HL,(RewriteExpressionLeftValue)
            CALL RewriteExpressionConvertConstant
            JR   C,_RewriteExpressionConvertLeftRange
            LD   (RewriteExpressionLeftValue),HL
            RET
_RewriteExpressionConvertLeftRange:
            JP   RewriteExpressionRangeFailureAtLeft

.routine in C out A,C,carry,zero clobbers sign,parity,halfCarry,D,DE,HL
RewriteExpressionConvertRight:
            LD   A,(RewriteExpressionRightMeta)
            LD   HL,(RewriteExpressionRightValue)
            CALL RewriteExpressionConvertConstant
            JR   C,_RewriteExpressionConvertRightRange
            LD   (RewriteExpressionRightValue),HL
            RET
_RewriteExpressionConvertRightRange:
            JP   RewriteExpressionRangeFailureAtRight

; Resolve integer operands to one common type in C and canonicalize/promote
; the retained values in place. A range error is anchored to the exact operand.
.routine out A,C,carry,zero clobbers sign,parity,halfCarry,D,DE,HL
RewriteExpressionResolveIntegerPair:
            LD   A,(RewriteExpressionLeftMeta)
            AND  RewriteTypeIdentityMask
            CP   RewriteScalarTypeBoolean
            JP   Z,RewriteExpressionTypeFailureAtRight
            LD   D,A
            LD   A,(RewriteExpressionRightMeta)
            AND  RewriteTypeIdentityMask
            CP   RewriteScalarTypeBoolean
            JP   Z,RewriteExpressionTypeFailureAtRight
            LD   E,A
            LD   A,D
            OR   A
            JR   NZ,_RewriteExpressionResolveLeftTyped
            LD   A,E
            OR   A
            JR   NZ,_RewriteExpressionResolveExactLeft
            LD   A,(RewriteExpressionExpectedType)
            AND  RewriteTypeIdentityMask
            CP   RewriteScalarTypeBoolean
            JR   Z,_RewriteExpressionResolveBothExactDefault
            OR   A
            JR   NZ,_RewriteExpressionResolveBothExactSelected
_RewriteExpressionResolveBothExactDefault:
            LD   A,(RewriteExpressionLeftMeta)
            LD   C,A
            LD   A,(RewriteExpressionRightMeta)
            OR   C
            AND  RewriteTypeMetaNegative
            LD   C,RewriteScalarTypeU16
            JR   Z,_RewriteExpressionResolveValidateBoth
            LD   C,RewriteScalarTypeI16
            JR   _RewriteExpressionResolveValidateBoth
_RewriteExpressionResolveBothExactSelected:
            LD   C,A
_RewriteExpressionResolveValidateBoth:
            CALL RewriteExpressionConvertLeft
            CALL RewriteExpressionConvertRight
            OR   A
            RET
_RewriteExpressionResolveExactLeft:
            LD   C,E
            CALL RewriteExpressionConvertLeft
            OR   A
            RET
_RewriteExpressionResolveLeftTyped:
            LD   A,E
            OR   A
            JR   NZ,_RewriteExpressionResolveBothTyped
            LD   C,D
            CALL RewriteExpressionConvertRight
            OR   A
            RET
_RewriteExpressionResolveBothTyped:
            LD   A,D
            CP   E
            JR   Z,_RewriteExpressionResolveUseLeft
            CP   RewriteScalarTypeU16
            JR   Z,_RewriteExpressionResolveU16Left
            LD   A,E
            CP   RewriteScalarTypeU16
            JR   Z,_RewriteExpressionResolveU16Right
            LD   A,D
            CP   RewriteScalarTypeI16
            JR   Z,_RewriteExpressionResolveI16
            LD   A,E
            CP   RewriteScalarTypeI16
            JR   Z,_RewriteExpressionResolveI16
            ; The only remaining distinct pair is u8/i8, whose complete
            ; common range requires i16.
            LD   C,RewriteScalarTypeI16
            JR   _RewriteExpressionPromoteI8Pair
_RewriteExpressionResolveU16Left:
            LD   A,E
            CP   RewriteScalarTypeU8
            JP   NZ,RewriteExpressionTypeFailureAtRight
            LD   C,RewriteScalarTypeU16
            RET
_RewriteExpressionResolveU16Right:
            LD   A,D
            CP   RewriteScalarTypeU8
            JP   NZ,RewriteExpressionTypeFailureAtRight
            LD   C,RewriteScalarTypeU16
            RET
_RewriteExpressionResolveI16:
            LD   A,D
            CP   RewriteScalarTypeU16
            JP   Z,RewriteExpressionTypeFailureAtRight
            LD   A,E
            CP   RewriteScalarTypeU16
            JP   Z,RewriteExpressionTypeFailureAtRight
            LD   C,RewriteScalarTypeI16
_RewriteExpressionPromoteI8Pair:
            LD   A,D
            CP   RewriteScalarTypeI8
            JR   NZ,_RewriteExpressionPromoteRightI8
            LD   HL,(RewriteExpressionLeftValue)
            BIT  7,L
            JR   Z,_RewriteExpressionPromoteLeftReady
            LD   H,$FF
_RewriteExpressionPromoteLeftReady:
            LD   (RewriteExpressionLeftValue),HL
_RewriteExpressionPromoteRightI8:
            LD   A,E
            CP   RewriteScalarTypeI8
            RET  NZ
            LD   HL,(RewriteExpressionRightValue)
            BIT  7,L
            RET  Z
            LD   H,$FF
            LD   (RewriteExpressionRightValue),HL
            RET
_RewriteExpressionResolveUseLeft:
            LD   C,D
            RET

.routine in A out A,carry,zero clobbers sign,parity,halfCarry,D
RewriteExpressionRequireInteger:
            LD   D,A
            AND  RewriteTypeIdentityMask
            CP   RewriteScalarTypeBoolean
            JP   Z,RewriteExpressionTypeFailureAtOperand
            CP   RewriteFirstOwnedTypeId
            JP   NC,RewriteExpressionTypeFailureAtOperand
            LD   A,D
            OR   A
            RET

.routine in A,C,HL out A,HL,carry,zero clobbers sign,parity,halfCarry
RewriteExpressionMaskWidth:
            BIT  1,C
            RET  NZ
            LD   H,0
            RET

.routine in HL out A,HL,carry,zero clobbers sign,parity,halfCarry
RewriteExpressionNegateHL:
            XOR  A
            SUB  L
            LD   L,A
            LD   A,0
            SBC  A,H
            LD   H,A
            RET

.routine in C out A,HL,carry,zero clobbers sign,parity,halfCarry
RewriteExpressionNarrowFailure:
            LD   A,(RewriteExpressionSuppressFault)
            OR   A
            JR   Z,_RewriteExpressionNarrowFailureActive
            LD   HL,0
            LD   A,C
            RET
_RewriteExpressionNarrowFailureActive:
            LD   A,DiagnosticNarrowing
            JP   RewriteRaiseDiagnostic
.routine noreturn
RewriteExpressionRangeFailureAtLeft:
            LD   DE,(RewriteExpressionLeftOffset)
            JP   RewriteExpressionRangeFailureAtDE
.routine noreturn
RewriteExpressionRangeFailureAtRight:
            LD   DE,(RewriteExpressionRightOffset)
            JP   RewriteExpressionRangeFailureAtDE
.routine noreturn
RewriteExpressionRangeFailureAtDE:
            LD   (TokenStartOffset),DE
            LD   A,DiagnosticIntegerRange
            JP   RewriteRaiseDiagnostic
.routine noreturn
RewriteExpressionTypeFailureAtRight:
            JP   RewriteExpressionTypeFailure

.routine noreturn
RewriteExpressionTypeFailureAtOperator:
            LD   HL,(RewriteExpressionOperatorOffset)
            LD   (TokenStartOffset),HL
            JP   RewriteExpressionTypeFailure

.routine noreturn
RewriteExpressionTypeFailureAtOperand:
            LD   HL,(RewriteExpressionRightOffset)
            LD   (TokenStartOffset),HL
            JP   RewriteExpressionTypeFailure

.routine noreturn
RewriteExpressionTypeFailure:
            LD   A,DiagnosticTypeMismatch
            JP   RewriteRaiseDiagnostic
