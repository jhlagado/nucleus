ORG MMPROOF
FPSTART:
            LD   SP,STACKTOP
            LD   A,$A5
            LD   (FPSTATUS),A
            HALT
FPEND:

FPSTATUS:
            DB  0

; End of source part.
