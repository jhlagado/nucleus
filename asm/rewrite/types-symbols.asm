; R3 replacement type and symbol substrate.
;
; Composite descriptors are structural for arrays and bounded strings and
; nominal for records. All retained pointers are complete sixteen-bit values.

.routine in A out A,HL clobbers carry,zero,sign,parity,halfCarry,DE
RewriteTypeAddress:
            SUB  RewriteFirstOwnedTypeId
            LD   L,A
            LD   H,0
            ADD  HL,HL
            ADD  HL,HL
            LD   DE,RewriteTypeTableBase
            ADD  HL,DE
            RET

.routine in A out A,HL clobbers carry,zero,sign,parity,halfCarry,DE
RewriteTypeExtentAddress:
            SUB  RewriteFirstOwnedTypeId
            ADD  A,A
            LD   E,A
            LD   D,0
            LD   HL,RewriteTypeExtentBase
            ADD  HL,DE
            RET

; Carry means that A is an exact literal or parameter-only open view and has
; no owned static extent. Otherwise HL is the complete nonzero extent.
.routine in A out A,HL,carry,zero clobbers sign,parity,halfCarry,DE
RewriteTypeStaticExtent:
            AND  RewriteTypeIdentityMask
            CP   RewriteFirstOwnedTypeId
            JR   C,RewriteTypeScalarExtent
            CP   RewriteOwnedTypeLimitId
            JR   NC,RewriteTypeNoStaticExtent
            CALL RewriteTypeExtentAddress
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            EX   DE,HL
            OR   A
            RET
RewriteTypeScalarExtent:
            OR   A
            JR   Z,RewriteTypeNoStaticExtent
            AND  RewriteScalarTypeBaseMask
            LD   HL,1
            CP   RewriteScalarTypeU16
            JR   NZ,RewriteTypeStaticExtentReady
            INC  L
RewriteTypeStaticExtentReady:
            OR   A
            RET
RewriteTypeNoStaticExtent:
            SCF
            RET

; Append the candidate without searching. This gives every record declaration
; a nominal identity even when two layouts happen to match.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteTypeAppendNominal:
            LD   A,(RewriteTypeCount)
            CP   RewriteOwnedTypeCapacity
            JR   NC,RewriteTypeCapacityFailure
            ADD  A,RewriteFirstOwnedTypeId
            LD   C,A
            CALL RewriteTypeAddress
            LD   D,H
            LD   E,L
            LD   HL,RewriteTypeCandidate
            LD   BC,RewriteTypeDescriptorSize
            LDIR
            ; LDIR leaves BC zero, so recover the new type from the retained
            ; count rather than depending on an accidental register value.
            LD   A,(RewriteTypeCount)
            ADD  A,RewriteFirstOwnedTypeId
            LD   C,A
            CALL RewriteTypeExtentAddress
            LD   DE,(RewriteTypeCandidateExtent)
            LD   (HL),E
            INC  HL
            LD   (HL),D
            LD   HL,RewriteTypeCount
            INC  (HL)
            LD   A,C
            OR   A
            RET
RewriteTypeCapacityFailure:
            LD   A,DiagnosticTypeMetadataCapacity
            JP   RewriteRaiseDiagnostic

; Intern arrays and strings by complete descriptor and extent. Callers use the
; nominal append entry for records.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteTypeInternStructural:
            LD   A,(RewriteTypeCount)
            OR   A
            JR   Z,RewriteTypeAppendNominal
            LD   B,A
            LD   C,RewriteFirstOwnedTypeId
RewriteTypeInternLoop:
            PUSH BC
            LD   A,C
            CALL RewriteTypeAddress
            LD   DE,RewriteTypeCandidate
            LD   B,RewriteTypeDescriptorSize
RewriteTypeInternDescriptorLoop:
            LD   A,(DE)
            CP   (HL)
            JR   NZ,RewriteTypeInternDifferent
            INC  DE
            INC  HL
            DJNZ RewriteTypeInternDescriptorLoop
            POP  BC
            PUSH BC
            LD   A,C
            CALL RewriteTypeExtentAddress
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            LD   HL,(RewriteTypeCandidateExtent)
            OR   A
            SBC  HL,DE
            POP  BC
            JR   Z,RewriteTypeInternFound
            JR   RewriteTypeInternNext
RewriteTypeInternDifferent:
            POP  BC
RewriteTypeInternNext:
            INC  C
            DJNZ RewriteTypeInternLoop
            JR   RewriteTypeAppendNominal
RewriteTypeInternFound:
            LD   A,C
            OR   A
            RET

; Open array identities encode an element type, not an address. Carry rejects
; identities that cannot be represented without truncation or nesting an open
; view inside another open view.
.routine in A out A,carry,zero clobbers sign,parity,halfCarry
RewriteTypeMakeOpenArray:
            OR   A
            JR   Z,RewriteTypeOpenInvalid
            CP   RewriteOpenStringTypeId
            JR   NC,RewriteTypeOpenInvalid
            OR   RewriteOpenArrayFlag
            RET
RewriteTypeOpenInvalid:
            SCF
            RET

; A -> address of one seven-byte symbol entry.
.routine in A out A,HL clobbers carry,zero,sign,parity,halfCarry,DE
RewriteSymbolAddress:
            LD   L,A
            LD   H,0
            LD   E,L
            LD   D,H
            ADD  HL,HL
            ADD  HL,HL
            ADD  HL,HL
            OR   A
            SBC  HL,DE
            LD   DE,RewriteSymbolTableBase
            ADD  HL,DE
            RET

; Carry returns equality while preserving HL at the entry start.
.routine in HL out A,HL,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE
RewriteSymbolNameEquals:
            LD   (RewriteSymbolCompareEntry),HL
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            INC  HL
            LD   A,(TokenLength)
            CP   (HL)
            JR   NZ,RewriteSymbolNameDifferent
            LD   B,A
            LD   HL,(TokenLexemePointer)
            EX   DE,HL
RewriteSymbolNameLoop:
            LD   A,(DE)
            CP   (HL)
            JR   NZ,RewriteSymbolNameDifferent
            INC  DE
            INC  HL
            DJNZ RewriteSymbolNameLoop
            LD   HL,(RewriteSymbolCompareEntry)
            SCF
            RET
RewriteSymbolNameDifferent:
            LD   HL,(RewriteSymbolCompareEntry)
            OR   A
            RET

; Carry returns a committed match in HL. The provisional entry at count is
; deliberately excluded.
.routine out A,HL,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE
RewriteSymbolFindCurrent:
            LD   A,(RewriteSymbolCount)
            OR   A
            RET  Z
            LD   C,A
            LD   HL,RewriteSymbolTableBase
RewriteSymbolFindLoop:
            PUSH BC
            CALL RewriteSymbolNameEquals
            POP  BC
            RET  C
            LD   DE,RewriteSymbolEntrySize
            ADD  HL,DE
            DEC  C
            JR   NZ,RewriteSymbolFindLoop
            OR   A
            RET

; Prepare the current NAME as a provisional symbol. A is class, D is type,
; and BC is the complete class-specific payload.
.routine in A,D,BC out A,carry,zero,HL clobbers sign,parity,halfCarry,B,C,D,DE
RewriteSymbolPrepareCurrent:
            PUSH AF
            PUSH BC
            PUSH DE
            CALL RewriteSymbolFindCurrent
            JR   C,RewriteSymbolPrepareDuplicate
            POP  DE
            POP  BC
            POP  AF
            PUSH AF
            LD   A,(RewriteSymbolCount)
            CP   RewriteSymbolCapacity
            JR   NC,RewriteSymbolPrepareFull
            PUSH DE
            CALL RewriteSymbolAddress
            LD   DE,(TokenLexemePointer)
            LD   (HL),E
            INC  HL
            LD   (HL),D
            INC  HL
            LD   E,A
            LD   A,(TokenLength)
            LD   (HL),A
            INC  HL
            POP  DE
            POP  AF
            LD   (HL),A
            INC  HL
            LD   (HL),D
            INC  HL
            LD   (HL),C
            INC  HL
            LD   (HL),B
            OR   A
            RET
RewriteSymbolPrepareDuplicate:
            POP  DE
            POP  BC
            POP  AF
            JR   RewriteSymbolDuplicateFailure
RewriteSymbolPrepareFull:
            POP  AF
            LD   A,DiagnosticSymbolCapacity
            JP   RewriteRaiseDiagnostic
RewriteSymbolDuplicateFailure:
            LD   A,DiagnosticDuplicateName
            JP   RewriteRaiseDiagnostic

.routine out A,carry,zero clobbers sign,parity,halfCarry,HL
RewriteSymbolCommit:
            LD   HL,RewriteSymbolCount
            INC  (HL)
            XOR  A
            RET
