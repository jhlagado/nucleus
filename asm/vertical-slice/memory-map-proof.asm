NativeStreamingSource .equ 0
; Executable proof that the manifest-driven harness and vertical-slice memory
; profile agree with the assembly interface.

            .include "memory-map.asmi"

            .org MMPROOF
FPSTART:
            LD   SP,STACKTOP
            LD   A,$A5
            LD   (FPSTATUS),A
            HALT
FPEND:

FPSTATUS:
            .db  0

            .end
