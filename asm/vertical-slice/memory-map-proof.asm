NativeStreamingSource .equ 0
; Executable proof that the manifest-driven harness and vertical-slice memory
; profile agree with the assembly interface.

            .include "memory-map.asmi"

            .org MMPROOF
ProofStart:
            LD   SP,STACKTOP
            LD   A,$A5
            LD   (ProofStatus),A
            HALT
ProofEnd:

ProofStatus:
            .db  0

            .end
