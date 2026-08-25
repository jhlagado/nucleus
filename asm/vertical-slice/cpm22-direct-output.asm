; Direct flat-image target sink for the CP/M compiler candidate.
;
; The trusted compiler still emits ordered IMAGE and PATCH operations. This
; sink materializes them immediately in a private TPA buffer; a later commit
; publishes the already-patched bytes transactionally as a COM file. Runtime
; catalogue transfer and CP/M file publication are provider operations and are
; measured outside this core.

CpmDirectMapPointer .equ CpmHostWorkspaceBase
CpmDirectActive     .equ CpmDirectMapPointer+2
CpmDirectUsedLength .equ CpmDirectActive+1
CpmDirectPatchAddress .equ CpmDirectUsedLength+2
CpmDirectPatchValue .equ CpmDirectPatchAddress+2
CpmDirectRuntimeOperation .equ CpmDirectPatchValue+2
CpmDirectRuntimeLength .equ CpmDirectRuntimeOperation+1
CpmDirectRuntimeIdentity .equ CpmDirectRuntimeLength+2
CpmDirectRuntimeContext .equ CpmDirectRuntimeIdentity+2
CpmDirectRangeStart .equ CpmDirectRuntimeContext+2
CpmDirectWorkspaceEnd .equ CpmDirectRangeStart+2

CpmDirectOutputCodeStart:
.routine in IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CpmDirectBegin:
            XOR  A
            LD   (CpmDirectMapPointer),A
            LD   (CpmDirectMapPointer+1),A
            INC  A
            LD   (CpmDirectActive),A
            LD   HL,CpmOutputBufferBase
            LD   DE,CpmOutputBufferBase+1
            LD   BC,CpmTargetImageCapacity-1
            XOR  A
            LD   (HL),A
            LDIR
            RET

; A is the byte, C the flat bank, and HL its logical target address.
.routine in A,C,HL out A,carry,zero clobbers sign,parity,halfCarry,DE
CpmDirectImageByte:
CpmDirectPatchByte:
            PUSH HL
            PUSH AF
            LD   A,C
            OR   A
            JR   NZ,CpmDirectByteInvalid
            CALL CpmDirectTranslateByte
            JR   C,CpmDirectByteInvalid
            POP  AF
            LD   (HL),A
            POP  HL
            XOR  A
            RET
CpmDirectByteInvalid:
            POP  AF
            POP  HL
            JP   CpmDirectInvalid

; C is the bank, DE the logical target address, and HL the replacement word.
.routine in C,DE,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CpmDirectPatchWord:
            LD   A,C
            OR   A
            JP   NZ,CpmDirectInvalid
            LD   (CpmDirectPatchAddress),DE
            LD   (CpmDirectPatchValue),HL
            LD   HL,(CpmDirectPatchAddress)
            CALL CpmDirectTranslateWord
            RET  C
            LD   D,H
            LD   E,L
            LD   HL,(CpmDirectPatchValue)
            LD   A,L
            LD   (DE),A
            INC  DE
            LD   A,H
            LD   (DE),A
            XOR  A
            RET

; The provider receives a physical destination in HL after the complete
; logical range has been validated. These two entries also reject the only
; invalid flat-bank ordinal before converting it into a catalogue operation.
.routine in A,BC,DE,HL,IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CpmDirectRuntimeImage:
            OR   A
            JP   NZ,CpmDirectInvalid
            XOR  A
            JR   CpmDirectRuntime
.routine in A,BC,DE,HL,IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CpmDirectRuntimeInitial:
            OR   A
            JP   NZ,CpmDirectInvalid
            LD   A,1
CpmDirectRuntime:
            LD   (CpmDirectRuntimeOperation),A
            LD   (CpmDirectRuntimeLength),BC
            LD   (CpmDirectRuntimeIdentity),DE
            LD   (CpmDirectRuntimeContext),IX
            CALL CpmDirectTranslateRange
            RET  C
            LD   A,(CpmDirectRuntimeOperation)
            LD   BC,(CpmDirectRuntimeLength)
            LD   DE,(CpmDirectRuntimeIdentity)
            LD   IX,(CpmDirectRuntimeContext)
            JP   CpmDirectRuntimeProvider

.routine in IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CpmDirectMap:
            LD   A,(IX+31)
            DEC  A
            JP   NZ,CpmDirectInvalid
            LD   (CpmDirectMapPointer),IX
            XOR  A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CpmDirectCommit:
            LD   IX,(CpmDirectMapPointer)
            LD   A,IXH
            OR   IXL
            JP   Z,CpmDirectInvalid
            LD   L,(IX+32)
            LD   H,(IX+33)
            LD   DE,CpmTargetImageBase
            OR   A
            SBC  HL,DE
            JP   C,CpmDirectInvalid
            LD   A,H
            OR   L
            JP   Z,CpmDirectInvalid
            LD   DE,CpmTargetImageCapacity
            PUSH HL
            OR   A
            SBC  HL,DE
            POP  HL
            JP   C,CpmDirectCommitLengthReady
            JP   NZ,CpmDirectInvalid
CpmDirectCommitLengthReady:
            LD   (CpmDirectUsedLength),HL
            CALL CpmDirectPublish
            RET  C
            XOR  A
            LD   (CpmDirectActive),A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry
CpmDirectAbort:
            XOR  A
            LD   (CpmDirectActive),A
            LD   (CpmDirectMapPointer),A
            LD   (CpmDirectMapPointer+1),A
            RET

; Translate one logical target byte in HL to its physical private-image byte.
.routine in HL out A,HL,carry,zero clobbers sign,parity,halfCarry,DE
CpmDirectTranslateByte:
            PUSH HL
            LD   DE,CpmTargetImageBase
            OR   A
            SBC  HL,DE
            JR   C,CpmDirectTranslateFailed
            LD   DE,CpmTargetImageCapacity
            OR   A
            SBC  HL,DE
            JR   NC,CpmDirectTranslateFailed
            POP  HL
            LD   DE,CpmOutputAddressDelta
            ADD  HL,DE
            OR   A
            RET
CpmDirectTranslateFailed:
            POP  HL
            JP   CpmDirectInvalid

.routine in HL out A,HL,carry,zero clobbers sign,parity,halfCarry,DE
CpmDirectTranslateWord:
            LD   A,L
            CP   (CpmTargetImageLimit-1)&$FF
            JR   NZ,CpmDirectTranslateByte
            LD   A,H
            CP   (CpmTargetImageLimit-1)/$100
            JP   Z,CpmDirectInvalid
            JR   CpmDirectTranslateByte

; BC is a nonempty length and HL the logical target start. Return the physical
; start only when the mathematical complete range lies inside the image.
.routine in BC,HL out A,HL,carry,zero clobbers sign,parity,halfCarry,DE
CpmDirectTranslateRange:
            LD   A,B
            OR   C
            JP   Z,CpmDirectInvalid
            CALL CpmDirectTranslateByte
            RET  C
            LD   (CpmDirectRangeStart),HL
            ADD  HL,BC
            JR   C,CpmDirectRangeFailed
            LD   DE,CpmOutputBufferLimit
            OR   A
            SBC  HL,DE
            JR   C,CpmDirectRangeEndReady
            JR   NZ,CpmDirectRangeFailed
CpmDirectRangeEndReady:
            LD   HL,(CpmDirectRangeStart)
            OR   A
            RET
CpmDirectRangeFailed:
            JP   CpmDirectInvalid

.routine out A,carry,zero clobbers sign,parity,halfCarry
CpmDirectInvalid:
            LD   A,1
            SCF
            RET
CpmDirectOutputCodeEnd:
