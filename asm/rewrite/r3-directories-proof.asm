; R3 declaration-directory proof. All .db content is proof state or retained
; source-name data, never raw instruction encoding.

CompilerWorkBase    .equ $6000
SourceBase          .equ $5000
SourceLimit         .equ $5800
RewriteAdapterBase  .equ $A000
RewriteAdapterLimit .equ $A100
DebugHooks          .equ 0

            .org $1000
ProofRecordsFields:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            CALL RewriteRecordBegin
            LD   A,3
            CALL ProofAppendFields
            CALL RewriteRecordCommit
            CALL RewriteRecordBegin
            LD   A,3
            CALL ProofAppendFields
            CALL RewriteRecordCommit
            CALL RewriteRecordBegin
            LD   A,3
            CALL ProofAppendFields
            CALL RewriteRecordCommit
            CALL RewriteRecordBegin
            LD   A,2
            CALL ProofAppendFields
            CALL RewriteRecordCommit
            CALL RewriteRecordBegin
            LD   A,1
            CALL ProofAppendFields
            CALL RewriteRecordCommit
            LD   A,(RewriteRecordCount)
            CP   RewriteRecordCapacity
            JP   NZ,ProofFailure
            LD   A,(RewriteFieldCount)
            CP   RewriteFieldCapacity
            JP   NZ,ProofFailure
            LD   A,(RewriteRecordTableBase+RewriteRecordEntrySize*4+RewriteRecordFieldStart)
            CP   11
            JP   NZ,ProofFailure
            LD   A,(RewriteRecordTableBase+RewriteRecordEntrySize*4+RewriteRecordFieldCount)
            CP   1
            JP   NZ,ProofFailure
            LD   HL,(RewriteFieldTableBase+RewriteFieldEntrySize*11+RewriteFieldNamePointer)
            LD   DE,ProofFieldNames+11
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   HL,(RewriteFieldTableBase+RewriteFieldEntrySize*11+RewriteFieldOffset)
            LD   DE,$1234
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   A,$C1
            LD   (ProofStatus),A
            HALT

ProofFieldDuplicate:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofDuplicateDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            CALL RewriteRecordBegin
            LD   HL,ProofFieldNames
            CALL ProofSetNameOne
            LD   A,RewriteScalarTypeU8
            LD   BC,0
            CALL RewriteFieldAppendCurrent
            LD   A,RewriteScalarTypeU16
            LD   BC,1
            CALL RewriteFieldAppendCurrent
            JP   ProofFailure

ProofFieldCapacity:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofTypeCapacityDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            CALL RewriteRecordBegin
            LD   A,RewriteFieldCapacity
            CALL ProofAppendFields
            LD   HL,ProofFieldNames+RewriteFieldCapacity
            CALL ProofSetNameOne
            LD   A,RewriteScalarTypeU8
            LD   BC,RewriteFieldCapacity
            CALL RewriteFieldAppendCurrent
            JP   ProofFailure

ProofRecordCapacity:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofTypeCapacityDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,RewriteRecordCapacity
            LD   (ProofRemaining),A
ProofRecordCapacityLoop:
            CALL RewriteRecordBegin
            LD   HL,ProofFieldNames
            CALL ProofSetNameOne
            LD   A,RewriteScalarTypeU8
            LD   BC,0
            CALL RewriteFieldAppendCurrent
            CALL RewriteRecordCommit
            LD   HL,ProofRemaining
            DEC  (HL)
            JR   NZ,ProofRecordCapacityLoop
            CALL RewriteRecordBegin
            JP   ProofFailure

ProofRecordEmpty:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofRecordEmptyDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            CALL RewriteRecordBegin
            CALL RewriteRecordCommit
            JP   ProofFailure

ProofRoutinesParameters:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            CALL ProofInstallGlobals
            XOR  A
            CALL ProofBeginRoutine
            LD   A,4
            CALL ProofAppendParameters
            CALL RewriteRoutineCommit
            LD   A,1
            CALL ProofBeginRoutine
            LD   A,4
            CALL ProofAppendParameters
            CALL RewriteRoutineCommit
            LD   A,2
            CALL ProofBeginRoutine
            LD   A,4
            CALL ProofAppendParameters
            CALL RewriteRoutineCommit
            LD   A,3
            CALL ProofBeginRoutine
            LD   A,4
            CALL ProofAppendParameters
            CALL RewriteRoutineCommit
            LD   A,(RewriteRoutineCount)
            CP   RewriteRoutineCapacity
            JP   NZ,ProofFailure
            LD   A,(RewriteParameterCount)
            CP   RewriteParameterCapacity
            JP   NZ,ProofFailure
            LD   A,(RewriteSymbolCount)
            CP   2
            JP   NZ,ProofFailure
            LD   A,(RewriteRoutineTableBase+RewriteRoutineEntrySize*3+RewriteRoutineParameterStart)
            CP   12
            JP   NZ,ProofFailure
            LD   A,(RewriteRoutineTableBase+RewriteRoutineEntrySize*3+RewriteRoutineParameterCount)
            CP   4
            JP   NZ,ProofFailure
            LD   A,(RewriteRoutineTableBase+RewriteRoutineEntrySize*3+RewriteRoutineLabel)
            CP   31
            JP   NZ,ProofFailure
            LD   A,(RewriteRoutineTableBase+RewriteRoutineEntrySize*3+RewriteRoutineFlags)
            CP   3
            JP   NZ,ProofFailure
            LD   HL,(RewriteParameterTableBase+RewriteParameterEntrySize*15+RewriteParameterNamePointer)
            LD   DE,ProofParameterNames+15
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   A,$C5
            LD   (ProofStatus),A
            HALT

ProofRoutineDuplicate:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofDuplicateDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            XOR  A
            CALL ProofBeginRoutine
            CALL RewriteRoutineCommit
            XOR  A
            CALL ProofBeginRoutine
            JP   ProofFailure

ProofRoutineCapacity:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofRoutineCapacityDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            XOR  A
            CALL ProofBeginRoutine
            CALL RewriteRoutineCommit
            LD   A,1
            CALL ProofBeginRoutine
            CALL RewriteRoutineCommit
            LD   A,2
            CALL ProofBeginRoutine
            CALL RewriteRoutineCommit
            LD   A,3
            CALL ProofBeginRoutine
            CALL RewriteRoutineCommit
            LD   A,4
            CALL ProofBeginRoutine
            JP   ProofFailure

ProofRoutineDuplicateAtCapacity:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofRoutineCapacityDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            XOR  A
            CALL ProofBeginRoutine
            CALL RewriteRoutineCommit
            LD   A,1
            CALL ProofBeginRoutine
            CALL RewriteRoutineCommit
            LD   A,2
            CALL ProofBeginRoutine
            CALL RewriteRoutineCommit
            LD   A,3
            CALL ProofBeginRoutine
            CALL RewriteRoutineCommit
            XOR  A
            CALL ProofBeginRoutine
            JP   ProofFailure

ProofParameterCapacity:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofParameterCapacityDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            XOR  A
            CALL ProofBeginRoutine
            LD   A,4
            CALL ProofAppendParameters
            CALL RewriteRoutineCommit
            LD   A,1
            CALL ProofBeginRoutine
            LD   A,4
            CALL ProofAppendParameters
            CALL RewriteRoutineCommit
            LD   A,2
            CALL ProofBeginRoutine
            LD   A,4
            CALL ProofAppendParameters
            CALL RewriteRoutineCommit
            LD   A,3
            CALL ProofBeginRoutine
            LD   A,5
            CALL ProofAppendParameters
            JP   ProofFailure

ProofParameterDuplicateAtCapacity:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofDuplicateDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            XOR  A
            CALL ProofBeginRoutine
            LD   A,RewriteParameterCapacity
            CALL ProofAppendParameters
            LD   HL,ProofParameterNames
            CALL ProofSetNameOne
            CALL RewriteSymbolRejectCurrent
            LD   A,RewriteScalarTypeU8
            CALL RewriteParameterAppendCurrent
            JP   ProofFailure

ProofSuffixes:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofTypeCapacityDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            CALL RewriteSuffixBegin
            LD   HL,1
            LD   DE,10
            CALL RewriteSuffixAppend
            LD   HL,$0100
            LD   DE,$0200
            CALL RewriteSuffixAppend
            LD   HL,$FFFF
            LD   DE,$1234
            CALL RewriteSuffixAppend
            LD   HL,2
            LD   DE,$5678
            CALL RewriteSuffixAppend
            LD   HL,(RewriteSuffixTableBase+RewriteSuffixEntrySize+RewriteSuffixLength)
            LD   DE,$0100
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   HL,(RewriteSuffixTableBase+RewriteSuffixEntrySize*2+RewriteSuffixSourceOffset)
            LD   DE,$1234
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   HL,3
            LD   DE,0
            CALL RewriteSuffixAppend
            JP   ProofFailure

ProofSuffixOpenShape:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofShapeDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            CALL RewriteSuffixBegin
            LD   HL,$4321
            CALL RewriteSuffixSetOpen
            LD   HL,$5678
            CALL RewriteSuffixSetOpen
            JP   ProofFailure

ProofSuffixConcreteThenOpen:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofShapeAfterConcreteDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            CALL RewriteSuffixBegin
            LD   HL,1
            LD   DE,$1111
            CALL RewriteSuffixAppend
            LD   HL,$2222
            CALL RewriteSuffixSetOpen
            JP   ProofFailure

; Expected diagnostic continuations.
ProofDuplicateDiagnostic:
            LD   A,(DiagnosticCode)
            CP   DiagnosticDuplicateName
            JP   NZ,ProofFailure
            LD   A,$C2
            LD   (ProofStatus),A
            HALT
ProofTypeCapacityDiagnostic:
            LD   A,(DiagnosticCode)
            CP   DiagnosticTypeMetadataCapacity
            JP   NZ,ProofFailure
            CALL RewriteReset
            LD   A,(RewriteRecordCount)
            LD   HL,RewriteFieldCount
            OR   (HL)
            LD   HL,RewriteSuffixCount
            OR   (HL)
            JP   NZ,ProofFailure
            LD   A,$C3
            LD   (ProofStatus),A
            HALT
ProofRoutineCapacityDiagnostic:
            LD   A,(DiagnosticCode)
            CP   DiagnosticRoutineCapacity
            JP   NZ,ProofFailure
            LD   A,$C6
            LD   (ProofStatus),A
            HALT
ProofParameterCapacityDiagnostic:
            LD   A,(DiagnosticCode)
            CP   DiagnosticParameterCapacity
            JP   NZ,ProofFailure
            LD   A,(RewriteParameterCount)
            CP   RewriteParameterCapacity
            JP   NZ,ProofFailure
            LD   A,$C7
            LD   (ProofStatus),A
            HALT
ProofRecordEmptyDiagnostic:
            LD   A,(DiagnosticCode)
            CP   DiagnosticRecordEmpty
            JP   NZ,ProofFailure
            LD   A,$CA
            LD   (ProofStatus),A
            HALT
ProofShapeDiagnostic:
            LD   A,(DiagnosticCode)
            CP   DiagnosticTypeBound
            JP   NZ,ProofFailure
            LD   HL,(RewriteSuffixOpenOffset)
            LD   DE,$4321
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   A,$C9
            LD   (ProofStatus),A
            HALT
ProofShapeAfterConcreteDiagnostic:
            LD   A,(DiagnosticCode)
            CP   DiagnosticTypeBound
            JP   NZ,ProofFailure
            LD   A,(RewriteSuffixOpen)
            OR   A
            JP   NZ,ProofFailure
            LD   A,$CB
            LD   (ProofStatus),A
            HALT

.routine in HL out A,carry,zero clobbers sign,parity,halfCarry
ProofSetNameOne:
            LD   (TokenLexemePointer),HL
            LD   A,1
            LD   (TokenLength),A
            RET

.routine in A out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
ProofAppendFields:
            LD   (ProofRemaining),A
ProofAppendFieldsLoop:
            LD   A,(RewriteFieldCount)
            LD   L,A
            LD   H,0
            LD   DE,ProofFieldNames
            ADD  HL,DE
            CALL ProofSetNameOne
            LD   A,(RewriteFieldCount)
            CP   11
            JR   Z,ProofAppendFieldWideOffset
            LD   C,A
            LD   B,0
            JR   ProofAppendFieldReady
ProofAppendFieldWideOffset:
            LD   BC,$1234
ProofAppendFieldReady:
            LD   A,RewriteScalarTypeU8
            CALL RewriteFieldAppendCurrent
            LD   HL,ProofRemaining
            DEC  (HL)
            JR   NZ,ProofAppendFieldsLoop
            XOR  A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,D,DE,HL
ProofInstallGlobals:
            LD   HL,ProofGlobalNames
            CALL ProofSetNameOne
            LD   A,RewriteSymbolClassProgram
            LD   D,RewriteScalarTypeU8
            LD   BC,0
            CALL RewriteSymbolPrepareCurrent
            CALL RewriteSymbolCommit
            LD   HL,ProofGlobalNames+1
            CALL ProofSetNameOne
            LD   A,RewriteSymbolClassProgram
            LD   D,RewriteScalarTypeU8
            LD   BC,1
            CALL RewriteSymbolPrepareCurrent
            JP   RewriteSymbolCommit

.routine in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ProofBeginRoutine:
            LD   L,A
            LD   H,0
            LD   DE,ProofRoutineNames
            ADD  HL,DE
            CALL ProofSetNameOne
            LD   B,RewriteScalarTypeU8
            LD   A,(RewriteRoutineCount)
            LD   D,A
            ADD  A,28
            LD   C,A
            JP   RewriteRoutineBeginCurrent

.routine in A out A,carry,zero clobbers sign,parity,halfCarry,BC,D,DE,HL
ProofAppendParameters:
            LD   (ProofRemaining),A
ProofAppendParametersLoop:
            LD   A,(RewriteParameterCount)
            LD   L,A
            LD   H,0
            LD   DE,ProofParameterNames
            ADD  HL,DE
            CALL ProofSetNameOne
            LD   A,RewriteScalarTypeU8
            CALL RewriteParameterAppendCurrent
            LD   A,RewriteSymbolClassParameter
            LD   D,RewriteScalarTypeU8
            LD   BC,0
            CALL RewriteSymbolPrepareCurrent
            CALL RewriteSymbolCommit
            LD   HL,ProofRemaining
            DEC  (HL)
            JR   NZ,ProofAppendParametersLoop
            XOR  A
            RET

ProofUnexpectedDiagnostic:
            LD   A,$E1
            LD   (ProofStatus),A
            HALT
ProofFailure:
            LD   A,$EF
            LD   (ProofStatus),A
            HALT

            .include "compiler-image.asmi"

ProofStatus:    .db 0
ProofRemaining: .db 0

            .org $9000
ProofGlobalNames:    .db "GH"
ProofRoutineNames:   .db "rstuv"
ProofParameterNames: .db "abcdefghijklmnopq"
ProofFieldNames:     .db "ABCDEFGHIJKLM"
