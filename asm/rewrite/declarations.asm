; R3 bounded declaration directories. These routines retain source identity and
; layout facts only; declaration grammar/actions are layered on them later.

.routine in A out A,HL clobbers carry,zero,sign,parity,halfCarry,DE
RewriteRecordAddress:
            ADD  A,A
            LD   E,A
            LD   D,0
            LD   HL,RewriteRecordTableBase
            ADD  HL,DE
            RET

.routine in A out A,HL clobbers carry,zero,sign,parity,halfCarry,DE
RewriteFieldAddress:
            LD   E,A
            LD   D,0
            ADD  A,A
            ADD  A,E
            ADD  A,A
            LD   E,A
            LD   HL,RewriteFieldTableBase
            ADD  HL,DE
            RET

.routine in A out A,HL clobbers carry,zero,sign,parity,halfCarry,DE
RewriteRoutineAddress:
            LD   L,A
            LD   H,0
            ADD  HL,HL
            ADD  HL,HL
            ADD  HL,HL
            LD   DE,RewriteRoutineTableBase
            ADD  HL,DE
            RET

.routine in A out A,HL clobbers carry,zero,sign,parity,halfCarry,DE
RewriteParameterAddress:
            LD   L,A
            LD   H,0
            ADD  HL,HL
            ADD  HL,HL
            LD   DE,RewriteParameterTableBase
            ADD  HL,DE
            RET

.routine in A out A,HL clobbers carry,zero,sign,parity,halfCarry,DE
RewriteSuffixAddress:
            LD   L,A
            LD   H,0
            ADD  HL,HL
            ADD  HL,HL
            LD   DE,RewriteSuffixTableBase
            ADD  HL,DE
            RET

; Begin one provisional record layout. Its fields become visible to the type
; only when RewriteRecordCommit succeeds.
.routine out A,HL,carry,zero clobbers sign,parity,halfCarry,DE
RewriteRecordBegin:
            LD   A,(RewriteRecordCount)
            CP   RewriteRecordCapacity
            JR   NC,RewriteDeclarationTypeCapacityFailure
            LD   (RewriteCurrentRecord),A
            CALL RewriteRecordAddress
            LD   A,(RewriteFieldCount)
            LD   (HL),A
            INC  HL
            LD   (HL),0
            XOR  A
            RET

; Carry returns an existing field of the current record in HL.
.routine out A,HL,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE
RewriteFieldFindCurrent:
            LD   A,(RewriteCurrentRecord)
            CALL RewriteRecordAddress
            LD   C,(HL)
            INC  HL
            LD   B,(HL)
            LD   A,B
            OR   A
            RET  Z
            LD   A,C
            CALL RewriteFieldAddress
RewriteFieldFindLoop:
            PUSH BC
            CALL RewriteSymbolNameEquals
            POP  BC
            RET  C
            LD   DE,RewriteFieldEntrySize
            ADD  HL,DE
            DJNZ RewriteFieldFindLoop
            OR   A
            RET

; Check and retain one provisional field name before parsing its type. This
; preserves duplicate-before-type diagnostic precedence without publishing the
; field count.
.routine out A,carry,zero,HL clobbers sign,parity,halfCarry,B,C,D,DE
RewriteFieldPrepareCurrent:
            CALL RewriteFieldFindCurrent
            JP   C,RewriteFieldDuplicate
            LD   A,(RewriteFieldCount)
            CP   RewriteFieldCapacity
            JP   NC,RewriteDeclarationTypeCapacityFailure
            CALL RewriteFieldAddress
            LD   DE,(TokenLexemePointer)
            LD   (HL),E
            INC  HL
            LD   (HL),D
            INC  HL
            LD   A,(TokenLength)
            LD   (HL),A
            XOR  A
            RET

