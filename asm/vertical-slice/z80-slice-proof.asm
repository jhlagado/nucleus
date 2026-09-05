NativeStreamingSource .equ 0
; Compile and execute the first Nucleus source program as direct Z80 code.

            .include "memory-map.asmi"
            .include "compiler-state.asmi"

AggregateCallSlices .equ 0
            .include "z80-state.asmi"

            .org MMCORE
KCSTART:
            .include "source-adapter.asm"
            .include "tokenizer.asm"
            .include "semantic-sink.asm"
            .include "parser.asm"
KCCOMEND:
KCSINK:
            .include "z80-sink.asm"
KCSNKEND:
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
ProgramTemplate:
            .db  $3E,$00
            .db  $CD
            .dw  RTWRITE
            .db  $38,$06
            .db  $3E,RTSUCC,$32
            .dw  RUNSTATE
            .db  $C9
            .db  $32
            .dw  RTTRPERR
            .db  $AF,$32
            .dw  RTTRPRTN
            .db  $21
            .dw  FailureOffset
            .db  $22
            .dw  RTTRPOFF
            .db  $3E,$06,$32
            .dw  RTTRPNO
            .db  $3E,RTTRAP,$32
            .dw  RUNSTATE
            .db  $C9
KCIMMEND:
KCEND:

            .org MMSOURCE
ProofSource:
            .db  "sub main() fails",10
            .db  "    writeOutputByte('A') else fail",10
            .db  "end",10
ProofSourceEnd:

            .org MMRUN
RTSTART:
            .include "z80-runtime.asm"
RTEND:

            .org MMPROOF
.routine out carry,zero clobbers sign,parity,halfCarry,A,BC,DE,HL,IX,IY
FPSTART:
            LD   SP,STACKTOP
            XOR  A
            LD   (FPCASE),A
            LD   (FPSTATUS),A
            LD   (ServiceForceFailure),A

            LD   A,7
            LD   HL,ProofSource
            LD   DE,ProofSourceEnd
            CALL CompileVerticalSlice
            JP   C,ProofFailCompile
            CALL EncodeSemanticProgram
            JP   C,ProofFailEncode
            LD   HL,(GNSZ)
            LD   DE,PGSZ
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailSize

            CALL RESET
            XOR  A
            LD   (ServiceForceFailure),A
            CALL MMGEN
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,ProofFailRunSuccess
            LD   A,(VOUTLEN)
            CP   1
            JP   NZ,ProofFailOutputLength
            LD   A,(ServiceOutputByte)
            CP   "A"
            JP   NZ,ProofFailOutputByte
            LD   (ProofSuccessOutput),A

            CALL RESET
            LD   A,1
            LD   (ServiceForceFailure),A
            CALL MMGEN
            LD   A,(RUNSTATE)
            CP   RTTRAP
            JP   NZ,ProofFailTrapState
            LD   A,(VOUTLEN)
            OR   A
            JP   NZ,ProofFailAtomicOutput
            LD   A,(RTTRPNO)
            CP   6
            JP   NZ,ProofFailTrapNumber
            LD   A,(RTTRPRTN)
            OR   A
            JP   NZ,ProofFailTrapRoutine
            LD   HL,(RTTRPOFF)
            LD   DE,FailureOffset
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailTrapOffset
            LD   A,(RTTRPERR)
            CP   3
            JP   NZ,ProofFailTrapError

            LD   A,$A5
            LD   (FPSTATUS),A
            HALT

ProofFailCompile:
            LD   A,1
            JR   ProofFailed
ProofFailEncode:
            LD   A,2
            JR   ProofFailed
ProofFailSize:
            LD   A,3
            JR   ProofFailed
ProofFailRunSuccess:
            LD   A,4
            JR   ProofFailed
ProofFailOutputLength:
            LD   A,5
            JR   ProofFailed
ProofFailOutputByte:
            LD   A,6
            JR   ProofFailed
ProofFailTrapState:
            LD   A,7
            JR   ProofFailed
ProofFailAtomicOutput:
            LD   A,8
            JR   ProofFailed
ProofFailTrapNumber:
            LD   A,9
            JR   ProofFailed
ProofFailTrapRoutine:
            LD   A,10
            JR   ProofFailed
ProofFailTrapOffset:
            LD   A,11
            JR   ProofFailed
ProofFailTrapError:
            LD   A,12
ProofFailed:
            LD   (FPCASE),A
            LD   A,$E0
            LD   (FPSTATUS),A
            HALT

FPSTATUS:
            .db  0
FPCASE:
            .db  0
ProofSuccessOutput:
            .db  0
FPEND:

            .end
