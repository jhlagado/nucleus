; Table-directed tokenizer for the replacement compiler.

.routine out A,BC,carry,zero clobbers sign,parity,halfCarry,D,DE,HL
RewriteTokenBegin:
            LD   HL,RewriteSourceOffset
            LD   DE,TokenStartOffset
            LD   BC,4
            LDIR
            RET

.routine in A,BC out A,BC,carry,zero clobbers sign,parity,halfCarry
RewriteTokenPublish:
            OR   A
            RET

.routine in A,BC out A,BC,carry,zero clobbers sign,parity,halfCarry
RewriteTokenFinishContent:
            LD   (RewriteSourceLineHasToken),A
            JR   RewriteTokenPublish

.routine in A out A,BC,carry,zero clobbers sign,parity,halfCarry
RewriteTokenFinishEmpty:
            LD   BC,0
            JR   RewriteTokenFinishContent

.routine in A out A,carry clobbers zero,sign,parity,halfCarry,D
RewriteTokenIsLetter:
            LD   D,A
            OR   $20
            SUB  "a"
            CP   26
            LD   A,D
            RET

.routine in A out A,carry clobbers zero,sign,parity,halfCarry,D
RewriteTokenIsNameByte:
            CALL RewriteTokenIsLetter
            RET  C
            CP   "0"
            JR   C,RewriteTokenIsNameUnderscore
            CP   "9"+1
            JR   C,RewriteTokenIsNameYes
RewriteTokenIsNameUnderscore:
            CP   "_"
            JR   Z,RewriteTokenIsNameYes
            OR   A
            RET
RewriteTokenIsNameYes:
            SCF
            RET

.routine noreturn
RewriteTokenLexicalFailure:
            LD   A,DiagnosticLexical
            JP   RewriteRaiseDiagnostic

.routine in BC out A,BC,carry,zero clobbers sign,parity,halfCarry,DE,HL
RewriteTokenTakeRequired:
            CALL RewriteSourceTake
            RET  NC
            JP   RewriteTokenLexicalFailure

; Match the retained NAME against high-bit-terminated keyword character data.
; C is the candidate token ordinal and DE advances through the table.
.routine out A,BC,carry,zero clobbers sign,parity,halfCarry,D,DE,HL
RewriteTokenScanName:
            LD   B,0
RewriteTokenScanNameLoop:
            CALL RewriteSourcePeek
            JR   C,RewriteTokenScanNameDone
            CALL RewriteTokenIsNameByte
            JR   NC,RewriteTokenScanNameDone
            CALL RewriteSourceTake
            INC  B
            JP   Z,RewriteTokenLexicalFailure
            JR   RewriteTokenScanNameLoop
RewriteTokenScanNameDone:
            LD   A,B
            LD   (TokenLength),A
            LD   DE,RewriteKeywordTable
            LD   C,TokenFirstKeyword
RewriteTokenKeywordEntry:
            LD   A,(DE)
            OR   A
            JR   Z,RewriteTokenName
            LD   HL,(TokenLexemePointer)
            LD   A,(TokenLength)
            LD   B,A
RewriteTokenKeywordByte:
            LD   A,(DE)
            AND  $7F
            CP   (HL)
            JR   NZ,RewriteTokenKeywordSkip
            LD   A,(DE)
            INC  DE
            INC  HL
            DEC  B
            JR   Z,RewriteTokenKeywordSourceEnd
            BIT  7,A
            JR   Z,RewriteTokenKeywordByte
            INC  C
            JR   RewriteTokenKeywordEntry
RewriteTokenKeywordSourceEnd:
            BIT  7,A
            JR   NZ,RewriteTokenKeywordFound
RewriteTokenKeywordSkip:
            LD   A,(DE)
            INC  DE
            BIT  7,A
            JR   Z,RewriteTokenKeywordSkip
            INC  C
            JR   RewriteTokenKeywordEntry
RewriteTokenKeywordFound:
            LD   A,C
            JP   RewriteTokenFinishEmpty
RewriteTokenName:
            LD   A,TokenName
            JP   RewriteTokenFinishEmpty

; Scan a decimal word. HL is checked before each multiply by ten and add.
.routine out A,BC,carry,zero clobbers sign,parity,halfCarry,D,DE,HL
RewriteTokenScanNumber:
            LD   HL,0
RewriteTokenScanNumberLoop:
            PUSH HL
            CALL RewriteSourcePeek
            POP  HL
            JR   C,RewriteTokenScanNumberEof
            CP   "0"
            JR   C,RewriteTokenScanNumberDone
            CP   "9"+1
            JR   NC,RewriteTokenScanNumberDone
            SUB  "0"
            LD   C,A
            LD   D,H
            LD   E,L
            ADD  HL,HL
            JR   C,RewriteTokenScanNumberFailure
            ADD  HL,HL
            JR   C,RewriteTokenScanNumberFailure
            ADD  HL,HL
            JR   C,RewriteTokenScanNumberFailure
            ADD  HL,DE
            JR   C,RewriteTokenScanNumberFailure
            ADD  HL,DE
            JR   C,RewriteTokenScanNumberFailure
            LD   D,0
            LD   E,C
            ADD  HL,DE
            JR   C,RewriteTokenScanNumberFailure
            PUSH HL
            CALL RewriteSourceTake
            POP  HL
            JR   RewriteTokenScanNumberLoop
RewriteTokenScanNumberFailure:
            JP   RewriteTokenLexicalFailure
RewriteTokenScanNumberDone:
            CALL RewriteTokenIsNameByte
            JP   C,RewriteTokenLexicalFailure
RewriteTokenScanNumberEof:
            LD   B,H
            LD   C,L
            LD   A,TokenNumber
            JP   RewriteTokenFinishContent

.routine in C out A,BC,carry,zero clobbers sign,parity,halfCarry,D,DE,HL
RewriteTokenScanBasedNumber:
            LD   B,C
            CALL RewriteSourceTake
            LD   HL,0
RewriteTokenScanBasedLoop:
            XOR  A
            PUSH HL
            CALL RewriteSourcePeek
            POP  HL
            LD   D,A
            JR   C,RewriteTokenScanBasedDone
            BIT  4,C
            JR   NZ,RewriteTokenScanBinaryDigit
            CALL RewriteTokenHexDigit
            JR   C,RewriteTokenScanBasedDigit
            JR   RewriteTokenScanBasedDone
RewriteTokenScanBinaryDigit:
            SUB  "0"
            JR   C,RewriteTokenScanBasedDone
            CP   2
            JR   NC,RewriteTokenScanBasedDone
RewriteTokenScanBasedDigit:
            DEC  B
            JP   Z,RewriteTokenLexicalFailure
            LD   E,A
            BIT  4,C
            JR   NZ,RewriteTokenScanBasedShift
            ADD  HL,HL
            ADD  HL,HL
            ADD  HL,HL
RewriteTokenScanBasedShift:
            ADD  HL,HL
            LD   A,E
            OR   L
            LD   L,A
            PUSH HL
            CALL RewriteSourceTake
            POP  HL
            JR   RewriteTokenScanBasedLoop
RewriteTokenScanBasedDone:
            LD   A,B
            CP   C
            JP   Z,RewriteTokenLexicalFailure
            LD   A,D
            OR   A
            JR   Z,RewriteTokenScanBasedPublish
            BIT  4,C
            JR   Z,RewriteTokenScanBasedNameCheck
            CP   "0"
            JR   C,RewriteTokenScanBasedNameCheck
            CP   "9"+1
            JP   C,RewriteTokenLexicalFailure
RewriteTokenScanBasedNameCheck:
            CALL RewriteTokenIsNameByte
            JP   C,RewriteTokenLexicalFailure
RewriteTokenScanBasedPublish:
            LD   B,H
            LD   C,L
            LD   A,TokenNumber
            JP   RewriteTokenFinishContent

.routine in A out A,carry,zero clobbers sign,parity,halfCarry
RewriteTokenHexDigit:
            CP   "0"
            JR   C,RewriteTokenHexNo
            CP   "9"+1
            JR   C,RewriteTokenHexDecimal
            OR   $20
            SUB  "a"
            CP   6
            JR   NC,RewriteTokenHexNo
            ADD  A,10
            SCF
            RET
RewriteTokenHexDecimal:
            SUB  "0"
            SCF
            RET
RewriteTokenHexNo:
            OR   A
            RET

.routine out A,BC,carry,zero clobbers sign,parity,halfCarry,D,DE,HL
RewriteTokenScanCharacter:
            CALL RewriteSourceTake
            CALL RewriteTokenTakeRequired
            CP   $27
            JP   Z,RewriteTokenLexicalFailure
            CALL RewriteTokenDecodeLiteralByte
            LD   C,A
            CALL RewriteTokenTakeRequired
            CP   $27
            JP   NZ,RewriteTokenLexicalFailure
            LD   B,0
            LD   A,TokenCharacter
            JP   RewriteTokenFinishContent

.routine out A,BC,carry,zero clobbers sign,parity,halfCarry,D,DE,HL
RewriteTokenScanString:
            CALL RewriteSourceTake
            LD   C,0
RewriteTokenScanStringNext:
            CALL RewriteTokenTakeRequired
            CP   $22
            JR   Z,RewriteTokenScanStringDone
            CALL RewriteTokenDecodeLiteralByte
            INC  C
            JP   Z,RewriteTokenLexicalFailure
            JR   RewriteTokenScanStringNext
RewriteTokenScanStringDone:
            LD   A,C
            LD   (TokenLength),A
            LD   B,0
            LD   A,TokenStringLiteral
            JP   RewriteTokenFinishContent

.routine in A,C out A,BC,carry,zero clobbers sign,parity,halfCarry,D,DE,HL
RewriteTokenDecodeLiteralByte:
            CP   $20
            JP   C,RewriteTokenLexicalFailure
            CP   $7F
            JP   NC,RewriteTokenLexicalFailure
            CP   "\\"
            RET  NZ

.routine in C out A,C,carry,zero clobbers sign,parity,halfCarry,B,D,DE,HL
RewriteTokenDecodeEscape:
            CALL RewriteTokenTakeRequired
            CP   "x"
            JR   Z,RewriteTokenDecodeHex
            LD   HL,RewriteStringEscapeTable
            LD   B,RewriteStringEscapeCount
RewriteTokenDecodeEscapeLoop:
            CP   (HL)
            INC  HL
            JR   Z,RewriteTokenDecodeEscapeFound
            INC  HL
            DJNZ RewriteTokenDecodeEscapeLoop
            JP   RewriteTokenLexicalFailure
RewriteTokenDecodeEscapeFound:
            LD   A,(HL)
            RET
RewriteTokenDecodeHex:
            PUSH BC
            CALL RewriteTokenTakeRequired
            CALL RewriteTokenHexDigit
            JP   NC,RewriteTokenLexicalFailure
            RLCA
            RLCA
            RLCA
            RLCA
            LD   B,A
            CALL RewriteTokenTakeRequired
            CALL RewriteTokenHexDigit
            JP   NC,RewriteTokenLexicalFailure
            OR   B
            POP  BC
            RET

.routine out A,BC,carry,zero clobbers sign,parity,halfCarry,D,DE,HL
RewriteTokenSkipComment:
RewriteTokenSkipCommentLoop:
            CALL RewriteTokenBegin
            CALL RewriteSourcePeek
            RET  C
            CP   10
            RET  Z
            CP   13
            RET  Z
            CP   9
            JR   Z,RewriteTokenSkipCommentByte
            SUB  $20
            CP   $5F
            JP   NC,RewriteTokenLexicalFailure
RewriteTokenSkipCommentByte:
            CALL RewriteSourceTake
            JR   RewriteTokenSkipCommentLoop

.routine out A,BC,carry,zero clobbers sign,parity,halfCarry,D,DE,HL
RewriteTokenizerNext:
RewriteTokenizerNextLoop:
            CALL RewriteTokenBegin
            CALL RewriteSourcePeek
            JP   C,RewriteTokenizerAtEof
            CP   " "
            JR   Z,RewriteTokenizerSkipByte
            CP   9
            JR   Z,RewriteTokenizerSkipByte
            CP   10
            JP   Z,RewriteTokenizerLf
            CP   13
            JP   Z,RewriteTokenizerCrLf
            CP   "/"
            JP   Z,RewriteTokenizerSlash
            CP   "<"
            JP   Z,RewriteTokenizerLess
            CP   ">"
            JP   Z,RewriteTokenizerGreater
            LD   HL,RewritePunctuationTable
            LD   B,RewritePunctuationCount
RewriteTokenizerTryPunctuation:
            CP   (HL)
            INC  HL
            JR   Z,RewriteTokenizerPunctuation
            INC  HL
            DJNZ RewriteTokenizerTryPunctuation
            CP   $27
            JP   Z,RewriteTokenScanCharacter
            CP   $22
            JP   Z,RewriteTokenScanString
            CP   "0"
            JR   C,RewriteTokenizerTryName
            CP   "9"+1
            JP   C,RewriteTokenScanNumber
RewriteTokenizerTryName:
            CALL RewriteTokenIsLetter
            JP   C,RewriteTokenScanName
            JP   RewriteTokenLexicalFailure

RewriteTokenizerSkipByte:
            CALL RewriteSourceTake
            JR   RewriteTokenizerNextLoop

RewriteTokenizerPunctuation:
            LD   C,(HL)
            BIT  7,C
            JR   NZ,RewriteTokenizerBasedNumber
            BIT  6,C
            JR   NZ,RewriteTokenizerDelimiter
            CALL RewriteSourceTake
            LD   A,C
            JP   RewriteTokenFinishEmpty
RewriteTokenizerBasedNumber:
            RES  7,C
            JP   RewriteTokenScanBasedNumber

RewriteTokenizerDelimiter:
            RES  6,C
            BIT  0,C
            JR   NZ,RewriteTokenizerRightDelimiter
            JR   RewriteTokenizerLeftDelimiter

RewriteTokenizerSlash:
            CALL RewriteSourceTake
            CALL RewriteSourcePeek
            JR   C,RewriteTokenizerSlashToken
            CP   "/"
            JR   NZ,RewriteTokenizerSlashToken
            CALL RewriteSourceTake
            CALL RewriteTokenSkipComment
            JP   RewriteTokenizerNextLoop
RewriteTokenizerSlashToken:
            LD   A,TokenSlash
            JP   RewriteTokenFinishEmpty

RewriteTokenizerLess:
            LD   C,TokenLess
            JR   RewriteTokenizerComparison

RewriteTokenizerGreater:
            LD   C,TokenGreater
RewriteTokenizerComparison:
            CALL RewriteSourceTake
            CALL RewriteSourcePeek
            JR   C,RewriteTokenizerComparisonToken
            CP   "="
            JR   Z,RewriteTokenizerComparisonEqual
            LD   D,A
            LD   A,C
            CP   TokenLess
            JR   NZ,RewriteTokenizerComparisonToken
            LD   A,D
            CP   ">"
            JR   NZ,RewriteTokenizerComparisonToken
            LD   C,TokenNotEqual
            JR   RewriteTokenizerSecond
RewriteTokenizerComparisonEqual:
            INC  C
RewriteTokenizerSecond:
            CALL RewriteSourceTake
RewriteTokenizerComparisonToken:
            LD   A,C
            JP   RewriteTokenFinishEmpty

RewriteTokenizerLeftDelimiter:
            LD   A,(RewriteSourceDelimiterDepth)
            CP   RewriteDelimiterCapacity
            JP   Z,RewriteTokenLexicalFailure
            LD   L,A
            LD   H,0
            LD   DE,RewriteDelimiterStack
            ADD  HL,DE
            LD   (HL),C
            INC  A
            LD   (RewriteSourceDelimiterDepth),A
            CALL RewriteSourceTake
            LD   A,C
            JP   RewriteTokenFinishEmpty

RewriteTokenizerRightDelimiter:
            LD   A,(RewriteSourceDelimiterDepth)
            OR   A
            JP   Z,RewriteTokenLexicalFailure
            DEC  A
            LD   (RewriteSourceDelimiterDepth),A
            LD   L,A
            LD   H,0
            LD   DE,RewriteDelimiterStack
            ADD  HL,DE
            LD   A,(HL)
            INC  A
            CP   C
            JP   NZ,RewriteTokenLexicalFailure
            CALL RewriteSourceTake
            LD   A,C
            JP   RewriteTokenFinishEmpty

RewriteTokenizerLf:
            CALL RewriteSourceTake
            JR   RewriteTokenizerFinishLine
RewriteTokenizerCrLf:
            CALL RewriteSourceTake
            CALL RewriteTokenTakeRequired
            CP   10
            JP   NZ,RewriteTokenLexicalFailure
RewriteTokenizerFinishLine:
            LD   A,(RewriteSourceDelimiterDepth)
            OR   A
            JP   NZ,RewriteTokenizerNextLoop
            LD   A,(RewriteSourceLineHasToken)
            OR   A
            JP   Z,RewriteTokenizerNextLoop
RewriteTokenizerEmitNewline:
            XOR  A
            LD   (RewriteSourceLineHasToken),A
            LD   A,TokenNewline
            JP   RewriteTokenPublish

RewriteTokenizerAtEof:
            LD   A,(RewriteSourceDelimiterDepth)
            OR   A
            JP   NZ,RewriteTokenLexicalFailure
            LD   HL,RewriteSourcePartsRemaining
            BIT  RewriteSourceAdvancePendingBit,(HL)
            JR   NZ,RewriteTokenizerAdvancePart
            LD   A,(HL)
            OR   A
            JR   Z,RewriteTokenizerFinalEof
            LD   A,(RewriteSourceLineHasToken)
            OR   A
            JR   Z,RewriteTokenizerAdvancePart
            SET  RewriteSourceAdvancePendingBit,(HL)
            JR   RewriteTokenizerEmitNewline
RewriteTokenizerAdvancePart:
            RES  RewriteSourceAdvancePendingBit,(HL)
            DEC  (HL)
            LD   HL,(RewriteSourceNextDescriptor)
            CALL RewriteSourceLoadPart
            JP   RewriteTokenizerNextLoop
RewriteTokenizerFinalEof:
            LD   A,(RewriteSourceLineHasToken)
            OR   A
            JR   Z,RewriteTokenizerEmitEof
            JR   RewriteTokenizerEmitNewline
RewriteTokenizerEmitEof:
            LD   A,TokenEof
            JP   RewriteTokenPublish
