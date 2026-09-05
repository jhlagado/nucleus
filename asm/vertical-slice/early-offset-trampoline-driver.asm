ORG MMCORE
KCSTART:
ETRSTART:
ETRPAGE:
            DB ETRCASE0-ETRPAGE
            DB ETRCASE1-ETRPAGE
            DB ETRCASE2-ETRPAGE
            DB ETRCASE3-ETRPAGE
            DB ETRCASE4-ETRPAGE
            DB ETRCASE5-ETRPAGE
            DB ETRCASE6-ETRPAGE
            DB ETRCASE7-ETRPAGE
ETRCASE0: JP EDCASE0
ETRCASE1: JP EDCASE1
ETRCASE2: JP EDCASE2
ETRCASE3: JP EDCASE3
ETRCASE4: JP EDCASE4
ETRCASE5: JP EDCASE5
ETRCASE6: JP EDCASE6
ETRCASE7: JP EDCASE7
; ABI: in A out carry,zero clobbers sign,parity,halfCarry,A,HL
ETRDISP:
            SUB  12
            CP   8
            JR   NC,ETRINVAL
            LD   L,A
            LD   H,0
            LD   L,(HL)
            LD   H,0
            JP   (HL)
ETRINVAL:
            SCF
            RET
ETREND:

; ABI: out carry,zero clobbers sign,parity,halfCarry,A
EDCASE0:  OR A
            RET
; ABI: out carry,zero clobbers sign,parity,halfCarry,A
EDCASE1:  OR A
            RET
; ABI: out carry,zero clobbers sign,parity,halfCarry,A
EDCASE2:  OR A
            RET
; ABI: out carry,zero clobbers sign,parity,halfCarry,A
EDCASE3:  OR A
            RET
; ABI: out carry,zero clobbers sign,parity,halfCarry,A
EDCASE4:  OR A
            RET
; ABI: out carry,zero clobbers sign,parity,halfCarry,A
EDCASE5:  OR A
            RET
; ABI: out carry,zero clobbers sign,parity,halfCarry,A
EDCASE6:  OR A
            RET
; ABI: out carry,zero clobbers sign,parity,halfCarry,A
EDCASE7:  OR A
            RET
KCCODEND:
KCEND:

            ORG MMPROOF
FPSTART:
            LD   A,$A5
            LD   (FPSTATUS),A
            HALT
FPSTATUS: DB 0
FPEND:

; End of source part.
