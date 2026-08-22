; Banked reference binding for the standalone stored NOBJ consumer.

NobjConsumerCodeBase      .equ $1000
NobjConsumerCodeLimit     .equ $3000
NobjConsumerWorkspaceBase .equ $3000
NobjConsumerStackBase     .equ $3F00
NobjConsumerStackLimit    .equ $4000
NobjConsumerObjectBase    .equ $5000
NobjConsumerObjectLimit   .equ $5800
NobjConsumerPlatformBase  .equ $6000
NobjConsumerPlatformCodeBase  .equ $6000
NobjConsumerPlatformCodeLimit .equ $6400
NobjConsumerControlBase   .equ $4800
NobjConsumerControlLimit  .equ $4900

            .include "nobj-consumer-state.asmi"

            .org $0100
.routine noreturn
ProofStart:
            LD   SP,NobjConsumerStackLimit
            XOR  A
            LD   (ProofPublished),A
            DEC  A
            LD   (ProofSelectedBank),A
            LD   IX,NobjRunDescriptor
            CALL NobjConsumerRun
            LD   (ProofFailureStatus),A
            HALT

            .org NobjConsumerCodeBase
NobjConsumerCodeStart:
            .include "nobj-consumer.asm"
NobjConsumerCodeEnd:

            .org $4800
NobjRunDescriptor:
            .db  10,0,1,0
            .dw  1,NobjDeploymentProfile,NobjResult
NobjDeploymentProfile:
            .db  18,1,1
            .dw  1
            .db  2,$EE
            .dw  $8000,$0100,$4000,$0100
            .db  0
            .dw  NobjBankBindings
NobjBankBindings:
            .db  0,0,0,0,0,0
            .db  1,0,0,1,0,0
NobjResult:
            .db  0,0,0,0
ProofPublished:
            .db  0
ProofFailureStatus:
            .db  0
ProofSelectedBank:
            .db  $FF
ProofNextBank:
            .db  0
ProofObjectCursor:
            .dw  0
ProofObjectActiveEnd:
            .dw  NobjObjectEnd
ProofFailureOperation:
            .db  0

            .org NobjConsumerObjectBase
NobjObject:
            .db $01,$0f,$00,$4e,$4f,$42,$4a,$00,$01,$01,$01,$00,$02,$ee,$00,$80,$00,$01
            .db $02,$09,$00,$00,$00,$80,$3e,$5a,$32,$01,$40,$76
            .db $02,$05,$00,$01,$10,$80,$aa,$bb
            .db $03,$04,$00,$01,$11,$80,$cc
            .db $04,$34,$00,$01,$01,$00,$00,$80,$00,$40,$00,$01,$00,$40,$01,$00,$00,$40
            .db $01,$00,$01,$40,$00,$00,$00,$00,$00,$00,$80,$01,$00,$02,$00,$01,$02,$06
            .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$12,$00,$00,$00,$00,$00,$00,$00,$00,$00
            .db $05,$07,$00,$06,$00,$00,$00,$80,$ea,$fa
NobjObjectEnd:

            .org NobjConsumerPlatformBase
            .db  "NC",0,1,8,8,0,0
            JP   ProofObjectOpen
            JP   ProofObjectReadByte
            JP   ProofObjectRewind
            JP   ProofObjectLock
            JP   ProofSelectTargetBank
            JP   ProofPublishTarget
            JP   ProofEnterTarget
            JP   ProofObjectClose

.routine in HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
ProofObjectOpen:
            LD   DE,1
            OR   A
            SBC  HL,DE
            JP   NZ,ProofPlatformInvalid
            LD   HL,NobjObject
            LD   (ProofObjectCursor),HL
            XOR  A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry
ProofObjectReadByte:
            PUSH HL
            PUSH DE
            LD   HL,(ProofObjectCursor)
            LD   DE,(ProofObjectActiveEnd)
            OR   A
            SBC  HL,DE
            JP   NZ,ProofObjectHasByte
            POP  DE
            POP  HL
            LD   A,NobjPlatformEnd
            SCF
            RET
ProofObjectHasByte:
            ADD  HL,DE
            LD   A,(HL)
            INC  HL
            LD   (ProofObjectCursor),HL
            POP  DE
            POP  HL
            OR   A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
ProofObjectRewind:
            LD   HL,NobjObject
            LD   (ProofObjectCursor),HL
            XOR  A
            RET

.routine out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,BC
ProofObjectLock:
            LD   DE,$1357
            LD   HL,$2468
            XOR  A
            RET

.routine in A,IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
ProofSelectTargetBank:
            CP   2
            JP   NC,ProofPlatformInvalid
            LD   (ProofNextBank),A
            LD   A,(ProofSelectedBank)
            CP   $FF
            JP   Z,ProofBankLoad
            OR   A
            LD   DE,ProofBank0
            JP   Z,ProofBankSaveReady
            LD   DE,ProofBank1
ProofBankSaveReady:
            LD   HL,(NobjDeploymentProfile+7)
            LD   BC,(NobjDeploymentProfile+9)
            LDIR
ProofBankLoad:
            LD   A,(ProofNextBank)
            OR   A
            LD   HL,ProofBank0
            JP   Z,ProofBankLoadReady
            LD   HL,ProofBank1
ProofBankLoadReady:
            LD   DE,(NobjDeploymentProfile+7)
            LD   BC,(NobjDeploymentProfile+9)
            LDIR
            LD   A,(ProofNextBank)
ProofBankSelected:
            LD   (ProofSelectedBank),A
            XOR  A
            RET

.routine in A,BC,DE,HL,IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX
ProofPublishTarget:
            LD   C,A
            LD   A,(ProofFailureOperation)
            CP   6
            JP   Z,ProofRequestedFailure
            LD   A,C
            OR   A
            JP   NZ,ProofPlatformInvalid
            LD   HL,NobjDeploymentProfile
            OR   A
            SBC  HL,DE
            JP   NZ,ProofPlatformInvalid
            LD   A,1
            LD   (ProofPublished),A
            XOR  A
            RET

.routine noreturn in A,HL,IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
ProofEnterTarget:
            PUSH HL
            CALL ProofSelectTargetBank
            JP   C,ProofPlatformInvalid
            POP  HL
            LD   A,(ProofPublished)
            CP   1
            JP   NZ,ProofPlatformInvalid
            JP   (HL)

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
ProofObjectClose:
            XOR  A
            RET

ProofRequestedFailure:
            LD   A,$42
            SCF
            RET

ProofPlatformInvalid:
            LD   A,4
            SCF
            RET

            .org $7000
ProofBank0:
            .ds  $0100
ProofBank1:
            .ds  $0100
