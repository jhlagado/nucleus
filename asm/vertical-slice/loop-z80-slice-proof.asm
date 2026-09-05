NativeStreamingSource .equ 0
; Compile and execute the counted-loop source as direct Z80 code.

            .include "memory-map.asmi"
SegmentedOutput .equ 0
TargetStreamingOutput .equ 0
            .include "loop-compiler-state.asmi"
            .include "loop-z80-state.asmi"

            .org MMCORE
KCSTART:
LegacyCompilerSlices .equ 1
AggregateCallSlices  .equ 0
            .include "source-adapter.asm"
            .include "loop-tokenizer.asm"
            .include "loop-semantic-sink.asm"
            .include "loop-symbols.asm"
            .include "compiler-profile-legacy.asmi"
            .include "loop-parser.asm"
KCCOMEND:
KCSINK:
LegacyEncoders .equ 1
            .include "loop-z80-sink.asm"
KCSNKEND:
KCCODEND:

KCIMM:
            .include "loop-keywords.asmi"
KCIMMEND:
KCEND:

            .org MMSOURCE
LoopProofSource:
            .db "sub main() fails",10
            .db "    var index as u8 = 0",10
            .db "    for index = 0 until 3",10
            .db "        writeOutputByte('A') else fail",10
            .db "    end",10
            .db "end",10
LoopProofSourceEnd:

ZeroLoopProofSource:
            .db "sub main() fails",10
            .db "    var index as u8 = 0",10
            .db "    for index = 0 until 0",10
            .db "        writeOutputByte('A') else fail",10
            .db "    end",10
            .db "end",10
ZeroLoopProofSourceEnd:

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

            LD   A,30
            LD   HL,LoopProofSource
            LD   DE,LoopProofSourceEnd
            CALL CPLPSL
            JP   C,ProofFailCompile
            CALL ZELOOP
            JP   C,ProofFailEncode
            LD   HL,(GNSZ)
            LD   DE,PGSZ
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailSize

            CALL RESET
            XOR  A
            LD   (SVFAIL),A
            CALL MMGEN
            LD   A,D
            CP   2
            JP   NZ,ProofFailFinalCounter
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,ProofFailRunSuccess
            LD   A,(VOUTLEN)
            CP   3
            JP   NZ,ProofFailOutputLength
            LD   HL,VOUTBAS
            LD   B,3
ProofCheckSuccessOutput:
            LD   A,(HL)
            CP   "A"
            JP   NZ,ProofFailOutputByte
            INC  HL
            DJNZ ProofCheckSuccessOutput

            CALL RESET
            LD   A,2
            LD   (SVFAIL),A
            CALL MMGEN
            LD   A,(RUNSTATE)
            CP   RTTRAP
            JP   NZ,ProofFailTrapState
            LD   A,(VOUTLEN)
            CP   1
            JP   NZ,ProofFailFailureOutput
            LD   A,(VOUTBAS)
            CP   "A"
            JP   NZ,ProofFailFailureOutput
            LD   A,(RTTRPNO)
            CP   6
            JP   NZ,ProofFailTrapNumber
            LD   HL,(RTTRPOFF)
            LD   DE,LPFAIL
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailTrapOffset
            LD   A,(RTTRPERR)
            CP   3
            JP   NZ,ProofFailTrapError

            LD   A,31
            LD   HL,ZeroLoopProofSource
            LD   DE,ZeroLoopProofSourceEnd
            CALL CPLPSL
            JP   C,ProofFailZeroCompile
            CALL ZELOOP
            JP   C,ProofFailZeroEncode
            CALL RESET
            XOR  A
            LD   (SVFAIL),A
            CALL MMGEN
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,ProofFailZeroRun
            LD   A,(VOUTLEN)
            OR   A
            JP   NZ,ProofFailZeroOutput

            ; Leave the normal direct program in generated output for inspection.
            LD   A,30
            LD   HL,LoopProofSource
            LD   DE,LoopProofSourceEnd
            CALL CPLPSL
            JP   C,ProofFailCompile
            CALL ZELOOP
            JP   C,ProofFailEncode

            LD   A,$A5
            LD   (FPSTATUS),A
            HALT

ProofFailCompile:       LD A,1
                        JR ProofFailed
ProofFailEncode:        LD A,2
                        JR ProofFailed
ProofFailSize:          LD A,3
                        JR ProofFailed
ProofFailRunSuccess:    LD A,4
                        JR ProofFailed
ProofFailOutputLength:  LD A,5
                        JR ProofFailed
ProofFailOutputByte:    LD A,6
                        JR ProofFailed
ProofFailFinalCounter:  LD A,7
                        JR ProofFailed
ProofFailTrapState:     LD A,8
                        JR ProofFailed
ProofFailFailureOutput: LD A,9
                        JR ProofFailed
ProofFailTrapNumber:    LD A,10
                        JR ProofFailed
ProofFailTrapOffset:    LD A,11
                        JR ProofFailed
ProofFailTrapError:     LD A,12
                        JR ProofFailed
ProofFailZeroCompile:   LD A,13
                        JR ProofFailed
ProofFailZeroEncode:    LD A,14
                        JR ProofFailed
ProofFailZeroRun:       LD A,15
                        JR ProofFailed
ProofFailZeroOutput:    LD A,16
ProofFailed:
            LD   (FPCASE),A
            LD   A,$E0
            LD   (FPSTATUS),A
            HALT

FPSTATUS:            .db 0
FPCASE:              .db 0
FPEND:

            .end
