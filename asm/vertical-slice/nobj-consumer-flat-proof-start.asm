ORG $0100
; Contract: noreturn
FPSTART:
            LD   SP,LVSTKLIM
            XOR  A
            LD   (LPCLOSED),A
            LD   (LPCLOSCN),A
            LD   IX,LPRUNDSC
            CALL LCRUN
            LD   (LPFLSTAT),A
            HALT

; Contract: noreturn
LPORDST:
            LD   SP,LVSTKLIM
            LD   HL,LPOBJECT+10
            LD   (LPOACTEN),HL
            LD   IX,LPRUNDSC
            CALL LCRUN
            XOR  A
            LD   (LPDEPLY),A
            LD   IX,LPRUNDSC
            CALL LCRUN
            HALT

; Contract: noreturn
LPRECST:
            LD   SP,LVSTKLIM
            LD   HL,LPOBJECT+10
            LD   (LPOACTEN),HL
            LD   IX,LPRUNDSC
            CALL LCRUN
            LD   HL,LPOBJEND
            LD   (LPOACTEN),HL
            LD   IX,LPRUNDSC
            CALL LCRUN
            HALT

            ORG LVCBASE
LPCCODE:
