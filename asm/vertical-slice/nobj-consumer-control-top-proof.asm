; Prove that a live control region may use $0000 as the exclusive $10000 end.

NobjConsumerCodeBase          .equ $1000
NobjConsumerCodeLimit         .equ $3000
NobjConsumerWorkspaceBase     .equ $3000
NobjConsumerStackBase         .equ $3F00
NobjConsumerStackLimit        .equ $4000
NobjConsumerObjectBase        .equ 0
NobjConsumerObjectLimit       .equ 0
NobjConsumerPlatformBase      .equ $6000
NobjConsumerPlatformCodeBase  .equ $6000
NobjConsumerPlatformCodeLimit .equ $6400
NobjConsumerControlBase       .equ $F000
NobjConsumerControlLimit      .equ 0

            .include "nobj-consumer-state.asmi"

            .org $0100
.routine noreturn
ProofStart:
            LD   SP,NobjConsumerStackLimit
            LD   IX,NobjRunDescriptor
            LD   (NobjStateDescriptorPointer),IX
            CALL NobjValidateRunDescriptor
            JR   C,ProofFailed
            CALL NobjValidateDeploymentProfile
            JR   C,ProofFailed
            LD   A,$A5
            JR   ProofFinished
ProofFailed:
            XOR  A
ProofFinished:
            LD   (ProofStatus),A
            HALT

            .org NobjConsumerCodeBase
NobjConsumerCodeStart:
            .include "nobj-consumer.asm"
NobjConsumerCodeEnd:

            .org NobjConsumerControlBase
NobjRunDescriptor:
            .db  10,0,1,0
            .dw  1,NobjDeploymentProfile,NobjResult
NobjDeploymentProfile:
            .db  18,1,0
            .dw  1
            .db  1,$EE
            .dw  $8000,$0100,$8080,$0020
            .db  0
            .dw  0
NobjResult:
            .db  0,0,0,0
ProofStatus:
            .db  0
