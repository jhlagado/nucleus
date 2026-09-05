ORG $0100
; Contract: noreturn
FPSTART:
            LD   SP,LVSTKLIM
            XOR  A
            LD   (LPPUBLED),A
            DEC  A
            LD   (LPSELBK),A
            LD   IX,LPRUNDSC
            CALL LCRUN
            LD   (LPFLSTAT),A
            HALT

            ORG LVCBASE
LPCCODE:
