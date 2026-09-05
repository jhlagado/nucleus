; Prove the compact descriptor and flat append-only compiler sink end to end.

            .include "target-memory-map.asmi"
            .org MMCORE
            .include "flat-target-compiler-image.asmi"

            .org MMSOURCE
FlatTargetSource:
            .db "var value as u16 = 3",10
            .db "var cleared as u8",10
            .db "sub main()",10
            .db "value = value * 2",10
            .db "end",10
FlatTargetSourceEnd:

FlatTargetParts:
            .db 1
            .dw FlatTargetSource,FlatTargetSourceEnd
FlatTargetPartBanks: .db 0

FlatTargetTrapSource:
            .db "var divisor as u8",10
            .db "sub main()",10
            .db "var value as u8 = 1 / divisor",10
            .db "end",10
FlatTargetTrapSourceEnd:
FlatTargetTrapParts:
            .db 1
            .dw FlatTargetTrapSource,FlatTargetTrapSourceEnd

FlatTargetUnhandledSource:
            .db "sub failer() fails",10
            .db "fail 7",10
            .db "end",10
            .db "sub main() fails",10
            .db "failer() else fail",10
            .db "end",10
FlatTargetUnhandledSourceEnd:
FlatTargetUnhandledParts:
            .db 1
            .dw FlatTargetUnhandledSource,FlatTargetUnhandledSourceEnd

BankedTargetLibrarySource:
            .db "record Box",10
            .db "value as u8",10
            .db "end",10
            .db "var shared as Box = (4)",10
            .db "var countdown as u8 = 1",10
            .db "var result as u8",10
            ; The first constant byte is a proof-only far-jump destination.
            .db "const Lookup as u8[2] = [$76, 5]",10
            .db "sub recursive()",10
            .db "if countdown = 0",10
            .db "return",10
            .db "end",10
            .db "countdown = countdown - 1",10
            .db "recursive()",10
            .db "end",10
            .db "sub readBox(box as Box, add as u8) as u8",10
            .db "return box.value + add",10
            .db "end",10
            .db "sub failRemote() fails",10
            .db "fail 7",10
            .db "end",10
BankedTargetLibrarySourceEnd:
BankedTargetMainSource:
            .db "sub main() fails",10
            .db "var code as u8",10
            .db "recursive()",10
            .db "result = readBox(shared, 1)",10
            .db "failRemote() handle code",10
            .db "result = result + code",10
            .db "end",10
            .db "end",10
BankedTargetMainSourceEnd:
BankedTargetParts:
            .db 1
            .dw BankedTargetLibrarySource,BankedTargetLibrarySourceEnd
            .db 2
            .dw BankedTargetMainSource,BankedTargetMainSourceEnd
BankedTargetPartBanks: .db 1,0
BankedTargetEntry1Source:
            .db "var result as u8",10
            .db "sub main()",10
            .db "result = 12",10
            .db "end",10
BankedTargetEntry1SourceEnd:
BankedTargetEntry1Parts:
            .db 1
            .dw BankedTargetEntry1Source,BankedTargetEntry1SourceEnd
BankedTargetEntry1PartBanks: .db 1

BankedConstantFailurePart1:
            .db "const Bytes as u8[2] = [1, 2]",10
            .db "sub take(value as u8[2])",10
            .db "end",10
BankedConstantFailurePart1End:
BankedConstantFailurePart2:
            .db "sub main()",10
            .db "take(Bytes)",10
            .db "end",10
BankedConstantFailurePart2End:
BankedConstantFailureParts:
            .db 1
            .dw BankedConstantFailurePart1,BankedConstantFailurePart1End
            .db 2
            .dw BankedConstantFailurePart2,BankedConstantFailurePart2End

BankedParameterFailurePart1:
            .db "record Box",10,"value as u8",10,"end",10
            .db "sub take(first as Box, second as Box)",10,"end",10
BankedParameterFailurePart1End:
BankedParameterFailurePart2:
            .db "var shared as Box = (1)",10
            .db "sub give() as Box",10,"return shared",10,"end",10
            .db "sub main()",10,"take(shared, give())",10,"end",10
BankedParameterFailurePart2End:
BankedParameterFailureParts:
            .db 1
            .dw BankedParameterFailurePart1,BankedParameterFailurePart1End
            .db 2
            .dw BankedParameterFailurePart2,BankedParameterFailurePart2End

BankedResultFailurePart1:
            .db "record Box",10,"value as u8",10,"end",10
            .db "var shared as Box = (1)",10
            .db "sub give() as Box",10,"return shared",10,"end",10
BankedResultFailurePart1End:
BankedResultFailurePart2:
            .db "var output as Box",10
            .db "sub main()",10
            .db "output = give()",10
            .db "end",10
BankedResultFailurePart2End:
BankedResultFailureParts:
            .db 1
            .dw BankedResultFailurePart1,BankedResultFailurePart1End
            .db 2
            .dw BankedResultFailurePart2,BankedResultFailurePart2End

BankedForwardFailurePart1:
            .db "forward sub later()",10
BankedForwardFailurePart1End:
BankedForwardFailurePart2:
            .db "sub later",10,"return",10,"end",10
            .db "sub main()",10,"later()",10,"end",10
BankedForwardFailurePart2End:
BankedForwardFailureParts:
            .db 1
            .dw BankedForwardFailurePart1,BankedForwardFailurePart1End
            .db 2
            .dw BankedForwardFailurePart2,BankedForwardFailurePart2End
BankedTrapPart1:
            .db "var result as u8",10
            .db "sub trapRemote(divisor as u8)",10
            .db "result = 1 / divisor",10
            .db "end",10
BankedTrapPart1End:
BankedTrapPart2:
            .db "sub main()",10
            .db "trapRemote(0)",10
            .db "end",10
BankedTrapPart2End:
BankedTrapParts:
            .db 1
            .dw BankedTrapPart1,BankedTrapPart1End
            .db 2
            .dw BankedTrapPart2,BankedTrapPart2End
BankedLargePart1:
            .db "const First as string[253] = ",34,34,10
            .db "const Second as string[253] = ",34,34,10
BankedLargePart1End:
BankedLargePart2:
            .db "sub main()",10,"end",10
BankedLargePart2End:
BankedLargeParts:
            .db 1
            .dw BankedLargePart1,BankedLargePart1End
            .db 2
            .dw BankedLargePart2,BankedLargePart2End
BankedFailurePartBanks: .db 1,0
BankedInvalidPartBanks: .db 2,0

FlatTargetDescriptor:
            .dw RIABI
            .dw $8000,$1000
            .dw $4000,$1000
            .db 1
            .db 1,0
            .dw FlatTargetPartBanks
FlatTargetLoadedDescriptor:
            .dw RIABI
            .dw $8000,$2000
            .dw $9000,$1000
            .db 0
            .db 1,0
            .dw FlatTargetPartBanks
FlatTargetEarlyWritableDescriptor:
            .dw RIABI
            .dw $8000,$2000
            .dw $8100,$1000
            .db 0
            .db 1,0
            .dw FlatTargetPartBanks
FlatTargetBadFlagsDescriptor:
            .dw RIABI
            .dw $8000,$1000
            .dw $4000,$1000
            .db 2
            .db 1,0
            .dw FlatTargetPartBanks
FlatTargetStackExactDescriptor:
            .dw RIABI
            .dw $8000,$1000
            .dw $4000,$0F4B+(RIVECBYT-33)+(RISTBYT-37)
            .db 1
            .db 1,0
            .dw FlatTargetPartBanks
FlatTargetStackOverflowDescriptor:
            .dw RIABI
            .dw $8000,$1000
            .dw $4000,$0F4A+(RIVECBYT-33)+(RISTBYT-37)
            .db 1
            .db 1,0
            .dw FlatTargetPartBanks
BankedTargetDescriptor:
            .dw RIABI
            .dw $8000,$1000
            .dw $4000,$1000
            .db 1
            .db 2,0
            .dw BankedTargetPartBanks
BankedTargetEntry1Descriptor:
            .dw RIABI
            .dw $8000,$1000
            .dw $4000,$1000
            .db 1
            .db 2,1
            .dw BankedTargetEntry1PartBanks
BankedFailureDescriptor:
            .dw RIABI
            .dw $8000,$1000
            .dw $4000,$1000
            .db 1
            .db 2,0
            .dw BankedFailurePartBanks
BankedWrongEntryDescriptor:
            .dw RIABI
            .dw $8000,$1000
            .dw $4000,$1000
            .db 1
            .db 2,1
            .dw BankedTargetPartBanks
BankedInvalidPartDescriptor:
            .dw RIABI
            .dw $8000,$1000
            .dw $4000,$1000
            .db 1
            .db 2,0
            .dw BankedInvalidPartBanks
BankedEntryOverflowDescriptor:
            .dw RIABI
            .dw $8000,$02BC
            .dw $4000,$1000
            .db 1
            .db 2,0
            .dw BankedTargetPartBanks
BankedOtherOverflowDescriptor:
            .dw RIABI
            .dw $8000,$0352
            .dw $4000,$1000
            .db 1
            .db 2,0
            .dw BankedFailurePartBanks

; The accepted multipart program from Chapter 18.1 is compiled through the
; production target entry and executed only from its committed NOBJ image.
; This proof-only corpus is deliberately separate from the deployment source
; window: the individual compile still observes the published source-window
; capacity, while the complete proof may retain many mutually exclusive input
; fixtures without overlapping the selected runtime.
            .org MMCORP
Chapter21TargetPart1:
            .db "record Cell",10
            .db "    value as u8",10
            .db "end",10
            .db 10
            .db "var template as Cell = (1)",10
            .db "var cells as Cell[4] = [(0), (0), (0), (0)]",10
            .db 10
Chapter21TargetPart1End:
Chapter21TargetPart2:
            .db "sub cellAt(index as u8) as Cell",10
            .db "    return cells[index]",10
            .db "end",10
            .db 10
            .db "sub setCell(cell as Cell, value as u8)",10
            .db "    cell.value = value",10
            .db "end",10
            .db 10
            .db "sub main()",10
            .db "    var index as u8",10
            .db "    var code as u8",10
            .db 10
            .db "    for index = 0 until 4",10
            .db "        cells[index] = template",10
            .db "        setCell(template, index + 1)",10
            .db "    end",10
            .db 10
            .db "    cells[0].value = cellAt(0).value",10
            .db "    if cells[0].value = 1",10
            .db "        writeOutputByte('Y') handle code",10
            .db "            return",10
            .db "        end",10
            .db "    elseif cells[0].value = 0",10
            .db "        writeOutputByte('N') handle code",10
            .db "            return",10
            .db "        end",10
            .db "    end",10
            .db "end",10
Chapter21TargetPart2End:
Chapter21TargetParts:
            .db 1
            .dw Chapter21TargetPart1,Chapter21TargetPart1End
            .db 2
            .dw Chapter21TargetPart2,Chapter21TargetPart2End
Chapter21TargetPartBanks: .db 0,0
Chapter21TargetDescriptor:
            .dw RIABI
            .dw $8000,$1000
            .dw $4000,$1000
            .db 1
            .db 1,0
            .dw Chapter21TargetPartBanks
Chapter21ProofCorpusEnd:

            .org MMRUN
RTSTART:
            .include "proof-z80-runtime.asm"
RTEND:

            ; The driver follows the selected runtime and must finish before
            ; ExecutionBase. Keeping the two adjacent prevents the proof from
            ; overlapping the adapter's saved high-memory logs.
