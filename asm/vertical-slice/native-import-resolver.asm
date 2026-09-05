; Native Nucleus import resolver. This is a standalone host tool, not part of
; the 16 KiB compiler image. It reads preserved //% import headers through the
; common named-object service and commits an SP1 plan for the source streamer.
;
; Entry contract:
;   HL = normalized or normalizable entry-object name
;   B  = name length, 1..255
; Result:
;   carry clear, A = 0 after committing .nucleus/source-plan.sp1
;   carry set, A = canonical system status after aborting tentative output

NativeImportPartCapacity       .equ 8

NativeImportPartPointers       .equ $5C40 ; eight little-endian pointers
NativeImportPartLengths        .equ $5C50 ; eight bytes
NativeImportPartStates         .equ $5C58 ; 0=new, 1=visiting, 2=done
NativeImportPartCount          .equ $5C60
NativeImportCurrentPart        .equ $5C61
NativeImportHeaderActive       .equ $5C62
NativeImportPlanHandle         .equ $5C63
NativeImportSourceHandle       .equ $5C65
NativeImportSourceOffset       .equ $5C67
NativeImportReadCursor         .equ $5C69
NativeImportReadEnd            .equ $5C6B
NativeImportCandidateLength    .equ $5C6D
NativeImportRawLength          .equ $5C6E
NativeImportSavedStatus        .equ $5C6F
NativeImportPathBuildLength    .equ $5C70
NativeImportNormalizeEnd       .equ $5C72
NativeImportNormalizeFloor     .equ $5C74
NativeImportDecimalScratch     .equ $5C76
NativeImportNamePoolEnd        .equ $5C79
NativeImportCurrentNamePointer .equ $5C7B
NativeImportComponentStart     .equ $5C7D
NativeImportComponentLength    .equ $5C7F
NativeImportChildPart          .equ $5C80
NativeImportResumeDepth        .equ $5C81
NativeImportResumeParts        .equ $5C82
NativeImportResumeOffsets      .equ $5C8A
NativeImportResumeHeaders      .equ $5C9A
NativeImportWorkspaceEnd       .equ $5CA2

NativeImportNamePoolBase       .equ $6000
NativeImportNamePoolLimit      .equ $6800
NativeImportReadBuffer         .equ $6800
NativeImportReadBufferLimit    .equ $6900
NativeImportCandidate          .equ $6900
NativeImportCandidateLimit     .equ $6A00
NativeImportRawPath            .equ $6A00
NativeImportRawPathLimit       .equ $6B00
NativeImportPathBuild          .equ $6B00
NativeImportPathBuildLimit     .equ $6D00

NativeImportStateNew           .equ 0
NativeImportStateVisiting      .equ 1
NativeImportStateDone          .equ 2

NativeImportPlanName:
            .db ".nucleus/source-plan.sp1"
NativeImportPlanNameLength .equ $-NativeImportPlanName
NativeImportPlanHeader:
            .db "SP1 0",10
NativeImportPlanHeaderLength .equ $-NativeImportPlanHeader
NativeImportPlanEnd:
            .db "END",10
NativeImportPlanEndLength .equ $-NativeImportPlanEnd
NativeImportStandardPrefix:
            .db "@nucleus/"
NativeImportStandardPrefixLength .equ $-NativeImportStandardPrefix

.routine in HL,B out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
NativeImportResolve:
            PUSH HL
            PUSH BC
            CALL NativeImportReset
            POP  BC
            POP  HL
            LD   A,B
            OR   A
            JP   Z,NativeImportInvalid
            LD   (NativeImportComponentLength),A
            LD   DE,NativeImportPathBuild
            LD   C,B
            LD   B,0
            LDIR
            LD   A,(NativeImportComponentLength)
            LD   L,A
            LD   H,0
            LD   (NativeImportPathBuildLength),HL
            CALL NativeImportNormalizeBuild
            JP   C,NativeImportResolveFail
            CALL NativeImportFindOrAddCandidate
            JP   C,NativeImportResolveFail
            LD   (NativeImportCurrentPart),A
            LD   HL,NativeImportPlanName
            LD   B,NativeImportPlanNameLength
            LD   A,NucleusObjectBeginWrite
            CALL NativeSourceProviderOpen
            JP   C,NativeImportResolveFail
            LD   (NativeImportPlanHandle),HL
            LD   DE,NativeImportPlanHeader
            LD   BC,NativeImportPlanHeaderLength
            CALL NativeImportWritePlan
            JP   C,NativeImportResolveFail
            LD   A,(NativeImportCurrentPart)
            CALL NativeImportVisitPart
            JP   C,NativeImportResolveFail
            LD   DE,NativeImportPlanEnd
            LD   BC,NativeImportPlanEndLength
            CALL NativeImportWritePlan
            JP   C,NativeImportResolveFail
            LD   HL,(NativeImportPlanHandle)
            LD   DE,4
            CALL NativeSourceProviderSeek
            JP   C,NativeImportResolveFail
            LD   A,(NativeImportPartCount)
            ADD  A,'0'
            LD   (NativeImportDecimalScratch),A
            LD   DE,NativeImportDecimalScratch
            LD   BC,1
            CALL NativeImportWritePlan
            JP   C,NativeImportResolveFail
            LD   HL,(NativeImportPlanHandle)
            LD   A,NucleusObjectCommit
            CALL NativeSourceProviderTerminal
            JP   C,NativeImportResolveFail
            XOR  A
            LD   (NativeImportPlanHandle),A
            LD   (NativeImportPlanHandle+1),A
            RET
NativeImportResolveFail:
            LD   (NativeImportSavedStatus),A
            CALL NativeImportCloseSource
            LD   HL,(NativeImportPlanHandle)
            LD   A,H
            OR   L
            JR   Z,NativeImportResolveFailed
            LD   A,NucleusObjectAbort
            CALL NativeSourceProviderTerminal
            XOR  A
            LD   (NativeImportPlanHandle),A
            LD   (NativeImportPlanHandle+1),A
NativeImportResolveFailed:
            LD   A,(NativeImportSavedStatus)
            SCF
            RET

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
NativeImportReset:
            LD   HL,NativeImportPartPointers
            LD   DE,NativeImportPartPointers+1
            LD   BC,NativeImportWorkspaceEnd-NativeImportPartPointers-1
            XOR  A
            LD   (HL),A
            LDIR
            LD   HL,NativeImportNamePoolBase
            LD   (NativeImportNamePoolEnd),HL
            LD   HL,NativeImportReadBuffer
            LD   (NativeImportReadCursor),HL
            LD   (NativeImportReadEnd),HL
            RET

; Write BC exact bytes at DE to the tentative SP1 object.
.routine in DE,BC out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
NativeImportWritePlan:
            LD   HL,(NativeImportPlanHandle)
            JP   NativeSourceProviderWrite

; Return part A's name in HL/B.
.routine in A out A,B,DE,HL,carry,zero clobbers sign,parity,halfCarry
NativeImportPartName:
            LD   E,A
            LD   D,0
            LD   HL,NativeImportPartLengths
            ADD  HL,DE
            LD   B,(HL)
            LD   HL,NativeImportPartPointers
            ADD  HL,DE
            ADD  HL,DE
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            EX   DE,HL
            RET

; Return a pointer to part A's visit-state byte in HL.
.routine in A out A,DE,HL,carry,zero clobbers sign,parity,halfCarry
NativeImportPartState:
            LD   E,A
            LD   D,0
            LD   HL,NativeImportPartStates
            ADD  HL,DE
            RET

; Find Candidate[CandidateLength], or append it to the bounded name pool.
; Return its part ordinal in A.
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
NativeImportFindOrAddCandidate:
            LD   A,(NativeImportPartCount)
            LD   C,A
            XOR  A
NativeImportFindCandidateLoop:
            CP   C
            JR   Z,NativeImportAppendCandidate
            PUSH AF
            CALL NativeImportPartName
            LD   A,(NativeImportCandidateLength)
            CP   B
            JR   NZ,NativeImportCandidateDifferent
            LD   DE,NativeImportCandidate
NativeImportCandidateCompare:
            LD   A,(DE)
            CP   (HL)
            JR   NZ,NativeImportCandidateDifferent
            INC  DE
            INC  HL
            DEC  B
            JR   NZ,NativeImportCandidateCompare
            POP  AF
            OR   A
            RET
NativeImportCandidateDifferent:
            POP  AF
            INC  A
            JR   NativeImportFindCandidateLoop

NativeImportAppendCandidate:
            CP   NativeImportPartCapacity
            JP   NC,NativeImportCapacity
            PUSH AF
            LD   A,(NativeImportCandidateLength)
            LD   C,A
            LD   B,0
            LD   HL,(NativeImportNamePoolEnd)
            PUSH HL
            ADD  HL,BC
            JR   C,NativeImportAppendOverflow
            LD   DE,NativeImportNamePoolLimit
            OR   A
            SBC  HL,DE
            JR   C,NativeImportAppendRoom
            JR   Z,NativeImportAppendRoom
NativeImportAppendOverflow:
            POP  HL
            POP  AF
            JP   NativeImportCapacity
NativeImportAppendRoom:
            ADD  HL,DE
            LD   (NativeImportNamePoolEnd),HL
            POP  DE
            POP  AF
            PUSH AF
            PUSH DE
            LD   L,A
            LD   H,0
            ADD  HL,HL
            LD   BC,NativeImportPartPointers
            ADD  HL,BC
            LD   (HL),E
            INC  HL
            LD   (HL),D
            POP  DE
            LD   HL,NativeImportCandidate
            LD   A,(NativeImportCandidateLength)
            LD   C,A
            LD   B,0
            PUSH BC
            LDIR
            POP  BC
            POP  AF
            PUSH AF
            LD   E,A
            LD   D,0
            LD   HL,NativeImportPartLengths
            ADD  HL,DE
            LD   (HL),C
            LD   HL,NativeImportPartStates
            ADD  HL,DE
            LD   (HL),NativeImportStateNew
            LD   HL,NativeImportPartCount
            INC  (HL)
            POP  AF
            OR   A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry
NativeImportCapacity:
            LD   A,NSTATCAP
            SCF
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry
NativeImportInvalid:
            LD   A,NSTATINV
            SCF
            RET

; Open part A for sequential scanning and reset the byte-refill state.
.routine in A out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
NativeImportOpenPart:
            CALL NativeImportPartName
            LD   A,NucleusObjectOpenRead
            CALL NativeSourceProviderOpen
            RET  C
            LD   (NativeImportSourceHandle),HL
            XOR  A
            LD   (NativeImportSourceOffset),A
            LD   (NativeImportSourceOffset+1),A
NativeImportResetReadBuffer:
            LD   HL,NativeImportReadBuffer
            LD   (NativeImportReadCursor),HL
            LD   (NativeImportReadEnd),HL
            RET

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
NativeImportCloseSource:
            LD   HL,(NativeImportSourceHandle)
            LD   A,H
            OR   L
            RET  Z
            LD   A,NucleusObjectClose
            CALL NativeSourceProviderTerminal
            RET  C
            XOR  A
            LD   (NativeImportSourceHandle),A
            LD   (NativeImportSourceHandle+1),A
            RET

; Return one source byte in A. Carry reports storage failure; Z reports EOF.
; A returned byte always has Z clear, including a zero byte. Parser
; accumulators remain live across a refill.
.routine out A,carry,zero clobbers sign,parity,halfCarry
NativeImportReadByte:
            PUSH BC
            PUSH DE
            PUSH HL
            CALL NativeImportReadByteBody
            POP  HL
            POP  DE
            POP  BC
            RET
.routine out A,B,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
NativeImportReadByteBody:
            LD   HL,(NativeImportReadCursor)
            LD   DE,(NativeImportReadEnd)
            OR   A
            SBC  HL,DE
            JR   Z,NativeImportRefill
            ADD  HL,DE
NativeImportReadBuffered:
            LD   A,(HL)
            LD   (NativeImportSavedStatus),A
            INC  HL
            LD   (NativeImportReadCursor),HL
            LD   HL,(NativeImportSourceOffset)
            INC  HL
            LD   (NativeImportSourceOffset),HL
            LD   A,H
            OR   L
            JP   Z,NativeImportCapacity
            LD   A,(NativeImportSavedStatus)
            LD   B,0
            DEC  B
            OR   A                       ; clear carry; zero fixed below
            LD   B,0
            DEC  B                       ; force NZ without changing A
            RET
NativeImportRefill:
            LD   HL,(NativeImportSourceHandle)
            LD   DE,NativeImportReadBuffer
            LD   BC,NativeImportReadBufferLimit-NativeImportReadBuffer
            CALL NativeSourceProviderRead
            RET  C
            LD   A,B
            OR   C
            JR   Z,NativeImportReadEof
            LD   HL,NativeImportReadBuffer
            LD   (NativeImportReadCursor),HL
            ADD  HL,BC
            LD   (NativeImportReadEnd),HL
            LD   HL,NativeImportReadBuffer
            JR   NativeImportReadBuffered
NativeImportReadEof:
            XOR  A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry
NativeImportReadRequired:
            CALL NativeImportReadByte
            RET  C
            RET  NZ
            JP   NativeImportInvalid

