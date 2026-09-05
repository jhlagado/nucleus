; Predictive aggregate paths, bounded routine signatures, forwards, and the
; predefined Stage 8 service surface. Runtime carriers are never entered in
; the source symbol model as integers.

.routine in A out A,HL,carry,zero clobbers sign,parity,halfCarry,DE
Stage7RoutineAddress:
            LD   L,A
            LD   H,0
            ADD  HL,HL
            ADD  HL,HL
            ADD  HL,HL
            LD   DE,R7TABBAS
            ADD  HL,DE
            OR   A
            RET

.routine in A out A,HL,carry,zero clobbers sign,parity,halfCarry,DE
Stage7ParameterAddress:
            LD   DE,P7TABBAS
.routine in A,DE out A,HL,carry,zero clobbers sign,parity,halfCarry,DE
Stage7Address4:
            LD   L,A
            LD   H,0
            ADD  HL,HL
            ADD  HL,HL
            ADD  HL,DE
            OR   A
            RET

; Z returns one exact routine match and A its table index. NZ means that the
; current name is not a retained routine; it is not itself a diagnostic.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
Stage7FindRoutineCurrent:
            LD   A,(R7CNT)
            OR   A
            JR   Z,Stage7FindRoutineMissing
            LD   C,A
            LD   B,0
Stage7FindRoutineLoop:
            LD   A,B
            CALL Stage7RoutineAddress
            CALL TKRECEQ
            JR   C,Stage7FindRoutineFound
            INC  B
            DEC  C
            JR   NZ,Stage7FindRoutineLoop
Stage7FindRoutineMissing:
            LD   A,(S8FMFLG)
            AND  R7MAIN
            JR   Z,Stage7FindRoutineAbsent
            CALL TypedNameEqualsMain
            JR   NC,Stage7FindRoutineAbsent
            LD   A,S7MAINRT
            CP   A
            RET
Stage7FindRoutineAbsent:
            LD   A,$FF
            OR   A
            RET
Stage7FindRoutineFound:
            LD   A,B
            CP   A
            RET

Stage7CurrentNameMatchesAtHL .equ TKRECEQ

; Carry identifies a predefined service or error constant and A returns its
; dense ordinal. No match returns carry clear.
.routine out A,B,carry,zero clobbers sign,parity,halfCarry,C,D,DE,HL
Stage8MatchPredefinedCurrent:
            LD   HL,KWPREDEF
            LD   C,KWPRECNT
Stage8MatchPredefinedLoop:
            LD   B,(HL)
            INC  HL
            LD   A,(TNLEN)
            CP   B
            JR   NZ,Stage8MatchPredefinedSkip
            LD   DE,(TNLEXPTR)
Stage8MatchPredefinedByte:
            LD   A,(DE)
            CP   (HL)
            JR   NZ,Stage8MatchPredefinedSkip
            INC  DE
            INC  HL
            DJNZ Stage8MatchPredefinedByte
            LD   A,KWPRECNT
            SUB  C
            SCF
            RET
Stage8MatchPredefinedSkip:
            LD   E,B
            LD   D,0
            ADD  HL,DE
            DEC  C
            JR   NZ,Stage8MatchPredefinedLoop
            OR   A
            RET

.if TargetStreamingOutput
; Compile one multipart source stream and publish one append-only object.
; IX points at the stable compact target descriptor; A/HL retain the existing
; bounded source-part descriptor ABI.
.routine in A,HL,IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CTACPART:
            LD   (CPABRTSP),SP
            LD   (TDPTR),IX
            PUSH AF
            PUSH HL
            CALL CompileSliceResetState
            POP  HL
            POP  AF
            PUSH AF
            CALL SAPARTS
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,B
            LD   (TGSRCPTS),A
            ; Validate every bank-bearing descriptor field before source
            ; semantics can retain a bank ordinal. A is the bounded part count.
            LD   B,A
            LD   IX,(TDPTR)
            LD   A,(IX+TDBNKCNT)
            OR   A
            JR   Z,TargetValidateCompileFailure
            CP   TBKCAP+1
            JR   NC,TargetValidateCompileFailure
            LD   (TDBNKVAL),A
            LD   C,A
            LD   A,(IX+TDENTBNK)
            CP   C
            JR   NC,TargetValidateCompileFailure
            LD   (TDENTVAL),A
            LD   L,(IX+TDPBPTR)
            LD   H,(IX+TDPBPTR+1)
            LD   (TGPBPTR),HL
TargetValidatePartBankLoop:
            LD   A,(HL)
            CP   C
            JR   NC,TargetValidateCompileFailure
            INC  HL
            DJNZ TargetValidatePartBankLoop
.if CompilerNonlocalDiagnostics
.else
            LD   HL,TBKROBAS
            LD   B,TBKROLIM-TBKROBAS
            XOR  A
TargetResetBankRoLengthLoop:
            LD   (HL),A
            INC  HL
            DJNZ TargetResetBankRoLengthLoop
.endif
            CALL CompileAggregateCallReady
.if CompilerDiagnosticReturns
            RET  C
.endif
            ; A diagnostic during generation restores this synthetic frame and
            ; returns directly through the one target-output abort path. A
            ; successful generation returns normally and discards the frame.
            LD   HL,AbortTargetProgram
            PUSH HL
            LD   (CPABRTSP),SP
            CALL EncodeAggregateProgram
            POP  HL
            RET
TargetValidateCompileFailure:
            JP   TargetConfigurationFailure

; Return the bank mapped to the current manifest source-part ordinal.
.routine out A,carry,zero,sign,parity,halfCarry clobbers D,DE,HL,IX
TargetCurrentSourceBank:
            LD   A,(SSPREM)
            AND  SSPORDMS
            RRCA
            RRCA
            RRCA
            LD   E,A
            LD   D,0
            LD   IX,(TDPTR)
            LD   L,(IX+TDPBPTR)
            LD   H,(IX+TDPBPTR+1)
            ADD  HL,DE
            LD   A,(HL)
            OR   A
            RET

; Add the current source bank to flag byte A without disturbing low flags.
.routine in A out A,carry,zero clobbers sign,parity,halfCarry,B,D,DE,HL,IX
TargetPackCurrentBank:
            LD   B,A
            CALL TargetCurrentSourceBank
            RLCA
            RLCA
            RLCA
            RLCA
            OR   B
            RET

; Extract the target bank stored in flag bits 4..5. The final rotate shifts a
; known zero bit through carry, so success returns carry clear.
.routine in A out A,carry,zero clobbers sign,parity,halfCarry
TargetUnpackBank:
            AND  TBKMSK
            RRCA
            RRCA
            RRCA
            RRCA
            RET

; Compare packed bank bits in D with the current source-part bank.
.routine in D out A,carry,zero clobbers sign,parity,halfCarry,B,D,DE,HL,IX
TargetCurrentBankMatches:
            LD   B,D
            CALL TargetCurrentSourceBank
            RLCA
            RLCA
            RLCA
            RLCA
            XOR  B
            AND  TBKMSK
            RET
.routine in D out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
TargetRequireCurrentBank:
            CALL TargetCurrentBankMatches
            RET  Z
            JP   TargetConfigurationFailure

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
TargetRequireEntrySourceBank:
            CALL TargetCurrentSourceBank
            LD   D,A
            LD   A,(TDENTVAL)
            CP   D
            RET  Z
            JP   TargetConfigurationFailure
.endif

.if TargetStreamingOutput
            ; The target entry initializes parts and calls the shared body.
.else
.routine in A,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CompileAggregateCallParts:
            PUSH AF
            PUSH HL
            CALL CompileSliceResetState
            POP  HL
            POP  AF
            CALL SAPARTS
.if CompilerDiagnosticReturns
            RET  C
.endif
            JR   CompileAggregateCallReady
.routine in A,DE,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CompileAggregateCallSlice:
            CALL CompileSliceInitialize
.endif
.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CompileAggregateCallReady:
            INC  A
            LD   (AGMODE),A
            LD   HL,S7STATE
            LD   DE,S7STATE+1
            LD   BC,S7WKEND-S7STATE-1
            XOR  A
            LD   (HL),A
            LDIR
            LD   (CTNXLBL),A
.if Stage7LL1
            CALL LLPARSE
.else
            CALL Stage7ParseTopLevel
.endif
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   SemanticSinkFinish

; Reject a routine name that collides with an ordinary name or an earlier
; routine. The current token remains the name being checked.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
Stage7RejectCurrentDeclarationName:
            CALL SymbolFindCurrent
            JP   C,TypedDuplicateNameFailure
            CALL Stage7FindRoutineCurrent
            JP   Z,TypedDuplicateNameFailure
            CALL Stage8MatchPredefinedCurrent
            JP   C,TypedDuplicateNameFailure
            OR   A
            RET

.if HybridLL1Full
.else
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
Stage7ParseTopLevel:
            CALL PSPEEK
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TNREC
            JR   Z,Stage7TopLevelRecord
            CP   TOKENVAR
            JR   Z,Stage7TopLevelVar
            CP   TNCONST
            JR   Z,Stage7TopLevelConst
            CP   TOKENSUB
            JR   Z,Stage7TopLevelRoutine
            CALL DGINLINE
            .db  DXTOPLVL
Stage7TopLevelRecord:
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   AggregateParseRecordAfterTake
Stage7TopLevelVar:
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   E,TNNAME
            CALL PSEXPECT
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   AggregateParseProgramAfterVar
Stage7TopLevelConst:
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL TypedParseTopLevelConstAfterTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   Stage7ParseTopLevel
Stage7TopLevelRoutine:
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   E,TNNAME
            CALL PSEXPECT
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,NAMEMAIN
            LD   B,4
            CALL TKNAMEEQ
            JP   C,Stage7ParseMainAfterName
            JP   Stage7ParseRoutineAfterName
.endif

; Check the current parameter name against the current signature prefix.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
Stage7CheckParameterDuplicate:
            LD   A,(C7PARCNT)
            OR   A
            RET  Z
            LD   C,A
            LD   A,(C7PARST)
            LD   B,A
Stage7CheckParameterLoop:
            LD   A,B
            CALL Stage7ParameterAddress
            CALL TKRECEQ
            JP   C,TypedDuplicateNameFailure
            INC  B
            DEC  C
            JR   NZ,Stage7CheckParameterLoop
            OR   A
            RET

; Reject a parameter name that collides with a routine, a predefined binding,
; the routine whose signature is being parsed, or an earlier parameter in that
; signature. An older program symbol may be shadowed by this routine binding.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
Stage7CheckParameterDeclarationName:
            CALL Stage7CurrentNameIsRoutineOrPredefined
            JP   C,TypedDuplicateNameFailure
            LD   A,(C7RTN)
            CALL Stage7RoutineAddress
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            INC  HL
            LD   A,(HL)
            LD   B,A
            EX   DE,HL
            CALL TKNAMEEQ
            JP   C,TypedDuplicateNameFailure
            JR   Stage7CheckParameterDuplicate

; Append the current parameter name and its parsed type A.
.routine in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
Stage7AppendParameter:
            LD   (S7PATHT),A
            LD   A,(P7CNT)
            CP   P7CAP
            JR   NC,Stage7ParameterCapacityFailure
            CALL Stage7ParameterAddress
            CALL TKRETAIN
            INC  HL
            LD   A,(S7PATHT)
            LD   (HL),A
            LD   HL,P7CNT
            INC  (HL)
            LD   HL,C7PARCNT
            INC  (HL)
            LD   A,(S7PATHT)
            OR   A
            RET
Stage7ParameterCapacityFailure:
            CALL DGINLINE
            .db  DGPARCAP

; Parse the parameter list and optional result of the provisional routine.
.if HybridLL1Full
.else
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
Stage7ParseSignature:
            CALL ParserExpectLeft
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL PSPEEK
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TNRPAR
            JR   Z,Stage7SignatureClose
Stage7SignatureParameter:
            LD   E,TNNAME
            CALL PSEXPECT
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL Stage7CheckParameterDeclarationName
.if CompilerDiagnosticReturns
            RET  C
.endif
            PUSH HL
.if NativeStreamingSource
            LD   HL,DCNAMPTR
            CALL TKRETAIN
.else
            LD   HL,(TNLEXPTR)
            LD   (DCNAMPTR),HL
            LD   A,(TNLEN)
            LD   (DCNAMLEN),A
.endif
            POP  HL
            CALL ParserExpectAs
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL AggregateParseType
.if CompilerDiagnosticReturns
            RET  C
.endif
            PUSH AF
            CALL TypedRestoreDeclarationToken
            POP  AF
            CALL Stage7AppendParameter
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL PSPEEK
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TNCOMMA
            JR   NZ,Stage7SignatureClose
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            JR   Stage7SignatureParameter
Stage7SignatureClose:
            CALL ParserExpectRight
.if CompilerDiagnosticReturns
            RET  C
.endif
            XOR  A
            LD   (C7RESTYP),A
            CALL PSPEEK
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TOKENAS
            JR   NZ,Stage7SignatureLine
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL AggregateParseType
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   (C7RESTYP),A
Stage7SignatureLine:
            JP   ParserExpectLine
.endif

; Install one retained parameter as an activation symbol and emit the copy
; from its caller-stack carrier into the routine's negative IX frame.
.routine in A,C out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
Stage7InstallParameter:
            LD   (C7PARST),A
            LD   A,C
            LD   (S7ARGIDX),A
            LD   A,(C7PARST)
            CALL Stage7ParameterAddress
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            INC  HL
            LD   B,(HL)
            INC  HL
            LD   A,(HL)
            LD   (S7PATHT),A
.if NativeStreamingSource
            LD   H,D
            LD   L,E
            CALL SAMATTOK
.else
            LD   (TNLEXPTR),DE
            LD   A,B
            LD   (TNLEN),A
.endif
            LD   A,(NXLOCAL)
            LD   (S7PATHOF),A
            LD   C,A
            LD   B,0
            LD   A,(S7PATHT)
            CP   AGDYNTYP
            LD   D,SYAGGFLG+SCPAR
            JR   NC,Stage7InstallParameterSymbol
Stage7InstallScalarParameter:
            OR   SCPAR
            LD   D,A
Stage7InstallParameterSymbol:
            CALL SymbolAppendCurrentWord
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(S7PATHT)
            CALL SymbolCommitTyped
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(S7PATHT)
            CP   AGOAMSK
            JR   C,Stage7InstallPublishParameter
            LD   A,TYU16          ; address word
            CALL Stage7PublishParameterBinding
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,S7PATHOF
            INC  (HL)
            INC  (HL)
            LD   HL,S7ARGIDX
            INC  (HL)
            INC  (HL)
            LD   A,TYU16          ; retained count word
            CALL Stage7PublishParameterBinding
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,4
            JR   Stage7InstallParameterWidth
Stage7InstallPublishParameter:
            CALL Stage7PublishParameterBinding
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(S7PATHT)
            CP   AGDYNTYP
            JR   C,Stage7InstallScalarParameterWidth
            CP   AGOSTR
            JR   C,Stage7InstallAggregateParameterWidth
            LD   A,3
            JR   Stage7InstallParameterWidth
Stage7InstallAggregateParameterWidth:
            LD   A,2
            JR   Stage7InstallParameterWidth
Stage7InstallScalarParameterWidth:
            CALL TypedTypeWidth
Stage7InstallParameterWidth:
            LD   HL,NXLOCAL
            ADD  A,(HL)
            LD   (HL),A
            OR   A
            RET

.routine in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
Stage7PublishParameterBinding:
            LD   C,A
            LD   A,SMBINDP
            CALL ParserEmitOperationC
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(S7PATHOF)
            CALL SemanticSinkPut
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(S7ARGIDX)
            JP   SemanticSinkPut

; Current token is a non-main routine name.
.if HybridLL1Full
.else
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
Stage7ParseRoutineAfterName:
            LD   A,(R7CNT)
            CP   R7CAP
            JP   NC,Stage7RoutineCapacityFailure
            CALL Stage7RejectCurrentDeclarationName
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(R7CNT)
            LD   (C7RTN),A
            CALL Stage7RoutineAddress
            CALL TKRETAIN
            INC  HL
            LD   A,(P7CNT)
            LD   (HL),A
            LD   (C7PARST),A
            XOR  A
            LD   (C7PARCNT),A
            CALL Stage7ParseSignature
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(C7RTN)
            CALL Stage7RoutineAddress
            LD   DE,R7PARCNT
            ADD  HL,DE
            LD   A,(C7PARCNT)
            LD   (HL),A
            INC  HL
            LD   A,(C7RESTYP)
            LD   (HL),A
            INC  HL
            LD   A,(C7RTN)
            ADD  A,R7LBLBAS
            LD   (HL),A
            LD   (S7CALLBL),A
            LD   HL,R7CNT
            INC  (HL)
            LD   A,(SYCNT)
            LD   (S7GLBCNT),A
            XOR  A
            LD   (NXLOCAL),A
            CALL ControlReset
            LD   A,(C7RESTYP)
            OR   A
            LD   A,CRVAL
            JR   NZ,Stage7RoutineKindReady
            XOR  A
Stage7RoutineKindReady:
            LD   (CRKIND),A
            LD   A,(C7RESTYP)
            LD   (CTRESTYP),A
            LD   A,1
            LD   (CTFALLS),A
            LD   A,SMBGGRTN
            CALL SemanticSinkOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(S7CALLBL)
            CALL SemanticSinkPut
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(C7PARCNT)
            CALL SemanticSinkPut
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   B,A
            LD   A,(C7PARST)
            LD   D,A
            XOR  A
            LD   E,A
Stage7RoutineParameterLoop:
            LD   A,B
            OR   A
            JR   Z,Stage7RoutineLocals
            CALL Stage7ParameterSourceOffset
            LD   A,D
            PUSH DE
            PUSH BC
            CALL Stage7InstallParameter
            POP  BC
            POP  DE
.if CompilerDiagnosticReturns
            RET  C
.endif
            INC  D
            INC  E
            DEC  B
            JR   Stage7RoutineParameterLoop

Stage7RoutineLocals:
            CALL TypedParseLocalRun
.if CompilerDiagnosticReturns
            RET  C
.endif
Stage7RoutineStatements:
            CALL TypedParseStatements
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(C7RESTYP)
            OR   A
            JR   Z,Stage7RoutineEndToken
            LD   A,(CTFALLS)
            OR   A
            JP   NZ,TypedRoutineFlowFailure
Stage7RoutineEndToken:
            LD   E,TOKENEND
            CALL PSEXPECT
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectLine
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,SMENGRTN
            CALL SemanticSinkOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(C7RESTYP)
            CALL SemanticSinkPut
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(S7GLBCNT)
            LD   (SYCNT),A
            XOR  A
            LD   (NXLOCAL),A
            JP   Stage7ParseTopLevel
Stage7RoutineCapacityFailure:
            CALL DGINLINE
            .db  DGRTNCAP

; Main is the final declaration in this increment. `fails` is accepted but
; its full call/failure surface remains Stage 8.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
Stage7ParseMainAfterName:
            CALL Stage7RejectCurrentDeclarationName
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
            CALL PSPEEK
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TNFAILS
            JR   NZ,Stage7MainLine
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
Stage7MainLine:
            CALL ParserExpectLine
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,SMBGMAIN
            CALL SemanticSinkOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(SYCNT)
            LD   (S7GLBCNT),A
            XOR  A
            LD   (NXLOCAL),A
            LD   (C7RESTYP),A
            LD   (CRKIND),A
            CALL ControlReset
            LD   A,1
            LD   (CTFALLS),A
Stage7MainLocals:
            CALL TypedParseLocalRun
.if CompilerDiagnosticReturns
            RET  C
.endif
Stage7MainStatements:
            CALL TypedParseStatements
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   E,TOKENEND
            CALL PSEXPECT
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
            JP   PSEXPECT
.endif

; Return the positive IX displacement of the current source argument. Every
; later source parameter contributes one address/scalar word; each later open
; view contributes its hidden count/capacity word as well.
.routine in B,D out A,B,C,D,E,carry,zero clobbers sign,parity,halfCarry,HL
Stage7ParameterSourceOffset:
            PUSH BC
            PUSH DE
            LD   A,B
            ADD  A,A
            ADD  A,2
            LD   C,A
            DEC  B
            JR   Z,_parameterSourceOffsetDone
            LD   A,D
            INC  A
            CALL Stage7ParameterAddress
_parameterSourceOffsetLoop:
            INC  HL
            INC  HL
            INC  HL
            LD   A,(HL)
            CP   AGOVIEW
            JR   C,_parameterSourceOffsetNext
            INC  C
            INC  C
_parameterSourceOffsetNext:
            INC  HL                      ; next four-byte parameter entry
            DJNZ _parameterSourceOffsetLoop
_parameterSourceOffsetDone:
            LD   A,C
            POP  DE
            POP  BC
            LD   C,A
            OR   A
            RET

; Return aggregate symbol info in D, word payload in BC, and exact type ID in
; A. All fields are contiguous in the ordinary symbol-table entry.
.routine out A,BC,D,carry,zero clobbers sign,parity,halfCarry,E,HL
Stage7LookupAggregateCurrent:
            CALL SymbolFindCurrent
            JP   NC,SymbolLookupMissing
            INC  HL
            INC  HL
            INC  HL
            LD   D,(HL)
            INC  HL
            LD   C,(HL)
            INC  HL
            LD   B,(HL)
            INC  HL
            LD   A,(HL)
            OR   A
            RET

; Stage 7 structural operands are emitted whenever their owning operation is
; emitted. They are not expression values and therefore do not consult the
; constant-folding emission flag used by TypedEmitWord.
.routine in HL out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
Stage7EmitWord:
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
            JP   SemanticSinkPut

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
Stage7EmitExtentAndCallOffset:
            LD   HL,(S7PATHEX)
            CALL Stage7EmitWord
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,(S7CALOFF)
            JR   Stage7EmitWord

.routine in A out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
Stage7EmitOperationAndPathOffset:
            CALL SemanticSinkOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,(S7PATHOF)
            JR   Stage7EmitWord

; D is the symbol class and BC its byte offset. Emit its opaque root carrier
; and return the exact aggregate type in A.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
Stage7EmitAggregateSymbolRoot:
            CALL Stage7LookupAggregateCurrent
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   (S7PATHT),A
            CP   AGOVIEW
            JR   C,Stage7EmitAggregateRootClass
            LD   A,C
            INC  A
            INC  A
            LD   (S7OVCOFF),A
Stage7EmitAggregateRootClass:
            LD   A,D
            AND  SCMSK
            JR   Z,Stage7EmitAggregateRootReadOnly
            CP   SCPROG
            JR   NZ,Stage7EmitAggregateRootParameter
            LD   A,SMLDPALS
Stage7EmitAggregateRootAddress:
            PUSH BC
            CALL SemanticSinkOperation
            POP  HL
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL Stage7EmitWord
            JR   Stage7EmitAggregateRootReady
Stage7EmitAggregateRootReadOnly:
.if TargetStreamingOutput
            PUSH BC
            CALL TargetRequireCurrentBank
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
.endif
            LD   A,SMLDROAL
            JR   Stage7EmitAggregateRootAddress
Stage7EmitAggregateRootParameter:
            CP   SCPAR
            JP   NZ,TypedTypeFailure
            LD   A,SMLDPARA
Stage7EmitAggregateRootSelected:
            CALL ParserEmitOperationC
Stage7EmitAggregateRootReady:
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(S7PATHT)
            OR   A
            RET

; Emit one checked postfix chain. A is the current aggregate type and one
; carrier is live on the generated evaluation stack. D returns zero for an
; address path, one when a property has produced a scalar value, or two when
; assignment parsing has retained a bounded-string carrier for `.length =`.
.routine out A,carry,zero clobbers sign,parity,halfCarry
Stage7PathCompareOpenString:
            LD   A,(S7PATHT)
            CP   AGOSTR
            RET

; These retained expression actions live here so the path and call parsers can
; reuse their result-saving tail under strict one-pass register contracts.
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LACONEXP:
            XOR  A                       ; ScalarTypeExact
            CALL TypedExpressionBeginConstant
            JR   HybridLL1SaveExpressionResult

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LARTEXP:
            LD   A,(EXEXPTYP)
            CALL TypedExpressionBeginRuntime
.routine in A,BC,DE,HL out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
HybridLL1SaveExpressionResult:
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   (EXRMETA),A
            LD   (EXRVAL),HL
            OR   A
            RET

.routine in A out A,D,carry,zero clobbers sign,parity,halfCarry,B,C,E,HL,IX,IY
Stage7ParsePathSuffix:
            LD   D,0
Stage7PathSuffixLoop:
            PUSH AF
            CALL PSPEEK
.if CompilerDiagnosticBranches
            JP   C,Stage7PathSuffixFailure
.endif
            CP   TOKENDOT
            JR   Z,Stage7PathFieldComposition
            CP   TNLBRK
            JP   Z,Stage7PathIndexComposition
            POP  AF
            LD   D,0
            OR   A
            RET
Stage7PathFieldComposition:
            POP  AF
            LD   (S7PATHT),A
            CALL Stage8RequireNoPendingFailure
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(S7PATHT)
            PUSH AF
Stage7PathField:
            CALL ParserTake
.if CompilerDiagnosticBranches
            JP   C,Stage7PathSuffixFailure
.endif
            LD   E,TNNAME
            CALL PSEXPECT
.if CompilerDiagnosticBranches
            JP   C,Stage7PathSuffixFailure
.endif
            POP  AF
            PUSH AF
            CP   AGDYNTYP
.if CompilerDiagnosticBranches
            JP   C,Stage7PathFieldTypeFailure
.endif
            CP   AGOSTR
            JR   Z,Stage7PathStringField
            CP   AGOAMSK
            JR   NC,Stage7PathArrayField
            CALL AggregateTypeAddress
            LD   A,(HL)
            CP   ATKSTR
            JR   Z,Stage7PathStringField
            CP   ATKARRAY
            JR   Z,Stage7PathArrayField
            JP   Stage7PathRecordField
Stage7PathStringField:
            LD   HL,KWLENGTH
            LD   B,6
            CALL TKNAMEEQ
            JR   C,Stage7PathStringLength
            LD   HL,KWCAP
            LD   B,8
            CALL TKNAMEEQ
            JP   NC,Stage7PathFieldTypeFailure
            CALL Stage7PathCompareOpenString
            JP   NZ,Stage7PathFieldTypeFailure
            LD   A,(S7OVCOFF)
            LD   C,A
            LD   A,SMSTRCAP
            CALL ParserEmitOperationC
.if CompilerDiagnosticBranches
            JP   C,Stage7PathSuffixFailure
.endif
            JR   Stage7PathStringScalarReady
Stage7PathStringLength:
            LD   A,(S7PASMOD)
            OR   A
            JR   Z,Stage7PathStringLengthRead
            CALL Stage7PathCompareOpenString
            JP   NZ,Stage7PathFieldTypeFailure
            LD   A,(S7OVCOFF)
            LD   (S7SROFF),A
            POP  AF
            LD   D,2
            OR   A
            RET
Stage7PathStringLengthRead:
            CALL Stage7PathCompareOpenString
            JR   Z,Stage7PathOpenStringLengthRead
            CALL Stage7StringCapacity
            LD   C,A
            LD   A,SMSTRLEN
            JR   Stage7PathStringLengthReady
Stage7PathOpenStringLengthRead:
            LD   A,(S7OVCOFF)
            LD   C,A
            LD   A,SMOSLEN
Stage7PathStringLengthReady:
            CALL ParserEmitOperationC
.if CompilerDiagnosticBranches
            JP   C,Stage7PathSuffixFailure
.endif
            LD   HL,(TNSTOFF)
            CALL Stage7EmitWord
.if CompilerDiagnosticBranches
            JP   C,Stage7PathSuffixFailure
.endif
Stage7PathStringScalarReady:
            POP  AF
            LD   A,TYU8
            JR   Stage7PathScalarPropertyReady
Stage7PathArrayField:
            LD   HL,KWLENGTH
            LD   B,6
            CALL TKNAMEEQ
            JP   NC,Stage7PathFieldTypeFailure
            LD   A,(S7PASMOD)
            OR   A
            JP   NZ,Stage7PathFieldTypeFailure
            LD   A,(S7PATHT)
            CP   AGOAMSK
            JR   NC,Stage7PathOpenArrayLength
            CALL AggregateTypeAddress
            INC  HL
            INC  HL
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            LD   (S7PATHOF),DE
            LD   A,SMARRLEN
            CALL Stage7EmitOperationAndPathOffset
.if CompilerDiagnosticBranches
            JP   C,Stage7PathSuffixFailure
.endif
            JR   Stage7PathArrayLengthReady
Stage7PathOpenArrayLength:
            LD   A,(S7OVCOFF)
            LD   C,A
            LD   A,SMOALEN
            CALL ParserEmitOperationC
.if CompilerDiagnosticBranches
            JP   C,Stage7PathSuffixFailure
.endif
Stage7PathArrayLengthReady:
            POP  AF
            LD   A,TYU16
Stage7PathScalarPropertyReady:
            LD   D,1
            OR   A
            RET
Stage7FieldMissing:
            CALL DGINLINE
            .db  DGUNKNAM
Stage7PathRecordField:
            POP  AF
            CALL AggregateTypeAddress
            LD   A,(HL)
            CP   ATKREC
            JP   NZ,TypedTypeFailure
            INC  HL
            LD   B,(HL)
            INC  HL
            LD   D,(HL)
Stage7PathRecordFieldLoop:
            LD   A,D
            OR   A
            JR   Z,Stage7FieldMissing
            LD   A,B
            CALL AggregateFieldAddress
            PUSH DE
            CALL TKRECEQ
            POP  DE
            JR   C,Stage7PathRecordFieldFound
            INC  B
            DEC  D
            JR   Stage7PathRecordFieldLoop
Stage7PathRecordFieldFound:
            LD   DE,AFTYPID
            ADD  HL,DE
            LD   A,(HL)
            INC  HL
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            OR   A
            PUSH AF
            LD   (S7PATHOF),DE
            LD   A,SMSELFLD
            CALL Stage7EmitOperationAndPathOffset
.if CompilerDiagnosticBranches
            JP   C,Stage7PathSuffixFailure
.endif
            POP  AF
            JP   Stage7PathSuffixLoop
Stage7PathIndexComposition:
            POP  AF
            LD   (S7PATHT),A
            CALL Stage8RequireNoPendingFailure
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(S7OVCOFF)
            PUSH AF
            LD   A,(S7PATHT)
            PUSH AF
Stage7PathIndex:
            LD   HL,(TNSTOFF)
            PUSH HL
            CALL ParserTake
.if CompilerDiagnosticBranches
            JP   C,Stage7PathIndexFailure
.endif
            LD   A,(EXEXPTYP)
            PUSH AF
            LD   A,(EXEMITON)
            PUSH AF
            LD   A,1
            LD   (EXEMITON),A
            LD   A,TYU16
            LD   (EXEXPTYP),A
            CALL TypedParseOr
.if CompilerDiagnosticBranches
            JP   C,Stage7PathIndexExpressionFailure
.endif
            CALL TypedRequireComposable
.if CompilerDiagnosticBranches
            JP   C,Stage7PathIndexExpressionFailure
.endif
            CALL HybridLL1SaveExpressionResult
            POP  AF
            LD   (EXEMITON),A
            POP  AF
            LD   (EXEXPTYP),A
            LD   A,(EXRMETA)
            AND  MTTYPMSK
            CP   TYBOOL
            JP   Z,Stage7PathIndexTypeFailure
            CALL Stage7PrepareIntegerIndex
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   E,TNRBRK
            CALL PSEXPECT
.if CompilerDiagnosticBranches
            JP   C,Stage7PathIndexFailure
.endif
            POP  HL
            LD   (S7CALOFF),HL
            POP  AF
            LD   E,A
            POP  BC
            LD   A,B
            LD   (S7OVCOFF),A
            LD   A,E
            CP   AGDYNTYP
            JP   C,TypedTypeFailure
            PUSH AF
            CP   AGOSTR
            JR   Z,Stage7PathOpenStringIndex
            CP   AGOAMSK
            JR   NC,Stage7PathOpenArrayIndex
            CALL AggregateTypeAddress
            LD   A,(HL)
            CP   ATKSTR
            JR   Z,Stage7PathStringIndex
            CP   ATKARRAY
            JP   NZ,Stage7PathFieldTypeFailure
            INC  HL
            LD   A,(HL)                  ; element type
            LD   (S7PATHT),A
            INC  HL
            LD   C,(HL)                  ; fixed length
            INC  HL
            LD   B,(HL)
            LD   A,(EXRMETA)
            AND  MTCONST
            JR   Z,Stage7PathIndexDynamic
            LD   HL,(EXRVAL)
            OR   A
            SBC  HL,BC
.if CompilerNonlocalDiagnostics
            JR   NC,Stage7PathIndexRangeFailure
.else
            JP   NC,Stage7PathIndexRangeFailure
.endif
Stage7PathIndexDynamic:
            LD   (S7PATHOF),BC
            LD   A,(S7PATHT)
            CALL AggregateGetExtent
            LD   (S7PATHEX),HL
            LD   A,SMSELIDX
            CALL Stage7EmitOperationAndPathOffset
.if CompilerDiagnosticBranches
            JR   C,Stage7PathSuffixFailure
.endif
            JR   Stage7PathArrayIndexTail
Stage7PathOpenArrayIndex:
            AND  AGOAELEM
            LD   (S7PATHT),A
            CALL AggregateGetExtent
            LD   (S7PATHEX),HL
            LD   A,(S7OVCOFF)
            LD   C,A
            LD   A,SMOAIDX
            CALL ParserEmitOperationC
.if CompilerDiagnosticBranches
            JR   C,Stage7PathSuffixFailure
.endif
Stage7PathArrayIndexTail:
            CALL Stage7EmitExtentAndCallOffset
.if CompilerDiagnosticBranches
            JR   C,Stage7PathSuffixFailure
.endif
            POP  AF
            LD   A,(S7PATHT)
            JP   Stage7PathSuffixLoop
Stage7PathStringIndex:
            INC  HL
            LD   C,(HL)                  ; capacity
            LD   A,SMSTRIDX
            JR   Stage7PathStringIndexReady
Stage7PathOpenStringIndex:
            LD   A,(S7OVCOFF)
            LD   C,A
            LD   A,SMOSIDX
Stage7PathStringIndexReady:
            CALL ParserEmitOperationC
.if CompilerDiagnosticBranches
            JR   C,Stage7PathSuffixFailure
.endif
            LD   HL,(S7CALOFF)
            CALL Stage7EmitWord
.if CompilerDiagnosticBranches
            JR   C,Stage7PathSuffixFailure
.endif
            POP  AF
            LD   A,TYU8
            JP   Stage7PathSuffixLoop
.if CompilerDiagnosticBranches
Stage7PathSuffixFailure:
            POP  AF
            SCF
            RET
.endif
Stage7PathIndexTypeFailure:
            POP  HL
            POP  AF
            POP  BC
            JP   TypedTypeFailure

; Convert a signed dynamic index to checked u16 before the existing unsigned
; upper-bound operation. Exact negatives are diagnosed at the index value.
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
Stage7PrepareIntegerIndex:
            LD   C,TYU16
            LD   A,(EXRMETA)
            LD   D,A
            AND  MTCONST
            JR   NZ,Stage7PrepareExactIndex
            LD   A,D
            AND  TYSGNFLG
            RET  Z
            SET  7,C                     ; range failure is an index bounds trap
            LD   HL,(EXVALPOS)
            JP   TypedEmitIntegerConversionOperation
Stage7PrepareExactIndex:
            LD   HL,(EXRVAL)
            LD   A,D
            CALL TypedConvertConstant
            JP   C,TypedValueRangeFailure
            OR   A
            RET
.if CompilerDiagnosticBranches
Stage7PathIndexFailure:
            POP  HL
            POP  AF
            POP  BC
            SCF
            RET
Stage7PathIndexExpressionFailure:
            POP  AF
            LD   (EXEMITON),A
            POP  AF
            LD   (EXEXPTYP),A
            JR   Stage7PathIndexFailure
.endif
Stage7PathIndexRangeFailure:
            LD   A,(EXSUPFLT)
            OR   A
.if CompilerNonlocalDiagnostics
            JR   NZ,Stage7PathIndexDynamic
.else
            JP   NZ,Stage7PathIndexDynamic
.endif
            LD   HL,(S7CALOFF)
            LD   (TNSTOFF),HL
            POP  AF
            JP   TypedRangeFailure
Stage7PathFieldTypeFailure:
            POP  AF
            JP   TypedTypeFailure

; Address one bounded nested-call frame. Eight bytes retain the source-call
; metadata that nested argument calls may overwrite. The scalar parser keeps
; only its balanced expression context, a source frame keeps its result flag,
; and a service keeps only its source offset temporarily on the compiler
; hardware stack.
.routine in A out HL,carry,zero clobbers A,sign,parity,halfCarry,D,DE
Stage7CallFrameAddress:
            ADD  A,F7RTNIDX
            JP   Stage7RoutineAddress

.routine out HL,carry,zero clobbers A,sign,parity,halfCarry,D,DE
Stage7CurrentCallFrame:
            LD   A,(S7CALDEP)
            DEC  A
            JR   Stage7CallFrameAddress

; Parse and validate one scalar argument against the expected type in A while
; preserving the enclosing expression context across nested calls.
.routine in A out A,HL,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,IX,IY
Stage7ParseScalarArgument:
            LD   D,A
            LD   A,(EXEXPTYP)
            LD   B,A
            LD   A,(EXEMITON)
            LD   C,A
            PUSH BC
            PUSH DE
            LD   A,D
            LD   (EXEXPTYP),A
            LD   A,1
            LD   (EXEMITON),A
            CALL TypedParseOr
.if CompilerDiagnosticBranches
            JR   C,Stage7ScalarArgumentFailure
.endif
            CALL HybridLL1SaveExpressionResult
            POP  DE
            POP  BC
            LD   A,C
            LD   (EXEMITON),A
            LD   A,B
            LD   (EXEXPTYP),A
            LD   E,D
            JP   HybridLL1CheckFailureResult
.if CompilerDiagnosticBranches
Stage7ScalarArgumentFailure:
            LD   L,A
            POP  DE
            POP  BC
            LD   A,C
            LD   (EXEMITON),A
            LD   A,B
            LD   (EXEXPTYP),A
            LD   A,L
            SCF
            RET
.endif

; Parse one call to a retained routine. A is the routine-table index and C is
; zero when the result is discarded or one when its carrier remains live.
.routine in A,C out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
Stage7ParseCall:
            LD   B,A
            LD   A,(S7CALDEP)
            CP   F7CAP
            JR   C,Stage7PushCallFrameSpace
            CALL DGINLINE
            .db  DGEXPCAP
Stage7PushCallFrameSpace:
            CALL Stage7CallFrameAddress
            LD   A,C
            PUSH AF
            PUSH HL
            LD   A,B
            CP   S7MAINRT
            JR   Z,Stage7PushMainCallFrame
            CALL Stage7RoutineAddress
            INC  HL
            INC  HL
            INC  HL
            LD   D,(HL)                  ; parameter start
            INC  HL
            LD   E,(HL)                  ; parameter count
            INC  HL
            LD   B,(HL)                  ; result
            INC  HL
            LD   A,(HL)                  ; label
            INC  HL
            LD   C,(HL)                  ; failure flags
            JR   Stage7PushCallFrameReady
Stage7PushMainCallFrame:
            LD   DE,0                    ; parameter start/count
            LD   B,D                     ; result-free
            LD   A,(S8FMFLG)
            LD   C,A
            LD   A,S7MAINLB
Stage7PushCallFrameReady:
            POP  HL
            LD   (HL),A
            POP  AF
            OR   A
            JR   Z,Stage7PushCallFrameLabelReady
            SET  6,(HL)
Stage7PushCallFrameLabelReady:
            INC  HL
            LD   (HL),B
            INC  HL
            LD   (HL),D
            INC  HL
            LD   (HL),E
            INC  HL
            LD   (HL),E                  ; original argument count
            INC  HL
            LD   DE,(TNSTOFF)
            LD   (HL),E
            INC  HL
            LD   (HL),D
            INC  HL
            LD   (HL),C
            LD   HL,S7CALDEP
            INC  (HL)
            CALL ParserExpectLeft
.if CompilerDiagnosticBranches
            JP   C,Stage7CallFailure
.endif
Stage7CallArgumentLoop:
            CALL Stage7CurrentCallFrame
            INC  HL
            INC  HL
            INC  HL
            LD   A,(HL)
            OR   A
            JP   Z,Stage7CallArgumentsDone
            DEC  HL
            LD   A,(HL)                  ; current parameter table index
            CALL Stage7ParameterAddress
            INC  HL
            INC  HL
            INC  HL
            XOR  A
            LD   (S8DIRFBL),A
            LD   A,(HL)
            CP   AGOSTR
            JR   NZ,Stage7CallClassifyStoredArgument
            CALL PSPEEK
.if CompilerDiagnosticBranches
            JP   C,Stage7CallFailure
.endif
            CP   TNSTRLIT
            JR   Z,Stage7CallStringLiteralArgument
            LD   A,(HL)
Stage7CallClassifyStoredArgument:
            CP   AGDYNTYP
            JR   NC,Stage7CallAggregateArgument
            CALL Stage7ParseScalarArgument
.if CompilerDiagnosticBranches
            JP   C,Stage7CallFailure
.endif
            JP   Stage7CallArgumentReady
Stage7CallStringLiteralArgument:
.if CompilerDiagnosticReturns
            CALL Stage7ParseStringLiteralArgument
            JP   C,Stage7CallFailure
            JP   Stage7CallArgumentReady
.endif
; Materialize one contextual string literal as a distinct bank-local constant.
; The object remains anonymous: only its bank-local read-only offset enters the
; semantic stream, and target publication walks it after the named constants.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
Stage7ParseStringLiteralArgument:
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(TNLEN)
            CP   254
            JP   NC,AggregateStringCapacityFailure
            OR   A
            JR   NZ,Stage7StringLiteralCapacityReady
            INC  A
Stage7StringLiteralCapacityReady:
            LD   (S7ARGCNT),A
            LD   L,A
            LD   H,0
            INC  HL
            INC  HL
            LD   (ACOBJEXT),HL
.if TargetStreamingOutput
            CALL Stage7CurrentCallFrame
            LD   DE,F7FLGS
            ADD  HL,DE
            LD   D,(HL)
            CALL TargetRequireCurrentBank
.if CompilerDiagnosticReturns
            RET  C
.endif
Stage7StringLiteralBankReady:
.endif
.if TargetStreamingOutput
            LD   H,A                     ; successful bank match leaves A=0
            LD   L,A
.else
            LD   HL,0
.endif
            LD   (ACOBJOFF),HL
            CALL AggregateZeroCurrentObject
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(S7ARGCNT)
            LD   B,A
            CALL AggregateDecodeString
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL Stage7CommitStringLiteralObject
.if CompilerDiagnosticReturns
            RET  C
.endif
            PUSH HL
            LD   A,SMLDROAL
            CALL SemanticSinkOperation
            POP  HL
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL Stage7EmitWord
.if CompilerDiagnosticReturns
            RET  C
.endif
            XOR  A
            JP   Stage7PrepareOpenStringReady
Stage7CallAggregateArgument:
            CALL Stage7ParseAggregateValue
.if CompilerDiagnosticBranches
            JP   C,Stage7CallFailure
.endif
            PUSH AF
            CALL Stage7CurrentCallFrame
            INC  HL
            INC  HL
            LD   A,(HL)
            CALL Stage7ParameterAddress
            INC  HL
            INC  HL
            INC  HL
            LD   D,(HL)
            POP  AF
            LD   (S7PATHT),A
            LD   A,D
            LD   (S7CALRES),A
            CP   AGOSTR
            JR   Z,Stage7CallOpenStringType
            CP   AGOAMSK
            JR   NC,Stage7CallOpenArrayType
            LD   A,(S7PATHT)
            CP   D
            JP   NZ,Stage7CallTypeFailure
            JR   Stage7CallAggregateTypeReady
Stage7CallOpenStringType:
            CALL Stage7PathCompareOpenString
            JR   Z,Stage7CallAggregateTypeReady
            CALL Stage7StringCapacity
.if CompilerDiagnosticBranches
            JP   C,Stage7CallFailure
.endif
            JR   Stage7CallAggregateTypeReady
Stage7CallOpenArrayType:
            AND  AGOAELEM
            LD   B,A                      ; preserve C: direct-root bank flag
            LD   A,(S7PATHT)
            LD   D,A
            LD   A,(S7CALRES)
            CP   D
            JR   Z,Stage7CallAggregateTypeReady
            LD   A,D
            CP   AGOVIEW
            JP   NC,Stage7CallTypeFailure
            CP   AGDYNTYP
            JP   C,Stage7CallTypeFailure
            CALL AggregateTypeAddress
            LD   A,(HL)
            CP   ATKARRAY
            JP   NZ,Stage7CallTypeFailure
            INC  HL
            LD   A,(HL)
            CP   B
            JP   NZ,Stage7CallTypeFailure
Stage7CallAggregateTypeReady:
.if TargetStreamingOutput
            ; A cross-bank aggregate parameter must originate at a direct
            ; program root. Diagnose through the ordinary call-frame unwind.
            CALL Stage7CurrentCallFrame
            LD   DE,F7FLGS
            ADD  HL,DE
            LD   D,(HL)
            CALL TargetCurrentBankMatches
            JR   Z,Stage7CallAggregateBankReady
            LD   A,C
            OR   A
            JR   NZ,Stage7CallAggregateBankReady
            LD   A,DGTGTCFG
            CALL DGSET
.if CompilerDiagnosticBranches
            JP   Stage7CallFailure
.endif
Stage7CallAggregateBankReady:
.endif
            CALL Stage8RequireNoPendingFailure
.if CompilerDiagnosticBranches
            JP   C,Stage7CallFailure
.endif
            LD   A,(S7CALRES)
            CP   AGOSTR
            JR   Z,Stage7CallPrepareOpenString
            CP   AGOAMSK
            JR   C,Stage7CallArgumentReady
.if CompilerNonlocalDiagnostics
            JP   Stage7PublishOpenArrayArgument
.else
            CALL Stage7PublishOpenArrayArgument
.if CompilerDiagnosticBranches
            JP   C,Stage7CallFailure
.endif
            JR   Stage7CallArgumentReady
.endif
Stage7CallPrepareOpenString:
.if CompilerNonlocalDiagnostics
            JR   Stage7PrepareOpenStringArgument
.else
            CALL Stage7PrepareOpenStringArgument
.if CompilerDiagnosticBranches
            JP   C,Stage7CallFailure
.endif
.endif
Stage7CallArgumentReady:
            CALL Stage7CurrentCallFrame
            INC  HL
            INC  HL
            INC  (HL)
            INC  HL
            DEC  (HL)
            JP   Z,Stage7CallArgumentsDone
            LD   E,TNCOMMA
            CALL PSEXPECT
.if TargetStreamingOutput
.if CompilerDiagnosticBranches
            JP   C,Stage7CallFailure
.endif
.else
.if CompilerDiagnosticBranches
            JP   C,Stage7CallFailure
.endif
.endif
            JP   Stage7CallArgumentLoop

; Append the prepared sealed object to the declaration-ordered read-only
; image and retain its bank-local offset. In banked output the compiler-only
; terminator byte carries the source bank until target publication replaces
; it with the required permanent zero.
.routine out A,HL,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,IX,IY
Stage7CommitStringLiteralObject:
.if TargetStreamingOutput
            CALL Stage7AllocateBankReadOnly
.if CompilerNonlocalDiagnostics
            PUSH BC
.else
            LD   (ACTYPID),A
            LD   (ACOBJOFF),BC
.endif
            LD   HL,AIBAS
            LD   DE,(ACOBJEXT)
            ADD  HL,DE
            DEC  HL
.if CompilerNonlocalDiagnostics
.else
            LD   A,(ACTYPID)
.endif
            LD   (HL),A
.else
            LD   BC,(ROILEN)
            LD   (ACOBJOFF),BC
.endif
            CALL Stage7AppendReadOnlyObject
.if CompilerDiagnosticReturns
            RET  C
.endif
.if TargetStreamingOutput
.if CompilerNonlocalDiagnostics
            POP  HL
.else
            LD   HL,(ACOBJOFF)
.endif
.else
            LD   HL,(ACOBJOFF)
.endif
            RET

.if TargetStreamingOutput
; Reserve the current object's extent in its source bank's read-only stream.
; Return the source bank in A and the object's old bank-local offset in BC.
.routine out A,BC,carry,zero clobbers sign,parity,halfCarry,D,DE,HL,IX,IY
Stage7AllocateBankReadOnly:
            CALL TargetCurrentSourceBank
            PUSH AF
            CALL TargetBankRoLengthAddress
            LD   C,(HL)
            INC  HL
            LD   B,(HL)
            LD   DE,(ACOBJEXT)
            EX   DE,HL
            ADD  HL,BC
            EX   DE,HL
            LD   (HL),D
            DEC  HL
            LD   (HL),E
            POP  AF
            RET
.endif

; Append the prepared object to the shared declaration-ordered read-only
; staging image. Named constants and anonymous literals use the same checked
; capacity and copy path.
.routine out A,BC,carry,zero clobbers sign,parity,halfCarry,D,DE,HL
Stage7AppendReadOnlyObject:
            LD   BC,(ROILEN)
            LD   HL,(ACOBJEXT)
            ADD  HL,BC
.if CompilerNonlocalDiagnostics
            PUSH HL
.endif
            LD   DE,(IMGLEN)
            ADD  HL,DE
.if CompilerNonlocalDiagnostics
            PUSH BC
.endif
            CALL AggregateCheckReadOnlyCapacity
.if CompilerNonlocalDiagnostics
            POP  BC
.endif
.if CompilerDiagnosticReturns
            RET  C
.endif
.if CompilerNonlocalDiagnostics
            POP  HL
.else
            OR   A
            SBC  HL,DE
.endif
            LD   (ROILEN),HL
            LD   HL,IMGBAS
            ADD  HL,DE
            ADD  HL,BC
            EX   DE,HL
            LD   HL,AIBAS
            LD   BC,(ACOBJEXT)
            LDIR
            OR   A
            RET

; Convert one concrete or already-open bounded-string carrier into the two-word
; internal call form: actual capacity below the ordinary address carrier.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
Stage7PrepareOpenStringArgument:
            CALL Stage7PathCompareOpenString
            JR   Z,Stage7PrepareForwardedOpenString
            CALL Stage7StringCapacity
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   (S7ARGCNT),A
            XOR  A
            JR   Stage7PrepareOpenStringReady
Stage7PrepareForwardedOpenString:
            LD   A,(S7OVCOFF)
            LD   (S7ARGCNT),A
            LD   A,1
Stage7PrepareOpenStringReady:
            LD   C,A
            LD   A,SMOPENAR
            CALL ParserEmitOperationC
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(S7ARGCNT)
            CALL SemanticSinkPut
.if CompilerDiagnosticReturns
            RET  C
.endif
Stage7CompleteOpenArgument:
            CALL Stage7CurrentCallFrame
            LD   DE,F7ARGCNT
            ADD  HL,DE
            INC  (HL)
.if CompilerNonlocalDiagnostics
            JP   Stage7CallArgumentReady
.else
            OR   A
            RET
.endif

; Convert a concrete or forwarded open-array carrier into the shared two-word
; call form. The retained array count remains a complete u16 word.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
Stage7PublishOpenArrayArgument:
            CALL Stage7PrepareOpenArrayCarrier
.if CompilerDiagnosticReturns
            RET  C
.endif
            JR   Stage7CompleteOpenArgument

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
Stage7PrepareOpenArrayCarrier:
            LD   A,(S7PATHT)
            CP   AGOAMSK
            JR   NC,Stage7PublishForwardedOpenArray
            CALL AggregateTypeAddress
            INC  HL
            INC  HL
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            EX   DE,HL
            LD   A,2
            JR   Stage7PrepareOpenArrayReady
Stage7PublishForwardedOpenArray:
            LD   A,(S7OVCOFF)
            LD   L,A
            LD   H,0
            LD   A,3
Stage7PrepareOpenArrayReady:
            LD   C,A
            LD   (S7PATHOF),HL
            LD   A,SMOPENAR
            CALL ParserEmitOperationC
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,(S7PATHOF)
            JP   Stage7EmitWord
Stage7CallArgumentsDone:
            CALL ParserExpectRight
.if TargetStreamingOutput
.if CompilerDiagnosticBranches
            JP   C,Stage7CallFailure
.endif
.else
.if CompilerDiagnosticBranches
            JR   C,Stage7CallFailure
.endif
.endif
            CALL Stage7CurrentCallFrame
            LD   A,(HL)
            LD   (S7CALLBL),A
            INC  HL
            LD   A,(HL)
            LD   (S7CALRES),A
            INC  HL
            INC  HL
            INC  HL
            LD   A,(HL)
            LD   (S7ARGCNT),A
            INC  HL
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            LD   (S7CALOFF),DE
            INC  HL
            LD   A,(HL)
            LD   (S8CALFLG),A
            LD   HL,S7CALDEP
            DEC  (HL)
.if TargetStreamingOutput
            LD   A,(S7CALRES)
            CP   AGDYNTYP
            JR   C,Stage7CallResultBankReady
            LD   A,(S8CALFLG)
            LD   D,A
            CALL TargetRequireCurrentBank
.if CompilerDiagnosticReturns
            RET  C
.endif
Stage7CallResultBankReady:
.endif
            LD   A,(S8CALFLG)
            AND  R7FAILS
            JR   Z,Stage7CallFailureClassReady
            LD   A,(S7CALDEP)
            OR   A
            JP   NZ,HybridLL1FailureContext
Stage7CallFailureClassReady:
; Publish one completed call description. Stage7CallLabel contains the packed
; target, kind, and keep-result choice. Target-specific signature fields are
; present only for source routines.
Stage7PublishCallable:
            LD   A,(S7CALLBL)
            LD   C,A
            LD   A,SMCALLG
            CALL ParserEmitOperationC
.if CompilerDiagnosticReturns
            RET  C
.endif
            AND  C8SVCFLG
            JR   NZ,Stage7PublishCallableCommon
            LD   A,(S7ARGCNT)
            CALL SemanticSinkPut
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(S7CALRES)
            CALL SemanticSinkPut
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(S8CALFLG)
            CALL SemanticSinkPut
.if CompilerDiagnosticReturns
            RET  C
.endif
Stage7PublishCallableCommon:
            LD   HL,(S7CALOFF)
            CALL Stage7EmitWord
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL Stage8EmitFailurePlaceholders
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(S8CALFLG)
            AND  R7FAILS
            LD   (S8DIRFBL),A
            LD   A,(S7CALRES)
            OR   A
            RET
Stage7CallTypeFailure:
            LD   HL,S7CALDEP
            DEC  (HL)
            JP   TypedTypeFailure
.if CompilerDiagnosticBranches
Stage7CallFailure:
            LD   HL,S7CALDEP
            DEC  (HL)
            SCF
            RET
.endif

; Parse a name-rooted aggregate path or aggregate-returning call. The result
; must still be an address path; scalar selection is rejected by this entry.
.if TargetStreamingOutput
.routine out A,C,carry,zero clobbers sign,parity,halfCarry,B,D,DE,HL,IX,IY
.else
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
.endif
Stage7ParseAggregateValue:
            LD   E,TNNAME
            CALL PSEXPECT
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL Stage7FindRoutineCurrent
            JR   NZ,Stage7AggregateValueSymbol
            LD   C,1
            CALL Stage7ParseCall
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   AGDYNTYP
            JP   C,TypedTypeFailure
.if TargetStreamingOutput
            LD   C,0
.endif
            JR   Stage7AggregateValueSuffix
Stage7AggregateValueSymbol:
            CALL Stage7LookupAggregateCurrent
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,D
            AND  SYAGGFLG
            JP   Z,TypedTypeFailure
.if TargetStreamingOutput
            LD   A,D
            AND  SCMSK
            LD   C,0
            CP   SCPROG
            JR   NZ,Stage7AggregateValueRootReady
            INC  C
Stage7AggregateValueRootReady:
            PUSH BC
            CALL Stage7EmitAggregateSymbolRoot
.if CompilerDiagnosticBranches
            JR   C,Stage7AggregateValueRootFailure
.endif
            POP  BC
            LD   A,(S7PATHT)
            JR   Stage7AggregateValueSuffix
.if CompilerDiagnosticBranches
Stage7AggregateValueRootFailure:
            POP  BC
            SCF
            RET
.endif
.else
            CALL Stage7EmitAggregateSymbolRoot
.if CompilerDiagnosticReturns
            RET  C
.endif
.endif
Stage7AggregateValueSuffix:
.if TargetStreamingOutput
            PUSH BC
            CALL Stage7ParsePathSuffix
.if CompilerDiagnosticBranches
            JR   C,Stage7AggregateValueSuffixFailure
.endif
            POP  BC
.else
            CALL Stage7ParsePathSuffix
.if CompilerDiagnosticReturns
            RET  C
.endif
.endif
            LD   E,A
            LD   A,D
            OR   A
            JP   NZ,TypedTypeFailure
            LD   A,E
            CP   AGDYNTYP
            JP   C,TypedTypeFailure
            OR   A
            RET
.if TargetStreamingOutput
.if CompilerDiagnosticBranches
Stage7AggregateValueSuffixFailure:
            POP  BC
            SCF
            RET
.endif
.endif

; Convert a scalar address path to an ordinary typed expression carrier.
.routine in A,D out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
Stage7FinishScalarPath:
            CP   AGDYNTYP
            JP   NC,TypedTypeFailure
            LD   (S7PATHT),A
            LD   A,D
            LD   (S7ARGCNT),A
            OR   A
            JR   NZ,Stage7ScalarPathReady
            LD   A,(S7PATHT)
            AND  2
            RRCA
            ADD  A,SMLDIND8
Stage7ScalarPathEmit:
            CALL SemanticSinkOperation
.if CompilerDiagnosticBranches
            JR   C,Stage7ScalarPathFailure
.endif
Stage7ScalarPathReady:
            LD   A,(S7PATHT)
            OR   A
            RET
.if CompilerDiagnosticBranches
Stage7ScalarPathFailure:
            SCF
            RET
.endif

; Hooks entered by the scalar primary parser after it has consumed the NAME.
Stage7TypedPrimaryRoutine:
            LD   C,1
            CALL Stage7ParseCall
.if CompilerDiagnosticReturns
            RET  C
.endif
            OR   A
            JP   Z,TypedTypeFailure
            CP   AGDYNTYP
            JR   NC,Stage7TypedPrimaryRoutineAggregate
            OR   A
            RET
Stage7TypedPrimaryRoutineAggregate:
            CALL Stage7ParsePathSuffix
.if CompilerDiagnosticReturns
            RET  C
.endif
            JR   Stage7FinishScalarPath

.routine in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
Stage8TypedPrimaryService:
            LD   HL,(TNSTOFF)
            LD   (S7CALOFF),HL
            LD   C,1
            JR   Stage8ParseServiceCall

.routine in A,B out A,B,HL,carry,zero clobbers sign,parity,halfCarry,C,D,DE,IX,IY
Stage8TypedPrimaryConstant:
            SUB  P8CONST-1
            LD   L,A
            LD   H,B
            LD   B,MTCONST+TYU8
            JP   TypedPrimaryEmitTypedConstant

; A is the dense service ID, B is the match loop's proven zero, and C says
; whether a successful u8 result is kept.
.routine in A,B,C out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
Stage8ParseServiceCall:
            CP   P8PKTSVC
            JR   Z,Stage8ParsePacketService
            CP   P8PORT
            JP   NC,Stage8ParsePortCall
            LD   E,A
            LD   D,B
            LD   HL,KWSIGTAB
            ADD  HL,DE
            LD   A,(HL)
            DEC  C
            JR   NZ,Stage8ServiceDescriptorReady
            OR   C8KEEP
Stage8ServiceDescriptorReady:
            LD   (V8ID),A
            CALL ParserExpectLeft
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(V8ID)
            RRCA
            RRCA
            RRCA
            AND  $03
            JR   Z,Stage8ServiceExpectRight
            LD   D,A
Stage8ServiceArgument:
            LD   HL,(S7CALOFF)
            PUSH HL
            LD   A,D
            CALL Stage7ParseScalarArgument
            POP  HL
            LD   (S7CALOFF),HL
.if CompilerDiagnosticReturns
            RET  C
.endif
Stage8ServiceExpectRight:
            CALL ParserExpectRight
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(V8ID)
            LD   (S7CALLBL),A
            AND  V8RESU8
            RLCA
            RLCA
            RLCA
Stage8ServiceResultTypeReady:
            LD   (S7CALRES),A
            LD   A,R7FAILS
            LD   (S8CALFLG),A
            JP   Stage7PublishCallable

; Parse the target-defined, infallible packet gateway. The slot is an exact
; u8 constant; the packet is a writable complete u8 array or forwarded u8[]
; carrier. The existing open-array preparation operation publishes address
; and count, while the terminal operation retains only slot and source offset.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
Stage8ParsePacketService:
            CALL ParserExpectLeft
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,TYU8
            CALL TypedExpressionBeginConstant
.if CompilerDiagnosticReturns
            RET  C
.endif
            PUSH HL
            LD   HL,EXVALPOS
            CALL DGRESTTK
            POP  HL
            LD   E,TYU8
            CALL TypedCheckAssignable
.if CompilerDiagnosticReturns
            RET  C
.endif
            AND  MTCONST
            JP   Z,TypedTypeFailure
            LD   A,L
            LD   (V8ID),A
            LD   E,TNCOMMA
            CALL PSEXPECT
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL PSPEEK
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL Stage7LookupAggregateCurrent
.if CompilerDiagnosticReturns
            RET  C
.endif
            BIT  2,D                     ; program or parameter, never constant
            JP   Z,TypedTypeFailure
Stage8PacketRootReady:
            LD   DE,EXVALPOS
            CALL DGCOPYTK
            CALL Stage7ParseAggregateValue
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,EXVALPOS
            CALL DGRESTTK
            LD   (S7PATHT),A
            CP   AGOAMSK
            JR   NC,Stage8PacketOpenArray
            CP   AGDYNTYP
            JP   C,TypedTypeFailure
            CALL AggregateTypeAddress
            LD   A,(HL)
            CP   ATKARRAY
            JP   NZ,TypedTypeFailure
            INC  HL
            LD   A,(HL)
            CP   TYU8
            JP   NZ,TypedTypeFailure
            JR   Stage8PacketTypeReady
Stage8PacketOpenArray:
            CP   AGOAMSK+TYU8
            JP   NZ,TypedTypeFailure
Stage8PacketTypeReady:
            CALL Stage7PrepareOpenArrayCarrier
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectRight
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(V8ID)
            LD   C,A
            LD   A,SMPKTSVC
            CALL ParserEmitOperationC
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,(S7CALOFF)
            CALL Stage7EmitWord
.if CompilerDiagnosticReturns
            RET  C
.endif
            XOR  A
            RET

; Return the declared byte capacity of a bounded-string type ordinal.
.routine in A out A,carry,zero clobbers sign,parity,halfCarry,DE,HL
Stage7StringCapacity:
            CALL AggregateTypeAddress
            LD   A,(HL)
            CP   ATKSTR
            JP   NZ,TypedTypeFailure
            INC  HL
            LD   A,(HL)
            OR   A
            RET

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
Stage8EmitFailurePlaceholders:
            LD   HL,(SKCUR)
            LD   (M8PTR),HL
            LD   C,3
            XOR  A
Stage8FailurePlaceholderLoop:
            CALL SemanticSinkPut
.if CompilerDiagnosticReturns
            RET  C
.endif
            DEC  C
            JR   NZ,Stage8FailurePlaceholderLoop
            RET

Stage7TypedPrimaryAggregateSymbol:
            CALL Stage7EmitAggregateSymbolRoot
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   Stage7TypedPrimaryRoutineAggregate

; Parse one infallible direct Z80 port operation. The source port is the full
; u16 BC address used by IN/OUT (C). The stored selector is zero for a discarded
; read, one for a retained read, and two for a write.
.routine in A,C out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
Stage8ParsePortCall:
            SUB  P8PORT
            ADD  A,A
            OR   C
            LD   (V8ID),A
            CALL ParserExpectLeft
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,TYU16
            CALL Stage7ParseScalarArgument
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(V8ID)
            CP   2
            JR   C,Stage8PortArgumentsDone
            LD   E,TNCOMMA
            CALL PSEXPECT
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,TYU8
            CALL Stage7ParseScalarArgument
.if CompilerDiagnosticReturns
            RET  C
.endif
Stage8PortArgumentsDone:
            CALL ParserExpectRight
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(V8ID)
            LD   C,A
            ADD  A,SMRDPRTD
            CALL SemanticSinkOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,C
            AND  TYU8
            RET

; Current routine name has already been consumed as a complete statement.
.if HybridLL1Full
.else
Stage7ParseCallStatement:
            LD   C,0
            CALL Stage7ParseCall
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectLine
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   TypedParseStatementsContinue

; Return one exact aggregate alias and mark the structured path non-fallthrough.
Stage7ParseAggregateReturn:
            LD   A,(C7RESTYP)
            PUSH AF
            CALL Stage7ParseAggregateValue
.if CompilerDiagnosticBranches
            JR   C,Stage7AggregateReturnFailure
.endif
            LD   D,A
            POP  AF
            CP   D
            JP   NZ,TypedTypeFailure
            CALL ParserExpectLine
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,SMRETAGG
            CALL SemanticSinkOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            XOR  A
            LD   (CTFALLS),A
            JP   TypedParseStatementsContinue
.if CompilerDiagnosticBranches
Stage7AggregateReturnFailure:
            POP  AF
            SCF
            RET
.endif
.endif

; D contains the aggregate symbol info and DeclarationPayload its root offset.
Stage7ParseAggregateAssignment:
            LD   A,D
            AND  SCMSK
            JR   NZ,Stage7AggregateAssignmentWritable
            CALL DGINLINE
            .db  DGROASGN
Stage7AggregateAssignmentWritable:
            CALL Stage7EmitAggregateSymbolRoot
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,1
            LD   (S7PASMOD),A
            LD   A,(S7PATHT)
            CALL Stage7ParsePathSuffix
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   E,A
            XOR  A
            LD   (S7PASMOD),A
            LD   A,D
            CP   2
            JR   Z,Stage7StringResizeAssignment
            OR   A
            JP   NZ,TypedTypeFailure
            LD   A,E
            LD   (S7PATHT),A
            CALL ParserExpectEqual
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,(TNSTOFF)
            LD   (S7CALOFF),HL
            LD   A,(S7PATHT)
            CP   AGDYNTYP
            JR   NC,Stage7AggregateCopyAssignment
            LD   E,A
            CALL TypedExpressionBeginRuntime
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   D,A
            LD   A,(S7PATHT)
            LD   E,A
            LD   A,D
            CALL TypedCheckAssignable
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL Stage8RetainOneAndSelectFailure
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(S7PATHT)
            AND  2
            RRCA
            ADD  A,SMSTIND8
Stage7ScalarAssignmentEmit:
.if Stage7LL1
            JP   SemanticSinkOperation
.else
            CALL SemanticSinkOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   ParserExpectLine
.endif
Stage7AggregateCopyAssignment:
            PUSH AF
            CALL Stage7ParseAggregateValue
.if CompilerDiagnosticBranches
            JR   C,Stage7AggregateCopyFailure
.endif
            LD   D,A
            POP  AF
            CP   AGOVIEW
            JP   NC,TypedTypeFailure
            CP   D
            JP   NZ,TypedTypeFailure
            CALL AggregateGetExtent
            LD   (S7PATHEX),HL
            CALL Stage8RetainOneAndSelectFailure
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,SMCOPYAG
            CALL SemanticSinkOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
.if Stage7LL1
            JP   Stage7EmitExtentAndCallOffset
.else
            CALL Stage7EmitExtentAndCallOffset
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   ParserExpectLine
.endif
Stage7StringResizeAssignment:
            CALL ParserExpectEqual
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,TYU8
            CALL TypedExpressionBeginRuntime
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   D,A
            LD   E,TYU8
            CALL TypedCheckAssignable
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL Stage8RetainOneAndSelectFailure
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(S7SROFF)
            LD   C,A
            LD   A,SMSTRRSZ
            CALL ParserEmitOperationC
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,(EXVALPOS)
.if Stage7LL1
            JP   Stage7EmitWord
.else
            CALL Stage7EmitWord
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   ParserExpectLine
.endif
.if CompilerDiagnosticBranches
Stage7AggregateCopyFailure:
            POP  AF
            SCF
            RET
.endif

.if Stage7LL1
            .include "stage7-ll1-parser.asm"
            .include "stage7-ll1-actions.asm"
.endif
