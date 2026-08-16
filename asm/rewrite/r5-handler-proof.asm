; R5 local-handler proof. Source, semantic records, and directory words are
; data; every compiler-executed instruction uses an ordinary Z80 mnemonic.

CompilerWorkBase    .equ $6000
SourceBase          .equ $7000
SourceLimit         .equ $7800
RewriteAdapterBase  .equ $A000
RewriteAdapterLimit .equ $A100
DebugHooks          .equ 0

            .org $1000
ProofHandlers:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,1
            LD   HL,ProofPartsHandlers
            CALL RewriteSourceInitializeParts
            CALL ProofRunForwardHeader
            CALL ProofRunProgramInitialized
            CALL ProofRunProgramBss
            CALL ProofRunDirectHeader
            CALL ProofRunLocalDefault
            CALL ProofRunLocalDefault
            CALL ProofResetSemantic
            CALL ProofRunScalarAssignment
            CALL ProofRunBareReturn
            CALL ProofRunHandleEnd
            CALL ProofRunCallStatement
            CALL ProofRunBareReturn
            CALL ProofRunHandleEnd
            CALL ProofRunCallStatement
            CALL ProofRunBareReturn
            CALL ProofRunHandleEnd
            CALL RewriteSemanticValidate
            LD   A,(RewriteControlDepth)
            OR   A
            JP   NZ,ProofFailure
            LD   A,(RewriteControlNextLabel)
            CP   6
            JP   NZ,ProofFailure
            LD   A,(RewritePendingFailure)
            OR   A
            JP   NZ,ProofFailure
            LD   A,(RewriteSemanticBufferBase)
            CP   16
            JP   NZ,ProofFailure
            LD   A,$D0
            LD   (ProofStatus),A
            HALT

ProofHandlerLoopTransfers:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,1
            LD   HL,ProofPartsHandlerLoopTransfers
            CALL RewriteSourceInitializeParts
            CALL ProofRunForwardHeader
            CALL ProofRunDirectHeader
            CALL ProofRunLocalDefault
            CALL ProofResetSemantic
            CALL ProofRunWhileHeader
            CALL ProofRunCallStatement
            CALL ProofRunContinue
            CALL ProofRunHandleEnd
            CALL ProofRunCallStatement
            CALL ProofRunExit
            CALL ProofRunHandleEnd
            CALL ProofRunWhileEnd
            CALL RewriteSemanticValidate
            LD   A,(RewriteControlDepth)
            OR   A
            JP   NZ,ProofFailure
            LD   A,(RewriteControlNextLabel)
            CP   6
            JP   NZ,ProofFailure
            LD   A,(RewriteSemanticBufferBase)
            CP   15
            JP   NZ,ProofFailure
            LD   A,$D9
            LD   (ProofStatus),A
            HALT

ProofHandlerUnknown:
            LD   HL,ProofPartsHandlerUnknown
            LD   BC,(1<<8)|DiagnosticUnknownName
            LD   DE,ProofHandlerUnknownAnchor-ProofSourceHandlerUnknown
            LD   A,$D1
            JP   ProofArmHandlerDiagnostic
ProofHandlerWrongType:
            LD   HL,ProofPartsHandlerWrongType
            LD   BC,(1<<8)|DiagnosticTypeMismatch
            LD   DE,ProofHandlerWrongTypeAnchor-ProofSourceHandlerWrongType
            LD   A,$D2
            JP   ProofArmHandlerDiagnostic
ProofHandlerConstant:
            LD   HL,ProofPartsHandlerConstant
            LD   BC,(1<<8)|DiagnosticTypeMismatch
            LD   DE,ProofHandlerConstantAnchor-ProofSourceHandlerConstant
            LD   A,$D3
            JP   ProofArmHandlerDiagnostic
ProofHandlerInfallible:
            LD   HL,ProofPartsHandlerInfallible
            LD   BC,(1<<8)|DiagnosticFailureContext
            LD   DE,ProofHandlerInfallibleAnchor-ProofSourceHandlerInfallible
            LD   A,$D4
            JP   ProofArmHandlerDiagnostic
ProofHandlerDoubleConsumer:
            LD   HL,ProofPartsHandlerDoubleConsumer
            LD   BC,(1<<8)|DiagnosticFailureContext
            LD   DE,ProofHandlerDoubleConsumerAnchor-ProofSourceHandlerDoubleConsumer
            LD   A,$D5
            JP   ProofArmHandlerDiagnostic
ProofHandlerLocalInitializer:
            LD   HL,ProofPartsHandlerLocalInitializer
            LD   BC,(1<<8)|DiagnosticFailureContext
            LD   DE,ProofHandlerLocalInitializerAnchor-ProofSourceHandlerLocalInitializer
            LD   A,$D6
            JP   ProofArmHandlerDiagnostic
ProofHandlerActiveCounter:
            LD   HL,ProofPartsHandlerActiveCounter
            LD   BC,(1<<8)|DiagnosticActiveCounter
            LD   DE,ProofHandlerActiveCounterAnchor-ProofSourceHandlerActiveCounter
            LD   A,$D7
            JP   ProofArmHandlerDiagnostic
ProofHandlerMissingName:
            LD   HL,ProofPartsHandlerMissingName
            LD   BC,(1<<8)|DiagnosticExpectedName
            LD   DE,ProofHandlerMissingNameAnchor-ProofSourceHandlerMissingName
            LD   A,$D8
            JP   ProofArmHandlerDiagnostic

ProofArmHandlerDiagnostic:
            LD   (ProofExpectedStatus),A
            LD   A,C
            LD   (ProofExpectedDiagnostic),A
            LD   A,B
            LD   (ProofExpectedPart),A
            LD   (ProofExpectedOffset),DE
            LD   (ProofPartsAddress),HL
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofExpectedDiagnosticReturn
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,1
            LD   HL,(ProofPartsAddress)
            CALL RewriteSourceInitializeParts
            LD   A,(ProofExpectedStatus)
            CP   $D3
            JR   Z,_ProofHandlerDiagnosticConstant
            CALL ProofRunForwardHeader
            CALL ProofRunDirectHeader
            LD   A,(ProofExpectedStatus)
            CP   $D1
            JR   Z,_ProofHandlerDiagnosticCall
            CP   $D4
            JR   Z,_ProofHandlerDiagnosticLocal
            CP   $D5
            JR   Z,_ProofHandlerDiagnosticLocal
            CP   $D8
            JR   Z,_ProofHandlerDiagnosticCall
            CALL ProofRunLocalDefault
            LD   A,(ProofExpectedStatus)
            CP   $D6
            JR   Z,_ProofHandlerDiagnosticInitializer
            CP   $D7
            JR   Z,_ProofHandlerDiagnosticFor
_ProofHandlerDiagnosticCall:
            CALL ProofRunCallStatement
            JP   ProofFailure
_ProofHandlerDiagnosticLocal:
            CALL ProofRunLocalDefault
            JR   _ProofHandlerDiagnosticCall
_ProofHandlerDiagnosticInitializer:
            CALL ProofRunLocalInitialized
            JP   ProofFailure
_ProofHandlerDiagnosticFor:
            CALL ProofRunForHeader
            JR   _ProofHandlerDiagnosticCall
_ProofHandlerDiagnosticConstant:
            CALL ProofRunScalarConstant
            CALL ProofRunForwardHeader
            CALL ProofRunDirectHeader
            JR   _ProofHandlerDiagnosticCall

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
ProofRunForwardHeader:
            LD   HL,RewriteActionProgramRoutineForwardHeader
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunProgramInitialized:
            LD   HL,RewriteActionProgramProgramScalarInitialized
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunProgramBss:
            LD   HL,RewriteActionProgramProgramBss
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunScalarConstant:
            LD   HL,RewriteActionProgramScalarConstant
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunDirectHeader:
            LD   HL,RewriteActionProgramRoutineDirectHeader
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunLocalDefault:
            LD   HL,RewriteActionProgramLocalDefault
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunLocalInitialized:
            LD   HL,RewriteActionProgramLocalInitializedExpression
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunScalarAssignment:
            LD   HL,RewriteActionProgramScalarAssignment
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunCallStatement:
            LD   HL,RewriteActionProgramCallStatement
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunBareReturn:
            LD   HL,RewriteActionProgramBareReturn
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunHandleEnd:
            LD   HL,RewriteActionProgramHandleEnd
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunForHeader:
            LD   HL,RewriteActionProgramForHeader
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

ProofUnexpectedDiagnostic:
            LD   A,(DiagnosticCode)
            LD   (ProofStatus),A
            HALT
ProofFailure:
            LD   A,$FF
            LD   (ProofStatus),A
            HALT

            .include "compiler-image.asmi"

ProofStatus: .db 0
ProofExpectedDiagnostic: .db 0
ProofExpectedPart: .db 0
ProofExpectedStatus: .db 0
ProofExpectedOffset: .dw 0
ProofPartsAddress: .dw 0

            .org $7000
ProofSourceHandlers:
            .db "forward sub stop() as u8 fails",10
            .db "var initialized as u8 = 0",10
            .db "var saved as u8",10
            .db "sub main() fails",10
            .db "var code as u8",10
            .db "var value as u8",10
            .db "code = stop() handle code",10
            .db "return",10,"end",10
            .db "stop() handle initialized",10
            .db "return",10,"end",10
            .db "stop() handle saved",10
            .db "return",10,"end",10
            .db "end",10
ProofSourceHandlersEnd:
ProofSourceHandlerLoopTransfers:
            .db "forward sub stop() fails",10,"sub main() fails",10
            .db "var code as u8",10,"while true",10
            .db "stop() handle code",10,"continue",10,"end",10
            .db "stop() handle code",10,"exit",10,"end",10
            .db "end",10,"end",10
ProofSourceHandlerLoopTransfersEnd:
ProofSourceHandlerUnknown:
            .db "forward sub stop() fails",10,"sub main() fails",10
            .db "stop() handle "
ProofHandlerUnknownAnchor:
            .db "missing",10,"end",10,"end",10
ProofSourceHandlerUnknownEnd:
ProofSourceHandlerWrongType:
            .db "forward sub stop() fails",10,"sub main() fails",10
            .db "var code as u16",10,"stop() handle "
ProofHandlerWrongTypeAnchor:
            .db "code",10,"end",10,"end",10
ProofSourceHandlerWrongTypeEnd:
ProofSourceHandlerConstant:
            .db "const code = 1",10,"forward sub stop() fails",10
            .db "sub main() fails",10,"stop() handle "
ProofHandlerConstantAnchor:
            .db "code",10,"end",10,"end",10
ProofSourceHandlerConstantEnd:
ProofSourceHandlerInfallible:
            .db "forward sub stop()",10,"sub main()",10,"var code as u8",10
            .db "stop() "
ProofHandlerInfallibleAnchor:
            .db "handle code",10,"end",10,"end",10
ProofSourceHandlerInfallibleEnd:
ProofSourceHandlerDoubleConsumer:
            .db "forward sub stop() fails",10,"sub main() fails",10
            .db "var code as u8",10,"stop() else fail "
ProofHandlerDoubleConsumerAnchor:
            .db "handle code",10,"end",10,"end",10
ProofSourceHandlerDoubleConsumerEnd:
ProofSourceHandlerLocalInitializer:
            .db "forward sub stop() as u8 fails",10,"sub main() fails",10
            .db "var code as u8",10,"var x as u8 = stop() "
ProofHandlerLocalInitializerAnchor:
            .db "handle code",10,"end",10,"end",10
ProofSourceHandlerLocalInitializerEnd:
ProofSourceHandlerActiveCounter:
            .db "forward sub stop() fails",10,"sub main() fails",10
            .db "var i as u8",10,"for i = 0 to 1",10,"stop() handle "
ProofHandlerActiveCounterAnchor:
            .db "i",10,"end",10,"end",10,"end",10
ProofSourceHandlerActiveCounterEnd:
ProofSourceHandlerMissingName:
            .db "forward sub stop() fails",10,"sub main() fails",10,"stop() handle"
ProofHandlerMissingNameAnchor:
            .db 10,"end",10,"end",10
ProofSourceHandlerMissingNameEnd:

            .org $9000
ProofPartsHandlers: .db 1
                      .dw ProofSourceHandlers,ProofSourceHandlersEnd
ProofPartsHandlerLoopTransfers: .db 1
                      .dw ProofSourceHandlerLoopTransfers,ProofSourceHandlerLoopTransfersEnd
ProofPartsHandlerUnknown: .db 1
                      .dw ProofSourceHandlerUnknown,ProofSourceHandlerUnknownEnd
ProofPartsHandlerWrongType: .db 1
                      .dw ProofSourceHandlerWrongType,ProofSourceHandlerWrongTypeEnd
ProofPartsHandlerConstant: .db 1
                      .dw ProofSourceHandlerConstant,ProofSourceHandlerConstantEnd
ProofPartsHandlerInfallible: .db 1
                      .dw ProofSourceHandlerInfallible,ProofSourceHandlerInfallibleEnd
ProofPartsHandlerDoubleConsumer: .db 1
                      .dw ProofSourceHandlerDoubleConsumer,ProofSourceHandlerDoubleConsumerEnd
ProofPartsHandlerLocalInitializer: .db 1
                      .dw ProofSourceHandlerLocalInitializer,ProofSourceHandlerLocalInitializerEnd
ProofPartsHandlerActiveCounter: .db 1
                      .dw ProofSourceHandlerActiveCounter,ProofSourceHandlerActiveCounterEnd
ProofPartsHandlerMissingName: .db 1
                      .dw ProofSourceHandlerMissingName,ProofSourceHandlerMissingNameEnd
