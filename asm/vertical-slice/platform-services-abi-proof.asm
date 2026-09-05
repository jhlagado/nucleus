            .include "platform-services-abi.asmi"

ProofStackTop .equ $7F00

            .org $4000
FPSTART:
            LD   SP,ProofStackTop
            LD   IX,$1357
            LD   IY,$2468
            LD   BC,$A55A
            LD   (ProofEntrySp),SP
            CALL ProofPlatformInfoAdapter
            JP   C,FPFAIL
            CP   NSABI
            JP   NZ,FPFAIL
            LD   A,D
            OR   A
            JP   NZ,FPFAIL
            LD   A,E
            CP   NSCAPEXE+NSCAPIO+NSCAPCTL+NSCAPDEV
            JP   NZ,FPFAIL
            PUSH IX
            POP  HL
            LD   DE,$1357
            OR   A
            SBC  HL,DE
            JP   NZ,FPFAIL
            PUSH IY
            POP  HL
            LD   DE,$2468
            OR   A
            SBC  HL,DE
            JP   NZ,FPFAIL
            LD   BC,$1234
            CALL ProofPacketAdapter
            JP   C,FPFAIL
            LD   HL,(ProofPacketBc)
            LD   DE,$1234
            OR   A
            SBC  HL,DE
            JP   NZ,FPFAIL
            LD   HL,ProofObjectRequest
            CALL ProofObjectAdapter
            JP   C,FPFAIL
            LD   HL,(ProofObjectRequest+NOFHAND)
            LD   DE,$3412
            OR   A
            SBC  HL,DE
            JP   NZ,FPFAIL
            LD   A,2
            LD   (ProofObjectRequest+NOFABI),A
            LD   HL,ProofObjectRequest
            CALL ProofObjectAdapter
            JP   NC,FPFAIL
            CP   NSTATINV
            JP   NZ,FPFAIL
            LD   A,1
            LD   (ProofSelectedBank),A
            CALL ProofNestedBankCall
            JP   C,FPFAIL
            CP   $5A
            JP   NZ,FPFAIL
            LD   A,(ProofSelectedBank)
            CP   1
            JP   NZ,FPFAIL
            LD   HL,0
            ADD  HL,SP
            LD   DE,(ProofEntrySp)
            OR   A
            SBC  HL,DE
            JP   NZ,FPFAIL
            XOR  A
            LD   (ProofResult),A
            HALT

FPFAIL:
            LD   A,1
            LD   (ProofResult),A
            HALT

.routine out A,DE,HL,carry,zero clobbers sign,parity,halfCarry
ProofPlatformInfoAdapter:
            PUSH BC
            LD   C,NSINFO
            CALL ProofExpansionDispatcher
            POP  BC
            RET

.routine in BC out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
ProofPacketAdapter:
            LD   (ProofSavedBc),BC
            LD   C,NSPACKET
            JP   ProofExpansionDispatcher

.routine in HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
ProofObjectAdapter:
            LD   C,NSOBJECT
            JP   ProofExpansionDispatcher

.routine in C out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
ProofExpansionDispatcher:
            LD   A,C
            CP   NSINFO
            JR   Z,ProofPlatformInfo
            CP   NSPACKET
            JR   Z,ProofPacketService
            CP   NSOBJECT
            JR   Z,ProofObjectService
            LD   A,$EE
            SCF
            RET

.routine out A,DE,carry,zero clobbers sign,parity,halfCarry
ProofPlatformInfo:
            LD   A,NSABI
            LD   DE,NSCAPEXE+NSCAPIO+NSCAPCTL+NSCAPDEV
            OR   A
            RET

.routine out A,BC,carry,zero clobbers sign,parity,halfCarry
ProofPacketService:
            LD   BC,(ProofSavedBc)
            LD   (ProofPacketBc),BC
            XOR  A
            RET

.routine in HL out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
ProofObjectService:
            LD   A,(HL)
            CP   NORQSIZE
            JR   NZ,ProofObjectInvalid
            INC  HL
            LD   A,(HL)
            CP   NOABI
            JR   NZ,ProofObjectInvalid
            INC  HL
            LD   A,(HL)
            CP   NOOPEN
            JR   NZ,ProofObjectInvalid
            INC  HL
            LD   A,(HL)
            OR   A
            JR   NZ,ProofObjectInvalid
            INC  HL
            LD   (HL),$12
            INC  HL
            LD   (HL),$34
            XOR  A
            RET
ProofObjectInvalid:
            LD   A,NSTATINV
            SCF
            RET

; This models the fixed-ROM far-call property which Stage 7 must prove against
; MON3 itself: nested calls restore the immediately preceding bank and return
; the callee's AF with the original stack depth.
.routine out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
ProofNestedBankCall:
            LD   A,(ProofSelectedBank)
            LD   B,A
            LD   A,2
            LD   (ProofSelectedBank),A
            OR   A
            CALL ProofBankedTarget
            PUSH AF
            LD   A,B
            LD   (ProofSelectedBank),A
            POP  AF
            RET

.routine out A
ProofBankedTarget:
            LD   A,$5A
            RET

ProofEntrySp:      .dw 0
ProofSavedBc:      .dw 0
ProofPacketBc:     .dw 0
ProofSelectedBank: .db 0
ProofResult:       .db $FF
ProofObjectName:   .db "main"
ProofObjectRequest:
            .db NORQSIZE,NOABI
            .db NOOPEN,0
            .dw 0,ProofObjectName,4,0,0,0
FPEND:
