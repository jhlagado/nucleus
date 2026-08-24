; Shipping standalone Z80 import resolver. A shell passes the entry object name
; in HL/B, calls NativeImportResolve, and then selects the compiler tool bank.

            .include "platform-services-abi.asmi"

SourcePartCapacity     .equ 8
NativeSourceChunkBase  .equ $7500
NativeSourceChunkLimit .equ $7800

            .org $8000
NativeImportResolverCodeStart:
            .include "native-source-plan-provider.asm"
            .include "native-import-resolver.asm"
NativeImportResolverCodeEnd:
