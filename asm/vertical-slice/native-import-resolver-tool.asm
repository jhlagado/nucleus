; Shipping standalone Z80 import resolver. A shell passes the entry object name
; in HL/B, calls NativeImportResolve, and then selects the compiler tool bank.

            .include "platform-services-abi.asmi"

SRCPARTS     .equ 8
SRCCHUNK  .equ $7500
NativeSourceChunkLimit .equ $7800

            .org $8000
NativeImportResolverCodeStart:
            .include "native-object-client.asm"
            .include "native-source-plan-provider.asm"
            .include "native-import-resolver.asm"
NativeImportResolverCodeEnd:
