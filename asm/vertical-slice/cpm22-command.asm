; CP/M command-tail parser and source preflight for native Nucleus. Accepted
; forms are no arguments, SOURCE, SOURCE OUTPUT, and ?.

CpmCommandLength          .equ $0080
CpmCommandStart           .equ $0081
CpmCommandDefaultFcb1     .equ $005C
CpmCommandDefaultFcb2     .equ $006C
CpmCommandReadFunction    .equ 20
CpmCommandOpenFunction    .equ 15
CpmCommandDmaFunction     .equ 26

CpmCommandWorkspaceBase   .equ CSWKEND
CpmCommandDescriptor      .equ CpmCommandWorkspaceBase
CpmCommandLaunchResult    .equ CpmCommandDescriptor+2
CpmCompilerOutputName     .equ CpmCommandLaunchResult+9
CpmCompilerOutputFormat   .equ CpmCompilerOutputName+12
CpmCommandHelpRequested   .equ CpmCompilerOutputFormat+1
CpmCommandWorkspaceEnd    .equ CpmCommandHelpRequested+1

CpmOutputFormatCom        .equ 0
CpmOutputFormatBin        .equ 1
CpmOutputFormatHex        .equ 2

CpmCommandCodeStart:
.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CpmCommandPrepare:
            XOR  A
            LD   (CpmCommandHelpRequested),A
            LD   HL,CpmCommandDefaultInput
            CALL CpmCommandCopyNamePair
            LD   A,1
            LD   (CSPARTN),A
            LD   A,(CpmCommandLength)
            LD   B,A
            LD   HL,CpmCommandStart
            CALL CpmCommandSkipSpaces
            JR   Z,CpmCommandNamesReady
            CP   '?'
            JR   NZ,CpmCommandFirstName
            INC  HL
            DEC  B
            CALL CpmCommandSkipSpaces
            JR   NZ,CpmCommandPrepareInvalid
            LD   A,1
            LD   (CpmCommandHelpRequested),A
            XOR  A
            RET
CpmCommandFirstName:
            CALL CpmCommandParseFilename
            JR   C,CpmCommandPrepareInvalid
            CALL CpmCommandSkipSpaces
            JR   Z,CpmCommandCopySingleName
            CALL CpmCommandParseFilename
            JR   C,CpmCommandPrepareInvalid
            CALL CpmCommandSkipSpaces
            JR   NZ,CpmCommandPrepareInvalid
CpmCommandCopyNames:
            LD   HL,CpmCommandDefaultFcb1
            LD   A,4
            CALL CpmCommandCopyNamePair
            JR   CpmCommandNamesReady
CpmCommandCopySingleName:
            LD   HL,CpmCommandDefaultFcb1
            LD   DE,CSDESCS
            LD   BC,12
            LDIR
            LD   HL,CSDESCS+9
            LD   A,(HL)
            CP   ' '
            JR   NZ,CpmCommandSingleExtensionReady
            LD   (HL),'N'
            INC  HL
            LD   (HL),'U'
CpmCommandSingleExtensionReady:
            LD   HL,CSDESCS
            LD   DE,CpmCompilerOutputName
            LD   BC,12
            LDIR
            LD   HL,CpmCompilerOutputName+9
            LD   (HL),'C'
            INC  HL
            LD   (HL),'O'
            INC  HL
            LD   (HL),'M'
CpmCommandNamesReady:
            CALL CpmCommandSelectOutputFormat
            JR   C,CpmCommandPrepareInvalid
            LD   HL,CSDESCS
            LD   DE,CpmCompilerOutputName
            CALL CpmCommandNamesEqual
            JP   Z,CpmCommandConflict
            LD   HL,CSDESCS
            CALL CpmCommandScanSource
            RET  C
            XOR  A
            RET
CpmCommandPrepareInvalid:
            JP   CpmCommandInvalid

; Select the materialized delivery format from the explicit output suffix.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
CpmCommandSelectOutputFormat:
            LD   DE,CpmCommandOutputExtensions
            LD   B,3
            XOR  A
CpmCommandOutputFormatLoop:
            PUSH AF
            PUSH BC
            PUSH DE
            LD   HL,CpmCompilerOutputName+9
            LD   B,3
CpmCommandOutputTypeLoop:
            LD   A,(DE)
            CP   (HL)
            JR   NZ,CpmCommandOutputTypeDifferent
            INC  DE
            INC  HL
            DJNZ CpmCommandOutputTypeLoop
            POP  DE
            POP  BC
            POP  AF
            LD   (CpmCompilerOutputFormat),A
            OR   A
            RET
CpmCommandOutputTypeDifferent:
            POP  DE
            LD   HL,3
            ADD  HL,DE
            EX   DE,HL
            POP  BC
            POP  AF
            INC  A
            DJNZ CpmCommandOutputFormatLoop
            SCF
            RET

; Read one selected source sequentially to establish its exact logical length.
; Text EOF terminates a part; byte 65,536 fails before descriptor publication.
.routine in HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CpmCommandScanSource:
            LD   DE,CSSTRFCB
            CALL FCBMAKE
            LD   (CpmCommandDescriptor),HL
            LD   DE,CSSTRFCB
            LD   C,CpmCommandOpenFunction
            CALL BDOSCALL
            INC  A
            JR   Z,CpmCommandNotFound
            LD   DE,SRCCHUNK
            LD   C,CpmCommandDmaFunction
            CALL BDOSCALL
            LD   HL,0
CpmCommandSourceRecord:
            PUSH HL
            LD   DE,CSSTRFCB
            LD   C,CpmCommandReadFunction
            CALL BDOSCALL
            POP  HL
            OR   A
            JR   Z,CpmCommandSourceScan
            DEC  A
            JR   NZ,CpmCommandStorage
            JR   CpmCommandSourceDone
CpmCommandSourceScan:
            LD   B,128
            LD   DE,SRCCHUNK
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

.routine out A,carry,zero clobbers sign,parity,halfCarry
CpmCommandNotFound:
            LD   A,NucleusStatusNotFound
            SCF
            RET
.routine out A,carry,zero clobbers sign,parity,halfCarry
CpmCommandCapacity:
            LD   A,NSTATCAP
            SCF
            RET
.routine out A,carry,zero clobbers sign,parity,halfCarry
CpmCommandStorage:
            LD   A,NSTATIO
            SCF
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry
CpmCommandInvalid:
            LD   A,NSTATINV
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
            LD   DE,CSDESCS
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
CpmCommandOutputExtensions: .db "COM","BIN","HEX"
CpmCommandImmutableEnd:
