; Tokenizer subset for the Stage-3 source program. It preserves the normative
; streaming positions and longest-name behavior while recognizing only the
; token families the slice can pass to its parser.

; ABI: out carry,zero clobbers sign,parity,halfCarry,A,DE,HL
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

; ABI: in A out A,carry,zero clobbers sign,parity,halfCarry
TKEND:
            LD   (TNKIND),A
            LD   A,1
            LD   (SSLNTOK),A
            LD   A,(TNKIND)
            OR   A
            RET

; ABI: out carry,zero clobbers sign,parity,halfCarry,A,HL
TKLEXERR:
            LD   A,DGLEX
            JP   DGSET

; Carry is set when A can begin a Nucleus identifier.
; ABI: in A out A,carry clobbers zero,sign,parity,halfCarry
TKLETTER:
            CP   $41
            JR   C,ETLETNO
            CP   $5A+1
            JR   C,ETLETYES
            CP   $61
            JR   C,ETLETNO
            CP   $7A+1
            JR   C,ETLETYES
ETLETNO:
            OR   A
            RET
ETLETYES:
            SCF
            RET

; Carry is set for identifier continuation bytes.
; ABI: in A out A,carry clobbers zero,sign,parity,halfCarry
TKNAMEBY:
            CALL TKLETTER
            RET  C
            CP   $30
            JR   C,ETNAMUND
            CP   $39+1
            JR   C,ETNAMYES
ETNAMUND:
            CP   $5F
            JR   Z,ETNAMYES
            OR   A
            RET
ETNAMYES:
            SCF
            RET

; Compare the current NAME token against B bytes at HL. Carry means equal.
; ABI: in B,HL out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
TKNAMEEQ:
            LD   A,(TNLEN)
            CP   B
            JR   NZ,ETNEQNO
            LD   DE,(TNLEXPTR)
TKNAMELP:
            LD   A,(DE)
            CP   (HL)
            JR   NZ,ETNEQNO
            INC  DE
            INC  HL
            DJNZ TKNAMELP
            SCF
            RET
ETNEQNO:
            OR   A
            RET

; Scan a complete name before testing the reserved-word spellings used here.
; ABI: out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
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

            LD   HL,EKWSUB
            LD   B,3
            CALL TKNAMEEQ
            JR   C,ETNSUB
            LD   HL,EKWFAILS
            LD   B,5
            CALL TKNAMEEQ
            JR   C,ETNFAILS
            LD   HL,EKWELSE
            LD   B,4
            CALL TKNAMEEQ
            JR   C,ETNELSE
            LD   HL,EKWFAIL
            LD   B,4
            CALL TKNAMEEQ
            JR   C,ETNFAIL
            LD   HL,EKWEND
            LD   B,3
            CALL TKNAMEEQ
            JR   C,ETNEND
            LD   A,TNNAME
            JP   TKEND
ETNSUB:
            LD   A,TOKENSUB
            JP   TKEND
ETNFAILS:
            LD   A,TNFAILS
            JP   TKEND
ETNELSE:
            LD   A,TNELSE
            JP   TKEND
ETNFAIL:
            LD   A,TNFAIL
            JP   TKEND
ETNEND:
            LD   A,TOKENEND
            JP   TKEND

; ABI: out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
TKCHAR:
            CALL SATAKE
            JP   C,TKLEXERR
            CALL SAPEEK
            JP   C,TKLEXERR
            CP   $20
            JP   C,TKLEXERR
            CP   $7F
            JP   NC,TKLEXERR
            CP   $27
            JP   Z,TKLEXERR
            CP   $5C
            JP   Z,TKLEXERR
            CALL SATAKE
            LD   (TNVALUE),A
            CALL SAPEEK
            JP   C,TKLEXERR
            CP   $27
            JP   NZ,TKLEXERR
            CALL SATAKE
            LD   A,TNCHAR
            JP   TKEND

; Skip a line comment, leaving its physical line ending for normal handling.
; ABI: out carry,zero clobbers sign,parity,halfCarry,A,DE,HL
ETSKPCMT:
ETCMTLP:
            CALL SAPEEK
            RET  C
            CP   10
            RET  Z
            CP   13
            RET  Z
            CALL SATAKE
            JR   ETCMTLP

; ABI: out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
TKNEXT:
TKNEXTLP:
            CALL TKSTART
            CALL SAPEEK
            JP   C,TKEOF

            CP   $20
            JR   Z,TKSKIP
            CP   9
            JR   Z,TKSKIP
            CP   10
            JR   Z,TKLF
            CP   13
            JR   Z,TKCRLF
            CP   $2F
            JR   Z,TKSLASH
            CP   $28
            JR   Z,ETLPAR
            CP   $29
            JR   Z,ETRPAR
            CP   $27
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
            CP   $2F
            JP   NZ,TKLEXERR
            CALL SATAKE
            CALL ETSKPCMT
            JR   TKNEXTLP

ETLPAR:
            CALL SATAKE
            LD   A,(SSDELDEP)
            INC  A
            JP   Z,TKLEXERR
            LD   (SSDELDEP),A
            LD   A,TNLPAR
            JP   TKEND

ETRPAR:
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
            JR   NZ,ETEOF
            LD   A,(SSLNTOK)
            OR   A
            JR   Z,ETEOF
            XOR  A
            LD   (SSLNTOK),A
            INC  A
            LD   (TNEOFPND),A
            LD   A,TNNL
            LD   (TNKIND),A
            OR   A
            RET
ETEOF:
            LD   A,TOKENEOF
            LD   (TNKIND),A
            OR   A
            RET
