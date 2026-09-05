; Canonical diagnostic publication and full-width token-position helpers.
; CompilerNonlocalDiagnostics is an immutable entry-profile input.

%IF CompilerNonlocalDiagnostics
; Contract: noreturn
%ELSE
; Contract: in A out A,carry clobbers zero,sign,parity,halfCarry,DE,HL
%ENDIF
DGSET:
            LD   (DGCODE),A
            LD   A,(SSPARTID)
            LD   (DGPARTID),A
%IF CompilerNonlocalDiagnostics
            LD   SP,(CPABRTSP)
%ENDIF
            SCF
            RET

; Contract: noreturn
DGINLINE:
            POP  HL
            LD   A,(HL)
            JR   DGSET

; Shared full-width source and destination setup for the three callers of each
; direction. These helpers alter no position representation or address width.
; Contract: in DE out BC,DE,HL clobbers parity,halfCarry
DGCOPYTK:
            LD   HL,TNSTOFF

; Copy one complete offset/line/column record from HL to DE. LDIR preserves
; carry, allowing diagnostic callers to establish failure after the copy.
; Contract: in DE,HL out BC,DE,HL clobbers parity,halfCarry
DGCOPYP:
            LD   BC,6
            LDIR
            RET

; Contract: in HL out BC,DE,HL clobbers parity,halfCarry
DGRESTTK:
            LD   DE,TNSTOFF
            JR   DGCOPYP
