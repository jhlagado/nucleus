; CP/M transient entry, diagnostic printer, and fixed flat-target descriptor.

CpmCompilerStartupCodeStart:
.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CpmCompilerEntry:
            ; The CCP stack lives inside the resident CP/M image and is far too
            ; small for the compiler. This transient is writable and cannot be
            ; re-entered, so retain the caller stack in one immediate operand
            ; and give the complete compilation its reserved stack.
            LD   (CpmCompilerRestoreSp+1),SP
            LD   SP,StackTop
            CALL CpmCompilerRun
CpmCompilerRestoreSp:
            LD   SP,0
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CpmCompilerRun:
            CALL CpmCommandPrepare
            JR   C,CpmCompilerPrintHostError
            LD   A,(CpmCommandHelpRequested)
            OR   A
            JR   NZ,CpmCompilerPrintHelp
            CALL CpmSourceProviderBegin
            JR   C,CpmCompilerPrintHostError
            CALL CpmPublishPrepare
            JR   C,CpmCompilerPrintHostError
            LD   A,(CpmSourcePartCount)
            LD   HL,0
            LD   IX,CpmCompilerTargetDescriptor
            CALL CompileTargetAggregateCallParts
            JR   C,CpmCompilerCompileFailure
            XOR  A
            RET

CpmCompilerPrintHelp:
            LD   DE,CpmCompilerHelpText
            CALL CpmCompilerPrintText
            XOR  A
            RET

CpmCompilerCompileFailure:
            CALL CpmDirectAbort
            LD   A,(SourceHostStatus)
            OR   A
            JR   NZ,CpmCompilerPrintHostError
            JR   CpmCompilerPrintDiagnostic

.routine in A out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CpmCompilerPrintHostError:
            PUSH AF
            LD   DE,CpmCompilerHostErrorText
            CALL CpmCompilerPrintText
            POP  AF
            CALL CpmCompilerPrintByte
            JR   CpmCompilerPrintNewline

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CpmCompilerPrintDiagnostic:
            LD   DE,CpmCompilerDiagnosticText
            CALL CpmCompilerPrintText
            LD   A,(DiagnosticCode)
            CALL CpmCompilerPrintByte
            LD   DE,CpmCompilerPartText
            CALL CpmCompilerPrintText
            LD   A,(DiagnosticPartId)
            CALL CpmCompilerPrintByte
            LD   DE,CpmCompilerOffsetText
            CALL CpmCompilerPrintText
            LD   HL,(DiagnosticOffset)
            CALL CpmCompilerPrintWord
            LD   DE,CpmCompilerLineText
            CALL CpmCompilerPrintText
            LD   HL,(DiagnosticLine)
            CALL CpmCompilerPrintWord
            LD   DE,CpmCompilerColumnText
            CALL CpmCompilerPrintText
            LD   HL,(DiagnosticColumn)
            CALL CpmCompilerPrintWord

CpmCompilerPrintNewline:
            LD   DE,CpmCompilerNewline
.routine in DE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CpmCompilerPrintText:
            LD   C,9
            JP   CpmCallBdos

.routine in HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CpmCompilerPrintWord:
            PUSH HL
            LD   A,H
            CALL CpmCompilerPrintByte
            POP  HL
            LD   A,L
            JP   CpmCompilerPrintByte

.routine in A out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CpmCompilerPrintByte:
            PUSH AF
            RRCA
            RRCA
            RRCA
            RRCA
            CALL CpmCompilerPrintNibble
            POP  AF
.routine in A out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CpmCompilerPrintNibble:
            AND  $0F
            ADD  A,'0'
            CP   '9'+1
            JR   C,CpmCompilerPrintDigit
            ADD  A,7
CpmCompilerPrintDigit:
            LD   E,A
            LD   C,2
            JP   CpmCallBdos
CpmCompilerStartupCodeEnd:

            .include "cpm22-embedded-assets.asmi"

CpmCompilerImmutableStart:
CpmCompilerPartBanks .equ CpmEmbeddedPrefixEnd-SourcePartCapacity
CpmCompilerTargetDescriptor:
            .dw  NucleusRuntimeIdentity
            .dw  CpmTargetImageBase
            .dw  CpmTargetImageCapacity
            .dw  CpmTargetWritableBase
            .dw  CpmTargetWritableCapacity
            .db  0,1,0
            .dw  CpmCompilerPartBanks
CpmCompilerHostErrorText:  .db 13,10,"Nucleus host error ","$"
CpmCompilerDiagnosticText: .db 13,10,"Nucleus error ","$"
CpmCompilerPartText:       .db " P=","$"
CpmCompilerOffsetText:     .db " O=","$"
CpmCompilerLineText:       .db " L=","$"
CpmCompilerColumnText:     .db " C=","$"
CpmCompilerHelpText:       .db 13,10,"NUC [SOURCE [OUTPUT.COM|OUTPUT.BIN|OUTPUT.HEX]]",13,10,"$"
CpmCompilerNewline:        .db 13,10,"$"
CpmCompilerImmutableEnd:
CpmCompilerResidentEnd:
