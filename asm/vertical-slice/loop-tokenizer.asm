; Tokenizer subset for the scalar-local, counted-loop, and array proofs.

.routine out A,carry,zero,HL clobbers sign,parity,halfCarry,BC,DE
TokenRecordStart:
.if NativeStreamingSource
            CALL SourcePinResetToken
.endif
            LD   HL,SourceOffset
            LD   DE,TokenStartOffset
            LD   BC,8
            LDIR
            JR   SourcePeek

.routine in A out A,carry clobbers zero,sign,parity,halfCarry,C
TokenIsLetter:
            LD   C,A
            OR   $20
            SUB  "a"
            CP   26
            LD   A,C
            RET

.routine in A out carry clobbers zero,sign,parity,halfCarry,A,C
TokenIsNameByte:
            CALL TokenIsLetter
            RET  C
            ADD  A,256-"_"
            RET  Z
            ADD  A,"_"-"0"
            CP   10
            RET

.routine in B,HL out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
TokenNameEquals:
            LD   A,(TokenLength)
            XOR  B
            RET  NZ
            LD   DE,(TokenLexemePointer)
TokenNameEqualsLoop:
            LD   A,(DE)
            XOR  (HL)
            RET  NZ
            INC  DE
            INC  HL
            DJNZ TokenNameEqualsLoop
            SCF
            RET

; Compare the current NAME token with the retained name record at HL. The
; record begins with a pointer word followed by a one-byte length.
.if NativeStreamingSource
; The record word is an opaque provider handle rather than a source pointer.
.routine in BC,HL out A,carry,zero clobbers sign,parity,halfCarry,DE
TokenNameRecordEquals:
            PUSH BC
            PUSH HL
            PUSH IX
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            INC  HL
            LD   A,(TokenLength)
            XOR  (HL)
            JP   Z,NativeTokenNameRecordLengthReady
            POP  IX
            POP  HL
            POP  BC
            RET
NativeTokenNameRecordLengthReady:
            LD   B,(HL)
            EX   DE,HL
            CALL SourceHostCompareCurrentName
            POP  IX
            POP  HL
            POP  BC
            RET  NZ
            SCF
            RET
.else
.routine in BC,HL out A,carry,zero clobbers sign,parity,halfCarry,DE
TokenNameRecordEquals:
            PUSH BC
            PUSH HL
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            INC  HL
            LD   B,(HL)
            EX   DE,HL
            CALL TokenNameEquals
            POP  HL
            POP  BC
            RET
.endif

; Store the current NAME token's pointer and length in the three-byte record
; at HL. HL returns at the length byte, matching the former inline sequences.
.if NativeStreamingSource
.routine in HL out A,BC,HL clobbers carry,zero,sign,parity,halfCarry
TokenRetainNameAtHL:
            PUSH DE
            PUSH HL
            LD   HL,(TokenLexemePointer)
            LD   A,(TokenLength)
            LD   B,A
            LD   A,(SourcePartId)
            LD   C,A
            LD   DE,(TokenStartOffset)
            CALL SourceHostRetainCurrentName
            LD   B,H
            LD   C,L
            POP  HL
            LD   (HL),C
            INC  HL
            LD   (HL),B
            INC  HL
            LD   A,(TokenLength)
            LD   (HL),A
            POP  DE
            RET
.else
.routine in HL out A,BC,HL clobbers carry,zero,sign,parity,halfCarry
TokenRetainNameAtHL:
            LD   BC,(TokenLexemePointer)
            LD   (HL),C
            INC  HL
            LD   (HL),B
            INC  HL
            LD   A,(TokenLength)
            LD   (HL),A
            RET
.endif

.routine in B out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
TokenScanName:
            ; The sole entry follows the exhausted punctuation DJNZ, so B=0.
.if NativeStreamingSource
            CALL SourcePinBeginToken
.endif
TokenScanNameLoop:
            CALL SourcePeek
            JR   C,TokenScanNameDone
            CALL TokenIsNameByte
            JR   NC,TokenScanNameDone
            CALL SourceTake
            INC  B
            JP   Z,TokenLexicalFailure
            JR   TokenScanNameLoop
TokenScanNameDone:
.if NativeStreamingSource
            CALL SourcePinFinishToken
.endif
            LD   A,B
            LD   C,B
            LD   (TokenLength),A
            SUB  2
            CP   7
            JR   NC,TokenScanNameDefault
            LD   E,A
            LD   D,0
            LD   HL,KeywordLengthOffsets
            ADD  HL,DE
            LD   E,(HL)
            ADD  HL,DE
TokenScanKeyword:
            LD   B,C
            LD   DE,(TokenLexemePointer)
TokenScanKeywordByte:
            LD   A,(DE)
            CP   (HL)
            JR   NZ,TokenScanKeywordSkip
            INC  DE
            INC  HL
            DJNZ TokenScanKeywordByte
            LD   A,(HL)
            JP   TokenFinish
TokenScanKeywordSkip:
            LD   E,B
            LD   D,0
            ADD  HL,DE
            BIT  7,(HL)
            INC  HL
            JR   Z,TokenScanKeyword
TokenScanNameDefault:
            CALL TokenFinishInline
            .db  TokenName

; Scan one or more decimal digits and reject a value above 65535. BC carries
; the exact unsigned literal payload to the predictive parser.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
TokenScanNumber:
            LD   H,B                     ; B=0 after punctuation exhaustion
            LD   L,B
TokenScanNumberLoop:
            PUSH HL
            CALL SourcePeek
            POP  HL
            JR   C,TokenScanNumberEof
            CP   "0"
            JR   C,TokenScanNumberDone
            CP   "9"+1
            JR   NC,TokenScanNumberDone
            SUB  "0"
TokenScanNumberAccumulate:
            LD   D,H
            LD   E,L
            LD   B,9
TokenScanNumberMultiply:
            ADD  HL,DE
            JR   C,TokenScanCharacterFailure
            DJNZ TokenScanNumberMultiply
            LD   C,A                     ; B=0 after the completed DJNZ loop
            ADD  HL,BC
            JR   C,TokenScanCharacterFailure
            PUSH HL
            CALL SourceTake
            POP  HL
            JR   TokenScanNumberLoop

.routine in BC out A,BC,carry,zero clobbers sign,parity,halfCarry,D,DE,HL
TokenScanBasedNumber:
            CALL SourceTake
            LD   HL,0
TokenScanBasedLoop:
            PUSH HL
            CALL SourcePeek
            POP  HL
            JR   C,TokenScanBasedEof
            LD   D,A
            CALL TokenIsHexDigit
            JR   NC,TokenScanBasedDone
            BIT  4,C
            JR   Z,TokenScanBasedDigit
            CP   2
            JR   NC,TokenScanBasedDone
TokenScanBasedDigit:
            DEC  B
            JR   Z,TokenLexicalFailure
            BIT  4,C
            JR   NZ,TokenScanBasedShift
            ADD  HL,HL
            ADD  HL,HL
            ADD  HL,HL
TokenScanBasedShift:
            ADD  HL,HL
            OR   L
            LD   L,A
            PUSH HL
            CALL SourceTake
            POP  HL
            JR   TokenScanBasedLoop
TokenScanBasedEof:
            LD   D,C
TokenScanBasedDone:
            LD   A,B
            CP   C
            JR   Z,TokenLexicalFailure
            LD   A,D
            CP   C
            JR   Z,TokenScanNumberEof
TokenScanNumberDone:
            ; An integer token cannot be followed immediately by a name byte.
            ; Reject forms such as 0x2a and 12u8 as one malformed number rather
            ; than exposing a misleading number/name token pair to the parser.
            CALL TokenIsNameByte
            JR   C,TokenScanCharacterFailure
TokenScanNumberEof:
            LD   B,H
            LD   C,L
            CALL TokenFinishInline
            .db  TokenNumber

.if TargetStreamingOutput
; Production diagnostics do not return, so required literal bytes share one
; checked source-take path without adding a carry-propagation site per caller.
.routine out A,carry,zero clobbers sign,parity,halfCarry,DE,HL
TokenTakeRequired:
            CALL SourceTake
            RET  NC
.routine noreturn
.else
.routine out carry,zero clobbers sign,parity,halfCarry,A,DE,HL
.endif
TokenScanCharacterFailure:
TokenLexicalFailure:
            CALL SetDiagInline
            .db  DiagnosticLexical

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
TokenScanCharacter:
.if TargetStreamingOutput
            CALL TokenTakeRequired
            CALL TokenTakeRequired
.else
            CALL SourceTake
            JR   C,TokenScanCharacterFailure
            CALL SourceTake
            JR   C,TokenScanCharacterFailure
.endif
            LD   C,A
            CP   "'"
            JR   Z,TokenScanCharacterFailure
            CP   "\\"
            JR   Z,TokenScanCharacterFailure
            SUB  $20
            CP   $5F
            JR   NC,TokenScanCharacterFailure
.if TargetStreamingOutput
            CALL TokenTakeRequired
.else
            CALL SourceTake
            JR   C,TokenScanCharacterFailure
.endif
            CP   "'"
            JR   NZ,TokenScanCharacterFailure
            CALL TokenFinishInline
            .db  TokenCharacter

; Return carry and the decoded nibble for one hexadecimal digit. Tokenization
; needs only the validity flag; the static-image decoder reuses the value.
.routine in A out A,carry clobbers zero,sign,parity,halfCarry
TokenIsHexDigit:
            SUB  "0"
            CP   10
            RET  C
            OR   $20
            SUB  "a"-"0"
            CP   6
            RET  NC
            SUB  -10
            RET

; Consume and validate one hexadecimal escape digit. Production diagnostics
; do not return. Returning historical slices clear carry after a valid digit,
; distinguishing success from the diagnostic carry returned by the failure.
.routine out A,carry,zero clobbers sign,parity,halfCarry,DE,HL
TokenTakeHexRequired:
.if TargetStreamingOutput
            CALL TokenTakeRequired
.else
            CALL SourceTake
            JR   C,TokenScanCharacterFailure
.endif
            CALL TokenIsHexDigit
.if TargetStreamingOutput
            RET  C
            JR   TokenScanCharacterFailure
.else
            JR   NC,TokenScanCharacterFailure
            OR   A
            RET
.endif

; Scan and validate a bounded-string literal. BC returns the decoded byte
; length. TokenLexemePointer continues to identify the opening quote so the
; declaration parser can decode the bytes directly into the static image.
.routine out A,BC,carry,zero clobbers sign,parity,halfCarry,D,DE,HL
TokenScanString:
.if NativeStreamingSource
            CALL SourcePinBeginToken
.endif
.if TargetStreamingOutput
            CALL TokenTakeRequired
.else
            CALL SourceTake
            JR   C,TokenScanCharacterFailure
.endif
            LD   C,B                     ; B=0 after punctuation exhaustion
TokenScanStringNext:
.if TargetStreamingOutput
            CALL TokenTakeRequired
.else
            CALL SourceTake
            JR   C,TokenScanCharacterFailure
.endif
            CP   '"'
            JR   Z,TokenScanStringDone
            CP   "\\"
            JR   Z,TokenScanStringEscape
            SUB  $20
            CP   $5F
            JR   NC,TokenScanCharacterFailure
TokenScanStringCount:
            INC  C
            JR   Z,TokenScanCharacterFailure
            JR   TokenScanStringNext
TokenScanStringEscape:
.if TargetStreamingOutput
            CALL TokenTakeRequired
.else
            CALL SourceTake
            JR   C,TokenScanCharacterFailure
.endif
            CP   "x"
            JR   Z,TokenScanStringHex
            LD   HL,StringEscapeTable
            LD   E,C
            LD   C,StringEscapeCount     ; B=0 after punctuation exhaustion
            CPIR
            LD   C,E
            JR   Z,TokenScanStringCount
            JR   TokenScanCharacterFailure
TokenScanStringHex:
.if TargetStreamingOutput
            CALL TokenTakeHexRequired
            CALL TokenTakeHexRequired
.else
            CALL TokenTakeHexRequired
            RET  C
            CALL TokenTakeHexRequired
            RET  C
.endif
            JR   TokenScanStringCount
TokenScanStringDone:
.if NativeStreamingSource
            CALL SourcePinFinishToken
.endif
            LD   A,C
            LD   (TokenLength),A
            CALL TokenFinishInline
            .db  TokenStringLiteral

.if TargetStreamingOutput
TokenizerNext .equ TokenizerNextLoop
.else
.routine out A,BC,carry,zero clobbers sign,parity,halfCarry,D,DE,HL
TokenizerNext:
            JR   TokenizerNextLoop
.endif

TokenizerAtEof:
            LD   HL,(SourceLineHasToken)
            LD   A,H                     ; SourceDelimiterDepth
            OR   A
            JR   NZ,TokenizerLineLexicalFailure
.if AggregateCallSlices
            LD   A,(SourcePartsRemaining)
            ADD  A,A
            JR   C,TokenizerAdvancePart
.if TargetStreamingOutput
            AND  SourcePartsRemainingMask*2
.else
            OR   A
.endif
            JR   Z,TokenizerAtCompilationEof
            LD   A,L
            OR   A
            JR   Z,TokenizerAdvancePart
            LD   HL,SourcePartsRemaining
            SET  7,(HL)
            JR   TokenizerClearLineAndReturnNewline
TokenizerAdvancePart:
            LD   HL,SourcePartsRemaining
.if TargetStreamingOutput
            LD   A,(HL)
            AND  $3F
            ADD  A,SourcePartOrdinalStep-1
            LD   (HL),A
.else
            RES  7,(HL)
            DEC  (HL)
.endif
.if NativeStreamingSource
            CALL SourceStreamBeginPart
.else
            LD   HL,(SourcePartDescriptorCursor)
            CALL SourceLoadPart
.endif
            JR   TokenizerNextLoop
TokenizerAtCompilationEof:
.endif
            LD   A,L
            OR   A
.if NativeStreamingSource
            JR   NZ,TokenizerClearLineAndReturnNewline
            CALL SourceStreamFinishUnit
            XOR  A
            RET
.else
            RET  Z
.endif
TokenizerClearLineAndReturnNewline:
            XOR  A
            LD   (SourceLineHasToken),A
            INC  A                       ; TokenNewline
            RET
TokenizerLineLexicalFailure:
            JP   TokenLexicalFailure

TokenizerCrLf:
            CALL SourceTakePeek
            JR   C,TokenizerLineLexicalFailure
            CP   10
            JR   NZ,TokenizerLineLexicalFailure
TokenizerLf:
            CALL SourceTake
TokenizerFinishLine:
.if AggregateCallSlices
            LD   HL,(SourceLine)
            INC  HL
            LD   (SourceLine),HL
            LD   HL,1
            LD   (SourceColumn),HL
.else
            CALL SourceFinishLine
.endif
            LD   HL,(SourceLineHasToken)
            LD   A,H                     ; SourceDelimiterDepth
            OR   A
            JR   NZ,TokenizerNextLoop
            LD   A,L
            OR   A
            JR   Z,TokenizerNextLoop
            JR   TokenizerClearLineAndReturnNewline

.routine out A,BC,carry,zero clobbers sign,parity,halfCarry,D,DE,HL
TokenizerNextLoop:
            CALL TokenRecordStart
            JR   C,TokenizerAtEof

            CP   " "
            JR   Z,TokenizerSkipByte
            CP   9
            JR   Z,TokenizerSkipByte
            CP   10
            JR   Z,TokenizerLf
            CP   13
            JR   Z,TokenizerCrLf
            CP   "/"
            JR   Z,TokenizerSlash
            LD   C,TokenLeftParen
            CP   "("
            JR   Z,TokenizerLeftDelimiter
            INC  C
            CP   ")"
            JR   Z,TokenizerRightDelimiter
            CP   "<"
            JR   Z,TokenizerComparison
            CP   ">"
            JR   Z,TokenizerComparison
            LD   HL,PunctuationTable
            LD   B,PunctuationCount
TokenizerTryPunctuation:
            CP   (HL)
            INC  HL
            JR   Z,TokenizerPunctuation
            INC  HL
            DJNZ TokenizerTryPunctuation
            CP   "'"
            JP   Z,TokenScanCharacter
            CP   '"'
            JP   Z,TokenScanString
            CP   "0"
            JR   C,TokenizerTryName
            CP   "9"+1
            JP   C,TokenScanNumber
TokenizerTryName:
            CALL TokenIsLetter
            JP   C,TokenScanName
            LD   C,TokenLeftBracket
            CP   "["
            JR   Z,TokenizerLeftDelimiter
            INC  C
            CP   "]"
            JR   Z,TokenizerRightDelimiter
            JR   TokenizerLexicalFailure

TokenizerSkipByte:
            CALL SourceTake
            JR   TokenizerNextLoop

TokenizerSlash:
            LD   C,TokenSlash
            CALL SourceTakePeek
            JR   C,TokenFinishC
            CP   "/"
            JR   NZ,TokenFinishC
            CALL SourceTakePeek
TokenizerSkipCommentLoop:
            JR   C,TokenizerNextLoop
            CP   10
            JR   Z,TokenizerNextLoop
            CP   13
            JR   Z,TokenizerNextLoop
            CALL SourceTakePeek
            JR   TokenizerSkipCommentLoop

TokenizerPunctuation:
            LD   C,(HL)
            LD   A,B
            CP   3
            JR   NC,TokenizerSimpleToken
            LD   B,C
            JP   TokenScanBasedNumber

TokenizerRightDelimiter:
            LD   HL,SourceDelimiterDepth
            LD   A,(HL)
            OR   A
            JR   Z,TokenizerLexicalFailure
            DEC  (HL)
            JR   TokenizerSimpleToken
TokenizerLeftDelimiter:
            CALL SourceTake
            LD   HL,SourceDelimiterDepth
            INC  (HL)
            JR   NZ,TokenFinishC
.if TargetStreamingOutput
.else
            DEC  (HL)
.endif
TokenizerLexicalFailure:
            JP   TokenLexicalFailure

TokenizerComparison:
            SUB  "<"-TokenLess
            LD   C,A
            CALL SourceTakePeek
            JR   C,TokenFinishC
            SUB  "="
            JR   Z,TokenizerComparisonEqual
            DEC  A
            JR   NZ,TokenFinishC
            BIT  1,C
            JR   NZ,TokenFinishC
            LD   C,TokenNotEqual
            JR   TokenizerComparisonConsume
TokenizerComparisonEqual:
            INC  C
TokenizerComparisonConsume:

.routine in C out A,carry,zero clobbers sign,parity,halfCarry,DE,HL
TokenizerSimpleToken:
            CALL SourceTake

.routine noreturn
TokenFinishC:
            LD   A,C
.routine in A out A,carry,zero clobbers sign,parity,halfCarry
TokenFinish:
            AND  $7F
            LD   (SourceLineHasToken),A
            RET

; The byte following the call is a token ordinal, not executable code.
.routine noreturn
TokenFinishInline:
            POP  HL
            LD   A,(HL)
            JR   TokenFinish
StringEscapeTable:      .db "0nrt",$27,$22,"\\"
StringEscapeCount       .equ 7
