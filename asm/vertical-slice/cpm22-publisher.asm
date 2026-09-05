; Transactional CP/M publisher for the direct materializer. The completed
; target image is already patched in TPA. COM and BIN are the same flat bytes
; loaded at $0100; HEX carries those bytes with their logical addresses.

CpmPublishDmaFunction   .equ 26
CpmPublishOpenFunction  .equ 15
CpmPublishCloseFunction .equ 16
CpmPublishDeleteFunction .equ 19
CpmPublishWriteFunction .equ 21
CpmPublishMakeFunction  .equ 22
CpmPublishRenameFunction .equ 23
CpmPublishDma           .equ $0080
CpmPublishPrefixRecords .equ (CpmTargetImageBase-$0100)/128

CpmPublisherCodeStart:
; IX and IY carry publisher state, but CP/M does not standardize their return
; values. Every BDOS edge therefore saves both rather than depending on an
; accidental property of an 8080-derived implementation.
; Reserve the output-derived temporary and backup names before compilation.
; CP/M is single-tasking, so absence reserves both for this transient.
.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CpmPublishPrepare:
            XOR  A
            LD   (CpmPublishState),A
            CALL CpmPublishSetTemporary
            CALL CpmPublishRequireAbsent
            RET  C
            CALL CpmPublishSetBackup
            CALL CpmPublishRequireAbsent
            RET  C
            LD   A,1
            LD   (CpmPublishState),A
            XOR  A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CpmPublishRequireAbsent:
            LD   C,CpmPublishOpenFunction
            CALL CpmPublishFcbCall
            INC  A
            JR   Z,CpmPublishAbsent
            JP   CpmDirectInvalid
CpmPublishAbsent:
            XOR  A
            RET

; HL is the exact nonzero generated-image length beginning at logical $0800.
; The COM first receives the packed provider prefix plus zero fill through
; $07FF, then the already-patched image. CP/M's final physical record is zero
; padded from the materializer's previously cleared buffer.
.routine in HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CpmDirectPublish:
            LD   A,(CpmPublishState)
            OR   A
            JP   Z,CpmDirectInvalid
            PUSH HL
            POP  IY
            CALL CpmPublishSetTemporary
            LD   C,CpmPublishMakeFunction
            CALL CpmPublishFcbCall
            INC  A
            JP   Z,CpmPublishRollbackFailure
            LD   A,(CpmCompilerOutputFormat)
            CP   CpmOutputFormatHex
            JP   Z,CpmPublishHexBody
CpmPublishRawBody:
            LD   IX,CpmEmbeddedPrefix
            LD   A,CpmPublishPrefixRecords
            LD   (CpmPublishPrefixRecordCount),A
CpmPublishPrefixLoop:
            CALL CpmPublishClearDma
            LD   HL,CpmEmbeddedPrefixEnd
            PUSH IX
            POP  DE
            OR   A
            SBC  HL,DE
            LD   A,H
            OR   L
            JR   Z,CpmPublishPrefixReady
            LD   BC,128
            OR   A
            SBC  HL,BC
            JR   NC,CpmPublishPrefixFull
            ADD  HL,BC
            LD   B,H
            LD   C,L
            JR   CpmPublishPrefixCopy
CpmPublishPrefixFull:
            LD   BC,128
CpmPublishPrefixCopy:
            PUSH IX
            POP  HL
            LD   DE,CpmPublishDma
            LDIR
            PUSH HL
            POP  IX
CpmPublishPrefixReady:
            LD   DE,CpmPublishDma
            CALL CpmPublishWriteRecord
            JP   C,CpmPublishRollbackFailure
            LD   HL,CpmPublishPrefixRecordCount
            DEC  (HL)
            JR   NZ,CpmPublishPrefixLoop

            LD   IX,CpmOutputBufferBase
CpmPublishImageLoop:
            PUSH IX
            POP  DE
            CALL CpmPublishWriteRecord
            JP   C,CpmPublishRollbackFailure
            PUSH IY
            POP  HL
            LD   DE,128
            OR   A
            SBC  HL,DE
            JP   C,CpmPublishCloseTemporary
            LD   A,H
            OR   L
            JP   Z,CpmPublishCloseTemporary
            PUSH HL
            POP  IY
            ADD  IX,DE
            JR   CpmPublishImageLoop

; Render the same logical $0100 image as addressed Intel HEX records. The
; resident prefix and generated image are disjoint physical buffers, so the
; zero-filled logical gap is emitted as bounded sixteen-byte segments.
CpmPublishHexBody:
            CALL ZTS_CPM_HEX_BEGIN
            LD   HL,CpmEmbeddedPrefix
            LD   (ZTS_CPM_FINAL_SOURCE_CURSOR),HL
            LD   HL,CpmEmbeddedPrefixEnd-CpmEmbeddedPrefix
            LD   (ZTS_CPM_FINAL_REMAINING),HL
            LD   HL,$0100
            LD   (ZTS_CPM_FINAL_ADDRESS),HL
            CALL ZTS_CPM_HEX_SEGMENT
            LD   HL,CpmTargetImageBase-$0100-(CpmEmbeddedPrefixEnd-CpmEmbeddedPrefix)
            LD   (CpmPublishHexGapRemaining),HL
CpmPublishHexGapLoop:
            LD   HL,(CpmPublishHexGapRemaining)
            LD   A,H
            OR   L
            JR   Z,CpmPublishHexImage
            LD   DE,16
            OR   A
            SBC  HL,DE
            JR   C,CpmPublishHexLastGap
            LD   (CpmPublishHexGapRemaining),HL
            LD   HL,16
            JR   CpmPublishHexGapReady
CpmPublishHexLastGap:
            ADD  HL,DE
            LD   DE,0
            LD   (CpmPublishHexGapRemaining),DE
CpmPublishHexGapReady:
            LD   (ZTS_CPM_FINAL_REMAINING),HL
            LD   HL,CpmPublishHexZeroes
            LD   (ZTS_CPM_FINAL_SOURCE_CURSOR),HL
            CALL ZTS_CPM_HEX_SEGMENT
            JR   CpmPublishHexGapLoop
CpmPublishHexImage:
            LD   HL,CpmOutputBufferBase
            LD   (ZTS_CPM_FINAL_SOURCE_CURSOR),HL
            PUSH IY
            POP  HL
            LD   (ZTS_CPM_FINAL_REMAINING),HL
            CALL ZTS_CPM_HEX_SEGMENT
            CALL ZTS_CPM_HEX_END
            JP   C,CpmPublishRollbackFailure

CpmPublishCloseTemporary:
            LD   C,CpmPublishCloseFunction
            CALL CpmPublishFcbCall
            INC  A
            JR   Z,CpmPublishRollbackFailure

            CALL CpmPublishSetBackup
            CALL CpmPublishBuildOutputToCurrent
            LD   C,CpmPublishRenameFunction
            CALL CpmPublishFcbCall
            INC  A
            JR   Z,CpmPublishNoBackup
            LD   A,3
            LD   (CpmPublishState),A
CpmPublishNoBackup:
            CALL CpmPublishSetTemporary
            CALL CpmPublishBuildCurrentToOutput
            LD   C,CpmPublishRenameFunction
            CALL CpmPublishFcbCall
            INC  A
            JR   Z,CpmPublishRollbackFailure
            CALL CpmPublishSetBackup
            LD   C,CpmPublishDeleteFunction
            CALL CpmPublishFcbCall
            XOR  A
            LD   (CpmPublishState),A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CpmDirectPublishAbort:
            JP   CpmPublishRollback

CpmPublishRollbackFailure:
            CALL CpmPublishRollback
            JP   CpmDirectInvalid

.routine in DE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CpmPublishWriteRecord:
            LD   C,CpmPublishDmaFunction
            CALL BDOSCALL
            LD   C,CpmPublishWriteFunction
            CALL CpmPublishFcbCall
            OR   A
            RET  Z
            SCF
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CpmPublishClearDma:
            LD   HL,CpmPublishDma
            LD   DE,CpmPublishDma+1
            LD   BC,127
            LD   (HL),0
            LDIR
            XOR  A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CpmPublishRollback:
            LD   A,(CpmPublishState)
            OR   A
            RET  Z
            CALL CpmPublishSetTemporary
            LD   C,CpmPublishCloseFunction
            CALL CpmPublishFcbCall
            LD   C,CpmPublishDeleteFunction
            CALL CpmPublishFcbCall
            LD   A,(CpmPublishState)
            AND  2
            JR   Z,CpmPublishRollbackDone
            CALL CpmPublishSetBackup
            CALL CpmPublishBuildCurrentToOutput
            LD   C,CpmPublishRenameFunction
            CALL CpmPublishFcbCall
CpmPublishRollbackDone:
            XOR  A
            LD   (CpmPublishState),A
            RET

.routine in C out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL
CpmPublishFcbCall:
            LD   DE,CpmPublishWorkFcb
            JP   BDOSCALL

.routine out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL
CpmPublishCopyOutputName:
            LD   HL,CpmCompilerOutputName
            LD   DE,CpmPublishWorkFcb
            JP   FCBMAKE

.routine out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL,IX,IY
CpmPublishSetTemporary:
            CALL CpmPublishCopyOutputName
            LD   HL,$2424
            LD   A,'$'
            JR   CpmPublishSetExtension

.routine out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL,IX,IY
CpmPublishSetBackup:
            CALL CpmPublishCopyOutputName
            LD   HL,$4142
            LD   A,'K'
CpmPublishSetExtension:
            LD   (CpmPublishWorkFcb+9),HL
            LD   (CpmPublishWorkFcb+11),A
            RET

; The current FCB name is the new name; install the selected output as old.
.routine out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL,IX,IY
CpmPublishBuildOutputToCurrent:
            LD   HL,CpmPublishWorkFcb
            LD   DE,CpmPublishWorkFcb+16
            CALL CpmPublishCopyRenameName
            LD   HL,CpmCompilerOutputName
            LD   DE,CpmPublishWorkFcb
            JP   CpmPublishCopyRenameName

.routine in DE,HL out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL
CpmPublishCopyRenameName:
            LD   BC,12
            LDIR
            RET

; The current FCB name is old; install the selected output as its new name.
.routine out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL,IX,IY
CpmPublishBuildCurrentToOutput:
            LD   HL,CpmCompilerOutputName
            LD   DE,CpmPublishWorkFcb+16
            JP   CpmPublishCopyRenameName

ZTS_CPM_FINAL_DMA           .equ CpmPublishDma
ZTS_CPM_FINAL_FCB           .equ CpmPublishWorkFcb
ZTS_CPM_FINAL_DMA_CURSOR    .equ CpmPublishHexDmaCursor
ZTS_CPM_FINAL_DMA_COUNT     .equ CpmPublishHexDmaCount
ZTS_CPM_FINAL_ERROR         .equ CpmPublishHexError
ZTS_CPM_FINAL_REMAINING     .equ CpmPublishHexRemaining
ZTS_CPM_FINAL_SOURCE_CURSOR .equ CpmPublishHexSourceCursor
ZTS_CPM_FINAL_ADDRESS       .equ CpmPublishHexAddress
ZTS_CPM_FINAL_SIZE          .equ CpmPublishHexSize
ZTS_CPM_FINAL_DATA_LEFT     .equ CpmPublishHexDataLeft
ZTS_CPM_FINAL_SUM           .equ CpmPublishHexSum
            .include "cpm22-final-image.asm"
CpmPublisherCodeEnd:

CpmPublishHexZeroes:        .ds 16,0

CpmPublisherWorkspaceStart .equ CpmDirectWorkspaceEnd
CpmPublishWorkFcb          .equ CpmPublisherWorkspaceStart
CpmPublishPrefixRecordCount .equ CpmPublishWorkFcb+36
CpmPublishState            .equ CpmPublishPrefixRecordCount+1
CpmPublishHexDmaCursor     .equ CpmPublishState+1
CpmPublishHexDmaCount      .equ CpmPublishHexDmaCursor+2
CpmPublishHexError         .equ CpmPublishHexDmaCount+1
CpmPublishHexRemaining     .equ CpmPublishHexError+1
CpmPublishHexSourceCursor  .equ CpmPublishHexRemaining+2
CpmPublishHexAddress       .equ CpmPublishHexSourceCursor+2
CpmPublishHexSize          .equ CpmPublishHexAddress+2
CpmPublishHexDataLeft      .equ CpmPublishHexSize+1
CpmPublishHexSum           .equ CpmPublishHexDataLeft+1
CpmPublishHexGapRemaining  .equ CpmPublishHexSum+1
CpmPublisherWorkspaceEnd   .equ CpmPublishHexGapRemaining+2
