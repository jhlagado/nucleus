; R3 transactional static-storage proof. The .db/.ds blocks are input data and
; proof state, never raw instruction encodings.

CompilerWorkBase    .equ $6000
SourceBase          .equ $5000
SourceLimit         .equ $5800
RewriteAdapterBase  .equ $A000
RewriteAdapterLimit .equ $A100
DebugHooks          .equ 0

            .org $1000
ProofStaticOrdering:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   HL,ProofConstantA
            LD   BC,2
            CALL RewriteStaticAppendConstant
            LD   A,D
            OR   E
            JP   NZ,ProofFailure
            LD   HL,ProofInitializedA
            LD   BC,3
            CALL RewriteStaticAppendInitialized
            LD   A,D
            OR   E
            JP   NZ,ProofFailure
            LD   HL,ProofConstantB
            LD   BC,1
            CALL RewriteStaticAppendConstant
            LD   A,D
            OR   A
            JP   NZ,ProofFailure
            LD   A,E
            CP   2
            JP   NZ,ProofFailure
            LD   HL,ProofInitializedB
            LD   BC,1
            CALL RewriteStaticAppendInitialized
            LD   A,D
            OR   A
            JP   NZ,ProofFailure
            LD   A,E
            CP   3
            JP   NZ,ProofFailure
            LD   HL,(RewriteStaticInitializedLength)
            LD   DE,4
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   HL,(RewriteStaticConstantLength)
            LD   DE,3
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   HL,RewriteStaticImageBase
            LD   DE,ProofExpectedImage
            LD   B,7
ProofStaticOrderingLoop:
            LD   A,(DE)
            CP   (HL)
            JP   NZ,ProofFailure
            INC  DE
            INC  HL
            DJNZ ProofStaticOrderingLoop
            LD   A,$E1
            LD   (ProofStatus),A
            HALT

ProofStaticProgramOverflow:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofProgramCapacityDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,$5A
            LD   (RewriteStaticImageLimit),A
            LD   HL,ProofBlock1024
            LD   BC,1024
            CALL RewriteStaticAppendInitialized
            LD   HL,ProofOne
            LD   BC,1
            CALL RewriteStaticAppendInitialized
            JP   ProofFailure

ProofStaticReadOnlyOverflow:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofReadOnlyCapacityDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,$5A
            LD   (RewriteStaticImageLimit),A
            LD   HL,ProofBlock1024
            LD   BC,512
            CALL RewriteStaticAppendInitialized
            LD   HL,ProofBlock1024
            LD   BC,512
            CALL RewriteStaticAppendConstant
            LD   HL,ProofOne
            LD   BC,1
            CALL RewriteStaticAppendConstant
            JP   ProofFailure

ProofStaticBssOverflow:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofBssCapacityDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   BC,1024
            CALL RewriteStaticReserveBss
            LD   A,D
            OR   E
            JP   NZ,ProofFailure
            LD   BC,1
            CALL RewriteStaticReserveBss
            JP   ProofFailure

ProofInitializerOverflow:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofInitializerCapacityDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,$5A
            LD   (RewriteInitializerLimit),A
            LD   HL,ProofBlock1024
            LD   BC,1024
            CALL RewriteInitializerAppendBlock
            LD   A,$44
            CALL RewriteInitializerAppendByte
            JP   ProofFailure

ProofStaticZeroLength:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   HL,ProofOne
            LD   BC,0
            CALL RewriteStaticAppendInitialized
            LD   A,D
            OR   E
            JP   NZ,ProofFailure
            CALL RewriteStaticAppendConstant
            LD   A,D
            OR   E
            JP   NZ,ProofFailure
            CALL RewriteInitializerAppendBlock
            LD   A,D
            OR   E
            JP   NZ,ProofFailure
            LD   HL,(RewriteStaticInitializedLength)
            LD   A,H
            OR   L
            JP   NZ,ProofFailure
            LD   HL,(RewriteStaticConstantLength)
            LD   A,H
            OR   L
            JP   NZ,ProofFailure
            LD   HL,(RewriteInitializerLength)
            LD   A,H
            OR   L
            JP   NZ,ProofFailure
            LD   A,$E6
            LD   (ProofStatus),A
            HALT

ProofInitializerResetReuse:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   HL,ProofInitializedA
            LD   BC,3
            CALL RewriteInitializerAppendBlock
            CALL RewriteInitializerReset
            LD   A,$7C
            CALL RewriteInitializerAppendByte
            LD   HL,(RewriteInitializerLength)
            LD   DE,1
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   A,(RewriteInitializerBase)
            CP   $7C
            JP   NZ,ProofFailure
            LD   A,$E7
            LD   (ProofStatus),A
            HALT

ProofStaticSymbolSegments:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   HL,ProofOne
            LD   BC,1
            CALL RewriteStaticAppendInitialized
            LD   B,D
            LD   C,E
            LD   HL,ProofNameInitialized
            LD   (TokenLexemePointer),HL
            LD   A,4
            LD   (TokenLength),A
            LD   A,RewriteSymbolClassProgram
            LD   D,RewriteScalarTypeU8
            CALL RewriteSymbolPrepareCurrent
            LD   A,RewriteSymbolStorageInitialized
            CALL RewriteSymbolSetStorageCurrent
            CALL RewriteSymbolCommit
            LD   BC,1
            CALL RewriteStaticReserveBss
            LD   B,D
            LD   C,E
            LD   HL,ProofNameBss
            LD   (TokenLexemePointer),HL
            LD   A,4
            LD   (TokenLength),A
            LD   A,RewriteSymbolClassProgram
            LD   D,RewriteScalarTypeU8
            CALL RewriteSymbolPrepareCurrent
            LD   A,RewriteSymbolStorageBss
            CALL RewriteSymbolSetStorageCurrent
            CALL RewriteSymbolCommit
            LD   HL,ProofBlock1024
            LD   BC,300
            CALL RewriteStaticAppendInitialized
            LD   BC,300
            CALL RewriteStaticReserveBss
            LD   HL,ProofOne
            LD   BC,1
            CALL RewriteStaticAppendInitialized
            LD   B,D
            LD   C,E
            LD   HL,ProofNameInitialized2
            LD   (TokenLexemePointer),HL
            LD   A,5
            LD   (TokenLength),A
            LD   A,RewriteSymbolClassProgram
            LD   D,RewriteScalarTypeU8
            CALL RewriteSymbolPrepareCurrent
            LD   A,RewriteSymbolStorageInitialized
            CALL RewriteSymbolSetStorageCurrent
            CALL RewriteSymbolCommit
            LD   BC,1
            CALL RewriteStaticReserveBss
            LD   B,D
            LD   C,E
            LD   HL,ProofNameBss2
            LD   (TokenLexemePointer),HL
            LD   A,5
            LD   (TokenLength),A
            LD   A,RewriteSymbolClassProgram
            LD   D,RewriteScalarTypeU8
            CALL RewriteSymbolPrepareCurrent
            LD   A,RewriteSymbolStorageBss
            CALL RewriteSymbolSetStorageCurrent
            CALL RewriteSymbolCommit
            LD   HL,(RewriteSymbolTableBase+RewriteSymbolPayload)
            LD   A,H
            OR   L
            JP   NZ,ProofFailure
            LD   HL,(RewriteSymbolTableBase+RewriteSymbolEntrySize+RewriteSymbolPayload)
            LD   A,H
            OR   L
            JP   NZ,ProofFailure
            LD   A,(RewriteSymbolTableBase+RewriteSymbolStorage)
            CP   RewriteSymbolStorageInitialized
            JP   NZ,ProofFailure
            LD   A,(RewriteSymbolTableBase+RewriteSymbolEntrySize+RewriteSymbolStorage)
            CP   RewriteSymbolStorageBss
            JP   NZ,ProofFailure
            LD   HL,(RewriteSymbolTableBase+RewriteSymbolEntrySize*2+RewriteSymbolPayload)
            LD   DE,301
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   HL,(RewriteSymbolTableBase+RewriteSymbolEntrySize*3+RewriteSymbolPayload)
            LD   DE,301
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   A,(RewriteSymbolTableBase+RewriteSymbolEntrySize*2+RewriteSymbolStorage)
            CP   RewriteSymbolStorageInitialized
            JP   NZ,ProofFailure
            LD   A,(RewriteSymbolTableBase+RewriteSymbolEntrySize*3+RewriteSymbolStorage)
            CP   RewriteSymbolStorageBss
            JP   NZ,ProofFailure
            LD   A,$E8
            LD   (ProofStatus),A
            HALT

ProofProgramCapacityDiagnostic:
            LD   A,(DiagnosticCode)
            CP   DiagnosticProgramDataCapacity
            JP   NZ,ProofFailure
            LD   HL,(RewriteStaticInitializedLength)
            LD   DE,1024
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   A,(RewriteStaticImageLimit)
            CP   $5A
            JP   NZ,ProofFailure
            LD   A,(RewriteStaticImageBase)
            CP   $31
            JP   NZ,ProofFailure
            LD   A,(RewriteStaticImageBase+511)
            CP   $72
            JP   NZ,ProofFailure
            LD   A,(RewriteStaticImageBase+1023)
            OR   A
            JP   NZ,ProofFailure
            LD   A,$E2
            LD   (ProofStatus),A
            HALT

ProofReadOnlyCapacityDiagnostic:
            LD   A,(DiagnosticCode)
            CP   DiagnosticReadOnlyCapacity
            JP   NZ,ProofFailure
            LD   HL,(RewriteStaticInitializedLength)
            LD   DE,512
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   HL,(RewriteStaticConstantLength)
            LD   DE,512
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   A,(RewriteStaticImageLimit)
            CP   $5A
            JP   NZ,ProofFailure
            LD   A,(RewriteStaticImageBase)
            CP   $31
            JP   NZ,ProofFailure
            LD   A,(RewriteStaticImageBase+511)
            CP   $72
            JP   NZ,ProofFailure
            LD   A,(RewriteStaticImageBase+512)
            CP   $31
            JP   NZ,ProofFailure
            LD   A,(RewriteStaticImageBase+1023)
            CP   $72
            JP   NZ,ProofFailure
            LD   A,$E3
            LD   (ProofStatus),A
            HALT

ProofBssCapacityDiagnostic:
            LD   A,(DiagnosticCode)
            CP   DiagnosticProgramDataCapacity
            JP   NZ,ProofFailure
            LD   HL,(RewriteStaticBssLength)
            LD   DE,1024
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   A,$E4
            LD   (ProofStatus),A
            HALT

ProofInitializerCapacityDiagnostic:
            LD   A,(DiagnosticCode)
            CP   DiagnosticInitializerCapacity
            JP   NZ,ProofFailure
            LD   HL,(RewriteInitializerLength)
            LD   DE,1024
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   A,(RewriteInitializerLimit)
            CP   $5A
            JP   NZ,ProofFailure
            LD   A,(RewriteInitializerBase)
            CP   $31
            JP   NZ,ProofFailure
            LD   A,(RewriteInitializerBase+511)
            CP   $72
            JP   NZ,ProofFailure
            LD   A,(RewriteInitializerBase+1023)
            OR   A
            JP   NZ,ProofFailure
            LD   A,$E5
            LD   (ProofStatus),A
            HALT

ProofUnexpectedDiagnostic:
            LD   A,(DiagnosticCode)
            LD   (ProofStatus),A
            HALT
ProofFailure:
            LD   A,$EF
            LD   (ProofStatus),A
            HALT

            .include "compiler-image.asmi"

ProofStatus: .db 0

            .org $9000
ProofInitializedA: .db $11,$12,$13
ProofInitializedB: .db $14
ProofConstantA:    .db $21,$22
ProofConstantB:    .db $23
ProofExpectedImage: .db $11,$12,$13,$14,$21,$22,$23
ProofOne:          .db $33
ProofNameInitialized: .db "init"
ProofNameBss:         .db "cold"
ProofNameInitialized2: .db "init2"
ProofNameBss2:         .db "cold2"
ProofBlock1024:    .db $31
                   .ds 510
                   .db $72
                   .ds 512
