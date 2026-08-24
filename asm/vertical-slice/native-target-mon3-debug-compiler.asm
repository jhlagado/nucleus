; Host-instrumented compiler relocated for the MON3-compatible transport.

DebugHooks .equ 1
NativeStreamingSource .equ 1
Mon3HostTransport .equ 1
            .include "mon3-target-memory-map.asmi"
            .include "nucleus-runtime-identity.asmi"
            .org CompilerCoreBase
            .include "flat-target-compiler-image.asmi"
            .include "native-host-vector.asmi"
            .org $4400
NativeSystemServicesBase:
            .include "platform-services-abi.asmi"
            .include "native-source-plan-provider.asm"
            .include "native-system-services.asm"
