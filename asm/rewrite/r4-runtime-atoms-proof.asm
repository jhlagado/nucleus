; R4 runtime-atom proof. Semantic records and source text are data; every
; compiler-executed instruction uses an ordinary Z80 mnemonic.

CompilerWorkBase    .equ $6000
SourceBase          .equ $5000
SourceLimit         .equ $5800
RewriteAdapterBase  .equ $A000
RewriteAdapterLimit .equ $A100
DebugHooks          .equ 0

            .org $1000
ProofRuntimeAtoms:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,1
            LD   HL,ProofPartsAccepted
            CALL RewriteSourceInitializeParts
            CALL ProofRunScalarConstant
            CALL ProofRunProgramScalar
            CALL ProofRunProgramBss
            CALL ProofRunDirectHeader
            LD   B,7
ProofRuntimeLocalLoop:
            PUSH BC
            CALL ProofRunLocalInitializedAtom
            POP  BC
            DJNZ ProofRuntimeLocalLoop
            LD   A,(RewriteCurrentLocalOffset)
            CP   12
            JP   NZ,ProofFailure
            LD   A,4
            LD   B,RewriteScalarTypeU8
            LD   C,1
            CALL ProofCheckLocal
            LD   A,5
            LD   B,RewriteScalarTypeU16
            LD   C,2
            CALL ProofCheckLocal
            LD   A,6
            LD   B,RewriteScalarTypeI16
            LD   C,4
            CALL ProofCheckLocal
            LD   A,7
            LD   B,RewriteScalarTypeU8
            LD   C,6
            CALL ProofCheckLocal
            LD   A,8
            LD   B,RewriteScalarTypeU16
            LD   C,7
            CALL ProofCheckLocal
            LD   A,9
            LD   B,RewriteScalarTypeI16
            LD   C,9
            CALL ProofCheckLocal
            LD   A,10
            LD   B,RewriteScalarTypeBoolean
            LD   C,11
            CALL ProofCheckLocal
            CALL RewriteSemanticValidate
            LD   A,(RewriteSemanticBufferBase)
            CP   22
            JP   NZ,ProofFailure
            LD   HL,RewriteSemanticPayloadBase
            LD   DE,ProofExpectedSemantics
            LD   B,ProofExpectedSemanticsEnd-ProofExpectedSemantics
ProofRuntimeSemanticLoop:
            LD   A,(DE)
            CP   (HL)
            JP   NZ,ProofFailure
            INC  DE
            INC  HL
            DJNZ ProofRuntimeSemanticLoop
            LD   DE,(RewriteSemanticSinkCursor)
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            CALL ProofRunRoutineEnd
            LD   A,(RewriteSymbolCount)
            CP   3
            JP   NZ,ProofFailure
            CALL ProofRunDirectHeader
            CALL ProofRunRoutineEnd
            CALL ProofRunCompilationEnd
            LD   A,$C0
            LD   (ProofStatus),A
            HALT

ProofRuntimeMismatch:
            LD   HL,ProofPartsMismatch
            LD   BC,(DiagnosticTypeMismatch<<8)|$C1
            LD   DE,31
            JP   ProofArmRuntimeDiagnostic
ProofRuntimeSelfReference:
            LD   HL,ProofPartsSelfReference
            LD   BC,(DiagnosticUnknownName<<8)|$C2
            LD   DE,25
            JP   ProofArmRuntimeDiagnostic
ProofRuntimeTrailingToken:
            LD   HL,ProofPartsTrailingToken
            LD   BC,(DiagnosticExpectedLine<<8)|$C3
            LD   DE,27

; HL source descriptor, B diagnostic, C status, DE exact offset.
.routine noreturn
ProofArmRuntimeDiagnostic:
            LD   A,B
            LD   (ProofExpectedDiagnostic),A
            LD   A,C
            LD   (ProofExpectedStatus),A
            LD   (ProofExpectedOffset),DE
            PUSH HL
            CALL RewriteReset
            POP  DE
            LD   HL,ProofExpectedDiagnosticReturn
            PUSH HL
            LD   (CompilerAbortSp),SP
            EX   DE,HL
            LD   A,1
            CALL RewriteSourceInitializeParts
            CALL ProofRunDirectHeader
            CALL ProofRunLocalInitializedAtom
            JP   ProofFailure

ProofExpectedDiagnosticReturn:
            LD   A,(DiagnosticCode)
            LD   B,A
            LD   A,(ProofExpectedDiagnostic)
            CP   B
            JP   NZ,ProofFailure
            LD   A,(DiagnosticPartId)
            CP   1
            JP   NZ,ProofFailure
            LD   HL,(DiagnosticOffset)
            LD   DE,(ProofExpectedOffset)
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   A,(ProofExpectedStatus)
            LD   (ProofStatus),A
            HALT

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunScalarConstant:
            LD   HL,RewriteActionProgramScalarConstant
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunProgramScalar:
            LD   HL,RewriteActionProgramProgramScalarInitialized
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunProgramBss:
            LD   HL,RewriteActionProgramProgramBss
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunDirectHeader:
            LD   HL,RewriteActionProgramRoutineDirectHeader
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunLocalInitializedAtom:
            LD   HL,RewriteActionProgramLocalInitializedAtom
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunRoutineEnd:
            LD   HL,RewriteActionProgramRoutineEnd
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunCompilationEnd:
            LD   HL,RewriteActionProgramCompilationEnd
            JP   RewriteActionRun

; A symbol ordinal, B exact type, C activation byte offset.
.routine in A,B,C out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ProofCheckLocal:
            PUSH BC
            CALL RewriteSymbolAddress
            POP  BC
            LD   DE,RewriteSymbolClass
            ADD  HL,DE
            LD   A,(HL)
            CP   RewriteSymbolClassLocal
            JP   NZ,ProofFailure
            INC  HL
            LD   A,(HL)
            CP   B
            JP   NZ,ProofFailure
            INC  HL
            LD   A,(HL)
            CP   C
            JP   NZ,ProofFailure
            INC  HL
            LD   A,(HL)
            OR   A
            JP   NZ,ProofFailure
            INC  HL
            LD   A,(HL)
            CP   RewriteSymbolStorageActivation
            JP   NZ,ProofFailure
            RET

ProofUnexpectedDiagnostic:
            LD   A,(DiagnosticCode)
            LD   (ProofStatus),A
            HALT
ProofFailure:
            LD   A,$FF
            LD   (ProofStatus),A
            HALT

            .include "compiler-image.asmi"

ProofStatus:             .db 0
ProofExpectedDiagnostic: .db 0
ProofExpectedStatus:     .db 0
ProofExpectedOffset:     .dw 0

ProofExpectedSemantics:
            .db RewriteSemanticDeclareLocalU8,1
            .db RewriteSemanticLoadParameter8,0
            .db RewriteSemanticStoreLocalU8,1
            .db RewriteSemanticDeclareLocal16,2
            .db RewriteSemanticLoadLocalU8,1
            .db RewriteSemanticStoreLocal16,2
            .db RewriteSemanticDeclareLocal16,4
            .db RewriteSemanticLiteral16,5,0
            .db RewriteSemanticStoreLocal16,4
            .db RewriteSemanticDeclareLocalU8,6
            .db RewriteSemanticLoadProgramU8,0,0
            .db RewriteSemanticStoreLocalU8,6
            .db RewriteSemanticDeclareLocal16,7
            .db RewriteSemanticLoadBss16,0,0
            .db RewriteSemanticStoreLocal16,7
            .db RewriteSemanticDeclareLocal16,9
            .db RewriteSemanticLiteral16,7,0
            .db RewriteSemanticConvertInteger,RewriteScalarTypeI8,RewriteScalarTypeI16
            .dw ProofSignedConversionToken-ProofSourceAccepted
            .db RewriteSemanticStoreLocal16,9
            .db RewriteSemanticDeclareLocalU8,11
            .db RewriteSemanticLiteral16,1,0
            .db RewriteSemanticStoreLocalU8,11
ProofExpectedSemanticsEnd:

            .org $5000
ProofSourceAccepted:
            .db "const five = 5",10
            .db "var initialized as u8 = 3",10
            .db "var reserved as u16",10
            .db "sub worker(input as u8)",10
            .db "var fromParameter as u8 = input",10
            .db "var widened as u16 = fromParameter",10
            .db "var fromConstant as i16 = five",10
            .db "var fromInitialized as u8 = initialized",10
            .db "var fromBss as u16 = reserved",10
            .db "var signed as i16 = "
ProofSignedConversionToken:
            .db "i8(7)",10
            .db "var flag as boolean = true",10
            .db "end",10
            .db "sub main()",10,"end",10
ProofSourceAcceptedEnd:
ProofSourceMismatch: .db "sub main()",10,"var x as boolean = 1",10
ProofSourceMismatchEnd:
ProofSourceSelfReference: .db "sub main()",10,"var x as u8 = x",10
ProofSourceSelfReferenceEnd:
ProofSourceTrailingToken: .db "sub main()",10,"var x as u8 = 1 2",10
ProofSourceTrailingTokenEnd:

ProofPartsAccepted:      .db 1
                         .dw ProofSourceAccepted,ProofSourceAcceptedEnd
ProofPartsMismatch:      .db 1
                         .dw ProofSourceMismatch,ProofSourceMismatchEnd
ProofPartsSelfReference: .db 1
                         .dw ProofSourceSelfReference,ProofSourceSelfReferenceEnd
ProofPartsTrailingToken: .db 1
                         .dw ProofSourceTrailingToken,ProofSourceTrailingTokenEnd
