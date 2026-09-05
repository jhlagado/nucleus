NativeStreamingSource .equ 0
; Compile general scalar symbols and a precedence expression to direct Z80.

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
            .include "typed-expression-z80.asm"
KCSNKEND:
KCCODEND:

KCIMM:
            .include "loop-keywords.asmi"
KCIMMEND:
KCEND:

            .org MMSOURCE
ExpressionProofSource:
            .db "var bytes as u8 = 0",10
            .db "sub main() fails",10
            .db "    var left as u8 = 2",10
            .db "    var right as u8 = 3",10
            .db "    //xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",10
            .db "    bytes = left + right * 4",10
            .db "    "
ExpressionOutputCall:
            .db "writeOutputByte(bytes) else fail",10
            .db "end",10
ExpressionProofSourceEnd:

DuplicateScalarSource:
            .db "var total as u8 = 0",10
            .db "var "
DuplicateScalarName:
            .db "total as u8 = 1",10
            .db "sub main() fails",10
            .db "end",10
DuplicateScalarSourceEnd:

UnknownScalarSource:
            .db "var total as u8 = 0",10
            .db "sub main() fails",10
            .db "    "
UnknownScalarName:
            .db "missing = total",10
            .db "end",10
UnknownScalarSourceEnd:

MalformedExpressionSource:
            .db "var total as u8 = 0",10
            .db "sub main() fails",10
            .db "    total = 1 +"
MalformedExpressionPoint:
            .db 10
            .db "end",10
MalformedExpressionSourceEnd:

FullScalarSource:
            .db "var a as u8 = 0",10
            .db "var b as u8 = 0",10
            .db "var c as u8 = 0",10
            .db "var d as u8 = 0",10
            .db "var e as u8 = 0",10
            .db "var f as u8 = 0",10
            .db "var g as u8 = 0",10
            .db "var h as u8 = 0",10
            .db "var i as u8 = 0",10
            .db "var j as u8 = 0",10
            .db "var k as u8 = 0",10
            .db "var l as u8 = 0",10
            .db "var m as u8 = 0",10
            .db "var n as u8 = 0",10
            .db "var o as u8 = 0",10
            .db "var p as u8 = 0",10
            .db "var "
FullScalarName:
            .db "q as u8 = 0",10
FullScalarSourceEnd:

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

            LD   A,70
            LD   HL,ExpressionProofSource
            LD   DE,ExpressionProofSourceEnd
            CALL CPSL
            JP   C,ProofFailCompile
            CALL ZXPROG
            JP   C,ProofFailEncode

            CALL RESET
            XOR  A
            LD   (SVFAIL),A
            CALL ProofCallGenerated
            JP   C,ProofFailFrame
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,ProofFailSuccessState
            LD   A,(VOUTLEN)
            CP   1
            JP   NZ,ProofFailSuccessOutput
            LD   A,(VOUTBAS)
            CP   14
            JP   NZ,ProofFailSuccessByte
            LD   A,(MMGEN+3)
            CP   14
            JP   NZ,ProofFailAssignment

            CALL RESET
            LD   A,1
            LD   (SVFAIL),A
            CALL ProofCallGenerated
            JP   C,ProofFailFrame
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
            LD   DE,ExpressionOutputCall-ExpressionProofSource
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailOutputOffset
            LD   A,(VOUTLEN)
            OR   A
            JP   NZ,ProofFailOutputAtomic

            LD   A,71
            LD   HL,DuplicateScalarSource
            LD   DE,DuplicateScalarSourceEnd
            CALL CPSL
            JP   NC,ProofFailDuplicateAccepted
            LD   A,(DGCODE)
            CP   DGDUPNAM
            JP   NZ,ProofFailDuplicateCode
            LD   HL,(DGOFF)
            LD   DE,DuplicateScalarName-DuplicateScalarSource
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailDuplicatePosition

            LD   A,72
            LD   HL,UnknownScalarSource
            LD   DE,UnknownScalarSourceEnd
            CALL CPSL
            JP   NC,ProofFailUnknownAccepted
            LD   A,(DGCODE)
            CP   DGUNKNAM
            JP   NZ,ProofFailUnknownCode
            LD   HL,(DGOFF)
            LD   DE,UnknownScalarName-UnknownScalarSource
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailUnknownPosition

            LD   A,73
            LD   HL,MalformedExpressionSource
            LD   DE,MalformedExpressionSourceEnd
            CALL CPSL
            JP   NC,ProofFailMalformedAccepted
            LD   A,(DGCODE)
            CP   DXSCA
            JP   NZ,ProofFailMalformedCode
            LD   HL,(DGOFF)
            LD   DE,MalformedExpressionPoint-MalformedExpressionSource
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailMalformedPosition

            LD   A,74
            LD   HL,FullScalarSource
            LD   DE,FullScalarSourceEnd
            CALL CPSL
            JP   NC,ProofFailFullAccepted
            LD   A,(DGCODE)
            CP   DGSYMCAP
            JP   NZ,ProofFailFullCode
            LD   HL,(DGOFF)
            LD   DE,FullScalarName-FullScalarSource
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailFullPosition

            ; Leave the successful program and transcript for host inspection.
            LD   A,70
            LD   HL,ExpressionProofSource
            LD   DE,ExpressionProofSourceEnd
            CALL CPSL
            JP   C,ProofFailCompile
            CALL ZXPROG
            JP   C,ProofFailEncode

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

ProofFailCompile:             LD A,1
                              JR ProofFailed
ProofFailOperations:          LD A,2
                              JR ProofFailed
ProofFailEncode:              LD A,3
                              JR ProofFailed
ProofFailSuccessState:        LD A,4
                              JR ProofFailed
ProofFailSuccessOutput:       LD A,5
                              JR ProofFailed
ProofFailSuccessByte:         LD A,6
                              JR ProofFailed
ProofFailAssignment:          LD A,7
                              JR ProofFailed
ProofFailOutputState:         LD A,8
                              JR ProofFailed
ProofFailOutputTrap:          LD A,9
                              JR ProofFailed
ProofFailOutputError:         LD A,10
                              JR ProofFailed
ProofFailOutputOffset:        LD A,11
                              JR ProofFailed
ProofFailOutputAtomic:        LD A,12
                              JR ProofFailed
ProofFailDuplicateAccepted:   LD A,13
                              JR ProofFailed
ProofFailDuplicateCode:       LD A,14
                              JR ProofFailed
ProofFailDuplicatePosition:   LD A,15
                              JR ProofFailed
ProofFailUnknownAccepted:     LD A,16
                              JR ProofFailed
ProofFailUnknownCode:         LD A,17
                              JR ProofFailed
ProofFailUnknownPosition:     LD A,18
                              JR ProofFailed
ProofFailGeneratedSize:       LD A,19
                              JR ProofFailed
ProofFailFullAccepted:        LD A,20
                              JR ProofFailed
ProofFailFullCode:            LD A,21
                              JR ProofFailed
ProofFailFullPosition:        LD A,22
                              JR ProofFailed
ProofFailMalformedAccepted:   LD A,23
                              JR ProofFailed
ProofFailMalformedCode:       LD A,24
                              JR ProofFailed
ProofFailMalformedPosition:   LD A,25
                              JR ProofFailed
ProofFailFrame:               LD A,26
ProofFailed:
            LD   (FPCASE),A
            LD   A,$E0
            LD   (FPSTATUS),A
            HALT

ExpectedExpressionOperations:
            .db 17
            .db SMDEFPU8,0,0
            .db SMBGMAIN
            .db SMDLCLU8,0,SMLITU8,2
            .db SMSTLU8,0
            .db SMDLCLU8,1,SMLITU8,3
            .db SMSTLU8,1
            .db SMLDLU8,0,SMLDLU8,1
            .db SMLITU8,4,SMMULU8,SMADDU8
            .db SMSTPU8,0
            .db SMLDPU8,0
            .db SMWRVU8
            .dw ExpressionOutputCall-ExpressionProofSource
            .db SMENMAIN
FPSTATUS:                 .db 0
FPCASE:                   .db 0
ProofExpectedSP:             .dw 0
FPEND:

ExpressionProgramSize .equ 116
GeneratedExpressionEnd      .equ MMGEN+ExpressionProgramSize

            .end
