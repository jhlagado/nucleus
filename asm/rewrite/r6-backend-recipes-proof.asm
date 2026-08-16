; R6 recipe-interpreter proof. Expected target bytes are assembled from legal
; Z80 mnemonics, never reproduced as disguised compiler instruction data.

CompilerWorkBase    .equ $6000
SourceBase          .equ $5000
SourceLimit         .equ $5800
RewriteAdapterBase  .equ $A000
RewriteAdapterLimit .equ $A100
DebugHooks          .equ 0
ProofRuntimeBase    .equ $9000

            .org $1000
ProofBackendRecipes:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   HL,ProofBackendOutput
            LD   DE,ProofBackendOutputLimit
            LD   BC,ProofRuntimeBase
            CALL RewriteBackendInitialize
            LD   HL,$1234
            LD   (RewriteSemanticOperandArea),HL
            LD   A,RewriteSemanticDeclareLocalU8
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticDeclareLocal16
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticLiteral16
            CALL RewriteBackendDispatchOperation
            LD   A,2
            LD   (RewriteSemanticOperandArea),A
            LD   A,RewriteSemanticLoadLocalU8
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticLoadLocal16
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticStoreLocalU8
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticStoreLocal16
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticLoadParameter8
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticLoadParameter16
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticStoreParameter8
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticStoreParameter16
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticAdd8
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticSubtract8
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticMultiply8
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticAnd8
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticOr8
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticXor8
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticAdd16
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticSubtract16
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticMultiply16
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticAnd16
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticOr16
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticXor16
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticNegate8
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticNot8
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticNegate16
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticNot16
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticNotBoolean
            CALL RewriteBackendDispatchOperation
            LD   A,$11
            LD   (RewriteSemanticOperandArea),A
            LD   A,RewriteSemanticCompare8
            CALL RewriteBackendDispatchOperation
            LD   A,$22
            LD   (RewriteSemanticOperandArea),A
            LD   A,RewriteSemanticCompare16
            CALL RewriteBackendDispatchOperation
            LD   A,$33
            LD   (RewriteSemanticOperandArea),A
            LD   A,RewriteSemanticCompareBoolean
            CALL RewriteBackendDispatchOperation
            LD   A,1
            LD   (RewriteSemanticOperandArea),A
            LD   A,RewriteSemanticPromoteI8Pair
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticBeginBooleanAnd
            CALL RewriteBackendDispatchOperation
            LD   HL,$CAFE
            LD   (RewriteSemanticOperandArea),HL
            LD   A,RewriteSemanticLiteral16
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticBeginBooleanOr
            CALL RewriteBackendDispatchOperation
            LD   HL,$BEEF
            LD   (RewriteSemanticOperandArea),HL
            LD   A,RewriteSemanticLiteral16
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticEndBoolean
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticEndBoolean
            CALL RewriteBackendDispatchOperation
            LD   A,(RewriteBackendBooleanFixupDepth)
            OR   A
            JP   NZ,ProofFailure
            LD   HL,(RewriteBackendOutputCursor)
            LD   DE,ProofBackendOutput+ProofExpectedBackendEnd-ProofExpectedBackend
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   HL,ProofBackendOutput
            LD   DE,ProofExpectedBackend
            LD   BC,ProofExpectedBackendEnd-ProofExpectedBackend
ProofBackendCompareLoop:
            LD   A,(DE)
            CP   (HL)
            JP   NZ,ProofFailure
            INC  DE
            INC  HL
            DEC  BC
            LD   A,B
            OR   C
            JR   NZ,ProofBackendCompareLoop
            LD   A,$A5
            LD   (ProofStatus),A
            HALT

ProofBackendCapacity:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofExpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   HL,ProofBackendOutput
            LD   DE,ProofBackendOutput+3
            LD   BC,ProofRuntimeBase
            CALL RewriteBackendInitialize
            LD   HL,$1234
            LD   (RewriteSemanticOperandArea),HL
            LD   A,RewriteSemanticLiteral16
            CALL RewriteBackendDispatchOperation
            JP   ProofFailure

ProofBackendUnsupported:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofExpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   HL,ProofBackendOutput
            LD   DE,ProofBackendOutputLimit
            LD   BC,ProofRuntimeBase
            CALL RewriteBackendInitialize
            LD   A,RewriteSemanticDivide8
            CALL RewriteBackendDispatchOperation
            JP   ProofFailure

ProofExpectedDiagnostic:
            HALT
ProofUnexpectedDiagnostic:
            LD   A,(DiagnosticCode)
            LD   (ProofStatus),A
            HALT
ProofFailure:
            LD   A,$FF
            LD   (ProofStatus),A
            HALT

            .include "compiler-image.asmi"

ProofStatus: .db 0

            .org $B000
ProofBackendOutput:
            .ds $0400
ProofBackendOutputLimit:

            .org $B800
ProofExpectedBackend:
            DEC  SP
            DEC  SP
            DEC  SP
            LD   HL,$1234
            PUSH HL
            LD   L,(IX-3)
            LD   H,0
            PUSH HL
            LD   L,(IX-3)
            LD   H,(IX-4)
            PUSH HL
            POP  HL
            LD   (IX-3),L
            POP  HL
            LD   (IX-3),L
            LD   (IX-4),H
            LD   L,(IX-3)
            LD   H,0
            PUSH HL
            LD   L,(IX-3)
            LD   H,(IX-4)
            PUSH HL
            POP  HL
            LD   (IX-3),L
            POP  HL
            LD   (IX-3),L
            LD   (IX-4),H
            POP  DE
            POP  HL
            LD   A,L
            ADD  A,E
            LD   L,A
            LD   H,0
            PUSH HL
            POP  DE
            POP  HL
            LD   A,L
            SUB  E
            LD   L,A
            LD   H,0
            PUSH HL
            POP  DE
            POP  HL
            CALL ProofRuntimeBase+NucleusRuntimeMultiplyU16Offset
            LD   H,0
            PUSH HL
            POP  DE
            POP  HL
            LD   A,L
            AND  E
            LD   L,A
            LD   H,0
            PUSH HL
            POP  DE
            POP  HL
            LD   A,L
            OR   E
            LD   L,A
            LD   H,0
            PUSH HL
            POP  DE
            POP  HL
            LD   A,L
            XOR  E
            LD   L,A
            LD   H,0
            PUSH HL
            POP  DE
            POP  HL
            ADD  HL,DE
            PUSH HL
            POP  DE
            POP  HL
            XOR  A
            SBC  HL,DE
            PUSH HL
            POP  DE
            POP  HL
            CALL ProofRuntimeBase+NucleusRuntimeMultiplyU16Offset
            PUSH HL
            POP  DE
            POP  HL
            LD   A,L
            AND  E
            LD   L,A
            LD   A,H
            AND  D
            LD   H,A
            PUSH HL
            POP  DE
            POP  HL
            LD   A,L
            OR   E
            LD   L,A
            LD   A,H
            OR   D
            LD   H,A
            PUSH HL
            POP  DE
            POP  HL
            LD   A,L
            XOR  E
            LD   L,A
            LD   A,H
            XOR  D
            LD   H,A
            PUSH HL
            POP  HL
            XOR  A
            SUB  L
            LD   L,A
            LD   H,0
            PUSH HL
            POP  HL
            LD   A,L
            CPL
            LD   L,A
            LD   H,0
            PUSH HL
            POP  HL
            XOR  A
            SUB  L
            LD   L,A
            LD   A,0
            SBC  A,H
            LD   H,A
            PUSH HL
            POP  HL
            LD   A,L
            CPL
            LD   L,A
            LD   A,H
            CPL
            LD   H,A
            PUSH HL
            POP  HL
            LD   A,L
            XOR  1
            LD   L,A
            LD   H,0
            PUSH HL
            POP  DE
            POP  HL
            LD   A,$11
            CALL ProofRuntimeBase+NucleusRuntimeCompareU16Offset
            PUSH HL
            POP  DE
            POP  HL
            LD   A,$22
            CALL ProofRuntimeBase+NucleusRuntimeCompareU16Offset
            PUSH HL
            POP  DE
            POP  HL
            LD   A,$33
            CALL ProofRuntimeBase+NucleusRuntimeCompareU16Offset
            PUSH HL
            POP  DE
            POP  HL
            LD   A,1
            CALL ProofRuntimeBase+NucleusRuntimePromoteI8PairOffset
            PUSH HL
            PUSH DE
            POP  HL
            LD   A,L
            OR   A
            JR   NZ,ProofExpectedBooleanAndContinue
            PUSH HL
            JR   ProofExpectedBooleanOuterEnd
ProofExpectedBooleanAndContinue:
            LD   HL,$CAFE
            PUSH HL
            POP  HL
            LD   A,L
            OR   A
            JR   Z,ProofExpectedBooleanOrContinue
            PUSH HL
            JR   ProofExpectedBooleanInnerEnd
ProofExpectedBooleanOrContinue:
            LD   HL,$BEEF
            PUSH HL
ProofExpectedBooleanInnerEnd:
ProofExpectedBooleanOuterEnd:
ProofExpectedBackendEnd:
