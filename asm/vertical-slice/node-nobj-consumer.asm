; Production Node reference image for the standalone NOBJ consumer.
;
; The consumer, its stack and its platform adapter remain outside the first
; TEC-1-style target profile: writable RAM $4000..$5000, service adapters near
; $7000 and the target image at $8000. Node implements the operations beneath
; a MON3-compatible RST 10h gateway. The Node image installs an emulator shim
; beneath that vector; native hardware already owns it in fixed monitor ROM.

NobjConsumerCodeBase          .equ $1000
NobjConsumerCodeLimit         .equ $3000
NobjConsumerWorkspaceBase     .equ $3000
NobjConsumerStackBase         .equ $5000
NobjConsumerStackLimit        .equ $5800
NobjConsumerObjectBase        .equ 0
NobjConsumerObjectLimit       .equ 0
NobjConsumerControlBase       .equ $5800
NobjConsumerControlLimit      .equ $5900
NobjConsumerPlatformBase      .equ $6000
NobjConsumerPlatformCodeBase  .equ $6000
NobjConsumerPlatformCodeLimit .equ $7200

NodeMon3GatewayPort          .equ $E0

NodeProgramServiceBase       .equ $7000

            .include "nobj-consumer-state.asmi"
            .include "platform-services-abi.asmi"

            .org $0010
NodeMon3Gateway:
            OUT  (NodeMon3GatewayPort),A
            RET

            .org $0100
NodeNobjReturnSentinel:
            HALT

            .org NobjConsumerCodeBase
NodeNobjConsumerCodeStart:
            .include "nobj-consumer.asm"
NodeNobjConsumerCodeEnd:

            .org NobjConsumerPlatformBase
NodeNobjPlatformCodeStart:
            .db  "NC",0,1,8,8,0,0
            JP   NodeNobjObjectOpen
            JP   NodeNobjObjectReadByte
            JP   NodeNobjObjectRewind
            JP   NodeNobjObjectLock
            JP   NodeNobjSelectTargetBank
            JP   NodeNobjPublishTarget
            JP   NodeNobjEnterTarget
            JP   NodeNobjObjectClose

.routine in HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
NodeNobjObjectOpen:
            LD   C,NucleusServiceLoaderOpen
            RST  $10
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry
NodeNobjObjectReadByte:
            PUSH BC
            LD   C,NucleusServiceLoaderReadByte
            RST  $10
            POP  BC
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
NodeNobjObjectRewind:
            LD   C,NucleusServiceLoaderRewind
            RST  $10
            RET

.routine out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,BC
NodeNobjObjectLock:
            LD   C,NucleusServiceLoaderLock
            RST  $10
            RET

.routine in A,IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
NodeNobjSelectTargetBank:
            LD   C,NucleusMonBankSelect
            RST  $10
            RET

.routine in A,BC,DE,HL,IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX
NodeNobjPublishTarget:
            LD   (NodeNobjInputBC),BC
            LD   C,NucleusServiceLoaderPublish
            RST  $10
            RET

.routine in A,HL,IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX
NodeNobjEnterTarget:
            PUSH HL
            LD   C,NucleusServiceLoaderEnter
            RST  $10
            POP  HL
            RET  C
            JP   (HL)

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
NodeNobjObjectClose:
            LD   C,NucleusServiceLoaderClose
            RST  $10
            RET
NodeNobjInputBC:
            .dw  0
NodeNobjPlatformCodeEnd:

            .org NodeProgramServiceBase
NodeProgramServiceVector:
            JP   NodeProgramReadInput
            JP   NodeProgramWriteOutput
            JP   NodeProgramReadStorage
            JP   NodeProgramRewindStorage
            JP   NodeProgramWriteStorage
            JP   NodeProgramSeekStorage
            JP   NodeProgramSuccess
            JP   NodeProgramFailure
            JP   NodeProgramTrap
            JP   NodeProgramFarCall
            JP   NodeProgramFarJump
            JP   NodeProgramPacket

NodeProgramReadInput:
            PUSH BC
            LD   C,NucleusServiceReadInput
            RST  $10
            POP  BC
            RET
NodeProgramWriteOutput:
            PUSH BC
            LD   C,NucleusServiceWriteOutput
            RST  $10
            POP  BC
            RET
NodeProgramReadStorage:
            PUSH BC
            LD   C,NucleusServiceReadStorage
            RST  $10
            POP  BC
            RET
NodeProgramRewindStorage:
            PUSH BC
            LD   C,NucleusServiceRewindStorage
            RST  $10
            POP  BC
            RET
NodeProgramWriteStorage:
            PUSH BC
            LD   C,NucleusServiceWriteStorage
            RST  $10
            POP  BC
            RET
NodeProgramSeekStorage:
            PUSH BC
            LD   C,NucleusServiceSeekStorage
            RST  $10
            POP  BC
            RET
NodeProgramSuccess:
            LD   C,NucleusServiceExitSuccess
            RST  $10
            HALT
NodeProgramFailure:
            LD   C,NucleusServiceExitFailure
            RST  $10
            HALT
NodeProgramTrap:
            LD   C,NucleusServiceExitTrap
            RST  $10
            HALT
NodeProgramFarCall:
            LD   (NodeProgramTargetBank),A
            LD   (NodeProgramTargetAddress),HL
            LD   HL,(NodeProgramRuntimeStateBase)
            LD   DE,6
            ADD  HL,DE
            LD   A,(HL)
            DEC  A
            CP   8
            JP   NC,NodeProgramTrap
            LD   (NodeProgramFarSlot),A
            LD   E,A
            LD   D,0
            LD   HL,(NodeProgramRuntimeStateBase)
            ADD  HL,DE
            LD   DE,9
            ADD  HL,DE
            PUSH HL
            LD   HL,(NodeProgramRuntimeStateBase)
            LD   DE,8
            ADD  HL,DE
            LD   A,(HL)
            POP  HL
            LD   (HL),A
            POP  DE
            LD   A,(NodeProgramFarSlot)
            ADD  A,A
            LD   C,A
            LD   B,0
            LD   HL,(NodeProgramRuntimeStateBase)
            ADD  HL,BC
            LD   BC,21
            ADD  HL,BC
            LD   (HL),E
            INC  HL
            LD   (HL),D
            LD   HL,NodeProgramFarReturn
            PUSH HL
            LD   A,(NodeProgramTargetBank)
            CALL NodeProgramSelectBank
            JP   C,NodeProgramTrap
            LD   HL,(NodeProgramTargetAddress)
            JP   (HL)
NodeProgramFarJump:
            CALL NodeProgramSelectBank
            JP   C,NodeProgramTrap
            JP   (HL)
NodeProgramPacket:
            LD   (NodeProgramInputBC),BC
            LD   C,NucleusServicePacket
            RST  $10
            RET
NodeProgramFarReturn:
            PUSH HL
            PUSH AF
            LD   HL,(NodeProgramRuntimeStateBase)
            LD   DE,6
            ADD  HL,DE
            LD   A,(HL)
            DEC  A
            CP   8
            JP   NC,NodeProgramTrap
            LD   (NodeProgramFarSlot),A
            LD   E,A
            LD   D,0
            LD   HL,(NodeProgramRuntimeStateBase)
            ADD  HL,DE
            LD   DE,9
            ADD  HL,DE
            LD   A,(HL)
            CALL NodeProgramSelectBank
            JP   C,NodeProgramTrap
            LD   A,(NodeProgramFarSlot)
            ADD  A,A
            LD   C,A
            LD   B,0
            LD   HL,(NodeProgramRuntimeStateBase)
            ADD  HL,BC
            LD   BC,21
            ADD  HL,BC
            LD   C,(HL)
            INC  HL
            LD   B,(HL)
            POP  AF
            POP  HL
            PUSH BC
            RET
.routine in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E
NodeProgramSelectBank:
            LD   (NodeProgramTargetBank),A
            LD   C,NucleusMonBankSelect
            RST  $10
            RET  C
            PUSH HL
            LD   HL,(NodeProgramRuntimeStateBase)
            LD   DE,8
            ADD  HL,DE
            LD   A,(NodeProgramTargetBank)
            LD   (HL),A
            POP  HL
            OR   A
            RET
NodeProgramRuntimeStateBase:
            .dw  0
NodeProgramInputBC:
            .dw  0
NodeProgramTargetAddress:
            .dw  0
NodeProgramTargetBank:
            .db  0
NodeProgramFarSlot:
            .db  0
NodeProgramServiceCodeEnd:
