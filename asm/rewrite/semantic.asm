; Checked fixed-width semantic transcript. Operation records are staged in the
; operand area and appended atomically. No consumer advances the live cursor
; while interpreting operands.

.routine in A out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
RewriteSemanticOperationWidth:
            OR   A
            JP   Z,RewriteSemanticInvalid
            CP   RewriteSemanticOperationCount+1
            JP   NC,RewriteSemanticInvalid
            DEC  A
            LD   E,A
            LD   D,0
            LD   HL,RewriteSemanticOperationWidthTable
            ADD  HL,DE
            LD   A,(HL)
            OR   A
            RET

; A is the operation ordinal. HL addresses exactly the declared operand bytes.
; Capacity and operation-count checks happen before the first transcript write.
.routine in A,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
RewriteSemanticAppend:
            LD   (RewriteSemanticPendingOperation),A
            LD   (RewriteSemanticPendingOperands),HL
            CALL RewriteSemanticOperationWidth
            LD   C,A
            LD   A,(RewriteSemanticBufferBase)
            CP   255
            JP   Z,RewriteSemanticCapacity
            LD   HL,RewriteSemanticBufferLimit
            LD   DE,(RewriteSemanticSinkCursor)
            OR   A
            SBC  HL,DE
            LD   A,H
            OR   A
            JR   NZ,RewriteSemanticAppendRoom
            LD   A,L
            CP   C
            JP   C,RewriteSemanticCapacity
RewriteSemanticAppendRoom:
            ; The operation count is the zero-based source-ledger index. All
            ; transcript capacity checks have completed, so this fixed word
            ; publication and the record append form one nonfailing commit.
            LD   A,(RewriteSemanticBufferBase)
            LD   L,A
            LD   H,0
            ADD  HL,HL
            LD   DE,RewriteSemanticSourceOffsetBase
            ADD  HL,DE
            LD   DE,(TokenStartOffset)
            LD   (HL),E
            INC  HL
            LD   (HL),D
            LD   HL,(RewriteSemanticPendingOperands)
            LD   A,(RewriteSemanticPendingOperation)
            LD   DE,(RewriteSemanticSinkCursor)
            LD   (DE),A
            INC  DE
            DEC  C
            JR   Z,RewriteSemanticAppendComplete
            LD   B,0
            LDIR
RewriteSemanticAppendComplete:
            LD   (RewriteSemanticSinkCursor),DE
            LD   HL,RewriteSemanticBufferBase
            INC  (HL)
            XOR  A
            RET

; Validate every operation ordinal and complete record boundary, then require
; the counted stream to end exactly at the sink cursor.
.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
RewriteSemanticValidate:
            LD   HL,RewriteSemanticPayloadBase
            LD   A,(RewriteSemanticBufferBase)
            LD   B,A
RewriteSemanticValidateNext:
            LD   DE,(RewriteSemanticSinkCursor)
            OR   A
            SBC  HL,DE
            ADD  HL,DE
            JP   NC,RewriteSemanticValidateAtEnd
            LD   A,B
            OR   A
            JP   Z,RewriteSemanticInvalid
            LD   A,(HL)
            PUSH BC
            PUSH HL
            CALL RewriteSemanticOperationWidth
            LD   C,A
            LD   B,0
            POP  HL
            ADD  HL,BC
            POP  BC
            LD   DE,(RewriteSemanticSinkCursor)
            PUSH HL
            OR   A
            SBC  HL,DE
            POP  HL
            JP   NC,RewriteSemanticValidateBoundary
            DJNZ RewriteSemanticValidateNext
            JP   RewriteSemanticInvalid
RewriteSemanticValidateBoundary:
            JP   NZ,RewriteSemanticInvalid
            DJNZ RewriteSemanticInvalid
            XOR  A
            RET
RewriteSemanticValidateAtEnd:
            JP   NZ,RewriteSemanticInvalid
            LD   A,B
            OR   A
            JP   NZ,RewriteSemanticInvalid
            RET

; Validate and walk without a target backend. This remains the R2 authority
; proof entry and shares the permanent record reader with target generation.
.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
RewriteSemanticDispatch:
            XOR  A
            JP   RewriteSemanticDispatchSelected

; Validate and walk while dispatching every operation to the backend. The
; current source offset is selected from the parallel ledger before any IMAGE
; byte can be emitted. The caller initializes the backend output/context.
.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
RewriteSemanticDispatchBackend:
            LD   A,1

.routine in A out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
RewriteSemanticDispatchSelected:
            LD   (RewriteSemanticPendingOperands),A
            CALL RewriteSemanticValidate
            LD   HL,RewriteSemanticPayloadBase
            LD   (RewriteSemanticReadCursor),HL
            LD   A,(RewriteSemanticBufferBase)
            LD   (RewriteSemanticReadRemaining),A
RewriteSemanticDispatchNext:
            LD   A,(RewriteSemanticReadRemaining)
            OR   A
            JR   Z,RewriteSemanticDispatchComplete
.if DebugHooks
            OUT  (DebugTraceSemanticStartPort),A
.endif
            LD   HL,(RewriteSemanticReadCursor)
            LD   A,(HL)
            LD   (RewriteSemanticPendingOperation),A
            CALL RewriteSemanticOperationWidth
            DEC  A
            LD   C,A
            LD   B,0
            LD   HL,(RewriteSemanticReadCursor)
            INC  HL
            LD   DE,RewriteSemanticOperandArea
            LD   A,C
            OR   A
            JR   Z,RewriteSemanticDispatchNoOperands
            LDIR
RewriteSemanticDispatchNoOperands:
            LD   (RewriteSemanticReadCursor),HL
            LD   A,(RewriteSemanticPendingOperands)
            OR   A
            JR   Z,RewriteSemanticDispatchAdvance
            LD   A,(RewriteSemanticBufferBase)
            LD   HL,RewriteSemanticReadRemaining
            SUB  (HL)
            LD   L,A
            LD   H,0
            ADD  HL,HL
            LD   DE,RewriteSemanticSourceOffsetBase
            ADD  HL,DE
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            EX   DE,HL
            CALL RewriteBackendSetCurrentSourceOffset
            LD   A,(RewriteSemanticPendingOperation)
            CALL RewriteBackendDispatchOperation
RewriteSemanticDispatchAdvance:
            LD   HL,RewriteSemanticReadRemaining
            DEC  (HL)
            JR   RewriteSemanticDispatchNext
RewriteSemanticDispatchComplete:
.if DebugHooks
            OUT  (DebugTraceSemanticEndPort),A
.endif
            XOR  A
            RET

.routine noreturn
RewriteSemanticCapacity:
            LD   A,DiagnosticSemanticCapacity
            JP   RewriteRaiseDiagnostic
.routine noreturn
RewriteSemanticInvalid:
            LD   A,DiagnosticInternalOperation
            JP   RewriteRaiseDiagnostic