; A is the exact field type and BC is its full-word byte offset. The name has
; already been prepared at RewriteFieldCount and remains unpublished until this
; routine advances both field counters.
.routine in A,BC out A,carry,zero,HL clobbers sign,parity,halfCarry,B,C,D,DE
RewriteFieldCommitCurrent:
            PUSH AF
            LD   A,(RewriteFieldCount)
            CALL RewriteFieldAddress
            LD   DE,RewriteFieldType
            ADD  HL,DE
            POP  AF
            LD   (HL),A
            INC  HL
            LD   (HL),C
            INC  HL
            LD   (HL),B
            LD   HL,RewriteFieldCount
            INC  (HL)
            LD   A,(RewriteCurrentRecord)
            CALL RewriteRecordAddress
            INC  HL
            INC  (HL)
            XOR  A
            RET

; Compatibility entry retained for direct directory users.
.routine in A,BC out A,carry,zero,HL clobbers sign,parity,halfCarry,B,C,D,DE
RewriteFieldAppendCurrent:
            PUSH AF
            PUSH BC
            CALL RewriteFieldPrepareCurrent
            POP  BC
            POP  AF
            JP   RewriteFieldCommitCurrent
RewriteFieldDuplicate:
            LD   A,DiagnosticDuplicateName
            JP   RewriteRaiseDiagnostic
RewriteDeclarationTypeCapacityFailure:
            LD   A,DiagnosticTypeMetadataCapacity
            JP   RewriteRaiseDiagnostic

.routine out A,carry,zero clobbers sign,parity,halfCarry,DE,HL
RewriteRecordCommit:
            LD   A,(RewriteCurrentRecord)
            CALL RewriteRecordAddress
            INC  HL
            LD   A,(HL)
            OR   A
            JR   Z,RewriteRecordEmptyFailure
            LD   HL,RewriteRecordCount
            INC  (HL)
            XOR  A
            RET
RewriteRecordEmptyFailure:
            LD   A,DiagnosticRecordEmpty
            JP   RewriteRaiseDiagnostic

; Carry returns a retained routine match in HL.
.routine out A,HL,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE
RewriteRoutineFindCurrent:
            LD   A,(RewriteRoutineCount)
            OR   A
            RET  Z
            LD   (RewriteRoutineLookupRemaining),A
            XOR  A
            LD   (RewriteRoutineLookupCursor),A
RewriteRoutineFindLoop:
            LD   A,(RewriteRoutineLookupCursor)
            CALL RewriteRoutineAddress
            CALL RewriteSymbolNameEquals
            JR   C,RewriteRoutineFindFound
            LD   HL,RewriteRoutineLookupCursor
            INC  (HL)
            LD   HL,RewriteRoutineLookupRemaining
            DEC  (HL)
            JR   NZ,RewriteRoutineFindLoop
            OR   A
            RET
RewriteRoutineFindFound:
            LD   A,(RewriteRoutineLookupCursor)
            SCF
            RET

; Carry returns the exact source spelling `main`.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteNameEqualsMain:
            LD   A,(TokenLength)
            CP   4
            JR   NZ,RewriteNameEqualsMainDifferent
            LD   HL,(TokenLexemePointer)
            LD   DE,RewriteNameMain
            LD   B,4
RewriteNameEqualsMainLoop:
            LD   A,(DE)
            CP   (HL)
            JR   NZ,RewriteNameEqualsMainDifferent
            INC  DE
            INC  HL
            DJNZ RewriteNameEqualsMainLoop
            SCF
            RET
RewriteNameEqualsMainDifferent:
            OR   A
            RET

; Carry returns a dense predefined ordinal in A. The table contains source
; spellings only and is independent of its assembled address.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewritePredefinedFindCurrent:
            LD   HL,RewritePredefinedTable
            LD   C,RewritePredefinedCount
RewritePredefinedFindLoop:
            LD   B,(HL)
            INC  HL
            LD   A,(TokenLength)
            CP   B
            JR   NZ,RewritePredefinedSkip
            LD   DE,(TokenLexemePointer)
RewritePredefinedFindByte:
            LD   A,(DE)
            CP   (HL)
            JR   NZ,RewritePredefinedSkip
            INC  DE
            INC  HL
            DJNZ RewritePredefinedFindByte
            LD   A,RewritePredefinedCount
            SUB  C
            SCF
            RET
RewritePredefinedSkip:
            LD   E,B
            LD   D,0
            ADD  HL,DE
            DEC  C
            JR   NZ,RewritePredefinedFindLoop
            OR   A
            RET

; Ordinary declarations and parameters share one complete source namespace:
; active symbols, retained routines, predefined names, and main.
.routine out A,carry,zero,HL clobbers sign,parity,halfCarry,B,C,D,DE
RewriteDeclarationRejectCurrent:
            CALL RewriteSymbolRejectCurrent
            CALL RewriteRoutineFindCurrent
            JR   C,RewriteDeclarationDuplicate
            CALL RewritePredefinedFindCurrent
            JR   C,RewriteDeclarationDuplicate
            CALL RewriteNameEqualsMain
            RET  NC
RewriteDeclarationDuplicate:
            LD   A,DiagnosticDuplicateName
            JP   RewriteRaiseDiagnostic

; B=result type, C=label, D=flags. The entry stays provisional until commit.
.routine in B,C,D out A,carry,zero,HL clobbers sign,parity,halfCarry,B,C,D,DE
RewriteRoutineBeginCurrent:
            LD   A,(RewriteRoutineCount)
            CP   RewriteRoutineCapacity
            JR   NC,RewriteRoutineCapacityFailure
            PUSH BC
            PUSH DE
            CALL RewriteRoutineFindCurrent
            JR   C,RewriteRoutineDuplicate
            POP  DE
            POP  BC
            LD   A,(RewriteRoutineCount)
            LD   (RewriteCurrentRoutine),A
            PUSH BC
            PUSH DE
            CALL RewriteRoutineAddress
            POP  DE
            POP  BC
            PUSH DE
            LD   DE,(TokenLexemePointer)
            LD   (HL),E
            INC  HL
            LD   (HL),D
            INC  HL
            LD   A,(TokenLength)
            LD   (HL),A
            INC  HL
            POP  DE
            LD   A,(RewriteParameterCount)
            LD   (HL),A
            INC  HL
            LD   (HL),0
            INC  HL
            LD   (HL),B
            INC  HL
            LD   (HL),C
            INC  HL
            LD   (HL),D
            LD   A,(RewriteSymbolCount)
            LD   (RewriteSymbolScopeBase),A
            XOR  A
            LD   (RewriteCurrentLocalOffset),A
            RET
RewriteRoutineDuplicate:
            POP  DE
            POP  BC
            LD   A,DiagnosticDuplicateName
            JP   RewriteRaiseDiagnostic
RewriteRoutineCapacityFailure:
            LD   A,DiagnosticRoutineCapacity
            JP   RewriteRaiseDiagnostic

; Begin a new non-main routine through the complete declaration namespace.
; B=result type, C=label, and D=flags retain the directory ABI.
.routine in B,C,D out A,carry,zero,HL clobbers sign,parity,halfCarry,B,C,D,DE
RewriteRoutineDeclareBeginCurrent:
            LD   A,(RewriteRoutineCount)
            CP   RewriteRoutineCapacity
            JP   NC,RewriteRoutineCapacityFailure
            PUSH BC
            PUSH DE
            CALL RewriteDeclarationRejectCurrent
            POP  DE
            POP  BC
            JP   RewriteRoutineBeginCurrent

; A is the retained parameter type. Active symbol publication is deliberately
; separate so its scoped payload can be assigned by the declaration action.
.routine in A out A,carry,zero,HL clobbers sign,parity,halfCarry,DE
RewriteParameterAppendCurrent:
            PUSH AF
            LD   A,(RewriteParameterCount)
            CP   RewriteParameterCapacity
            JR   NC,RewriteParameterCapacityFailure
            CALL RewriteParameterAddress
            LD   DE,(TokenLexemePointer)
            LD   (HL),E
            INC  HL
            LD   (HL),D
            INC  HL
            LD   A,(TokenLength)
            LD   (HL),A
            INC  HL
            POP  AF
            LD   (HL),A
            LD   HL,RewriteParameterCount
            INC  (HL)
            LD   A,(RewriteCurrentRoutine)
            CALL RewriteRoutineAddress
            LD   DE,RewriteRoutineParameterCount
            ADD  HL,DE
            INC  (HL)
            XOR  A
            RET
RewriteParameterCapacityFailure:
            POP  AF
            LD   A,DiagnosticParameterCapacity
            JP   RewriteRaiseDiagnostic

; A is the retained parameter type. Header checking rejects the complete
; namespace and earlier parameters before retaining the spelling and type.
; Scoped parameter symbols are published together only when the body opens.
.routine in A out A,carry,zero,HL clobbers sign,parity,halfCarry,B,C,D,DE,IX,IY
RewriteParameterDeclareCurrent:
            LD   (RewritePendingParameterType),A
            CALL RewriteParameterRejectCurrent
            LD   A,(RewritePendingParameterType)
            CALL RewriteParameterAppendCurrent
            XOR  A
            RET

; Parameters also reject the routine whose signature is still provisional and
; therefore not yet included in RewriteRoutineCount.
.routine out A,carry,zero,HL clobbers sign,parity,halfCarry,B,C,D,DE,IX,IY
RewriteParameterRejectCurrent:
            CALL RewriteDeclarationRejectCurrent
            LD   A,(RewriteCurrentRoutine)
            LD   B,A
            LD   A,(RewriteRoutineCount)
            CP   B
            JR   NZ,RewriteParameterRejectRetained
            LD   A,B
            CALL RewriteRoutineAddress
            CALL RewriteSymbolNameEquals
            JR   NC,RewriteParameterRejectRetained
RewriteParameterDuplicate:
            LD   A,DiagnosticDuplicateName
            JP   RewriteRaiseDiagnostic
RewriteParameterRejectRetained:
            LD   A,(RewriteCurrentRoutine)
            CALL RewriteRoutineAddress
            LD   DE,RewriteRoutineParameterStart
            ADD  HL,DE
            LD   C,(HL)
            INC  HL
            LD   B,(HL)
            LD   A,B
            OR   A
            RET  Z
            LD   A,C
            CALL RewriteParameterAddress
RewriteParameterRejectRetainedLoop:
            PUSH BC
            CALL RewriteSymbolNameEquals
            POP  BC
            JR   C,RewriteParameterDuplicate
            LD   DE,RewriteParameterEntrySize
            ADD  HL,DE
            DJNZ RewriteParameterRejectRetainedLoop
            OR   A
            RET

; Parameter activation widths are independent of the owned object extent:
; scalars use 1/2 bytes, concrete aliases 2, open string 3, open arrays 4.
.routine in A out A,carry,zero clobbers sign,parity,halfCarry
RewriteParameterActivationWidth:
            BIT  7,A
            JR   Z,RewriteParameterWidthNotOpenArray
            LD   A,4
            RET
RewriteParameterWidthNotOpenArray:
            CP   RewriteOpenStringTypeId
            JR   NZ,RewriteParameterWidthNotOpenString
            LD   A,3
            RET
RewriteParameterWidthNotOpenString:
            CP   RewriteFirstOwnedTypeId
            JR   C,RewriteParameterWidthScalar
            LD   A,2
            RET
RewriteParameterWidthScalar:
            AND  RewriteScalarTypeBaseMask
            CP   RewriteScalarTypeU16
            LD   A,1
            RET  NZ
            INC  A
            RET

; Return the positive IX displacement of a source argument in C. B is the
; number of parameters from the current one through the last, and D is the
; current retained-parameter ordinal. Every source parameter occupies one
; target-stack word; each later open view contributes its hidden count or
; capacity word as well. This is intentionally separate from the local
; activation offset used as the active parameter-symbol payload.
.routine in B,D out A,C,carry,zero clobbers sign,parity,halfCarry,B,D,E,HL
RewriteParameterSourceOffset:
            LD   A,B
            ADD  A,A
            ADD  A,2
            LD   C,A
            DEC  B
            JR   Z,RewriteParameterSourceOffsetDone
            LD   A,D
            INC  A
            CALL RewriteParameterAddress
RewriteParameterSourceOffsetLoop:
            INC  HL
            INC  HL
            INC  HL
            LD   A,(HL)
            CP   RewriteOpenStringTypeId
            JR   C,RewriteParameterSourceOffsetNext
            INC  C
            INC  C
RewriteParameterSourceOffsetNext:
            INC  HL
            DJNZ RewriteParameterSourceOffsetLoop
RewriteParameterSourceOffsetDone:
            LD   A,C
            OR   A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,HL
RewriteRoutinePublishSignature:
            LD   HL,RewriteRoutineCount
            INC  (HL)
            XOR  A
            RET

; Direct bodies publish the complete signature first, then make every formal
; parameter visible together. Header expressions therefore cannot resolve an
; earlier parameter as a type or array bound.
.routine out A,carry,zero,HL clobbers sign,parity,halfCarry,B,C,D,DE,IX,IY
RewriteRoutinePublish:
            CALL RewriteRoutinePublishSignature
            CALL RewriteRoutinePrepareParameterInstall
            JP   RewriteRoutineInstallForwardParameters

.routine out A,carry,zero clobbers sign,parity,halfCarry
RewriteRoutineCloseScope:
            LD   A,(RewriteSymbolScopeBase)
            LD   (RewriteSymbolCount),A
            XOR  A
            LD   (RewriteCurrentRoutineFlags),A
            LD   (RewriteCurrentRoutineResultType),A
            LD   (RewriteControlSequenceFallsThrough),A
            RET

; Every direct or completed-forward body starts with a reachable empty
; statement sequence. Structured statements refine this one-byte summary.
.routine out A,carry,zero clobbers sign,parity,halfCarry
RewriteRoutineBeginBody:
            LD   A,1
            LD   (RewriteControlSequenceFallsThrough),A
            XOR  A
            RET

; Forward declarations publish and close in one action. Direct declarations
; publish before their body and call RewriteRoutineCloseScope only at `end`.
.routine out A,carry,zero clobbers sign,parity,halfCarry,HL
RewriteRoutineCommit:
            CALL RewriteRoutinePublishSignature
            JP   RewriteRoutineCloseScope

; Publish the parameters selected for a direct or forwarded body. Retained
; spellings are checked against the namespaces visible when that body opens.
.routine out A,carry,zero,HL clobbers sign,parity,halfCarry,B,C,D,DE,IX,IY
RewriteRoutineInstallForwardParameters:
RewriteRoutineOpenForwardParameterLoop:
            LD   A,(RewriteForwardParameterRemaining)
            OR   A
            RET  Z
            LD   A,(RewriteForwardParameterCursor)
            CALL RewriteParameterAddress
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            LD   (TokenLexemePointer),DE
            INC  HL
            LD   A,(HL)
            LD   (TokenLength),A
            INC  HL
            LD   A,(HL)
            LD   (RewriteForwardParameterType),A
            CALL RewriteDeclarationRejectCurrent
            LD   A,(RewriteForwardParameterType)
            LD   D,A
            LD   A,(RewriteCurrentLocalOffset)
            LD   C,A
            LD   B,0
            LD   A,RewriteSymbolClassParameter
            CALL RewriteSymbolPrepareCurrent
            CALL RewriteSymbolCommit
            LD   A,(RewriteForwardParameterType)
            CALL RewriteParameterActivationWidth
            LD   HL,RewriteCurrentLocalOffset
            ADD  A,(HL)
            LD   (HL),A
            LD   HL,RewriteForwardParameterCursor
            INC  (HL)
            LD   HL,RewriteForwardParameterRemaining
            DEC  (HL)
            JR   RewriteRoutineOpenForwardParameterLoop

.routine out A,carry,zero,HL clobbers sign,parity,halfCarry,B,C,D,DE,IX,IY
RewriteRoutineSelectForwardCurrent:
            PUSH BC
            PUSH DE
            CALL RewriteRoutineFindCurrent
            JR   C,RewriteRoutineSelectForwardFound
            POP  DE
            POP  BC
            JR   RewriteRoutineSelectForwardMissing
RewriteRoutineSelectForwardFound:
            POP  DE
            POP  BC
            LD   (RewriteCurrentRoutine),A
            PUSH HL
            LD   DE,RewriteRoutineResultType
            ADD  HL,DE
            LD   A,(HL)
            LD   (RewriteCurrentRoutineResultType),A
            POP  HL
            LD   DE,RewriteRoutineFlags
            ADD  HL,DE
            BIT  2,(HL)
            JR   Z,RewriteRoutineSelectForwardDuplicate
            RES  2,(HL)
            LD   A,(HL)
            LD   (RewriteCurrentRoutineFlags),A
            LD   A,(RewriteSymbolCount)
            LD   (RewriteSymbolScopeBase),A
            CALL RewriteRoutinePrepareParameterInstall
            JP   RewriteRoutineBeginBody
RewriteRoutineSelectForwardDuplicate:
            LD   A,DiagnosticDuplicateName
            OR   A
            RET
RewriteRoutineSelectForwardMissing:
            LD   A,DiagnosticUnknownName
            OR   A
            RET

.routine out A,carry,zero,HL clobbers sign,parity,halfCarry,B,C,D,DE,IX,IY
RewriteRoutineOpenForwardCurrent:
            CALL RewriteRoutineSelectForwardCurrent
            OR   A
            RET  Z
            JP   RewriteRaiseDiagnostic

.routine out A,carry,zero,HL clobbers sign,parity,halfCarry,DE
RewriteRoutinePrepareParameterInstall:
            XOR  A
            LD   (RewriteCurrentLocalOffset),A
            LD   A,(RewriteCurrentRoutine)
            CALL RewriteRoutineAddress
            LD   DE,RewriteRoutineParameterStart
            ADD  HL,DE
            LD   A,(HL)
            LD   (RewriteForwardParameterCursor),A
            INC  HL
            LD   A,(HL)
            LD   (RewriteForwardParameterRemaining),A
            XOR  A
            RET

; Successful EOF requires main first, then rejects any incomplete forward.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteRoutineRequireComplete:
            LD   A,(RewriteMainFlags)
            OR   A
            JR   Z,RewriteRoutineMissingMainFailure
            AND  RewriteRoutineFlagIncomplete
            JR   NZ,RewriteRoutineIncompleteFailure
            LD   A,(RewriteRoutineCount)
            LD   B,A
            XOR  A
            LD   C,A
RewriteRoutineRequireCompleteLoop:
            LD   A,B
            OR   A
            RET  Z
            LD   A,C
            CALL RewriteRoutineAddress
            LD   DE,RewriteRoutineFlags
            ADD  HL,DE
            LD   A,(HL)
            AND  RewriteRoutineFlagIncomplete
            JR   NZ,RewriteRoutineIncompleteFailure
            INC  C
            DEC  B
            JR   RewriteRoutineRequireCompleteLoop
RewriteRoutineIncompleteFailure:
            LD   A,DiagnosticForwardIncomplete
            JP   RewriteRaiseDiagnostic
RewriteRoutineMissingMainFailure:
            LD   A,DiagnosticExpectedTopLevel
            JP   RewriteRaiseDiagnostic

; Main is unique and deliberately outside the four-entry routine directory.
; D carries the source effect flags; the fixed main bit is added here.
.routine in D out A,D,carry,zero clobbers sign,parity,halfCarry,B,C,E,HL,IX,IY
RewriteMainRequireAvailable:
            LD   A,D
            LD   (RewritePendingRoutineFlags),A
            CALL RewriteNameEqualsMain
            JR   NC,RewriteMainNameFailure
            CALL RewriteSymbolRejectCurrent
            CALL RewriteRoutineFindCurrent
            JR   C,RewriteMainDuplicateFailure
            CALL RewritePredefinedFindCurrent
            JR   C,RewriteMainDuplicateFailure
            LD   A,(RewriteMainFlags)
            OR   A
            JR   NZ,RewriteMainDuplicateFailure
            LD   A,(RewriteSymbolCount)
            LD   (RewriteSymbolScopeBase),A
            XOR  A
            LD   (RewriteCurrentLocalOffset),A
            LD   A,(RewritePendingRoutineFlags)
            LD   D,A
            XOR  A
            RET
RewriteMainNameFailure:
            LD   A,DiagnosticUnknownName
            JP   RewriteRaiseDiagnostic
RewriteMainDuplicateFailure:
            LD   A,DiagnosticDuplicateName
            JP   RewriteRaiseDiagnostic

.routine in D out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteMainBeginCurrent:
            CALL RewriteMainRequireAvailable
            LD   A,D
            OR   RewriteRoutineFlagMain
            LD   (RewriteMainFlags),A
            LD   (RewriteCurrentRoutineFlags),A
            XOR  A
            LD   (RewriteCurrentRoutineResultType),A
            JP   RewriteRoutineBeginBody

.routine in D out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteMainBeginForwardCurrent:
            CALL RewriteMainRequireAvailable
            LD   A,D
            OR   RewriteRoutineFlagMain+RewriteRoutineFlagIncomplete
            LD   (RewriteMainFlags),A
            XOR  A
            RET

; The abbreviated `sub main` body clears only the incomplete bit and retains
; the declared `fails` effect. A missing or already completed forward is not a
; second declaration and therefore reports unknown-name 57.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteMainOpenForwardCurrent:
            CALL RewriteNameEqualsMain
            JR   NC,RewriteMainNameFailure
            LD   A,(RewriteMainFlags)
            BIT  2,A
            JR   Z,RewriteMainNameFailure
            AND  $FF-RewriteRoutineFlagIncomplete
            LD   (RewriteMainFlags),A
            LD   (RewriteCurrentRoutineFlags),A
            LD   A,(RewriteSymbolCount)
            LD   (RewriteSymbolScopeBase),A
            XOR  A
            LD   (RewriteCurrentLocalOffset),A
            LD   (RewriteCurrentRoutineResultType),A
            JP   RewriteRoutineBeginBody

.routine out A,carry,zero clobbers sign,parity,halfCarry
RewriteSuffixBegin:
            XOR  A
            LD   (RewriteSuffixCount),A
            LD   (RewriteSuffixOpen),A
            RET

; HL is a positive concrete element count; DE is its source offset.
.routine in HL,DE out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
RewriteSuffixAppend:
            LD   B,H
            LD   C,L
            LD   A,(RewriteSuffixCount)
            CP   RewriteSuffixCapacity
            JP   NC,RewriteDeclarationTypeCapacityFailure
            PUSH DE
            CALL RewriteSuffixAddress
            POP  DE
            LD   (HL),C
            INC  HL
            LD   (HL),B
            INC  HL
            LD   (HL),E
            INC  HL
            LD   (HL),D
            LD   HL,RewriteSuffixCount
            INC  (HL)
            XOR  A
            RET

; Open omission is legal only as the first and only omitted suffix. The later
; placement action restricts the completed view to a formal parameter.
.routine in HL out A,carry,zero clobbers sign,parity,halfCarry,B
RewriteSuffixSetOpen:
            LD   A,(RewriteSuffixCount)
            LD   B,A
            LD   A,(RewriteSuffixOpen)
            OR   B
            JR   NZ,RewriteSuffixShapeFailure
            LD   (RewriteSuffixOpenOffset),HL
            LD   A,1
            LD   (RewriteSuffixOpen),A
            XOR  A
            RET
RewriteSuffixShapeFailure:
            LD   A,DiagnosticTypeBound
            JP   RewriteRaiseDiagnostic
