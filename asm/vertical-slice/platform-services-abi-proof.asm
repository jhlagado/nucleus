%INCLUDE "platform-services-abi.asmi"

LPSTACK    EQU $7F00

            ORG $4000
FPSTART:
            LD   SP,LPSTACK
            LD   IX,$1357
            LD   IY,$2468
            LD   BC,$A55A
            LD   (LPENTSP),SP
            CALL LPINFOAD
            JP   C,FPFAIL
            CP   NSABI
            JP   NZ,FPFAIL
            LD   A,D
            OR   A
            JP   NZ,FPFAIL
            LD   A,E
            CP   NSCAPEXE+NSCAPIO+NSCAPCTL+NSCAPDEV
            JP   NZ,FPFAIL
            PUSH IX
            POP  HL
            LD   DE,$1357
            OR   A
            SBC  HL,DE
            JP   NZ,FPFAIL
            PUSH IY
            POP  HL
            LD   DE,$2468
            OR   A
            SBC  HL,DE
            JP   NZ,FPFAIL
            LD   BC,$1234
            CALL LPPACKAD
            JP   C,FPFAIL
            LD   HL,(LPPACKBC)
            LD   DE,$1234
            OR   A
            SBC  HL,DE
            JP   NZ,FPFAIL
            LD   HL,LPOREQ
            CALL LPOBJAD
            JP   C,FPFAIL
            LD   HL,(LPOREQ+NOFHAND)
            LD   DE,$3412
            OR   A
            SBC  HL,DE
            JP   NZ,FPFAIL
            LD   A,2
            LD   (LPOREQ+NOFABI),A
            LD   HL,LPOREQ
            CALL LPOBJAD
            JP   NC,FPFAIL
            CP   NSTATINV
            JP   NZ,FPFAIL
            LD   A,1
            LD   (LPSELBK),A
            CALL LPNESTBK
            JP   C,FPFAIL
            CP   $5A
            JP   NZ,FPFAIL
            LD   A,(LPSELBK)
            CP   1
            JP   NZ,FPFAIL
            LD   HL,0
            ADD  HL,SP
            LD   DE,(LPENTSP)
            OR   A
            SBC  HL,DE
            JP   NZ,FPFAIL
            XOR  A
            LD   (LPRES),A
            HALT

FPFAIL:
            LD   A,1
            LD   (LPRES),A
            HALT

; Contract: out A,DE,HL,carry,zero clobbers sign,parity,halfCarry
LPINFOAD:
            PUSH BC
            LD   C,NSINFO
            CALL LPDISP
            POP  BC
            RET

; Contract: in BC out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
LPPACKAD:
            LD   (LPSAVEBC),BC
            LD   C,NSPACKET
            JP   LPDISP

; Contract: in HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
LPOBJAD:
            LD   C,NSOBJECT
            JP   LPDISP

; Contract: in C out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
LPDISP:
            LD   A,C
            CP   NSINFO
            JR   Z,LPINFO
            CP   NSPACKET
            JR   Z,LPPACK
            CP   NSOBJECT
            JR   Z,LPOBJSVC
            LD   A,$EE
            SCF
            RET

; Contract: out A,DE,carry,zero clobbers sign,parity,halfCarry
LPINFO:
            LD   A,NSABI
            LD   DE,NSCAPEXE+NSCAPIO+NSCAPCTL+NSCAPDEV
            OR   A
            RET

; Contract: out A,BC,carry,zero clobbers sign,parity,halfCarry
LPPACK:
            LD   BC,(LPSAVEBC)
            LD   (LPPACKBC),BC
            XOR  A
            RET

; Contract: in HL out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
LPOBJSVC:
            LD   A,(HL)
            CP   NORQSIZE
            JR   NZ,LPOINVAL
            INC  HL
            LD   A,(HL)
            CP   NOABI
            JR   NZ,LPOINVAL
            INC  HL
            LD   A,(HL)
            CP   NOOPEN
            JR   NZ,LPOINVAL
            INC  HL
            LD   A,(HL)
            OR   A
            JR   NZ,LPOINVAL
            INC  HL
            LD   (HL),$12
            INC  HL
            LD   (HL),$34
            XOR  A
            RET
LPOINVAL:
            LD   A,NSTATINV
            SCF
            RET

; This models the fixed-ROM far-call property which Stage 7 must prove against
; MON3 itself: nested calls restore the immediately preceding bank and return
; the callee's AF with the original stack depth.
; Contract: out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
LPNESTBK:
            LD   A,(LPSELBK)
            LD   B,A
            LD   A,2
            LD   (LPSELBK),A
            OR   A
            CALL LPBKTGT
            PUSH AF
            LD   A,B
            LD   (LPSELBK),A
            POP  AF
            RET

; Contract: out A
LPBKTGT:
            LD   A,$5A
            RET

LPENTSP:      DW 0
LPSAVEBC:      DW 0
LPPACKBC:     DW 0
LPSELBK: DB 0
LPRES:       DB $FF
LPONAME:   DB "main"
LPOREQ:
            DB NORQSIZE,NOABI
            DB NOOPEN,0
            DW 0,LPONAME,4,0,0,0
FPEND:
