NativeStreamingSource .equ 0
; End-to-end proof of the streaming source adapter, tokenizer, predictive
; parser, semantic checks, positioned diagnostic, and operation sink.

            .include "memory-map.asmi"
            .include "compiler-state.asmi"

AggregateCallSlices .equ 0

            .org MMCORE
KCSTART:
            .include "source-adapter.asm"
            .include "tokenizer.asm"
            .include "semantic-sink.asm"
            .include "parser.asm"
KCCODEND:

KCIMM:
KeywordSub:
            .db  "sub"
KeywordFails:
            .db  "fails"
KeywordElse:
            .db  "else"
KeywordFail:
            .db  "fail"
KeywordEnd:
            .db  "end"
NAMEMAIN:
            .db  "main"
KWWRTOUT:
            .db  "writeOutputByte"
KCIMMEND:
KCEND:

            .org MMSOURCE
AcceptedSource:
            .db  "sub main() fails",10
            .db  "    writeOutputByte('A') else fail",10
            .db  "end",10
AcceptedSourceEnd:

MalformedSource:
            .db  "sub main() fails",10
            .db  "    writeOutputByte('A') else fail",10
MalformedSourceEnd:

            .org MMPROOF
.routine out carry,zero clobbers sign,parity,halfCarry,A,BC,DE,HL
FPSTART:
            LD   SP,STACKTOP
            XOR  A
            LD   (FPCASE),A
            LD   (FPSTATUS),A

            LD   A,7
            LD   HL,AcceptedSource
            LD   DE,AcceptedSourceEnd
            CALL CompileVerticalSlice
            JP   C,ProofFailAcceptedCompile
            LD   A,(DGCODE)
            OR   A
            JP   NZ,ProofFailAcceptedDiagnostic
            LD   HL,SMBUFBAS
            LD   DE,ExpectedOperations
            LD   B,6
            CALL ProofCompareBytes
            JP   C,ProofFailAcceptedOperations

            LD   A,9
            LD   HL,MalformedSource
            LD   DE,MalformedSourceEnd
            CALL CompileVerticalSlice
            JP   NC,ProofFailMalformedAccepted
            LD   A,(DGCODE)
            CP   DXEND
            JP   NZ,ProofFailMalformedCode
            LD   A,(DGPARTID)
            CP   9
            JP   NZ,ProofFailMalformedPart
            LD   HL,(DGOFF)
            LD   DE,MalformedSourceEnd-MalformedSource
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailMalformedOffset
            LD   HL,(DGLINE)
            LD   DE,3
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailMalformedLine
            LD   HL,(DGCOL)
            LD   DE,1
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailMalformedColumn
            LD   A,(SMBUFBAS)
            OR   A
            JP   NZ,ProofFailMalformedOutput

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

ProofFailAcceptedCompile:
            LD   A,1
            JR   ProofFailed
ProofFailAcceptedDiagnostic:
            LD   A,2
            JR   ProofFailed
ProofFailAcceptedOperations:
            LD   A,3
            JR   ProofFailed
ProofFailMalformedAccepted:
            LD   A,4
            JR   ProofFailed
ProofFailMalformedCode:
            LD   A,5
            JR   ProofFailed
ProofFailMalformedPart:
            LD   A,6
            JR   ProofFailed
ProofFailMalformedOffset:
            LD   A,7
            JR   ProofFailed
ProofFailMalformedLine:
            LD   A,8
            JR   ProofFailed
ProofFailMalformedColumn:
            LD   A,9
            JR   ProofFailed
ProofFailMalformedOutput:
            LD   A,10
ProofFailed:
            LD   (FPCASE),A
            LD   A,$E0
            LD   (FPSTATUS),A
            HALT

ExpectedOperations:
            .db  4,SMLDU8,"A",SMWROBYT
            .db  SMPROP,SMRET

FPSTATUS:
            .db  0
FPCASE:
            .db  0
FPEND:

            .end