.routine out carry,zero clobbers sign,parity,halfCarry,A,BC,DE,HL,IX,IY
ProofStart:
            LD   SP,STACKTOP
            XOR  A
            LD   (ProofStatus),A
            LD   (ProofCase),A
            LD   (AdapterCommitted),A
            LD   (AdapterAborted),A
            LD   (AdapterMapFailure),A
            LD   (AdapterCommitFailure),A
            LD   HL,AdapterLogBase
            LD   (AdapterCursor),HL
            LD   A,73
            LD   (ProofCase),A
            CALL ProofCheckProductionCapacityBoundaries
            JP   C,ProofRegionFailure
            LD   HL,$F000
            LD   DE,$1000
            LD   A,10
            LD   (ProofCase),A
            CALL ProofCallTargetValidateRegion
            JP   C,ProofRegionFailure
            LD   HL,$FFFF
            LD   (EMCUR),HL
            LD   HL,1
            LD   (EMLIM),HL
            LD   DE,1
            LD   A,46
            LD   (ProofCase),A
            CALL TargetConsumeExtent
            JP   C,ProofRegionFailure
            LD   HL,(EMCUR)
            LD   A,H
            OR   L
            JP   NZ,ProofRegionFailure
            LD   HL,(EMLIM)
            LD   A,H
            OR   L
            JP   NZ,ProofRegionFailure
            LD   HL,$F001
            LD   DE,$1000
            LD   A,11
            LD   (ProofCase),A
            CALL ProofCallTargetValidateRegion
            JP   NC,ProofRegionFailure
            LD   A,(DGCODE)
            CP   DGTGTCAP
            JP   NZ,ProofRegionFailure
            LD   HL,$8000
            LD   A,12
            LD   (ProofCase),A
            LD   (TGIMGBAS),HL
            LD   HL,$1000
            LD   (TGIMGCAP),HL
            LD   HL,$8F00
            LD   (TGWRBAS),HL
            LD   HL,$0200
            LD   (TGWRCAP),HL
            CALL ProofCallTargetClassifyFlatLayout
            JP   NC,ProofRegionFailure
            LD   A,(DGCODE)
            CP   DGTGTCFG
            JP   NZ,ProofRegionFailure
            LD   HL,$2000
            LD   A,13
            LD   (ProofCase),A
            LD   (TGIMGCAP),HL
            LD   HL,$9000
            LD   (TGWRBAS),HL
            LD   HL,$0100
            LD   (TGWRCAP),HL
            CALL ProofCallTargetClassifyFlatLayout
            JP   C,ProofRegionFailure
            LD   A,(TGLAYMOD)
            OR   A
            JP   NZ,ProofRegionFailure
            LD   A,14
            LD   (ProofCase),A
            LD   A,1
            LD   HL,FlatTargetParts
            LD   IX,FlatTargetEarlyWritableDescriptor
            CALL CTACPART
            JP   NC,ProofLoadedFailure
            CALL ProofCompilerStackExact
            JP   NZ,ProofLoadedFailure
            LD   A,(DGCODE)
            CP   DGTGTCAP
            JP   NZ,ProofLoadedFailure
            LD   A,15
            LD   (ProofCase),A
            XOR  A
            LD   (AdapterCommitted),A
            LD   (AdapterAborted),A
            LD   A,61
            LD   (AdapterFailureCountdown),A
            LD   HL,AdapterLogBase
            LD   (AdapterCursor),HL
            LD   A,1
            LD   HL,FlatTargetParts
            LD   IX,FlatTargetLoadedDescriptor
            CALL CTACPART
            JP   NC,ProofLoadedFailure
            LD   A,(DGCODE)
            CP   DGTGTOUT
            JP   NZ,ProofLoadedFailure
            LD   A,(AdapterCommitted)
            OR   A
            JP   NZ,ProofLoadedFailure
            LD   A,(AdapterAborted)
            CP   1
            JP   NZ,ProofLoadedFailure
            LD   A,16
            LD   (ProofCase),A
            XOR  A
            LD   (AdapterCommitted),A
            LD   (AdapterAborted),A
            LD   (AdapterFailureCountdown),A
            LD   HL,AdapterLogBase
            LD   (AdapterCursor),HL
            LD   A,1
            LD   HL,FlatTargetParts
            LD   IX,FlatTargetLoadedDescriptor
            CALL CTACPART
            JP   C,ProofLoadedFailure
            CALL ProofCompilerStackExact
            JP   NZ,ProofLoadedFailure
            LD   A,(TGLAYMOD)
            OR   A
            JP   NZ,ProofLoadedFailure
            LD   HL,(TCROBAS)
            LD   DE,$82D4+(RIVECBYT-33)+(RIBYTES-689)
            OR   A
            SBC  HL,DE
            JP   NZ,ProofLoadedFailure
            LD   HL,(EMCUR)
            LD   DE,(TGIMGBAS)
            OR   A
            SBC  HL,DE
            LD   DE,$1048+(RIVECBYT-33)+(RISTBYT-37)
            OR   A
            SBC  HL,DE
            JP   NZ,ProofLoadedFailure
            LD   HL,(TGROLEN)
            LD   A,H
            OR   L
            JP   NZ,ProofLoadedFailure
            LD   HL,(TGCODBAS)
            LD   DE,$82D4+(RIVECBYT-33)+(RIBYTES-689)
            OR   A
            SBC  HL,DE
            JP   NZ,ProofLoadedFailure
            LD   HL,(TGWRBAS)
            LD   DE,$9000
            OR   A
            SBC  HL,DE
            JP   NZ,ProofLoadedFailure
            CALL TargetInitializedLength
            LD   DE,RIVECBYT+RISTBYT+2
            OR   A
            SBC  HL,DE
            JP   NZ,ProofLoadedFailure
            LD   HL,(TGWRBAS)
            LD   DE,$9000
            OR   A
            SBC  HL,DE
            JP   NZ,ProofLoadedFailure
            LD   HL,(TCROCAP)
            LD   A,H
            OR   L
            JP   NZ,ProofLoadedFailure
            LD   HL,(AdapterCursor)
            LD   DE,AdapterLogBase
            OR   A
            SBC  HL,DE
            LD   (AdapterLoadedLogLength),HL
            LD   B,H
            LD   C,L
            LD   HL,AdapterLogBase
            LD   DE,AdapterLoadedLogBase
            LDIR
            LD   A,17
            LD   (ProofCase),A
            LD   A,1
            LD   HL,FlatTargetParts
            LD   IX,FlatTargetBadFlagsDescriptor
            CALL CTACPART
            JP   NC,ProofConfigurationFailure
            CALL ProofCompilerStackExact
            JP   NZ,ProofConfigurationFailure
            LD   A,(DGCODE)
            LD   (AdapterSavedDiagnostic),A
            LD   A,(AdapterAborted)
            OR   A
            JP   NZ,ProofConfigurationFailure
            LD   A,18
            LD   (ProofCase),A
            LD   A,1
            LD   HL,FlatTargetParts
            LD   IX,FlatTargetStackExactDescriptor
            CALL CTACPART
            JP   C,ProofRegionFailure
            LD   A,19
            LD   (ProofCase),A
            LD   A,1
            LD   HL,FlatTargetParts
            LD   IX,FlatTargetStackOverflowDescriptor
            CALL CTACPART
            JP   NC,ProofRegionFailure
            LD   A,(DGCODE)
            CP   DGTGTCAP
            JP   NZ,ProofRegionFailure
            XOR  A
            LD   (AdapterCommitted),A
            LD   (AdapterAborted),A
            LD   A,20
            LD   (ProofCase),A
            LD   (AdapterFailureCountdown),A
            LD   A,1
            LD   HL,FlatTargetParts
            LD   IX,FlatTargetDescriptor
            CALL CTACPART
            JP   NC,ProofAtomicFailure
            CALL ProofCompilerStackExact
            JP   NZ,ProofAtomicFailure
            LD   A,21
            LD   (ProofCase),A
            LD   A,(DGCODE)
            CP   DGTGTOUT
            JP   NZ,ProofAtomicFailure
            LD   A,22
            LD   (ProofCase),A
            LD   A,(AdapterCommitted)
            OR   A
            JP   NZ,ProofAtomicFailure
            LD   A,23
            LD   (ProofCase),A
            LD   A,(AdapterAborted)
            CP   1
            JP   NZ,ProofAtomicFailure
            LD   A,24
            LD   (ProofCase),A
            LD   HL,(AdapterCursor)
            LD   DE,AdapterLogBase
            OR   A
            SBC  HL,DE
            LD   A,H
            OR   L
            JP   Z,ProofAtomicFailure
            LD   A,30
            LD   (ProofCase),A
            XOR  A
            LD   (AdapterCommitted),A
            LD   (AdapterAborted),A
            LD   (AdapterFailureCountdown),A
            INC  A
            LD   (AdapterMapFailure),A
            LD   HL,AdapterLogBase
            LD   (AdapterCursor),HL
            LD   A,1
            LD   HL,FlatTargetTrapParts
            LD   IX,FlatTargetDescriptor
            CALL CTACPART
            JP   NC,ProofAtomicFailure
            CALL ProofCompilerStackExact
            JP   NZ,ProofAtomicFailure
            LD   A,(DGCODE)
            CP   DGTGTOUT
            JP   NZ,ProofAtomicFailure
            LD   A,(AdapterCommitted)
            OR   A
            JP   NZ,ProofAtomicFailure
            LD   A,(AdapterAborted)
            CP   1
            JP   NZ,ProofAtomicFailure
            LD   HL,(AdapterCursor)
            LD   DE,AdapterLogBase
            OR   A
            SBC  HL,DE
            LD   (AdapterFailedLogLength),HL
            LD   B,H
            LD   C,L
            LD   HL,AdapterLogBase
            LD   DE,AdapterFailedLogBase
            LDIR

            ; COMMIT fails after the target bank selector has closed. The
            ; local late-output path must abort once; the synthetic diagnostic
            ; continuation must observe the closed selector and not abort
            ; again.
            LD   A,31
            LD   (ProofCase),A
            XOR  A
            LD   (AdapterCommitted),A
            LD   (AdapterAborted),A
            LD   (AdapterMapFailure),A
            INC  A
            LD   (AdapterCommitFailure),A
            LD   HL,AdapterLogBase
            LD   (AdapterCursor),HL
            LD   A,1
            LD   HL,FlatTargetTrapParts
            LD   IX,FlatTargetDescriptor
            CALL CTACPART
            JP   NC,ProofAtomicFailure
            CALL ProofCompilerStackExact
            JP   NZ,ProofAtomicFailure
            LD   A,(DGCODE)
            CP   DGTGTOUT
            JP   NZ,ProofAtomicFailure
            LD   A,(AdapterCommitted)
            OR   A
            JP   NZ,ProofAtomicFailure
            LD   A,(AdapterAborted)
            CP   1
            JP   NZ,ProofAtomicFailure
            LD   A,25
            LD   (ProofCase),A
            XOR  A
            LD   (AdapterCommitted),A
            LD   (AdapterAborted),A
            LD   (AdapterFailureCountdown),A
            LD   (AdapterMapFailure),A
            LD   (AdapterCommitFailure),A
            LD   HL,AdapterLogBase
            LD   (AdapterCursor),HL
            LD   A,1
            LD   HL,FlatTargetParts
            LD   IX,FlatTargetDescriptor
            CALL CTACPART
            JP   C,ProofCompileFailure
            LD   A,(AdapterCommitted)
            CP   1
            JP   NZ,ProofCommitFailure
            LD   A,(AdapterAborted)
            OR   A
            JP   NZ,ProofCommitFailure
            LD   HL,(AdapterCapturedBegin+TDIMGBAS)
            LD   DE,$8000
            OR   A
            SBC  HL,DE
            JP   NZ,ProofBeginFailure
            LD   A,(TGLAYMOD)
            CP   TGLAYROM
            JP   NZ,ProofRegionFailure
            LD   HL,(TCRTBAS)
            LD   DE,$8003
            OR   A
            SBC  HL,DE
            JP   NZ,ProofContextFailure
            LD   HL,(TCSTBAS)
            LD   DE,$4000+RIVECBYT
            OR   A
            SBC  HL,DE
            JP   NZ,ProofContextFailure
            LD   HL,(TGIMGBAS)
            LD   DE,$8000
            OR   A
            SBC  HL,DE
            JP   NZ,ProofMapFailure
            LD   HL,(TGROBAS)
            LD   DE,$82EC+(RIVECBYT-33)+(RIBYTES-689)
            OR   A
            SBC  HL,DE
            JP   NZ,ProofMapFailure
            LD   HL,(TGWRBAS)
            LD   DE,$4000
            OR   A
            SBC  HL,DE
            JP   NZ,ProofMapFailure
            CALL TargetInitializedLength
            LD   DE,RIVECBYT+RISTBYT+2
            OR   A
            SBC  HL,DE
            JP   NZ,ProofMapFailure
            LD   HL,(TGBSSBAS)
            LD   DE,$4000+RIVECBYT+RISTBYT+2
            OR   A
            SBC  HL,DE
            JP   NZ,ProofMapFailure
            LD   HL,(TGROBAS)
            LD   DE,$82EC+(RIVECBYT-33)+(RIBYTES-689)
            OR   A
            SBC  HL,DE
            JP   NZ,ProofMapFailure
            LD   HL,(AdapterCursor)
            LD   DE,AdapterLogBase
            OR   A
            SBC  HL,DE
            LD   (AdapterLogLength),HL
            LD   A,H
            OR   L
            JP   Z,ProofLogFailure
            LD   B,H
            LD   C,L
            LD   HL,AdapterLogBase
            LD   DE,AdapterSuccessLogBase
            LDIR

            XOR  A
            LD   (AdapterCommitted),A
            LD   (AdapterAborted),A
            LD   (AdapterFailureCountdown),A
            LD   HL,AdapterLogBase
            LD   (AdapterCursor),HL
            LD   A,1
            LD   HL,FlatTargetTrapParts
            LD   IX,FlatTargetDescriptor
            CALL CTACPART
            JP   C,ProofCompileFailure
            LD   HL,(AdapterCursor)
            LD   DE,AdapterLogBase
            OR   A
            SBC  HL,DE
            LD   (AdapterTrapLogLength),HL
            LD   B,H
            LD   C,L
            LD   HL,AdapterLogBase
            LD   DE,AdapterTrapLogBase
            LDIR

            XOR  A
            LD   (AdapterCommitted),A
            LD   (AdapterAborted),A
            LD   (AdapterFailureCountdown),A
            LD   HL,AdapterLogBase
            LD   (AdapterCursor),HL
            LD   A,1
            LD   HL,FlatTargetUnhandledParts
            LD   IX,FlatTargetDescriptor
            CALL CTACPART
            JP   C,ProofCompileFailure
            LD   HL,(AdapterCursor)
            LD   DE,AdapterLogBase
            OR   A
            SBC  HL,DE
            LD   (AdapterUnhandledLogLength),HL
            LD   B,H
            LD   C,L
            LD   HL,AdapterLogBase
            LD   DE,AdapterUnhandledLogBase
            LDIR

            LD   A,(DGCODE)
            LD   (AdapterSavedDiagnostic),A

            LD   A,40
            LD   (ProofCase),A
            LD   A,2
            LD   HL,BankedTargetParts
            LD   IX,BankedInvalidPartDescriptor
            CALL CTACPART
            JP   NC,ProofConfigurationFailure
            LD   A,(DGCODE)
            CP   DGTGTCFG
            JP   NZ,ProofConfigurationFailure

            LD   A,41
            LD   (ProofCase),A
            LD   A,2
            LD   HL,BankedTargetParts
            LD   IX,BankedWrongEntryDescriptor
            CALL CTACPART
            JP   NC,ProofConfigurationFailure
            LD   A,(DGCODE)
            CP   DGTGTCFG
            JP   NZ,ProofConfigurationFailure

            LD   A,42
            LD   (ProofCase),A
            LD   A,2
            LD   HL,BankedConstantFailureParts
            LD   IX,BankedFailureDescriptor
            CALL CTACPART
            JP   NC,ProofConfigurationFailure
            LD   A,(DGCODE)
            CP   DGTGTCFG
            JP   NZ,ProofConfigurationFailure

            LD   A,43
            LD   (ProofCase),A
            XOR  A
            LD   (AdapterCommitted),A
            LD   (AdapterAborted),A
            LD   (AdapterFailureCountdown),A
            LD   HL,AdapterLogBase
            LD   (AdapterCursor),HL
            LD   A,2
            LD   HL,BankedTargetParts
            LD   IX,BankedEntryOverflowDescriptor
            CALL CTACPART
            JP   NC,ProofConfigurationFailure
            LD   A,(DGCODE)
            CP   DGTGTCAP
            JP   NZ,ProofConfigurationFailure
            LD   A,(AdapterAborted)
            DEC  A
            JP   NZ,ProofAtomicFailure
            LD   A,(AdapterCommitted)
            OR   A
            JP   NZ,ProofAtomicFailure

            LD   A,44
            LD   (ProofCase),A
            XOR  A
            LD   (AdapterCommitted),A
            LD   (AdapterAborted),A
            LD   (AdapterFailureCountdown),A
            LD   HL,AdapterLogBase
            LD   (AdapterCursor),HL
            LD   A,2
            LD   HL,BankedLargeParts
            LD   IX,BankedOtherOverflowDescriptor
            CALL CTACPART
            JP   NC,ProofConfigurationFailure
            LD   A,(DGCODE)
            CP   DGTGTCAP
            JP   NZ,ProofFail
            LD   A,(AdapterAborted)
            DEC  A
            JP   NZ,ProofAtomicFailure
            LD   A,(AdapterCommitted)
            OR   A
            JP   NZ,ProofAtomicFailure

            LD   A,45
            LD   (ProofCase),A
            XOR  A
            LD   (AdapterAborted),A
            LD   (AdapterFailureCountdown),A
            LD   HL,AdapterLogBase
            LD   (AdapterCursor),HL
            LD   A,2
            LD   HL,BankedParameterFailureParts
            LD   IX,BankedFailureDescriptor
            CALL CTACPART
            JP   NC,ProofConfigurationFailure
            CALL ProofCompilerStackExact
            JP   NZ,ProofConfigurationFailure
            LD   A,(DGCODE)
            CP   DGTGTCFG
            JP   NZ,ProofFail
            LD   A,(AdapterAborted)
            OR   A
            JP   NZ,ProofAtomicFailure

            LD   A,46
            LD   (ProofCase),A
            XOR  A
            LD   (AdapterAborted),A
            LD   (AdapterFailureCountdown),A
            LD   HL,AdapterLogBase
            LD   (AdapterCursor),HL
            LD   A,2
            LD   HL,BankedResultFailureParts
            LD   IX,BankedFailureDescriptor
            CALL CTACPART
            JP   NC,ProofConfigurationFailure
            LD   A,(DGCODE)
            CP   DGTGTCFG
            JP   NZ,ProofFail

            LD   A,47
            LD   (ProofCase),A
            XOR  A
            LD   (AdapterAborted),A
            LD   (AdapterFailureCountdown),A
            LD   HL,AdapterLogBase
            LD   (AdapterCursor),HL
            LD   A,2
            LD   HL,BankedForwardFailureParts
            LD   IX,BankedFailureDescriptor
            CALL CTACPART
            JP   NC,ProofConfigurationFailure
            LD   A,(DGCODE)
            CP   DGTGTCFG
            JP   NZ,ProofFail

            XOR  A
            LD   (AdapterCommitted),A
            LD   (AdapterAborted),A
            LD   (AdapterFailureCountdown),A
            LD   HL,AdapterBankedTrapLogBase
            LD   (AdapterCursor),HL
            LD   A,2
            LD   HL,BankedTrapParts
            LD   IX,BankedTargetDescriptor
            CALL CTACPART
            JP   C,ProofCompileFailure
            LD   HL,(AdapterCursor)
            LD   DE,AdapterBankedTrapLogBase
            OR   A
            SBC  HL,DE
            LD   (AdapterBankedTrapLogLength),HL

            XOR  A
            LD   (AdapterCommitted),A
            LD   (AdapterAborted),A
            LD   (AdapterFailureCountdown),A
            LD   HL,AdapterEntry1LogBase
            LD   (AdapterCursor),HL
            LD   A,1
            LD   HL,BankedTargetEntry1Parts
            LD   IX,BankedTargetEntry1Descriptor
            CALL CTACPART
            JR   C,ProofCompileFailure
            LD   HL,(AdapterCursor)
            LD   DE,AdapterEntry1LogBase
            OR   A
            SBC  HL,DE
            LD   (AdapterEntry1LogLength),HL

            XOR  A
            LD   (AdapterCommitted),A
            LD   (AdapterAborted),A
            LD   (AdapterFailureCountdown),A
            LD   HL,AdapterLogBase
            LD   (AdapterCursor),HL
            LD   A,2
            LD   HL,BankedTargetParts
            LD   IX,BankedTargetDescriptor
            CALL CTACPART
            JR   C,ProofCompileFailure
            LD   HL,(AdapterCursor)
            LD   DE,AdapterLogBase
            OR   A
            SBC  HL,DE
            LD   (AdapterBankedLogLength),HL

            XOR  A
            LD   (AdapterCommitted),A
            LD   (AdapterAborted),A
            LD   (AdapterFailureCountdown),A
            LD   HL,AdapterChapter21LogBase
            LD   (AdapterCursor),HL
            LD   A,2
            LD   HL,Chapter21TargetParts
            LD   IX,Chapter21TargetDescriptor
            CALL CTACPART
            JR   C,ProofCompileFailure
            LD   HL,(AdapterCursor)
            LD   DE,AdapterChapter21LogBase
            OR   A
            SBC  HL,DE
            LD   (AdapterChapter21LogLength),HL
            LD   A,(AdapterSavedDiagnostic)
            LD   (DGCODE),A
            LD   A,$A5
            LD   (ProofStatus),A
            XOR  A
            LD   (ProofCase),A
            HALT

ProofCompileFailure: LD A,1
            JR   ProofFail
ProofCommitFailure:  LD A,2
            JR   ProofFail
ProofBeginFailure:   LD A,3
            JR   ProofFail
ProofContextFailure: LD A,4
            JR   ProofFail
ProofMapFailure:     LD A,5
            JR   ProofFail
ProofLogFailure:     LD A,6
            JR   ProofFail
ProofRegionFailure:  LD A,(ProofCase)
            JR   ProofFail
ProofLoadedFailure:  LD A,(ProofCase)
            JR   ProofFail
ProofAtomicFailure:  LD A,(ProofCase)
            JR   ProofFail
ProofConfigurationFailure: LD A,(ProofCase)
ProofFail:
            LD   (ProofCase),A
            LD   A,$E1
            LD   (ProofStatus),A
            HALT

; Reserve A bytes atomically in the bounded proof-only operation log.
.routine in A out A,IY,carry,zero clobbers sign,parity,halfCarry,DE,HL
AdapterReserve:
            LD   E,A
            LD   A,(AdapterFailureCountdown)
            OR   A
            JR   Z,AdapterReserveCapacity
            DEC  A
            LD   (AdapterFailureCountdown),A
            JR   NZ,AdapterReserveCapacity
            LD   A,DGTGTOUT
            SCF
            RET
AdapterReserveCapacity:
            LD   A,E
            LD   D,0
            LD   IY,(AdapterCursor)
            PUSH IY
            POP  HL
            ADD  HL,DE
            LD   DE,AdapterLogLimit
            OR   A
            SBC  HL,DE
            JR   C,AdapterReserveReady
            JR   Z,AdapterReserveReady
            LD   A,DGTGTOUT
            SCF
            RET
AdapterReserveReady:
            ADD  HL,DE
            LD   (AdapterCursor),HL
            OR   A
            RET

.routine in IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IY
TSBEGIN:
            LD   HL,AdapterCapturedBegin
            LD   B,TDSZ
TargetSinkBeginCopy:
            LD   A,(IX+0)
            LD   (HL),A
            INC  IX
            INC  HL
            DJNZ TargetSinkBeginCopy
            LD   A,1
            LD   (AdapterOpen),A
            OR   A
            RET

.routine in A,C,HL out A,carry,zero clobbers sign,parity,halfCarry,DE
TSBYTE:
            PUSH IY
            PUSH AF
            PUSH BC
            PUSH HL
            LD   A,7
            CALL AdapterReserve
            JR   C,TargetSinkImageByteReserveFailure
            POP  HL
            POP  BC
            POP  AF
.if DebugHooks
            OUT  (DTIMAGE),A
.endif
            LD   (IY+0),1
            LD   (IY+1),C
            LD   (IY+2),L
            LD   (IY+3),H
            LD   (IY+4),1
            LD   (IY+5),0
            LD   (IY+6),A
            POP  IY
            OR   A
            RET
TargetSinkImageByteFailure:
            POP  IY
            RET
TargetSinkImageByteReserveFailure:
            LD   E,A
            POP  HL
            POP  BC
            POP  AF
            POP  IY
            LD   A,E
            SCF
            RET

.routine in A,BC,DE,HL,IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
TSRTIMG:
            PUSH AF
            LD   A,3
            LD   (AdapterRuntimeKind),A
            POP  AF
            JR   TargetSinkRuntimeSelected
.routine in A,BC,DE,HL,IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
TSRTINIT:
            PUSH AF
            LD   A,4
            LD   (AdapterRuntimeKind),A
            POP  AF
TargetSinkRuntimeSelected:
            LD   (AdapterRuntimeBank),A
            LD   (AdapterRuntimeLength),BC
            LD   (AdapterRuntimeIdentity),DE
            LD   (AdapterRuntimeAddress),HL
            LD   A,8
            CALL AdapterReserve
            RET  C
            LD   A,(AdapterRuntimeBank)
            LD   BC,(AdapterRuntimeLength)
            LD   DE,(AdapterRuntimeIdentity)
            LD   HL,(AdapterRuntimeAddress)
            LD   A,(AdapterRuntimeKind)
            LD   (IY+0),A
            LD   A,(AdapterRuntimeBank)
            LD   (IY+1),A
            LD   (IY+2),L
            LD   (IY+3),H
            LD   (IY+4),C
            LD   (IY+5),B
            LD   (IY+6),E
            LD   (IY+7),D
            OR   A
            RET

