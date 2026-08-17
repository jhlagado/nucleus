; Origin-independent target descriptor validation and layout classification.
; This first R7 layer has no publication side effects: the adapter is opened
; only after the complete descriptor and layout have been admitted.

; A is the bounded source-part count and IX addresses the stable Host API 1
; target descriptor. Every bank-bearing byte is checked before it can enter
; retained compiler state.
.routine in A,IX out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteTargetValidateDescriptor:
            OR   A
            JP   Z,RewriteTargetConfigurationFailure
            CP   SourcePartCapacity+1
            JP   NC,RewriteTargetConfigurationFailure
            LD   (RewriteTargetPartCount),A
            LD   (RewriteTargetDescriptorPointer),IX
            LD   L,(IX+RewriteTargetDescriptorRuntimeIdentity)
            LD   H,(IX+RewriteTargetDescriptorRuntimeIdentity+1)
            LD   DE,NucleusRuntimeIdentity
            OR   A
            SBC  HL,DE
            JP   NZ,RewriteTargetConfigurationFailure
            LD   A,(IX+RewriteTargetDescriptorFlags)
            CP   RewriteTargetEstablishStack+1
            JP   NC,RewriteTargetConfigurationFailure
            LD   (RewriteTargetFlags),A
            LD   A,(IX+RewriteTargetDescriptorBankCount)
            OR   A
            JP   Z,RewriteTargetConfigurationFailure
            CP   RewriteTargetBankCapacity+1
            JP   NC,RewriteTargetConfigurationFailure
            LD   (RewriteTargetBankCount),A
            LD   C,A
            LD   A,(IX+RewriteTargetDescriptorEntryBank)
            CP   C
            JP   NC,RewriteTargetConfigurationFailure
            LD   (RewriteTargetEntryBank),A
            LD   E,(IX+RewriteTargetDescriptorPartBanksPointer)
            LD   D,(IX+RewriteTargetDescriptorPartBanksPointer+1)
            LD   A,(RewriteTargetPartCount)
            LD   B,A
RewriteTargetValidatePartBanks:
            LD   A,(DE)
            CP   C
            JP   NC,RewriteTargetConfigurationFailure
            INC  DE
            DJNZ RewriteTargetValidatePartBanks
            LD   L,(IX+RewriteTargetDescriptorImageBase)
            LD   H,(IX+RewriteTargetDescriptorImageBase+1)
            LD   (RewriteTargetImageBase),HL
            LD   E,(IX+RewriteTargetDescriptorImageCapacity)
            LD   D,(IX+RewriteTargetDescriptorImageCapacity+1)
            LD   (RewriteTargetImageCapacity),DE
            CALL RewriteTargetValidateRegion
            LD   L,(IX+RewriteTargetDescriptorWritableBase)
            LD   H,(IX+RewriteTargetDescriptorWritableBase+1)
            LD   (RewriteTargetWritableBase),HL
            LD   E,(IX+RewriteTargetDescriptorWritableCapacity)
            LD   D,(IX+RewriteTargetDescriptorWritableCapacity+1)
            LD   (RewriteTargetWritableCapacity),DE
            CALL RewriteTargetValidateRegion
            CALL RewriteTargetClassifyLayout
            LD   A,(RewriteTargetBankCount)
            CP   1
            JR   Z,RewriteTargetDescriptorReady
            LD   A,(RewriteTargetLayoutMode)
            OR   A
            JP   Z,RewriteTargetConfigurationFailure
RewriteTargetDescriptorReady:
            XOR  A
            RET

; Begin one append-only target generation only after the complete descriptor
; has been admitted. Adapter failure before open has nothing to abort.
.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
RewriteTargetBeginOutput:
            XOR  A
            LD   (RewriteTargetOutputState),A
            LD   IX,(RewriteTargetDescriptorPointer)
            CALL RewriteTargetSinkBegin
            JP   C,RewriteTargetOutputFailure
            LD   A,RewriteTargetOutputOpen
            LD   (RewriteTargetOutputState),A
            OR   A
            RET

; A is one image byte, C the bank, and HL its complete target address.
.routine in A,C,HL out A,carry,zero clobbers sign,parity,halfCarry,DE,IY
RewriteTargetAppendImageByte:
            CALL RewriteTargetSinkImageByte
            JP   C,RewriteTargetAbortOutputFailure
            RET

; C is the bank, DE the complete target address, and HL the patch word.
.routine in C,DE,HL out A,carry,zero clobbers sign,parity,halfCarry,IY
RewriteTargetAppendPatchWord:
            CALL RewriteTargetSinkPatchWord
            JP   C,RewriteTargetAbortOutputFailure
            RET

; A successful commit closes the only open generation. A commit failure first
; aborts the generation, so a stream can never observe both abort and commit.
.routine out A,carry,zero clobbers sign,parity,halfCarry,IY
RewriteTargetCommitOutput:
            CALL RewriteTargetSinkCommit
            JP   C,RewriteTargetAbortOutputFailure
            XOR  A
            LD   (RewriteTargetOutputState),A
            RET

; Idempotent output-failure cleanup and the cleanup entry for the later target
; generation catch. Parse diagnostics do not enter this target-only path;
; Begin initializes the state to closed before asking the adapter to open.
.routine out A,carry,zero clobbers sign,parity,halfCarry,IY
RewriteTargetAbortOutput:
            LD   A,(RewriteTargetOutputState)
            OR   A
            RET  Z
            CALL RewriteTargetSinkAbort
            XOR  A
            LD   (RewriteTargetOutputState),A
            RET

.routine noreturn
RewriteTargetAbortOutputFailure:
            CALL RewriteTargetAbortOutput
RewriteTargetOutputFailure:
            LD   A,DiagnosticTargetOutput
            JP   RewriteRaiseDiagnostic

; HL is a base and DE a nonzero capacity. Carrying to exact zero represents
; the legal mathematical end $10000; every other wrap is rejected.
.routine in DE,HL out A,carry,zero clobbers sign,parity,halfCarry,HL
RewriteTargetValidateRegion:
            LD   A,D
            OR   E
            JP   Z,RewriteTargetCapacityFailure
            ADD  HL,DE
            JR   NC,RewriteTargetRegionReady
            LD   A,H
            OR   L
            JP   NZ,RewriteTargetCapacityFailure
RewriteTargetRegionReady:
            XOR  A
            RET

; Loaded means the complete writable region is contained by the image.
; Otherwise the two half-open regions must be disjoint. Partial overlap is a
; target configuration error, never inferred from an address bit.
.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
RewriteTargetClassifyLayout:
            LD   HL,(RewriteTargetWritableBase)
            LD   DE,(RewriteTargetImageBase)
            OR   A
            SBC  HL,DE
            JR   C,RewriteTargetWritableBeforeImage
            LD   DE,(RewriteTargetImageCapacity)
            PUSH HL
            OR   A
            SBC  HL,DE
            POP  BC
            JR   NC,RewriteTargetRomReady
            LD   HL,(RewriteTargetImageCapacity)
            OR   A
            SBC  HL,BC
            LD   DE,(RewriteTargetWritableCapacity)
            OR   A
            SBC  HL,DE
            JP   C,RewriteTargetConfigurationFailure
            XOR  A
            LD   (RewriteTargetLayoutMode),A
            RET
RewriteTargetWritableBeforeImage:
            LD   HL,(RewriteTargetImageBase)
            LD   DE,(RewriteTargetWritableBase)
            OR   A
            SBC  HL,DE
            LD   DE,(RewriteTargetWritableCapacity)
            OR   A
            SBC  HL,DE
            JP   C,RewriteTargetConfigurationFailure
RewriteTargetRomReady:
            LD   A,RewriteTargetLayoutRom
            LD   (RewriteTargetLayoutMode),A
            OR   A
            RET

.routine noreturn
RewriteTargetConfigurationFailure:
            LD   A,DiagnosticTargetConfiguration
            JP   RewriteRaiseDiagnostic

.routine noreturn
RewriteTargetCapacityFailure:
            LD   A,DiagnosticTargetCapacity
            JP   RewriteRaiseDiagnostic
