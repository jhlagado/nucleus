LPCCEND:

            ORG $4800
LPRUNDSC:
            DB  10,0,1,0
            DW  1,LPDEPLY,LPRESULT
LPDEPLY:
            DB  18,1,0
            DW  1
            DB  1,$EE
            DW  $8000,$0100,$8080,$0020
            DB  0
            DW  0
LPRESULT:
            DB  0,0,0,0
LPPUBLED:
            DB  0
LPCLOSED:
            DB  0
LPCLOSCN:
            DB  0
LPFLSTAT:
            DB  0
LPOACTEN:
            DW  LPOBJEND
LPIDLOW:
            DW  $2468
LPIDHIGH:
            DW  $1357
LPLOCKCN:
            DB  0
LPCHGID:
            DB  0
LPFAILOP:
            DB  0

            ORG LVOBJBA
LPOBJECT:
            DB $01,$0f,$00,$4e,$4f,$42,$4a,$00,$01,$00,$01,$00,$01,$ee,$00,$80,$00,$01
            DB $02,$09,$00,$00,$00,$80,$3e,$00,$32,$81,$80,$76
            DB $02,$05,$00,$00,$80,$80,$00,$00
            DB $03,$04,$00,$00,$01,$80,$5a
            DB $04,$29,$00,$01,$00,$00,$00,$80,$80,$80,$20,$00,$80,$80,$01,$00,$80,$80
            DB $02,$00,$82,$80,$00,$00,$00,$00,$00,$80,$80,$02,$00,$01,$00,$01,$82,$00
            DB $00,$00,$00,$00,$00,$00,$00,$00
            DB $05,$07,$00,$06,$00,$00,$00,$80,$62,$9a
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
            LD   A,(LPFAILOP)
            CP   1
            JP   Z,LPREQFL
            LD   DE,1
            OR   A
            SBC  HL,DE
            JP   NZ,LPPLERR
            LD   HL,LPOBJECT
            LD   (LPOBJCUR),HL
            XOR  A
            LD   (LPLOCKCN),A
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry
LPREAD:
            LD   A,(LPFAILOP)
            CP   2
            JP   Z,LPREQFL
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
            LD   A,(LPFAILOP)
            CP   3
            JP   Z,LPREQFL
            LD   HL,LPOBJECT
            LD   (LPOBJCUR),HL
            XOR  A
            RET

; Contract: out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,BC
LPLOCK:
            LD   A,(LPFAILOP)
            CP   4
            JP   Z,LPREQFL
            LD   A,(LPLOCKCN)
            INC  A
            LD   (LPLOCKCN),A
            LD   DE,(LPIDHIGH)
            LD   HL,(LPIDLOW)
            LD   A,(LPCHGID)
            OR   A
            JP   Z,LPIDRDY
            LD   B,A
            INC  B
            LD   A,(LPLOCKCN)
            CP   B
            JP   NZ,LPIDRDY
            INC  HL
LPIDRDY:
            XOR  A
            RET

; Contract: in A,IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
LPSELECT:
            LD   B,A
            LD   A,(LPFAILOP)
            CP   5
            JP   Z,LPREQFL
            LD   A,B
            OR   A
            JP   NZ,LPPLERR
            LD   HL,LPDEPLY
            PUSH IX
            POP  DE
            OR   A
            SBC  HL,DE
            JP   NZ,LPPLERR
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
            PUSH HL
            LD   BC,(LPDEPLY+7)
            OR   A
            SBC  HL,BC
            POP  HL
            JP   NZ,LPPLERR
            LD   HL,LPDEPLY
            OR   A
            SBC  HL,DE
            JP   NZ,LPPLERR
            LD   A,1
            LD   (LPPUBLED),A
            XOR  A
            RET

; Contract: noreturn in A,HL,IX out A,carry,zero clobbers sign,parity,halfCarry,BC
LPENTER:
            LD   B,A
            LD   A,(LPFAILOP)
            CP   7
            JP   Z,LPREQFL
            LD   A,B
            OR   A
            JP   NZ,LPPLERR
            LD   A,(LPPUBLED)
            CP   1
            JP   NZ,LPPLERR
            JP   (HL)

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
LPCLOSE:
            LD   A,(LPCLOSCN)
            INC  A
            LD   (LPCLOSCN),A
            LD   A,1
            LD   (LPCLOSED),A
            LD   A,(LPFAILOP)
            CP   8
            JP   Z,LPREQFL
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

LPOBJCUR:
            DW  0
