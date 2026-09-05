NativeStreamingSource .equ 0
; Prove the correctness-first u8/u16/boolean expression increment end to end.

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
KCTYPED:
            .include "typed-expression-z80.asm"
KCTYPEND:
KCSNKEND:
KCCODEND:
KCIMM:
            .include "loop-keywords.asmi"
KCIMMEND:
KCEND:

            .org MMSOURCE
TypedAcceptedSource:
            .db "const folded = 65535 + 2",10
            .db "var out as u8 = 0",10
            .db "var word as u16 = 300",10
            .db "var flag as boolean = true",10
            .db "sub main() fails",10
            .db "    var a as u8 = 250",10
            .db "    var b as u16 = 20",10
            .db "    word = a + b * 3",10
            .db "    out = u8(word - 55)",10
            .db "    out = out + 2",10
            .db "    word = -word + 311",10
            .db "    word = not word and 65535",10
            .db "    word = word + folded",10
            .db "    word = word or 0",10
            .db "    word = word / 1",10
            .db "    flag = false and (u8(300) = 0)",10
            .db "    flag = true or (out / 0 = 0)",10
            .db "    flag = not (out > 1)",10
            .db "    flag = (out = 1) and (out <> 2) and (out <= 1) and (out >= 1) and not (out > 1)",10
            .db "    out = (not out) and 255",10
            .db "    out = -out + 255",10
            .db "    out = out * 3 / 3",10
            .db "    out = out - 0",10
            .db "    out = 'A' - 64",10
            .db "    word = u16(out) + word",10
            .db "    "
TypedAcceptedOutputCall:
            .db "writeOutputByte(out) else fail",10
            .db "end",10
TypedAcceptedSourceEnd:

TypedDefaultSource:
            .db "var out as u8 = 5",10
            .db "var word as u16",10
            .db "var flag as boolean",10
            .db "sub main() fails",10
            .db "    var localWord as u16",10
            .db "    out = u8(localWord)",10
            .db "    flag = not flag",10
            .db "    writeOutputByte(out) else fail",10
            .db "end",10
TypedDefaultSourceEnd:

TypedNarrowTrapSource:
            .db "var out as u8 = 7",10
            .db "var wide as u16 = 300",10
            .db "sub main() fails",10
            .db "    out = "
TypedNarrowTrapPoint:
            .db "u8(wide)",10
            .db "end",10
TypedNarrowTrapSourceEnd:

TypedDivideTrapSource:
            .db "var out as u8 = 9",10
            .db "var zero as u8 = 0",10
            .db "sub main() fails",10
            .db "    out = out "
TypedDivideTrapPoint:
            .db "/ zero",10
            .db "end",10
TypedDivideTrapSourceEnd:

TypedImplicitNarrowSource:
            .db "var out as u8 = 0",10
            .db "var wide as u16 = 1",10
            .db "sub main() fails",10
            .db "    out = wide",10
            .db "end",10
TypedImplicitNarrowSourceEnd:

TypedBooleanMixSource:
            .db "var flag as boolean = true",10
            .db "sub main() fails",10
            .db "    flag = 1",10
            .db "end",10
TypedBooleanMixSourceEnd:

TypedChainSource:
            .db "var flag as boolean = true",10
            .db "sub main() fails",10
            .db "    flag = 1 < 2 < 3",10
            .db "end",10
TypedChainSourceEnd:

TypedConstantDivideSource:
            .db "const bad = 1 / 0",10
TypedConstantDivideSourceEnd:

TypedConstantNarrowSource:
            .db "const bad = u8(300)",10
TypedConstantNarrowSourceEnd:

TypedLiteralOverflowSource:
            .db "var bad as u16 = 65536",10
TypedLiteralOverflowSourceEnd:

; The u16 definition and main marker consume five bytes. The repeated
; named-constant expression/store pairs cross the 511-byte transcript payload
; without approaching the independent 255-operation limit.
TypedTranscriptCapacitySource:
            .db "const k = 1",10
            .db "var out as u16 = 0",10
            .db "sub main() fails",10
            .db "out=k",10,"out=k",10,"out=k",10,"out=k",10
            .db "out=k",10,"out=k",10,"out=k",10,"out=k",10
            .db "out=k",10,"out=k",10,"out=k",10,"out=k",10
            .db "out=k",10,"out=k",10,"out=k",10,"out=k",10
            .db "out=k",10,"out=k",10,"out=k",10,"out=k",10
            .db "out=k",10,"out=k",10,"out=k",10,"out=k",10
            .db "out=k",10,"out=k",10,"out=k",10,"out=k",10
            .db "out=k",10,"out=k",10,"out=k",10,"out=k",10
            .db "out=k",10,"out=k",10,"out=k",10,"out=k",10
            .db "out=k",10,"out=k",10,"out=k",10,"out=k",10
            .db "out=k",10,"out=k",10,"out=k",10,"out=k",10
            .db "out=k",10,"out=k",10,"out=k",10,"out=k",10
            .db "out=k",10,"out=k",10,"out=k",10,"out=k",10
            .db "out=k",10,"out=k",10,"out=k",10,"out=k",10
            .db "out=k",10,"out=k",10,"out=k",10,"out=k",10
            .db "out=k",10,"out=k",10,"out=k",10,"out=k",10
            .db "out=k",10,"out=k",10,"out=k",10,"out=k",10
            .db "out=k",10,"out=k",10,"out=k",10,"out=k",10
            .db "out=k",10,"out=k",10,"out=k",10,"out=k",10
            .db "out=k",10,"out=k",10,"out=k",10,"out=k",10
            .db "out=k",10,"out=k",10,"out=k",10,"out=k",10
            .db "out=k",10,"out=k",10,"out=k",10,"out=k",10
            .db "out=k",10,"out=k",10,"out=k",10,"out=k",10
            .db "out=k",10,"out=k",10,"out=k",10,"out=k",10
            .db "out=k",10,"out=k",10,"out=k",10,"out=k",10
            .db "out=k",10,"out=k",10
            .db "end",10
TypedTranscriptCapacitySourceEnd:

; Seventeen pending additions exceed the sixteen-entry expression stack.
TypedExpressionCapacitySource:
            .db "var out as u8 = 0",10
            .db "sub main() fails",10
            .db "out=1+(1+(1+(1+(1+(1+(1+(1+(1+(1+(1+(1+(1+(1+(1+(1+(1+1))))))))))))))))",10
            .db "end",10
TypedExpressionCapacitySourceEnd:

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

            ; TokenEof shares zero with the empty lookahead marker. Repeated
            ; peeks therefore re-run the tokenizer, but must reproduce the
            ; same token, payload, flags, source cursor, and token position.
            LD   A,79
            LD   HL,TypedExpressionCapacitySourceEnd
            LD   DE,TypedExpressionCapacitySourceEnd
            CALL SAINIT
            XOR  A
            LD   (PSLOOK),A
            LD   BC,$FFFF
            CALL PSPEEK
            JP   C,ProofFailEofLookahead
            JP   NZ,ProofFailEofLookahead
            LD   A,B
            OR   C
            JP   NZ,ProofFailEofLookahead
            LD   BC,$FFFF
            CALL PSPEEK
            JP   C,ProofFailEofLookahead
            JP   NZ,ProofFailEofLookahead
            LD   A,B
            OR   C
            JP   NZ,ProofFailEofLookahead
            CALL PSTK
            JP   C,ProofFailEofLookahead
            JP   NZ,ProofFailEofLookahead
            LD   A,(PSLOOK)
            OR   A
            JP   NZ,ProofFailEofLookahead
            LD   HL,(SSCUR)
            LD   DE,TypedExpressionCapacitySourceEnd
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailEofLookahead
            LD   HL,(SSOFF)
            LD   A,H
            OR   L
            JP   NZ,ProofFailEofLookahead
            LD   HL,(SSLINE)
            DEC  HL
            LD   A,H
            OR   L
            JP   NZ,ProofFailEofLookahead
            LD   HL,(SSCOL)
            DEC  HL
            LD   A,H
            OR   L
            JP   NZ,ProofFailEofLookahead
            LD   HL,(TNSTOFF)
            LD   A,H
            OR   L
            JP   NZ,ProofFailEofLookahead
            LD   HL,(TNSTLINE)
            DEC  HL
            LD   A,H
            OR   L
            JP   NZ,ProofFailEofLookahead
            LD   HL,(TNSTCOL)
            DEC  HL
            LD   A,H
            OR   L
            JP   NZ,ProofFailEofLookahead
            LD   A,TNPLUS
            CALL TYTKOP
            JP   C,ProofFailEofLookahead
            JP   Z,ProofFailEofLookahead
            CP   $FF
            JP   NZ,ProofFailEofLookahead
            LD   A,(PSLOOK)
            OR   A
            JP   NZ,ProofFailEofLookahead
            LD   A,(EXOP)
            CP   TNPLUS
            JP   NZ,ProofFailEofLookahead

            LD   A,80
            LD   HL,TypedAcceptedSource
            LD   DE,TypedAcceptedSourceEnd
            CALL CPSL
            JP   C,ProofFailAcceptedCompile
            CALL ZXPROG
            JP   C,ProofFailAcceptedEncode
            CALL RESET
            CALL ProofCallGenerated
            JP   C,ProofFailFrame
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,ProofFailAcceptedState
            LD   A,(VOUTLEN)
            CP   1
            JP   NZ,ProofFailAcceptedLength
            LD   A,(VOUTBAS)
            CP   1
            JP   NZ,ProofFailAcceptedValue
            LD   A,(MMGEN+3)       ; out
            CP   1
            JP   NZ,ProofFailAcceptedStore
            LD   A,(MMGEN+6)       ; final comparison conjunction
            CP   1
            JP   NZ,ProofFailAcceptedBoolean
            LD   HL,(MMGEN+4)      ; widened add wraps 65535 + 1
            LD   A,H
            OR   L
            JP   NZ,ProofFailAcceptedWord
            LD   HL,(GNSZ)
            LD   (TypedGeneratedSize),HL

            LD   A,90
            LD   HL,TypedDefaultSource
            LD   DE,TypedDefaultSourceEnd
            CALL CPSL
            JP   C,ProofFailDefaultCompile
            CALL ZXPROG
            JP   C,ProofFailDefaultEncode
            CALL RESET
            CALL ProofCallGenerated
            JP   C,ProofFailFrame
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,ProofFailDefaultState
            LD   A,(VOUTLEN)
            CP   1
            JP   NZ,ProofFailDefaultOutput
            LD   A,(VOUTBAS)
            OR   A
            JP   NZ,ProofFailDefaultOutput
            LD   HL,(MMGEN+4)      ; word defaults to zero
            LD   A,H
            OR   L
            JP   NZ,ProofFailDefaultProgram
            LD   A,(MMGEN+6)       ; false, then not, becomes true
            CP   1
            JP   NZ,ProofFailDefaultBoolean

            LD   A,81
            LD   HL,TypedNarrowTrapSource
            LD   DE,TypedNarrowTrapSourceEnd
            CALL CPSL
            JP   C,ProofFailNarrowCompile
            CALL ZXPROG
            JP   C,ProofFailNarrowEncode
            CALL RESET
            CALL ProofCallGenerated
            JP   C,ProofFailFrame
            LD   A,(RUNSTATE)
            CP   RTTRAP
            JP   NZ,ProofFailNarrowState
            LD   A,(RTTRPNO)
            CP   2
            JP   NZ,ProofFailNarrowNumber
            LD   HL,(RTTRPOFF)
            LD   DE,TypedNarrowTrapPoint-TypedNarrowTrapSource
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailNarrowOffset
            LD   A,(MMGEN+3)
            CP   7
            JP   NZ,ProofFailNarrowAtomic

            LD   A,82
            LD   HL,TypedDivideTrapSource
            LD   DE,TypedDivideTrapSourceEnd
            CALL CPSL
            JP   C,ProofFailDivideCompile
            CALL ZXPROG
            JP   C,ProofFailDivideEncode
            CALL RESET
            CALL ProofCallGenerated
            JP   C,ProofFailFrame
            LD   A,(RUNSTATE)
            CP   RTTRAP
            JP   NZ,ProofFailDivideState
            LD   A,(RTTRPNO)
            CP   3
            JP   NZ,ProofFailDivideNumber
            LD   HL,(RTTRPOFF)
            LD   DE,TypedDivideTrapPoint-TypedDivideTrapSource
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailDivideOffset
            LD   A,(MMGEN+3)
            CP   9
            JP   NZ,ProofFailDivideAtomic

            LD   A,83
            LD   HL,TypedImplicitNarrowSource
            LD   DE,TypedImplicitNarrowSourceEnd
            LD   C,DGTYPMIS
            CALL ProofExpectDiagnostic
            JP   C,ProofFailImplicitNarrow
            LD   A,84
            LD   HL,TypedBooleanMixSource
            LD   DE,TypedBooleanMixSourceEnd
            LD   C,DGTYPMIS
            CALL ProofExpectDiagnostic
            JP   C,ProofFailBooleanMix
            LD   A,85
            LD   HL,TypedChainSource
            LD   DE,TypedChainSourceEnd
            LD   C,DGCMPCHN
            CALL ProofExpectDiagnostic
            JP   C,ProofFailChain
            LD   A,86
            LD   HL,TypedConstantDivideSource
            LD   DE,TypedConstantDivideSourceEnd
            LD   C,DGDIVZER
            CALL ProofExpectDiagnostic
            JP   C,ProofFailConstantDivide
            LD   A,87
            LD   HL,TypedConstantNarrowSource
            LD   DE,TypedConstantNarrowSourceEnd
            LD   C,DGNAR
            CALL ProofExpectDiagnostic
            JP   C,ProofFailConstantNarrow
            LD   A,88
            LD   HL,TypedLiteralOverflowSource
            LD   DE,TypedLiteralOverflowSourceEnd
            LD   C,DGLEX
            CALL ProofExpectDiagnostic
            JP   C,ProofFailLiteralOverflow
            LD   A,89
            LD   HL,TypedTranscriptCapacitySource
            LD   DE,TypedTranscriptCapacitySourceEnd
            LD   C,DGSNKCAP
            CALL ProofExpectDiagnostic
            JP   C,ProofFailTranscriptCapacity

            ; The byte stream still has room after 255 one-byte operations,
            ; but the independently published operation count does not. Lock
            ; the exact count and cursor before the 256th operation; its
            ; terminal diagnostic intentionally overlays that dead sink state.
            CALL TMRESET
            LD   C,255
ProofFillOperationCount:
            LD   A,SMLIT16
            CALL TMOPER
            JP   C,ProofFailOperationCapacityFill
            DEC  C
            JR   NZ,ProofFillOperationCount
            LD   A,(SKOPCNT)
            CP   255
            JP   NZ,ProofFailOperationCapacityBoundary
            LD   HL,(SKCUR)
            LD   DE,SMBUFBAS+256
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailOperationCapacityBoundary
            LD   A,SMLIT16
            CALL TMOPER
            JP   NC,ProofFailOperationCapacityAccept
            LD   A,(DGCODE)
            CP   DGSNKCAP
            JP   NZ,ProofFailOperationCapacityDiagnostic

            LD   A,91
            LD   HL,TypedExpressionCapacitySource
            LD   DE,TypedExpressionCapacitySourceEnd
            LD   C,DGEXPCAP
            CALL ProofExpectDiagnostic
            JP   C,ProofFailExpressionCapacity

            LD   A,92
            LD   HL,TypedDynamicZeroSource
            LD   DE,TypedDynamicZeroSourceEnd
            LD   C,DGDIVZER
            CALL ProofExpectDiagnostic
            JP   C,ProofFailDynamicZero
            LD   A,93
            LD   HL,TypedUnaryMinusOverflowSource
            LD   DE,TypedUnaryMinusOverflowSourceEnd
            LD   C,DGINTRNG
            CALL ProofExpectDiagnostic
            JP   C,ProofFailUnaryMinusRange
            LD   A,94
            LD   HL,TypedNotOverflowSource
            LD   DE,TypedNotOverflowSourceEnd
            LD   C,DGINTRNG
            CALL ProofExpectDiagnostic
            JP   C,ProofFailNotRange
            LD   A,95
            LD   HL,TypedMalformedHexSource
            LD   DE,TypedMalformedHexSourceEnd
            LD   C,DGLEX
            CALL ProofExpectDiagnostic
            JP   C,ProofFailMalformedHex
            LD   A,96
            LD   HL,TypedMalformedSuffixSource
            LD   DE,TypedMalformedSuffixSourceEnd
            LD   C,DGLEX
            CALL ProofExpectDiagnostic
            JP   C,ProofFailMalformedSuffix

            ; Fault suppression removes the fault, not the operation's static
            ; type. Both skipped u8 operations must still make 300 invalid as
            ; the exact peer of a u8 comparison.
            LD   A,100
            LD   HL,TypedSuppressedDivideTypeSource
            LD   DE,TypedSuppressedDivideTypeSourceEnd
            LD   C,DGINTRNG
            CALL ProofExpectDiagnostic
            JP   C,ProofFailSuppressedDivideType
            LD   A,101
            LD   HL,TypedSuppressedNarrowTypeSource
            LD   DE,TypedSuppressedNarrowTypeSourceEnd
            LD   C,DGINTRNG
            CALL ProofExpectDiagnostic
            JP   C,ProofFailSuppressedNarrowType
            LD   A,102
            LD   HL,TypedMissingConversionRightSource
            LD   DE,TypedMissingConversionRightSourceEnd
            LD   C,DXRPAR
            CALL ProofExpectDiagnostic
            JP   C,ProofFailMissingConversionRight
            LD   A,103
            LD   HL,TypedMissingParenRightSource
            LD   DE,TypedMissingParenRightSourceEnd
            LD   C,DXRPAR
            CALL ProofExpectDiagnostic
            JP   C,ProofFailMissingParenRight
            LD   A,104
            LD   HL,TypedMalformedAfterLeftSource
            LD   DE,TypedMalformedAfterLeftSourceEnd
            LD   C,DGLEX
            CALL ProofExpectDiagnostic
            JP   C,ProofFailMalformedAfterLeft

            ; Put the cursor three bytes below the transcript limit. The local
            ; declaration consumes two bytes and its literal operation consumes
            ; the third; the first literal operand must report capacity.
            LD   A,105
            LD   HL,TypedDefaultLocalCapacitySource
            LD   DE,TypedDefaultLocalCapacitySourceEnd
            CALL SAINIT
            CALL TMRESET
            XOR  A
            LD   (PSLOOK),A
            CALL SBRESET
            LD   HL,SMBUFLIM-3
            LD   (SKCUR),HL
            CALL TYPLOCDC
            JP   NC,ProofFailDefaultLocalCapacity
            LD   A,(DGCODE)
            CP   DGSNKCAP
            JP   NZ,ProofFailDefaultLocalCapacity

            ; Exercise paths absent from the primary program: named u8 and
            ; Boolean constants, unary plus, u8 or, integer less-than, Boolean
            ; equality/inequality, constant division, and boundary narrowing.
            LD   A,97
            LD   HL,TypedCoverageSource
            LD   DE,TypedCoverageSourceEnd
            CALL CPSL
            JP   C,ProofFailCoverageCompile
            CALL ZXPROG
            JP   C,ProofFailCoverageEncode
            CALL RESET
            CALL ProofCallGenerated
            JP   C,ProofFailFrame
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,ProofFailCoverageState
            LD   A,(VOUTBAS)
            CP   255
            JP   NZ,ProofFailCoverageOutput
            LD   A,(MMGEN+4)       ; dynamic Boolean conjunction
            CP   1
            JP   NZ,ProofFailCoverageBoolean

            ; The inner u8 conversion controls its arithmetic width even though
            ; the enclosing destination is u16: 200+100 wraps to 44, then widens.
            LD   A,98
            LD   HL,TypedConversionContextSource
            LD   DE,TypedConversionContextSourceEnd
            CALL CPSL
            JP   C,ProofFailConversionCompile
            CALL ZXPROG
            JP   C,ProofFailConversionEncode
            CALL RESET
            CALL ProofCallGenerated
            JP   C,ProofFailFrame
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,ProofFailConversionState
            LD   HL,(MMGEN+4)
            LD   A,H
            OR   A
            JP   NZ,ProofFailConversionValue
            LD   A,L
            CP   44
            JP   NZ,ProofFailConversionValue

            ; A nested successful divide must not replace the outer divide's
            ; source offset when the outer operation traps.
            LD   A,99
            LD   HL,TypedNestedDivideTrapSource
            LD   DE,TypedNestedDivideTrapSourceEnd
            CALL CPSL
            JP   C,ProofFailNestedDivideCompile
            CALL ZXPROG
            JP   C,ProofFailNestedDivideEncode
            CALL RESET
            CALL ProofCallGenerated
            JP   C,ProofFailFrame
            LD   A,(RUNSTATE)
            CP   RTTRAP
            JP   NZ,ProofFailNestedDivideState
            LD   HL,(RTTRPOFF)
            LD   DE,TypedNestedDivideOuter-TypedNestedDivideTrapSource
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailNestedDivideOffset
            LD   HL,(MMGEN+3)
            LD   DE,10
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailNestedDivideAtomic

            ; A nested successful narrowing likewise must not replace the
            ; outer checked conversion's trap position.
            LD   A,100
            LD   HL,TypedNestedNarrowTrapSource
            LD   DE,TypedNestedNarrowTrapSourceEnd
            CALL CPSL
            JP   C,ProofFailNestedNarrowCompile
            CALL ZXPROG
            JP   C,ProofFailNestedNarrowEncode
            CALL RESET
            CALL ProofCallGenerated
            JP   C,ProofFailFrame
            LD   A,(RUNSTATE)
            CP   RTTRAP
            JP   NZ,ProofFailNestedNarrowState
            LD   HL,(RTTRPOFF)
            LD   DE,TypedNestedNarrowOuter-TypedNestedNarrowTrapSource
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailNestedNarrowOffset
            LD   A,(MMGEN+3)
            CP   7
            JP   NZ,ProofFailNestedNarrowAtomic

            ; Defensive invariant failures use their own diagnostics rather
            ; than masquerading as semantic-transcript exhaustion.
            XOR  A
            LD   (EXSTKDEP),A
            LD   HL,1
            LD   A,MTCONST+TYU8
            CALL TYRSTOPS
            JP   NC,ProofFailExpressionUnderflow
            LD   A,(DGCODE)
            CP   DGINTOP
            JP   NZ,ProofFailExpressionUnderflow

            LD   A,EBFCAP
            LD   (EBFDEP),A
            LD   DE,0
            CALL ZXBLPUSH
            JP   NC,ProofFailBooleanCapacity
            LD   A,(DGCODE)
            CP   DGBFXCAP
            JP   NZ,ProofFailBooleanCapacity

            XOR  A
            LD   (EBFDEP),A
            LD   B,A
            CALL ZXBLPOP
            JP   NC,ProofFailBooleanUnderflow
            LD   A,(DGCODE)
            CP   DGINTOP
            JP   NZ,ProofFailBooleanUnderflow

            LD   A,1
            LD   (SMBUFBAS),A
            LD   A,SMLITU8
            LD   (SMPAYBAS),A
            CALL ZXDISP
            JP   NC,ProofFailRetiredOperation
            LD   A,(DGCODE)
            CP   DGINTOP
            JP   NZ,ProofFailRetiredOperation

            ; A unary template that exhausts the output after three bytes
            ; must return through both inline continuations with SP restored.
            ; The emitted prefix and untouched fourth byte lock the precise
            ; failure point of the returning-diagnostic historical layout.
            LD   HL,0
            ADD  HL,SP
            LD   (ProofExpectedSP),HL
            XOR  A
            LD   (DGCODE),A
            LD   HL,MMGEN
            LD   (EMCUR),HL
            LD   HL,MMGEN+3
            LD   (EMLIM),HL
            LD   A,$CC
            LD   (MMGEN+3),A
            CALL ZXNEG16
            JP   NC,ProofFailUnaryEmitReturn
            LD   HL,0
            ADD  HL,SP
            LD   DE,(ProofExpectedSP)
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailUnaryEmitStack
            LD   A,(DGCODE)
            CP   DGSNKCAP
            JP   NZ,ProofFailUnaryEmitDiagnostic
            LD   HL,(EMCUR)
            LD   DE,MMGEN+3
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailUnaryEmitCursor
            LD   HL,(MMGEN)
            LD   DE,$AFE1
            OR   A
            SBC  HL,DE
            JP   NZ,ProofFailUnaryEmitPrefixWord
            LD   A,(MMGEN+2)
            CP   $95
            JP   NZ,ProofFailUnaryEmitPrefixByte
            LD   A,(MMGEN+3)
            CP   $CC
            JP   NZ,ProofFailUnaryEmitCanary

            LD   A,1
            LD   (EBFDEP),A
            CALL ZXENDM
            JP   NC,ProofFailUnbalancedBoolean
            LD   A,(DGCODE)
            CP   DGINTOP
            JP   NZ,ProofFailUnbalancedBoolean

            CALL ProofCheckArithmeticFastPaths
            JP   C,ProofFailArithmeticRuntime

            ; Restore the accepted compiler result for host-side inspection.
            LD   A,80
            LD   HL,TypedAcceptedSource
            LD   DE,TypedAcceptedSourceEnd
            CALL CPSL
            JP   C,ProofFailAcceptedCompile
            CALL ZXPROG
            JP   C,ProofFailAcceptedEncode
            LD   A,$A5
            LD   (FPSTATUS),A
            HALT

