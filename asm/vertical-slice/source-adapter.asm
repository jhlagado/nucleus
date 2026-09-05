; Ordered source-byte adapter. Compatibility builds retain resident part
; descriptors; the native build obtains bounded chunks from the host vector.

.if AggregateCallSlices
.if NativeStreamingSource
; The native Z80 host supplies SourceInitializeParts and the bounded refill,
; token-pinning, part-transition, and end-unit entries outside compiler core.

.else
; A is a bounded part count and HL points to five-byte descriptors containing
; stable identity, source start, and source end. The source and descriptors
; remain resident until compilation finishes.
.routine in A,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
SourceInitializeParts:
            DEC  A
            CP   SRCPARTS
            JR   NC,SourcePartCapacityFailure
            LD   (SourcePartsRemaining),A

; Load the descriptor at HL and retain the address of the following one.
.routine in HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
SourceLoadPart:
            LD   A,(HL)
            INC  HL
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            INC  HL
            PUSH DE
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            INC  HL
            LD   (SourcePartDescriptorCursor),HL
            POP  HL
            ; Fall through with A=part, HL=start, and DE=end.
.endif
.endif

.routine in A,DE,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
SourceInitialize:
            LD   (SourcePartId),A
            LD   (SourceCursor),HL
            EX   DE,HL
            LD   (SourceEnd),HL
            XOR  A
            LD   H,A
            LD   L,A
            LD   (SourceOffset),HL
            LD   (SourceLineHasToken),HL
            INC  HL
            LD   (SourceLine),HL
            LD   (SourceColumn),HL
            RET

.if AggregateCallSlices
.routine noreturn
SourcePartCapacityFailure:
            XOR  A
            LD   H,A
            LD   L,A
            LD   D,A
            LD   E,A
            CALL SourceInitialize
            CALL TokenRecordStart
            CALL SetDiagInline
            .db  DiagnosticSourcePartCapacity
.endif

; Consume one byte and advance byte offset and byte column. Newline handling
; is separate because LF and CRLF each advance the logical line only once.
.routine out A,carry,zero clobbers sign,parity,halfCarry,DE,HL
SourceTake:
            CALL SourcePeek
            RET  C
            INC  HL
            LD   (SourceCursor),HL
.if NativeStreamingSource
            JP   SourceHostTakePosition
.else
            LD   HL,(SourceOffset)
            INC  HL
            LD   (SourceOffset),HL
            LD   HL,(SourceColumn)
            INC  HL
            LD   (SourceColumn),HL
            RET
.endif

; The tokenizer has three paths where a known-present byte is consumed and
; the following byte is inspected immediately. The helper falls through to
; SourcePeek so the pair retains full-width source state without a second
; call site.
.routine out A,carry,zero,HL clobbers sign,parity,halfCarry,DE
SourceTakePeek:
            CALL SourceTake

; Return the current source byte in A. Carry denotes the separate EOF event.
.routine out A,carry,zero,HL clobbers sign,parity,halfCarry,DE
SourcePeek:
            LD   HL,(SourceCursor)
            LD   DE,(SourceEnd)
            OR   A
            SBC  HL,DE
.if NativeStreamingSource
            ADD  HL,DE
            JR   NZ,SourcePeekByte
            ; A completed unit still retains SourcePartEnded. Beginning the
            ; next part clears it before installing that part's first chunk,
            ; so this one state bit distinguishes refill from logical EOF.
            LD   A,(SourcePartsRemaining)
            AND  SourcePartEnded
            JR   NZ,SourcePeekStreamEnd
            PUSH BC
            CALL SourceStreamRefill
            POP  BC
            RET  C
            LD   HL,(SourceCursor)
            JR   SourcePeekByte
SourcePeekStreamEnd:
            SCF
            RET
.else
.if AggregateCallSlices
.if TargetStreamingOutput
            CCF
            RET  C
            ADD  HL,DE
.else
            ADD  HL,DE
            JR   NZ,SourcePeekByte
            SCF
            RET
.endif
.else
            ADD  HL,DE
            JR   NZ,SourcePeekByte
            SCF
            RET
.endif
.endif
.routine in HL out A,carry,zero,HL clobbers sign,parity,halfCarry
SourcePeekByte:
            LD   A,(HL)
            OR   A
            RET

.if NativeStreamingSource
; Materialize one retained provider handle into the current-token cells. Both
; entry names share the same contract because every consumer needs the exact
; spelling length as well as its temporary readable pointer.
.routine in HL out A,HL,carry,zero clobbers sign,parity,halfCarry
SourceHostRestoreToken:
SourceHostMaterializeToken:
            PUSH BC
            PUSH DE
            CALL SourceHostMaterializeName
            LD   (TokenLexemePointer),HL
            LD   A,B
            LD   (TokenLength),A
            POP  DE
            POP  BC
            RET
.endif

.if AggregateCallSlices
.else
.routine out carry,zero clobbers sign,parity,halfCarry,A,HL
SourceFinishLine:
            LD   HL,(SourceLine)
            INC  HL
            LD   (SourceLine),HL
            LD   HL,1
            LD   (SourceColumn),HL
            OR   A
            RET
.endif
