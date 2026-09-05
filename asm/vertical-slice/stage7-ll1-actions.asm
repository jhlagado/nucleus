; Explicit semantic actions for the complete Stage 7 packed LL(1) grammar.
; These routines never select grammar productions. They consume only retained
; expression/type-directed external islands declared by the generated grammar.

; Aggregate initializer staging is dead while a routine body is parsed, so
; the for/flow action scratch safely reuses its first thirteen bytes.
HybridLL1ForMode       .equ AIBAS
HybridLL1ForStep       .equ HybridLL1ForMode+1
HybridLL1FlowStackBase .equ HybridLL1ForStep+2
HybridLL1ActionStateEnd .equ HybridLL1FlowStackBase+CFCAP

.routine out A,B,DE,carry,zero clobbers sign,parity,halfCarry,C,HL
LASTEPC:
            CALL StructuredParseStep
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(HybridLL1ForMode)
            OR   B
            LD   (HybridLL1ForMode),A
            LD   (HybridLL1ForStep),DE
            OR   A
            RET

; The declared type has already selected the initializer shape. This external
; island retains the recursive, type-directed aggregate initializer machinery.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
LASTATIC:
            LD   A,(DCINFO)
            LD   B,A
            PUSH BC
            CALL AggregateParseInitializer
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,B
            LD   (DCINFO),A
            OR   A
            RET

LACLAUSE:
            CALL DGINLINE
            .db  DXEND

LASELERR .equ LACLAUSE

; --------------------------------------------------------------- type actions

; A is the logical action ordinal for the contiguous u8/u16/Boolean family.
LASCALAR:
            SUB  LATYU8-1
            CP   3
            JR   C,HybridLL1SetCurrentType
            ADD  A,13
HybridLL1SetCurrentType:
            LD   (ACTYPID),A
            OR   A
            RET

.routine out A,BC,carry,zero clobbers sign,parity,halfCarry,D,DE,HL,IX,IY
LARECTYP:
            CALL SymbolLookupCurrent
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   D,A
            LD   (DCINFO),A
            LD   (DCPAY),BC
            AND  SYRECTYP+SYAGGFLG
            CP   SYRECTYP
            JP   NZ,AggregateTypeShapeFailure
            LD   A,C
            JR   HybridLL1SetCurrentType

LATYBND:
HybridLL1ExpectU16:
            LD   A,TYU16
            JR   HybridLL1SaveExpectedType

; Return the checked, positive, byte-sized constant bound in HL.
.routine out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B,C,IX,IY
HybridLL1CheckedBound:
            LD   A,(EXRMETA)
            LD   D,A
            AND  MTCONST
            JP   Z,AggregateTypeShapeFailure
            LD   E,TYU16
            LD   A,D
            CALL TypedCheckAssignable
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,(EXRVAL)
            LD   A,H
            OR   L
            JP   Z,AggregateTypeShapeFailure
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
LASTRTYP:
            CALL HybridLL1CheckedBound
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,H
            OR   A
            JP   NZ,AggregateStringCapacityFailure
            LD   A,L
            CP   254
            JP   NC,AggregateStringCapacityFailure
            LD   A,L
            LD   (ANAUX),A
            LD   (ANLEN),HL
            LD   A,ATKSTR
            LD   (ANKIND),A
            INC  HL
            INC  HL
            LD   (ANEXT),HL
HybridLL1InternCurrentType:
            CALL AggregateInternType
.if CompilerDiagnosticReturns
            RET  C
.endif
            JR   HybridLL1SetCurrentType

; `string[]` is a parameter-only view rather than an interned object type.
LAOSTRTY:
            LD   A,AGOSTR
            JR   HybridLL1SetCurrentType

LAARRTYP .equ AggregateBeginArrayType

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
LAARRDIM:
            CALL HybridLL1CheckedBound
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   AggregateSaveArrayDimension

LAOARDIM .equ AggregateSaveOpenArrayDimension

LAARRFIN .equ AggregateFinishArrayType

; --------------------------------------------------------- scalar constants

LARETNAM .equ TypedRetainDeclarationName

HybridLL1SaveExpectedType:
            LD   (EXEXPTYP),A
            OR   A
            RET

.routine out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B,C,IX,IY
LACONEND:
            LD   HL,(EXRVAL)
            LD   A,(EXRMETA)
            LD   D,A
            AND  MTCONST
            JP   Z,TypedTypeFailure
            LD   A,D
            CALL TypedInferredConstantType
HybridLL1ConstantTypeReady:
            LD   (DCINFO),A
            LD   HL,(EXRVAL)
            LD   (DCPAY),HL
            OR   A
            RET

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
LACONSET:
            LD   A,(DCINFO)
            OR   SCCONST
            LD   D,A
            LD   BC,(DCPAY)
            CALL TypedPrepareCurrentWord
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   SymbolCommit

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LAAGCSET:
.if TargetStreamingOutput
            CALL Stage7AllocateBankReadOnly
            LD   (DCINFO),A
            LD   (DCPAY),BC
            LD   A,(DCINFO)
            RLCA
            RLCA
            RLCA
            RLCA
            OR   SYAGGFLG+SCCONST
            LD   (DCINFO),A
.endif
            LD   BC,(ROILEN)
            LD   D,SYAGGFLG+SCCONST
.if TargetStreamingOutput
            LD   A,(DCINFO)
            LD   D,A
            LD   BC,(DCPAY)
.endif
            CALL TypedPrepareCurrentWord
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(ACTYPID)
            INC  HL
            LD   (HL),A
            CALL Stage7AppendReadOnlyObject
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   SymbolCommit

LAASSERT .equ TypedRetainDeclarationNameReady

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
LAASRTEN:
            CALL HybridLL1RestoreSubName
            LD   A,(EXRMETA)
            AND  MTCONST+MTTYPMSK
            CP   MTCONST+TYBOOL
            JR   NZ,HybridLL1AssertTypeFailure
            LD   A,(EXRVAL)
            OR   A
            RET  NZ
            CALL DGINLINE
            .db  DGASSERT
HybridLL1AssertTypeFailure:
            CALL DGINLINE
            .db  DGTYPMIS

; ------------------------------------------------------ program declarations

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
LAPROGTY:
HybridLL1SaveObjectType:
            CALL AggregateRejectOpenViewPlacement
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   (DCINFO),A
            CALL AggregateGetExtent
            LD   (ACOBJEXT),HL
            LD   (ACOBJEND),HL
            LD   HL,0
            LD   (ACOBJOFF),HL
            CALL AggregateZeroCurrentObject
.if CompilerDiagnosticReturns
            RET  C
.endif
            XOR  A
            LD   (AIDEP),A
            LD   (AGHASINI),A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
LAAGCTYP:
            LD   A,(ACTYPID)
            CP   AGDYNTYP
            JP   C,TypedTypeFailure
            JR   HybridLL1SaveObjectType

LAPINIEN:
            LD   A,1
            LD   (AGHASINI),A
            LD   HL,(ACOBJOFF)
            LD   DE,(ACOBJEND)
            OR   A
            SBC  HL,DE
            JP   NZ,AggregateInitializerCountFailure
            OR   A
            RET

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LAPRGVAR:
            LD   A,(AGHASINI)
            OR   A
            JR   NZ,HybridLL1AllocateDataObject
            JR   HybridLL1AllocateBssObject
HybridLL1CommitObjectReady:
            PUSH BC
            LD   A,(DCINFO)
            CP   AGDYNTYP
            JR   C,HybridLL1ProgramScalarInfo
            LD   D,SIAGPROG
            JR   HybridLL1ProgramPrepareSymbol
HybridLL1ProgramScalarInfo:
            OR   SCPROG
            LD   D,A
HybridLL1ProgramPrepareSymbol:
            CALL TypedPrepareCurrentWord
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(DCINFO)
            CALL SymbolCommitTyped
.if CompilerDiagnosticReturns
            RET  C
.endif
            OR   A
            RET

; Return the absolute target address of one initialized program object in BC.
; The complete prepared bytes are appended to the rodata-backed data image.
HybridLL1AllocateDataObject:
            LD   DE,(IMGLEN)
            CALL HybridLL1AllocateObjectEnd
.if CompilerDiagnosticReturns
            RET  C
.endif
            PUSH HL
            LD   DE,(ROILEN)
            ADD  HL,DE
            CALL AggregateCheckExtentCapacity
            POP  HL
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   (IMGLEN),HL
            LD   BC,(ROILEN)
            LD   A,B
            OR   C
            JR   Z,HybridLL1DataShiftReady
            LD   HL,IMGBAS
            LD   DE,(ACOBJOFF)
            ADD  HL,DE
            ADD  HL,BC
            DEC  HL
            LD   DE,(ACOBJEXT)
            PUSH HL
            ADD  HL,DE
            EX   DE,HL
            POP  HL
            LDDR
HybridLL1DataShiftReady:
            LD   BC,(ACOBJEXT)
            LD   HL,AIBAS
            LD   DE,(ACOBJOFF)
            PUSH HL
            LD   HL,IMGBAS
            ADD  HL,DE
            EX   DE,HL
            POP  HL
            LDIR
            LD   BC,(ACOBJOFF)
.if TargetStreamingOutput
            ; Target transcripts retain a segment-relative offset. Bit 15 is
            ; clear for initialized data and set for BSS.
.else
            LD   HL,MMDATA
            ADD  HL,BC
            LD   B,H
            LD   C,L
.endif
            OR   A
            JR   HybridLL1CommitObjectReady

; Return the absolute target address of one default-initialized object in BC.
HybridLL1AllocateBssObject:
            LD   DE,(PGBSSLEN)
            CALL HybridLL1AllocateObjectEnd
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   (PGBSSLEN),HL
            LD   B,D
            LD   C,E
.if TargetStreamingOutput
            SET  7,B
.else
            LD   HL,MMBSS
            ADD  HL,BC
            LD   B,H
            LD   C,L
.endif
            OR   A
.if TargetStreamingOutput
            JR   HybridLL1CommitObjectReady
.else
            JP   HybridLL1CommitObjectReady
.endif

; Add the current object extent to the selected segment length in DE. Return
; the old offset in DE and the checked mathematical end in HL.
.routine in DE out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B
HybridLL1AllocateObjectEnd:
            LD   (ACOBJOFF),DE
            LD   HL,(ACOBJEXT)
            LD   DE,(ACOBJOFF)
            ADD  HL,DE
HybridLL1CheckProgramSegmentEnd:
; Initialized data and BSS use the same exact 1 KiB extent rule and diagnostic
; as complete aggregate objects.
            JP   AggregateCheckExtentCapacity

; ---------------------------------------------------------- record metadata

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
LARECORD:
            CALL TypedRetainDeclarationName
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(ATCNT)
            CP   ATCAP
            JP   NC,AggregateTypeCapacityFailure
            LD   A,(ARCNT)
            CP   ARCAP
            JP   NC,AggregateTypeCapacityFailure
            LD   A,(AFCNT)
            LD   (ACFLDST),A
            XOR  A
            LD   (ACFLDCNT),A
            LD   H,A
            LD   L,A
            LD   (ACRECEXT),HL
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
LAFIELD:
            CALL AggregateCheckFieldDuplicate
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(AFCNT)
            CP   AFCAP
            JP   NC,AggregateTypeCapacityFailure
            PUSH AF
            CALL AggregateFieldAddress
            CALL TKRETAIN
            POP  AF
            OR   A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
LAFLDEND:
            CALL AggregateRejectOpenViewCurrent
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(AFCNT)
            CALL AggregateFieldAddress
            INC  HL
            INC  HL
            INC  HL
            LD   A,(ACTYPID)
            LD   (HL),A
            INC  HL
            LD   DE,(ACRECEXT)
            LD   (HL),E
            INC  HL
            LD   (HL),D
            LD   A,(ACTYPID)
            PUSH DE
            CALL AggregateGetExtent
            POP  DE
            ADD  HL,DE
            JP   C,AggregateProgramDataCapacityFailure
            CALL AggregateCheckExtentCapacity
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   (ACRECEXT),HL
            LD   HL,ACFLDCNT
            INC  (HL)
            LD   HL,AFCNT
            INC  (HL)
            XOR  A
            RET

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
LARECEND:
            LD   A,(ACFLDCNT)
            OR   A
            JP   Z,AggregateRecordEmptyFailure
            LD   A,ATKREC
            LD   (ANKIND),A
            LD   HL,(ACFLDST)
            LD   (ANAUX),HL
            XOR  A
            LD   (ANLEN+1),A
            LD   HL,(ACRECEXT)
            LD   (ANEXT),HL
            CALL AggregateAppendType
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   (ACTYPID),A
            LD   D,SIRECTYP
            LD   A,(ACTYPID)
            LD   C,A
            LD   B,0
            CALL TypedPrepareCurrentWord
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL SymbolCommit
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,ARCNT
            INC  (HL)
            XOR  A
            RET

; ----------------------------------------------------- Stage 7 routines/main

.routine out A,carry,zero clobbers sign,parity,halfCarry,DE,HL
LABEFMN:
            LD   A,DXEOF

; A selects the exact diagnostic if the current signature is main. Ordinary
; routines return normally; compiler diagnostics retain the caller's token.
.routine in A out A,carry,zero clobbers sign,parity,halfCarry,D,DE,HL
HybridLL1RequireNonMain:
            LD   D,A
            LD   A,(C7RTN)
            INC  A
            RET  NZ
            LD   A,D
            JP   DGSET

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL,IX,IY
LAREQMN:
            LD   A,(C7RTN)
            INC  A
            JR   Z,HybridLL1RequireOrdinaryForwards
            LD   A,(S8FMFLG)
            AND  S8RTNINC
            JR   NZ,HybridLL1IncompleteForward
            JR   HybridLL1MissingMain
HybridLL1RequireOrdinaryForwards:
            LD   A,(R7CNT)
            LD   B,A
            XOR  A
            LD   C,A
HybridLL1RequireForwardLoop:
            LD   A,B
            OR   A
            RET  Z
            LD   A,C
            CALL Stage7RoutineAddress
            LD   DE,R7FLGS
            ADD  HL,DE
            LD   A,(HL)
            AND  S8RTNINC
            JR   NZ,HybridLL1IncompleteForward
            INC  C
            DEC  B
            JR   HybridLL1RequireForwardLoop
HybridLL1MissingMain:
            CALL DGINLINE
            .db  DXTOPLVL
HybridLL1IncompleteForward:
            CALL DGINLINE
            .db  DGFWDINC

; The grammar deliberately treats the lexeme `main` as the same NAME token as
; ordinary routine names. This action is the one semantic discriminator.
LASUBNAM .equ TypedRetainDeclarationNameReady

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
HybridLL1RestoreSubName:
            CALL TypedRestoreDeclarationToken
            LD   HL,DCNAMPOS
            CALL DGRESTTK
            OR   A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry
HybridLL1ResetParametersAndResult:
            XOR  A
            LD   (C7PARCNT),A
            LD   (C7RESTYP),A
            RET

.if CompilerDiagnosticReturns
.else
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
HybridLL1ClassifySubName:
            CALL HybridLL1RestoreSubName
            CALL LABEFMN
            JP   TypedNameEqualsMain
.endif

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
LASUB:
.if CompilerDiagnosticReturns
            CALL HybridLL1RestoreSubName
            CALL LABEFMN
            RET  C
            CALL TypedNameEqualsMain
.else
            CALL HybridLL1ClassifySubName
.endif
            JR   C,HybridLL1BeginMainSignature
            LD   A,(R7CNT)
            CP   R7CAP
            JR   NC,HybridLL1RoutineCapacityFailure
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
            CALL HybridLL1ResetParametersAndResult
.if TargetStreamingOutput
            CALL TargetPackCurrentBank
.endif
            LD   (C7FLGS),A
            RET
HybridLL1BeginMainSignature:
.if TargetStreamingOutput
            CALL TargetRequireEntrySourceBank
.if CompilerDiagnosticReturns
            RET  C
.endif
.endif
            LD   A,(S8FMFLG)
            AND  S8RTNINC
            JP   NZ,TypedDuplicateNameFailure
            CALL Stage7RejectCurrentDeclarationName
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,$FF
            LD   (C7RTN),A
            CALL HybridLL1ResetParametersAndResult
            LD   A,R7MAIN
.if TargetStreamingOutput
            CALL TargetPackCurrentBank
.endif
            LD   (C7FLGS),A
            RET
HybridLL1RoutineCapacityFailure:
            CALL DGINLINE
            .db  DGRTNCAP

; A forward uses the ordinary signature builder, then publishes that sole
; signature without opening a body or emitting code.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
LAFORWRD:
            CALL LASUB
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   B,S8RTNINC
            JR   HybridLL1SetRoutineFlag

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
LAFWDEND:
            LD   A,(C7RTN)
            INC  A
            JR   Z,HybridLL1CommitForwardMain
            DEC  A
            CALL HybridLL1PublishRoutine
            XOR  A
            RET
HybridLL1CommitForwardMain:
            LD   A,(C7FLGS)
            LD   (S8FMFLG),A
            XOR  A
            LD   (C7RTN),A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
LAPARNAM:
            LD   A,DXRPAR
            CALL HybridLL1RequireNonMain
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL Stage7CheckParameterDeclarationName
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,DCNAMPTR
            CALL TKRETAIN
.if TargetStreamingOutput
.if DebugHooks
            OUT  (DTDECL),A
.endif
.endif
            OR   A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
LAPARSET:
            CALL TypedRestoreDeclarationToken
            LD   A,(ACTYPID)
            JP   Stage7AppendParameter

LARESOK:
            LD   A,DXLINE
            JP   HybridLL1RequireNonMain

LARESTYP:
            CALL AggregateRejectOpenViewPlacement
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   (C7RESTYP),A
            OR   A
            RET

LASUBFL:
            LD   B,R7FAILS
HybridLL1SetRoutineFlag:
            LD   A,(C7FLGS)
            OR   B
            LD   (C7FLGS),A
            OR   A
            RET

; Open the abbreviated body of one exact incomplete forward and recover its
; sole stored signature, including the original parameter spellings.
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LAFWDBDY:
.if CompilerDiagnosticReturns
            CALL HybridLL1RestoreSubName
            CALL LABEFMN
            RET  C
            CALL TypedNameEqualsMain
.else
            CALL HybridLL1ClassifySubName
.endif
            JR   C,HybridLL1BeginForwardMainBody
            CALL Stage7FindRoutineCurrent
            JR   NZ,HybridLL1ForwardMissing
            LD   (C7RTN),A
            CALL Stage7RoutineAddress
            LD   DE,R7PARST
            ADD  HL,DE
            LD   DE,C7PARST
            LD   BC,4
            LDIR
            LD   A,(HL)
            BIT  2,A
            JP   Z,TypedDuplicateNameFailure
.if TargetStreamingOutput
            LD   D,A
            PUSH AF
            PUSH HL
            CALL TargetRequireCurrentBank
.if CompilerDiagnosticBranches
            JR   C,HybridLL1ForwardBankFailure
.endif
            POP  HL
            POP  AF
.endif
            AND  $FB
            LD   (HL),A
            LD   (C7FLGS),A
            JR   HybridLL1OpenRoutineBody
.if TargetStreamingOutput
.if CompilerDiagnosticBranches
HybridLL1ForwardBankFailure:
            POP  HL
            POP  AF
            SCF
            RET
.endif
.endif
HybridLL1BeginForwardMainBody:
.if TargetStreamingOutput
            CALL TargetRequireEntrySourceBank
.if CompilerDiagnosticReturns
            RET  C
.endif
.endif
            LD   A,(S8FMFLG)
            BIT  2,A
            JR   Z,HybridLL1ForwardMissing
            AND  $FB
            LD   (C7FLGS),A
            LD   (S8FMFLG),A
            CALL HybridLL1ResetParametersAndResult
            DEC  A
            LD   (C7RTN),A
.if CompilerNonlocalDiagnostics
            JR   HybridLL1BeginMainBody
.else
            JP   HybridLL1BeginMainBody
.endif
HybridLL1ForwardMissing:
            CALL DGINLINE
            .db  DGUNKNAM

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LASUBODY:
            LD   A,(C7RTN)
            INC  A
.if CompilerNonlocalDiagnostics
            JR   Z,HybridLL1BeginMainBody
.else
            JP   Z,HybridLL1BeginMainBody
.endif
            DEC  A
            CALL HybridLL1PublishRoutine
            JR   HybridLL1OpenRoutineBody

.routine in A out A,BC,DE,HL clobbers carry,zero,sign,parity,halfCarry
HybridLL1PublishRoutine:
            CALL Stage7RoutineAddress
            LD   DE,R7PARCNT
            ADD  HL,DE
            EX   DE,HL
            LD   A,(C7RTN)
            ADD  A,R7LBLBAS
            LD   (S7CALLBL),A
            LD   HL,C7PARCNT
            LD   BC,4
            LDIR
            LD   HL,R7CNT
            INC  (HL)
            RET
.if TargetStreamingOutput
.routine in A out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
HybridLL1PutThenCurrentBank:
            CALL SemanticSinkPut
            LD   A,(C7FLGS)
            CALL TargetUnpackBank
            JP   SemanticSinkPut
.endif

.routine out A,carry,zero clobbers sign,parity,halfCarry
HybridLL1SaveGlobalsResetLocals:
            LD   A,(SYCNT)
            LD   (S7GLBCNT),A
            XOR  A
            LD   (NXLOCAL),A
            LD   (CTDEP),A
            RET
HybridLL1OpenRoutineBody:
            CALL HybridLL1SaveGlobalsResetLocals
.if TargetStreamingOutput
.else
            LD   A,(C7RESTYP)
            OR   A
            LD   A,CRVAL
            JR   NZ,HybridLL1RoutineKindReady
            XOR  A
HybridLL1RoutineKindReady:
            LD   (CRKIND),A
            LD   A,(C7RESTYP)
            LD   (CTRESTYP),A
.endif
            LD   A,1
            LD   (CTFALLS),A
.if TargetStreamingOutput
.if DebugHooks
            OUT  (DTROUT),A
.endif
.endif
            LD   A,(S7CALLBL)
            LD   C,A
            LD   A,SMBGGRTN
            CALL ParserEmitOperationC
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(C7PARCNT)
.if TargetStreamingOutput
            CALL HybridLL1PutThenCurrentBank
.if CompilerDiagnosticReturns
            RET  C
.endif
.else
            CALL SemanticSinkPut
.if CompilerDiagnosticReturns
            RET  C
.endif
.endif
            LD   A,(C7PARCNT)
            LD   B,A
            LD   A,(C7PARST)
            LD   D,A
            XOR  A
            LD   E,A
HybridLL1InstallParameterLoop:
            LD   A,B
            OR   A
            RET  Z
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
            JR   HybridLL1InstallParameterLoop

HybridLL1BeginMainBody:
            LD   A,(C7FLGS)
            LD   (S8FMFLG),A
.if TargetStreamingOutput
.if DebugHooks
            OUT  (DTROUT),A
.endif
.endif
            LD   A,SMBGCMN
            CALL SemanticSinkOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(C7FLGS)
.if TargetStreamingOutput
            CALL HybridLL1PutThenCurrentBank
.if CompilerDiagnosticReturns
            RET  C
.endif
.else
            CALL SemanticSinkPut
.if CompilerDiagnosticReturns
            RET  C
.endif
.endif
            CALL HybridLL1SaveGlobalsResetLocals
.if TargetStreamingOutput
.else
            LD   (C7RESTYP),A
            LD   (CRKIND),A
.endif

.routine out A,carry,zero clobbers sign,parity,halfCarry
HybridLL1SetFallsThrough:
            LD   A,1
            JR   HybridLL1StoreFallthrough

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LASUBEND:
            LD   A,(C7RTN)
            INC  A
            JR   Z,HybridLL1EndMainBody
            LD   A,(C7RESTYP)
            OR   A
            JR   Z,HybridLL1EndRoutineEmit
            LD   A,(CTFALLS)
            OR   A
            JP   NZ,TypedRoutineFlowFailure
HybridLL1EndRoutineEmit:
.if TargetStreamingOutput
.if DebugHooks
            OUT  (DTPOP),A
.endif
.endif
            CALL HybridLL1EmitRoutineEnd
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
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
HybridLL1EmitRoutineEnd:
            CALL HybridLL1TestRoutineFails
            LD   A,SMENGRTN
            JR   Z,HybridLL1EmitRoutineEndSelected
            LD   A,SMENFRTN
HybridLL1EmitRoutineEndSelected:
            JP   SemanticSinkOperation

.routine out A,carry,zero clobbers sign,parity,halfCarry
HybridLL1TestRoutineFails:
            LD   A,(C7FLGS)
            AND  R7FAILS
            RET
HybridLL1EndMainBody:
.if TargetStreamingOutput
.if DebugHooks
            OUT  (DTPOP),A
.endif
.endif
            CALL HybridLL1EmitRoutineEnd
.if CompilerDiagnosticReturns
            RET  C
.endif
            XOR  A
            JP   SemanticSinkPut

; ------------------------------------------------------ recoverable failure

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
LAFAIL:
.if TargetStreamingOutput
.if DebugHooks
            OUT  (DTSOURCE),A
.endif
.endif
            CALL HybridLL1TestRoutineFails
            JR   Z,HybridLL1FailureContext
            LD   HL,(TNSTOFF)
            LD   (S8FAIOFF),HL
            LD   A,TYU8
            JP   HybridLL1SaveExpectedType

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LAFAILEN:
            LD   E,TYU8
            CALL HybridLL1CheckFailureResult
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,SMFAILRT
HybridLL1FailOperationReady:
            CALL SemanticSinkOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,(S8FAIOFF)
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
HybridLL1NoFallthrough:
            XOR  A
.routine in A out A,carry,zero clobbers sign,parity,halfCarry
HybridLL1StoreFallthrough:
            LD   (CTFALLS),A
            OR   A
            RET

; Validate one scalar fail/return value and reject an unconsumed nested
; recoverable failure.
.routine in E out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B,C,IX,IY
HybridLL1CheckFailureResult:
            LD   A,(EXRMETA)
            LD   HL,(EXRVAL)
            CALL TypedCheckAssignable
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   Stage8RequireNoPendingFailure
.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
HybridLL1FailureContext:
            CALL DGINLINE
            .db  DGFAICTX

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
; Both callers have already observed a nonzero Stage8DirectFailable. The
; generic entry checks the token; the selected entry reuses its caller's peek.
Stage8ConsumePropagation:
            CALL PSPEEK
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TNELSE
            JR   NZ,HybridLL1FailureContext
Stage8ConsumePropagationSelected:
            CALL HybridLL1TestRoutineFails
            JR   Z,HybridLL1FailureContext
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   E,TNFAIL
            CALL PSEXPECT
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL PSPEEK
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TNHDL
            JR   Z,HybridLL1FailureContext
            CP   TNELSE
            JR   Z,HybridLL1FailureContext
            LD   A,M8PROP
Stage8PropagationModeReady:
            LD   HL,(M8PTR)
            LD   (HL),A
            INC  HL
            INC  HL
            LD   A,(S8CARR)
            LD   (HL),A
Stage8ClearPendingFailure:
            XOR  A
            LD   (S8DIRFBL),A
            LD   (S8CARR),A
            RET

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
Stage8SelectFailureConsumer:
            LD   A,(S8DIRFBL)
            OR   A
            JR   NZ,Stage8SelectPendingFailure
            LD   (S8CARR),A
            CALL PSPEEK
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TNELSE
            JR   Z,HybridLL1FailureContext
            CP   TNHDL
            JP   Z,LLHANDLE
            OR   A
            RET

; Address the selected field of the active control frame and load its byte.
; Callers have already established the frame precondition.
.routine in B out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
HybridLL1TopFrameFieldToC:
            CALL ControlTopFrameField
            LD   C,(HL)
            LD   A,C
            RET

Stage8SelectPendingFailure:
            CALL PSPEEK
.if CompilerDiagnosticReturns
            RET  C
.endif
            DEC  A                       ; newline becomes zero
            JP   Z,LLHANDLE
            CP   TNELSE-1
            JR   Z,Stage8ConsumePropagationSelected
            CP   TNHDL-1
            JR   NZ,HybridLL1FailureContext
            LD   B,CKHDL
            CALL HybridLL1PushFlowFrameAndLabelA
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ControlAllocateExit
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,(M8PTR)
            LD   (HL),M8HDL
            LD   B,CFLBLA
            CALL HybridLL1TopFrameFieldToC
            LD   HL,(M8PTR)
            INC  HL
            LD   (HL),C
            INC  HL
            LD   A,(S8CARR)
            LD   (HL),A
            JR   Stage8ClearPendingFailure

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
Stage8RetainOneAndSelectFailure:
            LD   A,1
            LD   (S8CARR),A
            JR   Stage8SelectFailureConsumer

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
HybridLL1LookupDeclaration:
            CALL SymbolLookupCurrent
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   (DCINFO),A
            LD   (DCPAY),BC
            LD   D,A
            RET

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LAHANDLE:
.if TargetStreamingOutput
.if DebugHooks
            OUT  (DTSOURCE),A
            OUT  (DTPUSH),A
.endif
.endif
            CALL HybridLL1LookupDeclaration
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL TypedRequireScalarSymbolClass
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   Z,TypedTypeFailure
            CP   SCLOC
            JR   NZ,Stage8HandlerCounterReady
            CALL ControlCheckActiveCounter
.if CompilerDiagnosticReturns
            RET  C
.endif
Stage8HandlerCounterReady:
            CALL TypedDeclarationScalarType
            CP   TYU8
            JP   NZ,TypedTypeFailure
            LD   B,CFEXIT
            CALL HybridLL1TopFrameFieldToC
            LD   D,SMSKIPHD
            CALL ControlEmitOperationByte
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   B,CFLBLA
            CALL HybridLL1TopFrameFieldToC
            LD   D,SMBEGHDL
            CALL ControlEmitOperationByte
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(DCINFO)
            CALL SemanticSinkPut
.if CompilerDiagnosticReturns
            RET  C
.endif
            AND  SCMSK
            CP   SCPROG
            LD   HL,(DCPAY)
            JR   Z,HybridLL1BeginHandleProgramPayload
            LD   A,L
            CALL SemanticSinkPut
            JR   HybridLL1BeginHandlePayloadReady
HybridLL1BeginHandleProgramPayload:
            CALL Stage7EmitWord
HybridLL1BeginHandlePayloadReady:
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   HybridLL1SetFallsThrough

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LAHDLEND:
.if TargetStreamingOutput
.if DebugHooks
            OUT  (DTPOP),A
.endif
.endif
            LD   B,CFEXIT
            CALL HybridLL1TopFrameFieldToC
            LD   D,SMENDHDL
            CALL ControlEmitOperationByte
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,1
            JP   HybridLL1CombineFlow

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
Stage8RequireNoPendingFailure:
            LD   A,(S8DIRFBL)
            OR   A
            RET  Z
            JP   HybridLL1FailureContext

; ------------------------------------------------------------- local scalars

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
LALOCTYP:
.if TargetStreamingOutput
.if DebugHooks
            OUT  (DTSOURCE),A
.endif
.endif
            LD   A,(ACTYPID)
            OR   SCLOC
            LD   (DCINFO),A
            LD   A,(NXLOCAL)
            LD   C,A
            LD   B,0
            LD   (DCPAY),BC
            PUSH BC
            LD   A,(DCINFO)
            LD   D,A
            CALL TypedPrepareRoutineWord
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL TypedDeclarationScalarType
            CALL TypedEmitLocalDeclare
HybridLL1SetLocalExpectedType:
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL TypedDeclarationScalarType
            JP   HybridLL1SaveExpectedType

LALOCINI:
            CALL TypedDeclarationScalarType
            JP   HybridLL1SaveExpectedType

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
LALOCDEF:
            LD   A,1
            LD   (EXEMITON),A
            LD   A,SMLIT16
            CALL TypedEmitOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,0
.if CompilerNonlocalDiagnostics
            LD   (EXRVAL),HL
.endif
            CALL TypedEmitWord
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL TypedDeclarationScalarType
            OR   MTCONST
            LD   (EXRMETA),A
.if CompilerNonlocalDiagnostics
.else
            LD   HL,0
            LD   (EXRVAL),HL
.endif
            OR   A
            RET

.routine out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B,C,IX,IY
LALOCEND:
            CALL HybridLL1ValidateDeclarationExpression
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(S8DIRFBL)
            OR   A
            JP   NZ,Stage8ConsumePropagation
            CALL PSPEEK
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TNELSE
            JP   Z,HybridLL1FailureContext
            OR   A
            RET

.routine out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B,C,IX,IY
HybridLL1ValidateDeclarationExpression:
            CALL TypedDeclarationScalarType
            LD   E,A

.routine in E out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B,C,IX,IY
HybridLL1CheckExpressionAssignable:
            LD   HL,(EXRVAL)
            LD   A,(EXRMETA)
            JP   TypedCheckAssignable

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LALOCSET:
            LD   A,(DCINFO)
            LD   D,A
            LD   A,(DCPAY)
            LD   C,A
            CALL TypedEmitStoreByInfo
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL SymbolCommit
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL TypedDeclarationScalarType
            JP   Stage7InstallScalarParameterWidth

; ------------------------------------------------------------ simple statements

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LANAMSTM:
.if TargetStreamingOutput
.if DebugHooks
            OUT  (DTSOURCE),A
.endif
.endif
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,(TNSTOFF)
            LD   (EXCALOFF),HL
            LD   (S7CALOFF),HL
            CALL Stage8MatchPredefinedCurrent
            JR   NC,HybridLL1OrdinaryNameStatement
            CP   P8CONST
            JP   NC,TypedTypeFailure
            LD   C,B
            CALL Stage8ParseServiceCall
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   Stage8SelectFailureConsumer
HybridLL1OrdinaryNameStatement:
            CALL Stage7FindRoutineCurrent
            JR   NZ,HybridLL1ParseAssignment
            LD   C,0
            CALL Stage7ParseCall
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   Stage8SelectFailureConsumer
HybridLL1ParseAssignment:
            CALL HybridLL1LookupDeclaration
.if CompilerDiagnosticReturns
            RET  C
.endif
            AND  SYAGGFLG
            JP   NZ,Stage7ParseAggregateAssignment
            LD   A,D
            CALL TypedRequireScalarSymbolClass
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   SCLOC
            JR   NZ,HybridLL1StatementCounterChecked
            CALL ControlCheckActiveCounter
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(DCINFO)
            LD   D,A
HybridLL1StatementCounterChecked:
            LD   A,D
            AND  SCMSK
            JP   Z,TypedTypeFailure
            CALL ParserExpectEqual
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL TypedDeclarationScalarType
            CALL TypedExpressionBeginRuntime
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   D,A
            CALL TypedDeclarationScalarType
            LD   E,A
            LD   A,D
            CALL TypedCheckAssignable
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL Stage8SelectFailureConsumer
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   BC,(DCPAY)
            LD   A,(DCINFO)
            LD   D,A
            JP   TypedEmitStoreByInfo
LARETVBG:
.if TargetStreamingOutput
.if DebugHooks
            OUT  (DTSOURCE),A
.endif
.endif
            LD   A,(C7RESTYP)
            OR   A
            RET  Z
            CP   AGDYNTYP
            RET  NC
            JP   HybridLL1SaveExpectedType

.if TargetStreamingOutput
.routine out A,carry,zero clobbers sign,parity,halfCarry
HybridLL1RequireReturnType:
            LD   A,(C7RESTYP)
            OR   A
            JP   Z,TypedRoutineFlowFailure
            CP   AGDYNTYP
            RET
.endif

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LARETVAL:
.if TargetStreamingOutput
            CALL HybridLL1RequireReturnType
.else
            LD   A,(C7RESTYP)
            OR   A
            JP   Z,TypedRoutineFlowFailure
            CP   AGDYNTYP
.endif
            JR   NC,HybridLL1ReturnAggregateValue
            CALL TypedExpressionBeginRuntime
            JP   HybridLL1SaveExpressionResult
HybridLL1ReturnAggregateValue:
            CALL Stage7ParseAggregateValue
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   (S7PATHT),A
            OR   A
            RET

LARETSET:
.if TargetStreamingOutput
            CALL HybridLL1RequireReturnType
.else
            LD   A,(C7RESTYP)
            OR   A
            JP   Z,TypedRoutineFlowFailure
            CP   AGDYNTYP
.endif
            JR   NC,HybridLL1CommitAggregateReturn
            LD   E,A
            CALL HybridLL1CheckFailureResult
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL HybridLL1TestRoutineFails
            LD   A,SMRETSCA
            JR   Z,HybridLL1ReturnScalarSelected
            LD   A,SMRTFS
HybridLL1ReturnScalarSelected:
            CALL SemanticSinkOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
            JR   HybridLL1ReturnCommitted
HybridLL1CommitAggregateReturn:
            LD   D,A
            LD   A,(S7PATHT)
            CP   D
            JP   NZ,TypedTypeFailure
            CALL Stage8RequireNoPendingFailure
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL HybridLL1TestRoutineFails
            LD   A,SMRETAGG
            JR   Z,HybridLL1ReturnAggregateSelected
            LD   A,SMRTFA
HybridLL1ReturnAggregateSelected:
            CALL SemanticSinkOperation
.if CompilerDiagnosticReturns
            RET  C
.endif
HybridLL1ReturnCommitted:
            JP   HybridLL1NoFallthrough

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LARETNON:
            LD   A,(C7RESTYP)
            OR   A
            JP   NZ,TypedRoutineFlowFailure
            CALL HybridLL1EmitRoutineEnd
.if CompilerDiagnosticReturns
            RET  C
.endif
            XOR  A
            CALL SemanticSinkPut
.if CompilerDiagnosticReturns
            RET  C
.endif
            JR   HybridLL1ReturnCommitted

; A is the logical action ordinal. The two ordinals and tokens are contiguous.
LAXFER:
.if TargetStreamingOutput
.if DebugHooks
            OUT  (DTSOURCE),A
.endif
.endif
            DEC  A
HybridLL1EmitTransfer:
            LD   (DCINFO),A
            CALL ControlFindLoop
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   DE,CFEXIT
            LD   A,(DCINFO)
            CP   TNEXIT
            JR   Z,HybridLL1TransferSelected
            LD   DE,CFCONT
HybridLL1TransferSelected:
            ADD  HL,DE
            LD   C,(HL)
            JP   ControlEmitJump

; ---------------------------------------------------------- structured flow

; Save the enclosing statement sequence's fallthrough bit, then push the
; control-frame kind supplied in B.
.routine in B out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B,C
HybridLL1PushFlowFrame:
            LD   A,(CTDEP)
            CP   CFCAP
            JP   NC,ControlCapacityFailure
            CALL HybridLL1FlowAddress
            LD   A,(CTFALLS)
            LD   (HL),A
            LD   A,B
            JP   ControlPushFrame

.routine out A,DE,HL clobbers carry,zero,sign,parity,halfCarry
HybridLL1FlowAddress:
            LD   A,(CTDEP)
            LD   E,A
            LD   D,0
            LD   HL,HybridLL1FlowStackBase
            ADD  HL,DE
            RET

; The frame has already been popped. Restore its enclosing sequence bit.
.routine out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B,C
HybridLL1RestoreFlow:
            CALL HybridLL1FlowAddress
            LD   A,(HL)
            JP   HybridLL1StoreFallthrough

; A is the completed compound statement's fallthrough bit.
.routine in A out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B,C
HybridLL1CombineFlow:
            LD   B,A
            CALL ControlPopFrame
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL HybridLL1FlowAddress
            LD   A,(HL)
            AND  B
            JP   HybridLL1StoreFallthrough

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
HybridLL1CheckBooleanResult:
            LD   E,TYBOOL
HybridLL1CheckTypedResult:
            CALL Stage8RequireNoPendingFailure
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   HybridLL1CheckExpressionAssignable

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LAIF:
.if TargetStreamingOutput
.if DebugHooks
            OUT  (DTSOURCE),A
            OUT  (DTPUSH),A
.endif
.endif
            LD   B,CKIF
            CALL HybridLL1PushFlowFrame
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ControlAllocateExit
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ControlAllocateLabelA
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   DE,CFCTR-CFLBLA
            ADD  HL,DE
            LD   (HL),1
HybridLL1ExpectBoolean:
            LD   A,TYBOOL
            JP   HybridLL1SaveExpectedType

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LAIFBODY:
            CALL HybridLL1CheckBooleanResult
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   B,CFLBLA

.routine in B out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
HybridLL1BeginConditionBody:
            CALL ControlTopFrameField
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   C,(HL)
            CALL ControlEmitBranchFalse
HybridLL1CheckedSetFallsThrough:
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   HybridLL1SetFallsThrough

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
HybridLL1BeginBranchClause:
            CALL StructuredRecordIfClause
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   B,CFEXIT
            CALL HybridLL1TopFrameFieldToC
            CALL ControlEmitJump
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   B,CFLBLA
            JR   HybridLL1EmitFrameLabel

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LAELSEIF:
.if TargetStreamingOutput
.if DebugHooks
            OUT  (DTSOURCE),A
.endif
.endif
            CALL HybridLL1BeginBranchClause
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ControlAllocateLabelA
.if CompilerDiagnosticReturns
            RET  C
.endif
            JR   HybridLL1ExpectBoolean

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LAELSE:
.if TargetStreamingOutput
.if DebugHooks
            OUT  (DTSOURCE),A
.endif
.endif
            CALL HybridLL1BeginBranchClause
            JR   HybridLL1CheckedSetFallsThrough

.routine out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B,C
LAELSEEN:
            CALL StructuredRecordIfClause
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   B,CFMODE
            CALL ControlTopFrameField
            LD   (HL),1
            XOR  A
            RET

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LAIFDONE:
            CALL StructuredRecordIfClause
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   B,CFLBLA

; B selects a field in the active control frame. All callers have already
; established that frame; the helper preserves their existing precondition.
.routine in B out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
HybridLL1EmitFrameLabel:
            CALL HybridLL1TopFrameFieldToC
            JP   ControlEmitLabel

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LAIFEND:
.if TargetStreamingOutput
.if DebugHooks
            OUT  (DTPOP),A
.endif
.endif
            LD   B,CFEXIT
            CALL HybridLL1EmitFrameLabel
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ControlTopFrame
            PUSH HL
            LD   DE,CFCTR
            ADD  HL,DE
            LD   A,(HL)
            POP  HL
            LD   DE,CFMODE
            ADD  HL,DE
            AND  (HL)
            XOR  1
            JP   HybridLL1CombineFlow

; --------------------------------------------------------------- select/case

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LASELECT:
.if TargetStreamingOutput
.if DebugHooks
            OUT  (DTSOURCE),A
            OUT  (DTPUSH),A
.endif
.endif
            LD   B,CKSEL
            CALL HybridLL1PushFlowFrame
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ControlAllocateExit
.if CompilerDiagnosticReturns
            RET  C
.endif
            INC  HL
            LD   (HL),1                   ; all bodies non-fallthrough so far
            XOR  A                       ; exact selector context
            JP   HybridLL1SaveExpectedType

; Retain the selector's concrete integer type in the active frame. Untyped
; exact values use the language's ordinary u16/i16 inference; typed selectors
; retain their declared width and signedness.
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LASELEXP:
            CALL Stage8RequireNoPendingFailure
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(EXRMETA)
            LD   D,A
            AND  MTTYPMSK
            JR   NZ,HybridLL1SelectTypeReady
HybridLL1InferSelectType:
            LD   A,D
            AND  MTNEG
            RRCA
            OR   TYU16
HybridLL1SelectTypeReady:
            CP   TYBOOL
            JP   Z,TypedTypeFailure
            LD   C,A
            LD   B,CFMODE
            CALL ControlTopFrameField
            LD   (HL),C
            RET

.routine out A,C,DE,HL,carry,zero clobbers sign,parity,halfCarry,B
LASELCAS:
.if TargetStreamingOutput
.if DebugHooks
            OUT  (DTSOURCE),A
.endif
.endif
            CALL ControlAllocateLabelA
.if CompilerDiagnosticReturns
            RET  C
.endif
            INC  B                       ; LabelA -> Continue
            JP   ControlAllocateInto

; Case expressions are folded under the selector's exact type and never emit
; a runtime value of their own.
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LASELCON:
            LD   B,CFMODE
            CALL ControlTopFrameField
            LD   A,(HL)
            CALL TypedExpressionBeginConstant
            JP   HybridLL1SaveExpressionResult

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LACASVAL:
            LD   A,(EXEXPTYP)
            LD   E,A
            LD   A,(EXRMETA)
            OR   A
            JP   P,TypedTypeFailure
            CALL HybridLL1CheckExpressionAssignable
.if CompilerDiagnosticReturns
            RET  C
.endif
            AND  MTTYPMSK
            LD   C,A
            PUSH HL
            LD   A,SMSELCS
            CALL ParserEmitOperationC
            POP  HL
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL Stage7EmitWord
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   B,CFLBLA
            CALL HybridLL1TopFrameFieldToC
            JP   SemanticSinkPut

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LACASBDY:
            LD   B,CFCONT
            CALL HybridLL1TopFrameFieldToC
            CALL ControlEmitJump
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   B,CFLBLA
            CALL HybridLL1EmitFrameLabel
.if CompilerDiagnosticReturns
            RET  C
.endif
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LASELELS:
            CALL HybridLL1DiscardSelectCarrier
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   HybridLL1SetFallsThrough

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LACASEND:
            CALL StructuredRecordIfClause
            LD   B,CFEXIT
            CALL HybridLL1TopFrameFieldToC
            CALL ControlEmitJump
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   B,CFCONT
            CALL HybridLL1EmitFrameLabel
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   HybridLL1SetFallsThrough

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
HybridLL1DiscardSelectCarrier:
            LD   A,SMFCLEAN
            JP   SemanticSinkOperation

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LASELEND:
            CALL StructuredRecordIfClause
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(HL)
            XOR  1                       ; all non-fallthrough -> select result
.if CompilerDiagnosticReturns
            LD   B,A
.endif
            JR   HybridLL1EndSelect

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LASELNON:
            CALL HybridLL1DiscardSelectCarrier
.if CompilerDiagnosticReturns
            RET  C
.endif
.if CompilerNonlocalDiagnostics
            LD   A,1                     ; no else always permits fallthrough
.else
            LD   B,1                     ; no else always permits fallthrough
.endif
HybridLL1EndSelect:
.if TargetStreamingOutput
.if DebugHooks
            OUT  (DTPOP),A
.endif
.endif
.if CompilerNonlocalDiagnostics
            PUSH AF
.else
            PUSH BC
.endif
            LD   B,CFEXIT
            CALL HybridLL1EmitFrameLabel
.if CompilerNonlocalDiagnostics
            POP  AF
.else
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,B
.endif
            JP   HybridLL1CombineFlow

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LAWHILE:
.if TargetStreamingOutput
.if DebugHooks
            OUT  (DTSOURCE),A
            OUT  (DTPUSH),A
.endif
.endif
            LD   B,CKWHILE
            CALL HybridLL1PushFlowFrameAndLabelA
.if CompilerDiagnosticReturns
            RET  C
.endif
            INC  HL
            LD   (HL),C
            CALL ControlAllocateExit
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   B,CFLBLA
            CALL HybridLL1EmitFrameLabel
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   HybridLL1ExpectBoolean

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LAWHBODY:
            CALL HybridLL1CheckBooleanResult
.if CompilerDiagnosticReturns
            RET  C
.endif
            ; Folded Boolean values are canonical zero or one in L. Turn the
            ; constant bit in A into a mask, then retain constant true only.
            RLCA
            SBC  A,A
            AND  L
            LD   C,A
            LD   B,CFMODE
            CALL ControlTopFrameField
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   (HL),C
            LD   B,CFEXIT
            JP   HybridLL1BeginConditionBody

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LAWHEND:
.if TargetStreamingOutput
.if DebugHooks
            OUT  (DTPOP),A
.endif
.endif
            LD   B,CFCONT
            CALL HybridLL1TopFrameFieldToC
            CALL ControlEmitJump
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   B,CFEXIT
            CALL HybridLL1EmitFrameLabel
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   B,CFMODE
            CALL HybridLL1TopFrameFieldToC
            XOR  CTWHTRUE
            JP   HybridLL1CombineFlow

HybridLL1PopAndRestoreFlow:
            CALL ControlPopFrame
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   HybridLL1RestoreFlow

; -------------------------------------------------------------- counted loop

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LAFOR:
.if TargetStreamingOutput
.if DebugHooks
            OUT  (DTSOURCE),A
            OUT  (DTPUSH),A
.endif
.endif
            ; The streaming parser has consumed the counter name before this
            ; action. Convert its retained source pointer through the current
            ; multipart descriptor; parser lookahead may advance part-local
            ; cursor metadata beyond the token whose action is now running.
.if NativeStreamingSource
            LD   HL,(TNSTOFF)
.else
.if TargetStreamingOutput
            LD   HL,(SSPDCUR)
            LD   DE,-4                  ; current descriptor's source start
            ADD  HL,DE
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            LD   HL,(TNLEXPTR)
            OR   A
            SBC  HL,DE
.else
            LD   HL,(TNSTOFF)
.endif
.endif
            LD   (S7FOROFF),HL
            CALL HybridLL1LookupDeclaration
.if CompilerDiagnosticReturns
            RET  C
.endif
            AND  SCMSK
            CP   SCLOC
            JP   NZ,StructuredCounterFailure
            LD   A,D
            AND  TYBASMSK
            JP   Z,StructuredCounterFailure
            CALL ControlCheckActiveCounter
            JP   HybridLL1SetLocalExpectedType

HybridLL1CheckForInitial:
            CALL HybridLL1ValidateDeclarationExpression
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   Stage8RequireNoPendingFailure

; A is the logical action ordinal for the contiguous to/until family.
LAFORBND:
            AND  1
HybridLL1ForBoundSelected:
            LD   (HybridLL1ForMode),A
            CALL LALOCEND
.if CompilerDiagnosticReturns
            RET  C
.endif
HybridLL1ExpectForBound:
            JP   HybridLL1SetLocalExpectedType

.routine out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B,C,IX,IY
HybridLL1CheckForBound:
            CALL TypedDeclarationScalarType
            LD   E,A
            JP   HybridLL1CheckTypedResult

LASTEPSV .equ HybridLL1CheckForBound

LASTEPDF:
            CALL HybridLL1CheckForBound
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   DE,1
            LD   (HybridLL1ForStep),DE
            XOR  A
            RET

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LAFORBDY:
            LD   B,CKFOR
            CALL HybridLL1PushFlowFrameAndLabelA
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   B,CFCONT
            CALL ControlAllocateInto
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ControlAllocateExit
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   B,CFCTR
            CALL ControlTopFrameField
            LD   A,(DCPAY)
            LD   (HL),A
            INC  HL
            CALL TypedDeclarationScalarType
            LD   D,A
            AND  TYSGNFLG
            RRCA
            LD   E,A
            LD   A,D
            AND  TYU16
            RLCA
            OR   E
            LD   E,A
            LD   A,(HybridLL1ForMode)
            OR   E
            LD   (HL),A
            INC  HL
            LD   DE,(HybridLL1ForStep)
            LD   (HL),E
            INC  HL
            LD   (HL),D
            INC  HL
            LD   DE,(S7FOROFF)
            LD   (HL),E
            INC  HL
            LD   (HL),D
            CALL ControlTopFrame
            CALL StructuredEmitForSetup
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   B,CFLBLA
            CALL HybridLL1EmitFrameLabel
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL StructuredEmitForTest
            JP   HybridLL1CheckedSetFallsThrough

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LAFOREND:
.if TargetStreamingOutput
.if DebugHooks
            OUT  (DTPOP),A
.endif
.endif
            LD   B,CFCONT
            CALL HybridLL1EmitFrameLabel
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL StructuredEmitForNext
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   B,CFEXIT
            CALL HybridLL1EmitFrameLabel
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL HybridLL1DiscardSelectCarrier
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   HybridLL1PopAndRestoreFlow
HybridLL1ActionsEnd:
