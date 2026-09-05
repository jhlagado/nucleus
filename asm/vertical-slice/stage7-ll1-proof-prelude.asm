            ORG MMCORE
; Contract: out A,BC,HL,carry,zero clobbers sign,parity,halfCarry,D,DE
PSPEEK:
            LD   A,(LGPEEKFL)
            OR   A
            JR   Z,LGPEEKRD
            CALL DGINLINE
            DB  DXTOKBAS
LGPEEKRD:
            PUSH HL
            LD   HL,(LGCURSOR)
            LD   A,(HL)
            POP  HL
            OR   A
            RET
; Contract: out A,BC,HL,carry,zero clobbers sign,parity,halfCarry,D,DE
LGTAKE:
            PUSH HL
            CALL PSPEEK
            JR   C,LGTAKEER
            LD   HL,(LGCURSOR)
            INC  HL
            LD   (LGCURSOR),HL
            POP  HL
            OR   A
            RET
LGTAKEER:
            POP  HL
            RET
; Contract: in E out A,C,carry,zero clobbers sign,parity,halfCarry,B,D,DE,HL
PSEXPECT:
            PUSH DE
            CALL LGTAKE
            POP  DE
            RET  C
            CP   E
            RET  Z
            LD   A,E
            OR   DXTOKBAS
; Contract: in A out A,carry clobbers zero,sign,parity,halfCarry,DE,HL
DGSET:
            LD   (DGCODE),A
            SCF
            RET

; Contract: noreturn
DGINLINE:
            POP  HL
            LD   A,(HL)
            JR   DGSET

LGMEAS:
