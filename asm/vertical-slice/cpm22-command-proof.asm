DebugHooks .equ 0
NativeStreamingSource .equ 1
SRCPARTS .equ 8
            .include "cpm22-target-memory-map.asmi"
            .include "platform-services-abi.asmi"
            .org $4100
            .include "cpm22-bdos-call.asm"
            .include "cpm22-source-provider.asm"
            .include "cpm22-command.asm"
            .end
