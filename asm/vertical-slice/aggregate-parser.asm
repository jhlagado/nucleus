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
            LD   DE,AggregateFieldTableBase
            JR   AggregateAddress6

.routine in A out A,HL clobbers carry,zero,sign,parity,halfCarry,DE
AggregateTypeAddress:
            SUB  AggregateFirstDynamicTypeId
            LD   DE,AggregateTypeTableBase
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

.routine in A out A,HL,carry,zero clobbers sign,parity,halfCarry,DE
AggregateGetExtent:
            CP   AggregateFirstDynamicTypeId
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
            LD   DE,AggregateTypeExtent
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
            LD   A,(AggregateTypeCount)
            CP   AggregateTypeCapacity
            JR   NC,AggregateTypeCapacityFailure
            ADD  A,AggregateFirstDynamicTypeId
            CALL AggregateTypeAddress
            LD   D,H
            LD   E,L
            LD   HL,AggregateCandidateKind
            LD   BC,AggregateTypeEntrySize
            LDIR
            LD   A,(AggregateTypeCount)
            ADD  A,AggregateFirstDynamicTypeId
            LD   C,A
            LD   HL,AggregateTypeCount
            INC  (HL)
            LD   A,C
            OR   A
            RET
AggregateTypeCapacityFailure:
            CALL SetDiagInline
            .db  DiagnosticTypeMetadataCapacity

; Intern a structural string or array descriptor. CandidateKind/Aux/Length and
; CandidateExtent must already be complete. Extent is not part of structural
; identity; the first four bytes determine it for structural types.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
AggregateInternType:
            LD   A,(AggregateTypeCount)
            OR   A
            JR   Z,AggregateAppendType
            LD   B,A
            LD   C,AggregateFirstDynamicTypeId
AggregateInternLoop:
            LD   A,C
            CALL AggregateTypeAddress
            LD   DE,AggregateCandidateKind
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
            LD   (AggregateTypeDimensionCount),A
            LD   (AggregateTypeOpenArrayFlag),A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry
AggregateRejectOpenViewCurrent:
            LD   A,(AggregateCurrentTypeId)
            CP   AggregateFirstOpenViewTypeId
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
            LD   A,(AggregateTypeDimensionCount)
            CP   AggregateTypeDimensionCapacity
            JR   NC,AggregateTypeCapacityFailure
            LD   C,L
            LD   B,H
            ADD  A,A
            ADD  A,A
            LD   E,A
            LD   D,0
            LD   HL,AggregateTypeDimensionBase
            ADD  HL,DE
            LD   (HL),C
            INC  HL
            LD   (HL),B
            INC  HL
            LD   DE,(TokenStartOffset)
            LD   (HL),E
            INC  HL
            LD   (HL),D
            LD   HL,AggregateTypeDimensionCount
            INC  (HL)
            OR   A
            RET

; The only omitted array bound is the first suffix of a formal-parameter
; type. Later placement checks keep the completed view parameter-only.
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
AggregateSaveOpenArrayDimension:
            LD   A,(AggregateTypeDimensionCount)
            LD   B,A
            LD   A,(AggregateTypeOpenArrayFlag)
            OR   B
            JP   NZ,AggregateTypeShapeFailure
            CALL AggregateRejectOpenViewCurrent
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   DE,AggregateTypeOpenArrayPosition
            CALL CompilerCopyTokenPosition
            LD   A,1
            LD   (AggregateTypeOpenArrayFlag),A
            OR   A
            RET

; Owning and result positions historically diagnose an illegal open array at
; its closing bracket. The recursive suffix collector has already buffered the
; following token, so restore the retained suffix position only for an open
; array; concrete types and string[] keep their existing diagnostic positions.
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
AggregateRejectOpenViewPlacement:
            LD   A,(AggregateCurrentTypeId)
            OR   A
            JP   P,AggregateRejectOpenViewCurrent
            LD   HL,AggregateTypeOpenArrayPosition
            CALL CompilerRestoreTokenPosition
            JR   AggregateRejectOpenViewCurrent

; Wrap AggregateCurrentTypeId in one concrete array dimension. HL is the
; dimension length and the previous current type becomes the exact element ID.
.routine in HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
AggregateWrapArrayCurrent:
            CALL AggregateRejectOpenViewCurrent
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   (AggregateCandidateAux),A
            LD   (AggregateCandidateLength),HL
            LD   B,H
            LD   C,L
            LD   A,(AggregateCandidateAux)
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
            LD   (AggregateCandidateExtent),HL
            LD   A,AggregateTypeKindArray
            LD   (AggregateCandidateKind),A
            CALL AggregateInternType
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   (AggregateCurrentTypeId),A
            OR   A
            RET

; Apply saved concrete dimensions from innermost to outermost, then apply an
; optional outer open view. The buffer itself stays outside source-visible
; type identity and is reused by the next type parse.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
AggregateFinishArrayType:
            LD   A,(AggregateTypeDimensionCount)
            OR   A
            JR   Z,AggregateFinishArrayOpen
            LD   DE,(TokenStartOffset)
            LD   (AggregateTypeResumeOffset),DE
            LD   B,A
            ADD  A,A
            ADD  A,A
            LD   E,A
            LD   D,0
            LD   HL,AggregateTypeDimensionBase
            ADD  HL,DE
AggregateFinishArrayLoop:
            DEC  HL
            LD   D,(HL)
            DEC  HL
            LD   E,(HL)
            LD   (TokenStartOffset),DE
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
            LD   DE,(AggregateTypeResumeOffset)
            LD   (TokenStartOffset),DE
AggregateFinishArrayOpen:
            LD   A,(AggregateTypeOpenArrayFlag)
            OR   A
            JR   Z,AggregateFinishArrayReady
            CALL AggregateRejectOpenViewCurrent
.if CompilerDiagnosticReturns
            RET  C
.endif
            OR   AggregateOpenArrayTypeMask
            LD   (AggregateCurrentTypeId),A
AggregateFinishArrayReady:
            LD   A,(AggregateCurrentTypeId)
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
            LD   B,DiagnosticProgramDataCapacity
            JR   AggregateCheckSegmentedCapacity

.routine in HL out A,HL,carry,zero clobbers sign,parity,halfCarry,B
AggregateCheckReadOnlyCapacity:
            LD   B,DiagnosticReadOnlyCapacity
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
            JP   CompilerSetDiagnostic
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
            CALL SetDiagInline
            .db  DiagnosticProgramDataCapacity

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
            CALL SetDiagInline
            .db  DiagnosticReadOnlyCapacity
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
            CALL SetDiagInline
            .db  DiagnosticProgramDataCapacity
.endif

.if HybridLL1Full
AggregateTypeShapeFailure:
            CALL SetDiagInline
            .db  DiagnosticTypeBound
AggregateProgramDataCapacityFailure:
            CALL SetDiagInline
            .db  DiagnosticProgramDataCapacity
AggregateStringCapacityFailure:
            CALL SetDiagInline
            .db  DiagnosticStringCapacity
.else
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
AggregateParseBound:
            LD   A,ScalarTypeU16
            CALL TypedExpressionBeginConstant
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   D,A
            AND  ScalarMetaConstant
            JP   Z,AggregateTypeShapeFailure
            LD   E,ScalarTypeU16
            LD   A,D
            CALL TypedCheckAssignable
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,H
            OR   L
            JR   Z,AggregateTypeShapeFailure
            PUSH HL
            LD   E,TokenRightBracket
            CALL ParserExpect
            POP  HL
            RET

AggregateTypeShapeFailure:
            CALL SetDiagInline
            .db  DiagnosticTypeBound

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
            CP   TokenU8
            JR   Z,AggregateTypeU8
            CP   TokenU16
            JR   Z,AggregateTypeU16
            CP   TokenI8
            JR   Z,AggregateTypeI8
            CP   TokenI16
            JR   Z,AggregateTypeI16
            CP   TokenBoolean
            JR   Z,AggregateTypeBoolean
            CP   TokenString
            JR   Z,AggregateParseStringType
            CP   TokenName
            JR   NZ,AggregateTypeShapeFailure
            CALL SymbolLookupCurrent
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   D,A
            AND  SymbolRecordTypeFlag+SymbolAggregateFlag
            CP   SymbolRecordTypeFlag
            JR   NZ,AggregateTypeShapeFailure
            LD   A,C
            JR   AggregateTypeBaseReady
AggregateTypeU8:
            LD   A,AggregateTypeIdU8
            JR   AggregateTypeBaseReady
AggregateTypeU16:
            LD   A,AggregateTypeIdU16
            JR   AggregateTypeBaseReady
AggregateTypeI8:
            LD   A,AggregateTypeIdI8
            JR   AggregateTypeBaseReady
AggregateTypeI16:
            LD   A,AggregateTypeIdI16
            JR   AggregateTypeBaseReady
AggregateTypeBoolean:
            LD   A,AggregateTypeIdBoolean
            JR   AggregateTypeBaseReady
AggregateParseStringType:
            LD   E,TokenLeftBracket
            CALL ParserExpect
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
            LD   (AggregateCandidateAux),A
            LD   (AggregateCandidateLength),HL
            LD   A,AggregateTypeKindString
            LD   (AggregateCandidateKind),A
            INC  HL
            INC  HL
            LD   (AggregateCandidateExtent),HL
            CALL AggregateInternType
.if CompilerDiagnosticReturns
            RET  C
.endif
AggregateTypeBaseReady:
            LD   (AggregateCurrentTypeId),A
AggregateParseArraySuffixLoop:
            CALL ParserPeek
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TokenLeftBracket
            JR   Z,AggregateParseArraySuffix
            JP   AggregateFinishArrayType
AggregateParseArraySuffix:
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ParserPeek
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TokenRightBracket
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
            CALL SetDiagInline
            .db  DiagnosticProgramDataCapacity
AggregateStringCapacityFailure:
            CALL SetDiagInline
            .db  DiagnosticStringCapacity
.endif

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
AggregateCheckFieldDuplicate:
            LD   A,(AggregateCurrentFieldCount)
            OR   A
            RET  Z
            LD   C,A
            LD   A,(AggregateCurrentFieldStart)
AggregateFieldDuplicateLoop:
            PUSH AF
            PUSH BC
            CALL AggregateFieldAddress
            CALL TokenNameRecordEquals
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
            CALL SetDiagInline
            .db  DiagnosticRecordEmpty
.else
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
AggregateParseRecordAfterTake:
            LD   E,TokenName
            CALL ParserExpect
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL TypedRetainDeclarationName
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(AggregateTypeCount)
            CP   AggregateTypeCapacity
            JP   NC,AggregateTypeCapacityFailure
            LD   A,(AggregateRecordCount)
            CP   AggregateRecordCapacity
            JP   NC,AggregateTypeCapacityFailure
            CALL ParserExpectLine
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(AggregateFieldCount)
            LD   (AggregateCurrentFieldStart),A
            XOR  A
            LD   (AggregateCurrentFieldCount),A
            LD   H,A
            LD   L,A
            LD   (AggregateCurrentRecordExtent),HL
AggregateRecordFieldLoop:
            CALL ParserPeek
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TokenEnd
            JR   Z,AggregateRecordFinish
            CP   TokenName
            JP   NZ,AggregateTypeShapeFailure
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL AggregateCheckFieldDuplicate
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(AggregateFieldCount)
            LD   B,A
            LD   A,(AggregateCurrentFieldCount)
            ADD  A,B
            CP   AggregateFieldCapacity
            JP   NC,AggregateTypeCapacityFailure
            PUSH AF
            CALL AggregateFieldAddress
            CALL TokenRetainNameAtHL
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
            LD   DE,(AggregateCurrentRecordExtent)
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
            LD   (AggregateCurrentRecordExtent),HL
            CALL ParserExpectLine
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,AggregateCurrentFieldCount
            INC  (HL)
            JR   AggregateRecordFieldLoop
AggregateRecordFinish:
            LD   A,(AggregateCurrentFieldCount)
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
            LD   A,AggregateTypeKindRecord
            LD   (AggregateCandidateKind),A
            LD   A,(AggregateCurrentFieldStart)
            LD   (AggregateCandidateAux),A
            LD   A,(AggregateCurrentFieldCount)
            LD   (AggregateCandidateLength),A
            XOR  A
            LD   (AggregateCandidateLength+1),A
            LD   HL,(AggregateCurrentRecordExtent)
            LD   (AggregateCandidateExtent),HL
            CALL AggregateAppendType
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   (AggregateCurrentTypeId),A
            LD   D,SymbolInfoRecordType
            LD   A,(AggregateCurrentTypeId)
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
            LD   A,(AggregateCurrentFieldCount)
            LD   HL,AggregateFieldCount
            ADD  A,(HL)
            LD   (HL),A
            LD   HL,AggregateRecordCount
            INC  (HL)
.if AggregateCallSlices
            JP   Stage7ParseTopLevel
.else
            JP   TypedParseTopLevel
.endif
AggregateRecordEmptyFailure:
            CALL SetDiagInline
            .db  DiagnosticRecordEmpty
.endif

AggregateInitializerCapacityFailure:
            CALL SetDiagInline
            .db  DiagnosticInitializerCapacity

.routine out A,carry,zero clobbers sign,parity,halfCarry,HL
AggregateInitializerLeave:
            LD   HL,AggregateInitializerDepth
            DEC  (HL)
            OR   A
            RET

.routine in A out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
AggregateWriteByte:
            LD   B,A
            LD   HL,(AggregateCurrentObjectOffset)
            LD   DE,AggregateInitializerBase
            ADD  HL,DE
            LD   A,B
            LD   (HL),A
            LD   HL,(AggregateCurrentObjectOffset)
            INC  HL
            LD   (AggregateCurrentObjectOffset),HL
            OR   A
            RET

; Decode the already tokenized string literal directly from resident source.
; B is the fixed capacity. The enclosing object is already zeroed, so the
; final cursor advances over padding without rewriting it.
.routine in B out A,B,carry,zero clobbers sign,parity,halfCarry,C,D,DE,HL
AggregateDecodeString:
            LD   A,(TokenLength)
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
            LD   HL,(TokenLexemePointer)
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
            CALL TokenIsHexDigit
            ADD  A,A
            ADD  A,A
            ADD  A,A
            ADD  A,A
            LD   D,A
            LD   A,(HL)
            INC  HL
            CALL TokenIsHexDigit
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
            LD   HL,(AggregateCurrentObjectOffset)
            ADD  HL,DE
            LD   (AggregateCurrentObjectOffset),HL
            OR   A
            RET

AggregateInitializerShapeFailure:
            CALL SetDiagInline
            .db  DiagnosticInitializerShape
AggregateInitializerCountFailure:
            CALL SetDiagInline
            .db  DiagnosticInitializerCount

.routine out A,BC,carry,zero clobbers sign,parity,halfCarry,D,DE,HL
AggregatePeekPreserveBC:
            PUSH BC
            CALL ParserPeek
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
            CP   TokenComma
            JR   NZ,AggregateInitializerShapeFailure
            JR   AggregateTakePreserveBC

; Parse one type-directed static initializer at the current image cursor.
.routine in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
AggregateParseInitializer:
            CP   AggregateFirstDynamicTypeId
            JR   C,AggregateParseScalarInitializer
            PUSH AF
            CALL AggregateTypeAddress
            LD   A,(HL)
            POP  DE
            LD   E,D
            LD   D,0
            CP   AggregateTypeKindString
            JR   Z,AggregateParseStringInitializer
            CP   AggregateTypeKindRecord
            JR   Z,AggregateParseRecordInitializer
            CP   AggregateTypeKindArray
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
            AND  ScalarMetaConstant
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
            LD   E,TokenStringLiteral
            CALL ParserExpect
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(TokenLength)
            CP   B
            JR   C,AggregateParseStringDecode
            JR   Z,AggregateParseStringDecode
            CALL SetDiagInline
            .db  DiagnosticStringLength
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
            JR   NZ,AggregateInitializerShapeFailure
.else
            JP   NZ,AggregateInitializerShapeFailure
.endif
            CALL AggregateTakePreserveBC
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(AggregateInitializerDepth)
            CP   AggregateInitializerDepthCapacity
            JP   NC,AggregateInitializerCapacityFailure
            INC  A
            LD   (AggregateInitializerDepth),A
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
            LD   A,TokenLeftParen
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
            CP   TokenRightParen
            CALL AggregateExpectCommaPreserveBC
.if CompilerDiagnosticReturns
            RET  C
.endif
            JR   AggregateRecordInitializerLoop
AggregateRecordInitializerExpectClose:
            LD   BC,(TokenRightParen<<8)|TokenRightBracket
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
            LD   A,TokenLeftBracket
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
            CP   TokenRightBracket
            PUSH DE
            CALL AggregateExpectCommaPreserveBC
            POP  DE
.if CompilerDiagnosticReturns
            RET  C
.endif
            JR   AggregateArrayInitializerLoop
AggregateArrayInitializerExpectClose:
            LD   BC,(TokenRightBracket<<8)|TokenRightParen

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

; Zero exactly the candidate object's complete extent before applying an
; explicit initializer. This also defines every byte of a zero initializer.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
AggregateZeroCurrentObject:
            LD   HL,(AggregateCurrentObjectOffset)
            LD   DE,AggregateInitializerBase
            ADD  HL,DE
            LD   BC,(AggregateCurrentObjectExtent)
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
            LD   (AggregateCurrentTypeId),A
            CALL AggregateGetExtent
            LD   (AggregateCurrentObjectExtent),HL
            LD   DE,(StaticImageLength)
            LD   (AggregateCurrentObjectOffset),DE
            ADD  HL,DE
            JP   C,AggregateProgramDataCapacityFailure
            LD   A,H
            OR   A
            JP   NZ,AggregateProgramDataCapacityFailure
            LD   (AggregateCurrentObjectEnd),HL
            CALL AggregateZeroCurrentObject
.if CompilerDiagnosticReturns
            RET  C
.endif
            XOR  A
            LD   (AggregateInitializerDepth),A
            LD   (AggregateHasInitializer),A
            CALL ParserPeek
.if CompilerDiagnosticReturns
            RET  C
.endif
            CP   TokenEquals
            JR   NZ,AggregateProgramInitializerDone
            CALL ParserTake
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,(StaticImageLength)
            LD   (AggregateCurrentObjectOffset),HL
            LD   A,(AggregateCurrentTypeId)
            LD   B,A
            PUSH BC
            CALL AggregateParseInitializer
.if CompilerDiagnosticBranches
            JR   C,AggregateProgramInitializerFailure
.endif
            POP  BC
            LD   A,1
            LD   (AggregateHasInitializer),A
            LD   A,B
            LD   (AggregateCurrentTypeId),A
            LD   HL,(AggregateCurrentObjectOffset)
            LD   DE,(AggregateCurrentObjectEnd)
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
            LD   BC,(StaticImageLength)
            LD   A,(AggregateCurrentTypeId)
            CP   AggregateFirstDynamicTypeId
            JR   C,AggregateProgramScalarInfo
            LD   D,SymbolInfoAggregateProgram
            JR   AggregateProgramPrepareSymbol
AggregateProgramScalarInfo:
            OR   SymbolClassProgram
            LD   D,A
AggregateProgramPrepareSymbol:
            PUSH BC
            CALL TypedPrepareCurrentWord
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(AggregateCurrentTypeId)
            INC  HL
            LD   (HL),A
            CALL SymbolCommit
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,(AggregateCurrentObjectEnd)
            LD   (StaticImageLength),HL
            LD   A,L
            LD   (NextProgramSlot),A
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
            LD   (AggregateMode),A
.if HybridLL1Full
            XOR  A
            LD   (Stage7CurrentRoutine),A
            CALL HybridLL1Parse
.else
            CALL ParserParseProgram
.endif
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   SemanticSinkFinish
.endif
