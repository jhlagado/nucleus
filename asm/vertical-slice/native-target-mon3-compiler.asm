; Shipping compiler relocated for a MON3-compatible RST 10h host transport.

DebugHooks .equ 0
NativeStreamingSource .equ 1
Mon3HostTransport .equ 1
            .include "mon3-target-memory-map.asmi"
            .include "nucleus-runtime-identity.asmi"
            .org $4400
NativeSystemServicesBase:
            .include "platform-services-abi.asmi"
            .include "native-object-client.asm"
            .include "native-source-plan-provider.asm"
NativeNobjWriterCodeStart:
            .include "native-nobj-writer.asm"
NativeNobjWriterCodeEnd:
            .include "native-system-services.asm"
            .org CompilerCoreBase
            .include "flat-target-compiler-image.asmi"
            .include "native-host-vector.asmi"
