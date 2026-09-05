%INCLUDE "cpm22-proof-context.asmi"
%INCLUDE "nucleus-runtime-identity.asmi"
%INCLUDE "cpm22-direct-output.asm"
%INCLUDE "cpm22-runtime-provider.asm"
%INCLUDE "cpm22-embedded-assets.asmi"

; Contract: in HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
PBPUBL:
            XOR  A
            RET
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
PBABORT:
            XOR  A
            RET

            ORG $5900
CRPROOFC:
            DW $0803,$5800,$0D00,$5824,$5800,$584D,$0CB3,0,0
