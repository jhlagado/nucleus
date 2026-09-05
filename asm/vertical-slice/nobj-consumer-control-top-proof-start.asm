ORG $0100
; Contract: noreturn
FPSTART:
            LD   SP,LVSTKLIM
            LD   IX,LPRUNDSC
            LD   (LVSDPTR),IX
            CALL LCVALDSC
            JR   C,QF
            CALL LCVALDEP
            JR   C,QF
            LD   A,$A5
            JR   LPFINISH
QF:
            XOR  A
LPFINISH:
            LD   (FPSTATUS),A
            HALT

            ORG LVCBASE
LPCCODE:
