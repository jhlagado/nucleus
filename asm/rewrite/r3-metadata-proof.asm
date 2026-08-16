; R3 type/symbol substrate proof. The .db blocks are retained source-name data,
; not instruction encodings.

CompilerWorkBase    .equ $6000
SourceBase          .equ $5000
SourceLimit         .equ $5800
RewriteAdapterBase  .equ $A000
RewriteAdapterLimit .equ $A100
DebugHooks          .equ 0

            .org $1000
ProofTypeMetadata:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP

            LD   A,RewriteTypeKindRecord
            LD   (RewriteTypeCandidateKind),A
            XOR  A
            LD   (RewriteTypeCandidateAux),A
            LD   HL,1
            LD   (RewriteTypeCandidateCount),HL
            LD   HL,3
            LD   (RewriteTypeCandidateExtent),HL
            CALL RewriteTypeAppendNominal
            CP   RewriteFirstOwnedTypeId
            JP   NZ,ProofFailure
            CALL RewriteTypeAppendNominal
            CP   RewriteFirstOwnedTypeId+1
            JP   NZ,ProofFailure

            LD   A,RewriteTypeKindString
            LD   (RewriteTypeCandidateKind),A
            XOR  A
            LD   (RewriteTypeCandidateAux),A
            LD   HL,253
            LD   (RewriteTypeCandidateCount),HL
            LD   HL,255
            LD   (RewriteTypeCandidateExtent),HL
            CALL RewriteTypeInternStructural
            CP   RewriteFirstOwnedTypeId+2
            JP   NZ,ProofFailure
            CALL RewriteTypeInternStructural
            CP   RewriteFirstOwnedTypeId+2
            JP   NZ,ProofFailure

            LD   A,RewriteTypeKindArray
            LD   (RewriteTypeCandidateKind),A
            LD   A,RewriteScalarTypeU8
            LD   (RewriteTypeCandidateAux),A
            LD   HL,2
            LD   (RewriteTypeCandidateCount),HL
            LD   (RewriteTypeCandidateExtent),HL
            CALL RewriteTypeInternStructural
            CP   RewriteFirstOwnedTypeId+3
            JP   NZ,ProofFailure
            LD   (RewriteTypeCandidateAux),A
            LD   HL,3
            LD   (RewriteTypeCandidateCount),HL
            LD   HL,6
            LD   (RewriteTypeCandidateExtent),HL
            CALL RewriteTypeInternStructural
            CP   RewriteFirstOwnedTypeId+4
            JP   NZ,ProofFailure
            CALL RewriteTypeStaticExtent
            JP   C,ProofFailure
            LD   DE,6
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   A,RewriteScalarTypeBoolean
            CALL RewriteTypeStaticExtent
            JP   C,ProofFailure
            LD   A,L
            CP   1
            JP   NZ,ProofFailure
            LD   A,RewriteScalarTypeI16
            CALL RewriteTypeStaticExtent
            JP   C,ProofFailure
            LD   A,L
            CP   2
            JP   NZ,ProofFailure
            LD   A,RewriteFirstOwnedTypeId+3
            CALL RewriteTypeMakeOpenArray
            CP   RewriteOpenArrayFlag+RewriteFirstOwnedTypeId+3
            JP   NZ,ProofFailure
            CALL RewriteTypeStaticExtent
            JP   NC,ProofFailure
            LD   A,RewriteOpenStringTypeId
            CALL RewriteTypeStaticExtent
            JP   NC,ProofFailure
            XOR  A
            CALL RewriteTypeStaticExtent
            JP   NC,ProofFailure
            LD   A,RewriteScalarTypeExact+RewriteTypeMetaNegative
            CALL RewriteTypeStaticExtent
            JP   NC,ProofFailure
            LD   A,RewriteTypeKindArray
            LD   (RewriteTypeCandidateKind),A
            LD   A,RewriteScalarTypeU16
            LD   (RewriteTypeCandidateAux),A
            LD   HL,$0100
            LD   (RewriteTypeCandidateCount),HL
            LD   HL,$0200
            LD   (RewriteTypeCandidateExtent),HL
            CALL RewriteTypeInternStructural
            CP   RewriteFirstOwnedTypeId+5
            JP   NZ,ProofFailure
            PUSH AF
            CALL RewriteTypeStaticExtent
            LD   DE,$0200
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            POP  AF
            PUSH AF
            CALL RewriteTypeAddress
            LD   DE,RewriteTypeCountOffset
            ADD  HL,DE
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            LD   HL,$0100
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            POP  AF
            CALL RewriteTypeInternStructural
            CP   RewriteFirstOwnedTypeId+5
            JP   NZ,ProofFailure
            LD   A,(RewriteTypeCount)
            CP   6
            JP   NZ,ProofFailure
            LD   A,$B1
            LD   (ProofStatus),A
            HALT

ProofTypeCapacity:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofTypeCapacityDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,RewriteTypeKindRecord
            LD   (RewriteTypeCandidateKind),A
            LD   HL,1
            LD   (RewriteTypeCandidateCount),HL
            LD   (RewriteTypeCandidateExtent),HL
            LD   B,RewriteOwnedTypeCapacity
ProofTypeCapacityLoop:
            PUSH BC
            CALL RewriteTypeAppendNominal
            POP  BC
            DJNZ ProofTypeCapacityLoop
            CALL RewriteTypeAppendNominal
            JP   ProofFailure
ProofTypeCapacityDiagnostic:
            LD   A,(DiagnosticCode)
            CP   DiagnosticTypeMetadataCapacity
            JP   NZ,ProofFailure
            LD   A,(RewriteTypeCount)
            CP   RewriteOwnedTypeCapacity
            JP   NZ,ProofFailure
            CALL RewriteReset
            LD   A,(RewriteTypeCount)
            OR   A
            JP   NZ,ProofFailure
            LD   A,$B2
            LD   (ProofStatus),A
            HALT

