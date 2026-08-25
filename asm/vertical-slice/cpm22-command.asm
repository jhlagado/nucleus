; CP/M command-tail parser and source preflight for native Nucleus. Accepted
; forms are no arguments, SOURCE OUTPUT.COM, and SOURCE-PLAN OUTPUT.COM @.

CpmCommandLength          .equ $0080
CpmCommandStart           .equ $0081
CpmCommandDefaultFcb1     .equ $005C
CpmCommandDefaultFcb2     .equ $006C
CpmCommandPlanDma         .equ $0080
CpmCommandReadFunction    .equ 20
CpmCommandOpenFunction    .equ 15
CpmCommandDmaFunction     .equ 26

CpmCommandWorkspaceBase   .equ CpmSourceWorkspaceEnd
CpmCommandPlanFcb         .equ CpmCommandWorkspaceBase
CpmCommandPlanPointer     .equ CpmCommandPlanFcb+36
CpmCommandPlanRemaining   .equ CpmCommandPlanPointer+2
CpmCommandPlanLineEnd     .equ CpmCommandPlanRemaining+1
CpmCommandDescriptor      .equ CpmCommandPlanLineEnd+1
CpmCommandLaunchResult    .equ CpmCommandDescriptor+2
CpmCompilerOutputName     .equ CpmCommandLaunchResult+9
CpmCommandWorkspaceEnd    .equ CpmCompilerOutputName+12

CpmCommandCodeStart:
.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CpmCommandPrepare:
            LD   HL,CpmCommandDefaultInput
            XOR  A
            CALL CpmCommandCopyNamePair
            LD   A,1
            LD   (CpmSourcePartCount),A
            LD   A,(CpmCommandLength)
            LD   B,A
            LD   HL,CpmCommandStart
            CALL CpmCommandSkipSpaces
            JR   Z,CpmCommandNamesReady
            CALL CpmCommandParseFilename
            JR   C,CpmCommandPrepareInvalid
            CALL CpmCommandSkipSpaces
            JR   Z,CpmCommandPrepareInvalid
            CALL CpmCommandParseFilename
            JR   C,CpmCommandPrepareInvalid
            CALL CpmCommandSkipSpaces
            JR   Z,CpmCommandCopyNames
            CP   '@'
            JR   NZ,CpmCommandPrepareInvalid
            INC  HL
            DEC  B
            CALL CpmCommandSkipSpaces
            JR   NZ,CpmCommandPrepareInvalid
            XOR  A
            LD   (CpmSourcePartCount),A
CpmCommandCopyNames:
            LD   HL,CpmCommandDefaultFcb1
            LD   A,4
            CALL CpmCommandCopyNamePair
CpmCommandNamesReady:
            LD   HL,CpmCompilerOutputName+9
            LD   DE,CpmCommandComExtension
            LD   B,3
CpmCommandOutputTypeLoop:
            LD   A,(DE)
            CP   (HL)
            JR   NZ,CpmCommandPrepareInvalid
            INC  DE
            INC  HL
            DJNZ CpmCommandOutputTypeLoop
            LD   HL,CpmSourcePartDescriptors
            LD   DE,CpmCompilerOutputName
            CALL CpmCommandNamesEqual
            JP   Z,CpmCommandConflict
            LD   A,(CpmSourcePartCount)
            OR   A
            JP   Z,CpmCommandLoadPlan
            LD   HL,CpmSourcePartDescriptors
            CALL CpmCommandScanSource
            RET  C
            XOR  A
            RET
CpmCommandPrepareInvalid:
            JP   CpmCommandInvalid

; Parse the complete one-name-per-line plan directly into the eight external
; source descriptors and preflight every source before compilation begins.
.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CpmCommandLoadPlan:
            LD   HL,CpmSourcePartDescriptors
            LD   (CpmCommandDescriptor),HL
            LD   DE,CpmCommandPlanFcb
            CALL CpmBuildFcb
            LD   DE,CpmCommandPlanFcb
            LD   C,CpmCommandOpenFunction
            CALL CpmCallBdos
            INC  A
            JP   Z,CpmCommandNotFound
            XOR  A
            LD   (CpmCommandPlanRemaining),A
CpmCommandPlanLoop:
            CALL CpmCommandPlanByte
            JR   NC,CpmCommandPlanHaveByte
            OR   A
            JP   NZ,CpmCommandStorage
            LD   A,(CpmSourcePartCount)
            OR   A
            JP   Z,CpmCommandInvalid
            XOR  A
            RET
CpmCommandPlanHaveByte:
            LD   C,A
            LD   A,(CpmSourcePartCount)
            CP   SourcePartCapacity
            JP   Z,CpmCommandCapacity
            LD   HL,(CpmCommandDescriptor)
            LD   A,C
            CALL CpmCommandParsePlanName
            RET  C
            LD   (CpmCommandPlanLineEnd),A
            LD   HL,(CpmCommandDescriptor)
            LD   DE,CpmCompilerOutputName
            CALL CpmCommandNamesEqual
            JP   Z,CpmCommandConflict
            LD   HL,(CpmCommandDescriptor)
            CALL CpmCommandScanSource
            RET  C
            LD   HL,(CpmCommandDescriptor)
            INC  HL
            INC  HL
            LD   (CpmCommandDescriptor),HL
            LD   HL,CpmSourcePartCount
            INC  (HL)
            LD   A,(CpmCommandPlanLineEnd)
            OR   A
            JR   Z,CpmCommandPlanLoop
            XOR  A
            RET

; Read one selected source sequentially to establish its exact logical length.
; Text EOF terminates a part; byte 65,536 fails before descriptor publication.
.routine in HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CpmCommandScanSource:
            LD   DE,CpmSourceStreamFcb
            CALL CpmBuildFcb
            LD   (CpmCommandDescriptor),HL
            LD   DE,CpmSourceStreamFcb
            LD   C,CpmCommandOpenFunction
            CALL CpmCallBdos
            INC  A
            JR   Z,CpmCommandNotFound
            LD   DE,NativeSourceChunkBase
            LD   C,CpmCommandDmaFunction
            CALL CpmCallBdos
            LD   HL,0
CpmCommandSourceRecord:
            PUSH HL
            LD   DE,CpmSourceStreamFcb
            LD   C,CpmCommandReadFunction
            CALL CpmCallBdos
            POP  HL
            OR   A
            JR   Z,CpmCommandSourceScan
            DEC  A
            JR   NZ,CpmCommandStorage
            JR   CpmCommandSourceDone
CpmCommandSourceScan:
            LD   B,128
            LD   DE,NativeSourceChunkBase
CpmCommandSourceByte:
            LD   A,(DE)
            CP   $1A
            JR   Z,CpmCommandSourceDone
            INC  DE
            INC  HL
            LD   A,H
            OR   L
            JR   Z,CpmCommandCapacity
            DJNZ CpmCommandSourceByte
            JR   CpmCommandSourceRecord
CpmCommandSourceDone:
            EX   DE,HL
            LD   HL,(CpmCommandDescriptor)
            LD   (HL),E
            INC  HL
            LD   (HL),D
            XOR  A
            RET

; Return one plan byte. Carry with A=0 is physical/text EOF; carry with A=6 is
; a disk error. Page-zero DMA stays live while source scans use the chunk DMA.
.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CpmCommandPlanByte:
            LD   A,(CpmCommandPlanRemaining)
            OR   A
            JR   NZ,CpmCommandPlanCached
            LD   DE,CpmCommandPlanDma
            LD   C,CpmCommandDmaFunction
            CALL CpmCallBdos
            LD   DE,CpmCommandPlanFcb
            LD   C,CpmCommandReadFunction
            CALL CpmCallBdos
            OR   A
            JR   Z,CpmCommandPlanRecord
            DEC  A
            JR   Z,CpmCommandPlanEof
            JR   CpmCommandStorage
CpmCommandPlanRecord:
            LD   HL,CpmCommandPlanDma
            LD   (CpmCommandPlanPointer),HL
            LD   A,128
            LD   (CpmCommandPlanRemaining),A
CpmCommandPlanCached:
            LD   HL,(CpmCommandPlanPointer)
            LD   A,(HL)
            INC  HL
            LD   (CpmCommandPlanPointer),HL
            LD   HL,CpmCommandPlanRemaining
            DEC  (HL)
            CP   $1A
            JR   Z,CpmCommandPlanEof
            OR   A
            RET
CpmCommandPlanEof:
            XOR  A
            SCF
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry
CpmCommandNotFound:
            LD   A,NucleusStatusNotFound
            SCF
            RET
.routine out A,carry,zero clobbers sign,parity,halfCarry
CpmCommandCapacity:
            LD   A,NucleusStatusCapacity
            SCF
            RET
.routine out A,carry,zero clobbers sign,parity,halfCarry
CpmCommandStorage:
            LD   A,NucleusStatusStorage
            SCF
            RET

; A is the first name byte and HL the destination descriptor. Accept LF,
; CRLF, physical EOF, or text EOF after one valid current-drive 8.3 name.
.routine in A,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CpmCommandParsePlanName:
            LD   C,A
            LD   D,H
            LD   E,L
            XOR  A
            LD   (DE),A
            INC  DE
            LD   B,11
            LD   A,' '
CpmCommandClearPlanName:
            LD   (DE),A
            INC  DE
            DJNZ CpmCommandClearPlanName
            INC  HL
            LD   A,C
            LD   D,8
            LD   C,0
CpmCommandPlanNameByte:
            CP   13
            JR   Z,CpmCommandPlanNameCr
            CP   10
            JR   Z,CpmCommandPlanNameEol
            CP   '.'
            JR   NZ,CpmCommandPlanNameData
            LD   A,D
            CP   8
            JR   NZ,CpmCommandInvalid
            LD   A,C
            OR   A
            JR   Z,CpmCommandInvalid
            LD   HL,(CpmCommandDescriptor)
            LD   DE,9
            ADD  HL,DE
            LD   D,3
            LD   C,0
            JR   CpmCommandPlanNameNext
CpmCommandPlanNameData:
            CP   'a'
            JR   C,CpmCommandPlanNameCheck
            CP   'z'+1
            JR   NC,CpmCommandPlanNameCheck
            AND  $DF
CpmCommandPlanNameCheck:
            CALL CpmCommandFilenameChar
            JR   C,CpmCommandInvalid
            INC  C
            LD   B,A
            LD   A,D
            CP   C
            JR   C,CpmCommandInvalid
            LD   A,B
            LD   (HL),A
            INC  HL
CpmCommandPlanNameNext:
            PUSH HL
            CALL CpmCommandPlanByte
            POP  HL
            JR   NC,CpmCommandPlanNameByte
            OR   A
            JR   NZ,CpmCommandStorage
            LD   A,C
            OR   A
            JR   Z,CpmCommandInvalid
            LD   A,1
            RET
CpmCommandPlanNameCr:
            CALL CpmCommandPlanByte
            JR   NC,CpmCommandPlanNameCrByte
            OR   A
            JR   NZ,CpmCommandStorage
            JR   CpmCommandInvalid
CpmCommandPlanNameCrByte:
            CP   10
            JR   NZ,CpmCommandInvalid
CpmCommandPlanNameEol:
            LD   A,C
            OR   A
            JR   Z,CpmCommandInvalid
            XOR  A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry
CpmCommandInvalid:
            LD   A,NucleusStatusInvalid
            SCF
            RET
.routine out A,carry,zero clobbers sign,parity,halfCarry
CpmCommandConflict:
            LD   A,NucleusStatusConflict
            SCF
            RET

; Raw command-tail helpers validate exact arity and current-drive 8.3 syntax.
.routine in B,HL out A,B,HL,zero clobbers carry,sign,parity,halfCarry
CpmCommandSkipSpaces:
            LD   A,B
            OR   A
            RET  Z
            LD   A,(HL)
            CP   ' '
            RET  NZ
            INC  HL
            DEC  B
            JR   CpmCommandSkipSpaces

.routine in B,HL out A,B,HL,carry clobbers zero,sign,parity,halfCarry,C,D
CpmCommandParseFilename:
            LD   D,8
            LD   C,0
CpmCommandFilenameByte:
            LD   A,B
            OR   A
            JR   Z,CpmCommandFilenameDone
            LD   A,(HL)
            CP   ' '
            JR   Z,CpmCommandFilenameDone
            CP   '.'
            JR   NZ,CpmCommandFilenameData
            LD   A,D
            CP   8
            JR   NZ,CpmCommandFilenameBad
            LD   A,C
            OR   A
            JR   Z,CpmCommandFilenameBad
            LD   D,3
            LD   C,0
            JR   CpmCommandFilenameTake
CpmCommandFilenameData:
            CALL CpmCommandFilenameChar
            RET  C
            INC  C
            LD   A,D
            CP   C
            JR   C,CpmCommandFilenameBad
CpmCommandFilenameTake:
            INC  HL
            DEC  B
            JR   CpmCommandFilenameByte
CpmCommandFilenameDone:
            LD   A,C
            OR   A
            JR   Z,CpmCommandFilenameBad
            RET
CpmCommandFilenameBad:
            SCF
            RET

.routine in A out A,carry clobbers zero,sign,parity,halfCarry
CpmCommandFilenameChar:
            CP   '!'
            RET  C
            CP   $7F
            JR   NC,CpmCommandFilenameCharBad
            CP   '*'
            JR   C,CpmCommandFilenameCharHigh
            CP   '-'
            JR   C,CpmCommandFilenameCharBad
            CP   '/'
            JR   Z,CpmCommandFilenameCharBad
            CP   ':'
            JR   C,CpmCommandFilenameCharHigh
            CP   '@'
            JR   C,CpmCommandFilenameCharBad
CpmCommandFilenameCharHigh:
            CP   '['
            JR   C,CpmCommandFilenameCharReady
            CP   '^'
            JR   C,CpmCommandFilenameCharBad
            CP   '_'
            JR   Z,CpmCommandFilenameCharBad
CpmCommandFilenameCharReady:
            OR   A
            RET
CpmCommandFilenameCharBad:
            SCF
            RET

.routine in DE,HL out A,zero clobbers carry,sign,parity,halfCarry,B,DE,HL
CpmCommandNamesEqual:
            LD   B,12
CpmCommandNameByte:
            LD   A,(DE)
            CP   (HL)
            RET  NZ
            INC  DE
            INC  HL
            DJNZ CpmCommandNameByte
            XOR  A
            RET

; Copy two twelve-byte FCB name fields separated by A bytes in the source.
.routine in A,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CpmCommandCopyNamePair:
            LD   DE,CpmSourcePartDescriptors
            LD   BC,12
            LDIR
            LD   C,A
            ADD  HL,BC
            LD   DE,CpmCompilerOutputName
            LD   BC,12
            LDIR
            RET

CpmCommandCodeEnd:

CpmCommandImmutableStart:
CpmCommandDefaultInput:  .db 0,"INPUT   ","NU "
CpmCommandDefaultOutput: .db 0,"OUTPUT  ","COM"
CpmCommandComExtension:  .db "COM"
CpmCommandImmutableEnd:
