; Contract: in A out A,carry clobbers zero,sign,parity,halfCarry,DE,HL
TTDGSET:
            LD   (DGCODE),A
            SCF
            RET

; Contract: noreturn
DGINLINE:
            POP  HL
            LD   A,(HL)
            JR   TTDGSET
TTCEND:

TTIDATA:
