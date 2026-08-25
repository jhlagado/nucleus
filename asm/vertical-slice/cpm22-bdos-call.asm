; CP/M standardizes only the 8080 register set. Native Z80 providers share this
; wrapper so no provider depends on accidental IX/IY preservation by a BIOS.

CpmBdos .equ $0005

CpmBdosCallCodeStart:
.routine in C,DE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CpmCallBdos:
            PUSH IX
            PUSH IY
            CALL CpmBdos
            POP  IY
            POP  IX
            RET

; Copy a twelve-byte drive/name/type field and clear the remaining ordinary
; 36-byte FCB. Publisher and source providers both rebuild private FCBs.
.routine in DE,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CpmBuildFcb:
            LD   BC,12
            LDIR
            XOR  A
            LD   B,24
CpmClearFcbTail:
            LD   (DE),A
            INC  DE
            DJNZ CpmClearFcbTail
            RET
CpmBdosCallCodeEnd:
