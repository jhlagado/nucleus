%INCLUDE "cpm22-proof-context.asmi"
%INCLUDE "nucleus-runtime-identity.asmi"
%INCLUDE "cpm22-direct-output.asm"
%INCLUDE "cpm22-embedded-assets.asmi"
%INCLUDE "cpm22-publisher-extents.asmi"
%INCLUDE "cpm22-bdos-call.asm"
%INCLUDE "cpm22-publisher.asm"

; Contract: in A,BC,DE,HL,IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CRPROVID:
            XOR  A
            RET

CCOUTNAM:
            DB 0,"OUTPUT  ","COM"
CCOUTFMT: DB 0
CCFMTCOM EQU 0
CCFMTBIN EQU 1
CCFMTHEX EQU 2
