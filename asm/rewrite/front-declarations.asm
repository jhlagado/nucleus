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

; Generated routine-header actions. The regular keyword/name shell remains in
; generated action data; this escape handles the genuinely iterative formal
; list and its optional result/effect suffix without a second grammar engine.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteDeclarationFinishDirectRoutineHeader:
            LD   D,0
            JR   RewriteDeclarationFinishRoutineHeader

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteDeclarationFinishForwardRoutineHeader:
            LD   D,RewriteRoutineFlagIncomplete

.routine in D out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteDeclarationFinishRoutineHeader:
            LD   A,D
            LD   (RewritePendingRoutineFlags),A
            CALL RewriteNameEqualsMain
            JP   C,RewriteDeclarationFinishMainHeader
            LD   B,RewriteScalarTypeExact
            LD   A,(RewriteRoutineCount)
            LD   C,A
            LD   A,(RewritePendingRoutineFlags)
            LD   D,A
            CALL RewriteRoutineDeclareBeginCurrent
            CALL RewriteDeclarationParseParameterList
            CALL RewriteDeclarationParseResultAndFails
            CALL RewriteDeclarationPublishRoutineHeader
            JP   RewriteDeclarationExpectHeaderNewline

; Main has the fixed empty data signature. The main lifecycle remains outside
; the four-entry ordinary routine directory and retains only the fails effect.
RewriteDeclarationFinishMainHeader:
            LD   DE,(TokenLexemePointer)
            LD   A,(TokenLength)
            LD   B,A
            PUSH BC
            PUSH DE
            LD   A,TokenLeftParen
            LD   C,DiagnosticExpectedLeft
            CALL RewriteDeclarationTakeExpected
            LD   A,TokenRightParen
            LD   C,DiagnosticExpectedRight
            CALL RewriteDeclarationTakeExpected
            CALL RewriteParserPeek
            CP   TokenAs
            JP   Z,RewriteDeclarationMainResultFailure
            CP   TokenFails
            JR   NZ,_RewriteDeclarationMainFlagsReady
            CALL RewriteParserTake
            LD   A,(RewritePendingRoutineFlags)
            OR   RewriteRoutineFlagFails
            LD   (RewritePendingRoutineFlags),A
_RewriteDeclarationMainFlagsReady:
            CALL RewriteDeclarationExpectHeaderNewline
            POP  DE
            POP  BC
            LD   (TokenLexemePointer),DE
            LD   A,B
            LD   (TokenLength),A
            LD   A,(RewritePendingRoutineFlags)
            LD   D,A
            AND  RewriteRoutineFlagIncomplete
            JP   NZ,RewriteMainBeginForwardCurrent
            JP   RewriteMainBeginCurrent

RewriteDeclarationMainResultFailure:
            LD   A,DiagnosticExpectedLine
            JP   RewriteRaiseDiagnostic

; A expected private token, C published diagnostic.
.routine in A,C out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteDeclarationTakeExpected:
            LD   B,A
            PUSH BC
            CALL RewriteParserTake
            POP  BC
            CP   B
            RET  Z
            LD   A,C
            JP   RewriteRaiseDiagnostic

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteDeclarationParseParameterList:
            LD   A,TokenLeftParen
            LD   C,DiagnosticExpectedLeft
            CALL RewriteDeclarationTakeExpected
            CALL RewriteParserPeek
            CP   TokenRightParen
            JR   Z,_RewriteDeclarationParameterListClose
_RewriteDeclarationParameterLoop:
            CALL RewriteParserTake
            CP   TokenName
            JP   NZ,RewriteDeclarationExpectedNameFailure
            LD   HL,(TokenStartOffset)
            PUSH HL
            LD   DE,(TokenLexemePointer)
            LD   A,(TokenLength)
            LD   B,A
            PUSH BC
            PUSH DE
            LD   A,TokenAs
            LD   C,DiagnosticExpectedAs
            CALL RewriteDeclarationTakeExpected
            CALL RewriteTypeParse
            LD   (RewritePendingParameterType),A
            POP  DE
            POP  BC
            POP  HL
            LD   (TokenStartOffset),HL
            LD   (TokenLexemePointer),DE
            LD   A,B
            LD   (TokenLength),A
            LD   A,(RewritePendingParameterType)
            CALL RewriteParameterDeclareCurrent
            CALL RewriteParserPeek
            CP   TokenRightParen
            JR   Z,_RewriteDeclarationParameterListClose
            LD   A,TokenComma
            LD   C,DiagnosticInitializerShape
            CALL RewriteDeclarationTakeExpected
            JR   _RewriteDeclarationParameterLoop
_RewriteDeclarationParameterListClose:
            LD   A,TokenRightParen
            LD   C,DiagnosticExpectedRight
            JP   RewriteDeclarationTakeExpected

RewriteDeclarationExpectedNameFailure:
            LD   A,DiagnosticExpectedName
            JP   RewriteRaiseDiagnostic

; The result defaults to no value (exact/zero). The optional fails flag follows
; the optional result and is retained in the same directory flag byte.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteDeclarationParseResultAndFails:
            XOR  A
            LD   (RewriteForwardParameterType),A
            CALL RewriteParserPeek
            CP   TokenAs
            JR   NZ,_RewriteDeclarationResultReady
            CALL RewriteParserTake
            CALL RewriteTypeParse
            CALL RewriteTypeRequireOwned
            LD   (RewriteForwardParameterType),A
_RewriteDeclarationResultReady:
            CALL RewriteParserPeek
            CP   TokenFails
            RET  NZ
            CALL RewriteParserTake
            LD   A,(RewritePendingRoutineFlags)
            OR   RewriteRoutineFlagFails
            LD   (RewritePendingRoutineFlags),A
            XOR  A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteDeclarationPublishRoutineHeader:
            LD   A,(RewriteCurrentRoutine)
            CALL RewriteRoutineAddress
            LD   DE,RewriteRoutineResultType
            ADD  HL,DE
            LD   A,(RewriteForwardParameterType)
            LD   (HL),A
            INC  HL
            INC  HL
            LD   A,(RewritePendingRoutineFlags)
            LD   (HL),A
            AND  RewriteRoutineFlagIncomplete
            JP   NZ,RewriteRoutineCommit
            LD   A,(RewritePendingRoutineFlags)
            LD   (RewriteCurrentRoutineFlags),A
            LD   A,(RewriteForwardParameterType)
            LD   (RewriteCurrentRoutineResultType),A
            CALL RewriteRoutinePublish
            JP   RewriteRoutineBeginBody

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteDeclarationExpectHeaderNewline:
            LD   A,TokenNewline
            LD   C,DiagnosticExpectedLine
            JP   RewriteDeclarationTakeExpected

; An abbreviated body has no second signature. Opening it clears the retained
; incomplete bit and republishes the original parameter spellings into the new
; routine scope.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteDeclarationOpenForwardBody:
            CALL RewriteNameEqualsMain
            JP   C,RewriteMainOpenForwardCurrent
            CALL RewriteRoutineOpenForwardCurrent
            JP   RewriteRoutineInstallForwardParameters

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteDeclarationRequireComplete:
            JP   RewriteRoutineRequireComplete

; Default scalar locals are the declaration half of the R3/R4 boundary. R3
; owns name/type/layout publication and the exact zero-initialization records;
; R4 will add the runtime-expression path without changing this lifecycle.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteDeclarationBeginLocal:
            CALL RewriteDeclarationRejectCurrent
            LD   A,(RewriteCurrentLocalOffset)
            LD   C,A
            LD   B,0
            LD   D,RewriteScalarTypeExact
            LD   A,RewriteSymbolClassLocal
            CALL RewriteSymbolPrepareCurrent
            LD   A,RewriteSymbolStorageActivation
            JP   RewriteSymbolSetStorageCurrent

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteDeclarationParseLocalScalarType:
            ; Retain the first type token because concrete aggregates and
            ; string[] use the frozen expected-type anchor there. An open
            ; array instead retains its closing bracket as the grammar's
            ; unexpected continuation.
            CALL RewriteParserPeek
            LD   HL,(TokenStartOffset)
            LD   (RewriteDeclarationAnchor),HL
            CALL RewriteTypeParse
            BIT  7,A
            JR   NZ,RewriteDeclarationLocalOpenArrayFailure
            CP   RewriteFirstOwnedTypeId
            JP   NC,RewriteDeclarationLocalTypeFailure
            OR   A
            JP   Z,RewriteDeclarationLocalTypeFailure
            LD   (RewriteCurrentType),A
            LD   C,A
            LD   A,(RewriteSymbolCount)
            CALL RewriteSymbolAddress
            LD   DE,RewriteSymbolType
            ADD  HL,DE
            LD   (HL),C
            LD   A,C
            CALL RewriteTypeStaticExtent
            JP   C,RewriteDeclarationLocalTypeFailure
            LD   A,(RewriteCurrentLocalOffset)
            LD   (RewriteSemanticOperandArea),A
            LD   A,L
            CP   2
            LD   A,RewriteSemanticDeclareLocalU8
            JR   NZ,_RewriteDeclarationEmitLocalDeclare
            LD   A,RewriteSemanticDeclareLocal16
_RewriteDeclarationEmitLocalDeclare:
            LD   HL,RewriteSemanticOperandArea
            JP   RewriteSemanticAppend

RewriteDeclarationLocalTypeFailure:
            ; The frozen compiler classifies a non-scalar local declaration
            ; as an invalid declared type, not as a scalar-expression fault.
            LD   HL,(RewriteDeclarationAnchor)
            LD   (TokenStartOffset),HL
            LD   A,DiagnosticExpectedType
            JP   RewriteRaiseDiagnostic

RewriteDeclarationLocalOpenArrayFailure:
            LD   HL,(RewriteSuffixOpenOffset)
            ; A local's scalar grammar stops at the opening bracket; the
            ; general type parser retained the following closing bracket.
            DEC  HL
            LD   (TokenStartOffset),HL
            LD   A,DiagnosticExpectedLine
            JP   RewriteRaiseDiagnostic

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteDeclarationEmitDefaultLocal:
            XOR  A
            LD   (RewriteSemanticOperandArea),A
            LD   (RewriteSemanticOperandArea+1),A
            LD   A,RewriteSemanticLiteral16
            LD   HL,RewriteSemanticOperandArea
            CALL RewriteSemanticAppend

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteDeclarationEmitLocalStore:
            LD   A,(RewriteCurrentLocalOffset)
            LD   (RewriteSemanticOperandArea),A
            LD   A,(RewriteCurrentType)
            CALL RewriteTypeStaticExtent
            JP   C,RewriteDeclarationLocalTypeFailure
            LD   A,L
            CP   2
            LD   A,RewriteSemanticStoreLocalU8
            JR   NZ,_RewriteDeclarationEmitLocalStore
            LD   A,RewriteSemanticStoreLocal16
_RewriteDeclarationEmitLocalStore:
            LD   HL,RewriteSemanticOperandArea
            JP   RewriteSemanticAppend

; Runtime atoms are the first R4 consumer. The action program keeps the local
; provisional until the following newline and store emission both succeed.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteDeclarationFinishRuntimeLocalExpression:
            LD   A,(RewriteCurrentType)
            CALL RewriteExpressionEvaluateRuntime
            LD   (RewriteExpressionRightMeta),A
            PUSH DE
            PUSH HL
            CALL RewriteParserPeek
            POP  HL
            POP  DE
            LD   A,(RewriteExpressionRightMeta)
            LD   B,A
            LD   A,(RewriteCurrentType)
            LD   C,A
            LD   A,B
            CALL RewriteExpressionCheckRuntimeAssignable
            JP   RewriteCallConsumeLocalFailure

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteDeclarationCommitLocal:
            LD   A,(RewriteCurrentType)
            CALL RewriteTypeStaticExtent
            JP   C,RewriteDeclarationLocalTypeFailure
            LD   A,(RewriteCurrentLocalOffset)
            ADD  A,L
            JP   C,RewriteDeclarationLocalCapacityFailure
            LD   (RewriteCurrentLocalOffset),A
            JP   RewriteSymbolCommit

RewriteDeclarationLocalCapacityFailure:
            LD   A,DiagnosticSymbolCapacity
            JP   RewriteRaiseDiagnostic
