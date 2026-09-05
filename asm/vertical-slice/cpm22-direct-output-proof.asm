%INCLUDE "cpm22-proof-context.asmi"
%INCLUDE "nucleus-runtime-identity.asmi"
%INCLUDE "cpm22-direct-output.asm"

; Measured test-only provider placeholders remain after the direct sink.
; The complete compiler supplies the runtime catalogue and publisher.
; Contract: in A,BC,DE,HL,IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CRPROVID:
            XOR  A
            RET
; Contract: in HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
PBPUBL:
            XOR  A
            RET
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
PBABORT:
            XOR  A
            RET
