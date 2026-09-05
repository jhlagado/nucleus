; Proof-layout runtime wrapper. Target-linked runtime images use the separate
; nucleus-target-runtime-link.asm entry and exclude the proof service adapter.

; Profile inputs: RuntimeProofServices=1, RuntimePacketGateway=0.
%INCLUDE "loop-z80-runtime.asm"
