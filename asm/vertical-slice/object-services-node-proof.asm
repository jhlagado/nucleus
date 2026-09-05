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
            LD   C,NSOBJECT
            RST  $10
            JP   C,ProofFail
            LD   HL,(ProofObjectRequest+NOFHAND)
            LD   A,H
            OR   L
            JP   Z,ProofFail

            LD   A,NOREAD
            LD   (ProofObjectRequest+NOFOPER),A
            LD   HL,ProofReadBuffer
            LD   (ProofObjectRequest+NOFPTR),HL
            LD   HL,3
            LD   (ProofObjectRequest+NOFLEN),HL
            LD   HL,ProofObjectRequest
            LD   C,NSOBJECT
            RST  $10
            JP   C,ProofFail
            LD   HL,(ProofObjectRequest+NOFRES)
            LD   DE,3
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFail

            LD   A,NOCLOSE
            LD   (ProofObjectRequest+NOFOPER),A
            LD   HL,0
            LD   (ProofObjectRequest+NOFPTR),HL
            LD   (ProofObjectRequest+NOFLEN),HL
            LD   (ProofObjectRequest+NOFRES),HL
            LD   HL,ProofObjectRequest
            LD   C,NSOBJECT
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
            .db NORQSIZE,NOABI
            .db NOOPEN,0
            .dw 0,ProofObjectName,9,0,0,0
ProofReadBuffer:   .db 0,0,0
ProofEnd:
