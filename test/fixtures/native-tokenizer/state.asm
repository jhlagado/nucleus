; Test-only profile selector; all memory/layout values come from production.
%IF TargetStreamingOutput
%INCLUDE "../../../asm/vertical-slice/target-memory-map.asmi"
%ELSE
%INCLUDE "../../../asm/vertical-slice/memory-map.asmi"
%ENDIF
%IF HistoricalCompilerState
%INCLUDE "../../../asm/vertical-slice/compiler-state.asmi"
%ELSE
%INCLUDE "../../../asm/vertical-slice/loop-compiler-state.asmi"
%INCLUDE "../../../asm/vertical-slice/aggregate-call-state.asmi"
%IF TargetStreamingOutput
%INCLUDE "../../../asm/vertical-slice/target-output-state.asmi"
%ENDIF
%ENDIF
