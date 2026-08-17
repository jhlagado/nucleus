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
            CALL RewriteExpressionBeginRuntime
            LD   B,A
            LD   C,A
            JP   RewriteExpressionParsePrecedence

; Reset the runtime-only expression state without consuming a primary. Call
; statements use this entry before their call engine parses actuals.
.routine out A,carry,zero clobbers sign,parity,halfCarry
RewriteExpressionBeginRuntime:
            LD   A,1
            LD   (RewriteExpressionMode),A
            XOR  A
            LD   (RewritePathAssignmentMode),A
            LD   (RewriteStatementRetainedCarriers),A
            LD   (RewritePendingFailure),A
            LD   (RewritePendingFailureOffset),A
            LD   (RewritePendingFailureOffset+1),A
            LD   (RewriteExpressionKnown),A
            LD   (RewriteExpressionDepth),A
            LD   (RewriteExpressionSuppressFault),A
            RET

; The expression family always publishes from the shared operand staging
; area. Keeping that address load at one contract-checked entry removes the
; repeated three-byte immediate without changing any record representation.
.routine in A out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
RewriteExpressionAppendSemantic:
            LD   HL,RewriteSemanticOperandArea
            JP   RewriteSemanticAppend

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
            LD   A,(RewritePendingFailure)
            OR   A
            JP   NZ,RewriteCallFailureContext
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
            JP   NC,RewriteCallCapacityFailure
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
            CALL RewriteExpressionAppendSemantic
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
            LD   (RewriteExpressionRightMeta),A
            LD   A,(RewritePendingFailure)
            OR   A
            JP   NZ,RewriteCallFailureAtPending
            POP  BC
            POP  DE
            LD   A,(RewriteExpressionRightMeta)
            JP   RewriteExpressionApplyUnary

; Match the retained NAME against B bytes at HL. Carry means equal. The
; spelling comparison is case-sensitive, like every source name in Nucleus.
.routine in B,HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewritePathNameEquals:
            LD   A,(TokenLength)
            CP   B
            RET  NZ
            LD   DE,(TokenLexemePointer)
_RewritePathNameEqualsLoop:
            LD   A,(DE)
            CP   (HL)
            RET  NZ
            INC  DE
            INC  HL
            DJNZ _RewritePathNameEqualsLoop
            SCF
            RET

; Return the record field selected by the current NAME. A is the owned record
; type. Carry returns A=field type and DE=complete field byte offset.
.routine in A out A,DE,carry,zero clobbers sign,parity,halfCarry,B,C,HL
RewritePathFindRecordField:
            CALL RewriteTypeAddress
            LD   A,(HL)
            CP   RewriteTypeKindRecord
            JP   NZ,RewriteExpressionTypeFailure
            INC  HL
            LD   A,(HL)
            CALL RewriteRecordAddress
            LD   C,(HL)
            INC  HL
            LD   B,(HL)
            LD   A,B
            OR   A
            JR   Z,_RewritePathUnknownField
            LD   A,C
            CALL RewriteFieldAddress
_RewritePathRecordFieldLoop:
            PUSH BC
            CALL RewriteSymbolNameEquals
            POP  BC
            JR   C,_RewritePathRecordFieldFound
            LD   DE,RewriteFieldEntrySize
            ADD  HL,DE
            DJNZ _RewritePathRecordFieldLoop
_RewritePathUnknownField:
            LD   A,DiagnosticUnknownName
            JP   RewriteRaiseDiagnostic
_RewritePathRecordFieldFound:
            INC  HL
            INC  HL
            INC  HL
            LD   A,(HL)
            INC  HL
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            SCF
            RET

; Publish one aggregate root. A/C is its exact type, B its symbol class, DE
; its full segment/local payload, and RewriteExpressionRightMeta its storage
; tag. C returns the activation count-offset for open parameters or zero.
.routine in A,B,C,DE out A,C,DE,carry,zero clobbers sign,parity,halfCarry,B,HL
RewritePathEmitRoot:
            PUSH AF
            LD   C,0
            CP   RewriteOpenStringTypeId
            JR   Z,_RewritePathRootOpen
            CP   RewriteOpenArrayFlag
            JR   C,_RewritePathRootShapeReady
_RewritePathRootOpen:
            LD   A,E
            ADD  A,2
            LD   C,A
_RewritePathRootShapeReady:
            LD   A,B
            OR   A
            JR   Z,_RewritePathRootReadOnly
            DEC  A
            JR   Z,_RewritePathRootProgram
            CP   RewriteSymbolClassParameter-1
            JR   NZ,_RewritePathRootTypeFailure
            LD   A,E
            LD   (RewriteSemanticOperandArea+RewriteSemanticLoadParameterAliasOperandOffsetOffset),A
            LD   A,RewriteSemanticLoadParameterAlias
            JR   _RewritePathRootAppend
_RewritePathRootProgram:
            LD   A,(RewriteExpressionRightMeta)
            CP   RewriteSymbolStorageReadOnly
            JR   Z,_RewritePathRootProgramReadOnly
            DEC  A
            CP   RewriteSymbolStorageBss
            JR   NC,_RewritePathRootTypeFailure
            ADD  A,RewriteSemanticLoadProgramAlias
            JR   _RewritePathRootProgramReady
_RewritePathRootProgramReadOnly:
            LD   A,RewriteSemanticLoadReadOnlyAlias
            JR   _RewritePathRootProgramReady
_RewritePathRootReadOnly:
            LD   A,RewriteSemanticLoadReadOnlyAlias
_RewritePathRootProgramReady:
            LD   (RewriteSemanticOperandArea+RewriteSemanticLoadProgramAliasOperandOffsetOffset),DE
_RewritePathRootAppend:
            PUSH BC
            CALL RewriteExpressionAppendSemantic
            POP  BC
            POP  AF
            RET
_RewritePathRootTypeFailure:
            JP   RewriteExpressionTypeFailure

; Convert a completed index expression to the u16 index carrier. Dynamic
; signed values use bit seven of targetType to request the bounds-trap form of
; the declared integer conversion, matching the target runtime contract.
.routine in A,DE,HL out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B,C
RewritePathPrepareIndex:
            LD   B,A
            AND  RewriteTypeIdentityMask
            CP   RewriteScalarTypeBoolean
            JR   Z,_RewritePathIndexTypeFailure
            LD   A,(RewriteExpressionKnown)
            OR   A
            JR   Z,_RewritePathIndexDynamic
            LD   A,B
            LD   C,RewriteScalarTypeU16
            PUSH DE
            CALL RewriteExpressionConvertConstant
            POP  DE
            JR   C,_RewritePathIndexKnownRangeFailure
            LD   A,RewriteScalarTypeU16
            RET
_RewritePathIndexKnownRangeFailure:
            LD   DE,(RewriteExpressionAtomOffset)
            JP   RewriteExpressionRangeFailureAtDE
_RewritePathIndexDynamic:
            LD   A,B
            AND  RewriteTypeIdentityMask
            CP   RewriteScalarTypeI8
            JR   Z,RewritePathIndexDynamicSigned
            CP   RewriteScalarTypeI16
            JR   Z,RewritePathIndexDynamicSigned
            CP   RewriteScalarTypeU8
            JR   Z,RewritePathIndexReady
            CP   RewriteScalarTypeU16
            JR   Z,RewritePathIndexReady
_RewritePathIndexTypeFailure:
            JP   RewriteExpressionTypeFailure
RewritePathIndexDynamicSigned:
            LD   (RewriteSemanticOperandArea+RewriteSemanticConvertIntegerOperandSourceTypeOffset),A
            LD   A,RewriteScalarTypeU16+$80
            LD   (RewriteSemanticOperandArea+RewriteSemanticConvertIntegerOperandTargetTypeOffset),A
            LD   (RewriteSemanticOperandArea+RewriteSemanticConvertIntegerOperandSourceOffsetOffset),DE
            LD   A,RewriteSemanticConvertInteger
            LD   HL,RewriteSemanticOperandArea
            PUSH DE
            CALL RewriteSemanticAppend
            POP  DE
RewritePathIndexReady:
            LD   A,RewriteScalarTypeU16
            RET
; R4 call parsing uses four compact compiler-side frames. They retain only
; signature progress and transcript operands; target activations remain a
; backend concern. No frame field contains or tags a compiler address.
.routine in A out A,HL clobbers carry,zero,sign,parity,halfCarry,DE
RewriteCallFrameAddress:
            ADD  A,A
            ADD  A,A
            ADD  A,A
            LD   E,A
            LD   D,0
            LD   HL,RewriteCallFrameBase
            ADD  HL,DE
            RET

.routine out A,HL clobbers carry,zero,sign,parity,halfCarry,DE
RewriteCallCurrentFrame:
            LD   A,(RewriteCallDepth)
            DEC  A
            JP   RewriteCallFrameAddress

.routine noreturn
RewriteCallFailureContext:
            LD   A,DiagnosticFailureContext
            JP   RewriteRaiseDiagnostic

.routine noreturn
RewriteCallFailureAtPending:
            LD   HL,(RewritePendingFailureOffset)
            LD   (TokenStartOffset),HL
            JP   RewriteCallFailureContext

; A is a retained routine ordinal and C is call metadata. Publish its signature
; into the next call frame before parsing any argument so nested infallible
; calls are independent.
.routine in A,C out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteCallPushSourceFrame:
            LD   B,A
            LD   A,(RewriteCallDepth)
            CP   RewriteCallFrameCapacity
            JR   NC,RewriteCallCapacityFailure
            LD   A,B
            CALL RewriteRoutineAddress
            INC  HL
            INC  HL
            INC  HL
            PUSH HL
            LD   A,(RewriteCallDepth)
            CALL RewriteCallFrameAddress
            LD   D,H
            LD   E,L
            POP  HL
            PUSH BC
            LDI
            LDI
            XOR  A
            LD   (DE),A
            INC  DE
            LDI
            LDI
            POP  BC
            LD   A,(HL)
            AND  RewriteRoutineFlagFails
            OR   C
            LD   (DE),A
            INC  DE
            LD   HL,(RewriteExpressionAtomOffset)
            LD   A,L
            LD   (DE),A
            INC  DE
            LD   A,H
            LD   (DE),A
            LD   HL,RewriteCallDepth
            INC  (HL)
            XOR  A
            RET
RewriteCallCapacityFailure:
            LD   A,DiagnosticExpressionCapacity
            JP   RewriteRaiseDiagnostic

; Parse one argument expression with formal type A. B returns the formal type;
; A/HL/DE return the actual metadata, value, and source offset. Publication and
; aggregate compatibility remain with the two callers below.
.routine in A out A,B,DE,HL,carry,zero clobbers sign,parity,halfCarry,C
RewriteCallParseArgumentValue:
            LD   B,A
            LD   A,(RewriteExpressionExpectedType)
            PUSH AF
            PUSH BC
            LD   A,B
            LD   (RewriteExpressionExpectedType),A
            LD   B,0
            LD   C,0
            CALL RewriteExpressionParsePrecedence
            LD   (RewriteExpressionRightMeta),A
            LD   (RewriteExpressionRightValue),HL
            LD   (RewriteExpressionRightOffset),DE
            POP  BC
            POP  AF
            LD   (RewriteExpressionExpectedType),A
            LD   A,(RewritePendingFailure)
            OR   A
            JP   NZ,RewriteCallFailureContext
            LD   A,(RewriteExpressionRightMeta)
            OR   A
            RET

; Parse one scalar actual under the formal type in A. Calls inside the argument
; may be infallible, but a failable call cannot be consumed inside an argument.
.routine in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteCallParseScalarArgument:
            CALL RewriteCallParseArgumentValue
            LD   C,B
            CALL RewriteExpressionCheckRuntimeAssignable
            CALL RewriteCallCurrentFrame
            INC  HL
            INC  HL
            INC  (HL)
            XOR  A
            RET

; Parse one aggregate actual under the formal type in A. Concrete parameters
; require exact identity. The sole polymorphic cases retain a concrete
; capacity/count or forward the hidden activation offset in a declared record.
.routine in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteCallParseAggregateArgument:
            PUSH AF
            CALL RewriteParserPeek
            CP   TokenStringLiteral
            JP   Z,_RewriteCallLiteralAggregateFailure
            POP  AF
            CALL RewriteCallParseArgumentValue
            LD   D,A
            LD   A,B
            CP   RewriteOpenStringTypeId
            JR   Z,_RewriteCallOpenStringActual
            CP   RewriteOpenArrayFlag
            JR   NC,_RewriteCallOpenArrayActual
            CP   D
            JP   NZ,RewriteExpressionTypeFailure
            JR   _RewriteCallAggregateArgumentReady

_RewriteCallOpenStringActual:
            LD   A,D
            CP   RewriteOpenStringTypeId
            JR   Z,_RewriteCallOpenStringForward
            CP   RewriteFirstOwnedTypeId
            JP   C,RewriteExpressionTypeFailure
            CALL RewriteTypeAddress
            LD   A,(HL)
            CP   RewriteTypeKindString
            JP   NZ,RewriteExpressionTypeFailure
            INC  HL
            INC  HL
            LD   A,(HL)
            LD   (RewriteSemanticOperandArea+RewriteSemanticPrepareOpenStringDirectOperandCapacityOffset),A
            XOR  A
            LD   (RewriteSemanticOperandArea+RewriteSemanticPrepareOpenStringDirectOperandArgumentModeOffset),A
            LD   A,RewriteSemanticPrepareOpenStringDirect
            JR   _RewriteCallPrepareOpenAppend
_RewriteCallOpenStringForward:
            LD   A,1
            LD   (RewriteSemanticOperandArea+RewriteSemanticPrepareOpenStringForwardOperandArgumentModeOffset),A
            LD   A,(RewriteExpressionAggregateCountOffset)
            LD   (RewriteSemanticOperandArea+RewriteSemanticPrepareOpenStringForwardOperandCapacityOffsetOffset),A
            LD   A,RewriteSemanticPrepareOpenStringForward
            JR   _RewriteCallPrepareOpenAppend

_RewriteCallOpenArrayActual:
            AND  RewriteOpenArrayElementMask
            LD   C,A
            LD   A,D
            CP   B
            JR   Z,_RewriteCallOpenArrayForward
            CP   RewriteFirstOwnedTypeId
            JP   C,RewriteExpressionTypeFailure
            CALL RewriteTypeAddress
            LD   A,(HL)
            CP   RewriteTypeKindArray
            JP   NZ,RewriteExpressionTypeFailure
            INC  HL
            LD   A,(HL)
            CP   C
            JP   NZ,RewriteExpressionTypeFailure
            INC  HL
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            LD   A,2
            LD   (RewriteSemanticOperandArea+RewriteSemanticPrepareOpenArrayDirectOperandArgumentModeOffset),A
            LD   (RewriteSemanticOperandArea+RewriteSemanticPrepareOpenArrayDirectOperandCountOffset),DE
            LD   A,RewriteSemanticPrepareOpenArrayDirect
            JR   _RewriteCallPrepareOpenAppend
_RewriteCallOpenArrayForward:
            LD   A,3
            LD   (RewriteSemanticOperandArea+RewriteSemanticPrepareOpenArrayForwardOperandArgumentModeOffset),A
            LD   A,(RewriteExpressionAggregateCountOffset)
            LD   L,A
            LD   H,0
            LD   (RewriteSemanticOperandArea+RewriteSemanticPrepareOpenArrayForwardOperandCountOffsetOffset),HL
            LD   A,RewriteSemanticPrepareOpenArrayForward
_RewriteCallPrepareOpenAppend:
            CALL RewriteExpressionAppendSemantic
            CALL RewriteCallCurrentFrame
            INC  HL
            INC  HL
            INC  (HL)
_RewriteCallAggregateArgumentReady:
            CALL RewriteCallCurrentFrame
            INC  HL
            INC  HL
            INC  (HL)
            XOR  A
            RET
_RewriteCallLiteralAggregateFailure:
            LD   A,DiagnosticExpectedName
            JP   RewriteRaiseDiagnostic

.routine in A,C out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteCallTakeExpected:
            LD   B,A
            PUSH BC
            CALL RewriteParserTake
            POP  BC
            CP   B
            RET  Z
            LD   A,C
            JP   RewriteRaiseDiagnostic

; Parse one nested scalar expression, consume the exact closing token in A,
; and use diagnostic C if it differs. The completed result is retained across
; token consumption without narrowing its type, value, or source offset.
.routine in A,C out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B,C
RewriteExpressionParseNested:
            LD   B,A
            PUSH BC
            LD   B,0
            LD   C,0
            CALL RewriteExpressionParsePrecedence
            LD   (RewriteExpressionRightMeta),A
            LD   (RewriteExpressionRightValue),HL
            LD   (RewriteExpressionRightOffset),DE
            POP  BC
            LD   A,B
            CALL RewriteCallTakeExpected
            LD   A,(RewritePendingFailure)
            OR   A
            JP   NZ,RewriteCallFailureContext
            LD   A,(RewriteExpressionRightMeta)
            LD   HL,(RewriteExpressionRightValue)
            LD   DE,(RewriteExpressionRightOffset)
            RET

; A is the source/service semantic operation and DE its record-relative call
; mode offset. The three statement-consumption operands begin cleared, and the
; exact in-transcript mode byte is retained for the immediate consumer.
.routine in A,DE out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B,C
RewriteCallPublishReady:
            LD   B,A
            PUSH DE
            DEC  DE
            LD   HL,RewriteSemanticOperandArea
            ADD  HL,DE
            XOR  A
            LD   (HL),A
            INC  HL
            LD   (HL),A
            INC  HL
            LD   (HL),A
            POP  DE
            LD   HL,(RewriteSemanticSinkCursor)
            ADD  HL,DE
            LD   (RewritePendingCallModePointer),HL
            LD   A,B
            CALL RewriteExpressionAppendSemantic
            JP   RewriteCallFinish

; Publish the completed source call from the current frame. The call-mode
; pointer addresses the generated operand by its declared record-relative
; offset; no instruction address is packed or shortened.
.routine out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B,C
RewriteCallPublishSource:
            CALL RewriteCallCurrentFrame
            INC  HL
            INC  HL
            LD   DE,RewriteSemanticOperandArea
            LD   BC,6
            LDIR
            LD   DE,RewriteSemanticCallSourceRecordOperandCallModeOffset
            LD   A,RewriteSemanticCallSource
            JP   RewriteCallPublishReady

.routine out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B,C
RewriteCallPublishService:
            CALL RewriteCallCurrentFrame
            LD   DE,RewriteCallFrameSelector
            ADD  HL,DE
            LD   A,(HL)
            LD   (RewriteSemanticOperandArea+RewriteSemanticCallServiceOperandSelectorOffset),A
            INC  HL
            INC  HL
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            LD   (RewriteSemanticOperandArea+RewriteSemanticCallServiceOperandSourceOffsetOffset),DE
            LD   DE,RewriteSemanticCallServiceRecordOperandCallModeOffset
            LD   A,RewriteSemanticCallService
            JP   RewriteCallPublishReady

; Complete either call kind. A failable nested call is invalid before its
; enclosing argument can observe a carrier; a direct failable call retains the
; exact mode operand for the immediate statement-level consumer.
.routine out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B,C
RewriteCallFinish:
            CALL RewriteCallCurrentFrame
            LD   DE,RewriteCallFrameResultType
            ADD  HL,DE
            LD   A,(HL)
            LD   B,A
            INC  HL
            INC  HL
            LD   A,(HL)
            LD   C,A
            INC  HL
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            LD   HL,RewriteCallDepth
            DEC  (HL)
            LD   A,C
            AND  RewriteRoutineFlagFails
            JR   Z,_RewriteCallFinishInfallible
            LD   A,(RewriteCallDepth)
            OR   A
            JP   NZ,RewriteCallFailureContext
            LD   HL,(TokenStartOffset)
            LD   (RewritePendingFailureOffset),HL
            LD   A,1
            LD   (RewritePendingFailure),A
            JR   _RewriteCallFinishReady
_RewriteCallFinishInfallible:
            XOR  A
            LD   (RewritePendingFailure),A
_RewriteCallFinishReady:
            XOR  A
            LD   (RewriteExpressionKnown),A
            LD   (RewriteExpressionAggregateCountOffset),A
            LD   A,B
            LD   HL,0
            RET

; Parse all actuals for the current retained source signature. The expression
; entry retains a successful result; the statement entry explicitly discards
; it without changing the declared result type in the call record.
.routine in A out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B,C
RewriteCallParseSource:
            LD   C,RewriteCallFlagKeepResult
            JR   RewriteCallParseSourceMode
.routine in A out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B,C
RewriteCallParseSourceDiscard:
            LD   C,0
.routine in A,C out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B,C
RewriteCallParseSourceMode:
            CALL RewriteCallPushSourceFrame
            LD   A,TokenLeftParen
            LD   C,DiagnosticExpectedLeft
            CALL RewriteCallTakeExpected
_RewriteCallSourceArgumentLoop:
            CALL RewriteCallCurrentFrame
            LD   A,(HL)
            INC  HL
            LD   B,(HL)
            LD   A,B
            OR   A
            JR   Z,_RewriteCallSourceClose
            DEC  HL
            LD   A,(HL)
            CALL RewriteParameterAddress
            LD   DE,RewriteParameterType
            ADD  HL,DE
            LD   A,(HL)
            CP   RewriteFirstOwnedTypeId
            JR   NC,_RewriteCallSourceAggregate
            CALL RewriteCallParseScalarArgument
            JR   _RewriteCallSourceArgumentDone
_RewriteCallSourceAggregate:
            CALL RewriteCallParseAggregateArgument
_RewriteCallSourceArgumentDone:
            CALL RewriteCallCurrentFrame
            INC  (HL)
            INC  HL
            DEC  (HL)
            JR   Z,_RewriteCallSourceClose
            LD   A,TokenComma
            LD   C,DiagnosticExpectedComma
            CALL RewriteCallTakeExpected
            JR   _RewriteCallSourceArgumentLoop
_RewriteCallSourceClose:
            LD   A,TokenRightParen
            LD   C,DiagnosticExpectedRight
            CALL RewriteCallTakeExpected
            JP   RewriteCallPublishSource

; A is one of the six dense service ordinals. Their fixed scalar signatures
; share the same argument checker and every service is failable. The expression
; entry sets the selector metadata bit; the statement entry leaves it clear.
.routine in A out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B,C
RewriteCallParseService:
            LD   C,RewriteCallFlagKeepResult
            JR   RewriteCallParseServiceMode
.routine in A out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B,C
RewriteCallParseServiceDiscard:
            LD   C,0
.routine in A,C out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B,C
RewriteCallParseServiceMode:
            LD   B,A
            PUSH BC
            LD   A,(RewriteCallDepth)
            CP   RewriteCallFrameCapacity
            JP   NC,RewriteCallCapacityFailure
            LD   A,B
            LD   E,A
            LD   D,0
            LD   HL,RewriteServiceSignatureTable
            ADD  HL,DE
            LD   A,(HL)
            LD   C,A
            LD   A,(RewriteCallDepth)
            CALL RewriteCallFrameAddress
            PUSH HL
            LD   A,C
            AND  RewriteServiceArgumentMask
            RRCA
            RRCA
            RRCA
            POP  HL
            LD   (HL),A
            OR   A
            LD   A,0
            JR   Z,_RewriteCallServiceCountReady
            INC  A
_RewriteCallServiceCountReady:
            INC  HL
            LD   (HL),A
            INC  HL
            XOR  A
            LD   (HL),A
            INC  HL
            LD   A,C
            AND  RewriteServiceResultU8
            LD   A,0
            JR   Z,_RewriteCallServiceResultReady
            LD   A,RewriteScalarTypeU8
_RewriteCallServiceResultReady:
            LD   (HL),A
            INC  HL
            POP  DE
            LD   A,B
            OR   E
            LD   (HL),A
            INC  HL
            LD   A,RewriteRoutineFlagFails
            LD   (HL),A
            INC  HL
            LD   D,H
            LD   E,L
            LD   HL,(RewriteExpressionAtomOffset)
            LD   A,L
            LD   (DE),A
            INC  DE
            LD   A,H
            LD   (DE),A
            LD   HL,RewriteCallDepth
            INC  (HL)
            LD   A,TokenLeftParen
            LD   C,DiagnosticExpectedLeft
            CALL RewriteCallTakeExpected
            CALL RewriteCallCurrentFrame
            LD   A,(HL)
            OR   A
            JR   Z,_RewriteCallServiceClose
            INC  HL
            LD   A,(HL)
            CALL RewriteCallParseScalarArgument
_RewriteCallServiceClose:
            LD   A,TokenRightParen
            LD   C,DiagnosticExpectedRight
            CALL RewriteCallTakeExpected
            JP   RewriteCallPublishService

; Local initializers admit exactly the propagation consumer. Infallible calls
; reject a stray consumer, and failable calls require a failable enclosing
; routine. The only transcript mutation is the declared callMode operand.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteCallConsumeLocalFailure:
            CALL RewriteParserPeek
            LD   B,A
            LD   A,(RewritePendingFailure)
            OR   A
            JR   NZ,_RewriteCallConsumePending
            LD   A,B
            CP   TokenElse
            JP   Z,RewriteCallFailureContext
            CP   TokenHandle
            JP   Z,RewriteCallFailureContext
            XOR  A
            RET
_RewriteCallConsumePending:
            LD   A,B
            CP   TokenElse
            JP   NZ,RewriteCallFailureContext
            LD   A,(RewriteCurrentRoutineFlags)
            AND  RewriteRoutineFlagFails
            JP   Z,RewriteCallFailureContext
            CALL RewriteParserTake
            LD   A,TokenFail
            LD   C,DiagnosticExpectedFail
            CALL RewriteCallTakeExpected
            CALL RewriteParserPeek
            CP   TokenElse
            JP   Z,RewriteCallFailureContext
            CP   TokenHandle
            JP   Z,RewriteCallFailureContext
            LD   A,(RewriteCurrentRoutineFlags)
            AND  RewriteRoutineFlagMain
            LD   A,RewriteCallModePropagateRoutine
            JR   Z,_RewriteCallConsumeModeReady
            LD   A,RewriteCallModePropagateMain
_RewriteCallConsumeModeReady:
            LD   HL,(RewritePendingCallModePointer)
            LD   (HL),A
            INC  HL
            INC  HL
            LD   A,(RewriteStatementRetainedCarriers)
            LD   (HL),A
            XOR  A
            LD   (RewritePendingFailure),A
            RET

; Materialize the scalar selected by an address path. A is its exact scalar
; type; the alias carrier is already on the target evaluation stack.
.routine in A out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B,C
RewritePathFinishScalar:
            LD   (RewritePathType),A
            CALL RewritePathRequireNoSuffix
            LD   A,(RewritePathAssignmentMode)
            OR   A
            JR   NZ,RewritePathFinishSelected
            LD   A,(RewritePathType)
            BIT  1,A
            LD   A,RewriteSemanticLoadIndirect8
            JR   Z,_RewritePathFinishAppend
            LD   A,RewriteSemanticLoadIndirect16
_RewritePathFinishAppend:
            CALL RewriteExpressionAppendSemantic
; Shared result tail for scalar aliases and already-emitted scalar properties.
.routine in A out A,DE,HL,carry,zero clobbers sign,parity,halfCarry
RewritePathFinishSelected:
            XOR  A
            LD   (RewriteExpressionKnown),A
            LD   A,(RewritePathType)
            LD   DE,(RewriteExpressionAtomOffset)
            LD   HL,0
            RET
.routine noreturn
RewriteExpressionTypeFailure:
            LD   A,DiagnosticTypeMismatch
            JP   RewriteRaiseDiagnostic

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C
RewritePathRequireNoSuffix:
            CALL RewriteParserPeek
            CP   TokenDot
            JR   Z,RewriteExpressionTypeFailure
            CP   TokenLeftBracket
            JR   Z,RewriteExpressionTypeFailure
            RET

; Return a scalar already produced by a property or source/service call.
.routine in A out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B,C
RewritePathReturnScalarValue:
            LD   (RewritePathType),A
            CALL RewritePathRequireNoSuffix
            JP   RewritePathFinishSelected

; The four checked string records share the same capacity/source operand
; layout. A selects the exact semantic operation, C is the concrete capacity
; or open-view capacity offset, and DE is the source offset.
.routine in A,C,DE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
RewritePathAppendStringCheck:
            LD   B,A
            LD   A,C
            LD   (RewriteSemanticOperandArea),A
            LD   (RewriteSemanticOperandArea+1),DE
            LD   A,B
            JP   RewriteExpressionAppendSemantic

; A/C is the current aggregate type/open-count activation offset. This one
; iterative postfix engine serves record fields, concrete/open arrays, and
; bounded/open strings. Recursive index expressions preserve the outer path
; on the compiler hardware stack.
.routine in A,C out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B,C
RewriteExpressionParsePostfix:
            LD   (RewritePathType),A
            LD   A,C
            LD   (RewritePathCountOffset),A
_RewritePathLoop:
            CALL RewriteParserPeek
            CP   TokenDot
            JP   Z,_RewritePathDot
            CP   TokenLeftBracket
            JP   Z,_RewritePathIndex
            LD   A,(RewritePathType)
            AND  RewriteTypeIdentityMask
            CP   RewriteFirstOwnedTypeId
            JP   C,RewritePathFinishScalar
            LD   A,(RewritePathCountOffset)
            LD   (RewriteExpressionAggregateCountOffset),A
            XOR  A
            LD   (RewriteExpressionKnown),A
            LD   A,(RewritePathType)
            LD   DE,(RewriteExpressionAtomOffset)
            LD   HL,0
            RET

_RewritePathDot:
            CALL RewriteParserTake
            CALL RewriteParserTake
            CP   TokenName
            JP   NZ,_RewritePathExpectedName
            LD   A,(RewritePathType)
            CP   RewriteOpenStringTypeId
            JP   Z,_RewritePathStringProperty
            CP   RewriteOpenArrayFlag
            JP   NC,_RewritePathArrayProperty
            CP   RewriteFirstOwnedTypeId
            JP   C,RewriteExpressionTypeFailure
            LD   B,A
            CALL RewriteTypeAddress
            LD   A,(HL)
            CP   RewriteTypeKindString
            LD   A,B
            JP   Z,_RewritePathStringProperty
            LD   A,(HL)
            CP   RewriteTypeKindArray
            LD   A,B
            JP   Z,_RewritePathArrayProperty
            CALL RewritePathFindRecordField
            LD   (RewriteSemanticOperandArea+RewriteSemanticSelectFieldOperandOffsetOffset),DE
            LD   (RewritePathType),A
            LD   A,RewriteSemanticSelectField
            CALL RewriteExpressionAppendSemantic
            XOR  A
            LD   (RewritePathCountOffset),A
            JP   _RewritePathLoop

_RewritePathStringProperty:
            LD   (RewritePathType),A
            LD   HL,RewritePathNameLength
            LD   B,6
            CALL RewritePathNameEquals
            JR   C,_RewritePathStringLength
            LD   HL,RewritePathNameCapacity
            LD   B,8
            CALL RewritePathNameEquals
            JP   NC,RewriteExpressionTypeFailure
            LD   A,(RewritePathAssignmentMode)
            OR   A
            JP   NZ,RewriteExpressionTypeFailure
            LD   A,(RewritePathType)
            CP   RewriteOpenStringTypeId
            JP   NZ,RewriteExpressionTypeFailure
            LD   A,(RewritePathCountOffset)
            LD   (RewriteSemanticOperandArea+RewriteSemanticOpenStringCapacityOperandCapacityOffsetOffset),A
            LD   A,RewriteSemanticOpenStringCapacity
            CALL RewriteExpressionAppendSemantic
            JR   _RewritePathPropertyReady
_RewritePathStringLength:
            LD   A,(RewritePathAssignmentMode)
            OR   A
            JR   Z,_RewritePathStringLengthRead
            LD   A,(RewritePathType)
            CP   RewriteOpenStringTypeId
            JP   NZ,RewriteExpressionTypeFailure
            LD   A,(RewritePathCountOffset)
            LD   (RewriteStatementTargetClass),A
            LD   A,2
            LD   (RewriteStatementTargetMode),A
            LD   A,RewriteScalarTypeU8
            JP   RewritePathReturnScalarValue
_RewritePathStringLengthRead:
            LD   A,(RewritePathType)
            CP   RewriteOpenStringTypeId
            JR   Z,_RewritePathOpenStringLength
            CALL RewriteTypeAddress
            INC  HL
            INC  HL
            LD   C,(HL)
            LD   DE,(TokenStartOffset)
            LD   A,RewriteSemanticStringLength
            CALL RewritePathAppendStringCheck
            JR   _RewritePathPropertyReady
_RewritePathOpenStringLength:
            LD   A,(RewritePathCountOffset)
            LD   C,A
            LD   DE,(TokenStartOffset)
            LD   A,RewriteSemanticOpenStringLength
            CALL RewritePathAppendStringCheck
_RewritePathPropertyReady:
            LD   A,RewriteScalarTypeU8
            JP   RewritePathReturnScalarValue

_RewritePathArrayProperty:
            LD   (RewritePathType),A
            LD   HL,RewritePathNameLength
            LD   B,6
            CALL RewritePathNameEquals
            JP   NC,RewriteExpressionTypeFailure
            LD   A,(RewritePathAssignmentMode)
            OR   A
            JP   NZ,RewriteExpressionTypeFailure
            LD   A,(RewritePathType)
            CP   RewriteOpenArrayFlag
            JR   NC,_RewritePathOpenArrayLength
            CALL RewriteTypeAddress
            INC  HL
            INC  HL
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            LD   (RewriteSemanticOperandArea+RewriteSemanticArrayLengthOperandCountOffset),DE
            LD   A,RewriteSemanticArrayLength
            JR   _RewritePathArrayPropertyAppend
_RewritePathOpenArrayLength:
            LD   A,(RewritePathCountOffset)
            LD   (RewriteSemanticOperandArea+RewriteSemanticOpenArrayLengthOperandCountOffsetOffset),A
            LD   A,RewriteSemanticOpenArrayLength
_RewritePathArrayPropertyAppend:
            CALL RewriteExpressionAppendSemantic
            LD   A,RewriteScalarTypeU16
            JP   RewritePathReturnScalarValue

_RewritePathIndex:
            LD   HL,(TokenStartOffset)
            LD   (RewritePathSourceOffset),HL
            LD   A,(RewritePathType)
            LD   B,A
            LD   A,(RewritePathCountOffset)
            LD   C,A
            PUSH BC
            PUSH HL
            LD   A,(RewritePathAssignmentMode)
            PUSH AF
            XOR  A
            LD   (RewritePathAssignmentMode),A
            CALL RewriteParserTake
            LD   A,(RewriteExpressionExpectedType)
            LD   DE,0
            LD   D,A
            PUSH DE
            LD   A,RewriteScalarTypeU16
            LD   (RewriteExpressionExpectedType),A
            LD   A,TokenRightBracket
            LD   C,DiagnosticExpectedRightBracket
            CALL RewriteExpressionParseNested
            POP  DE
            LD   A,D
            LD   (RewriteExpressionExpectedType),A
            LD   A,(RewriteExpressionRightMeta)
            LD   HL,(RewriteExpressionRightValue)
            LD   DE,(RewriteExpressionRightOffset)
            CALL RewritePathPrepareIndex
            POP  AF
            LD   (RewritePathAssignmentMode),A
            POP  DE
            LD   (RewritePathSourceOffset),DE
            POP  BC
            LD   A,B
            LD   (RewritePathType),A
            LD   A,C
            LD   (RewritePathCountOffset),A
            LD   A,(RewritePathType)
            CP   RewriteOpenStringTypeId
            JP   Z,_RewritePathOpenStringIndex
            CP   RewriteOpenArrayFlag
            JP   NC,_RewritePathOpenArrayIndex
            CALL RewriteTypeAddress
            LD   A,(HL)
            CP   RewriteTypeKindString
            JR   Z,_RewritePathStringIndex
            CP   RewriteTypeKindArray
            JP   NZ,RewriteExpressionTypeFailure
            INC  HL
            LD   A,(HL)
            LD   (RewritePathType),A
            INC  HL
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            LD   A,(RewriteExpressionKnown)
            OR   A
            JR   Z,_RewritePathFixedIndexDynamic
            LD   HL,(RewriteExpressionRightValue)
            OR   A
            SBC  HL,DE
            JR   NC,_RewritePathIndexRangeAtValue
_RewritePathFixedIndexDynamic:
            LD   (RewriteSemanticOperandArea+RewriteSemanticSelectIndexOperandCountOffset),DE
            LD   A,(RewritePathType)
            CALL RewriteTypeStaticExtent
            JP   C,RewriteExpressionTypeFailure
            LD   (RewriteSemanticOperandArea+RewriteSemanticSelectIndexOperandElementExtentOffset),HL
            LD   DE,(RewritePathSourceOffset)
            LD   (RewriteSemanticOperandArea+RewriteSemanticSelectIndexOperandSourceOffsetOffset),DE
            LD   A,RewriteSemanticSelectIndex
            JR   _RewritePathIndexAppend
_RewritePathOpenArrayIndex:
            AND  RewriteOpenArrayElementMask
            LD   (RewritePathType),A
            LD   A,(RewritePathCountOffset)
            LD   (RewriteSemanticOperandArea+RewriteSemanticOpenArrayIndexOperandCountOffsetOffset),A
            LD   A,(RewritePathType)
            CALL RewriteTypeStaticExtent
            JP   C,RewriteExpressionTypeFailure
            LD   (RewriteSemanticOperandArea+RewriteSemanticOpenArrayIndexOperandElementExtentOffset),HL
            LD   DE,(RewritePathSourceOffset)
            LD   (RewriteSemanticOperandArea+RewriteSemanticOpenArrayIndexOperandSourceOffsetOffset),DE
            LD   A,RewriteSemanticOpenArrayIndex
_RewritePathIndexAppend:
            CALL RewriteExpressionAppendSemantic
            XOR  A
            LD   (RewritePathCountOffset),A
            JP   _RewritePathLoop
_RewritePathStringIndex:
            INC  HL
            INC  HL
            LD   C,(HL)
            LD   DE,(RewritePathSourceOffset)
            LD   A,RewriteSemanticStringIndex
            CALL RewritePathAppendStringCheck
            JR   _RewritePathStringIndexReady
_RewritePathOpenStringIndex:
            LD   A,(RewritePathCountOffset)
            LD   C,A
            LD   DE,(RewritePathSourceOffset)
            LD   A,RewriteSemanticOpenStringIndex
            CALL RewritePathAppendStringCheck
_RewritePathStringIndexReady:
            LD   A,RewriteScalarTypeU8
            JP   RewritePathFinishScalar

_RewritePathIndexRangeAtValue:
            LD   A,(RewriteExpressionSuppressFault)
            OR   A
            JP   NZ,_RewritePathFixedIndexDynamic
            LD   DE,(RewriteExpressionRightOffset)
            JP   RewriteExpressionRangeFailureAtDE
_RewritePathExpectedName:
            LD   A,DiagnosticExpectedName
            JP   RewriteRaiseDiagnostic
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
            JP   NC,_RewriteExpressionPrimaryCallable
            LD   DE,RewriteSymbolClass
            ADD  HL,DE
            LD   A,(HL)
            LD   B,A
            INC  HL
            LD   A,(HL)
            LD   C,A
            INC  HL
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            INC  HL
            LD   A,(HL)
            LD   (RewriteExpressionRightMeta),A
            LD   A,C
            AND  RewriteTypeIdentityMask
            CP   RewriteFirstOwnedTypeId
            JP   NC,_RewriteExpressionPrimaryAggregate
            LD   A,B
            CP   RewriteSymbolClassConstant
            JP   Z,_RewriteExpressionPrimaryNamedConstant
            LD   A,C
            AND  RewriteTypeIdentityMask
            JP   Z,RewriteExpressionTypeFailure
            LD   A,B
            CP   RewriteSymbolClassProgram
            JR   Z,_RewriteExpressionPrimaryProgramClass
            SUB  RewriteSymbolClassLocal
            CP   2
            JP   NC,RewriteExpressionTypeFailure
            ADD  A,2
            JR   _RewriteExpressionPrimaryLoadClassReady
_RewriteExpressionPrimaryProgramClass:
            LD   A,(RewriteExpressionRightMeta)
            DEC  A
            CP   2
            JP   NC,RewriteExpressionTypeFailure
_RewriteExpressionPrimaryLoadClassReady:
            LD   B,A
            CP   2
            JR   NC,_RewriteExpressionPrimaryActivationOperand
            LD   (RewriteSemanticOperandArea),DE
            JR   _RewriteExpressionPrimaryLoadOperandReady
_RewriteExpressionPrimaryActivationOperand:
            LD   A,E
            LD   (RewriteSemanticOperandArea),A
_RewriteExpressionPrimaryLoadOperandReady:
            LD   A,B
            ADD  A,A
            BIT  1,C
            JR   Z,_RewriteExpressionPrimaryLoadWidthReady
            INC  A
_RewriteExpressionPrimaryLoadWidthReady:
            LD   E,A
            LD   D,0
            LD   HL,RewriteExpressionScalarLoadOperations
            ADD  HL,DE
            LD   A,(HL)
_RewriteExpressionPrimaryDynamic:
            LD   B,A
            LD   A,C
            LD   (RewriteExpressionRightMeta),A
            LD   A,B
            CALL RewriteExpressionAppendSemantic
            XOR  A
            LD   (RewriteExpressionKnown),A
            LD   A,(RewriteExpressionRightMeta)
            LD   HL,0
            LD   DE,(RewriteExpressionAtomOffset)
            RET
_RewriteExpressionPrimaryAggregate:
            LD   A,(RewriteExpressionMode)
            OR   A
            JP   Z,RewriteExpressionTypeFailure
            LD   A,C
            CALL RewritePathEmitRoot
            LD   HL,(RewriteExpressionAtomOffset)
            PUSH HL
            CALL RewriteExpressionParsePostfix
            POP  DE
            RET
_RewriteExpressionPrimaryCallable:
            CALL RewriteRoutineFindCurrent
            JR   C,_RewriteExpressionPrimarySourceCall
            CALL RewritePredefinedFindCurrent
            JP   NC,_RewriteExpressionUnknownName
            CP   6
            JR   C,_RewriteExpressionPrimaryServiceCall
            SUB  5
            LD   L,A
            LD   H,0
            LD   A,RewriteScalarTypeU8
            LD   DE,(RewriteExpressionAtomOffset)
            JP   _RewriteExpressionPrimaryKnown
_RewriteExpressionPrimarySourceCall:
            CALL RewriteCallParseSource
            JR   _RewriteExpressionPrimaryCallReady
_RewriteExpressionPrimaryServiceCall:
            CALL RewriteCallParseService
_RewriteExpressionPrimaryCallReady:
            OR   A
            JP   Z,RewriteExpressionTypeFailure
            CP   RewriteFirstOwnedTypeId
            JP   C,RewritePathReturnScalarValue
            LD   B,A
            LD   A,(RewritePendingFailure)
            OR   A
            LD   A,B
            RET  NZ
            LD   C,0
            JP   RewriteExpressionParsePostfix
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
            LD   A,TokenRightParen
            LD   C,DiagnosticExpectedRight
            CALL RewriteExpressionParseNested
            POP  DE
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
            LD   A,TokenRightParen
            LD   C,DiagnosticExpectedRight
            CALL RewriteExpressionParseNested
            LD   B,A
            POP  AF
            LD   (RewriteExpressionExpectedType),A
            LD   A,B
            POP  DE
            POP  BC
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
            CALL RewriteExpressionAppendSemantic
_RewriteExpressionPrimaryKnownReady:
            POP  HL
            POP  DE
            POP  AF
            OR   A
            RET

_RewriteExpressionExpectedLeft:
            LD   A,DiagnosticExpectedLeft
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
            CALL RewriteExpressionAppendSemantic
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
            LD   A,B
            JP   Z,RewriteExpressionApplyBinaryConstantReady
            LD   HL,(RewriteExpressionLeftValue)
            LD   DE,(RewriteExpressionLeftOffset)
            CALL RewriteExpressionApplyBinaryConstantReady
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
RewriteExpressionApplyBinaryConstantReady:
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
            JP   NZ,RewriteExpressionTypeFailure
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
            LD   A,(RewriteExpressionRightKnown)
            OR   A
            JR   Z,_RewriteExpressionDivisionSuppressed
            LD   A,(RewriteExpressionSuppressFault)
            OR   A
            JR   Z,_RewriteExpressionDivisionZeroFailure
_RewriteExpressionDivisionSuppressed:
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
            JP   NZ,RewriteExpressionTypeFailure
            LD   A,(RewriteExpressionOperator)
            CP   RewriteExpressionOpEqual
            JR   Z,_RewriteExpressionCompareBooleanReady
            CP   RewriteExpressionOpNotEqual
            JP   NZ,RewriteExpressionTypeFailure
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
            SUB  RewriteExpressionOpEqual
            LD   E,A
            ADD  A,A
            ADD  A,E
            ADD  A,D
            LD   E,A
            LD   D,0
            LD   HL,RewriteExpressionComparisonResults
            ADD  HL,DE
            LD   A,(HL)
            LD   L,A
            LD   H,0
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
            JP   RewriteExpressionAppendSemantic

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
            CALL RewriteExpressionAppendSemantic
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
            JP   Z,RewriteExpressionTypeFailure
            LD   D,A
            LD   A,(RewriteExpressionRightMeta)
            AND  RewriteTypeIdentityMask
            CP   RewriteScalarTypeBoolean
            JP   Z,RewriteExpressionTypeFailure
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
            JP   NZ,RewriteExpressionTypeFailure
            LD   C,RewriteScalarTypeU16
            RET
_RewriteExpressionResolveU16Right:
            LD   A,D
            CP   RewriteScalarTypeU8
            JP   NZ,RewriteExpressionTypeFailure
            LD   C,RewriteScalarTypeU16
            RET
_RewriteExpressionResolveI16:
            LD   A,D
            CP   RewriteScalarTypeU16
            JP   Z,RewriteExpressionTypeFailure
            LD   A,E
            CP   RewriteScalarTypeU16
            JP   Z,RewriteExpressionTypeFailure
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
RewriteExpressionTypeFailureAtOperator:
            LD   HL,(RewriteExpressionOperatorOffset)
            LD   (TokenStartOffset),HL
            JP   RewriteExpressionTypeFailure

.routine noreturn
RewriteExpressionTypeFailureAtOperand:
            LD   HL,(RewriteExpressionRightOffset)
            LD   (TokenStartOffset),HL
            JP   RewriteExpressionTypeFailure
