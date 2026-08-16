; R5 source-driven routine-body proof. Source and expected semantic records are
; data; every compiler-executed instruction uses an ordinary Z80 mnemonic.

CompilerWorkBase    .equ $6000
SourceBase          .equ $7000
SourceLimit         .equ $7800
RewriteAdapterBase  .equ $A000
RewriteAdapterLimit .equ $A100
DebugHooks          .equ 0

            .org $1000
ProofFrontDriver:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,1
            LD   HL,ProofPartsFrontDriver
            CALL RewriteSourceInitializeParts
            LD   HL,RewriteActionProgramRoutineForwardHeader
            CALL RewriteActionRun
            LD   HL,RewriteActionProgramRoutineDirectHeader
            CALL RewriteActionRun
            XOR  A
            LD   (RewriteSemanticBufferBase),A
            LD   HL,RewriteSemanticPayloadBase
            LD   (RewriteSemanticSinkCursor),HL
            CALL RewriteFrontParseRoutineBody
            CALL RewriteSemanticValidate
            CALL RewriteParserPeek
            OR   A
            JP   NZ,ProofFailure
            LD   A,(RewriteControlDepth)
            OR   A
            JP   NZ,ProofFailure
            LD   A,(RewriteCurrentRoutineFlags)
            OR   A
            JP   NZ,ProofFailure
            LD   A,(RewriteSymbolCount)
            OR   A
            JP   NZ,ProofFailure
            LD   A,$A5
            LD   (ProofStatus),A
            HALT

ProofFrontLateLocal:
            LD   HL,ProofPartsLateLocal
            JR   ProofFrontArmDiagnostic

ProofFrontMissingEnd:
            LD   HL,ProofPartsMissingEnd
            JR   ProofFrontArmDiagnostic

ProofFrontWhileElse:
            LD   HL,ProofPartsWhileElse
            JR   ProofFrontArmDiagnostic

ProofFrontRoutineAssignment:
            LD   HL,ProofPartsRoutineAssignment
            JR   ProofFrontArmDiagnostic

ProofFrontVariableCall:
            LD   HL,ProofPartsVariableCall

ProofFrontArmDiagnostic:
            LD   SP,$FF00
            PUSH HL
            CALL RewriteReset
            LD   HL,ProofDiagnosticReturn
            PUSH HL
            LD   (CompilerAbortSp),SP
            POP  DE
            POP  HL
            PUSH DE
            LD   A,1
            CALL RewriteSourceInitializeParts
            LD   HL,RewriteActionProgramRoutineDirectHeader
            CALL RewriteActionRun
            CALL RewriteFrontParseRoutineBody
            JP   ProofFailure

ProofDiagnosticReturn:
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

            .org $7000
ProofSourceFrontDriver:
            .db "forward sub stop() fails",10
            .db "sub main() fails",10
            .db "var i as i16 = 0",10
            .db "var code as u8",10
            .db "while true",10
            .db "if i = 0",10
            .db "i = 1",10
            .db "elseif false",10
            .db "continue",10
            .db "else",10
            .db "stop() handle code",10
            .db "i = 2",10
            .db "end",10
            .db "exit",10
            .db "end",10
            .db "end",10
            .db "return",10
            .db "end",10
ProofSourceFrontDriverEnd:

ProofSourceLateLocal:
            .db "sub main()",10
            .db "return",10
            .db "var late as u8",10
            .db "end",10
ProofSourceLateLocalEnd:

ProofSourceMissingEnd:
            .db "sub main()",10
ProofSourceMissingEndEnd:

ProofSourceWhileElse:
            .db "sub main()",10
            .db "var i as u8",10
            .db "for i = 0 to 1",10
            .db "else",10
            .db "end",10
            .db "end",10
ProofSourceWhileElseEnd:

ProofSourceRoutineAssignment:
            .db "sub main()",10
            .db "writeOutputByte = 1",10
            .db "end",10
ProofSourceRoutineAssignmentEnd:

ProofSourceVariableCall:
            .db "sub main()",10
            .db "var x as u8",10
            .db "x()",10
            .db "end",10
ProofSourceVariableCallEnd:

            .org $7900
ProofPartsFrontDriver: .db 1
                         .dw ProofSourceFrontDriver,ProofSourceFrontDriverEnd
ProofPartsLateLocal: .db 1
                     .dw ProofSourceLateLocal,ProofSourceLateLocalEnd
ProofPartsMissingEnd: .db 1
                      .dw ProofSourceMissingEnd,ProofSourceMissingEndEnd
ProofPartsWhileElse: .db 1
                     .dw ProofSourceWhileElse,ProofSourceWhileElseEnd
ProofPartsRoutineAssignment: .db 1
                             .dw ProofSourceRoutineAssignment,ProofSourceRoutineAssignmentEnd
ProofPartsVariableCall: .db 1
                        .dw ProofSourceVariableCall,ProofSourceVariableCallEnd
