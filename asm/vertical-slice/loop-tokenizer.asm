; Tokenizer subset for the scalar-local, counted-loop, and array proofs.

; Contract: out A,carry,zero,HL clobbers sign,parity,halfCarry,BC,DE
TKSTART:
%IF NativeStreamingSource
            CALL SHUNPIN
%ENDIF
            LD   HL,SSOFF
            LD   DE,TNSTOFF
            LD   BC,8
            LDIR
            JR   SAPEEK

; Contract: in A out A,carry clobbers zero,sign,parity,halfCarry,C
TKLETTER:
            LD   C,A
            OR   $20
            SUB  'a'
            CP   26
            LD   A,C
            RET

; Contract: in A out carry clobbers zero,sign,parity,halfCarry,A,C
TKNAMEBY:
            CALL TKLETTER
            RET  C
            ADD  A,256-'_'
            RET  Z
            ADD  A,'_'-'0'
            CP   10
            RET

; Contract: in B,HL out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
TKNAMEEQ:
            LD   A,(TNLEN)
            XOR  B
            RET  NZ
            LD   DE,(TNLEXPTR)
TKNAMELP:
            LD   A,(DE)
            XOR  (HL)
            RET  NZ
            INC  DE
            INC  HL
            DJNZ TKNAMELP
            SCF
            RET

; Compare the current NAME token with the retained name record at HL. The
; record begins with a pointer word followed by a one-byte length.
%IF NativeStreamingSource
; The record word is an opaque provider handle rather than a source pointer.
; Contract: in BC,HL out A,carry,zero clobbers sign,parity,halfCarry,DE
TKRECEQ:
            PUSH BC
            PUSH HL
            PUSH IX
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            INC  HL
            LD   A,(TNLEN)
            XOR  (HL)
            JP   Z,TKRECLEN
            POP  IX
            POP  HL
            POP  BC
            RET
TKRECLEN:
            LD   B,(HL)
            EX   DE,HL
            CALL SHCMPNAM
            POP  IX
            POP  HL
            POP  BC
            RET  NZ
            SCF
            RET
%ELSE
; Contract: in BC,HL out A,carry,zero clobbers sign,parity,halfCarry,DE
TKRECEQ:
            PUSH BC
            PUSH HL
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            INC  HL
            LD   B,(HL)
            EX   DE,HL
            CALL TKNAMEEQ
            POP  HL
            POP  BC
            RET
%ENDIF

; Store the current NAME token's pointer and length in the three-byte record
; at HL. HL returns at the length byte, matching the former inline sequences.
%IF NativeStreamingSource
; Contract: in HL out A,BC,HL clobbers carry,zero,sign,parity,halfCarry
TKRETAIN:
            PUSH DE
            PUSH HL
            LD   HL,(TNLEXPTR)
            LD   A,(TNLEN)
            LD   B,A
            LD   A,(SSPARTID)
            LD   C,A
            LD   DE,(TNSTOFF)
            CALL SHRETAIN
            LD   B,H
            LD   C,L
            POP  HL
            LD   (HL),C
            INC  HL
            LD   (HL),B
            INC  HL
            LD   A,(TNLEN)
            LD   (HL),A
            POP  DE
            RET
%ELSE
; Contract: in HL out A,BC,HL clobbers carry,zero,sign,parity,halfCarry
TKRETAIN:
            LD   BC,(TNLEXPTR)
            LD   (HL),C
            INC  HL
            LD   (HL),B
            INC  HL
            LD   A,(TNLEN)
            LD   (HL),A
            RET
%ENDIF

; Contract: in B out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
TKNAME:
            ; The sole entry follows the exhausted punctuation DJNZ, so B=0.
%IF NativeStreamingSource
            CALL SHPIN
%ENDIF
TKSCANLP:
            CALL SAPEEK
            JR   C,TKNAMEEN
            CALL TKNAMEBY
            JR   NC,TKNAMEEN
            CALL SATAKE
            INC  B
            JP   Z,TKLEXERR
            JR   TKSCANLP
TKNAMEEN:
%IF NativeStreamingSource
            CALL SHPINEND
%ENDIF
            LD   A,B
            LD   C,B
            LD   (TNLEN),A
            SUB  2
            CP   7
            JR   NC,TKNAMEID
            LD   E,A
            LD   D,0
            LD   HL,KWOFFSET
            ADD  HL,DE
            LD   E,(HL)
            ADD  HL,DE
TKKEY:
            LD   B,C
            LD   DE,(TNLEXPTR)
TKKEYBYT:
            LD   A,(DE)
            CP   (HL)
            JR   NZ,TKKEYSKP
            INC  DE
            INC  HL
            DJNZ TKKEYBYT
            LD   A,(HL)
            JP   TKEND
TKKEYSKP:
            LD   E,B
            LD   D,0
            ADD  HL,DE
            BIT  7,(HL)
            INC  HL
            JR   Z,TKKEY
TKNAMEID:
            CALL TKINLINE
            DB  TNNAME

; Scan one or more decimal digits and reject a value above 65535. BC carries
; the exact unsigned literal payload to the predictive parser.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
TKNUM:
            LD   H,B                     ; B=0 after punctuation exhaustion
            LD   L,B
TKNUMLP:
            PUSH HL
            CALL SAPEEK
            POP  HL
            JR   C,TKNUMEOF
            CP   '0'
            JR   C,TKNUMEND
            CP   '9'+1
            JR   NC,TKNUMEND
            SUB  '0'
TKNUMADD:
            LD   D,H
            LD   E,L
            LD   B,9
TKNUMMUL:
            ADD  HL,DE
            JR   C,TKCHRERR
            DJNZ TKNUMMUL
            LD   C,A                     ; B=0 after the completed DJNZ loop
            ADD  HL,BC
            JR   C,TKCHRERR
            PUSH HL
            CALL SATAKE
            POP  HL
            JR   TKNUMLP

; Contract: in BC out A,BC,carry,zero clobbers sign,parity,halfCarry,D,DE,HL
TKBASED:
            CALL SATAKE
            LD   HL,0
TKBASELP:
            PUSH HL
            CALL SAPEEK
            POP  HL
            JR   C,TKBEOF
            LD   D,A
            CALL TKHEX
            JR   NC,TKBEND
            BIT  4,C
            JR   Z,TKBDIGIT
            CP   2
            JR   NC,TKBEND
TKBDIGIT:
            DEC  B
            JR   Z,TKLEXERR
            BIT  4,C
            JR   NZ,TKBSHIFT
            ADD  HL,HL
            ADD  HL,HL
            ADD  HL,HL
TKBSHIFT:
            ADD  HL,HL
            OR   L
            LD   L,A
            PUSH HL
            CALL SATAKE
            POP  HL
            JR   TKBASELP
TKBEOF:
            LD   D,C
TKBEND:
            LD   A,B
            CP   C
            JR   Z,TKLEXERR
            LD   A,D
            CP   C
            JR   Z,TKNUMEOF
TKNUMEND:
            ; An integer token cannot be followed immediately by a name byte.
            ; Reject forms such as 0x2a and 12u8 as one malformed number rather
            ; than exposing a misleading number/name token pair to the parser.
            CALL TKNAMEBY
            JR   C,TKCHRERR
TKNUMEOF:
            LD   B,H
            LD   C,L
            CALL TKINLINE
            DB  TNNUM

%IF TargetStreamingOutput
; Production diagnostics do not return, so required literal bytes share one
; checked source-take path without adding a carry-propagation site per caller.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,DE,HL
TKTAKE:
            CALL SATAKE
            RET  NC
; Contract: noreturn
%ELSE
; Contract: out carry,zero clobbers sign,parity,halfCarry,A,DE,HL
%ENDIF
TKCHRERR:
TKLEXERR:
            CALL DGINLINE
            DB  DGLEX

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
TKCHAR:
%IF TargetStreamingOutput
            CALL TKTAKE
            CALL TKTAKE
%ELSE
            CALL SATAKE
            JR   C,TKCHRERR
            CALL SATAKE
            JR   C,TKCHRERR
%ENDIF
            LD   C,A
            CP   $27
            JR   Z,TKCHRERR
            CP   $5C
            JR   Z,TKCHRERR
            SUB  $20
            CP   $5F
            JR   NC,TKCHRERR
%IF TargetStreamingOutput
            CALL TKTAKE
%ELSE
            CALL SATAKE
            JR   C,TKCHRERR
%ENDIF
            CP   $27
            JR   NZ,TKCHRERR
            CALL TKINLINE
            DB  TNCHAR

; Return carry and the decoded nibble for one hexadecimal digit. Tokenization
; needs only the validity flag; the static-image decoder reuses the value.
; Contract: in A out A,carry clobbers zero,sign,parity,halfCarry
TKHEX:
            SUB  '0'
            CP   10
            RET  C
            OR   $20
            SUB  'a'-'0'
            CP   6
            RET  NC
            SUB  $F6
            RET

; Consume and validate one hexadecimal escape digit. Production diagnostics
; do not return. Returning historical slices clear carry after a valid digit,
; distinguishing success from the diagnostic carry returned by the failure.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,DE,HL
TKTAKHEX:
%IF TargetStreamingOutput
            CALL TKTAKE
%ELSE
            CALL SATAKE
            JR   C,TKCHRERR
%ENDIF
            CALL TKHEX
%IF TargetStreamingOutput
            RET  C
            JR   TKCHRERR
%ELSE
            JR   NC,TKCHRERR
            OR   A
            RET
%ENDIF

; Scan and validate a bounded-string literal. BC returns the decoded byte
; length. TokenLexemePointer continues to identify the opening quote so the
; declaration parser can decode the bytes directly into the static image.
; Contract: out A,BC,carry,zero clobbers sign,parity,halfCarry,D,DE,HL
TKSTRING:
%IF NativeStreamingSource
            CALL SHPIN
%ENDIF
%IF TargetStreamingOutput
            CALL TKTAKE
%ELSE
            CALL SATAKE
            JR   C,TKCHRERR
%ENDIF
            LD   C,B                     ; B=0 after punctuation exhaustion
TKSTRNXT:
%IF TargetStreamingOutput
            CALL TKTAKE
%ELSE
            CALL SATAKE
            JR   C,TKCHRERR
%ENDIF
            CP   '"'
            JR   Z,TKSTREND
            CP   $5C
            JR   Z,TKSTRESC
            SUB  $20
            CP   $5F
            JR   NC,TKCHRERR
TKSTRCNT:
            INC  C
            JR   Z,TKCHRERR
            JR   TKSTRNXT
TKSTRESC:
%IF TargetStreamingOutput
            CALL TKTAKE
%ELSE
            CALL SATAKE
            JR   C,TKCHRERR
%ENDIF
            CP   'x'
            JR   Z,TKSTRHEX
            LD   HL,TKESCTAB
            LD   E,C
            LD   C,TKESCCNT     ; B=0 after punctuation exhaustion
            CPIR
            LD   C,E
            JR   Z,TKSTRCNT
            JR   TKCHRERR
TKSTRHEX:
%IF TargetStreamingOutput
            CALL TKTAKHEX
            CALL TKTAKHEX
%ELSE
            CALL TKTAKHEX
            RET  C
            CALL TKTAKHEX
            RET  C
%ENDIF
            JR   TKSTRCNT
TKSTREND:
%IF NativeStreamingSource
            CALL SHPINEND
%ENDIF
            LD   A,C
            LD   (TNLEN),A
            CALL TKINLINE
            DB  TNSTRLIT

%IF TargetStreamingOutput
; The production entry alias is defined after its target below.
%ELSE
; Contract: out A,BC,carry,zero clobbers sign,parity,halfCarry,D,DE,HL
TKNEXT:
            JR   TKNEXTLP
%ENDIF

TKEOF:
            LD   HL,(SSLNTOK)
            LD   A,H                     ; SourceDelimiterDepth
            OR   A
            JR   NZ,TKLINERR
%IF AggregateCallSlices
            LD   A,(SSPREM)
            ADD  A,A
            JR   C,TKPART
%IF TargetStreamingOutput
            AND  SSPREMM*2
%ELSE
            OR   A
%ENDIF
            JR   Z,TKALLEOF
            LD   A,L
            OR   A
            JR   Z,TKPART
            LD   HL,SSPREM
            SET  7,(HL)
            JR   TKNEWLN
TKPART:
            LD   HL,SSPREM
%IF TargetStreamingOutput
            LD   A,(HL)
            AND  $3F
            ADD  A,SSPORDST-1
            LD   (HL),A
%ELSE
            RES  7,(HL)
            DEC  (HL)
%ENDIF
%IF NativeStreamingSource
            CALL SHPART
%ELSE
            LD   HL,(SSPDCUR)
            CALL SALDPART
%ENDIF
            JR   TKNEXTLP
TKALLEOF:
%ENDIF
            LD   A,L
            OR   A
%IF NativeStreamingSource
            JR   NZ,TKNEWLN
            CALL SHEND
            XOR  A
            RET
%ELSE
            RET  Z
%ENDIF
TKNEWLN:
            XOR  A
            LD   (SSLNTOK),A
            INC  A                       ; TokenNewline
            RET
TKLINERR:
            JP   TKLEXERR

TKCRLF:
            CALL SATAKPEK
            JR   C,TKLINERR
            CP   10
            JR   NZ,TKLINERR
TKLF:
            CALL SATAKE
TKLINE:
%IF AggregateCallSlices
            LD   HL,(SSLINE)
            INC  HL
            LD   (SSLINE),HL
            LD   HL,1
            LD   (SSCOL),HL
%ELSE
            CALL SALINE
%ENDIF
            LD   HL,(SSLNTOK)
            LD   A,H                     ; SourceDelimiterDepth
            OR   A
            JR   NZ,TKNEXTLP
            LD   A,L
            OR   A
            JR   Z,TKNEXTLP
            JR   TKNEWLN

; Contract: out A,BC,carry,zero clobbers sign,parity,halfCarry,D,DE,HL
TKNEXTLP:
%IF TargetStreamingOutput
TKNEXT EQU TKNEXTLP
%ENDIF
            CALL TKSTART
            JR   C,TKEOF

            CP   ' '
            JR   Z,TKSKIP
            CP   9
            JR   Z,TKSKIP
            CP   10
            JR   Z,TKLF
            CP   13
            JR   Z,TKCRLF
            CP   '/'
            JR   Z,TKSLASH
            LD   C,TNLPAR
            CP   '('
            JR   Z,TKOPEN
            INC  C
            CP   ')'
            JR   Z,TKCLOSE
            CP   '<'
            JR   Z,TKCMP
            CP   '>'
            JR   Z,TKCMP
            LD   HL,KWPUNCT
            LD   B,KWPUNCNT
TKTRYPUN:
            CP   (HL)
            INC  HL
            JR   Z,TKPUNCT
            INC  HL
            DJNZ TKTRYPUN
            CP   $27
            JP   Z,TKCHAR
            CP   '"'
            JP   Z,TKSTRING
            CP   '0'
            JR   C,TKTRYNAM
            CP   '9'+1
            JP   C,TKNUM
TKTRYNAM:
            CALL TKLETTER
            JP   C,TKNAME
            LD   C,TNLBRK
            CP   '['
            JR   Z,TKOPEN
            INC  C
            CP   ']'
            JR   Z,TKCLOSE
            JR   TKBADTOK

TKSKIP:
            CALL SATAKE
            JR   TKNEXTLP

TKSLASH:
            LD   C,TNSLASH
            CALL SATAKPEK
            JR   C,TKENDC
            CP   '/'
            JR   NZ,TKENDC
            CALL SATAKPEK
TKCOMMLP:
            JR   C,TKNEXTLP
            CP   10
            JR   Z,TKNEXTLP
            CP   13
            JR   Z,TKNEXTLP
            CALL SATAKPEK
            JR   TKCOMMLP

TKPUNCT:
            LD   C,(HL)
            LD   A,B
            CP   3
            JR   NC,TKSIMPLE
            LD   B,C
            JP   TKBASED

TKCLOSE:
            LD   HL,SSDELDEP
            LD   A,(HL)
            OR   A
            JR   Z,TKBADTOK
            DEC  (HL)
            JR   TKSIMPLE
TKOPEN:
            CALL SATAKE
            LD   HL,SSDELDEP
            INC  (HL)
            JR   NZ,TKENDC
%IF TargetStreamingOutput
%ELSE
            DEC  (HL)
%ENDIF
TKBADTOK:
            JP   TKLEXERR

TKCMP:
            SUB  '<'-TNLT
            LD   C,A
            CALL SATAKPEK
            JR   C,TKENDC
            SUB  '='
            JR   Z,TKCMPEQ
            DEC  A
            JR   NZ,TKENDC
            BIT  1,C
            JR   NZ,TKENDC
            LD   C,TNNOTEQ
            JR   TKCMPTAK
TKCMPEQ:
            INC  C
TKCMPTAK:

; Contract: in C out A,carry,zero clobbers sign,parity,halfCarry,DE,HL
TKSIMPLE:
            CALL SATAKE

; Contract: noreturn
TKENDC:
            LD   A,C
; Contract: in A out A,carry,zero clobbers sign,parity,halfCarry
TKEND:
            AND  $7F
            LD   (SSLNTOK),A
            RET

; The byte following the call is a token ordinal, not executable code.
; Contract: noreturn
TKINLINE:
            POP  HL
            LD   A,(HL)
            JR   TKEND
TKESCTAB:      DB "0nrt",$27,$22,"\\"
TKESCCNT       EQU 7
