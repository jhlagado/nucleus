; MON3-compatible development dispatcher. Source and retained-name services
; and target-stream services are implemented by Z80 code. Named objects and
; runtime-catalogue chunks continue through the narrow platform provider.

NativeSystemSavedStatus .equ SPWKEND
NativeSystemSavedA      .equ NativeSystemSavedStatus+1

.routine in A,C out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
NativeSystemDispatcher:
            LD   (NativeSystemSavedA),A
            LD   A,C
            CP   NSCOMPF+0
            JR   Z,NativeSystemSourceNext
            CP   NSCOMPF+1
            JR   Z,NativeSystemRetainName
            CP   NSCOMPF+2
            JR   Z,NativeSystemCompareName
            CP   NSCOMPF+3
            JR   Z,NativeSystemMaterializeName
            CP   NSCOMPF+4
            JP   Z,NativeSystemTargetBegin
            CP   NSCOMPF+5
            JP   Z,NativeSystemTargetImage
            CP   NSCOMPF+6
            JP   Z,NativeSystemRuntime
            CP   NSCOMPF+7
            JP   Z,NativeSystemRuntime
            CP   NSCOMPF+8
            JP   Z,NativeSystemPatchByte
            CP   NSCOMPF+9
            JP   Z,NativeSystemPatchWord
            CP   NSCOMPF+10
            JP   Z,NativeSystemMap
            CP   NSCOMPF+11
            JP   Z,NativeSystemMap
            CP   NSCOMPF+12
            JP   Z,NativeSystemCommit
            CP   NSCOMPF+13
            JP   Z,NativeSystemAbort
            CP   NSCOMPF+14
            JP   Z,NativeSystemLaunchBegin
            CP   NSCOMPF+15
            JP   Z,NativeSystemLaunchEnd
NativeSystemExternal:
            LD   A,(NativeSystemSavedA)
            OUT  (HPMON3),A
            RET

NativeSystemSourceNext:
            LD   A,(NativeSystemSavedA)
            JP   SPNEXT

NativeSystemRetainName:
            LD   A,(NativeSystemSavedA)
            LD   BC,(NHM3BC)
            JP   SPRETAIN

NativeSystemCompareName:
            LD   A,(NativeSystemSavedA)
            JP   SPCMPNAM

NativeSystemMaterializeName:
            LD   A,(NativeSystemSavedA)
            JP   SPMATNAM

NativeSystemTargetBegin:
            JP   NativeNobjBegin

NativeSystemTargetImage:
            LD   A,(NativeSystemSavedA)
            LD   BC,(NHM3BC)
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
            LD   A,(NHRTOP)
            LD   BC,(NHM3BC)
            CALL NativeNobjRuntime
            JR   C,NativeSystemRuntimeFailed
            XOR  A
NativeSystemRuntimeStatus:
            LD   (NHRTSTAT),A
            RET
NativeSystemRuntimeFailed:
            SCF
            JR   NativeSystemRuntimeStatus

NativeSystemPatchByte:
            LD   A,(NativeSystemSavedA)
            LD   BC,(NHM3BC)
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
            LD   BC,(NHM3BC)
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
            CALL SPBEGIN
            RET  C
            LD   C,NSCOMPF+14
            OUT  (HPMON3),A
            RET  NC
            LD   (NativeSystemSavedStatus),A
            CALL SPEND
            LD   A,(NativeSystemSavedStatus)
            SCF
            RET

NativeSystemLaunchEnd:
            LD   A,(NativeSystemSavedA)
            LD   (NativeSystemSavedStatus),A
            CALL SPEND
            RET  C
            LD   A,(NativeSystemSavedStatus)
            LD   C,NSCOMPF+15
            OUT  (HPMON3),A
            RET

NativeSystemServicesEnd:
