; Proof-only producer for the optional NOBJ manifest path.

LPMEMBEG   EQU $0000
LPMEMEND   EQU $FFFF

            ORG $0100
FPSTART:
            HALT

            ORG $1000
LPADPLEN:
            DW LPLOGLEN
LPADPLOG:
            ; IMAGE bank 0, $8000: LD A,$5A / LD ($8081),A / HALT
            DB 1,0,$00,$80,6,0,$3E,$5A,$32,$81,$80,$76
            ; IMAGE bank 0, $8080: loaded initialized bytes
            DB 1,0,$80,$80,2,0,0,0
LPADPEND:

; Resolve the log length after both source-owned labels, without rewriting input.
LPLOGLEN   EQU LPADPEND-LPADPLOG
