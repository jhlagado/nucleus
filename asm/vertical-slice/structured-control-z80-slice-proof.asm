NativeStreamingSource .equ 0
; Prove typed if/elseif/else, while, counted for, and loop transfers end to end.

            .include "memory-map.asmi"
SegmentedOutput .equ 0
TargetStreamingOutput .equ 0
            .include "loop-compiler-state.asmi"
            .include "loop-z80-state.asmi"

            .org MMCORE
KCSTART:
LegacyCompilerSlices .equ 1
AggregateCallSlices  .equ 0
KCSRC:
            .include "source-adapter.asm"
KCSRCEND:
KCTOKEN:
            .include "loop-tokenizer.asm"
KCTOKEND:
KCSEM:
            .include "loop-semantic-sink.asm"
KCSEMEND:
KCSYM:
            .include "loop-symbols.asm"
KCSYMEND:
KCPARSER:
            .include "compiler-profile-legacy.asmi"
            .include "loop-parser.asm"
KCPAREND:
KCCOMEND:
KCSINK:
LegacyEncoders .equ 0
            .include "loop-z80-sink.asm"
StructuredSinkStart:
            .include "typed-expression-z80.asm"
StructuredSinkEnd:
KCSNKEND:
KCCODEND:
KCIMM:
            .include "loop-keywords.asmi"
KCIMMEND:
KCEND:

            .org MMSOURCE
StructuredAcceptedSource:
            .db "var out as u8 = 0",10
            .db "var finalI as u8 = 0",10
            .db "var finalJ as u16 = 0",10
            .db "forward sub descend(value as u8) as u8",10
            .db "sub main() fails",10
            .db "    var i as u8 = 0",10
            .db "    var j as u16 = 0",10
            .db "    if false",10
            .db "        out = 99",10
            .db "    elseif true",10
            .db "        out = 1",10
            .db "    else",10
            .db "        out = 98",10
            .db "    end",10
            .db "    while out < 3",10
            .db "        out = out + 1",10
            .db "    end",10
            .db "    for i = 0 until 4",10
            .db "        if i = 1",10
            .db "            continue",10
            .db "        end",10
            .db "        if i = 3",10
            .db "            exit",10
            .db "        end",10
            .db "        out = out + i",10
            .db "    end",10
            .db "    for j = 3 to 0 step -1",10
            .db "        out = out + 1",10
            .db "    end",10
            .db "    finalI = i",10
            .db "    finalJ = j",10
            .db "    out = out + descend(3)",10
            .db "    writeOutputByte(out) else fail",10
            .db "end",10
            .db "sub descend",10
            .db "    if value = 0",10
            .db "        return value",10
            .db "    end",10
            .db "    return "
StructuredAcceptedRecursiveCall:
            .db "descend(value - 1)",10
            .db "end",10
StructuredAcceptedSourceEnd:

StructuredRangeSource:
            .db "var out as u8 = 0",10
            .db "var snapshot as i8 = 0",10
            .db "var limit as i8 = 127",10
            .db "sub main() fails",10
            .db "    var i as i8 = 0",10
            .db "    for "
StructuredRangeCounter:
            .db "i = 120 to limit step 10",10
            .db "        out = out + 1",10
            .db "        snapshot = i",10
            .db "    end",10
            .db "end",10
StructuredRangeSourceEnd:

StructuredActiveCounterSource:
            .db "var dummy as u8 = 0",10
            .db "sub main() fails",10
            .db "    var i as u8 = 0",10
            .db "    for i = 0 until 2",10
            .db "        "
StructuredActiveCounterName:
            .db "i = i + 1",10
            .db "    end",10
            .db "end",10
StructuredActiveCounterSourceEnd:

StructuredExitOutsideSource:
            .db "var dummy as u8 = 0",10
            .db "sub main() fails",10
            .db "    "
StructuredExitOutsidePoint:
            .db "exit",10
            .db "end",10
StructuredExitOutsideSourceEnd:

StructuredZeroStepSource:
            .db "var dummy as u8 = 0",10
            .db "sub main() fails",10
            .db "    var i as u8 = 0",10
            .db "    for i = 0 until 2 step "
StructuredZeroStepPoint:
            .db "0",10
            .db "    end",10
            .db "end",10
StructuredZeroStepSourceEnd:

StructuredBooleanFlowSource:
            .db "var flag as boolean = false",10
            .db "forward sub choose(value as boolean) as boolean",10
            .db "sub main() fails",10
            .db "    flag = choose(false)",10
            .db "end",10
            .db "sub choose",10
            .db "    if value",10
            .db "        return false",10
            .db "    else",10
            .db "        return true",10
            .db "    end",10
            .db "    value = false",10
            .db "end",10
StructuredBooleanFlowSourceEnd:

StructuredStrayElseSource:
            .db "sub main() fails",10
StructuredStrayElsePoint:
            .db "else",10
StructuredStrayElseSourceEnd:
StructuredStrayElseIfSource:
            .db "sub main() fails",10
StructuredStrayElseIfPoint:
            .db "elseif true",10
StructuredStrayElseIfSourceEnd:

StructuredSecondForwardSource:
            .db "forward sub first(value as u8) as u8",10
            .db "forward sub "
StructuredSecondForwardPoint:
            .db "second(value as u8) as u8",10
StructuredSecondForwardSourceEnd:
StructuredProgramForwardSource:
            .db "var clash as u8 = 0",10
            .db "forward sub "
StructuredProgramForwardPoint:
            .db "clash(value as u8) as u8",10
StructuredProgramForwardSourceEnd:
StructuredLocalForwardSource:
            .db "forward sub work(value as u8) as u8",10
            .db "sub main() fails",10
            .db "    var "
StructuredLocalForwardPoint:
            .db "work as u8 = 0",10
StructuredLocalForwardSourceEnd:
StructuredMainForwardSource:
            .db "forward sub "
StructuredMainForwardPoint:
            .db "main(value as u8) as u8",10
StructuredMainForwardSourceEnd:
StructuredParameterForwardSource:
            .db "forward sub same("
StructuredParameterForwardPoint:
            .db "same as u8) as u8",10
StructuredParameterForwardSourceEnd:

StructuredProgramMainSource:
            .db "var "
StructuredProgramMainPoint:
            .db "main as u8 = 0",10
StructuredProgramMainSourceEnd:
StructuredLocalMainSource:
            .db "sub main() fails",10
            .db "    var "
StructuredLocalMainPoint:
            .db "main as u8 = 0",10
StructuredLocalMainSourceEnd:
StructuredParameterMainSource:
            .db "forward sub work("
StructuredParameterMainPoint:
            .db "main as u8) as u8",10
StructuredParameterMainSourceEnd:

            .org MMRUN
RTSTART:
RuntimeProofServices .equ 1
RuntimePacketGateway .equ 0
            .include "proof-z80-runtime.asm"
RTEND:

            .org MMPROOF
.routine out carry,zero clobbers sign,parity,halfCarry,A,BC,DE,HL,IX,IY
FPSTART:
            LD   SP,STACKTOP
            XOR  A
            LD   (FPCASE),A
            LD   (FPSTATUS),A
            LD   (SVFAIL),A

            LD   A,110
            LD   HL,StructuredAcceptedSource
            LD   DE,StructuredAcceptedSourceEnd
            CALL CPSL
            JP   C,ProofFailAcceptedCompile
            CALL ZXPROG
            JP   C,ProofFailAcceptedEncode
            CALL RESET
            CALL ProofCallGenerated
            JP   C,ProofFailAcceptedFrame
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,ProofFailAcceptedState
            LD   A,(VOUTLEN)
            CP   1
            JP   NZ,ProofFailAcceptedOutput
            LD   A,(VOUTBAS)
            LD   (AcceptedObservedOutput),A
            ; The harness independently checks the observed byte while this
            ; proof continues to discriminate storage and final counters.
            LD   A,(MMGEN+3)
            LD   (AcceptedObservedStore),A
            LD   A,(MMGEN+4)
            LD   (AcceptedObservedCounter),A
            LD   HL,(MMGEN+5)
            LD   (AcceptedObservedDescending),HL
            LD   HL,(GNSZ)
            LD   (StructuredGeneratedSize),HL

            ; A failed Z80-emission transaction must leave the published
            ; program byte-for-byte runnable.
            LD   A,(MMGEN)
            LD   (AtomicObservedByte),A
            LD   HL,MMGEN+1
            CALL ZEBEGIN
            XOR  A
            CALL EMITBYTE
            JP   C,ProofFailAtomicSetup
            CALL EMITBYTE
            JP   NC,ProofFailAtomicAccepted
            CALL ZEABORT
            LD   A,(MMGEN)
            LD   B,A
            LD   A,(AtomicObservedByte)
            CP   B
            JP   NZ,ProofFailAtomicByte
            LD   HL,(GNSZ)
            LD   DE,(StructuredGeneratedSize)
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailAtomicSize

            ; The same program must unwind a capacity trap from recursive
            ; routine depth back to the outer machine frame.
            CALL RESET
            LD   A,3
            LD   (RTACTLIM),A
            CALL ProofCallGenerated
            JP   C,ProofFailCapacityFrame
            LD   A,(RUNSTATE)
            CP   RTTRAP
            JP   NZ,ProofFailCapacityState
            LD   A,(RTTRPNO)
            CP   5
            JP   NZ,ProofFailCapacityNumber
            LD   A,(RTDEPTH)
            OR   A
            JP   NZ,ProofFailCapacityDepth
            LD   HL,(RTTRPOFF)
            LD   DE,StructuredAcceptedRecursiveCall-StructuredAcceptedSource
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailCapacityOffset

            LD   A,111
            LD   HL,StructuredRangeSource
            LD   DE,StructuredRangeSourceEnd
            CALL CPSL
            JP   C,ProofFailRangeCompile
            CALL ZXPROG
            JP   C,ProofFailRangeEncode
            CALL RESET
            CALL ProofCallGenerated
            JP   C,ProofFailRangeFrame
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,ProofFailRangeState
            LD   A,(RTDEPTH)
            OR   A
            JP   NZ,ProofFailRangeOffset
            LD   A,(MMGEN+3)
            LD   (RangeObservedEffect),A
            CP   1
            JP   NZ,ProofFailRangeEffect
            LD   A,(MMGEN+4)
            LD   (RangeObservedAtomic),A
            CP   120
            JP   NZ,ProofFailRangeAtomic

            LD   A,112
            LD   HL,StructuredActiveCounterSource
            LD   DE,StructuredActiveCounterSourceEnd
            LD   B,DGACTCTR
            LD   IX,StructuredActiveCounterName-StructuredActiveCounterSource
            CALL ProofExpectDiagnostic
            LD   A,(DGCODE)
            LD   (ActiveObservedDiagnostic),A
            LD   HL,(DGOFF)
            LD   (ActiveObservedOffset),HL

            LD   A,113
            LD   HL,StructuredExitOutsideSource
            LD   DE,StructuredExitOutsideSourceEnd
            LD   B,DXLOOP
            LD   IX,StructuredExitOutsidePoint-StructuredExitOutsideSource
            CALL ProofExpectDiagnostic
            LD   A,(DGCODE)
            LD   (ExitObservedDiagnostic),A
            LD   HL,(DGOFF)
            LD   (ExitObservedOffset),HL

            LD   A,114
            LD   HL,StructuredZeroStepSource
            LD   DE,StructuredZeroStepSourceEnd
            LD   B,DGLOPSTP
            LD   IX,StructuredZeroStepPoint-StructuredZeroStepSource
            CALL ProofExpectDiagnostic
            LD   A,(DGCODE)
            LD   (StepObservedDiagnostic),A
            LD   HL,(DGOFF)
            LD   (StepObservedOffset),HL

            LD   A,115
            LD   HL,StructuredBooleanFlowSource
            LD   DE,StructuredBooleanFlowSourceEnd
            CALL CPSL
            JP   C,ProofFailBooleanFlowCompile
            CALL ZXPROG
            JP   C,ProofFailBooleanFlowEncode
            CALL RESET
            CALL ProofCallGenerated
            JP   C,ProofFailBooleanFlowFrame
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,ProofFailBooleanFlowState
            LD   A,(MMGEN+3)
            CP   1
            JP   NZ,ProofFailBooleanFlowValue

            LD   A,116
            LD   HL,StructuredStrayElseSource
            LD   DE,StructuredStrayElseSourceEnd
            LD   B,DXEND
            LD   IX,StructuredStrayElsePoint-StructuredStrayElseSource
            CALL ProofExpectDiagnostic
            JP   C,ProofFailStrayElse
            LD   A,117
            LD   HL,StructuredStrayElseIfSource
            LD   DE,StructuredStrayElseIfSourceEnd
            LD   B,DXEND
            LD   IX,StructuredStrayElseIfPoint-StructuredStrayElseIfSource
            CALL ProofExpectDiagnostic
            JP   C,ProofFailStrayElseIf

            LD   A,118
            LD   HL,StructuredSecondForwardSource
            LD   DE,StructuredSecondForwardSourceEnd
            LD   B,DGDUPNAM
            LD   IX,StructuredSecondForwardPoint-StructuredSecondForwardSource
            CALL ProofExpectDiagnostic
            JP   C,ProofFailSecondForward
            LD   A,119
            LD   HL,StructuredProgramForwardSource
            LD   DE,StructuredProgramForwardSourceEnd
            LD   B,DGDUPNAM
            LD   IX,StructuredProgramForwardPoint-StructuredProgramForwardSource
            CALL ProofExpectDiagnostic
            JP   C,ProofFailProgramForward
            LD   A,120
            LD   HL,StructuredLocalForwardSource
            LD   DE,StructuredLocalForwardSourceEnd
            LD   B,DGDUPNAM
            LD   IX,StructuredLocalForwardPoint-StructuredLocalForwardSource
            CALL ProofExpectDiagnostic
            JP   C,ProofFailLocalForward
            LD   A,121
            LD   HL,StructuredMainForwardSource
            LD   DE,StructuredMainForwardSourceEnd
            LD   B,DGDUPNAM
            LD   IX,StructuredMainForwardPoint-StructuredMainForwardSource
            CALL ProofExpectDiagnostic
            JP   C,ProofFailMainForward
            LD   A,122
            LD   HL,StructuredParameterForwardSource
            LD   DE,StructuredParameterForwardSourceEnd
            LD   B,DGDUPNAM
            LD   IX,StructuredParameterForwardPoint-StructuredParameterForwardSource
            CALL ProofExpectDiagnostic
            JP   C,ProofFailParameterForward
            LD   A,124
            LD   HL,StructuredProgramMainSource
            LD   DE,StructuredProgramMainSourceEnd
            LD   B,DGDUPNAM
            LD   IX,StructuredProgramMainPoint-StructuredProgramMainSource
            CALL ProofExpectDiagnostic
            JP   C,ProofFailProgramMain
            LD   A,125
            LD   HL,StructuredLocalMainSource
            LD   DE,StructuredLocalMainSourceEnd
            LD   B,DGDUPNAM
            LD   IX,StructuredLocalMainPoint-StructuredLocalMainSource
            CALL ProofExpectDiagnostic
            JP   C,ProofFailLocalMain
            LD   A,126
            LD   HL,StructuredParameterMainSource
            LD   DE,StructuredParameterMainSourceEnd
            LD   B,DGDUPNAM
            LD   IX,StructuredParameterMainPoint-StructuredParameterMainSource
            CALL ProofExpectDiagnostic
            JP   C,ProofFailParameterMain
            LD   A,123
            LD   HL,StructuredLabelCapacitySource
            LD   DE,StructuredLabelCapacitySourceEnd
            LD   B,DGCLBCAP
            LD   IX,StructuredLabelCapacityPoint-StructuredLabelCapacitySource
            CALL ProofExpectDiagnostic
            JP   C,ProofFailLabelCapacity

            LD   A,$A5
            LD   (FPSTATUS),A
            HALT

; A part, HL..DE source, B diagnostic, IX expected offset.
.routine in A,B,DE,HL,IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IY
ProofExpectDiagnostic:
            PUSH BC
            PUSH IX
            CALL CPSL
            POP  IX
            POP  BC
            RET  NC
            LD   A,(DGCODE)
            CP   B
            JR   NZ,ProofExpectedDiagnosticNo
            LD   HL,(DGOFF)
            PUSH IX
            POP  DE
            OR   A
            SBC  HL,DE
            RET  Z
ProofExpectedDiagnosticNo:
            SCF
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
ProofCallGenerated:
            LD   HL,0
            ADD  HL,SP
            LD   (ProofExpectedSP),HL
            LD   IX,$A55A
            CALL MMGEN
            PUSH IX
            POP  DE
            LD   HL,$A55A
            OR   A
            SBC  HL,DE
            JR   NZ,ProofCallGeneratedNo
            LD   HL,0
            ADD  HL,SP
            LD   DE,(ProofExpectedSP)
            OR   A
            SBC  HL,DE
            RET  Z
ProofCallGeneratedNo:
            SCF
            RET

ProofFailAcceptedCompile:     LD A,1
                              JP ProofFailed
ProofFailAcceptedEncode:      LD A,2
                              JP ProofFailed
ProofFailAcceptedFrame:       LD A,3
                              JP ProofFailed
ProofFailAcceptedState:       LD A,4
                              JP ProofFailed
ProofFailAcceptedOutput:      LD A,5
                              JP ProofFailed
ProofFailAcceptedValue:       LD A,6
                              JP ProofFailed
ProofFailAcceptedStore:       LD A,7
                              JP ProofFailed
ProofFailAcceptedCounter:     LD A,8
                              JP ProofFailed
ProofFailAcceptedDescending:  LD A,9
                              JP ProofFailed
ProofFailedNear:              JP ProofFailed
ProofFailCapacityFrame:       LD A,21
                              JR ProofFailedNear
ProofFailCapacityState:       LD A,22
                              JR ProofFailedNear
