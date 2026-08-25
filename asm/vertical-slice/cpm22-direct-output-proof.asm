DebugHooks .equ 0
            .include "cpm22-target-memory-map.asmi"
            .include "nucleus-runtime-identity.asmi"
            .org $4100
            .include "cpm22-direct-output.asm"

; Measured external-provider placeholders. They are deliberately outside the
; direct-sink extent and replaced by the runtime-catalogue and transaction
; implementations in the complete CP/M application.
.routine in A,BC,DE,HL,IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CpmDirectRuntimeProvider:
            XOR  A
            RET
.routine in HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CpmDirectPublish:
            XOR  A
            RET
.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CpmDirectPublishAbort:
            XOR  A
            RET
            .end
