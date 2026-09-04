; Minimal characterization of AZM's separate code/data placement cursors.
            .org $0100
First:      NOP
            .org $0200
Header:     .db "NH"
Second:     RET
