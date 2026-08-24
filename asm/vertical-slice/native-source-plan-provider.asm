; Native SP1 source-plan reader and source-event provider. This is host code,
; outside the 16 KiB compiler core. It obtains every stored byte through the
; common named-object service and supplies the existing four-event compiler
; source ABI.

NativeSourceProviderPlanHandle    .equ $5A10
NativeSourceProviderSourceHandle  .equ $5A12
NativeSourceProviderPlanCursor    .equ $5A14
NativeSourceProviderPlanEnd       .equ $5A16
NativeSourceProviderPartCount     .equ $5A18
NativeSourceProviderPartOrdinal   .equ $5A19
NativeSourceProviderPhase         .equ $5A1A
NativeSourceProviderPathLength    .equ $5A1B
NativeSourceProviderNamesHandle   .equ $5A1C
NativeSourceProviderNamesEnd      .equ $5A1E
NativeSourceProviderMaterialized  .equ $5A20
NativeSourceProviderMaterializedLength .equ $5A22
NativeSourceProviderSavedPointer  .equ $5A23
NativeSourceProviderSavedLength   .equ $5A25
NativeSourceProviderSavedPart     .equ $5A26
NativeSourceProviderSavedOffset   .equ $5A27
NativeSourceProviderNamePosition  .equ $5A29
NativeSourceProviderNameHeader    .equ $5A2B
NativeSourceProviderWorkspaceEnd  .equ $5A2F

NativeSourceProviderPlanBuffer    .equ $5A40
NativeSourceProviderPlanLimit     .equ $5B40
NativeSourceProviderNameScratch   .equ $5B40
NativeSourceProviderNameLimit     .equ $5C40

NativeSourceProviderPhasePart     .equ 0
NativeSourceProviderPhaseBytes    .equ 1
NativeSourceProviderPhaseDone     .equ 2

; The native resolver publishes this fixed tentative-plan name before launch.
; A platform binding maps the logical name into its own filesystem.
NativeSourceProviderPlanName:
            .db ".nucleus/source-plan.sp1"
NativeSourceProviderPlanNameLength .equ $-NativeSourceProviderPlanName
NativeSourceProviderNamesName:
            .db ".nucleus/retained-names.work"
NativeSourceProviderNamesNameLength .equ $-NativeSourceProviderNamesName

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
NativeSourceProviderLaunchBegin:
            LD   HL,NativeSourceProviderPlanHandle
            LD   DE,NativeSourceProviderPlanHandle+1
            LD   BC,NativeSourceProviderWorkspaceEnd-NativeSourceProviderPlanHandle-1
            XOR  A
            LD   (HL),A
            LDIR
            LD   HL,NativeSourceProviderPlanBuffer
            LD   (NativeSourceProviderPlanCursor),HL
            LD   (NativeSourceProviderPlanEnd),HL
            LD   HL,NativeSourceProviderPlanName
            LD   B,NativeSourceProviderPlanNameLength
            LD   A,NucleusObjectOpenRead
            CALL NativeSourceProviderOpen
            RET  C
            LD   (NativeSourceProviderPlanHandle),HL
            CALL NativeSourceProviderReadHeader
            JR   C,NativeSourceProviderLaunchCleanupPlan
            LD   HL,NativeSourceProviderNamesName
            LD   B,NativeSourceProviderNamesNameLength
            LD   A,NucleusObjectBeginWrite
            CALL NativeSourceProviderOpen
            JR   C,NativeSourceProviderLaunchCleanupPlan
            LD   (NativeSourceProviderNamesHandle),HL
            OR   A
            RET
NativeSourceProviderLaunchCleanupPlan:
            LD   (NativeSourceProviderPathLength),A
            LD   HL,(NativeSourceProviderPlanHandle)
            LD   A,NucleusObjectClose
            CALL NativeSourceProviderTerminal
            XOR  A
            LD   (NativeSourceProviderPlanHandle),A
            LD   (NativeSourceProviderPlanHandle+1),A
            LD   A,(NativeSourceProviderPathLength)
            SCF
            RET

; Release every source-side handle. It is safe after success or source error.
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
NativeSourceProviderLaunchEnd:
            LD   HL,(NativeSourceProviderSourceHandle)
            LD   A,H
            OR   L
            JR   Z,NativeSourceProviderClosePlan
            LD   A,NucleusObjectClose
            CALL NativeSourceProviderTerminal
            RET  C
            XOR  A
            LD   (NativeSourceProviderSourceHandle),A
            LD   (NativeSourceProviderSourceHandle+1),A
NativeSourceProviderClosePlan:
            LD   HL,(NativeSourceProviderPlanHandle)
            LD   A,H
            OR   L
            JP   Z,NativeSourceProviderAbortNames
            LD   A,NucleusObjectClose
            CALL NativeSourceProviderTerminal
            RET  C
            XOR  A
            LD   (NativeSourceProviderPlanHandle),A
            LD   (NativeSourceProviderPlanHandle+1),A
NativeSourceProviderAbortNames:
            LD   HL,(NativeSourceProviderNamesHandle)
            LD   A,H
            OR   L
            RET  Z
            LD   A,NucleusObjectAbort
            CALL NativeSourceProviderTerminal
            RET  C
            XOR  A
            LD   (NativeSourceProviderNamesHandle),A
            LD   (NativeSourceProviderNamesHandle+1),A
            RET

; Return one raw plan byte in A. Parser accumulators remain live across a
; refill, so this byte operation preserves their registers.
.routine out A,carry,zero clobbers sign,parity,halfCarry
NativeSourceProviderPlanByte:
            PUSH BC
            PUSH DE
            PUSH HL
            CALL NativeSourceProviderPlanByteBody
            POP  HL
            POP  DE
            POP  BC
            RET
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
NativeSourceProviderPlanByteBody:
            LD   HL,(NativeSourceProviderPlanCursor)
            LD   DE,(NativeSourceProviderPlanEnd)
            OR   A
            SBC  HL,DE
            JR   Z,NativeSourceProviderRefillPlan
            ADD  HL,DE
            LD   A,(HL)
            INC  HL
            LD   (NativeSourceProviderPlanCursor),HL
            OR   A
            RET
NativeSourceProviderRefillPlan:
            LD   HL,(NativeSourceProviderPlanHandle)
            LD   DE,NativeSourceProviderPlanBuffer
            LD   BC,NativeSourceProviderPlanLimit-NativeSourceProviderPlanBuffer
            CALL NativeSourceProviderRead
            RET  C
            LD   A,B
            OR   C
            JP   Z,NativeSourceProviderInvalid
            LD   HL,NativeSourceProviderPlanBuffer
            LD   (NativeSourceProviderPlanCursor),HL
            ADD  HL,BC
            LD   (NativeSourceProviderPlanEnd),HL
            JP   NativeSourceProviderPlanByteBody

; HL points at an immutable literal and B is its length.
.routine in HL,B out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
NativeSourceProviderExpectLiteral:
            LD   C,B
NativeSourceProviderLiteralLoop:
            CALL NativeSourceProviderPlanByte
            RET  C
            CP   (HL)
            JP   NZ,NativeSourceProviderInvalid
            INC  HL
            DEC  C
            JR   NZ,NativeSourceProviderLiteralLoop
            RET

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
NativeSourceProviderExpectLineEnd:
            CALL NativeSourceProviderPlanByte
            RET  C
            CP   10
            RET  Z
            CP   13
            JP   NZ,NativeSourceProviderInvalid
            CALL NativeSourceProviderPlanByte
            RET  C
            CP   10
            RET  Z
            JP   NativeSourceProviderInvalid

NativeSourceProviderHeaderLiteral:
            .db "SP1 "
NativeSourceProviderRecordLiteral:
            .db "P "
NativeSourceProviderEndLiteral:
            .db "END"

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
NativeSourceProviderReadHeader:
            LD   HL,NativeSourceProviderHeaderLiteral
            LD   B,4
            CALL NativeSourceProviderExpectLiteral
            RET  C
            CALL NativeSourceProviderPlanByte
            RET  C
            SUB  '1'
            JP   C,NativeSourceProviderInvalid
            CP   SourcePartCapacity
            JP   NC,NativeSourceProviderInvalid
            INC  A
            LD   (NativeSourceProviderPartCount),A
            JP   NativeSourceProviderExpectLineEnd

; Parse one canonical decimal byte terminated by a space.
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
NativeSourceProviderDecimalSpace:
            CALL NativeSourceProviderPlanByte
            RET  C
            CP   '0'
            JP   C,NativeSourceProviderInvalid
            CP   '9'+1
            JP   NC,NativeSourceProviderInvalid
            SUB  '0'
            LD   E,A
            OR   A
            JR   NZ,NativeSourceProviderDecimalMore
            CALL NativeSourceProviderPlanByte
            RET  C
            CP   ' '
            JP   NZ,NativeSourceProviderInvalid
            XOR  A
            RET
NativeSourceProviderDecimalMore:
            CALL NativeSourceProviderPlanByte
            RET  C
            CP   ' '
            JR   Z,NativeSourceProviderDecimalReady
            CP   '0'
            JP   C,NativeSourceProviderInvalid
            CP   '9'+1
            JP   NC,NativeSourceProviderInvalid
            SUB  '0'
            LD   D,A
            LD   A,E
            ADD  A,A
            JP   C,NativeSourceProviderInvalid
            LD   L,A
            ADD  A,A
            JP   C,NativeSourceProviderInvalid
            ADD  A,A
            JP   C,NativeSourceProviderInvalid
            ADD  A,L
            JP   C,NativeSourceProviderInvalid
            ADD  A,D
            JP   C,NativeSourceProviderInvalid
            LD   E,A
            JR   NativeSourceProviderDecimalMore
NativeSourceProviderDecimalReady:
            LD   A,E
            RET

; Read the next P record, open its source object, and retain its path length.
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
NativeSourceProviderOpenNextPart:
            LD   HL,NativeSourceProviderRecordLiteral
            LD   B,2
            CALL NativeSourceProviderExpectLiteral
            RET  C
            CALL NativeSourceProviderDecimalSpace
            RET  C
            ; Bank ordinals are target metadata. The target descriptor checks
            ; them independently; the source streamer only validates u8 syntax.
            CALL NativeSourceProviderDecimalSpace
            RET  C
            OR   A
            JP   Z,NativeSourceProviderInvalid
            LD   (NativeSourceProviderPathLength),A
            LD   B,A
            LD   HL,NativeSourceProviderNameScratch
NativeSourceProviderPathLoop:
            CALL NativeSourceProviderPlanByte
            RET  C
            CP   32
            JP   C,NativeSourceProviderInvalid
            CP   127
            JP   NC,NativeSourceProviderInvalid
            CP   '\\'
            JP   Z,NativeSourceProviderInvalid
            LD   (HL),A
            INC  HL
            DJNZ NativeSourceProviderPathLoop
            CALL NativeSourceProviderExpectLineEnd
            RET  C
            LD   HL,NativeSourceProviderNameScratch
            LD   A,(NativeSourceProviderPathLength)
            LD   B,A
            LD   A,NucleusObjectOpenRead
            CALL NativeSourceProviderOpen
            RET  C
            LD   (NativeSourceProviderSourceHandle),HL
            LD   A,(NativeSourceProviderPartOrdinal)
            INC  A
            LD   (NativeSourceProviderPartOrdinal),A
            LD   A,NativeSourceProviderPhaseBytes
            LD   (NativeSourceProviderPhase),A
            LD   A,(NativeSourceProviderPartOrdinal)
            LD   C,A
            LD   A,1
            OR   A
            RET

; Validate END, exact object EOF, and release the plan handle.
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
NativeSourceProviderFinishPlan:
            LD   HL,NativeSourceProviderEndLiteral
            LD   B,3
            CALL NativeSourceProviderExpectLiteral
            RET  C
            CALL NativeSourceProviderExpectLineEnd
            RET  C
            LD   HL,(NativeSourceProviderPlanCursor)
            LD   DE,(NativeSourceProviderPlanEnd)
            OR   A
            SBC  HL,DE
            JP   NZ,NativeSourceProviderInvalid
            LD   HL,(NativeSourceProviderPlanHandle)
            LD   DE,NativeSourceProviderPlanBuffer
            LD   BC,1
            CALL NativeSourceProviderRead
            RET  C
            LD   A,B
            OR   C
            JP   NZ,NativeSourceProviderInvalid
            LD   HL,(NativeSourceProviderPlanHandle)
            LD   A,NucleusObjectClose
            CALL NativeSourceProviderTerminal
            RET  C
            XOR  A
            LD   (NativeSourceProviderPlanHandle),A
            LD   (NativeSourceProviderPlanHandle+1),A
            LD   A,NativeSourceProviderPhaseDone
            LD   (NativeSourceProviderPhase),A
            LD   A,3
            OR   A
            RET

; Read and validate the four-byte name record at the current scan position.
; Success leaves the spool cursor immediately after the header and B=length.
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
NativeSourceProviderReadNameHeader:
            LD   HL,(NativeSourceProviderNamesHandle)
            LD   DE,(NativeSourceProviderSavedOffset)
            CALL NativeSourceProviderSeek
            RET  C
            LD   HL,(NativeSourceProviderNamesHandle)
            LD   DE,NativeSourceProviderNameHeader
            LD   BC,4
            CALL NativeSourceProviderRead
            RET  C
            LD   A,B
            OR   A
            JP   NZ,NativeSourceProviderInvalid
            LD   A,C
            CP   4
            JP   NZ,NativeSourceProviderInvalid
            LD   A,(NativeSourceProviderNameHeader)
            OR   A
            JP   Z,NativeSourceProviderInvalid
            LD   B,A
            RET

; HL is an opaque retained-name handle. Success proves it is exactly the start
; of a record in the current generation and returns B=length.
.routine in HL out A,B,carry,zero clobbers sign,parity,halfCarry,C,DE,HL
NativeSourceProviderValidateName:
            LD   A,H
            OR   L
            JP   Z,NativeSourceProviderInvalid
            DEC  HL
            LD   (NativeSourceProviderNamePosition),HL
            LD   HL,0
            LD   (NativeSourceProviderSavedOffset),HL
NativeSourceProviderValidateNameLoop:
            LD   HL,(NativeSourceProviderSavedOffset)
            LD   DE,(NativeSourceProviderNamePosition)
            OR   A
            SBC  HL,DE
            JR   Z,NativeSourceProviderValidateNameFound
            JP   NC,NativeSourceProviderInvalid
            CALL NativeSourceProviderReadNameHeader
            RET  C
            LD   A,B
            LD   E,A
            LD   D,0
            LD   HL,(NativeSourceProviderSavedOffset)
            LD   BC,4
            ADD  HL,BC
            JP   C,NativeSourceProviderInvalid
            ADD  HL,DE
            JP   C,NativeSourceProviderInvalid
            LD   (NativeSourceProviderSavedOffset),HL
            LD   DE,(NativeSourceProviderNamesEnd)
            OR   A
            SBC  HL,DE
            JP   NC,NativeSourceProviderValidateNameAtEnd
            JR   NativeSourceProviderValidateNameLoop
NativeSourceProviderValidateNameAtEnd:
            JP   NZ,NativeSourceProviderInvalid
            LD   HL,(NativeSourceProviderNamePosition)
            LD   DE,(NativeSourceProviderNamesEnd)
            OR   A
            SBC  HL,DE
            JP   NZ,NativeSourceProviderInvalid
            JP   NativeSourceProviderInvalid
NativeSourceProviderValidateNameFound:
            LD   HL,(NativeSourceProviderSavedOffset)
            LD   DE,(NativeSourceProviderNamesEnd)
            OR   A
            SBC  HL,DE
            JP   NC,NativeSourceProviderInvalid
            JP   NativeSourceProviderReadNameHeader

; Compiler retained-name ABI: HL=bytes, B=length, C=part, DE=part offset.
.routine in HL,B,C,DE out A,HL,carry,zero clobbers sign,parity,halfCarry
NativeSourceProviderRetainName:
            PUSH BC
            PUSH DE
            CALL NativeSourceProviderRetainNameBody
            POP  DE
            POP  BC
            RET
.routine in HL,B,C,DE out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
NativeSourceProviderRetainNameBody:
            LD   (NativeSourceProviderSavedPointer),HL
            LD   A,B
            LD   (NativeSourceProviderSavedLength),A
            LD   A,C
            LD   (NativeSourceProviderSavedPart),A
            LD   (NativeSourceProviderSavedOffset),DE
            LD   A,B
            OR   A
            JP   Z,NativeSourceProviderInvalid
            LD   A,(NativeSourceProviderPartOrdinal)
            CP   C
            JP   NZ,NativeSourceProviderInvalid

            ; A materialized spelling immediately retained again denotes the
            ; same logical name, not a second record.
            LD   HL,(NativeSourceProviderMaterialized)
            LD   A,H
            OR   L
            JR   Z,NativeSourceProviderRetainAppend
            LD   A,(NativeSourceProviderMaterializedLength)
            CP   B
            JR   NZ,NativeSourceProviderRetainAppend
            LD   HL,(NativeSourceProviderSavedPointer)
            LD   DE,NativeSourceProviderNameScratch
            OR   A
            SBC  HL,DE
            LD   HL,(NativeSourceProviderMaterialized)
            RET  Z

NativeSourceProviderRetainAppend:
            XOR  A
            LD   (NativeSourceProviderMaterialized),A
            LD   (NativeSourceProviderMaterialized+1),A
            LD   HL,(NativeSourceProviderNamesEnd)
            PUSH HL
            LD   DE,4
            ADD  HL,DE
            JP   C,NativeSourceProviderRetainCapacity
            LD   A,(NativeSourceProviderSavedLength)
            LD   E,A
            LD   D,0
            ADD  HL,DE
            JP   C,NativeSourceProviderRetainCapacity
            LD   (NativeSourceProviderNamePosition),HL
            POP  HL
            INC  HL
            LD   (NativeSourceProviderMaterialized),HL
            DEC  HL

            LD   DE,(NativeSourceProviderSavedOffset)
            LD   A,(NativeSourceProviderSavedLength)
            LD   (NativeSourceProviderNameHeader),A
            LD   A,(NativeSourceProviderSavedPart)
            LD   (NativeSourceProviderNameHeader+1),A
            LD   (NativeSourceProviderNameHeader+2),DE

            EX   DE,HL
            LD   HL,(NativeSourceProviderNamesHandle)
            CALL NativeSourceProviderSeek
            RET  C
            LD   HL,(NativeSourceProviderNamesHandle)
            LD   DE,NativeSourceProviderNameHeader
            LD   BC,4
            CALL NativeSourceProviderWrite
            RET  C
            LD   HL,(NativeSourceProviderNamesHandle)
            LD   DE,(NativeSourceProviderSavedPointer)
            LD   A,(NativeSourceProviderSavedLength)
            LD   C,A
            LD   B,0
            CALL NativeSourceProviderWrite
            RET  C
            LD   HL,(NativeSourceProviderNamePosition)
            LD   (NativeSourceProviderNamesEnd),HL
            LD   HL,(NativeSourceProviderMaterialized)
            XOR  A
            LD   (NativeSourceProviderMaterializedLength),A
            RET
NativeSourceProviderRetainCapacity:
            POP  HL
            LD   A,NucleusStatusCapacity
            SCF
            RET

; Compiler compare ABI: HL=handle, IX=current bytes, B=length; Z reports equal.
.routine in HL,IX,B out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
NativeSourceProviderCompareName:
            LD   A,B
            LD   (NativeSourceProviderSavedLength),A
            CALL NativeSourceProviderValidateName
            RET  C
            LD   A,(NativeSourceProviderSavedLength)
            CP   B
            JR   NZ,NativeSourceProviderNameUnequal
            LD   C,B
            LD   B,0
            LD   HL,(NativeSourceProviderNamesHandle)
            LD   DE,NativeSourceProviderNameScratch
            CALL NativeSourceProviderRead
            RET  C
            LD   A,B
            OR   A
            JP   NZ,NativeSourceProviderInvalid
            LD   A,(NativeSourceProviderSavedLength)
            CP   C
            JP   NZ,NativeSourceProviderInvalid
            LD   B,A
            PUSH IX
            POP  DE
            LD   HL,NativeSourceProviderNameScratch
NativeSourceProviderCompareNameLoop:
            LD   A,(DE)
            CP   (HL)
            JR   NZ,NativeSourceProviderNameUnequal
            INC  DE
            INC  HL
            DJNZ NativeSourceProviderCompareNameLoop
            XOR  A
            RET
NativeSourceProviderNameUnequal:
            LD   A,1
            OR   A
            RET

; Compiler materialize ABI: HL=handle; returns HL=stable bytes and B=length.
.routine in HL out A,B,HL,carry,zero clobbers sign,parity,halfCarry
NativeSourceProviderMaterializeName:
            PUSH BC
            PUSH DE
            CALL NativeSourceProviderMaterializeNameBody
            PUSH HL
            PUSH AF
            LD   A,B
            LD   (NativeSourceProviderMaterializedLength),A
            POP  AF
            POP  HL
            POP  DE
            POP  BC
            PUSH AF
            LD   A,(NativeSourceProviderMaterializedLength)
            LD   B,A
            POP  AF
            RET
.routine in HL out A,BC,DE,HL,carry,zero,sign,parity,halfCarry
NativeSourceProviderMaterializeNameBody:
            LD   (NativeSourceProviderMaterialized),HL
            CALL NativeSourceProviderValidateName
            RET  C
            LD   A,B
            LD   (NativeSourceProviderMaterializedLength),A
            LD   C,A
            LD   B,0
            LD   HL,(NativeSourceProviderNamesHandle)
            LD   DE,NativeSourceProviderNameScratch
            CALL NativeSourceProviderRead
            RET  C
            LD   A,B
            OR   A
            JP   NZ,NativeSourceProviderInvalid
            LD   A,(NativeSourceProviderMaterializedLength)
            CP   C
            JP   NZ,NativeSourceProviderInvalid
            LD   B,A
            LD   HL,NativeSourceProviderNameScratch
            XOR  A
            RET

; Existing compiler source-provider ABI: A=event, C=part, HL=bytes, DE=count.
.routine out A,C,DE,HL,carry,zero clobbers sign,parity,halfCarry,B
NativeSourceProviderNext:
            XOR  A
            LD   (NativeSourceProviderMaterialized),A
            LD   (NativeSourceProviderMaterialized+1),A
            LD   A,(NativeSourceProviderPhase)
            CP   NativeSourceProviderPhaseBytes
            JR   Z,NativeSourceProviderNextBytes
            CP   NativeSourceProviderPhaseDone
            JP   Z,NativeSourceProviderInvalid
            LD   A,(NativeSourceProviderPartOrdinal)
            LD   HL,NativeSourceProviderPartCount
            CP   (HL)
            JP   Z,NativeSourceProviderFinishPlan
            JP   NativeSourceProviderOpenNextPart
NativeSourceProviderNextBytes:
            LD   HL,(NativeSourceProviderSourceHandle)
            LD   DE,NativeSourceChunkBase
            LD   BC,NativeSourceChunkLimit-NativeSourceChunkBase
            CALL NativeSourceProviderRead
            RET  C
            LD   A,B
            OR   C
            JR   Z,NativeSourceProviderEndPart
            LD   D,B
            LD   E,C
            LD   HL,NativeSourceChunkBase
            LD   A,(NativeSourceProviderPartOrdinal)
            LD   C,A
            XOR  A
            RET
NativeSourceProviderEndPart:
            LD   HL,(NativeSourceProviderSourceHandle)
            LD   A,NucleusObjectClose
            CALL NativeSourceProviderTerminal
            RET  C
            XOR  A
            LD   (NativeSourceProviderSourceHandle),A
            LD   (NativeSourceProviderSourceHandle+1),A
            LD   (NativeSourceProviderPhase),A
            LD   A,(NativeSourceProviderPartOrdinal)
            LD   C,A
            LD   A,2
            OR   A
            RET
