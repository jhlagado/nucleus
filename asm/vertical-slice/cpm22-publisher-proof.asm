DebugHooks .equ 0
            .include "cpm22-target-memory-map.asmi"
            .include "nucleus-runtime-identity.asmi"

            .org $4100
            .include "cpm22-direct-output.asm"
            .include "cpm22-embedded-assets.asmi"
            .include "cpm22-bdos-call.asm"
            .include "cpm22-publisher.asm"

.routine in A,BC,DE,HL,IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CpmDirectRuntimeProvider:
            XOR  A
            RET

CpmCompilerOutputName:
            .db  0,"OUTPUT  ","COM"
CpmCompilerOutputFormat: .db 0
CpmOutputFormatCom .equ 0
CpmOutputFormatBin .equ 1
CpmOutputFormatHex .equ 2
            .end
