ORG MMPROOF
; Contract: out carry,zero clobbers sign,parity,halfCarry,A,BC,DE,HL,IX,IY
FPSTART:
            LD   SP,STACKTOP
            XOR  A
            LD   (FPSTATUS),A
            LD   (FPCASE),A
            LD   A,160
            LD   HL,CVCONST
            LD   DE,CVCONEND
            CALL CPAGCLSL
            JP   C,PFCSTCMP
            CALL ZGPROG
            JP   C,PFCSTENC
            CALL RESET
            CALL QPCAGE
            JP   C,PFCSFRER
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,PFCSTRUN
            LD   A,(VOUTLEN)
            CP   1
            JP   NZ,PFCSOUER
            LD   A,(VOUTBAS)
            CP   2
            JP   NZ,PFCSOUER
            LD   A,160
            LD   HL,CVPARSE
            LD   DE,CVPAREND
            CALL CPAGCLSL
            JR   C,FPCOMPFL
            CALL ZGPROG
            JR   C,PFENCERR
            LD   HL,(GNSZ)
            LD   (PFGENSZ),HL
            CALL RESET
            CALL QPCAGE
            JR   C,PFFRMERR
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JR   NZ,PFRUNERR
            LD   A,(VOUTLEN)
            CP   1
            JR   NZ,PFOUTERR
            LD   A,(VOUTBAS)
            CP   9
            JR   NZ,PFOUTERR
            LD   A,(MMDATA+1)
            CP   3
            JR   NZ,PFOUTERR
            LD   A,(MMDATA+2)
            OR   A
            JR   NZ,PFOUTERR
            LD   A,(MMDATA+3)
            OR   A
            JR   NZ,PFOUTERR
            LD   A,$A5
            LD   (FPSTATUS),A
            HALT

FPCOMPFL:
            LD   A,1
            JR   QF
PFENCERR:
            LD   A,2
            JR   QF
PFFRMERR:
            LD   A,3
            JR   QF
PFRUNERR:
            LD   A,4
            JR   QF
PFOUTERR:
            LD   A,5
            JR   QF
PFCSTCMP:
            LD   A,6
            JR   QF
PFCSTENC:
            LD   A,7
            JR   QF
PFCSFRER:
            LD   A,8
            JR   QF
PFCSTRUN:
            LD   A,9
            JR   QF
PFCSOUER:
            LD   A,10
QF:
            LD   (FPCASE),A
            HALT

; The generated program must restore both the root hardware stack and IX.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
QPCAGE:
            LD   HL,0
            ADD  HL,SP
            LD   (QPEXSP),HL
            LD   IX,$A55A
            CALL MMGEN
            PUSH IX
            POP  DE
            LD   HL,$A55A
            OR   A
            SBC  HL,DE
            JR   NZ,PFCALLNO
            LD   HL,0
            ADD  HL,SP
            LD   DE,(QPEXSP)
            OR   A
            SBC  HL,DE
            RET  Z
PFCALLNO:
            SCF
            RET

QPEXSP:   DW 0
PFGENSZ: DW 0
FPSTATUS:        DB 0
FPCASE:          DB 0
FPEND:
