; R3 generated scalar-declaration proof. Source strings and action programs are
; data; no .db or .dw directive below encodes a compiler-executed instruction.

CompilerWorkBase    .equ $6000
SourceBase          .equ $5000
SourceLimit         .equ $5800
RewriteAdapterBase  .equ $A000
RewriteAdapterLimit .equ $A100
DebugHooks          .equ 0

            .org $1000
ProofScalarDeclarations:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,1
            LD   HL,ProofPartsDeclarations
            CALL RewriteSourceInitializeParts
            CALL ProofRunConstantProgram
            CALL ProofRunAssertProgram
            CALL ProofRunConstantProgram
            CALL ProofRunConstantProgram
            CALL ProofRunAssertProgram
            CALL RewriteParserTake
            CP   TokenEof
            JP   NZ,ProofFailure
            LD   A,(RewriteSymbolCount)
            CP   3
            JP   NZ,ProofFailure

            LD   A,RewriteScalarTypeExact
            LD   BC,3
            LD   DE,ProofNameAnswer
            LD   H,6
            CALL ProofCheckConstant
            LD   A,RewriteTypeMetaNegative
            LD   BC,$FFFF
            LD   DE,ProofNameNegative
            LD   H,8
            CALL ProofCheckConstant
            LD   A,RewriteScalarTypeExact
            LD   BC,7
            LD   DE,ProofNamePositive
            LD   H,8
            CALL ProofCheckConstant
            LD   A,$C6
            LD   (ProofStatus),A
            HALT

ProofScalarDeclarationDiagnostics:
            LD   SP,$FF00
            XOR  A
            LD   (ProofCase),A
            LD   A,DiagnosticAssertionFailed
            LD   BC,0
            LD   DE,ProofDiagnosticFalseAssert
            LD   HL,ProofPartsFalseAssert
            JP   ProofArmAssertDiagnostic
ProofDiagnosticFalseAssert:
            CALL ProofCheckDiagnostic
            LD   A,DiagnosticTypeMismatch
            LD   BC,0
            LD   DE,ProofDiagnosticAssertType
            LD   HL,ProofPartsIntegerAssert
            JP   ProofArmAssertDiagnostic
ProofDiagnosticAssertType:
            CALL ProofCheckDiagnostic
            LD   A,DiagnosticExpectedEqual
            LD   BC,8
            LD   DE,ProofDiagnosticExpectedEqual
            LD   HL,ProofPartsMissingEqual
            JP   ProofArmConstantDiagnostic
ProofDiagnosticExpectedEqual:
            CALL ProofCheckDiagnostic
            LD   A,DiagnosticDivisionZero
            LD   BC,12
            LD   DE,ProofDiagnosticDivision
            LD   HL,ProofPartsDivision
            JP   ProofArmConstantDiagnostic
ProofDiagnosticDivision:
            CALL ProofCheckDiagnostic
            LD   A,(RewriteSymbolCount)
            OR   A
            JP   NZ,ProofFailure

            ; Duplicate checking sees only the first committed entry and is
            ; anchored to the second source spelling.
            CALL RewriteReset
            LD   HL,ProofDiagnosticDuplicate
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,DiagnosticDuplicateName
            LD   (ProofExpectedDiagnostic),A
            LD   HL,18
            LD   (ProofExpectedOffset),HL
            LD   A,1
            LD   HL,ProofPartsDuplicate
            CALL RewriteSourceInitializeParts
            CALL ProofRunConstantProgram
            CALL ProofRunConstantProgram
            JP   ProofFailure
ProofDiagnosticDuplicate:
            CALL ProofCheckDiagnostic
            LD   A,(RewriteSymbolCount)
            CP   1
            JP   NZ,ProofFailure

            ; A fresh compile after failure must not see the provisional entry.
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,1
            LD   HL,ProofPartsRecovery
            CALL RewriteSourceInitializeParts
            CALL ProofRunConstantProgram
            LD   A,(RewriteSymbolCount)
            CP   1
            JP   NZ,ProofFailure
            LD   A,$C7
            LD   (ProofStatus),A
            HALT

ProofProgramVariables:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,1
            LD   HL,ProofPartsPrograms
            CALL RewriteSourceInitializeParts
            CALL ProofRunProgramBss
            CALL ProofRunProgramScalar
            CALL ProofRunProgramBss
            CALL ProofRunProgramScalar
            CALL ProofRunProgramScalar
            CALL ProofRunProgramScalar
            CALL ProofRunProgramScalar
            CALL ProofRunProgramScalar
            CALL RewriteParserTake
            CP   TokenEof
            JP   NZ,ProofFailure
            LD   A,(RewriteSymbolCount)
            CP   8
            JP   NZ,ProofFailure
            LD   A,0
            LD   B,RewriteScalarTypeU16
            LD   C,RewriteSymbolStorageBss
            LD   DE,0
            CALL ProofCheckProgramEntry
            LD   A,1
            LD   B,RewriteScalarTypeBoolean
            LD   C,RewriteSymbolStorageInitialized
            LD   DE,0
            CALL ProofCheckProgramEntry
            LD   A,2
            LD   B,RewriteFirstOwnedTypeId
            LD   C,RewriteSymbolStorageBss
            LD   DE,2
            CALL ProofCheckProgramEntry
            LD   A,3
            LD   B,RewriteScalarTypeI8
            LD   C,RewriteSymbolStorageInitialized
            LD   DE,1
            CALL ProofCheckProgramEntry
            LD   A,4
            LD   B,RewriteScalarTypeU8
            LD   C,RewriteSymbolStorageInitialized
            LD   DE,2
            CALL ProofCheckProgramEntry
            LD   A,5
            LD   B,RewriteScalarTypeU16
            LD   C,RewriteSymbolStorageInitialized
            LD   DE,3
            CALL ProofCheckProgramEntry
            LD   A,6
            LD   B,RewriteScalarTypeI16
            LD   C,RewriteSymbolStorageInitialized
            LD   DE,5
            CALL ProofCheckProgramEntry
            LD   A,7
            LD   B,RewriteScalarTypeI16
            LD   C,RewriteSymbolStorageInitialized
            LD   DE,7
            CALL ProofCheckProgramEntry
            LD   HL,(RewriteStaticBssLength)
            LD   DE,4
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   HL,(RewriteStaticInitializedLength)
            LD   DE,9
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   A,(RewriteStaticImageBase)
            CP   1
            JP   NZ,ProofFailure
            LD   A,(RewriteStaticImageBase+1)
            CP   $FF
            JP   NZ,ProofFailure
            LD   A,(RewriteStaticImageBase+2)
            OR   A
            JP   NZ,ProofFailure
            LD   A,(RewriteStaticImageBase+3)
            CP   $FF
            JP   NZ,ProofFailure
            LD   A,(RewriteStaticImageBase+4)
            OR   A
            JP   NZ,ProofFailure
            LD   A,(RewriteStaticImageBase+5)
            CP   $FF
            JP   NZ,ProofFailure
            LD   A,(RewriteStaticImageBase+6)
            CP   $FF
            JP   NZ,ProofFailure
            LD   A,(RewriteStaticImageBase+7)
            CP   $FF
            JP   NZ,ProofFailure
            LD   A,(RewriteStaticImageBase+8)
            OR   A
            JP   NZ,ProofFailure
            LD   A,$C8
            LD   (ProofStatus),A
            HALT

ProofProgramVariableDiagnostics:
            LD   SP,$FF00
            XOR  A
            LD   (ProofCase),A
            LD   A,DiagnosticTypeBound
            LD   BC,14
            LD   DE,ProofDiagnosticOpenArray
            LD   HL,ProofPartsOpenArray
            JP   ProofArmProgramBssDiagnostic
ProofDiagnosticOpenArray:
            CALL ProofCheckDiagnostic
            LD   A,DiagnosticTypeBound
            LD   BC,19
            LD   DE,ProofDiagnosticOpenString
            LD   HL,ProofPartsOpenString
            JP   ProofArmProgramBssDiagnostic
ProofDiagnosticOpenString:
            CALL ProofCheckDiagnostic
            LD   A,DiagnosticTypeMismatch
            LD   BC,19
            LD   DE,ProofDiagnosticProgramType
            LD   HL,ProofPartsProgramType
            JP   ProofArmProgramScalarDiagnostic
ProofDiagnosticProgramType:
            CALL ProofCheckDiagnostic
            LD   A,DiagnosticIntegerRange
            LD   BC,15
            LD   DE,ProofDiagnosticProgramRange
            LD   HL,ProofPartsProgramRange
            JP   ProofArmProgramScalarDiagnostic
ProofDiagnosticProgramRange:
            CALL ProofCheckDiagnostic
            LD   A,DiagnosticIntegerRange
            LD   BC,16
            LD   DE,ProofDiagnosticProgramNestedRange
            LD   HL,ProofPartsProgramNestedRange
            JP   ProofArmProgramScalarDiagnostic
ProofDiagnosticProgramNestedRange:
            CALL ProofCheckDiagnostic
            LD   A,DiagnosticUnknownName
            LD   BC,14
            LD   DE,ProofDiagnosticProgramSelf
            LD   HL,ProofPartsProgramSelf
            JP   ProofArmProgramScalarDiagnostic
ProofDiagnosticProgramSelf:
            CALL ProofCheckDiagnostic
            LD   A,(RewriteSymbolCount)
            OR   A
            JP   NZ,ProofFailure

            ; A committed program variable is visible to duplicate checking,
            ; while the rejected second provisional entry is never published.
            CALL RewriteReset
            LD   HL,ProofDiagnosticProgramDuplicate
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,DiagnosticDuplicateName
            LD   (ProofExpectedDiagnostic),A
            LD   HL,20
            LD   (ProofExpectedOffset),HL
            LD   A,1
            LD   HL,ProofPartsProgramDuplicate
            CALL RewriteSourceInitializeParts
            CALL ProofRunProgramScalar
            CALL ProofRunProgramScalar
            JP   ProofFailure
ProofDiagnosticProgramDuplicate:
            CALL ProofCheckDiagnostic
            LD   A,(RewriteSymbolCount)
            CP   1
            JP   NZ,ProofFailure
            LD   A,$C9
            LD   (ProofStatus),A
            HALT

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunConstantProgram:
            LD   HL,RewriteActionProgramScalarConstant
            JP   RewriteActionRun

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunAssertProgram:
            LD   HL,RewriteActionProgramAssert
            JP   RewriteActionRun

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunProgramBss:
            LD   HL,RewriteActionProgramProgramBss
            JP   RewriteActionRun

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunProgramScalar:
            LD   HL,RewriteActionProgramProgramScalarInitialized
            JP   RewriteActionRun

; A entry, B expected type, C storage, DE payload.
.routine in A,B,C,DE out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ProofCheckProgramEntry:
            LD   (ProofExpectedPayload),DE
            PUSH AF
            LD   A,B
            LD   (ProofExpectedType),A
            LD   A,C
            LD   (ProofExpectedStorage),A
            POP  AF
            CALL RewriteSymbolAddress
            LD   DE,RewriteSymbolClass
            ADD  HL,DE
            LD   A,(HL)
            CP   RewriteSymbolClassProgram
            JP   NZ,ProofFailure
            INC  HL
            LD   A,(HL)
            LD   B,A
            LD   A,(ProofExpectedType)
            CP   B
            JP   NZ,ProofFailure
            INC  HL
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            PUSH HL
            LD   HL,(ProofExpectedPayload)
            OR   A
            SBC  HL,DE
            POP  HL
            JP   NZ,ProofFailure
            INC  HL
            LD   A,(HL)
            LD   B,A
            LD   A,(ProofExpectedStorage)
            CP   B
            JP   NZ,ProofFailure
            RET

; A expected type, BC expected payload, DE comparison spelling, H length.
.routine in A,BC,DE,H out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ProofCheckConstant:
            LD   (ProofExpectedType),A
            LD   (ProofExpectedPayload),BC
            LD   (TokenLexemePointer),DE
            LD   A,H
            LD   (TokenLength),A
            CALL RewriteSymbolFindCurrent
            JP   NC,ProofFailure
            LD   DE,RewriteSymbolClass
            ADD  HL,DE
            LD   A,(HL)
            CP   RewriteSymbolClassConstant
            JP   NZ,ProofFailure
            INC  HL
            LD   A,(ProofExpectedType)
            CP   (HL)
            JP   NZ,ProofFailure
            INC  HL
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            LD   HL,(ProofExpectedPayload)
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            RET

; A/BC expected diagnostic, DE continuation, HL source parts.
.routine noreturn
ProofArmConstantDiagnostic:
            LD   (ProofExpectedDiagnostic),A
            LD   (ProofExpectedOffset),BC
            LD   (ProofDiagnosticContinuation),DE
            PUSH HL
            CALL RewriteReset
            POP  HL
            LD   DE,(ProofDiagnosticContinuation)
            PUSH DE
            LD   (CompilerAbortSp),SP
            LD   A,1
            CALL RewriteSourceInitializeParts
            CALL ProofRunConstantProgram
            JP   ProofFailure

; A/BC expected diagnostic, DE continuation, HL source parts.
.routine noreturn
ProofArmAssertDiagnostic:
            LD   (ProofExpectedDiagnostic),A
            LD   (ProofExpectedOffset),BC
            LD   (ProofDiagnosticContinuation),DE
            PUSH HL
            CALL RewriteReset
            POP  HL
            LD   DE,(ProofDiagnosticContinuation)
            PUSH DE
            LD   (CompilerAbortSp),SP
            LD   A,1
            CALL RewriteSourceInitializeParts
            CALL ProofRunAssertProgram
            JP   ProofFailure

.routine noreturn
ProofArmProgramBssDiagnostic:
            LD   (ProofExpectedDiagnostic),A
            LD   (ProofExpectedOffset),BC
            LD   (ProofDiagnosticContinuation),DE
            PUSH HL
            CALL RewriteReset
            POP  HL
            LD   DE,(ProofDiagnosticContinuation)
            PUSH DE
            LD   (CompilerAbortSp),SP
            LD   A,1
            CALL RewriteSourceInitializeParts
            CALL ProofRunProgramBss
            JP   ProofFailure

.routine noreturn
ProofArmProgramScalarDiagnostic:
            LD   (ProofExpectedDiagnostic),A
            LD   (ProofExpectedOffset),BC
            LD   (ProofDiagnosticContinuation),DE
            PUSH HL
            CALL RewriteReset
            POP  HL
            LD   DE,(ProofDiagnosticContinuation)
            PUSH DE
            LD   (CompilerAbortSp),SP
            LD   A,1
            CALL RewriteSourceInitializeParts
            CALL ProofRunProgramScalar
            JP   ProofFailure

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ProofCheckDiagnostic:
            LD   HL,ProofCase
            INC  (HL)
            LD   A,(ProofExpectedDiagnostic)
            LD   B,A
            LD   A,(DiagnosticCode)
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

ProofStatus:                 .db 0
ProofCase:                   .db 0
ProofExpectedType:           .db 0
ProofExpectedPayload:        .dw 0
ProofExpectedStorage:        .db 0
ProofExpectedDiagnostic:     .db 0
ProofExpectedOffset:         .dw 0
ProofDiagnosticContinuation: .dw 0

            .org $4800
ProofNameAnswer:   .db "answer"
ProofNameNegative: .db "negative"
ProofNamePositive: .db "positive"

ProofSourceDeclarations:
            .db "const answer = 1+2",10
            .db "assert answer = 3",10
            .db "const negative = i16(-1)",10
            .db "const positive = i16(7)",10
            .db "assert negative < positive",10
ProofSourceDeclarationsEnd:
ProofSourceFalseAssert:   .db "assert false"
ProofSourceFalseAssertEnd:
ProofSourceIntegerAssert: .db "assert 1"
ProofSourceIntegerAssertEnd:
ProofSourceMissingEqual:  .db "const x 1"
ProofSourceMissingEqualEnd:
ProofSourceDivision:      .db "const x = 1/0"
ProofSourceDivisionEnd:
ProofSourceDuplicate:     .db "const x = 1",10,"const x = 2"
ProofSourceDuplicateEnd:
ProofSourceRecovery:      .db "const x = 7"
ProofSourceRecoveryEnd:
ProofSourcePrograms:
            .db "var count as u16",10
            .db "var flag as boolean = true",10
            .db "var row as u8[2]",10
            .db "var signed as i8 = -1",10
            .db "var wrapped as u8 = 255+1",10
            .db "var wide as u16 = u8(255)",10
            .db "var promoted as i16 = i8(-1)",10
            .db "var positive as i16 = u8(255)",10
ProofSourceProgramsEnd:
ProofSourceOpenArray:    .db "var bad as u8[]"
ProofSourceOpenArrayEnd:
ProofSourceOpenString:   .db "var bad as string[]"
ProofSourceOpenStringEnd:
ProofSourceProgramType:  .db "var x as u8 = i8(1)"
ProofSourceProgramTypeEnd:
ProofSourceProgramRange: .db "var x as u8 = -1"
ProofSourceProgramRangeEnd:
ProofSourceProgramNestedRange: .db "var x as u8 = ((256))"
ProofSourceProgramNestedRangeEnd:
ProofSourceProgramSelf: .db "var x as u8 = x"
ProofSourceProgramSelfEnd:
ProofSourceProgramDuplicate:
            .db "var x as u8 = 1",10,"var x as u8 = 2"
ProofSourceProgramDuplicateEnd:

ProofPartsDeclarations:  .db 1
                         .dw ProofSourceDeclarations,ProofSourceDeclarationsEnd
ProofPartsFalseAssert:   .db 1
                         .dw ProofSourceFalseAssert,ProofSourceFalseAssertEnd
ProofPartsIntegerAssert: .db 1
                         .dw ProofSourceIntegerAssert,ProofSourceIntegerAssertEnd
ProofPartsMissingEqual:  .db 1
                         .dw ProofSourceMissingEqual,ProofSourceMissingEqualEnd
ProofPartsDivision:      .db 1
                         .dw ProofSourceDivision,ProofSourceDivisionEnd
ProofPartsDuplicate:     .db 1
                         .dw ProofSourceDuplicate,ProofSourceDuplicateEnd
ProofPartsRecovery:      .db 1
                         .dw ProofSourceRecovery,ProofSourceRecoveryEnd
ProofPartsPrograms:      .db 1
                         .dw ProofSourcePrograms,ProofSourceProgramsEnd
ProofPartsOpenArray:     .db 1
                         .dw ProofSourceOpenArray,ProofSourceOpenArrayEnd
ProofPartsOpenString:    .db 1
                         .dw ProofSourceOpenString,ProofSourceOpenStringEnd
ProofPartsProgramType:   .db 1
                         .dw ProofSourceProgramType,ProofSourceProgramTypeEnd
ProofPartsProgramRange:  .db 1
                         .dw ProofSourceProgramRange,ProofSourceProgramRangeEnd
ProofPartsProgramNestedRange:
                         .db 1
                         .dw ProofSourceProgramNestedRange,ProofSourceProgramNestedRangeEnd
ProofPartsProgramSelf:   .db 1
                         .dw ProofSourceProgramSelf,ProofSourceProgramSelfEnd
ProofPartsProgramDuplicate:
                         .db 1
                         .dw ProofSourceProgramDuplicate,ProofSourceProgramDuplicateEnd
