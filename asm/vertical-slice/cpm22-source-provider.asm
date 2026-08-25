; CP/M source and retained-name provider for the native streaming compiler.
; The command adapter preflights and fills one fourteen-byte descriptor per
; part: twelve FCB-name bytes followed by the exact logical length.

CpmSourceOpenFunction       .equ 15
CpmSourceReadFunction       .equ 20
CpmSourceDmaFunction        .equ 26
CpmSourceRandomReadFunction .equ 33
CpmSourceDma                .equ $0080
CpmSourceDescriptorSize     .equ 14
CpmSourceRetainedCapacity   .equ 255
CpmSourceRetainedEntrySize  .equ 4
CpmSourcePhasePart          .equ 0
CpmSourcePhaseBytes         .equ 1
CpmSourcePhaseDone          .equ 2

CpmSourcePartDescriptors    .equ CpmSourceWorkspaceBase
CpmSourcePartDescriptorsEnd .equ CpmSourcePartDescriptors+SourcePartCapacity*CpmSourceDescriptorSize
CpmSourceStreamFcb          .equ CpmSourcePartDescriptorsEnd
CpmSourceRandomFcb          .equ CpmSourceStreamFcb+36
CpmSourcePartCount          .equ CpmSourceRandomFcb+36
CpmSourceNextPart           .equ CpmSourcePartCount+1
CpmSourcePhase              .equ CpmSourceNextPart+1
CpmSourceActivePart         .equ CpmSourcePhase+1
CpmSourceRemaining          .equ CpmSourceActivePart+1
CpmSourceRetainedCount      .equ CpmSourceRemaining+2
CpmSourceMaterializedHandle .equ CpmSourceRetainedCount+1
CpmSourceSavedLength        .equ CpmSourceMaterializedHandle+1
CpmSourceSavedPart          .equ CpmSourceSavedLength+1
CpmSourceSavedOffset        .equ CpmSourceSavedPart+1
CpmSourceSavedEnd           .equ CpmSourceSavedOffset+2
CpmSourceSavedPointer       .equ CpmSourceSavedEnd+2
CpmSourceSavedHandle        .equ CpmSourceSavedPointer+2
CpmSourceNameRemaining      .equ CpmSourceSavedLength
CpmSourceNameOriginalLength .equ CpmSourceSavedPart
CpmSourceNameOffset         .equ CpmSourceSavedEnd
CpmSourceNameCursor         .equ CpmSourceSavedOffset
CpmSourceCopyLength         .equ CpmSourceSavedHandle
CpmSourceCompareLength      .equ CpmSourceSavedOffset
CpmSourceStateEnd           .equ CpmSourceSavedHandle+1
CpmSourceRetainedTable      .equ CpmSourceStateEnd
CpmSourceRetainedTableEnd   .equ CpmSourceRetainedTable+CpmSourceRetainedCapacity*CpmSourceRetainedEntrySize
CpmSourceNameScratch        .equ CpmSourceRetainedTableEnd
CpmSourceNameScratchEnd     .equ CpmSourceNameScratch+255
CpmSourceWorkspaceEnd       .equ CpmSourceNameScratchEnd

CpmSourceProviderCodeStart:
; The command adapter owns PartCount and descriptors. Reset everything whose
; lifetime is one compilation without paying to clear the dead table bytes.
.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CpmSourceProviderBegin:
            LD   A,(CpmSourcePartCount)
            OR   A
            JP   Z,CpmSourceInvalid
            CP   SourcePartCapacity+1
            JP   NC,CpmSourceInvalid
            LD   HL,CpmSourceNextPart
            LD   DE,CpmSourceNextPart+1
            LD   BC,CpmSourceStateEnd-CpmSourceNextPart-1
            XOR  A
            LD   (HL),A
            LDIR
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry
CpmSourceProviderEnd:
            XOR  A
            RET

; Existing compiler event ABI: A=event, C=one-based part, HL=bytes, DE=count.
.routine out A,C,DE,HL,carry,zero clobbers sign,parity,halfCarry,B
CpmSourceProviderNext:
            LD   A,(CpmSourcePhase)
            OR   A
            JR   Z,CpmSourceNextPartEvent
            DEC  A
            JP   Z,CpmSourceNextBytes
            JP   CpmSourceInvalid
CpmSourceNextPartEvent:
            LD   A,(CpmSourceNextPart)
            LD   B,A
            LD   A,(CpmSourcePartCount)
            CP   B
            JR   Z,CpmSourceNextUnit
            LD   A,B
            INC  A
            LD   (CpmSourceNextPart),A
            LD   (CpmSourceActivePart),A
            CALL CpmSourceDescriptor
            RET  C
            PUSH HL
            LD   DE,12
            ADD  HL,DE
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            LD   (CpmSourceRemaining),DE
            POP  HL
            LD   DE,CpmSourceStreamFcb
            CALL CpmBuildFcb
            LD   DE,CpmSourceStreamFcb
            LD   C,CpmSourceOpenFunction
            CALL CpmCallBdos
            INC  A
            JP   Z,CpmSourceStorage
            LD   A,CpmSourcePhaseBytes
            LD   (CpmSourcePhase),A
            LD   A,(CpmSourceActivePart)
            LD   C,A
            LD   A,1
            JP   CpmSourceEmptyEvent
CpmSourceNextUnit:
            LD   A,CpmSourcePhaseDone
            LD   (CpmSourcePhase),A
            LD   C,0
            LD   A,3
            JP   CpmSourceEmptyEvent

CpmSourceNextBytes:
            LD   HL,(CpmSourceRemaining)
            LD   A,H
            OR   L
            JR   Z,CpmSourceNextEnd
            LD   DE,NativeSourceChunkBase
            LD   C,CpmSourceDmaFunction
            CALL CpmCallBdos
            LD   DE,CpmSourceStreamFcb
            LD   C,CpmSourceReadFunction
            CALL CpmCallBdos
            OR   A
            JP   NZ,CpmSourceStorage
            LD   HL,(CpmSourceRemaining)
            LD   DE,128
            OR   A
            SBC  HL,DE
            JR   C,CpmSourceNextShortRecord
            LD   (CpmSourceRemaining),HL
            JR   CpmSourceNextOutput
CpmSourceNextShortRecord:
            ADD  HL,DE
            EX   DE,HL
            LD   HL,0
            LD   (CpmSourceRemaining),HL
CpmSourceNextOutput:
            LD   HL,NativeSourceChunkBase
            LD   A,(CpmSourceActivePart)
            LD   C,A
            XOR  A
            RET
CpmSourceNextEnd:
            XOR  A
            LD   (CpmSourcePhase),A
            LD   A,(CpmSourceActivePart)
            LD   C,A
            LD   A,2
            JP   CpmSourceEmptyEvent

.routine in A,C out A,C,DE,HL,carry,zero clobbers sign,parity,halfCarry
CpmSourceEmptyEvent:
            LD   HL,0
            LD   D,H
            LD   E,L
            OR   A
            RET

; Compiler retain ABI: HL=bytes, B=length, C=part, DE=part offset. B/C/DE are
; caller-live; the returned nonzero HL is a one-byte handle widened to a word.
.routine in HL,B,C,DE out A,HL,carry,zero clobbers sign,parity,halfCarry
CpmSourceProviderRetainName:
            PUSH BC
            PUSH DE
            CALL CpmSourceRetainBody
            POP  DE
            POP  BC
            RET

.routine in HL,B,C,DE out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
CpmSourceRetainBody:
            LD   (CpmSourceSavedPointer),HL
            LD   A,B
            LD   (CpmSourceSavedLength),A
            LD   A,C
            LD   (CpmSourceSavedPart),A
            LD   (CpmSourceSavedOffset),DE
            CALL CpmSourceValidatePosition
            RET  C

            LD   HL,(CpmSourceSavedPointer)
            LD   DE,CpmSourceNameScratch
            OR   A
            SBC  HL,DE
            JR   NZ,CpmSourceRetainAppend
            LD   A,(CpmSourceMaterializedHandle)
            OR   A
            JR   Z,CpmSourceRetainAppend
            LD   (CpmSourceSavedHandle),A
            LD   L,A
            LD   H,0
            CALL CpmSourceHandleEntry
            RET  C
            LD   A,(CpmSourceSavedPart)
            CP   (HL)
            JR   NZ,CpmSourceRetainAppend
            INC  HL
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            INC  HL
            PUSH HL
            LD   HL,(CpmSourceSavedOffset)
            OR   A
            SBC  HL,DE
            JR   NZ,CpmSourceRetainAppendDrop
            POP  HL
            LD   A,(CpmSourceSavedLength)
            CP   (HL)
            JR   NZ,CpmSourceRetainAppend
            LD   A,(CpmSourceSavedHandle)
            LD   L,A
            LD   H,0
            XOR  A
            RET

CpmSourceRetainAppendDrop:
            POP  HL
CpmSourceRetainAppend:
            LD   A,(CpmSourceRetainedCount)
            CP   CpmSourceRetainedCapacity
            JP   Z,CpmSourceCapacity
            INC  A
            LD   (CpmSourceRetainedCount),A
            LD   (CpmSourceSavedHandle),A
            CALL CpmSourceEntryFromA
            LD   A,(CpmSourceSavedPart)
            LD   (HL),A
            INC  HL
            LD   DE,(CpmSourceSavedOffset)
            LD   (HL),E
            INC  HL
            LD   (HL),D
            INC  HL
            LD   A,(CpmSourceSavedLength)
            LD   (HL),A
            LD   A,(CpmSourceSavedHandle)
            LD   L,A
            LD   H,0
            XOR  A
            RET

; Compiler compare ABI: HL=handle, IX=current bytes, B=length; Z means equal.
.routine in HL,IX,B out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CpmSourceProviderCompareName:
            LD   A,B
            LD   (CpmSourceCompareLength),A
            PUSH HL
            PUSH IX
            POP  HL
            LD   (CpmSourceSavedPointer),HL
            POP  HL
            CALL CpmSourcePrepareName
            RET  C
            LD   A,(CpmSourceCompareLength)
            CP   B
            JR   NZ,CpmSourceNameUnequal
CpmSourceCompareRecord:
            CALL CpmSourceReadNameChunk
            RET  C
            LD   DE,(CpmSourceSavedPointer)
            LD   B,C
CpmSourceCompareLoop:
            LD   A,(DE)
            CP   (HL)
            JR   NZ,CpmSourceNameUnequal
            INC  DE
            INC  HL
            DJNZ CpmSourceCompareLoop
            LD   (CpmSourceSavedPointer),DE
            LD   A,(CpmSourceNameRemaining)
            OR   A
            JR   NZ,CpmSourceCompareRecord
            XOR  A
            RET
CpmSourceNameUnequal:
            LD   A,1
            OR   A
            RET

; Compiler materialize ABI: HL=handle; return stable HL and exact B while
; preserving the caller's C and DE values.
.routine in HL out A,B,HL,carry,zero clobbers sign,parity,halfCarry
CpmSourceProviderMaterializeName:
            PUSH BC
            PUSH DE
            LD   A,L
            LD   (CpmSourceMaterializedHandle),A
            CALL CpmSourceMaterializeBody
            POP  DE
            POP  BC
            PUSH AF
            LD   A,(CpmSourceNameOriginalLength)
            LD   B,A
            POP  AF
            RET

; Validate a retained handle and return its four-byte entry in HL.
.routine in HL out A,HL,carry,zero clobbers sign,parity,halfCarry,BC,DE
CpmSourceHandleEntry:
            LD   A,H
            OR   A
            JP   NZ,CpmSourceInvalid
            LD   A,L
            OR   A
            JP   Z,CpmSourceInvalid
            LD   B,A
            LD   A,(CpmSourceRetainedCount)
            CP   B
            JP   C,CpmSourceInvalid
            LD   A,B
            JP   CpmSourceEntryFromA

.routine in A out A,HL,carry,zero clobbers sign,parity,halfCarry,DE
CpmSourceEntryFromA:
            DEC  A
            LD   L,A
            LD   H,0
            ADD  HL,HL
            ADD  HL,HL
            LD   DE,CpmSourceRetainedTable
            ADD  HL,DE
            OR   A
            RET

; Validate and reopen the source which owns a retained name. Comparison reads
; each DMA record in place; materialization alone writes the stable scratch.
.routine in HL out A,B,carry,zero clobbers sign,parity,halfCarry,C,DE,HL
CpmSourcePrepareName:
            LD   A,L
            LD   (CpmSourceSavedHandle),A
            CALL CpmSourceHandleEntry
            RET  C
            LD   A,(HL)
            LD   (CpmSourceSavedPart),A
            INC  HL
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            LD   (CpmSourceNameOffset),DE
            INC  HL
            LD   A,(HL)
            LD   (CpmSourceNameRemaining),A
            LD   A,(CpmSourceSavedPart)
            CALL CpmSourceDescriptor
            RET  C
            LD   DE,CpmSourceRandomFcb
            CALL CpmBuildFcb
            LD   DE,CpmSourceRandomFcb
            LD   C,CpmSourceOpenFunction
            CALL CpmCallBdos
            INC  A
            JP   Z,CpmSourceStorage
            LD   A,(CpmSourceNameRemaining)
            LD   (CpmSourceNameOriginalLength),A
            LD   B,A
            XOR  A
            RET

.routine in HL out A,B,HL,carry,zero,sign,parity,halfCarry clobbers C,DE
CpmSourceMaterializeBody:
            CALL CpmSourcePrepareName
            RET  C
            LD   HL,CpmSourceNameScratch
            LD   (CpmSourceNameCursor),HL
CpmSourceMaterializeRecord:
            CALL CpmSourceReadNameChunk
            RET  C
            LD   DE,(CpmSourceNameCursor)
            LDIR
            LD   (CpmSourceNameCursor),DE
            LD   A,(CpmSourceNameRemaining)
            OR   A
            JR   NZ,CpmSourceMaterializeRecord
            LD   A,(CpmSourceNameOriginalLength)
            LD   B,A
            LD   HL,CpmSourceNameScratch
            XOR  A
            RET

; Read the next retained-name segment. Return HL=DMA bytes and C=count after
; advancing the saved logical offset and remaining length.
.routine out A,BC,HL,carry,zero clobbers sign,parity,halfCarry,DE
CpmSourceReadNameChunk:
            LD   HL,(CpmSourceNameOffset)
            LD   A,L
            RLCA
            AND  1
            LD   E,A
            LD   A,H
            ADD  A,A
            OR   E
            LD   (CpmSourceRandomFcb+33),A
            LD   A,H
            RLCA
            AND  1
            LD   (CpmSourceRandomFcb+34),A
            XOR  A
            LD   (CpmSourceRandomFcb+35),A
            LD   DE,CpmSourceDma
            LD   C,CpmSourceDmaFunction
            CALL CpmCallBdos
            LD   DE,CpmSourceRandomFcb
            LD   C,CpmSourceRandomReadFunction
            CALL CpmCallBdos
            OR   A
            JP   NZ,CpmSourceStorage

            LD   HL,(CpmSourceNameOffset)
            LD   A,L
            AND  127
            LD   E,A
            LD   A,128
            SUB  E
            LD   C,A
            LD   A,(CpmSourceNameRemaining)
            CP   C
            JR   NC,CpmSourceCopyLengthReady
            LD   C,A
CpmSourceCopyLengthReady:
            LD   A,C
            LD   (CpmSourceCopyLength),A
            LD   B,0
            LD   HL,CpmSourceDma
            LD   D,B
            ADD  HL,DE
            PUSH HL
            LD   A,(CpmSourceCopyLength)
            LD   C,A
            LD   B,0
            LD   HL,(CpmSourceNameOffset)
            ADD  HL,BC
            LD   (CpmSourceNameOffset),HL
            LD   A,(CpmSourceNameRemaining)
            SUB  C
            LD   (CpmSourceNameRemaining),A
            POP  HL
            XOR  A
            RET

; Validate the part and complete [offset, offset+length) range captured by
; RetainName against its preflighted descriptor.
.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CpmSourceValidatePosition:
            LD   A,(CpmSourceSavedLength)
            OR   A
            JP   Z,CpmSourceInvalid
            LD   E,A
            LD   D,0
            LD   HL,(CpmSourceSavedOffset)
            ADD  HL,DE
            JP   C,CpmSourceInvalid
            LD   (CpmSourceSavedEnd),HL
            LD   A,(CpmSourceSavedPart)
            CALL CpmSourceDescriptor
            RET  C
            LD   DE,12
            ADD  HL,DE
            LD   C,(HL)
            INC  HL
            LD   B,(HL)
            LD   HL,(CpmSourceSavedEnd)
            OR   A
            SBC  HL,BC
            JP   C,CpmSourcePositionValid
            JP   NZ,CpmSourceInvalid
CpmSourcePositionValid:
            XOR  A
            RET

; A is a one-based part ID. Return its descriptor only inside PartCount.
.routine in A out A,HL,carry,zero clobbers sign,parity,halfCarry,B,DE
CpmSourceDescriptor:
            OR   A
            JP   Z,CpmSourceInvalid
            LD   B,A
            LD   A,(CpmSourcePartCount)
            CP   B
            JP   C,CpmSourceInvalid
            LD   A,B
            DEC  A
            LD   HL,CpmSourcePartDescriptors
            LD   DE,CpmSourceDescriptorSize
            RET  Z
CpmSourceDescriptorLoop:
            ADD  HL,DE
            DEC  A
            JR   NZ,CpmSourceDescriptorLoop
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry
CpmSourceInvalid:
            LD   A,NucleusStatusInvalid
            SCF
            RET
.routine out A,carry,zero clobbers sign,parity,halfCarry
CpmSourceCapacity:
            LD   A,NucleusStatusCapacity
            SCF
            RET
.routine out A,carry,zero clobbers sign,parity,halfCarry
CpmSourceStorage:
            LD   A,NucleusStatusStorage
            SCF
            RET
CpmSourceProviderCodeEnd:
