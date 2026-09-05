; Fixed native CP/M runtime-catalogue provider. The offline-generated assets
; are already linked for the one loaded target placement and packet gateway.

CpmRuntimeDestination .equ CpmDirectWorkspaceEnd
CpmRuntimeContext     .equ CpmRuntimeDestination+2
CpmRuntimeWorkspaceEnd .equ CpmRuntimeContext+2

CpmRuntimeCodePhysical    .equ CpmOutputBufferBase+3
CpmRuntimeInitialPhysical .equ CpmOutputBufferBase+(CpmTargetWritableBase-CpmTargetImageBase)
CpmRuntimeInitialLength   .equ RIVECBYT+RISTBYT
CpmRuntimeDataBaseOffset  .equ RIVECBYT+RODBASE
CpmRuntimeDataCapacityOffset .equ RIVECBYT+RODCAP
CpmRuntimeDiagnosticConfiguration .equ 95

CpmRuntimeProviderCodeStart:
.routine in A,BC,DE,HL,IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CpmDirectRuntimeProvider:
            LD   (CpmRuntimeDestination),HL
            LD   (CpmRuntimeContext),IX
            PUSH AF
            LD   A,D
            OR   A
            JR   NZ,CpmRuntimeProviderInvalidPop
            LD   A,E
            CP   RIABI
            JR   NZ,CpmRuntimeProviderInvalidPop
            POP  AF
            OR   A
            JR   Z,CpmRuntimeProviderCode
            DEC  A
            JR   NZ,CpmRuntimeProviderInvalid
            LD   HL,CpmRuntimeInitialLength
            OR   A
            SBC  HL,BC
            JR   NZ,CpmRuntimeProviderInvalid
            LD   HL,(CpmRuntimeDestination)
            LD   DE,CpmRuntimeInitialPhysical
            OR   A
            SBC  HL,DE
            JR   NZ,CpmRuntimeProviderInvalid
            LD   HL,CpmEmbeddedInitial
            JR   CpmRuntimeProviderCopyInitial
CpmRuntimeProviderCode:
            LD   HL,RIBYTES
            OR   A
            SBC  HL,BC
            JR   NZ,CpmRuntimeProviderInvalid
            LD   HL,(CpmRuntimeDestination)
            LD   DE,CpmRuntimeCodePhysical
            OR   A
            SBC  HL,DE
            JR   NZ,CpmRuntimeProviderInvalid
            LD   HL,CpmEmbeddedRuntime
            LD   DE,(CpmRuntimeDestination)
            LD   BC,RIBYTES
            LDIR
            XOR  A
            RET
CpmRuntimeProviderCopyInitial:
            LD   DE,(CpmRuntimeDestination)
            LD   BC,CpmRuntimeInitialLength
            LDIR
            LD   IX,(CpmRuntimeContext)
            LD   HL,(CpmRuntimeDestination)
            LD   BC,CpmRuntimeDataBaseOffset
            ADD  HL,BC
            LD   A,(IX+10)
            LD   (HL),A
            INC  HL
            LD   A,(IX+11)
            LD   (HL),A
            INC  HL
            LD   A,(IX+12)
            LD   (HL),A
            INC  HL
            LD   A,(IX+13)
            LD   (HL),A
            XOR  A
            RET
CpmRuntimeProviderInvalidPop:
            POP  AF
CpmRuntimeProviderInvalid:
            LD   A,CpmRuntimeDiagnosticConfiguration
            SCF
            RET
CpmRuntimeProviderCodeEnd:
