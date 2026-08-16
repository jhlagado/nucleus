; R5 source-driven compilation-unit proof. Source and expected metadata are
; proof data; compiler-executed instructions use ordinary Z80 mnemonics.

CompilerWorkBase    .equ $6000
SourceBase          .equ $7000
SourceLimit         .equ $7C00
RewriteAdapterBase  .equ $A000
RewriteAdapterLimit .equ $A100
DebugHooks          .equ 0

            .org $1000
ProofCompilationUnit:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,1
            LD   HL,ProofPartsCompilationUnit
            CALL RewriteSourceInitializeParts
            XOR  A
            LD   (RewriteSemanticBufferBase),A
            LD   HL,RewriteSemanticPayloadBase
            LD   (RewriteSemanticSinkCursor),HL
            CALL RewriteFrontParseCompilationUnit
            CALL RewriteSemanticValidate
            LD   A,(RewriteSymbolCount)
            CP   7
            JP   NZ,ProofFailure
            LD   A,(RewriteRoutineCount)
            CP   1
            JP   NZ,ProofFailure
            LD   A,(RewriteParameterCount)
            CP   1
            JP   NZ,ProofFailure
            LD   A,(RewriteRecordCount)
            CP   1
            JP   NZ,ProofFailure
            LD   A,(RewriteMainFlags)
            CP   RewriteRoutineFlagMain+RewriteRoutineFlagFails
            JP   NZ,ProofFailure
            LD   HL,(RewriteStaticConstantLength)
            LD   DE,6
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   HL,(RewriteStaticInitializedLength)
            LD   DE,4
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   HL,(RewriteStaticBssLength)
            LD   DE,2
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   A,$A5
            LD   (ProofStatus),A
            HALT

ProofCompilationMissingMain:
            LD   HL,ProofPartsMissingMain
            JR   ProofArmCompilationDiagnostic
ProofCompilationIncompleteForward:
            LD   HL,ProofPartsIncompleteForward
            JR   ProofArmCompilationDiagnostic
ProofCompilationMalformedRecord:
            LD   HL,ProofPartsMalformedRecord
            JR   ProofArmCompilationDiagnostic
ProofCompilationTypedScalarConstant:
            LD   HL,ProofPartsTypedScalarConstant
            JR   ProofArmCompilationDiagnostic
ProofCompilationMissingForward:
            LD   HL,ProofPartsMissingForward

ProofArmCompilationDiagnostic:
            LD   SP,$FF00
            PUSH HL
            CALL RewriteReset
            POP  HL
            LD   DE,ProofDiagnosticReturn
            PUSH DE
            LD   (CompilerAbortSp),SP
            LD   A,1
            CALL RewriteSourceInitializeParts
            CALL RewriteFrontParseCompilationUnit
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
ProofSourceCompilationUnit:
            .db "record Pair",10
            .db "value as i16",10
            .db "end",10
            .db "const limit = 3",10
            .db "assert limit = 3",10
            .db "const banner as string[4] = ",$22,"hi",$22,10
            .db "var total as i16 = limit",10
            .db "var pair as Pair = (1)",10
            .db "var scratch as u8",10
            .db "forward sub add(value as i16) as i16",10
            .db "sub add",10
            .db "return value + total",10
            .db "end",10
            .db "sub main() fails",10
            .db "var code as u8",10
            .db "total = add(2)",10
            .db "end",10
            .db "var after as u8",10
ProofSourceCompilationUnitEnd:

ProofSourceMissingMain:
            .db "const x = 1",10
ProofSourceMissingMainEnd:

ProofSourceIncompleteForward:
            .db "forward sub later()",10
            .db "sub main()",10
            .db "end",10
ProofSourceIncompleteForwardEnd:

ProofSourceMalformedRecord:
            .db "record Broken",10
            .db "var value as u8",10
            .db "end",10
            .db "sub main()",10
            .db "end",10
ProofSourceMalformedRecordEnd:

ProofSourceTypedScalarConstant:
            .db "const x as u8 = 1",10
            .db "sub main()",10
            .db "end",10
ProofSourceTypedScalarConstantEnd:

ProofSourceMissingForward:
            .db "sub missing",10
            .db "end",10
            .db "sub main()",10
            .db "end",10
ProofSourceMissingForwardEnd:

            .org $7D00
ProofPartsCompilationUnit: .db 1
                           .dw ProofSourceCompilationUnit,ProofSourceCompilationUnitEnd
ProofPartsMissingMain: .db 1
                       .dw ProofSourceMissingMain,ProofSourceMissingMainEnd
ProofPartsIncompleteForward: .db 1
                             .dw ProofSourceIncompleteForward,ProofSourceIncompleteForwardEnd
ProofPartsMalformedRecord: .db 1
                           .dw ProofSourceMalformedRecord,ProofSourceMalformedRecordEnd
ProofPartsTypedScalarConstant: .db 1
                               .dw ProofSourceTypedScalarConstant,ProofSourceTypedScalarConstantEnd
ProofPartsMissingForward: .db 1
                          .dw ProofSourceMissingForward,ProofSourceMissingForwardEnd
