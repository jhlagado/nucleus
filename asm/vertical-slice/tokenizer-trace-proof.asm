; Direct token and full-width source-position trace for comparison punctuation,
; slash tokens, comments, line endings, EOF, and multipart boundaries.

            .include "memory-map.asmi"
SegmentedOutput      .equ 0
TargetStreamingOutput .equ 0
LegacyCompilerSlices .equ 0
AggregateCallSlices  .equ 1
Stage7LL1            .equ 1
            .include "loop-compiler-state.asmi"
            .include "aggregate-call-state.asmi"

            .org CompilerCoreBase
CompilerCodeStart:
            .include "source-adapter.asm"
            .include "loop-tokenizer.asm"

.routine in A out A,carry clobbers zero,sign,parity,halfCarry,DE,HL
CompilerSetDiagnostic:
            LD   (DiagnosticCode),A
            SCF
            RET

.routine noreturn
SetDiagInline:
            POP  HL
            LD   A,(HL)
            JR   CompilerSetDiagnostic
CompilerCodeEnd:

CompilerImmutableStart:
            .include "loop-keywords.asmi"
CompilerImmutableEnd:
CompilerCoreEnd:

            .org SourceBase
TokenizerTracePart1:
            .db  "< <= <> > >= << >> /"
TokenizerTracePart1End:
TokenizerTracePart2:
            .db  "/",10
            .db  "//lf",10
            .db  "//crlf",13,10
            .db  "//eof"
TokenizerTracePart2End:
TokenizerTracePart3:
            .db  "$f"
TokenizerTracePart3End:

TokenizerTraceParts:
            .db  1
            .dw  TokenizerTracePart1,TokenizerTracePart1End
            .db  2
            .dw  TokenizerTracePart2,TokenizerTracePart2End
            .db  3
            .dw  TokenizerTracePart3,TokenizerTracePart3End

            .org ProofBase
.routine out carry,zero clobbers sign,parity,halfCarry,A,BC,DE,HL,IX
ProofStart:
            LD   SP,StackTop
            XOR  A
            LD   (ProofCase),A
            LD   (ProofStatus),A
            LD   A,3
            LD   HL,TokenizerTraceParts
            CALL SourceInitializeParts
            JP   C,ProofFailure
            LD   IX,TokenizerExpectedTrace

TokenizerTraceNext:
            CALL TokenizerNext
            JP   C,ProofFailure
            CP   (IX+0)
            JP   NZ,ProofFailure

            LD   L,(IX+1)
            LD   H,(IX+2)
            LD   DE,(TokenStartOffset)
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure

            LD   L,(IX+3)
            LD   H,(IX+4)
            LD   DE,(TokenStartLine)
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure

            LD   L,(IX+5)
            LD   H,(IX+6)
            LD   DE,(TokenStartColumn)
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure

            LD   DE,7
            ADD  IX,DE
            LD   A,(IX+0)
            INC  A
            JR   NZ,TokenizerTraceNext

            LD   A,$A5
            LD   (ProofStatus),A
            HALT

ProofFailure:
            LD   A,1
            LD   (ProofCase),A
            LD   A,$E0
            LD   (ProofStatus),A
            HALT

; token, offset, line, column. Offsets restart for each source part.
TokenizerExpectedTrace:
            .db  TokenLess
            .dw  0,1,1
            .db  TokenLessEqual
            .dw  2,1,3
            .db  TokenNotEqual
            .dw  5,1,6
            .db  TokenGreater
            .dw  8,1,9
            .db  TokenGreaterEqual
            .dw  10,1,11
            .db  TokenLess
            .dw  13,1,14
            .db  TokenLess
            .dw  14,1,15
            .db  TokenGreater
            .dw  16,1,17
            .db  TokenGreater
            .dw  17,1,18
            .db  TokenSlash
            .dw  19,1,20
            .db  TokenNewline
            .dw  20,1,21
            .db  TokenSlash
            .dw  0,1,1
            .db  TokenNewline
            .dw  1,1,2
            .db  TokenNumber
            .dw  0,1,1
            .db  TokenNewline
            .dw  2,1,3
            .db  TokenEof
            .dw  2,1,3
            .db  $FF

ProofStatus: .db 0
ProofCase:   .db 0
ProofEnd:

            .end
