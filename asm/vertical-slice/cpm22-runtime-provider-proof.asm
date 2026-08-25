DebugHooks .equ 0
            .include "cpm22-target-memory-map.asmi"
            .include "nucleus-runtime-identity.asmi"
            .org $4100
            .include "cpm22-direct-output.asm"
            .include "cpm22-runtime-provider.asm"
            .include "cpm22-embedded-assets.asmi"

.routine in HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CpmDirectPublish:
            XOR  A
            RET
.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CpmDirectPublishAbort:
            XOR  A
            RET

            .org $5900
CpmRuntimeProofContext:
            .dw  $0803
            .dw  $5800
            .dw  $0D00
            .dw  $5824
            .dw  $5800
            .dw  $584D
            .dw  $0CB3
            .dw  0
            .dw  0
            .end
