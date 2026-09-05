; Streaming direct-Z80 encoder for the counted-loop semantic stream.

.routine in A out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
EmitByte:
.if TargetStreamingOutput
            LD   B,A
            LD   HL,(EMLIM)
            LD   A,H
            OR   L
            JP   Z,TargetCapacityFailure
            DEC  HL
            LD   (EMLIM),HL
            LD   HL,(EMCUR)
            PUSH BC
            LD   A,(TGOUTBNK)
            LD   C,A
            LD   A,B
            PUSH HL
            CALL TSBYTE
            POP  HL
            POP  BC
            JP   C,TargetOutputFailure
            INC  HL
            LD   (EMCUR),HL
            OR   A
            RET
.else
            LD   B,A
            LD   HL,(EMCUR)
            LD   DE,(EMLIM)
            OR   A
            SBC  HL,DE
            ADD  HL,DE
            JP   Z,SemanticSinkPutFull
EmitByteRoom:
            LD   A,B
            LD   (HL),A
            INC  HL
            LD   (EMCUR),HL
            OR   A
            RET
.endif

.routine noreturn
EmitByteInline:
            POP  HL
            LD   A,(HL)
            JR   EmitByte

.routine noreturn
EmitByteInlineChecked:
            POP  HL
            LD   A,(HL)
            INC  HL
            PUSH HL
.if CompilerDiagnosticReturns
            CALL EmitByte
            RET  NC
            POP  HL
            RET
.else
            JR   EmitByte
.endif

.routine noreturn
EmitPairIndexedInline:
            POP  HL
            LD   A,(HL)
            INC  HL
            PUSH HL
.routine in A out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
EmitPairIndexed:
            ADD  A,A
            LD   L,A
            LD   H,0
            LD   DE,EmitPairInlineTable
            ADD  HL,DE
.if TargetStreamingOutput
            JR   EmitPair
.else
            JP   EmitPair
.endif

EmitPairDecSp2          .equ 0
EmitPairLoadIXL         .equ 1
EmitPairLoadIXH         .equ 2
EmitPairStoreIXL        .equ 3
EmitPairStoreIXH        .equ 4
EmitPairPopDEHL         .equ 5
EmitPairPopDEPushDE     .equ 6
EmitPairTestL           .equ 7
EmitPairTestH           .equ 8
EmitPairPopHLToA        .equ 9
EmitPairPopHLLoadDE     .equ 10
EmitPairPopHLDE         .equ 11
EmitPairZeroH           .equ 12
EmitPairLDIR            .equ 13
EmitPairAdd8            .equ 14
EmitPairSubtract8       .equ 15
EmitPairAnd8            .equ 16
EmitPairOr8             .equ 17
EmitPairXor8            .equ 18
EmitPairPopHLBC         .equ 19
EmitPairInlineTable:
            .db  $3B,$3B                 ; DEC SP / DEC SP
            .db  $DD,$6E                 ; LD L,(IX+n)
            .db  $DD,$66                 ; LD H,(IX+n)
            .db  $DD,$75                 ; LD (IX+n),L
            .db  $DD,$74                 ; LD (IX+n),H
            .db  $D1,$E1                 ; POP DE / POP HL
            .db  $D1,$D5                 ; POP DE / PUSH DE
            .db  $7D,$B7                 ; LD A,L / OR A
            .db  $7C,$B7                 ; LD A,H / OR A
            .db  $E1,$7D                 ; POP HL / LD A,L
            .db  $E1,$11                 ; POP HL / LD DE,nn
            .db  $E1,$D1                 ; POP HL / POP DE
            .db  $26,$00                 ; LD H,0
            .db  $ED,$B0                 ; LDIR
            .db  $7D,$83                 ; LD A,L / ADD A,E
            .db  $7D,$93                 ; LD A,L / SUB E
            .db  $7D,$A3                 ; LD A,L / AND E
            .db  $7D,$B3                 ; LD A,L / OR E
            .db  $7D,$AB                 ; LD A,L / XOR E
            .db  $E1,$C1                 ; POP HL / POP BC

.routine in HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
EmitWord:
            LD   C,H
            LD   A,L
            CALL EmitByte
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,C
            JR   EmitByte

; Copy B retained opcode bytes. Shared fixed sequences are cheaper as data
; once two or more encoder paths need four or more emitted bytes.
.routine in B,HL out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
EmitBytes:
.if TargetStreamingOutput
            PUSH BC
            LD   C,B
            LD   B,0
            CALL EmitBlock
            POP  BC
            RET
.else
            LD   A,(HL)
            INC  HL
            PUSH BC
            PUSH HL
            CALL EmitByte
            POP  HL
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            DJNZ EmitBytes
            OR   A
            RET
.endif

.if TargetStreamingOutput
; Copy the complete BC-byte region through the checked output sink.
.routine in BC,HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
EmitBlock:
            LD   A,B
            OR   C
            RET  Z
            LD   A,(HL)
            INC  HL
            PUSH BC
            PUSH HL
            CALL EmitByte
            POP  HL
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            DEC  BC
            JR   EmitBlock
.endif

.routine in HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
EmitEight:
            LD   B,8
            JR   EmitGo
.routine in HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
EmitFive:
            LD   B,5
            JR   EmitGo
.routine in HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
EmitFour:
            LD   B,4
            JR   EmitGo
.routine in HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
EmitThree:
            LD   B,3
            JR   EmitGo
.routine in HL out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
EmitPair:
            LD   B,2
.routine in B,HL out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
EmitGo:
            JR   EmitBytes

; Patch one Z80 relative displacement. DE is the operand and HL the target.
.routine in DE,HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL,IX,IY
PatchRelative:
            LD   (EMPATCH),DE
            INC  DE
            OR   A
            SBC  HL,DE
            LD   C,L
            LD   A,C
            ADD  A,A
            SBC  A,A
            CP   H
            JR   NZ,PatchInvalid
PatchStore:
.if TargetStreamingOutput
            LD   B,C
            LD   HL,(EMPATCH)
            LD   A,(TGOUTBNK)
            LD   C,A
            LD   A,B
            CALL TSPATBYT
            JP   C,TargetOutputFailure
            OR   A
            RET
.else
            LD   DE,(EMPATCH)
            LD   A,C
            LD   (DE),A
            OR   A
            RET
.endif
PatchInvalid:
            CALL DGINLINE
            .db  DGFIXRNG

.if TargetStreamingOutput
.else
.routine in HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
BeginProgram:
            LD   (EMLIM),HL
            LD   BC,(GNSZ)
            LD   (PUSZ),BC
            LD   A,B
            OR   C
            JR   Z,BeginProgramReady
            LD   HL,MMGEN
            LD   DE,MMBACK
            LDIR
BeginProgramReady:
            LD   HL,MMGEN
            LD   (EMCUR),HL
            OR   A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
AbortProgram:
            LD   BC,(PUSZ)
            LD   A,B
            OR   C
            JR   Z,AbortProgramSize
            LD   HL,MMBACK
            LD   DE,MMGEN
            LDIR
AbortProgramSize:
            LD   HL,(PUSZ)
            LD   (GNSZ),HL
            SCF
            RET
.endif

.if AggregateCallSlices
.if TargetStreamingOutput
.else
; Initialize the fixed adapter table, retain all previously published segment
; sizes, and back up both image-bearing segments before tentative emission.
.routine in HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
BeginSegmentedProgram:
            PUSH HL
            LD   HL,GNSZ
            LD   DE,PUSZ
            LD   BC,8
            LDIR
            LD   BC,(GNSZ)
            LD   HL,MMGENCOD
            LD   DE,MMBACK
            CALL SegmentCopyIfAny
            LD   BC,(GNROSZ)
            LD   HL,RORDATA
            LD   DE,MMBACK+(RORDATA-MMGEN)
            CALL SegmentCopyIfAny
            LD   HL,SegmentInitialTable
            LD   DE,SGTABBAS
            LD   BC,SGENTSZ*SGCAP
            LDIR
            POP  HL
            LD   (SGCDENT+SGENTLIM),HL

            CALL ValidateSegmentTable
.if CompilerDiagnosticReturns
            RET  C
.endif
            XOR  A
            RET

SegmentInitialTable:
            .dw MMGENCOD,MMGCEND
            .dw RORDATA,MMROEND
            .dw MMDATA,MMDATEND
            .dw MMBSS,MMBSSEND

.routine in BC,DE,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
SegmentCopyIfAny:
            LD   A,B
            OR   C
            RET  Z
            LDIR
            OR   A
            RET

; Only the two image-bearing segments are selectable by the byte emitter. A is
; an internal SegmentCode/SegmentRoData ordinal supplied at the two call sites.
; Their current cursors remain cached in EmitCursor/EmitLimit and are written
; back to the bounded table at each segment switch and at publication.
.routine in A out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
SelectOutputSegment:
            OR   A
            JR   NZ,SelectOutputSegmentRoData
            LD   DE,(EMCUR)
            LD   (SGROCUR),DE
            LD   HL,SGCDENT
            JR   SelectOutputSegmentReady
SelectOutputSegmentRoData:
            LD   HL,SGROENT
SelectOutputSegmentReady:
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            LD   (EMCUR),DE
            INC  HL
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            LD   (EMLIM),DE
            OR   A
            RET

; The adapter owns two ordered ROM-image segments and two ordered RAM
; segments. Reject malformed or overlapping target maps before one byte can
; be published.
.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
ValidateSegmentTable:
            LD   IX,SGTABBAS
            LD   B,SGCAP
ValidateSegmentEntryLoop:
            LD   L,(IX+SGENTBAS)
            LD   H,(IX+SGENTBAS+1)
            LD   E,(IX+SGENTLIM)
            LD   D,(IX+SGENTLIM+1)
            OR   A
            SBC  HL,DE
            JR   NC,SegmentTableFailure
            LD   DE,SGENTSZ
            ADD  IX,DE
            DJNZ ValidateSegmentEntryLoop
            LD   HL,(SGCDENT+SGENTLIM)
            LD   DE,(SGROENT+SGENTBAS)
            CALL SegmentRequireOrder
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,(SGDATENT+SGENTLIM)
            LD   DE,(SGBSSENT+SGENTBAS)
.routine in DE,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
SegmentRequireOrder:
            OR   A
            SBC  HL,DE
            JR   C,SegmentOrderReady
            RET  Z
            JR   SegmentTableFailure
SegmentOrderReady:
            OR   A
            RET
SegmentTableFailure:
            CALL DGINLINE
            .db  DGOUTSEG

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
AbortSegmentedProgram:
            LD   BC,(PUSZ)
            LD   HL,MMBACK
            LD   DE,MMGENCOD
            CALL SegmentCopyIfAny
            LD   BC,(PUROSZ)
            LD   HL,MMBACK+(RORDATA-MMGEN)
            LD   DE,RORDATA
            CALL SegmentCopyIfAny
            LD   HL,PUSZ
            LD   DE,GNSZ
            LD   BC,8
            LDIR
            SCF
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,DE,HL
FinishSegmentedProgram:
            LD   HL,(EMCUR)
            LD   DE,MMGENCOD
            OR   A
            SBC  HL,DE
            LD   (GNSZ),HL
            LD   HL,(SGROCUR)
            LD   DE,RORDATA
            OR   A
            SBC  HL,DE
            LD   (GNROSZ),HL
            LD   HL,(IMGLEN)
            LD   (GNDATSZ),HL
            LD   HL,(PGBSSLEN)
            LD   (GNBSSSZ),HL
            OR   A
            RET
.endif
.endif

.if LegacyEncoders
.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
EncodeLoopProgram:
            CALL EncodeLoopProgramBody
            JR   EncodeProgramResult
.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
EncodeCallProgram:
            CALL EncodeCallProgramBody
            JR   EncodeProgramResult
.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
EncodeExpressionProgram:
            CALL EncodeExpressionProgramBody
            JR   EncodeProgramResult
.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
EncodeArrayProgram:
            LD   HL,MMGENLIM
            JR   EncodeArrayProgramWithinLimit
.routine in HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
EncodeArrayProgramWithinLimit:
            CALL EncodeArrayProgramBody
EncodeProgramResult:
            RET  NC
            JP   AbortProgram

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
EncodeLoopProgramBody:
            LD   HL,MMGENLIM
            CALL BeginProgram

            LD   A,(SMBUFBAS+2)
            CALL EmitLoadDImmediate
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(SMBUFBAS+4)
            CALL EmitLoadDImmediate
.if CompilerDiagnosticReturns
            RET  C
.endif

            LD   HL,(EMCUR)
            LD   (EMLOOP),HL
            CALL EmitByteInlineChecked
            .db  $7A
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(SMBUFBAS+5)
            CALL EmitCompareImmediate
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitJrNcPlaceholder
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   (EMEXIT),DE

            LD   A,(SMBUFBAS+7)
            CALL EmitLoadAImmediate
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,RTWRITE
            CALL EmitCall
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,$38
            CALL EmitRelativePlaceholder
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   (EMFAIL),DE
            CALL EmitByteInlineChecked
            .db  $7A
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(SMBUFBAS+5)
            DEC  A
            CALL EmitCompareImmediate
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitJrNcPlaceholder
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   (EMUPEXIT),DE
            CALL EmitByteInlineChecked
            .db  $14
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitJrPlaceholder
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,(EMLOOP)
            CALL PatchRelative
.if CompilerDiagnosticReturns
            RET  C
.endif

            LD   DE,(EMEXIT)
            CALL PatchHere
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   DE,(EMUPEXIT)
            CALL PatchHere
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitSuccessReturn
.if CompilerDiagnosticReturns
            RET  C
.endif

            LD   DE,(EMFAIL)
            CALL PatchHere
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,LPFAIL
            CALL EmitLoadHl
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitUnhandledTrapPrefix
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitTrapEnding
.if CompilerDiagnosticReturns
            RET  C
.endif

            JP   FinishProgram
.endif

; Small instruction emitters shared by the direct back end. Multiple entry
; points share the opcode-plus-operand tails rather than repeating them in
; every semantic operation.
.routine in A,HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
EmitOpcodeWord:
            PUSH HL
            CALL EmitByte
            POP  HL
.if CompilerDiagnosticReturns
            RET  C
.endif
.if TargetStreamingOutput
            JR   EmitWord
.else
            JP   EmitWord
.endif

.routine in HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
EmitCall:
            LD   A,$CD
            JR   EmitOpcodeWord

.routine in HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
EmitLoadHl:
            LD   A,$21
            JR   EmitOpcodeWord

.routine in HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
EmitLoadBcImmediate:
            LD   A,$01
            JR   EmitOpcodeWord

.routine in HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
EmitStoreA:
            LD   A,$32
            JR   EmitOpcodeWord

.if TargetStreamingOutput
; Emit LD (state-base+DE),A through the target-linked writable-state address.
.routine in DE out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
EmitStoreTargetStateA:
            CALL TargetStateAddress
            JR   EmitStoreA
.endif

.routine in A,C out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
EmitOpcodeByte:
            CALL EmitByte
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,C
            JP   EmitByte

.routine in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
EmitLoadAImmediate:
            LD   C,A
            LD   A,$3E
            JR   EmitOpcodeByte

.if LegacyEncoders
.routine in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
EmitLoadDImmediate:
            LD   C,A
            LD   A,$16
            JP   EmitOpcodeByte

.routine in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
EmitCompareImmediate:
            LD   C,A
            LD   A,$FE
            JP   EmitOpcodeByte
.endif

.if LegacyEncoders
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
EmitLoadScalar:
            LD   HL,RTSCALAR
            LD   A,$3A
            JP   EmitOpcodeWord

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
EmitRestoreAfterCall:
            CALL EmitByteInlineChecked
            .db  $F5
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,RTAPOP
            CALL EmitCall
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,$F1
            JP   EmitByte
.endif

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
EmitSuccessReturn:
            LD   A,RTSUCC
            JR   EmitRunEnding

; At runtime A carries the trap number and HL carries the source offset.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
EmitTrapEnding:
.if TargetStreamingOutput
            LD   DE,RTTRPNO-RTSTATE
            CALL EmitStoreTargetStateA
.else
            LD   HL,RTTRPNO
            CALL EmitStoreA
.endif
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitByteInlineChecked
            .db  $AF
.if CompilerDiagnosticReturns
            RET  C
.endif
.if TargetStreamingOutput
            LD   DE,RTTRPRTN-RTSTATE
            CALL EmitStoreTargetStateA
.else
            LD   HL,RTTRPRTN
            CALL EmitStoreA
.endif
.if CompilerDiagnosticReturns
            RET  C
.endif
.if TargetStreamingOutput
            LD   DE,RTTRPOFF-RTSTATE
            CALL TargetStateAddress
.else
            LD   HL,RTTRPOFF
.endif
            LD   A,$22
            CALL EmitOpcodeWord
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,RTTRAP
.routine in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
EmitRunEnding:
            CALL EmitLoadAImmediate
.if CompilerDiagnosticReturns
            RET  C
.endif
.if TargetStreamingOutput
            LD   DE,RUNSTATE-RTSTATE
            CALL EmitStoreTargetStateA
.else
            LD   HL,RUNSTATE
            CALL EmitStoreA
.endif
.if CompilerDiagnosticReturns
            RET  C
.endif
.if TargetStreamingOutput
            LD   A,(TDENTVAL)
            LD   D,A
            LD   A,(TGOUTBNK)
            CP   D
            JR   Z,EmitRunEndingLocal
            LD   A,D
            CALL EmitLoadAImmediate
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,(TGTERM)
            CALL EmitLoadHl
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,10                     ; far-jump vector ordinal
            JP   EmitTargetVectorJump
EmitRunEndingLocal:
            LD   HL,(TGTERM)
            LD   A,$C3
            JR   EmitOpcodeWord
.else
            LD   A,$C9
            JP   EmitByte
.endif

; At runtime A carries an unhandled error and HL the failing source offset.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
EmitUnhandledTrapPrefix:
.if TargetStreamingOutput
            LD   DE,RTTRPERR-RTSTATE
            CALL EmitStoreTargetStateA
.else
            LD   HL,RTTRPERR
            CALL EmitStoreA
.endif
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,6
            JR   EmitLoadAImmediate

.routine out A,carry,zero,DE clobbers sign,parity,halfCarry,B,HL
EmitJrPlaceholder:
            LD   A,$18
            JR   EmitRelativePlaceholder
.routine out A,carry,zero,DE clobbers sign,parity,halfCarry,B,HL
EmitJrNcPlaceholder:
            LD   A,$30
.routine in A out A,carry,zero,DE clobbers sign,parity,halfCarry,B,HL
EmitRelativePlaceholder:
            CALL EmitByte
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,(EMCUR)
            PUSH HL
            XOR  A
            CALL EmitByte
            POP  DE
            RET

.if LegacyEncoders
.routine out A,carry,zero,DE clobbers sign,parity,halfCarry,B,HL
EmitJrCPlaceholder:
            LD   A,$38
            JP   EmitRelativePlaceholder
.endif

.routine in DE,HL out A,carry,zero clobbers sign,parity,halfCarry,DE,HL
PatchWord:
.if TargetStreamingOutput
            PUSH BC
            LD   A,(TGOUTBNK)
            LD   C,A
            CALL TSPATWRD
            POP  BC
            JP   C,TargetOutputFailure
            OR   A
            RET
.else
            LD   A,L
            LD   (DE),A
            INC  DE
            LD   A,H
            LD   (DE),A
            OR   A
            RET
.endif

; Patch a stored displacement to the current output position.
.routine in DE out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL,IX,IY
PatchHere:
            LD   HL,(EMCUR)
            JP   PatchRelative

.if TargetStreamingOutput
.else
.routine out A,carry,zero clobbers sign,parity,halfCarry,DE,HL
FinishProgram:
            LD   HL,(EMCUR)
            LD   DE,MMGEN
            OR   A
            SBC  HL,DE
            LD   (GNSZ),HL
            OR   A
            RET
.endif

; Read one operand from the checked semantic transcript. The operation count
; bounds dispatch; individual handlers know the fixed width of their operands.
CallBackendStart:
.routine out A,carry,zero clobbers sign,parity,halfCarry,HL
NextSemanticByte:
            LD   HL,(SMRDCUR)
            LD   A,(HL)
            INC  HL
            LD   (SMRDCUR),HL
            OR   A
            RET

.routine out A,DE,carry,zero clobbers sign,parity,halfCarry,HL
ReadSemanticWord:
            CALL NextSemanticByte
            LD   E,A
            CALL NextSemanticByte
            LD   D,A
            RET

; Dense ordinal dispatcher for the first non-positional backend. A pushed
; continuation turns the Z80's JP (HL) into a compact indirect call. This
; entry is post-parse only: SemanticSinkFinish must have published the complete
; transcript before emitter scratch overlays the retained forward signature.
.if LegacyEncoders
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL,IX,IY
DispatchCallOperations:
            LD   HL,SMPAYBAS
            LD   (SMRDCUR),HL
            LD   A,(SMBUFBAS)
            OR   A
            RET  Z
            LD   B,A
DispatchCallNext:
            PUSH BC
            CALL NextSemanticByte
            SUB  SMCLITU8
            CP   CallOperationCount
            JR   NC,DispatchCallInvalid
            ADD  A,A
            LD   E,A
            LD   D,0
            LD   HL,CallOperationTable
            ADD  HL,DE
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            EX   DE,HL
            LD   DE,DispatchCallReturn
            PUSH DE
            JP   (HL)
DispatchCallReturn:
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            DJNZ DispatchCallNext
            OR   A
            RET
DispatchCallInvalid:
            POP  BC
            CALL DGINLINE
            .db  DGSNKCAP

CallOperationTable:
            .dw CallLiteral
            .dw CallWriteLocal
            .dw CallBeginForward
            .dw CallIfParameterZero
            .dw CallReturnParameter
            .dw CallEndIf
            .dw CallReturnSelfMinus
            .dw CallEndRoutine
CallOperationCount .equ 8

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL,IX,IY
CallLiteral:
            CALL NextSemanticByte
            CALL NextSemanticByte
            CALL EmitLoadAImmediate
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,RTAPUSH
            CALL EmitCall
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitJrCPlaceholder
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   (EMEXIT),DE
            CALL EmitByteInlineChecked
            .db  $CD
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,(EMCUR)
            LD   (EMRTNCFX),HL
            LD   HL,0
            CALL EmitWord
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitRestoreAfterCall
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   DE,(EMEXIT)
            CALL PatchHere
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitJrCPlaceholder
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   (EMUPEXIT),DE
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
CallWriteLocal:
            LD   HL,RTWRITE
            CALL EmitCall
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitJrCPlaceholder
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   (EMFAIL),DE
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
CallBeginForward:
            CALL NextSemanticByte
            LD   HL,(EMCUR)
            LD   (EMRTNADR),HL
            LD   DE,(EMRTNCFX)
            JP   PatchWord

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
CallIfParameterZero:
            CALL NextSemanticByte
            CALL EmitLoadScalar
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitByteInlineChecked
            .db  $B7
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,$20
            CALL EmitRelativePlaceholder
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   (EMIFFIX),DE
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
CallReturnParameter:
            CALL EmitLoadScalar
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,$C9
            JP   EmitByte

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL,IX,IY
CallEndIf:
            LD   DE,(EMIFFIX)
            JP   PatchHere

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
CallReturnSelfMinus:
            CALL NextSemanticByte
            CALL NextSemanticByte
            LD   C,A
            PUSH BC
            CALL EmitLoadScalar
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,$D6
            CALL EmitOpcodeByte
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,RTAPUSH
            CALL EmitCall
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitByteInlineChecked
            .db  $D8
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,(EMRTNADR)
            CALL EmitCall
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitRestoreAfterCall
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,$C9
            JP   EmitByte

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL,IX,IY
CallEndRoutine:
            LD   HL,(EMRTNADR)
            LD   A,H
            OR   L
            RET  NZ
            CALL EmitSuccessReturn
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   DE,(EMUPEXIT)
            CALL PatchHere
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,CLCAPOFF
            CALL EmitLoadHl
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitTrapEnding
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   DE,(EMFAIL)
            CALL PatchHere
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,CLFAIL
            CALL EmitLoadHl
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitUnhandledTrapPrefix
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   EmitTrapEnding

; Compile the routine slice from its variable-width semantic stream.
.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
EncodeCallProgramBody:
            LD   HL,MMGENLIM
            CALL BeginProgram
            LD   HL,0
            LD   (EMRTNADR),HL
            CALL DispatchCallOperations
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   FinishProgram
CallBackendEnd:
.endif

; Dense postfix-expression backend. Program data follows an initial JP, so its
; address is known before the code entry is patched. Scalar locals use an IX
; frame and therefore remain per activation; the evaluation stack lies below
; that frame and is empty at every statement boundary.
.if LegacyEncoders
ExpressionBackendStart:
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL,IX,IY
DispatchExpressionOperations:
            LD   HL,SMPAYBAS
            LD   (SMRDCUR),HL
            LD   A,(SMBUFBAS)
            OR   A
            RET  Z
            LD   B,A
DispatchExpressionNext:
            PUSH BC
            CALL NextSemanticByte
            SUB  SMDEFPU8
            CP   ExpressionOperationCount
            JR   NC,DispatchExpressionInvalid
            ADD  A,A
            LD   E,A
            LD   D,0
            LD   HL,ExpressionOperationTable
            ADD  HL,DE
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            EX   DE,HL
            LD   DE,DispatchExpressionReturn
            PUSH DE
            JP   (HL)
DispatchExpressionReturn:
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            DJNZ DispatchExpressionNext
            OR   A
            RET
DispatchExpressionInvalid:
            POP  BC
            CALL DGINLINE
            .db  DGSNKCAP

ExpressionOperationTable:
            .dw ExpressionDefineProgram
            .dw ExpressionBeginMain
            .dw ExpressionDeclareLocal
            .dw ExpressionLiteral
            .dw ExpressionLoadProgram
            .dw ExpressionLoadLocal
            .dw ExpressionMultiply
            .dw ExpressionAdd
            .dw ExpressionStoreProgram
            .dw ExpressionStoreLocal
            .dw ExpressionWrite
            .dw ExpressionEndMain
ExpressionOperationCount .equ 12
.endif

.routine out A,HL,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,IX,IY
ExpressionProgramAddress:
.if AggregateCallSlices
            CALL ReadSemanticWord
.if TargetStreamingOutput
            BIT  7,D
            JR   Z,ExpressionTargetDataAddress
            RES  7,D
            LD   HL,(TGBSSBAS)
            JR   ExpressionTargetAddressReady
ExpressionTargetDataAddress:
            LD   HL,(TCDATBAS)
ExpressionTargetAddressReady:
            ADD  HL,DE
            OR   A
            RET
.else
            LD   H,D
            LD   L,E
            OR   A
            RET
.endif
.else
            CALL NextSemanticByte
            LD   E,A
            LD   D,0
            LD   HL,MMGEN+3
            ADD  HL,DE
            RET
.endif

.if LegacyEncoders
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
ExpressionDefineProgram:
            CALL NextSemanticByte
            CALL NextSemanticByte
            JP   EmitByte

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ExpressionBeginMain:
            LD   DE,(EMDATFIX)
            LD   HL,(EMCUR)
            CALL PatchWord
            LD   HL,ExpressionFrameBytes
            JP   EmitEight

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
ExpressionDeclareLocal:
            CALL NextSemanticByte
            LD   A,$3B
            JP   EmitByte

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ExpressionLiteral:
            CALL NextSemanticByte
            CALL EmitLoadAImmediate
.if CompilerDiagnosticReturns
            RET  C
.endif
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
ExpressionPushA:
            LD   A,$F5
            JP   EmitByte

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ExpressionLoadProgram:
            CALL NextSemanticByte
            CALL ExpressionProgramAddress
            LD   A,$3A
            CALL EmitOpcodeWord
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   ExpressionPushA

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ExpressionLoadLocal:
            CALL NextSemanticByte
            CPL
            LD   C,A
            CALL EmitByteInlineChecked
            .db  $DD
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,$7E
            CALL EmitOpcodeByte
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   ExpressionPushA

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ExpressionMultiply:
            CALL EmitByteInlineChecked
            .db  $C1
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitByteInlineChecked
            .db  $F1
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,RTMUL8
            CALL EmitCall
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,$F5
            JP   EmitByte

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
ExpressionAdd:
            LD   HL,ExpressionAddBytes
            JP   EmitFour

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ExpressionStoreProgram:
            CALL NextSemanticByte
            CALL ExpressionProgramAddress
            PUSH HL
            LD   A,$F1
            CALL EmitByte
            POP  HL
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,$32
            JP   EmitOpcodeWord

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ExpressionStoreLocal:
            CALL NextSemanticByte
            CPL
            LD   C,A
            CALL EmitByteInlineChecked
            .db  $F1
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitByteInlineChecked
            .db  $DD
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,$77
            JP   EmitOpcodeByte

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ExpressionWrite:
            CALL NextSemanticByte
            LD   C,A
            CALL NextSemanticByte
            LD   H,A
            LD   L,C
            LD   (EMLOOP),HL
            CALL EmitByteInlineChecked
            .db  $F1
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,RTWRITE
            CALL EmitCall
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitJrCPlaceholder
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   (EMFAIL),DE
            RET
.endif

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
ExpressionRestoreFrame:
            LD   HL,ExpressionRestoreBytes
            JP   EmitFour

.if LegacyEncoders
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ExpressionEndMain:
            CALL ExpressionRestoreFrame
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitSuccessReturn
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   DE,(EMFAIL)
            CALL PatchHere
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL ExpressionRestoreFrame
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,(EMLOOP)
            CALL EmitLoadHl
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitUnhandledTrapPrefix
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   EmitTrapEnding

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
EncodeExpressionProgramBody:
            LD   HL,MMGENLIM
            CALL BeginProgram
            CALL EmitByteInlineChecked
            .db  $C3
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,(EMCUR)
            LD   (EMDATFIX),HL
            LD   HL,0
            CALL EmitWord
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL DispatchExpressionOperations
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   FinishProgram
.endif
ExpressionFrameBytes:
            .db $DD,$E5,$DD,$21,$00,$00,$DD,$39
.if LegacyEncoders
ExpressionAddBytes:
            .db $C1,$F1,$80,$F5
.endif
ExpressionRestoreBytes:
            .db $DD,$F9,$DD,$E1
.if LegacyEncoders
ExpressionBackendEnd:

; Default entry and proof-only bounded entry for the checked-array program.
.routine in HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
EncodeArrayProgramBody:
            CALL BeginProgram

            LD   HL,RTREADIN
            CALL EmitCall
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitJrNcPlaceholder
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   (EMEXIT),DE
            LD   HL,ARYIFAIL
            CALL EmitLoadHl
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitJrPlaceholder
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   (EMFAIL),DE

            LD   DE,(EMEXIT)
            CALL PatchHere
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(SMBUFBAS+2)
            CALL EmitCompareImmediate
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitJrNcPlaceholder
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   (EMUPEXIT),DE
            CALL EmitByteInlineChecked
            .db  $5F
.if CompilerDiagnosticReturns
            RET  C
.endif
            XOR  A
            CALL EmitLoadDImmediate
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitByteInlineChecked
            .db  $21
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,(EMCUR)
            LD   (EMDATFIX),HL
            LD   HL,0
            CALL EmitWord
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitByteInlineChecked
            .db  $19
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitByteInlineChecked
            .db  $7E
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,RTWRITE
            CALL EmitCall
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitJrNcPlaceholder
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   (EMLOOP),DE
            LD   HL,ARYOFAIL
            CALL EmitLoadHl
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitJrPlaceholder
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   (EMCODST),DE

            LD   DE,(EMLOOP)
            CALL PatchHere
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitSuccessReturn
.if CompilerDiagnosticReturns
            RET  C
.endif

            LD   DE,(EMUPEXIT)
            CALL PatchHere
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,ARYBOFF
            CALL EmitLoadHl
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitByteInlineChecked
            .db  $AF
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,RTTRPERR
            CALL EmitStoreA
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,1
            CALL EmitLoadAImmediate
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitJrPlaceholder
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   (EMEXIT),DE

            LD   DE,(EMFAIL)
            CALL PatchHere
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   DE,(EMCODST)
            CALL PatchHere
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitUnhandledTrapPrefix
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   DE,(EMEXIT)
            CALL PatchHere
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitTrapEnding
.if CompilerDiagnosticReturns
            RET  C
.endif

            LD   HL,(EMCUR)
            LD   DE,(EMDATFIX)
            CALL PatchWord
            LD   HL,SMBUFBAS+3
            LD   C,4
EmitArrayData:
            LD   A,(HL)
            PUSH HL
            CALL EmitByte
            POP  HL
.if CompilerDiagnosticReturns
            RET  C
.endif
            INC  HL
            DEC  C
            JR   NZ,EmitArrayData
            JP   FinishProgram
.endif
