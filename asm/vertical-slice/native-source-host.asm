; Native windowed-source adapter. This code belongs to the Z80 host image,
; outside CompilerCodeEnd: it manages source storage lifetime without charging
; the 16 KiB compiler core. The compiler and host are linked against the same
; source-state ABI.

.routine in A out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
SourceInitializeParts:
            DEC  A
            CP   SourcePartCapacity
            JP   NC,SourcePartCapacityFailure
            LD   B,A
            XOR  A
            LD   HL,SourcePinSegmentStart
            LD   C,SourceHostStatus-SourcePinSegmentStart+1
_sourceInitializeNativeState:
            LD   (HL),A
            INC  HL
            DEC  C
            JP   NZ,_sourceInitializeNativeState
            LD   A,B
            LD   (SourcePartsRemaining),A
            JP   SourceStreamBeginPart

.routine noreturn
SourceHostRejectInvalid:
            LD   A,4                    ; native-host invalid status
            LD   (SourceHostStatus),A
            LD   SP,(CompilerAbortSp)
            SCF
            RET

; Capture the provider's event part ID without exposing its BC clobber to the
; tokenizer. A/DE/HL remain the public event result.
.routine out A,carry,zero,DE,HL clobbers sign,parity,halfCarry
SourceHostNextChunk:
            PUSH BC
            CALL HostSourceNextChunk
            JP   C,SourceHostFailure
            PUSH HL
            LD   HL,SourceProviderPartId
            LD   (HL),C
            POP  HL
            POP  BC
            RET

.routine in HL,B,C,DE out A,HL,carry,zero clobbers sign,parity,halfCarry
SourceHostRetainCurrentName:
            CALL HostRetainCurrentName
            RET  NC
            JP   SourceHostFailure

; Adapt the compiler's current-token cell to the host ABI's IX input. The
; compiler-side caller saves and restores its own IX around this entry.
.routine in HL,B out A,carry,zero,IX clobbers sign,parity,halfCarry,BC,DE,HL
SourceHostCompareCurrentName:
            LD   IX,(TokenLexemePointer)
            CALL HostCompareCurrentName
            RET  NC
            JP   SourceHostFailure

.routine in HL out A,B,HL,carry,zero clobbers sign,parity,halfCarry
SourceHostMaterializeName:
            CALL HostMaterializeName
            RET  NC
.routine noreturn
SourceHostFailure:
            LD   (SourceHostStatus),A
            LD   SP,(CompilerAbortSp)
            SCF
            RET

; Advance the compiler's full-width source position for the byte in A. This
; belongs with the native source adapter rather than the 16 KiB compiler. A
; newline is preflighted here and completed by TokenizerFinishLine.
.routine in A out A,carry,zero clobbers sign,parity,halfCarry,DE,HL
SourceHostTakePosition:
            LD   D,A
            CP   13
            JP   Z,SourceHostCheckLine
            CP   10
            JP   NZ,SourceHostLineReady
SourceHostCheckLine:
            LD   HL,(SourceLine)
            INC  HL
            LD   A,H
            OR   L
            JP   Z,SourceHostPositionCapacityFailure
SourceHostLineReady:
            LD   HL,(SourceOffset)
            INC  HL
            LD   A,H
            OR   L
            JP   Z,SourceHostPositionCapacityFailure
            PUSH HL
            LD   A,D
            CP   10
            JP   Z,SourceHostCommitOffset
            CP   13
            JP   Z,SourceHostCommitOffset
            LD   HL,(SourceColumn)
            INC  HL
            LD   A,H
            OR   L
            JP   Z,SourceHostColumnCapacityFailure
            LD   (SourceColumn),HL
SourceHostCommitOffset:
            POP  HL
            LD   (SourceOffset),HL
            LD   A,D
            OR   A
            RET
SourceHostColumnCapacityFailure:
            POP  HL
SourceHostPositionCapacityFailure:
            LD   HL,SourceOffset
            LD   DE,TokenStartOffset
            CALL CompilerCopyPosition
            CALL SetDiagInline
            .db  DiagnosticSourcePositionCapacity

.routine out HL
SourcePinResetToken:
            LD   HL,0
            LD   (SourcePinScratchCursor),HL
            RET

.routine out HL
SourcePinBeginToken:
            LD   HL,1
            LD   (SourcePinScratchCursor),HL
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
SourceStreamBeginPart:
            CALL SourceHostNextChunk
            CP   1
            JP   NZ,SourceHostRejectInvalid
            LD   A,(SourceProviderPartId)
            OR   A
            JP   Z,SourceHostRejectInvalid
            LD   HL,0
            LD   D,H
            LD   E,L
            CALL SourceInitialize
            CALL SourceStreamRefill
            OR   A
            RET

; Append the current live-chunk portion of an active token before a refill can
; invalidate it. Zero means no active token; one means no refill has occurred.
.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
SourcePinBeforeRefill:
            LD   HL,(SourcePinScratchCursor)
            LD   A,H
            OR   L
            RET  Z
            DEC  HL
            LD   A,H
            OR   L
            JP   NZ,SourcePinBeforeRefillLater
            LD   HL,(TokenLexemePointer)
            LD   DE,NativeSourceTokenBase
            JP   SourcePinCopySegment
SourcePinBeforeRefillLater:
            LD   HL,(SourcePinSegmentStart)
            LD   DE,(SourcePinScratchCursor)
            JP   SourcePinCopySegment

.routine in DE,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
SourcePinCopySegment:
            PUSH DE
            PUSH HL
            LD   HL,(SourceCursor)
            POP  DE
            OR   A
            SBC  HL,DE
            LD   B,H
            LD   C,L
            PUSH DE
            POP  HL
            POP  DE
            LD   A,B
            OR   C
            RET  Z
            LDIR
            LD   (SourcePinScratchCursor),DE
            LD   HL,NativeSourceTokenBase
            LD   (TokenLexemePointer),HL
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,DE,HL
SourcePinFinishToken:
            PUSH BC
            CALL SourcePinFinishTokenBody
            POP  BC
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
SourcePinFinishTokenBody:
            LD   HL,(SourcePinScratchCursor)
            LD   A,H
            OR   L
            RET  Z
            DEC  HL
            LD   A,H
            OR   L
            RET  Z
            LD   HL,(SourcePinSegmentStart)
            LD   DE,(SourcePinScratchCursor)
            JP   SourcePinCopySegment

.routine in DE out A,carry,zero,HL clobbers sign,parity,halfCarry,DE
SourceStreamBytesEvent:
            LD   A,D
            OR   E
            JP   Z,SourceHostRejectInvalid
            PUSH BC
            LD   A,(SourceProviderPartId)
            LD   C,A
            LD   A,(SourcePartId)
            CP   C
            JP   NZ,SourceHostRejectInvalid
            CALL SourceStreamBytes
            POP  BC
            RET
.routine out A,carry,zero,HL clobbers sign,parity,halfCarry,DE
SourceStreamRefill:
            PUSH BC
            CALL SourcePinBeforeRefill
            POP  BC
            CALL SourceHostNextChunk
            JP   SourceStreamRefillEvent

.routine in A,DE,HL out A,carry,zero,HL clobbers sign,parity,halfCarry,DE
SourceStreamRefillEvent:
            OR   A
            JP   Z,SourceStreamBytesEvent
            CP   2
            JP   NZ,SourceHostRejectInvalid
            LD   A,(SourceProviderPartId)
            LD   HL,SourcePartId
            CP   (HL)
            JP   NZ,SourceHostRejectInvalid
            ; PinBeforeRefill already copied through SourceCursor. An end event
            ; supplies no replacement chunk, so make the remaining segment
            ; explicitly empty for SourcePinFinishToken.
            LD   HL,(SourceCursor)
            LD   (SourcePinSegmentStart),HL
            LD   HL,SourcePartsRemaining
            SET  6,(HL)
            SCF
            RET

.routine in DE,HL out A,carry,zero,HL clobbers sign,parity,halfCarry,DE
SourceStreamBytes:
            LD   (SourceCursor),HL
            ADD  HL,DE
            LD   (SourceEnd),HL
            LD   HL,(SourceCursor)
            LD   DE,(SourcePinScratchCursor)
            LD   A,D
            OR   E
            CALL Z,SourceStreamUnpinnedChunk
            RET  Z
            LD   (SourcePinSegmentStart),HL
            OR   A
            RET

.routine in HL out A,carry,zero,HL clobbers sign,parity,halfCarry
SourceStreamUnpinnedChunk:
            LD   (TokenLexemePointer),HL
            OR   A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
SourceStreamFinishUnit:
            LD   A,(SourceProviderPartId)
            OR   A
            RET  Z
            CALL SourceHostNextChunk
            CP   3
            JP   NZ,SourceHostRejectInvalid
            XOR  A
            LD   (SourceProviderPartId),A
            RET
