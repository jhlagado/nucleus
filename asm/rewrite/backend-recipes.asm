; First replacement backend recipe interpreter. Recipes are declared data;
; compiler-executed Z80 remains ordinary mnemonics. All directories retain
; complete addresses and impose no origin policy.

            .include "../vertical-slice/nucleus-runtime-identity.asmi"

; HL is the first writable target byte, DE its exclusive limit, and IX a
; complete RewriteBackendContextSize-byte deployment link context.
.routine in HL,DE,IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
RewriteBackendInitialize:
            LD   (RewriteBackendOutputCursor),HL
            LD   (RewriteBackendOutputLimit),DE
            PUSH IX
            POP  HL
            LD   DE,RewriteBackendRuntimeBase
            LD   BC,RewriteBackendContextSize
            LDIR
            XOR  A
            LD   (RewriteBackendBooleanFixupDepth),A
            LD   (RewriteBackendFixupCount),A
            LD   HL,RewriteBackendLabelValidBase
            LD   B,RewriteBackendLabelCapacity
RewriteBackendInitializeLabels:
            LD   (HL),A
            INC  HL
            DJNZ RewriteBackendInitializeLabels
            RET

; Append one target byte to the bounded prototype sink. The later target/NOBJ
; milestone replaces only this sink boundary, not the recipe interpreter.
.routine in A out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
RewriteBackendEmitByte:
            LD   B,A
            LD   HL,(RewriteBackendOutputCursor)
            LD   DE,(RewriteBackendOutputLimit)
            OR   A
            SBC  HL,DE
            JP   NC,RewriteBackendCapacity
            ADD  HL,DE
            LD   A,B
            LD   (HL),A
            INC  HL
            LD   (RewriteBackendOutputCursor),HL
            XOR  A
            RET

; Dispatch one already-prefetched semantic operation in A. The semantic
; descriptor supplies a dense recipe or escape selector. Both generated
; directories retain complete handler addresses; no compiler origin bits are
; packed into either selector.
.routine in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteBackendDispatchOperation:
            LD   (RewriteBackendCurrentOperation),A
            OR   A
            JP   Z,RewriteBackendInvalid
            CP   RewriteSemanticOperationCount+1
            JP   NC,RewriteBackendInvalid
            DEC  A
            LD   E,A
            LD   D,0
            LD   L,E
            LD   H,D
            ADD  HL,HL
            ADD  HL,HL
            ADD  HL,DE
            LD   DE,RewriteSemanticOperationDescriptorTable
            ADD  HL,DE
            INC  HL
            LD   B,(HL)
            INC  HL
            INC  HL
            LD   A,(HL)
            BIT  7,B
            JR   NZ,RewriteBackendDispatchEscape
            CP   RewriteRecipeCount
            JP   NC,RewriteBackendInvalid
            LD   L,A
            LD   H,0
            ADD  HL,HL
            LD   DE,RewriteBackendRecipeDirectory
            ADD  HL,DE
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            LD   A,D
            OR   E
            JP   Z,RewriteBackendInvalid
            EX   DE,HL
            JP   RewriteBackendRunRecipe

RewriteBackendDispatchEscape:
            CP   RewriteEscapeCount
            JP   NC,RewriteBackendInvalid
            LD   L,A
            LD   H,0
            ADD  HL,HL
            LD   DE,RewriteBackendEscapeDirectory
            ADD  HL,DE
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            LD   A,D
            OR   E
            JP   Z,RewriteBackendInvalid
            EX   DE,HL
            JP   (HL)

; HL is the current generated recipe instruction. Literal target bytes and
; address-directory words are recipe data, not compiler-executed opcodes.
.routine in HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteBackendRunRecipe:
RewriteBackendRecipeNext:
            LD   A,(HL)
            INC  HL
            CP   RewriteBackendRecipeInstructionCount
            JP   NC,RewriteBackendInvalid
            OR   A
            RET  Z
            CP   RewriteBackendRecipeEmit
            JR   Z,RewriteBackendRecipeEmitLiteral
            CP   RewriteBackendRecipeOperandByte
            JR   Z,RewriteBackendRecipeEmitOperandByte
            CP   RewriteBackendRecipeOperandWord
            JR   Z,RewriteBackendRecipeEmitOperandWord
            CP   RewriteBackendRecipeComplementByte
            JR   Z,RewriteBackendRecipeEmitComplement
            CP   RewriteBackendRecipeDispatch
            JP   Z,RewriteBackendRecipeDoDispatch
            CP   RewriteBackendRecipeRuntimeCall
            JP   Z,RewriteBackendRecipeEmitRuntimeCall
            CP   RewriteBackendRecipeRelativeFixupPush
            JP   Z,RewriteBackendRecipePushRelativeFixup
            CP   RewriteBackendRecipeRelativeFixupPatch
            JP   Z,RewriteBackendRecipePatchRelativeFixup
            CP   RewriteBackendRecipeAddressWord
            JP   Z,RewriteBackendRecipeEmitAddressWord
            CP   RewriteBackendRecipeDefineLabel
            JP   Z,RewriteBackendRecipeDoDefineLabel
            JP   RewriteBackendRecipeEmitAbsoluteFixup

