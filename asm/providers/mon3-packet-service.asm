; Reference Nucleus packet-service provider for MON-3.
;
; Entry follows the runtime-vector ABI: A=source slot, HL=packet address and
; BC=packet byte count. Slot 1 maps to the MON-3 scanKeys API call (C=16,
; RST $10) and requires at least three bytes. Carry reports an unsupported
; slot or extent to the shared Nucleus trap gateway before any mutation.

SCANSLOT EQU 1
SCANAPI  EQU 16
SRVTRAP  EQU 7

; In A,BC,HL; out A,BC,DE,HL,carry,zero; clobbers sign,parity,halfCarry.
PKTSVC:
            CP   SCANSLOT
            JR   NZ,.fail
            LD   A,B
            OR   A
            JR   NZ,.keys
            LD   A,C
            CP   3
            JR   C,.fail
.keys:
            LD   C,SCANAPI
            RST  $10
            PUSH AF
            POP  DE                      ; D=key, E=MON-3 flags
            LD   (HL),D
            INC  HL
            LD   A,E
            RLCA
            RLCA                         ; MON-3 Z flag into bit zero
            AND  1
            LD   (HL),A
            INC  HL
            LD   A,E
            AND  1                       ; MON-3 carry flag
            LD   (HL),A
            OR   A
            RET

.fail:
            LD   A,SRVTRAP
            SCF
            RET
