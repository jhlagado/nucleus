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

; A is the exact field type and BC is its full-word byte offset.
.routine in A,BC out A,carry,zero,HL clobbers sign,parity,halfCarry,B,C,D,DE
RewriteFieldAppendCurrent:
            PUSH AF
            PUSH BC
            CALL RewriteFieldFindCurrent
            JR   C,RewriteFieldDuplicate
            POP  BC
            POP  AF
            PUSH AF
            LD   A,(RewriteFieldCount)
            CP   RewriteFieldCapacity
            JR   NC,RewriteFieldCapacityFailure
            CALL RewriteFieldAddress
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
RewriteFieldDuplicate:
            POP  BC
            POP  AF
            LD   A,DiagnosticDuplicateName
            JP   RewriteRaiseDiagnostic
RewriteFieldCapacityFailure:
            POP  AF
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
            LD   C,A
            LD   HL,RewriteRoutineTableBase
RewriteRoutineFindLoop:
            PUSH BC
            CALL RewriteSymbolNameEquals
            POP  BC
            RET  C
            LD   DE,RewriteRoutineEntrySize
            ADD  HL,DE
            DEC  C
            JR   NZ,RewriteRoutineFindLoop
            OR   A
            RET

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
            RET
RewriteRoutineDuplicate:
            POP  DE
            POP  BC
            LD   A,DiagnosticDuplicateName
            JP   RewriteRaiseDiagnostic
RewriteRoutineCapacityFailure:
            LD   A,DiagnosticRoutineCapacity
            JP   RewriteRaiseDiagnostic

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

.routine out A,carry,zero clobbers sign,parity,halfCarry,HL
RewriteRoutineCommit:
            LD   A,(RewriteSymbolScopeBase)
            LD   (RewriteSymbolCount),A
            LD   HL,RewriteRoutineCount
            INC  (HL)
            XOR  A
            RET

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