; A=part, HL..DE source, C=expected diagnostic. Carry means mismatch.
.routine in A,C,DE,HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ProofExpectDiagnostic:
            PUSH BC
            CALL CPSL
            POP  BC
            JR   NC,ProofExpectedDiagnosticNo
            LD   A,(DGCODE)
            CP   C
            JR   NZ,ProofExpectedDiagnosticNo
            OR   A
            RET
ProofExpectedDiagnosticNo:
            SCF
            RET

; Execute a generated routine with a visible frame sentinel. Returning through
; local storage or a saved IX value cannot satisfy both observations.
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

; The runtime fast paths must preserve the full multiply/divide/modulo result
; matrix at their gating boundaries. Rows are dividend, divisor, quotient,
; remainder, and wrapped product.
.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX
ProofCheckArithmeticFastPaths:
            LD   IX,ProofArithmeticCases
ProofCheckArithmeticRow:
            LD   L,(IX+0)
            LD   H,(IX+1)
            LD   E,(IX+2)
            LD   D,(IX+3)
            CALL RTDIV16
            JR   C,ProofCheckArithmeticNo
            LD   E,(IX+4)
            LD   D,(IX+5)
            OR   A
            SBC  HL,DE
            JR   NZ,ProofCheckArithmeticNo
            LD   L,(IX+0)
            LD   H,(IX+1)
            LD   E,(IX+2)
            LD   D,(IX+3)
            CALL RTMOD16
            JR   C,ProofCheckArithmeticNo
            LD   E,(IX+6)
            LD   D,(IX+7)
            OR   A
            SBC  HL,DE
            JR   NZ,ProofCheckArithmeticNo
            LD   L,(IX+0)
            LD   H,(IX+1)
            LD   E,(IX+2)
            LD   D,(IX+3)
            CALL RTMUL16
            JR   C,ProofCheckArithmeticNo
            LD   E,(IX+8)
            LD   D,(IX+9)
            OR   A
            SBC  HL,DE
            JR   NZ,ProofCheckArithmeticNo
            LD   DE,10
            ADD  IX,DE
            PUSH IX
            POP  HL
            LD   DE,ProofArithmeticCasesEnd
            OR   A
            SBC  HL,DE
            JR   NZ,ProofCheckArithmeticRow

            LD   HL,1000
            LD   DE,0
            CALL RTDIV16
            JR   NC,ProofCheckArithmeticNo
            LD   HL,1000
            LD   DE,0
            CALL RTMOD16
            JR   NC,ProofCheckArithmeticNo
            LD   HL,37
            LD   DE,0
            CALL RTMUL16
            JR   C,ProofCheckArithmeticNo
            LD   A,H
            OR   L
            RET  Z