RewriteBackendRecipeEmitLiteral:
            LD   B,(HL)
            INC  HL
RewriteBackendRecipeEmitLiteralLoop:
            LD   A,(HL)
            INC  HL
            PUSH BC
            PUSH HL
            CALL RewriteBackendEmitByte
            POP  HL
            POP  BC
            DJNZ RewriteBackendRecipeEmitLiteralLoop
            JP   RewriteBackendRecipeNext

RewriteBackendRecipeEmitOperandByte:
            LD   E,(HL)
            INC  HL
            PUSH HL
            LD   D,0
            LD   HL,RewriteSemanticOperandArea
            ADD  HL,DE
            LD   A,(HL)
            CALL RewriteBackendEmitByte
            POP  HL
            JP   RewriteBackendRecipeNext

RewriteBackendRecipeEmitOperandWord:
            LD   E,(HL)
            INC  HL
            PUSH HL
            LD   D,0
            LD   HL,RewriteSemanticOperandArea
            ADD  HL,DE
            LD   C,(HL)
            INC  HL
            LD   B,(HL)
            PUSH BC
            LD   A,C
            CALL RewriteBackendEmitByte
            POP  BC
            LD   A,B
            CALL RewriteBackendEmitByte
            POP  HL
            JR   RewriteBackendRecipeNext

; Emit the Z80 IX displacement -(offset+1+adjustment). CPL computes the first
; negative displacement directly; the adjustment selects a following byte.
RewriteBackendRecipeEmitComplement:
            LD   E,(HL)
            INC  HL
            LD   C,(HL)
            INC  HL
            PUSH HL
            LD   D,0
            LD   HL,RewriteSemanticOperandArea
            ADD  HL,DE
            LD   A,(HL)
            CPL
            SUB  C
            CALL RewriteBackendEmitByte
            POP  HL
            JP   RewriteBackendRecipeNext

; Add a semantic word operand to one full-width deployment base and emit the
; complete target address. The recipe stores context and operand offsets, not
; address bits or placement assumptions.
RewriteBackendRecipeEmitAddressWord:
            LD   E,(HL)
            INC  HL
            LD   C,(HL)
            INC  HL
            PUSH HL
            LD   D,0
            LD   HL,RewriteBackendRuntimeBase
            ADD  HL,DE
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            LD   L,C
            LD   H,0
            LD   BC,RewriteSemanticOperandArea
            ADD  HL,BC
            LD   C,(HL)
            INC  HL
            LD   B,(HL)
            EX   DE,HL
            ADD  HL,BC
            CALL RewriteBackendEmitWord
            POP  HL
            JP   RewriteBackendRecipeNext

RewriteBackendRecipeDoDefineLabel:
            LD   E,(HL)
            INC  HL
            PUSH HL
            LD   D,0
            LD   HL,RewriteSemanticOperandArea
            ADD  HL,DE
            LD   A,(HL)
            CALL RewriteBackendDefineLabel
            POP  HL
            JP   RewriteBackendRecipeNext

RewriteBackendRecipeEmitAbsoluteFixup:
            LD   E,(HL)
            INC  HL
            LD   A,(HL)
            INC  HL
            PUSH HL
            LD   (RewriteBackendTrapReason),A
            LD   D,0
            LD   HL,RewriteSemanticOperandArea
            ADD  HL,DE
            LD   A,(HL)
            LD   (RewriteBackendTrapSourceOffset),A
            LD   A,(RewriteBackendTrapReason)
            CALL RewriteBackendEmitByte
            LD   HL,(RewriteBackendOutputCursor)
            LD   D,H
            LD   E,L
            PUSH DE
            XOR  A
            CALL RewriteBackendEmitByte
            XOR  A
            CALL RewriteBackendEmitByte
            POP  DE
            LD   A,(RewriteBackendTrapSourceOffset)
            CALL RewriteBackendRecordFixup
            POP  HL
            JP   RewriteBackendRecipeNext

; A family recipe selects an operation-specific fragment through an inline
; full-address directory. Zero is an explicit unavailable-family member.
RewriteBackendRecipeDoDispatch:
            LD   A,(RewriteBackendCurrentOperation)
            SUB  (HL)
            INC  HL
            LD   B,(HL)
            INC  HL
            CP   B
            JP   NC,RewriteBackendInvalid
            LD   E,A
            LD   D,0
            ADD  HL,DE
            ADD  HL,DE
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            LD   A,D
            OR   E
            JP   Z,RewriteBackendInvalid
            EX   DE,HL
            JP   RewriteBackendRecipeNext

; A runtime-call recipe stores an identity-fixed helper offset. The linked
; base is deployment data, and the target CALL receives the complete sum.
RewriteBackendRecipeEmitRuntimeCall:
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            INC  HL
            PUSH HL
            LD   HL,(RewriteBackendRuntimeBase)
            ADD  HL,DE
            LD   (RewriteBackendRuntimeCallAddress),HL
            LD   A,$CD                    ; CALL nn
            CALL RewriteBackendEmitByte
            LD   A,(RewriteBackendRuntimeCallAddress)
            CALL RewriteBackendEmitByte
            LD   A,(RewriteBackendRuntimeCallAddress+1)
            CALL RewriteBackendEmitByte
            POP  HL
            JP   RewriteBackendRecipeNext

; Emit a JR placeholder and retain its operand address. Boolean short-circuit
; nesting uses a bounded word stack inside dead initializer scratch.
RewriteBackendRecipePushRelativeFixup:
            LD   A,(RewriteBackendBooleanFixupDepth)
            CP   RewriteBackendBooleanFixupCapacity
            JP   NC,RewriteBackendBooleanFixupCapacityFailure
            PUSH HL
            LD   A,$18                    ; JR displacement
            CALL RewriteBackendEmitByte
            LD   HL,(RewriteBackendOutputCursor)
            LD   (RewriteBackendRuntimeCallAddress),HL
            XOR  A
            CALL RewriteBackendEmitByte
            LD   A,(RewriteBackendBooleanFixupDepth)
            LD   E,A
            LD   D,0
            LD   HL,RewriteBackendBooleanFixupBase
            ADD  HL,DE
            ADD  HL,DE
            LD   DE,(RewriteBackendRuntimeCallAddress)
            LD   (HL),E
            INC  HL
            LD   (HL),D
            LD   HL,RewriteBackendBooleanFixupDepth
            INC  (HL)
            POP  HL
            JP   RewriteBackendRecipeNext

; Patch the most recent short-circuit edge to the current output cursor.
RewriteBackendRecipePatchRelativeFixup:
            PUSH HL
            LD   A,(RewriteBackendBooleanFixupDepth)
            OR   A
            JP   Z,RewriteBackendInvalid
            DEC  A
            LD   (RewriteBackendBooleanFixupDepth),A
            LD   E,A
            LD   D,0
            LD   HL,RewriteBackendBooleanFixupBase
            ADD  HL,DE
            ADD  HL,DE
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            LD   HL,(RewriteBackendOutputCursor)
            INC  DE
            OR   A
            SBC  HL,DE
            LD   C,L
            LD   A,C
            ADD  A,A
            SBC  A,A
            CP   H
            JP   NZ,RewriteBackendFixupRangeFailure
            DEC  DE
            LD   A,C
            LD   (DE),A
            POP  HL
            JP   RewriteBackendRecipeNext

; Define and later resolve absolute control-flow operands without packing the
; label ordinal, bank, or either address. All three remain separate fields.
.routine in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
RewriteBackendDefineLabel:
            CP   RewriteBackendLabelCapacity
            JP   NC,RewriteBackendControlLabelCapacityFailure
            LD   C,A
            LD   B,0
            LD   HL,RewriteBackendLabelValidBase
            ADD  HL,BC
            LD   A,(HL)
            OR   A
            JP   NZ,RewriteBackendInvalid
            INC  (HL)
            LD   HL,RewriteBackendLabelBankBase
            ADD  HL,BC
            LD   A,(RewriteBackendOutputBank)
            LD   (HL),A
            LD   L,C
            LD   H,0
            ADD  HL,HL
            LD   DE,RewriteBackendLabelAddressBase
            ADD  HL,DE
            LD   DE,(RewriteBackendOutputCursor)
            LD   (HL),E
            INC  HL
            LD   (HL),D
            XOR  A
            RET

.routine in A,DE out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteBackendRecordFixup:
            CP   RewriteBackendLabelCapacity
            JP   NC,RewriteBackendControlLabelCapacityFailure
            LD   C,A
            LD   A,(RewriteBackendFixupCount)
            CP   RewriteBackendFixupCapacity
            JP   NC,RewriteBackendControlFixupCapacityFailure
            LD   L,A
            LD   H,0
            ADD  HL,HL
            ADD  HL,HL
            LD   B,0
            LD   A,C
            LD   BC,RewriteBackendFixupBase
            ADD  HL,BC
            LD   (HL),A
            INC  HL
            LD   A,(RewriteBackendOutputBank)
            LD   (HL),A
            INC  HL
            LD   (HL),E
            INC  HL
            LD   (HL),D
            LD   HL,RewriteBackendFixupCount
            INC  (HL)
            XOR  A
            RET

; Resolve all label operands only after semantic emission completes. A bank
; mismatch is an internal lowering error: source-level structured control may
; not cross a generated bank boundary.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteBackendResolveFixups:
            LD   A,(RewriteBackendFixupCount)
            OR   A
            RET  Z
            LD   (RewriteBackendTrapReason),A
            LD   IX,RewriteBackendFixupBase
RewriteBackendResolveFixupNext:
            LD   C,(IX+0)
            LD   B,0
            LD   HL,RewriteBackendLabelValidBase
            ADD  HL,BC
            LD   A,(HL)
            OR   A
            JP   Z,RewriteBackendInvalid
            LD   HL,RewriteBackendLabelBankBase
            ADD  HL,BC
            LD   A,(HL)
            CP   (IX+1)
            JP   NZ,RewriteBackendInvalid
            LD   L,C
            LD   H,0
            ADD  HL,HL
            LD   BC,RewriteBackendLabelAddressBase
            ADD  HL,BC
            LD   C,(HL)
            INC  HL
            LD   H,(HL)
            LD   L,C
            LD   E,(IX+2)
            LD   D,(IX+3)
            LD   A,L
            LD   (DE),A
            INC  DE
            LD   A,H
            LD   (DE),A
            INC  IX
            INC  IX
            INC  IX
            INC  IX
            LD   HL,RewriteBackendTrapReason
            DEC  (HL)
            JP   NZ,RewriteBackendResolveFixupNext
            XOR  A
            LD   (RewriteBackendFixupCount),A
            RET

; Shared escape-emission primitives. These produce target instruction bytes;
; the compiler executes only the mnemonics below. Full addresses always come
; from the deployment context or the semantic operand buffer.
.routine in HL out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
RewriteBackendEmitWord:
            LD   (RewriteBackendRuntimeCallAddress),HL
            LD   A,(RewriteBackendRuntimeCallAddress)
            CALL RewriteBackendEmitByte
            LD   A,(RewriteBackendRuntimeCallAddress+1)
            JP   RewriteBackendEmitByte

.routine in A,HL out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
RewriteBackendEmitOpcodeWord:
            PUSH HL
            CALL RewriteBackendEmitByte
            POP  HL
            JP   RewriteBackendEmitWord

.routine in DE out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
RewriteBackendEmitRuntimeOffset:
            LD   HL,(RewriteBackendRuntimeBase)
            ADD  HL,DE
            LD   A,$CD                    ; CALL nn
            JP   RewriteBackendEmitOpcodeWord

; A is a target JR opcode. DE returns the displacement-byte address.
.routine in A out A,DE,carry,zero clobbers sign,parity,halfCarry,B,HL
RewriteBackendEmitRelativePlaceholder:
            CALL RewriteBackendEmitByte
            LD   HL,(RewriteBackendOutputCursor)
            LD   D,H
            LD   E,L
            PUSH DE
            XOR  A
            CALL RewriteBackendEmitByte
            POP  DE
            RET

; DE is a previously emitted JR displacement byte.
.routine in DE out A,DE,carry,zero clobbers sign,parity,halfCarry,C,HL
RewriteBackendPatchRelative:
            LD   HL,(RewriteBackendOutputCursor)
            INC  DE
            OR   A
            SBC  HL,DE
            LD   C,L
            LD   A,C
            ADD  A,A
            SBC  A,A
            CP   H
            JP   NZ,RewriteBackendFixupRangeFailure
            DEC  DE
            LD   A,C
            LD   (DE),A
            XOR  A
            RET

; Emit LD A,n for a byte retained in RewriteBackendTrapReason.
.routine in A out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
RewriteBackendEmitLoadAImmediate:
            LD   (RewriteBackendTrapReason),A
            LD   A,$3E
            CALL RewriteBackendEmitByte
            LD   A,(RewriteBackendTrapReason)
            JP   RewriteBackendEmitByte

; DE is a target-state-relative byte address; runtime A is stored there.
.routine in DE out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
RewriteBackendEmitStateStoreA:
            LD   HL,(RewriteBackendStateBase)
            ADD  HL,DE
            LD   A,$32                    ; LD (nn),A
            JP   RewriteBackendEmitOpcodeWord

; A is the runtime trap reason and HL is the source offset. The emitted tail
; restores the root frame, publishes the complete trap record, and transfers
; to the local terminal or the identity-defined far-jump vector.
.routine in A,HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteBackendEmitTrap:
            LD   (RewriteBackendTrapReason),A
            LD   (RewriteBackendTrapSourceOffset),HL

            LD   A,$21                    ; LD HL,sourceOffset
            CALL RewriteBackendEmitOpcodeWord
            LD   A,(RewriteBackendTrapReason)
            CALL RewriteBackendEmitLoadAImmediate

            LD   A,$ED                    ; LD SP,(nn)
            CALL RewriteBackendEmitByte
            LD   A,$7B
            CALL RewriteBackendEmitByte
            LD   HL,(RewriteBackendStateBase)
            LD   DE,17                    ; RootSP-StateBase
            ADD  HL,DE
            CALL RewriteBackendEmitWord

            LD   A,$DD                    ; LD IX,(nn)
            CALL RewriteBackendEmitByte
            LD   A,$2A
            CALL RewriteBackendEmitByte
            LD   HL,(RewriteBackendStateBase)
            LD   DE,19                    ; RootIX-StateBase
            ADD  HL,DE
            CALL RewriteBackendEmitWord

            LD   A,$F5                    ; PUSH AF
            CALL RewriteBackendEmitByte
            LD   A,$AF                    ; XOR A
            CALL RewriteBackendEmitByte
            LD   DE,6                     ; ActivationDepth-StateBase
            CALL RewriteBackendEmitStateStoreA
            LD   A,$F1                    ; POP AF
            CALL RewriteBackendEmitByte
            LD   DE,1                     ; TrapNumber-StateBase
            CALL RewriteBackendEmitStateStoreA
            LD   A,$AF                    ; XOR A
            CALL RewriteBackendEmitByte
            LD   DE,2                     ; TrapRoutine-StateBase
            CALL RewriteBackendEmitStateStoreA
            LD   HL,(RewriteBackendStateBase)
            LD   DE,3                     ; TrapOffset-StateBase
            ADD  HL,DE
            LD   A,$22                    ; LD (nn),HL
            CALL RewriteBackendEmitOpcodeWord
            LD   A,3                      ; RunTrapped
            CALL RewriteBackendEmitLoadAImmediate
            LD   DE,0                     ; RunState-StateBase
            CALL RewriteBackendEmitStateStoreA

            LD   A,(RewriteBackendEntryBank)
            LD   B,A
            LD   A,(RewriteBackendOutputBank)
            CP   B
            JR   Z,RewriteBackendEmitTrapLocal
            LD   A,B
            CALL RewriteBackendEmitLoadAImmediate
            LD   HL,(RewriteBackendTerminalAddress)
            LD   A,$21                    ; LD HL,nn
            CALL RewriteBackendEmitOpcodeWord
            LD   HL,(RewriteBackendVectorBase)
            LD   DE,30                    ; far-jump vector ordinal 10 * 3
            ADD  HL,DE
            JR   RewriteBackendEmitTrapJump
RewriteBackendEmitTrapLocal:
            LD   HL,(RewriteBackendTerminalAddress)
RewriteBackendEmitTrapJump:
            LD   A,$C3                    ; JP nn
            JP   RewriteBackendEmitOpcodeWord

; Patch the retained success branch after a terminal trap body.
.routine in DE out A,DE,carry,zero clobbers sign,parity,halfCarry,C,HL
RewriteBackendEscapePatchSuccess:
            JP   RewriteBackendPatchRelative

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteBackendEscapeNarrowU8:
            LD   A,$E1                    ; POP HL / LD A,H / OR A
            CALL RewriteBackendEmitByte
            LD   A,$7C
            CALL RewriteBackendEmitByte
            LD   A,$B7
            CALL RewriteBackendEmitByte
            LD   A,$28                    ; JR Z,success
            CALL RewriteBackendEmitRelativePlaceholder
            LD   (RewriteBackendRelativeOperand),DE
            LD   HL,(RewriteSemanticOperandArea+RewriteSemanticNarrowU8OperandSourceOffsetOffset)
            LD   A,2                      ; narrowing trap
            CALL RewriteBackendEmitTrap
            LD   DE,(RewriteBackendRelativeOperand)
            CALL RewriteBackendEscapePatchSuccess
            LD   A,$E5                    ; PUSH HL
            JP   RewriteBackendEmitByte

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteBackendEscapeConvertInteger:
            LD   A,$E1                    ; POP HL
            CALL RewriteBackendEmitByte
            LD   A,$3E                    ; LD A,sourceType
            CALL RewriteBackendEmitByte
            LD   A,(RewriteSemanticOperandArea+RewriteSemanticConvertIntegerOperandSourceTypeOffset)
            CALL RewriteBackendEmitByte
            LD   A,$0E                    ; LD C,targetType
            CALL RewriteBackendEmitByte
            LD   A,(RewriteSemanticOperandArea+RewriteSemanticConvertIntegerOperandTargetTypeOffset)
            CALL RewriteBackendEmitByte
            LD   DE,NucleusRuntimeConvertIntegerOffset
            CALL RewriteBackendEmitRuntimeOffset
            LD   A,$30                    ; JR NC,success
            CALL RewriteBackendEmitRelativePlaceholder
            LD   (RewriteBackendRelativeOperand),DE
            LD   HL,(RewriteSemanticOperandArea+RewriteSemanticConvertIntegerOperandSourceOffsetOffset)
            LD   A,(RewriteSemanticOperandArea+RewriteSemanticConvertIntegerOperandTargetTypeOffset)
            RLCA
            LD   A,2                      ; ordinary narrowing
            JR   NC,RewriteBackendEscapeConvertTrapReady
            DEC  A                        ; signed index conversion is bounds
RewriteBackendEscapeConvertTrapReady:
            CALL RewriteBackendEmitTrap
            LD   DE,(RewriteBackendRelativeOperand)
            CALL RewriteBackendEscapePatchSuccess
            LD   A,$E5                    ; PUSH HL
            JP   RewriteBackendEmitByte

; Common unsigned divide/modulo lowering. Operation identity selects the
; runtime helper and whether the canonical result is one or two bytes wide.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteBackendEscapeDivideUnsigned:
            LD   A,(RewriteBackendCurrentOperation)
            SUB  RewriteSemanticDivide8
            CP   4
            JP   NC,RewriteBackendInvalid
            LD   (RewriteBackendTrapReason),A
            LD   A,$D1                    ; POP DE / POP HL
            CALL RewriteBackendEmitByte
            LD   A,$E1
            CALL RewriteBackendEmitByte
            LD   A,(RewriteBackendTrapReason)
            BIT  1,A
            LD   DE,NucleusRuntimeDivideU16Offset
            JR   Z,RewriteBackendEscapeDivideHelperReady
            LD   DE,NucleusRuntimeModuloU16Offset
RewriteBackendEscapeDivideHelperReady:
            CALL RewriteBackendEmitRuntimeOffset
            LD   A,$30                    ; JR NC,success
            CALL RewriteBackendEmitRelativePlaceholder
            LD   (RewriteBackendRelativeOperand),DE
            LD   HL,(RewriteSemanticOperandArea+RewriteSemanticDivide8OperandSourceOffsetOffset)
            LD   A,3                      ; division trap
            CALL RewriteBackendEmitTrap
            LD   DE,(RewriteBackendRelativeOperand)
            CALL RewriteBackendEscapePatchSuccess
            LD   A,(RewriteBackendCurrentOperation)
            SUB  RewriteSemanticDivide8
            AND  1
            JR   NZ,RewriteBackendEscapeDividePush
            LD   A,$26                    ; LD H,0 for byte result
            CALL RewriteBackendEmitByte
            XOR  A
            CALL RewriteBackendEmitByte
RewriteBackendEscapeDividePush:
            LD   A,$E5                    ; PUSH HL
            JP   RewriteBackendEmitByte

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteBackendEscapeDivideSigned:
            LD   A,$D1                    ; POP DE / POP HL
            CALL RewriteBackendEmitByte
            LD   A,$E1
            CALL RewriteBackendEmitByte
            LD   A,(RewriteSemanticOperandArea+RewriteSemanticDivideSignedOperandModeOffset)
            CALL RewriteBackendEmitLoadAImmediate
            LD   DE,NucleusRuntimeDivideSignedOffset
            CALL RewriteBackendEmitRuntimeOffset
            LD   A,$30                    ; JR NC,success
            CALL RewriteBackendEmitRelativePlaceholder
            LD   (RewriteBackendRelativeOperand),DE
            LD   HL,(RewriteSemanticOperandArea+RewriteSemanticDivideSignedOperandSourceOffsetOffset)
            LD   A,3
            CALL RewriteBackendEmitTrap
            LD   DE,(RewriteBackendRelativeOperand)
            CALL RewriteBackendEscapePatchSuccess
            LD   A,(RewriteSemanticOperandArea+RewriteSemanticDivideSignedOperandModeOffset)
            BIT  7,A
            JR   Z,RewriteBackendEscapeDivideSignedPush
            LD   A,$26                    ; LD H,0 for byte result
            CALL RewriteBackendEmitByte
            XOR  A
            CALL RewriteBackendEmitByte
RewriteBackendEscapeDivideSignedPush:
            LD   A,$E5
            JP   RewriteBackendEmitByte

; Routine-frame escapes retain the frozen target ABI while the surrounding
; compiler is rebuilt. The semantic bank is checked against the sink selected
; by the output driver; this prototype never changes a cursor merely by
; changing a bank byte.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteBackendEscapeBeginRoutine:
            LD   A,(RewriteSemanticOperandArea+RewriteSemanticBeginGeneralRoutineOperandBankOffset)
            LD   C,A
            LD   A,(RewriteBackendOutputBank)
            CP   C
            JP   NZ,RewriteBackendInvalid
            LD   A,(RewriteSemanticOperandArea+RewriteSemanticBeginGeneralRoutineOperandLabelOffset)
            CALL RewriteBackendDefineLabel
            LD   A,$DD                    ; PUSH IX
            CALL RewriteBackendEmitByte
            LD   A,$E5
            CALL RewriteBackendEmitByte
            LD   A,$DD                    ; LD IX,0
            CALL RewriteBackendEmitByte
            LD   A,$21
            CALL RewriteBackendEmitByte
            XOR  A
            CALL RewriteBackendEmitByte
            XOR  A
            CALL RewriteBackendEmitByte
            LD   A,$DD                    ; ADD IX,SP
            CALL RewriteBackendEmitByte
            LD   A,$39
            JP   RewriteBackendEmitByte

; Emit one target IX-displaced instruction. A is the second opcode byte and C
; is the complete signed displacement. The prefix and operands are compiler
; output, not compiler-executed instruction data.
.routine in A,C out A,C,carry,zero clobbers sign,parity,halfCarry,B,D,DE,HL
RewriteBackendEmitIxByte:
            PUSH AF
            LD   A,$DD
            CALL RewriteBackendEmitByte
            POP  AF
            CALL RewriteBackendEmitByte
            LD   A,C
            JP   RewriteBackendEmitByte

.routine in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteBackendEmitDecSpCount:
            LD   C,A
RewriteBackendEmitDecSpNext:
            LD   A,$3B                    ; DEC SP
            CALL RewriteBackendEmitByte
            DEC  C
            JR   NZ,RewriteBackendEmitDecSpNext
            XOR  A
            RET

; Bind one published formal parameter. Scalar values occupy one or two
; activation bytes, aggregate aliases occupy one word, and string[] adds its
; hidden capacity byte. Open arrays arrive as two independent u16 bindings.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteBackendEscapeBindParameter:
            LD   A,(RewriteSemanticOperandArea+RewriteSemanticBindParameterOperandTypeOffset)
            LD   (RewriteBackendTrapReason),A
            CP   RewriteOpenStringTypeId
            JR   Z,RewriteBackendBindOpenString
            CP   RewriteFirstOwnedTypeId
            JR   NC,RewriteBackendBindWord
            AND  RewriteScalarTypeBaseMask
            CP   RewriteScalarTypeU16
            JR   Z,RewriteBackendBindWord
RewriteBackendBindByte:
            LD   A,1
            CALL RewriteBackendEmitDecSpCount
            LD   A,(RewriteSemanticOperandArea+RewriteSemanticBindParameterOperandArgumentOffsetOffset)
            LD   C,A
            LD   A,$6E                    ; LD L,(IX+n)
            CALL RewriteBackendEmitIxByte
            LD   A,(RewriteSemanticOperandArea+RewriteSemanticBindParameterOperandLocalOffsetOffset)
            CPL
            LD   C,A
            LD   A,$75                    ; LD (IX-n),L
            JP   RewriteBackendEmitIxByte
RewriteBackendBindOpenString:
            LD   A,3
            JR   RewriteBackendBindWordAllocate
RewriteBackendBindWord:
            LD   A,2
RewriteBackendBindWordAllocate:
            CALL RewriteBackendEmitDecSpCount
            LD   A,(RewriteSemanticOperandArea+RewriteSemanticBindParameterOperandArgumentOffsetOffset)
            LD   C,A
            LD   A,$6E                    ; LD L,(IX+n)
            CALL RewriteBackendEmitIxByte
            INC  C
            LD   A,$66                    ; LD H,(IX+n+1)
            CALL RewriteBackendEmitIxByte
            LD   A,(RewriteSemanticOperandArea+RewriteSemanticBindParameterOperandLocalOffsetOffset)
            CPL
            LD   C,A
            LD   A,$75                    ; LD (IX-n),L
            CALL RewriteBackendEmitIxByte
            DEC  C
            LD   A,$74                    ; LD (IX-n-1),H
            CALL RewriteBackendEmitIxByte
            LD   A,(RewriteBackendTrapReason)
            CP   RewriteOpenStringTypeId
            JR   Z,RewriteBackendBindOpenCapacity
            XOR  A
            RET
RewriteBackendBindOpenCapacity:
            LD   A,(RewriteSemanticOperandArea+RewriteSemanticBindParameterOperandArgumentOffsetOffset)
            ADD  A,2
            LD   C,A
            LD   A,$6E                    ; hidden capacity byte
            CALL RewriteBackendEmitIxByte
            LD   A,(RewriteSemanticOperandArea+RewriteSemanticBindParameterOperandLocalOffsetOffset)
            CPL
            SUB  2
            LD   C,A
            LD   A,$75
            JP   RewriteBackendEmitIxByte

; A result-bearing fallthrough is unreachable by the language flow checker.
; Result-free fallthrough restores the canonical IX frame and returns.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,D,DE,HL
RewriteBackendEscapeEndRoutine:
            LD   A,(RewriteSemanticOperandArea+RewriteSemanticEndGeneralRoutineDirectOperandResultTypeOffset)
            OR   A
            RET  NZ
            LD   A,$DD                    ; LD SP,IX
            CALL RewriteBackendEmitByte
            LD   A,$F9
            CALL RewriteBackendEmitByte
            LD   A,$DD                    ; POP IX
            CALL RewriteBackendEmitByte
            LD   A,$E1
            CALL RewriteBackendEmitByte
            LD   A,$C9                    ; RET
            JP   RewriteBackendEmitByte

.routine noreturn
RewriteBackendCapacity:
            LD   A,DiagnosticTargetCapacity
            JP   RewriteRaiseDiagnostic
.routine noreturn
RewriteBackendInvalid:
            LD   A,DiagnosticInternalOperation
            JP   RewriteRaiseDiagnostic
.routine noreturn
RewriteBackendBooleanFixupCapacityFailure:
            LD   A,DiagnosticBooleanFixupCapacity
            JP   RewriteRaiseDiagnostic
.routine noreturn
RewriteBackendControlLabelCapacityFailure:
            LD   A,DiagnosticControlLabelCapacity
            JP   RewriteRaiseDiagnostic
.routine noreturn
RewriteBackendControlFixupCapacityFailure:
            LD   A,DiagnosticControlFixupCapacity
            JP   RewriteRaiseDiagnostic
.routine noreturn
RewriteBackendFixupRangeFailure:
            LD   A,DiagnosticFixupRange
            JP   RewriteRaiseDiagnostic