; Visit part A in depth-first postorder.
.routine in A out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
NativeImportVisitPart:
            LD   (NativeImportCurrentPart),A
            CALL NativeImportPartState
            LD   A,(HL)
            CP   NativeImportStateDone
            JR   Z,NativeImportVisitAlreadyDone
            CP   NativeImportStateVisiting
            JR   Z,NativeImportVisitCycle
            LD   (HL),NativeImportStateVisiting
            LD   A,(NativeImportCurrentPart)
            CALL NativeImportOpenPart
            RET  C
            LD   A,1
            LD   (NativeImportHeaderActive),A
            CALL NativeImportScanSource
            JR   C,NativeImportVisitScanFailed
            CALL NativeImportCloseSource
            RET  C
            LD   A,(NativeImportCurrentPart)
            CALL NativeImportPartState
            LD   (HL),NativeImportStateDone
            LD   A,(NativeImportCurrentPart)
            CALL NativeImportEmitPartRecord
            RET
NativeImportVisitAlreadyDone:
            OR   A
            RET
NativeImportVisitCycle:
            JP   NativeImportInvalid
NativeImportVisitScanFailed:
            LD   (NativeImportSavedStatus),A
            CALL NativeImportCloseSource
            LD   A,(NativeImportSavedStatus)
            SCF
            RET

; Scan leading headers and reject every later //% line.
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
NativeImportScanSource:
NativeImportScanLine:
            CALL NativeImportReadByte
            RET  C
            RET  Z
NativeImportScanLeadingSpace:
            CP   ' '
            JR   Z,NativeImportScanMoreSpace
            CP   9
            JR   Z,NativeImportScanMoreSpace
            CP   10
            JR   Z,NativeImportScanLine
            CP   13
            JR   Z,NativeImportScanBlankCr
            CP   '/'
            JR   NZ,NativeImportScanSourceLine
            CALL NativeImportReadByte
            RET  C
            RET  Z
            CP   '/'
            JR   NZ,NativeImportScanSourceLine
            CALL NativeImportReadByte
            RET  C
            RET  Z
            CP   '%'
            JR   Z,NativeImportScanDirective
            CALL NativeImportSkipLine
            RET  C
            JR   NativeImportScanLine
NativeImportScanMoreSpace:
            CALL NativeImportReadByte
            RET  C
            RET  Z
            JR   NativeImportScanLeadingSpace
NativeImportScanBlankCr:
            CALL NativeImportReadRequired
            RET  C
            CP   10
            JP   NZ,NativeImportInvalid
            JR   NativeImportScanLine
NativeImportScanSourceLine:
            XOR  A
            LD   (NativeImportHeaderActive),A
            CALL NativeImportSkipLine
            RET  C
            JR   NativeImportScanLine
NativeImportScanDirective:
            LD   A,(NativeImportHeaderActive)
            OR   A
            JP   Z,NativeImportInvalid
            CALL NativeImportParseDirective
            RET  C
            JR   NativeImportScanLine

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
NativeImportSkipLine:
            CALL NativeImportReadByte
            RET  C
            RET  Z
            CP   10
            RET  Z
            JR   NativeImportSkipLine

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
NativeImportParseDirective:
            CALL NativeImportReadRequired
            RET  C
            CP   ' '
            JR   Z,NativeImportDirectiveSpace
            CP   9
            JP   NZ,NativeImportInvalid
NativeImportDirectiveSpace:
            CALL NativeImportReadRequired
            RET  C
            CP   ' '
            JR   Z,NativeImportDirectiveSpace
            CP   9
            JR   Z,NativeImportDirectiveSpace
            CP   'i'
            JP   NZ,NativeImportInvalid
            CALL NativeImportReadRequired
            RET  C
            CP   'm'
            JP   NZ,NativeImportInvalid
            CALL NativeImportReadRequired
            RET  C
            CP   'p'
            JP   NZ,NativeImportInvalid
            CALL NativeImportReadRequired
            RET  C
            CP   'o'
            JP   NZ,NativeImportInvalid
            CALL NativeImportReadRequired
            RET  C
            CP   'r'
            JP   NZ,NativeImportInvalid
            CALL NativeImportReadRequired
            RET  C
            CP   't'
            JP   NZ,NativeImportInvalid
            CALL NativeImportReadRequired
            RET  C
            CP   ' '
            JR   Z,NativeImportAfterKeywordSpace
            CP   9
            JP   NZ,NativeImportInvalid
NativeImportAfterKeywordSpace:
            CALL NativeImportReadRequired
            RET  C
            CP   ' '
            JR   Z,NativeImportAfterKeywordSpace
            CP   9
            JR   Z,NativeImportAfterKeywordSpace
            CP   '"'
            JP   NZ,NativeImportInvalid
            LD   DE,NativeImportRawPath
            LD   C,0
