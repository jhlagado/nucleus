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
