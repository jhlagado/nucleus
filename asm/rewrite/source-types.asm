; Shared source-type parser for declarations, parameters, fields, and results.
;
; Array suffixes are collected outermost-first and applied in reverse, so the
; source spelling u8[3][2] forms three elements of the exact u8[2] row type.
; Open views remain type metadata: no source or compiler address bit is used.

; Parse one complete source type. On success A is the exact scalar, owned
; composite, or parameter-only open-view identity. The first following token
; remains cached in the parser lookahead.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteTypeParse:
            CALL RewriteSuffixBegin
            CALL RewriteParserTake
            CP   TokenU8
            JR   Z,_RewriteTypeBaseU8
            CP   TokenU16
            JR   Z,_RewriteTypeBaseU16
            CP   TokenI8
            JR   Z,_RewriteTypeBaseI8
            CP   TokenI16
            JR   Z,_RewriteTypeBaseI16
            CP   TokenBoolean
            JR   Z,_RewriteTypeBaseBoolean
            CP   TokenString
            JR   Z,_RewriteTypeParseString
            CP   TokenName
            JP   NZ,RewriteTypeExpectedFailure
            CALL RewriteSymbolFindCurrent
            JP   NC,RewriteTypeUnknownFailure
            LD   DE,RewriteSymbolClass
            ADD  HL,DE
            LD   A,(HL)
            CP   RewriteSymbolClassRecordType
            JP   NZ,RewriteTypeBoundFailure
            INC  HL
            LD   A,(HL)
            JR   _RewriteTypeBaseReady
_RewriteTypeBaseU8:
            LD   A,RewriteScalarTypeU8
            JR   _RewriteTypeBaseReady
_RewriteTypeBaseU16:
            LD   A,RewriteScalarTypeU16
            JR   _RewriteTypeBaseReady
_RewriteTypeBaseI8:
            LD   A,RewriteScalarTypeI8
            JR   _RewriteTypeBaseReady
_RewriteTypeBaseI16:
            LD   A,RewriteScalarTypeI16
            JR   _RewriteTypeBaseReady
_RewriteTypeBaseBoolean:
            LD   A,RewriteScalarTypeBoolean
_RewriteTypeBaseReady:
            LD   (RewriteCurrentType),A
_RewriteTypeSuffixLoop:
            CALL RewriteParserPeek
            CP   TokenLeftBracket
            JP   NZ,RewriteTypeFinishSuffixes
            CALL RewriteParserTake
            CALL RewriteParserPeek
            CP   TokenRightBracket
            JR   NZ,_RewriteTypeConcreteSuffix
            CALL RewriteParserTake
            LD   A,(RewriteCurrentType)
            CALL RewriteTypeRejectOpenCurrent
            LD   HL,(TokenStartOffset)
            CALL RewriteSuffixSetOpen
            JR   _RewriteTypeSuffixLoop
_RewriteTypeConcreteSuffix:
            CALL RewriteTypeParseBound
            LD   A,(RewriteCurrentType)
            CALL RewriteTypeRejectOpenCurrent
            LD   DE,(TokenStartOffset)
            CALL RewriteSuffixAppend
            JR   _RewriteTypeSuffixLoop

_RewriteTypeParseString:
            CALL RewriteParserTake
            CP   TokenLeftBracket
            JP   NZ,RewriteTypeExpectedLeftBracketFailure
            CALL RewriteParserPeek
            CP   TokenRightBracket
            JR   NZ,_RewriteTypeParseConcreteString
            CALL RewriteParserTake
            LD   A,RewriteOpenStringTypeId
            JR   _RewriteTypeBaseReady
_RewriteTypeParseConcreteString:
            CALL RewriteTypeParseBound
            LD   A,H
            OR   A
            JP   NZ,RewriteTypeStringCapacityFailure
            LD   A,L
            CP   254
            JP   NC,RewriteTypeStringCapacityFailure
            LD   A,RewriteTypeKindString
            LD   (RewriteTypeCandidateKind),A
            XOR  A
            LD   (RewriteTypeCandidateAux),A
            LD   (RewriteTypeCandidateCount),HL
            INC  HL
            INC  HL
            LD   (RewriteTypeCandidateExtent),HL
            CALL RewriteTypeInternStructural
            JR   _RewriteTypeBaseReady

; A bound is a constant expression assignable to u16, followed by `]`.
; Successful return keeps the positive word in HL and anchors TokenStartOffset
; to the closing bracket for later extent/capacity diagnostics.
.routine out A,HL,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,IX,IY
RewriteTypeParseBound:
            CALL RewriteParserPeek
            LD   B,A
            PUSH BC
            LD   A,RewriteScalarTypeU16
            CALL RewriteExpressionEvaluateConstant
            LD   (RewriteSuffixResumeOffset),DE
            LD   D,A
            PUSH DE
            PUSH HL
            CALL RewriteParserTake
            CP   TokenRightBracket
            JP   NZ,RewriteTypeExpectedRightBracketFailureSaved
            POP  HL
            POP  DE
            POP  BC
            LD   E,B
            LD   A,D
            AND  RewriteTypeIdentityMask
            CP   RewriteScalarTypeBoolean
            JP   Z,RewriteTypeMismatchFailure
            CP   RewriteScalarTypeI8
            JP   Z,RewriteTypeMismatchFailure
            CP   RewriteScalarTypeI16
            JP   Z,RewriteTypeMismatchFailure
            LD   A,D
            LD   C,RewriteScalarTypeU16
            PUSH DE
            CALL RewriteExpressionConvertConstant
            POP  DE
            JR   NC,_RewriteTypeBoundConverted
            LD   A,D
            AND  RewriteTypeMetaNegative
            OR   A
            JP   Z,RewriteTypeRangeFailure
            LD   A,E
            CP   TokenPlus
            JR   Z,_RewriteTypeRangeAtOperand
            CP   TokenMinus
            JR   Z,_RewriteTypeRangeAtOperand
            CP   TokenLeftParen
            JR   Z,_RewriteTypeRangeAtOperand
            LD   HL,(RewriteSuffixResumeOffset)
            JR   _RewriteTypeRangePublish
_RewriteTypeRangeAtOperand:
            LD   HL,(RewriteExpressionRightOffset)
_RewriteTypeRangePublish:
            LD   (TokenStartOffset),HL
            JP   RewriteTypeRangeFailure
_RewriteTypeBoundConverted:
            LD   A,H
            OR   L
            JP   Z,RewriteTypeBoundFailure
            OR   A
            RET
RewriteTypeExpectedRightBracketFailureSaved:
            POP  HL
            POP  DE
            POP  BC
            LD   A,DiagnosticExpectedRightBracket
            JP   RewriteRaiseDiagnostic

; Apply concrete suffixes from innermost to outermost, restoring the live
; lookahead position afterwards. Then add the optional outer open-array view.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteTypeFinishSuffixes:
            LD   HL,(TokenStartOffset)
            LD   (RewriteSuffixResumeOffset),HL
            LD   A,(RewriteSuffixCount)
            OR   A
            JR   Z,_RewriteTypeFinishOpen
            LD   B,A
            CALL RewriteSuffixAddress
_RewriteTypeFinishLoop:
            LD   DE,RewriteSuffixEntrySize
            OR   A
            SBC  HL,DE
            PUSH BC
            PUSH HL
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            INC  HL
            LD   C,(HL)
            INC  HL
            LD   B,(HL)
            LD   (TokenStartOffset),BC
            EX   DE,HL
            CALL RewriteTypeWrapArrayCurrent
            POP  HL
            POP  BC
            DJNZ _RewriteTypeFinishLoop
            LD   HL,(RewriteSuffixResumeOffset)
            LD   (TokenStartOffset),HL
_RewriteTypeFinishOpen:
            LD   A,(RewriteSuffixOpen)
            OR   A
            JR   Z,_RewriteTypeFinishReady
            LD   A,(RewriteCurrentType)
            CALL RewriteTypeMakeOpenArray
            JP   C,RewriteTypeBoundFailure
            LD   (RewriteCurrentType),A
_RewriteTypeFinishReady:
            LD   A,(RewriteCurrentType)
            OR   A
            RET

; HL is a positive element count. The current exact type becomes one concrete
; array descriptor. Extents above the published one-KiB object boundary fail
; at the suffix's closing bracket, before any declaration storage is changed.
.routine in HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteTypeWrapArrayCurrent:
            LD   (RewriteTypeCandidateCount),HL
            LD   B,H
            LD   C,L
            LD   A,(RewriteCurrentType)
            CALL RewriteTypeStaticExtent
            JP   C,RewriteTypeBoundFailure
            LD   D,H
            LD   E,L
            LD   HL,0
_RewriteTypeExtentLoop:
            ADD  HL,DE
            JP   C,RewriteTypeProgramCapacityFailure
            LD   A,H
            CP   4
            JR   C,_RewriteTypeExtentAdmitted
            JR   NZ,RewriteTypeProgramCapacityFailure
            LD   A,L
            OR   A
            JP   NZ,RewriteTypeProgramCapacityFailure
_RewriteTypeExtentAdmitted:
            DEC  BC
            LD   A,B
            OR   C
            JR   NZ,_RewriteTypeExtentLoop
            LD   (RewriteTypeCandidateExtent),HL
            LD   A,(RewriteCurrentType)
            LD   (RewriteTypeCandidateAux),A
            LD   A,RewriteTypeKindArray
            LD   (RewriteTypeCandidateKind),A
            CALL RewriteTypeInternStructural
            LD   (RewriteCurrentType),A
            OR   A
            RET

; Reject an open base before another suffix is retained.
.routine in A out A,carry,zero clobbers sign,parity,halfCarry
RewriteTypeRejectOpenCurrent:
            CP   RewriteOpenStringTypeId
            JP   Z,RewriteTypeBoundFailure
            BIT  7,A
            JP   NZ,RewriteTypeBoundFailure
            OR   A
            RET

; Owning/result positions reject open arrays at their retained closing bracket;
; string[] retains the historical following-token anchor.
.routine in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteTypeRequireOwned:
            CP   RewriteOpenStringTypeId
            JP   Z,RewriteTypeBoundFailure
            BIT  7,A
            RET  Z
            LD   HL,(RewriteSuffixOpenOffset)
            LD   (TokenStartOffset),HL
            JP   RewriteTypeBoundFailure

RewriteTypeExpectedFailure:
            LD   A,DiagnosticExpectedType
            JP   RewriteRaiseDiagnostic
RewriteTypeExpectedLeftBracketFailure:
            LD   A,DiagnosticExpectedLeftBracket
            JP   RewriteRaiseDiagnostic
RewriteTypeMismatchFailure:
            LD   A,DiagnosticTypeMismatch
            JP   RewriteRaiseDiagnostic
RewriteTypeRangeFailure:
            LD   A,DiagnosticIntegerRange
            JP   RewriteRaiseDiagnostic
RewriteTypeBoundFailure:
            LD   A,DiagnosticTypeBound
            JP   RewriteRaiseDiagnostic
RewriteTypeUnknownFailure:
            LD   A,DiagnosticUnknownName
            JP   RewriteRaiseDiagnostic
RewriteTypeStringCapacityFailure:
            LD   A,DiagnosticStringCapacity
            JP   RewriteRaiseDiagnostic
RewriteTypeProgramCapacityFailure:
            LD   A,DiagnosticProgramDataCapacity
            JP   RewriteRaiseDiagnostic