NativeImportPathByte:
            CALL NativeImportReadRequired
            RET  C
            CP   '"'
            JR   Z,NativeImportPathDone
            CP   '/'
            JR   NZ,NativeImportPathNotAbsolute
            LD   B,A
            LD   A,C
            OR   A
            JP   Z,NativeImportInvalid
            LD   A,B
NativeImportPathNotAbsolute:
            CP   $20
            JP   C,NativeImportInvalid
            CP   $7F
            JP   NC,NativeImportInvalid
            CP   '\\'
            JP   Z,NativeImportInvalid
            LD   (DE),A
            INC  DE
            INC  C
            JP   Z,NativeImportCapacity
            JR   NativeImportPathByte
NativeImportPathDone:
            LD   A,C
            OR   A
            JP   Z,NativeImportInvalid
            LD   A,C
            LD   (NativeImportRawLength),A
NativeImportDirectiveTail:
            CALL NativeImportReadByte
            RET  C
            JR   Z,NativeImportDirectiveReady
            CP   ' '
            JR   Z,NativeImportDirectiveTail
            CP   9
            JR   Z,NativeImportDirectiveTail
            CP   10
            JR   Z,NativeImportDirectiveReady
            CP   13
            JP   NZ,NativeImportInvalid
            CALL NativeImportReadRequired
            RET  C
            CP   10
            JP   NZ,NativeImportInvalid
NativeImportDirectiveReady:
            JP   NativeImportResolveRaw

; Resolve RawPath relative to CurrentPart, falling back to @nucleus/RawPath.
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
NativeImportResolveRaw:
            CALL NativeImportBuildLocalPath
            RET  C
            CALL NativeImportProbeCandidate
            JR   NC,NativeImportCandidateResolved
            CP   NucleusStatusNotFound
            RET  NZ
            CALL NativeImportBuildStandardPath
            RET  C
            CALL NativeImportProbeCandidate
            RET  C
NativeImportCandidateResolved:
            CALL NativeImportFindOrAddCandidate
            RET  C
            LD   (NativeImportChildPart),A
            CALL NativeImportSaveResume
            RET  C
            CALL NativeImportCloseSource
            JR   C,NativeImportResolveRawRestore
            LD   A,(NativeImportChildPart)
            CALL NativeImportVisitPart
            JR   C,NativeImportResolveRawRestore
            XOR  A
            LD   (NativeImportSavedStatus),A
NativeImportResolveRawRestore:
            JR   NC,NativeImportResolveRawRestoreSaved
            LD   (NativeImportSavedStatus),A
NativeImportResolveRawRestoreSaved:
            CALL NativeImportRestoreResume
            LD   A,(NativeImportSavedStatus)
            OR   A
            JR   NZ,NativeImportResolveRawRestoredFail
            LD   HL,(NativeImportSourceOffset)
            LD   (NativeImportPathBuildLength),HL
            LD   A,(NativeImportCurrentPart)
            CALL NativeImportOpenPart
            RET  C
            LD   DE,(NativeImportPathBuildLength)
            LD   (NativeImportSourceOffset),DE
            LD   HL,(NativeImportSourceHandle)
            CALL NativeSourceProviderSeek
            RET  C
            JP   NativeImportResetReadBuffer
NativeImportResolveRawRestoredFail:
            LD   A,(NativeImportSavedStatus)
            SCF
            RET

; Save and restore the parent part and source offset around one recursive
; dependency visit. The bounded arrays replace an unprovable hardware-stack
; convention and make the eight-part depth limit explicit.
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
NativeImportSaveResume:
            LD   A,(NativeImportResumeDepth)
            CP   NativeImportPartCapacity
            JP   NC,NativeImportCapacity
            LD   E,A
            LD   D,0
            LD   HL,NativeImportResumeParts
            ADD  HL,DE
            LD   A,(NativeImportCurrentPart)
            LD   (HL),A
            LD   A,(NativeImportResumeDepth)
            LD   E,A
            LD   D,0
            LD   HL,NativeImportResumeHeaders
            ADD  HL,DE
            LD   A,(NativeImportHeaderActive)
            LD   (HL),A
            LD   HL,NativeImportResumeOffsets
            ADD  HL,DE
            ADD  HL,DE
            LD   (NativeImportCurrentNamePointer),HL
            LD   DE,(NativeImportSourceOffset)
            LD   HL,(NativeImportCurrentNamePointer)
            LD   (HL),E
            INC  HL
            LD   (HL),D
            LD   HL,NativeImportResumeDepth
            INC  (HL)
            OR   A
            RET

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
NativeImportRestoreResume:
            LD   HL,NativeImportResumeDepth
            DEC  (HL)
            LD   A,(HL)
            LD   E,A
            LD   D,0
            LD   HL,NativeImportResumeParts
            ADD  HL,DE
            LD   A,(HL)
            LD   (NativeImportCurrentPart),A
            LD   HL,NativeImportResumeHeaders
            ADD  HL,DE
            LD   A,(HL)
            LD   (NativeImportHeaderActive),A
            LD   HL,NativeImportResumeOffsets
            ADD  HL,DE
            ADD  HL,DE
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            EX   DE,HL
            LD   (NativeImportSourceOffset),HL
            RET

; Probe Candidate as a readable object without retaining the handle.
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
NativeImportProbeCandidate:
            LD   HL,NativeImportCandidate
            LD   A,(NativeImportCandidateLength)
            LD   B,A
            LD   A,NucleusObjectOpenRead
            CALL NativeSourceProviderOpen
            RET  C
            LD   A,NucleusObjectClose
            JP   NativeSourceProviderTerminal

; Build dirname(CurrentPart)+RawPath in PathBuild, then normalize it.
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
NativeImportBuildLocalPath:
            LD   A,(NativeImportCurrentPart)
            CALL NativeImportPartName
            LD   (NativeImportCurrentNamePointer),HL
            LD   C,B
            LD   A,B
            OR   A
            JR   Z,NativeImportBuildLocalNoDirectory
            LD   E,0
            XOR  A
            LD   (NativeImportComponentLength),A
NativeImportFindLastSlash:
            LD   A,(HL)
            INC  E
            CP   '/'
            JR   NZ,NativeImportNotSlash
            LD   A,E
            LD   (NativeImportComponentLength),A
NativeImportNotSlash:
            INC  HL
            DEC  C
            JR   NZ,NativeImportFindLastSlash
            LD   A,(NativeImportComponentLength)
            OR   A
            JR   Z,NativeImportBuildLocalNoDirectory
            LD   C,A
            LD   B,0
            LD   HL,(NativeImportCurrentNamePointer)
            LD   DE,NativeImportPathBuild
            LDIR
            JR   NativeImportAppendRaw
NativeImportBuildLocalNoDirectory:
            LD   DE,NativeImportPathBuild
NativeImportAppendRaw:
            LD   HL,NativeImportRawPath
            LD   A,(NativeImportRawLength)
            LD   C,A
            LD   B,0
            LDIR
            LD   HL,NativeImportPathBuild
            EX   DE,HL
            OR   A
            SBC  HL,DE
            LD   (NativeImportPathBuildLength),HL
            CALL NativeImportNormalizeBuild
            RET

; Build @nucleus/RawPath and normalize it inside the standard-library root.
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
NativeImportBuildStandardPath:
            LD   HL,NativeImportStandardPrefix
            LD   DE,NativeImportPathBuild
            LD   BC,NativeImportStandardPrefixLength
            LDIR
            LD   HL,NativeImportRawPath
            LD   A,(NativeImportRawLength)
            LD   C,A
            LD   B,0
            LDIR
            LD   HL,NativeImportPathBuild
            EX   DE,HL
            OR   A
            SBC  HL,DE
            LD   (NativeImportPathBuildLength),HL
            CALL NativeImportNormalizeBuild
            RET

; Normalize PathBuild into Candidate. Repeated separators and '.' collapse;
; '..' pops one component but may not escape the project or @nucleus/ root.
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
NativeImportNormalizeBuild:
            LD   HL,NativeImportPathBuild
            LD   BC,(NativeImportPathBuildLength)
            LD   A,B
            OR   C
            JP   Z,NativeImportInvalid
            ADD  HL,BC
            LD   (NativeImportNormalizeEnd),HL
            LD   HL,NativeImportPathBuild
            LD   A,(HL)
            CP   '/'
            JP   Z,NativeImportInvalid
            LD   A,B
            OR   A
            JR   NZ,NativeImportTryStandardPrefix
            LD   A,C
            CP   NativeImportStandardPrefixLength
            JR   C,NativeImportProjectFloor
NativeImportTryStandardPrefix:
            LD   DE,NativeImportStandardPrefix
            LD   C,NativeImportStandardPrefixLength
NativeImportPrefixCompare:
            LD   A,(DE)
            CP   (HL)
            JR   NZ,NativeImportProjectFloor
            INC  DE
            INC  HL
            DEC  C
            JR   NZ,NativeImportPrefixCompare
            LD   HL,NativeImportStandardPrefix
            LD   DE,NativeImportCandidate
            LD   BC,NativeImportStandardPrefixLength
            LDIR
            LD   (NativeImportNormalizeFloor),DE
            LD   HL,NativeImportPathBuild+NativeImportStandardPrefixLength
            JR   NativeImportNormalizeComponent
NativeImportProjectFloor:
            LD   HL,NativeImportPathBuild
            LD   DE,NativeImportCandidate
            LD   (NativeImportNormalizeFloor),DE

NativeImportNormalizeComponent:
            LD   BC,(NativeImportNormalizeEnd)
            LD   A,H
            CP   B
            JR   NZ,NativeImportNormalizeSkipSlash
            LD   A,L
            CP   C
            JP   Z,NativeImportNormalizeDone
NativeImportNormalizeSkipSlash:
            LD   A,(HL)
            CP   '/'
            JR   NZ,NativeImportNormalizeComponentStart
            INC  HL
            JP   NativeImportNormalizeComponent
NativeImportNormalizeComponentStart:
            LD   (NativeImportComponentStart),HL
            LD   C,0
NativeImportNormalizeMeasure:
            LD   A,H
            LD   B,A
            LD   A,(NativeImportNormalizeEnd+1)
            CP   B
            JR   NZ,NativeImportNormalizeMeasureByte
            LD   A,L
            LD   B,A
            LD   A,(NativeImportNormalizeEnd)
            CP   B
            JR   Z,NativeImportNormalizeMeasured
NativeImportNormalizeMeasureByte:
            LD   A,(HL)
            CP   '/'
            JR   Z,NativeImportNormalizeMeasured
            INC  HL
            INC  C
            JP   Z,NativeImportCapacity
            JR   NativeImportNormalizeMeasure
NativeImportNormalizeMeasured:
            LD   A,C
            LD   (NativeImportComponentLength),A
            LD   HL,(NativeImportComponentStart)
            LD   A,C
            CP   1
            JR   NZ,NativeImportNormalizeCheckDotDot
            LD   A,(HL)
            CP   '.'
            JR   Z,NativeImportNormalizeAdvance
NativeImportNormalizeCheckDotDot:
            LD   A,C
            CP   2
            JR   NZ,NativeImportNormalizeCopy
            LD   A,(HL)
            CP   '.'
            JR   NZ,NativeImportNormalizeCopy
            INC  HL
            LD   A,(HL)
            DEC  HL
            CP   '.'
            JR   NZ,NativeImportNormalizeCopy
            CALL NativeImportNormalizePop
            RET  C
            LD   HL,(NativeImportComponentStart)
            JR   NativeImportNormalizeAdvance
NativeImportNormalizeCopy:
            LD   A,C
            OR   A
            JR   Z,NativeImportNormalizeAdvance
            CALL NativeImportNormalizeAddSlash
            RET  C
            LD   HL,(NativeImportComponentStart)
            LD   A,(NativeImportComponentLength)
            LD   C,A
NativeImportNormalizeCopyLoop:
            LD   A,(HL)
            CP   $20
            JP   C,NativeImportInvalid
            CP   $7F
            JP   NC,NativeImportInvalid
            CP   '\\'
            JP   Z,NativeImportInvalid
            LD   (DE),A
            INC  DE
            INC  HL
            LD   A,D
            CP   NativeImportCandidateLimit>>8
            JR   NZ,NativeImportNormalizeCopyRoom
            LD   A,E
            CP   NativeImportCandidateLimit&$FF
            JP   Z,NativeImportCapacity
NativeImportNormalizeCopyRoom:
            DEC  C
            JR   NZ,NativeImportNormalizeCopyLoop
            JP   NativeImportNormalizeComponent
NativeImportNormalizeAdvance:
            LD   HL,(NativeImportComponentStart)
            LD   A,(NativeImportComponentLength)
            LD   C,A
            LD   B,0
            ADD  HL,BC
            JP   NativeImportNormalizeComponent
NativeImportNormalizeDone:
            LD   HL,NativeImportCandidate
            EX   DE,HL
            OR   A
            SBC  HL,DE
            LD   A,H
            OR   A
            JP   NZ,NativeImportCapacity
            LD   A,L
            OR   A
            JP   Z,NativeImportInvalid
            LD   (NativeImportCandidateLength),A
            OR   A
            RET

; Add one separator unless Candidate is empty or already ends with '/'.
.routine in DE out A,DE,HL,carry,zero clobbers sign,parity,halfCarry
NativeImportNormalizeAddSlash:
            LD   HL,NativeImportCandidate
            OR   A
            SBC  HL,DE
            RET  Z
            ADD  HL,DE
            DEC  DE
            LD   A,(DE)
            INC  DE
            CP   '/'
            RET  Z
            LD   A,D
            CP   NativeImportCandidateLimit>>8
            JR   NZ,NativeImportNormalizeSlashRoom
            LD   A,E
            CP   NativeImportCandidateLimit&$FF
            JR   NZ,NativeImportNormalizeSlashRoom
            LD   A,NSTATCAP
            SCF
            RET
NativeImportNormalizeSlashRoom:
            LD   A,'/'
            LD   (DE),A
            INC  DE
            OR   A
            RET

; Pop the preceding normalized component, respecting the domain floor.
.routine in DE out A,DE,HL,carry,zero clobbers sign,parity,halfCarry
NativeImportNormalizePop:
            LD   HL,(NativeImportNormalizeFloor)
            OR   A
            SBC  HL,DE
            JR   NZ,NativeImportNormalizePopReady
            LD   A,NSTATINV
            SCF
            RET
NativeImportNormalizePopReady:
            ADD  HL,DE
NativeImportNormalizePopLoop:
            DEC  DE
            LD   HL,(NativeImportNormalizeFloor)
            OR   A
            SBC  HL,DE
            JR   Z,NativeImportNormalizePopFloor
            ADD  HL,DE
            LD   A,(DE)
            CP   '/'
            JR   NZ,NativeImportNormalizePopLoop
            RET
NativeImportNormalizePopFloor:
            LD   DE,(NativeImportNormalizeFloor)
            OR   A
            RET

; Append the completed part to SP1 in postorder: P 0 <length> <name> LF.
.routine in A out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
NativeImportEmitPartRecord:
            LD   (NativeImportCurrentPart),A
            LD   A,'P'
            LD   (NativeImportDecimalScratch),A
            LD   A,' '
            LD   (NativeImportDecimalScratch+1),A
            LD   A,'0'
            LD   (NativeImportDecimalScratch+2),A
            LD   A,' '
            LD   (NativeImportDecimalScratch+3),A
            LD   DE,NativeImportDecimalScratch
            LD   BC,4
            CALL NativeImportWritePlan
            RET  C
            LD   A,(NativeImportCurrentPart)
            CALL NativeImportPartName
            LD   A,B
            CALL NativeImportWriteDecimalByte
            RET  C
            LD   A,' '
            LD   (NativeImportDecimalScratch),A
            LD   DE,NativeImportDecimalScratch
            LD   BC,1
            CALL NativeImportWritePlan
            RET  C
            LD   A,(NativeImportCurrentPart)
            CALL NativeImportPartName
            LD   D,H
            LD   E,L
            LD   C,B
            LD   B,0
            CALL NativeImportWritePlan
            RET  C
            LD   A,10
            LD   (NativeImportDecimalScratch),A
            LD   DE,NativeImportDecimalScratch
            LD   BC,1
            JP   NativeImportWritePlan

; Write unsigned A as one to three canonical decimal bytes.
.routine in A out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
NativeImportWriteDecimalByte:
            LD   B,0
NativeImportDecimalHundreds:
            CP   100
            JR   C,NativeImportDecimalTensStart
            SUB  100
            INC  B
            JR   NativeImportDecimalHundreds
NativeImportDecimalTensStart:
            LD   C,0
NativeImportDecimalTens:
            CP   10
            JR   C,NativeImportDecimalDigits
            SUB  10
            INC  C
            JR   NativeImportDecimalTens
NativeImportDecimalDigits:
            LD   E,A
            LD   HL,NativeImportDecimalScratch
            LD   D,0
            LD   A,B
            OR   A
            JR   Z,NativeImportDecimalNoHundreds
            ADD  A,'0'
            LD   (HL),A
            INC  HL
            INC  D
NativeImportDecimalNoHundreds:
            LD   A,C
            OR   B
            JR   Z,NativeImportDecimalNoTens
            LD   A,C
            ADD  A,'0'
            LD   (HL),A
            INC  HL
            INC  D
NativeImportDecimalNoTens:
            LD   A,E
            ADD  A,'0'
            LD   (HL),A
            INC  D
            LD   A,D
            LD   (NativeImportComponentLength),A
            LD   DE,NativeImportDecimalScratch
            LD   A,(NativeImportComponentLength)
            LD   C,A
            LD   B,0
            JP   NativeImportWritePlan

NativeImportResolverEnd:
