RTEND:

            ORG MMPROOF
; Contract: out carry,zero clobbers sign,parity,halfCarry,A,BC,DE,HL,IX,IY
FPSTART:
            LD   SP,STACKTOP
            XOR  A
            LD   (FPCASE),A
            LD   (FPSTATUS),A
            LD   (SVFAIL),A

            LD   A,70
            LD   HL,QESOURCE
            LD   DE,QEPSE
            CALL CPSL
            JP   C,QFCOMP
            CALL ZXPROG
            JP   C,QFEN

            CALL RESET
            XOR  A
            LD   (SVFAIL),A
            CALL QPCAGE
            JP   C,QFFR
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,QFSUST
            LD   A,(VOUTLEN)
            CP   1
            JP   NZ,QFSUOU
            LD   A,(VOUTBAS)
            CP   14
            JP   NZ,QFSUBY
            LD   A,(MMGEN+3)
            CP   14
            JP   NZ,QFAS

            CALL RESET
            LD   A,1
            LD   (SVFAIL),A
            CALL QPCAGE
            JP   C,QFFR
            LD   A,(RUNSTATE)
            CP   RTTRAP
            JP   NZ,QFOUST
            LD   A,(RTTRPNO)
            CP   6
            JP   NZ,QFOUTR
            LD   A,(RTTRPERR)
            CP   3
            JP   NZ,QFOUER
            LD   HL,(RTTRPOFF)
            LD   DE,QEOC-QESOURCE
            OR   A
            SBC  HL,DE
            JP   NZ,QFOUOF
            LD   A,(VOUTLEN)
            OR   A
            JP   NZ,QFOUAT

            LD   A,71
            LD   HL,QDSS
            LD   DE,QDSSE
            CALL CPSL
            JP   NC,QFDUAC
            LD   A,(DGCODE)
            CP   DGDUPNAM
            JP   NZ,QFDUCO
            LD   HL,(DGOFF)
            LD   DE,QDSN-QDSS
            OR   A
            SBC  HL,DE
            JP   NZ,QFDUPO

            LD   A,72
            LD   HL,QUSS
            LD   DE,QUSSE
            CALL CPSL
            JP   NC,QFUNAC
            LD   A,(DGCODE)
            CP   DGUNKNAM
            JP   NZ,QFUNCO
            LD   HL,(DGOFF)
            LD   DE,QUSN-QUSS
            OR   A
            SBC  HL,DE
            JP   NZ,QFUNPO

            LD   A,73
            LD   HL,QHES
            LD   DE,QHESE
            CALL CPSL
            JP   NC,QFMAAC
            LD   A,(DGCODE)
            CP   DXSCA
            JP   NZ,QFMACO
            LD   HL,(DGOFF)
            LD   DE,QHEP-QHES
            OR   A
            SBC  HL,DE
            JP   NZ,QFMAPO

            LD   A,74
            LD   HL,QLSS
            LD   DE,QLSSE
            CALL CPSL
            JP   NC,QFFUAC
            LD   A,(DGCODE)
            CP   DGSYMCAP
            JP   NZ,QFFUCO
            LD   HL,(DGOFF)
            LD   DE,QLSN-QLSS
            OR   A
            SBC  HL,DE
            JP   NZ,QFFUPO

            ; Leave the successful program and transcript for host inspection.
            LD   A,70
            LD   HL,QESOURCE
            LD   DE,QEPSE
            CALL CPSL
            JP   C,QFCOMP
            CALL ZXPROG
            JP   C,QFEN

            LD   A,$A5
            LD   (FPSTATUS),A
            HALT

; Contract: in B,DE,HL out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
QPCOBY:
            LD   A,(DE)
            CP   (HL)
            JR   NZ,QPCOBYNO
            INC  DE
            INC  HL
            DJNZ QPCOBY
            OR   A
            RET
QPCOBYNO:
            SCF
            RET

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
            JR   NZ,QPCAGENO
            LD   HL,0
            ADD  HL,SP
            LD   DE,(QPEXSP)
            OR   A
            SBC  HL,DE
            RET  Z
QPCAGENO:
            SCF
            RET

QFCOMP:             LD A,1
                              JR QF
QFOP:          LD A,2
                              JR QF
QFEN:              LD A,3
                              JR QF
QFSUST:        LD A,4
                              JR QF
QFSUOU:       LD A,5
                              JR QF
QFSUBY:         LD A,6
                              JR QF
QFAS:          LD A,7
                              JR QF
QFOUST:         LD A,8
                              JR QF
QFOUTR:          LD A,9
                              JR QF
QFOUER:         LD A,10
                              JR QF
QFOUOF:        LD A,11
                              JR QF
QFOUAT:        LD A,12
                              JR QF
QFDUAC:   LD A,13
                              JR QF
QFDUCO:       LD A,14
                              JR QF
QFDUPO:   LD A,15
                              JR QF
QFUNAC:     LD A,16
                              JR QF
QFUNCO:         LD A,17
                              JR QF
QFUNPO:     LD A,18
                              JR QF
QFGESI:       LD A,19
                              JR QF
QFFUAC:        LD A,20
                              JR QF
QFFUCO:            LD A,21
                              JR QF
QFFUPO:        LD A,22
                              JR QF
QFMAAC:   LD A,23
                              JR QF
QFMACO:       LD A,24
                              JR QF
QFMAPO:   LD A,25
                              JR QF
QFFR:               LD A,26
QF:
            LD   (FPCASE),A
            LD   A,$E0
            LD   (FPSTATUS),A
            HALT

QXEO:
            DB 17
            DB SMDEFPU8,0,0
            DB SMBGMAIN
            DB SMDLCLU8,0,SMLITU8,2
            DB SMSTLU8,0
            DB SMDLCLU8,1,SMLITU8,3
            DB SMSTLU8,1
            DB SMLDLU8,0,SMLDLU8,1
            DB SMLITU8,4,SMMULU8,SMADDU8
            DB SMSTPU8,0
            DB SMLDPU8,0
            DB SMWRVU8
            DW QEOC-QESOURCE
            DB SMENMAIN
FPSTATUS:                 DB 0
FPCASE:                   DB 0
QPEXSP:             DW 0
FPEND:

QEPRGSZ EQU 116
QZEE      EQU MMGEN+QEPRGSZ