.routine in A,C,HL out A,carry,zero clobbers sign,parity,halfCarry,DE
TSPATBYT:
            PUSH IY
            PUSH AF
            PUSH BC
            PUSH HL
            LD   A,7
            CALL AdapterReserve
            JR   C,TargetSinkPatchByteReserveFailure
            POP  HL
            POP  BC
            POP  AF
            LD   (IY+0),2
            LD   (IY+1),C
            LD   (IY+2),L
            LD   (IY+3),H
            LD   (IY+4),1
            LD   (IY+5),0
            LD   (IY+6),A
            POP  IY
            OR   A
            RET
TargetSinkPatchByteFailure:
            POP  IY
            RET
TargetSinkPatchByteReserveFailure:
            LD   E,A
            POP  HL
            POP  BC
            POP  AF
            POP  IY
            LD   A,E
            SCF
            RET

.routine in C,DE,HL out A,carry,zero clobbers sign,parity,halfCarry
TSPATWRD:
            PUSH IY
            PUSH BC
            PUSH DE
            PUSH HL
            LD   A,8
            CALL AdapterReserve
            POP  HL
            POP  DE
            POP  BC
            JR   C,TargetSinkPatchWordFailure
            LD   (IY+0),2
            LD   (IY+1),C
            LD   (IY+2),E
            LD   (IY+3),D
            LD   (IY+4),2
            LD   (IY+5),0
            LD   (IY+6),L
            LD   (IY+7),H
            POP  IY
            OR   A
            RET
TargetSinkPatchWordFailure:
            POP  IY
            RET

.routine in IX out A,carry,zero clobbers sign,parity,halfCarry
TSMAP:
            LD   A,(AdapterMapFailure)
            OR   A
            JR   Z,TargetSinkMapReady
            LD   A,DGTGTOUT
            SCF
            RET
TargetSinkMapReady:
            OR   A
            RET

.routine in IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
TSBANK:
            LD   A,(IX+TQBNKCNT-TQBASE)
            LD   B,A
            LD   L,(IX+TQBNKST-TQBASE)
            LD   H,(IX+TQBNKST-TQBASE+1)
            PUSH HL
            POP  IY
            LD   HL,AdapterCapturedBankCursors
            LD   DE,AdapterCapturedBankRemaining
            LD   IX,AdapterCapturedBankRoLengths
TargetSinkMapBankedCursorLoop:
            LD   A,(IY+0)
            LD   (HL),A
            INC  HL
            LD   A,(IY+1)
            LD   (HL),A
            INC  HL
            LD   A,(IY+2)
            LD   (DE),A
            INC  DE
            LD   A,(IY+3)
            LD   (DE),A
            INC  DE
            LD   A,(IY+4)
            LD   (IX+0),A
            INC  IX
            LD   A,(IY+5)
            LD   (IX+0),A
            INC  IX
            PUSH DE
            LD   DE,TBSZ
            ADD  IY,DE
            POP  DE
            DJNZ TargetSinkMapBankedCursorLoop
            OR   A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry
TSCOMMIT:
            LD   A,(AdapterCommitFailure)
            OR   A
            JR   Z,TargetSinkCommitReady
            LD   A,DGTGTOUT
            SCF
            RET
TargetSinkCommitReady:
            LD   A,1
            LD   (AdapterCommitted),A
            OR   A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry
TSABORT:
            LD   A,(AdapterAborted)
            INC  A
            LD   (AdapterAborted),A
            OR   A
            RET

; Direct proof calls do not enter through the public compiler boundary. These
; wrappers plant their ordinary CALL continuation as the diagnostic return SP,
; so both success and a nonlocal diagnostic return to the same proof site.
.routine in DE,HL out A,carry,zero clobbers sign,parity,halfCarry,HL
ProofCallTargetValidateRegion:
            LD   (CPABRTSP),SP
            JP   TargetValidateRegion

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
ProofCallTargetClassifyFlatLayout:
            LD   (CPABRTSP),SP
            JP   TargetClassifyFlatLayout

; Called only while ProofStart owns StackTop. The helper's return address is
; the sole expected two-byte displacement from that root stack pointer.
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
ProofCompilerStackExact:
            LD   HL,0
            ADD  HL,SP
            LD   DE,STACKTOP-2
            OR   A
            SBC  HL,DE
            RET

; Exercise the production-only shared segmented-capacity predicate directly.
; Each wrapper plants its caller continuation as CompilerAbortSp, so a
; nonlocal diagnostic must restore the exact proof stack before returning.
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
ProofCheckProductionCapacityBoundaries:
            LD   HL,0
            ADD  HL,SP
            LD   (ProofCapacityExpectedSP),HL
            LD   HL,$0400
            CALL ProofCallProgramCapacity
            JR   C,ProofProductionCapacityFailure
            CALL ProofCapacityStackExact
            JR   NZ,ProofProductionCapacityFailure
            LD   HL,$0400
            CALL ProofCallReadOnlyCapacity
            JR   C,ProofProductionCapacityFailure
            CALL ProofCapacityStackExact
            JR   NZ,ProofProductionCapacityFailure
            LD   HL,$0401
            CALL ProofCallProgramCapacity
            JR   NC,ProofProductionCapacityFailure
            LD   A,(DGCODE)
            CP   DGPDCAP
            JR   NZ,ProofProductionCapacityFailure
            CALL ProofCapacityStackExact
            JR   NZ,ProofProductionCapacityFailure
            LD   HL,$0401
            CALL ProofCallReadOnlyCapacity
            JR   NC,ProofProductionCapacityFailure
            LD   A,(DGCODE)
            CP   DGROCAP
            JR   NZ,ProofProductionCapacityFailure
            CALL ProofCapacityStackExact
            JR   NZ,ProofProductionCapacityFailure
            LD   HL,$FFFF
            CALL ProofCallProgramCapacity
            JR   NC,ProofProductionCapacityFailure
            LD   A,(DGCODE)
            CP   DGPDCAP
            JR   NZ,ProofProductionCapacityFailure
            CALL ProofCapacityStackExact
            JR   NZ,ProofProductionCapacityFailure
            LD   HL,$FFFF
            CALL ProofCallReadOnlyCapacity
            JR   NC,ProofProductionCapacityFailure
            LD   A,(DGCODE)
            CP   DGROCAP
            JR   NZ,ProofProductionCapacityFailure
            CALL ProofCapacityStackExact
            RET  NZ
            XOR  A
            RET
ProofProductionCapacityFailure:
            SCF
            RET

.routine in HL out A,HL,carry,zero clobbers sign,parity,halfCarry,B
ProofCallProgramCapacity:
            LD   (CPABRTSP),SP
            JP   AggregateCheckExtentCapacity

.routine in HL out A,HL,carry,zero clobbers sign,parity,halfCarry,B
ProofCallReadOnlyCapacity:
            LD   (CPABRTSP),SP
            JP   AggregateCheckReadOnlyCapacity

.routine out A,DE,HL,carry,zero clobbers sign,parity,halfCarry
ProofCapacityStackExact:
            LD   HL,2
            ADD  HL,SP
            LD   DE,(ProofCapacityExpectedSP)
            OR   A
            SBC  HL,DE
            RET

ProofStatus: .db 0
ProofCase:   .db 0
ProofCapacityExpectedSP: .dw 0
AdapterOpen: .db 0
AdapterCommitted: .db 0
AdapterAborted:   .db 0
AdapterCursor:    .dw 0
AdapterLogLength: .dw 0
AdapterLoadedLogLength: .dw 0
AdapterTrapLogLength: .dw 0
AdapterUnhandledLogLength: .dw 0
AdapterBankedLogLength: .dw 0
AdapterEntry1LogLength: .dw 0
AdapterBankedTrapLogLength: .dw 0
AdapterChapter21LogLength: .dw 0
AdapterFailedLogLength: .dw 0
AdapterFailureCountdown: .db 0
AdapterMapFailure:       .db 0
AdapterCommitFailure:    .db 0
AdapterSavedDiagnostic:  .db 0
AdapterCapturedBegin:   .ds TDSZ
AdapterCapturedBankCursors: .ds TBKCAP*2
AdapterCapturedBank0Cursor .equ AdapterCapturedBankCursors
AdapterCapturedBank1Cursor .equ AdapterCapturedBankCursors+2
AdapterCapturedBankRemaining: .ds TBKCAP*2
AdapterCapturedBank0Remaining .equ AdapterCapturedBankRemaining
AdapterCapturedBank1Remaining .equ AdapterCapturedBankRemaining+2
AdapterCapturedBankRoLengths: .ds TBKCAP*2
AdapterCapturedBank0RoLength .equ AdapterCapturedBankRoLengths
AdapterCapturedBank1RoLength .equ AdapterCapturedBankRoLengths+2
AdapterCapturedBankedMapLength: .dw 0
AdapterCapturedBankedMap: .ds 1
AdapterCapturedRuntimeBase .equ TCRTBAS
AdapterCapturedStateBase   .equ TCSTBAS
AdapterRuntimeBank:     .db 0
AdapterRuntimeKind:     .db 0
AdapterRuntimeLength:   .dw 0
AdapterRuntimeIdentity: .dw 0
AdapterRuntimeAddress:  .dw 0
AdapterRuntimeContext:  .dw TGRTCTX
AdapterRuntimeContextPointer .equ AdapterRuntimeContext
ProofEnd:

AdapterLoadedLogBase    .equ $99F0
AdapterSuccessLogBase   .equ $9CF0
AdapterTrapLogBase      .equ $A0C0
AdapterUnhandledLogBase .equ $A5C0
AdapterBankedTrapLogBase .equ $ACC0
AdapterLogBase          .equ $B4C0
AdapterFailedLogBase    .equ $C6C0
AdapterEntry1LogBase    .equ $CBC0
AdapterChapter21LogBase .equ $D0C0
AdapterLogLimit         .equ $F000
