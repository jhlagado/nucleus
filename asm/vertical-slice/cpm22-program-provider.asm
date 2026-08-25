; Runtime-vector provider embedded at the front of a generated CP/M COM file.
; CP/M starts at $0100. The prefix calls the separately compiled Nucleus image
; at $0800, and terminal vector entries return through that call to the CCP.

CpmProgramTargetEntry .equ $0800
CpmProgramBdos        .equ $0005
CpmProgramBiosConin   .equ $FA09
CpmProgramBiosConout  .equ $FA0C
CpmProgramDmaFunction .equ 26
CpmProgramOpenFunction .equ 15
CpmProgramCloseFunction .equ 16
CpmProgramMakeFunction .equ 22
CpmProgramRandomReadFunction .equ 33
CpmProgramRandomWriteFunction .equ 34
CpmProgramInputReadyFlag  .equ 1
CpmProgramOutputReadyFlag .equ 2
CpmProgramRecordCache     .equ $0080
CpmProgramRecordCacheEnd  .equ $0100

            .org $0100
CpmProgramPrefixStart:
.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CpmProgramEntry:
            CALL CpmProgramInitialize
            CALL CpmProgramTargetEntry
CpmProgramReturn:
            RET

            ; Fixed addresses let the offline runtime catalogue bind ordinary
            ; vectors and the packet gateway without runtime linking.
            .org $0107
CpmProgramServiceVector:
            JP   CpmProgramReadInput
            JP   CpmProgramWriteOutput
            JP   CpmProgramReadStorage
            JP   CpmProgramRewindStorage
            JP   CpmProgramWriteStorage
            JP   CpmProgramSeekStorage
            JP   CpmProgramSuccess
            JP   CpmProgramFailure
            JP   CpmProgramTrap
            JP   CpmProgramFarCall
            JP   CpmProgramFarJump
CpmProgramPacketVector:
            JP   CpmProgramPacket
CpmProgramServiceVectorEnd:

CpmProgramProviderCodeStart:
.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CpmProgramInitialize:
            XOR  A
            LD   HL,CpmProgramInputCursor
            LD   DE,CpmProgramInputCursor+1
            LD   BC,CpmProgramStorageState-CpmProgramInputCursor
            LD   (HL),A
            LDIR
            LD   HL,$005C
            LD   DE,CpmProgramInputFcb
            CALL CpmProgramCopyFcb
            LD   HL,$006C
            LD   DE,CpmProgramOutputFcb
            CALL CpmProgramCopyFcb
            CALL CpmProgramOpenInput
            CALL CpmProgramOpenOutput
            XOR  A
            RET

; The ideal Debug80 BIOS CONIN path blocks, returns every byte including zero,
; and performs no implicit echo. Preserve the generated-program register set.
.routine out A,carry,zero clobbers sign,parity,halfCarry
CpmProgramReadInput:
            PUSH BC
            PUSH DE
            PUSH HL
            CALL CpmProgramBiosConin
            POP  HL
            POP  DE
            POP  BC
            OR   A
            RET

.routine in A out A,carry,zero clobbers sign,parity,halfCarry
CpmProgramWriteOutput:
            PUSH BC
            PUSH DE
            PUSH HL
            LD   C,A
            CALL CpmProgramBiosConout
            POP  HL
            POP  DE
            POP  BC
            XOR  A
            RET

; CP/M does not retain a byte count for the final 128-byte record. Each selected
; Nucleus storage file therefore begins with a private little-endian u16 payload
; length. Logical offset zero follows that header. One random-record cache is
; shared because service calls are synchronous.
.routine out A,carry,zero clobbers sign,parity,halfCarry
CpmProgramReadStorage:
            PUSH BC
            PUSH DE
            PUSH HL
            PUSH IX
            CALL CpmProgramReadStorageBody
            POP  IX
            POP  HL
            POP  DE
            POP  BC
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX
CpmProgramReadStorageBody:
            LD   A,(CpmProgramStorageState)
            AND  CpmProgramInputReadyFlag
            JR   Z,CpmProgramReadStorageFailure
            LD   HL,(CpmProgramInputCursor)
            LD   DE,(CpmProgramInputLength)
            OR   A
            SBC  HL,DE
            JR   Z,CpmProgramReadStorageEof
            JR   NC,CpmProgramReadStorageFailure
            LD   HL,(CpmProgramInputCursor)
            LD   IX,CpmProgramInputFcb
            CALL CpmProgramReadLogicalRecordRaw
            OR   A
            JP   NZ,CpmProgramStorageFailure
            LD   A,(HL)
            LD   HL,(CpmProgramInputCursor)
            INC  HL
            LD   (CpmProgramInputCursor),HL
            OR   A
            RET
CpmProgramReadStorageEof:
            LD   A,1
            SCF
            RET
CpmProgramReadStorageFailure:
            JP   CpmProgramStorageFailure

.routine out A,carry,zero clobbers sign,parity,halfCarry
CpmProgramRewindStorage:
            LD   A,(CpmProgramStorageState)
            AND  CpmProgramInputReadyFlag
            JR   Z,CpmProgramRewindStorageFailure
            XOR  A
            LD   (CpmProgramInputCursor),A
            LD   (CpmProgramInputCursor+1),A
            RET
CpmProgramRewindStorageFailure:
            JP   CpmProgramStorageFailure

.routine in A out A,carry,zero clobbers sign,parity,halfCarry
CpmProgramWriteStorage:
            LD   (CpmProgramWriteValue),A
            PUSH BC
            PUSH DE
            PUSH HL
            PUSH IX
            CALL CpmProgramWriteStorageBody
            POP  IX
            POP  HL
            POP  DE
            POP  BC
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX
CpmProgramWriteStorageBody:
            LD   A,(CpmProgramStorageState)
            AND  CpmProgramOutputReadyFlag
            JR   Z,CpmProgramWriteStorageFailure
            XOR  A
            LD   (CpmProgramAppendFlag),A
            LD   HL,(CpmProgramOutputCursor)
            LD   DE,(CpmProgramOutputLength)
            OR   A
            SBC  HL,DE
            JR   C,CpmProgramWriteStorageRecord
            JR   NZ,CpmProgramWriteStorageFailure
            LD   A,D
            AND  E
            INC  A
            JR   Z,CpmProgramWriteStorageFailure
            LD   A,1
            LD   (CpmProgramAppendFlag),A
CpmProgramWriteStorageRecord:
            LD   HL,(CpmProgramOutputCursor)
            LD   IX,CpmProgramOutputFcb
            CALL CpmProgramReadLogicalRecordRaw
            OR   A
            JR   Z,CpmProgramWriteStorageHaveRecord
            LD   B,A
            LD   A,(CpmProgramAppendFlag)
            OR   A
            JR   Z,CpmProgramWriteStorageFailure
            LD   A,B
            CP   1
            JR   Z,CpmProgramWriteStorageNewRecord
            CP   4
            JR   NZ,CpmProgramWriteStorageFailure
CpmProgramWriteStorageNewRecord:
            CALL CpmProgramClearCache
            LD   HL,(CpmProgramOutputCursor)
            LD   IX,CpmProgramOutputFcb
            CALL CpmProgramPrepareLogicalRecord
CpmProgramWriteStorageHaveRecord:
            LD   A,(CpmProgramWriteValue)
            LD   (HL),A
            LD   IX,CpmProgramOutputFcb
            CALL CpmProgramWriteCurrentRecord
            JR   C,CpmProgramWriteStorageFailure
            LD   A,(CpmProgramAppendFlag)
            OR   A
            JR   Z,CpmProgramWriteStorageAdvance
            LD   HL,(CpmProgramOutputLength)
            INC  HL
            CALL CpmProgramStoreOutputHeader
            JR   C,CpmProgramWriteStorageFailure
            LD   (CpmProgramOutputLength),HL
CpmProgramWriteStorageAdvance:
            LD   HL,(CpmProgramOutputCursor)
            INC  HL
            LD   (CpmProgramOutputCursor),HL
            XOR  A
            RET
CpmProgramWriteStorageFailure:
            JR   CpmProgramStorageFailure

.routine in HL out A,carry,zero clobbers sign,parity,halfCarry
CpmProgramSeekStorage:
            PUSH BC
            PUSH DE
            PUSH HL
            CALL CpmProgramSeekStorageBody
            POP  HL
            POP  DE
            POP  BC
            RET

.routine in HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CpmProgramSeekStorageBody:
            LD   A,(CpmProgramStorageState)
            AND  CpmProgramOutputReadyFlag
            JR   Z,CpmProgramSeekStorageFailure
            EX   DE,HL
            LD   HL,(CpmProgramOutputLength)
            OR   A
            SBC  HL,DE
            JR   C,CpmProgramSeekStorageFailure
            LD   (CpmProgramOutputCursor),DE
            XOR  A
            RET
CpmProgramSeekStorageFailure:
.routine out A,carry,zero clobbers sign,parity,halfCarry
CpmProgramStorageFailure:
            LD   A,4
            SCF
            RET

; Copy a twelve-byte default FCB name and clear its mutable twenty-four-byte
; tail. The CCP's two default names overlap in page zero, so both copies happen
; before either private FCB is opened.
.routine in DE,HL out A clobbers sign,parity,halfCarry,BC,DE,HL,carry,zero
CpmProgramCopyFcb:
            LD   BC,12
            LDIR
            XOR  A
            LD   B,24
.routine in A,B,DE out B,DE
CpmProgramClearFcbTail:
            LD   (DE),A
            INC  DE
            DJNZ CpmProgramClearFcbTail
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CpmProgramOpenInput:
            LD   A,(CpmProgramInputFcb+1)
            CP   ' '
            RET  Z
            LD   DE,CpmProgramInputFcb
            LD   C,CpmProgramOpenFunction
            CALL CpmProgramBdos
            INC  A
            RET  Z
            LD   IX,CpmProgramInputFcb
            CALL CpmProgramLoadHeader
            RET  C
            LD   (CpmProgramInputLength),HL
            LD   A,(CpmProgramStorageState)
            OR   CpmProgramInputReadyFlag
            LD   (CpmProgramStorageState),A
            XOR  A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CpmProgramOpenOutput:
            LD   A,(CpmProgramOutputFcb+1)
            CP   ' '
            RET  Z
            LD   A,(CpmProgramStorageState)
            AND  CpmProgramInputReadyFlag
            JR   Z,CpmProgramOpenOutputFile
            LD   HL,CpmProgramInputFcb
            LD   DE,CpmProgramOutputFcb
            LD   B,12
CpmProgramCompareStorageName:
            LD   A,(DE)
            CP   (HL)
            JR   NZ,CpmProgramOpenOutputFile
            INC  DE
            INC  HL
            DJNZ CpmProgramCompareStorageName
            RET
CpmProgramOpenOutputFile:
            LD   DE,CpmProgramOutputFcb
            LD   C,CpmProgramOpenFunction
            CALL CpmProgramBdos
            INC  A
            JR   Z,CpmProgramCreateOutput
            LD   IX,CpmProgramOutputFcb
            CALL CpmProgramLoadHeader
            RET  C
            JR   CpmProgramOutputReady
CpmProgramCreateOutput:
            XOR  A
            LD   B,24
            LD   DE,CpmProgramOutputFcb+12
            CALL CpmProgramClearFcbTail
            LD   DE,CpmProgramOutputFcb
            LD   C,CpmProgramMakeFunction
            CALL CpmProgramBdos
            INC  A
            RET  Z
            CALL CpmProgramClearCache
            LD   IX,CpmProgramOutputFcb
            CALL CpmProgramSetRecordZero
            CALL CpmProgramWriteCurrentRecord
            RET  C
            LD   HL,0
CpmProgramOutputReady:
            LD   (CpmProgramOutputLength),HL
            LD   (CpmProgramOutputCursor),HL
            LD   A,(CpmProgramStorageState)
            OR   CpmProgramOutputReadyFlag
            LD   (CpmProgramStorageState),A
            XOR  A
            RET

.routine in IX out A,HL,carry,zero clobbers sign,parity,halfCarry,BC,DE
CpmProgramLoadHeader:
            CALL CpmProgramSetRecordZero
            CALL CpmProgramReadCurrentRecord
            RET  C
            LD   HL,(CpmProgramRecordCache)
            XOR  A
            RET

.routine in IX,HL out A,HL,carry,zero clobbers sign,parity,halfCarry,BC,DE
CpmProgramReadLogicalRecordRaw:
            CALL CpmProgramPrepareLogicalRecord
            PUSH HL
            CALL CpmProgramReadCurrentRecordRaw
            POP  HL
            OR   A
            RET

; Map one logical payload offset through the two-byte length header. The random
; record field is 24-bit, so logical $FFFE correctly maps to physical $10000,
; record 512, byte zero instead of wrapping in a 16-bit calculation.
.routine in IX,HL out HL clobbers A,BC,DE,carry,zero,sign,parity,halfCarry
CpmProgramPrepareLogicalRecord:
            LD   DE,2
            ADD  HL,DE
            LD   A,0
            ADC  A,A
            ADD  A,A
            LD   (IX+34),A
            XOR  A
            LD   (IX+35),A
            LD   A,L
            AND  $7F
            LD   B,A
            LD   A,L
            RLCA
            AND  1
            LD   E,A
            LD   A,H
            ADD  A,A
            OR   E
            LD   (IX+33),A
            LD   HL,CpmProgramRecordCache
            LD   C,B
            LD   B,0
            ADD  HL,BC
            RET

.routine in IX out A clobbers carry,zero,sign,parity,halfCarry
CpmProgramSetRecordZero:
            XOR  A
            LD   (IX+33),A
            LD   (IX+34),A
            LD   (IX+35),A
            RET

.routine in IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CpmProgramReadCurrentRecord:
            CALL CpmProgramReadCurrentRecordRaw
            OR   A
            RET  Z
            JP   CpmProgramStorageFailure

.routine in IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CpmProgramReadCurrentRecordRaw:
            CALL CpmProgramSetDma
            PUSH IX
            POP  DE
            LD   C,CpmProgramRandomReadFunction
            CALL CpmProgramBdos
            OR   A
            RET

.routine in IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CpmProgramWriteCurrentRecord:
            CALL CpmProgramSetDma
            PUSH IX
            POP  DE
            LD   C,CpmProgramRandomWriteFunction
            CALL CpmProgramBdos
            OR   A
            RET  Z
            JP   CpmProgramStorageFailure

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CpmProgramSetDma:
            LD   DE,CpmProgramRecordCache
            LD   C,CpmProgramDmaFunction
            JP   CpmProgramBdos

.routine in HL out A,HL,carry,zero clobbers sign,parity,halfCarry,BC,DE,IX
CpmProgramStoreOutputHeader:
            PUSH HL
            LD   IX,CpmProgramOutputFcb
            CALL CpmProgramSetRecordZero
            CALL CpmProgramReadCurrentRecord
            POP  HL
            RET  C
            LD   (CpmProgramRecordCache),HL
            PUSH HL
            CALL CpmProgramWriteCurrentRecord
            POP  HL
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CpmProgramClearCache:
            LD   HL,CpmProgramRecordCache
            LD   DE,CpmProgramRecordCache+1
            LD   BC,127
            LD   (HL),0
            LDIR
            XOR  A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CpmProgramCloseStorage:
            LD   A,(CpmProgramStorageState)
            AND  CpmProgramInputReadyFlag
            JR   Z,CpmProgramCloseOutput
            LD   DE,CpmProgramInputFcb
            LD   C,CpmProgramCloseFunction
            CALL CpmProgramBdos
CpmProgramCloseOutput:
            LD   A,(CpmProgramStorageState)
            AND  CpmProgramOutputReadyFlag
            JR   Z,CpmProgramStorageClosed
            LD   DE,CpmProgramOutputFcb
            LD   C,CpmProgramCloseFunction
            CALL CpmProgramBdos
CpmProgramStorageClosed:
            XOR  A
            LD   (CpmProgramStorageState),A
            RET

; Terminal entries are reached by JP after the runtime has restored its root
; stack. RET therefore resumes CpmProgramEntry and then the CCP.
.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CpmProgramSuccess:
            CALL CpmProgramCloseStorage
            XOR  A
            RET
.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CpmProgramFailure:
            LD   DE,CpmProgramFailureText
            JR   CpmProgramTerminalMessage
.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CpmProgramTrap:
            LD   DE,CpmProgramTrapText
CpmProgramTerminalMessage:
            CALL CpmProgramCloseStorage
            LD   C,9
            CALL CpmProgramBdos
            XOR  A
            RET

; Flat CP/M images never require bank control. Reaching either entry is a
; provider fault; return the packet-service trap code so execution cannot
; silently continue with an invented transfer.
.routine out A,carry,zero clobbers sign,parity,halfCarry
CpmProgramFarCall:
CpmProgramFarJump:
CpmProgramPacket:
            LD   A,7
            SCF
            RET
CpmProgramProviderCodeEnd:

CpmProgramProviderImmutableStart:
CpmProgramFailureText:
            .db 13,10,"Unhandled Nucleus failure",13,10,"$"
CpmProgramTrapText:
            .db 13,10,"Nucleus trap",13,10,"$"
CpmProgramProviderImmutableEnd:

CpmProgramProviderWorkspaceStart:
CpmProgramInputFcb:
            .ds  36
CpmProgramOutputFcb:
            .ds  36
CpmProgramInputCursor:
            .dw  0
CpmProgramInputLength:
            .dw  0
CpmProgramOutputCursor:
            .dw  0
CpmProgramOutputLength:
            .dw  0
CpmProgramStorageState:
            .db  0
CpmProgramWriteValue:
            .db  0
CpmProgramAppendFlag:
            .db  0
CpmProgramProviderWorkspaceEnd:
CpmProgramPrefixEnd:
