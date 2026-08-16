; First generated declaration-program escapes. These routines deliberately
; keep the provisional symbol invisible until the complete source line passes.

; The action program has just consumed the constant name. Reserve the
; provisional symbol with a harmless placeholder type and payload; its count
; remains unpublished until RewriteSymbolCommit.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteDeclarationBeginScalarConstant:
            LD   A,RewriteSymbolClassConstant
            LD   D,RewriteScalarTypeExact
            LD   BC,0
            JP   RewriteSymbolPrepareCurrent

; Normalize a completed integer constant back to the exact domain. Boolean is
; the sole retained scalar type; signed negative values retain only the exact
; negative metadata bit.
.routine in A,HL out A,carry,zero clobbers sign,parity,halfCarry,D
RewriteDeclarationInferConstantType:
            LD   D,A
            AND  RewriteTypeIdentityMask
            CP   RewriteScalarTypeBoolean
            RET  Z
            CP   RewriteScalarTypeI8
            JR   Z,_RewriteDeclarationInferI8
            CP   RewriteScalarTypeI16
            JR   Z,_RewriteDeclarationInferI16
            LD   A,D
            AND  RewriteTypeMetaNegative
            RET
_RewriteDeclarationInferI8:
            BIT  7,L
            JR   _RewriteDeclarationInferSign
_RewriteDeclarationInferI16:
            BIT  7,H
_RewriteDeclarationInferSign:
            LD   A,RewriteScalarTypeExact
            RET  Z
            LD   A,RewriteTypeMetaNegative
            RET

; Evaluate the scalar initializer, then complete the provisional entry in
; place. The next action instruction validates and consumes the newline before
; the entry becomes visible.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteDeclarationFinishScalarConstant:
            XOR  A
            CALL RewriteExpressionEvaluateConstant
            CALL RewriteDeclarationInferConstantType
            LD   D,A
            PUSH DE
            PUSH HL
            LD   A,(RewriteSymbolCount)
            CALL RewriteSymbolAddress
            LD   DE,RewriteSymbolType
            ADD  HL,DE
            POP  DE
            POP  BC
            LD   (HL),B
            INC  HL
            LD   (HL),E
            INC  HL
            LD   (HL),D
            XOR  A
            RET

; Assertions retain their keyword position because both a false assertion and
; a non-Boolean result are diagnosed at `assert`, not at the expression.
.routine out A,carry,zero clobbers sign,parity,halfCarry,HL
RewriteDeclarationBeginAssert:
            LD   HL,(TokenStartOffset)
            LD   (RewriteDeclarationAnchor),HL
            XOR  A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteDeclarationFinishAssert:
            LD   A,RewriteScalarTypeBoolean
            CALL RewriteExpressionEvaluateConstant
            LD   D,A
            LD   BC,(RewriteDeclarationAnchor)
            LD   (TokenStartOffset),BC
            AND  RewriteTypeIdentityMask
            CP   RewriteScalarTypeBoolean
            JR   NZ,_RewriteDeclarationAssertTypeFailure
            LD   A,H
            OR   L
            RET  NZ
            LD   A,DiagnosticAssertionFailed
            JP   RewriteRaiseDiagnostic
_RewriteDeclarationAssertTypeFailure:
            LD   A,DiagnosticTypeMismatch
            JP   RewriteRaiseDiagnostic

; Program variables use the same provisional publication rule as constants.
; The type and segment-relative payload are filled only after the complete type
; and initializer path succeeds.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteDeclarationBeginProgram:
            LD   A,RewriteSymbolClassProgram
            LD   D,RewriteScalarTypeExact
            LD   BC,0
            JP   RewriteSymbolPrepareCurrent

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteDeclarationParseOwnedType:
            CALL RewriteTypeParse
            CALL RewriteTypeRequireOwned
            LD   D,A
            LD   E,0
            PUSH DE
            LD   A,(RewriteSymbolCount)
            CALL RewriteSymbolAddress
            LD   DE,RewriteSymbolType
            ADD  HL,DE
            POP  BC
            LD   (HL),B
            XOR  A
            RET

; A is the explicit storage tag and DE the full segment-relative offset.
.routine in A,DE out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteDeclarationSetProgramStorage:
            PUSH AF
            PUSH DE
            LD   A,(RewriteSymbolCount)
            CALL RewriteSymbolAddress
            LD   DE,RewriteSymbolPayload
            ADD  HL,DE
            POP  BC
            LD   (HL),C
            INC  HL
            LD   (HL),B
            INC  HL
            POP  AF
            LD   (HL),A
            XOR  A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
RewriteDeclarationFinishProgramBss:
            LD   A,(RewriteCurrentType)
            CALL RewriteTypeStaticExtent
            JP   C,RewriteDeclarationProgramTypeFailure
            LD   B,H
            LD   C,L
            CALL RewriteStaticReserveBss
            LD   A,RewriteSymbolStorageBss
            JP   RewriteDeclarationSetProgramStorage

; Convert one constant initializer under the language's exact/same/widening
; compatibility rule. Carry from numeric conversion is a source range error;
; incompatible typed values are a type mismatch at the following token.
.routine in A,C,HL out A,C,HL,carry,zero clobbers sign,parity,halfCarry,D,E
RewriteDeclarationConvertConstant:
            LD   D,A
            AND  RewriteTypeIdentityMask
            CP   RewriteScalarTypeBoolean
            JR   Z,_RewriteDeclarationConvertBoolean
            OR   A
            JR   Z,_RewriteDeclarationConvertNumeric
            CP   C
            JR   Z,_RewriteDeclarationConvertNumeric
            CP   RewriteScalarTypeU8
            JR   NZ,_RewriteDeclarationConvertSignedByte
            LD   A,C
            CP   RewriteScalarTypeU16
            JR   Z,_RewriteDeclarationConvertNumeric
            CP   RewriteScalarTypeI16
            JR   Z,_RewriteDeclarationConvertNumeric
            JR   _RewriteDeclarationConvertTypeFailure
_RewriteDeclarationConvertSignedByte:
            CP   RewriteScalarTypeI8
            JR   NZ,_RewriteDeclarationConvertTypeFailure
            LD   A,C
            CP   RewriteScalarTypeI16
            JR   NZ,_RewriteDeclarationConvertTypeFailure
_RewriteDeclarationConvertNumeric:
            LD   A,D
            CALL RewriteExpressionConvertConstant
            JR   C,_RewriteDeclarationConvertRangeFailure
            RET
_RewriteDeclarationConvertBoolean:
            LD   A,C
            CP   RewriteScalarTypeBoolean
            JR   NZ,_RewriteDeclarationConvertTypeFailure
            LD   A,D
            OR   A
            RET
_RewriteDeclarationConvertTypeFailure:
            LD   A,DiagnosticTypeMismatch
            JP   RewriteRaiseDiagnostic
_RewriteDeclarationConvertRangeFailure:
            LD   HL,(RewriteExpressionAtomOffset)
            LD   (TokenStartOffset),HL
            LD   A,DiagnosticIntegerRange
            JP   RewriteRaiseDiagnostic

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
RewriteDeclarationFinishProgramScalar:
            LD   A,(RewriteCurrentType)
            CP   RewriteFirstOwnedTypeId
            JR   NC,RewriteDeclarationProgramTypeFailure
            LD   A,(RewriteCurrentType)
            CALL RewriteExpressionEvaluateConstant
            LD   D,A
            LD   A,(RewriteCurrentType)
            LD   C,A
            LD   A,D
            CALL RewriteDeclarationConvertConstant
            LD   (RewriteInitializerBase),HL
            LD   A,(RewriteCurrentType)
            CALL RewriteTypeStaticExtent
            JP   C,RewriteDeclarationProgramTypeFailure
            LD   B,H
            LD   C,L
            LD   HL,RewriteInitializerBase
            CALL RewriteStaticAppendInitialized
            LD   A,RewriteSymbolStorageInitialized
            JP   RewriteDeclarationSetProgramStorage

RewriteDeclarationProgramTypeFailure:
            LD   A,DiagnosticTypeMismatch
            JP   RewriteRaiseDiagnostic
