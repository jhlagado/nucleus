; Host-instrumented compiler linked to the native host vector.

DebugHooks .equ 1
NativeStreamingSource .equ 1
Mon3HostTransport .equ 0
            .include "target-memory-map.asmi"
            .include "nucleus-runtime-identity.asmi"
            .org MMCORE
            .include "flat-target-compiler-image.asmi"
            .include "native-host-vector.asmi"
