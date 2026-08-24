; MON3-compatible development dispatcher. Source and retained-name services
; are implemented by Z80 code. Object storage and the not-yet-converged target
; sink continue through the narrow Node/monitor provider beneath this gateway.

NativeSystemSavedStatus .equ NativeSourceProviderWorkspaceEnd
NativeSystemSavedA      .equ NativeSystemSavedStatus+1

.routine in A,C out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
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
            CP   NucleusServiceCompilerFirst+14
            JR   Z,NativeSystemLaunchBegin
            CP   NucleusServiceCompilerFirst+15
            JR   Z,NativeSystemLaunchEnd
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
