; Native compiler launch shell. This host-owned entry validates the public
; launch descriptor, owns one compilation lifecycle, calls the streaming
; compiler entry, classifies compiler diagnostics separately from host
; failures, and publishes the nine-byte launch result.

.if Mon3HostTransport
NativeHostWorkspaceBase            .equ $5800
.else
NativeHostWorkspaceBase            .equ $A800
.endif
NativeHostLaunchActive             .equ NativeHostWorkspaceBase
NativeHostLaunchCommitted          .equ NativeHostLaunchActive+1
NativeHostLaunchDescriptorPointer  .equ NativeHostLaunchCommitted+1
NativeHostLaunchResultPointer      .equ NativeHostLaunchDescriptorPointer+2
NativeHostLaunchTargetPointer      .equ NativeHostLaunchResultPointer+2
NativeHostLaunchPartCount          .equ NativeHostLaunchTargetPointer+2
NativeHostRuntimeOperation         .equ NativeHostLaunchPartCount+1
NativeHostRuntimeBank              .equ NativeHostRuntimeOperation+1
NativeHostRuntimeLength            .equ NativeHostRuntimeBank+1
NativeHostRuntimeIdentity          .equ NativeHostRuntimeLength+2
NativeHostRuntimeAddress           .equ NativeHostRuntimeIdentity+2
NativeHostRuntimeContext           .equ NativeHostRuntimeAddress+2
NativeHostRuntimeStatus            .equ NativeHostRuntimeContext+2
NativeHostRuntimePending           .equ NativeHostRuntimeStatus+1
NativeHostAsyncStatus              .equ NativeHostRuntimePending+1
.if Mon3HostTransport
NativeHostMon3InputBC              .equ NativeHostAsyncStatus+1
NativeHostMon3InputC               .equ NativeHostMon3InputBC
NativeHostMon3InputB               .equ NativeHostMon3InputBC+1
NativeHostWorkspaceEnd             .equ NativeHostMon3InputBC+2
.else
NativeHostWorkspaceEnd             .equ NativeHostAsyncStatus+1
.endif

NativeHostLaunchDescriptorSize     .equ 14
NativeHostLaunchAbiMajor           .equ 0
NativeHostLaunchAbiMinor           .equ 1
NativeHostLaunchOutcomeSuccess     .equ 0
NativeHostLaunchOutcomeDiagnostic  .equ 1
NativeHostLaunchOutcomeHost        .equ 2
NativeHostStatusInvalid            .equ 4
NativeHostStatusCancelled          .equ 6
NativeHostStatusStorage            .equ 3

; Called once when the host image is installed. An abnormal outer reset first
; calls NucleusHostReset, while a cold installation can clear unconditionally.
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
NucleusHostInitialize:
            LD   HL,NativeHostWorkspaceBase
            LD   DE,NativeHostWorkspaceBase+1
            LD   BC,NativeHostWorkspaceEnd-NativeHostWorkspaceBase-1
            XOR  A
            LD   (HL),A
            LDIR
            RET

; Release an interrupted launch before reusing the same host image. Abort is
; requested exactly once when a generation was active. Failure is returned to
; the outer platform, but host state is cleared in either case.
.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
NucleusHostReset:
            LD   A,(NativeHostLaunchActive)
            OR   A
            JP   Z,NHResetClear
            CALL TargetSinkAbort
            JP   C,NHResetAbortFailure
            LD   A,NativeHostLaunchOutcomeHost
            CALL NativeHostFinishLaunch
NHResetClear:
            JP   NucleusHostInitialize
NHResetAbortFailure:
            LD   A,NativeHostLaunchOutcomeHost
            CALL NativeHostFinishLaunch
            CALL NucleusHostInitialize
            LD   A,NativeHostStatusStorage
            SCF
            RET

; IX points to the stable fourteen-byte launch descriptor. The descriptor and
; its result and target records remain live until this routine returns.
.routine in IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
NucleusHostCompile:
            LD   (NativeHostLaunchDescriptorPointer),IX
            LD   L,(IX+8)
            LD   H,(IX+9)
            LD   A,H
            OR   L
            JP   Z,NHLaunchNoResult
            LD   (NativeHostLaunchResultPointer),HL
            CALL NativeHostClearLaunchResult
            LD   A,(NativeHostLaunchActive)
            OR   A
            JP   NZ,NHInvalidLaunch

            LD   A,(IX+0)
            CP   NativeHostLaunchDescriptorSize
            JP   NZ,NHInvalidLaunch
            LD   A,(IX+1)
            CP   NativeHostLaunchAbiMajor
            JP   NZ,NHInvalidLaunch
            LD   A,(IX+2)
            CP   NativeHostLaunchAbiMinor
            JP   NZ,NHInvalidLaunch
            LD   A,(IX+3)
            DEC  A
            CP   SRCPARTS
            JP   NC,NHInvalidLaunch
            INC  A
            LD   (NativeHostLaunchPartCount),A
            LD   A,(IX+4)
            OR   (IX+5)
            JP   Z,NHInvalidLaunch
            LD   L,(IX+6)
            LD   H,(IX+7)
            LD   A,H
            OR   L
            JP   Z,NHInvalidLaunch
            LD   (NativeHostLaunchTargetPointer),HL
            LD   A,(IX+10)
            OR   (IX+11)
            JP   Z,NHInvalidLaunch
            LD   A,(IX+12)
            CP   3
            JP   NC,NHInvalidLaunch
            LD   A,(IX+13)
            OR   A
            JP   NZ,NHInvalidLaunch

            ; The reference platform validates the opaque generations and the
            ; retained target context before the compiler can request source or
            ; output. This call is beneath the fixed compiler-host vector.
            XOR  A
