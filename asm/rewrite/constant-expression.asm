; Shared constant/runtime mode of the replacement precedence-climbing scalar
; expression engine.
;
; A result is A=RewriteScalarType* (or exact plus RewriteTypeMetaNegative),
; HL=value, DE=source byte offset. The engine is deliberately independent of
; compiler origin and retains complete word values and positions. Runtime
; Runtime mode publishes the declared semantic records while retaining known
; values for compile-time diagnostics and short-circuit suppression.

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
            LD   (RewriteExpressionMode),A
            LD   (RewriteExpressionDepth),A
            LD   (RewriteExpressionSuppressFault),A
            LD   B,A
            LD   C,A
            CALL RewriteExpressionParsePrecedence
            RET

; Runtime entry: parse a complete scalar precedence expression and publish its
; target carriers and reductions. The caller checks the following token.
.routine in A out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B,C
RewriteExpressionEvaluateRuntime:
            LD   (RewriteExpressionExpectedType),A
            LD   A,1
            LD   (RewriteExpressionMode),A
            XOR  A
            LD   (RewriteExpressionKnown),A
            LD   (RewriteExpressionDepth),A
            LD   (RewriteExpressionSuppressFault),A
            LD   B,A
            LD   C,A
            JP   RewriteExpressionParsePrecedence

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
            LD   A,(RewriteExpressionKnown)
            LD   (RewriteExpressionLeftKnown),A
            OR   A
            JR   Z,_RewriteExpressionNoShortCircuit
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
            LD   A,(RewriteExpressionMode)
            OR   A
            CALL NZ,RewriteExpressionRuntimeBeginBoolean
            LD   A,(RewriteExpressionLeftMeta)
            OR   A
            PUSH DE
            PUSH HL
            PUSH AF
            LD   A,(RewriteExpressionKnown)
            LD   (RewriteExpressionLeftKnown),A
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
            LD   A,(RewriteExpressionKnown)
            LD   (RewriteExpressionRightKnown),A
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
            LD   (RewriteExpressionLeftKnown),A
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

; In runtime mode a Boolean and/or begins its target short-circuit before the
; right operand is parsed. BC remains the precedence-loop state.
.routine in B,C,DE,HL out A,B,C,DE,HL,carry,zero clobbers sign,parity,halfCarry
RewriteExpressionRuntimeBeginBoolean:
            LD   A,(RewriteExpressionLeftMeta)
            AND  RewriteTypeIdentityMask
            CP   RewriteScalarTypeBoolean
            RET  NZ
            LD   A,B
            CP   RewriteExpressionOpAnd
            JR   Z,_RewriteExpressionRuntimeBeginAnd
            CP   RewriteExpressionOpOr
            RET  NZ
            LD   A,RewriteSemanticBeginBooleanOr
            JR   _RewriteExpressionRuntimeBeginReady
_RewriteExpressionRuntimeBeginAnd:
            LD   A,RewriteSemanticBeginBooleanAnd
_RewriteExpressionRuntimeBeginReady:
            PUSH DE
            PUSH HL
            PUSH BC
            LD   HL,RewriteSemanticOperandArea
            CALL RewriteSemanticAppend
            POP  BC
            POP  HL
            POP  DE
            RET

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
            LD   (RewriteExpressionAtomOffset),DE
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
            JP   Z,_RewriteExpressionPrimaryParenthesized
            SUB  TokenU8
            CP   4
            JP   C,_RewriteExpressionPrimaryConversion
            LD   A,DiagnosticExpectedScalar
            JP   RewriteRaiseDiagnostic
_RewriteExpressionPrimaryNumber:
            LD   H,B
            LD   L,C
            XOR  A
            JP   _RewriteExpressionPrimaryKnown
_RewriteExpressionPrimaryCharacter:
            LD   H,0
            LD   L,C
            LD   A,RewriteScalarTypeU8
            JP   _RewriteExpressionPrimaryKnown
_RewriteExpressionPrimaryTrue:
            LD   HL,1
            LD   A,RewriteScalarTypeBoolean
            JP   _RewriteExpressionPrimaryKnown
_RewriteExpressionPrimaryFalse:
            LD   HL,0
            LD   A,RewriteScalarTypeBoolean
            JP   _RewriteExpressionPrimaryKnown

_RewriteExpressionPrimaryName:
            CALL RewriteSymbolFindCurrent
            JP   NC,_RewriteExpressionUnknownName
            LD   DE,RewriteSymbolClass
            ADD  HL,DE
            LD   A,(HL)
            LD   B,A
            INC  HL
            LD   A,(HL)
            LD   C,A
            AND  RewriteTypeIdentityMask
            CP   RewriteFirstOwnedTypeId
            JP   NC,RewriteExpressionTypeFailure
            INC  HL
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            INC  HL
            LD   A,(HL)
            LD   (RewriteExpressionRightMeta),A
            LD   A,B
            CP   RewriteSymbolClassConstant
            JR   Z,_RewriteExpressionPrimaryNamedConstant
            LD   A,C
            AND  RewriteTypeIdentityMask
            JP   Z,RewriteExpressionTypeFailure
            LD   A,B
            CP   RewriteSymbolClassProgram
            JR   Z,_RewriteExpressionPrimaryProgram
            CP   RewriteSymbolClassLocal
            JR   Z,_RewriteExpressionPrimaryLocal
            CP   RewriteSymbolClassParameter
            JP   NZ,RewriteExpressionTypeFailure
            LD   A,C
            BIT  1,A
            LD   A,RewriteSemanticLoadParameter8
            JR   Z,_RewriteExpressionPrimaryActivationReady
            LD   A,RewriteSemanticLoadParameter16
            JR   _RewriteExpressionPrimaryActivationReady
_RewriteExpressionPrimaryLocal:
            LD   A,C
            BIT  1,A
            LD   A,RewriteSemanticLoadLocalU8
            JR   Z,_RewriteExpressionPrimaryActivationReady
            LD   A,RewriteSemanticLoadLocal16
_RewriteExpressionPrimaryActivationReady:
            LD   B,A
            LD   A,E
            LD   (RewriteSemanticOperandArea),A
            LD   A,B
            JR   _RewriteExpressionPrimaryDynamic
_RewriteExpressionPrimaryProgram:
            LD   A,(RewriteExpressionRightMeta)
            CP   RewriteSymbolStorageInitialized
            JR   Z,_RewriteExpressionPrimaryProgramInitialized
            CP   RewriteSymbolStorageBss
            JP   NZ,RewriteExpressionTypeFailure
            LD   A,C
            BIT  1,A
            LD   A,RewriteSemanticLoadBssU8
            JR   Z,_RewriteExpressionPrimaryProgramReady
            LD   A,RewriteSemanticLoadBss16
            JR   _RewriteExpressionPrimaryProgramReady
_RewriteExpressionPrimaryProgramInitialized:
            LD   A,C
            BIT  1,A
            LD   A,RewriteSemanticLoadProgramU8
            JR   Z,_RewriteExpressionPrimaryProgramReady
            LD   A,RewriteSemanticLoadProgram16
_RewriteExpressionPrimaryProgramReady:
            LD   (RewriteSemanticOperandArea),DE
_RewriteExpressionPrimaryDynamic:
            LD   B,A
            LD   A,C
            LD   (RewriteExpressionRightMeta),A
            LD   A,B
            LD   HL,RewriteSemanticOperandArea
            CALL RewriteSemanticAppend
            XOR  A
            LD   (RewriteExpressionKnown),A
            LD   A,(RewriteExpressionRightMeta)
            LD   HL,0
            LD   DE,(RewriteExpressionAtomOffset)
            RET
_RewriteExpressionPrimaryNamedConstant:
            EX   DE,HL
            LD   A,C
            LD   DE,(RewriteExpressionAtomOffset)
            JP   _RewriteExpressionPrimaryKnown
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
            LD   A,(RewriteExpressionKnown)
            OR   A
            JR   Z,_RewriteExpressionPrimaryDynamicConversion
            LD   A,(RewriteExpressionRightMeta)
            LD   HL,(RewriteExpressionRightValue)
            LD   C,B
            PUSH DE
            CALL RewriteExpressionConvertConstant
            POP  DE
            JP   C,RewriteExpressionNarrowFailure
            LD   A,C
            RET
_RewriteExpressionPrimaryDynamicConversion:
            LD   A,(RewriteExpressionRightMeta)
            AND  RewriteTypeIdentityMask
            LD   C,B
            CP   C
            JR   Z,_RewriteExpressionPrimaryConversionDone
            CP   RewriteScalarTypeU8
            JR   NZ,_RewriteExpressionPrimaryConversionEmit
            BIT  1,C
            JR   NZ,_RewriteExpressionPrimaryConversionDone
_RewriteExpressionPrimaryConversionEmit:
            LD   (RewriteSemanticOperandArea+RewriteSemanticConvertIntegerOperandSourceTypeOffset),A
            LD   A,C
            LD   (RewriteSemanticOperandArea+RewriteSemanticConvertIntegerOperandTargetTypeOffset),A
            LD   (RewriteSemanticOperandArea+RewriteSemanticConvertIntegerOperandSourceOffsetOffset),DE
            LD   A,RewriteSemanticConvertInteger
            LD   HL,RewriteSemanticOperandArea
            PUSH BC
            CALL RewriteSemanticAppend
            POP  BC
_RewriteExpressionPrimaryConversionDone:
            LD   A,C
            RET

; A/HL/DE is a compile-time-known scalar. Runtime mode publishes the same
; Literal16 carrier as the frozen compiler; constant mode remains emission-free.
_RewriteExpressionPrimaryKnown:
            PUSH AF
            PUSH DE
            PUSH HL
            LD   A,1
            LD   (RewriteExpressionKnown),A
            LD   A,(RewriteExpressionMode)
            OR   A
            JR   Z,_RewriteExpressionPrimaryKnownReady
            LD   (RewriteSemanticOperandArea),HL
            LD   A,RewriteSemanticLiteral16
            LD   HL,RewriteSemanticOperandArea
            CALL RewriteSemanticAppend
_RewriteExpressionPrimaryKnownReady:
            POP  HL
            POP  DE
            POP  AF
            OR   A
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
            LD   (RewriteExpressionRightMeta),A
            LD   (RewriteExpressionRightValue),HL
            LD   (RewriteExpressionOperatorOffset),DE
            LD   A,B
            LD   (RewriteExpressionOperator),A
            LD   A,(RewriteExpressionMode)
            OR   A
            LD   A,(RewriteExpressionRightMeta)
            JP   Z,RewriteExpressionApplyUnaryConstant
            LD   HL,(RewriteExpressionRightValue)
            LD   DE,(RewriteExpressionOperatorOffset)
            CALL RewriteExpressionApplyUnaryConstant
            OR   A
            PUSH AF
            PUSH DE
            PUSH HL
            LD   C,A
            LD   A,(RewriteExpressionOperator)
            CP   TokenPlus
            JR   Z,_RewriteExpressionRuntimeUnaryDone
            CP   TokenMinus
            JR   Z,_RewriteExpressionRuntimeUnaryMinus
            LD   A,C
            AND  RewriteTypeIdentityMask
            CP   RewriteScalarTypeBoolean
            LD   A,RewriteSemanticNotBoolean
            JR   Z,_RewriteExpressionRuntimeUnaryEmit
            LD   A,C
            BIT  1,A
            LD   A,RewriteSemanticNot8
            JR   Z,_RewriteExpressionRuntimeUnaryEmit
            LD   A,RewriteSemanticNot16
            JR   _RewriteExpressionRuntimeUnaryEmit
_RewriteExpressionRuntimeUnaryMinus:
            LD   A,C
            AND  RewriteTypeIdentityMask
            JR   Z,_RewriteExpressionRuntimeUnaryMinus16
            BIT  1,A
            LD   A,RewriteSemanticNegate8
            JR   Z,_RewriteExpressionRuntimeUnaryEmit
_RewriteExpressionRuntimeUnaryMinus16:
            LD   A,RewriteSemanticNegate16
_RewriteExpressionRuntimeUnaryEmit:
            LD   HL,RewriteSemanticOperandArea
            CALL RewriteSemanticAppend
_RewriteExpressionRuntimeUnaryDone:
            POP  HL
            POP  DE
            POP  AF
            OR   A
            RET

.routine in A,B,DE,HL out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B,C
RewriteExpressionApplyUnaryConstant:
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
            LD   A,(RewriteExpressionMode)
            OR   A
            LD   A,(RewriteExpressionLeftMeta)
            JP   Z,RewriteExpressionApplyBinaryConstant
            LD   HL,(RewriteExpressionLeftValue)
            LD   DE,(RewriteExpressionLeftOffset)
            CALL RewriteExpressionApplyBinaryConstant
            OR   A
            PUSH AF
            PUSH HL
            CALL RewriteExpressionRuntimeEmitBinary
            LD   A,(RewriteExpressionLeftKnown)
            LD   HL,RewriteExpressionRightKnown
            AND  (HL)
            LD   (RewriteExpressionKnown),A
            POP  HL
            POP  AF
            OR   A
            RET

.routine in A,B,DE,HL out A,HL,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE
RewriteExpressionApplyBinaryConstant:
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

; Runtime reductions use the already validated constant-mode type resolver,
; then publish the frozen width-specific operation. The table below contains
; semantic ordinals, not encoded Z80 instructions.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteExpressionRuntimeEmitBinary:
            LD   A,(RewriteExpressionOperator)
            CP   RewriteExpressionOpEqual
            JR   C,_RewriteExpressionRuntimeEmitArithmetic
            CP   RewriteExpressionOpAnd
            JR   C,_RewriteExpressionRuntimeEmitComparison
            LD   A,(RewriteExpressionLeftMeta)
            AND  RewriteTypeIdentityMask
            CP   RewriteScalarTypeBoolean
            JR   NZ,_RewriteExpressionRuntimeEmitIntegerLogic
            LD   A,RewriteSemanticEndBoolean
            JP   _RewriteExpressionRuntimeEmitSelected
_RewriteExpressionRuntimeEmitIntegerLogic:
            CALL RewriteExpressionRuntimeResolvePair
            LD   A,(RewriteExpressionOperator)
            SUB  RewriteExpressionOpAnd-3
            JR   _RewriteExpressionRuntimeEmitWidthTable
_RewriteExpressionRuntimeEmitArithmetic:
            CALL RewriteExpressionRuntimeResolvePair
            LD   A,(RewriteExpressionOperator)
            CP   RewriteExpressionOpDivide
            JR   NC,_RewriteExpressionRuntimeEmitDivision
_RewriteExpressionRuntimeEmitWidthTable:
            ADD  A,A
            LD   E,A
            LD   D,0
            LD   HL,RewriteExpressionRuntimeBinaryOperations
            ADD  HL,DE
            LD   A,(HL)
            BIT  1,C
            JR   Z,_RewriteExpressionRuntimeEmitSelected
            INC  HL
            LD   A,(HL)
            JR   _RewriteExpressionRuntimeEmitSelected
_RewriteExpressionRuntimeEmitDivision:
            LD   A,C
            AND  RewriteScalarTypeSignedFlag
            JR   NZ,_RewriteExpressionRuntimeEmitSignedDivision
            LD   A,(RewriteExpressionOperator)
            CP   RewriteExpressionOpModulo
            LD   A,RewriteSemanticDivide8
            JR   NZ,_RewriteExpressionRuntimeEmitUnsignedWidth
            LD   A,RewriteSemanticModulo8
_RewriteExpressionRuntimeEmitUnsignedWidth:
            BIT  1,C
            JR   Z,_RewriteExpressionRuntimeEmitDivisionOffset
            INC  A
_RewriteExpressionRuntimeEmitDivisionOffset:
            LD   HL,(RewriteExpressionOperatorOffset)
            LD   (RewriteSemanticOperandArea),HL
            JR   _RewriteExpressionRuntimeEmitSelected
_RewriteExpressionRuntimeEmitSignedDivision:
            LD   A,C
            BIT  1,A
            LD   A,$C0
            JR   Z,_RewriteExpressionRuntimeSignedModeReady
            LD   A,$40
_RewriteExpressionRuntimeSignedModeReady:
            LD   B,A
            LD   A,(RewriteExpressionOperator)
            CP   RewriteExpressionOpModulo
            LD   A,B
            JR   NZ,_RewriteExpressionRuntimeSignedModeStored
            OR   1
_RewriteExpressionRuntimeSignedModeStored:
            LD   (RewriteSemanticOperandArea+RewriteSemanticDivideSignedOperandModeOffset),A
            LD   HL,(RewriteExpressionOperatorOffset)
            LD   (RewriteSemanticOperandArea+RewriteSemanticDivideSignedOperandSourceOffsetOffset),HL
            LD   A,RewriteSemanticDivideSigned
            JR   _RewriteExpressionRuntimeEmitSelected
_RewriteExpressionRuntimeEmitComparison:
            LD   B,0
            LD   A,(RewriteExpressionLeftMeta)
            AND  RewriteTypeIdentityMask
            CP   RewriteScalarTypeBoolean
            LD   A,RewriteSemanticCompareBoolean
            JR   Z,_RewriteExpressionRuntimeComparisonOperationReady
            CALL RewriteExpressionRuntimeResolvePair
            LD   A,C
            AND  RewriteScalarTypeSignedFlag
            JR   Z,_RewriteExpressionRuntimeComparisonUnsigned
            LD   A,C
            BIT  1,A
            LD   B,$C0
            JR   Z,_RewriteExpressionRuntimeComparisonSignedReady
            LD   B,$80
_RewriteExpressionRuntimeComparisonSignedReady:
            LD   A,RewriteSemanticCompare16
            JR   _RewriteExpressionRuntimeComparisonOperationReady
_RewriteExpressionRuntimeComparisonUnsigned:
            LD   B,0
            LD   A,RewriteSemanticCompare8
            BIT  1,C
            JR   Z,_RewriteExpressionRuntimeComparisonOperationReady
            LD   A,RewriteSemanticCompare16
_RewriteExpressionRuntimeComparisonOperationReady:
            LD   C,A
            LD   A,(RewriteExpressionOperator)
            SUB  RewriteExpressionOpEqual
            OR   B
            LD   (RewriteSemanticOperandArea+RewriteSemanticCompare8OperandComparisonOffset),A
            LD   A,C
_RewriteExpressionRuntimeEmitSelected:
            LD   HL,RewriteSemanticOperandArea
            JP   RewriteSemanticAppend

; Resolve and, where necessary, publish sign extension of the left or right
; i8 carrier already on the target stack. C returns the common integer type.
.routine out A,C,carry,zero clobbers sign,parity,halfCarry,B,D,DE,HL
RewriteExpressionRuntimeResolvePair:
            CALL RewriteExpressionResolveIntegerPair
            LD   A,C
            LD   (RewriteExpressionResolvedType),A
            CP   RewriteScalarTypeI16
            JR   NZ,_RewriteExpressionRuntimeResolveDone
            LD   A,(RewriteExpressionLeftMeta)
            AND  RewriteTypeIdentityMask
            LD   D,A
            LD   A,(RewriteExpressionRightMeta)
            AND  RewriteTypeIdentityMask
            LD   E,A
            LD   A,D
            CP   RewriteScalarTypeI8
            JR   NZ,_RewriteExpressionRuntimeResolveRight
            LD   A,E
            CP   RewriteScalarTypeI8
            JR   Z,_RewriteExpressionRuntimeResolveDone
            LD   A,1
            JR   _RewriteExpressionRuntimePromote
