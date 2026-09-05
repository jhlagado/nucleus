; Native flat-target NOBJ 0.1 writer. This host component is outside the
; compiler core. It receives the existing target-sink callbacks, uses bounded
; runtime-catalogue chunks, and stores tentative IMAGE, PATCH, and final NOBJ
; objects through the common named-object service.

NativeNobjImageHandle       .equ $5C40
NativeNobjPatchHandle       .equ $5C42
NativeNobjOutputHandle      .equ $5C44
NativeNobjBeginPointer      .equ $5C46
NativeNobjMapPointer        .equ $5C48
NativeNobjImageCount        .equ $5C4A
NativeNobjPatchCount        .equ $5C4C
NativeNobjCrc               .equ $5C4E
NativeNobjRuntimeRequest    .equ $5C50
NativeNobjMapUsedLength     .equ $5C50
NativeNobjMapRoBase         .equ $5C52
NativeNobjMapInitialLength  .equ $5C54
NativeNobjMapAggregateLength .equ $5C56
NativeNobjMapRoLength       .equ $5C58
NativeNobjMapAggregateBase  .equ $5C5A
NativeNobjMapTailPointer    .equ $5C5C
NativeNobjCopyHandle        .equ $5C5E
NativeNobjImageFill         .equ $5C60
NativeNobjAbortStatus       .equ $5C61
NativeNobjSavedFailure      .equ $5C62
; RuntimeRequest occupies $5C50..$5C65. Bank count must survive every runtime
; catalogue call, so the persistent/map state starts after that overlay.
NativeNobjBankCount         .equ $5C66
NativeNobjMapStatePointer   .equ $5C67
NativeNobjMapBankOrdinal    .equ $5C69
NativeNobjRecordBuffer      .equ $5C70
NativeNobjTransferBuffer    .equ $5D00
NativeNobjTransferLimit     .equ $5E00
NativeNobjWorkspaceEnd      .equ NativeNobjTransferLimit

NativeNobjImageName:  .db ".nucleus/image.work"
NativeNobjImageNameLength .equ $-NativeNobjImageName
NativeNobjPatchName:  .db ".nucleus/patch.work"
NativeNobjPatchNameLength .equ $-NativeNobjPatchName
NativeNobjOutputName: .db ".nucleus/program.nobj"
NativeNobjOutputNameLength .equ $-NativeNobjOutputName

NativeNobjBeginPrefix:
            .db 1,15,0,"NOBJ",0,1,0

.routine out A,carry,zero clobbers sign,parity,halfCarry
NativeNobjUnavailable:
            LD   A,NSTATNA
            SCF
            RET

.routine in IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
NativeNobjBegin:
            LD   A,(IX+11)
            DEC  A
            CP   4
            JR   C,NativeNobjBeginValid
            CALL NativeNobjUnavailable
            RET
NativeNobjBeginValid:
            LD   (NativeNobjBeginPointer),IX
            LD   A,(IX+11)
            LD   (NativeNobjBankCount),A
            XOR  A
            LD   (NativeNobjMapPointer),A
            LD   (NativeNobjMapPointer+1),A
            LD   (NativeNobjImageCount),A
            LD   (NativeNobjImageCount+1),A
            LD   (NativeNobjPatchCount),A
            LD   (NativeNobjPatchCount+1),A
            LD   (NativeNobjImageHandle),A
            LD   (NativeNobjImageHandle+1),A
            LD   (NativeNobjPatchHandle),A
            LD   (NativeNobjPatchHandle+1),A
            LD   (NativeNobjOutputHandle),A
            LD   (NativeNobjOutputHandle+1),A
            DEC  A
            LD   (NativeNobjCrc),A
            LD   (NativeNobjCrc+1),A

            LD   HL,NativeNobjImageName
            LD   B,NativeNobjImageNameLength
            LD   A,NOBEGIN
            CALL OCOPEN
            JR   C,NativeNobjBeginAbort
            LD   (NativeNobjImageHandle),HL
            LD   HL,NativeNobjPatchName
            LD   B,NativeNobjPatchNameLength
            LD   A,NOBEGIN
            CALL OCOPEN
            JR   C,NativeNobjBeginAbort
            LD   (NativeNobjPatchHandle),HL
            LD   HL,NativeNobjOutputName
            LD   B,NativeNobjOutputNameLength
            LD   A,NOBEGIN
            CALL OCOPEN
            JR   C,NativeNobjBeginAbort
            LD   (NativeNobjOutputHandle),HL

            LD   HL,NativeNobjBeginPrefix
            LD   DE,NativeNobjRecordBuffer
            LD   BC,10
            LDIR
            LD   A,(NativeNobjBankCount)
            DEC  A
            LD   A,0
            JR   Z,NativeNobjBeginFlagsReady
            INC  A
NativeNobjBeginFlagsReady:
            LD   (NativeNobjRecordBuffer+9),A
            LD   IX,(NativeNobjBeginPointer)
            LD   L,(IX+0)
            LD   H,(IX+1)
            LD   (NativeNobjRecordBuffer+10),HL
            LD   A,(NativeNobjBankCount)
            LD   (NativeNobjRecordBuffer+12),A
            LD   A,(NativeNobjImageFill)
            LD   (NativeNobjRecordBuffer+13),A
            LD   L,(IX+2)
            LD   H,(IX+3)
            LD   (NativeNobjRecordBuffer+14),HL
            LD   L,(IX+4)
            LD   H,(IX+5)
            LD   (NativeNobjRecordBuffer+16),HL
            LD   HL,(NativeNobjOutputHandle)
            LD   DE,NativeNobjRecordBuffer
            LD   BC,18
            CALL NativeNobjWriteCovered
            RET
NativeNobjBeginAbort:
            LD   (NativeNobjSavedFailure),A
            CALL NativeNobjAbort
            LD   A,(NativeNobjSavedFailure)
            SCF
            RET

; A is the byte, C the bank, and HL its final address.
.routine in A,C,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
NativeNobjImageByte:
            LD   (NativeNobjRecordBuffer+6),A
            LD   A,2
            CALL NativeNobjSingleByte
            RET

; A is the byte, C the bank, and HL its final address.
.routine in A,C,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
NativeNobjPatchByte:
            LD   (NativeNobjRecordBuffer+6),A
            LD   A,3
            CALL NativeNobjSingleByte
            RET
.routine in A,C,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
NativeNobjSingleByte:
            LD   (NativeNobjRecordBuffer),A
            LD   A,4
            LD   (NativeNobjRecordBuffer+1),A
            XOR  A
            LD   (NativeNobjRecordBuffer+2),A
            LD   A,C
            LD   (NativeNobjRecordBuffer+3),A
            LD   (NativeNobjRecordBuffer+4),HL
            LD   DE,NativeNobjRecordBuffer
            LD   BC,7
            LD   A,(NativeNobjRecordBuffer)
            CP   2
            JR   NZ,NativeNobjWritePatchRecord
            LD   HL,(NativeNobjImageHandle)
            CALL OCWRITE
            RET  C
            LD   HL,NativeNobjImageCount
            JR   NativeNobjIncrementWord
NativeNobjWritePatchRecord:
            LD   HL,(NativeNobjPatchHandle)
            CALL OCWRITE
            RET  C
            LD   HL,NativeNobjPatchCount
.routine in HL out HL,zero clobbers sign,parity,halfCarry
NativeNobjIncrementWord:
            INC  (HL)
            RET  NZ
            INC  HL
            INC  (HL)
            RET

; C is the bank, DE the target address, and HL the replacement word.
.routine in C,DE,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
NativeNobjPatchWord:
            LD   A,3
            LD   (NativeNobjRecordBuffer),A
            LD   A,5
            LD   (NativeNobjRecordBuffer+1),A
            XOR  A
            LD   (NativeNobjRecordBuffer+2),A
            LD   A,C
            LD   (NativeNobjRecordBuffer+3),A
            LD   (NativeNobjRecordBuffer+4),DE
            LD   (NativeNobjRecordBuffer+6),HL
            LD   HL,(NativeNobjPatchHandle)
            LD   DE,NativeNobjRecordBuffer
            LD   BC,8
            CALL OCWRITE
            RET  C
            LD   HL,NativeNobjPatchCount
            JR   NativeNobjIncrementWord

; The dispatcher supplies A=operation, BC=complete length, DE=identity,
; HL=address, and IX=context. NativeHostRuntimeBank supplies the selected bank.
.routine in A,BC,DE,HL,IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
NativeNobjRuntime:
            CP   2
            JP   NC,NativeNobjUnavailable
            LD   (NativeNobjRecordBuffer+4),HL
            PUSH AF
            LD   A,2
            LD   (NativeNobjRecordBuffer),A
            LD   H,B
            LD   L,C
            INC  HL
            INC  HL
            INC  HL
            LD   (NativeNobjRecordBuffer+1),HL
            LD   A,(NativeHostRuntimeBank)
            LD   (NativeNobjRecordBuffer+3),A
            POP  AF
            LD   (NativeNobjRuntimeRequest+NCFOPER),A
            LD   A,NCRQSIZE
            LD   (NativeNobjRuntimeRequest+NCFSIZE),A
            LD   A,NCABI
            LD   (NativeNobjRuntimeRequest+NCFABI),A
            LD   A,(NativeNobjBankCount)
            DEC  A
            LD   A,0
            JR   Z,NativeNobjRuntimeFlagsReady
            INC  A
NativeNobjRuntimeFlagsReady:
            LD   (NativeNobjRuntimeRequest+NCFFLAG),A
            LD   A,(NativeHostRuntimeBank)
            LD   (NativeNobjRuntimeRequest+NCFBANK),A
            XOR  A
            LD   (NativeNobjRuntimeRequest+5),A
            LD   (NativeNobjRuntimeRequest+20),A
            LD   (NativeNobjRuntimeRequest+21),A
            LD   (NativeNobjRuntimeRequest+NCFIDENT),DE
            LD   (NativeNobjRuntimeRequest+NCFLEN),BC
            LD   (NativeNobjRuntimeRequest+NCFCTX),IX
            LD   DE,0
            LD   (NativeNobjRuntimeRequest+NCFOFF),DE
            LD   DE,NativeNobjTransferBuffer
            LD   (NativeNobjRuntimeRequest+NCFPTR),DE
            LD   DE,$0100
            LD   (NativeNobjRuntimeRequest+NCFCAP),DE
            LD   HL,(NativeNobjImageHandle)
            LD   DE,NativeNobjRecordBuffer
            LD   BC,6
            CALL OCWRITE
            RET  C
NativeNobjRuntimeLoop:
            LD   HL,NativeNobjRuntimeRequest
            LD   C,NSRTCAT
            RST  $10
            RET  C
            LD   BC,(NativeNobjRuntimeRequest+NCFRES)
            LD   A,B
            OR   C
            JP   Z,OCINVAL
            LD   HL,(NativeNobjImageHandle)
            LD   DE,NativeNobjTransferBuffer
            CALL OCWRITE
            RET  C
            LD   BC,(NativeNobjRuntimeRequest+NCFRES)
            LD   HL,(NativeNobjRuntimeRequest+NCFOFF)
            ADD  HL,BC
            LD   (NativeNobjRuntimeRequest+NCFOFF),HL
            LD   DE,(NativeNobjRuntimeRequest+NCFLEN)
            OR   A
            SBC  HL,DE
            JR   C,NativeNobjRuntimeLoop
            JP   NZ,OCINVAL
            LD   HL,NativeNobjImageCount
            JP   NativeNobjIncrementWord

.routine in IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
NativeNobjMap:
            LD   A,(IX+31)
            LD   B,A
            LD   A,(NativeNobjBankCount)
            CP   B
            JP   NZ,OCINVAL
            LD   (NativeNobjMapPointer),IX
            OR   A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
NativeNobjCommit:
            LD   IX,(NativeNobjMapPointer)
            LD   A,IXH
            OR   IXL
            JR   NZ,NativeNobjCommitHasMap
            CALL OCINVAL
            RET
NativeNobjCommitHasMap:
            LD   HL,(NativeNobjImageHandle)
            CALL NativeNobjCopySpool
            JP   C,NativeNobjCommitAbort
            LD   HL,(NativeNobjPatchHandle)
            CALL NativeNobjCopySpool
            JP   C,NativeNobjCommitAbort
            CALL NativeNobjWriteMap
            JP   C,NativeNobjCommitAbort

            LD   HL,(NativeNobjImageCount)
            LD   DE,(NativeNobjPatchCount)
            ADD  HL,DE
            LD   DE,3
            ADD  HL,DE
            LD   A,5
            LD   (NativeNobjRecordBuffer),A
            LD   A,7
            LD   (NativeNobjRecordBuffer+1),A
            XOR  A
            LD   (NativeNobjRecordBuffer+2),A
            LD   (NativeNobjRecordBuffer+3),HL
            LD   IX,(NativeNobjMapPointer)
            LD   A,(IX+2)
            LD   (NativeNobjRecordBuffer+5),A
            LD   L,(IX+3)
            LD   H,(IX+4)
            LD   (NativeNobjRecordBuffer+6),HL
            LD   HL,(NativeNobjOutputHandle)
            LD   DE,NativeNobjRecordBuffer
            LD   BC,8
            CALL NativeNobjWriteCovered
            JR   C,NativeNobjCommitAbort
            LD   HL,(NativeNobjOutputHandle)
            LD   DE,NativeNobjCrc
            LD   BC,2
            CALL OCWRITE
            JR   C,NativeNobjCommitAbort

            LD   HL,(NativeNobjImageHandle)
            LD   A,NOABORT
            CALL OCTERM
            JR   C,NativeNobjCommitAbort
            XOR  A
            LD   (NativeNobjImageHandle),A
            LD   (NativeNobjImageHandle+1),A
            LD   HL,(NativeNobjPatchHandle)
            LD   A,NOABORT
            CALL OCTERM
            JR   C,NativeNobjCommitAbort
            XOR  A
            LD   (NativeNobjPatchHandle),A
            LD   (NativeNobjPatchHandle+1),A
            LD   HL,(NativeNobjOutputHandle)
            LD   A,NOCOMMIT
            CALL OCTERM
            JR   C,NativeNobjCommitAbort
            XOR  A
            LD   (NativeNobjOutputHandle),A
            LD   (NativeNobjOutputHandle+1),A
            RET
NativeNobjCommitAbort:
            LD   (NativeNobjSavedFailure),A
            CALL NativeNobjAbort
            LD   A,(NativeNobjSavedFailure)
            SCF
            RET

; Copy one tentative spool to the final tentative object with CRC coverage.
.routine in HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
NativeNobjCopySpool:
            LD   (NativeNobjCopyHandle),HL
            CALL OCREWIND
            RET  C
NativeNobjCopyLoop:
            LD   HL,(NativeNobjCopyHandle)
            LD   DE,NativeNobjTransferBuffer
            LD   BC,NativeNobjTransferLimit-NativeNobjTransferBuffer
            CALL OCREAD
            RET  C
            LD   A,B
            OR   C
            RET  Z
            LD   DE,NativeNobjTransferBuffer
            LD   HL,(NativeNobjOutputHandle)
            CALL NativeNobjWriteCovered
            RET  C
            JR   NativeNobjCopyLoop

; Serialize the native MAP request into the NOBJ 0.1 MAP payload.
.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
NativeNobjWriteMap:
            LD   IX,(NativeNobjMapPointer)
            LD   A,(IX+28)
            LD   (NativeNobjRecordBuffer+31),A
            LD   B,A
            LD   A,(IX+31)
            ADD  A,A
            LD   E,A
            ADD  A,A
            ADD  A,A
            ADD  A,E
            ADD  A,B
            ADD  A,30
            LD   (NativeNobjRecordBuffer+1),A
            XOR  A
            LD   (NativeNobjRecordBuffer+2),A
            LD   A,4
            LD   (NativeNobjRecordBuffer),A
            LD   A,(IX+0)
            LD   (NativeNobjRecordBuffer+3),A
            LD   A,(IX+1)
            LD   (NativeNobjRecordBuffer+4),A
            LD   A,(IX+2)
            LD   (NativeNobjRecordBuffer+5),A
            LD   L,(IX+3)
            LD   H,(IX+4)
            LD   (NativeNobjRecordBuffer+6),HL
            LD   L,(IX+9)
            LD   H,(IX+10)
            LD   (NativeNobjRecordBuffer+8),HL
            LD   (NativeNobjRecordBuffer+12),HL
            LD   (NativeNobjRecordBuffer+16),HL
            LD   L,(IX+11)
            LD   H,(IX+12)
            LD   (NativeNobjRecordBuffer+10),HL
            LD   L,(IX+13)
            LD   H,(IX+14)
            LD   (NativeNobjRecordBuffer+14),HL
            LD   L,(IX+15)
            LD   H,(IX+16)
            LD   (NativeNobjRecordBuffer+18),HL
            LD   L,(IX+17)
            LD   H,(IX+18)
            LD   (NativeNobjRecordBuffer+20),HL
            LD   L,(IX+19)
            LD   H,(IX+20)
            LD   (NativeNobjRecordBuffer+22),HL
            LD   L,(IX+21)
            LD   H,(IX+22)
            LD   (NativeNobjRecordBuffer+24),HL
            LD   A,(IX+23)
            LD   (NativeNobjRecordBuffer+26),A
            LD   L,(IX+24)
            LD   H,(IX+25)
            LD   (NativeNobjRecordBuffer+27),HL
            LD   L,(IX+26)
            LD   H,(IX+27)
            LD   (NativeNobjRecordBuffer+29),HL

            LD   B,0
            LD   C,(IX+28)
            LD   L,(IX+29)
            LD   H,(IX+30)
            LD   DE,NativeNobjRecordBuffer+32
            LDIR
            LD   A,(IX+31)
            LD   (DE),A
            INC  DE
            LD   (NativeNobjMapTailPointer),DE

            LD   L,(IX+32)
            LD   H,(IX+33)
            LD   (NativeNobjMapStatePointer),HL
            XOR  A
            LD   (NativeNobjMapBankOrdinal),A
NativeNobjMapBankLoop:
            ; usedLength = bank cursor - imageBase.
            LD   HL,(NativeNobjMapStatePointer)
            LD   C,(HL)
            INC  HL
            LD   B,(HL)
            INC  HL
            INC  HL
            INC  HL
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            LD   (NativeNobjMapAggregateLength),DE
            LD   H,B
            LD   L,C
            LD   E,(IX+5)
            LD   D,(IX+6)
            OR   A
            SBC  HL,DE
            LD   (NativeNobjMapUsedLength),HL

            LD   HL,(NativeNobjMapStatePointer)
            LD   DE,6
            ADD  HL,DE
            LD   (NativeNobjMapStatePointer),HL

            ; Every bank starts with the entry slot and runtime. The entry
            ; bank then carries startup and the initialized image.
            LD   L,(IX+5)
            LD   H,(IX+6)
            LD   BC,3
            ADD  HL,BC
            LD   C,(IX+34)
            LD   B,(IX+35)
            ADD  HL,BC
            LD   A,(NativeNobjMapBankOrdinal)
            CP   (IX+2)
            JR   NZ,NativeNobjMapRoBaseReadyForBank
            LD   C,(IX+36)
            LD   B,(IX+37)
            ADD  HL,BC
NativeNobjMapRoBaseReadyForBank:
            LD   (NativeNobjMapRoBase),HL

            LD   BC,0
            LD   A,(NativeNobjMapBankOrdinal)
            CP   (IX+2)
            JR   NZ,NativeNobjMapHasInitial
            BIT  0,(IX+1)
            JR   Z,NativeNobjMapHasInitial
            LD   C,(IX+15)
            LD   B,(IX+16)
NativeNobjMapHasInitial:
            LD   (NativeNobjMapInitialLength),BC

            LD   DE,(NativeNobjMapAggregateLength)
            LD   HL,(NativeNobjMapInitialLength)
            ADD  HL,DE
            LD   (NativeNobjMapRoLength),HL
            LD   A,D
            OR   E
            LD   HL,0
            JR   Z,NativeNobjMapAggregateReady
            LD   HL,(NativeNobjMapRoBase)
            LD   BC,(NativeNobjMapInitialLength)
            ADD  HL,BC
NativeNobjMapAggregateReady:
            LD   (NativeNobjMapAggregateBase),HL

            LD   HL,(NativeNobjMapTailPointer)
            LD   DE,(NativeNobjMapUsedLength)
            LD   (HL),E
            INC  HL
            LD   (HL),D
            INC  HL
            LD   DE,(NativeNobjMapRoBase)
            LD   BC,(NativeNobjMapRoLength)
            LD   A,B
            OR   C
            JR   NZ,NativeNobjMapRoBaseReady
            LD   DE,0
NativeNobjMapRoBaseReady:
            LD   (HL),E
            INC  HL
            LD   (HL),D
            INC  HL
            LD   (HL),C
            INC  HL
            LD   (HL),B
            INC  HL
            LD   DE,(NativeNobjMapAggregateBase)
            LD   (HL),E
            INC  HL
            LD   (HL),D
            INC  HL
            LD   DE,(NativeNobjMapAggregateLength)
            LD   (HL),E
            INC  HL
            LD   (HL),D
            INC  HL
            LD   (NativeNobjMapTailPointer),HL

            LD   A,(NativeNobjMapBankOrdinal)
            INC  A
            LD   (NativeNobjMapBankOrdinal),A
            CP   (IX+31)
            JP   C,NativeNobjMapBankLoop

            LD   A,(NativeNobjRecordBuffer+1)
            ADD  A,3
            LD   C,A
            LD   B,0
            LD   HL,(NativeNobjOutputHandle)
            LD   DE,NativeNobjRecordBuffer
            JP   NativeNobjWriteCovered

; Write one block to the final object and include it in the running CRC.
.routine in HL,DE,BC out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
NativeNobjWriteCovered:
            PUSH HL
            PUSH DE
            PUSH BC
            EX   DE,HL
            CALL NativeNobjCrcBlock
            POP  BC
            POP  DE
            POP  HL
            CALL OCWRITE
            RET

.routine in HL,BC out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
NativeNobjCrcBlock:
NativeNobjCrcLoop:
            LD   A,B
            OR   C
            RET  Z
            LD   A,(HL)
            INC  HL
            DEC  BC
            PUSH BC
            PUSH HL
            CALL NativeNobjCrcByte
            POP  HL
            POP  BC
            JR   NativeNobjCrcLoop

.routine in A out A,BC,DE,carry,zero clobbers sign,parity,halfCarry
NativeNobjCrcByte:
            LD   DE,(NativeNobjCrc)
            XOR  D
            LD   D,A
            LD   B,8
NativeNobjCrcBit:
            SLA  E
            RL   D
            JR   NC,NativeNobjCrcNext
            LD   A,E
            XOR  $21
            LD   E,A
            LD   A,D
            XOR  $10
            LD   D,A
NativeNobjCrcNext:
            DJNZ NativeNobjCrcBit
            LD   (NativeNobjCrc),DE
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
NativeNobjAbort:
            XOR  A
            LD   (NativeNobjAbortStatus),A
            LD   HL,NativeNobjImageHandle
            LD   B,3
NativeNobjAbortLoop:
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            INC  HL
            LD   A,D
            OR   E
            JR   Z,NativeNobjAbortNext
            PUSH HL
            PUSH BC
            EX   DE,HL
            LD   A,NOABORT
            CALL OCTERM
            JR   NC,NativeNobjAbortRestored
            LD   (NativeNobjAbortStatus),A
NativeNobjAbortRestored:
            POP  BC
            POP  HL
NativeNobjAbortNext:
            DJNZ NativeNobjAbortLoop
            XOR  A
            LD   HL,NativeNobjImageHandle
            LD   DE,NativeNobjImageHandle+1
            LD   BC,5
            LD   (HL),A
            LDIR
            LD   A,(NativeNobjAbortStatus)
            OR   A
            RET  Z
            SCF
            RET
