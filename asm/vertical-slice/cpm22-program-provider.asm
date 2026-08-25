; Runtime-vector provider embedded at the front of a generated CP/M COM file.
; CP/M starts at $0100. The prefix calls the separately compiled Nucleus image
; at $0800, and terminal vector entries return through that call to the CCP.

CpmProgramTargetEntry .equ $0800
CpmProgramBdos        .equ $0005
CpmProgramBiosConin   .equ $FA09
CpmProgramBiosConout  .equ $FA0C

            .org $0100
CpmProgramPrefixStart:
.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CpmProgramEntry:
            CALL CpmProgramInitialize
            JR   C,CpmProgramReturn
            CALL CpmProgramTargetEntry
CpmProgramReturn:
            RET

            ; Fixed addresses let the offline runtime catalogue bind ordinary
            ; vectors and the packet gateway without runtime linking.
            .org $0120
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
            RET

; The ideal Debug80 BIOS CONIN path blocks, returns every byte including zero,
; and performs no implicit echo. Preserve the generated-program register set.
.routine out A,carry,zero clobbers sign,parity,halfCarry
CpmProgramReadInput:
            PUSH BC
            PUSH DE
            PUSH HL
            PUSH IX
            PUSH IY
            CALL CpmProgramBiosConin
            POP  IY
            POP  IX
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
            PUSH IX
            PUSH IY
            LD   C,A
            CALL CpmProgramBiosConout
            POP  IY
            POP  IX
            POP  HL
            POP  DE
            POP  BC
            XOR  A
            RET

; Bulk storage is deliberately unavailable until the following provider
; increment installs the two CP/M FCBs and their exact cursor semantics. These
; entries are real recoverable service failures, not false successes.
.routine out A,carry,zero clobbers sign,parity,halfCarry
CpmProgramReadStorage:
CpmProgramRewindStorage:
CpmProgramWriteStorage:
CpmProgramSeekStorage:
            LD   A,4
            SCF
            RET

; Terminal entries are reached by JP after the runtime has restored its root
; stack. RET therefore resumes CpmProgramEntry and then the CCP.
.routine out A,carry,zero clobbers sign,parity,halfCarry
CpmProgramSuccess:
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
CpmProgramPrefixEnd:
