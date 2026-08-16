; R6 recipe-interpreter proof. Expected target bytes are assembled from legal
; Z80 mnemonics, never reproduced as disguised compiler instruction data.

CompilerWorkBase    .equ $6000
SourceBase          .equ $5000
SourceLimit         .equ $5800
RewriteAdapterBase  .equ $A000
RewriteAdapterLimit .equ $A100
DebugHooks          .equ 0
ProofRuntimeBase    .equ $9000

            .org $1000
ProofBackendRecipes:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   HL,ProofBackendOutput
            LD   DE,ProofBackendOutputLimit
            LD   IX,ProofBackendContext
            CALL RewriteBackendInitialize
            LD   HL,$1234
            LD   (RewriteSemanticOperandArea),HL
            LD   A,RewriteSemanticDeclareLocalU8
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticDeclareLocal16
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticLiteral16
            CALL RewriteBackendDispatchOperation
            LD   A,2
            LD   (RewriteSemanticOperandArea),A
            LD   A,RewriteSemanticLoadLocalU8
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticLoadLocal16
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticStoreLocalU8
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticStoreLocal16
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticLoadParameter8
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticLoadParameter16
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticStoreParameter8
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticStoreParameter16
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticAdd8
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticSubtract8
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticMultiply8
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticAnd8
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticOr8
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticXor8
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticAdd16
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticSubtract16
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticMultiply16
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticAnd16
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticOr16
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticXor16
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticNegate8
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticNot8
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticNegate16
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticNot16
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticNotBoolean
            CALL RewriteBackendDispatchOperation
            LD   A,$11
            LD   (RewriteSemanticOperandArea),A
            LD   A,RewriteSemanticCompare8
            CALL RewriteBackendDispatchOperation
            LD   A,$22
            LD   (RewriteSemanticOperandArea),A
            LD   A,RewriteSemanticCompare16
            CALL RewriteBackendDispatchOperation
            LD   A,$33
            LD   (RewriteSemanticOperandArea),A
            LD   A,RewriteSemanticCompareBoolean
            CALL RewriteBackendDispatchOperation
            LD   A,1
            LD   (RewriteSemanticOperandArea),A
            LD   A,RewriteSemanticPromoteI8Pair
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticBeginBooleanAnd
            CALL RewriteBackendDispatchOperation
            LD   HL,$CAFE
            LD   (RewriteSemanticOperandArea),HL
            LD   A,RewriteSemanticLiteral16
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticBeginBooleanOr
            CALL RewriteBackendDispatchOperation
            LD   HL,$BEEF
            LD   (RewriteSemanticOperandArea),HL
            LD   A,RewriteSemanticLiteral16
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticEndBoolean
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticEndBoolean
            CALL RewriteBackendDispatchOperation
            LD   A,(RewriteBackendBooleanFixupDepth)
            OR   A
            JP   NZ,ProofFailure
            LD   HL,(RewriteBackendOutputCursor)
            LD   DE,ProofBackendOutput+ProofExpectedBackendEnd-ProofExpectedBackend
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   HL,ProofBackendOutput
            LD   DE,ProofExpectedBackend
            LD   BC,ProofExpectedBackendEnd-ProofExpectedBackend
ProofBackendCompareLoop:
            LD   A,(DE)
            CP   (HL)
            JP   NZ,ProofFailure
            INC  DE
            INC  HL
            DEC  BC
            LD   A,B
            OR   C
            JR   NZ,ProofBackendCompareLoop
            LD   A,$A5
            LD   (ProofStatus),A
            HALT

ProofBackendCapacity:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofExpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   HL,ProofBackendOutput
            LD   DE,ProofBackendOutput+3
            LD   IX,ProofBackendContext
            CALL RewriteBackendInitialize
            LD   HL,$1234
            LD   (RewriteSemanticOperandArea),HL
            LD   A,RewriteSemanticLiteral16
            CALL RewriteBackendDispatchOperation
            JP   ProofFailure

ProofBackendEscapeCapacity:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofExpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   HL,ProofBackendOutput
            LD   DE,ProofBackendOutput+4
            LD   IX,ProofBackendContext
            CALL RewriteBackendInitialize
            LD   HL,$1111
            LD   (RewriteSemanticOperandArea+RewriteSemanticNarrowU8OperandSourceOffsetOffset),HL
            LD   A,RewriteSemanticNarrowU8
            CALL RewriteBackendDispatchOperation
            JP   ProofFailure

ProofBackendAddressCapacity:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofExpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   HL,ProofBackendOutput
            LD   DE,ProofBackendOutput+2
            LD   IX,ProofBackendContext
            CALL RewriteBackendInitialize
            LD   HL,$0012
            LD   (RewriteSemanticOperandArea),HL
            LD   A,RewriteSemanticLoadProgramU8
            CALL RewriteBackendDispatchOperation
            JP   ProofFailure

ProofBackendEscapes:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   HL,ProofBackendOutput
            LD   DE,ProofBackendOutputLimit
            LD   IX,ProofBackendContext
            CALL RewriteBackendInitialize

            LD   HL,$1111
            LD   (RewriteSemanticOperandArea+RewriteSemanticNarrowU8OperandSourceOffsetOffset),HL
            LD   A,RewriteSemanticNarrowU8
            CALL RewriteBackendDispatchOperation

            LD   A,RewriteScalarTypeI8
            LD   (RewriteSemanticOperandArea+RewriteSemanticConvertIntegerOperandSourceTypeOffset),A
            LD   A,RewriteScalarTypeU16+$80
            LD   (RewriteSemanticOperandArea+RewriteSemanticConvertIntegerOperandTargetTypeOffset),A
            LD   HL,$2222
            LD   (RewriteSemanticOperandArea+RewriteSemanticConvertIntegerOperandSourceOffsetOffset),HL
            LD   A,RewriteSemanticConvertInteger
            CALL RewriteBackendDispatchOperation

            LD   HL,$3333
            LD   (RewriteSemanticOperandArea+RewriteSemanticDivide8OperandSourceOffsetOffset),HL
            LD   A,RewriteSemanticDivide8
            CALL RewriteBackendDispatchOperation

            LD   HL,$4444
            LD   (RewriteSemanticOperandArea+RewriteSemanticModulo16OperandSourceOffsetOffset),HL
            LD   A,RewriteSemanticModulo16
            CALL RewriteBackendDispatchOperation

            LD   A,$C1
            LD   (RewriteSemanticOperandArea+RewriteSemanticDivideSignedOperandModeOffset),A
            LD   HL,$5555
            LD   (RewriteSemanticOperandArea+RewriteSemanticDivideSignedOperandSourceOffsetOffset),HL
            LD   A,RewriteSemanticDivideSigned
            CALL RewriteBackendDispatchOperation

            LD   HL,(RewriteBackendOutputCursor)
            LD   DE,ProofBackendOutput+ProofExpectedEscapesEnd-ProofExpectedEscapes
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   HL,ProofBackendOutput
            LD   DE,ProofExpectedEscapes
            LD   BC,ProofExpectedEscapesEnd-ProofExpectedEscapes
ProofBackendEscapeCompareLoop:
            LD   A,(DE)
            CP   (HL)
            JP   NZ,ProofFailure
            INC  DE
            INC  HL
            DEC  BC
            LD   A,B
            OR   C
            JR   NZ,ProofBackendEscapeCompareLoop
            LD   A,$A5
            LD   (ProofStatus),A
            HALT

ProofBackendBankedTrap:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   HL,ProofBackendOutput
            LD   DE,ProofBackendOutputLimit
            LD   IX,ProofBackendBankedContext
            CALL RewriteBackendInitialize
            LD   HL,$6666
            LD   (RewriteSemanticOperandArea+RewriteSemanticNarrowU8OperandSourceOffsetOffset),HL
            LD   A,RewriteSemanticNarrowU8
            CALL RewriteBackendDispatchOperation
            LD   HL,(RewriteBackendOutputCursor)
            LD   DE,ProofBackendOutput+ProofExpectedBankedTrapEnd-ProofExpectedBankedTrap
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   HL,ProofBackendOutput
            LD   DE,ProofExpectedBankedTrap
            LD   BC,ProofExpectedBankedTrapEnd-ProofExpectedBankedTrap
ProofBackendBankedCompareLoop:
            LD   A,(DE)
            CP   (HL)
            JP   NZ,ProofFailure
            INC  DE
            INC  HL
            DEC  BC
            LD   A,B
            OR   C
            JR   NZ,ProofBackendBankedCompareLoop
            LD   A,$A5
            LD   (ProofStatus),A
            HALT

ProofBackendAddresses:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   HL,ProofBackendOutput
            LD   DE,ProofBackendOutputLimit
            LD   IX,ProofBackendContext
            CALL RewriteBackendInitialize

            LD   A,RewriteSemanticDefineProgramU8
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticDefineProgram16
            CALL RewriteBackendDispatchOperation

            LD   HL,$0012
            LD   (RewriteSemanticOperandArea),HL
            LD   A,RewriteSemanticLoadProgramU8
            CALL RewriteBackendDispatchOperation
            LD   HL,$0134
            LD   (RewriteSemanticOperandArea),HL
            LD   A,RewriteSemanticLoadProgram16
            CALL RewriteBackendDispatchOperation
            LD   HL,$0020
            LD   (RewriteSemanticOperandArea),HL
            LD   A,RewriteSemanticStoreProgramU8
            CALL RewriteBackendDispatchOperation
            LD   HL,$0030
            LD   (RewriteSemanticOperandArea),HL
            LD   A,RewriteSemanticStoreProgram16
            CALL RewriteBackendDispatchOperation

            LD   HL,$0040
            LD   (RewriteSemanticOperandArea),HL
            LD   A,RewriteSemanticLoadBssU8
            CALL RewriteBackendDispatchOperation
            LD   HL,$0050
            LD   (RewriteSemanticOperandArea),HL
            LD   A,RewriteSemanticLoadBss16
            CALL RewriteBackendDispatchOperation
            LD   HL,$0060
            LD   (RewriteSemanticOperandArea),HL
            LD   A,RewriteSemanticStoreBssU8
            CALL RewriteBackendDispatchOperation
            LD   HL,$0070
            LD   (RewriteSemanticOperandArea),HL
            LD   A,RewriteSemanticStoreBss16
            CALL RewriteBackendDispatchOperation

            LD   HL,$0080
            LD   (RewriteSemanticOperandArea),HL
            LD   A,RewriteSemanticLoadProgramAlias
            CALL RewriteBackendDispatchOperation
            LD   HL,$0090
            LD   (RewriteSemanticOperandArea),HL
            LD   A,RewriteSemanticLoadBssAlias
            CALL RewriteBackendDispatchOperation
            LD   HL,$00A0
            LD   (RewriteSemanticOperandArea),HL
            LD   A,RewriteSemanticLoadReadOnlyAlias
            CALL RewriteBackendDispatchOperation
            LD   A,2
            LD   (RewriteSemanticOperandArea),A
            LD   A,RewriteSemanticLoadParameterAlias
            CALL RewriteBackendDispatchOperation
            LD   HL,$1234
            LD   (RewriteSemanticOperandArea),HL
            LD   A,RewriteSemanticSelectField
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticLoadIndirect8
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticLoadIndirect16
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticStoreIndirect8
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticStoreIndirect16
            CALL RewriteBackendDispatchOperation

            LD   HL,(RewriteBackendOutputCursor)
            LD   DE,ProofBackendOutput+ProofExpectedAddressesEnd-ProofExpectedAddresses
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   HL,ProofBackendOutput
            LD   DE,ProofExpectedAddresses
            LD   BC,ProofExpectedAddressesEnd-ProofExpectedAddresses
ProofBackendAddressCompareLoop:
            LD   A,(DE)
            CP   (HL)
            JP   NZ,ProofFailure
            INC  DE
            INC  HL
            DEC  BC
            LD   A,B
            OR   C
            JR   NZ,ProofBackendAddressCompareLoop
            LD   A,$A5
            LD   (ProofStatus),A
            HALT

ProofBackendControl:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   HL,ProofBackendOutput
            LD   DE,ProofBackendOutputLimit
            LD   IX,ProofBackendContext
            CALL RewriteBackendInitialize
            LD   A,1
            LD   (RewriteSemanticOperandArea),A
            LD   A,RewriteSemanticJumpDirect
            CALL RewriteBackendDispatchOperation
            LD   A,2
            LD   (RewriteSemanticOperandArea),A
            LD   A,RewriteSemanticControlLabelEnclosing
            CALL RewriteBackendDispatchOperation
            LD   A,1
            LD   (RewriteSemanticOperandArea),A
            LD   A,RewriteSemanticBranchFalse
            CALL RewriteBackendDispatchOperation
            LD   A,1
            LD   (RewriteSemanticOperandArea),A
            LD   A,RewriteSemanticControlLabelDirect
            CALL RewriteBackendDispatchOperation
            LD   A,2
            LD   (RewriteSemanticOperandArea),A
            LD   A,RewriteSemanticJumpEnclosing
            CALL RewriteBackendDispatchOperation
            LD   A,RewriteSemanticReturnScalar
            CALL RewriteBackendDispatchOperation
            CALL RewriteBackendResolveFixups
            LD   HL,ProofBackendOutput+9
            LD   (ProofExpectedControl+1),HL
            LD   (ProofExpectedControl+7),HL
            LD   HL,ProofBackendOutput+3
            LD   (ProofExpectedControl+10),HL
            LD   HL,(RewriteBackendOutputCursor)
            LD   DE,ProofBackendOutput+ProofExpectedControlEnd-ProofExpectedControl
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   HL,ProofBackendOutput
            LD   DE,ProofExpectedControl
            LD   BC,ProofExpectedControlEnd-ProofExpectedControl
ProofBackendControlCompareLoop:
            LD   A,(DE)
            CP   (HL)
            JP   NZ,ProofFailure
            INC  DE
            INC  HL
            DEC  BC
            LD   A,B
            OR   C
            JR   NZ,ProofBackendControlCompareLoop
            LD   A,(RewriteBackendFixupCount)
            OR   A
            JP   NZ,ProofFailure
            LD   A,$A5
            LD   (ProofStatus),A
            HALT

ProofBackendRoutineFrame:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   HL,ProofBackendOutput
            LD   DE,ProofBackendOutputLimit
            LD   IX,ProofBackendContext
            CALL RewriteBackendInitialize

            LD   A,4
            LD   (RewriteSemanticOperandArea+RewriteSemanticBeginGeneralRoutineOperandLabelOffset),A
            LD   A,3
            LD   (RewriteSemanticOperandArea+RewriteSemanticBeginGeneralRoutineOperandParameterCountOffset),A
            XOR  A
            LD   (RewriteSemanticOperandArea+RewriteSemanticBeginGeneralRoutineOperandBankOffset),A
            LD   A,RewriteSemanticBeginGeneralRoutine
            CALL RewriteBackendDispatchOperation
            JP   C,ProofFailure

            LD   A,RewriteScalarTypeU8
            LD   (RewriteSemanticOperandArea+RewriteSemanticBindParameterOperandTypeOffset),A
            XOR  A
            LD   (RewriteSemanticOperandArea+RewriteSemanticBindParameterOperandLocalOffsetOffset),A
            LD   A,4
            LD   (RewriteSemanticOperandArea+RewriteSemanticBindParameterOperandArgumentOffsetOffset),A
            LD   A,RewriteSemanticBindParameter
            CALL RewriteBackendDispatchOperation
            JP   C,ProofFailure

            LD   A,RewriteScalarTypeU16
            LD   (RewriteSemanticOperandArea+RewriteSemanticBindParameterOperandTypeOffset),A
            LD   A,1
            LD   (RewriteSemanticOperandArea+RewriteSemanticBindParameterOperandLocalOffsetOffset),A
            LD   A,6
            LD   (RewriteSemanticOperandArea+RewriteSemanticBindParameterOperandArgumentOffsetOffset),A
            LD   A,RewriteSemanticBindParameter
            CALL RewriteBackendDispatchOperation
            JP   C,ProofFailure

            LD   A,RewriteOpenStringTypeId
            LD   (RewriteSemanticOperandArea+RewriteSemanticBindParameterOperandTypeOffset),A
            LD   A,3
            LD   (RewriteSemanticOperandArea+RewriteSemanticBindParameterOperandLocalOffsetOffset),A
            LD   A,8
            LD   (RewriteSemanticOperandArea+RewriteSemanticBindParameterOperandArgumentOffsetOffset),A
            LD   A,RewriteSemanticBindParameter
            CALL RewriteBackendDispatchOperation
            JP   C,ProofFailure

            XOR  A
            LD   (RewriteSemanticOperandArea+RewriteSemanticEndGeneralRoutineDirectOperandResultTypeOffset),A
            LD   A,RewriteSemanticEndGeneralRoutineDirect
            CALL RewriteBackendDispatchOperation
            JP   C,ProofFailure
            LD   HL,(RewriteBackendOutputCursor)
            PUSH HL
            LD   A,RewriteScalarTypeU8
            LD   (RewriteSemanticOperandArea+RewriteSemanticEndGeneralRoutineEnclosingOperandResultTypeOffset),A
            LD   A,RewriteSemanticEndGeneralRoutineEnclosing
            CALL RewriteBackendDispatchOperation
            JP   C,ProofFailure
            POP  DE
            LD   HL,(RewriteBackendOutputCursor)
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure

            LD   A,(RewriteBackendLabelValidBase+4)
            CP   1
            JP   NZ,ProofFailure
            LD   A,(RewriteBackendLabelBankBase+4)
            OR   A
            JP   NZ,ProofFailure
            LD   HL,(RewriteBackendLabelAddressBase+8)
            LD   DE,ProofBackendOutput
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   HL,(RewriteBackendOutputCursor)
            LD   DE,ProofBackendOutput+ProofExpectedRoutineFrameEnd-ProofExpectedRoutineFrame
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   HL,ProofBackendOutput
            LD   DE,ProofExpectedRoutineFrame
            LD   BC,ProofExpectedRoutineFrameEnd-ProofExpectedRoutineFrame
ProofBackendRoutineFrameCompare:
            LD   A,(DE)
            CP   (HL)
            JP   NZ,ProofFailure
            INC  DE
            INC  HL
            DEC  BC
            LD   A,B
            OR   C
            JR   NZ,ProofBackendRoutineFrameCompare
            LD   A,$A5
            LD   (ProofStatus),A
            HALT

ProofBackendRoutineBankMismatch:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofExpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   HL,ProofBackendOutput
            LD   DE,ProofBackendOutputLimit
            LD   IX,ProofBackendContext
            CALL RewriteBackendInitialize
            XOR  A
            LD   (RewriteSemanticOperandArea+RewriteSemanticBeginGeneralRoutineOperandLabelOffset),A
            LD   (RewriteSemanticOperandArea+RewriteSemanticBeginGeneralRoutineOperandParameterCountOffset),A
            INC  A
            LD   (RewriteSemanticOperandArea+RewriteSemanticBeginGeneralRoutineOperandBankOffset),A
            LD   A,RewriteSemanticBeginGeneralRoutine
            CALL RewriteBackendDispatchOperation
            JP   ProofFailure

ProofBackendSourceCalls:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   HL,ProofBackendOutput
            LD   DE,ProofBackendOutputLimit
            LD   IX,ProofBackendContext
            CALL RewriteBackendInitialize

            ; The declaration prepass publishes banks before any call emits.
            LD   A,5
            LD   B,0
            CALL RewriteBackendEnsureLabelBank
            LD   A,5
            CALL RewriteBackendDefineLabel
            LD   A,6
            LD   B,2
            CALL RewriteBackendEnsureLabelBank
            LD   A,1
            LD   (RewriteBackendLabelValidBase+6),A
            LD   HL,$C234
            LD   (RewriteBackendLabelAddressBase+12),HL

            ; Local failable value call, propagated by the current routine.
            LD   A,5
            LD   (RewriteSemanticOperandArea+RewriteSemanticCallSourceOperandSelectorOffset),A
            XOR  A
            LD   (RewriteSemanticOperandArea+RewriteSemanticCallSourceOperandArgumentWordsOffset),A
            LD   A,RewriteScalarTypeU8
            LD   (RewriteSemanticOperandArea+RewriteSemanticCallSourceOperandResultTypeOffset),A
            LD   A,RewriteRoutineFlagFails+RewriteCallFlagKeepResult
            LD   (RewriteSemanticOperandArea+RewriteSemanticCallSourceOperandRoutineFlagsOffset),A
            LD   HL,$3333
            LD   (RewriteSemanticOperandArea+RewriteSemanticCallSourceOperandSourceOffsetOffset),HL
            LD   A,RewriteCallModePropagateRoutine
            LD   (RewriteSemanticOperandArea+RewriteSemanticCallSourceOperandCallModeOffset),A
            XOR  A
            LD   (RewriteSemanticOperandArea+RewriteSemanticCallSourceOperandHandlerLabelOffset),A
            LD   (RewriteSemanticOperandArea+RewriteSemanticCallSourceOperandRetainedCarriersOffset),A
            LD   A,RewriteSemanticCallSource
            CALL RewriteBackendDispatchOperation
            JP   C,ProofFailure

            ; Infallible cross-bank value call discarded as a complete call
            ; statement. The declared result type remains in the transcript,
            ; while the absent keep-result bit prevents a result carrier.
            LD   A,6
            LD   (RewriteSemanticOperandArea+RewriteSemanticCallSourceOperandSelectorOffset),A
            XOR  A
            LD   (RewriteSemanticOperandArea+RewriteSemanticCallSourceOperandArgumentWordsOffset),A
            LD   A,RewriteScalarTypeU8
            LD   (RewriteSemanticOperandArea+RewriteSemanticCallSourceOperandResultTypeOffset),A
            XOR  A
            LD   (RewriteSemanticOperandArea+RewriteSemanticCallSourceOperandRoutineFlagsOffset),A
            LD   HL,$2222
            LD   (RewriteSemanticOperandArea+RewriteSemanticCallSourceOperandSourceOffsetOffset),HL
            XOR  A
            LD   (RewriteSemanticOperandArea+RewriteSemanticCallSourceOperandCallModeOffset),A
            LD   (RewriteSemanticOperandArea+RewriteSemanticCallSourceOperandHandlerLabelOffset),A
            LD   (RewriteSemanticOperandArea+RewriteSemanticCallSourceOperandRetainedCarriersOffset),A
            LD   A,RewriteSemanticCallSource
            CALL RewriteBackendDispatchOperation
            JP   C,ProofFailure

            ; Local handled failure discards one argument and one retained
            ; carrier before the branch, but only the argument on success.
            LD   A,5
            LD   (RewriteSemanticOperandArea+RewriteSemanticCallSourceOperandSelectorOffset),A
            LD   A,1
            LD   (RewriteSemanticOperandArea+RewriteSemanticCallSourceOperandArgumentWordsOffset),A
            XOR  A
            LD   (RewriteSemanticOperandArea+RewriteSemanticCallSourceOperandResultTypeOffset),A
            LD   A,RewriteRoutineFlagFails
            LD   (RewriteSemanticOperandArea+RewriteSemanticCallSourceOperandRoutineFlagsOffset),A
            LD   HL,$4444
            LD   (RewriteSemanticOperandArea+RewriteSemanticCallSourceOperandSourceOffsetOffset),HL
            LD   A,RewriteCallModeHandle
            LD   (RewriteSemanticOperandArea+RewriteSemanticCallSourceOperandCallModeOffset),A
            LD   A,7
            LD   (RewriteSemanticOperandArea+RewriteSemanticCallSourceOperandHandlerLabelOffset),A
            LD   A,1
            LD   (RewriteSemanticOperandArea+RewriteSemanticCallSourceOperandRetainedCarriersOffset),A
            LD   A,RewriteSemanticCallSource
            CALL RewriteBackendDispatchOperation
            JP   C,ProofFailure
            LD   A,7
            CALL RewriteBackendDefineLabel
            CALL RewriteBackendResolveFixups

            LD   HL,ProofBackendOutput
            LD   (ProofExpectedSourceCall1+1),HL
            LD   (ProofExpectedSourceCall3+1),HL
            LD   HL,ProofBackendOutput+ProofExpectedSourceCallsEnd-ProofExpectedSourceCalls
            LD   (ProofExpectedSourceHandler+1),HL
            LD   HL,(RewriteBackendOutputCursor)
            LD   DE,ProofBackendOutput+ProofExpectedSourceCallsEnd-ProofExpectedSourceCalls
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailure
            LD   HL,ProofBackendOutput
            LD   DE,ProofExpectedSourceCalls
            LD   BC,ProofExpectedSourceCallsEnd-ProofExpectedSourceCalls
ProofBackendSourceCallCompare:
            LD   A,(DE)
            CP   (HL)
            JP   NZ,ProofFailure
            INC  DE
            INC  HL
            DEC  BC
            LD   A,B
            OR   C
            JR   NZ,ProofBackendSourceCallCompare
            LD   A,(RewriteBackendFixupCount)
            OR   A
            JP   NZ,ProofFailure
            LD   A,$A5
            LD   (ProofStatus),A
            HALT

ProofBackendSourceCallMissingBank:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofExpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   HL,ProofBackendOutput
            LD   DE,ProofBackendOutputLimit
            LD   IX,ProofBackendContext
            CALL RewriteBackendInitialize
            LD   A,5
            LD   (RewriteSemanticOperandArea+RewriteSemanticCallSourceOperandSelectorOffset),A
            XOR  A
            LD   (RewriteSemanticOperandArea+RewriteSemanticCallSourceOperandArgumentWordsOffset),A
            LD   (RewriteSemanticOperandArea+RewriteSemanticCallSourceOperandResultTypeOffset),A
            LD   (RewriteSemanticOperandArea+RewriteSemanticCallSourceOperandRoutineFlagsOffset),A
            LD   (RewriteSemanticOperandArea+RewriteSemanticCallSourceOperandCallModeOffset),A
            LD   (RewriteSemanticOperandArea+RewriteSemanticCallSourceOperandHandlerLabelOffset),A
            LD   (RewriteSemanticOperandArea+RewriteSemanticCallSourceOperandRetainedCarriersOffset),A
            LD   A,RewriteSemanticCallSource
            CALL RewriteBackendDispatchOperation
            JP   ProofFailure

ProofBackendUndefinedLabel:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofExpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   HL,ProofBackendOutput
            LD   DE,ProofBackendOutputLimit
            LD   IX,ProofBackendContext
            CALL RewriteBackendInitialize
            LD   A,3
            LD   (RewriteSemanticOperandArea),A
            LD   A,RewriteSemanticJumpDirect
            CALL RewriteBackendDispatchOperation
            CALL RewriteBackendResolveFixups
            JP   ProofFailure

ProofBackendLabelCapacity:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofExpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   HL,ProofBackendOutput
            LD   DE,ProofBackendOutputLimit
            LD   IX,ProofBackendContext
            CALL RewriteBackendInitialize
            XOR  A
ProofBackendLabelCapacityLoop:
            LD   (RewriteSemanticOperandArea),A
            PUSH AF
            LD   A,RewriteSemanticControlLabelDirect
            CALL RewriteBackendDispatchOperation
            POP  AF
            INC  A
            CP   RewriteBackendLabelCapacity
            JR   C,ProofBackendLabelCapacityLoop
            LD   (RewriteSemanticOperandArea),A
            LD   A,RewriteSemanticControlLabelDirect
            CALL RewriteBackendDispatchOperation
            JP   ProofFailure

ProofBackendFixupCapacity:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofExpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   HL,ProofBackendOutput
            LD   DE,ProofBackendOutputLimit
            LD   IX,ProofBackendContext
            CALL RewriteBackendInitialize
            LD   B,RewriteBackendFixupCapacity
ProofBackendFixupCapacityLoop:
            XOR  A
            LD   (RewriteSemanticOperandArea),A
            PUSH BC
            LD   A,RewriteSemanticJumpDirect
            CALL RewriteBackendDispatchOperation
            POP  BC
            DJNZ ProofBackendFixupCapacityLoop
            XOR  A
            LD   (RewriteSemanticOperandArea),A
            LD   A,RewriteSemanticJumpDirect
            CALL RewriteBackendDispatchOperation
            JP   ProofFailure

ProofExpectedDiagnostic:
            HALT
ProofUnexpectedDiagnostic:
            LD   A,(DiagnosticCode)
            LD   (ProofStatus),A
            HALT
ProofFailure:
            LD   A,$FF
            LD   (ProofStatus),A
            HALT

            .include "compiler-image.asmi"

ProofStatus: .db 0
ProofBackendContext:
            .dw ProofRuntimeBase,$A000,$A100,$A200,$A300,$A400,$A500
            .db 0,0
ProofBackendBankedContext:
            .dw ProofRuntimeBase,$A000,$A100,$A200,$A300,$A400,$A500
            .db 2,5

            .org $B000
ProofBackendOutput:
            .ds $0400
ProofBackendOutputLimit:

            .org $B800
ProofExpectedBackend:
            DEC  SP
            DEC  SP
            DEC  SP
            LD   HL,$1234
            PUSH HL
            LD   L,(IX-3)
            LD   H,0
            PUSH HL
            LD   L,(IX-3)
            LD   H,(IX-4)
            PUSH HL
            POP  HL
            LD   (IX-3),L
            POP  HL
            LD   (IX-3),L
            LD   (IX-4),H
            LD   L,(IX-3)
            LD   H,0
            PUSH HL
            LD   L,(IX-3)
            LD   H,(IX-4)
            PUSH HL
            POP  HL
            LD   (IX-3),L
            POP  HL
            LD   (IX-3),L
            LD   (IX-4),H
            POP  DE
            POP  HL
            LD   A,L
            ADD  A,E
            LD   L,A
            LD   H,0
            PUSH HL
            POP  DE
            POP  HL
            LD   A,L
            SUB  E
            LD   L,A
            LD   H,0
            PUSH HL
            POP  DE
            POP  HL
            CALL ProofRuntimeBase+NucleusRuntimeMultiplyU16Offset
            LD   H,0
            PUSH HL
            POP  DE
            POP  HL
            LD   A,L
            AND  E
            LD   L,A
            LD   H,0
            PUSH HL
            POP  DE
            POP  HL
            LD   A,L
            OR   E
            LD   L,A
            LD   H,0
            PUSH HL
            POP  DE
            POP  HL
            LD   A,L
            XOR  E
            LD   L,A
            LD   H,0
            PUSH HL
            POP  DE
            POP  HL
            ADD  HL,DE
            PUSH HL
            POP  DE
            POP  HL
            XOR  A
            SBC  HL,DE
            PUSH HL
            POP  DE
            POP  HL
            CALL ProofRuntimeBase+NucleusRuntimeMultiplyU16Offset
            PUSH HL
            POP  DE
            POP  HL
            LD   A,L
            AND  E
            LD   L,A
            LD   A,H
            AND  D
            LD   H,A
            PUSH HL
            POP  DE
            POP  HL
            LD   A,L
            OR   E
            LD   L,A
            LD   A,H
            OR   D
            LD   H,A
            PUSH HL
            POP  DE
            POP  HL
            LD   A,L
            XOR  E
            LD   L,A
            LD   A,H
            XOR  D
            LD   H,A
            PUSH HL
            POP  HL
            XOR  A
            SUB  L
            LD   L,A
            LD   H,0
            PUSH HL
            POP  HL
            LD   A,L
            CPL
            LD   L,A
            LD   H,0
            PUSH HL
            POP  HL
            XOR  A
            SUB  L
            LD   L,A
            LD   A,0
            SBC  A,H
            LD   H,A
            PUSH HL
            POP  HL
            LD   A,L
            CPL
            LD   L,A
            LD   A,H
            CPL
            LD   H,A
            PUSH HL
            POP  HL
            LD   A,L
            XOR  1
            LD   L,A
            LD   H,0
            PUSH HL
            POP  DE
            POP  HL
            LD   A,$11
            CALL ProofRuntimeBase+NucleusRuntimeCompareU16Offset
            PUSH HL
            POP  DE
            POP  HL
            LD   A,$22
            CALL ProofRuntimeBase+NucleusRuntimeCompareU16Offset
            PUSH HL
            POP  DE
            POP  HL
            LD   A,$33
            CALL ProofRuntimeBase+NucleusRuntimeCompareU16Offset
            PUSH HL
            POP  DE
            POP  HL
            LD   A,1
            CALL ProofRuntimeBase+NucleusRuntimePromoteI8PairOffset
            PUSH HL
            PUSH DE
            POP  HL
            LD   A,L
            OR   A
            JR   NZ,ProofExpectedBooleanAndContinue
            PUSH HL
            JR   ProofExpectedBooleanOuterEnd
ProofExpectedBooleanAndContinue:
            LD   HL,$CAFE
            PUSH HL
            POP  HL
            LD   A,L
            OR   A
            JR   Z,ProofExpectedBooleanOrContinue
            PUSH HL
            JR   ProofExpectedBooleanInnerEnd
ProofExpectedBooleanOrContinue:
            LD   HL,$BEEF
            PUSH HL
ProofExpectedBooleanInnerEnd:
ProofExpectedBooleanOuterEnd:
ProofExpectedBackendEnd:

; Five escape paths cover ordinary narrowing, bounds-mode conversion,
; unsigned divide, unsigned modulo, and signed byte modulo. Conditional
; branches skip complete inline trap bodies assembled only from mnemonics.
ProofExpectedEscapes:
            POP  HL
            LD   A,H
            OR   A
            JR   Z,ProofExpectedNarrowSuccess
            LD   HL,$1111
            LD   A,2
            LD   SP,($A111)
            LD   IX,($A113)
            PUSH AF
            XOR  A
            LD   ($A106),A
            POP  AF
            LD   ($A101),A
            XOR  A
            LD   ($A102),A
            LD   ($A103),HL
            LD   A,3
            LD   ($A100),A
            JP   $A200
ProofExpectedNarrowSuccess:
            PUSH HL

            POP  HL
            LD   A,RewriteScalarTypeI8
            LD   C,RewriteScalarTypeU16+$80
            CALL ProofRuntimeBase+NucleusRuntimeConvertIntegerOffset
            JR   NC,ProofExpectedConvertSuccess
            LD   HL,$2222
            LD   A,1
            LD   SP,($A111)
            LD   IX,($A113)
            PUSH AF
            XOR  A
            LD   ($A106),A
            POP  AF
            LD   ($A101),A
            XOR  A
            LD   ($A102),A
            LD   ($A103),HL
            LD   A,3
            LD   ($A100),A
            JP   $A200
ProofExpectedConvertSuccess:
            PUSH HL

            POP  DE
            POP  HL
            CALL ProofRuntimeBase+NucleusRuntimeDivideU16Offset
            JR   NC,ProofExpectedDivide8Success
            LD   HL,$3333
            LD   A,3
            LD   SP,($A111)
            LD   IX,($A113)
            PUSH AF
            XOR  A
            LD   ($A106),A
            POP  AF
            LD   ($A101),A
            XOR  A
            LD   ($A102),A
            LD   ($A103),HL
            LD   A,3
            LD   ($A100),A
            JP   $A200
ProofExpectedDivide8Success:
            LD   H,0
            PUSH HL

            POP  DE
            POP  HL
            CALL ProofRuntimeBase+NucleusRuntimeModuloU16Offset
            JR   NC,ProofExpectedModulo16Success
            LD   HL,$4444
            LD   A,3
            LD   SP,($A111)
            LD   IX,($A113)
            PUSH AF
            XOR  A
            LD   ($A106),A
            POP  AF
            LD   ($A101),A
            XOR  A
            LD   ($A102),A
            LD   ($A103),HL
            LD   A,3
            LD   ($A100),A
            JP   $A200
ProofExpectedModulo16Success:
            PUSH HL

            POP  DE
            POP  HL
            LD   A,$C1
            CALL ProofRuntimeBase+NucleusRuntimeDivideSignedOffset
            JR   NC,ProofExpectedDivideSignedSuccess
            LD   HL,$5555
            LD   A,3
            LD   SP,($A111)
            LD   IX,($A113)
            PUSH AF
            XOR  A
            LD   ($A106),A
            POP  AF
            LD   ($A101),A
            XOR  A
            LD   ($A102),A
            LD   ($A103),HL
            LD   A,3
            LD   ($A100),A
            JP   $A200
ProofExpectedDivideSignedSuccess:
            LD   H,0
            PUSH HL
ProofExpectedEscapesEnd:

ProofExpectedBankedTrap:
            POP  HL
            LD   A,H
            OR   A
            JR   Z,ProofExpectedBankedSuccess
            LD   HL,$6666
            LD   A,2
            LD   SP,($A111)
            LD   IX,($A113)
            PUSH AF
            XOR  A
            LD   ($A106),A
            POP  AF
            LD   ($A101),A
            XOR  A
            LD   ($A102),A
            LD   ($A103),HL
            LD   A,3
            LD   ($A100),A
            LD   A,2
            LD   HL,$A200
            JP   $A01E
ProofExpectedBankedSuccess:
            PUSH HL
ProofExpectedBankedTrapEnd:

ProofExpectedAddresses:
            LD   A,($A312)
            LD   L,A
            LD   H,0
            PUSH HL
            LD   HL,($A434)
            PUSH HL
            POP  HL
            LD   A,L
            LD   ($A320),A
            POP  HL
            LD   ($A330),HL
            LD   A,($A440)
            LD   L,A
            LD   H,0
            PUSH HL
            LD   HL,($A450)
            PUSH HL
            POP  HL
            LD   A,L
            LD   ($A460),A
            POP  HL
            LD   ($A470),HL
            LD   HL,$A380
            PUSH HL
            LD   HL,$A490
            PUSH HL
            LD   HL,$A5A0
            PUSH HL
            LD   L,(IX-3)
            LD   H,(IX-4)
            PUSH HL
            POP  HL
            LD   DE,$1234
            ADD  HL,DE
            PUSH HL
            POP  HL
            LD   A,(HL)
            LD   L,A
            LD   H,0
            PUSH HL
            POP  HL
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            PUSH DE
            POP  DE
            POP  HL
            LD   (HL),E
            POP  DE
            POP  HL
            LD   (HL),E
            INC  HL
            LD   (HL),D
ProofExpectedAddressesEnd:

ProofExpectedControl:
            JP   ProofExpectedControlLabel1
ProofExpectedControlLabel2:
            POP  HL
            LD   A,L
            OR   A
            JP   Z,ProofExpectedControlLabel1
ProofExpectedControlLabel1:
            JP   ProofExpectedControlLabel2
            POP  HL
            LD   SP,IX
            POP  IX
            RET
ProofExpectedControlEnd:

ProofExpectedRoutineFrame:
            PUSH IX
            LD   IX,0
            ADD  IX,SP
            DEC  SP
            LD   L,(IX+4)
            LD   (IX-1),L
            DEC  SP
            DEC  SP
            LD   L,(IX+6)
            LD   H,(IX+7)
            LD   (IX-2),L
            LD   (IX-3),H
            DEC  SP
            DEC  SP
            DEC  SP
            LD   L,(IX+8)
            LD   H,(IX+9)
            LD   (IX-4),L
            LD   (IX-5),H
            LD   L,(IX+10)
            LD   (IX-6),L
            LD   SP,IX
            POP  IX
            RET
ProofExpectedRoutineFrameEnd:

ProofExpectedSourceCalls:
            CALL ProofRuntimeBase+NucleusRuntimeActivationClaimOffset
            JR   NC,ProofExpectedSourceCall1Ready
            LD   HL,$3333
            LD   A,5
            LD   SP,($A100+17)
            LD   IX,($A100+19)
            PUSH AF
            XOR  A
            LD   ($A100+6),A
            POP  AF
            LD   ($A100+1),A
            XOR  A
            LD   ($A100+2),A
            LD   ($A100+3),HL
            LD   A,3
            LD   ($A100),A
            JP   $A200
ProofExpectedSourceCall1Ready:
ProofExpectedSourceCall1:
            CALL 0
            PUSH AF
            CALL ProofRuntimeBase+NucleusRuntimeActivationReleaseOffset
            POP  AF
            JR   NC,ProofExpectedSourceCall1Success
            LD   HL,$3333
            LD   ($A100+3),HL
            LD   SP,IX
            POP  IX
            SCF
            RET
ProofExpectedSourceCall1Success:
            PUSH HL
            LD   L,A
            LD   H,0
            PUSH HL

            CALL ProofRuntimeBase+NucleusRuntimeActivationClaimOffset
            JR   NC,ProofExpectedSourceCall2Ready
            LD   HL,$2222
            LD   A,5
            LD   SP,($A100+17)
            LD   IX,($A100+19)
            PUSH AF
            XOR  A
            LD   ($A100+6),A
            POP  AF
            LD   ($A100+1),A
            XOR  A
            LD   ($A100+2),A
            LD   ($A100+3),HL
            LD   A,3
            LD   ($A100),A
            JP   $A200
ProofExpectedSourceCall2Ready:
            LD   A,2
            LD   HL,$C234
            CALL $A000+RewriteBackendFarCallVectorOffset
            CALL ProofRuntimeBase+NucleusRuntimeActivationReleaseOffset

            CALL ProofRuntimeBase+NucleusRuntimeActivationClaimOffset
            JR   NC,ProofExpectedSourceCall3Ready
            LD   HL,$4444
            LD   A,5
            LD   SP,($A100+17)
            LD   IX,($A100+19)
            PUSH AF
            XOR  A
            LD   ($A100+6),A
            POP  AF
            LD   ($A100+1),A
            XOR  A
            LD   ($A100+2),A
            LD   ($A100+3),HL
            LD   A,3
            LD   ($A100),A
            JP   $A200
ProofExpectedSourceCall3Ready:
ProofExpectedSourceCall3:
            CALL 0
            PUSH AF
            CALL ProofRuntimeBase+NucleusRuntimeActivationReleaseOffset
            POP  AF
            JR   NC,ProofExpectedSourceCall3Success
            LD   C,A
            POP  DE
            POP  DE
            LD   A,C
ProofExpectedSourceHandler:
            JP   0
ProofExpectedSourceCall3Success:
            POP  DE
ProofExpectedSourceCallsEnd:
