; R2 semantic-transcript proof. The .db blocks below are producer operands and
; deliberately malformed transcript data, not Z80 instruction encodings.

CompilerWorkBase    .equ $6000
SourceBase          .equ $5000
SourceLimit         .equ $5800
RewriteAdapterBase  .equ $A000
RewriteAdapterLimit .equ $A100
DebugHooks          .equ 1

            .org $1000
ProofSemanticStart:
            LD   SP,$FF00
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            CALL RewriteReset
            LD   A,RewriteSemanticForCleanup
            LD   HL,ProofNoOperands
            CALL RewriteSemanticAppend
            LD   A,RewriteSemanticLiteral16
            LD   HL,ProofLiteral16Operands
            CALL RewriteSemanticAppend
            LD   A,RewriteSemanticCallSource
            LD   HL,ProofCallSourceOperands
            CALL RewriteSemanticAppend
            LD   A,RewriteSemanticBeginHandlerLocal
            LD   HL,ProofBeginHandlerLocalOperands
            CALL RewriteSemanticAppend
            CALL RewriteSemanticDispatch
            LD   A,$A5
            LD   (ProofStatus),A
            HALT

ProofSemanticCapacity:
            LD   SP,$FF00
            LD   HL,ProofCapacityDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            CALL RewriteReset
            LD   B,127
ProofSemanticFillLoop:
            PUSH BC
            LD   A,RewriteSemanticBeginHandlerLocal
            LD   HL,ProofBeginHandlerLocalOperands
            CALL RewriteSemanticAppend
            POP  BC
            DJNZ ProofSemanticFillLoop
            LD   A,RewriteSemanticLiteral16
            LD   HL,ProofLiteral16Operands
            CALL RewriteSemanticAppend
            CALL RewriteSemanticValidate
            LD   A,(RewriteSemanticBufferBase)
            LD   (ProofExactFillCount),A
            LD   A,RewriteSemanticForCleanup
            LD   HL,ProofNoOperands
            CALL RewriteSemanticAppend
            JP   ProofFailure
ProofCapacityDiagnostic:
            LD   A,(DiagnosticCode)
            CP   DiagnosticSemanticCapacity
            JP   NZ,ProofFailure
            LD   HL,RewriteSemanticBufferLimit
            LD   DE,(RewriteSemanticSinkCursor)
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            CALL RewriteReset
            LD   A,RewriteSemanticForCleanup
            LD   HL,ProofNoOperands
            CALL RewriteSemanticAppend
            CALL RewriteSemanticValidate
            LD   A,$A6
            LD   (ProofStatus),A
            HALT

ProofSemanticInvalidOrdinal:
            LD   SP,$FF00
            LD   HL,ProofInvalidDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            CALL RewriteReset
            LD   A,1
            LD   (RewriteSemanticBufferBase),A
            XOR  A
            LD   (RewriteSemanticPayloadBase),A
            LD   HL,RewriteSemanticPayloadBase+1
            LD   (RewriteSemanticSinkCursor),HL
            JP   RewriteSemanticDispatch

ProofSemanticTruncated:
            LD   SP,$FF00
            LD   HL,ProofInvalidDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            CALL RewriteReset
            LD   A,1
            LD   (RewriteSemanticBufferBase),A
            LD   A,RewriteSemanticLiteral16
            LD   (RewriteSemanticPayloadBase),A
            LD   HL,RewriteSemanticPayloadBase+2
            LD   (RewriteSemanticSinkCursor),HL
            JP   RewriteSemanticDispatch

ProofSemanticTrailing:
            LD   SP,$FF00
            LD   HL,ProofInvalidDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            CALL RewriteReset
            LD   A,1
            LD   (RewriteSemanticBufferBase),A
            LD   A,RewriteSemanticForCleanup
            LD   (RewriteSemanticPayloadBase),A
            LD   HL,RewriteSemanticPayloadBase+2
            LD   (RewriteSemanticSinkCursor),HL
            JP   RewriteSemanticDispatch

ProofSemanticAtomicOverflow:
            LD   SP,$FF00
            LD   HL,ProofAtomicDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            CALL RewriteReset
            LD   B,127
ProofSemanticAtomicFillLoop:
            PUSH BC
            LD   A,RewriteSemanticBeginHandlerLocal
            LD   HL,ProofBeginHandlerLocalOperands
            CALL RewriteSemanticAppend
            POP  BC
            DJNZ ProofSemanticAtomicFillLoop
            LD   HL,(RewriteSemanticSinkCursor)
            LD   (HL),$AA
            INC  HL
            LD   (HL),$BB
            INC  HL
            LD   (HL),$CC
            LD   A,RewriteSemanticBeginHandlerLocal
            LD   HL,ProofBeginHandlerLocalOperands
            CALL RewriteSemanticAppend
            JP   ProofFailure
ProofAtomicDiagnostic:
            LD   A,(DiagnosticCode)
            CP   DiagnosticSemanticCapacity
            JP   NZ,ProofFailure
            LD   A,(RewriteSemanticBufferBase)
            CP   127
            JP   NZ,ProofFailure
            LD   HL,(RewriteSemanticSinkCursor)
            LD   DE,RewriteSemanticPayloadBase+508
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            EX   DE,HL
            LD   A,(HL)
            CP   $AA
            JP   NZ,ProofFailure
            INC  HL
            LD   A,(HL)
            CP   $BB
            JP   NZ,ProofFailure
            INC  HL
            LD   A,(HL)
            CP   $CC
            JP   NZ,ProofFailure
            LD   A,$A8
            LD   (ProofStatus),A
            HALT

ProofSemanticCountCapacity:
            LD   SP,$FF00
            LD   HL,ProofCountDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            CALL RewriteReset
            LD   B,255
ProofSemanticCountFillLoop:
            PUSH BC
            LD   A,RewriteSemanticForCleanup
            LD   HL,ProofNoOperands
            CALL RewriteSemanticAppend
            POP  BC
            DJNZ ProofSemanticCountFillLoop
            CALL RewriteSemanticValidate
            LD   A,RewriteSemanticEndBoolean
            LD   HL,ProofNoOperands
            CALL RewriteSemanticAppend
            JP   ProofFailure
ProofCountDiagnostic:
            LD   A,(DiagnosticCode)
            CP   DiagnosticSemanticCapacity
            JP   NZ,ProofFailure
            LD   A,(RewriteSemanticBufferBase)
            CP   255
            JP   NZ,ProofFailure
            LD   HL,(RewriteSemanticSinkCursor)
            LD   DE,RewriteSemanticPayloadBase+255
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   A,$A9
            LD   (ProofStatus),A
            HALT

ProofInvalidDiagnostic:
            LD   A,(DiagnosticCode)
            CP   DiagnosticInternalOperation
            JR   NZ,ProofFailure
            LD   A,$A7
            LD   (ProofStatus),A
            HALT
ProofUnexpectedDiagnostic:
            LD   A,$E1
            LD   (ProofStatus),A
            HALT
ProofFailure:
            LD   A,$E2
            LD   (ProofStatus),A
            HALT

ProofStatus:              .db 0
ProofExactFillCount:      .db 0
ProofNoOperands:
ProofLiteral16Operands:
ProofLiteral16Value:          .db $34,$12
ProofCallSourceOperands:
ProofCallSourceSelector:      .db 2
ProofCallSourceArgumentWords: .db 3
ProofCallSourceResultType:    .db 1
ProofCallSourceRoutineFlags:  .db 0
ProofCallSourceSourceOffset:  .db $78,$56
ProofCallSourceCallMode:      .db 2
ProofCallSourceHandlerLabel:  .db 4
ProofCallSourceRetained:      .db 1
ProofBeginHandlerLocalOperands:
ProofBeginHandlerLocalLabel:  .db 4
ProofBeginHandlerLocalInfo:   .db 5
ProofBeginHandlerLocalOffset: .db 6

            .org $8000
            .include "compiler-image.asmi"
