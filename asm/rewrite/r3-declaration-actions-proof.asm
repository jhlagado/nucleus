; R3 namespace and routine-lifecycle action proof. All .db blocks below are
; source spellings or proof state, never raw instruction encodings.

CompilerWorkBase    .equ $6000
SourceBase          .equ $5000
SourceLimit         .equ $5800
RewriteAdapterBase  .equ $A000
RewriteAdapterLimit .equ $A100
DebugHooks          .equ 0

            .org $1000
ProofForwardLifecycle:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            CALL ProofBeginForwardWork
            CALL ProofDeclareArgParameter
            CALL RewriteRoutineCommit
            LD   A,(RewriteRoutineCount)
            CP   1
            JP   NZ,ProofFailure
            LD   A,(RewriteSymbolCount)
            OR   A
            JP   NZ,ProofFailure
            CALL ProofSetWork
            CALL RewriteRoutineOpenForwardCurrent
            CALL RewriteRoutineInstallForwardParameters
            LD   A,(RewriteRoutineCount)
            CP   1
            JP   NZ,ProofFailure
            LD   A,(RewriteSymbolCount)
            CP   1
            JP   NZ,ProofFailure
            LD   A,(RewriteRoutineTableBase+RewriteRoutineFlags)
            AND  RewriteRoutineFlagIncomplete
            JP   NZ,ProofFailure
            CALL RewriteRoutineCloseScope
            CALL ProofSetMain
            LD   D,0
            CALL RewriteMainBeginCurrent
            CALL RewriteRoutineCloseScope
            CALL RewriteRoutineRequireComplete
            LD   A,$D1
            LD   (ProofStatus),A
            HALT

ProofForwardGlobalCollision:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofDuplicateDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            CALL ProofBeginForwardWork
            CALL ProofDeclareArgParameter
            CALL RewriteRoutineCommit
            CALL ProofDeclareArgGlobal
            CALL ProofSetWork
            CALL RewriteRoutineOpenForwardCurrent
            CALL RewriteRoutineInstallForwardParameters
            JP   ProofFailure

ProofForwardMissing:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnknownDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            CALL ProofSetWork
            CALL RewriteRoutineOpenForwardCurrent
            JP   ProofFailure

ProofForwardAlreadyComplete:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofDuplicateDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            CALL ProofBeginForwardWork
            CALL RewriteRoutineCommit
            CALL ProofSetWork
            CALL RewriteRoutineOpenForwardCurrent
            CALL RewriteRoutineInstallForwardParameters
            CALL RewriteRoutineCloseScope
            CALL ProofSetWork
            CALL RewriteRoutineOpenForwardCurrent
            JP   ProofFailure

ProofForwardIncomplete:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofIncompleteDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            CALL ProofBeginForwardWork
            CALL RewriteRoutineCommit
            CALL ProofSetMain
            LD   D,0
            CALL RewriteMainBeginCurrent
            CALL RewriteRoutineCloseScope
            CALL RewriteRoutineRequireComplete
            JP   ProofFailure

ProofMissingMain:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofExpectedTopLevelDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            CALL RewriteRoutineRequireComplete
            JP   ProofFailure

ProofForwardWithoutMain:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofExpectedTopLevelDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            CALL ProofBeginForwardWork
            CALL RewriteRoutineCommit
            CALL RewriteRoutineRequireComplete
            JP   ProofFailure

ProofOrdinaryAndForwardMainIncomplete:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofIncompleteDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            CALL ProofBeginForwardWork
            CALL RewriteRoutineCommit
            CALL ProofSetMain
            LD   D,0
            CALL RewriteMainBeginForwardCurrent
            CALL RewriteRoutineCloseScope
            CALL RewriteRoutineRequireComplete
            JP   ProofFailure

ProofMainOutsideRoutineCapacity:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            XOR  A
            CALL ProofBeginNumberedRoutine
            CALL RewriteRoutineCommit
            LD   A,1
            CALL ProofBeginNumberedRoutine
            CALL RewriteRoutineCommit
            LD   A,2
            CALL ProofBeginNumberedRoutine
            CALL RewriteRoutineCommit
            LD   A,3
            CALL ProofBeginNumberedRoutine
            CALL RewriteRoutineCommit
            CALL ProofSetMain
            LD   D,0
            CALL RewriteMainBeginCurrent
            LD   A,(RewriteRoutineCount)
            CP   RewriteRoutineCapacity
            JP   NZ,ProofFailure
            LD   A,(RewriteMainFlags)
            CP   RewriteRoutineFlagMain
            JP   NZ,ProofFailure
            LD   A,$D2
            LD   (ProofStatus),A
            HALT

ProofMainDuplicate:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofDuplicateDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            CALL ProofSetMain
            LD   D,0
            CALL RewriteMainBeginCurrent
            CALL RewriteRoutineCloseScope
            CALL ProofSetMain
            LD   D,0
            CALL RewriteMainBeginCurrent
            JP   ProofFailure

ProofForwardMainLifecycle:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            CALL ProofSetMain
            LD   D,RewriteRoutineFlagFails
            CALL RewriteMainBeginForwardCurrent
            LD   A,(RewriteMainFlags)
            CP   RewriteRoutineFlagMain+RewriteRoutineFlagIncomplete+RewriteRoutineFlagFails
            JP   NZ,ProofFailure
            CALL RewriteRoutineCloseScope
            CALL ProofSetMain
            CALL RewriteMainOpenForwardCurrent
            LD   A,(RewriteMainFlags)
            CP   RewriteRoutineFlagMain+RewriteRoutineFlagFails
            JP   NZ,ProofFailure
            CALL RewriteRoutineRequireComplete
            LD   A,(RewriteRoutineCount)
            OR   A
            JP   NZ,ProofFailure
            LD   A,$D7
            LD   (ProofStatus),A
            HALT

ProofForwardMainIncomplete:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofIncompleteDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            CALL ProofSetMain
            LD   D,RewriteRoutineFlagFails
            CALL RewriteMainBeginForwardCurrent
            CALL RewriteRoutineCloseScope
            CALL RewriteRoutineRequireComplete
            JP   ProofFailure

ProofForwardMainMissing:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnknownDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            CALL ProofSetMain
            CALL RewriteMainOpenForwardCurrent
            JP   ProofFailure

ProofForwardMainRepeated:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnknownDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            CALL ProofSetMain
            LD   D,0
            CALL RewriteMainBeginForwardCurrent
            CALL RewriteRoutineCloseScope
            CALL ProofSetMain
            CALL RewriteMainOpenForwardCurrent
            CALL RewriteRoutineCloseScope
            CALL ProofSetMain
            CALL RewriteMainOpenForwardCurrent
            JP   ProofFailure

ProofRoutineActionCapacityPrecedence:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofRoutineCapacityDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            XOR  A
            CALL ProofBeginNumberedRoutine
            CALL RewriteRoutineCommit
            LD   A,1
            CALL ProofBeginNumberedRoutine
            CALL RewriteRoutineCommit
            LD   A,2
            CALL ProofBeginNumberedRoutine
            CALL RewriteRoutineCommit
            LD   A,3
            CALL ProofBeginNumberedRoutine
            CALL RewriteRoutineCommit
            XOR  A
            CALL ProofBeginNumberedRoutine
            JP   ProofFailure

ProofParameterRoutineCollision:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofDuplicateDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            CALL ProofSetWork
            LD   B,RewriteScalarTypeU8
            LD   C,28
            LD   D,0
            CALL RewriteRoutineDeclareBeginCurrent
            CALL ProofSetWork
            LD   A,RewriteScalarTypeU8
            LD   BC,0
            CALL RewriteParameterDeclareCurrent
            JP   ProofFailure

ProofParameterRoutineCaseDistinct:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            CALL ProofSetWork
            LD   B,RewriteScalarTypeU8
            LD   C,28
            LD   D,0
            CALL RewriteRoutineDeclareBeginCurrent
            LD   HL,ProofNameWorkUpper
            LD   A,4
            CALL ProofSetName
            LD   A,RewriteScalarTypeU8
            LD   BC,0
            CALL RewriteParameterDeclareCurrent
            LD   A,(RewriteSymbolCount)
            OR   A
            JP   NZ,ProofFailure
            CALL RewriteRoutinePublish
            LD   A,(RewriteSymbolCount)
            CP   1
            JP   NZ,ProofFailure
            LD   A,$D9
            LD   (ProofStatus),A
            HALT

ProofForwardMixedParameterLayout:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            XOR  A
            CALL ProofBeginNumberedRoutine
            XOR  A
            CALL ProofDeclareLetterU8
            LD   A,1
            CALL ProofDeclareLetterU8
            LD   A,2
            CALL ProofDeclareLetterU8
            CALL RewriteRoutineCommit
            LD   A,1
            CALL ProofBeginNumberedForward
            LD   A,3
            CALL ProofDeclareLetterU8
            LD   A,4
            CALL ProofSetParameterLetter
            LD   A,RewriteScalarTypeU16
            LD   BC,0
            CALL RewriteParameterDeclareCurrent
            LD   A,5
            CALL ProofSetParameterLetter
            LD   A,RewriteOpenStringTypeId
            LD   BC,0
            CALL RewriteParameterDeclareCurrent
            LD   A,6
            CALL ProofSetParameterLetter
            LD   A,RewriteOpenArrayFlag+RewriteScalarTypeU8
            LD   BC,0
            CALL RewriteParameterDeclareCurrent
            CALL RewriteRoutineCommit
            LD   A,1
            CALL ProofSetNumberedRoutine
            CALL RewriteRoutineOpenForwardCurrent
            CALL RewriteRoutineInstallForwardParameters
            LD   A,(RewriteCurrentLocalOffset)
            CP   10
            JP   NZ,ProofFailure
            LD   HL,RewriteSymbolTableBase+RewriteSymbolPayload
            LD   A,(HL)
            OR   A
            JP   NZ,ProofFailure
            INC  HL
            LD   A,(HL)
            OR   A
            JP   NZ,ProofFailure
            LD   HL,RewriteSymbolTableBase+RewriteSymbolEntrySize+RewriteSymbolPayload
            LD   A,(HL)
            CP   1
            JP   NZ,ProofFailure
            LD   HL,RewriteSymbolTableBase+RewriteSymbolEntrySize*2+RewriteSymbolPayload
            LD   A,(HL)
            CP   3
            JP   NZ,ProofFailure
            LD   HL,RewriteSymbolTableBase+RewriteSymbolEntrySize*3+RewriteSymbolPayload
            LD   A,(HL)
            CP   6
            JP   NZ,ProofFailure
            LD   B,4
            LD   D,3
            CALL RewriteParameterSourceOffset
            LD   A,C
            CP   14
            JP   NZ,ProofFailure
            LD   B,3
            LD   D,4
            CALL RewriteParameterSourceOffset
            LD   A,C
            CP   12
            JP   NZ,ProofFailure
            LD   B,2
            LD   D,5
            CALL RewriteParameterSourceOffset
            LD   A,C
            CP   8
            JP   NZ,ProofFailure
            LD   B,1
            LD   D,6
            CALL RewriteParameterSourceOffset
            LD   A,C
            CP   4
            JP   NZ,ProofFailure
            LD   A,$DA
            LD   (ProofStatus),A
            HALT

ProofMainLocalOffsetReset:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            CALL ProofSetWork
            LD   B,RewriteScalarTypeU8
            LD   C,28
            LD   D,0
            CALL RewriteRoutineDeclareBeginCurrent
            CALL ProofSetArg
            LD   A,RewriteScalarTypeU16
            LD   BC,0
            CALL RewriteParameterDeclareCurrent
            CALL RewriteRoutinePublish
            LD   A,(RewriteCurrentLocalOffset)
            CP   2
            JP   NZ,ProofFailure
            CALL RewriteRoutineCloseScope
            CALL ProofSetMain
            LD   D,0
            CALL RewriteMainBeginForwardCurrent
            LD   A,(RewriteCurrentLocalOffset)
            OR   A
            JP   NZ,ProofFailure
            LD   A,9
            LD   (RewriteCurrentLocalOffset),A
            CALL RewriteRoutineCloseScope
            CALL ProofSetMain
            CALL RewriteMainOpenForwardCurrent
            LD   A,(RewriteCurrentLocalOffset)
            OR   A
            JP   NZ,ProofFailure
            LD   A,$DB
            LD   (ProofStatus),A
            HALT

ProofParameterHeaderIsolation:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            CALL ProofSetWork
            LD   B,RewriteScalarTypeU8
            LD   C,28
            LD   D,0
            CALL RewriteRoutineDeclareBeginCurrent
            XOR  A
            CALL ProofDeclareLetterU8
            LD   A,(RewriteSymbolCount)
            OR   A
            JP   NZ,ProofFailure
            XOR  A
            CALL ProofSetParameterLetter
            CALL RewriteSymbolFindCurrent
            JP   C,ProofFailure
            LD   A,1
            CALL ProofDeclareLetterU8
            LD   A,(RewriteSymbolCount)
            OR   A
            JP   NZ,ProofFailure
            CALL RewriteRoutinePublish
            LD   A,(RewriteSymbolCount)
            CP   2
            JP   NZ,ProofFailure
            LD   A,(RewriteCurrentLocalOffset)
            CP   2
            JP   NZ,ProofFailure
            LD   A,$DC
            LD   (ProofStatus),A
            HALT

ProofParameterHeaderDuplicate:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofDuplicateDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            CALL ProofSetWork
            LD   B,RewriteScalarTypeU8
            LD   C,28
            LD   D,0
            CALL RewriteRoutineDeclareBeginCurrent
            XOR  A
            CALL ProofDeclareLetterU8
            XOR  A
            CALL ProofDeclareLetterU8
            JP   ProofFailure

ProofDeclarationAfterMain:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            CALL ProofSetMain
            LD   D,0
            CALL RewriteMainBeginCurrent
            CALL RewriteRoutineCloseScope
            CALL ProofSetWork
            LD   B,RewriteScalarTypeU8
            LD   C,28
            LD   D,0
            CALL RewriteRoutineDeclareBeginCurrent
            CALL RewriteRoutineCommit
            CALL RewriteRoutineRequireComplete
            LD   A,$DE
            LD   (ProofStatus),A
            HALT

ProofPredefinedParameter:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofDuplicateDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            CALL ProofSetWork
            LD   B,RewriteScalarTypeU8
            LD   C,28
            XOR  A
            LD   D,A
            CALL RewriteRoutineDeclareBeginCurrent
            CALL ProofSetOutputFailure
            LD   A,RewriteScalarTypeU8
            LD   BC,0
            CALL RewriteParameterDeclareCurrent
            JP   ProofFailure

ProofRoutineSharedCollision:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofDuplicateDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            CALL ProofDeclareWorkGlobal
            CALL ProofSetWork
            LD   B,RewriteScalarTypeU8
            LD   C,28
            XOR  A
            LD   D,A
            CALL RewriteRoutineDeclareBeginCurrent
            JP   ProofFailure

ProofDirectPublishBeforeClose:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            CALL ProofSetWork
            LD   B,RewriteScalarTypeU8
            LD   C,28
            XOR  A
            LD   D,A
            CALL RewriteRoutineDeclareBeginCurrent
            CALL ProofDeclareArgParameter
            CALL RewriteRoutinePublish
            CALL ProofSetWork
            CALL RewriteRoutineFindCurrent
            JP   NC,ProofFailure
            LD   A,(RewriteSymbolCount)
            CP   1
            JP   NZ,ProofFailure
            CALL RewriteRoutineCloseScope
            LD   A,(RewriteSymbolCount)
            OR   A
            JP   NZ,ProofFailure
            LD   A,$D3
            LD   (ProofStatus),A
            HALT

ProofDuplicateDiagnostic:
            LD   A,(DiagnosticCode)
            CP   DiagnosticDuplicateName
            JP   NZ,ProofFailure
            LD   A,$D4
            LD   (ProofStatus),A
            HALT
ProofUnknownDiagnostic:
            LD   A,(DiagnosticCode)
            CP   DiagnosticUnknownName
            JP   NZ,ProofFailure
            LD   A,$D5
            LD   (ProofStatus),A
            HALT
ProofIncompleteDiagnostic:
            LD   A,(DiagnosticCode)
            CP   DiagnosticForwardIncomplete
            JP   NZ,ProofFailure
            LD   A,$D6
            LD   (ProofStatus),A
            HALT
ProofRoutineCapacityDiagnostic:
            LD   A,(DiagnosticCode)
            CP   DiagnosticRoutineCapacity
            JP   NZ,ProofFailure
            LD   A,$D8
            LD   (ProofStatus),A
            HALT
ProofExpectedTopLevelDiagnostic:
            LD   A,(DiagnosticCode)
            CP   DiagnosticExpectedTopLevel
            JP   NZ,ProofFailure
            LD   A,$DD
            LD   (ProofStatus),A
            HALT

.routine in A,HL out A,carry,zero clobbers sign,parity,halfCarry
ProofSetName:
            LD   (TokenLexemePointer),HL
            LD   (TokenLength),A
            XOR  A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofBeginForwardWork:
            CALL ProofSetWork
            LD   B,RewriteScalarTypeU8
            LD   C,28
            LD   D,RewriteRoutineFlagIncomplete
            JP   RewriteRoutineDeclareBeginCurrent

.routine in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofBeginNumberedRoutine:
            CALL ProofSetNumberedRoutine
            LD   B,RewriteScalarTypeU8
            LD   A,(RewriteRoutineCount)
            ADD  A,28
            LD   C,A
            XOR  A
            LD   D,A
            JP   RewriteRoutineDeclareBeginCurrent

.routine in A out A,carry,zero clobbers sign,parity,halfCarry,D,DE,HL
ProofSetNumberedRoutine:
            LD   L,A
            LD   H,0
            LD   DE,ProofRoutineNames
            ADD  HL,DE
            LD   A,1
            JP   ProofSetName

.routine in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofBeginNumberedForward:
            CALL ProofSetNumberedRoutine
            LD   B,RewriteScalarTypeU8
            LD   A,(RewriteRoutineCount)
            ADD  A,28
            LD   C,A
            LD   D,RewriteRoutineFlagIncomplete
            JP   RewriteRoutineDeclareBeginCurrent

.routine in A out A,carry,zero clobbers sign,parity,halfCarry,D,DE,HL
ProofSetParameterLetter:
            LD   L,A
            LD   H,0
            LD   DE,ProofParameterNames
            ADD  HL,DE
            LD   A,1
            JP   ProofSetName

.routine in A out A,carry,zero clobbers sign,parity,halfCarry,BC,D,DE,HL,IX,IY
ProofDeclareLetterU8:
            CALL ProofSetParameterLetter
            LD   A,RewriteScalarTypeU8
            LD   BC,0
            JP   RewriteParameterDeclareCurrent

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,D,DE,HL,IX,IY
ProofDeclareArgParameter:
            CALL ProofSetArg
            LD   A,RewriteScalarTypeU8
            LD   BC,0
            JP   RewriteParameterDeclareCurrent

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,D,DE,HL,IX,IY
ProofDeclareArgGlobal:
            CALL ProofSetArg
            JR   ProofDeclareCurrentGlobal

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,D,DE,HL,IX,IY
ProofDeclareWorkGlobal:
            CALL ProofSetWork
ProofDeclareCurrentGlobal:
            CALL RewriteDeclarationRejectCurrent
            LD   A,RewriteSymbolClassProgram
            LD   D,RewriteScalarTypeU8
            LD   BC,0
            CALL RewriteSymbolPrepareCurrent
            JP   RewriteSymbolCommit

.routine out A,carry,zero clobbers sign,parity,halfCarry,DE,HL
ProofSetWork:
            LD   HL,ProofNameWork
            LD   A,4
            JP   ProofSetName

.routine out A,carry,zero clobbers sign,parity,halfCarry,DE,HL
ProofSetArg:
            LD   HL,ProofNameArg
            LD   A,3
            JP   ProofSetName

.routine out A,carry,zero clobbers sign,parity,halfCarry,DE,HL
ProofSetMain:
            LD   HL,ProofNameMain
            LD   A,4
            JP   ProofSetName

.routine out A,carry,zero clobbers sign,parity,halfCarry,DE,HL
ProofSetOutputFailure:
            LD   HL,ProofNameOutputFailure
            LD   A,13
            JP   ProofSetName

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
ProofNameWork:          .db "work"
ProofNameArg:           .db "arg"
ProofNameMain:          .db "main"
ProofNameWorkUpper:     .db "Work"
ProofNameOutputFailure: .db "outputFailure"
ProofRoutineNames:      .db "abcd"
ProofParameterNames:    .db "pqrstuv"
