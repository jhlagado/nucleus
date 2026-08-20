; Standalone NOBJ 0.1 stored-object consumer.
;
; This module owns no filesystem or target device policy. It calls the fixed
; NC platform vector from native-z80-host-contract.md and keeps all tentative
; target writes unpublished until two complete reads of one locked generation
; have succeeded.

.routine in IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX
NobjConsumerRun:
            PUSH IY
            CALL NobjConsumerRunBody
            POP  IY
            RET

.routine in IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
NobjConsumerRunBody:
            LD   (NobjStateDescriptorPointer),IX
            XOR  A
            LD   (NobjStateObjectOpen),A
            LD   (NobjStateFailureOutcome),A
            LD   (NobjStateFailureStatus),A
            LD   (NobjStateRecordOrdinal),A
            LD   (NobjStateRecordOrdinal+1),A
            CALL NobjValidateRunDescriptor
            JP   C,NobjConsumerReturnFailure
            CALL NobjValidatePlatformVector
            JP   C,NobjConsumerReturnFailure
            CALL NobjValidateDeploymentProfile
            JP   C,NobjConsumerReturnFailure

            LD   IX,(NobjStateDescriptorPointer)
            LD   L,(IX+4)
            LD   H,(IX+5)
            CALL NobjPlatformObjectOpen
            JP   C,NobjConsumerPlatformFailure
            LD   A,1
            LD   (NobjStateObjectOpen),A
            CALL NobjPlatformObjectLock
            JP   C,NobjConsumerPlatformFailure
            LD   (NobjStateIdentityLow),HL
            LD   (NobjStateIdentityHigh),DE

            XOR  A
            LD   (NobjStateMaterialize),A
            CALL NobjValidatePass
            JR   C,NobjConsumerOpenedFailure
            CALL NobjValidatePatchOverlaps
            JR   C,NobjConsumerOpenedFailure

            CALL NobjPlatformObjectRewind
            JR   C,NobjConsumerPlatformFailure
            CALL NobjVerifyGenerationIdentity
            JR   C,NobjConsumerOpenedFailure

            CALL NobjFillTarget
            JR   C,NobjConsumerOpenedFailure
            LD   A,1
            LD   (NobjStateMaterialize),A
            CALL NobjValidatePass
            JR   C,NobjConsumerOpenedFailure
            CALL NobjVerifyGenerationIdentity
            JR   C,NobjConsumerOpenedFailure

            CALL NobjPlatformObjectClose
            JR   C,NobjConsumerPlatformFailureAfterClose
            XOR  A
            LD   (NobjStateObjectOpen),A

            LD   A,(NobjStateEntryBank)
            LD   HL,(NobjStateImageBase)
            LD   IX,NobjStateMapBuffer
            LD   BC,(NobjStateMapLength)
            LD   DE,(NobjStateProfilePointer)
            CALL NobjPlatformPublishTarget
            JR   C,NobjConsumerPlatformFailureAfterClose

            LD   A,(NobjStateEntryBank)
            LD   HL,(NobjStateImageBase)
            LD   IX,(NobjStateProfilePointer)
            CALL NobjPlatformEnterTarget
            ; A successful entry never returns.
            JR   NobjConsumerPlatformFailureAfterClose

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
NobjVerifyGenerationIdentity:
            CALL NobjPlatformObjectLock
            JR   C,NobjVerifyGenerationPlatformFailure
            LD   BC,(NobjStateIdentityLow)
            OR   A
            SBC  HL,BC
            JR   NZ,NobjVerifyGenerationChanged
            LD   BC,(NobjStateIdentityHigh)
            EX   DE,HL
            OR   A
            SBC  HL,BC
            JR   NZ,NobjVerifyGenerationChanged
            OR   A
            RET
NobjVerifyGenerationChanged:
            LD   A,NobjStatusGenerationChanged
            JP   NobjSetValidatorFailure
NobjVerifyGenerationPlatformFailure:
            JP   NobjSetPlatformFailure

NobjConsumerPlatformFailure:
            CALL NobjSetPlatformFailure
NobjConsumerOpenedFailure:
            LD   A,(NobjStateObjectOpen)
            OR   A
            JR   Z,NobjConsumerReturnFailure
            CALL NobjPlatformObjectClose
            XOR  A
            LD   (NobjStateObjectOpen),A
            JR   NobjConsumerReturnFailure

NobjConsumerPlatformFailureAfterClose:
            CALL NobjSetPlatformFailure

.routine out A,carry clobbers zero,sign,parity,halfCarry,BC,DE,HL,IX
NobjConsumerReturnFailure:
            LD   HL,(NobjStateResultPointer)
            LD   A,H
            OR   L
            JR   Z,NobjConsumerReturnBareFailure
            LD   A,(NobjStateFailureOutcome)
            LD   (HL),A
            INC  HL
            LD   A,(NobjStateFailureStatus)
            LD   (HL),A
            INC  HL
            LD   DE,(NobjStateRecordOrdinal)
            LD   (HL),E
            INC  HL
            LD   (HL),D
NobjConsumerReturnBareFailure:
            LD   A,(NobjStateFailureStatus)
            SCF
            RET

.routine in A out A,carry clobbers zero,sign,parity,halfCarry
NobjSetValidatorFailure:
            LD   (NobjStateFailureStatus),A
            LD   A,NobjOutcomeInvalid
            LD   (NobjStateFailureOutcome),A
            SCF
            RET

.routine in A out A,carry clobbers zero,sign,parity,halfCarry
NobjSetPlatformFailure:
            LD   (NobjStateFailureStatus),A
            LD   A,NobjOutcomePlatform
            LD   (NobjStateFailureOutcome),A
            SCF
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
NobjValidateRunDescriptor:
            LD   IX,(NobjStateDescriptorPointer)
            PUSH IX
            POP  HL
            LD   DE,10
            CALL NobjControlContainsExtent
            JR   C,NobjDescriptorInvalidBare
            LD   IX,(NobjStateDescriptorPointer)
            LD   A,(IX+0)
            CP   10
            JR   NZ,NobjDescriptorInvalidBare
            LD   A,(IX+1)
            OR   A
            JR   NZ,NobjDescriptorInvalidBare
            LD   A,(IX+2)
            CP   1
            JR   NZ,NobjDescriptorInvalidBare
            LD   A,(IX+3)
            OR   A
            JR   NZ,NobjDescriptorInvalidBare
            LD   L,(IX+8)
            LD   H,(IX+9)
            LD   A,H
            OR   L
            JR   Z,NobjDescriptorInvalidBare
            PUSH HL
            LD   DE,4
            CALL NobjControlContainsExtent
            POP  HL
            JR   C,NobjDescriptorInvalidBare
            LD   (NobjStateResultPointer),HL
            LD   IX,(NobjStateDescriptorPointer)
            LD   L,(IX+6)
            LD   H,(IX+7)
            LD   A,H
            OR   L
            JR   Z,NobjDescriptorInvalid
            PUSH HL
            LD   DE,18
            CALL NobjControlContainsExtent
            POP  HL
            JR   C,NobjDescriptorInvalid
            LD   (NobjStateProfilePointer),HL
            OR   A
            RET
