; First replacement backend recipe interpreter. Recipes are declared data;
; compiler-executed Z80 remains ordinary mnemonics. All directories retain
; complete addresses and impose no origin policy.

            .include "../vertical-slice/nucleus-runtime-identity.asmi"

; HL is the first writable target byte, DE its exclusive limit, and BC the
; linked runtime base used by identity-fixed helper calls.
.routine in HL,DE,BC out A,carry,zero clobbers sign,parity,halfCarry
RewriteBackendInitialize:
            LD   (RewriteBackendOutputCursor),HL
            LD   (RewriteBackendOutputLimit),DE
            LD   (RewriteBackendRuntimeBase),BC
            XOR  A
            LD   (RewriteBackendBooleanFixupDepth),A
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
; descriptor supplies a dense recipe selector; the generated selector
; directory supplies a complete recipe address. Escape-class and unavailable
; recipes are rejected rather than silently skipped.
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
            BIT  7,(HL)
            JP   NZ,RewriteBackendInvalid
            INC  HL
            INC  HL
            LD   A,(HL)
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
            JP   RewriteBackendRecipePatchRelativeFixup

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
            JR   RewriteBackendRecipeNext

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
            JR   RewriteBackendRecipeNext

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
RewriteBackendFixupRangeFailure:
            LD   A,DiagnosticFixupRange
            JP   RewriteRaiseDiagnostic
