            .include "platform-services-abi.asmi"

ObjectNodeGatewayPort .equ $E1
ProofStackTop         .equ $7F00

            .org $0010
ObjectNodeGateway:
            OUT  (ObjectNodeGatewayPort),A
            RET

            .org $4000
ProofStart:
            LD   SP,ProofStackTop
            LD   (ProofEntrySp),SP
            LD   IX,$1357
            LD   IY,$2468

            LD   HL,ProofObjectRequest
            LD   C,NucleusServiceObject
            RST  $10
            JP   C,ProofFail
            LD   HL,(ProofObjectRequest+NucleusObjectRequestHandle)
            LD   A,H
            OR   L
            JP   Z,ProofFail

            LD   A,NucleusObjectRead
            LD   (ProofObjectRequest+NucleusObjectRequestOperation),A
            LD   HL,ProofReadBuffer
            LD   (ProofObjectRequest+NucleusObjectRequestPointer),HL
            LD   HL,3
            LD   (ProofObjectRequest+NucleusObjectRequestLength),HL
            LD   HL,ProofObjectRequest
            LD   C,NucleusServiceObject
            RST  $10
            JP   C,ProofFail
            LD   HL,(ProofObjectRequest+NucleusObjectRequestResult)
            LD   DE,3
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFail

            LD   A,NucleusObjectClose
            LD   (ProofObjectRequest+NucleusObjectRequestOperation),A
            LD   HL,0
            LD   (ProofObjectRequest+NucleusObjectRequestPointer),HL
            LD   (ProofObjectRequest+NucleusObjectRequestLength),HL
            LD   (ProofObjectRequest+NucleusObjectRequestResult),HL
            LD   HL,ProofObjectRequest
            LD   C,NucleusServiceObject
            RST  $10
            JP   C,ProofFail

            PUSH IX
            POP  HL
            LD   DE,$1357
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFail
            PUSH IY
            POP  HL
            LD   DE,$2468
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFail
            LD   HL,0
            ADD  HL,SP
            LD   DE,(ProofEntrySp)
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFail
            XOR  A
            LD   (ProofResult),A
            HALT

ProofFail:
            LD   A,1
            LD   (ProofResult),A
            HALT

ProofEntrySp:      .dw 0
ProofResult:       .db $FF
ProofObjectName:   .db "source.nu"
ProofObjectRequest:
            .db NucleusObjectRequestSize,NucleusObjectAbiVersion
            .db NucleusObjectOpenRead,0
            .dw 0,ProofObjectName,9,0,0,0
ProofReadBuffer:   .db 0,0,0
ProofEnd:
