; Test-only compiler-side linkage; host sources remain the canonical parts.
%IF Mon3HostTransport
%INCLUDE "../../../asm/vertical-slice/mon3-target-memory-map.asmi"
%ELSE
%INCLUDE "../../../asm/vertical-slice/target-memory-map.asmi"
%ENDIF
%INCLUDE "../../../asm/vertical-slice/loop-compiler-state.asmi"
%INCLUDE "../../../asm/vertical-slice/aggregate-call-state.asmi"
%INCLUDE "../../../asm/vertical-slice/target-output-state.asmi"
%INCLUDE "compiler-links.asmi"
%INCLUDE "../../../asm/vertical-slice/native-host-vector.asmi"
