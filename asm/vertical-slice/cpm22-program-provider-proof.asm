            .include "cpm22-program-provider.asm"

            .org CpmProgramTargetEntry
CpmProgramProofTarget:
            JP   CpmProgramSuccess
            .end
