RTEND:

            ORG MMPROOF
; ABI: out carry,zero clobbers sign,parity,halfCarry,A,BC,DE,HL,IX,IY
FPSTART:
            LD   SP,STACKTOP
            XOR  A
            LD   (FPCASE),A
            LD   (FPSTATUS),A
            LD   (SVFAIL),A

            LD   A,30
            LD   HL,ELPSRC
            LD   DE,ELPSRCEN
            CALL CPLPSL
            JP   C,QFCOMP
            CALL ZELOOP
            JP   C,QFEN
            LD   HL,(GNSZ)
            LD   DE,PGSZ
            OR   A
            SBC  HL,DE
            JP   NZ,QFSI

            CALL RESET
            XOR  A
            LD   (SVFAIL),A
            CALL MMGEN
            LD   A,D
            CP   2
            JP   NZ,EFFINCTR
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,EFRUNOK
            LD   A,(VOUTLEN)
            CP   3
            JP   NZ,EFOUTLEN
            LD   HL,VOUTBAS
            LD   B,3
ECHKOUT:
            LD   A,(HL)
            CP   $41
            JP   NZ,EFOUTBYT
            INC  HL
            DJNZ ECHKOUT

            CALL RESET
            LD   A,2
            LD   (SVFAIL),A
            CALL MMGEN
            LD   A,(RUNSTATE)
            CP   RTTRAP
            JP   NZ,EFTRPST
            LD   A,(VOUTLEN)
            CP   1
            JP   NZ,EFFLOUT
            LD   A,(VOUTBAS)
            CP   $41
            JP   NZ,EFFLOUT
            LD   A,(RTTRPNO)
            CP   6
            JP   NZ,EFTRPNUM
            LD   HL,(RTTRPOFF)
            LD   DE,LPFAIL
            OR   A
            SBC  HL,DE
            JP   NZ,EFTRPOFF
            LD   A,(RTTRPERR)
            CP   3
            JP   NZ,EFTRPERR

            LD   A,31
            LD   HL,EZLPSRC
            LD   DE,EZLPSREN
            CALL CPLPSL
            JP   C,EFZCOMP
            CALL ZELOOP
            JP   C,EFZENC
            CALL RESET
            XOR  A
            LD   (SVFAIL),A
            CALL MMGEN
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,EFZRUN
            LD   A,(VOUTLEN)
            OR   A
            JP   NZ,EFZOUT

            ; Leave the normal direct program in generated output for inspection.
            LD   A,30
            LD   HL,ELPSRC
            LD   DE,ELPSRCEN
            CALL CPLPSL
            JP   C,QFCOMP
            CALL ZELOOP
            JP   C,QFEN

            LD   A,$A5
            LD   (FPSTATUS),A
            HALT

QFCOMP:       LD A,1
                        JR QF
QFEN:        LD A,2
                        JR QF
QFSI:          LD A,3
                        JR QF
EFRUNOK:    LD A,4
                        JR QF
EFOUTLEN:  LD A,5
                        JR QF
EFOUTBYT:    LD A,6
                        JR QF
EFFINCTR:  LD A,7
                        JR QF
EFTRPST:     LD A,8
                        JR QF
EFFLOUT: LD A,9
                        JR QF
EFTRPNUM:    LD A,10
                        JR QF
EFTRPOFF:    LD A,11
                        JR QF
EFTRPERR:     LD A,12
                        JR QF
EFZCOMP:   LD A,13
                        JR QF
EFZENC:    LD A,14
                        JR QF
EFZRUN:       LD A,15
                        JR QF
EFZOUT:    LD A,16
QF:
            LD   (FPCASE),A
            LD   A,$E0
            LD   (FPSTATUS),A
            HALT

FPSTATUS:            DB 0
FPCASE:              DB 0
FPEND:

; End of source part.
