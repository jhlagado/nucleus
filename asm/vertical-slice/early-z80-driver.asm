RTEND:

            ORG MMPROOF
; ABI: out carry,zero clobbers sign,parity,halfCarry,A,BC,DE,HL,IX,IY
FPSTART:
            LD   SP,STACKTOP
            XOR  A
            LD   (FPCASE),A
            LD   (FPSTATUS),A
            LD   (ESVCFAIL),A

            LD   A,7
            LD   HL,EPRFSRC
            LD   DE,EPRFSEND
            CALL ECOMPSL
            JP   C,QFCOMP
            CALL EENCODE
            JP   C,QFEN
            LD   HL,(GNSZ)
            LD   DE,PGSZ
            OR   A
            SBC  HL,DE
            JP   NZ,QFSI

            CALL RESET
            XOR  A
            LD   (ESVCFAIL),A
            CALL MMGEN
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,EFRUNOK
            LD   A,(VOUTLEN)
            CP   1
            JP   NZ,EFOUTLEN
            LD   A,(ESVCOUT)
            CP   $41
            JP   NZ,EFOUTBYT
            LD   (ESUCOUT),A

            CALL RESET
            LD   A,1
            LD   (ESVCFAIL),A
            CALL MMGEN
            LD   A,(RUNSTATE)
            CP   RTTRAP
            JP   NZ,EFTRPST
            LD   A,(VOUTLEN)
            OR   A
            JP   NZ,EFATMOUT
            LD   A,(RTTRPNO)
            CP   6
            JP   NZ,EFTRPNUM
            LD   A,(RTTRPRTN)
            OR   A
            JP   NZ,EFTRPRTN
            LD   HL,(RTTRPOFF)
            LD   DE,EFAILOFF
            OR   A
            SBC  HL,DE
            JP   NZ,EFTRPOFF
            LD   A,(RTTRPERR)
            CP   3
            JP   NZ,EFTRPERR

            LD   A,$A5
            LD   (FPSTATUS),A
            HALT

QFCOMP:
            LD   A,1
            JR   QF
QFEN:
            LD   A,2
            JR   QF
QFSI:
            LD   A,3
            JR   QF
EFRUNOK:
            LD   A,4
            JR   QF
EFOUTLEN:
            LD   A,5
            JR   QF
EFOUTBYT:
            LD   A,6
            JR   QF
EFTRPST:
            LD   A,7
            JR   QF
EFATMOUT:
            LD   A,8
            JR   QF
EFTRPNUM:
            LD   A,9
            JR   QF
EFTRPRTN:
            LD   A,10
            JR   QF
EFTRPOFF:
            LD   A,11
            JR   QF
EFTRPERR:
            LD   A,12
QF:
            LD   (FPCASE),A
            LD   A,$E0
            LD   (FPSTATUS),A
            HALT

FPSTATUS:
            DB  0
FPCASE:
            DB  0
ESUCOUT:
            DB  0
FPEND:

; End of source part.
