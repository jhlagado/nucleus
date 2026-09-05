; Transitional legacy-adapter test entry. Production catalog generation and
; development links use scripts/assemble-native-runtime.mjs with native parts.

            .include "nucleus-runtime-link-context.asmi"

            .org RTORIGIN
RTSTART:
            .include "target-z80-runtime.asm"
RTEND:
