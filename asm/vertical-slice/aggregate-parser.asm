; Stage 6 aggregate layout and static-image construction.
;
; Types use one-byte IDs. Predefined scalars use contextual metadata values;
; dynamic IDs begin at AggregateFirstDynamicTypeId and index a bounded
; six-byte descriptor whose first four bytes are its structural identity and
; whose final word is its retained extent. Aggregate
; storage is allocated by top-level variables and aggregate constants.
; Initializer bytes are staged privately; the Z80 backend publishes them only
; after the complete source has succeeded.

.routine in A out A,HL clobbers carry,zero,sign,parity,halfCarry,DE
AggregateFieldAddress:
            LD   DE,AFTABBAS
            JR   AggregateAddress6

.routine in A out A,HL clobbers carry,zero,sign,parity,halfCarry,DE
AggregateTypeAddress:
            SUB  AGDYNTYP
            LD   DE,ATTABBAS
.routine in A,DE out A,HL clobbers carry,zero,sign,parity,halfCarry,DE
AggregateAddress6:
            LD   L,A
            ADD  A,A
            ADD  A,L
            ADD  A,A
            LD   L,A
            LD   H,0
            ADD  HL,DE
            RET

.if TargetStreamingOutput
.routine in A out A,HL clobbers carry,zero,sign,parity,halfCarry,D,DE
TargetBankStateAddress:
            LD   DE,TBBAS
            JR   AggregateAddress6

.routine in A out A,HL clobbers carry,zero,sign,parity,halfCarry,D,DE
TargetBankRoLengthAddress:
            LD   DE,TBKROBAS
            JR   AggregateAddress6
.endif

.routine in A out A,HL,carry,zero clobbers sign,parity,halfCarry,DE
AggregateGetExtent:
            CP   AGDYNTYP
            JR   NC,AggregateGetDynamicExtent
            LD   HL,1
            BIT  1,A
            JR   NZ,AggregateGetU16Extent
            OR   A
            RET
AggregateGetU16Extent:
            INC  L
            OR   A
            RET
AggregateGetDynamicExtent:
            CALL AggregateTypeAddress
            LD   DE,ATEXT
            ADD  HL,DE
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            EX   DE,HL
            OR   A
            RET

; Append the complete descriptor in AggregateCandidate*. No structural
; lookup is performed, so this entry creates nominal record identity.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
AggregateAppendType:
            LD   A,(ATCNT)
            CP   ATCAP
            JR   NC,AggregateTypeCapacityFailure
            ADD  A,AGDYNTYP
            CALL AggregateTypeAddress
            LD   D,H
            LD   E,L
            LD   HL,ANKIND
            LD   BC,ATENTSZ
            LDIR
            LD   A,(ATCNT)
            ADD  A,AGDYNTYP
            LD   C,A
            LD   HL,ATCNT
            INC  (HL)
            LD   A,C
            OR   A
            RET
AggregateTypeCapacityFailure:
            CALL DGINLINE
            .db  DGTYPCAP

; Intern a structural string or array descriptor. CandidateKind/Aux/Length and
; CandidateExtent must already be complete. Extent is not part of structural
; identity; the first four bytes determine it for structural types.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
AggregateInternType:
            LD   A,(ATCNT)
            OR   A
            JR   Z,AggregateAppendType
            LD   B,A
            LD   C,AGDYNTYP
AggregateInternLoop:
            LD   A,C
            CALL AggregateTypeAddress
            LD   DE,ANKIND
            PUSH BC
            LD   B,4
AggregateInternCompareLoop:
            LD   A,(DE)
            CP   (HL)
            JR   NZ,AggregateInternDifferent
            INC  DE
            INC  HL
            DJNZ AggregateInternCompareLoop
            POP  BC
            JR   AggregateInternFound
AggregateInternDifferent:
            POP  BC
AggregateInternNext:
            INC  C
            DJNZ AggregateInternLoop
            JR   AggregateAppendType
AggregateInternFound:
            LD   A,C
            OR   A
            RET

; Collect array suffixes in source order. The complete type is formed only
; after the last suffix, so u8[3][2] can be interned as u8[2] and then as
; three elements of that row type.
.routine out A,carry,zero clobbers sign,parity,halfCarry
AggregateBeginArrayType:
            XOR  A
            LD   (ADCNT),A
            LD   (ATOAFLAG),A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry
AggregateRejectOpenViewCurrent:
            LD   A,(ACTYPID)
            CP   AGOVIEW
            JP   NC,AggregateTypeShapeFailure
            OR   A
            RET

; HL is one already-checked positive concrete dimension.
.routine in HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
AggregateSaveArrayDimension:
            CALL AggregateRejectOpenViewCurrent
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(ADCNT)
            CP   ADCAP
            JR   NC,AggregateTypeCapacityFailure
            LD   C,L
            LD   B,H
            ADD  A,A
            ADD  A,A
            LD   E,A
            LD   D,0
            LD   HL,ADBAS
            ADD  HL,DE
            LD   (HL),C
            INC  HL
            LD   (HL),B
            INC  HL
            LD   DE,(TNSTOFF)
            LD   (HL),E
            INC  HL
            LD   (HL),D
            LD   HL,ADCNT
            INC  (HL)
            OR   A
            RET

; The only omitted array bound is the first suffix of a formal-parameter
; type. Later placement checks keep the completed view parameter-only.
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
AggregateSaveOpenArrayDimension:
            LD   A,(ADCNT)
            LD   B,A
            LD   A,(ATOAFLAG)
            OR   B
            JP   NZ,AggregateTypeShapeFailure
            CALL AggregateRejectOpenViewCurrent
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   DE,ATOAPOS
            CALL DGCOPYTK
            LD   A,1
            LD   (ATOAFLAG),A
            OR   A
            RET

; Owning and result positions historically diagnose an illegal open array at
; its closing bracket. The recursive suffix collector has already buffered the
; following token, so restore the retained suffix position only for an open
; array; concrete types and string[] keep their existing diagnostic positions.
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
AggregateRejectOpenViewPlacement:
            LD   A,(ACTYPID)
            OR   A
            JP   P,AggregateRejectOpenViewCurrent
            LD   HL,ATOAPOS
            CALL DGRESTTK
            JR   AggregateRejectOpenViewCurrent

; Wrap AggregateCurrentTypeId in one concrete array dimension. HL is the
; dimension length and the previous current type becomes the exact element ID.
.routine in HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
AggregateWrapArrayCurrent:
            CALL AggregateRejectOpenViewCurrent
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   (ANAUX),A
            LD   (ANLEN),HL
            LD   B,H
            LD   C,L
            LD   A,(ANAUX)
            CALL AggregateGetExtent
            LD   D,H
            LD   E,L
            LD   HL,0
AggregateWrapArrayExtentLoop:
            ADD  HL,DE
.if CompilerNonlocalDiagnostics
            JR   C,AggregateProgramDataCapacityFailure
.else
            JP   C,AggregateProgramDataCapacityFailure
.endif
.if CompilerNonlocalDiagnostics
            PUSH BC
.endif
            CALL AggregateCheckExtentCapacity
.if CompilerNonlocalDiagnostics
            POP  BC
.endif
.if CompilerDiagnosticReturns
            RET  C
.endif
            DEC  BC
            LD   A,B
            OR   C
            JR   NZ,AggregateWrapArrayExtentLoop
            LD   (ANEXT),HL
            LD   A,ATKARRAY
            LD   (ANKIND),A
            CALL AggregateInternType
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   (ACTYPID),A
            OR   A
            RET

; Apply saved concrete dimensions from innermost to outermost, then apply an
; optional outer open view. The buffer itself stays outside source-visible
; type identity and is reused by the next type parse.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
AggregateFinishArrayType:
            LD   A,(ADCNT)
            OR   A
            JR   Z,AggregateFinishArrayOpen
            LD   DE,(TNSTOFF)
            LD   (ATRESOFF),DE
            LD   B,A
            ADD  A,A
            ADD  A,A
            LD   E,A
            LD   D,0
            LD   HL,ADBAS
            ADD  HL,DE
AggregateFinishArrayLoop:
            DEC  HL
            LD   D,(HL)
            DEC  HL
            LD   E,(HL)
            LD   (TNSTOFF),DE
            DEC  HL
            LD   D,(HL)
            DEC  HL
            LD   E,(HL)
            PUSH BC
            PUSH HL
            EX   DE,HL
            CALL AggregateWrapArrayCurrent
            POP  HL
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            DJNZ AggregateFinishArrayLoop
            LD   DE,(ATRESOFF)
            LD   (TNSTOFF),DE
AggregateFinishArrayOpen:
            LD   A,(ATOAFLAG)
            OR   A
            JR   Z,AggregateFinishArrayReady
            CALL AggregateRejectOpenViewCurrent
.if CompilerDiagnosticReturns
            RET  C
.endif
            OR   AGOAMSK
            LD   (ACTYPID),A
AggregateFinishArrayReady:
            LD   A,(ACTYPID)
            OR   A
            RET

; The first compiler admits one aggregate object up to the selected complete
; program-data region. HL is a nonzero mathematical extent.
.if SegmentedOutput
.if CompilerNonlocalDiagnostics
; Production diagnostics never return, so B can select the exact
; capacity diagnostic without adding a second copy of the word predicate.
.routine in HL out A,HL,carry,zero clobbers sign,parity,halfCarry,B
AggregateCheckExtentCapacity:
            LD   B,DGPDCAP
            JR   AggregateCheckSegmentedCapacity

.routine in HL out A,HL,carry,zero clobbers sign,parity,halfCarry,B
AggregateCheckReadOnlyCapacity:
            LD   B,DGROCAP
.routine in B,HL out A,HL,carry,zero clobbers sign,parity,halfCarry,B
AggregateCheckSegmentedCapacity:
            LD   A,H
            CP   4
            JR   C,AggregateSegmentedCapacityReady
            JR   NZ,AggregateSegmentedCapacityFailure
            LD   A,L
            OR   A
            JR   NZ,AggregateSegmentedCapacityFailure
AggregateSegmentedCapacityReady:
            OR   A
            RET
AggregateSegmentedCapacityFailure:
            LD   A,B
            JP   DGSET
.else
; Returning-diagnostic historical layouts retain independently balanced
; routines so their public preservation contracts remain unchanged.
.routine in HL out A,HL,carry,zero clobbers sign,parity,halfCarry
AggregateCheckExtentCapacity:
            LD   A,H
            CP   4
            JR   C,AggregateExtentCapacityReady
            JR   NZ,AggregateExtentCapacityFailure
            LD   A,L
            OR   A
            JR   NZ,AggregateExtentCapacityFailure
AggregateExtentCapacityReady:
            OR   A
            RET
AggregateExtentCapacityFailure:
            CALL DGINLINE
            .db  DGPDCAP

.routine in HL out A,HL,carry,zero clobbers sign,parity,halfCarry
AggregateCheckReadOnlyCapacity:
            LD   A,H
            CP   4
            JR   C,AggregateReadOnlyCapacityReady
            JR   NZ,AggregateReadOnlyCapacityFailure
            LD   A,L
            OR   A
            JR   NZ,AggregateReadOnlyCapacityFailure
AggregateReadOnlyCapacityReady:
            OR   A
            RET
AggregateReadOnlyCapacityFailure:
            CALL DGINLINE
            .db  DGROCAP
.endif
.else
.routine in HL out A,HL,carry,zero clobbers sign,parity,halfCarry
AggregateCheckExtentCapacity:
            LD   A,H
            OR   A
            JR   NZ,AggregateExtentCapacityFailure
AggregateExtentCapacityReady:
            OR   A
            RET
AggregateExtentCapacityFailure:
            CALL DGINLINE
            .db  DGPDCAP
.endif

.if HybridLL1Full
AggregateTypeShapeFailure:
            CALL DGINLINE
            .db  DGTYPBND
AggregateProgramDataCapacityFailure:
            CALL DGINLINE
            .db  DGPDCAP
AggregateStringCapacityFailure:
            CALL DGINLINE
            .db  DGSTRCAP
.else
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
AggregateParseBound:
            LD   A,TYU16
            CALL TypedExpressionBeginConstant
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   D,A
            AND  MTCONST
            JP   Z,AggregateTypeShapeFailure
            LD   E,TYU16
            LD   A,D
            CALL TypedCheckAssignable
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,H
            OR   L
            JR   Z,AggregateTypeShapeFailure
            PUSH HL
            LD   E,TNRBRK
            CALL PSEXPECT
            POP  HL
            RET

AggregateTypeShapeFailure:
            CALL DGINLINE
            .db  DGTYPBND

; Parse any admitted aggregate type. Bounds and complete extents are retained
; as words. Object allocation is still bounded by the selected program-data
; region, and exceeding that implementation capacity receives a capacity
; diagnostic rather than changing the source type.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
AggregateParseType:
            CALL AggregateBeginArrayType
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TOKENU8
            JR   Z,AggregateTypeU8
            CP   TOKENU16
            JR   Z,AggregateTypeU16
            CP   TOKENI8
            JR   Z,AggregateTypeI8
            CP   TOKENI16
            JR   Z,AggregateTypeI16
            CP   TNBOOL
            JR   Z,AggregateTypeBoolean
            CP   TNSTR
            JR   Z,AggregateParseStringType
            CP   TNNAME
            JR   NZ,AggregateTypeShapeFailure
            CALL SymbolLookupCurrent
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   D,A
            AND  SYRECTYP+SYAGGFLG
            CP   SYRECTYP
            JR   NZ,AggregateTypeShapeFailure
            LD   A,C
            JR   AggregateTypeBaseReady
AggregateTypeU8:
            LD   A,ATIDU8
            JR   AggregateTypeBaseReady
AggregateTypeU16:
            LD   A,ATIDU16
            JR   AggregateTypeBaseReady
AggregateTypeI8:
            LD   A,ATIDI8
            JR   AggregateTypeBaseReady
AggregateTypeI16:
            LD   A,ATIDI16
            JR   AggregateTypeBaseReady
AggregateTypeBoolean:
            LD   A,ATIDBOOL
            JR   AggregateTypeBaseReady
AggregateParseStringType:
            LD   E,TNLBRK
            CALL PSEXPECT
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL AggregateParseBound
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,H
            OR   A
            JP   NZ,AggregateStringCapacityFailure
            LD   A,L
            OR   A
            JP   Z,AggregateTypeShapeFailure
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
            CALL AggregateInternType
.if CompilerDiagnosticReturns
            RET  C
.endif
AggregateTypeBaseReady:
            LD   (ACTYPID),A
AggregateParseArraySuffixLoop:
            CALL PSPEEK
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TNLBRK
            JR   Z,AggregateParseArraySuffix
            JP   AggregateFinishArrayType
AggregateParseArraySuffix:
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL PSPEEK
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TNRBRK
            JR   NZ,AggregateParseConcreteArraySuffix
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL AggregateSaveOpenArrayDimension
.if CompilerDiagnosticReturns
            RET  C
.endif
            JR   AggregateParseArraySuffixLoop
AggregateParseConcreteArraySuffix:
            CALL AggregateParseBound
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL AggregateSaveArrayDimension
.if CompilerDiagnosticReturns
            RET  C
.endif
            JR   AggregateParseArraySuffixLoop
AggregateProgramDataCapacityFailure:
            CALL DGINLINE
            .db  DGPDCAP
AggregateStringCapacityFailure:
            CALL DGINLINE
            .db  DGSTRCAP
.endif

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
AggregateCheckFieldDuplicate:
            LD   A,(ACFLDCNT)
            OR   A
            RET  Z
            LD   C,A
            LD   A,(ACFLDST)
AggregateFieldDuplicateLoop:
            PUSH AF
            PUSH BC
            CALL AggregateFieldAddress
            CALL TKRECEQ
            JR   C,AggregateFieldDuplicateUnwind
            POP  BC
            POP  AF
            INC  A
            DEC  C
            JR   NZ,AggregateFieldDuplicateLoop
            OR   A
            RET
AggregateFieldDuplicateUnwind:
            POP  BC
            POP  AF
AggregateFieldDuplicateFailure:
            JP   TypedDuplicateNameFailure

.if HybridLL1Full
AggregateRecordEmptyFailure:
            CALL DGINLINE
            .db  DGRECEMP
.else
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
AggregateParseRecordAfterTake:
            LD   E,TNNAME
            CALL PSEXPECT
.if CompilerDiagnosticReturns
            RET  C
.endif
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
            CALL ParserExpectLine
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(AFCNT)
            LD   (ACFLDST),A
            XOR  A
            LD   (ACFLDCNT),A
            LD   H,A
            LD   L,A
            LD   (ACRECEXT),HL
AggregateRecordFieldLoop:
            CALL PSPEEK
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TOKENEND
            JR   Z,AggregateRecordFinish
            CP   TNNAME
            JP   NZ,AggregateTypeShapeFailure
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL AggregateCheckFieldDuplicate
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(AFCNT)
            LD   B,A
            LD   A,(ACFLDCNT)
            ADD  A,B
            CP   AFCAP
            JP   NC,AggregateTypeCapacityFailure
            PUSH AF
            CALL AggregateFieldAddress
            CALL TKRETAIN
            POP  AF
            PUSH HL
            CALL ParserExpectAs
            POP  HL
.if CompilerDiagnosticReturns
            RET  C
.endif
            PUSH HL
            CALL AggregateParseType
            POP  HL
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   B,A
            INC  HL
            LD   (HL),B
            INC  HL
            LD   DE,(ACRECEXT)
            LD   (HL),E
            INC  HL
            LD   (HL),D
            PUSH DE
            LD   A,B
            CALL AggregateGetExtent
            POP  DE
            ADD  HL,DE
            JP   C,AggregateProgramDataCapacityFailure
            CALL AggregateCheckExtentCapacity
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   (ACRECEXT),HL
            CALL ParserExpectLine
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,ACFLDCNT
            INC  (HL)
            JR   AggregateRecordFieldLoop
AggregateRecordFinish:
            LD   A,(ACFLDCNT)
            OR   A
            JR   Z,AggregateRecordEmptyFailure
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectLine
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,ATKREC
            LD   (ANKIND),A
            LD   A,(ACFLDST)
            LD   (ANAUX),A
            LD   A,(ACFLDCNT)
            LD   (ANLEN),A
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
            LD   A,(ACFLDCNT)
            LD   HL,AFCNT
            ADD  A,(HL)
            LD   (HL),A
            LD   HL,ARCNT
            INC  (HL)
.if AggregateCallSlices
            JP   Stage7ParseTopLevel
.else
            JP   TypedParseTopLevel
.endif
AggregateRecordEmptyFailure:
            CALL DGINLINE
            .db  DGRECEMP
.endif

AggregateInitializerCapacityFailure:
            CALL DGINLINE
            .db  DGINICAP

.routine out A,carry,zero clobbers sign,parity,halfCarry,HL
AggregateInitializerLeave:
            LD   HL,AIDEP
            DEC  (HL)
            OR   A
            RET

.routine in A out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
AggregateWriteByte:
            LD   B,A
            LD   HL,(ACOBJOFF)
            LD   DE,AIBAS
            ADD  HL,DE
            LD   A,B
            LD   (HL),A
            LD   HL,(ACOBJOFF)
            INC  HL
            LD   (ACOBJOFF),HL
            OR   A
            RET

; Decode the already tokenized string literal directly from resident source.
; B is the fixed capacity. The enclosing object is already zeroed, so the
; final cursor advances over padding without rewriting it.
.routine in B out A,B,carry,zero clobbers sign,parity,halfCarry,C,D,DE,HL
AggregateDecodeString:
            LD   A,(TNLEN)
            LD   C,A
            PUSH BC
            CALL AggregateWriteByte
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,B
            SUB  C
            LD   B,A
            LD   HL,(TNLEXPTR)
            INC  HL
AggregateDecodeStringLoop:
            LD   A,C
            OR   A
            JR   Z,AggregateDecodeStringAdvancePadding
            LD   A,(HL)
            INC  HL
            CP   "\\"
            JR   NZ,AggregateDecodeStringWrite
            LD   A,(HL)
            INC  HL
            CP   "x"
            JR   Z,AggregateDecodeStringHex
            CP   "0"
            JR   Z,AggregateDecodeStringZero
            CP   "n"
            JR   Z,AggregateDecodeStringNewline
            CP   "r"
            JR   Z,AggregateDecodeStringReturn
            CP   "t"
            JR   Z,AggregateDecodeStringTab
            JR   AggregateDecodeStringWrite
AggregateDecodeStringHex:
            LD   A,(HL)
            INC  HL
            CALL TKHEX
            ADD  A,A
            ADD  A,A
            ADD  A,A
            ADD  A,A
            LD   D,A
            LD   A,(HL)
            INC  HL
            CALL TKHEX
            OR   D
            JR   AggregateDecodeStringWrite
AggregateDecodeStringZero:
            XOR  A
            JR   AggregateDecodeStringWrite
AggregateDecodeStringNewline:
            LD   A,10
            JR   AggregateDecodeStringWrite
AggregateDecodeStringReturn:
            LD   A,13
            JR   AggregateDecodeStringWrite
AggregateDecodeStringTab:
            LD   A,9
AggregateDecodeStringWrite:
            PUSH BC
            PUSH HL
            CALL AggregateWriteByte
            POP  HL
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            DEC  C
            JR   AggregateDecodeStringLoop
AggregateDecodeStringAdvancePadding:
            LD   E,B
            LD   D,0
            INC  DE                      ; permanent terminator at capacity+1
            LD   HL,(ACOBJOFF)
            ADD  HL,DE
            LD   (ACOBJOFF),HL
            OR   A
            RET

AggregateInitializerShapeFailure:
            CALL DGINLINE
            .db  DGINISHP
AggregateInitializerCountFailure:
            CALL DGINLINE
            .db  DGINICNT

.routine out A,BC,carry,zero clobbers sign,parity,halfCarry,D,DE,HL
AggregatePeekPreserveBC:
            PUSH BC
            CALL PSPEEK
            POP  BC
            RET

.routine out A,BC,carry,zero clobbers sign,parity,halfCarry,D,DE,HL
AggregateTakePreserveBC:
            PUSH BC
            CALL ParserTake
            POP  BC
            RET

.routine in A,BC,zero out A,BC,carry,zero clobbers sign,parity,halfCarry,D,DE,HL
AggregateExpectCommaPreserveBC:
            JR   Z,AggregateInitializerCountFailure
            CP   TNCOMMA
            JR   NZ,AggregateInitializerShapeFailure
            JR   AggregateTakePreserveBC

; Parse one type-directed static initializer at the current image cursor.
.routine in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
AggregateParseInitializer:
            CP   AGDYNTYP
            JR   C,AggregateParseScalarInitializer
            LD   C,A
            CALL AggregatePeekPreserveBC
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TNNAME
            LD   A,C
            JP   Z,AggregateParseConstantInitializer
            PUSH AF
            CALL AggregateTypeAddress
            LD   A,(HL)
            POP  DE
            LD   E,D
            LD   D,0
            CP   ATKSTR
            JR   Z,AggregateParseStringInitializer
            CP   ATKREC
            JR   Z,AggregateParseRecordInitializer
            CP   ATKARRAY
            JP   Z,AggregateParseArrayInitializer
            JR   AggregateInitializerShapeFailure

AggregateParseScalarInitializer:
            LD   E,A
            PUSH DE
            CALL TypedExpressionBeginConstant
            POP  DE
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL TypedCheckAssignable
.if CompilerDiagnosticReturns
            RET  C
.endif
            AND  MTCONST
            JP   Z,TypedTypeFailure
            LD   A,L
            PUSH DE
            PUSH HL
            CALL AggregateWriteByte
            POP  HL
            POP  DE
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,E
            BIT  1,A
            JR   NZ,AggregateParseScalarU16High
            OR   A
            RET
AggregateParseScalarU16High:
            LD   A,H
            JP   AggregateWriteByte

AggregateParseStringInitializer:
            EX   DE,HL
            LD   A,L
            CALL AggregateTypeAddress
            INC  HL
            LD   B,(HL)
            PUSH BC
            LD   E,TNSTRLIT
            CALL PSEXPECT
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(TNLEN)
            CP   B
            JR   C,AggregateParseStringDecode
            JR   Z,AggregateParseStringDecode
            CALL DGINLINE
            .db  DGSTRLEN
AggregateParseStringDecode:
            ; AggregateZeroCurrentObject already defined the complete object,
            ; so decoding need only overwrite the length and payload bytes.
            JP   AggregateDecodeString

.routine in A,BC out A,BC,carry,zero clobbers sign,parity,halfCarry,D,DE,HL
AggregateBeginCompositeInitializer:
            PUSH AF
            CALL AggregatePeekPreserveBC
            POP  DE
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   D
.if TargetStreamingOutput
            JP   NZ,AggregateInitializerShapeFailure
.else
            JP   NZ,AggregateInitializerShapeFailure
.endif
            CALL AggregateTakePreserveBC
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(AIDEP)
            CP   AIDEPCAP
            JP   NC,AggregateInitializerCapacityFailure
            INC  A
            LD   (AIDEP),A
            OR   A
            RET

AggregateParseRecordInitializer:
            EX   DE,HL
            LD   A,L
            CALL AggregateTypeAddress
            INC  HL
            LD   B,(HL)
            INC  HL
            LD   C,(HL)
            LD   A,TNLPAR
            CALL AggregateBeginCompositeInitializer
.if CompilerDiagnosticReturns
            RET  C
.endif
AggregateRecordInitializerLoop:
            PUSH BC
            LD   A,B
            CALL AggregateFieldAddress
            INC  HL
            INC  HL
            INC  HL
            LD   A,(HL)
            CALL AggregateParseInitializer
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            INC  B
            DEC  C
            JR   Z,AggregateRecordInitializerExpectClose
            CALL AggregatePeekPreserveBC
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TNRPAR
            CALL AggregateExpectCommaPreserveBC
.if CompilerDiagnosticReturns
            RET  C
.endif
            JR   AggregateRecordInitializerLoop
AggregateRecordInitializerExpectClose:
            LD   BC,(TNRPAR<<8)|TNRBRK
            JR   AggregateInitializerExpectClose

AggregateParseArrayInitializer:
            EX   DE,HL
            LD   A,L
            CALL AggregateTypeAddress
            INC  HL
            LD   C,(HL)
            INC  HL
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            PUSH BC
            PUSH DE
            LD   A,TNLBRK
            CALL AggregateBeginCompositeInitializer
            POP  DE
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
AggregateArrayInitializerLoop:
            PUSH BC
            PUSH DE
            LD   A,C
            CALL AggregateParseInitializer
            POP  DE
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            DEC  DE
            LD   A,D
            OR   E
            JR   Z,AggregateArrayInitializerExpectClose
            PUSH DE
            CALL AggregatePeekPreserveBC
            POP  DE
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TNRBRK
            PUSH DE
            CALL AggregateExpectCommaPreserveBC
            POP  DE
.if CompilerDiagnosticReturns
            RET  C
.endif
            JR   AggregateArrayInitializerLoop
AggregateArrayInitializerExpectClose:
            LD   BC,(TNRBRK<<8)|TNRPAR

.routine in BC out A,BC,carry,zero clobbers sign,parity,halfCarry,D,DE,HL,IX,IY
AggregateInitializerExpectClose:
            CALL AggregatePeekPreserveBC
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   B
            JR   Z,AggregateInitializerTakeClose
            CP   C
            JP   Z,AggregateInitializerShapeFailure
            JP   AggregateInitializerCountFailure
AggregateInitializerTakeClose:
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   AggregateInitializerLeave

; Copy an earlier exact-type aggregate constant into the current initializer
; position. The symbol scan derives its offset in the declaration-ordered
; read-only staging suffix, avoiding another retained workspace field.
.routine in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
AggregateParseConstantInitializer:
            LD   C,A
            CALL AggregateTakePreserveBC
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(SYCNT)
            OR   A
            JR   Z,AggregateConstantInitializerMissing
            LD   B,A
            LD   IX,SYTABBAS
            LD   IY,(IMGLEN)
            LD   DE,IMGBAS
            ADD  IY,DE
AggregateConstantInitializerScan:
            PUSH IX
            POP  HL
            CALL TKRECEQ
            JR   C,AggregateConstantInitializerCopy
            LD   A,(IX+3)
            AND  SYAGGFLG+SCMSK
            CP   SYAGGFLG+SCCONST
            JR   NZ,AggregateConstantInitializerNext
            LD   A,(IX+SYTYPID)
            CALL AggregateGetExtent
            EX   DE,HL
            ADD  IY,DE
AggregateConstantInitializerNext:
            LD   DE,SYENTSZ
            ADD  IX,DE
            DJNZ AggregateConstantInitializerScan
AggregateConstantInitializerMissing:
            JP   SymbolLookupMissing
AggregateConstantInitializerCopy:
            LD   A,(IX+3)
            AND  SYAGGFLG+SCMSK
            CP   SYAGGFLG+SCCONST
            JP   NZ,TypedTypeFailure
            LD   A,(IX+SYTYPID)
            CP   C
            JP   NZ,TypedTypeFailure
            CALL AggregateGetExtent
            LD   B,H
            LD   C,L
            LD   DE,(ACOBJOFF)
            PUSH DE
            ADD  HL,DE
            LD   (ACOBJOFF),HL
            POP  HL
            LD   DE,AIBAS
            ADD  HL,DE
            EX   DE,HL
            PUSH IY
            POP  HL
            LDIR
            OR   A
            RET

; Zero exactly the candidate object's complete extent before applying an
; explicit initializer. This also defines every byte of a zero initializer.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
AggregateZeroCurrentObject:
            LD   HL,(ACOBJOFF)
            LD   DE,AIBAS
            ADD  HL,DE
            LD   BC,(ACOBJEXT)
AggregateZeroCurrentLoop:
            LD   A,B
            OR   C
            RET  Z
            XOR  A
            LD   (HL),A
            INC  HL
            DEC  BC
            JR   AggregateZeroCurrentLoop

; The current token is the program variable name.
.if HybridLL1Full
.else
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
AggregateParseProgramAfterVar:
            CALL TypedRetainDeclarationName
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserExpectAs
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL AggregateParseType
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   (ACTYPID),A
            CALL AggregateGetExtent
            LD   (ACOBJEXT),HL
            LD   DE,(IMGLEN)
            LD   (ACOBJOFF),DE
            ADD  HL,DE
            JP   C,AggregateProgramDataCapacityFailure
            LD   A,H
            OR   A
            JP   NZ,AggregateProgramDataCapacityFailure
            LD   (ACOBJEND),HL
            CALL AggregateZeroCurrentObject
.if CompilerDiagnosticReturns
            RET  C
.endif
            XOR  A
            LD   (AIDEP),A
            LD   (AGHASINI),A
            CALL PSPEEK
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TNEQ
            JR   NZ,AggregateProgramInitializerDone
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,(IMGLEN)
            LD   (ACOBJOFF),HL
            LD   A,(ACTYPID)
            LD   B,A
            PUSH BC
            CALL AggregateParseInitializer
.if CompilerDiagnosticBranches
            JR   C,AggregateProgramInitializerFailure
.endif
            POP  BC
            LD   A,1
            LD   (AGHASINI),A
            LD   A,B
            LD   (ACTYPID),A
            LD   HL,(ACOBJOFF)
            LD   DE,(ACOBJEND)
            OR   A
            SBC  HL,DE
            JP   NZ,AggregateInitializerCountFailure
            JR   AggregateProgramInitializerDone
.if CompilerDiagnosticBranches
AggregateProgramInitializerFailure:
            POP  BC
            SCF
            RET
.endif
AggregateProgramInitializerDone:
            CALL ParserExpectLine
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   BC,(IMGLEN)
            LD   A,(ACTYPID)
            CP   AGDYNTYP
            JR   C,AggregateProgramScalarInfo
            LD   D,SIAGPROG
            JR   AggregateProgramPrepareSymbol
AggregateProgramScalarInfo:
            OR   SCPROG
            LD   D,A
AggregateProgramPrepareSymbol:
            PUSH BC
            CALL TypedPrepareCurrentWord
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(ACTYPID)
            INC  HL
            LD   (HL),A
            CALL SymbolCommit
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,(ACOBJEND)
            LD   (IMGLEN),HL
            LD   A,L
            LD   (NXPROG),A
.if AggregateCallSlices
            JP   Stage7ParseTopLevel
.else
            JP   TypedParseTopLevel
.endif
.endif

; Dedicated Stage 6 compile entry. Historical slices keep AggregateMode clear;
; this entry makes the complete static-image path authoritative.
.if AggregateCallSlices
.else
            .routine in A,DE,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CompileAggregateSlice:
            CALL CompileSliceInitialize
            LD   A,1
            LD   (AGMODE),A
.if HybridLL1Full
            XOR  A
            LD   (C7RTN),A
            CALL LLPARSE
.else
            CALL ParserParseProgram
.endif
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   SemanticSinkFinish
.endif