_RewriteExpressionRuntimeResolveRight:
            LD   A,E
            CP   RewriteScalarTypeI8
            JR   NZ,_RewriteExpressionRuntimeResolveDone
            XOR  A
_RewriteExpressionRuntimePromote:
            LD   (RewriteSemanticOperandArea+RewriteSemanticPromoteI8PairOperandModeOffset),A
            LD   A,RewriteSemanticPromoteI8Pair
            LD   HL,RewriteSemanticOperandArea
            CALL RewriteSemanticAppend
_RewriteExpressionRuntimeResolveDone:
            LD   A,(RewriteExpressionResolvedType)
            LD   C,A
            OR   A
            RET

RewriteExpressionRuntimeBinaryOperations:
            .db RewriteSemanticAdd8,RewriteSemanticAdd16
            .db RewriteSemanticSubtract8,RewriteSemanticSubtract16
            .db RewriteSemanticMultiply8,RewriteSemanticMultiply16
            .db RewriteSemanticAnd8,RewriteSemanticAnd16
            .db RewriteSemanticOr8,RewriteSemanticOr16
            .db RewriteSemanticXor8,RewriteSemanticXor16

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

; A/HL/DE is one runtime scalar result and C is the declared destination.
; Exact values are range-checked now. Dynamic i8-to-i16 widening publishes
; the one required carrier conversion; canonical u8 widening needs no record.
.routine in A,C,DE,HL out A,DE,carry,zero clobbers sign,parity,halfCarry,B,C,HL
RewriteExpressionCheckRuntimeAssignable:
            LD   B,A
            AND  RewriteTypeIdentityMask
            JR   NZ,_RewriteExpressionRuntimeAssignableTyped
            LD   A,C
            CP   RewriteScalarTypeBoolean
            JP   Z,RewriteExpressionTypeFailure
            LD   A,B
            PUSH DE
            CALL RewriteExpressionConvertConstant
            POP  DE
            JP   C,RewriteExpressionRangeFailureAtDE
            LD   A,C
            RET
_RewriteExpressionRuntimeAssignableTyped:
            CP   C
            JR   Z,_RewriteExpressionRuntimeAssignableReady
            CP   RewriteScalarTypeU8
            JR   Z,_RewriteExpressionRuntimeAssignableU8
            CP   RewriteScalarTypeI8
            JP   NZ,RewriteExpressionTypeFailure
            LD   A,C
            CP   RewriteScalarTypeI16
            JP   NZ,RewriteExpressionTypeFailure
            LD   A,RewriteScalarTypeI8
            JR   _RewriteExpressionRuntimeAssignableConvert
_RewriteExpressionRuntimeAssignableU8:
            LD   A,C
            CP   RewriteScalarTypeU16
            JR   Z,_RewriteExpressionRuntimeAssignableReady
            CP   RewriteScalarTypeI16
            JP   NZ,RewriteExpressionTypeFailure
            JR   _RewriteExpressionRuntimeAssignableReady
_RewriteExpressionRuntimeAssignableConvert:
            LD   (RewriteSemanticOperandArea+RewriteSemanticConvertIntegerOperandSourceTypeOffset),A
            LD   A,C
            LD   (RewriteSemanticOperandArea+RewriteSemanticConvertIntegerOperandTargetTypeOffset),A
            LD   (RewriteSemanticOperandArea+RewriteSemanticConvertIntegerOperandSourceOffsetOffset),DE
            LD   A,RewriteSemanticConvertInteger
            LD   HL,RewriteSemanticOperandArea
            PUSH BC
            PUSH DE
            CALL RewriteSemanticAppend
            POP  DE
            POP  BC
_RewriteExpressionRuntimeAssignableReady:
            LD   A,C
            OR   A
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
