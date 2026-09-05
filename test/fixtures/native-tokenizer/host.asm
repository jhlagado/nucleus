%INCLUDE "../../../asm/vertical-slice/target-memory-map.asmi"
%INCLUDE "../../../asm/vertical-slice/loop-compiler-state.asmi"
%INCLUDE "../../../asm/vertical-slice/aggregate-call-state.asmi"
%INCLUDE "../../../asm/vertical-slice/target-output-state.asmi"
%INCLUDE "host-layout.asmi"
%INCLUDE "../../../asm/vertical-slice/source-adapter.asm"
%INCLUDE "../../../asm/vertical-slice/loop-tokenizer.asm"
%INCLUDE "../../../asm/vertical-slice/loop-keywords.asmi"
%INCLUDE "../../../asm/vertical-slice/native-source-host.asm"

; These are test-only transports, not the native host vector implementation.
HVCHUNK: OUT (THPCHUNK),A
         RET
HVRETAIN: OUT (THPRET),A
         RET
HVCMPNAM: OUT (THPCMP),A
         RET
HVMATNAM: OUT (THPMAT),A
         RET

; Six-byte source position copy and launch-boundary diagnostic return.
DGCOPYP: LD BC,6
         LDIR
         RET
DGINLINE: POP HL
          LD A,(HL)
THDIAG: LD (DGCODE),A
        LD SP,(CPABRTSP)
        SCF
        RET
THEND:
