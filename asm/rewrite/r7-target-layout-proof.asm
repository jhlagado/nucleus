; R7 target descriptor and layout proof. Descriptor blocks are Host API data;
; every compiler-executed instruction uses an ordinary Z80 mnemonic.

CompilerWorkBase    .equ $8000
SourceBase          .equ $7000
SourceLimit         .equ $7800
RewriteAdapterBase  .equ $A000
RewriteAdapterLimit .equ $A100
DebugHooks          .equ 0

            .org $1000
ProofTargetLayouts:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofTargetUnexpectedDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   IX,ProofTargetRomDescriptor
            LD   A,2
            CALL RewriteTargetValidateDescriptor
            LD   A,(RewriteTargetLayoutMode)
            CP   RewriteTargetLayoutRom
            JP   NZ,ProofTargetFailure
            LD   HL,(RewriteTargetImageBase)
            LD   DE,$8000
            OR   A
            SBC  HL,DE
            JP   NZ,ProofTargetFailure
            LD   IX,ProofTargetLoadedDescriptor
            LD   A,1
            CALL RewriteTargetValidateDescriptor
            LD   A,(RewriteTargetLayoutMode)
            OR   A
            JP   NZ,ProofTargetFailure
            LD   IX,ProofTargetExactEndDescriptor
            LD   A,1
            CALL RewriteTargetValidateDescriptor
            LD   A,(RewriteTargetLayoutMode)
            CP   RewriteTargetLayoutRom
            JP   NZ,ProofTargetFailure
            LD   IX,ProofTargetBankedDescriptor
            LD   A,2
            CALL RewriteTargetValidateDescriptor
            LD   A,(RewriteTargetBankCount)
            CP   2
            JP   NZ,ProofTargetFailure
            LD   A,(RewriteTargetEntryBank)
            CP   1
            JP   NZ,ProofTargetFailure
            LD   A,$B0
            LD   (ProofTargetStatus),A
            HALT

ProofTargetInvalidIdentity:
            LD   IX,ProofTargetIdentityDescriptor
            JR   ProofTargetArmOnePart
ProofTargetFailureThenRecovery:
            LD   SP,$FF00
            CALL RewriteReset
            LD   HL,ProofTargetRecoveryDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   IX,ProofTargetIdentityDescriptor
            LD   A,1
            CALL RewriteTargetValidateDescriptor
            JP   ProofTargetFailure
ProofTargetRecoveryDiagnostic:
            LD   HL,ProofTargetRecoveryReturn
            PUSH HL
            LD   (CompilerAbortSp),SP
            LD   IX,ProofTargetRomDescriptor
            LD   A,2
            CALL RewriteTargetValidateDescriptor
            LD   A,(RewriteTargetLayoutMode)
            CP   RewriteTargetLayoutRom
            JP   NZ,ProofTargetFailure
            LD   A,$B1
            LD   (ProofTargetStatus),A
ProofTargetRecoveryReturn:
            HALT
ProofTargetInvalidPartBank:
            LD   IX,ProofTargetPartBankDescriptor
            JR   ProofTargetArmOnePart
ProofTargetPartialOverlap:
            LD   IX,ProofTargetOverlapDescriptor
            JR   ProofTargetArmOnePart
ProofTargetZeroCapacity:
            LD   IX,ProofTargetZeroDescriptor
            JR   ProofTargetArmOnePart
ProofTargetWrappedRegion:
            LD   IX,ProofTargetWrappedDescriptor
            JR   ProofTargetArmOnePart
ProofTargetBankedLoaded:
            LD   IX,ProofTargetBankedLoadedDescriptor
            LD   A,2
            JR   ProofTargetArmDiagnostic
ProofTargetArmOnePart:
            LD   A,1
ProofTargetArmDiagnostic:
            LD   SP,$FF00
            PUSH AF
            PUSH IX
            CALL RewriteReset
            POP  IX
            POP  AF
            LD   HL,ProofTargetDiagnosticReturn
            PUSH HL
            LD   (CompilerAbortSp),SP
            CALL RewriteTargetValidateDescriptor
            JP   ProofTargetFailure
ProofTargetDiagnosticReturn:
            HALT

ProofTargetUnexpectedDiagnostic:
            LD   A,(DiagnosticCode)
            LD   (ProofTargetStatus),A
            HALT
ProofTargetFailure:
            LD   A,$FF
            LD   (ProofTargetStatus),A
            HALT

            .include "compiler-image.asmi"

ProofTargetStatus: .db 0
ProofTargetBanks0: .db 0,0
ProofTargetBanks01: .db 0,1
ProofTargetBadBank: .db 1

ProofTargetRomDescriptor:
            .dw NucleusRuntimeIdentity,$8000,$1000,$4000,$1000
            .db 1,1,0
            .dw ProofTargetBanks0
ProofTargetLoadedDescriptor:
            .dw NucleusRuntimeIdentity,$8000,$2000,$9000,$1000
            .db 0,1,0
            .dw ProofTargetBanks0
ProofTargetExactEndDescriptor:
            .dw NucleusRuntimeIdentity,$F000,$1000,$4000,$1000
            .db 0,1,0
            .dw ProofTargetBanks0
ProofTargetBankedDescriptor:
            .dw NucleusRuntimeIdentity,$8000,$1000,$4000,$1000
            .db 1,2,1
            .dw ProofTargetBanks01
ProofTargetIdentityDescriptor:
            .dw NucleusRuntimeIdentity+1,$8000,$1000,$4000,$1000
            .db 1,1,0
            .dw ProofTargetBanks0
ProofTargetPartBankDescriptor:
            .dw NucleusRuntimeIdentity,$8000,$1000,$4000,$1000
            .db 1,1,0
            .dw ProofTargetBadBank
ProofTargetOverlapDescriptor:
            .dw NucleusRuntimeIdentity,$8000,$1000,$7F80,$0100
            .db 1,1,0
            .dw ProofTargetBanks0
ProofTargetZeroDescriptor:
            .dw NucleusRuntimeIdentity,$8000,0,$4000,$1000
            .db 1,1,0
            .dw ProofTargetBanks0
ProofTargetWrappedDescriptor:
            .dw NucleusRuntimeIdentity,$FFF0,$0020,$4000,$1000
            .db 1,1,0
            .dw ProofTargetBanks0
ProofTargetBankedLoadedDescriptor:
            .dw NucleusRuntimeIdentity,$8000,$2000,$9000,$1000
            .db 1,2,1
            .dw ProofTargetBanks01
