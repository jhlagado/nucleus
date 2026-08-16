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
