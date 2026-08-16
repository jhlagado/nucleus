; R3 source-type parser proof. Every .db string is Nucleus source text or
; retained proof data, never a raw Z80 instruction encoding.

CompilerWorkBase    .equ $6000
SourceBase          .equ $7000
SourceLimit         .equ $7800
RewriteAdapterBase  .equ $A000
RewriteAdapterLimit .equ $A100
DebugHooks          .equ 0

            .org $1000
ProofSourceTypes:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            XOR  A
            LD   (ProofCase),A

            ; Publish one nominal record type and its source spelling.
            LD   A,RewriteTypeKindRecord
            LD   (RewriteTypeCandidateKind),A
            XOR  A
            LD   (RewriteTypeCandidateAux),A
            LD   HL,1
            LD   (RewriteTypeCandidateCount),HL
            LD   HL,3
            LD   (RewriteTypeCandidateExtent),HL
            CALL RewriteTypeAppendNominal
            LD   D,A
            LD   HL,ProofRecordName
            LD   (TokenLexemePointer),HL
            LD   A,1
            LD   (TokenLength),A
            LD   A,RewriteSymbolClassRecordType
            LD   BC,0
            CALL RewriteSymbolPrepareCurrent
            CALL RewriteSymbolCommit

            LD   A,RewriteScalarTypeU8
            LD   BC,1
            LD   HL,ProofPartsU8
            CALL ProofParseType
            LD   A,RewriteScalarTypeBoolean
            LD   BC,1
            LD   HL,ProofPartsBoolean
            CALL ProofParseType
            LD   A,RewriteScalarTypeU16
            LD   BC,2
            LD   HL,ProofPartsU16
            CALL ProofParseType
            LD   A,RewriteScalarTypeI8
            LD   BC,1
            LD   HL,ProofPartsI8
            CALL ProofParseType
            LD   A,RewriteScalarTypeI16
            LD   BC,2
            LD   HL,ProofPartsI16
            CALL ProofParseType
            LD   A,RewriteOpenStringTypeId
            LD   BC,$FFFF
            LD   HL,ProofPartsOpenString
            CALL ProofParseType
            LD   A,RewriteFirstOwnedTypeId+1
            LD   BC,18
            LD   HL,ProofPartsString16
            CALL ProofParseType
            LD   A,RewriteFirstOwnedTypeId+1
            LD   BC,18
            LD   HL,ProofPartsString16
            CALL ProofParseType
            LD   A,RewriteFirstOwnedTypeId+2
            LD   BC,2
            LD   HL,ProofPartsRow
            CALL ProofParseType
            LD   A,RewriteFirstOwnedTypeId+3
            LD   BC,6
            LD   HL,ProofPartsGrid
            CALL ProofParseType
            LD   A,RewriteOpenArrayFlag+RewriteFirstOwnedTypeId+2
            LD   BC,$FFFF
            LD   HL,ProofPartsOpenRows
            CALL ProofParseType
            LD   A,RewriteOpenArrayFlag+RewriteFirstOwnedTypeId+1
            LD   BC,$FFFF
            LD   HL,ProofPartsOpenStrings
            CALL ProofParseType
            LD   A,RewriteFirstOwnedTypeId
            LD   BC,3
            LD   HL,ProofPartsRecord
            CALL ProofParseType
            LD   A,RewriteFirstOwnedTypeId+2
            LD   BC,2
            LD   HL,ProofPartsExpressionBound
            CALL ProofParseType
            LD   A,RewriteFirstOwnedTypeId+2
            LD   BC,2
            LD   HL,ProofPartsTypedByteBound
            CALL ProofParseType
            LD   A,RewriteFirstOwnedTypeId+1
            LD   BC,18
            LD   HL,ProofPartsTypedWordBound
            CALL ProofParseType
            LD   A,RewriteFirstOwnedTypeId+4
            LD   BC,1024
            LD   HL,ProofPartsMaximumExtent
            CALL ProofParseType

            ; The outer grid descriptor must contain three exact row values.
            LD   A,RewriteFirstOwnedTypeId+3
            CALL RewriteTypeAddress
            LD   A,(HL)
            CP   RewriteTypeKindArray
            JP   NZ,ProofFailure
            INC  HL
            LD   A,(HL)
            CP   RewriteFirstOwnedTypeId+2
            JP   NZ,ProofFailure
            INC  HL
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            LD   HL,3
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure

            LD   A,$C3
            LD   (ProofStatus),A
            HALT

ProofSourceTypeCapacity:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            XOR  A
            LD   (ProofCase),A
            LD   A,RewriteFirstOwnedTypeId
            LD   BC,3
            LD   HL,ProofPartsString1
            CALL ProofParseType
            LD   A,RewriteFirstOwnedTypeId+1
            LD   BC,4
            LD   HL,ProofPartsString2
            CALL ProofParseType
            LD   A,RewriteFirstOwnedTypeId+2
            LD   BC,5
            LD   HL,ProofPartsString3
            CALL ProofParseType
            LD   A,RewriteFirstOwnedTypeId+3
            LD   BC,6
            LD   HL,ProofPartsString4
            CALL ProofParseType
            LD   A,RewriteFirstOwnedTypeId+4
            LD   BC,7
            LD   HL,ProofPartsString5
            CALL ProofParseType
            LD   A,RewriteFirstOwnedTypeId+5
            LD   BC,8
            LD   HL,ProofPartsString6
            CALL ProofParseType
            LD   A,RewriteFirstOwnedTypeId+6
            LD   BC,9
            LD   HL,ProofPartsString7
            CALL ProofParseType
            LD   A,RewriteFirstOwnedTypeId+7
            LD   BC,10
            LD   HL,ProofPartsString8
            CALL ProofParseType
            LD   A,DiagnosticTypeMetadataCapacity
            LD   (ProofExpectedDiagnostic),A
            LD   HL,8
            LD   (ProofExpectedOffset),HL
            LD   HL,ProofCapacityDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            XOR  A
            LD   (RewriteParserHasToken),A
            LD   A,1
            LD   HL,ProofPartsString9
            CALL RewriteSourceInitializeParts
            CALL RewriteTypeParse
            JP   ProofFailure
ProofCapacityDiagnostic:
            CALL ProofCheckDiagnostic
            LD   A,$C5
            LD   (ProofStatus),A
            HALT

ProofSourceTypeDiagnostics:
            LD   SP,$FF00
            XOR  A
            LD   (ProofCase),A
            LD   A,DiagnosticTypeBound
            LD   BC,4
            LD   D,0
            LD   IX,ProofDiagnosticZero
            LD   HL,ProofPartsZero
            JP   ProofArmTypeDiagnostic
ProofDiagnosticZero:
            CALL ProofCheckDiagnostic
            LD   A,DiagnosticTypeMismatch
            LD   BC,9
            LD   D,0
            LD   IX,ProofDiagnosticSignedBound
            LD   HL,ProofPartsSignedBound
            JP   ProofArmTypeDiagnostic
ProofDiagnosticSignedBound:
            CALL ProofCheckDiagnostic
            LD   A,DiagnosticIntegerRange
            LD   BC,4
            LD   D,0
            LD   IX,ProofDiagnosticNegative
            LD   HL,ProofPartsNegative
            JP   ProofArmTypeDiagnostic
ProofDiagnosticNegative:
            CALL ProofCheckDiagnostic
            LD   A,DiagnosticIntegerRange
            LD   BC,5
            LD   D,0
            LD   IX,ProofDiagnosticSpacedNegative
            LD   HL,ProofPartsSpacedNegative
            JP   ProofArmTypeDiagnostic
ProofDiagnosticSpacedNegative:
            CALL ProofCheckDiagnostic
            LD   A,2
            LD   (ProofInstallSymbol),A
            LD   A,DiagnosticIntegerRange
            LD   BC,3
            LD   D,0
            LD   IX,ProofDiagnosticNamedNegative
            LD   HL,ProofPartsNamedNegative
            JP   ProofArmTypeDiagnostic
ProofDiagnosticNamedNegative:
            CALL ProofCheckDiagnostic
            LD   A,DiagnosticStringCapacity
            LD   BC,10
            LD   D,0
            LD   IX,ProofDiagnosticStringCapacity
            LD   HL,ProofPartsStringCapacity
            JP   ProofArmTypeDiagnostic
ProofDiagnosticStringCapacity:
            CALL ProofCheckDiagnostic
            LD   A,DiagnosticProgramDataCapacity
            LD   BC,7
            LD   D,0
            LD   IX,ProofDiagnosticObjectCapacity
            LD   HL,ProofPartsObjectCapacity
            JP   ProofArmTypeDiagnostic
ProofDiagnosticObjectCapacity:
            CALL ProofCheckDiagnostic
            LD   A,DiagnosticTypeMetadataCapacity
            LD   BC,16
            LD   D,0
            LD   IX,ProofDiagnosticSuffixCapacity
            LD   HL,ProofPartsSuffixCapacity
            JP   ProofArmTypeDiagnostic
ProofDiagnosticSuffixCapacity:
            CALL ProofCheckDiagnostic
            LD   A,DiagnosticTypeBound
            LD   BC,6
            LD   D,0
            LD   IX,ProofDiagnosticInnerOpen
            LD   HL,ProofPartsInnerOpen
            JP   ProofArmTypeDiagnostic
ProofDiagnosticInnerOpen:
            CALL ProofCheckDiagnostic
            LD   A,DiagnosticTypeBound
            LD   BC,10
            LD   D,0
            LD   IX,ProofDiagnosticOpenElement
            LD   HL,ProofPartsOpenElement
            JP   ProofArmTypeDiagnostic
ProofDiagnosticOpenElement:
            CALL ProofCheckDiagnostic
            LD   A,DiagnosticTypeBound
            LD   BC,3
            LD   D,1
            LD   IX,ProofDiagnosticOwnedArray
            LD   HL,ProofPartsOwnedArray
            JP   ProofArmTypeDiagnostic
ProofDiagnosticOwnedArray:
            CALL ProofCheckDiagnostic
            LD   A,DiagnosticTypeBound
            LD   BC,8
            LD   D,1
            LD   IX,ProofDiagnosticOwnedString
            LD   HL,ProofPartsOwnedString
            JP   ProofArmTypeDiagnostic
ProofDiagnosticOwnedString:
            CALL ProofCheckDiagnostic
            LD   A,DiagnosticTypeBound
            LD   BC,5
            LD   D,0
            LD   IX,ProofDiagnosticDoubleOpen
            LD   HL,ProofPartsDoubleOpen
            JP   ProofArmTypeDiagnostic
ProofDiagnosticDoubleOpen:
            CALL ProofCheckDiagnostic
            LD   A,DiagnosticTypeMismatch
            LD   BC,7
            LD   D,0
            LD   IX,ProofDiagnosticBooleanBound
            LD   HL,ProofPartsBooleanBound
            JP   ProofArmTypeDiagnostic
ProofDiagnosticBooleanBound:
            CALL ProofCheckDiagnostic
            LD   A,DiagnosticExpectedScalar
            LD   BC,3
            LD   D,0
            LD   IX,ProofDiagnosticBooleanConversion
            LD   HL,ProofPartsBooleanConversion
            JP   ProofArmTypeDiagnostic
ProofDiagnosticBooleanConversion:
            CALL ProofCheckDiagnostic
            LD   A,DiagnosticExpectedLeftBracket
            LD   BC,6
            LD   D,0
            LD   IX,ProofDiagnosticLeftBracket
            LD   HL,ProofPartsLeftBracket
            JP   ProofArmTypeDiagnostic
ProofDiagnosticLeftBracket:
            CALL ProofCheckDiagnostic
            LD   A,DiagnosticExpectedRightBracket
            LD   BC,5
            LD   D,0
            LD   IX,ProofDiagnosticRightBracket
            LD   HL,ProofPartsRightBracket
            JP   ProofArmTypeDiagnostic
ProofDiagnosticRightBracket:
            CALL ProofCheckDiagnostic
            LD   A,1
            LD   (ProofInstallSymbol),A
            LD   A,DiagnosticTypeBound
            LD   BC,0
            LD   D,0
            LD   IX,ProofDiagnosticWrongClass
            LD   HL,ProofPartsUnknown
            JP   ProofArmTypeDiagnostic
ProofDiagnosticWrongClass:
            CALL ProofCheckDiagnostic
            LD   A,DiagnosticUnknownName
            LD   BC,0
            LD   D,0
            LD   IX,ProofDiagnosticUnknown
            LD   HL,ProofPartsUnknown
            JP   ProofArmTypeDiagnostic
ProofDiagnosticUnknown:
            CALL ProofCheckDiagnostic
            LD   A,DiagnosticExpectedType
            LD   BC,0
            LD   D,0
            LD   IX,ProofDiagnosticExpected
            LD   HL,ProofPartsExpected
            JP   ProofArmTypeDiagnostic
ProofDiagnosticExpected:
            CALL ProofCheckDiagnostic
            LD   A,$C4
            LD   (ProofStatus),A
            HALT

; A is expected type, BC expected extent ($FFFF for open), HL source parts.
.routine in A,BC,HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofParseType:
            LD   (ProofExpectedType),A
            LD   (ProofExpectedExtent),BC
            PUSH HL
            XOR  A
            LD   (RewriteParserHasToken),A
            POP  HL
            LD   A,1
            CALL RewriteSourceInitializeParts
            CALL RewriteTypeParse
            LD   D,A
            LD   A,(ProofExpectedType)
            CP   D
            JP   NZ,ProofFailure
            LD   A,D
            CALL RewriteTypeStaticExtent
            JR   C,_ProofParseOpenExtent
            LD   DE,(ProofExpectedExtent)
            LD   A,D
            AND  E
            INC  A
            JP   Z,ProofFailure
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            JR   _ProofParseExtentReady
_ProofParseOpenExtent:
            LD   HL,(ProofExpectedExtent)
            INC  HL
            LD   A,H
            OR   L
            JP   NZ,ProofFailure
_ProofParseExtentReady:
            CALL RewriteParserTake
            CP   TokenNewline
            JP   NZ,ProofFailure
            CALL RewriteParserTake
            CP   TokenEof
            JP   NZ,ProofFailure
            LD   HL,ProofCase
            INC  (HL)
            XOR  A
            RET

; A/BC expected diagnostic, D placement mode, IX continuation, HL parts.
.routine noreturn
ProofArmTypeDiagnostic:
            LD   (ProofExpectedDiagnostic),A
            LD   (ProofExpectedOffset),BC
            LD   A,D
            LD   (ProofPlacementMode),A
            LD   (ProofDiagnosticContinuation),IX
            PUSH HL
            CALL RewriteReset
            POP  HL
            LD   A,(ProofInstallSymbol)
            OR   A
            JR   Z,_ProofArmTypeSource
            CP   2
            JR   Z,_ProofArmNegativeSymbol
            XOR  A
            LD   (ProofInstallSymbol),A
            PUSH HL
            LD   HL,ProofWrongClassName
            LD   (TokenLexemePointer),HL
            LD   A,7
            LD   (TokenLength),A
            LD   A,RewriteSymbolClassConstant
            LD   D,RewriteScalarTypeU8
            LD   BC,1
            CALL RewriteSymbolPrepareCurrent
            CALL RewriteSymbolCommit
            POP  HL
            JR   _ProofArmTypeSource
_ProofArmNegativeSymbol:
            XOR  A
            LD   (ProofInstallSymbol),A
            PUSH HL
            LD   HL,ProofNegativeName
            LD   (TokenLexemePointer),HL
            LD   A,8
            LD   (TokenLength),A
            LD   A,RewriteSymbolClassConstant
            LD   D,RewriteTypeMetaNegative
            LD   BC,$FFFF
            CALL RewriteSymbolPrepareCurrent
            CALL RewriteSymbolCommit
            POP  HL
_ProofArmTypeSource:
            LD   DE,(ProofDiagnosticContinuation)
            PUSH DE
            LD   (CompilerAbortSp),SP
            XOR  A
            LD   (RewriteParserHasToken),A
            LD   A,1
            CALL RewriteSourceInitializeParts
            CALL RewriteTypeParse
            LD   D,A
            LD   A,(ProofPlacementMode)
            OR   A
            LD   A,D
            CALL NZ,RewriteTypeRequireOwned
            JP   ProofFailure

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
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
            LD   HL,ProofCase
            INC  (HL)
            RET

ProofUnexpectedDiagnostic:
            LD   A,(DiagnosticCode)
            LD   (ProofStatus),A
            HALT
ProofFailure:
            LD   A,$FF
            LD   (ProofStatus),A
            HALT

            .include "compiler-image.asmi"

ProofStatus:                 .db 0
ProofCase:                   .db 0
ProofExpectedType:           .db 0
ProofExpectedExtent:         .dw 0
ProofExpectedDiagnostic:     .db 0
ProofExpectedOffset:         .dw 0
ProofPlacementMode:          .db 0
ProofDiagnosticContinuation: .dw 0
ProofInstallSymbol:           .db 0

            .org $7000
ProofRecordName: .db "R"
ProofWrongClassName: .db "Missing"
ProofNegativeName: .db "negative"

ProofSourceU8:              .db "u8"
ProofSourceU8End:
ProofSourceBoolean:         .db "boolean"
ProofSourceBooleanEnd:
ProofSourceU16:             .db "u16"
ProofSourceU16End:
ProofSourceI8:              .db "i8"
ProofSourceI8End:
ProofSourceI16:             .db "i16"
ProofSourceI16End:
ProofSourceOpenString:      .db "string[]"
ProofSourceOpenStringEnd:
ProofSourceString16:        .db "string[16]"
ProofSourceString16End:
ProofSourceRow:             .db "u8[2]"
ProofSourceRowEnd:
ProofSourceGrid:            .db "u8[3][2]"
ProofSourceGridEnd:
ProofSourceOpenRows:        .db "u8[][2]"
ProofSourceOpenRowsEnd:
ProofSourceOpenStrings:     .db "string[16][]"
ProofSourceOpenStringsEnd:
ProofSourceRecord:          .db "R"
ProofSourceRecordEnd:
ProofSourceExpressionBound: .db "u8[1+1]"
ProofSourceExpressionBoundEnd:
ProofSourceTypedByteBound:  .db "u8[u8(2)]"
ProofSourceTypedByteBoundEnd:
ProofSourceTypedWordBound:  .db "string[u16(16)]"
ProofSourceTypedWordBoundEnd:
ProofSourceMaximumExtent:   .db "u16[512]"
ProofSourceMaximumExtentEnd:
ProofSourceZero:            .db "u8[0]"
ProofSourceZeroEnd:
ProofSourceSignedBound:     .db "u8[i16(2)]"
ProofSourceSignedBoundEnd:
ProofSourceNegative:        .db "u8[-1]"
ProofSourceNegativeEnd:
ProofSourceSpacedNegative:  .db "u8[- 1]"
ProofSourceSpacedNegativeEnd:
ProofSourceNamedNegative:   .db "u8[negative]"
ProofSourceNamedNegativeEnd:
ProofSourceStringCapacity:  .db "string[254]"
ProofSourceStringCapacityEnd:
ProofSourceObjectCapacity:  .db "u8[1025]"
ProofSourceObjectCapacityEnd:
ProofSourceSuffixCapacity:  .db "u8[1][1][1][1][1]"
ProofSourceSuffixCapacityEnd:
ProofSourceInnerOpen:       .db "u8[2][]"
ProofSourceInnerOpenEnd:
ProofSourceOpenElement:     .db "string[][2]"
ProofSourceOpenElementEnd:
ProofSourceOwnedArray:      .db "u8[]"
ProofSourceOwnedArrayEnd:
ProofSourceOwnedString:     .db "string[]"
ProofSourceOwnedStringEnd:
ProofSourceDoubleOpen:      .db "u8[][]"
ProofSourceDoubleOpenEnd:
ProofSourceBooleanBound:    .db "u8[true]"
ProofSourceBooleanBoundEnd:
ProofSourceBooleanConversion: .db "u8[boolean(1)]"
ProofSourceBooleanConversionEnd:
ProofSourceLeftBracket:     .db "string"
ProofSourceLeftBracketEnd:
ProofSourceRightBracket:    .db "u8[2",10,"x"
ProofSourceRightBracketEnd:
ProofSourceUnknown:         .db "Missing"
ProofSourceUnknownEnd:
ProofSourceExpected:        .db "123"
ProofSourceExpectedEnd:

ProofPartsU8:              .db 1
                           .dw ProofSourceU8,ProofSourceU8End
ProofPartsBoolean:         .db 1
                           .dw ProofSourceBoolean,ProofSourceBooleanEnd
ProofPartsU16:             .db 1
                           .dw ProofSourceU16,ProofSourceU16End
ProofPartsI8:              .db 1
                           .dw ProofSourceI8,ProofSourceI8End
ProofPartsI16:             .db 1
                           .dw ProofSourceI16,ProofSourceI16End
ProofPartsOpenString:      .db 1
                           .dw ProofSourceOpenString,ProofSourceOpenStringEnd
ProofPartsString16:        .db 1
                           .dw ProofSourceString16,ProofSourceString16End
ProofPartsRow:             .db 1
                           .dw ProofSourceRow,ProofSourceRowEnd
ProofPartsGrid:            .db 1
                           .dw ProofSourceGrid,ProofSourceGridEnd
ProofPartsOpenRows:        .db 1
                           .dw ProofSourceOpenRows,ProofSourceOpenRowsEnd
ProofPartsOpenStrings:     .db 1
                           .dw ProofSourceOpenStrings,ProofSourceOpenStringsEnd
ProofPartsRecord:          .db 1
                           .dw ProofSourceRecord,ProofSourceRecordEnd
ProofPartsExpressionBound: .db 1
                           .dw ProofSourceExpressionBound,ProofSourceExpressionBoundEnd
ProofPartsTypedByteBound:  .db 1
                           .dw ProofSourceTypedByteBound,ProofSourceTypedByteBoundEnd
ProofPartsTypedWordBound:  .db 1
                           .dw ProofSourceTypedWordBound,ProofSourceTypedWordBoundEnd
ProofPartsMaximumExtent:   .db 1
                           .dw ProofSourceMaximumExtent,ProofSourceMaximumExtentEnd
ProofPartsZero:            .db 1
                           .dw ProofSourceZero,ProofSourceZeroEnd
ProofPartsSignedBound:     .db 1
                           .dw ProofSourceSignedBound,ProofSourceSignedBoundEnd
ProofPartsNegative:        .db 1
                           .dw ProofSourceNegative,ProofSourceNegativeEnd
ProofPartsSpacedNegative:  .db 1
                           .dw ProofSourceSpacedNegative,ProofSourceSpacedNegativeEnd
ProofPartsNamedNegative:   .db 1
                           .dw ProofSourceNamedNegative,ProofSourceNamedNegativeEnd
ProofPartsStringCapacity:  .db 1
                           .dw ProofSourceStringCapacity,ProofSourceStringCapacityEnd
ProofPartsObjectCapacity:  .db 1
                           .dw ProofSourceObjectCapacity,ProofSourceObjectCapacityEnd
ProofPartsSuffixCapacity:  .db 1
                           .dw ProofSourceSuffixCapacity,ProofSourceSuffixCapacityEnd
ProofPartsInnerOpen:       .db 1
                           .dw ProofSourceInnerOpen,ProofSourceInnerOpenEnd
ProofPartsOpenElement:     .db 1
                           .dw ProofSourceOpenElement,ProofSourceOpenElementEnd
ProofPartsOwnedArray:      .db 1
                           .dw ProofSourceOwnedArray,ProofSourceOwnedArrayEnd
ProofPartsOwnedString:     .db 1
                           .dw ProofSourceOwnedString,ProofSourceOwnedStringEnd
ProofPartsDoubleOpen:      .db 1
                           .dw ProofSourceDoubleOpen,ProofSourceDoubleOpenEnd
ProofPartsBooleanBound:    .db 1
                           .dw ProofSourceBooleanBound,ProofSourceBooleanBoundEnd
ProofPartsBooleanConversion: .db 1
                           .dw ProofSourceBooleanConversion,ProofSourceBooleanConversionEnd
ProofPartsLeftBracket:     .db 1
                           .dw ProofSourceLeftBracket,ProofSourceLeftBracketEnd
ProofPartsRightBracket:    .db 1
                           .dw ProofSourceRightBracket,ProofSourceRightBracketEnd
ProofPartsUnknown:         .db 1
                           .dw ProofSourceUnknown,ProofSourceUnknownEnd
ProofPartsExpected:        .db 1
                           .dw ProofSourceExpected,ProofSourceExpectedEnd

ProofSourceString1: .db "string[1]"
ProofSourceString1End:
ProofSourceString2: .db "string[2]"
ProofSourceString2End:
ProofSourceString3: .db "string[3]"
ProofSourceString3End:
ProofSourceString4: .db "string[4]"
ProofSourceString4End:
ProofSourceString5: .db "string[5]"
ProofSourceString5End:
ProofSourceString6: .db "string[6]"
ProofSourceString6End:
ProofSourceString7: .db "string[7]"
ProofSourceString7End:
ProofSourceString8: .db "string[8]"
ProofSourceString8End:
ProofSourceString9: .db "string[9]"
ProofSourceString9End:
ProofPartsString1: .db 1
                   .dw ProofSourceString1,ProofSourceString1End
ProofPartsString2: .db 1
                   .dw ProofSourceString2,ProofSourceString2End
ProofPartsString3: .db 1
                   .dw ProofSourceString3,ProofSourceString3End
ProofPartsString4: .db 1
                   .dw ProofSourceString4,ProofSourceString4End
ProofPartsString5: .db 1
                   .dw ProofSourceString5,ProofSourceString5End
ProofPartsString6: .db 1
                   .dw ProofSourceString6,ProofSourceString6End
ProofPartsString7: .db 1
                   .dw ProofSourceString7,ProofSourceString7End
ProofPartsString8: .db 1
                   .dw ProofSourceString8,ProofSourceString8End
ProofPartsString9: .db 1
                   .dw ProofSourceString9,ProofSourceString9End
