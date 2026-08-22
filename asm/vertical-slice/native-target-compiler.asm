; Shipping compiler linked to the native host vector rather than AdapterLog.

DebugHooks .equ 0
NativeStreamingSource .equ 1
Mon3HostTransport .equ 0
            .include "target-memory-map.asmi"
            .include "nucleus-runtime-identity.asmi"
            .org CompilerCoreBase
            .include "flat-target-compiler-image.asmi"
            .include "native-host-vector.asmi"