.if Mon3HostTransport
            CALL NativeHostLaunchBegin
.else
            OUT  (NativeHostLaunchBeginPort),A
.endif
            JP   C,NHLaunchHostFailure
            LD   A,1
            LD   (NativeHostLaunchActive),A
            XOR  A
            LD   (NativeHostLaunchCommitted),A
            LD   (NativeHostAsyncStatus),A

            LD   A,(NativeHostLaunchPartCount)
            LD   HL,0
            LD   IX,(NativeHostLaunchTargetPointer)
            CALL CompileTargetAggregateCallParts
            JP   C,NHCompileFailure
            LD   A,(NativeHostLaunchCommitted)
            OR   A
            JP   Z,NHActiveInvalid

            CALL NativeHostClearLaunchResult
            LD   (HL),A
            CALL NativeHostFinishLaunch
            XOR  A
            RET

NHCompileFailure:
            LD   A,(NativeHostAsyncStatus)
            OR   A
            JP   NZ,NHActiveHostFailure
            LD   A,(SourceHostStatus)
            OR   A
            JP   NZ,NHActiveHostFailure
            CALL NativeHostWriteDiagnosticResult
            LD   A,NativeHostLaunchOutcomeDiagnostic
            CALL NativeHostFinishLaunch
            LD   A,NativeHostLaunchOutcomeDiagnostic
            SCF
            RET

NHActiveInvalid:
            LD   A,NativeHostStatusInvalid
            PUSH AF
            CALL TargetSinkAbort
            JP   NC,NHAbortReady
            POP  AF
            LD   A,NativeHostStatusStorage
            JP   NHActiveHostFailure
NHAbortReady:
            POP  AF
NHActiveHostFailure:
            CALL NativeHostWriteHostResult
            LD   A,NativeHostLaunchOutcomeHost
            CALL NativeHostFinishLaunch
            LD   A,NativeHostLaunchOutcomeHost
            SCF
            RET

NHInvalidLaunch:
            LD   A,NativeHostStatusInvalid
NHLaunchHostFailure:
            CALL NativeHostWriteHostResult
            LD   A,NativeHostLaunchOutcomeHost
            SCF
            RET

NHLaunchNoResult:
            LD   A,NativeHostLaunchOutcomeHost
            SCF
            RET

; A is the completed launch outcome. The reference lower host treats release
; as infallible: publication has already happened on success, so cleanup must
; not manufacture a failure that cannot roll it back.
.routine in A out A,carry,zero clobbers sign,parity,halfCarry
NativeHostFinishLaunch:
.if Mon3HostTransport
            CALL NativeHostLaunchEnd
.else
            OUT  (NativeHostLaunchEndPort),A
.endif
            XOR  A
            LD   (NativeHostLaunchActive),A
            RET

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
NativeHostClearLaunchResult:
            LD   HL,(NativeHostLaunchResultPointer)
            XOR  A
            LD   (HL),A
            LD   D,H
            LD   E,L
            INC  DE
            LD   BC,8
            LDIR
            LD   HL,(NativeHostLaunchResultPointer)
            RET

; A is the private host status.
.routine in A out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
NativeHostWriteHostResult:
            PUSH AF
            CALL NativeHostClearLaunchResult
            POP  AF
            LD   (HL),NativeHostLaunchOutcomeHost
            INC  HL
            LD   (HL),A
            RET

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
NativeHostWriteDiagnosticResult:
            CALL NativeHostClearLaunchResult
            LD   (HL),NativeHostLaunchOutcomeDiagnostic
            INC  HL
            LD   A,(DiagnosticCode)
            LD   (HL),A
            INC  HL
            LD   A,(DiagnosticPartId)
            LD   (HL),A
            INC  HL
            EX   DE,HL
            LD   HL,DiagnosticOffset
            LD   BC,6
            LDIR
            RET

; Runtime-image provider calls are the asynchronous compiler-host operation.
; The request is complete before the yield OUT. Node writes only the status
; byte, then the ordinary stepping loop resumes at NativeHostResumeRuntimeRequest
; with the compiler call frame still on the hardware stack.
.routine in BC,DE,HL,IX out A,carry,zero clobbers sign,parity,halfCarry
NativeHostPrepareRuntimeRequest:
            LD   (NativeHostRuntimeLength),BC
            LD   (NativeHostRuntimeIdentity),DE
            LD   (NativeHostRuntimeAddress),HL
            LD   (NativeHostRuntimeContext),IX
            LD   A,$FF
            LD   (NativeHostRuntimeStatus),A
            LD   A,1
            LD   (NativeHostRuntimePending),A
            LD   A,(NativeHostRuntimeBank)
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry
NativeHostResumeRuntimeRequest:
            XOR  A
            LD   (NativeHostRuntimePending),A
            LD   A,(NativeHostRuntimeStatus)
            OR   A
            RET  Z
            CP   NativeHostStatusCancelled
            JP   Z,NHAsyncFailure
            SCF
            RET
NHAsyncFailure:
            LD   (NativeHostAsyncStatus),A
            LD   SP,(CompilerAbortSp)
            SCF
            RET
