; Correctness-first direct-Z80 backend for the complete scalar-expression
; increment. All evaluation values use canonical 16-bit carriers on the Z80
; stack. Declared u8/boolean objects still occupy one byte; u16 occupies two.

; Typed dispatch and loop dispatch are currently mutually exclusive. These
; aliases make the temporary reuse visible; merging the dispatchers requires
; dedicated storage or a new liveness proof.
EmitTypedTrapPosition .equ EmitLoopHead
EmitTypedWidth        .equ EmitCodeStart
EmitTypedDestination  .equ EmitCodeStart+1

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL,IX,IY
TypedDispatch:
            LD   HL,SemanticPayloadBase
            LD   (SemanticReadCursor),HL
            XOR  A
            LD   (EmitBooleanFixupDepth),A
            LD   (EmitControlFixupCount),A
            LD   HL,EmitControlLabelValidBase
.if TargetStreamingOutput
            LD   B,EmitControlLabelCapacity*EmitControlLabelSize
.else
            LD   B,EmitControlLabelCapacity
.endif
TypedResetControlLabels:
            LD   (HL),A
            INC  HL
            DJNZ TypedResetControlLabels
            LD   A,(SemanticBufferBase)
            OR   A
.if TargetStreamingOutput
.if DebugHooks
            JR   Z,TypedDispatchComplete
.else
            RET  Z
.endif
.else
            RET  Z
.endif
            LD   B,A
TypedDispatchNext:
            PUSH BC
.if TargetStreamingOutput
.if DebugHooks
            OUT  (DebugTraceSemanticStartPort),A
.endif
.endif
            CALL NextSemanticByte
            SUB  SemanticDefineProgramU8
            CP   TypedOperationCount
            JR   NC,TypedInvalidPopped
            CALL TypedPrefetchFirstOperand
            LD   B,A
            LD   A,C
            ADD  A,A
            LD   E,A
            LD   D,0
            LD   HL,TypedOperationTable
            ADD  HL,DE
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            LD   A,B
            EX   DE,HL
            LD   DE,TypedDispatchReturn
            PUSH DE
            JP   (HL)
TypedDispatchReturn:
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            DJNZ TypedDispatchNext
.if TargetStreamingOutput
.if DebugHooks
            CALL StructuredResolveFixups
.if CompilerDiagnosticReturns
            RET  C
.endif
TypedDispatchComplete:
            OUT  (DebugTraceSemanticEndPort),A
            RET
.else
            JP   StructuredResolveFixups
.endif
.else
            JP   StructuredResolveFixups
.endif
TypedInvalidPopped:
            POP  BC
TypedInternalOperation:
            JP   TypedExpressionStackUnderflow
TypedBooleanFixupCapacity:
            CALL SetDiagInline
            .db  DiagnosticBooleanFixupCapacity

TypedPrefetchBits:
            .db $05,$70,$00,$00,$C0,$81,$5F,$C2,$05,$00,$7C,$04,$04

TypedOperationTable:
            .dw TypedDefine8          ; 20
            .dw TypedBeginMain        ; 21
            .dw TypedDeclare8         ; 22
            .dw TypedInternalOperation ; 23 retired literal8
            .dw TypedLoadProgram8     ; 24
            .dw TypedLoadLocal8       ; 25
            .dw TypedInternalOperation ; 26 retired multiply8
            .dw TypedInternalOperation ; 27 retired add8
            .dw TypedStoreProgram8    ; 28
            .dw TypedStoreLocal8      ; 29
            .dw TypedWrite8           ; 30
            .dw TypedEndMain          ; 31
            .dw TypedDefine16         ; 32
            .dw TypedDeclare16        ; 33
            .dw TypedLiteral16        ; 34
            .dw TypedLoadProgram16    ; 35
            .dw TypedLoadLocal16      ; 36
            .dw TypedAdd8             ; 37
            .dw TypedAdd16            ; 38
            .dw TypedSubtract8        ; 39
            .dw TypedSubtract16       ; 40
            .dw TypedMultiply8        ; 41
            .dw TypedMultiply16       ; 42
            .dw TypedDivide8          ; 43
            .dw TypedDivide16         ; 44
            .dw TypedNegate8          ; 45
            .dw TypedNegate16         ; 46
            .dw TypedNot8             ; 47
            .dw TypedNot16            ; 48
            .dw TypedNotBoolean       ; 49
            .dw TypedAnd8             ; 50
            .dw TypedAnd16            ; 51
            .dw TypedOr8              ; 52
            .dw TypedOr16             ; 53
            .dw TypedXor8             ; 54
            .dw TypedXor16            ; 55
            .dw TypedModulo8          ; 56
            .dw TypedModulo16         ; 57
            .dw TypedCompare          ; 58
            .dw TypedCompare          ; 59
            .dw TypedCompare          ; 60
            .dw TypedNarrow8          ; 61
            .dw TypedStoreProgram16   ; 62
            .dw TypedStoreLocal16     ; 63
            .dw TypedBeginAnd         ; 64
            .dw TypedBeginOr          ; 65
            .dw TypedEndBoolean       ; 66
            .dw StructuredLabel       ; 67
            .dw StructuredBranchFalse ; 68
            .dw StructuredJump        ; 69
            .dw StructuredForSetup    ; 70
            .dw StructuredForTest     ; 71
            .dw StructuredForNext     ; 72
            .dw StructuredForCleanup  ; 73
            .dw TypedBeginRoutine     ; 74
            .dw TypedLoadLocal8       ; 75 parameter u8
            .dw TypedLoadLocal16      ; 76 parameter u16
            .dw TypedCallScalar       ; 77
            .dw TypedReturnScalar     ; 78
            .dw TypedStoreLocal8      ; 79 parameter u8
            .dw TypedStoreLocal16     ; 80 parameter u16
            .dw TypedEndRoutine       ; 81
.if AggregateCallSlices
            .dw Stage7BeginRoutine    ; 82
            .dw Stage7BindParameter   ; 83
            .dw Stage7Call            ; 84
            .dw Stage7ReturnAggregate ; 85
            .dw Stage7EndRoutine      ; 86
            .dw Stage7LoadProgramAlias ; 87
            .dw Stage7LoadParameterAlias ; 88
            .dw Stage7SelectField     ; 89
            .dw Stage7SelectIndex     ; 90
            .dw Stage7LoadIndirect8   ; 91
            .dw Stage7LoadIndirect16  ; 92
            .dw Stage7StoreIndirect8  ; 93
            .dw Stage7StoreIndirect16 ; 94
            .dw Stage7CopyAggregate   ; 95
            .dw Stage7StringLength    ; 96
            .dw Stage7StringIndex     ; 97
            .dw Stage8FailRoutine     ; 98
            .dw Stage8FailMain        ; 99
            .dw Stage8ReturnSuccess   ; 100
            .dw Stage8ReturnSuccess   ; 101
            .dw Stage8EndFailableRoutine ; 102
            .dw Stage8SkipHandler     ; 103
            .dw Stage8BeginHandler    ; 104
            .dw Stage8EndHandler      ; 105
            .dw Stage8BeginCallableMain ; 106
            .dw Stage7LoadReadOnlyAlias ; 107
            .dw Stage7OpenStringLength ; 108
            .dw Stage7OpenStringIndex  ; 109
            .dw Stage7PrepareOpenArgument ; 110
            .dw Stage7EmitStringCapacityValue ; 111
            .dw Stage7StringResize   ; 112
            .dw Stage7ArrayLength    ; 113
            .dw Stage7OpenArrayLength ; 114
            .dw Stage7OpenArrayIndex ; 115
            .dw TypedConvertInteger  ; 116
            .dw TypedDivideSigned    ; 117
            .dw TypedPromoteI8Pair   ; 118
TypedOperationCount .equ 99
.else
TypedOperationCount .equ 62
.endif

; Operand-prefetch metadata is deliberately separate from the full-width
; handler addresses. C returns the zero-based operation index. For marked
; operations A returns the first operand; otherwise A is scratch.
.routine in A out A,C,carry,zero clobbers sign,parity,halfCarry,B,D,E,HL
TypedPrefetchFirstOperand:
            LD   C,A
            AND  7
            LD   B,A
            INC  B
            LD   A,C
            RRCA
            RRCA
            RRCA
            AND  $1F
            LD   E,A
            LD   D,0
            LD   HL,TypedPrefetchBits
            ADD  HL,DE
            LD   A,(HL)
TypedPrefetchBitLoop:
            RRCA
            DJNZ TypedPrefetchBitLoop
            RET  NC
            JP   NextSemanticByte

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
TypedDefine8:
            CALL NextSemanticByte     ; value
            JP   EmitByte

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
TypedDefine16:
            CALL NextSemanticByte
            CALL EmitByte
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL NextSemanticByte
            JP   EmitByte

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
TypedBeginMain:
            CALL TypedBeginProgramFrame
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,ExpressionFrameBytes
            JP   EmitEight

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
TypedBeginProgramFrame:
            LD   DE,(EmitDataFixup)
            LD   HL,(EmitCursor)
            CALL PatchWord
            JP   TypedSaveRootFrame

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
TypedDeclare8:
            CALL EmitByteInline
            .db  $3B                      ; DEC SP

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
TypedDeclare16:
            CALL TypedDeclare8
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitByteInline
            .db  $3B

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
TypedLiteral16:
            LD   C,A
            CALL NextSemanticByte
            LD   H,A
            LD   L,C
            LD   A,$21                    ; LD HL,nn
.routine in A,HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
TypedEmitOpcodeWordPushHL:
            CALL EmitOpcodeWord
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitByteInline
            .db  $E5                      ; PUSH HL

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
TypedLoadProgram8:
            CALL ExpressionProgramAddress
            LD   A,$3A                    ; LD A,(nn)
            CALL EmitOpcodeWord
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,TypedAtoHL
            JP   EmitFour

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
TypedLoadProgram16:
            CALL ExpressionProgramAddress
            LD   A,$2A                    ; LD HL,(nn)
            JR   TypedEmitOpcodeWordPushHL

; C receives -(byte offset + 1), the displacement of the low byte from IX.
.routine out A,C,carry,zero clobbers sign,parity,halfCarry,B,D,DE,HL
TypedLocalDisplacement:
            CALL NextSemanticByte
            CPL
            LD   C,A
            OR   A
            RET

.routine in C,HL out A,C,carry,zero clobbers sign,parity,halfCarry,B,D,DE,HL
TypedEmitIndexed:
            LD   B,2
            CALL EmitBytes
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,C
            JP   EmitByte

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
TypedEmitPopHL:
            CALL EmitByteInline
            .db  $E1                      ; POP HL

.routine out A,C,carry,zero clobbers sign,parity,halfCarry,B,D,DE,HL
TypedLoadLocalLowIndexed:
            CALL TypedLocalDisplacement
            LD   HL,TypedLoadLocalLow
            JR   TypedEmitIndexed

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
TypedLoadLocal8:
            CALL TypedLoadLocalLowIndexed
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,TypedZeroHighPush
            JP   EmitThree

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
TypedLoadLocal16:
            CALL TypedLoadLocalLowIndexed
.if CompilerDiagnosticReturns
            RET  C
.endif
            DEC  C
            LD   HL,TypedLoadLocalHigh
            CALL TypedEmitIndexed
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitByteInline
            .db  $E5

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
TypedPopOperands:
            LD   HL,TypedPopOperandsBytes
            JP   EmitPair

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
TypedPushHL:
            CALL EmitByteInline
            .db  $E5

.routine in C,HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
TypedEmitSequence:
            PUSH HL
            CALL TypedPopOperands
            POP  HL
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   B,C
            CALL EmitBytes
.if CompilerDiagnosticReturns
            RET  C
.endif
            JR   TypedPushHL

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
TypedAdd8:
            LD   C,EmitPairAdd8
            JR   TypedBinary8
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
TypedSubtract8:
            LD   C,EmitPairSubtract8
            JR   TypedBinary8
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
TypedXor8:
            LD   C,EmitPairXor8
            JR   TypedBinary8
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
TypedAnd8:
            LD   C,EmitPairAnd8
            JR   TypedBinary8
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
TypedOr8:
            LD   C,EmitPairOr8
.routine in C out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
TypedBinary8:
            CALL TypedPopOperands
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,C
            CALL EmitPairIndexed
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,TypedAtoHL
            JP   EmitFour

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
TypedXor16:
            LD   HL,TypedXor16Bytes
            JR   TypedBinary6
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
TypedAnd16:
            LD   HL,TypedAnd16Bytes
            JR   TypedBinary6
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
TypedOr16:
            LD   HL,TypedOr16Bytes
.routine in HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
TypedBinary6:
            LD   C,6
            JR   TypedEmitSequence

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
TypedAdd16:
            LD   HL,TypedAdd16Bytes
            LD   C,1
            JR   TypedEmitSequence
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
TypedSubtract16:
            LD   HL,TypedSubtract16Bytes
            LD   C,3
            JR   TypedEmitSequence

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
TypedMultiply8:
            CALL TypedMultiply
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitPairIndexedInline
            .db  EmitPairZeroH
.if CompilerDiagnosticReturns
            RET  C
.endif
            JR   TypedPushHL
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
TypedMultiply16:
            CALL TypedMultiply
.if CompilerDiagnosticReturns
            RET  C
.endif
            JR   TypedPushHL
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
TypedMultiply:
            CALL TypedPopOperands
.if CompilerDiagnosticReturns
            RET  C
.endif
.if TargetStreamingOutput
            LD   DE,NucleusRuntimeMultiplyU16Offset
            JP   EmitRuntimeCall
.else
            LD   HL,MultiplyU16
            JP   EmitCall
.endif

; Emit a call whose carry-clear success path must skip a generated failure
; outcome. DE returns the branch operand for the caller to patch.
.routine in HL out A,DE,carry,zero clobbers sign,parity,halfCarry,B,C,HL
TypedEmitFailableCall:
            CALL EmitCall
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   EmitJrNcPlaceholder

.if TargetStreamingOutput
.routine in DE out A,DE,carry,zero clobbers sign,parity,halfCarry,B,C,HL
TypedEmitFailableRuntimeCall:
            CALL EmitRuntimeCall
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   EmitJrNcPlaceholder
.endif

.routine out A,DE,HL,carry,zero clobbers sign,parity,halfCarry
TypedReadTrapPosition:
            CALL ReadSemanticWord
            LD   (EmitTypedTrapPosition),DE
            RET

.routine in DE out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
TypedEmitTrapHead:
            LD   (EmitExitFixup),DE
            LD   HL,(EmitTypedTrapPosition)
            JP   EmitLoadHl

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL,IX,IY
TypedDivide8:
            LD   C,$80
            JR   TypedDivide
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL,IX,IY
TypedDivide16:
            LD   C,0
            JR   TypedDivide
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL,IX,IY
TypedModulo8:
            LD   C,$81
            JR   TypedDivide
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL,IX,IY
TypedModulo16:
            LD   C,1
            JR   TypedDivide
TypedDivideSigned:
            CALL NextSemanticByte
            LD   C,A
TypedDivide:
            CALL TypedReadTrapPosition
            LD   A,C
            LD   (EmitTypedWidth),A
            CALL TypedPopOperands
.if CompilerDiagnosticReturns
            RET  C
.endif
.if TargetStreamingOutput
            LD   DE,NucleusRuntimeDivideU16Offset
.else
            LD   HL,DivideU16
.endif
            LD   A,(EmitTypedWidth)
            BIT  6,A
            JR   NZ,TypedDivideSignedCall
            BIT  0,A
            JR   Z,TypedDivideCall
.if TargetStreamingOutput
            LD   DE,NucleusRuntimeModuloU16Offset
.else
            LD   HL,ModuloU16
.endif
TypedDivideCall:
.if TargetStreamingOutput
            CALL TypedEmitFailableRuntimeCall
.else
            CALL TypedEmitFailableCall
.endif
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,3
            CALL TypedEmitCurrentTrap
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(EmitTypedWidth)
            BIT  7,A
            JR   Z,TypedDividePush
            CALL EmitPairIndexedInline
            .db  EmitPairZeroH
.if CompilerDiagnosticReturns
            RET  C
.endif
TypedDividePush:
            JP   TypedPushHL

TypedDivideSignedCall:
            LD   A,(EmitTypedWidth)
            CALL EmitLoadAImmediate
.if CompilerDiagnosticReturns
            RET  C
.endif
.if TargetStreamingOutput
            LD   DE,NucleusRuntimeDivideSignedOffset
.else
            LD   HL,DivideSigned
.endif
            JR   TypedDivideCall

.if AggregateCallSlices
; Promote the selected i8 operand in an i16 common expression. The production
; parser emits mode 0 for the right carrier and mode 1 for the left carrier.
.routine in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL,IX,IY
TypedPromoteI8Pair:
            LD   (EmitTypedWidth),A
            CALL TypedPopOperands
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(EmitTypedWidth)
            CALL EmitLoadAImmediate
.if CompilerDiagnosticReturns
            RET  C
.endif
.if TargetStreamingOutput
            LD   DE,NucleusRuntimePromoteI8PairOffset
            CALL EmitRuntimeCall
.else
            LD   HL,RuntimePromoteI8Pair
            CALL EmitCall
.endif
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,TypedPushOperandsBytes
            JP   EmitPair
.endif

.routine noreturn
TypedUnaryInline:
            POP  HL
            LD   B,(HL)
            INC  HL
            CALL EmitBytes
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   TypedPushHL

; The length byte is compiler metadata.  The following ordinary Z80
; instructions are the target template copied by TypedUnaryInline; the
; noreturn call keeps the compiler from ever executing through the data.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL,IX,IY
TypedNegate8:
            CALL TypedUnaryInline
            .db  6
TypedNegate8Bytes:
            POP  HL
            XOR  A
            SUB  L
            LD   L,A
            LD   H,0
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL,IX,IY
TypedNegate16:
            CALL TypedUnaryInline
            .db  8
TypedNegate16Bytes:
            POP  HL
            XOR  A
            SUB  L
            LD   L,A
            LD   A,0
            SBC  A,H
            LD   H,A
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL,IX,IY
TypedNot8:
            CALL TypedUnaryInline
            .db  6
TypedNot8Bytes:
TypedPopHLtoA           .equ TypedNot8Bytes
            POP  HL
            LD   A,L
            CPL
            LD   L,A
            LD   H,0
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL,IX,IY
TypedNot16:
            CALL TypedUnaryInline
            .db  7
TypedNot16Bytes:
            POP  HL
            LD   A,L
            CPL
            LD   L,A
            LD   A,H
            CPL
            LD   H,A
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
TypedNotBoolean:
            CALL TypedUnaryInline
            .db  7
TypedNotBooleanBytes:
            POP  HL
            LD   A,L
            XOR  1
            LD   L,A
            LD   H,0

.routine in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
TypedEmitCompare:
            CALL EmitLoadAImmediate
.if CompilerDiagnosticReturns
            RET  C
.endif
.if TargetStreamingOutput
            LD   DE,NucleusRuntimeCompareU16Offset
            JP   EmitRuntimeCall
.else
            LD   HL,CompareU16
            JP   EmitCall
.endif

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
TypedCompare:
            LD   C,A
            CALL TypedPopOperands
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,C
            CALL TypedEmitCompare
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   TypedPushHL

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
TypedNarrow8:
            CALL TypedReadTrapPosition
            CALL TypedEmitPopHL
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitPairIndexedInline
            .db  EmitPairTestH
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,$28                    ; JR Z,success
            CALL EmitRelativePlaceholder
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,2
            CALL TypedEmitCurrentTrap
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   TypedPushHL

; Convert one canonical integer carrier. The semantic operands are source
; type, destination type, and the conversion's trap position.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
TypedConvertInteger:
            CALL NextSemanticByte
            LD   (EmitTypedWidth),A
            CALL NextSemanticByte
            LD   (EmitTypedDestination),A
            CALL TypedReadTrapPosition
            CALL TypedEmitPopHL
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(EmitTypedWidth)
            CALL EmitLoadAImmediate
.if CompilerDiagnosticReturns
            RET  C
.endif
            ; Deliberate partial target instruction: the compiler emits the
            ; LD C,n opcode now and the dynamic destination-type byte below.
            ; AZM cannot spell an instruction whose immediate is supplied at
            ; compiler runtime; this byte is target data, not compiler code.
            CALL EmitByteInlineChecked
            .db  $0E                      ; LD C,n
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(EmitTypedDestination)
            CALL EmitByte
.if CompilerDiagnosticReturns
            RET  C
.endif
.if TargetStreamingOutput
            LD   DE,NucleusRuntimeConvertIntegerOffset
            CALL TypedEmitFailableRuntimeCall
.else
            LD   HL,ConvertInteger
            CALL TypedEmitFailableCall
.endif
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(EmitTypedDestination)
            RLCA
            LD   A,2
            JR   NC,TypedConvertTrapReady
            DEC  A                        ; signed index conversion uses bounds
TypedConvertTrapReady:
            CALL TypedEmitCurrentTrap
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   TypedPushHL

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
TypedStoreProgram8:
            CALL ExpressionProgramAddress
            PUSH HL
            CALL EmitPairIndexedInline
            .db  EmitPairPopHLToA
            POP  HL
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,$32
            JP   EmitOpcodeWord
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
TypedStoreProgram16:
            CALL ExpressionProgramAddress
            PUSH HL
            CALL TypedEmitPopHL
            POP  HL
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,$22
            JP   EmitOpcodeWord

.routine out A,C,carry,zero clobbers sign,parity,halfCarry,B,D,DE,HL
TypedStoreLocal8:
            CALL TypedLocalDisplacement
            CALL TypedEmitPopHL
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,TypedStoreLocalLow
            JP   TypedEmitIndexed
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
TypedStoreLocal16:
            CALL TypedStoreLocal8
.if CompilerDiagnosticReturns
            RET  C
.endif
            DEC  C
            LD   HL,TypedStoreLocalHigh
            JP   TypedEmitIndexed

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
TypedWrite8:
            CALL TypedReadTrapPosition
            CALL EmitPairIndexedInline
            .db  EmitPairPopHLToA
.if CompilerDiagnosticReturns
            RET  C
.endif
.if TargetStreamingOutput
            LD   A,1
            CALL EmitTargetVectorCall
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitJrNcPlaceholder
.else
            LD   HL,WriteOutputByte
            CALL TypedEmitFailableCall
.endif
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL TypedEmitTrapHead
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitUnhandledTrapPrefix
.if CompilerDiagnosticReturns
            RET  C
.endif
            JR   TypedEmitTrapTail

; Every terminal typed-expression trap must dismantle the routine frame before
; emitting the common trap record and RET. Without this epilogue the generated
; return consumes local bytes or the saved IX value as its return address.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
TypedEmitTrapEnding:
            CALL TypedRestoreRootFrame
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitByteInlineChecked
            .db  $F5                    ; PUSH AF, preserve trap reason
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitByteInlineChecked
            .db  $AF                    ; XOR A
.if CompilerDiagnosticReturns
            RET  C
.endif
.if TargetStreamingOutput
            LD   DE,ActivationDepth-StateBase
            CALL EmitStoreTargetStateA
.else
            LD   HL,ActivationDepth
            CALL EmitStoreA
.endif
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitByteInlineChecked
            .db  $F1                    ; POP AF
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   EmitTrapEnding

; Emit the common terminal trap body for source position HL and trap code A.
; The caller owns and patches the conditional branch around this terminal path.
.routine in A,HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
TypedEmitTrapBody:
            PUSH AF
            CALL EmitLoadHl
.if CompilerDiagnosticBranches
            JR   C,TypedEmitTrapBodyFailure
.endif
            POP  AF
            CALL EmitLoadAImmediate
.if CompilerDiagnosticReturns
            RET  C
.endif
            JR   TypedEmitTrapEnding
.if CompilerDiagnosticBranches
TypedEmitTrapBodyFailure:
            LD   L,A
            POP  BC
            LD   A,L
            SCF
            RET
.endif

; Emit and patch a terminal trap using the retained typed-expression source
; position. A is the trap code and DE the success-branch operand.
.routine in A,DE out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
TypedEmitCurrentTrap:
            PUSH AF
            CALL TypedEmitTrapHead
.if CompilerDiagnosticBranches
            JR   C,TypedEmitTrapBodyFailure
.endif
            POP  AF
            CALL EmitLoadAImmediate
.if CompilerDiagnosticReturns
            RET  C
.endif

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
TypedEmitTrapTail:
            CALL TypedEmitTrapEnding
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   DE,(EmitExitFixup)
            JP   PatchHere

; Save the outer machine frame before main allocates locals, and restore that
; exact frame on every terminal trap, including a trap inside recursive calls.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
TypedSaveRootFrame:
            LD   HL,TypedStoreSPPrefix
            JR   TypedRootFrameReady

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
TypedRestoreRootFrame:
            LD   HL,TypedLoadSPPrefix
.routine in HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
TypedRootFrameReady:
            PUSH HL
            CALL   EmitPair
            POP  HL
.if CompilerDiagnosticReturns
            RET  C
.endif
            PUSH HL
.if TargetStreamingOutput
            LD   DE,RootSP-StateBase
            CALL TargetStateAddress
.else
            LD   HL,RootSP
.endif
            CALL EmitWord
            POP  HL
.if CompilerDiagnosticReturns
            RET  C
.endif
            INC  HL
            INC  HL
            CALL   EmitPair
.if CompilerDiagnosticReturns
            RET  C
.endif
.if TargetStreamingOutput
            LD   DE,RootIX-StateBase
            CALL TargetStateAddress
.else
            LD   HL,RootIX
.endif
            JP   EmitWord

; Begin the single retained value routine. Operand bytes are routine ordinal
; and parameter type. HL carries the copied argument into this entry.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
TypedBeginRoutine:
            CALL NextSemanticByte
            LD   (EmitTypedWidth),A
            LD   C,ControlRoutineLabel
            CALL StructuredDefineLabel
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,ExpressionFrameBytes
            CALL   EmitEight
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(EmitTypedWidth)
            BIT  1,A
            LD   HL,TypedParameter8Bytes
            LD   B,4
            JR   Z,TypedBeginRoutineParameter
            LD   HL,TypedParameter16Bytes
            LD   B,8
TypedBeginRoutineParameter:
            JP   EmitBytes

; Evaluate has already left the copied argument as one canonical carrier.
; Claim activation capacity before the callee begins, then call the fixed
; forward label. The result returns in HL and becomes the enclosing carrier.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
TypedCallScalar:
            CALL NextSemanticByte     ; result type
            LD   (EmitTypedWidth),A
            CALL TypedReadTrapPosition
            CALL TypedEmitPopHL           ; argument
.if CompilerDiagnosticReturns
            RET  C
.endif
.if TargetStreamingOutput
            LD   DE,NucleusRuntimeActivationClaimOffset
            CALL TypedEmitFailableRuntimeCall
.else
            LD   HL,ActivationClaim
            CALL TypedEmitFailableCall
.endif
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,5
            CALL TypedEmitCurrentTrap
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   C,ControlRoutineLabel
            LD   A,$CD                    ; CALL nn
            CALL StructuredEmitFixup
.if CompilerDiagnosticReturns
            RET  C
.endif
.if TargetStreamingOutput
            LD   DE,NucleusRuntimeActivationReleaseOffset
            CALL EmitRuntimeCall
.else
            LD   HL,ActivationRelease
            CALL EmitCall
.endif
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitByteInline
            .db  $E5                      ; PUSH HL result carrier

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
TypedReturnScalar:
            CALL TypedEmitPopHL           ; result
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ExpressionRestoreFrame
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitByteInline
            .db  $C9

.routine out A,carry,zero clobbers sign,parity,halfCarry
TypedEndRoutine:
            XOR  A
            RET

.routine in DE out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
TypedPushBooleanFixup:
            LD   HL,EmitBooleanFixupDepth
            LD   A,(HL)
            CP   EmitBooleanFixupCapacity
            JP   NC,TypedBooleanFixupCapacity
            INC  (HL)
            INC  HL
            LD   C,A
            LD   B,0
            ADD  HL,BC
            ADD  HL,BC
            LD   (HL),E
            INC  HL
            LD   (HL),D
            INC  A
            OR   A
            RET

.routine out A,carry,zero,DE clobbers sign,parity,halfCarry,B,C,HL
TypedPopBooleanFixup:
            LD   HL,EmitBooleanFixupDepth
            LD   A,(HL)
            OR   A
            JP   Z,TypedInternalOperation
            DEC  (HL)
            DEC  A
            INC  HL
            LD   C,A
            LD   B,0
            ADD  HL,BC
            ADD  HL,BC
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            OR   A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL,IX,IY
TypedBeginAnd:
            LD   HL,TypedBeginAndBytes
            LD   B,6
            JR   TypedBeginBoolean
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
TypedBeginOr:
            LD   HL,TypedBeginOrBytes
            LD   B,6
TypedBeginBoolean:
            CALL EmitBytes
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitJrPlaceholder
.if CompilerDiagnosticReturns
            RET  C
.endif
            JR   TypedPushBooleanFixup

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
TypedEndBoolean:
            CALL TypedPopBooleanFixup
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   PatchHere

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL,IX,IY
TypedEndMain:
            LD   A,(EmitBooleanFixupDepth)
            OR   A
            JP   NZ,TypedInternalOperation
            CALL ExpressionRestoreFrame
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   EmitSuccessReturn

; Entry point used by the typed-expression proof.
TypedBackendStart:
.if TargetStreamingOutput
.else
.routine in HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
EncodeProgramHeader:
            CALL BeginProgram
.if AggregateCallSlices
            JR   EncodeProgramEntry

; Emit startup into the code segment. Prepared bytes are copied from rodata
; into initialized RAM, then the complete BSS allocation is cleared before the
; existing entry jump transfers to main.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
EncodeSegmentedProgramHeader:
            LD   HL,(StaticImageLength)
            LD   A,H
            OR   L
            JR   Z,EncodeSegmentedBss
            LD   HL,GeneratedRoDataBase
            CALL EmitLoadHl
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   DE,ProgramDataBase
            CALL EmitLoadDeImmediate
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,(StaticImageLength)
            CALL EmitLoadBcImmediate
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitPairIndexedInline
            .db  EmitPairLDIR
.if CompilerDiagnosticReturns
            RET  C
.endif
EncodeSegmentedBss:
            LD   HL,(ProgramBssLength)
            LD   A,H
            OR   L
            JR   Z,EncodeSegmentedEntry
            LD   HL,ProgramBssBase
            CALL EmitLoadHl
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,(ProgramBssLength)
            CALL EmitLoadBcImmediate
.if CompilerDiagnosticReturns
            RET  C
.endif
.if TargetStreamingOutput
            LD   DE,NucleusRuntimeInitializeBssOffset
            CALL EmitRuntimeCall
.else
            LD   HL,InitializeBss
            CALL EmitCall
.endif
.if CompilerDiagnosticReturns
            RET  C
.endif
EncodeSegmentedEntry:
.endif
EncodeProgramEntry:
            CALL EmitByteInlineChecked
            .db  $C3
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,(EmitCursor)
            LD   (EmitDataFixup),HL
            LD   HL,0
            JP   EmitWord

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
EncodeTypedExpressionProgram:
            LD   HL,GeneratedLimit
            CALL EncodeProgramHeader
            JP   C,AbortProgram
.if AggregateCallSlices
            JP   AggregateDispatch
.else
            CALL TypedDispatch
            JP   C,AbortProgram
            JP   FinishProgram
.endif
TypedBackendEnd:
.endif

.if AggregateCallSlices
SegmentedCopyBytes: .db $ED,$B0           ; LDIR
.endif

            .include "structured-control-z80.asm"
.if AggregateCallSlices
            .include "aggregate-call-z80.asm"
.endif

.if AggregateCallSlices
Stage7LoadIndirect8Prefix: .db $E1,$7E
.endif
TypedAtoHL:             .db $6F,$26,$00,$E5
TypedStoreSPPrefix:     .db $ED,$73
TypedStoreIXPrefix:     .db $DD,$22
TypedLoadSPPrefix:      .db $ED,$7B
TypedLoadIXPrefix:      .db $DD,$2A
TypedParameter16Bytes:  .db $3B,$3B,$DD,$75,$FF,$DD,$74,$FE
TypedParameter8Bytes    .equ TypedParameter16Bytes+1
TypedLoadLocalLow:      .db $DD,$6E
TypedLoadLocalHigh:     .db $DD,$66
TypedStoreLocalLow       .equ TypedParameter16Bytes+2
TypedStoreLocalHigh      .equ TypedParameter16Bytes+5
TypedZeroHighPush       .equ TypedAtoHL+1
TypedZeroHigh           .equ TypedAtoHL+1
TypedPopOperandsBytes:  .db $D1,$E1
.if AggregateCallSlices
TypedPushOperandsBytes: .db $E5,$D5
.endif
.if AggregateCallSlices
TypedAdd16Bytes          .equ Stage7OffsetAddress+3
.else
TypedAdd16Bytes:        .db $19
.endif
TypedSubtract16Bytes:   .db $AF,$ED,$52
TypedAnd16Bytes:        .db $7D,$A3,$6F,$7C,$A2,$67
TypedOr16Bytes:         .db $7D,$B3,$6F,$7C,$B2,$67
TypedXor16Bytes:        .db $7D,$AB,$6F,$7C,$AA,$67
; POP HL; LD A,L; OR A; JR NZ/Z,+3; PUSH HL
TypedBeginAndBytes:     .db $E1,$7D,$B7,$20,$03,$E5
TypedBeginOrBytes:      .db $E1,$7D,$B7,$28,$03,$E5
