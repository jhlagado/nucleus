; Aggregate Z80 publisher. The complete checked initialized-data and constant
; image is emitted after
; the initial JP and before main's first instruction. TypedBeginMain
; patches the JP operand to the first code byte, so source execution cannot
; observe initialization in progress.

.if TargetStreamingOutput
; Emit every aggregate constant exactly once in declaration order. Symbols
; retain per-bank offsets, while IY walks the single declaration-ordered
; compiler backing image. Switching banks never replays source or semantics.
.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
TargetEmitBankedAggregateConstants:
            LD   IY,IMGBAS
            LD   DE,(IMGLEN)
            ADD  IY,DE
            LD   A,(SYCNT)
            OR   A
            LD   B,A
            JR   Z,TargetEmitBankedStringLiterals
            LD   C,0
            LD   IX,SYTABBAS
TargetEmitBankedConstantSymbolLoop:
            LD   A,(IX+3)
            LD   D,A
            AND  SYAGGFLG+SCMSK
            CP   SYAGGFLG+SCCONST
            JR   NZ,TargetEmitBankedConstantNext
            LD   A,D
            CALL TargetUnpackBank
            PUSH BC
            CALL TargetSelectOutputBank
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(IX+SYTYPID)
            CALL AggregateGetExtent
            EX   DE,HL
TargetEmitBankedConstantByteLoop:
            LD   A,D
            OR   E
            JR   Z,TargetEmitBankedConstantNext
            LD   A,(IY+0)
            INC  IY
            PUSH BC
            PUSH DE
            CALL EmitByte
            POP  DE
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            DEC  DE
            JR   TargetEmitBankedConstantByteLoop
TargetEmitBankedConstantNext:
            LD   DE,SYENTSZ
            ADD  IX,DE
            INC  C
            DJNZ TargetEmitBankedConstantSymbolLoop

; Anonymous literal objects follow all named aggregate constants in the
; staging image. Their compiler-only final byte retains the source bank;
; publish the preceding sealed bytes and restore the permanent zero.
TargetEmitBankedStringLiterals:
            LD   HL,IMGBAS
            LD   DE,(IMGLEN)
            ADD  HL,DE
            LD   DE,(ROILEN)
            ADD  HL,DE
            PUSH HL
            POP  IX                      ; end of staged read-only bytes
            PUSH IY
            POP  HL                      ; first anonymous literal
TargetEmitBankedStringLiteralLoop:
            PUSH IX
            POP  DE
            OR   A
            SBC  HL,DE
            RET  Z
            ADD  HL,DE                   ; restore the current object
            LD   C,(HL)
            LD   A,C
            OR   A
            JR   NZ,TargetEmitBankedStringExtentReady
            INC  BC                      ; empty literal capacity is one
TargetEmitBankedStringExtentReady:
            INC  BC
            INC  BC
            PUSH HL
            PUSH BC
            ADD  HL,BC
            DEC  HL
            LD   A,(HL)                  ; compiler-only source bank
            LD   (HL),0                  ; publish the permanent terminator
            CALL TargetSelectOutputBank
            POP  BC
            POP  HL
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitBlock
.if CompilerDiagnosticReturns
            RET  C
.endif
            JR   TargetEmitBankedStringLiteralLoop
.endif

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
EncodeAggregateProgram:
.if TargetStreamingOutput
            LD   IX,(TDPTR)
            CALL BeginTargetFlatProgram
.if CompilerDiagnosticBranches
            JP   C,AbortTargetProgram
.endif
.else
.if AggregateCallSlices
            LD   HL,MMGCEND
.else
            LD   HL,MMGENLIM
.endif
.endif
.routine in HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
EncodeAggregateProgramWithinLimit:
.if TargetStreamingOutput
            CALL TargetCompareSingleBank
            JR   NZ,AggregateDispatch
            ; BeginTargetFlatProgram already selected the first read-only byte.
            CALL TargetLoadLayoutMode
            JR   Z,AggregateTargetLoadedRoData
            CALL TargetEmitRuntimeInitialImage
.if CompilerDiagnosticBranches
            JP   C,AggregateAbortProgram
.endif
            JR   AggregateTargetCopyReady
AggregateTargetLoadedRoData:
            LD   HL,IMGBAS
            LD   DE,(IMGLEN)
            ADD  HL,DE
            LD   BC,(ROILEN)
            JR   AggregateTargetCopySelected
AggregateTargetCopyReady:
.else
.if AggregateCallSlices
            CALL BeginSegmentedProgram
            JP   C,AbortSegmentedProgram
            LD   A,SGRODAT
            CALL SelectOutputSegment
.else
            CALL EncodeProgramHeader
            JP   C,AbortProgram
.endif
.endif
.if SegmentedOutput
            LD   HL,(ROILEN)
            LD   BC,(IMGLEN)
            ADD  HL,BC
            LD   B,H
            LD   C,L
            LD   HL,IMGBAS
.else
            LD   HL,IMGBAS
            LD   BC,(IMGLEN)
.endif
.if TargetStreamingOutput
AggregateTargetCopySelected:
            CALL EmitBlock
.if CompilerDiagnosticBranches
            JP   C,AggregateAbortProgram
.endif
.else
            LD   A,B
            OR   C
            JR   Z,AggregateDispatch
AggregateCopyLoop:
            LD   A,(HL)
            INC  HL
            PUSH BC
            PUSH HL
            CALL EmitByte
            POP  HL
            POP  BC
            JP   C,AggregateAbortProgram
            DEC  BC
            LD   A,B
            OR   C
            JR   NZ,AggregateCopyLoop
.endif
AggregateDispatch:
.if TargetStreamingOutput
            CALL TargetCompareSingleBank
            JR   NZ,AggregateTargetBoundsReady
            LD   HL,(EMCUR)
            LD   (TGCODBAS),HL
            CALL TargetLoadLayoutMode
            JR   NZ,AggregateTargetCodeReady
            LD   HL,(TGCODCAP)
            LD   (EMLIM),HL
AggregateTargetCodeReady:
            LD   HL,(TCROBAS)
            LD   (TGCRBAS),HL
            LD   HL,(TCROCAP)
            LD   (TGCROCAP),HL
AggregateTargetBoundsReady:
.else
.if AggregateCallSlices
            LD   A,SGCODE
            CALL SelectOutputSegment
            CALL EncodeSegmentedProgramHeader
            JP   C,AbortSegmentedProgram
.endif
.endif
            CALL TypedDispatch
.if CompilerDiagnosticBranches
            JP   C,AggregateAbortProgram
.endif
.if TargetStreamingOutput
            JP   FinishTargetFlatProgram
.else
.if AggregateCallSlices
            JP   FinishSegmentedProgram
.else
            JP   FinishProgram
.endif
.endif

.if TargetStreamingOutput
AggregateAbortProgram .equ AbortTargetProgram
.else
.if AggregateCallSlices
AggregateAbortProgram .equ AbortSegmentedProgram
.else
AggregateAbortProgram .equ AbortProgram
.endif
.endif
