NativeStreamingSource .equ 0
; Compile and execute one forward-declared recursive scalar value routine.

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
CallProofSource:
            .db "forward sub descend(value as u8) as u8",10
            .db 10
            .db "sub main() fails",10
            .db "    var result as u8 = "
CallProofInitialCall:
            .db "descend(3)",10
            .db "    "
CallProofOutputCall:
            .db "writeOutputByte(result) else fail",10
            .db "end",10
            .db 10
            .db "sub descend",10
            .db "    if value = 0",10
            .db "        return value",10
            .db "    end",10
            .db "    return "
CallProofRecursiveCall:
            .db "descend(value - 1)",10
            .db "end",10
CallProofSourceEnd:

BadCompletionSource:
            .db "forward sub descend(value as u8) as u8",10
            .db "sub main() fails",10
            .db "    var result as u8 = descend(3)",10
            .db "    writeOutputByte(result) else fail",10
            .db "end",10
            .db "sub "
BadCompletionName:
            .db "descent",10
            .db "    return descend(value - 1)",10
            .db "end",10
BadCompletionSourceEnd:

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
            LD   A,60
            LD   HL,CallProofSource
            LD   DE,CallProofSourceEnd
            CALL CPCLSL
            JP   C,ProofFailCompile
            LD   A,(SMBUFBAS)
            CP   9
            JP   NZ,ProofFailOperations
            CALL ZECALLPG
            JP   C,ProofFailEncode
            LD   HL,(GNSZ)
            LD   DE,CLPROGSZ
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailSize
            LD   HL,(SMRDCUR)
            LD   DE,SMBUFBAS+$10
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailTranscriptEnd

            CALL RESET
            CALL MMGEN
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,ProofFailSuccessState
            LD   A,(VOUTLEN)
            CP   1
            JP   NZ,ProofFailSuccessOutput
            LD   A,(VOUTBAS)
            OR   A
            JP   NZ,ProofFailSuccessByte
            LD   A,(RTDEPTH)
            OR   A
            JP   NZ,ProofFailSuccessActivation
            LD   A,(RTACTMEM+3)
            CP   1
            JP   NZ,ProofFailSuccessPeak

            CALL RESET
            LD   A,$A5
            LD   (RTACTMEM+3),A
            LD   A,3
            LD   (RTACTLIM),A
            CALL MMGEN
            LD   A,(RUNSTATE)
            CP   RTTRAP
            JP   NZ,ProofFailCapacityState
            LD   A,(RTTRPNO)
            CP   5
            JP   NZ,ProofFailCapacityTrap
            LD   A,(VOUTLEN)
            OR   A
            JP   NZ,ProofFailCapacityOutput
            LD   A,(RTDEPTH)
            OR   A
            JP   NZ,ProofFailCapacityActivation
            LD   HL,(RTTRPOFF)
            LD   DE,CLCAPOFF
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailCapacityOffset
            LD   A,(RTACTMEM+2)
            CP   2
            JP   NZ,ProofFailCapacityPeak
            LD   A,(RTACTMEM+3)
            CP   $A5
            JP   NZ,ProofFailCapacityAtomic

            CALL RESET
            LD   A,1
            LD   (SVFAIL),A
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
            LD   DE,CLFAIL
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailOutputOffset
            LD   A,(VOUTLEN)
            OR   A
            JP   NZ,ProofFailOutputBytes
            LD   A,(RTDEPTH)
            OR   A
            JP   NZ,ProofFailOutputActivation

            LD   A,61
            LD   HL,BadCompletionSource
            LD   DE,BadCompletionSourceEnd
            CALL CPCLSL
            JP   NC,ProofFailBadAccepted
            LD   A,(DGCODE)
            CP   DGFWDMIS
            JP   NZ,ProofFailBadCode
            LD   HL,(DGOFF)
            LD   DE,BadCompletionName-BadCompletionSource
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailBadPosition

            ; Leave the complete successful program available to host tests.
            LD   A,60
            LD   HL,CallProofSource
            LD   DE,CallProofSourceEnd
            CALL CPCLSL
            JP   C,ProofFailCompile
            CALL ZECALLPG
            JP   C,ProofFailEncode

            LD   A,$A5
            LD   (FPSTATUS),A
            HALT

ProofFailCompile:             LD A,1
                              JR ProofFailed
ProofFailOperations:          LD A,2
                              JR ProofFailed
ProofFailEncode:              LD A,3
                              JR ProofFailed
ProofFailSize:                LD A,15
                              JR ProofFailed
ProofFailSuccessState:        LD A,4
                              JR ProofFailed
ProofFailSuccessOutput:       LD A,5
                              JR ProofFailed
ProofFailSuccessByte:         LD A,6
                              JR ProofFailed
ProofFailSuccessActivation:   LD A,7
                              JR ProofFailed
ProofFailCapacityState:       LD A,8
                              JR ProofFailed
ProofFailCapacityTrap:        LD A,9
                              JR ProofFailed
ProofFailCapacityOutput:      LD A,10
                              JR ProofFailed
ProofFailCapacityActivation:  LD A,11
                              JR ProofFailed
ProofFailBadAccepted:         LD A,12
                              JR ProofFailed
ProofFailBadCode:             LD A,13
                              JR ProofFailed
ProofFailBadPosition:         LD A,14
                              JR ProofFailed
ProofFailTranscriptEnd:       LD A,16
                              JR ProofFailed
ProofFailSuccessPeak:         LD A,17
                              JR ProofFailed
ProofFailCapacityOffset:      LD A,18
                              JR ProofFailed
ProofFailCapacityPeak:        LD A,19
                              JR ProofFailed
ProofFailCapacityAtomic:      LD A,20
                              JR ProofFailed
ProofFailOutputState:         LD A,21
                              JR ProofFailed
ProofFailOutputTrap:          LD A,22
                              JR ProofFailed
ProofFailOutputError:         LD A,23
                              JR ProofFailed
ProofFailOutputOffset:        LD A,24
                              JR ProofFailed
ProofFailOutputBytes:         LD A,25
                              JR ProofFailed
ProofFailOutputActivation:   LD A,26
ProofFailed:
            LD   (FPCASE),A
            LD   A,$E0
            LD   (FPSTATUS),A
            HALT

FPSTATUS:            .db 0
FPCASE:              .db 0
FPEND:

            .end
