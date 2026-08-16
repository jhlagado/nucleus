; R3 front-action interpreter proof. Local .db blocks are action/source data,
; never hidden Z80 instructions.

CompilerWorkBase    .equ $6000
SourceBase          .equ $5000
SourceLimit         .equ $5800
RewriteAdapterBase  .equ $A000
RewriteAdapterLimit .equ $A100
DebugHooks          .equ 0

            .org $1000
ProofActionProgram:
            LD   SP,$FF00
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            CALL RewriteReset
            LD   A,1
            LD   HL,ProofVarParts
            CALL RewriteSourceInitializeParts
            LD   HL,7
            LD   (RewriteInitializerLength),HL
            LD   HL,ProofValidActions
            CALL RewriteActionRun
            LD   HL,(RewriteInitializerLength)
            LD   A,H
            OR   L
            JP   NZ,ProofFailure
            CALL RewriteParserTake
            CP   TokenEof
            JP   NZ,ProofFailure
            LD   A,$F1
            LD   (ProofStatus),A
            HALT

ProofActionMismatch:
            LD   SP,$FF00
            LD   HL,ProofExpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            CALL RewriteReset
            LD   A,2
            LD   HL,ProofMismatchParts
            CALL RewriteSourceInitializeParts
            LD   HL,ProofMismatchActions
            CALL RewriteActionRun
            JP   ProofFailure

ProofActionInvalid:
            LD   SP,$FF00
            LD   HL,ProofInvalidDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            CALL RewriteReset
            LD   HL,ProofInvalidActions
            CALL RewriteActionRun
            JP   ProofFailure

ProofExpectedDiagnostic:
            LD   A,(DiagnosticCode)
            CP   DiagnosticExpectedTopLevel
            JP   NZ,ProofFailure
            LD   A,(DiagnosticPartId)
            CP   2
            JP   NZ,ProofFailure
            LD   HL,(DiagnosticOffset)
            LD   DE,2
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   A,$F2
            LD   (ProofStatus),A
            HALT
ProofInvalidDiagnostic:
            LD   A,(DiagnosticCode)
            CP   DiagnosticInternalOperation
            JP   NZ,ProofFailure
            LD   A,$F3
            LD   (ProofStatus),A
            HALT
ProofUnexpectedDiagnostic:
            LD   A,(DiagnosticCode)
            LD   (ProofStatus),A
            HALT
ProofFailure:
            LD   A,$FF
            LD   (ProofStatus),A
            HALT

ProofStatus: .db 0
ProofValidActions:
            .db RewriteActionExpect,TokenVar,DiagnosticExpectedTopLevel
            .db RewriteActionExpect,TokenNewline,DiagnosticExpectedTopLevel
            .db RewriteActionEscape,RewriteActionEscapeResetInitializer
            .db RewriteActionEnd
ProofMismatchActions:
            .db RewriteActionExpect,TokenVar,DiagnosticExpectedTopLevel
            .db RewriteActionExpect,TokenNewline,DiagnosticExpectedTopLevel
            .db RewriteActionExpect,TokenName,DiagnosticExpectedTopLevel
            .db RewriteActionExpect,TokenVar,DiagnosticExpectedTopLevel
            .db RewriteActionEnd
ProofInvalidActions:
            .db RewriteActionInstructionCount

            .org $4000
ProofVarSource: .db "var"
ProofVarSourceEnd:
ProofMismatchSource: .db "x const"
ProofMismatchSourceEnd:
ProofVarParts:
            .db 1
            .dw ProofVarSource,ProofVarSourceEnd
ProofMismatchParts:
            .db 1
            .dw ProofVarSource,ProofVarSourceEnd
            .db 2
            .dw ProofMismatchSource,ProofMismatchSourceEnd

            .org $8000
            .include "compiler-image.asmi"