ProofFailCapacityNumber:      LD A,23
                              JR ProofFailedNear
ProofFailCapacityDepth:       LD A,24
                              JR ProofFailedNear
ProofFailCapacityOffset:      LD A,25
                              JR ProofFailedNear
ProofFailRangeCompile:        LD A,10
                              JR ProofFailedNear
ProofFailRangeEncode:         LD A,11
                              JR ProofFailedNear
ProofFailRangeFrame:          LD A,12
                              JR ProofFailedNear
ProofFailRangeState:          LD A,13
                              JR ProofFailedNear
ProofFailRangeNumber:         LD A,14
                              JR ProofFailedNear
ProofFailRangeOffset:         LD A,15
                              JR ProofFailedNear
ProofFailRangeEffect:         LD A,16
                              JR ProofFailedNear
ProofFailRangeAtomic:         LD A,17
                              JR ProofFailedNear
ProofFailActiveCounter:       LD A,18
                              JR ProofFailedNear
ProofFailExitOutside:         LD A,19
                              JR ProofFailedNear
ProofFailZeroStep:            LD A,20
                              JR ProofFailedNear
ProofFailAtomicSetup:         LD A,26
                              JR ProofFailedNear
ProofFailAtomicAccepted:      LD A,27
                              JR ProofFailedNear
ProofFailAtomicByte:          LD A,28
                              JR ProofFailedNear
ProofFailAtomicSize:          LD A,29
                              JR ProofFailedNear
ProofFailBooleanFlowCompile:  LD A,30
                              JR ProofFailedNear
ProofFailBooleanFlowEncode:   LD A,31
                              JR ProofFailedNear
ProofFailBooleanFlowFrame:    LD A,32
                              JR ProofFailedNear
ProofFailBooleanFlowState:    LD A,33
                              JR ProofFailedNear
ProofFailBooleanFlowValue:    LD A,34
                              JR ProofFailedNear
ProofFailStrayElse:           LD A,35
                              JR ProofFailedNear
ProofFailStrayElseIf:         LD A,36
                              JR ProofFailedNear
ProofFailSecondForward:       LD A,37
                              JR ProofFailedNear
ProofFailProgramForward:      LD A,38
                              JR ProofFailedNear
ProofFailLocalForward:        LD A,39
                              JR ProofFailedNear
ProofFailMainForward:         LD A,40
                              JR ProofFailedNear
ProofFailParameterForward:    LD A,41
                              JR ProofFailed
ProofFailLabelCapacity:       LD A,42
                              JR ProofFailed
ProofFailProgramMain:         LD A,43
                              JR ProofFailed
ProofFailLocalMain:           LD A,44
                              JR ProofFailed
ProofFailParameterMain:       LD A,45
ProofFailed:
            LD   (FPCASE),A
            LD   A,$E0
            LD   (FPSTATUS),A
            HALT

ProofExpectedSP:              .dw 0
StructuredGeneratedSize:     .dw 0
AcceptedObservedOutput:      .db 0
AcceptedObservedStore:       .db 0
AcceptedObservedCounter:     .db 0
AcceptedObservedDescending:  .dw 0
RangeObservedEffect:         .db 0
RangeObservedAtomic:         .db 0
ActiveObservedDiagnostic:    .db 0
ActiveObservedOffset:        .dw 0
ExitObservedDiagnostic:      .db 0
ExitObservedOffset:          .dw 0
StepObservedDiagnostic:      .db 0
StepObservedOffset:          .dw 0
AtomicObservedByte:          .db 0
FPSTATUS:                  .db 0
FPCASE:                    .db 0
GeneratedTypedEnd            .equ MMGEN+715
FPEND:

            ; Retain the fixture at $9800 while emitting images in address order.
            .org MMSPARE
StructuredLabelCapacitySource:
            .db "sub main() fails",10
            .db "    if true",10,"    end",10
            .db "    if true",10,"    end",10
            .db "    if true",10,"    end",10
            .db "    if true",10,"    end",10
            .db "    if true",10,"    end",10
            .db "    if true",10,"    end",10
            .db "    if true",10,"    end",10
            .db "    if true",10,"    end",10
            .db "    if true",10,"    end",10
            .db "    if true",10,"    end",10
            .db "    if true",10,"    end",10
            .db "    if true",10,"    end",10
            .db "    if true",10,"    end",10
            .db "    if true",10,"    end",10
            .db "    if true",10,"    end",10
            .db "    "
StructuredLabelCapacityPoint:
            .db "if true",10,"    end",10
            .db "end",10
StructuredLabelCapacitySourceEnd:
            .end
