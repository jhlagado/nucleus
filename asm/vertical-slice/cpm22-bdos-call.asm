; CP/M standardizes only the 8080 register set. Native Z80 providers share this
; wrapper so no provider depends on accidental IX/IY preservation by a BIOS.

CPMBDOS   EQU $0005

BDSTART:
; Contract: in C,DE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
BDOSCALL:
            PUSH IX
            PUSH IY
            CALL CPMBDOS
            POP  IY
            POP  IX
            RET

; Copy a twelve-byte drive/name/type field and clear the remaining ordinary
; 36-byte FCB. HL returns at the byte after the source name field. Publisher
; and source providers both rebuild private FCBs.
; Contract: in DE,HL out A,HL,carry,zero clobbers sign,parity,halfCarry,BC,DE
FCBMAKE:
            LD   BC,12
            LDIR
            XOR  A
            LD   B,24
FCBCLR:
            LD   (DE),A
            INC  DE
            DJNZ FCBCLR
            RET
BDEND:
