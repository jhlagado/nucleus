; Reference Nucleus packet-service provider for MON-3.
;
; Entry follows the runtime-vector ABI: A=source slot, HL=packet address and
; BC=packet byte count. Slot 1 maps to the MON-3 scanKeys API call (C=16,
; RST $10) and requires at least three bytes. Carry reports an unsupported
; slot or extent to the shared Nucleus trap gateway before any mutation.

NucleusServiceScanKeys .equ 1
Mon3ApiScanKeys         .equ 16
NucleusTrapService      .equ 7

.routine in A,BC,HL out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
PacketService:
            CP   NucleusServiceScanKeys
            JR   NZ,PacketServiceFailure
            LD   A,B
            OR   A
            JR   NZ,PacketServiceScanKeys
            LD   A,C
            CP   3
            JR   C,PacketServiceFailure
PacketServiceScanKeys:
            LD   C,Mon3ApiScanKeys
            RST  $10
            PUSH AF
            POP  DE                      ; D=key, E=MON-3 flags
            LD   (HL),D
            INC  HL
            LD   A,E
            RLCA
            RLCA                         ; MON-3 Z flag into bit zero
            AND  1
PacketServicePressedReady:
            LD   (HL),A
            INC  HL
            LD   A,E
            AND  1                       ; MON-3 carry flag
PacketServiceNewReady:
            LD   (HL),A
            OR   A
            RET

PacketServiceFailure:
            LD   A,NucleusTrapService
            SCF
            RET
