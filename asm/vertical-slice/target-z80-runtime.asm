; Target-linked runtime wrapper. Service implementations and proof reset state
; live outside the selected target helper image and are reached through the
; writable vector table.

RuntimeProofServices .equ 0
RuntimePacketGateway .equ 1
            .include "loop-z80-runtime.asm"
