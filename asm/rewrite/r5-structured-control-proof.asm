; R5 structured-control proof. Semantic records and source text are data;
; every compiler-executed instruction uses an ordinary Z80 mnemonic.

CompilerWorkBase    .equ $6000
SourceBase          .equ $7000
SourceLimit         .equ $7800
RewriteAdapterBase  .equ $A000
RewriteAdapterLimit .equ $A100
DebugHooks          .equ 0

            .org $1000
ProofStructuredControl:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,1
            LD   HL,ProofPartsStructured
            CALL RewriteSourceInitializeParts
            CALL ProofRunDirectHeader
            CALL ProofResetSemantic
            CALL ProofRunIfHeader
            CALL ProofRunBareReturn
            CALL ProofRunElseIfHeader
            CALL ProofRunBareReturn
            CALL ProofRunElseHeader
            CALL ProofRunBareReturn
            CALL ProofRunIfElseTail
            CALL ProofRunIfEnd
            CALL ProofRunWhileHeader
            CALL ProofRunContinue
            CALL ProofRunExit
            CALL ProofRunWhileEnd
            CALL RewriteSemanticValidate
            LD   A,(RewriteControlDepth)
            OR   A
            JP   NZ,ProofFailure
            LD   A,(RewriteControlNextLabel)
            CP   5
            JP   NZ,ProofFailure
            LD   A,(RewriteControlSequenceFallsThrough)
            OR   A
            JP   NZ,ProofFailure
            LD   A,(RewriteSemanticBufferBase)
            CP   19
            JP   NZ,ProofFailure
            LD   HL,RewriteSemanticPayloadBase
            LD   DE,ProofExpectedStructuredSemantics
            LD   B,ProofExpectedStructuredSemanticsEnd-ProofExpectedStructuredSemantics
ProofStructuredSemanticLoop:
            LD   A,(DE)
            CP   (HL)
            JP   NZ,ProofFailure
            INC  DE
            INC  HL
            DJNZ ProofStructuredSemanticLoop
            LD   DE,(RewriteSemanticSinkCursor)
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   A,$E8
            LD   (ProofStatus),A
            HALT

ProofStructuredNonBoolean:
            LD   HL,ProofPartsNonBoolean
            LD   BC,(1<<8)|DiagnosticTypeMismatch
            LD   DE,15
            LD   A,$E9
            JP   ProofArmStructuredDiagnostic

ProofStructuredExitOutsideLoop:
            LD   HL,ProofPartsExitOutsideLoop
            LD   BC,(1<<8)|DiagnosticExpectedLoop
            LD   DE,11
            LD   A,$EA
            JP   ProofArmStructuredDiagnostic

ProofStructuredContinueOutsideLoop:
            LD   HL,ProofPartsContinueOutsideLoop
            LD   BC,(1<<8)|DiagnosticExpectedLoop
            LD   DE,11
            LD   A,$EB
            JP   ProofArmStructuredDiagnostic

ProofStructuredFrameCapacity:
            LD   HL,ProofPartsFrameCapacity
            LD   BC,(1<<8)|DiagnosticControlCapacity
            LD   DE,75
            LD   A,$EC
            JP   ProofArmStructuredDiagnostic

ProofStructuredLabelCapacity:
            LD   HL,ProofPartsLabelCapacity
            LD   BC,(1<<8)|DiagnosticControlLabelCapacity
            LD   DE,11
            LD   A,$ED
            JP   ProofArmStructuredDiagnostic

ProofCountedLoop:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,1
            LD   HL,ProofPartsCounted
            CALL RewriteSourceInitializeParts
            CALL ProofRunDirectHeader
            CALL ProofRunLocalDefault
            CALL ProofResetSemantic
            CALL ProofRunForHeader
            CALL ProofRunContinue
            CALL ProofRunExit
            CALL ProofRunForEnd
            CALL RewriteSemanticValidate
            LD   A,(RewriteControlDepth)
            OR   A
            JP   NZ,ProofFailure
            LD   A,(RewriteControlNextLabel)
            CP   3
            JP   NZ,ProofFailure
            LD   A,(RewriteControlSequenceFallsThrough)
            CP   1
            JP   NZ,ProofFailure
            LD   A,(RewriteSemanticBufferBase)
            CP   11
            JP   NZ,ProofFailure
            LD   HL,RewriteSemanticPayloadBase
            LD   DE,ProofExpectedCountedSemantics
            LD   B,ProofExpectedCountedSemanticsEnd-ProofExpectedCountedSemantics
ProofCountedSemanticLoop:
            LD   A,(DE)
            CP   (HL)
            JP   NZ,ProofFailure
            INC  DE
            INC  HL
            DJNZ ProofCountedSemanticLoop
            LD   DE,(RewriteSemanticSinkCursor)
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   A,$F0
            LD   (ProofStatus),A
            HALT

ProofCountedActiveAssignment:
            LD   HL,ProofPartsActiveAssignment
            LD   BC,(1<<8)|DiagnosticActiveCounter
            LD   DE,ProofActiveAssignmentAnchor-ProofSourceActiveAssignment
            LD   A,$F1
            JP   ProofArmStructuredDiagnostic

ProofCountedNestedCounter:
            LD   HL,ProofPartsNestedCounter
            LD   BC,(1<<8)|DiagnosticActiveCounter
            LD   DE,ProofNestedCounterAnchor-ProofSourceNestedCounter
            LD   A,$F2
            JP   ProofArmStructuredDiagnostic

ProofCountedWrongCounter:
            LD   HL,ProofPartsWrongCounter
            LD   BC,(1<<8)|DiagnosticUnknownName
            LD   DE,ProofWrongCounterAnchor-ProofSourceWrongCounter
            LD   A,$F3
            JP   ProofArmStructuredDiagnostic

ProofCountedZeroStep:
            LD   HL,ProofPartsZeroStep
            LD   BC,(1<<8)|DiagnosticLoopStep
            LD   DE,ProofZeroStepAnchor-ProofSourceZeroStep
            LD   A,$F4
            JP   ProofArmStructuredDiagnostic

ProofCountedVariants:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,1
            LD   HL,ProofPartsCountedVariants
            CALL RewriteSourceInitializeParts
            CALL ProofRunScalarConstant
            CALL ProofRunDirectHeader
            CALL ProofRunLocalDefault
            CALL ProofRunLocalDefault
            CALL ProofRunLocalDefault
            CALL ProofRunLocalDefault
            CALL ProofResetSemantic
            LD   B,4
ProofCountedVariantsLoop:
            PUSH BC
            CALL ProofRunForHeader
            CALL ProofRunForEnd
            POP  BC
            DJNZ ProofCountedVariantsLoop
            CALL RewriteSemanticValidate
            LD   A,(RewriteControlDepth)
            OR   A
            JP   NZ,ProofFailure
            LD   A,(RewriteControlNextLabel)
            CP   12
            JP   NZ,ProofFailure
            LD   A,(RewriteSemanticBufferBase)
            CP   38
            JP   NZ,ProofFailure
            LD   HL,RewriteSemanticPayloadBase
            LD   DE,ProofExpectedCountedVariantSemantics
            LD   B,ProofExpectedCountedVariantSemanticsEnd-ProofExpectedCountedVariantSemantics
ProofCountedVariantSemanticLoop:
            LD   A,(DE)
            CP   (HL)
            JP   NZ,ProofFailure
            INC  DE
            INC  HL
            DJNZ ProofCountedVariantSemanticLoop
            LD   DE,(RewriteSemanticSinkCursor)
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   A,$F5
            LD   (ProofStatus),A
            HALT

ProofCountedBooleanCounter:
            LD   HL,ProofPartsBooleanCounter
            LD   BC,(1<<8)|DiagnosticLoopCounter
            LD   DE,ProofBooleanCounterAnchor-ProofSourceBooleanCounter
            LD   A,$F6
            JP   ProofArmStructuredDiagnostic

ProofCountedNonconstantStep:
            LD   HL,ProofPartsNonconstantStep
            LD   BC,(1<<8)|DiagnosticLoopStep
            LD   DE,ProofNonconstantStepAnchor-ProofSourceNonconstantStep
            LD   A,$F7
            JP   ProofArmStructuredDiagnostic

ProofCountedIncompatibleStart:
            LD   HL,ProofPartsIncompatibleStart
            LD   BC,(1<<8)|DiagnosticIntegerRange
            LD   DE,ProofIncompatibleStartAnchor-ProofSourceIncompatibleStart
            LD   A,$F8
            JP   ProofArmStructuredDiagnostic

ProofCountedNestedTransfers:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,1
            LD   HL,ProofPartsNestedTransfers
            CALL RewriteSourceInitializeParts
            CALL ProofRunDirectHeader
            CALL ProofRunLocalDefault
            CALL ProofResetSemantic
            CALL ProofRunWhileHeader
            CALL ProofRunForHeader
            CALL ProofRunContinue
            CALL ProofRunExit
            CALL ProofRunForEnd
            CALL ProofRunWhileEnd
            CALL RewriteSemanticValidate
            LD   A,(RewriteControlDepth)
            OR   A
            JP   NZ,ProofFailure
            LD   A,(RewriteControlNextLabel)
            CP   5
            JP   NZ,ProofFailure
            LD   A,(RewriteSemanticBufferBase)
            CP   16
            JP   NZ,ProofFailure
            LD   HL,RewriteSemanticPayloadBase
            LD   DE,ProofExpectedNestedTransferSemantics
            LD   B,ProofExpectedNestedTransferSemanticsEnd-ProofExpectedNestedTransferSemantics
ProofCountedNestedTransferSemanticLoop:
            LD   A,(DE)
            CP   (HL)
            JP   NZ,ProofFailure
            INC  DE
            INC  HL
            DJNZ ProofCountedNestedTransferSemanticLoop
            LD   DE,(RewriteSemanticSinkCursor)
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   A,$F9
            LD   (ProofStatus),A
            HALT

ProofCountedNegativeNamedStep:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofExpectedDiagnosticReturn
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,DiagnosticLoopStep
            LD   (ProofExpectedDiagnostic),A
            LD   A,1
            LD   (ProofExpectedPart),A
            LD   HL,ProofNegativeNamedStepAnchor-ProofSourceNegativeNamedStep
            LD   (ProofExpectedOffset),HL
            LD   A,$FA
            LD   (ProofExpectedStatus),A
            LD   A,1
            LD   HL,ProofPartsNegativeNamedStep
            CALL RewriteSourceInitializeParts
            CALL ProofRunScalarConstant
            CALL ProofRunDirectHeader
            CALL ProofRunLocalDefault
            CALL ProofRunForHeader
            JP   ProofFailure

ProofCountedFailableStart:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofExpectedDiagnosticReturn
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,DiagnosticFailureContext
            LD   (ProofExpectedDiagnostic),A
            LD   A,1
            LD   (ProofExpectedPart),A
            LD   HL,ProofFailableStartAnchor-ProofSourceFailableStart
            LD   (ProofExpectedOffset),HL
            LD   A,$FB
            LD   (ProofExpectedStatus),A
            LD   A,1
            LD   HL,ProofPartsFailableStart
            CALL RewriteSourceInitializeParts
            CALL ProofRunForwardHeader
            CALL ProofRunDirectHeader
            CALL ProofRunLocalDefault
            CALL ProofRunForHeader
            JP   ProofFailure

ProofCountedFailableBound:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofExpectedDiagnosticReturn
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,DiagnosticFailureContext
            LD   (ProofExpectedDiagnostic),A
            LD   A,1
            LD   (ProofExpectedPart),A
            LD   HL,ProofFailableBoundAnchor-ProofSourceFailableBound
            LD   (ProofExpectedOffset),HL
            LD   A,$FC
            LD   (ProofExpectedStatus),A
            LD   A,1
            LD   HL,ProofPartsFailableBound
            CALL RewriteSourceInitializeParts
            CALL ProofRunForwardHeader
            CALL ProofRunDirectHeader
            CALL ProofRunLocalDefault
            CALL ProofRunForHeader
            JP   ProofFailure

ProofCountedAggregateStep:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofExpectedDiagnosticReturn
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,DiagnosticLoopStep
            LD   (ProofExpectedDiagnostic),A
            LD   A,1
            LD   (ProofExpectedPart),A
            LD   HL,ProofAggregateStepAnchor-ProofSourceAggregateStep
            LD   (ProofExpectedOffset),HL
            LD   A,$FD
            LD   (ProofExpectedStatus),A
            LD   A,1
            LD   HL,ProofPartsAggregateStep
            CALL RewriteSourceInitializeParts
            CALL ProofRunAggregateConstant
            CALL ProofRunDirectHeader
            CALL ProofRunLocalDefault
            CALL ProofRunForHeader
            JP   ProofFailure

ProofCountedMissingBound:
            LD   HL,ProofPartsMissingBound
            LD   BC,(1<<8)|DiagnosticExpectedScalar
            LD   DE,ProofMissingBoundAnchor-ProofSourceMissingBound
            LD   A,$FE
            JP   ProofArmStructuredDiagnostic

ProofCountedProgramCounter:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofExpectedDiagnosticReturn
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,DiagnosticLoopCounter
            LD   (ProofExpectedDiagnostic),A
            LD   A,1
            LD   (ProofExpectedPart),A
            LD   HL,ProofProgramCounterAnchor-ProofSourceProgramCounter
            LD   (ProofExpectedOffset),HL
            LD   A,$EF
            LD   (ProofExpectedStatus),A
            LD   A,1
            LD   HL,ProofPartsProgramCounter
            CALL RewriteSourceInitializeParts
            CALL ProofRunProgramBss
            CALL ProofRunDirectHeader
            CALL ProofRunForHeader
            JP   ProofFailure

; HL is the descriptor, B the part id, C the diagnostic, DE the offset, and A
; the success status. Every diagnostic returns through the armed continuation.
.routine noreturn
ProofArmStructuredDiagnostic:
            LD   SP,$FF00
            PUSH AF
            PUSH BC
            PUSH DE
            PUSH HL
            CALL RewriteReset
            POP  HL
            POP  DE
            POP  BC
            POP  AF
            LD   (ProofExpectedStatus),A
            LD   A,C
            LD   (ProofExpectedDiagnostic),A
            LD   A,B
            LD   (ProofExpectedPart),A
            LD   (ProofExpectedOffset),DE
            LD   (ProofPartsAddress),HL
            LD   HL,ProofExpectedDiagnosticReturn
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   HL,(ProofPartsAddress)
            LD   A,1
            CALL RewriteSourceInitializeParts
            CALL ProofRunDirectHeader
            LD   A,(ProofExpectedStatus)
            CP   $E9
            JR   Z,ProofRunNonBoolean
            CP   $EB
            JR   Z,ProofRunContinueOutsideLoop
            CP   $EC
            JR   Z,ProofRunFrameCapacity
            CP   $ED
            JR   Z,ProofRunLabelCapacity
            CP   $F1
            JR   Z,ProofRunActiveAssignment
            CP   $F2
            JR   Z,ProofRunNestedCounter
            CP   $F3
            JR   Z,ProofRunWrongCounter
            CP   $F4
            JR   Z,ProofRunZeroStep
            CP   $F6
            JR   Z,ProofRunBooleanCounter
            CP   $F7
            JR   Z,ProofRunNonconstantStep
            CP   $F8
            JR   Z,ProofRunIncompatibleStart
            CP   $FE
            JR   Z,ProofRunMissingBound
            CALL ProofRunExit
            JP   ProofFailure
ProofRunNonBoolean:
            CALL ProofRunIfHeader
            JP   ProofFailure
ProofRunContinueOutsideLoop:
            CALL ProofRunContinue
            JP   ProofFailure
ProofRunFrameCapacity:
            LD   B,9
ProofRunFrameCapacityLoop:
            PUSH BC
            CALL ProofRunIfHeader
            POP  BC
            DJNZ ProofRunFrameCapacityLoop
            JP   ProofFailure
ProofRunLabelCapacity:
            LD   A,26
            LD   (RewriteControlNextLabel),A
            CALL ProofRunIfHeader
            JP   ProofFailure
ProofRunActiveAssignment:
            CALL ProofRunLocalDefault
            CALL ProofRunForHeader
            CALL ProofRunScalarAssignment
            JP   ProofFailure
ProofRunNestedCounter:
            CALL ProofRunLocalDefault
            CALL ProofRunForHeader
            CALL ProofRunForHeader
            JP   ProofFailure
ProofRunWrongCounter:
            CALL ProofRunForHeader
            JP   ProofFailure
ProofRunZeroStep:
            CALL ProofRunLocalDefault
            CALL ProofRunForHeader
            JP   ProofFailure
ProofRunBooleanCounter:
            CALL ProofRunLocalDefault
            CALL ProofRunForHeader
            JP   ProofFailure
ProofRunNonconstantStep:
            CALL ProofRunLocalDefault
            CALL ProofRunLocalDefault
            CALL ProofRunForHeader
            JP   ProofFailure
ProofRunIncompatibleStart:
            CALL ProofRunLocalDefault
            CALL ProofRunForHeader
            JP   ProofFailure
ProofRunMissingBound:
            CALL ProofRunLocalDefault
            CALL ProofRunForHeader
            JP   ProofFailure

ProofExpectedDiagnosticReturn:
            LD   A,(DiagnosticCode)
            LD   B,A
            LD   A,(ProofExpectedDiagnostic)
            CP   B
            JP   NZ,ProofFailure
            LD   A,(DiagnosticPartId)
            LD   B,A
            LD   A,(ProofExpectedPart)
            CP   B
            JP   NZ,ProofFailure
            LD   HL,(DiagnosticOffset)
            LD   DE,(ProofExpectedOffset)
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   A,(ProofExpectedStatus)
            LD   (ProofStatus),A
            HALT

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ProofResetSemantic:
            XOR  A
            LD   (RewriteSemanticBufferBase),A
            LD   HL,RewriteSemanticPayloadBase
            LD   (RewriteSemanticSinkCursor),HL
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunDirectHeader:
            LD   HL,RewriteActionProgramRoutineDirectHeader
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunScalarConstant:
            LD   HL,RewriteActionProgramScalarConstant
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunForwardHeader:
            LD   HL,RewriteActionProgramRoutineForwardHeader
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunAggregateConstant:
            LD   HL,RewriteActionProgramAggregateConstant
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunProgramBss:
            LD   HL,RewriteActionProgramProgramBss
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunIfHeader:
            LD   HL,RewriteActionProgramIfHeader
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunElseIfHeader:
            LD   HL,RewriteActionProgramElseIfHeader
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunElseHeader:
            LD   HL,RewriteActionProgramElseHeader
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunIfElseTail:
            LD   HL,RewriteActionProgramIfElseTail
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunIfEnd:
            LD   HL,RewriteActionProgramIfEnd
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunWhileHeader:
            LD   HL,RewriteActionProgramWhileHeader
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunWhileEnd:
            LD   HL,RewriteActionProgramWhileEnd
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunExit:
            LD   HL,RewriteActionProgramExit
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunContinue:
            LD   HL,RewriteActionProgramContinue
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunBareReturn:
            LD   HL,RewriteActionProgramBareReturn
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunLocalDefault:
            LD   HL,RewriteActionProgramLocalDefault
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunScalarAssignment:
            LD   HL,RewriteActionProgramScalarAssignment
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunForHeader:
            LD   HL,RewriteActionProgramForHeader
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunForEnd:
            LD   HL,RewriteActionProgramForEnd
            JP   RewriteActionRun

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
ProofExpectedPart:       .db 0
ProofExpectedStatus:     .db 0
ProofExpectedOffset:     .dw 0
ProofPartsAddress:       .dw 0

ProofExpectedStructuredSemantics:
            .db RewriteSemanticLiteral16,1,0
            .db RewriteSemanticBranchFalse,1
            .db RewriteSemanticEndGeneralRoutineDirect,0
            .db RewriteSemanticJumpDirect,0
            .db RewriteSemanticControlLabelDirect,1
            .db RewriteSemanticLiteral16,0,0
            .db RewriteSemanticBranchFalse,2
            .db RewriteSemanticEndGeneralRoutineDirect,0
            .db RewriteSemanticJumpDirect,0
            .db RewriteSemanticControlLabelDirect,2
            .db RewriteSemanticEndGeneralRoutineDirect,0
            .db RewriteSemanticControlLabelEnclosing,0
            .db RewriteSemanticControlLabelDirect,3
            .db RewriteSemanticLiteral16,1,0
            .db RewriteSemanticBranchFalse,4
            .db RewriteSemanticJumpDirect,3
            .db RewriteSemanticJumpDirect,4
            .db RewriteSemanticJumpEnclosing,3
            .db RewriteSemanticControlLabelEnclosing,4
ProofExpectedStructuredSemanticsEnd:

ProofExpectedCountedSemantics:
            .db RewriteSemanticLiteral16,0,0
            .db RewriteSemanticLiteral16,100,0
            .db RewriteSemanticForSetup,0,$0F
            .db RewriteSemanticControlLabelDirect,0
            .db RewriteSemanticForTest,0,$0F,2
            .db RewriteSemanticJumpDirect,1
            .db RewriteSemanticJumpDirect,2
            .db RewriteSemanticControlLabelEnclosing,1
            .db RewriteSemanticForNext,0,2,0,$0F
            .dw 2,ProofCountedCounterAnchor-ProofSourceCounted
            .db RewriteSemanticControlLabelEnclosing,2
            .db RewriteSemanticForCleanup
ProofExpectedCountedSemanticsEnd:

ProofExpectedCountedVariantSemantics:
            ; u8, exclusive, default positive step.
            .db RewriteSemanticLiteral16,0,0
            .db RewriteSemanticLiteral16,255,0
            .db RewriteSemanticForSetup,0,$00
            .db RewriteSemanticControlLabelDirect,0
            .db RewriteSemanticForTest,0,$00,2
            .db RewriteSemanticControlLabelEnclosing,1
            .db RewriteSemanticForNext,0,2,0,$00
            .dw 1,ProofCountedVariantByteAnchor-ProofSourceCountedVariants
            .db RewriteSemanticControlLabelEnclosing,2
            .db RewriteSemanticForCleanup
            ; u16, inclusive, named maximum positive step.
            .db RewriteSemanticLiteral16,0,0
            .db RewriteSemanticLiteral16
            .dw $FFFF
            .db RewriteSemanticForSetup,1,$05
            .db RewriteSemanticControlLabelDirect,3
            .db RewriteSemanticForTest,1,$05,5
            .db RewriteSemanticControlLabelEnclosing,4
            .db RewriteSemanticForNext,3,5,1,$05
            .dw $FFFF,ProofCountedVariantWordAnchor-ProofSourceCountedVariants
            .db RewriteSemanticControlLabelEnclosing,5
            .db RewriteSemanticForCleanup
            ; i8, inclusive, explicit positive maximum byte-distance step.
            .db RewriteSemanticLiteral16,128,0
            .db RewriteSemanticNegate16
            .db RewriteSemanticLiteral16,127,0
            .db RewriteSemanticForSetup,3,$09
            .db RewriteSemanticControlLabelDirect,6
            .db RewriteSemanticForTest,3,$09,8
            .db RewriteSemanticControlLabelEnclosing,7
            .db RewriteSemanticForNext,6,8,3,$09
            .dw 255,ProofCountedVariantSignedByteAnchor-ProofSourceCountedVariants
            .db RewriteSemanticControlLabelEnclosing,8
            .db RewriteSemanticForCleanup
            ; i16, exclusive, explicit negative complete-width step.
            .db RewriteSemanticLiteral16
            .dw $7FFF
            .db RewriteSemanticLiteral16
            .dw $8000
            .db RewriteSemanticNegate16
            .db RewriteSemanticForSetup,4,$0E
            .db RewriteSemanticControlLabelDirect,9
            .db RewriteSemanticForTest,4,$0E,11
            .db RewriteSemanticControlLabelEnclosing,10
            .db RewriteSemanticForNext,9,11,4,$0E
            .dw $FFFF,ProofCountedVariantSignedWordAnchor-ProofSourceCountedVariants
            .db RewriteSemanticControlLabelEnclosing,11
            .db RewriteSemanticForCleanup
ProofExpectedCountedVariantSemanticsEnd:

ProofExpectedNestedTransferSemantics:
            .db RewriteSemanticControlLabelDirect,0
            .db RewriteSemanticLiteral16,1,0
            .db RewriteSemanticBranchFalse,1
            .db RewriteSemanticLiteral16,0,0
            .db RewriteSemanticLiteral16,1,0
            .db RewriteSemanticForSetup,0,$01
            .db RewriteSemanticControlLabelDirect,2
            .db RewriteSemanticForTest,0,$01,4
            .db RewriteSemanticJumpDirect,3
            .db RewriteSemanticJumpDirect,4
            .db RewriteSemanticControlLabelEnclosing,3
            .db RewriteSemanticForNext,2,4,0,$01
            .dw 1,ProofNestedTransferCounterAnchor-ProofSourceNestedTransfers
            .db RewriteSemanticControlLabelEnclosing,4
            .db RewriteSemanticForCleanup
            .db RewriteSemanticJumpEnclosing,0
            .db RewriteSemanticControlLabelEnclosing,1
ProofExpectedNestedTransferSemanticsEnd:

            .org $7000
ProofSourceStructured:
            .db "sub main()",10
            .db "if true",10
            .db "return",10
            .db "elseif false",10
            .db "return",10
            .db "else",10
            .db "return",10
            .db "end",10
            .db "while true",10
            .db "continue",10
            .db "exit",10
            .db "end",10
            .db "end",10
ProofSourceStructuredEnd:
ProofSourceNonBoolean:
            .db "sub main()",10,"if 1",10
ProofSourceNonBooleanEnd:
ProofSourceExitOutsideLoop:
            .db "sub main()",10,"exit",10
ProofSourceExitOutsideLoopEnd:
ProofSourceContinueOutsideLoop:
            .db "sub main()",10,"continue",10
ProofSourceContinueOutsideLoopEnd:
ProofSourceFrameCapacity:
            .db "sub main()",10
            .db "if true",10,"if true",10,"if true",10
            .db "if true",10,"if true",10,"if true",10
            .db "if true",10,"if true",10,"if true",10
ProofSourceFrameCapacityEnd:
ProofSourceLabelCapacity:
            .db "sub main()",10,"if true",10
ProofSourceLabelCapacityEnd:
ProofSourceCounted:
            .db "sub main()",10
            .db "var i as i16",10
            .db "for "
ProofCountedCounterAnchor:
            .db "i = 0 to 100 step -2",10
            .db "continue",10,"exit",10,"end",10,"end",10
ProofSourceCountedEnd:
ProofSourceActiveAssignment:
            .db "sub main()",10,"var i as u8",10,"for i = 0 to 1",10
ProofActiveAssignmentAnchor:
            .db "i = 0",10
ProofSourceActiveAssignmentEnd:
ProofSourceNestedCounter:
            .db "sub main()",10,"var i as u8",10,"for i = 0 to 1",10,"for "
ProofNestedCounterAnchor:
            .db "i = 0 to 1",10
ProofSourceNestedCounterEnd:
ProofSourceWrongCounter:
            .db "sub main()",10,"for "
ProofWrongCounterAnchor:
            .db "missing = 0 to 1",10
ProofSourceWrongCounterEnd:
ProofSourceZeroStep:
            .db "sub main()",10,"var i as u8",10,"for i = 0 to 1 step "
ProofZeroStepAnchor:
            .db "0",10
ProofSourceZeroStepEnd:
ProofSourceCountedVariants:
            .db "const maxStep = 65535",10
            .db "sub main()",10
            .db "var byte as u8",10
            .db "var word as u16",10
            .db "var signedByte as i8",10
            .db "var signedWord as i16",10
            .db "for "
ProofCountedVariantByteAnchor:
            .db "byte = 0 until 255",10,"end",10
            .db "for "
ProofCountedVariantWordAnchor:
            .db "word = 0 to 65535 step maxStep",10,"end",10
            .db "for "
ProofCountedVariantSignedByteAnchor:
            .db "signedByte = -128 to 127 step +255",10,"end",10
            .db "for "
ProofCountedVariantSignedWordAnchor:
            .db "signedWord = 32767 until -32768 step -65535",10,"end",10
            .db "end",10
ProofSourceCountedVariantsEnd:
ProofSourceBooleanCounter:
            .db "sub main()",10,"var flag as boolean",10,"for "
ProofBooleanCounterAnchor:
            .db "flag = false to true",10
ProofSourceBooleanCounterEnd:
ProofSourceNonconstantStep:
            .db "sub main()",10,"var stride as u16",10,"var i as u16",10
            .db "for i = 0 to 1 step "
ProofNonconstantStepAnchor:
            .db "stride",10
ProofSourceNonconstantStepEnd:
ProofSourceIncompatibleStart:
            .db "sub main()",10,"var i as i8",10,"for i = "
ProofIncompatibleStartAnchor:
            .db "128 to 127",10
ProofSourceIncompatibleStartEnd:
ProofSourceNestedTransfers:
            .db "sub main()",10,"var i as u8",10,"while true",10,"for "
ProofNestedTransferCounterAnchor:
            .db "i = 0 to 1",10,"continue",10,"exit",10,"end",10,"end",10
ProofSourceNestedTransfersEnd:
ProofSourceNegativeNamedStep:
            .db "const backwards = -1",10,"sub main()",10,"var i as u8",10
            .db "for i = 1 to 0 step "
ProofNegativeNamedStepAnchor:
            .db "backwards",10
ProofSourceNegativeNamedStepEnd:
ProofSourceFailableStart:
            .db "forward sub value() as u8 fails",10
            .db "sub main() fails",10,"var i as u8",10
            .db "for i = value() to "
ProofFailableStartAnchor:
            .db "1",10
ProofSourceFailableStartEnd:
ProofSourceFailableBound:
            .db "forward sub value() as u8 fails",10
            .db "sub main() fails",10,"var i as u8",10
            .db "for i = 0 to value()"
ProofFailableBoundAnchor:
            .db 10
ProofSourceFailableBoundEnd:
ProofSourceAggregateStep:
            .db "const steps as u8[1] = [1]",10
            .db "sub main()",10,"var i as u8",10,"for i = 0 to 1 step "
ProofAggregateStepAnchor:
            .db "steps",10
ProofSourceAggregateStepEnd:
ProofSourceMissingBound:
            .db "sub main()",10,"var i as u8",10,"for i = 0 "
ProofMissingBoundAnchor:
            .db "step 1",10
ProofSourceMissingBoundEnd:
ProofSourceProgramCounter:
            .db "var i as u8",10,"sub main()",10,"for "
ProofProgramCounterAnchor:
            .db "i = 0 to 1",10
ProofSourceProgramCounterEnd:

            .org $9000
ProofPartsStructured: .db 1
                      .dw ProofSourceStructured,ProofSourceStructuredEnd
ProofPartsNonBoolean: .db 1
                      .dw ProofSourceNonBoolean,ProofSourceNonBooleanEnd
ProofPartsExitOutsideLoop: .db 1
                      .dw ProofSourceExitOutsideLoop,ProofSourceExitOutsideLoopEnd
ProofPartsContinueOutsideLoop: .db 1
                      .dw ProofSourceContinueOutsideLoop,ProofSourceContinueOutsideLoopEnd
ProofPartsFrameCapacity: .db 1
                      .dw ProofSourceFrameCapacity,ProofSourceFrameCapacityEnd
ProofPartsLabelCapacity: .db 1
                      .dw ProofSourceLabelCapacity,ProofSourceLabelCapacityEnd
ProofPartsCounted: .db 1
                      .dw ProofSourceCounted,ProofSourceCountedEnd
ProofPartsActiveAssignment: .db 1
                      .dw ProofSourceActiveAssignment,ProofSourceActiveAssignmentEnd
ProofPartsNestedCounter: .db 1
                      .dw ProofSourceNestedCounter,ProofSourceNestedCounterEnd
ProofPartsWrongCounter: .db 1
                      .dw ProofSourceWrongCounter,ProofSourceWrongCounterEnd
ProofPartsZeroStep: .db 1
                      .dw ProofSourceZeroStep,ProofSourceZeroStepEnd
ProofPartsCountedVariants: .db 1
                      .dw ProofSourceCountedVariants,ProofSourceCountedVariantsEnd
ProofPartsBooleanCounter: .db 1
                      .dw ProofSourceBooleanCounter,ProofSourceBooleanCounterEnd
ProofPartsNonconstantStep: .db 1
                      .dw ProofSourceNonconstantStep,ProofSourceNonconstantStepEnd
ProofPartsIncompatibleStart: .db 1
                      .dw ProofSourceIncompatibleStart,ProofSourceIncompatibleStartEnd
ProofPartsNestedTransfers: .db 1
                      .dw ProofSourceNestedTransfers,ProofSourceNestedTransfersEnd
ProofPartsNegativeNamedStep: .db 1
                      .dw ProofSourceNegativeNamedStep,ProofSourceNegativeNamedStepEnd
ProofPartsFailableStart: .db 1
                      .dw ProofSourceFailableStart,ProofSourceFailableStartEnd
ProofPartsFailableBound: .db 1
                      .dw ProofSourceFailableBound,ProofSourceFailableBoundEnd
ProofPartsAggregateStep: .db 1
                      .dw ProofSourceAggregateStep,ProofSourceAggregateStepEnd
ProofPartsMissingBound: .db 1
                      .dw ProofSourceMissingBound,ProofSourceMissingBoundEnd
ProofPartsProgramCounter: .db 1
                      .dw ProofSourceProgramCounter,ProofSourceProgramCounterEnd
