NativeStreamingSource .equ 0
; Independently exercise the packed Stage 7 LL(1) engine and generated tables
; with the smallest complete main program. All semantic actions are proof-only
; RET aliases; this proof tests grammar selection, terminal consumption, stack
; order, indirect action returns, and clean completion.

            .include "memory-map.asmi"
SegmentedOutput .equ 0
TargetStreamingOutput .equ 0
            .include "loop-compiler-state.asmi"
            .include "aggregate-call-state.asmi"

AggregateCallSlices .equ 0
CompilerDiagnosticReturns .equ 1
CompilerDiagnosticBranches .equ 1

            .org MMCORE
.routine out A,BC,HL,carry,zero clobbers sign,parity,halfCarry,D,DE
ParserPeek:
            LD   A,(MockPeekFailure)
            OR   A
            JR   Z,ParserPeekReady
            CALL DGINLINE
            .db  DXTOKBAS
ParserPeekReady:
            PUSH HL
            LD   HL,(MockTokenCursor)
            LD   A,(HL)
            POP  HL
            OR   A
            RET
.routine out A,BC,HL,carry,zero clobbers sign,parity,halfCarry,D,DE
ParserTake:
            PUSH HL
            CALL ParserPeek
            JR   C,ParserTakeFailure
            LD   HL,(MockTokenCursor)
            INC  HL
            LD   (MockTokenCursor),HL
            POP  HL
            OR   A
            RET
ParserTakeFailure:
            POP  HL
            RET
.routine in E out A,C,carry,zero clobbers sign,parity,halfCarry,B,D,DE,HL
ParserExpect:
            PUSH DE
            CALL ParserTake
            POP  DE
            RET  C
            CP   E
            RET  Z
            LD   A,E
            OR   DXTOKBAS
.routine in A out A,carry clobbers zero,sign,parity,halfCarry,DE,HL
CompilerSetDiagnostic:
            LD   (DGCODE),A
            SCF
            RET

.routine noreturn
DGINLINE:
            POP  HL
            LD   A,(HL)
            JR   CompilerSetDiagnostic

HybridLL1MeasuredStart:
            .include "stage7-ll1-parser.asm"
HybridLL1MeasuredEnd:

            .org MMSOURCE
MockTokenStream:
            .db TOKENSUB,TNNAME,TNLPAR,TNRPAR
            .db TNFAILS,TNNL,TOKENEND,TNNL,TOKENEOF
MockTokenStreamEnd:

            .org MMPROOF
ProofStart:
            LD   SP,STACKTOP
            LD   HL,MockTokenStream
            LD   (MockTokenCursor),HL
            XOR  A
            LD   (DGCODE),A
            CALL HybridLL1Parse
            JP   C,ProofFailure
            LD   HL,(MockTokenCursor)
            LD   DE,MockTokenStreamEnd
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure

            ; Prediction must propagate a tokenizer/source failure without
            ; retaining the row diagnostic on the hardware stack.
            LD   HL,MockTokenStream
            LD   (MockTokenCursor),HL
            LD   A,1
            LD   (MockPeekFailure),A
            LD   (ProofExpectedSP),SP
            CALL HybridLL1Parse
            JP   NC,ProofFailure
            CP   DXTOKBAS
            JP   NZ,ProofFailure
            LD   A,(DGCODE)
            CP   DXTOKBAS
            JP   NZ,ProofFailure
            LD   HL,0
            ADD  HL,SP
            LD   DE,(ProofExpectedSP)
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            XOR  A
            LD   (MockPeekFailure),A

            ; A four-symbol production exactly fills slots 60..63 without
            ; touching the action workspace immediately above the stack.
            LD   A,$5A
            LD   (HybridLL1StackBase+HYLLCAP),A
            LD   A,60
            LD   (HybridLL1StackDepth),A
            LD   A,31
            CALL HybridLL1PushProduction
            JR   C,ProofFailure
            LD   A,(HybridLL1StackDepth)
            CP   HYLLCAP
            JR   NZ,ProofFailure
            LD   A,(HybridLL1StackBase+HYLLCAP)
            CP   $5A
            JR   NZ,ProofFailure

            ; Both a single-symbol push at depth 64 and the same production
            ; at depth 63 fail atomically with the dedicated diagnostic.
            XOR  A
            CALL HybridLL1PushSymbol
            JR   NC,ProofFailure
            LD   A,(DGCODE)
            CP   DiagnosticParserCapacity
            JR   NZ,ProofFailure
            LD   A,(HybridLL1StackDepth)
            CP   HYLLCAP
            JR   NZ,ProofFailure
            LD   A,63
            LD   (HybridLL1StackDepth),A
            LD   A,31
            CALL HybridLL1PushProduction
            JR   NC,ProofFailure
            LD   A,(DGCODE)
            CP   DiagnosticParserCapacity
            JR   NZ,ProofFailure
            LD   A,(HybridLL1StackDepth)
            CP   63
            JR   NZ,ProofFailure
            LD   A,(HybridLL1StackBase+HYLLCAP)
            CP   $5A
            JR   NZ,ProofFailure
            LD   A,$A5
            LD   (ProofStatus),A
            HALT
ProofFailure:
            LD   A,$EE
            LD   (ProofStatus),A
            HALT

            .include "../../grammar/stage7-proof-actions.asmi"

ProofStatus:     .db 0
MockTokenCursor: .dw 0
MockPeekFailure: .db 0
ProofExpectedSP: .dw 0
ProofEnd:
