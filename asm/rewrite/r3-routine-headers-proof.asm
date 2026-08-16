; R3 generated routine-header proof. All directive data is source text or proof
; state; compiler-executed instructions use ordinary Z80 mnemonics.

CompilerWorkBase    .equ $6000
SourceBase          .equ $5000
SourceLimit         .equ $5800
RewriteAdapterBase  .equ $A000
RewriteAdapterLimit .equ $A100
DebugHooks          .equ 0

            .org $1000
ProofRoutineHeaders:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,1
            LD   HL,ProofPartsAccepted
            CALL RewriteSourceInitializeParts
            CALL ProofRunForwardHeader
            CALL ProofRunForwardBody
            LD   A,0
            LD   B,RewriteScalarTypeU8
            LD   C,0
            CALL ProofCheckActiveParameter
            LD   A,1
            LD   B,RewriteOpenStringTypeId
            LD   C,1
            CALL ProofCheckActiveParameter
            LD   A,2
            LD   B,RewriteOpenArrayFlag+RewriteScalarTypeI16
            LD   C,4
            CALL ProofCheckActiveParameter
            CALL ProofRunRoutineEnd
            CALL ProofRunDirectHeader
            LD   A,0
            LD   B,RewriteScalarTypeU16
            LD   C,0
            CALL ProofCheckActiveParameter
            LD   A,1
            LD   B,RewriteOpenStringTypeId
            LD   C,2
            CALL ProofCheckActiveParameter
            CALL ProofRunRoutineEnd
            CALL ProofRunDirectHeader
            CALL ProofRunRoutineEnd
            CALL ProofRunCompilationEnd
            LD   A,(RewriteRoutineCount)
            CP   2
            JP   NZ,ProofFailure
            LD   A,(RewriteParameterCount)
            CP   5
            JP   NZ,ProofFailure
            LD   A,(RewriteSymbolCount)
            OR   A
            JP   NZ,ProofFailure
            LD   A,(RewriteMainFlags)
            CP   RewriteRoutineFlagMain+RewriteRoutineFlagFails
            JP   NZ,ProofFailure
            LD   A,0
            LD   B,3
            LD   C,RewriteScalarTypeI16
            LD   D,RewriteRoutineFlagFails
            CALL ProofCheckRoutine
            LD   A,1
            LD   B,2
            LD   C,RewriteScalarTypeI8
            LD   D,0
            CALL ProofCheckRoutine
            ; Forward-body activation offsets are byte, 3-byte open string,
            ; then 4-byte open array; the direct header uses word then open.
            LD   A,0
            LD   B,RewriteScalarTypeU8
            CALL ProofCheckParameter
            LD   A,1
            LD   B,RewriteOpenStringTypeId
            CALL ProofCheckParameter
            LD   A,2
            LD   B,RewriteOpenArrayFlag+RewriteScalarTypeI16
            CALL ProofCheckParameter
            LD   A,3
            LD   B,RewriteScalarTypeU16
            CALL ProofCheckParameter
            LD   A,4
            LD   B,RewriteOpenStringTypeId
            CALL ProofCheckParameter
            LD   A,$E8
            LD   (ProofStatus),A
            HALT

ProofRoutineMissingMain:
            LD   HL,ProofPartsMissingMain
            LD   BC,(DiagnosticExpectedTopLevel<<8)|$E9
            JP   ProofArmDirectThenEofDiagnostic
ProofRoutineIncomplete:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofExpectedIncompleteReturn
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   A,1
            LD   HL,ProofPartsIncomplete
            CALL RewriteSourceInitializeParts
            CALL ProofRunForwardHeader
            CALL ProofRunDirectHeader
            CALL ProofRunRoutineEnd
            CALL ProofRunCompilationEnd
            JP   ProofFailure
ProofExpectedIncompleteReturn:
            LD   A,(DiagnosticCode)
            CP   DiagnosticForwardIncomplete
            JP   NZ,ProofFailure
            LD   A,$EA
            LD   (ProofStatus),A
            HALT
ProofRoutineDuplicateParameter:
            LD   HL,ProofPartsDuplicateParameter
            LD   BC,(DiagnosticDuplicateName<<8)|$EB
            JP   ProofArmDirectDiagnostic
ProofRoutineHeaderIsolation:
            LD   HL,ProofPartsHeaderIsolation
            LD   BC,(DiagnosticUnknownName<<8)|$EC
            JP   ProofArmDirectDiagnostic
ProofRoutineMainParameter:
            LD   HL,ProofPartsMainParameter
            LD   BC,(DiagnosticExpectedRight<<8)|$ED
            JP   ProofArmDirectDiagnostic
ProofRoutineMainResult:
            LD   HL,ProofPartsMainResult
            LD   BC,(DiagnosticExpectedLine<<8)|$EE

; HL part descriptor, B expected diagnostic, C success status.
.routine noreturn
ProofArmDirectDiagnostic:
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
            EX   DE,HL
            LD   A,1
            CALL RewriteSourceInitializeParts
            CALL ProofRunDirectHeader
            JP   ProofFailure

.routine noreturn
ProofArmDirectThenEofDiagnostic:
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
            EX   DE,HL
            LD   A,1
            CALL RewriteSourceInitializeParts
            CALL ProofRunDirectHeader
            CALL ProofRunRoutineEnd
            CALL ProofRunCompilationEnd
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
            LD   A,(ProofExpectedStatus)
            LD   (ProofStatus),A
            HALT

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunDirectHeader:
            LD   HL,RewriteActionProgramRoutineDirectHeader
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunForwardHeader:
            LD   HL,RewriteActionProgramRoutineForwardHeader
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunForwardBody:
            LD   HL,RewriteActionProgramRoutineForwardBody
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunCompilationEnd:
            LD   HL,RewriteActionProgramCompilationEnd
            JP   RewriteActionRun
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofRunRoutineEnd:
            LD   HL,RewriteActionProgramRoutineEnd
            JP   RewriteActionRun

; A routine ordinal, B parameter count, C result, D flags.
.routine in A,B,C,D out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ProofCheckRoutine:
            PUSH AF
            LD   A,D
            LD   (ProofExpectedFlags),A
            POP  AF
            PUSH BC
            PUSH DE
            CALL RewriteRoutineAddress
            POP  DE
            POP  BC
            LD   A,(HL)
            OR   A
            JP   Z,ProofFailure
            LD   DE,RewriteRoutineParameterCount
            ADD  HL,DE
            LD   A,(HL)
            CP   B
            JP   NZ,ProofFailure
            INC  HL
            LD   A,(HL)
            CP   C
            JP   NZ,ProofFailure
            INC  HL
            INC  HL
            LD   A,(HL)
            LD   B,A
            LD   A,(ProofExpectedFlags)
            CP   B
            JP   NZ,ProofFailure
            RET

; A retained parameter ordinal and B exact type.
.routine in A,B out A,carry,zero clobbers sign,parity,halfCarry,B,D,DE,HL
ProofCheckParameter:
            PUSH BC
            CALL RewriteParameterAddress
            POP  BC
            LD   DE,RewriteParameterType
            ADD  HL,DE
            LD   A,(HL)
            CP   B
            JP   NZ,ProofFailure
            RET

; A active symbol ordinal, B type, C byte offset in the activation.
.routine in A,B,C out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ProofCheckActiveParameter:
            PUSH BC
            CALL RewriteSymbolAddress
            POP  BC
            LD   DE,RewriteSymbolClass
            ADD  HL,DE
            LD   A,(HL)
            CP   RewriteSymbolClassParameter
            JP   NZ,ProofFailure
            INC  HL
            LD   A,(HL)
            CP   B
            JP   NZ,ProofFailure
            INC  HL
            LD   A,(HL)
            CP   C
            JP   NZ,ProofFailure
            INC  HL
            LD   A,(HL)
            OR   A
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
ProofExpectedFlags:      .db 0

            .org $7000
ProofSourceAccepted:
            .db "forward sub later(x as u8, text as string[], rows as i16[]) as i16 fails",10
            .db "sub later",10,"end",10
            .db "sub direct(a as u16, text as string[]) as i8",10,"end",10
            .db "sub main() fails",10,"end",10
ProofSourceAcceptedEnd:
ProofSourceMissingMain: .db "sub f()",10,"end",10
ProofSourceMissingMainEnd:
ProofSourceIncomplete: .db "forward sub f()",10,"sub main()",10,"end",10
ProofSourceIncompleteEnd:
ProofSourceDuplicateParameter: .db "sub f(x as u8, x as u16)"
ProofSourceDuplicateParameterEnd:
ProofSourceHeaderIsolation: .db "sub f(x as u8, y as x)"
ProofSourceHeaderIsolationEnd:
ProofSourceMainParameter: .db "sub main(x as u8)"
ProofSourceMainParameterEnd:
ProofSourceMainResult: .db "sub main() as u8"
ProofSourceMainResultEnd:

ProofPartsAccepted:           .db 1
                              .dw ProofSourceAccepted,ProofSourceAcceptedEnd
ProofPartsMissingMain:        .db 1
                              .dw ProofSourceMissingMain,ProofSourceMissingMainEnd
ProofPartsIncomplete:         .db 1
                              .dw ProofSourceIncomplete,ProofSourceIncompleteEnd
ProofPartsDuplicateParameter: .db 1
                              .dw ProofSourceDuplicateParameter,ProofSourceDuplicateParameterEnd
ProofPartsHeaderIsolation:    .db 1
                              .dw ProofSourceHeaderIsolation,ProofSourceHeaderIsolationEnd
ProofPartsMainParameter:      .db 1
                              .dw ProofSourceMainParameter,ProofSourceMainParameterEnd
ProofPartsMainResult:         .db 1
                              .dw ProofSourceMainResult,ProofSourceMainResultEnd
