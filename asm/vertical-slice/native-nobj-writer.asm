; Native flat-target NOBJ 0.1 writer. This host component is outside the
; compiler core. It receives the existing target-sink callbacks, uses bounded
; runtime-catalogue chunks, and stores tentative IMAGE, PATCH, and final NOBJ
; objects through the common named-object service.

NJCODE:

NJIMGH      EQU $5C40
NJPATH      EQU $5C42
NJOUTH      EQU $5C44
NJBEGP      EQU $5C46
NJMAPP      EQU $5C48
NJIMGCNT    EQU $5C4A
NJPATCNT    EQU $5C4C
NJCRC       EQU $5C4E
NJRTREQ     EQU $5C50
NJUSED      EQU $5C50
NJROBASE    EQU $5C52
NJINITN     EQU $5C54
NJAGGN      EQU $5C56
NJRON       EQU $5C58
NJAGGADR    EQU $5C5A
NJTAILP     EQU $5C5C
NJCOPYH     EQU $5C5E
NJFILL      EQU $5C60
NJABSTAT    EQU $5C61
NJFAIL      EQU $5C62
; RuntimeRequest occupies $5C50..$5C65. Bank count must survive every runtime
; catalogue call, so the persistent/map state starts after that overlay.
NJBANKN     EQU $5C66
NJSTATEP    EQU $5C67
NJBANKID    EQU $5C69
NJRECBUF    EQU $5C70
NJXFER      EQU $5D00
NJXFLIM     EQU $5E00
NJWKEND     EQU NJXFLIM

NJIMGNAM:  DB ".nucleus/image.work"
NJIMGNL     EQU $-NJIMGNAM
NJPATNAM:  DB ".nucleus/patch.work"
NJPATNL     EQU $-NJPATNAM
NJOUTNAM: DB ".nucleus/program.nobj"
NJOUTNL     EQU $-NJOUTNAM

NJPREFIX:
            DB 1,15,0,"NOBJ",0,1,0

; Contract: out A,carry,zero clobbers sign,parity,halfCarry
NJUNAVL:
            LD   A,NSTATNA
            SCF
            RET

; Contract: in IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
NJBEGIN:
            LD   A,(IX+11)
            DEC  A
            CP   4
            JR   C,NJBEGOK
            CALL NJUNAVL
            RET
NJBEGOK:
            LD   (NJBEGP),IX
            LD   A,(IX+11)
            LD   (NJBANKN),A
            XOR  A
            LD   (NJMAPP),A
            LD   (NJMAPP+1),A
            LD   (NJIMGCNT),A
            LD   (NJIMGCNT+1),A
            LD   (NJPATCNT),A
            LD   (NJPATCNT+1),A
            LD   (NJIMGH),A
            LD   (NJIMGH+1),A
            LD   (NJPATH),A
            LD   (NJPATH+1),A
            LD   (NJOUTH),A
            LD   (NJOUTH+1),A
            DEC  A
            LD   (NJCRC),A
            LD   (NJCRC+1),A

            LD   HL,NJIMGNAM
            LD   B,NJIMGNL
            LD   A,NOBEGIN
            CALL OCOPEN
            JR   C,NJBEGAB
            LD   (NJIMGH),HL
            LD   HL,NJPATNAM
            LD   B,NJPATNL
            LD   A,NOBEGIN
            CALL OCOPEN
            JR   C,NJBEGAB
            LD   (NJPATH),HL
            LD   HL,NJOUTNAM
            LD   B,NJOUTNL
            LD   A,NOBEGIN
            CALL OCOPEN
            JR   C,NJBEGAB
            LD   (NJOUTH),HL

            LD   HL,NJPREFIX
            LD   DE,NJRECBUF
            LD   BC,10
            LDIR
            LD   A,(NJBANKN)
            DEC  A
            LD   A,0
            JR   Z,NJBEGFLG
            INC  A
NJBEGFLG:
            LD   (NJRECBUF+9),A
            LD   IX,(NJBEGP)
            LD   L,(IX+0)
            LD   H,(IX+1)
            LD   (NJRECBUF+10),HL
            LD   A,(NJBANKN)
            LD   (NJRECBUF+12),A
            LD   A,(NJFILL)
            LD   (NJRECBUF+13),A
            LD   L,(IX+2)
            LD   H,(IX+3)
            LD   (NJRECBUF+14),HL
            LD   L,(IX+4)
            LD   H,(IX+5)
            LD   (NJRECBUF+16),HL
            LD   HL,(NJOUTH)
            LD   DE,NJRECBUF
            LD   BC,18
            CALL NJCOVER
            RET
NJBEGAB:
            LD   (NJFAIL),A
            CALL NJABORT
            LD   A,(NJFAIL)
            SCF
            RET

; A is the byte, C the bank, and HL its final address.
; Contract: in A,C,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
NJIMAGE:
            LD   (NJRECBUF+6),A
            LD   A,2
            CALL NJSINGLE
            RET

; A is the byte, C the bank, and HL its final address.
; Contract: in A,C,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
NJPATCH:
            LD   (NJRECBUF+6),A
            LD   A,3
            CALL NJSINGLE
            RET
; Contract: in A,C,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
NJSINGLE:
            LD   (NJRECBUF),A
            LD   A,4
            LD   (NJRECBUF+1),A
            XOR  A
            LD   (NJRECBUF+2),A
            LD   A,C
            LD   (NJRECBUF+3),A
            LD   (NJRECBUF+4),HL
            LD   DE,NJRECBUF
            LD   BC,7
            LD   A,(NJRECBUF)
            CP   2
            JR   NZ,NJPATREC
            LD   HL,(NJIMGH)
            CALL OCWRITE
            RET  C
            LD   HL,NJIMGCNT
            JR   NJINCWD
NJPATREC:
            LD   HL,(NJPATH)
            CALL OCWRITE
            RET  C
            LD   HL,NJPATCNT
; Contract: in HL out HL,zero clobbers sign,parity,halfCarry
NJINCWD:
            INC  (HL)
            RET  NZ
            INC  HL
            INC  (HL)
            RET

; C is the bank, DE the target address, and HL the replacement word.
; Contract: in C,DE,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
NJPATWD:
            LD   A,3
            LD   (NJRECBUF),A
            LD   A,5
            LD   (NJRECBUF+1),A
            XOR  A
            LD   (NJRECBUF+2),A
            LD   A,C
            LD   (NJRECBUF+3),A
            LD   (NJRECBUF+4),DE
            LD   (NJRECBUF+6),HL
            LD   HL,(NJPATH)
            LD   DE,NJRECBUF
            LD   BC,8
            CALL OCWRITE
            RET  C
            LD   HL,NJPATCNT
            JR   NJINCWD

; The dispatcher supplies A=operation, BC=complete length, DE=identity,
; HL=address, and IX=context. NativeHostRuntimeBank supplies the selected bank.
; Contract: in A,BC,DE,HL,IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
NJRUNTIM:
            CP   2
            JP   NC,NJUNAVL
            LD   (NJRECBUF+4),HL
            PUSH AF
            LD   A,2
            LD   (NJRECBUF),A
            LD   H,B
            LD   L,C
            INC  HL
            INC  HL
            INC  HL
            LD   (NJRECBUF+1),HL
            LD   A,(NHRTBNK)
            LD   (NJRECBUF+3),A
            POP  AF
            LD   (NJRTREQ+NCFOPER),A
            LD   A,NCRQSIZE
            LD   (NJRTREQ+NCFSIZE),A
            LD   A,NCABI
            LD   (NJRTREQ+NCFABI),A
            LD   A,(NJBANKN)
            DEC  A
            LD   A,0
            JR   Z,NJRTFLAG
            INC  A
NJRTFLAG:
            LD   (NJRTREQ+NCFFLAG),A
            LD   A,(NHRTBNK)
            LD   (NJRTREQ+NCFBANK),A
            XOR  A
            LD   (NJRTREQ+5),A
            LD   (NJRTREQ+20),A
            LD   (NJRTREQ+21),A
            LD   (NJRTREQ+NCFIDENT),DE
            LD   (NJRTREQ+NCFLEN),BC
            LD   (NJRTREQ+NCFCTX),IX
            LD   DE,0
            LD   (NJRTREQ+NCFOFF),DE
            LD   DE,NJXFER
            LD   (NJRTREQ+NCFPTR),DE
            LD   DE,$0100
            LD   (NJRTREQ+NCFCAP),DE
            LD   HL,(NJIMGH)
            LD   DE,NJRECBUF
            LD   BC,6
            CALL OCWRITE
            RET  C
NJRTLOOP:
            LD   HL,NJRTREQ
            LD   C,NSRTCAT
            RST  $10
            RET  C
            LD   BC,(NJRTREQ+NCFRES)
            LD   A,B
            OR   C
            JP   Z,OCINVAL
            LD   HL,(NJIMGH)
            LD   DE,NJXFER
            CALL OCWRITE
            RET  C
            LD   BC,(NJRTREQ+NCFRES)
            LD   HL,(NJRTREQ+NCFOFF)
            ADD  HL,BC
            LD   (NJRTREQ+NCFOFF),HL
            LD   DE,(NJRTREQ+NCFLEN)
            OR   A
            SBC  HL,DE
            JR   C,NJRTLOOP
            JP   NZ,OCINVAL
            LD   HL,NJIMGCNT
            JP   NJINCWD

; Contract: in IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
NJMAP:
            LD   A,(IX+31)
            LD   B,A
            LD   A,(NJBANKN)
            CP   B
            JP   NZ,OCINVAL
            LD   (NJMAPP),IX
            OR   A
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
NJCOMMIT:
            LD   IX,(NJMAPP)
            LD   A,IXH
            OR   IXL
            JR   NZ,NJCOMMAP
            CALL OCINVAL
            RET
NJCOMMAP:
            LD   HL,(NJIMGH)
            CALL NJSPOOL
            JP   C,NJCOMAB
            LD   HL,(NJPATH)
            CALL NJSPOOL
            JP   C,NJCOMAB
            CALL NJWRMAP
            JP   C,NJCOMAB

            LD   HL,(NJIMGCNT)
            LD   DE,(NJPATCNT)
            ADD  HL,DE
            LD   DE,3
            ADD  HL,DE
            LD   A,5
            LD   (NJRECBUF),A
            LD   A,7
            LD   (NJRECBUF+1),A
            XOR  A
            LD   (NJRECBUF+2),A
            LD   (NJRECBUF+3),HL
            LD   IX,(NJMAPP)
            LD   A,(IX+2)
            LD   (NJRECBUF+5),A
            LD   L,(IX+3)
            LD   H,(IX+4)
            LD   (NJRECBUF+6),HL
            LD   HL,(NJOUTH)
            LD   DE,NJRECBUF
            LD   BC,8
            CALL NJCOVER
            JR   C,NJCOMAB
            LD   HL,(NJOUTH)
            LD   DE,NJCRC
            LD   BC,2
            CALL OCWRITE
            JR   C,NJCOMAB

            LD   HL,(NJIMGH)
            LD   A,NOABORT
            CALL OCTERM
            JR   C,NJCOMAB
            XOR  A
            LD   (NJIMGH),A
            LD   (NJIMGH+1),A
            LD   HL,(NJPATH)
            LD   A,NOABORT
            CALL OCTERM
            JR   C,NJCOMAB
            XOR  A
            LD   (NJPATH),A
            LD   (NJPATH+1),A
            LD   HL,(NJOUTH)
            LD   A,NOCOMMIT
            CALL OCTERM
            JR   C,NJCOMAB
            XOR  A
            LD   (NJOUTH),A
            LD   (NJOUTH+1),A
            RET
NJCOMAB:
            LD   (NJFAIL),A
            CALL NJABORT
            LD   A,(NJFAIL)
            SCF
            RET

; Copy one tentative spool to the final tentative object with CRC coverage.
; Contract: in HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
NJSPOOL:
            LD   (NJCOPYH),HL
            CALL OCREWIND
            RET  C
NJCOPYLP:
            LD   HL,(NJCOPYH)
            LD   DE,NJXFER
            LD   BC,NJXFLIM-NJXFER
            CALL OCREAD
            RET  C
            LD   A,B
            OR   C
            RET  Z
            LD   DE,NJXFER
            LD   HL,(NJOUTH)
            CALL NJCOVER
            RET  C
            JR   NJCOPYLP

; Serialize the native MAP request into the NOBJ 0.1 MAP payload.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
NJWRMAP:
            LD   IX,(NJMAPP)
            LD   A,(IX+28)
            LD   (NJRECBUF+31),A
            LD   B,A
            LD   A,(IX+31)
            ADD  A,A
            LD   E,A
            ADD  A,A
            ADD  A,A
            ADD  A,E
            ADD  A,B
            ADD  A,30
            LD   (NJRECBUF+1),A
            XOR  A
            LD   (NJRECBUF+2),A
            LD   A,4
            LD   (NJRECBUF),A
            LD   A,(IX+0)
            LD   (NJRECBUF+3),A
            LD   A,(IX+1)
            LD   (NJRECBUF+4),A
            LD   A,(IX+2)
            LD   (NJRECBUF+5),A
            LD   L,(IX+3)
            LD   H,(IX+4)
            LD   (NJRECBUF+6),HL
            LD   L,(IX+9)
            LD   H,(IX+10)
            LD   (NJRECBUF+8),HL
            LD   (NJRECBUF+12),HL
            LD   (NJRECBUF+16),HL
            LD   L,(IX+11)
            LD   H,(IX+12)
            LD   (NJRECBUF+10),HL
            LD   L,(IX+13)
            LD   H,(IX+14)
            LD   (NJRECBUF+14),HL
            LD   L,(IX+15)
            LD   H,(IX+16)
            LD   (NJRECBUF+18),HL
            LD   L,(IX+17)
            LD   H,(IX+18)
            LD   (NJRECBUF+20),HL
            LD   L,(IX+19)
            LD   H,(IX+20)
            LD   (NJRECBUF+22),HL
            LD   L,(IX+21)
            LD   H,(IX+22)
            LD   (NJRECBUF+24),HL
            LD   A,(IX+23)
            LD   (NJRECBUF+26),A
            LD   L,(IX+24)
            LD   H,(IX+25)
            LD   (NJRECBUF+27),HL
            LD   L,(IX+26)
            LD   H,(IX+27)
            LD   (NJRECBUF+29),HL

            LD   B,0
            LD   C,(IX+28)
            LD   L,(IX+29)
            LD   H,(IX+30)
            LD   DE,NJRECBUF+32
            LDIR
            LD   A,(IX+31)
            LD   (DE),A
            INC  DE
            LD   (NJTAILP),DE

            LD   L,(IX+32)
            LD   H,(IX+33)
            LD   (NJSTATEP),HL
            XOR  A
            LD   (NJBANKID),A
NJMAPBNK:
            ; usedLength = bank cursor - imageBase.
            LD   HL,(NJSTATEP)
            LD   C,(HL)
            INC  HL
            LD   B,(HL)
            INC  HL
            INC  HL
            INC  HL
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            LD   (NJAGGN),DE
            LD   H,B
            LD   L,C
            LD   E,(IX+5)
            LD   D,(IX+6)
            OR   A
            SBC  HL,DE
            LD   (NJUSED),HL

            LD   HL,(NJSTATEP)
            LD   DE,6
            ADD  HL,DE
            LD   (NJSTATEP),HL

            ; Every bank starts with the entry slot and runtime. The entry
            ; bank then carries startup and the initialized image.
            LD   L,(IX+5)
            LD   H,(IX+6)
            LD   BC,3
            ADD  HL,BC
            LD   C,(IX+34)
            LD   B,(IX+35)
            ADD  HL,BC
            LD   A,(NJBANKID)
            CP   (IX+2)
            JR   NZ,NJBNKRO
            LD   C,(IX+36)
            LD   B,(IX+37)
            ADD  HL,BC
NJBNKRO:
            LD   (NJROBASE),HL

            LD   BC,0
            LD   A,(NJBANKID)
            CP   (IX+2)
            JR   NZ,NJMAPINI
            BIT  0,(IX+1)
            JR   Z,NJMAPINI
            LD   C,(IX+15)
            LD   B,(IX+16)
NJMAPINI:
            LD   (NJINITN),BC

            LD   DE,(NJAGGN)
            LD   HL,(NJINITN)
            ADD  HL,DE
            LD   (NJRON),HL
            LD   A,D
            OR   E
            LD   HL,0
            JR   Z,NJMAPAGG
            LD   HL,(NJROBASE)
            LD   BC,(NJINITN)
            ADD  HL,BC
NJMAPAGG:
            LD   (NJAGGADR),HL

            LD   HL,(NJTAILP)
            LD   DE,(NJUSED)
            LD   (HL),E
            INC  HL
            LD   (HL),D
            INC  HL
            LD   DE,(NJROBASE)
            LD   BC,(NJRON)
            LD   A,B
            OR   C
            JR   NZ,NJMAPRO
            LD   DE,0
NJMAPRO:
            LD   (HL),E
            INC  HL
            LD   (HL),D
            INC  HL
            LD   (HL),C
            INC  HL
            LD   (HL),B
            INC  HL
            LD   DE,(NJAGGADR)
            LD   (HL),E
            INC  HL
            LD   (HL),D
            INC  HL
            LD   DE,(NJAGGN)
            LD   (HL),E
            INC  HL
            LD   (HL),D
            INC  HL
            LD   (NJTAILP),HL

            LD   A,(NJBANKID)
            INC  A
            LD   (NJBANKID),A
            CP   (IX+31)
            JP   C,NJMAPBNK

            LD   A,(NJRECBUF+1)
            ADD  A,3
            LD   C,A
            LD   B,0
            LD   HL,(NJOUTH)
            LD   DE,NJRECBUF
            JP   NJCOVER

; Write one block to the final object and include it in the running CRC.
; Contract: in HL,DE,BC out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
NJCOVER:
            PUSH HL
            PUSH DE
            PUSH BC
            EX   DE,HL
            CALL NJCRCBLK
            POP  BC
            POP  DE
            POP  HL
            CALL OCWRITE
            RET

; Contract: in HL,BC out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
NJCRCBLK:
NJCRCLP:
            LD   A,B
            OR   C
            RET  Z
            LD   A,(HL)
            INC  HL
            DEC  BC
            PUSH BC
            PUSH HL
            CALL NJCRCBYT
            POP  HL
            POP  BC
            JR   NJCRCLP

; Contract: in A out A,BC,DE,carry,zero clobbers sign,parity,halfCarry
NJCRCBYT:
            LD   DE,(NJCRC)
            XOR  D
            LD   D,A
            LD   B,8
NJCRCBIT:
            SLA  E
            RL   D
            JR   NC,NJCRCNXT
            LD   A,E
            XOR  $21
            LD   E,A
            LD   A,D
            XOR  $10
            LD   D,A
NJCRCNXT:
            DJNZ NJCRCBIT
            LD   (NJCRC),DE
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
NJABORT:
            XOR  A
            LD   (NJABSTAT),A
            LD   HL,NJIMGH
            LD   B,3
NJABLOOP:
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            INC  HL
            LD   A,D
            OR   E
            JR   Z,NJABNEXT
            PUSH HL
            PUSH BC
            EX   DE,HL
            LD   A,NOABORT
            CALL OCTERM
            JR   NC,NJABREST
            LD   (NJABSTAT),A
NJABREST:
            POP  BC
            POP  HL
NJABNEXT:
            DJNZ NJABLOOP
            XOR  A
            LD   HL,NJIMGH
            LD   DE,NJIMGH+1
            LD   BC,5
            LD   (HL),A
            LDIR
            LD   A,(NJABSTAT)
            OR   A
            RET  Z
            SCF
            RET

NJCODEND:
