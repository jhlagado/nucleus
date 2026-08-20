; Executable reference binding for the standalone stored flat NOBJ consumer.

NobjConsumerCodeBase      .equ $1000
NobjConsumerCodeLimit     .equ $3000
NobjConsumerWorkspaceBase .equ $3000
NobjConsumerStackBase     .equ $3F00
NobjConsumerStackLimit    .equ $4000
NobjConsumerObjectBase    .equ $5000
NobjConsumerObjectLimit   .equ $5800
NobjConsumerPlatformBase  .equ $6000
NobjConsumerPlatformCodeBase  .equ $6000
NobjConsumerPlatformCodeLimit .equ $6100
NobjConsumerControlBase   .equ $4800
NobjConsumerControlLimit  .equ $4900

            .include "nobj-consumer-state.asmi"

            .org $0100
.routine noreturn
ProofStart:
            LD   SP,NobjConsumerStackLimit
            XOR  A
            LD   (ProofClosed),A
            LD   (ProofCloseCount),A
            LD   IX,NobjRunDescriptor
            CALL NobjConsumerRun
            LD   (ProofFailureStatus),A
            HALT

.routine noreturn
ProofSequentialOrdinalStart:
            LD   SP,NobjConsumerStackLimit
            LD   HL,NobjObject+10
            LD   (ProofObjectActiveEnd),HL
            LD   IX,NobjRunDescriptor
            CALL NobjConsumerRun
            XOR  A
            LD   (NobjDeploymentProfile),A
            LD   IX,NobjRunDescriptor
            CALL NobjConsumerRun
            HALT

.routine noreturn
ProofSequentialRecoveryStart:
            LD   SP,NobjConsumerStackLimit
            LD   HL,NobjObject+10
            LD   (ProofObjectActiveEnd),HL
            LD   IX,NobjRunDescriptor
            CALL NobjConsumerRun
            LD   HL,NobjObjectEnd
            LD   (ProofObjectActiveEnd),HL
            LD   IX,NobjRunDescriptor
            CALL NobjConsumerRun
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
            .db  18,1,0
            .dw  1
            .db  1,$EE
            .dw  $8000,$0100,$8080,$0020
            .db  0
            .dw  0
NobjResult:
            .db  0,0,0,0
ProofPublished:
            .db  0
ProofClosed:
            .db  0
ProofCloseCount:
            .db  0
ProofFailureStatus:
            .db  0
ProofObjectActiveEnd:
            .dw  NobjObjectEnd
ProofIdentityLow:
            .dw  $2468
ProofIdentityHigh:
            .dw  $1357
ProofLockCount:
            .db  0
ProofChangeIdentity:
            .db  0
ProofFailureOperation:
            .db  0

            .org NobjConsumerObjectBase
NobjObject:
            .db $01,$0f,$00,$4e,$4f,$42,$4a,$00,$01,$00,$01,$00,$01,$ee,$00,$80,$00,$01
            .db $02,$09,$00,$00,$00,$80,$3e,$00,$32,$81,$80,$76
            .db $02,$05,$00,$00,$80,$80,$00,$00
            .db $03,$04,$00,$00,$01,$80,$5a
            .db $04,$29,$00,$01,$00,$00,$00,$80,$80,$80,$20,$00,$80,$80,$01,$00,$80,$80
            .db $02,$00,$82,$80,$00,$00,$00,$00,$00,$80,$80,$02,$00,$01,$00,$01,$82,$00
            .db $00,$00,$00,$00,$00,$00,$00,$00
            .db $05,$07,$00,$06,$00,$00,$00,$80,$62,$9a
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
            LD   A,(ProofFailureOperation)
            CP   1
            JP   Z,ProofRequestedFailure
            LD   DE,1
            OR   A
            SBC  HL,DE
            JP   NZ,ProofPlatformInvalid
            LD   HL,NobjObject
            LD   (ProofObjectCursor),HL
            XOR  A
            LD   (ProofLockCount),A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry
ProofObjectReadByte:
            LD   A,(ProofFailureOperation)
            CP   2
            JP   Z,ProofRequestedFailure
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
            LD   A,(ProofFailureOperation)
            CP   3
            JP   Z,ProofRequestedFailure
            LD   HL,NobjObject
            LD   (ProofObjectCursor),HL
            XOR  A
            RET

.routine out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,BC
ProofObjectLock:
            LD   A,(ProofFailureOperation)
            CP   4
            JP   Z,ProofRequestedFailure
            LD   A,(ProofLockCount)
            INC  A
            LD   (ProofLockCount),A
            LD   DE,(ProofIdentityHigh)
            LD   HL,(ProofIdentityLow)
            LD   A,(ProofChangeIdentity)
            OR   A
            JP   Z,ProofObjectIdentityReady
            LD   B,A
            INC  B
            LD   A,(ProofLockCount)
            CP   B
            JP   NZ,ProofObjectIdentityReady
            INC  HL
ProofObjectIdentityReady:
            XOR  A
            RET

.routine in A,IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
ProofSelectTargetBank:
            LD   B,A
            LD   A,(ProofFailureOperation)
            CP   5
            JP   Z,ProofRequestedFailure
            LD   A,B
            OR   A
            JP   NZ,ProofPlatformInvalid
            LD   HL,NobjDeploymentProfile
            PUSH IX
            POP  DE
            OR   A
            SBC  HL,DE
            JP   NZ,ProofPlatformInvalid
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
            PUSH HL
            LD   BC,(NobjDeploymentProfile+7)
            OR   A
            SBC  HL,BC
            POP  HL
            JP   NZ,ProofPlatformInvalid
            LD   HL,NobjDeploymentProfile
            OR   A
            SBC  HL,DE
            JP   NZ,ProofPlatformInvalid
            LD   A,1
            LD   (ProofPublished),A
            XOR  A
            RET

.routine noreturn in A,HL,IX out A,carry,zero clobbers sign,parity,halfCarry,BC
ProofEnterTarget:
            LD   B,A
            LD   A,(ProofFailureOperation)
            CP   7
            JP   Z,ProofRequestedFailure
            LD   A,B
            OR   A
            JP   NZ,ProofPlatformInvalid
            LD   A,(ProofPublished)
            CP   1
            JP   NZ,ProofPlatformInvalid
            JP   (HL)

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
ProofObjectClose:
            LD   A,(ProofCloseCount)
            INC  A
            LD   (ProofCloseCount),A
            LD   A,1
            LD   (ProofClosed),A
            LD   A,(ProofFailureOperation)
            CP   8
            JP   Z,ProofRequestedFailure
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

ProofObjectCursor:
            .dw  0