NobjDescriptorInvalidBare:
            XOR  A
            LD   (NobjStateResultPointer),A
            LD   (NobjStateResultPointer+1),A
NobjDescriptorInvalid:
            LD   A,NobjStatusDescriptor
            JP   NobjSetValidatorFailure

; HL=start, DE=length. Carry means the complete extent is not inside the
; caller-owned control region that remains live until target entry.
.routine in DE,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
NobjControlContainsExtent:
            LD   BC,NobjConsumerControlBase
            OR   A
            SBC  HL,BC
            JR   C,NobjControlExtentInvalid
            ADD  HL,BC
            ADD  HL,DE
            JR   NC,NobjControlExtentEndReady
            LD   A,H
            OR   L
            JR   NZ,NobjControlExtentInvalid
            LD   BC,NobjConsumerControlLimit
            LD   A,B
            OR   C
            JR   Z,NobjControlExtentValid
            JR   NobjControlExtentInvalid
NobjControlExtentEndReady:
            LD   BC,NobjConsumerControlLimit
            LD   A,B
            OR   C
            JR   Z,NobjControlExtentValid
            OR   A
            SBC  HL,BC
            JR   C,NobjControlExtentValid
            RET  Z
NobjControlExtentInvalid:
            SCF
            RET
NobjControlExtentValid:
            OR   A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
NobjValidatePlatformVector:
            LD   HL,NobjConsumerPlatformBase
            LD   DE,NobjConsumerVectorSignature
            LD   B,8
NobjValidatePlatformVectorLoop:
            LD   A,(DE)
            CP   (HL)
            JR   NZ,NobjPlatformVectorInvalid
            INC  DE
            INC  HL
            DJNZ NobjValidatePlatformVectorLoop
            RET
NobjPlatformVectorInvalid:
            LD   A,NobjStatusConsumerVector
            JP   NobjSetValidatorFailure

NobjConsumerVectorSignature:
            .db  "NC",0,1,8,8,0,0

; Validate the exact revision-one deployment record, derive loaded/ROM mode,
; and reject a target window that can overwrite the resident consumer.
.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
NobjValidateDeploymentProfile:
            LD   IX,(NobjStateProfilePointer)
            LD   A,(IX+0)
            CP   18
            JP   NZ,NobjDeploymentInvalid
            LD   A,(IX+1)
            CP   1
            JP   NZ,NobjDeploymentInvalid
            LD   A,(IX+2)
            AND  $FC
            JP   NZ,NobjDeploymentInvalid
            LD   A,(IX+2)
            LD   (NobjStateProfileFlags),A
            LD   L,(IX+3)
            LD   H,(IX+4)
            LD   (NobjStateRuntimeIdentity),HL
            LD   A,(IX+5)
            LD   (NobjStateBankCount),A
            LD   B,A
            LD   A,(IX+6)
            LD   (NobjStateImageFill),A
            LD   L,(IX+7)
            LD   H,(IX+8)
            LD   (NobjStateImageBase),HL
            LD   E,(IX+9)
            LD   D,(IX+10)
            LD   (NobjStateImageCapacity),DE
            LD   A,D
            OR   E
            JP   Z,NobjDeploymentInvalid
            CALL NobjExtentEndValid
            JP   C,NobjDeploymentInvalid
            LD   L,(IX+11)
            LD   H,(IX+12)
            LD   (NobjStateWritableBase),HL
            LD   E,(IX+13)
            LD   D,(IX+14)
            LD   (NobjStateWritableCapacity),DE
            LD   A,D
            OR   E
            JP   Z,NobjDeploymentInvalid
            CALL NobjExtentEndValid
            JP   C,NobjDeploymentInvalid
            LD   A,(IX+15)
            LD   (NobjStateEntryBank),A

            LD   A,(NobjStateProfileFlags)
            BIT  0,A
            JR   NZ,NobjValidateBankedProfile
            LD   A,(NobjStateBankCount)
            LD   B,A
            LD   A,B
            CP   1
            JP   NZ,NobjDeploymentInvalid
            LD   A,(NobjStateEntryBank)
            OR   A
            JP   NZ,NobjDeploymentInvalid
            LD   A,(IX+16)
            OR   (IX+17)
            JP   NZ,NobjDeploymentInvalid
            CALL NobjDeriveFlatMode
            JP   C,NobjDeploymentInvalid
            JR   NobjValidateProfileProtection

NobjValidateBankedProfile:
            LD   A,(NobjStateBankCount)
            LD   B,A
            LD   A,B
            CP   2
            JP   C,NobjDeploymentInvalid
            CP   5
            JP   NC,NobjDeploymentInvalid
            LD   A,(NobjStateEntryBank)
            CP   B
            JP   NC,NobjDeploymentInvalid
            LD   A,(IX+16)
            OR   (IX+17)
            JP   Z,NobjDeploymentInvalid
            CALL NobjRequireWritableOutsideImage
            JP   C,NobjDeploymentInvalid
            LD   A,1
            LD   (NobjStateRomMode),A
            CALL NobjValidateBankBindings
            JP   C,NobjDeploymentInvalid

NobjValidateProfileProtection:
            CALL NobjImageAvoidsProtectedMemory
            RET  NC
NobjProtectedMemoryInvalid:
            LD   A,NobjStatusProtectedMemory
            JP   NobjSetValidatorFailure
NobjDeploymentInvalid:
            LD   A,NobjStatusDeploymentProfile
            JP   NobjSetValidatorFailure

; HL=base, DE=capacity. Carry means the mathematical end exceeds $10000.
.routine in DE,HL out A,HL,carry,zero clobbers sign,parity,halfCarry,BC
NobjExtentEndValid:
            LD   B,H
            LD   C,L
            ADD  HL,DE
            RET  NC
            LD   A,H
            OR   L
            RET  Z
            SCF
            RET

; Derive the flat mode without a profile mode bit. Carry means partial overlap.
.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
NobjDeriveFlatMode:
            LD   HL,(NobjStateWritableBase)
            LD   DE,(NobjStateImageBase)
            OR   A
            SBC  HL,DE                  ; writable offset from image base
            JR   C,NobjWritableStartsBelowImage
            LD   DE,(NobjStateImageCapacity)
            PUSH HL
            OR   A
            SBC  HL,DE
            POP  HL
            JR   NC,NobjWritableWhollyAboveImage
            EX   DE,HL                  ; DE=offset, HL=image capacity
            OR   A
            SBC  HL,DE                  ; remaining image capacity
            LD   DE,(NobjStateWritableCapacity)
            OR   A
            SBC  HL,DE
            JR   C,NobjModePartialOverlap
            XOR  A                      ; loaded mode
            LD   (NobjStateRomMode),A
            RET
NobjWritableStartsBelowImage:
            LD   HL,(NobjStateImageBase)
            LD   DE,(NobjStateWritableBase)
            OR   A
            SBC  HL,DE                  ; distance to image base
            LD   DE,(NobjStateWritableCapacity)
            OR   A
            SBC  HL,DE
            JR   C,NobjModePartialOverlap
NobjWritableWhollyAboveImage:
            LD   A,1                    ; disjoint ROM mode
            LD   (NobjStateRomMode),A
            OR   A
            RET
NobjModePartialOverlap:
            SCF
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
NobjRequireWritableOutsideImage:
            CALL NobjDeriveFlatMode
            RET  C
            LD   A,(NobjStateRomMode)
            OR   A
            RET  NZ
            SCF
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
NobjValidateBankBindings:
            LD   IX,(NobjStateProfilePointer)
            LD   L,(IX+16)
            LD   H,(IX+17)
            LD   A,(NobjStateBankCount)
            ADD  A,A                     ; 2n
            LD   E,A
            ADD  A,A                     ; 4n
            ADD  A,E                     ; 6n
            LD   E,A
            LD   D,0
            CALL NobjControlContainsExtent
            RET  C
            LD   IX,(NobjStateProfilePointer)
            LD   L,(IX+16)
            LD   H,(IX+17)
            LD   A,(NobjStateBankCount)
            LD   B,A
NobjValidateBankBindingLoop:
            INC  HL                      ; selector is opaque
            LD   A,(HL)                  ; reserved byte
            OR   A
            JR   NZ,NobjBankBindingInvalid
            LD   DE,5
            ADD  HL,DE
            DJNZ NobjValidateBankBindingLoop
            OR   A
            RET
NobjBankBindingInvalid:
            SCF
            RET

; Carry means either target-write region overlaps a resident protected extent.
; The image check is independent of which physical bank is selected.
.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
NobjImageAvoidsProtectedMemory:
            LD   BC,NobjConsumerCodeBase
            LD   DE,NobjConsumerCodeLimit
            CALL NobjTargetRegionsIntersectFixed
            RET  C
            LD   BC,NobjConsumerWorkspaceBase
            LD   DE,NobjConsumerWorkspaceEnd
            CALL NobjTargetRegionsIntersectFixed
            RET  C
            LD   BC,NobjConsumerStackBase
            LD   DE,NobjConsumerStackLimit
            CALL NobjTargetRegionsIntersectFixed
            RET  C
            LD   BC,NobjConsumerPlatformCodeBase
            LD   DE,NobjConsumerPlatformCodeLimit
            CALL NobjTargetRegionsIntersectFixed
            RET  C
            LD   BC,NobjConsumerControlBase
            LD   DE,NobjConsumerControlLimit
            CALL NobjTargetRegionsIntersectFixed
            RET  C
            LD   BC,NobjConsumerObjectBase
            LD   DE,NobjConsumerObjectLimit
            LD   A,B
            OR   C
            OR   D
            OR   E
            RET  Z
            JP   NobjTargetRegionsIntersectFixed

; BC=fixed start, DE=fixed limit. Carry means image or writable intersects it.
.routine in BC,DE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
NobjTargetRegionsIntersectFixed:
            PUSH BC
            PUSH DE
            LD   HL,(NobjStateImageBase)
            LD   IX,(NobjStateImageCapacity)
            CALL NobjRegionIntersectsFixed
            POP  DE
            POP  BC
            RET  C
            LD   HL,(NobjStateWritableBase)
            LD   IX,(NobjStateWritableCapacity)
            JP   NobjRegionIntersectsFixed

; HL=target base, IX=capacity, BC=fixed start, DE=fixed exclusive limit.
; Both inputs are valid half-open extents; a zero fixed limit means $10000.
.routine in BC,DE,HL,IX out A,carry,zero clobbers sign,parity,halfCarry,DE,HL,IX,IY
NobjRegionIntersectsFixed:
            LD   A,D
            OR   E
            JR   Z,NobjRegionStartsBeforeFixedEnd
            PUSH HL
            OR   A
            SBC  HL,DE
            POP  HL
            JR   NC,NobjRegionDisjoint
NobjRegionStartsBeforeFixedEnd:
            PUSH IX
            POP  DE
            ADD  HL,DE
            JR   C,NobjRegionIntersects
            OR   A
            SBC  HL,BC
            JR   C,NobjRegionDisjoint
            RET  Z
NobjRegionIntersects:
            SCF
            RET
NobjRegionDisjoint:
            OR   A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX
NobjValidatePass:
            XOR  A
            LD   (NobjStatePhase),A
            LD   (NobjStateImageSeen),A
            LD   (NobjStatePatchCount),A
            LD   (NobjStatePatchCount+1),A
            LD   (NobjStateRecordOrdinal),A
            LD   (NobjStateRecordOrdinal+1),A
            LD   HL,$FFFF
            LD   (NobjStateCrc),HL
            LD   DE,NobjStateImageEnds
            LD   B,16
NobjResetEndsLoop:
            XOR  A
            LD   (DE),A
            INC  DE
            DJNZ NobjResetEndsLoop

NobjValidateRecordLoop:
            CALL NobjReadRecordHeader
            RET  C
            LD   A,(NobjStateRecordKind)
            CP   NobjKindBegin
            JP   Z,NobjAcceptBegin
            CP   NobjKindImage
            JP   Z,NobjAcceptImage
            CP   NobjKindPatch
            JP   Z,NobjAcceptPatch
            CP   NobjKindMap
            JP   Z,NobjAcceptMap
            CP   NobjKindCommit
            JP   Z,NobjAcceptCommit
            LD   A,NobjStatusFraming
            JP   NobjSetValidatorFailure

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
NobjReadRecordHeader:
            LD   HL,(NobjStateRecordOrdinal)
            INC  HL
            LD   A,H
            OR   L
            JR   Z,NobjRecordCountInvalid
            LD   (NobjStateRecordOrdinal),HL
            CALL NobjReadCrcByte
            RET  C
            LD   (NobjStateRecordKind),A
            CALL NobjReadCrcWord
            RET  C
            LD   (NobjStatePayloadLength),HL
            RET
NobjRecordCountInvalid:
            LD   A,NobjStatusRecordOrder
            JP   NobjSetValidatorFailure

; Carry clear returns one required byte. Carry set records either a truncated
; validator result or the exact platform status.
.routine out A,carry,zero,sign,parity,halfCarry clobbers BC,DE,HL,IX,IY
NobjRequireByte:
            CALL NobjPlatformObjectReadByte
            RET  NC
            CP   NobjPlatformEnd
            JR   NZ,NobjRequirePlatformFailure
            LD   A,NobjStatusTruncated
            JP   NobjSetValidatorFailure
NobjRequirePlatformFailure:
            JP   NobjSetPlatformFailure

.routine out A,carry,zero,sign,parity,halfCarry clobbers BC,DE,HL,IX,IY
NobjReadCrcByte:
            CALL NobjRequireByte
            RET  C
            PUSH AF
            CALL NobjCrcByte
            POP  AF
            OR   A
            RET

; CRC-16/CCITT-FALSE, polynomial $1021, no reflection.
.routine in A out carry,zero clobbers sign,parity,halfCarry,A,B,HL
NobjCrcByte:
            LD   HL,(NobjStateCrc)
            XOR  H
            LD   H,A
            LD   B,8
NobjCrcByteBit:
            ADD  HL,HL
            JR   NC,NobjCrcByteNext
            LD   A,H
            XOR  $10
            LD   H,A
            LD   A,L
            XOR  $21
            LD   L,A
NobjCrcByteNext:
            DJNZ NobjCrcByteBit
            LD   (NobjStateCrc),HL
            OR   A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
NobjAcceptBegin:
            LD   A,(NobjStatePhase)
            OR   A
            JP   NZ,NobjRecordOrderInvalid
            LD   HL,(NobjStateRecordOrdinal)
            DEC  HL
            LD   A,H
            OR   L
            JP   NZ,NobjRecordOrderInvalid
            LD   HL,(NobjStatePayloadLength)
            LD   DE,15
            OR   A
            SBC  HL,DE
            JP   NZ,NobjFramingInvalid
            LD   DE,NobjBeginSignature
            LD   B,6
NobjAcceptBeginSignature:
            PUSH BC
            CALL NobjReadCrcByte
            POP  BC
            RET  C
            EX   DE,HL
            CP   (HL)
            EX   DE,HL
            JR   NZ,NobjFramingInvalid
            INC  DE
            DJNZ NobjAcceptBeginSignature
            CALL NobjReadCrcByte          ; BEGIN flags
            RET  C
            LD   (NobjStateBeginFlags),A
            AND  $FE
            JR   NZ,NobjFramingInvalid
            CALL NobjReadCrcWord
            RET  C
            LD   DE,(NobjStateRuntimeIdentity)
            OR   A
            SBC  HL,DE
            JR   NZ,NobjDeploymentMismatch
            CALL NobjReadCrcByte          ; bank count
            RET  C
            LD   B,A
            LD   A,(NobjStateBankCount)
            CP   B
            JR   NZ,NobjDeploymentMismatch
            CALL NobjReadCrcByte          ; fill
            RET  C
            LD   B,A
            LD   A,(NobjStateImageFill)
            CP   B
            JR   NZ,NobjDeploymentMismatch
            CALL NobjReadCrcWord
            RET  C
            LD   DE,(NobjStateImageBase)
            OR   A
            SBC  HL,DE
            JR   NZ,NobjDeploymentMismatch
            CALL NobjReadCrcWord
            RET  C
            LD   DE,(NobjStateImageCapacity)
            OR   A
            SBC  HL,DE
            JR   NZ,NobjDeploymentMismatch
            LD   A,(NobjStateBeginFlags)
            AND  1
            LD   B,A
            LD   A,(NobjStateProfileFlags)
            AND  1
            CP   B
            JR   NZ,NobjDeploymentMismatch
            LD   A,NobjPhaseImage
            LD   (NobjStatePhase),A
            JP   NobjValidateRecordLoop

NobjBeginSignature:
            .db  "NOBJ",0,1

.routine out A,HL,carry,zero,sign,parity,halfCarry clobbers BC,DE,IX,IY
NobjReadCrcWord:
            CALL NobjReadCrcByte
            RET  C
            PUSH AF
            CALL NobjReadCrcByte
            JR   C,NobjReadCrcWordFailure
            LD   H,A
            POP  AF
            LD   L,A
            RET
NobjReadCrcWordFailure:
            POP  HL
            SCF
            RET

NobjDeploymentMismatch:
            LD   A,NobjStatusDeploymentProfile
            JP   NobjSetValidatorFailure
NobjFramingInvalid:
            LD   A,NobjStatusFraming
            JP   NobjSetValidatorFailure
NobjRecordOrderInvalid:
            LD   A,NobjStatusRecordOrder
            JP   NobjSetValidatorFailure

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
NobjAcceptImage:
            LD   A,(NobjStatePhase)
            CP   NobjPhaseImage
            JR   NZ,NobjRecordOrderInvalid
            CALL NobjReadImageLikeHeader
            RET  C
            LD   A,(NobjStateCurrentBank)
            LD   HL,NobjStateImageEnds
            CALL NobjBankWordPointer
            LD   E,(HL)
            INC  HL
            LD   D,(HL)                  ; previous end offset
            LD   HL,(NobjStateCurrentAddress)
            LD   BC,(NobjStateImageBase)
            OR   A
            SBC  HL,BC                   ; current start offset
            OR   A
            SBC  HL,DE
            JR   C,NobjImageOrderInvalid
            LD   A,(NobjStateCurrentBank)
            LD   HL,NobjStateImageEnds
            CALL NobjBankWordPointer
            LD   DE,(NobjStateCurrentEnd)
            LD   (HL),E
            INC  HL
            LD   (HL),D
            LD   A,1
            LD   (NobjStateImageSeen),A
            CALL NobjConsumeImageLikeBytes
            RET  C
            JP   NobjValidateRecordLoop
NobjImageOrderInvalid:
            LD   A,NobjStatusImageOrder
            JP   NobjSetValidatorFailure

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX
NobjAcceptPatch:
            LD   A,(NobjStatePhase)
            CP   NobjPhaseImage
            JR   Z,NobjPatchPhaseReady
            CP   NobjPhasePatch
            JR   NZ,NobjRecordOrderInvalid
NobjPatchPhaseReady:
            LD   A,(NobjStateImageSeen)
            OR   A
            JR   Z,NobjRecordOrderInvalid
            LD   A,NobjPhasePatch
            LD   (NobjStatePhase),A
            CALL NobjReadImageLikeHeader
            RET  C
            LD   A,(NobjStateCurrentBank)
            LD   HL,NobjStatePatchEnds
            CALL NobjBankWordPointer
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            LD   BC,(NobjStateCurrentEnd)
            EX   DE,HL
            OR   A
            SBC  HL,BC
            JR   NC,NobjPatchEndRetained
            LD   A,(NobjStateCurrentBank)
            LD   HL,NobjStatePatchEnds
            CALL NobjBankWordPointer
            LD   DE,(NobjStateCurrentEnd)
            LD   (HL),E
            INC  HL
            LD   (HL),D
NobjPatchEndRetained:
            LD   HL,(NobjStatePatchCount)
            INC  HL
            LD   A,H
            OR   L
            JP   Z,NobjRecordCountInvalid
            LD   (NobjStatePatchCount),HL
            CALL NobjConsumeImageLikeBytes
            RET  C
            JP   NobjValidateRecordLoop

; Read bank/address, validate the nonempty extent, and retain the modular end
; as an offset from imageBase. The replacement/data bytes remain unread.
.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
NobjReadImageLikeHeader:
            LD   HL,(NobjStatePayloadLength)
            LD   DE,4
            OR   A
            SBC  HL,DE
            JP   C,NobjFramingInvalid
            CALL NobjReadCrcByte
            RET  C
            LD   (NobjStateCurrentBank),A
            LD   B,A
            LD   A,(NobjStateBankCount)
            DEC  A
            CP   B
            JR   C,NobjTargetExtentInvalid
            CALL NobjReadCrcWord
            RET  C
            LD   (NobjStateCurrentAddress),HL
            LD   DE,(NobjStateImageBase)
            OR   A
            SBC  HL,DE
            JR   C,NobjTargetExtentInvalid
            LD   BC,(NobjStatePayloadLength)
            DEC  BC
            DEC  BC
            DEC  BC                       ; byte count, known nonzero
            ADD  HL,BC                    ; end offset
            JR   C,NobjTargetExtentInvalid
            LD   DE,(NobjStateImageCapacity)
            PUSH HL
            OR   A
            SBC  HL,DE
            POP  HL
            JR   C,NobjImageLikeExtentReady
            JR   NZ,NobjTargetExtentInvalid
NobjImageLikeExtentReady:
            LD   (NobjStateCurrentEnd),HL
            OR   A
            RET
NobjTargetExtentInvalid:
            LD   A,NobjStatusTargetExtent
            JP   NobjSetValidatorFailure

.routine in A,HL out A,HL,carry,zero clobbers sign,parity,halfCarry,DE
NobjBankWordPointer:
            ADD  A,A
            LD   E,A
            LD   D,0
            ADD  HL,DE
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX
NobjConsumeImageLikeBytes:
            LD   A,(NobjStateMaterialize)
            OR   A
            JR   Z,NobjConsumeImageLikeReady
            LD   A,(NobjStateCurrentBank)
            LD   IX,(NobjStateProfilePointer)
            CALL NobjPlatformSelectTargetBank
            JR   C,NobjConsumeImagePlatformFailure
NobjConsumeImageLikeReady:
            LD   HL,(NobjStateCurrentAddress)
            LD   BC,(NobjStatePayloadLength)
            DEC  BC
            DEC  BC
            DEC  BC
NobjConsumeImageLikeLoop:
            PUSH BC
            PUSH HL
            CALL NobjReadCrcByte
            POP  HL
            POP  BC
            RET  C
            LD   D,A
            LD   A,(NobjStateMaterialize)
            OR   A
            LD   A,D
            JR   Z,NobjConsumeImageLikeNext
            LD   (HL),A
NobjConsumeImageLikeNext:
            INC  HL
            DEC  BC
            LD   A,B
            OR   C
            JR   NZ,NobjConsumeImageLikeLoop
            RET
NobjConsumeImagePlatformFailure:
            JP   NobjSetPlatformFailure

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX
NobjAcceptMap:
            LD   A,(NobjStatePhase)
            CP   NobjPhaseImage
            JP   Z,NobjMapPhaseReady
            CP   NobjPhasePatch
            JP   NZ,NobjRecordOrderInvalid
NobjMapPhaseReady:
            LD   A,(NobjStateImageSeen)
            OR   A
            JP   Z,NobjRecordOrderInvalid
            LD   HL,(NobjStatePayloadLength)
            LD   DE,41
            OR   A
            SBC  HL,DE
            JR   C,NobjMapInvalid
            LD   HL,NobjConsumerMapCapacity
            LD   DE,(NobjStatePayloadLength)
            OR   A
            SBC  HL,DE
            JR   C,NobjMapInvalid
            LD   (NobjStateMapLength),DE
            LD   HL,NobjStateMapBuffer
            LD   BC,(NobjStatePayloadLength)
NobjReadMapLoop:
            PUSH BC
            PUSH HL
            CALL NobjReadCrcByte
            POP  HL
            POP  BC
            RET  C
            LD   (HL),A
            INC  HL
            DEC  BC
            LD   A,B
            OR   C
            JR   NZ,NobjReadMapLoop
            CALL NobjValidateMap
            RET  C
            LD   A,NobjPhaseMap
            LD   (NobjStatePhase),A
            JP   NobjValidateRecordLoop
NobjMapInvalid:
            LD   A,NobjStatusMap
            JP   NobjSetValidatorFailure

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX
NobjValidateMap:
            LD   IX,NobjStateMapBuffer
            LD   A,(IX+0)
            CP   1
            JP   NZ,NobjMapInvalid
            LD   A,(IX+NobjMapFlags)
            AND  $FC
            JP   NZ,NobjMapInvalid
            LD   A,(IX+NobjMapFlags)
            AND  1
            LD   B,A
            LD   A,(NobjStateRomMode)
            CP   B
            JP   NZ,NobjMapInvalid
            LD   A,(IX+NobjMapFlags)
            AND  2
            LD   B,A
            LD   A,(NobjStateProfileFlags)
            AND  2
            CP   B
            JP   NZ,NobjMapInvalid
            LD   A,(IX+NobjMapEntryBank)
            LD   B,A
            LD   A,(NobjStateEntryBank)
            CP   B
            JP   NZ,NobjMapInvalid
            LD   L,(IX+NobjMapEntryAddress)
            LD   H,(IX+NobjMapEntryAddress+1)
            LD   DE,(NobjStateImageBase)
            OR   A
            SBC  HL,DE
            JP   NZ,NobjMapInvalid
            LD   L,(IX+NobjMapWritableBase)
            LD   H,(IX+NobjMapWritableBase+1)
            LD   DE,(NobjStateWritableBase)
            OR   A
            SBC  HL,DE
            JP   NZ,NobjMapInvalid
            LD   L,(IX+NobjMapWritableCapacity)
            LD   H,(IX+NobjMapWritableCapacity+1)
            LD   DE,(NobjStateWritableCapacity)
            OR   A
            SBC  HL,DE
            JP   NZ,NobjMapInvalid

            LD   A,(IX+NobjMapPartCount)
            OR   A
            JP   Z,NobjMapInvalid
            LD   C,A
            LD   B,0
            LD   HL,NobjStateMapBuffer+29
NobjValidatePartBanksLoop:
            LD   A,(HL)
            LD   D,A
            LD   A,(NobjStateBankCount)
            DEC  A
            CP   D
            JP   C,NobjMapInvalid
            INC  HL
            DEC  BC
            LD   A,B
            OR   C
            JR   NZ,NobjValidatePartBanksLoop
            LD   A,(HL)                  ; bank entry count
            LD   B,A
            LD   A,(NobjStateBankCount)
            CP   B
            JP   NZ,NobjMapInvalid

            ; Exact payload length: 30 + partCount + 10*bankCount.
            LD   A,(NobjStateBankCount)
            LD   L,A
            LD   H,0
            ADD  HL,HL                   ; 2n
            LD   D,H
            LD   E,L
            ADD  HL,HL                   ; 4n
            ADD  HL,HL                   ; 8n
            ADD  HL,DE                   ; 10n
            LD   A,(IX+NobjMapPartCount)
            LD   E,A
            LD   D,0
            ADD  HL,DE
            LD   DE,30
            ADD  HL,DE
            LD   DE,(NobjStateMapLength)
            OR   A
            SBC  HL,DE
            JP   NZ,NobjMapInvalid

            CALL NobjValidateWritableMap
            RET  C
            JP   NobjValidateMapBanks

