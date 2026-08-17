; Generated front-end action programs use this token cache and compact
; interpreter. A generated dispatcher reaches escape targets with ordinary
; full-address jumps; no code address is narrowed or packed into metadata.

.routine out A,BC,carry,zero clobbers sign,parity,halfCarry,D,DE,HL
RewriteParserPeek:
            LD   A,(RewriteParserHasToken)
            OR   A
            JR   Z,RewriteParserPeekLoad
            LD   A,(TokenKind)
            LD   BC,(TokenValue)
            OR   A
            RET
RewriteParserPeekLoad:
            CALL RewriteTokenizerNext
            LD   (TokenKind),A
            LD   (TokenValue),BC
            LD   A,1
            LD   (RewriteParserHasToken),A
            LD   A,(TokenKind)
            OR   A
            RET

.routine out A,BC,carry,zero clobbers sign,parity,halfCarry,D,DE,HL
RewriteParserTake:
            CALL RewriteParserPeek
            LD   D,A
            XOR  A
            LD   (RewriteParserHasToken),A
            LD   A,D
            OR   A
            RET

.routine in HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteActionRun:
RewriteActionNext:
            LD   A,(HL)
            INC  HL
            OR   A
            RET  Z
            LD   (RewriteActionCursor),HL
            JP   M,RewriteActionDoEscape

RewriteActionDoExpect:
            DEC  A
            CP   RewriteActionExpectCount
            JR   NC,RewriteActionInvalid
            ADD  A,A
            LD   E,A
            LD   D,0
            LD   HL,RewriteActionExpectationTable
            ADD  HL,DE
            LD   B,(HL)
            INC  HL
            LD   C,(HL)
            PUSH BC
            CALL RewriteParserTake
            POP  BC
            CP   B
            JR   NZ,RewriteActionExpectedFailure
RewriteActionResume:
            LD   HL,(RewriteActionCursor)
            JR   RewriteActionNext
RewriteActionExpectedFailure:
            LD   A,C
            JP   RewriteRaiseDiagnostic

RewriteActionDoEscape:
            AND  $7F
            CP   RewriteActionEscapeCount
            JR   NC,RewriteActionInvalid
            CALL RewriteActionEscapeDispatch
            JR   RewriteActionResume

RewriteActionInvalid:
            LD   A,DiagnosticInternalOperation
            JP   RewriteRaiseDiagnostic

            .include "actions-escape-generated.asmi"
