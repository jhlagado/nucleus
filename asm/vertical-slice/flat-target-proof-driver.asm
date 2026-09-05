RTEND:

            ; The driver follows the selected runtime and must finish before
            ; ExecutionBase. Keeping the two adjacent prevents the proof from
            ; overlapping the adapter's saved high-memory logs.
; Contract: out carry,zero clobbers sign,parity,halfCarry,A,BC,DE,HL,IX,IY
FPSTART:
            LD   SP,STACKTOP
            XOR  A
            LD   (FPSTATUS),A
            LD   (FPCASE),A
            LD   (FACOMMIT),A
            LD   (FAABORT),A
            LD   (FAMAPFL),A
            LD   (FACOMFL),A
            LD   HL,FALOG
            LD   (FACURSOR),HL
            LD   A,73
            LD   (FPCASE),A
            CALL FPCAPCHK
            JP   C,FPREGFL
            LD   HL,$F000
            LD   DE,$1000
            LD   A,10
            LD   (FPCASE),A
            CALL FPREGION
            JP   C,FPREGFL
            LD   HL,$FFFF
            LD   (EMCUR),HL
            LD   HL,1
            LD   (EMLIM),HL
            LD   DE,1
            LD   A,46
            LD   (FPCASE),A
            CALL ZTCONEXT
            JP   C,FPREGFL
            LD   HL,(EMCUR)
            LD   A,H
            OR   L
            JP   NZ,FPREGFL
            LD   HL,(EMLIM)
            LD   A,H
            OR   L
            JP   NZ,FPREGFL
            LD   HL,$F001
            LD   DE,$1000
            LD   A,11
            LD   (FPCASE),A
            CALL FPREGION
            JP   NC,FPREGFL
            LD   A,(DGCODE)
            CP   DGTGTCAP
            JP   NZ,FPREGFL
            LD   HL,$8000
            LD   A,12
            LD   (FPCASE),A
            LD   (TGIMGBAS),HL
            LD   HL,$1000
            LD   (TGIMGCAP),HL
            LD   HL,$8F00
            LD   (TGWRBAS),HL
            LD   HL,$0200
            LD   (TGWRCAP),HL
            CALL FPLAYOUT
            JP   NC,FPREGFL
            LD   A,(DGCODE)
            CP   DGTGTCFG
            JP   NZ,FPREGFL
            LD   HL,$2000
            LD   A,13
            LD   (FPCASE),A
            LD   (TGIMGCAP),HL
            LD   HL,$9000
            LD   (TGWRBAS),HL
            LD   HL,$0100
            LD   (TGWRCAP),HL
            CALL FPLAYOUT
            JP   C,FPREGFL
            LD   A,(TGLAYMOD)
            OR   A
            JP   NZ,FPREGFL
            LD   A,14
            LD   (FPCASE),A
            LD   A,1
            LD   HL,FSPARTS
            LD   IX,FDEARLY
            CALL CTACPART
            JP   NC,FPLOADFL
            CALL FPCOMSTK
            JP   NZ,FPLOADFL
            LD   A,(DGCODE)
            CP   DGTGTCAP
            JP   NZ,FPLOADFL
            LD   A,15
            LD   (FPCASE),A
            XOR  A
            LD   (FACOMMIT),A
            LD   (FAABORT),A
            LD   A,61
            LD   (FAFAILCT),A
            LD   HL,FALOG
            LD   (FACURSOR),HL
            LD   A,1
            LD   HL,FSPARTS
            LD   IX,FDLOADED
            CALL CTACPART
            JP   NC,FPLOADFL
            LD   A,(DGCODE)
            CP   DGTGTOUT
            JP   NZ,FPLOADFL
            LD   A,(FACOMMIT)
            OR   A
            JP   NZ,FPLOADFL
            LD   A,(FAABORT)
            CP   1
            JP   NZ,FPLOADFL
            LD   A,16
            LD   (FPCASE),A
            XOR  A
            LD   (FACOMMIT),A
            LD   (FAABORT),A
            LD   (FAFAILCT),A
            LD   HL,FALOG
            LD   (FACURSOR),HL
            LD   A,1
            LD   HL,FSPARTS
            LD   IX,FDLOADED
            CALL CTACPART
            JP   C,FPLOADFL
            CALL FPCOMSTK
            JP   NZ,FPLOADFL
            LD   A,(TGLAYMOD)
            OR   A
            JP   NZ,FPLOADFL
            LD   HL,(TCROBAS)
            LD   DE,$82D4+(RIVECBYT-33)+(RIBYTES-689)
            OR   A
            SBC  HL,DE
            JP   NZ,FPLOADFL
            LD   HL,(EMCUR)
            LD   DE,(TGIMGBAS)
            OR   A
            SBC  HL,DE
            LD   DE,$1048+(RIVECBYT-33)+(RISTBYT-37)
            OR   A
            SBC  HL,DE
            JP   NZ,FPLOADFL
            LD   HL,(TGROLEN)
            LD   A,H
            OR   L
            JP   NZ,FPLOADFL
            LD   HL,(TGCODBAS)
            LD   DE,$82D4+(RIVECBYT-33)+(RIBYTES-689)
            OR   A
            SBC  HL,DE
            JP   NZ,FPLOADFL
            LD   HL,(TGWRBAS)
            LD   DE,$9000
            OR   A
            SBC  HL,DE
            JP   NZ,FPLOADFL
            CALL ZTINITLN
            LD   DE,RIVECBYT+RISTBYT+2
            OR   A
            SBC  HL,DE
            JP   NZ,FPLOADFL
            LD   HL,(TGWRBAS)
            LD   DE,$9000
            OR   A
            SBC  HL,DE
            JP   NZ,FPLOADFL
            LD   HL,(TCROCAP)
            LD   A,H
            OR   L
            JP   NZ,FPLOADFL
            LD   HL,(FACURSOR)
            LD   DE,FALOG
            OR   A
            SBC  HL,DE
            LD   (FALDLEN),HL
            LD   B,H
            LD   C,L
            LD   HL,FALOG
            LD   DE,FALDLOG
            LDIR
            LD   A,17
            LD   (FPCASE),A
            LD   A,1
            LD   HL,FSPARTS
            LD   IX,FDBADFLG
            CALL CTACPART
            JP   NC,FPCONFFL
            CALL FPCOMSTK
            JP   NZ,FPCONFFL
            LD   A,(DGCODE)
            LD   (FADIAG),A
            LD   A,(FAABORT)
            OR   A
            JP   NZ,FPCONFFL
            LD   A,18
            LD   (FPCASE),A
            LD   A,1
            LD   HL,FSPARTS
            LD   IX,FDSTKFIT
            CALL CTACPART
            JP   C,FPREGFL
            LD   A,19
            LD   (FPCASE),A
            LD   A,1
            LD   HL,FSPARTS
            LD   IX,FDSTKOVR
            CALL CTACPART
            JP   NC,FPREGFL
            LD   A,(DGCODE)
            CP   DGTGTCAP
            JP   NZ,FPREGFL
            XOR  A
            LD   (FACOMMIT),A
            LD   (FAABORT),A
            LD   A,20
            LD   (FPCASE),A
            LD   (FAFAILCT),A
            LD   A,1
            LD   HL,FSPARTS
            LD   IX,FDDFLT
            CALL CTACPART
            JP   NC,FPATOMFL
            CALL FPCOMSTK
            JP   NZ,FPATOMFL
            LD   A,21
            LD   (FPCASE),A
            LD   A,(DGCODE)
            CP   DGTGTOUT
            JP   NZ,FPATOMFL
            LD   A,22
            LD   (FPCASE),A
            LD   A,(FACOMMIT)
            OR   A
            JP   NZ,FPATOMFL
            LD   A,23
            LD   (FPCASE),A
            LD   A,(FAABORT)
            CP   1
            JP   NZ,FPATOMFL
            LD   A,24
            LD   (FPCASE),A
            LD   HL,(FACURSOR)
            LD   DE,FALOG
            OR   A
            SBC  HL,DE
            LD   A,H
            OR   L
            JP   Z,FPATOMFL
            LD   A,30
            LD   (FPCASE),A
            XOR  A
            LD   (FACOMMIT),A
            LD   (FAABORT),A
            LD   (FAFAILCT),A
            INC  A
            LD   (FAMAPFL),A
            LD   HL,FALOG
            LD   (FACURSOR),HL
            LD   A,1
            LD   HL,FSTRPPRT
            LD   IX,FDDFLT
            CALL CTACPART
            JP   NC,FPATOMFL
            CALL FPCOMSTK
            JP   NZ,FPATOMFL
            LD   A,(DGCODE)
            CP   DGTGTOUT
            JP   NZ,FPATOMFL
            LD   A,(FACOMMIT)
            OR   A
            JP   NZ,FPATOMFL
            LD   A,(FAABORT)
            CP   1
            JP   NZ,FPATOMFL
            LD   HL,(FACURSOR)
            LD   DE,FALOG
            OR   A
            SBC  HL,DE
            LD   (FAFAILLN),HL
            LD   B,H
            LD   C,L
            LD   HL,FALOG
            LD   DE,FAFAILLG
            LDIR

            ; COMMIT fails after the target bank selector has closed. The
            ; local late-output path must abort once; the synthetic diagnostic
            ; continuation must observe the closed selector and not abort
            ; again.
            LD   A,31
            LD   (FPCASE),A
            XOR  A
            LD   (FACOMMIT),A
            LD   (FAABORT),A
            LD   (FAMAPFL),A
            INC  A
            LD   (FACOMFL),A
            LD   HL,FALOG
            LD   (FACURSOR),HL
            LD   A,1
            LD   HL,FSTRPPRT
            LD   IX,FDDFLT
            CALL CTACPART
            JP   NC,FPATOMFL
            CALL FPCOMSTK
            JP   NZ,FPATOMFL
            LD   A,(DGCODE)
            CP   DGTGTOUT
            JP   NZ,FPATOMFL
            LD   A,(FACOMMIT)
            OR   A
            JP   NZ,FPATOMFL
            LD   A,(FAABORT)
            CP   1
            JP   NZ,FPATOMFL
            LD   A,25
            LD   (FPCASE),A
            XOR  A
            LD   (FACOMMIT),A
            LD   (FAABORT),A
            LD   (FAFAILCT),A
            LD   (FAMAPFL),A
            LD   (FACOMFL),A
            LD   HL,FALOG
            LD   (FACURSOR),HL
            LD   A,1
            LD   HL,FSPARTS
            LD   IX,FDDFLT
            CALL CTACPART
            JP   C,FPCOMPFL
            LD   A,(FACOMMIT)
            CP   1
            JP   NZ,FPCOMTFL
            LD   A,(FAABORT)
            OR   A
            JP   NZ,FPCOMTFL
            LD   HL,(FACBEGIN+TDIMGBAS)
            LD   DE,$8000
            OR   A
            SBC  HL,DE
            JP   NZ,FPBEGFL
            LD   A,(TGLAYMOD)
            CP   TGLAYROM
            JP   NZ,FPREGFL
            LD   HL,(TCRTBAS)
            LD   DE,$8003
            OR   A
            SBC  HL,DE
            JP   NZ,FPCTXFL
            LD   HL,(TCSTBAS)
            LD   DE,$4000+RIVECBYT
            OR   A
            SBC  HL,DE
            JP   NZ,FPCTXFL
            LD   HL,(TGIMGBAS)
            LD   DE,$8000
            OR   A
            SBC  HL,DE
            JP   NZ,FPMAPFL
            LD   HL,(TGROBAS)
            LD   DE,$82EC+(RIVECBYT-33)+(RIBYTES-689)
            OR   A
            SBC  HL,DE
            JP   NZ,FPMAPFL
            LD   HL,(TGWRBAS)
            LD   DE,$4000
            OR   A
            SBC  HL,DE
            JP   NZ,FPMAPFL
            CALL ZTINITLN
            LD   DE,RIVECBYT+RISTBYT+2
            OR   A
            SBC  HL,DE
            JP   NZ,FPMAPFL
            LD   HL,(TGBSSBAS)
            LD   DE,$4000+RIVECBYT+RISTBYT+2
            OR   A
            SBC  HL,DE
            JP   NZ,FPMAPFL
            LD   HL,(TGROBAS)
            LD   DE,$82EC+(RIVECBYT-33)+(RIBYTES-689)
            OR   A
            SBC  HL,DE
            JP   NZ,FPMAPFL
            LD   HL,(FACURSOR)
            LD   DE,FALOG
            OR   A
            SBC  HL,DE
            LD   (FALOGLEN),HL
            LD   A,H
            OR   L
            JP   Z,FPLOGFL
            LD   B,H
            LD   C,L
            LD   HL,FALOG
            LD   DE,FAOKLOG
            LDIR

            XOR  A
            LD   (FACOMMIT),A
            LD   (FAABORT),A
            LD   (FAFAILCT),A
            LD   HL,FALOG
            LD   (FACURSOR),HL
            LD   A,1
            LD   HL,FSTRPPRT
            LD   IX,FDDFLT
            CALL CTACPART
            JP   C,FPCOMPFL
            LD   HL,(FACURSOR)
            LD   DE,FALOG
            OR   A
            SBC  HL,DE
            LD   (FATRPLEN),HL
            LD   B,H
            LD   C,L
            LD   HL,FALOG
            LD   DE,FATRAPLG
            LDIR

            XOR  A
            LD   (FACOMMIT),A
            LD   (FAABORT),A
            LD   (FAFAILCT),A
            LD   HL,FALOG
            LD   (FACURSOR),HL
            LD   A,1
            LD   HL,FSUNHPRT
            LD   IX,FDDFLT
            CALL CTACPART
            JP   C,FPCOMPFL
            LD   HL,(FACURSOR)
            LD   DE,FALOG
            OR   A
            SBC  HL,DE
            LD   (FAUNHLEN),HL
            LD   B,H
            LD   C,L
            LD   HL,FALOG
            LD   DE,FAUNHLG
            LDIR

            LD   A,(DGCODE)
            LD   (FADIAG),A

            LD   A,40
            LD   (FPCASE),A
            LD   A,2
            LD   HL,FBPARTS
            LD   IX,FDBADPRT
            CALL CTACPART
            JP   NC,FPCONFFL
            LD   A,(DGCODE)
            CP   DGTGTCFG
            JP   NZ,FPCONFFL

            LD   A,41
            LD   (FPCASE),A
            LD   A,2
            LD   HL,FBPARTS
            LD   IX,FDBADENT
            CALL CTACPART
            JP   NC,FPCONFFL
            LD   A,(DGCODE)
            CP   DGTGTCFG
            JP   NZ,FPCONFFL

            LD   A,42
            LD   (FPCASE),A
            LD   A,2
            LD   HL,FBCONPRT
            LD   IX,FDFAIL
            CALL CTACPART
            JP   NC,FPCONFFL
            LD   A,(DGCODE)
            CP   DGTGTCFG
            JP   NZ,FPCONFFL

            LD   A,43
            LD   (FPCASE),A
            XOR  A
            LD   (FACOMMIT),A
            LD   (FAABORT),A
            LD   (FAFAILCT),A
            LD   HL,FALOG
            LD   (FACURSOR),HL
            LD   A,2
            LD   HL,FBPARTS
            LD   IX,FDENTOVR
            CALL CTACPART
            JP   NC,FPCONFFL
            LD   A,(DGCODE)
            CP   DGTGTCAP
            JP   NZ,FPCONFFL
            LD   A,(FAABORT)
            DEC  A
            JP   NZ,FPATOMFL
            LD   A,(FACOMMIT)
            OR   A
            JP   NZ,FPATOMFL

            LD   A,44
            LD   (FPCASE),A
            XOR  A
            LD   (FACOMMIT),A
            LD   (FAABORT),A
            LD   (FAFAILCT),A
            LD   HL,FALOG
            LD   (FACURSOR),HL
            LD   A,2
            LD   HL,FBLRGPRT
            LD   IX,FDBNKOVR
            CALL CTACPART
            JP   NC,FPCONFFL
            LD   A,(DGCODE)
            CP   DGTGTCAP
            JP   NZ,FPFAIL
            LD   A,(FAABORT)
            DEC  A
            JP   NZ,FPATOMFL
            LD   A,(FACOMMIT)
            OR   A
            JP   NZ,FPATOMFL

            LD   A,45
            LD   (FPCASE),A
            XOR  A
            LD   (FAABORT),A
            LD   (FAFAILCT),A
            LD   HL,FALOG
            LD   (FACURSOR),HL
            LD   A,2
            LD   HL,FBPARPRT
            LD   IX,FDFAIL
            CALL CTACPART
            JP   NC,FPCONFFL
            CALL FPCOMSTK
            JP   NZ,FPCONFFL
            LD   A,(DGCODE)
            CP   DGTGTCFG
            JP   NZ,FPFAIL
            LD   A,(FAABORT)
            OR   A
            JP   NZ,FPATOMFL

            LD   A,46
            LD   (FPCASE),A
            XOR  A
            LD   (FAABORT),A
            LD   (FAFAILCT),A
            LD   HL,FALOG
            LD   (FACURSOR),HL
            LD   A,2
            LD   HL,FBRESPRT
            LD   IX,FDFAIL
            CALL CTACPART
            JP   NC,FPCONFFL
            LD   A,(DGCODE)
            CP   DGTGTCFG
            JP   NZ,FPFAIL

            LD   A,47
            LD   (FPCASE),A
            XOR  A
            LD   (FAABORT),A
            LD   (FAFAILCT),A
            LD   HL,FALOG
            LD   (FACURSOR),HL
            LD   A,2
            LD   HL,FBFWDPRT
            LD   IX,FDFAIL
            CALL CTACPART
            JP   NC,FPCONFFL
            LD   A,(DGCODE)
            CP   DGTGTCFG
            JP   NZ,FPFAIL

            XOR  A
            LD   (FACOMMIT),A
            LD   (FAABORT),A
            LD   (FAFAILCT),A
            LD   HL,FABTRLG
            LD   (FACURSOR),HL
            LD   A,2
            LD   HL,FBTRPPRT
            LD   IX,FDBANKED
            CALL CTACPART
            JP   C,FPCOMPFL
            LD   HL,(FACURSOR)
            LD   DE,FABTRLG
            OR   A
            SBC  HL,DE
            LD   (FABTRLEN),HL

            XOR  A
            LD   (FACOMMIT),A
            LD   (FAABORT),A
            LD   (FAFAILCT),A
            LD   HL,FAENTLG
            LD   (FACURSOR),HL
            LD   A,1
            LD   HL,FBENTPRT
            LD   IX,FDENTRY1
            CALL CTACPART
            JR   C,FPCOMPFL
            LD   HL,(FACURSOR)
            LD   DE,FAENTLG
            OR   A
            SBC  HL,DE
            LD   (FAENTLEN),HL

            XOR  A
            LD   (FACOMMIT),A
            LD   (FAABORT),A
            LD   (FAFAILCT),A
            LD   HL,FALOG
            LD   (FACURSOR),HL
            LD   A,2
            LD   HL,FBPARTS
            LD   IX,FDBANKED
            CALL CTACPART
            JR   C,FPCOMPFL
            LD   HL,(FACURSOR)
            LD   DE,FALOG
            OR   A
            SBC  HL,DE
            LD   (FABNKLEN),HL

            XOR  A
            LD   (FACOMMIT),A
            LD   (FAABORT),A
            LD   (FAFAILCT),A
            LD   HL,FAC21LG
            LD   (FACURSOR),HL
            LD   A,2
            LD   HL,FSC21PRT
            LD   IX,FDC21
            CALL CTACPART
            JR   C,FPCOMPFL
            LD   HL,(FACURSOR)
            LD   DE,FAC21LG
            OR   A
            SBC  HL,DE
            LD   (FAC21LEN),HL
            LD   A,(FADIAG)
            LD   (DGCODE),A
            LD   A,$A5
            LD   (FPSTATUS),A
            XOR  A
            LD   (FPCASE),A
            HALT

FPCOMPFL: LD A,1
            JR   FPFAIL
FPCOMTFL:  LD A,2
            JR   FPFAIL
FPBEGFL:   LD A,3
            JR   FPFAIL
FPCTXFL: LD A,4
            JR   FPFAIL
FPMAPFL:     LD A,5
            JR   FPFAIL
FPLOGFL:     LD A,6
            JR   FPFAIL
FPREGFL:  LD A,(FPCASE)
            JR   FPFAIL
FPLOADFL:  LD A,(FPCASE)
            JR   FPFAIL
FPATOMFL:  LD A,(FPCASE)
            JR   FPFAIL
FPCONFFL: LD A,(FPCASE)
FPFAIL:
            LD   (FPCASE),A
            LD   A,$E1
            LD   (FPSTATUS),A
            HALT

; Reserve A bytes atomically in the bounded proof-only operation log.
; Contract: in A out A,IY,carry,zero clobbers sign,parity,halfCarry,DE,HL
FARESERV:
            LD   E,A
            LD   A,(FAFAILCT)
            OR   A
            JR   Z,FARESCAP
            DEC  A
            LD   (FAFAILCT),A
            JR   NZ,FARESCAP
            LD   A,DGTGTOUT
            SCF
            RET
FARESCAP:
            LD   A,E
            LD   D,0
            LD   IY,(FACURSOR)
            PUSH IY
            POP  HL
            ADD  HL,DE
            LD   DE,FALOGLIM
            OR   A
            SBC  HL,DE
            JR   C,FARESRDY
            JR   Z,FARESRDY
            LD   A,DGTGTOUT
            SCF
            RET
FARESRDY:
            ADD  HL,DE
            LD   (FACURSOR),HL
            OR   A
            RET

; Contract: in IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IY
TSBEGIN:
            LD   HL,FACBEGIN
            LD   B,TDSZ
FABEGCPY:
            LD   A,(IX+0)
            LD   (HL),A
            INC  IX
            INC  HL
            DJNZ FABEGCPY
            LD   A,1
            LD   (FAOPEN),A
            OR   A
            RET

; Contract: in A,C,HL out A,carry,zero clobbers sign,parity,halfCarry,DE
TSBYTE:
            PUSH IY
            PUSH AF
            PUSH BC
            PUSH HL
            LD   A,7
            CALL FARESERV
            JR   C,FAIMGRES
            POP  HL
            POP  BC
            POP  AF
%IF DebugHooks
            OUT  (DTIMAGE),A
%ENDIF
            LD   (IY+0),1
            LD   (IY+1),C
            LD   (IY+2),L
            LD   (IY+3),H
            LD   (IY+4),1
            LD   (IY+5),0
            LD   (IY+6),A
            POP  IY
            OR   A
            RET
FAIMGFL:
            POP  IY
            RET
FAIMGRES:
            LD   E,A
            POP  HL
            POP  BC
            POP  AF
            POP  IY
            LD   A,E
            SCF
            RET

; Contract: in A,BC,DE,HL,IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
TSRTIMG:
            PUSH AF
            LD   A,3
            LD   (FARTKIND),A
            POP  AF
            JR   FARTSEL
; Contract: in A,BC,DE,HL,IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
TSRTINIT:
            PUSH AF
            LD   A,4
            LD   (FARTKIND),A
            POP  AF
FARTSEL:
            LD   (FARTBNK),A
            LD   (FARTLEN),BC
            LD   (FARTID),DE
            LD   (FARTADR),HL
            LD   A,8
            CALL FARESERV
            RET  C
            LD   A,(FARTBNK)
            LD   BC,(FARTLEN)
            LD   DE,(FARTID)
            LD   HL,(FARTADR)
            LD   A,(FARTKIND)
            LD   (IY+0),A
            LD   A,(FARTBNK)
            LD   (IY+1),A
            LD   (IY+2),L
            LD   (IY+3),H
            LD   (IY+4),C
            LD   (IY+5),B
            LD   (IY+6),E
            LD   (IY+7),D
            OR   A
            RET

; Contract: in A,C,HL out A,carry,zero clobbers sign,parity,halfCarry,DE
TSPATBYT:
            PUSH IY
            PUSH AF
            PUSH BC
            PUSH HL
            LD   A,7
            CALL FARESERV
            JR   C,FAPATRES
            POP  HL
            POP  BC
            POP  AF
            LD   (IY+0),2
            LD   (IY+1),C
            LD   (IY+2),L
            LD   (IY+3),H
            LD   (IY+4),1
            LD   (IY+5),0
            LD   (IY+6),A
            POP  IY
            OR   A
            RET
FAPATFL:
            POP  IY
            RET
FAPATRES:
            LD   E,A
            POP  HL
            POP  BC
            POP  AF
            POP  IY
            LD   A,E
            SCF
            RET

; Contract: in C,DE,HL out A,carry,zero clobbers sign,parity,halfCarry
TSPATWRD:
            PUSH IY
            PUSH BC
            PUSH DE
            PUSH HL
            LD   A,8
            CALL FARESERV
            POP  HL
            POP  DE
            POP  BC
            JR   C,FAPATWFL
            LD   (IY+0),2
            LD   (IY+1),C
            LD   (IY+2),E
            LD   (IY+3),D
            LD   (IY+4),2
            LD   (IY+5),0
            LD   (IY+6),L
            LD   (IY+7),H
            POP  IY
            OR   A
            RET
FAPATWFL:
            POP  IY
            RET

; Contract: in IX out A,carry,zero clobbers sign,parity,halfCarry
TSMAP:
            LD   A,(FAMAPFL)
            OR   A
            JR   Z,FAMAPRDY
            LD   A,DGTGTOUT
            SCF
            RET
FAMAPRDY:
            OR   A
            RET

; Contract: in IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
TSBANK:
            LD   A,(IX+TQBNKCNT-TQBASE)
            LD   B,A
            LD   L,(IX+TQBNKST-TQBASE)
            LD   H,(IX+TQBNKST-TQBASE+1)
            PUSH HL
            POP  IY
            LD   HL,FACCURS
            LD   DE,FACREMS
            LD   IX,FACROS
FAMAPBNK:
            LD   A,(IY+0)
            LD   (HL),A
            INC  HL
            LD   A,(IY+1)
            LD   (HL),A
            INC  HL
            LD   A,(IY+2)
            LD   (DE),A
            INC  DE
            LD   A,(IY+3)
            LD   (DE),A
            INC  DE
            LD   A,(IY+4)
            LD   (IX+0),A
            INC  IX
            LD   A,(IY+5)
            LD   (IX+0),A
            INC  IX
            PUSH DE
            LD   DE,TBSZ
            ADD  IY,DE
            POP  DE
            DJNZ FAMAPBNK
            OR   A
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry
TSCOMMIT:
            LD   A,(FACOMFL)
            OR   A
            JR   Z,FACOMRDY
            LD   A,DGTGTOUT
            SCF
            RET
FACOMRDY:
            LD   A,1
            LD   (FACOMMIT),A
            OR   A
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry
TSABORT:
            LD   A,(FAABORT)
            INC  A
            LD   (FAABORT),A
            OR   A
            RET

; Direct proof calls do not enter through the public compiler boundary. These
; wrappers plant their ordinary CALL continuation as the diagnostic return SP,
; so both success and a nonlocal diagnostic return to the same proof site.
; Contract: in DE,HL out A,carry,zero clobbers sign,parity,halfCarry,HL
FPREGION:
            LD   (CPABRTSP),SP
            JP   ZTVALREG

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
FPLAYOUT:
            LD   (CPABRTSP),SP
            JP   ZTCLASS

; Called only while ProofStart owns StackTop. The helper's return address is
; the sole expected two-byte displacement from that root stack pointer.
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
FPCOMSTK:
            LD   HL,0
            ADD  HL,SP
            LD   DE,STACKTOP-2
            OR   A
            SBC  HL,DE
            RET

; Exercise the production-only shared segmented-capacity predicate directly.
; Each wrapper plants its caller continuation as CompilerAbortSp, so a
; nonlocal diagnostic must restore the exact proof stack before returning.
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
FPCAPCHK:
            LD   HL,0
            ADD  HL,SP
            LD   (FPCAPSP),HL
            LD   HL,$0400
            CALL FPPRGCAP
            JR   C,FPCAPFL
            CALL FPCAPSTK
            JR   NZ,FPCAPFL
            LD   HL,$0400
            CALL FPROCAP
            JR   C,FPCAPFL
            CALL FPCAPSTK
            JR   NZ,FPCAPFL
            LD   HL,$0401
            CALL FPPRGCAP
            JR   NC,FPCAPFL
            LD   A,(DGCODE)
            CP   DGPDCAP
            JR   NZ,FPCAPFL
            CALL FPCAPSTK
            JR   NZ,FPCAPFL
            LD   HL,$0401
            CALL FPROCAP
            JR   NC,FPCAPFL
            LD   A,(DGCODE)
            CP   DGROCAP
            JR   NZ,FPCAPFL
            CALL FPCAPSTK
            JR   NZ,FPCAPFL
            LD   HL,$FFFF
            CALL FPPRGCAP
            JR   NC,FPCAPFL
            LD   A,(DGCODE)
            CP   DGPDCAP
            JR   NZ,FPCAPFL
            CALL FPCAPSTK
            JR   NZ,FPCAPFL
            LD   HL,$FFFF
            CALL FPROCAP
            JR   NC,FPCAPFL
            LD   A,(DGCODE)
            CP   DGROCAP
            JR   NZ,FPCAPFL
            CALL FPCAPSTK
            RET  NZ
            XOR  A
            RET
FPCAPFL:
            SCF
            RET

; Contract: in HL out A,HL,carry,zero clobbers sign,parity,halfCarry,B
FPPRGCAP:
            LD   (CPABRTSP),SP
            JP   APCKEXCA

; Contract: in HL out A,HL,carry,zero clobbers sign,parity,halfCarry,B
FPROCAP:
            LD   (CPABRTSP),SP
            JP   APCRDOCA

; Contract: out A,DE,HL,carry,zero clobbers sign,parity,halfCarry
FPCAPSTK:
            LD   HL,2
            ADD  HL,SP
            LD   DE,(FPCAPSP)
            OR   A
            SBC  HL,DE
            RET

FPSTATUS: DB 0
FPCASE:   DB 0
FPCAPSP: DW 0
FAOPEN: DB 0
FACOMMIT: DB 0
FAABORT:   DB 0
FACURSOR:    DW 0
FALOGLEN: DW 0
FALDLEN: DW 0
FATRPLEN: DW 0
FAUNHLEN: DW 0
FABNKLEN: DW 0
FAENTLEN: DW 0
FABTRLEN: DW 0
FAC21LEN: DW 0
FAFAILLN: DW 0
FAFAILCT: DB 0
FAMAPFL:       DB 0
FACOMFL:    DB 0
FADIAG:  DB 0
FACBEGIN:   DS TDSZ
FACCURS: DS TBKCAP*2
FACCUR0     EQU FACCURS
FACCUR1     EQU FACCURS+2
FACREMS: DS TBKCAP*2
FACREM0     EQU FACREMS
FACREM1     EQU FACREMS+2
FACROS: DS TBKCAP*2
FACRO0      EQU FACROS
FACRO1      EQU FACROS+2
FACMAPLN: DW 0
FACMAP: DS 1
FACRT       EQU TCRTBAS
FACSTATE    EQU TCSTBAS
FARTBNK:     DB 0
FARTKIND:     DB 0
FARTLEN:   DW 0
FARTID: DW 0
FARTADR:  DW 0
FARTCTX:  DW TGRTCTX
FARTCTXP    EQU FARTCTX
FPEND:

FALDLOG     EQU $99F0
FAOKLOG     EQU $9CF0
FATRAPLG    EQU $A0C0
FAUNHLG     EQU $A5C0
FABTRLG     EQU $ACC0
FALOG       EQU $B4C0
FAFAILLG    EQU $C6C0
FAENTLG     EQU $CBC0
FAC21LG     EQU $D0C0
FALOGLIM    EQU $F000
