            .include "platform-services-abi.asmi"

RuntimeCatalogNodeGatewayPort .equ $E2
ProofStackTop                 .equ $7F00

            .org $0010
RuntimeCatalogNodeGateway:
            OUT  (RuntimeCatalogNodeGatewayPort),A
            RET

            .org $4000
ProofStart:
            LD   SP,ProofStackTop
            LD   (ProofEntrySp),SP
            LD   IX,$1357
            LD   IY,$2468

            LD   HL,ProofRequest
            LD   C,NSRTCAT
            RST  $10
            JP   C,ProofFail
            LD   HL,(ProofRequest+NCFRES)
            LD   DE,2
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFail
            LD   HL,(ProofBuffer)
            LD   DE,$3322
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFail

            LD   A,NCINIT
            LD   (ProofRequest+NCFOPER),A
            LD   A,1
            LD   (ProofRequest+NCFFLAG),A
            LD   A,3
            LD   (ProofRequest+NCFBANK),A
            LD   HL,5
            LD   (ProofRequest+NCFLEN),HL
            LD   HL,0
            LD   (ProofRequest+NCFOFF),HL
            LD   HL,5
            LD   (ProofRequest+NCFCAP),HL
            LD   HL,ProofRequest
            LD   C,NSRTCAT
            RST  $10
            JP   C,ProofFail
            LD   HL,(ProofRequest+NCFRES)
            LD   DE,5
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFail
            LD   HL,ProofExpectedInitial
            LD   DE,ProofBuffer
            LD   B,5
ProofCompare:
            LD   A,(DE)
            CP   (HL)
            JP   NZ,ProofFail
            INC  DE
            INC  HL
            DJNZ ProofCompare

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

ProofEntrySp: .dw 0
ProofResult:  .db $FF
ProofContext: .dw $8003,$4000,$1000,$4024,$4000,$404D,$0010,0,0
ProofRequest:
            .db NCRQSIZE
            .db NCABI
            .db NCCODE,0,0,0
            .dw $000A,4,ProofContext,1,ProofBuffer,2,0,0
ProofBuffer:          .db 0,0,0,0,0
ProofExpectedInitial: .db 1,2,3,3,5
