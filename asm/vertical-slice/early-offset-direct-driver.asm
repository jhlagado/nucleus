ORG MMCORE
KCSTART:
EDOSTART:
EDOPAGE:
            DB EDOCASE0-EDOPAGE
            DB EDOCASE1-EDOPAGE
            DB EDOCASE2-EDOPAGE
            DB EDOCASE3-EDOPAGE
            DB EDOCASE4-EDOPAGE
            DB EDOCASE5-EDOPAGE
            DB EDOCASE6-EDOPAGE
            DB EDOCASE7-EDOPAGE
; ABI: in A out carry,zero clobbers sign,parity,halfCarry,A,HL
EDODISP:
            SUB  12
            CP   8
            JR   NC,EDOINVAL
            LD   L,A
            LD   H,0
            LD   L,(HL)
            LD   H,0
            JP   (HL)
EDOINVAL:
            SCF
            RET
EDOEND:

; ABI: out carry,zero clobbers sign,parity,halfCarry,A
EDOCASE0: OR A
               RET
; ABI: out carry,zero clobbers sign,parity,halfCarry,A
EDOCASE1: OR A
               RET
; ABI: out carry,zero clobbers sign,parity,halfCarry,A
EDOCASE2: OR A
               RET
; ABI: out carry,zero clobbers sign,parity,halfCarry,A
EDOCASE3: OR A
               RET
; ABI: out carry,zero clobbers sign,parity,halfCarry,A
EDOCASE4: OR A
               RET
; ABI: out carry,zero clobbers sign,parity,halfCarry,A
EDOCASE5: OR A
               RET
; ABI: out carry,zero clobbers sign,parity,halfCarry,A
EDOCASE6: OR A
               RET
; ABI: out carry,zero clobbers sign,parity,halfCarry,A
EDOCASE7: OR A
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