; Validate the fixed writable, data-load, and stack relationships.
.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
NobjValidateWritableMap:
            LD   IX,NobjStateMapBuffer
            LD   L,(IX+NobjMapVectorBase)
            LD   H,(IX+NobjMapVectorBase+1)
            LD   DE,(NobjStateWritableBase)
            OR   A
            SBC  HL,DE
            JP   NZ,NobjMapInvalid
            LD   L,(IX+NobjMapInitializedRunBase)
            LD   H,(IX+NobjMapInitializedRunBase+1)
            LD   DE,(NobjStateWritableBase)
            OR   A
            SBC  HL,DE
            JP   NZ,NobjMapInvalid
            LD   E,(IX+NobjMapVectorLength)
            LD   D,(IX+NobjMapVectorLength+1)
            LD   A,D
            OR   E
            JP   Z,NobjMapInvalid
            LD   L,(IX+NobjMapInitializedRunLength)
            LD   H,(IX+NobjMapInitializedRunLength+1)
            PUSH HL
            OR   A
            SBC  HL,DE
            POP  HL
            JP   C,NobjMapInvalid
            LD   E,(IX+NobjMapBssLength)
            LD   D,(IX+NobjMapBssLength+1)
            ADD  HL,DE
            JP   C,NobjMapInvalid
            LD   DE,(NobjStateWritableCapacity)
            PUSH HL
            OR   A
            SBC  HL,DE
            POP  HL
            JR   C,NobjWritableUseFits
            JP   NZ,NobjMapInvalid
NobjWritableUseFits:
            ; BSS starts at writableBase + initializedRunLength, modulo $10000.
            LD   E,(IX+NobjMapInitializedRunLength)
            LD   D,(IX+NobjMapInitializedRunLength+1)
            LD   HL,(NobjStateWritableBase)
            ADD  HL,DE
            LD   E,(IX+NobjMapBssBase)
            LD   D,(IX+NobjMapBssBase+1)
            OR   A
            SBC  HL,DE
            JP   NZ,NobjMapInvalid
            ; data-load length is the complete initialized run length.
            LD   L,(IX+NobjMapDataLoadLength)
            LD   H,(IX+NobjMapDataLoadLength+1)
            LD   E,(IX+NobjMapInitializedRunLength)
            LD   D,(IX+NobjMapInitializedRunLength+1)
            OR   A
            SBC  HL,DE
            JP   NZ,NobjMapInvalid

            LD   A,(NobjStateProfileFlags)
            BIT  1,A
            JR   Z,NobjWritableStackReady
            ; free = writableCapacity - initializedLength - bssLength
            LD   HL,(NobjStateWritableCapacity)
            LD   E,(IX+NobjMapInitializedRunLength)
            LD   D,(IX+NobjMapInitializedRunLength+1)
            OR   A
            SBC  HL,DE
            LD   E,(IX+NobjMapBssLength)
            LD   D,(IX+NobjMapBssLength+1)
            OR   A
            SBC  HL,DE
            JP   C,NobjMapInvalid
            LD   E,(IX+NobjMapStackRequirement)
            LD   D,(IX+NobjMapStackRequirement+1)
            LD   A,D
            CP   $FF
            JR   NZ,NobjStackRequirementAddReturn
            LD   A,E
            CP   $FE
            JP   NC,NobjMapInvalid
NobjStackRequirementAddReturn:
            INC  DE
            INC  DE
            OR   A
            SBC  HL,DE
            JP   C,NobjMapInvalid
NobjWritableStackReady:
            LD   A,(NobjStateRomMode)
            OR   A
            JR   NZ,NobjValidateRomDataLoad
            LD   A,(IX+NobjMapDataLoadBank)
            OR   A
            JP   NZ,NobjMapInvalid
            LD   L,(IX+NobjMapDataLoadAddress)
            LD   H,(IX+NobjMapDataLoadAddress+1)
            LD   DE,(NobjStateWritableBase)
            OR   A
            SBC  HL,DE
            JP   NZ,NobjMapInvalid
            RET
NobjValidateRomDataLoad:
            LD   A,(NobjStateProfileFlags)
            BIT  0,A
            JR   Z,NobjRomDataLoadBankReady
            LD   A,(IX+NobjMapDataLoadBank)
            LD   B,A
            LD   A,(NobjStateEntryBank)
            CP   B
            JP   NZ,NobjMapInvalid
NobjRomDataLoadBankReady:
            LD   A,(IX+NobjMapDataLoadBank)
            LD   B,A
            LD   A,(NobjStateBankCount)
            DEC  A
            CP   B
            JP   C,NobjMapInvalid
            OR   A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX
NobjValidateMapBanks:
            CALL NobjMapBankEntriesPointer
            PUSH HL
            POP  IX
            XOR  A
            LD   (NobjStateCurrentBank),A
NobjValidateMapBankLoop:
            LD   L,(IX+0)
            LD   H,(IX+1)                ; used length
            LD   A,H
            OR   L
            JP   Z,NobjMapInvalid
            LD   DE,(NobjStateImageCapacity)
            PUSH HL
            OR   A
            SBC  HL,DE
            POP  HL
            JR   C,NobjMapUsedWithinCapacity
            JP   NZ,NobjMapInvalid
NobjMapUsedWithinCapacity:
            PUSH HL
            LD   A,(NobjStateCurrentBank)
            CALL NobjExpectedUsedForBank
            EX   DE,HL                    ; DE=expected
            POP  HL                      ; HL=map used
            OR   A
            SBC  HL,DE
            JP   NZ,NobjMapInvalid

            LD   E,2
            CALL NobjValidateMapOptionalExtent
            JP   C,NobjMapInvalid

            LD   E,6
            CALL NobjValidateMapOptionalExtent
            JP   C,NobjMapInvalid
            LD   A,D
            OR   E
            JR   Z,NobjMapAggregateReady
            LD   A,(IX+4)
            OR   (IX+5)
            JP   Z,NobjMapInvalid
            ; aggregateBase >= readOnlyBase
            LD   L,C
            LD   H,B
            LD   E,(IX+2)
            LD   D,(IX+3)
            OR   A
            SBC  HL,DE
            JP   C,NobjMapInvalid
            ; aggregate offset within read-only plus its length.
            PUSH HL
            LD   E,(IX+8)
            LD   D,(IX+9)
            ADD  HL,DE
            JR   C,NobjMapAggregateOverflow
            LD   E,(IX+4)
            LD   D,(IX+5)
            OR   A
            SBC  HL,DE
            POP  HL
            JR   C,NobjMapAggregateReady
            JP   NZ,NobjMapInvalid
NobjMapAggregateOverflow:
            POP  HL
            JP   NobjMapInvalid
NobjMapAggregateReady:
            LD   DE,10
            ADD  IX,DE
            LD   A,(NobjStateCurrentBank)
            INC  A
            LD   (NobjStateCurrentBank),A
            LD   B,A
            LD   A,(NobjStateBankCount)
            CP   B
            JP   NZ,NobjValidateMapBankLoop

            LD   A,(NobjStateRomMode)
            OR   A
            JR   NZ,NobjValidateRomMapLoadExtent
            JP   NobjValidateLoadedMapEnd
NobjValidateRomMapLoadExtent:
            JP   NobjValidateRomLoadExtent

; E=base-field offset within the current ten-byte bank entry; IX=entry.
; Returns BC=base and DE=length so the caller can continue validating the
; selected extent. IX is preserved.
.routine in E,IX out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
NobjValidateMapOptionalExtent:
            PUSH IX
            POP  HL
            LD   D,0
            ADD  HL,DE
            LD   C,(HL)
            INC  HL
            LD   B,(HL)
            INC  HL
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            LD   L,(IX+0)
            LD   H,(IX+1)                ; used length
            PUSH BC
            PUSH DE
            CALL NobjValidateOptionalExtent
            POP  DE
            POP  BC
            RET

; HL=used length, BC=optional base, DE=optional length.
.routine in BC,DE,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
NobjValidateOptionalExtent:
            LD   A,D
            OR   E
            JR   NZ,NobjOptionalExtentPresent
            LD   A,B
            OR   C
            RET  Z
            SCF
            RET
NobjOptionalExtentPresent:
            PUSH HL                      ; used length
            LD   H,B
            LD   L,C
            LD   BC,(NobjStateImageBase)
            OR   A
            SBC  HL,BC                   ; offset
            JR   C,NobjOptionalExtentBadPop
            ADD  HL,DE
            JR   C,NobjOptionalExtentBadPop
            POP  DE                      ; used length
            OR   A
            SBC  HL,DE
            JR   C,NobjOptionalExtentGood
            RET  Z
            SCF
            RET
NobjOptionalExtentBadPop:
            POP  HL
            SCF
            RET
NobjOptionalExtentGood:
            OR   A
            RET

.routine out A,HL,carry clobbers halfCarry,DE
NobjMapBankEntriesPointer:
            LD   A,(NobjStateMapBuffer+NobjMapPartCount)
            LD   E,A
            LD   D,0
            LD   HL,NobjStateMapBuffer+30
            ADD  HL,DE
            RET

.routine in A out A,HL,carry,zero clobbers sign,parity,halfCarry,BC,DE
NobjExpectedUsedForBank:
            PUSH AF
            LD   HL,NobjStateImageEnds
            CALL NobjBankWordPointer
            LD   C,(HL)
            INC  HL
            LD   B,(HL)
            POP  AF
            LD   HL,NobjStatePatchEnds
            CALL NobjBankWordPointer
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            LD   H,B
            LD   L,C
            OR   A
            SBC  HL,DE
            JR   C,NobjExpectedPatchEnd
            LD   H,B
            LD   L,C
            RET
NobjExpectedPatchEnd:
            LD   H,D
            LD   L,E
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
NobjValidateLoadedMapEnd:
            CALL NobjMapBankEntriesPointer
            LD   C,(HL)
            INC  HL
            LD   B,(HL)                  ; bank zero used length
            LD   HL,(NobjStateWritableBase)
            LD   DE,(NobjStateImageBase)
            OR   A
            SBC  HL,DE
            PUSH BC
            LD   DE,NobjStateMapBuffer+NobjMapInitializedRunLength
            LD   A,(DE)
            INC  DE
            LD   C,A
            LD   A,(DE)
            LD   D,A
            LD   E,C
            ADD  HL,DE
            POP  BC
            JP   C,NobjMapInvalid
            OR   A
            SBC  HL,BC
            JP   NZ,NobjMapInvalid
            LD   HL,(NobjStateImageBase)
            LD   DE,(NobjStateWritableBase)
            OR   A
            SBC  HL,DE
            JP   NC,NobjMapInvalid
            OR   A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
NobjValidateRomLoadExtent:
            LD   A,(NobjStateMapBuffer+NobjMapDataLoadBank)
            LD   C,A
            CALL NobjMapBankEntriesPointer
            LD   A,C
            OR   A
            JR   Z,NobjRomMapEntryReady
            LD   DE,10
NobjRomMapEntrySeek:
            ADD  HL,DE
            DEC  A
            JR   NZ,NobjRomMapEntrySeek
NobjRomMapEntryReady:
            LD   C,(HL)
            INC  HL
            LD   B,(HL)                  ; used length
            LD   HL,(NobjStateMapBuffer+NobjMapDataLoadAddress)
            LD   DE,(NobjStateImageBase)
            OR   A
            SBC  HL,DE
            JP   C,NobjMapInvalid
            LD   DE,(NobjStateMapBuffer+NobjMapDataLoadLength)
            ADD  HL,DE
            JP   C,NobjMapInvalid
            OR   A
            SBC  HL,BC
            JR   C,NobjRomLoadFits
            JP   NZ,NobjMapInvalid
NobjRomLoadFits:
            OR   A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
NobjAcceptCommit:
            LD   A,(NobjStatePhase)
            CP   NobjPhaseMap
            JP   NZ,NobjRecordOrderInvalid
            LD   HL,(NobjStatePayloadLength)
            LD   DE,7
            OR   A
            SBC  HL,DE
            JP   NZ,NobjFramingInvalid
            CALL NobjReadCrcWord          ; record count
            RET  C
            LD   DE,(NobjStateRecordOrdinal)
            OR   A
            SBC  HL,DE
            JR   NZ,NobjCommitInvalid
            CALL NobjReadCrcByte          ; entry bank
            RET  C
            LD   B,A
            LD   A,(NobjStateEntryBank)
            CP   B
            JR   NZ,NobjCommitInvalid
            CALL NobjReadCrcWord          ; canonical entry address
            RET  C
            LD   DE,(NobjStateImageBase)
            OR   A
            SBC  HL,DE
            JR   NZ,NobjCommitInvalid
            CALL NobjRequireByte          ; stored CRC is excluded from CRC
            RET  C
            PUSH AF
            CALL NobjRequireByte
            JR   C,NobjCommitCrcReadFailure
            LD   H,A
            POP  AF
            LD   L,A
            LD   DE,(NobjStateCrc)
            OR   A
            SBC  HL,DE
            JR   NZ,NobjCrcInvalid
            CALL NobjExpectImmediateEof
            RET  C
            LD   A,NobjPhaseCommit
            LD   (NobjStatePhase),A
            OR   A
            RET
NobjCommitCrcReadFailure:
            POP  HL
            SCF
            RET
NobjCommitInvalid:
            LD   A,NobjStatusCommit
            JP   NobjSetValidatorFailure
NobjCrcInvalid:
            LD   A,NobjStatusCrc
            JP   NobjSetValidatorFailure

.routine out A,carry,zero clobbers sign,parity,halfCarry
NobjExpectImmediateEof:
            CALL NobjPlatformObjectReadByte
            JR   NC,NobjTrailingDataInvalid
            CP   NobjPlatformEnd
            JR   NZ,NobjEofPlatformFailure
            OR   A
            RET
NobjTrailingDataInvalid:
            LD   A,NobjStatusTrailingData
            JP   NobjSetValidatorFailure
NobjEofPlatformFailure:
            JP   NobjSetPlatformFailure

; Fill every selected bank before the second materializing pass. The filled
; target remains unpublished until the second COMMIT and EOF have passed.
.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX
NobjFillTarget:
            XOR  A
            LD   (NobjStateCurrentBank),A
NobjFillTargetBank:
            LD   A,(NobjStateCurrentBank)
            LD   IX,(NobjStateProfilePointer)
            CALL NobjPlatformSelectTargetBank
            JR   C,NobjFillPlatformFailure
            LD   HL,(NobjStateImageBase)
            LD   BC,(NobjStateImageCapacity)
            LD   A,(NobjStateImageFill)
NobjFillTargetByte:
            LD   (HL),A
            INC  HL
            DEC  BC
            LD   D,A
            LD   A,B
            OR   C
            LD   A,D
            JR   NZ,NobjFillTargetByte
            LD   A,(NobjStateCurrentBank)
            INC  A
            LD   (NobjStateCurrentBank),A
            LD   B,A
            LD   A,(NobjStateBankCount)
            CP   B
            JR   NZ,NobjFillTargetBank
            OR   A
            RET
NobjFillPlatformFailure:
            JP   NobjSetPlatformFailure

; Pairwise PATCH validation uses repeated rewindable scans and retains only
; two interval descriptors. It deliberately trades time for bounded memory.
.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
NobjValidatePatchOverlaps:
            LD   HL,(NobjStatePatchCount)
            LD   A,H
            OR   A
            JR   NZ,NobjPatchOverlapOuterStart
            LD   A,L
            CP   2
            JR   NC,NobjPatchOverlapOuterStart
            OR   A
            RET
NobjPatchOverlapOuterStart:
            LD   HL,2
            LD   (NobjStateOuterPatch),HL
NobjPatchOverlapOuterLoop:
            LD   BC,(NobjStateOuterPatch)
            CALL NobjLocatePatch
            RET  C
            LD   (NobjStateCurrentBank),A
            LD   (NobjStatePatchStart),HL
            LD   (NobjStatePatchEnd),DE
            LD   HL,1
            LD   (NobjStateScanPatch),HL
NobjPatchOverlapInnerLoop:
            LD   BC,(NobjStateScanPatch)
            CALL NobjLocatePatch
            RET  C
            LD   B,A
            LD   A,(NobjStateCurrentBank)
            CP   B
            JR   NZ,NobjPatchPairReady
            ; outerStart < innerEnd
            PUSH HL                      ; inner start
            LD   BC,(NobjStatePatchStart)
            EX   DE,HL                   ; HL=inner end, DE=inner start
            OR   A
            SBC  HL,BC
            POP  HL                      ; HL=inner start
            JR   C,NobjPatchPairReady
            JR   Z,NobjPatchPairReady
            ; innerStart < outerEnd
            LD   DE,(NobjStatePatchEnd)
            OR   A
            SBC  HL,DE
            JR   C,NobjPatchOverlapInvalid
NobjPatchPairReady:
            LD   HL,(NobjStateScanPatch)
            INC  HL
            LD   (NobjStateScanPatch),HL
            LD   DE,(NobjStateOuterPatch)
            OR   A
            SBC  HL,DE
            JR   C,NobjPatchOverlapInnerLoop
            LD   HL,(NobjStateOuterPatch)
            INC  HL
            LD   (NobjStateOuterPatch),HL
            LD   DE,(NobjStatePatchCount)
            OR   A
            SBC  HL,DE
            JR   C,NobjPatchOverlapOuterLoop
            JR   Z,NobjPatchOverlapOuterLoop
            OR   A
            RET
NobjPatchOverlapInvalid:
            LD   A,NobjStatusPatchOverlap
            JP   NobjSetValidatorFailure

; BC is the one-based PATCH ordinal. Returns A=bank, HL=start offset,
; DE=end offset. The already validated object is rescanned without CRC state.
.routine in BC out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,BC
NobjLocatePatch:
            LD   (NobjStateLocatePatch),BC
            CALL NobjPlatformObjectRewind
            JR   C,NobjLocatePatchPlatformFailure
            XOR  A
            LD   (NobjStateScanPatch),A
            LD   (NobjStateScanPatch+1),A
NobjLocatePatchRecord:
            CALL NobjReadRawHeader
            RET  C
            LD   A,(NobjStateRecordKind)
            CP   NobjKindPatch
            JR   NZ,NobjLocatePatchSkip
            LD   HL,(NobjStateScanPatch)
            INC  HL
            LD   (NobjStateScanPatch),HL
            LD   DE,(NobjStateLocatePatch)
            OR   A
            SBC  HL,DE
            JR   NZ,NobjLocatePatchSkip
            CALL NobjRequireByte
            RET  C
            LD   (NobjStateCurrentBank),A
            CALL NobjReadRawWord
            RET  C
            LD   BC,(NobjStateImageBase)
            OR   A
            SBC  HL,BC
            JR   C,NobjLocatePatchChanged
            PUSH HL
            LD   DE,(NobjStatePayloadLength)
            DEC  DE
            DEC  DE
            DEC  DE
            ADD  HL,DE
            EX   DE,HL
            POP  HL
            LD   A,(NobjStateCurrentBank)
            OR   A
            RET
NobjLocatePatchSkip:
            LD   BC,(NobjStatePayloadLength)
            CALL NobjSkipRawBytes
            RET  C
            JR   NobjLocatePatchRecord
NobjLocatePatchChanged:
            LD   A,NobjStatusGenerationChanged
            JP   NobjSetValidatorFailure
NobjLocatePatchPlatformFailure:
            JP   NobjSetPlatformFailure

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,HL
NobjReadRawHeader:
            CALL NobjRequireByte
            RET  C
            LD   (NobjStateRecordKind),A
            CALL NobjReadRawWord
            RET  C
            LD   (NobjStatePayloadLength),HL
            RET

.routine out A,HL,carry,zero,sign,parity,halfCarry clobbers BC,DE,IX,IY
NobjReadRawWord:
            CALL NobjRequireByte
            RET  C
            PUSH AF
            CALL NobjRequireByte
            JR   C,NobjReadRawWordFailure
            LD   H,A
            POP  AF
            LD   L,A
            OR   A
            RET
NobjReadRawWordFailure:
            POP  HL
            SCF
            RET

.routine in BC out A,carry,zero clobbers sign,parity,halfCarry,BC
NobjSkipRawBytes:
            LD   A,B
            OR   C
            RET  Z
NobjSkipRawByteLoop:
            CALL NobjRequireByte
            RET  C
            DEC  BC
            LD   A,B
            OR   C
            JR   NZ,NobjSkipRawByteLoop
            RET
