%IF TargetStreamingOutput
%INCLUDE "../../../asm/vertical-slice/target-memory-map.asmi"
%ELSE
%INCLUDE "../../../asm/vertical-slice/memory-map.asmi"
%ENDIF
%INCLUDE "../../../asm/vertical-slice/loop-compiler-state.asmi"
%INCLUDE "../../../asm/vertical-slice/aggregate-call-state.asmi"
%IF TargetStreamingOutput
%INCLUDE "../../../asm/vertical-slice/target-output-state.asmi"
%ENDIF
%INCLUDE "layout.asmi"
%INCLUDE "../../../asm/vertical-slice/compiler-diagnostics.asm"

PDEND:
