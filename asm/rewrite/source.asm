; Ordered multipart source adapter for the replacement compiler.

; Load the five-byte descriptor at HL and retain the address of its successor.
.routine in HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
RewriteSourceLoadPart:
            LD   DE,SourcePartId
            LD   BC,5
            LDIR
            LD   (RewriteSourceNextDescriptor),HL
            LD   HL,(RewriteSourceDescriptorStart)
            LD   (RewriteSourceCursor),HL
            LD   HL,0
            LD   (RewriteSourceOffset),HL
            LD   (RewriteSourceLineHasToken),HL
            RET

; A is the part count and HL points at retained five-byte descriptors.
.routine in A,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
RewriteSourceInitializeParts:
            OR   A
            JR   Z,RewriteSourcePartCapacityFailure
            CP   SourcePartCapacity+1
            JR   NC,RewriteSourcePartCapacityFailure
            DEC  A
            LD   (RewriteSourcePartsRemaining),A
            JP   RewriteSourceLoadPart
RewriteSourcePartCapacityFailure:
            XOR  A
            LD   (SourcePartId),A
            LD   HL,0
            LD   (TokenStartOffset),HL
            LD   A,DiagnosticSourcePartCapacity
            JP   RewriteRaiseDiagnostic

; Return the current byte in A. Carry denotes the separate physical EOF event.
.routine out A,carry,zero clobbers sign,parity,halfCarry,DE,HL
RewriteSourcePeek:
            LD   HL,(RewriteSourceCursor)
            LD   DE,(RewriteSourceEnd)
            OR   A
            SBC  HL,DE
            ADD  HL,DE
            JR   Z,RewriteSourcePeekEof
            LD   A,(HL)
            OR   A
            RET
RewriteSourcePeekEof:
            SCF
            RET

; Consume one physical byte and advance the part-relative byte position.
.routine out A,carry,zero clobbers sign,parity,halfCarry,DE,HL
RewriteSourceTake:
            CALL RewriteSourcePeek
            RET  C
            LD   HL,(RewriteSourceCursor)
            INC  HL
            LD   (RewriteSourceCursor),HL
            LD   HL,(RewriteSourceOffset)
            INC  HL
            LD   (RewriteSourceOffset),HL
            OR   A
            RET
