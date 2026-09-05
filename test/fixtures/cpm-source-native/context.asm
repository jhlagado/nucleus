; Numeric proof inputs, not a replacement machine map.
; cpm22-target-memory-map.asmi: $5800+$0058, $7000+$0500, $6000.
; cpm22-source-provider-proof.asm: eight configured source parts.
; platform-services-abi.asmi: invalid=1, capacity=4, storage=6.
CSWKBASE EQU $5858
SRCPARTS EQU 8
SRCCHUNK EQU $7500
NSTATINV EQU 1
NSTATCAP EQU 4
NSTATIO  EQU 6
; Test-only upper bound, exported separately from production symbol map.
HOSTLIM  EQU $6000