ProofSymbols:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   HL,ProofNameAlpha
            LD   (TokenLexemePointer),HL
            LD   A,5
            LD   (TokenLength),A
            LD   A,RewriteSymbolClassProgram
            LD   D,RewriteScalarTypeU16
            LD   BC,$1234
            CALL RewriteSymbolPrepareCurrent
            CALL RewriteSymbolFindCurrent
            JP   C,ProofFailure
            CALL RewriteSymbolCommit
            CALL RewriteSymbolFindCurrent
            JP   NC,ProofFailure
            LD   DE,RewriteSymbolNamePointer
            ADD  HL,DE
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            LD   HL,ProofNameAlpha
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   A,(RewriteSymbolTableBase+RewriteSymbolClass)
            CP   RewriteSymbolClassProgram
            JP   NZ,ProofFailure
            LD   A,(RewriteSymbolTableBase+RewriteSymbolType)
            CP   RewriteScalarTypeU16
            JP   NZ,ProofFailure
            LD   HL,(RewriteSymbolTableBase+RewriteSymbolPayload)
            LD   DE,$1234
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure

            LD   HL,ProofNameNegative
            LD   (TokenLexemePointer),HL
            LD   A,8
            LD   (TokenLength),A
            LD   A,RewriteSymbolClassConstant
            LD   D,RewriteScalarTypeExact+RewriteTypeMetaNegative
            LD   BC,$FFFF
            CALL RewriteSymbolPrepareCurrent
            CALL RewriteSymbolCommit
            LD   HL,ProofNamePositive
            LD   (TokenLexemePointer),HL
            LD   A,8
            LD   (TokenLength),A
            LD   A,RewriteSymbolClassConstant
            LD   D,RewriteScalarTypeExact
            LD   BC,$FFFF
            CALL RewriteSymbolPrepareCurrent
            CALL RewriteSymbolCommit
            LD   A,(RewriteSymbolTableBase+RewriteSymbolEntrySize+RewriteSymbolType)
            CP   RewriteTypeMetaNegative
            JP   NZ,ProofFailure
            LD   A,(RewriteSymbolTableBase+RewriteSymbolEntrySize*2+RewriteSymbolType)
            OR   A
            JP   NZ,ProofFailure
            LD   HL,(RewriteSymbolTableBase+RewriteSymbolEntrySize+RewriteSymbolPayload)
            LD   DE,$FFFF
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   HL,(RewriteSymbolTableBase+RewriteSymbolEntrySize*2+RewriteSymbolPayload)
            LD   DE,$FFFF
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   A,$B3
            LD   (ProofStatus),A
            HALT

ProofSymbolDuplicate:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofSymbolDuplicateDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   HL,ProofNameAlpha
            LD   (TokenLexemePointer),HL
            LD   A,5
            LD   (TokenLength),A
            LD   A,RewriteSymbolClassProgram
            LD   D,RewriteScalarTypeU8
            LD   BC,0
            CALL RewriteSymbolPrepareCurrent
            CALL RewriteSymbolCommit
            LD   A,RewriteSymbolClassProgram
            LD   D,RewriteScalarTypeU8
            LD   BC,1
            CALL RewriteSymbolPrepareCurrent
            JP   ProofFailure
ProofSymbolDuplicateDiagnostic:
            LD   A,(DiagnosticCode)
            CP   DiagnosticDuplicateName
            JP   NZ,ProofFailure
            LD   A,(RewriteSymbolCount)
            CP   1
            JP   NZ,ProofFailure
            LD   A,$B4
            LD   (ProofStatus),A
            HALT

ProofSymbolCapacity:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofSymbolCapacityDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
ProofSymbolCapacityLoop:
            LD   A,(RewriteSymbolCount)
            LD   L,A
            LD   H,0
            LD   DE,ProofSymbolNames
            ADD  HL,DE
            LD   (TokenLexemePointer),HL
            LD   A,RewriteSymbolClassProgram
            LD   (TokenLength),A
            LD   A,1
            LD   D,RewriteScalarTypeU8
            LD   BC,0
            CALL RewriteSymbolPrepareCurrent
            CALL RewriteSymbolCommit
            LD   A,(RewriteSymbolCount)
            CP   RewriteSymbolCapacity
            JR   C,ProofSymbolCapacityLoop
            LD   HL,ProofSymbolNames+RewriteSymbolCapacity
            LD   (TokenLexemePointer),HL
            LD   A,1
            LD   D,RewriteScalarTypeU8
            LD   BC,0
            CALL RewriteSymbolPrepareCurrent
            JP   ProofFailure
ProofSymbolCapacityDiagnostic:
            LD   A,(DiagnosticCode)
            CP   DiagnosticSymbolCapacity
            JP   NZ,ProofFailure
            LD   A,(RewriteSymbolCount)
            CP   RewriteSymbolCapacity
            JP   NZ,ProofFailure
            CALL RewriteReset
            LD   A,(RewriteSymbolCount)
            OR   A
            JP   NZ,ProofFailure
            LD   A,$B5
            LD   (ProofStatus),A
            HALT

ProofUnexpectedDiagnostic:
            LD   A,$E1
            LD   (ProofStatus),A
            HALT
ProofFailure:
            LD   A,$EF
            LD   (ProofStatus),A
            HALT

            .include "compiler-image.asmi"

ProofStatus: .db 0

            .org $9000
ProofNameAlpha:   .db "alpha"
ProofNameNegative: .db "negative"
ProofNamePositive: .db "positive"
ProofSymbolNames: .db "abcdefghijklmnopq"
