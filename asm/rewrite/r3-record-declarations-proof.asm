; R3 generated record-declaration proof. Source strings and expected data use
; .db/.dw; no directive below encodes a compiler-executed Z80 instruction.

CompilerWorkBase    .equ $6000
SourceBase          .equ $5000
SourceLimit         .equ $5800
RewriteAdapterBase  .equ $A000
RewriteAdapterLimit .equ $A100
DebugHooks          .equ 0

            .org $1000
ProofRecordDeclarations:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,1
            LD   HL,ProofPartsRecords
            CALL RewriteSourceInitializeParts
            CALL ProofRunRecordBegin
            CALL ProofRunRecordField
            CALL ProofRunRecordField
            CALL ProofRunRecordEnd
            CALL ProofRunRecordBegin
            CALL ProofRunRecordField
            CALL ProofRunRecordField
            CALL ProofRunRecordEnd
            CALL RewriteParserTake
            CP   TokenEof
            JP   NZ,ProofFailure
            LD   A,(RewriteRecordCount)
            CP   2
            JP   NZ,ProofFailure
            LD   A,(RewriteFieldCount)
            CP   4
            JP   NZ,ProofFailure
            LD   A,(RewriteTypeCount)
            CP   3
            JP   NZ,ProofFailure
            LD   A,(RewriteSymbolCount)
            CP   2
            JP   NZ,ProofFailure

            LD   A,RewriteFirstOwnedTypeId
            LD   DE,3
            CALL ProofCheckTypeExtent
            LD   A,RewriteFirstOwnedTypeId+1
            LD   DE,2
            CALL ProofCheckTypeExtent
            LD   A,RewriteFirstOwnedTypeId+2
            LD   DE,5
            CALL ProofCheckTypeExtent

            LD   A,0
            LD   B,RewriteFirstOwnedTypeId
            CALL ProofCheckRecordSymbol
            LD   A,1
            LD   B,RewriteFirstOwnedTypeId+2
            CALL ProofCheckRecordSymbol

            LD   A,0
            LD   B,RewriteScalarTypeU8
            LD   DE,0
            CALL ProofCheckField
            LD   A,1
            LD   B,RewriteScalarTypeU16
            LD   DE,1
            CALL ProofCheckField
            LD   A,2
            LD   B,RewriteFirstOwnedTypeId
            LD   DE,0
            CALL ProofCheckField
            LD   A,3
            LD   B,RewriteFirstOwnedTypeId+1
            LD   DE,3
            CALL ProofCheckField

            LD   A,(RewriteRecordTableBase+RewriteRecordFieldStart)
            OR   A
            JP   NZ,ProofFailure
            LD   A,(RewriteRecordTableBase+RewriteRecordFieldCount)
            CP   2
            JP   NZ,ProofFailure
            LD   A,(RewriteRecordTableBase+RewriteRecordEntrySize+RewriteRecordFieldStart)
            CP   2
            JP   NZ,ProofFailure
            LD   A,(RewriteRecordTableBase+RewriteRecordEntrySize+RewriteRecordFieldCount)
            CP   2
            JP   NZ,ProofFailure
            LD   A,$CA
            LD   (ProofStatus),A
            HALT

ProofRecordDeclarationDiagnostics:
            LD   SP,$FF00
            XOR  A
            LD   (ProofCase),A
            LD   A,DiagnosticRecordEmpty
            LD   BC,9
            LD   DE,ProofDiagnosticEmpty
            LD   HL,ProofPartsEmpty
            JP   ProofArmRecordEndDiagnostic
ProofDiagnosticEmpty:
            CALL ProofCheckDiagnostic
            LD   A,DiagnosticDuplicateName
            LD   BC,17
            LD   DE,ProofDiagnosticDuplicateField
            LD   HL,ProofPartsDuplicateField
            JP   ProofArmSecondFieldDiagnostic
ProofDiagnosticDuplicateField:
            CALL ProofCheckDiagnostic
            LD   A,DiagnosticUnknownName
            LD   BC,14
            LD   DE,ProofDiagnosticSelfType
            LD   HL,ProofPartsSelfType
            JP   ProofArmFirstFieldDiagnostic
ProofDiagnosticSelfType:
            CALL ProofCheckDiagnostic
            LD   A,DiagnosticTypeBound
            LD   BC,18
            LD   DE,ProofDiagnosticOpenField
            LD   HL,ProofPartsOpenField
            JP   ProofArmFirstFieldDiagnostic
ProofDiagnosticOpenField:
            CALL ProofCheckDiagnostic
            LD   A,DiagnosticTypeBound
            LD   BC,22
            LD   DE,ProofDiagnosticOpenStringField
            LD   HL,ProofPartsOpenStringField
            JP   ProofArmFirstFieldDiagnostic
ProofDiagnosticOpenStringField:
            CALL ProofCheckDiagnostic
            LD   A,DiagnosticProgramDataCapacity
            LD   BC,30
            LD   DE,ProofDiagnosticExtent
            LD   HL,ProofPartsExtent
            JP   ProofArmSecondFieldDiagnostic
ProofDiagnosticExtent:
            CALL ProofCheckDiagnostic

            CALL RewriteReset
            LD   HL,ProofDiagnosticDuplicateRecord
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,DiagnosticDuplicateName
            LD   (ProofExpectedDiagnostic),A
            LD   HL,28
            LD   (ProofExpectedOffset),HL
            LD   A,1
            LD   HL,ProofPartsDuplicateRecord
            CALL RewriteSourceInitializeParts
            CALL ProofRunRecordBegin
            CALL ProofRunRecordField
            CALL ProofRunRecordEnd
            CALL ProofRunRecordBegin
            JP   ProofFailure
ProofDiagnosticDuplicateRecord:
            CALL ProofCheckDiagnostic
            LD   A,(RewriteSymbolCount)
            CP   1
            JP   NZ,ProofFailure
            LD   A,$CB
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

; A type, DE expected extent.
.routine in A,DE out A,carry,zero clobbers sign,parity,halfCarry,DE,HL
ProofCheckTypeExtent:
            PUSH DE
            CALL RewriteTypeStaticExtent
            POP  DE
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            RET

; A symbol entry, B expected record type.
.routine in A,B out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ProofCheckRecordSymbol:
            LD   C,B
            CALL RewriteSymbolAddress
            LD   DE,RewriteSymbolClass
            ADD  HL,DE
            LD   A,(HL)
            CP   RewriteSymbolClassRecordType
            JP   NZ,ProofFailure
            INC  HL
            LD   A,(HL)
            CP   C
            JP   NZ,ProofFailure
            RET

; A field entry, B expected type, DE expected offset.
.routine in A,B,DE out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ProofCheckField:
            LD   (ProofExpectedOffset),DE
            LD   C,B
            CALL RewriteFieldAddress
            LD   DE,RewriteFieldType
            ADD  HL,DE
            LD   A,(HL)
            CP   C
            JP   NZ,ProofFailure
            INC  HL
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            LD   HL,(ProofExpectedOffset)
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            RET

; A/BC expected diagnostic, DE continuation, HL source parts.
.routine noreturn
ProofArmRecordEndDiagnostic:
            CALL ProofArmDiagnostic
            LD   DE,(ProofDiagnosticContinuation)
            PUSH DE
            LD   (CompilerAbortSp),SP
            CALL ProofRunRecordBegin
            CALL ProofRunRecordEnd
            JP   ProofFailure

.routine noreturn
ProofArmFirstFieldDiagnostic:
            CALL ProofArmDiagnostic
            LD   DE,(ProofDiagnosticContinuation)
            PUSH DE
            LD   (CompilerAbortSp),SP
            CALL ProofRunRecordBegin
            CALL ProofRunRecordField
            JP   ProofFailure

.routine noreturn
ProofArmSecondFieldDiagnostic:
            CALL ProofArmDiagnostic
            LD   DE,(ProofDiagnosticContinuation)
            PUSH DE
            LD   (CompilerAbortSp),SP
            CALL ProofRunRecordBegin
            CALL ProofRunRecordField
            CALL ProofRunRecordField
            JP   ProofFailure

; A/BC expected diagnostic, DE continuation, HL source parts.
.routine in A,BC,DE,HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ProofArmDiagnostic:
            LD   (ProofExpectedDiagnostic),A
            LD   (ProofExpectedOffset),BC
            LD   (ProofDiagnosticContinuation),DE
            PUSH HL
            CALL RewriteReset
            POP  HL
            LD   A,1
            CALL RewriteSourceInitializeParts
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,DE,HL
ProofCheckDiagnostic:
            LD   HL,ProofCase
            INC  (HL)
            LD   A,(ProofExpectedDiagnostic)
            LD   D,A
            LD   A,(DiagnosticCode)
            CP   D
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
ProofExpectedDiagnostic:     .db 0
ProofExpectedOffset:         .dw 0
ProofDiagnosticContinuation: .dw 0

            .org $7000
ProofSourceRecords:
            .db "record Pair",10
            .db "left as u8",10
            .db "right as u16",10
            .db "end",10
            .db "record Box",10
            ; Field-name identity is scoped to its containing record.
            .db "left as Pair",10
            .db "flags as boolean[2]",10
            .db "end"
ProofSourceRecordsEnd:
ProofSourceEmpty: .db "record R",10,"end"
ProofSourceEmptyEnd:
ProofSourceDuplicateField: .db "record R",10,"x as u8",10,"x as Missing"
ProofSourceDuplicateFieldEnd:
ProofSourceSelfType: .db "record R",10,"x as R"
ProofSourceSelfTypeEnd:
ProofSourceOpenField: .db "record R",10,"x as u8[]"
ProofSourceOpenFieldEnd:
ProofSourceOpenStringField: .db "record R",10,"x as string[]"
ProofSourceOpenStringFieldEnd:
ProofSourceExtent: .db "record R",10,"x as u8[1024]",10,"y as u8"
ProofSourceExtentEnd:
ProofSourceDuplicateRecord:
            .db "record R",10,"x as u8",10,"end",10,"record R",10,"y as u8"
ProofSourceDuplicateRecordEnd:

ProofPartsRecords:         .db 1
                           .dw ProofSourceRecords,ProofSourceRecordsEnd
ProofPartsEmpty:           .db 1
                           .dw ProofSourceEmpty,ProofSourceEmptyEnd
ProofPartsDuplicateField:  .db 1
                           .dw ProofSourceDuplicateField,ProofSourceDuplicateFieldEnd
ProofPartsSelfType:        .db 1
                           .dw ProofSourceSelfType,ProofSourceSelfTypeEnd
ProofPartsOpenField:       .db 1
                           .dw ProofSourceOpenField,ProofSourceOpenFieldEnd
ProofPartsOpenStringField: .db 1
                           .dw ProofSourceOpenStringField,ProofSourceOpenStringFieldEnd
ProofPartsExtent:          .db 1
                           .dw ProofSourceExtent,ProofSourceExtentEnd
ProofPartsDuplicateRecord: .db 1
                           .dw ProofSourceDuplicateRecord,ProofSourceDuplicateRecordEnd
