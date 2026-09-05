ORG MMCORE
KCSTART:
EDTSTART:
; ABI: in A out carry,zero clobbers sign,parity,halfCarry,A,DE,HL
EDTABLE:
            SUB  12
            CP   8
            JR   NC,EDTINVAL
            ADD  A,A
            LD   E,A
            LD   D,0
            LD   HL,EDTTARGS
            ADD  HL,DE
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            EX   DE,HL
            JP   (HL)
EDTINVAL:
            SCF
            RET
EDTTARGS:
            DW EDCASE0,EDCASE1,EDCASE2,EDCASE3
            DW EDCASE4,EDCASE5,EDCASE6,EDCASE7
EDTEND:

EDCSTART:
; ABI: in A out carry,zero clobbers sign,parity,halfCarry,A
EDCHAIN:
            CP   12
            JP   Z,EDCASE0
            CP   13
            JP   Z,EDCASE1
            CP   14
            JP   Z,EDCASE2
            CP   15
            JP   Z,EDCASE3
            CP   16
            JP   Z,EDCASE4
            CP   17
            JP   Z,EDCASE5
            CP   18
            JP   Z,EDCASE6
            CP   19
            JP   Z,EDCASE7
            SCF
            RET
EDCEND:

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
