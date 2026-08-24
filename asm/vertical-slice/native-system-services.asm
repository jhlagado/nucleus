; MON3-compatible development dispatcher. Source and retained-name services
; and target-stream services are implemented by Z80 code. Named objects and
; runtime-catalogue chunks continue through the narrow platform provider.

NativeSystemSavedStatus .equ NativeSourceProviderWorkspaceEnd
NativeSystemSavedA      .equ NativeSystemSavedStatus+1

.routine in A,C out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
NativeSystemDispatcher:
            LD   (NativeSystemSavedA),A
            LD   A,C
            CP   NucleusServiceCompilerFirst+0
            JR   Z,NativeSystemSourceNext
            CP   NucleusServiceCompilerFirst+1
            JR   Z,NativeSystemRetainName
            CP   NucleusServiceCompilerFirst+2
            JR   Z,NativeSystemCompareName
            CP   NucleusServiceCompilerFirst+3
            JR   Z,NativeSystemMaterializeName
            CP   NucleusServiceCompilerFirst+4
            JP   Z,NativeSystemTargetBegin
            CP   NucleusServiceCompilerFirst+5
            JP   Z,NativeSystemTargetImage
            CP   NucleusServiceCompilerFirst+6
            JP   Z,NativeSystemRuntime
            CP   NucleusServiceCompilerFirst+7
            JP   Z,NativeSystemRuntime
            CP   NucleusServiceCompilerFirst+8
            JP   Z,NativeSystemPatchByte
            CP   NucleusServiceCompilerFirst+9
            JP   Z,NativeSystemPatchWord
            CP   NucleusServiceCompilerFirst+10
            JP   Z,NativeSystemMap
            CP   NucleusServiceCompilerFirst+11
            JP   Z,NativeSystemMap
            CP   NucleusServiceCompilerFirst+12
            JP   Z,NativeSystemCommit
            CP   NucleusServiceCompilerFirst+13
            JP   Z,NativeSystemAbort
            CP   NucleusServiceCompilerFirst+14
            JP   Z,NativeSystemLaunchBegin
            CP   NucleusServiceCompilerFirst+15
            JP   Z,NativeSystemLaunchEnd
NativeSystemExternal:
            LD   A,(NativeSystemSavedA)
            OUT  (NativeHostMon3NodePort),A
            RET

NativeSystemSourceNext:
            LD   A,(NativeSystemSavedA)
            JP   NativeSourceProviderNext

NativeSystemRetainName:
            LD   A,(NativeSystemSavedA)
            LD   BC,(NativeHostMon3InputBC)
            JP   NativeSourceProviderRetainName

NativeSystemCompareName:
            LD   A,(NativeSystemSavedA)
            JP   NativeSourceProviderCompareName

NativeSystemMaterializeName:
            LD   A,(NativeSystemSavedA)
            JP   NativeSourceProviderMaterializeName

NativeSystemTargetBegin:
            JP   NativeNobjBegin

NativeSystemTargetImage:
            LD   A,(NativeSystemSavedA)
            LD   BC,(NativeHostMon3InputBC)
            PUSH BC
            PUSH HL
            PUSH IX
            PUSH IY
            CALL NativeNobjImageByte
            POP  IY
            POP  IX
            POP  HL
            POP  BC
            RET

NativeSystemRuntime:
            LD   A,(NativeHostRuntimeOperation)
            LD   BC,(NativeHostMon3InputBC)
            CALL NativeNobjRuntime
            JR   C,NativeSystemRuntimeFailed
            XOR  A
NativeSystemRuntimeStatus:
            LD   (NativeHostRuntimeStatus),A
            RET
NativeSystemRuntimeFailed:
            SCF
            JR   NativeSystemRuntimeStatus

NativeSystemPatchByte:
            LD   A,(NativeSystemSavedA)
            LD   BC,(NativeHostMon3InputBC)
            PUSH BC
            PUSH HL
            PUSH IX
            PUSH IY
            CALL NativeNobjPatchByte
            POP  IY
            POP  IX
            POP  HL
            POP  BC
            RET

NativeSystemPatchWord:
            LD   BC,(NativeHostMon3InputBC)
            PUSH BC
            PUSH DE
            PUSH HL
            PUSH IX
            PUSH IY
            CALL NativeNobjPatchWord
            POP  IY
            POP  IX
            POP  HL
            POP  DE
            POP  BC
            RET

NativeSystemMap:
            JP   NativeNobjMap

NativeSystemCommit:
            PUSH BC
            PUSH DE
            PUSH HL
            PUSH IX
            PUSH IY
            CALL NativeNobjCommit
            POP  IY
            POP  IX
            POP  HL
            POP  DE
            POP  BC
            RET

NativeSystemAbort:
            PUSH BC
            PUSH DE
            PUSH HL
            PUSH IX
            PUSH IY
            CALL NativeNobjAbort
            POP  IY
            POP  IX
            POP  HL
            POP  DE
            POP  BC
            RET

NativeSystemLaunchBegin:
            LD   A,(NativeSystemSavedA)
            CALL NativeSourceProviderLaunchBegin
            RET  C
            LD   C,NucleusServiceCompilerFirst+14
            OUT  (NativeHostMon3NodePort),A
            RET  NC
            LD   (NativeSystemSavedStatus),A
            CALL NativeSourceProviderLaunchEnd
            LD   A,(NativeSystemSavedStatus)
            SCF
            RET

NativeSystemLaunchEnd:
            LD   A,(NativeSystemSavedA)
            LD   (NativeSystemSavedStatus),A
            CALL NativeSourceProviderLaunchEnd
            RET  C
            LD   A,(NativeSystemSavedStatus)
            LD   C,NucleusServiceCompilerFirst+15
            OUT  (NativeHostMon3NodePort),A
            RET

NativeSystemServicesEnd:
