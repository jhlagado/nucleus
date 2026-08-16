; First generated declaration-program escapes. These routines deliberately
; keep the provisional symbol invisible until the complete source line passes.

; The action program has just consumed the constant name. Reserve the
; provisional symbol with a harmless placeholder type and payload; its count
; remains unpublished until RewriteSymbolCommit.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteDeclarationBeginScalarConstant:
            LD   A,RewriteSymbolClassConstant
            LD   D,RewriteScalarTypeExact
            LD   BC,0
            JP   RewriteSymbolPrepareCurrent

; Normalize a completed integer constant back to the exact domain. Boolean is
; the sole retained scalar type; signed negative values retain only the exact
; negative metadata bit.
.routine in A,HL out A,carry,zero clobbers sign,parity,halfCarry,D
RewriteDeclarationInferConstantType:
            LD   D,A
            AND  RewriteTypeIdentityMask
            CP   RewriteScalarTypeBoolean
            RET  Z
            CP   RewriteScalarTypeI8
            JR   Z,_RewriteDeclarationInferI8
            CP   RewriteScalarTypeI16
            JR   Z,_RewriteDeclarationInferI16
            LD   A,D
            AND  RewriteTypeMetaNegative
            RET
_RewriteDeclarationInferI8:
            BIT  7,L
            JR   _RewriteDeclarationInferSign
_RewriteDeclarationInferI16:
            BIT  7,H
_RewriteDeclarationInferSign:
            LD   A,RewriteScalarTypeExact
            RET  Z
            LD   A,RewriteTypeMetaNegative
            RET

; Evaluate the scalar initializer, then complete the provisional entry in
; place. The next action instruction validates and consumes the newline before
; the entry becomes visible.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteDeclarationFinishScalarConstant:
            XOR  A
            CALL RewriteExpressionEvaluateConstant
            CALL RewriteDeclarationInferConstantType
            LD   D,A
            PUSH DE
            PUSH HL
            LD   A,(RewriteSymbolCount)
            CALL RewriteSymbolAddress
            LD   DE,RewriteSymbolType
            ADD  HL,DE
            POP  DE
            POP  BC
            LD   (HL),B
            INC  HL
            LD   (HL),E
            INC  HL
            LD   (HL),D
            XOR  A
            RET

; Assertions retain their keyword position because both a false assertion and
; a non-Boolean result are diagnosed at `assert`, not at the expression.
.routine out A,carry,zero clobbers sign,parity,halfCarry,HL
RewriteDeclarationBeginAssert:
            LD   HL,(TokenStartOffset)
            LD   (RewriteDeclarationAnchor),HL
            XOR  A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteDeclarationFinishAssert:
            LD   A,RewriteScalarTypeBoolean
            CALL RewriteExpressionEvaluateConstant
            LD   D,A
            LD   BC,(RewriteDeclarationAnchor)
            LD   (TokenStartOffset),BC
            AND  RewriteTypeIdentityMask
            CP   RewriteScalarTypeBoolean
            JR   NZ,_RewriteDeclarationAssertTypeFailure
            LD   A,H
            OR   L
            RET  NZ
            LD   A,DiagnosticAssertionFailed
            JP   RewriteRaiseDiagnostic
_RewriteDeclarationAssertTypeFailure:
            LD   A,DiagnosticTypeMismatch
            JP   RewriteRaiseDiagnostic

; Program variables use the same provisional publication rule as constants.
; The type and segment-relative payload are filled only after the complete type
; and initializer path succeeds.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteDeclarationBeginProgram:
            LD   A,RewriteSymbolClassProgram
            LD   D,RewriteScalarTypeExact
            LD   BC,0
            JP   RewriteSymbolPrepareCurrent

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteDeclarationParseOwnedType:
            CALL RewriteTypeParse
            CALL RewriteTypeRequireOwned
            LD   D,A
            LD   E,0
            PUSH DE
            LD   A,(RewriteSymbolCount)
            CALL RewriteSymbolAddress
            LD   DE,RewriteSymbolType
            ADD  HL,DE
            POP  BC
            LD   (HL),B
            XOR  A
            RET

; A is the explicit storage tag and DE the full segment-relative offset.
.routine in A,DE out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteDeclarationSetProgramStorage:
            PUSH AF
            PUSH DE
            LD   A,(RewriteSymbolCount)
            CALL RewriteSymbolAddress
            LD   DE,RewriteSymbolPayload
            ADD  HL,DE
            POP  BC
            LD   (HL),C
            INC  HL
            LD   (HL),B
            INC  HL
            POP  AF
            LD   (HL),A
            XOR  A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteDeclarationFinishProgramBss:
            LD   A,(RewriteCurrentType)
            CALL RewriteTypeStaticExtent
            JP   C,RewriteDeclarationProgramTypeFailure
            LD   B,H
            LD   C,L
            CALL RewriteStaticReserveBss
            LD   A,RewriteSymbolStorageBss
            JP   RewriteDeclarationSetProgramStorage

; Convert one constant initializer under the language's exact/same/widening
; compatibility rule. Carry from numeric conversion is a source range error;
; incompatible typed values are a type mismatch at the following token.
.routine in A,C,HL out A,C,HL,carry,zero clobbers sign,parity,halfCarry,D,E
RewriteDeclarationConvertConstant:
            LD   D,A
            AND  RewriteTypeIdentityMask
            CP   RewriteScalarTypeBoolean
            JR   Z,_RewriteDeclarationConvertBoolean
            OR   A
            JR   Z,_RewriteDeclarationConvertNumeric
            CP   C
            JR   Z,_RewriteDeclarationConvertNumeric
            CP   RewriteScalarTypeU8
            JR   NZ,_RewriteDeclarationConvertSignedByte
            LD   A,C
            CP   RewriteScalarTypeU16
            JR   Z,_RewriteDeclarationConvertNumeric
            CP   RewriteScalarTypeI16
            JR   Z,_RewriteDeclarationConvertNumeric
            JR   _RewriteDeclarationConvertTypeFailure
_RewriteDeclarationConvertSignedByte:
            CP   RewriteScalarTypeI8
            JR   NZ,_RewriteDeclarationConvertTypeFailure
            LD   A,C
            CP   RewriteScalarTypeI16
            JR   NZ,_RewriteDeclarationConvertTypeFailure
_RewriteDeclarationConvertNumeric:
            LD   A,D
            CALL RewriteExpressionConvertConstant
            JR   C,_RewriteDeclarationConvertRangeFailure
            RET
_RewriteDeclarationConvertBoolean:
            LD   A,C
            CP   RewriteScalarTypeBoolean
            JR   NZ,_RewriteDeclarationConvertTypeFailure
            LD   A,D
            OR   A
            RET
_RewriteDeclarationConvertTypeFailure:
            LD   A,DiagnosticTypeMismatch
            JP   RewriteRaiseDiagnostic
_RewriteDeclarationConvertRangeFailure:
            LD   HL,(RewriteExpressionAtomOffset)
            LD   (TokenStartOffset),HL
            LD   A,DiagnosticIntegerRange
            JP   RewriteRaiseDiagnostic

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteDeclarationFinishProgramScalar:
            LD   A,(RewriteCurrentType)
            CP   RewriteFirstOwnedTypeId
            JR   NC,RewriteDeclarationProgramTypeFailure
            LD   A,(RewriteCurrentType)
            CALL RewriteExpressionEvaluateConstant
            LD   D,A
            LD   A,(RewriteCurrentType)
            LD   C,A
            LD   A,D
            CALL RewriteDeclarationConvertConstant
            LD   (RewriteInitializerBase),HL
            LD   A,(RewriteCurrentType)
            CALL RewriteTypeStaticExtent
            JP   C,RewriteDeclarationProgramTypeFailure
            LD   B,H
            LD   C,L
            LD   HL,RewriteInitializerBase
            CALL RewriteStaticAppendInitialized
            LD   A,RewriteSymbolStorageInitialized
            JP   RewriteDeclarationSetProgramStorage

RewriteDeclarationProgramTypeFailure:
            LD   A,DiagnosticTypeMismatch
            JP   RewriteRaiseDiagnostic

; Record names occupy the shared provisional symbol entry, while fields use
; the independent field directory. The record type remains invisible until
; its closing `end` and newline have both passed.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteDeclarationBeginRecord:
            LD   A,RewriteSymbolClassRecordType
            LD   D,RewriteScalarTypeExact
            LD   BC,0
            CALL RewriteSymbolPrepareCurrent
            LD   A,(RewriteTypeCount)
            CP   RewriteOwnedTypeCapacity
            JP   NC,RewriteDeclarationTypeCapacityFailure
            CALL RewriteRecordBegin
            XOR  A
            LD   (RewriteCurrentRecordExtent),A
            LD   (RewriteCurrentRecordExtent+1),A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteDeclarationParseRecordFieldType:
            CALL RewriteTypeParse
            ; The frozen field diagnostic is anchored to the following token
            ; for both open-view forms. Other owning positions retain the
            ; shared parser's established open-array closing-bracket anchor.
            CP   RewriteOpenStringTypeId
            JP   Z,RewriteTypeBoundFailure
            BIT  7,A
            JP   NZ,RewriteTypeBoundFailure
            OR   A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteDeclarationFinishRecordField:
            LD   A,(RewriteCurrentType)
            CALL RewriteTypeStaticExtent
            JP   C,RewriteDeclarationProgramTypeFailure
            LD   DE,(RewriteCurrentRecordExtent)
            ADD  HL,DE
            JP   C,RewriteStaticProgramCapacityFailure
            CALL RewriteStaticCheckCapacity
            JP   C,RewriteStaticProgramCapacityFailure
            PUSH HL
            LD   A,(RewriteCurrentType)
            LD   BC,(RewriteCurrentRecordExtent)
            CALL RewriteFieldCommitCurrent
            POP  HL
            LD   (RewriteCurrentRecordExtent),HL
            XOR  A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteDeclarationFinishRecord:
            LD   A,(RewriteCurrentRecord)
            CALL RewriteRecordAddress
            INC  HL
            LD   A,(HL)
            OR   A
            JP   Z,RewriteRecordEmptyFailure
            LD   A,RewriteTypeKindRecord
            LD   (RewriteTypeCandidateKind),A
            LD   A,(RewriteCurrentRecord)
            LD   (RewriteTypeCandidateAux),A
            LD   HL,0
            LD   (RewriteTypeCandidateCount),HL
            LD   HL,(RewriteCurrentRecordExtent)
            LD   (RewriteTypeCandidateExtent),HL
            CALL RewriteTypeAppendNominal
            LD   C,A
            LD   A,(RewriteSymbolCount)
            CALL RewriteSymbolAddress
            LD   DE,RewriteSymbolType
            ADD  HL,DE
            LD   (HL),C
            JP   RewriteRecordCommit

; Aggregate constants and initialized aggregate program objects share the
; recursive initializer below. The destination segment is preflighted before
; the first initializer token is interpreted, so diagnostics 81 and 93 retain
; precedence over internal scratch/depth failures.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteDeclarationBeginAggregateConstant:
            LD   A,RewriteSymbolClassConstant
            LD   D,RewriteScalarTypeExact
            LD   BC,0
            JP   RewriteSymbolPrepareCurrent

.routine in HL out A,carry,zero clobbers sign,parity,halfCarry,DE,HL
RewriteDeclarationPreflightProgram:
            LD   DE,(RewriteStaticInitializedLength)
            ADD  HL,DE
            JP   C,RewriteStaticProgramCapacityFailure
            LD   DE,(RewriteStaticConstantLength)
            ADD  HL,DE
            JP   C,RewriteStaticProgramCapacityFailure
            CALL RewriteStaticCheckCapacity
            JP   C,RewriteStaticProgramCapacityFailure
            XOR  A
            RET

.routine in HL out A,carry,zero clobbers sign,parity,halfCarry,DE,HL
RewriteDeclarationPreflightReadOnly:
            LD   DE,(RewriteStaticInitializedLength)
            ADD  HL,DE
            JP   C,RewriteStaticReadOnlyCapacityFailure
            LD   DE,(RewriteStaticConstantLength)
            ADD  HL,DE
            JP   C,RewriteStaticReadOnlyCapacityFailure
            CALL RewriteStaticCheckCapacity
            JP   C,RewriteStaticReadOnlyCapacityFailure
            XOR  A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteDeclarationFinishAggregateConstant:
            LD   A,(RewriteCurrentType)
            CP   RewriteFirstOwnedTypeId
            JP   C,RewriteDeclarationProgramTypeFailure
            CALL RewriteTypeStaticExtent
            JP   C,RewriteDeclarationProgramTypeFailure
            PUSH HL
            CALL RewriteDeclarationPreflightReadOnly
            POP  HL
            PUSH HL
            LD   A,(RewriteCurrentType)
            CALL RewriteInitializerBuild
            POP  BC
            LD   HL,RewriteInitializerBase
            CALL RewriteStaticAppendConstant
            LD   A,RewriteSymbolStorageReadOnly
            JP   RewriteDeclarationSetProgramStorage

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteDeclarationFinishProgramAggregate:
            LD   A,(RewriteCurrentType)
            CP   RewriteFirstOwnedTypeId
            JP   C,RewriteDeclarationProgramTypeFailure
            CALL RewriteTypeStaticExtent
            JP   C,RewriteDeclarationProgramTypeFailure
            PUSH HL
            CALL RewriteDeclarationPreflightProgram
            POP  HL
            PUSH HL
            LD   A,(RewriteCurrentType)
            CALL RewriteInitializerBuild
            POP  BC
            LD   HL,RewriteInitializerBase
            CALL RewriteStaticAppendInitialized
            LD   A,RewriteSymbolStorageInitialized
            JP   RewriteDeclarationSetProgramStorage

; Build one complete object of exact type A. HL is its already-preflighted
; extent. Every recursive leaf advances RewriteInitializerLength by exactly
; its physical representation.
.routine in A,HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteInitializerBuild:
            PUSH AF
            PUSH HL
            CALL RewriteInitializerReset
            XOR  A
            LD   (RewriteInitializerDepth),A
            POP  HL
            POP  AF
            PUSH HL
            CALL RewriteInitializerParseType
            POP  DE
            LD   HL,(RewriteInitializerLength)
            OR   A
            SBC  HL,DE
            JP   NZ,RewriteInitializerInternalFailure
            XOR  A
            RET

RewriteInitializerInternalFailure:
            LD   A,DiagnosticInternalOperation
            JP   RewriteRaiseDiagnostic

RewriteInitializerShapeFailure:
            LD   A,DiagnosticInitializerShape
            JP   RewriteRaiseDiagnostic
RewriteInitializerCountFailure:
            LD   A,DiagnosticInitializerCount
            JP   RewriteRaiseDiagnostic
RewriteInitializerStringLengthFailure:
            LD   A,DiagnosticStringLength
            JP   RewriteRaiseDiagnostic
RewriteInitializerExpectedStringFailure:
            LD   A,DiagnosticExpectedStringLiteral
            JP   RewriteRaiseDiagnostic

; Parse one exact type-directed value at the current token. Open views and
; exact literals cannot reach this routine from an owning declaration.
.routine in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteInitializerParseType:
            CP   RewriteFirstOwnedTypeId
            JP   C,RewriteInitializerParseScalar
            PUSH AF
            CALL RewriteTypeAddress
            LD   A,(HL)
            POP  DE
            LD   E,D
            CP   RewriteTypeKindString
            JP   Z,RewriteInitializerParseString
            CP   RewriteTypeKindRecord
            JP   Z,RewriteInitializerParseRecord
            CP   RewriteTypeKindArray
            JP   Z,RewriteInitializerParseArray
            JP   RewriteInitializerShapeFailure

RewriteInitializerParseScalar:
            LD   C,A
            PUSH BC
            CALL RewriteExpressionEvaluateConstant
            POP  BC
            CALL RewriteDeclarationConvertConstant
            PUSH HL
            LD   A,C
            CALL RewriteTypeStaticExtent
            JP   C,RewriteInitializerInternalFailure
            PUSH HL
            LD   B,H
            LD   C,L
            CALL RewriteInitializerReserveZero
            LD   HL,RewriteInitializerBase
            ADD  HL,DE
            POP  DE
            POP  BC
            LD   (HL),C
            DEC  E
            RET  Z
            INC  HL
            LD   (HL),B
            XOR  A
            RET

; Consume and depth-check the opener in A. The diagnostic is deliberately the
; aggregate shape diagnostic rather than the generic action-token mismatch.
.routine in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteInitializerBeginComposite:
            LD   C,A
            PUSH BC
            CALL RewriteParserTake
            POP  BC
            CP   C
            JP   NZ,RewriteInitializerShapeFailure
            LD   A,(RewriteInitializerDepth)
            CP   RewriteInitializerDepthCapacity
            JP   NC,RewriteInitializerCapacityFailure
            INC  A
            LD   (RewriteInitializerDepth),A
            XOR  A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,HL
RewriteInitializerLeaveComposite:
            LD   HL,RewriteInitializerDepth
            DEC  (HL)
            XOR  A
            RET

; B is the required closer and C the other aggregate closer. Too few/many
; elements are count errors; the wrong delimiter family is a shape error.
.routine in B,C out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteInitializerFinishComposite:
            PUSH BC
            CALL RewriteParserPeek
            POP  BC
            CP   B
            JR   Z,_RewriteInitializerTakeClose
            CP   C
            JP   Z,RewriteInitializerShapeFailure
            JP   RewriteInitializerCountFailure
_RewriteInitializerTakeClose:
            CALL RewriteParserTake
            JP   RewriteInitializerLeaveComposite

; Expect a comma while more declared components remain. Seeing the proper
; closer early is a count error; every other token is a shape error.
.routine in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteInitializerExpectComma:
            LD   C,A
            PUSH BC
            CALL RewriteParserPeek
            POP  BC
            CP   C
            JP   Z,RewriteInitializerCountFailure
            CP   TokenComma
            JP   NZ,RewriteInitializerShapeFailure
            JP   RewriteParserTake

RewriteInitializerParseRecord:
            LD   A,E
            CALL RewriteTypeAddress
            INC  HL
            LD   A,(HL)
            CALL RewriteRecordAddress
            LD   B,(HL)
            INC  HL
            LD   C,(HL)
            LD   A,TokenLeftParen
            PUSH BC
            CALL RewriteInitializerBeginComposite
            POP  BC
_RewriteInitializerRecordLoop:
            PUSH BC
            LD   A,B
            CALL RewriteFieldAddress
            LD   DE,RewriteFieldType
            ADD  HL,DE
            LD   A,(HL)
            CALL RewriteInitializerParseType
            POP  BC
            INC  B
            DEC  C
            JR   Z,_RewriteInitializerRecordClose
            LD   A,TokenRightParen
            PUSH BC
            CALL RewriteInitializerExpectComma
            POP  BC
            JR   _RewriteInitializerRecordLoop
_RewriteInitializerRecordClose:
            LD   B,TokenRightParen
            LD   C,TokenRightBracket
            JP   RewriteInitializerFinishComposite

RewriteInitializerParseArray:
            LD   A,E
            CALL RewriteTypeAddress
            INC  HL
            LD   C,(HL)
            INC  HL
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            LD   A,TokenLeftBracket
            PUSH BC
            PUSH DE
            CALL RewriteInitializerBeginComposite
            POP  DE
            POP  BC
_RewriteInitializerArrayLoop:
            PUSH BC
            PUSH DE
            LD   A,C
            CALL RewriteInitializerParseType
            POP  DE
            POP  BC
            DEC  DE
            LD   A,D
            OR   E
            JR   Z,_RewriteInitializerArrayClose
            PUSH BC
            PUSH DE
            LD   A,TokenRightBracket
            CALL RewriteInitializerExpectComma
            POP  DE
            POP  BC
            JR   _RewriteInitializerArrayLoop
_RewriteInitializerArrayClose:
            LD   B,TokenRightBracket
            LD   C,TokenRightParen
            JP   RewriteInitializerFinishComposite

RewriteInitializerParseString:
            LD   A,E
            CALL RewriteTypeAddress
            INC  HL
            INC  HL
            LD   B,(HL)
            PUSH BC
            CALL RewriteParserTake
            POP  BC
            CP   TokenStringLiteral
            JP   NZ,RewriteInitializerExpectedStringFailure
            LD   A,(TokenLength)
            CP   B
            JP   C,_RewriteInitializerStringLengthReady
            JP   NZ,RewriteInitializerStringLengthFailure
_RewriteInitializerStringLengthReady:
            LD   C,B
            LD   B,0
            INC  BC
            INC  BC
            CALL RewriteInitializerReserveZero
            LD   HL,RewriteInitializerBase
            ADD  HL,DE
            EX   DE,HL
            LD   A,(TokenLength)
            LD   (DE),A
            INC  DE
            LD   C,A
            OR   A
            RET  Z
            LD   HL,(TokenLexemePointer)
            INC  HL
_RewriteInitializerStringDecodeLoop:
            PUSH BC
            PUSH DE
            CALL RewriteInitializerDecodeLiteralByte
            POP  DE
            POP  BC
            LD   (DE),A
            INC  DE
            DEC  C
            JR   NZ,_RewriteInitializerStringDecodeLoop
            XOR  A
            RET

; Decode one already-validated source spelling byte from HL. The tokenizer has
; established lexical validity; this pure pointer walk does not disturb the
; source adapter or parser token cache.
.routine in HL out A,HL,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,IX,IY
RewriteInitializerDecodeLiteralByte:
            LD   A,(HL)
            INC  HL
            CP   "\\"
            RET  NZ
            LD   A,(HL)
            INC  HL
            CP   "x"
            JR   Z,_RewriteInitializerDecodeHex
            PUSH HL
            LD   HL,RewriteStringEscapeTable
            LD   B,RewriteStringEscapeCount
_RewriteInitializerDecodeEscapeLoop:
            CP   (HL)
            INC  HL
            JR   Z,_RewriteInitializerDecodeEscapeFound
            INC  HL
            DJNZ _RewriteInitializerDecodeEscapeLoop
            POP  HL
            JP   RewriteInitializerInternalFailure
_RewriteInitializerDecodeEscapeFound:
            LD   A,(HL)
            POP  HL
            RET
_RewriteInitializerDecodeHex:
            LD   A,(HL)
            INC  HL
            CALL RewriteTokenHexDigit
            RLCA
            RLCA
            RLCA
            RLCA
            LD   D,A
            LD   A,(HL)
            INC  HL
            CALL RewriteTokenHexDigit
            OR   D
            RET
