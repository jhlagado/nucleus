; Predictive parser for the counted-loop and checked-array proof programs.

; Only the Stage 7 packed parser selects the complete grammar overlay. Nesting the
; Stage7LL1 reference keeps every older proof source independent of that flag.
.if AggregateCallSlices
.if Stage7LL1
HybridLL1Full .equ 1
.else
HybridLL1Full .equ 0
.endif
.else
HybridLL1Full .equ 0
.endif

.if AggregateCallSlices
.if TargetStreamingOutput
CompilerNonlocalDiagnostics .equ 1
.else
CompilerNonlocalDiagnostics .equ 0
.endif
.else
CompilerNonlocalDiagnostics .equ 0
.endif

.if CompilerNonlocalDiagnostics
CompilerDiagnosticReturns .equ 0
CompilerDiagnosticBranches .equ 0
.else
CompilerDiagnosticReturns .equ 1
CompilerDiagnosticBranches .equ 1
.endif

.if CompilerNonlocalDiagnostics
.routine noreturn
.else
.routine in A out A,carry clobbers zero,sign,parity,halfCarry,DE,HL
.endif
CompilerSetDiagnostic:
            LD   (DGCODE),A
            LD   A,(SSPARTID)
            LD   (DGPARTID),A
.if CompilerNonlocalDiagnostics
            LD   SP,(CPABRTSP)
.endif
            SCF
            RET

.routine noreturn
DGINLINE:
            POP  HL
            LD   A,(HL)
            JR   CompilerSetDiagnostic

; Shared full-width source and destination setup for the three callers of each
; direction. These helpers alter no position representation or address width.
.routine in DE out BC,DE,HL clobbers parity,halfCarry
CompilerCopyTokenPosition:
            LD   HL,TNSTOFF

; Copy one complete offset/line/column record from HL to DE. LDIR preserves
; carry, allowing diagnostic callers to establish failure after the copy.
.routine in DE,HL out BC,DE,HL clobbers parity,halfCarry
DGCOPYP:
            LD   BC,6
            LDIR
            RET

.routine in HL out BC,DE,HL clobbers parity,halfCarry
CompilerRestoreTokenPosition:
            LD   DE,TNSTOFF
            JR   DGCOPYP

; E is the expected token ordinal. An ordinary mismatch reports the token
; ordinal with DiagnosticExpectedTokenBase set.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ParserExpectLine:
            LD   E,TNNL
.routine in E out A,C,carry,zero clobbers sign,parity,halfCarry,B,D,DE,HL
ParserExpect:
            LD   L,E
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   L
            RET  Z
            LD   A,L
            OR   DXTOKBAS
            JR   CompilerSetDiagnostic

; The expression parser needs one token of lookahead. Token metadata remains
; current until another tokenizer request, so buffering kind and word payload
; is sufficient for names, positions, numbers, and characters.
.routine out A,BC,HL,carry,zero clobbers sign,parity,halfCarry,D,DE
ParserPeek:
            LD   BC,(PSLOOKV)
            LD   A,(PSLOOK)
            OR   A
            RET  NZ
ParserPeekEmpty:
            PUSH HL
.if TargetStreamingOutput
            CALL TKNEXTLP
.else
            CALL TKNEXT
.endif
            POP  HL
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   (PSLOOK),A
            LD   (PSLOOKV),BC
            RET

; Expression reductions keep the left value in HL across lookahead consumption.
.routine out A,BC,HL,carry,zero clobbers sign,parity,halfCarry,D,DE
ParserTake:
            CALL ParserPeek
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   D,A
            XOR  A
            LD   (PSLOOK),A
            XOR  D
            RET

; Frequent token checks enter the common ParserExpect tail. These wrappers
; trade one shared seven-byte body for each repeated eight-byte inline check.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ParserExpectLeft:
            LD   E,TNLPAR
            JR   ParserExpect
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ParserExpectRight:
            LD   E,TNRPAR
            JR   ParserExpect
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ParserExpectAs:
            LD   E,TOKENAS
            JR   ParserExpect
.if LegacyCompilerSlices
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ParserExpectU8:
            LD   E,TOKENU8
            JP   ParserExpect

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ParserExpectAsU8:
            CALL ParserExpectAs
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   ParserExpectU8
.endif

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ParserExpectEqual:
            LD   E,TNEQ
            JR   ParserExpect
.if LegacyCompilerSlices
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ParserExpectSub:
            LD   E,TOKENSUB
            JP   ParserExpect
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ParserExpectLeftBracket:
            LD   E,TNLBRK
            JP   ParserExpect
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ParserExpectRightBracket:
            LD   E,TNRBRK
            JP   ParserExpect
.endif
.if HybridLL1Full
.else
.routine in B,D,HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ParserExpectNamed:
            PUSH BC
            PUSH DE
            PUSH HL
            LD   E,TNNAME
            CALL ParserExpect
            POP  HL
            POP  DE
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL TKNAMEEQ
            JR   NC,ParserExpectNamedNo
            OR   A
            RET
ParserExpectNamedNo:
            LD   A,D
            JP   CompilerSetDiagnostic

.if LegacyCompilerSlices
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ParserExpectIndex:
            LD   D,DXIDX
            LD   HL,KWINDEX
            LD   B,5
            JP   ParserExpectNamed

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ParserExpectBytes:
            LD   D,DXBYTS
            LD   HL,KWBYTES
            LD   B,5
            JP   ParserExpectNamed

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ParserExpectResult:
            LD   D,DXRES
            LD   HL,KWRESULT
            LD   B,6
            JP   ParserExpectNamed
.endif

; Compare the current name token with the one retained by the forward.
.routine in D out A,carry,zero clobbers sign,parity,halfCarry,B,D,DE,HL
ParserCurrentNameIsForward:
            PUSH DE
.if NativeStreamingSource
            LD   HL,FWNAMPTR
            CALL TKRECEQ
.else
            LD   HL,(FWNAMPTR)
            LD   A,(FWNAMLEN)
            LD   B,A
            CALL TKNAMEEQ
.endif
            POP  DE
            JR   NC,ParserCurrentNameNotForward
            OR   A
            RET
ParserCurrentNameNotForward .equ ParserExpectNamedNo

.routine in D out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ParserExpectForwardName:
            PUSH DE
            LD   E,TNNAME
            CALL ParserExpect
            POP  DE
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   ParserCurrentNameIsForward

; Retain the current name token as the one complete forward signature.
.routine out A,carry,zero clobbers sign,parity,halfCarry,HL
ParserRetainForwardName:
.if NativeStreamingSource
            PUSH BC
            LD   HL,FWNAMPTR
            CALL TKRETAIN
            POP  BC
.else
            LD   HL,(TNLEXPTR)
            LD   (FWNAMPTR),HL
            LD   A,(TNLEN)
            LD   (FWNAMLEN),A
.endif
            OR   A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,HL
ParserRetainForwardParameter:
.if NativeStreamingSource
            PUSH BC
            LD   HL,FWPARPTR
            CALL TKRETAIN
            POP  BC
.else
            LD   HL,(TNLEXPTR)
            LD   (FWPARPTR),HL
            LD   A,(TNLEN)
            LD   (FWPARLEN),A
.endif
            OR   A
            RET
.endif

.if LegacyCompilerSlices
.routine in D out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ParserExpectForwardParameter:
            PUSH DE
            LD   E,TNNAME
            CALL ParserExpect
            POP  DE
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,(FWPARPTR)
            LD   A,(FWPARLEN)
            LD   B,A
            PUSH DE
            CALL TKNAMEEQ
            POP  DE
            JR   NC,ParserForwardParameterNo
            OR   A
            RET
ParserForwardParameterNo:
            LD   A,D
            JP   CompilerSetDiagnostic
.endif

.if LegacyCompilerSlices
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ParserExpectWrite:
            LD   E,TNNAME
            CALL ParserExpect
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,KWWRTOUT
            LD   B,15
            CALL TKNAMEEQ
            JR   C,ParserExpectWriteYes
            LD   HL,KWINDEX
            LD   B,5
            CALL TKNAMEEQ
            JR   C,ParserActiveCounter
            CALL DGINLINE
            .db  DXWR
ParserActiveCounter:
            CALL DGINLINE
            .db  DGACTCTR
ParserExpectWriteYes:
            OR   A
            RET
.endif

.if LegacyCompilerSlices
.routine out A,C,carry,zero clobbers sign,parity,halfCarry,B,D,DE,HL
ParserExpectNumber:
            LD   E,TNNUM
            CALL ParserExpect
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,C
            OR   A
            RET
.endif

; Append one operation followed by the byte in C. The helper preserves the
; operand across the sink's internal cursor work.
.routine in A,C out A,carry,zero clobbers sign,parity,halfCarry,B,D,DE,HL
ParserEmitOperationC:
            CALL SemanticSinkOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,C
            JP   SemanticSinkPut

.if LegacyCompilerSlices
; A resolved scalar symbol is represented by its class in A and its storage
; ordinal in C. Expressions emit postfix operations, leaving evaluation order
; independent of either backend's register choices.
.routine in A,C out A,carry,zero clobbers sign,parity,halfCarry,B,D,DE,HL
ParserEmitSymbolLoad:
            CP   SIPU8
            JR   Z,ParserEmitProgramLoad
            CP   SILU8
            JR   NZ,ParserExpectedScalar
            LD   A,SMLDLU8
            JP   ParserEmitOperationC
ParserEmitProgramLoad:
            LD   A,SMLDPU8
            JP   ParserEmitOperationC

.routine in A,C out A,carry,zero clobbers sign,parity,halfCarry,B,D,DE,HL
ParserEmitSymbolStore:
            CP   SIPU8
            JR   Z,ParserEmitProgramStore
            CP   SILU8
            JR   NZ,ParserExpectedScalar
            LD   A,SMSTLU8
            JP   ParserEmitOperationC
ParserEmitProgramStore:
            LD   A,SMSTPU8
            JP   ParserEmitOperationC
.endif

ParserExpectedScalar:
            LD   A,DXSCA
            ; The legacy proof layouts put this target outside JR range.
.if AggregateCallSlices
            JR   CompilerSetDiagnostic
.else
            JP   CompilerSetDiagnostic
.endif

.if LegacyCompilerSlices
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ParserParseScalarPrimary:
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TNNUM
            JR   Z,ParserParseScalarLiteral
            CP   TNNAME
            JR   NZ,ParserExpectedScalar
            CALL SymbolLookupCurrent
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   ParserEmitSymbolLoad
ParserParseScalarLiteral:
            LD   A,SMLITU8
            JP   ParserEmitOperationC

; Precedence climbing uses one loop for both admitted operators. B is the
; minimum precedence; recursive calls only represent nested precedence, not a
; separate parser routine per grammar level.
.routine in B out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ParserParseScalarExpressionMin:
            PUSH BC
            CALL ParserParseScalarPrimary
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
ParserParseScalarExpressionLoop:
            PUSH BC
            CALL ParserPeek
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TNPLUS
            JR   Z,ParserScalarPlus
            CP   TNSTAR
            JR   NZ,ParserScalarExpressionDone
            LD   C,2
            LD   D,SMMULU8
            JR   ParserScalarOperator
ParserScalarPlus:
            LD   C,1
            LD   D,SMADDU8
ParserScalarOperator:
            LD   A,C
            CP   B
            JR   C,ParserScalarExpressionDone
            PUSH BC
            PUSH DE
            CALL ParserTake
            POP  DE
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            PUSH BC
            PUSH DE
            LD   B,C
            INC  B
            CALL ParserParseScalarExpressionMin
            POP  DE
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,D
            PUSH BC
            CALL SemanticSinkOperation
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            JR   ParserParseScalarExpressionLoop
ParserScalarExpressionDone:
            OR   A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ParserParseScalarExpression:
            LD   B,1
            JP   ParserParseScalarExpressionMin
.endif

.if HybridLL1Full
.else
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ParserExpectRoutineHeader:
            LD   D,DXMAIN
            LD   HL,NAMEMAIN
            LD   B,4
            CALL ParserExpectNamed
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectLeft
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectRight
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   E,TNFAILS
            CALL ParserExpect
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   ParserExpectLine
.endif

.if LegacyCompilerSlices
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ParserExpectIndexDeclaration:
            LD   E,TOKENVAR
            CALL ParserExpect
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectIndex
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectAs
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectU8
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   ParserExpectEqual
.endif

.if HybridLL1Full
            ; Packed actions consume the active `else fail` grammar.
.else
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ParserExpectElseFailLine:
            CALL ParserExpectElseFail
.if CompilerDiagnosticReturns
            RET  C
.endif
            ; The legacy proof layouts put this target outside JR range.
.if AggregateCallSlices
            JR   ParserExpectLine
.else
            JP   ParserExpectLine
.endif

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ParserExpectElseFail:
            LD   E,TNELSE
            CALL ParserExpect
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   E,TNFAIL
            ; The legacy proof layouts put this target outside JR range.
.if AggregateCallSlices
            JR   ParserExpect
.else
            JP   ParserExpect
.endif
.endif

.if LegacyCompilerSlices
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ParserExpectPropagateLine:
            CALL ParserExpectElseFailLine
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,SMPROP
            JP   SemanticSinkOperation

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ParserExpectEndLine:
            LD   E,TOKENEND
            CALL ParserExpect
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   ParserExpectLine

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ParserParseLoopProgramAfterSub:
            CALL ParserExpectRoutineHeader
.if CompilerDiagnosticReturns
            RET  C
.endif

            CALL ParserExpectIndexDeclaration
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,SMDECLU8
            CALL SemanticSinkOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectNumber
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL SemanticSinkPut
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectLine
.if CompilerDiagnosticReturns
            RET  C
.endif

            LD   E,TOKENFOR
            CALL ParserExpect
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectIndex
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectEqual
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,SMFORU8
            CALL SemanticSinkOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectNumber
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL SemanticSinkPut
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   E,TNUNT
            CALL ParserExpect
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectNumber
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL SemanticSinkPut
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectLine
.if CompilerDiagnosticReturns
            RET  C
.endif

            CALL ParserExpectWrite
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectLeft
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,SMWROBYT
            CALL SemanticSinkOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   E,TNCHAR
            CALL ParserExpect
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,C
            CALL SemanticSinkPut
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectRight
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectPropagateLine
.if CompilerDiagnosticReturns
            RET  C
.endif

            CALL ParserExpectEndLine
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,SMENDLP
            CALL SemanticSinkOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   ParserFinishRoutine
.endif

; The first general scalar path admits bounded program variables and scalar
; locals, then parses a main body as assignment and output statements. The
; current token is the program variable's name on entry.
.if LegacyCompilerSlices
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ParserParseScalarProgramDeclaration:
            LD   A,(NXPROG)
            LD   E,A
            LD   D,SIPU8
            CALL SymbolPrepareCurrent
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   ParserParseScalarProgramDeclarationAfterPrepare
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ParserParseScalarProgramDeclarationAfterPrepare:
            CALL ParserExpectAsU8
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   ParserParseScalarProgramDeclarationAfterU8
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ParserParseScalarProgramDeclarationAfterU8:
            CALL ParserExpectEqual
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectNumber
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   B,0
            PUSH BC
            LD   A,SMDEFPU8
            CALL SemanticSinkOperation
.if CompilerDiagnosticBranches
            JR   C,ParserScalarProgramOperandFailure
.endif
            LD   A,(NXPROG)
            CALL SemanticSinkPut
.if CompilerDiagnosticBranches
            JR   C,ParserScalarProgramOperandFailure
.endif
            POP  BC
            LD   A,C
            CALL SemanticSinkPut
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectLine
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL SymbolCommit
            LD   HL,NXPROG
            INC  (HL)
            XOR  A
            RET
.if CompilerDiagnosticBranches
ParserScalarProgramOperandFailure:
            POP  BC
            RET
.endif

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ParserParseScalarLocalDeclaration:
            LD   E,TNNAME
            CALL ParserExpect
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(NXLOCAL)
            LD   E,A
            LD   D,SILU8
            CALL SymbolPrepareCurrent
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectAsU8
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectEqual
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(NXLOCAL)
            LD   C,A
            LD   A,SMDLCLU8
            CALL ParserEmitOperationC
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserParseScalarExpression
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(NXLOCAL)
            LD   C,A
            LD   A,SMSTLU8
            CALL ParserEmitOperationC
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectLine
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL SymbolCommit
            LD   HL,NXLOCAL
            INC  (HL)
            XOR  A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ParserParseScalarAssignment:
            CALL SymbolLookupCurrent
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   B,A
            PUSH BC
            CALL ParserExpectEqual
.if CompilerDiagnosticBranches
            JR   C,ParserScalarAssignmentFailure
.endif
            CALL ParserParseScalarExpression
.if CompilerDiagnosticBranches
            JR   C,ParserScalarAssignmentFailure
.endif
            POP  BC
            LD   A,B
            CALL ParserEmitSymbolStore
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   ParserExpectLine
.if CompilerDiagnosticBranches
ParserScalarAssignmentFailure:
            POP  BC
            RET
.endif

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ParserParseScalarWrite:
            LD   HL,(TNSTOFF)
            PUSH HL
            CALL ParserExpectLeft
.if CompilerDiagnosticBranches
            JR   C,ParserScalarWriteFailure
.endif
            CALL ParserParseScalarExpression
.if CompilerDiagnosticBranches
            JR   C,ParserScalarWriteFailure
.endif
            CALL ParserExpectRight
.if CompilerDiagnosticBranches
            JR   C,ParserScalarWriteFailure
.endif
            LD   A,SMWRVU8
            CALL SemanticSinkOperation
.if CompilerDiagnosticBranches
            JR   C,ParserScalarWriteFailure
.endif
            POP  HL
            LD   A,L
.if CompilerDiagnosticReturns
            PUSH HL
            CALL SemanticSinkPut
            POP  HL
.else
            CALL SemanticSinkPutPreserveHL
.endif
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,H
            CALL SemanticSinkPut
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   ParserExpectElseFailLine
.if CompilerDiagnosticBranches
ParserScalarWriteFailure:
            POP  HL
            RET
.endif

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ParserParseScalarStatements:
            CALL ParserPeek
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TOKENEND
            JR   Z,ParserParseScalarEnd
            CP   TNNAME
            JP   NZ,ParserExpectedScalar
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,KWWRTOUT
            LD   B,15
            CALL TKNAMEEQ
            JR   NC,ParserParseScalarAssignmentStatement
            CALL ParserParseScalarWrite
.if CompilerDiagnosticReturns
            RET  C
.endif
            JR   ParserParseScalarStatements
ParserParseScalarAssignmentStatement:
            CALL ParserParseScalarAssignment
.if CompilerDiagnosticReturns
            RET  C
.endif
            JR   ParserParseScalarStatements
ParserParseScalarEnd:
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectLine
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,SMENMAIN
            CALL SemanticSinkOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   E,TOKENEOF
            JP   ParserExpect

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ParserParseScalarTopLevel:
            CALL ParserPeek
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TOKENVAR
            JR   NZ,ParserParseScalarMain
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   E,TNNAME
            CALL ParserExpect
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserParseScalarProgramDeclaration
.if CompilerDiagnosticReturns
            RET  C
.endif
            JR   ParserParseScalarTopLevel
ParserParseScalarMain:
            CP   TOKENSUB
            JR   NZ,ParserScalarExpectedTopLevel
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectRoutineHeader
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,SMBGMAIN
            CALL SemanticSinkOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
ParserParseScalarLocals:
            CALL ParserPeek
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TOKENVAR
            JR   NZ,ParserParseScalarStatements
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserParseScalarLocalDeclaration
.if CompilerDiagnosticReturns
            RET  C
.endif
            JR   ParserParseScalarLocals
ParserScalarExpectedTopLevel:
            CALL DGINLINE
            .db  DXTOPLVL
.endif

.if HybridLL1Full
.else
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ParserParseProgramAfterVar:
            LD   E,TNNAME
            CALL ParserExpect
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   TypedParseProgramAfterVar
.endif

; The older array slice is selected by the bracketed type suffix. Its body is
; still deliberately fixed; this split only keeps scalar names unrestricted.
.if LegacyCompilerSlices
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ParserParseArrayProgramAfterU8:
            CALL ParserExpectLeftBracket
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,SMARRU8
            CALL SemanticSinkOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectNumber
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   4
            JR   Z,ParserArrayLengthYes
            CALL DGINLINE
            .db  DXARRLEN
ParserArrayLengthYes:
            CALL SemanticSinkPut
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectRightBracket
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectEqual
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectLeftBracket
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   C,4
ParserArrayInitializer:
            PUSH BC
            CALL ParserExpectNumber
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL SemanticSinkPut
.if CompilerDiagnosticReturns
            RET  C
.endif
            DEC  C
            JR   Z,ParserArrayInitializerDone
            PUSH BC
            LD   E,TNCOMMA
            CALL ParserExpect
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            JR   ParserArrayInitializer
ParserArrayInitializerDone:
            CALL ParserExpectRightBracket
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectLine
.if CompilerDiagnosticReturns
            RET  C
.endif

            LD   E,TOKENSUB
            CALL ParserExpect
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectRoutineHeader
.if CompilerDiagnosticReturns
            RET  C
.endif

            CALL ParserExpectIndexDeclaration
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   D,DXRD
            LD   HL,KWREADIN
            LD   B,13
            CALL ParserExpectNamed
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectLeft
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectRight
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,SMRDIBYT
            CALL SemanticSinkOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectPropagateLine
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,SMSTRSU8
            CALL SemanticSinkOperation
.if CompilerDiagnosticReturns
            RET  C
.endif

            CALL ParserExpectWrite
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectLeft
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectBytes
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectLeftBracket
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectIndex
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectRightBracket
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectRight
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,SMLDAU8
            CALL SemanticSinkOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,SMWROU8
            CALL SemanticSinkOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectPropagateLine
.if CompilerDiagnosticReturns
            RET  C
.endif
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ParserFinishRoutine:
            CALL ParserExpectEndLine
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,SMRET
            CALL SemanticSinkOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   E,TOKENEOF
            JP   ParserExpect
.endif

; Parse the first general routine-call slice. It deliberately admits one
; retained forward signature while exercising exact completion and parameter
; lookup, scalar call/result flow, and direct recursion.
.if LegacyCompilerSlices
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ParserParseCallProgramAfterForward:
            CALL ParserExpectSub
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   E,TNNAME
            CALL ParserExpect
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserRetainForwardName
            CALL ParserExpectLeft
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   E,TNNAME
            CALL ParserExpect
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserRetainForwardParameter
            CALL ParserExpectAsU8
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectRight
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectAsU8
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectLine
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,1
            LD   (FWORD),A
            CALL ParserExpectSub
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectRoutineHeader
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   E,TOKENVAR
            CALL ParserExpect
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectResult
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectAsU8
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectEqual
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   D,DGFWDMIS
            CALL ParserExpectForwardName
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectLeft
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,SMCLITU8
            CALL SemanticSinkOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(FWORD)
            CALL SemanticSinkPut
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectNumber
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL SemanticSinkPut
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectRight
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectLine
.if CompilerDiagnosticReturns
            RET  C
.endif

            CALL ParserExpectWrite
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectLeft
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectResult
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectRight
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,SMWRLU8
            CALL SemanticSinkOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectElseFailLine
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectEndLine
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,SMENDRTN
            CALL SemanticSinkOperation
.if CompilerDiagnosticReturns
            RET  C
.endif

            CALL ParserExpectSub
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   D,DGFWDMIS
            CALL ParserExpectForwardName
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectLine
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,1
            LD   (FWDONE),A
            LD   A,SMFWDU8
            CALL SemanticSinkOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(FWORD)
            CALL SemanticSinkPut
.if CompilerDiagnosticReturns
            RET  C
.endif

            LD   E,TOKENIF
            CALL ParserExpect
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   D,DXVAL
            CALL ParserExpectForwardParameter
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectEqual
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,SMIFPARZ
            CALL SemanticSinkOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectNumber
.if CompilerDiagnosticReturns
            RET  C
.endif
            OR   A
            JP   NZ,ParserExpectedZero
            CALL SemanticSinkPut
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectLine
.if CompilerDiagnosticReturns
            RET  C
.endif

            LD   E,TNRET
            CALL ParserExpect
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   D,DXVAL
            CALL ParserExpectForwardParameter
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectLine
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,SMRETPAR
            CALL SemanticSinkOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectEndLine
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,SMENDIF
            CALL SemanticSinkOperation
.if CompilerDiagnosticReturns
            RET  C
.endif

            LD   E,TNRET
            CALL ParserExpect
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   D,DGFWDMIS
            CALL ParserExpectForwardName
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectLeft
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   D,DXVAL
            CALL ParserExpectForwardParameter
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   E,TNMIN
            CALL ParserExpect
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,SMRTSELF
            CALL SemanticSinkOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(FWORD)
            CALL SemanticSinkPut
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectNumber
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL SemanticSinkPut
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectRight
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectLine
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectEndLine
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,SMENDRTN
            CALL SemanticSinkOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(FWDONE)
            OR   A
            JR   Z,ParserForwardIncomplete
            LD   E,TOKENEOF
            JP   ParserExpect
ParserExpectedZero:
            CALL DGINLINE
            .db  DXNUM
ParserForwardIncomplete:
            CALL DGINLINE
            .db  DGFWDINC
.endif

.if HybridLL1Full
.else
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ParserParseProgram:
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TOKENSUB
            JP   Z,TypedParseMainAfterTake
            CP   TOKENVAR
            JP   Z,ParserParseProgramAfterVar
            CP   TNFWD
            JP   Z,TypedParseForwardAfterTake
            CP   TNCONST
            JP   Z,TypedParseTopLevelConstAfterTake
            CP   TNREC
            JP   Z,AggregateParseRecordAfterTake
            CALL DGINLINE
            .db  DXTOPLVL
.endif

; A is the stable source-part identity; HL..DE is the half-open byte range.
.if LegacyCompilerSlices
.routine in A,DE,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CompileLoopSlice:
            CALL CompileSliceInitialize
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TOKENSUB
            JP   NZ,ParserScalarExpectedTopLevel
            CALL ParserParseLoopProgramAfterSub
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   SemanticSinkFinish
.routine in A,DE,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CompileCallSlice:
            CALL CompileSliceInitialize
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TNFWD
            JP   NZ,ParserScalarExpectedTopLevel
            CALL ParserParseCallProgramAfterForward
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   SemanticSinkFinish
.endif
.if AggregateCallSlices
.else
            .routine in A,DE,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CompileSlice:
            CALL CompileSliceInitialize
.if HybridLL1Full
            XOR  A
            LD   (C7RTN),A
            CALL HybridLL1Parse
.else
            CALL ParserParseProgram
.endif
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   SemanticSinkFinish
.endif
.if TargetStreamingOutput
.else
.routine in A,DE,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CompileSliceInitialize:
.if AggregateCallSlices
            PUSH AF
            XOR  A
            LD   (SSPREM),A
            POP  AF
.endif
            CALL SAINIT
.endif
.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CompileSliceResetState:
.if CompilerNonlocalDiagnostics
            ; The production entry resets state before SourceInitializeParts.
            ; Clear the complete live-state prefix, but retain the initializer
            ; and static-image buffers plus the later target descriptor and
            ; diagnostic-abort words.
            XOR  A
            LD   HL,CPSTBASE
            LD   (HL),A
            LD   DE,CPSTBASE+1
            LD   BC,AIBAS-CPSTBASE-1
            LDIR
            LD   HL,SMPAYBAS
            LD   (SKCUR),HL
            RET
.else
            XOR  A
            LD   (DGCODE),A
            LD   (DGPARTID),A
.if AggregateCallSlices
            LD   HL,SMPAYBAS
            LD   (SKCUR),HL
            LD   (SKOPCNT),A
            LD   (SMBUFBAS),A
.else
            CALL SemanticSinkReset
.endif
            XOR  A
            LD   (PSLOOK),A
.if AggregateCallSlices
            LD   (SYCNT),A
            LD   (NXLOCAL),A
            LD   (NXPROG),A
.else
            CALL SymbolReset
.endif
            XOR  A
            LD   HL,AGMODE
            LD   B,AGHASINI-AGMODE+1
CompileSliceResetAggregateLoop:
            LD   (HL),A
            INC  HL
            DJNZ CompileSliceResetAggregateLoop
            LD   (IMGLEN),A
            LD   (IMGLEN+1),A
.if SegmentedOutput
            LD   (ROILEN),A
            LD   (ROILEN+1),A
.endif
.if AggregateCallSlices
            LD   (PGBSSLEN),A
            LD   (PGBSSLEN+1),A
.endif
            LD   (FWDONE),A
            LD   (FWORD),A
            RET
.endif

; The typed scalar increment is kept in a separate source unit while it is
; correctness-first and under review. The compression pass may fold shared
; tails back into this parser after the rules are stable.
            .include "typed-expression-parser.asm"
            .include "aggregate-parser.asm"
.if AggregateCallSlices
            .include "aggregate-call-parser.asm"
.endif
