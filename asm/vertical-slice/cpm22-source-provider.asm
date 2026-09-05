; CP/M source and retained-name provider for the native streaming compiler.
; The command adapter preflights and fills one fourteen-byte descriptor per
; part: twelve FCB-name bytes followed by the exact logical length.

CSFOPEN   EQU 15
CSFREAD   EQU 20
CSFDMA    EQU 26
CSFRAND   EQU 33
CSDMA     EQU $0080
CSDESCSZ  EQU 14
CSRETCAP  EQU 255
CSRETSZ   EQU 4
CSPARTPH  EQU 0
CSBYTEPH  EQU 1
CSDONEPH  EQU 2

CSDESCS   EQU CSWKBASE
CSDESCEN  EQU CSDESCS+SRCPARTS*CSDESCSZ
CSSTRFCB  EQU CSDESCEN
CSRANFCB  EQU CSSTRFCB+36
CSPARTN   EQU CSRANFCB+36
CSNXTPRT  EQU CSPARTN+1
CSPHASE   EQU CSNXTPRT+1
CSACTPRT  EQU CSPHASE+1
CSLEFT    EQU CSACTPRT+1
CSRETN    EQU CSLEFT+2
CSMATID   EQU CSRETN+1
CSSVLEN   EQU CSMATID+1
CSSVPART  EQU CSSVLEN+1
CSSVOFF   EQU CSSVPART+1
CSSVEND   EQU CSSVOFF+2
CSSVPTR   EQU CSSVEND+2
CSSVHND   EQU CSSVPTR+2
CSNLEFT   EQU CSSVLEN
CSNLEN    EQU CSSVPART
CSNOFF    EQU CSSVEND
CSNCUR    EQU CSSVOFF
CSCOPYN   EQU CSSVHND
CSCMPLEN  EQU CSSVOFF
CSSTEND   EQU CSSVHND+1
CSRETTAB  EQU CSSTEND
CSRETEND  EQU CSRETTAB+CSRETCAP*CSRETSZ
CSSCRAT   EQU CSRETEND
CSSCREND  EQU CSSCRAT+255
CSWKEND   EQU CSSCREND

CSCODE:
; The command adapter owns PartCount and descriptors. Reset everything whose
; lifetime is one compilation without paying to clear the dead table bytes.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CSBEGIN:
            LD   A,(CSPARTN)
            OR   A
            JP   Z,CSINVAL
            CP   SRCPARTS+1
            JP   NC,CSINVAL
            LD   HL,CSNXTPRT
            LD   DE,CSNXTPRT+1
            LD   BC,CSSTEND-CSNXTPRT-1
            XOR  A
            LD   (HL),A
            LDIR
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry
CSEND:
            XOR  A
            RET

; Existing compiler event ABI: A=event, C=one-based part, HL=bytes, DE=count.
; Contract: out A,C,DE,HL,carry,zero clobbers sign,parity,halfCarry,B
CSNEXT:
            LD   A,(CSPHASE)
            OR   A
            JR   Z,CSPARTEV
            DEC  A
            JP   Z,CSBYTES
            JP   CSINVAL
CSPARTEV:
            LD   A,(CSNXTPRT)
            LD   B,A
            LD   A,(CSPARTN)
            CP   B
            JR   Z,CSUNITEV
            LD   A,B
            INC  A
            LD   (CSNXTPRT),A
            LD   (CSACTPRT),A
            CALL CSDESC
            RET  C
            PUSH HL
            LD   DE,12
            ADD  HL,DE
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            LD   (CSLEFT),DE
            POP  HL
            LD   DE,CSSTRFCB
            CALL FCBMAKE
            LD   DE,CSSTRFCB
            LD   C,CSFOPEN
            CALL BDOSCALL
            INC  A
            JP   Z,CSIOERR
            LD   A,CSBYTEPH
            LD   (CSPHASE),A
            LD   A,(CSACTPRT)
            LD   C,A
            LD   A,1
            JP   CSEMPTY
CSUNITEV:
            LD   A,CSDONEPH
            LD   (CSPHASE),A
            LD   C,0
            LD   A,3
            JP   CSEMPTY

CSBYTES:
            LD   HL,(CSLEFT)
            LD   A,H
            OR   L
            JR   Z,CSENDEV
            LD   DE,SRCCHUNK
            LD   C,CSFDMA
            CALL BDOSCALL
            LD   DE,CSSTRFCB
            LD   C,CSFREAD
            CALL BDOSCALL
            OR   A
            JP   NZ,CSIOERR
            LD   HL,(CSLEFT)
            LD   DE,128
            OR   A
            SBC  HL,DE
            JR   C,CSSHORT
            LD   (CSLEFT),HL
            JR   CSOUTPUT
CSSHORT:
            ADD  HL,DE
            EX   DE,HL
            LD   HL,0
            LD   (CSLEFT),HL
CSOUTPUT:
            LD   HL,SRCCHUNK
            LD   A,(CSACTPRT)
            LD   C,A
            XOR  A
            RET
CSENDEV:
            XOR  A
            LD   (CSPHASE),A
            LD   A,(CSACTPRT)
            LD   C,A
            LD   A,2
            JP   CSEMPTY

; Contract: in A,C out A,C,DE,HL,carry,zero clobbers sign,parity,halfCarry
CSEMPTY:
            LD   HL,0
            LD   D,H
            LD   E,L
            OR   A
            RET

; Compiler retain ABI: HL=bytes, B=length, C=part, DE=part offset. B/C/DE are
; caller-live; the returned nonzero HL is a one-byte handle widened to a word.
; Contract: in HL,B,C,DE out A,HL,carry,zero clobbers sign,parity,halfCarry
CSRETAIN:
            PUSH BC
            PUSH DE
            PUSH IX
            CALL CSRETBOD
            POP  IX
            POP  DE
            POP  BC
            RET

; Contract: in HL,B,C,DE out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX
CSRETBOD:
            ; A materialized parameter retains its original identity even after
            ; the parser advances. Compare the actual spelling before reusing
            ; that identity; current part/offset belongs only to a fresh token.
            ; Comparison overlays provider scratch, so retain the complete
            ; original request on the stack until the outcome is known.
            PUSH BC
            PUSH DE
            PUSH HL
            CALL CSREUSE
            POP  HL
            POP  DE
            POP  BC
            RET  C
            JR   NZ,CSFRESH
            LD   L,A
            LD   H,0
            XOR  A
            RET

CSFRESH:
            LD   (CSSVPTR),HL
            LD   A,B
            LD   (CSSVLEN),A
            LD   A,C
            LD   (CSSVPART),A
            LD   (CSSVOFF),DE
            CALL CSCHKPOS
            RET  C
CSAPPEND:
            LD   A,(CSRETN)
            CP   CSRETCAP
            JP   Z,CSCAPERR
            INC  A
            LD   (CSRETN),A
            LD   (CSSVHND),A
            CALL CSENTRY
            LD   A,(CSSVPART)
            LD   (HL),A
            INC  HL
            LD   DE,(CSSVOFF)
            LD   (HL),E
            INC  HL
            LD   (HL),D
            INC  HL
            LD   A,(CSSVLEN)
            LD   (HL),A
            LD   A,(CSSVHND)
            LD   L,A
            LD   H,0
            XOR  A
            RET

; Z with A=original handle means exact materialized identity; NZ means a fresh
; request. Carry remains a storage/invalid error, never an equality result.
; Contract: in HL,B out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX
CSREUSE:
            LD   DE,CSSCRAT
            OR   A
            SBC  HL,DE
            JP   NZ,CSNEQUAL
            LD   A,(CSMATID)
            OR   A
            JP   Z,CSNEQUAL
            LD   L,A
            LD   H,0
            LD   IX,CSSCRAT
            CALL CSCMPNAM
            RET  C
            RET  NZ
            LD   A,(CSMATID)
            RET

; Compiler compare ABI: HL=handle, IX=current bytes, B=length; Z means equal.
; Contract: in HL,IX,B out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CSCMPNAM:
            LD   A,B
            LD   (CSCMPLEN),A
            PUSH HL
            PUSH IX
            POP  HL
            LD   (CSSVPTR),HL
            POP  HL
            CALL CSPRENAM
            RET  C
            LD   A,(CSCMPLEN)
            CP   B
            JR   NZ,CSNEQUAL
CSCMPREC:
            CALL CSRDNAME
            RET  C
            LD   DE,(CSSVPTR)
            LD   B,C
CSCMPLOP:
            LD   A,(DE)
            CP   (HL)
            JR   NZ,CSNEQUAL
            INC  DE
            INC  HL
            DJNZ CSCMPLOP
            LD   (CSSVPTR),DE
            LD   A,(CSNLEFT)
            OR   A
            JR   NZ,CSCMPREC
            XOR  A
            RET
CSNEQUAL:
            LD   A,1
            OR   A
            RET

; Compiler materialize ABI: HL=handle; return stable HL and exact B while
; preserving the caller's C and DE values.
; Contract: in HL out A,B,HL,carry,zero clobbers sign,parity,halfCarry
CSMATNAM:
            PUSH BC
            PUSH DE
            LD   A,L
            LD   (CSMATID),A
            CALL CSMATBOD
            POP  DE
            POP  BC
            PUSH AF
            LD   A,(CSNLEN)
            LD   B,A
            POP  AF
            RET

; Validate a retained handle and return its four-byte entry in HL.
; Contract: in HL out A,HL,carry,zero clobbers sign,parity,halfCarry,BC,DE
CSHANDLE:
            LD   A,H
            OR   A
            JP   NZ,CSINVAL
            LD   A,L
            OR   A
            JP   Z,CSINVAL
            LD   B,A
            LD   A,(CSRETN)
            CP   B
            JP   C,CSINVAL
            LD   A,B
            JP   CSENTRY

; Contract: in A out A,HL,carry,zero clobbers sign,parity,halfCarry,DE
CSENTRY:
            DEC  A
            LD   L,A
            LD   H,0
            ADD  HL,HL
            ADD  HL,HL
            LD   DE,CSRETTAB
            ADD  HL,DE
            OR   A
            RET

; Validate and reopen the source which owns a retained name. Comparison reads
; each DMA record in place; materialization alone writes the stable scratch.
; Contract: in HL out A,B,carry,zero clobbers sign,parity,halfCarry,C,DE,HL
CSPRENAM:
            LD   A,L
            LD   (CSSVHND),A
            CALL CSHANDLE
            RET  C
            LD   A,(HL)
            LD   (CSSVPART),A
            INC  HL
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            LD   (CSNOFF),DE
            INC  HL
            LD   A,(HL)
            LD   (CSNLEFT),A
            LD   A,(CSSVPART)
            CALL CSDESC
            RET  C
            LD   DE,CSRANFCB
            CALL FCBMAKE
            LD   DE,CSRANFCB
            LD   C,CSFOPEN
            CALL BDOSCALL
            INC  A
            JP   Z,CSIOERR
            LD   A,(CSNLEFT)
            LD   (CSNLEN),A
            LD   B,A
            XOR  A
            RET

; Contract: in HL out A,B,HL,carry,zero,sign,parity,halfCarry clobbers C,DE
CSMATBOD:
            CALL CSPRENAM
            RET  C
            LD   HL,CSSCRAT
            LD   (CSNCUR),HL
CSMATREC:
            CALL CSRDNAME
            RET  C
            LD   DE,(CSNCUR)
            LDIR
            LD   (CSNCUR),DE
            LD   A,(CSNLEFT)
            OR   A
            JR   NZ,CSMATREC
            LD   A,(CSNLEN)
            LD   B,A
            LD   HL,CSSCRAT
            XOR  A
            RET

; Read the next retained-name segment. Return HL=DMA bytes and C=count after
; advancing the saved logical offset and remaining length.
; Contract: out A,BC,HL,carry,zero clobbers sign,parity,halfCarry,DE
CSRDNAME:
            LD   HL,(CSNOFF)
            LD   A,L
            RLCA
            AND  1
            LD   E,A
            LD   A,H
            ADD  A,A
            OR   E
            LD   (CSRANFCB+33),A
            LD   A,H
            RLCA
            AND  1
            LD   (CSRANFCB+34),A
            XOR  A
            LD   (CSRANFCB+35),A
            LD   DE,CSDMA
            LD   C,CSFDMA
            CALL BDOSCALL
            LD   DE,CSRANFCB
            LD   C,CSFRAND
            CALL BDOSCALL
            OR   A
            JP   NZ,CSIOERR

            LD   HL,(CSNOFF)
            LD   A,L
            AND  127
            LD   E,A
            LD   A,128
            SUB  E
            LD   C,A
            LD   A,(CSNLEFT)
            CP   C
            JR   NC,CSCOPYOK
            LD   C,A
CSCOPYOK:
            LD   A,C
            LD   (CSCOPYN),A
            LD   B,0
            LD   HL,CSDMA
            LD   D,B
            ADD  HL,DE
            PUSH HL
            LD   A,(CSCOPYN)
            LD   C,A
            LD   B,0
            LD   HL,(CSNOFF)
            ADD  HL,BC
            LD   (CSNOFF),HL
            LD   A,(CSNLEFT)
            SUB  C
            LD   (CSNLEFT),A
            POP  HL
            XOR  A
            RET

; Validate the part and complete [offset, offset+length) range captured by
; RetainName against its preflighted descriptor.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CSCHKPOS:
            LD   A,(CSSVLEN)
            OR   A
            JP   Z,CSINVAL
            LD   E,A
            LD   D,0
            LD   HL,(CSSVOFF)
            ADD  HL,DE
            JP   C,CSINVAL
            LD   (CSSVEND),HL
            LD   A,(CSSVPART)
            CALL CSDESC
            RET  C
            LD   DE,12
            ADD  HL,DE
            LD   C,(HL)
            INC  HL
            LD   B,(HL)
            LD   HL,(CSSVEND)
            OR   A
            SBC  HL,BC
            JP   C,CSPOSOK
            JP   NZ,CSINVAL
CSPOSOK:
            XOR  A
            RET

; A is a one-based part ID. Return its descriptor only inside PartCount.
; Contract: in A out A,HL,carry,zero clobbers sign,parity,halfCarry,B,DE
CSDESC:
            OR   A
            JP   Z,CSINVAL
            LD   B,A
            LD   A,(CSPARTN)
            CP   B
            JP   C,CSINVAL
            LD   A,B
            DEC  A
            LD   HL,CSDESCS
            LD   DE,CSDESCSZ
            RET  Z
CSDESCLP:
            ADD  HL,DE
            DEC  A
            JR   NZ,CSDESCLP
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry
CSINVAL:
            LD   A,NSTATINV
            SCF
            RET
; Contract: out A,carry,zero clobbers sign,parity,halfCarry
CSCAPERR:
            LD   A,NSTATCAP
            SCF
            RET
; Contract: out A,carry,zero clobbers sign,parity,halfCarry
CSIOERR:
            LD   A,NSTATIO
            SCF
            RET
CSCODEND:
