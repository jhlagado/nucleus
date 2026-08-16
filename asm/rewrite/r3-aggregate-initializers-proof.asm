; R3 recursive static-initializer proof. Directive data below is source text,
; expected object data, or proof state; it never hides executable opcodes.

CompilerWorkBase    .equ $6000
SourceBase          .equ $5000
SourceLimit         .equ $5800
RewriteAdapterBase  .equ $A000
RewriteAdapterLimit .equ $A100
DebugHooks          .equ 0

            .org $1000
ProofAggregateInitializers:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,1
            LD   HL,ProofPartsAccepted
            CALL RewriteSourceInitializeParts
            CALL ProofRunRecordBegin
            CALL ProofRunRecordField
            CALL ProofRunRecordField
            CALL ProofRunRecordEnd
            CALL ProofRunAggregateConstant
            CALL ProofRunAggregateConstant
            CALL ProofRunProgramAggregate
            CALL ProofRunProgramAggregate
            CALL RewriteParserTake
            CP   TokenEof
            JP   NZ,ProofFailure
            LD   A,(RewriteSymbolCount)
            CP   5
            JP   NZ,ProofFailure
            LD   HL,(RewriteStaticInitializedLength)
            LD   DE,7
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   HL,(RewriteStaticConstantLength)
            LD   DE,13
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   HL,RewriteStaticImageBase
            LD   DE,ProofExpectedImage
            LD   B,20
_ProofAggregateImageLoop:
            LD   A,(DE)
            CP   (HL)
            JP   NZ,ProofFailure
            INC  DE
            INC  HL
            DJNZ _ProofAggregateImageLoop
            LD   A,1
            LD   B,RewriteSymbolClassConstant
            LD   C,RewriteSymbolStorageReadOnly
            LD   DE,0
            CALL ProofCheckSymbol
            LD   A,2
            LD   B,RewriteSymbolClassConstant
            LD   C,RewriteSymbolStorageReadOnly
            LD   DE,6
            CALL ProofCheckSymbol
            LD   A,3
            LD   B,RewriteSymbolClassProgram
            LD   C,RewriteSymbolStorageInitialized
            LD   DE,0
            CALL ProofCheckSymbol
            LD   A,4
            LD   B,RewriteSymbolClassProgram
            LD   C,RewriteSymbolStorageInitialized
            LD   DE,3
            CALL ProofCheckSymbol
            LD   A,$E0
            LD   (ProofStatus),A
            HALT

ProofInitializerShapeDiagnostic:
            LD   HL,ProofPartsShape
            LD   BC,(DiagnosticInitializerShape<<8)|$E1
            JP   ProofArmAggregateConstantDiagnostic
ProofInitializerCountDiagnostic:
            LD   HL,ProofPartsCount
            LD   BC,(DiagnosticInitializerCount<<8)|$E2
            JP   ProofArmAggregateConstantDiagnostic
ProofInitializerStringDiagnostic:
            LD   HL,ProofPartsString
            LD   BC,(DiagnosticStringLength<<8)|$E3
            JP   ProofArmAggregateConstantDiagnostic
ProofInitializerDepthDiagnostic:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofExpectedDepthReturn
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,1
            LD   HL,ProofPartsDepth
            CALL RewriteSourceInitializeParts
            LD   B,5
_ProofDepthRecordLoop:
            PUSH BC
            CALL ProofRunRecordBegin
            CALL ProofRunRecordField
            CALL ProofRunRecordEnd
            POP  BC
            DJNZ _ProofDepthRecordLoop
            CALL ProofRunAggregateConstant
            JP   ProofFailure
ProofExpectedDepthReturn:
            LD   A,(DiagnosticCode)
            CP   DiagnosticInitializerCapacity
            JP   NZ,ProofFailure
            LD   A,(DiagnosticPartId)
            CP   1
            JP   NZ,ProofFailure
            LD   A,$E4
            LD   (ProofStatus),A
            HALT
ProofInitializerScalarConstantDiagnostic:
            LD   HL,ProofPartsScalarConstant
            LD   BC,(DiagnosticTypeMismatch<<8)|$E5
            JP   ProofArmAggregateConstantDiagnostic
ProofInitializerProgramPreflightDiagnostic:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofExpectedProgramCapacityReturn
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   HL,1024
            LD   (RewriteStaticInitializedLength),HL
            LD   A,1
            LD   HL,ProofPartsProgramPreflight
            CALL RewriteSourceInitializeParts
            CALL ProofRunProgramAggregate
            JP   ProofFailure
ProofExpectedProgramCapacityReturn:
            LD   A,(DiagnosticCode)
            CP   DiagnosticProgramDataCapacity
            JP   NZ,ProofFailure
            LD   HL,(RewriteStaticInitializedLength)
            LD   DE,1024
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   A,$E6
            LD   (ProofStatus),A
            HALT
ProofInitializerReadOnlyPreflightDiagnostic:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofExpectedReadOnlyCapacityReturn
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   HL,1024
            LD   (RewriteStaticConstantLength),HL
            LD   A,1
            LD   HL,ProofPartsConstantPreflight
            CALL RewriteSourceInitializeParts
            CALL ProofRunAggregateConstant
            JP   ProofFailure
ProofExpectedReadOnlyCapacityReturn:
            LD   A,(DiagnosticCode)
            CP   DiagnosticReadOnlyCapacity
            JP   NZ,ProofFailure
            LD   HL,(RewriteStaticConstantLength)
            LD   DE,1024
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   A,$E7
            LD   (ProofStatus),A
            HALT

; HL is a one-part descriptor, B expected diagnostic, C success marker.
.routine noreturn
ProofArmAggregateConstantDiagnostic:
            LD   A,B
            LD   (ProofExpectedDiagnostic),A
            LD   A,C
            LD   (ProofExpectedStatus),A
            PUSH HL
            CALL RewriteReset
            POP  DE
            LD   HL,ProofExpectedDiagnosticReturn
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,1
            EX   DE,HL
            CALL RewriteSourceInitializeParts
            CALL ProofRunAggregateConstant
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
            LD   A,(RewriteSymbolCount)
            OR   A
            JP   NZ,ProofFailure
            LD   A,(RewriteStaticInitializedLength)
            OR   A
            JP   NZ,ProofFailure
            LD   A,(RewriteStaticConstantLength)
            OR   A
            JP   NZ,ProofFailure
            LD   A,(ProofExpectedStatus)
            LD   (ProofStatus),A
            HALT

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunRecordBegin:
            LD   HL,RewriteActionProgramRecordBegin
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunRecordField:
            LD   HL,RewriteActionProgramRecordField
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunRecordEnd:
            LD   HL,RewriteActionProgramRecordEnd
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunAggregateConstant:
            LD   HL,RewriteActionProgramAggregateConstant
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunProgramAggregate:
            LD   HL,RewriteActionProgramProgramAggregateInitialized
            JP   RewriteActionRun

; A symbol ordinal, B class, C storage, DE full segment-relative payload.
.routine in A,B,C,DE out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ProofCheckSymbol:
            LD   (ProofExpectedPayload),DE
            PUSH BC
            CALL RewriteSymbolAddress
            POP  BC
            LD   DE,RewriteSymbolClass
            ADD  HL,DE
            LD   A,(HL)
            CP   B
            JP   NZ,ProofFailure
            INC  HL
            INC  HL
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            INC  HL
            LD   A,(HL)
            CP   C
            JP   NZ,ProofFailure
            LD   HL,(ProofExpectedPayload)
            OR   A
            SBC  HL,DE
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
ProofExpectedPayload:    .dw 0
ProofExpectedImage:
            ; Initialized prefix: Pair then nested i8 array.
            .db 7,$56,$34,$FF,2,3,$FC
            ; Constant suffix: Pair[2], then string[5] with embedded zero.
            .db 1,$34,$12,2,$CD,$AB,3,"a",0,"B",0,0,0

            .org $5000
ProofSourceAccepted:
            .db "record Pair",10,"left as u8",10,"right as u16",10,"end",10
            .db "const pairs as Pair[2] = [(1,$1234),(2,$ABCD)]",10
            .db "const text as string[5] = ",$22,"a",$5C,"0",$5C,"x42",$22,10
            .db "var current as Pair = (7,$3456)",10
            .db "var grid as i8[2][2] = [[-1,2],[3,-4]]"
ProofSourceAcceptedEnd:
ProofSourceShape: .db "const a as u8[2] = (1,2)"
ProofSourceShapeEnd:
ProofSourceCount: .db "const a as u8[2] = [1]"
ProofSourceCountEnd:
ProofSourceString: .db "const a as string[2] = ",$22,"abc",$22
ProofSourceStringEnd:
ProofSourceDepth:
            .db "record R1",10,"v as u8",10,"end",10
            .db "record R2",10,"v as R1",10,"end",10
            .db "record R3",10,"v as R2",10,"end",10
            .db "record R4",10,"v as R3",10,"end",10
            .db "record R5",10,"v as R4",10,"end",10
            .db "const a as R5 = (((((1)))))"
ProofSourceDepthEnd:
ProofSourceScalarConstant: .db "const a as u8 = 1"
ProofSourceScalarConstantEnd:
ProofSourceProgramPreflight: .db "var a as string[1] = ("
ProofSourceProgramPreflightEnd:
ProofSourceConstantPreflight: .db "const a as string[1] = ("
ProofSourceConstantPreflightEnd:

ProofPartsAccepted:       .db 1
                          .dw ProofSourceAccepted,ProofSourceAcceptedEnd
ProofPartsShape:          .db 1
                          .dw ProofSourceShape,ProofSourceShapeEnd
ProofPartsCount:          .db 1
                          .dw ProofSourceCount,ProofSourceCountEnd
ProofPartsString:         .db 1
                          .dw ProofSourceString,ProofSourceStringEnd
ProofPartsDepth:          .db 1
                          .dw ProofSourceDepth,ProofSourceDepthEnd
ProofPartsScalarConstant: .db 1
                          .dw ProofSourceScalarConstant,ProofSourceScalarConstantEnd
ProofPartsProgramPreflight: .db 1
                            .dw ProofSourceProgramPreflight,ProofSourceProgramPreflightEnd
ProofPartsConstantPreflight: .db 1
                             .dw ProofSourceConstantPreflight,ProofSourceConstantPreflightEnd
