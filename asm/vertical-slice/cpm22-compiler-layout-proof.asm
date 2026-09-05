; Native ATOM composition. Build flags are immutable entry metadata.
; Strict-link proof for the native Nucleus compiler inside the CP/M 2.2 TPA.
; Provider entries are inert because this proof establishes relocation and
; simultaneous memory extents only. Executable BDOS bindings are separate.










%INCLUDE "cpm22-target-memory-map.asmi"
%INCLUDE "nucleus-runtime-identity.asmi"
%INCLUDE "cpm-layout-core-origin.asmi"
%INCLUDE "flat-target-compiler-image.asmi"
%INCLUDE "cpm-layout-host-vector.asm"
%INCLUDE "native-source-host.asm"
%INCLUDE "cpm-layout-host-stubs.asm"
