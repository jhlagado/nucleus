NativeStreamingSource .equ 0
; Source proof for the u8-local and counted-loop compiler slice.

            .include "memory-map.asmi"
SegmentedOutput .equ 0
TargetStreamingOutput .equ 0
            .include "loop-compiler-state.asmi"

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
KCCODEND:

KCIMM:
            .include "loop-keywords.asmi"
KCIMMEND:
KCEND:

            .org MMSOURCE
AcceptedLoopSource:
            .db "sub main() fails",10
            .db "    var index as u8 = 0",10
            .db "    for index = 0 until 3",10
            .db "        writeOutputByte('A') else fail",10
            .db "    end",10
            .db "end",10
AcceptedLoopSourceEnd:

ZeroLoopSource:
            .db "sub main() fails",10
            .db "    var index as u8 = 0",10
            .db "    for index = 0 until 0",10
            .db "        writeOutputByte('A') else fail",10
            .db "    end",10
            .db "end",10
ZeroLoopSourceEnd:

CounterWriteSource:
            .db "sub main() fails",10
            .db "    var index as u8 = 0",10
            .db "    for index = 0 until 3",10
CounterWriteStart:
            .db "        index = 1",10
            .db "    end",10
            .db "end",10
CounterWriteSourceEnd:

MissingEndSource:
            .db "sub main() fails",10
            .db "    var index as u8 = 0",10
            .db "    for index = 0 until 3",10
            .db "        writeOutputByte('A') else fail",10
            .db "    end",10
MissingEndSourceEnd:

            .org MMPROOF
.routine out carry,zero clobbers sign,parity,halfCarry,A,BC,DE,HL,IX,IY
FPSTART:
            LD   SP,STACKTOP
            XOR  A
            LD   (FPCASE),A
            LD   (FPSTATUS),A

            LD   A,10
            LD   HL,AcceptedLoopSource
            LD   DE,AcceptedLoopSourceEnd
            CALL CPLPSL
            JP   C,ProofFailAccepted
            LD   HL,SMBUFBAS
            LD   DE,ExpectedLoopOperations
            LD   B,11
            CALL ProofCompareBytes
            JP   C,ProofFailOperations

            LD   A,11
            LD   HL,ZeroLoopSource
            LD   DE,ZeroLoopSourceEnd
            CALL CPLPSL
            JP   C,ProofFailZero
            LD   A,(SMBUFBAS+5)
            OR   A
            JP   NZ,ProofFailZeroBound

            LD   A,12
            LD   HL,CounterWriteSource
            LD   DE,CounterWriteSourceEnd
            CALL CPLPSL
            JP   NC,ProofFailCounterAccepted
            LD   A,(DGCODE)
            CP   DGACTCTR
            JP   NZ,ProofFailCounterCode
            LD   HL,(DGOFF)
            LD   DE,CounterWriteStart-CounterWriteSource+8
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailCounterOffset

            LD   A,13
            LD   HL,MissingEndSource
            LD   DE,MissingEndSourceEnd
            CALL CPLPSL
            JP   NC,ProofFailMissingAccepted
            LD   A,(DGCODE)
            CP   DXEND
            JP   NZ,ProofFailMissingCode
            LD   A,(DGPARTID)
            CP   13
            JP   NZ,ProofFailMissingPart
            LD   HL,(DGOFF)
            LD   DE,MissingEndSourceEnd-MissingEndSource
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailMissingPosition
            LD   HL,(DGLINE)
            LD   DE,6
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailMissingPosition
            LD   HL,(DGCOL)
            LD   DE,1
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailMissingPosition

            LD   A,$A5
            LD   (FPSTATUS),A
            HALT

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

ProofFailAccepted:       LD A,1
                         JR ProofFailed
ProofFailOperations:     LD A,2
                         JR ProofFailed
ProofFailZero:           LD A,3
                         JR ProofFailed
ProofFailZeroBound:      LD A,4
                         JR ProofFailed
ProofFailCounterAccepted: LD A,5
                         JR ProofFailed
ProofFailCounterCode:    LD A,6
                         JR ProofFailed
ProofFailCounterOffset:  LD A,7
                         JR ProofFailed
ProofFailMissingAccepted: LD A,8
                         JR ProofFailed
ProofFailMissingCode:    LD A,9
                         JR ProofFailed
ProofFailMissingPart:    LD A,10
                         JR ProofFailed
ProofFailMissingPosition: LD A,11
ProofFailed:
            LD   (FPCASE),A
            LD   A,$E0
            LD   (FPSTATUS),A
            HALT

ExpectedLoopOperations:
            .db 6,SMDECLU8,0,SMFORU8,0,3
            .db SMWROBYT,"A",SMPROP
            .db SMENDLP,SMRET
FPSTATUS:             .db 0
FPCASE:               .db 0
FPEND:

            .end
