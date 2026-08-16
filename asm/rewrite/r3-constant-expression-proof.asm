; R3 constant-expression proof. Every .db block below is Nucleus source or
; proof state, never an encoded Z80 instruction.

CompilerWorkBase    .equ $6000
SourceBase          .equ $5000
SourceLimit         .equ $5800
RewriteAdapterBase  .equ $A000
RewriteAdapterLimit .equ $A100
DebugHooks          .equ 0

            .org $1000
ProofExpressionValues:
            LD   SP,$FF00
            CALL RewriteReset
            XOR  A
            LD   (ProofCase),A
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   HL,0
            ADD  HL,SP
            LD   (ProofExpectedSp),HL

            LD   A,0
            LD   D,RewriteScalarTypeU16
            LD   BC,7
            LD   HL,ProofPartsPrecedence
            CALL ProofEvaluateExpression
            LD   A,0
            LD   D,RewriteScalarTypeU16
            LD   BC,12
            LD   HL,ProofPartsAssociation
            CALL ProofEvaluateExpression
            LD   A,0
            LD   D,RewriteScalarTypeU16
            LD   BC,9
            LD   HL,ProofPartsGrouping
            CALL ProofEvaluateExpression
            LD   A,0
            LD   D,RewriteScalarTypeBoolean
            LD   BC,0
            LD   HL,ProofPartsNotComparison
            CALL ProofEvaluateExpression
            LD   A,0
            LD   D,RewriteScalarTypeBoolean
            LD   BC,1
            LD   HL,ProofPartsIntegerNot
            CALL ProofEvaluateExpression
            LD   A,0
            LD   D,RewriteScalarTypeI16
            LD   BC,1
            LD   HL,ProofPartsPromoteLeft
            CALL ProofEvaluateExpression
            LD   A,0
            LD   D,RewriteScalarTypeI16
            LD   BC,1
            LD   HL,ProofPartsPromoteRight
            CALL ProofEvaluateExpression
            LD   A,0
            LD   D,RewriteScalarTypeI16
            LD   BC,254
            LD   HL,ProofPartsPromoteMixed
            CALL ProofEvaluateExpression
            LD   A,0
            LD   D,RewriteScalarTypeI16
            LD   BC,$FFFE
            LD   HL,ProofPartsSignedDivide
            CALL ProofEvaluateExpression
            LD   A,0
            LD   D,RewriteScalarTypeI16
            LD   BC,$FFFF
            LD   HL,ProofPartsSignedModulo
            CALL ProofEvaluateExpression
            LD   A,0
            LD   D,RewriteScalarTypeI16
            LD   BC,$8000
            LD   HL,ProofPartsSignedMinimum
            CALL ProofEvaluateExpression
            LD   A,0
            LD   D,RewriteScalarTypeBoolean
            LD   BC,0
            LD   HL,ProofPartsShortAnd
            CALL ProofEvaluateExpression
            LD   A,0
            LD   D,RewriteScalarTypeBoolean
            LD   BC,1
            LD   HL,ProofPartsShortOr
            CALL ProofEvaluateExpression
            LD   A,0
            LD   D,RewriteScalarTypeU8
            LD   BC,0
            LD   HL,ProofPartsByteWrap
            CALL ProofEvaluateExpression
            LD   A,0
            LD   D,RewriteScalarTypeU8
            LD   BC,$00FF
            LD   HL,ProofPartsComplement
            CALL ProofEvaluateExpression
            LD   A,0
            LD   D,RewriteScalarTypeU16
            LD   BC,0
            LD   HL,ProofPartsLogicAssociation
            CALL ProofEvaluateExpression
            LD   A,0
            LD   D,RewriteScalarTypeU16
            LD   BC,17
            LD   HL,ProofPartsDepthFill
            CALL ProofEvaluateExpression
            LD   A,0
            LD   D,RewriteScalarTypeU16
            LD   BC,66
            LD   HL,ProofPartsCharacterWiden
            CALL ProofEvaluateExpression

            LD   HL,ProofNameNegative
            LD   (TokenLexemePointer),HL
            LD   A,8
            LD   (TokenLength),A
            LD   A,RewriteSymbolClassConstant
            LD   D,RewriteTypeMetaNegative
            LD   BC,$FFFF
            CALL RewriteSymbolPrepareCurrent
            CALL RewriteSymbolCommit
            LD   A,0
            LD   D,RewriteScalarTypeI16
            LD   BC,1
            LD   HL,ProofPartsNamedExact
            CALL ProofEvaluateExpression

            LD   A,RewriteScalarTypeU8
            LD   D,RewriteScalarTypeU8
            LD   BC,0
            LD   HL,ProofPartsExpectedByteWrap
            CALL ProofEvaluateExpression
            LD   A,0
            LD   D,RewriteScalarTypeBoolean
            LD   BC,1
            LD   HL,ProofPartsSignedLess
            CALL ProofEvaluateExpression
            LD   A,0
            LD   D,RewriteScalarTypeBoolean
            LD   BC,0
            LD   HL,ProofPartsUnsignedLess
            CALL ProofEvaluateExpression
            LD   A,0
            LD   D,RewriteScalarTypeBoolean
            LD   BC,0
            LD   HL,ProofPartsBooleanEqual
            CALL ProofEvaluateExpression
            LD   A,0
            LD   D,RewriteScalarTypeBoolean
            LD   BC,1
            LD   HL,ProofPartsBooleanNotEqual
            CALL ProofEvaluateExpression
            LD   A,0
            LD   D,RewriteScalarTypeBoolean
            LD   BC,1
            LD   HL,ProofPartsGreaterEqual
            CALL ProofEvaluateExpression
            LD   A,0
            LD   D,RewriteScalarTypeU16
            LD   BC,2
            LD   HL,ProofPartsUnsignedDivide
            CALL ProofEvaluateExpression
            LD   A,0
            LD   D,RewriteScalarTypeU16
            LD   BC,1
            LD   HL,ProofPartsUnsignedModulo
            CALL ProofEvaluateExpression
            LD   A,0
            LD   D,RewriteScalarTypeU8
            LD   BC,44
            LD   HL,ProofPartsByteMultiply
            CALL ProofEvaluateExpression
            LD   A,0
            LD   D,RewriteScalarTypeU8
            LD   BC,255
            LD   HL,ProofPartsUnsignedNegate
            CALL ProofEvaluateExpression
            LD   A,0
            LD   D,RewriteScalarTypeExact
            LD   BC,1
            LD   HL,ProofPartsDelimiterMaximum
            CALL ProofEvaluateExpression
            LD   A,0
            LD   D,RewriteScalarTypeBoolean
            LD   BC,1
            LD   HL,ProofPartsNestedPrefix
            CALL ProofEvaluateExpression
            LD   A,0
            LD   D,RewriteScalarTypeU8
            LD   BC,0
            LD   HL,ProofPartsU8Minimum
            CALL ProofEvaluateExpression
            LD   A,0
            LD   D,RewriteScalarTypeU8
            LD   BC,255
            LD   HL,ProofPartsU8Maximum
            CALL ProofEvaluateExpression
            LD   A,0
            LD   D,RewriteScalarTypeI8
            LD   BC,128
            LD   HL,ProofPartsI8Minimum
            CALL ProofEvaluateExpression
            LD   A,0
            LD   D,RewriteScalarTypeI8
            LD   BC,127
            LD   HL,ProofPartsI8Maximum
            CALL ProofEvaluateExpression
            LD   A,0
            LD   D,RewriteScalarTypeU16
            LD   BC,0
            LD   HL,ProofPartsU16Minimum
            CALL ProofEvaluateExpression
            LD   A,0
            LD   D,RewriteScalarTypeU16
            LD   BC,$FFFF
            LD   HL,ProofPartsU16Maximum
            CALL ProofEvaluateExpression
            LD   A,0
            LD   D,RewriteScalarTypeI16
            LD   BC,$8000
            LD   HL,ProofPartsI16Minimum
            CALL ProofEvaluateExpression
            LD   A,0
            LD   D,RewriteScalarTypeI16
            LD   BC,$7FFF
            LD   HL,ProofPartsI16Maximum
            CALL ProofEvaluateExpression

            LD   A,(RewriteExpressionDepth)
            OR   A
            JP   NZ,ProofFailure
            LD   A,(RewriteExpressionSuppressFault)
            OR   A
            JP   NZ,ProofFailure
            LD   HL,0
            ADD  HL,SP
            LD   DE,(ProofExpectedSp)
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   A,$C1
            LD   (ProofStatus),A
            HALT

; A is the surrounding expected type, D/BC the exact expected result, and HL
; the one-part descriptor. The diagnostic frame remains below this call.
.routine in A,BC,D,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,D,DE,HL
ProofEvaluateExpression:
            PUSH AF
            LD   A,(ProofCase)
            INC  A
            LD   (ProofCase),A
            POP  AF
            LD   (ProofExpectedType),A
            LD   A,D
            LD   (ProofExpectedMeta),A
            LD   (ProofExpectedValue),BC
            XOR  A
            LD   (RewriteParserHasToken),A
            LD   A,1
            CALL RewriteSourceInitializeParts
            LD   A,(ProofExpectedType)
            CALL RewriteExpressionEvaluateConstant
            LD   (ProofActualMeta),A
            LD   (ProofActualValue),HL
            LD   D,A
            LD   A,(ProofExpectedMeta)
            CP   D
            JP   NZ,ProofFailure
            LD   DE,(ProofExpectedValue)
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            CALL RewriteParserTake
            LD   (ProofActualToken),A
            CP   TokenNewline
            JP   NZ,ProofFailure
            CALL RewriteParserTake
            CP   TokenEof
            JP   NZ,ProofFailure
            RET

ProofExpressionDiagnostics:
            LD   SP,$FF00
            XOR  A
            LD   (ProofCase),A
            LD   (ProofSymbolPending),A
            LD   A,DiagnosticDivisionZero
            LD   BC,4
            LD   DE,ProofDiagnosticDivision
            LD   HL,ProofPartsDivisionZero
            JP   ProofArmDiagnostic
ProofDiagnosticDivision:
            LD   SP,$FF00
            CALL ProofCheckDiagnostic
            LD   A,DiagnosticNarrowing
            LD   BC,6
            LD   DE,ProofDiagnosticNarrowing
            LD   HL,ProofPartsNarrowing
            JP   ProofArmDiagnostic
ProofDiagnosticNarrowing:
            LD   SP,$FF00
            CALL ProofCheckDiagnostic
            LD   A,DiagnosticComparisonChain
            LD   BC,6
            LD   DE,ProofDiagnosticComparison
            LD   HL,ProofPartsComparisonChain
            JP   ProofArmDiagnostic
ProofDiagnosticComparison:
            LD   SP,$FF00
            CALL ProofCheckDiagnostic
            LD   A,DiagnosticUnknownName
            LD   BC,0
            LD   DE,ProofDiagnosticUnknown
            LD   HL,ProofPartsUnknownName
            JP   ProofArmDiagnostic
ProofDiagnosticUnknown:
            LD   SP,$FF00
            CALL ProofCheckDiagnostic
            LD   A,DiagnosticTypeMismatch
            LD   BC,5
            LD   DE,ProofDiagnosticType
            LD   HL,ProofPartsBooleanXor
            JP   ProofArmDiagnostic
ProofDiagnosticType:
            LD   SP,$FF00
            CALL ProofCheckDiagnostic
            LD   A,DiagnosticTypeMismatch
            LD   BC,10
            LD   DE,ProofDiagnosticXorRight
            LD   HL,ProofPartsXorRightBoolean
            JP   ProofArmDiagnostic
ProofDiagnosticXorRight:
            LD   SP,$FF00
            CALL ProofCheckDiagnostic
            LD   A,DiagnosticTypeMismatch
            LD   BC,10
            LD   DE,ProofDiagnosticBooleanAnd
            LD   HL,ProofPartsBooleanAndInteger
            JP   ProofArmDiagnostic
ProofDiagnosticBooleanAnd:
            LD   SP,$FF00
            CALL ProofCheckDiagnostic
            LD   A,DiagnosticTypeMismatch
            LD   BC,12
            LD   DE,ProofDiagnosticBooleanOrder
            LD   HL,ProofPartsBooleanOrder
            JP   ProofArmDiagnostic
ProofDiagnosticBooleanOrder:
            LD   SP,$FF00
            CALL ProofCheckDiagnostic
            LD   A,DiagnosticTypeMismatch
            LD   BC,15
            LD   DE,ProofDiagnosticMixedInteger
            LD   HL,ProofPartsMixedInteger
            JP   ProofArmDiagnostic
ProofDiagnosticMixedInteger:
            LD   SP,$FF00
            CALL ProofCheckDiagnostic
            LD   A,DiagnosticTypeMismatch
            LD   BC,7
            LD   DE,ProofDiagnosticBooleanConversion
            LD   HL,ProofPartsBooleanConversion
            JP   ProofArmDiagnostic
ProofDiagnosticBooleanConversion:
            LD   SP,$FF00
            CALL ProofCheckDiagnostic
            LD   A,DiagnosticTypeMismatch
            LD   BC,1
            LD   DE,ProofDiagnosticUnaryType
            LD   HL,ProofPartsUnaryType
            JP   ProofArmDiagnostic
ProofDiagnosticUnaryType:
            LD   SP,$FF00
            CALL ProofCheckDiagnostic
            LD   A,DiagnosticNarrowing
            LD   BC,6
            LD   DE,ProofDiagnosticU8Overflow
            LD   HL,ProofPartsU8Overflow
            JP   ProofArmDiagnostic
ProofDiagnosticU8Overflow:
            LD   SP,$FF00
            CALL ProofCheckDiagnostic
            LD   A,DiagnosticNarrowing
            LD   BC,7
            LD   DE,ProofDiagnosticI8Underflow
            LD   HL,ProofPartsI8Underflow
            JP   ProofArmDiagnostic
ProofDiagnosticI8Underflow:
            LD   SP,$FF00
            CALL ProofCheckDiagnostic
            LD   A,DiagnosticNarrowing
            LD   BC,6
            LD   DE,ProofDiagnosticU16Negative
            LD   HL,ProofPartsU16Negative
            JP   ProofArmDiagnostic
ProofDiagnosticU16Negative:
            LD   SP,$FF00
            CALL ProofCheckDiagnostic
            LD   A,DiagnosticNarrowing
            LD   BC,9
            LD   DE,ProofDiagnosticI16Overflow
            LD   HL,ProofPartsI16Overflow
            JP   ProofArmDiagnostic
ProofDiagnosticI16Overflow:
            LD   SP,$FF00
            CALL ProofCheckDiagnostic
            LD   HL,ProofNameVariable
            LD   (ProofSymbolName),HL
            LD   A,8
            LD   (ProofSymbolLength),A
            LD   A,RewriteSymbolClassProgram
            LD   (ProofSymbolClass),A
            LD   A,1
            LD   (ProofSymbolPending),A
            LD   A,RewriteScalarTypeU8
            LD   (ProofSymbolType),A
            LD   A,DiagnosticTypeMismatch
            LD   BC,0
            LD   DE,ProofDiagnosticVariableName
            LD   HL,ProofPartsVariableName
            JP   ProofArmDiagnostic
ProofDiagnosticVariableName:
            LD   SP,$FF00
            CALL ProofCheckDiagnostic
            LD   HL,ProofNameAggregate
            LD   (ProofSymbolName),HL
            LD   A,9
            LD   (ProofSymbolLength),A
            LD   A,RewriteSymbolClassConstant
            LD   (ProofSymbolClass),A
            LD   A,1
            LD   (ProofSymbolPending),A
            LD   A,RewriteFirstOwnedTypeId
            LD   (ProofSymbolType),A
            LD   A,DiagnosticTypeMismatch
            LD   BC,0
            LD   DE,ProofDiagnosticAggregateName
            LD   HL,ProofPartsAggregateName
            JP   ProofArmDiagnostic
ProofDiagnosticAggregateName:
            LD   SP,$FF00
            CALL ProofCheckDiagnostic
            LD   A,DiagnosticExpressionCapacity
            LD   BC,49
            LD   DE,ProofDiagnosticDepth
            LD   HL,ProofPartsDepthOverflow
            JP   ProofArmDiagnostic
ProofDiagnosticDepth:
            LD   SP,$FF00
            CALL ProofCheckDiagnostic
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,0
            LD   D,RewriteScalarTypeU16
            LD   BC,5
            LD   HL,ProofPartsRecovery
            CALL ProofEvaluateExpression
            LD   A,$C2
            LD   (ProofStatus),A
            HALT

; A/BC are the expected code/offset, DE the nonlocal continuation, and HL the
; source descriptor. This routine intentionally never returns normally.
.routine noreturn
ProofArmDiagnostic:
            PUSH AF
            LD   A,(ProofCase)
            INC  A
            LD   (ProofCase),A
            POP  AF
            LD   (ProofExpectedDiagnostic),A
            LD   (ProofExpectedOffset),BC
            LD   (ProofDiagnosticContinuation),DE
            LD   (ProofDiagnosticParts),HL
            CALL RewriteReset
            LD   A,(ProofSymbolPending)
            OR   A
            JR   Z,ProofArmDiagnosticSource
            LD   HL,(ProofSymbolName)
            LD   (TokenLexemePointer),HL
            LD   A,(ProofSymbolLength)
            LD   (TokenLength),A
            LD   A,(ProofSymbolType)
            LD   D,A
            LD   A,(ProofSymbolClass)
            LD   BC,0
            CALL RewriteSymbolPrepareCurrent
            CALL RewriteSymbolCommit
            XOR  A
            LD   (ProofSymbolPending),A
ProofArmDiagnosticSource:
            LD   HL,(ProofDiagnosticContinuation)
            PUSH HL
            LD   (CompilerAbortSp),SP
            XOR  A
            LD   (RewriteParserHasToken),A
            LD   A,1
            LD   HL,(ProofDiagnosticParts)
            CALL RewriteSourceInitializeParts
            XOR  A
            CALL RewriteExpressionEvaluateConstant
            JP   ProofFailure

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
ProofCheckDiagnostic:
            LD   A,(ProofExpectedDiagnostic)
            LD   B,A
            LD   A,(DiagnosticCode)
            CP   B
            JP   NZ,ProofFailure
            LD   A,(DiagnosticPartId)
            CP   1
            JP   NZ,ProofFailure
            LD   HL,(DiagnosticOffset)
            LD   DE,(ProofExpectedOffset)
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            RET

ProofUnexpectedDiagnostic:
            LD   A,(DiagnosticCode)
            LD   (ProofStatus),A
            HALT
ProofFailure:
            LD   A,$FF
            LD   (ProofStatus),A
            HALT

ProofStatus:                 .db 0
ProofCase:                   .db 0
ProofExpectedType:           .db 0
ProofExpectedMeta:           .db 0
ProofExpectedValue:          .dw 0
ProofActualMeta:             .db 0
ProofActualValue:            .dw 0
ProofActualToken:            .db 0
ProofExpectedDiagnostic:     .db 0
ProofExpectedOffset:         .dw 0
ProofDiagnosticContinuation: .dw 0
ProofDiagnosticParts:        .dw 0
ProofExpectedSp:             .dw 0
ProofSymbolName:             .dw 0
ProofSymbolLength:           .db 0
ProofSymbolPending:          .db 0
ProofSymbolClass:            .db 0
ProofSymbolType:             .db 0

            .org $4000
ProofNameNegative: .db "negative"
ProofNameVariable: .db "variable"
ProofNameAggregate: .db "aggregate"

ProofSourcePrecedence:       .db "1 + 2 * 3"
ProofSourcePrecedenceEnd:
ProofSourceAssociation:      .db "20 - 5 - 3"
ProofSourceAssociationEnd:
ProofSourceGrouping:         .db "(1 + 2) * 3"
ProofSourceGroupingEnd:
ProofSourceNotComparison:    .db "not 1 = 1"
ProofSourceNotComparisonEnd:
ProofSourceIntegerNot:       .db "(not u8(0)) = u8(255)"
ProofSourceIntegerNotEnd:
ProofSourcePromoteLeft:      .db "i8(-1) + i16(2)"
ProofSourcePromoteLeftEnd:
ProofSourcePromoteRight:     .db "i16(2) + i8(-1)"
ProofSourcePromoteRightEnd:
ProofSourcePromoteMixed:     .db "u8(255) + i8(-1)"
ProofSourcePromoteMixedEnd:
ProofSourceSignedDivide:     .db "i16(-7) / i16(3)"
ProofSourceSignedDivideEnd:
ProofSourceSignedModulo:     .db "i16(-7) mod i16(3)"
ProofSourceSignedModuloEnd:
ProofSourceSignedMinimum:    .db "i16(-32768) / i16(-1)"
ProofSourceSignedMinimumEnd:
ProofSourceShortAnd:         .db "false and (1 / 0 = 0)"
ProofSourceShortAndEnd:
ProofSourceShortOr:          .db "true or (i8(128) = i8(0))"
ProofSourceShortOrEnd:
ProofSourceByteWrap:         .db "u8(255) + 1"
ProofSourceByteWrapEnd:
ProofSourceComplement:       .db "not u8(0)"
ProofSourceComplementEnd:
ProofSourceLogicAssociation: .db "1 or 2 xor 3"
ProofSourceLogicAssociationEnd:
ProofSourceDepthFill:        .db "1+(1+(1+(1+(1+(1+(1+(1+(1+(1+(1+(1+(1+(1+(1+(1+1)))))))))))))))"
ProofSourceDepthFillEnd:
ProofSourceCharacterWiden:   .db "'A' + u16(1)"
ProofSourceCharacterWidenEnd:
ProofSourceNamedExact:       .db "negative + i16(2)"
ProofSourceNamedExactEnd:
ProofSourceExpectedByteWrap: .db "255 + 1"
ProofSourceExpectedByteWrapEnd:
ProofSourceSignedLess:       .db "i8(-1) < i8(1)"
ProofSourceSignedLessEnd:
ProofSourceUnsignedLess:     .db "u8(255) < u8(1)"
ProofSourceUnsignedLessEnd:
ProofSourceBooleanEqual:     .db "true = false"
ProofSourceBooleanEqualEnd:
ProofSourceBooleanNotEqual:  .db "true <> false"
ProofSourceBooleanNotEqualEnd:
ProofSourceGreaterEqual:     .db "u16(2) >= u8(2)"
ProofSourceGreaterEqualEnd:
ProofSourceUnsignedDivide:   .db "u16(7) / u8(3)"
ProofSourceUnsignedDivideEnd:
ProofSourceUnsignedModulo:   .db "u16(7) mod u8(3)"
ProofSourceUnsignedModuloEnd:
ProofSourceByteMultiply:     .db "u8(100) * u8(3)"
ProofSourceByteMultiplyEnd:
ProofSourceUnsignedNegate:   .db "-u8(1)"
ProofSourceUnsignedNegateEnd:
ProofSourceDelimiterMaximum: .db "(((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((1)))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))"
ProofSourceDelimiterMaximumEnd:
ProofSourceNestedPrefix:     .db "not not true"
ProofSourceNestedPrefixEnd:
ProofSourceU8Minimum:        .db "u8(0)"
ProofSourceU8MinimumEnd:
ProofSourceU8Maximum:        .db "u8(255)"
ProofSourceU8MaximumEnd:
ProofSourceI8Minimum:        .db "i8(-128)"
ProofSourceI8MinimumEnd:
ProofSourceI8Maximum:        .db "i8(127)"
ProofSourceI8MaximumEnd:
ProofSourceU16Minimum:       .db "u16(0)"
ProofSourceU16MinimumEnd:
ProofSourceU16Maximum:       .db "u16(65535)"
ProofSourceU16MaximumEnd:
ProofSourceI16Minimum:       .db "i16(-32768)"
ProofSourceI16MinimumEnd:
ProofSourceI16Maximum:       .db "i16(32767)"
ProofSourceI16MaximumEnd:
ProofSourceDivisionZero:     .db "1 / 0"
ProofSourceDivisionZeroEnd:
ProofSourceNarrowing:        .db "i8(128)"
ProofSourceNarrowingEnd:
ProofSourceComparisonChain:  .db "1 < 2 < 3"
ProofSourceComparisonChainEnd:
ProofSourceUnknownName:      .db "missing + 1"
ProofSourceUnknownNameEnd:
ProofSourceBooleanXor:       .db "true xor false"
ProofSourceBooleanXorEnd:
ProofSourceXorRightBoolean:  .db "1 xor true"
ProofSourceXorRightBooleanEnd:
ProofSourceBooleanAndInteger: .db "true and 1"
ProofSourceBooleanAndIntegerEnd:
ProofSourceBooleanOrder:     .db "true < false"
ProofSourceBooleanOrderEnd:
ProofSourceMixedInteger:     .db "u16(1) + i16(1)"
ProofSourceMixedIntegerEnd:
ProofSourceBooleanConversion: .db "u8(true)"
ProofSourceBooleanConversionEnd:
ProofSourceUnaryType:        .db "+true"
ProofSourceUnaryTypeEnd:
ProofSourceU8Overflow:       .db "u8(256)"
ProofSourceU8OverflowEnd:
ProofSourceI8Underflow:      .db "i8(-129)"
ProofSourceI8UnderflowEnd:
ProofSourceU16Negative:      .db "u16(-1)"
ProofSourceU16NegativeEnd:
ProofSourceI16Overflow:      .db "i16(32768)"
ProofSourceI16OverflowEnd:
ProofSourceVariableName:     .db "variable"
ProofSourceVariableNameEnd:
ProofSourceAggregateName:    .db "aggregate"
ProofSourceAggregateNameEnd:
ProofSourceDepthOverflow:    .db "1+(1+(1+(1+(1+(1+(1+(1+(1+(1+(1+(1+(1+(1+(1+(1+(1+1))))))))))))))))"
ProofSourceDepthOverflowEnd:
ProofSourceRecovery:         .db "2 + 3"
ProofSourceRecoveryEnd:

ProofPartsPrecedence:       .db 1
                            .dw ProofSourcePrecedence,ProofSourcePrecedenceEnd
ProofPartsAssociation:      .db 1
                            .dw ProofSourceAssociation,ProofSourceAssociationEnd
ProofPartsGrouping:         .db 1
                            .dw ProofSourceGrouping,ProofSourceGroupingEnd
ProofPartsNotComparison:    .db 1
                            .dw ProofSourceNotComparison,ProofSourceNotComparisonEnd
ProofPartsIntegerNot:       .db 1
                            .dw ProofSourceIntegerNot,ProofSourceIntegerNotEnd
ProofPartsPromoteLeft:      .db 1
                            .dw ProofSourcePromoteLeft,ProofSourcePromoteLeftEnd
ProofPartsPromoteRight:     .db 1
                            .dw ProofSourcePromoteRight,ProofSourcePromoteRightEnd
ProofPartsPromoteMixed:     .db 1
                            .dw ProofSourcePromoteMixed,ProofSourcePromoteMixedEnd
ProofPartsSignedDivide:     .db 1
                            .dw ProofSourceSignedDivide,ProofSourceSignedDivideEnd
ProofPartsSignedModulo:     .db 1
                            .dw ProofSourceSignedModulo,ProofSourceSignedModuloEnd
ProofPartsSignedMinimum:    .db 1
                            .dw ProofSourceSignedMinimum,ProofSourceSignedMinimumEnd
ProofPartsShortAnd:         .db 1
                            .dw ProofSourceShortAnd,ProofSourceShortAndEnd
ProofPartsShortOr:          .db 1
                            .dw ProofSourceShortOr,ProofSourceShortOrEnd
ProofPartsByteWrap:         .db 1
                            .dw ProofSourceByteWrap,ProofSourceByteWrapEnd
ProofPartsComplement:       .db 1
                            .dw ProofSourceComplement,ProofSourceComplementEnd
ProofPartsLogicAssociation: .db 1
                            .dw ProofSourceLogicAssociation,ProofSourceLogicAssociationEnd
ProofPartsDepthFill:        .db 1
                            .dw ProofSourceDepthFill,ProofSourceDepthFillEnd
ProofPartsCharacterWiden:   .db 1
                            .dw ProofSourceCharacterWiden,ProofSourceCharacterWidenEnd
ProofPartsNamedExact:       .db 1
                            .dw ProofSourceNamedExact,ProofSourceNamedExactEnd
ProofPartsExpectedByteWrap: .db 1
                            .dw ProofSourceExpectedByteWrap,ProofSourceExpectedByteWrapEnd
ProofPartsSignedLess:       .db 1
                            .dw ProofSourceSignedLess,ProofSourceSignedLessEnd
ProofPartsUnsignedLess:     .db 1
                            .dw ProofSourceUnsignedLess,ProofSourceUnsignedLessEnd
ProofPartsBooleanEqual:     .db 1
                            .dw ProofSourceBooleanEqual,ProofSourceBooleanEqualEnd
ProofPartsBooleanNotEqual:  .db 1
                            .dw ProofSourceBooleanNotEqual,ProofSourceBooleanNotEqualEnd
ProofPartsGreaterEqual:     .db 1
                            .dw ProofSourceGreaterEqual,ProofSourceGreaterEqualEnd
ProofPartsUnsignedDivide:   .db 1
                            .dw ProofSourceUnsignedDivide,ProofSourceUnsignedDivideEnd
ProofPartsUnsignedModulo:   .db 1
                            .dw ProofSourceUnsignedModulo,ProofSourceUnsignedModuloEnd
ProofPartsByteMultiply:     .db 1
                            .dw ProofSourceByteMultiply,ProofSourceByteMultiplyEnd
ProofPartsUnsignedNegate:   .db 1
                            .dw ProofSourceUnsignedNegate,ProofSourceUnsignedNegateEnd
ProofPartsDelimiterMaximum: .db 1
                            .dw ProofSourceDelimiterMaximum,ProofSourceDelimiterMaximumEnd
ProofPartsNestedPrefix:     .db 1
                            .dw ProofSourceNestedPrefix,ProofSourceNestedPrefixEnd
ProofPartsU8Minimum:        .db 1
                            .dw ProofSourceU8Minimum,ProofSourceU8MinimumEnd
ProofPartsU8Maximum:        .db 1
                            .dw ProofSourceU8Maximum,ProofSourceU8MaximumEnd
ProofPartsI8Minimum:        .db 1
                            .dw ProofSourceI8Minimum,ProofSourceI8MinimumEnd
ProofPartsI8Maximum:        .db 1
                            .dw ProofSourceI8Maximum,ProofSourceI8MaximumEnd
ProofPartsU16Minimum:       .db 1
                            .dw ProofSourceU16Minimum,ProofSourceU16MinimumEnd
ProofPartsU16Maximum:       .db 1
                            .dw ProofSourceU16Maximum,ProofSourceU16MaximumEnd
ProofPartsI16Minimum:       .db 1
                            .dw ProofSourceI16Minimum,ProofSourceI16MinimumEnd
ProofPartsI16Maximum:       .db 1
                            .dw ProofSourceI16Maximum,ProofSourceI16MaximumEnd
ProofPartsDivisionZero:     .db 1
                            .dw ProofSourceDivisionZero,ProofSourceDivisionZeroEnd
ProofPartsNarrowing:        .db 1
                            .dw ProofSourceNarrowing,ProofSourceNarrowingEnd
ProofPartsComparisonChain:  .db 1
                            .dw ProofSourceComparisonChain,ProofSourceComparisonChainEnd
ProofPartsUnknownName:      .db 1
                            .dw ProofSourceUnknownName,ProofSourceUnknownNameEnd
ProofPartsBooleanXor:       .db 1
                            .dw ProofSourceBooleanXor,ProofSourceBooleanXorEnd
ProofPartsXorRightBoolean:  .db 1
                            .dw ProofSourceXorRightBoolean,ProofSourceXorRightBooleanEnd
ProofPartsBooleanAndInteger: .db 1
                            .dw ProofSourceBooleanAndInteger,ProofSourceBooleanAndIntegerEnd
ProofPartsBooleanOrder:     .db 1
                            .dw ProofSourceBooleanOrder,ProofSourceBooleanOrderEnd
ProofPartsMixedInteger:     .db 1
                            .dw ProofSourceMixedInteger,ProofSourceMixedIntegerEnd
ProofPartsBooleanConversion: .db 1
                            .dw ProofSourceBooleanConversion,ProofSourceBooleanConversionEnd
ProofPartsUnaryType:        .db 1
                            .dw ProofSourceUnaryType,ProofSourceUnaryTypeEnd
ProofPartsU8Overflow:       .db 1
                            .dw ProofSourceU8Overflow,ProofSourceU8OverflowEnd
ProofPartsI8Underflow:      .db 1
                            .dw ProofSourceI8Underflow,ProofSourceI8UnderflowEnd
ProofPartsU16Negative:      .db 1
                            .dw ProofSourceU16Negative,ProofSourceU16NegativeEnd
ProofPartsI16Overflow:      .db 1
                            .dw ProofSourceI16Overflow,ProofSourceI16OverflowEnd
ProofPartsVariableName:     .db 1
                            .dw ProofSourceVariableName,ProofSourceVariableNameEnd
ProofPartsAggregateName:    .db 1
                            .dw ProofSourceAggregateName,ProofSourceAggregateNameEnd
ProofPartsDepthOverflow:    .db 1
                            .dw ProofSourceDepthOverflow,ProofSourceDepthOverflowEnd
ProofPartsRecovery:         .db 1
                            .dw ProofSourceRecovery,ProofSourceRecoveryEnd

            .org $8000
            .include "compiler-image.asmi"
