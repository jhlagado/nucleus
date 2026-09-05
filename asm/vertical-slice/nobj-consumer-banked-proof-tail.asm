LPCCEND:

            ORG $4800
LPRUNDSC:
            DB  10,0,1,0
            DW  1,LPDEPLY,LPRESULT
LPDEPLY:
            DB  18,1,1
            DW  1
            DB  2,$EE
            DW  $8000,$0100,$4000,$0100
            DB  0
            DW  LPBINDS
LPBINDS:
            DB  0,0,0,0,0,0
            DB  1,0,0,1,0,0
LPRESULT:
            DB  0,0,0,0
LPPUBLED:
            DB  0
LPFLSTAT:
            DB  0
LPSELBK:
            DB  $FF
LPNEXTBK:
            DB  0
LPOBJCUR:
            DW  0
LPOACTEN:
            DW  LPOBJEND
LPFAILOP:
            DB  0

            ORG LVOBJBA
LPOBJECT:
            DB $01,$0f,$00,$4e,$4f,$42,$4a,$00,$01,$01,$01,$00,$02,$ee,$00,$80,$00,$01
            DB $02,$09,$00,$00,$00,$80,$3e,$5a,$32,$01,$40,$76
            DB $02,$05,$00,$01,$10,$80,$aa,$bb
            DB $03,$04,$00,$01,$11,$80,$cc
            DB $04,$34,$00,$01,$01,$00,$00,$80,$00,$40,$00,$01,$00,$40,$01,$00,$00,$40
            DB $01,$00,$01,$40,$00,$00,$00,$00,$00,$00,$80,$01,$00,$02,$00,$01,$02,$06
            DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$12,$00,$00,$00,$00,$00,$00,$00,$00,$00
            DB $05,$07,$00,$06,$00,$00,$00,$80,$ea,$fa
LPOBJEND:

            ORG LVPLBASE
            DB  "NC",0,1,8,8,0,0
            JP   LPOPEN
            JP   LPREAD
            JP   LPREWIND
            JP   LPLOCK
            JP   LPSELECT
            JP   LPPUBTGT
            JP   LPENTER
            JP   LPCLOSE

; Contract: in HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
LPOPEN:
            LD   DE,1
            OR   A
            SBC  HL,DE
            JP   NZ,LPPLERR
            LD   HL,LPOBJECT
            LD   (LPOBJCUR),HL
            XOR  A
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry
LPREAD:
            PUSH HL
            PUSH DE
            LD   HL,(LPOBJCUR)
            LD   DE,(LPOACTEN)
            OR   A
            SBC  HL,DE
            JP   NZ,LPHASBYT
            POP  DE
            POP  HL
            LD   A,LVPLEND
            SCF
            RET
LPHASBYT:
            ADD  HL,DE
            LD   A,(HL)
            INC  HL
            LD   (LPOBJCUR),HL
            POP  DE
            POP  HL
            OR   A
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
LPREWIND:
            LD   HL,LPOBJECT
            LD   (LPOBJCUR),HL
            XOR  A
            RET

; Contract: out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,BC
LPLOCK:
            LD   DE,$1357
            LD   HL,$2468
            XOR  A
            RET

; Contract: in A,IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
LPSELECT:
            CP   2
            JP   NC,LPPLERR
            LD   (LPNEXTBK),A
            LD   A,(LPSELBK)
            CP   $FF
            JP   Z,LPBKLOAD
            OR   A
            LD   DE,LPBANK0
            JP   Z,LPBKSAVE
            LD   DE,LPBANK1
LPBKSAVE:
            LD   HL,(LPDEPLY+7)
            LD   BC,(LPDEPLY+9)
            LDIR
LPBKLOAD:
            LD   A,(LPNEXTBK)
            OR   A
            LD   HL,LPBANK0
            JP   Z,LPBKLRDY
            LD   HL,LPBANK1
LPBKLRDY:
            LD   DE,(LPDEPLY+7)
            LD   BC,(LPDEPLY+9)
            LDIR
            LD   A,(LPNEXTBK)
LPBKSELD:
            LD   (LPSELBK),A
            XOR  A
            RET

; Contract: in A,BC,DE,HL,IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX
LPPUBTGT:
            LD   C,A
            LD   A,(LPFAILOP)
            CP   6
            JP   Z,LPREQFL
            LD   A,C
            OR   A
            JP   NZ,LPPLERR
            LD   HL,LPDEPLY
            OR   A
            SBC  HL,DE
            JP   NZ,LPPLERR
            LD   A,1
            LD   (LPPUBLED),A
            XOR  A
            RET

; Contract: noreturn in A,HL,IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
LPENTER:
            PUSH HL
            CALL LPSELECT
            JP   C,LPPLERR
            POP  HL
            LD   A,(LPPUBLED)
            CP   1
            JP   NZ,LPPLERR
            JP   (HL)

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
LPCLOSE:
            XOR  A
            RET

LPREQFL:
            LD   A,$42
            SCF
            RET

LPPLERR:
            LD   A,4
            SCF
            RET

            ORG $7000
LPBANK0:
            DS  $0100
LPBANK1:
            DS  $0100
