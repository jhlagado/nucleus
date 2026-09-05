; Tokenizer subset for the Stage-3 source program. It preserves the normative
; streaming positions and longest-name behavior while recognizing only the
; token families the slice can pass to its parser.

.routine out carry,zero clobbers sign,parity,halfCarry,A,DE,HL
TKSTART:
            LD   HL,(SSOFF)
            LD   (TNSTOFF),HL
            LD   HL,(SSLINE)
            LD   (TNSTLINE),HL
            LD   HL,(SSCOL)
            LD   (TNSTCOL),HL
            LD   HL,(SSCUR)
            LD   (TNLEXPTR),HL
            XOR  A
            LD   (TNLEN),A
            RET

.routine in A out A,carry,zero clobbers sign,parity,halfCarry
TKEND:
            LD   (TNKIND),A
            LD   A,1
            LD   (SSLNTOK),A
            LD   A,(TNKIND)
            OR   A
            RET

.routine out carry,zero clobbers sign,parity,halfCarry,A,HL
TKLEXERR:
            LD   A,DGLEX
            JP   CompilerSetDiagnostic

; Carry is set when A can begin a Nucleus identifier.
.routine in A out A,carry clobbers zero,sign,parity,halfCarry
TKLETTER:
            CP   "A"
            JR   C,TokenIsLetterNo
            CP   "Z"+1
            JR   C,TokenIsLetterYes
            CP   "a"
            JR   C,TokenIsLetterNo
            CP   "z"+1
            JR   C,TokenIsLetterYes
TokenIsLetterNo:
            OR   A
            RET
TokenIsLetterYes:
            SCF
            RET

; Carry is set for identifier continuation bytes.
.routine in A out A,carry clobbers zero,sign,parity,halfCarry
TKNAMEBY:
            CALL TKLETTER
            RET  C
            CP   "0"
            JR   C,TokenIsNameByteUnderscore
            CP   "9"+1
            JR   C,TokenIsNameByteYes
TokenIsNameByteUnderscore:
            CP   "_"
            JR   Z,TokenIsNameByteYes
            OR   A
            RET
TokenIsNameByteYes:
            SCF
            RET

; Compare the current NAME token against B bytes at HL. Carry means equal.
.routine in B,HL out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
TKNAMEEQ:
            LD   A,(TNLEN)
            CP   B
            JR   NZ,TokenNameEqualsNo
            LD   DE,(TNLEXPTR)
TKNAMELP:
            LD   A,(DE)
            CP   (HL)
            JR   NZ,TokenNameEqualsNo
            INC  DE
            INC  HL
            DJNZ TKNAMELP
            SCF
            RET
TokenNameEqualsNo:
            OR   A
            RET

; Scan a complete name before testing the reserved-word spellings used here.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
TKNAME:
            LD   B,0
TKSCANLP:
            CALL SAPEEK
            JR   C,TKNAMEEN
            CALL TKNAMEBY
            JR   NC,TKNAMEEN
            CALL SATAKE
            INC  B
            JR   Z,TKLEXERR
            JR   TKSCANLP
TKNAMEEN:
            LD   A,B
            LD   (TNLEN),A

            LD   HL,KeywordSub
            LD   B,3
            CALL TKNAMEEQ
            JR   C,TokenScanNameSub
            LD   HL,KeywordFails
            LD   B,5
            CALL TKNAMEEQ
            JR   C,TokenScanNameFails
            LD   HL,KeywordElse
            LD   B,4
            CALL TKNAMEEQ
            JR   C,TokenScanNameElse
            LD   HL,KeywordFail
            LD   B,4
            CALL TKNAMEEQ
            JR   C,TokenScanNameFail
            LD   HL,KeywordEnd
            LD   B,3
            CALL TKNAMEEQ
            JR   C,TokenScanNameEnd
            LD   A,TNNAME
            JP   TKEND
TokenScanNameSub:
            LD   A,TOKENSUB
            JP   TKEND
TokenScanNameFails:
            LD   A,TNFAILS
            JP   TKEND
TokenScanNameElse:
            LD   A,TNELSE
            JP   TKEND
TokenScanNameFail:
            LD   A,TNFAIL
            JP   TKEND
TokenScanNameEnd:
            LD   A,TOKENEND
            JP   TKEND

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
TKCHAR:
            CALL SATAKE
            JP   C,TKLEXERR
            CALL SAPEEK
            JP   C,TKLEXERR
            CP   $20
            JP   C,TKLEXERR
            CP   $7F
            JP   NC,TKLEXERR
            CP   "'"
            JP   Z,TKLEXERR
            CP   "\\"
            JP   Z,TKLEXERR
            CALL SATAKE
            LD   (TNVALUE),A
            CALL SAPEEK
            JP   C,TKLEXERR
            CP   "'"
            JP   NZ,TKLEXERR
            CALL SATAKE
            LD   A,TNCHAR
            JP   TKEND

; Skip a line comment, leaving its physical line ending for normal handling.
.routine out carry,zero clobbers sign,parity,halfCarry,A,DE,HL
TokenSkipComment:
TokenSkipCommentLoop:
            CALL SAPEEK
            RET  C
            CP   10
            RET  Z
            CP   13
            RET  Z
            CALL SATAKE
            JR   TokenSkipCommentLoop

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
TKNEXT:
TKNEXTLP:
            CALL TKSTART
            CALL SAPEEK
            JP   C,TKEOF

            CP   " "
            JR   Z,TKSKIP
            CP   9
            JR   Z,TKSKIP
            CP   10
            JR   Z,TKLF
            CP   13
            JR   Z,TKCRLF
            CP   "/"
            JR   Z,TKSLASH
            CP   "("
            JR   Z,TokenizerLeftParen
            CP   ")"
            JR   Z,TokenizerRightParen
            CP   "'"
            JP   Z,TKCHAR
            CALL TKLETTER
            JP   C,TKNAME
            JP   TKLEXERR

TKSKIP:
            CALL SATAKE
            JR   TKNEXTLP

TKSLASH:
            CALL SATAKPEK
            JP   C,TKLEXERR
            CP   "/"
            JP   NZ,TKLEXERR
            CALL SATAKE
            CALL TokenSkipComment
            JR   TKNEXTLP

TokenizerLeftParen:
            CALL SATAKE
            LD   A,(SSDELDEP)
            INC  A
            JP   Z,TKLEXERR
            LD   (SSDELDEP),A
            LD   A,TNLPAR
            JP   TKEND

TokenizerRightParen:
            LD   A,(SSDELDEP)
            OR   A
            JP   Z,TKLEXERR
            DEC  A
            LD   (SSDELDEP),A
            CALL SATAKE
            LD   A,TNRPAR
            JP   TKEND

TKLF:
            CALL SATAKE
            CALL SALINE
            LD   A,(SSDELDEP)
            OR   A
            JR   NZ,TKNEXTLP
            LD   A,(SSLNTOK)
            OR   A
            JP   Z,TKNEXTLP
            XOR  A
            LD   (SSLNTOK),A
            LD   A,TNNL
            LD   (TNKIND),A
            OR   A
            RET

TKCRLF:
            CALL SATAKPEK
            JP   C,TKLEXERR
            CP   10
            JP   NZ,TKLEXERR
            CALL SATAKE
            CALL SALINE
            LD   A,(SSDELDEP)
            OR   A
            JP   NZ,TKNEXTLP
            LD   A,(SSLNTOK)
            OR   A
            JP   Z,TKNEXTLP
            XOR  A
            LD   (SSLNTOK),A
            LD   A,TNNL
            LD   (TNKIND),A
            OR   A
            RET

TKEOF:
            LD   A,(SSDELDEP)
            OR   A
            JP   NZ,TKLEXERR
            LD   A,(TNEOFPND)
            OR   A
            JR   NZ,TokenizerEmitEof
            LD   A,(SSLNTOK)
            OR   A
            JR   Z,TokenizerEmitEof
            XOR  A
            LD   (SSLNTOK),A
            INC  A
            LD   (TNEOFPND),A
            LD   A,TNNL
            LD   (TNKIND),A
            OR   A
            RET
TokenizerEmitEof:
            LD   A,TOKENEOF
            LD   (TNKIND),A
            OR   A
            RET
