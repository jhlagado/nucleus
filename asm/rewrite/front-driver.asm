; Source-driven compilation-unit and routine-body grammar for the replacement
; front end. Generated action programs retain regular token sequencing. This
; driver supplies recursive grammar structure and selects the appropriate
; action from the current token, declared type, and namespace class.

; Parse top-level declarations until the generated EOF action has checked the
; unique-main and incomplete-forward invariants. No declaration kind rewinds
; the source or retains a second tokenizer.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteFrontParseCompilationUnit:
_RewriteFrontTopLevelLoop:
            CALL RewriteParserPeek
            OR   A
            JR   Z,_RewriteFrontCompilationEnd
            CALL RewriteFrontParseTopLevel
            JR   _RewriteFrontTopLevelLoop
_RewriteFrontCompilationEnd:
            LD   HL,RewriteActionProgramCompilationEnd
            JP   RewriteActionRun

.routine in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteFrontParseTopLevel:
            CP   TokenConst
            JP   Z,RewriteFrontParseConstant
            CP   TokenAssert
            JR   Z,_RewriteFrontRunAssert
            CP   TokenVar
            JP   Z,RewriteFrontParseProgram
            CP   TokenRecord
            JP   Z,RewriteFrontParseRecord
            CP   TokenForward
            JR   Z,_RewriteFrontRunForward
            CP   TokenSub
            JP   Z,RewriteFrontParseRoutine
            LD   A,DiagnosticExpectedTopLevel
            JP   RewriteRaiseDiagnostic
_RewriteFrontRunAssert:
            LD   HL,RewriteActionProgramAssert
            JP   RewriteActionRun
_RewriteFrontRunForward:
            LD   HL,RewriteActionProgramRoutineForwardHeader
            JP   RewriteActionRun

; Both constant forms reserve the same provisional constant symbol. The token
; after the name selects inferred scalar `=` or owned aggregate `as` without
; duplicating that lifecycle.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteFrontParseConstant:
            CALL RewriteParserTake
            LD   A,TokenName
            LD   C,DiagnosticExpectedName
            CALL RewriteDeclarationTakeExpected
            CALL RewriteDeclarationBeginScalarConstant
            CALL RewriteParserPeek
            CP   TokenAs
            JR   Z,_RewriteFrontAggregateConstant
            LD   A,TokenEquals
            LD   C,DiagnosticExpectedEqual
            CALL RewriteDeclarationTakeExpected
            CALL RewriteDeclarationFinishScalarConstant
            JR   RewriteFrontCommitProgramSymbol
_RewriteFrontAggregateConstant:
            CALL RewriteParserTake
            CALL RewriteDeclarationParseOwnedType
            LD   A,TokenEquals
            LD   C,DiagnosticExpectedEqual
            CALL RewriteDeclarationTakeExpected
            CALL RewriteDeclarationFinishAggregateConstant
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteFrontCommitProgramSymbol:
            LD   A,TokenNewline
            LD   C,DiagnosticExpectedLine
            CALL RewriteDeclarationTakeExpected
            JP   RewriteSymbolCommit

; Program storage is selected after the complete owned type is known. An
; absent equals sign follows the BSS path; initialized scalars and aggregates
; share the same source prefix and publication tail.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteFrontParseProgram:
            CALL RewriteParserTake
            LD   A,TokenName
            LD   C,DiagnosticExpectedName
            CALL RewriteDeclarationTakeExpected
            CALL RewriteDeclarationBeginProgram
            LD   A,TokenAs
            LD   C,DiagnosticExpectedAs
            CALL RewriteDeclarationTakeExpected
            CALL RewriteDeclarationParseOwnedType
            CALL RewriteParserPeek
            CP   TokenEquals
            JR   Z,_RewriteFrontInitializedProgram
            CALL RewriteDeclarationFinishProgramBss
            JR   RewriteFrontCommitProgramSymbol
_RewriteFrontInitializedProgram:
            CALL RewriteParserTake
            LD   A,(RewriteCurrentType)
            CP   RewriteFirstOwnedTypeId
            JR   NC,_RewriteFrontInitializedAggregate
            CALL RewriteDeclarationFinishProgramScalar
            JR   RewriteFrontCommitProgramSymbol
_RewriteFrontInitializedAggregate:
            CALL RewriteDeclarationFinishProgramAggregate
            JR   RewriteFrontCommitProgramSymbol

; A record field always begins with NAME. An empty record is rejected before
; closing-token syntax, as the frozen diagnostic requires; every other token
; is handed to the generated closing action.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteFrontParseRecord:
            LD   HL,RewriteActionProgramRecordBegin
            CALL RewriteActionRun
_RewriteFrontRecordFieldLoop:
            CALL RewriteParserPeek
            CP   TokenName
            JR   NZ,_RewriteFrontRecordEnd
            LD   HL,RewriteActionProgramRecordField
            CALL RewriteActionRun
            JR   _RewriteFrontRecordFieldLoop
_RewriteFrontRecordEnd:
            LD   A,(RewriteCurrentRecord)
            CALL RewriteRecordAddress
            INC  HL
            LD   A,(HL)
            OR   A
            JP   Z,RewriteDeclarationFinishRecord
            LD   HL,RewriteActionProgramRecordEnd
            JP   RewriteActionRun

; `sub NAME NEWLINE` is the abbreviated forward-body form. The NAME token's
; exact spelling, anchor, and source part are kept on the hardware stack while
; one token of grammar lookahead distinguishes that form from a full header.
; For `(` and NEWLINE the lookahead token is guaranteed to match the first
; subsequent expectation, so restoring NAME metadata cannot hide a failure.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteFrontParseRoutine:
            CALL RewriteParserTake
            LD   A,TokenName
            LD   C,DiagnosticExpectedName
            CALL RewriteDeclarationTakeExpected
            LD   HL,(TokenStartOffset)
            PUSH HL
            LD   HL,(TokenLexemePointer)
            PUSH HL
            LD   A,(TokenLength)
            LD   B,A
            LD   A,(SourcePartId)
            LD   C,A
            PUSH BC
            CALL RewriteParserPeek
            LD   D,A
            CP   TokenNewline
            JR   Z,_RewriteFrontRoutineRestoreName
            CP   TokenLeftParen
            JR   Z,_RewriteFrontRoutineRestoreName
            POP  BC
            POP  HL
            POP  HL
            LD   A,DiagnosticExpectedLeft
            JP   RewriteRaiseDiagnostic
_RewriteFrontRoutineRestoreName:
            POP  BC
            LD   A,B
            LD   (TokenLength),A
            LD   A,C
            LD   (SourcePartId),A
            POP  HL
            LD   (TokenLexemePointer),HL
            POP  HL
            LD   (TokenStartOffset),HL
            LD   A,D
            CP   TokenNewline
            JR   Z,_RewriteFrontForwardBody
            CALL RewriteDeclarationFinishDirectRoutineHeader
            JP   RewriteFrontParseRoutineBody
_RewriteFrontForwardBody:
            CALL RewriteDeclarationOpenForwardBody
            LD   A,TokenNewline
            LD   C,DiagnosticExpectedLine
            CALL RewriteDeclarationTakeExpected
            JP   RewriteFrontParseRoutineBody

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteFrontParseRoutineBody:
_RewriteFrontLocalLoop:
            CALL RewriteParserPeek
            CP   TokenVar
            JR   NZ,_RewriteFrontRoutineStatements
            CALL RewriteFrontParseLocal
            JR   _RewriteFrontLocalLoop
_RewriteFrontRoutineStatements:
            CALL RewriteFrontParseStatementSequence
            LD   HL,RewriteActionProgramRoutineBodyEnd
            JP   RewriteActionRun

; Return with A equal to the unconsumed closing token. EOF is also returned so
; the construct-specific closing action can publish its exact expected-token
; diagnostic rather than a generic statement failure.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteFrontParseStatementSequence:
_RewriteFrontStatementLoop:
            CALL RewriteParserPeek
            CP   TokenEnd
            RET  Z
            CP   TokenElseIf
            RET  Z
            CP   TokenElse
            RET  Z
            OR   A
            JR   NZ,_RewriteFrontStatementReady
            LD   A,DiagnosticExpectedScalar
            JP   RewriteRaiseDiagnostic
_RewriteFrontStatementReady:
            CALL RewriteFrontParseStatement
            JR   _RewriteFrontStatementLoop

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteFrontParseStatement:
            CALL RewriteParserPeek
            CP   TokenName
            JP   Z,RewriteFrontParseNameStatement
            CP   TokenReturn
            JP   Z,RewriteFrontParseReturn
            CP   TokenFail
            JR   Z,_RewriteFrontRunFail
            CP   TokenIf
            JP   Z,RewriteFrontParseIf
            CP   TokenWhile
            JP   Z,RewriteFrontParseWhile
            CP   TokenFor
            JP   Z,RewriteFrontParseFor
            CP   TokenExit
            JR   Z,_RewriteFrontRunExit
            CP   TokenContinue
            JR   Z,_RewriteFrontRunContinue
            LD   A,DiagnosticExpectedScalar
            JP   RewriteRaiseDiagnostic
_RewriteFrontRunFail:
            LD   HL,RewriteActionProgramFail
            JP   RewriteActionRun
_RewriteFrontRunExit:
            LD   HL,RewriteActionProgramExit
            JP   RewriteActionRun
_RewriteFrontRunContinue:
            LD   HL,RewriteActionProgramContinue
            JP   RewriteActionRun

; Local declarations are admitted only before the first routine statement.
; The common prefix is parsed once; the next token then selects default or
; runtime-expression initialization without rewinding source state.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteFrontParseLocal:
            CALL RewriteParserTake
            LD   A,TokenName
            LD   C,DiagnosticExpectedName
            CALL RewriteDeclarationTakeExpected
            CALL RewriteDeclarationBeginLocal
            LD   A,TokenAs
            LD   C,DiagnosticExpectedAs
            CALL RewriteDeclarationTakeExpected
            CALL RewriteDeclarationParseLocalScalarType
            CALL RewriteParserPeek
            CP   TokenEquals
            JR   Z,_RewriteFrontParseInitializedLocal
            CALL RewriteDeclarationEmitDefaultLocal
            LD   A,TokenNewline
            LD   C,DiagnosticExpectedLine
            CALL RewriteDeclarationTakeExpected
            JP   RewriteDeclarationCommitLocal
_RewriteFrontParseInitializedLocal:
            CALL RewriteParserTake
            CALL RewriteDeclarationFinishRuntimeLocalExpression
            LD   A,TokenNewline
            LD   C,DiagnosticExpectedLine
            CALL RewriteDeclarationTakeExpected
            CALL RewriteDeclarationEmitLocalStore
            JP   RewriteDeclarationCommitLocal

; Nucleus has one namespace. A program/local/parameter name begins an
; assignment, while a retained routine or service name begins a call. This
; decides the NAME-led statement without consuming or duplicating lookahead.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteFrontParseNameStatement:
            CALL RewriteSymbolFindCurrent
            JR   C,_RewriteFrontRunAssignment
            OR   A
            CALL RewriteRoutineFindCurrent
            JR   C,_RewriteFrontRunCall
            OR   A
            CALL RewritePredefinedFindCurrent
            JP   NC,RewriteStatementUnknownName
            CP   6
            JP   NC,RewriteStatementUnknownName
_RewriteFrontRunCall:
            OR   A
            LD   HL,RewriteActionProgramCallStatement
            JR   _RewriteFrontRunNameAction
_RewriteFrontRunAssignment:
            OR   A
            LD   HL,RewriteActionProgramScalarAssignment
_RewriteFrontRunNameAction:
            LD   A,(RewriteControlDepth)
            PUSH AF
            CALL RewriteActionRun
            POP  BC
            LD   A,(RewriteControlDepth)
            CP   B
            RET  Z
            DEC  A
            CP   B
            JP   NZ,RewriteActionInvalid
            CALL RewriteControlTopFrame
            LD   A,(HL)
            CP   RewriteControlKindHandler
            JP   NZ,RewriteActionInvalid
            CALL RewriteFrontParseStatementSequence
            LD   HL,RewriteActionProgramHandleEnd
            JP   RewriteActionRun

; The newline immediately after return distinguishes the bare form. The
; expression parser otherwise consumes the complete return value and leaves
; the line ending cached for the shared exact diagnostic check.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteFrontParseReturn:
            CALL RewriteParserTake
            CALL RewriteParserPeek
            CP   TokenNewline
            JR   NZ,_RewriteFrontReturnValue
            CALL RewriteStatementCommitBareReturn
            JR   _RewriteFrontReturnLine
_RewriteFrontReturnValue:
            CALL RewriteStatementParseReturnValue
_RewriteFrontReturnLine:
            LD   A,TokenNewline
            LD   C,DiagnosticExpectedLine
            JP   RewriteDeclarationTakeExpected

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteFrontParseIf:
            LD   HL,RewriteActionProgramIfHeader
            CALL RewriteActionRun
_RewriteFrontIfClause:
            CALL RewriteFrontParseStatementSequence
            CP   TokenElseIf
            JR   Z,_RewriteFrontIfElseIf
            CP   TokenElse
            JR   Z,_RewriteFrontIfElse
            LD   HL,RewriteActionProgramIfNoElseTail
            CALL RewriteActionRun
            JR   _RewriteFrontIfEnd
_RewriteFrontIfElseIf:
            LD   HL,RewriteActionProgramElseIfHeader
            CALL RewriteActionRun
            JR   _RewriteFrontIfClause
_RewriteFrontIfElse:
            LD   HL,RewriteActionProgramElseHeader
            CALL RewriteActionRun
            CALL RewriteFrontParseStatementSequence
            LD   HL,RewriteActionProgramIfElseTail
            CALL RewriteActionRun
_RewriteFrontIfEnd:
            LD   HL,RewriteActionProgramIfEnd
            JP   RewriteActionRun

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteFrontParseWhile:
            LD   HL,RewriteActionProgramWhileHeader
            CALL RewriteActionRun
            CALL RewriteFrontParseStatementSequence
            LD   HL,RewriteActionProgramWhileEnd
            JP   RewriteActionRun

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteFrontParseFor:
            LD   HL,RewriteActionProgramForHeader
            CALL RewriteActionRun
            CALL RewriteFrontParseStatementSequence
            LD   HL,RewriteActionProgramForEnd
            JP   RewriteActionRun
