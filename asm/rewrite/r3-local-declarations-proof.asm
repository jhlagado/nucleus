; R3 generated default-local proof. Semantic records and source text are data;
; every compiler-executed instruction uses an ordinary Z80 mnemonic.

CompilerWorkBase    .equ $6000
SourceBase          .equ $5000
SourceLimit         .equ $5800
RewriteAdapterBase  .equ $A000
RewriteAdapterLimit .equ $A100
DebugHooks          .equ 0

            .org $1000
ProofLocalDeclarations:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,1
            LD   HL,ProofPartsAccepted
            CALL RewriteSourceInitializeParts
            CALL ProofRunDirectHeader
            LD   B,5
ProofLocalDeclarationLoop:
            PUSH BC
            CALL ProofRunLocalDefault
            POP  BC
            DJNZ ProofLocalDeclarationLoop
            LD   A,(RewriteSymbolCount)
            CP   5
            JP   NZ,ProofFailure
            LD   A,(RewriteCurrentLocalOffset)
            CP   7
            JP   NZ,ProofFailure
            LD   A,0
            LD   B,RewriteScalarTypeU8
            LD   C,0
            CALL ProofCheckLocal
            LD   A,1
            LD   B,RewriteScalarTypeU16
            LD   C,1
            CALL ProofCheckLocal
            LD   A,2
            LD   B,RewriteScalarTypeBoolean
            LD   C,3
            CALL ProofCheckLocal
            LD   A,3
            LD   B,RewriteScalarTypeI8
            LD   C,4
            CALL ProofCheckLocal
            LD   A,4
            LD   B,RewriteScalarTypeI16
            LD   C,5
            CALL ProofCheckLocal
            CALL RewriteSemanticValidate
            LD   A,(RewriteSemanticBufferBase)
            CP   15
            JP   NZ,ProofFailure
            LD   HL,RewriteSemanticPayloadBase
            LD   DE,ProofExpectedSemantics
            LD   B,ProofExpectedSemanticsEnd-ProofExpectedSemantics
ProofSemanticCompareLoop:
            LD   A,(DE)
            CP   (HL)
            JP   NZ,ProofFailure
            INC  DE
            INC  HL
            DJNZ ProofSemanticCompareLoop
            LD   DE,(RewriteSemanticSinkCursor)
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            CALL ProofRunRoutineEnd
            LD   A,(RewriteSymbolCount)
            OR   A
            JP   NZ,ProofFailure
            CALL ProofRunCompilationEnd
            LD   A,$D0
            LD   (ProofStatus),A
            HALT

ProofLocalAggregateType:
            LD   HL,ProofPartsAggregateType
            LD   BC,(DiagnosticExpectedType<<8)|$D1
            LD   DE,20
            JP   ProofArmLocalDiagnostic

ProofLocalOpenArrayType:
            LD   HL,ProofPartsOpenArrayType
            LD   BC,(DiagnosticExpectedLine<<8)|$D2
            LD   DE,22
            JP   ProofArmLocalDiagnostic

ProofLocalDuplicate:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofExpectedDiagnosticReturn
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,DiagnosticDuplicateName
            LD   (ProofExpectedDiagnostic),A
            LD   A,$D3
            LD   (ProofExpectedStatus),A
            LD   HL,27
            LD   (ProofExpectedOffset),HL
            LD   A,1
            LD   HL,ProofPartsDuplicate
            CALL RewriteSourceInitializeParts
            CALL ProofRunDirectHeader
            CALL ProofRunLocalDefault
            CALL ProofRunLocalDefault
            JP   ProofFailure

ProofLocalCapacity:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofExpectedDiagnosticReturn
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,DiagnosticSymbolCapacity
            LD   (ProofExpectedDiagnostic),A
            LD   A,$D4
            LD   (ProofExpectedStatus),A
            LD   HL,229
            LD   (ProofExpectedOffset),HL
            LD   A,1
            LD   HL,ProofPartsCapacity
            CALL RewriteSourceInitializeParts
            CALL ProofRunDirectHeader
            LD   B,17
ProofLocalCapacityLoop:
            PUSH BC
            CALL ProofRunLocalDefault
            POP  BC
            DJNZ ProofLocalCapacityLoop
            JP   ProofFailure

ProofLocalAfterParameters:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,1
            LD   HL,ProofPartsAfterParameters
            CALL RewriteSourceInitializeParts
            CALL ProofRunDirectHeader
            LD   A,(RewriteCurrentLocalOffset)
            CP   5
            JP   NZ,ProofFailure
            CALL ProofRunLocalDefault
            CALL ProofRunLocalDefault
            LD   A,(RewriteCurrentLocalOffset)
            CP   8
            JP   NZ,ProofFailure
            LD   A,2
            LD   B,RewriteScalarTypeU8
            LD   C,5
            CALL ProofCheckLocal
            LD   A,3
            LD   B,RewriteScalarTypeI16
            LD   C,6
            CALL ProofCheckLocal
            CALL RewriteSemanticValidate
            LD   A,(RewriteSemanticBufferBase)
            CP   6
            JP   NZ,ProofFailure
            LD   HL,RewriteSemanticPayloadBase
            LD   DE,ProofExpectedParameterLocalSemantics
            LD   B,ProofExpectedParameterLocalSemanticsEnd-ProofExpectedParameterLocalSemantics
ProofParameterLocalSemanticLoop:
            LD   A,(DE)
            CP   (HL)
            JP   NZ,ProofFailure
            INC  DE
            INC  HL
            DJNZ ProofParameterLocalSemanticLoop
            CALL ProofRunRoutineEnd
            CALL ProofRunDirectHeader
            CALL ProofRunRoutineEnd
            CALL ProofRunCompilationEnd
            LD   A,$D5
            LD   (ProofStatus),A
            HALT

; HL part descriptor, B diagnostic, C status, DE exact offset.
.routine noreturn
ProofArmLocalDiagnostic:
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
            CALL ProofRunLocalDefault
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
ProofRunDirectHeader:
            LD   HL,RewriteActionProgramRoutineDirectHeader
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunLocalDefault:
            LD   HL,RewriteActionProgramLocalDefault
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

; Exact checked transcript for byte, word, Boolean, signed-byte, signed-word.
ProofExpectedSemantics:
            .db RewriteSemanticDeclareLocalU8,0
            .db RewriteSemanticLiteral16,0,0
            .db RewriteSemanticStoreLocalU8,0
            .db RewriteSemanticDeclareLocal16,1
            .db RewriteSemanticLiteral16,0,0
            .db RewriteSemanticStoreLocal16,1
            .db RewriteSemanticDeclareLocalU8,3
            .db RewriteSemanticLiteral16,0,0
            .db RewriteSemanticStoreLocalU8,3
            .db RewriteSemanticDeclareLocalU8,4
            .db RewriteSemanticLiteral16,0,0
            .db RewriteSemanticStoreLocalU8,4
            .db RewriteSemanticDeclareLocal16,5
            .db RewriteSemanticLiteral16,0,0
            .db RewriteSemanticStoreLocal16,5
ProofExpectedSemanticsEnd:
ProofExpectedParameterLocalSemantics:
            .db RewriteSemanticDeclareLocalU8,5
            .db RewriteSemanticLiteral16,0,0
            .db RewriteSemanticStoreLocalU8,5
            .db RewriteSemanticDeclareLocal16,6
            .db RewriteSemanticLiteral16,0,0
            .db RewriteSemanticStoreLocal16,6
ProofExpectedParameterLocalSemanticsEnd:

            .org $5000
ProofSourceAccepted:
            .db "sub main()",10
            .db "var byte as u8",10
            .db "var word as u16",10
            .db "var ready as boolean",10
            .db "var signedByte as i8",10
            .db "var signedWord as i16",10
            .db "end",10
ProofSourceAcceptedEnd:
ProofSourceAggregateType: .db "sub main()",10,"var x as string[2]",10
ProofSourceAggregateTypeEnd:
ProofSourceOpenArrayType: .db "sub main()",10,"var x as u8[]",10
ProofSourceOpenArrayTypeEnd:
ProofSourceDuplicate: .db "sub main()",10,"var x as u8",10,"var x as u16",10
ProofSourceDuplicateEnd:
ProofSourceCapacity:
            .db "sub main()",10
            .db "var x0 as u8",10,"var x1 as u8",10,"var x2 as u8",10
            .db "var x3 as u8",10,"var x4 as u8",10,"var x5 as u8",10
            .db "var x6 as u8",10,"var x7 as u8",10,"var x8 as u8",10
            .db "var x9 as u8",10,"var x10 as u8",10,"var x11 as u8",10
            .db "var x12 as u8",10,"var x13 as u8",10,"var x14 as u8",10
            .db "var x15 as u8",10,"var x16 as u8",10
ProofSourceCapacityEnd:
ProofSourceAfterParameters:
            .db "sub worker(word as u16, text as string[])",10
            .db "var byte as u8",10
            .db "var signedWord as i16",10
            .db "end",10
            .db "sub main()",10,"end",10
ProofSourceAfterParametersEnd:

ProofPartsAccepted:      .db 1
                         .dw ProofSourceAccepted,ProofSourceAcceptedEnd
ProofPartsAggregateType: .db 1
                         .dw ProofSourceAggregateType,ProofSourceAggregateTypeEnd
ProofPartsOpenArrayType: .db 1
                         .dw ProofSourceOpenArrayType,ProofSourceOpenArrayTypeEnd
ProofPartsDuplicate:     .db 1
                         .dw ProofSourceDuplicate,ProofSourceDuplicateEnd
ProofPartsCapacity:      .db 1
                         .dw ProofSourceCapacity,ProofSourceCapacityEnd
ProofPartsAfterParameters: .db 1
                           .dw ProofSourceAfterParameters,ProofSourceAfterParametersEnd
