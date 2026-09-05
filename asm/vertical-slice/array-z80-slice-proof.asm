NativeStreamingSource .equ 0
; Compile and execute the initialized-array source as direct Z80 code.

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
LegacyEncoders .equ 1
            .include "loop-z80-sink.asm"
KCSNKEND:
KCCODEND:

KCIMM:
            .include "loop-keywords.asmi"
KCIMMEND:
KCEND:

            .org MMSOURCE
ArrayProofSource:
            .db "var bytes as u8[4] = [65, 66, 67, 68]",10
            .db 10
            .db "sub main() fails",10
            .db "    var index as u8 = readInputByte() else fail",10
            .db "    writeOutputByte(bytes[index]) else fail",10
            .db "end",10
ArrayProofSourceEnd:

BadArraySource:
            .db "var bytes as u8[4] = [65, 66 "
BadArrayValue:
            .db "67, 68]",10
            .db "sub main() fails",10
            .db "    var index as u8 = readInputByte() else fail",10
            .db "    writeOutputByte(bytes[index]) else fail",10
            .db "end",10
BadArraySourceEnd:

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
            LD   (VINFAIL),A
            LD   (SVFAIL),A

            LD   A,40
            LD   HL,ArrayProofSource
            LD   DE,ArrayProofSourceEnd
            CALL CPSL
            JP   C,ProofFailCompile
            LD   HL,SMBUFBAS
            LD   DE,ExpectedArrayOperations
            LD   B,14
            CALL ProofCompareBytes
            JP   C,ProofFailOperations
            CALL ZEARRAY
            JP   C,ProofFailEncode
            LD   HL,(GNSZ)
            LD   DE,ARYPGSZ
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailSize
            LD   HL,GNARREND-4
            LD   DE,ExpectedArrayBytes
            LD   B,4
            CALL ProofCompareBytes
            JP   C,ProofFailStaticData

            CALL ProofConfigureSuccessInput
            CALL MMGEN
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,ProofFailSuccessState
            LD   A,(VOUTLEN)
            CP   1
            JP   NZ,ProofFailSuccessOutput
            LD   A,(VOUTBAS)
            CP   "B"
            JP   NZ,ProofFailSuccessByte
            LD   A,(VINCUR)
            CP   1
            JP   NZ,ProofFailSuccessInput

            CALL ProofConfigureBoundsInput
            CALL MMGEN
            LD   A,(RUNSTATE)
            CP   RTTRAP
            JP   NZ,ProofFailBoundsState
            LD   A,(RTTRPNO)
            CP   1
            JP   NZ,ProofFailBoundsTrap
            LD   HL,(RTTRPOFF)
            LD   DE,ARYBOFF
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailBoundsOffset
            LD   A,(VOUTLEN)
            OR   A
            JP   NZ,ProofFailBoundsOutput
            LD   A,(VINCUR)
            CP   1
            JP   NZ,ProofFailBoundsInput

            CALL ProofConfigureNoInput
            CALL MMGEN
            LD   A,(RUNSTATE)
            CP   RTTRAP
            JP   NZ,ProofFailInputState
            LD   A,(RTTRPNO)
            CP   6
            JP   NZ,ProofFailInputTrap
            LD   A,(RTTRPERR)
            CP   1
            JP   NZ,ProofFailInputError
            LD   HL,(RTTRPOFF)
            LD   DE,ARYIFAIL
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailInputOffset
            LD   A,(VOUTLEN)
            OR   A
            JP   NZ,ProofFailInputOutput
            LD   A,(VINCUR)
            OR   A
            JP   NZ,ProofFailInputCursor

            CALL ProofConfigureOutputFailure
            CALL MMGEN
            LD   A,(RUNSTATE)
            CP   RTTRAP
            JP   NZ,ProofFailOutputState
            LD   A,(RTTRPNO)
            CP   6
            JP   NZ,ProofFailOutputTrap
            LD   A,(RTTRPERR)
            CP   3
            JP   NZ,ProofFailOutputError
            LD   HL,(RTTRPOFF)
            LD   DE,ARYOFAIL
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailOutputOffset
            LD   A,(VOUTLEN)
            OR   A
            JP   NZ,ProofFailOutputAtomic

            LD   A,41
            LD   HL,BadArraySource
            LD   DE,BadArraySourceEnd
            CALL CPSL
            JP   NC,ProofFailBadAccepted
            LD   A,(DGCODE)
            CP   DXCOMMA
            JP   NZ,ProofFailBadCode
            LD   HL,(DGOFF)
            LD   DE,BadArrayValue-BadArraySource
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailBadPosition
            LD   HL,(DGLINE)
            LD   DE,1
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailBadPosition
            LD   HL,(DGCOL)
            LD   DE,BadArrayValue-BadArraySource+1
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailBadPosition

            LD   A,$5A
            LD   (RUNSTATE),A
            LD   A,40
            LD   HL,ArrayProofSource
            LD   DE,ArrayProofSourceEnd
            CALL CPSL
            JP   C,ProofFailCompile
            LD   HL,MMGEN+10
            CALL ZEARRLIM
            JP   NC,ProofFailCapacityAccepted
            LD   A,(DGCODE)
            CP   DGSNKCAP
            JP   NZ,ProofFailCapacityCode
            LD   HL,(GNSZ)
            LD   DE,ARYPGSZ
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailCapacityPublished
            LD   HL,MMGEN
            LD   DE,MMBACK
            LD   B,ARYPGSZ
            CALL ProofCompareBytes
            JP   C,ProofFailCapacityPublished
            LD   A,(RUNSTATE)
            CP   $5A
            JP   NZ,ProofFailCapacityState

            ; Leave the complete Z80 program available for host inspection.
            LD   A,40
            LD   HL,ArrayProofSource
            LD   DE,ArrayProofSourceEnd
            CALL CPSL
            JP   C,ProofFailCompile
            CALL ZEARRAY
            JP   C,ProofFailEncode

            LD   A,$A5
            LD   (FPSTATUS),A
            HALT

.routine out carry,zero clobbers sign,parity,halfCarry,A,B,C,HL
ProofConfigureSuccessInput:
            CALL RESET
            XOR  A
            LD   (VINFAIL),A
            LD   (SVFAIL),A
            INC  A
            LD   (VINLEN),A
            LD   (VINBAS),A
            RET

.routine out carry,zero clobbers sign,parity,halfCarry,A,B,C,HL
ProofConfigureBoundsInput:
            CALL RESET
            XOR  A
            LD   (VINFAIL),A
            LD   (SVFAIL),A
            INC  A
            LD   (VINLEN),A
            LD   A,4
            LD   (VINBAS),A
            RET

.routine out carry,zero clobbers sign,parity,halfCarry,A,B,C,HL
ProofConfigureNoInput:
            CALL RESET
            XOR  A
            LD   (VINFAIL),A
            LD   (SVFAIL),A
            LD   (VINLEN),A
            RET

.routine out carry,zero clobbers sign,parity,halfCarry,A,B,C,HL
ProofConfigureOutputFailure:
            CALL RESET
            XOR  A
            LD   (VINFAIL),A
            INC  A
            LD   (SVFAIL),A
            LD   (VINLEN),A
            LD   A,2
            LD   (VINBAS),A
            RET

.routine in B,DE,HL out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
ProofCompareBytes:
            LD   A,(DE)
            CP   (HL)
            JR   NZ,ProofCompareBytesNo
            INC  DE
            INC  HL
            DJNZ ProofCompareBytes
            OR   A
            RET
ProofCompareBytesNo:
            SCF
            RET

ProofFailCompile:           LD A,1
                            JR ProofFailed
ProofFailOperations:        LD A,2
                            JR ProofFailed
ProofFailEncode:            LD A,3
                            JR ProofFailed
ProofFailSize:              LD A,4
                            JR ProofFailed
ProofFailStaticData:        LD A,5
                            JR ProofFailed
ProofFailSuccessState:      LD A,6
                            JR ProofFailed
ProofFailSuccessOutput:     LD A,7
                            JR ProofFailed
ProofFailSuccessInput:      LD A,8
                            JR ProofFailed
ProofFailBoundsState:       LD A,9
                            JR ProofFailed
ProofFailBoundsTrap:        LD A,10
                            JR ProofFailed
ProofFailBoundsOffset:      LD A,11
                            JR ProofFailed
ProofFailBoundsOutput:      LD A,12
                            JR ProofFailed
ProofFailBoundsInput:       LD A,13
                            JR ProofFailed
ProofFailInputState:        LD A,14
                            JR ProofFailed
ProofFailInputTrap:         LD A,15
                            JR ProofFailed
ProofFailInputError:        LD A,16
                            JR ProofFailed
ProofFailInputOffset:       LD A,17
                            JR ProofFailed
ProofFailInputOutput:       LD A,18
                            JR ProofFailed
ProofFailInputCursor:       LD A,19
                            JR ProofFailed
ProofFailOutputState:       LD A,20
                            JR ProofFailed
ProofFailOutputTrap:        LD A,21
                            JR ProofFailed
ProofFailOutputError:       LD A,22
                            JR ProofFailed
ProofFailOutputOffset:      LD A,23
                            JR ProofFailed
ProofFailOutputAtomic:      LD A,24
                            JR ProofFailed
ProofFailBadAccepted:       LD A,25
                            JR ProofFailed
ProofFailBadCode:           LD A,26
                            JR ProofFailed
ProofFailBadPosition:       LD A,27
                            JR ProofFailed
ProofFailCapacityAccepted:  LD A,28
                            JR ProofFailed
ProofFailCapacityCode:      LD A,29
                            JR ProofFailed
ProofFailCapacityPublished: LD A,30
                            JR ProofFailed
ProofFailCapacityState:     LD A,31
                            JR ProofFailed
ProofFailSuccessByte:       LD A,32
ProofFailed:
            LD   (FPCASE),A
            LD   A,$E0
            LD   (FPSTATUS),A
            HALT

ExpectedArrayOperations:
            .db 8,SMARRU8,4,65,66,67,68
            .db SMRDIBYT,SMPROP,SMSTRSU8
            .db SMLDAU8,SMWROU8
            .db SMPROP,SMRET
ExpectedArrayBytes:     .db 65,66,67,68
FPSTATUS:            .db 0
FPCASE:              .db 0
FPEND:

            .end
