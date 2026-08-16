; Transactional static-image allocation for the replacement compiler.
; Complete 16-bit offsets are retained throughout; no address bit is metadata.

; Carry means HL exceeds the exact inclusive 1,024-byte boundary.
.routine in HL out A,HL,carry,zero clobbers sign,parity,halfCarry
RewriteStaticCheckCapacity:
            LD   A,H
            CP   4
            JR   C,RewriteStaticCapacityReady
            JR   NZ,RewriteStaticCapacityFailure
            LD   A,L
            OR   A
            RET  Z
RewriteStaticCapacityFailure:
            SCF
            RET
RewriteStaticCapacityReady:
            OR   A
            RET

RewriteStaticProgramCapacityFailure:
            LD   A,DiagnosticProgramDataCapacity
            JP   RewriteRaiseDiagnostic
RewriteStaticReadOnlyCapacityFailure:
            LD   A,DiagnosticReadOnlyCapacity
            JP   RewriteRaiseDiagnostic
RewriteInitializerCapacityFailure:
            LD   A,DiagnosticInitializerCapacity
            JP   RewriteRaiseDiagnostic

; Reserve BC zero-initialized bytes. DE returns the old BSS-relative offset.
.routine in BC out A,DE,HL,carry,zero clobbers sign,parity,halfCarry
RewriteStaticReserveBss:
            LD   HL,(RewriteStaticBssLength)
            LD   D,H
            LD   E,L
            ADD  HL,BC
            JP   C,RewriteStaticProgramCapacityFailure
            CALL RewriteStaticCheckCapacity
            JP   C,RewriteStaticProgramCapacityFailure
            LD   (RewriteStaticBssLength),HL
            XOR  A
            RET

; Append BC bytes from HL to the aggregate-constant suffix. DE returns the old
; constant-relative offset. Capacity is checked before either bytes or length
; change, so a failed declaration cannot publish a partial constant.
.routine in HL,BC out A,DE,carry,zero clobbers sign,parity,halfCarry,B,C,HL
RewriteStaticAppendConstant:
            LD   A,B
            OR   C
            JR   NZ,RewriteStaticAppendConstantNonempty
            LD   DE,(RewriteStaticConstantLength)
            XOR  A
            RET
RewriteStaticAppendConstantNonempty:
            LD   (RewriteStaticPendingSource),HL
            LD   (RewriteStaticPendingLength),BC
            LD   DE,(RewriteStaticConstantLength)
            LD   (RewriteStaticPendingOffset),DE
            LD   HL,(RewriteStaticInitializedLength)
            ADD  HL,DE
            JP   C,RewriteStaticReadOnlyCapacityFailure
            ADD  HL,BC
            JP   C,RewriteStaticReadOnlyCapacityFailure
            CALL RewriteStaticCheckCapacity
            JP   C,RewriteStaticReadOnlyCapacityFailure
            LD   HL,RewriteStaticImageBase
            LD   DE,(RewriteStaticInitializedLength)
            ADD  HL,DE
            LD   DE,(RewriteStaticPendingOffset)
            ADD  HL,DE
            EX   DE,HL
            LD   HL,(RewriteStaticPendingSource)
            LD   BC,(RewriteStaticPendingLength)
            LDIR
            LD   HL,(RewriteStaticConstantLength)
            LD   BC,(RewriteStaticPendingLength)
            ADD  HL,BC
            LD   (RewriteStaticConstantLength),HL
            LD   DE,(RewriteStaticPendingOffset)
            XOR  A
            RET

; Insert BC initialized bytes from HL before the retained constant suffix. DE
; returns the old initialized-data offset. The suffix moves high-to-low before
; the new prefix bytes are copied, preserving constant-relative identities.
.routine in HL,BC out A,DE,carry,zero clobbers sign,parity,halfCarry,B,C,HL
RewriteStaticAppendInitialized:
            LD   A,B
            OR   C
            JR   NZ,RewriteStaticAppendInitializedNonempty
            LD   DE,(RewriteStaticInitializedLength)
            XOR  A
            RET
RewriteStaticAppendInitializedNonempty:
            LD   (RewriteStaticPendingSource),HL
            LD   (RewriteStaticPendingLength),BC
            LD   HL,(RewriteStaticInitializedLength)
            LD   (RewriteStaticPendingOffset),HL
            LD   DE,(RewriteStaticConstantLength)
            ADD  HL,DE
            JP   C,RewriteStaticProgramCapacityFailure
            ADD  HL,BC
            JP   C,RewriteStaticProgramCapacityFailure
            CALL RewriteStaticCheckCapacity
            JP   C,RewriteStaticProgramCapacityFailure
            LD   BC,(RewriteStaticConstantLength)
            LD   A,B
            OR   C
            JR   Z,RewriteStaticInitializedCopy
            LD   HL,RewriteStaticImageBase
            LD   DE,(RewriteStaticInitializedLength)
            ADD  HL,DE
            ADD  HL,BC
            DEC  HL
            LD   DE,(RewriteStaticPendingLength)
            PUSH HL
            ADD  HL,DE
            EX   DE,HL
            POP  HL
            LDDR
RewriteStaticInitializedCopy:
            LD   HL,RewriteStaticImageBase
            LD   DE,(RewriteStaticInitializedLength)
            ADD  HL,DE
            EX   DE,HL
            LD   HL,(RewriteStaticPendingSource)
            LD   BC,(RewriteStaticPendingLength)
            LDIR
            LD   HL,(RewriteStaticInitializedLength)
            LD   BC,(RewriteStaticPendingLength)
            ADD  HL,BC
            LD   (RewriteStaticInitializedLength),HL
            LD   DE,(RewriteStaticPendingOffset)
            XOR  A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,HL
RewriteInitializerReset:
            XOR  A
            LD   HL,RewriteInitializerLength
            LD   (HL),A
            INC  HL
            LD   (HL),A
            RET

; Append BC bytes from HL to the complete-object scratch image atomically.
.routine in HL,BC out A,DE,carry,zero clobbers sign,parity,halfCarry,B,C,HL
RewriteInitializerAppendBlock:
            LD   A,B
            OR   C
            JR   NZ,RewriteInitializerAppendBlockNonempty
            LD   DE,(RewriteInitializerLength)
            XOR  A
            RET
RewriteInitializerAppendBlockNonempty:
            LD   (RewriteStaticPendingSource),HL
            LD   (RewriteStaticPendingLength),BC
            LD   HL,(RewriteInitializerLength)
            LD   (RewriteStaticPendingOffset),HL
            ADD  HL,BC
            JP   C,RewriteInitializerCapacityFailure
            CALL RewriteStaticCheckCapacity
            JP   C,RewriteInitializerCapacityFailure
            LD   HL,RewriteInitializerBase
            LD   DE,(RewriteStaticPendingOffset)
            ADD  HL,DE
            EX   DE,HL
            LD   HL,(RewriteStaticPendingSource)
            LD   BC,(RewriteStaticPendingLength)
            LDIR
            LD   HL,(RewriteInitializerLength)
            LD   BC,(RewriteStaticPendingLength)
            ADD  HL,BC
            LD   (RewriteInitializerLength),HL
            LD   DE,(RewriteStaticPendingOffset)
            XOR  A
            RET

.routine in A out A,DE,carry,zero clobbers sign,parity,halfCarry,B,C,HL
RewriteInitializerAppendByte:
            LD   (RewriteStaticPendingByte),A
            LD   HL,RewriteStaticPendingByte
            LD   BC,1
            JP   RewriteInitializerAppendBlock