ProofCheckArithmeticNo:
            SCF
            RET

ProofFailedNear:              JP ProofFailed
ProofFailAcceptedCompile:     LD A,1
                              JR ProofFailedNear
ProofFailAcceptedEncode:      LD A,2
                              JR ProofFailedNear
ProofFailAcceptedState:       LD A,3
                              JR ProofFailedNear
ProofFailAcceptedLength:      LD A,4
                              JR ProofFailedNear
ProofFailAcceptedValue:       LD A,5
                              JR ProofFailedNear
ProofFailAcceptedStore:       LD A,6
                              JR ProofFailedNear
ProofFailAcceptedBoolean:     LD A,26
                              JR ProofFailedNear
ProofFailAcceptedWord:        LD A,27
                              JR ProofFailedNear
ProofFailDefaultCompile:      LD A,28
                              JR ProofFailedNear
ProofFailDefaultEncode:       LD A,29
                              JR ProofFailedNear
ProofFailDefaultState:        LD A,30
                              JR ProofFailedNear
ProofFailDefaultOutput:       LD A,31
                              JR ProofFailedNear
ProofFailDefaultProgram:      LD A,32
                              JR ProofFailedNear
ProofFailDefaultBoolean:      LD A,33
                              JR ProofFailedNear
ProofFailNarrowCompile:       LD A,7
                              JR ProofFailedNear
ProofFailNarrowEncode:        LD A,8
                              JR ProofFailedNear
ProofFailNarrowState:         LD A,9
                              JR ProofFailedNear
ProofFailNarrowNumber:        LD A,10
                              JR ProofFailedNear
ProofFailNarrowOffset:        LD A,11
                              JR ProofFailedNear
ProofFailNarrowAtomic:        LD A,12
                              JR ProofFailedNear
ProofFailDivideCompile:       LD A,13
                              JR ProofFailedNear
ProofFailDivideEncode:        LD A,14
                              JR ProofFailedNear
ProofFailDivideState:         LD A,15
                              JR ProofFailedNear
ProofFailDivideNumber:        LD A,16
                              JR ProofFailedNear
ProofFailDivideOffset:        LD A,17
                              JR ProofFailedNear
ProofFailDivideAtomic:        LD A,18
                              JR ProofFailedNear
ProofFailImplicitNarrow:      LD A,19
                              JR ProofFailedNear
ProofFailBooleanMix:          LD A,20
                              JR ProofFailedNear
ProofFailChain:               LD A,21
                              JR ProofFailedNear
ProofFailConstantDivide:      LD A,22
                              JR ProofFailedNear
ProofFailConstantNarrow:      LD A,23
                              JR ProofFailedNear
ProofFailLiteralOverflow:     LD A,24
                              JP ProofFailed
ProofFailTranscriptCapacity:  LD A,25
                              JP ProofFailed
ProofFailExpressionCapacity:  LD A,34
                              JP ProofFailed
ProofFailExpressionUnderflow: LD A,35
                              JP ProofFailed
ProofFailBooleanCapacity:     LD A,36
                              JP ProofFailed
ProofFailBooleanUnderflow:    LD A,37
                              JP ProofFailed
ProofFailRetiredOperation:    LD A,38
                              JP ProofFailed
ProofFailUnbalancedBoolean:   LD A,39
                              JP ProofFailed
ProofFailFrame:               LD A,40
                              JP ProofFailed
ProofFailDynamicZero:         LD A,41
                              JP ProofFailed
ProofFailUnaryMinusRange:     LD A,42
                              JP ProofFailed
ProofFailNotRange:            LD A,43
                              JP ProofFailed
ProofFailMalformedHex:        LD A,44
                              JP ProofFailed
ProofFailMalformedSuffix:     LD A,45
                              JP ProofFailed
ProofFailSuppressedDivideType: LD A,65
                              JP ProofFailed
ProofFailSuppressedNarrowType: LD A,66
                              JP ProofFailed
ProofFailMissingConversionRight: LD A,67
                              JP ProofFailed
ProofFailMissingParenRight:   LD A,68
                              JP ProofFailed
ProofFailMalformedAfterLeft:  LD A,69
                              JP ProofFailed
ProofFailDefaultLocalCapacity: LD A,70
                              JP ProofFailed
ProofFailOperationCapacityFill: LD A,71
                              JP ProofFailed
ProofFailOperationCapacityBoundary: LD A,72
                              JP ProofFailed
ProofFailOperationCapacityAccept: LD A,73
                              JP ProofFailed
ProofFailOperationCapacityDiagnostic: LD A,74
                              JP ProofFailed
ProofFailEofLookahead:       LD A,75
                              JP ProofFailed
ProofFailUnaryEmitReturn:    LD A,76
                              JP ProofFailed
ProofFailUnaryEmitStack:     LD A,77
                              JP ProofFailed
ProofFailUnaryEmitDiagnostic: LD A,78
                              JP ProofFailed
ProofFailUnaryEmitCursor:    LD A,79
                              JP ProofFailed
ProofFailUnaryEmitPrefixWord: LD A,80
                              JP ProofFailed
ProofFailUnaryEmitPrefixByte: LD A,81
                              JP ProofFailed
ProofFailUnaryEmitCanary:    LD A,82
                              JP ProofFailed
ProofFailCoverageCompile:     LD A,46
                              JR ProofFailed
ProofFailCoverageEncode:      LD A,47
                              JR ProofFailed
ProofFailCoverageState:       LD A,48
                              JR ProofFailed
ProofFailCoverageOutput:      LD A,49
                              JR ProofFailed
ProofFailCoverageBoolean:     LD A,50
                              JR ProofFailed
ProofFailConversionCompile:   LD A,51
                              JR ProofFailed
ProofFailConversionEncode:    LD A,52
                              JR ProofFailed
ProofFailConversionState:     LD A,53
                              JR ProofFailed
ProofFailConversionValue:     LD A,54
                              JR ProofFailed
ProofFailNestedDivideCompile: LD A,55
                              JR ProofFailed
ProofFailNestedDivideEncode:  LD A,56
                              JR ProofFailed
ProofFailNestedDivideState:   LD A,57
                              JR ProofFailed
ProofFailNestedDivideOffset:  LD A,58
                              JR ProofFailed
ProofFailNestedDivideAtomic:  LD A,59
                              JR ProofFailed
ProofFailNestedNarrowCompile: LD A,60
                              JR ProofFailed
ProofFailNestedNarrowEncode:  LD A,61
                              JR ProofFailed
ProofFailNestedNarrowState:   LD A,62
                              JR ProofFailed
ProofFailNestedNarrowOffset:  LD A,63
                              JR ProofFailed
ProofFailNestedNarrowAtomic:  LD A,64
                              JR ProofFailed
ProofFailArithmeticRuntime:   LD A,71
ProofFailed:
            LD   (FPCASE),A
            LD   A,$E0
            LD   (FPSTATUS),A
            HALT

TypedGeneratedSize:           .dw 0
ProofExpectedSP:              .dw 0
FPSTATUS:                  .db 0
FPCASE:                    .db 0
ProofArithmeticCases:
            .dw 1000,1,1000,0,1000
            .dw 1000,2,500,0,2000
            .dw 1000,255,3,235,58392
            .dw 1000,256,3,232,59392
            .dw 1000,257,3,229,60392
            .dw 65535,65535,1,0,1
ProofArithmeticCasesEnd:
FPEND:

GeneratedTypedEnd             .equ MMGEN+857

            .org MMSPARE
TypedDynamicZeroSource:
            .db "var out as u8 = 1",10
            .db "sub main() fails",10
            .db "    out = out / 0",10
            .db "end",10
TypedDynamicZeroSourceEnd:

TypedUnaryMinusOverflowSource:
            .db "var bad as u8 = -256",10
TypedUnaryMinusOverflowSourceEnd:
TypedNotOverflowSource:
            .db "var bad as u8 = not 256",10
TypedNotOverflowSourceEnd:
TypedMalformedHexSource:
            .db "var bad as u16 = 0x2a",10
TypedMalformedHexSourceEnd:
TypedMalformedSuffixSource:
            .db "var bad as u16 = 12u8",10
TypedMalformedSuffixSourceEnd:

TypedSuppressedDivideTypeSource:
            .db "var byte as u8 = 1",10
            .db "var flag as boolean = false",10
            .db "sub main() fails",10
            .db "    flag = false and (byte / 0 = 300)",10
            .db "end",10
TypedSuppressedDivideTypeSourceEnd:

TypedSuppressedNarrowTypeSource:
            .db "var flag as boolean = false",10
            .db "sub main() fails",10
            .db "    flag = false and (u8(300) = 300)",10
            .db "end",10
TypedSuppressedNarrowTypeSourceEnd:

TypedMissingConversionRightSource:
            .db "var out as u8 = 0",10
            .db "sub main() fails",10
            .db "    out = u8(1",10
            .db "end",10
TypedMissingConversionRightSourceEnd:

TypedMissingParenRightSource:
            .db "var out as u8 = 0",10
            .db "sub main() fails",10
            .db "    out = (1",10
            .db "end",10
TypedMissingParenRightSourceEnd:

TypedMalformedAfterLeftSource:
            .db "var out as u8 = 0",10
            .db "sub main() fails",10
            .db "    out = 1 0x2a",10
            .db "end",10
TypedMalformedAfterLeftSourceEnd:

TypedDefaultLocalCapacitySource:
            .db "local as u16",10
TypedDefaultLocalCapacitySourceEnd:

TypedCoverageSource:
            .db "const byteMask = u8(255)",10
            .db "const truth = true",10
            .db "const quotient = 8 / 2",10
            .db "var out as u8 = 0",10
            .db "var flag as boolean = false",10
            .db "sub main() fails",10
            .db "    var value as u8 = +1",10
            .db "    out = not 255",10
            .db "    out = -u8(255)",10
            .db "    out = value or byteMask",10
            .db "    flag = truth",10
            .db "    flag = (value < quotient) and (flag = truth) and (flag <> false)",10
            .db "    writeOutputByte(out) else fail",10
            .db "end",10
TypedCoverageSourceEnd:

TypedConversionContextSource:
            .db "var out as u8 = 0",10
            .db "var word as u16 = 0",10
            .db "sub main() fails",10
            .db "    word = u8(200 + 100)",10
            .db "    out = u8(word)",10
            .db "    writeOutputByte(out) else fail",10
            .db "end",10
TypedConversionContextSourceEnd:

TypedNestedDivideTrapSource:
            .db "var result as u16 = 10",10
            .db "var left as u16 = 1",10
            .db "var right as u16 = 2",10
            .db "sub main() fails",10
            .db "    result = result "
TypedNestedDivideOuter:
            .db "/ (left / right)",10
            .db "end",10
TypedNestedDivideTrapSourceEnd:

TypedNestedNarrowTrapSource:
            .db "var out as u8 = 7",10
            .db "var wide as u16 = 300",10
            .db "var small as u16 = 1",10
            .db "sub main() fails",10
            .db "    out = "
TypedNestedNarrowOuter:
            .db "u8(wide + u8(small))",10
            .db "end",10
TypedNestedNarrowTrapSourceEnd:
            .end
