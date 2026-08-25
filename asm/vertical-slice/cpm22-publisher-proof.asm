DebugHooks .equ 0
            .include "cpm22-target-memory-map.asmi"
            .include "nucleus-runtime-identity.asmi"

            .org $4100
            .include "cpm22-direct-output.asm"
            .include "cpm22-embedded-assets.asmi"
            .include "cpm22-publisher.asm"

.routine in A,BC,DE,HL,IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CpmDirectRuntimeProvider:
            XOR  A
            RET

CpmCompilerOutputName:
            .db  0,"OUTPUT  ","COM"
            .end
