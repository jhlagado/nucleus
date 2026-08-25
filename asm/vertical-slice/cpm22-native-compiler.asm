; Complete native Nucleus compiler transient for the ideal CP/M 2.2 target.
; CP/M enters at $0100; the compiler core remains a fixed, relocatable 16 KiB
; image and all host/provider code remains outside its accounting boundary.

DebugHooks           .equ 0
NativeStreamingSource .equ 1

            .include "cpm22-target-memory-map.asmi"
            .include "nucleus-runtime-identity.asmi"
            .include "platform-services-abi.asmi"

            .org CompilerTransientBase
CpmCompilerTransientStart:
            JP   CpmCompilerEntry

            .org CompilerCoreBase
            .include "flat-target-compiler-image.asmi"

            .org CpmHostVectorBase
            .include "cpm22-native-host-vector.asmi"

            .include "cpm22-bdos-call.asm"
            .include "cpm22-direct-output.asm"
            .include "cpm22-runtime-provider.asm"
            .include "cpm22-publisher.asm"
            .include "cpm22-source-provider.asm"
            .include "cpm22-command.asm"

CpmCompilerSourceHostStart:
            .include "native-source-host.asm"
CpmCompilerSourceHostEnd:

            .include "cpm22-native-startup.asm"

            .end
