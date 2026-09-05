; Proof-layout runtime wrapper. Target-linked runtime images use the separate
; assemble-native-runtime.mjs composition and exclude the proof service adapter.

; Profile inputs: RuntimeProofServices=1, RuntimePacketGateway=0.
%INCLUDE "loop-z80-runtime.asm"
