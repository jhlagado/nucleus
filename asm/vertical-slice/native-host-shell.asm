; Native compiler launch shell. This host-owned entry validates the public
; launch descriptor, owns one compilation lifecycle, calls the streaming
; compiler entry, classifies compiler diagnostics separately from host
; failures, and publishes the nine-byte launch result.

; Called once when the host image is installed. An abnormal outer reset first
; calls NucleusHostReset, while a cold installation can clear unconditionally.
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
NHINIT:
            LD   HL,NHWORK
            LD   DE,NHWORK+1
            LD   BC,NHWKEND-NHWORK-1
            XOR  A
            LD   (HL),A
            LDIR
            RET

; Release an interrupted launch before reusing the same host image. Abort is
; requested exactly once when a generation was active. Failure is returned to
; the outer platform, but host state is cleared in either case.
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
NHRESET:
            LD   A,(NHLACTV)
            OR   A
            JP   Z,NHRESCLR
            CALL TSABORT
            JP   C,NHRSTERR
            LD   A,NHLHOST
            CALL NHDONE
NHRESCLR:
            JP   NHINIT
NHRSTERR:
            LD   A,NHLHOST
            CALL NHDONE
            CALL NHINIT
            LD   A,NHSSTORE
            SCF
            RET

; IX points to the stable fourteen-byte launch descriptor. The descriptor and
; its result and target records remain live until this routine returns.
; Contract: in IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
NHCOMPIL:
            LD   (NHLDSCP),IX
            LD   L,(IX+8)
            LD   H,(IX+9)
            LD   A,H
            OR   L
            JP   Z,NHLNORES
            LD   (NHLRESP),HL
            CALL NHCLRRES
            LD   A,(NHLACTV)
            OR   A
            JP   NZ,NHLBAD

            LD   A,(IX+0)
            CP   NHLDSCSZ
            JP   NZ,NHLBAD
            LD   A,(IX+1)
            CP   NHLMAJOR
            JP   NZ,NHLBAD
            LD   A,(IX+2)
            CP   NHLMINOR
            JP   NZ,NHLBAD
            LD   A,(IX+3)
            DEC  A
            CP   SRCPARTS
            JP   NC,NHLBAD
            INC  A
            LD   (NHLPRTS),A
            LD   A,(IX+4)
            OR   (IX+5)
            JP   Z,NHLBAD
            LD   L,(IX+6)
            LD   H,(IX+7)
            LD   A,H
            OR   L
            JP   Z,NHLBAD
            LD   (NHLTARG),HL
            LD   A,(IX+10)
            OR   (IX+11)
            JP   Z,NHLBAD
            LD   A,(IX+12)
            CP   3
            JP   NC,NHLBAD
            LD   A,(IX+13)
            OR   A
            JP   NZ,NHLBAD

            ; The reference platform validates the opaque generations and the
            ; retained target context before the compiler can request source or
            ; output. This call is beneath the fixed compiler-host vector.
            XOR  A
%IF Mon3HostTransport
            CALL NHLAUNCH
%ELSE
            OUT  (HPLAUNCH),A
%ENDIF
            JP   C,NHLFAIL
            LD   A,1
            LD   (NHLACTV),A
            XOR  A
            LD   (NHLCOMIT),A
            LD   (NHASYNC),A

            LD   A,(NHLPRTS)
            LD   HL,0
            LD   IX,(NHLTARG)
            CALL CTACPART
            JP   C,NHCMPERR
            LD   A,(NHLCOMIT)
            OR   A
            JP   Z,NHACTBAD

            CALL NHCLRRES
            LD   (HL),A
            CALL NHDONE
            XOR  A
            RET

NHCMPERR:
            LD   A,(NHASYNC)
            OR   A
            JP   NZ,NHACTERR
            LD   A,(SSHOST)
            OR   A
            JP   NZ,NHACTERR
            CALL NHWDIAG
            LD   A,NHLDIAG
            CALL NHDONE
            LD   A,NHLDIAG
            SCF
            RET

NHACTBAD:
            LD   A,NHSINVAL
            PUSH AF
            CALL TSABORT
            JP   NC,NHABRDY
            POP  AF
            LD   A,NHSSTORE
            JP   NHACTERR
NHABRDY:
            POP  AF
NHACTERR:
            CALL NHWHOST
            LD   A,NHLHOST
            CALL NHDONE
            LD   A,NHLHOST
            SCF
            RET

NHLBAD:
            LD   A,NHSINVAL
NHLFAIL:
            CALL NHWHOST
            LD   A,NHLHOST
            SCF
            RET

NHLNORES:
            LD   A,NHLHOST
            SCF
            RET

; A is the completed launch outcome. The reference lower host treats release
; as infallible: publication has already happened on success, so cleanup must
; not manufacture a failure that cannot roll it back.
; Contract: in A out A,carry,zero clobbers sign,parity,halfCarry
NHDONE:
%IF Mon3HostTransport
            CALL NHFINISH
%ELSE
            OUT  (HPFINISH),A
%ENDIF
            XOR  A
            LD   (NHLACTV),A
            RET

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
NHCLRRES:
            LD   HL,(NHLRESP)
            XOR  A
            LD   (HL),A
            LD   D,H
            LD   E,L
            INC  DE
            LD   BC,8
            LDIR
            LD   HL,(NHLRESP)
            RET

; A is the private host status.
; Contract: in A out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
NHWHOST:
            PUSH AF
            CALL NHCLRRES
            POP  AF
            LD   (HL),NHLHOST
            INC  HL
            LD   (HL),A
            RET

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
NHWDIAG:
            CALL NHCLRRES
            LD   (HL),NHLDIAG
            INC  HL
            LD   A,(DGCODE)
            LD   (HL),A
            INC  HL
            LD   A,(DGPARTID)
            LD   (HL),A
            INC  HL
            EX   DE,HL
            LD   HL,DGOFF
            LD   BC,6
            LDIR
            RET

; Runtime-image provider calls are the asynchronous compiler-host operation.
; The request is complete before the yield OUT. Node writes only the status
; byte, then the ordinary stepping loop resumes at NativeHostResumeRuntimeRequest
; with the compiler call frame still on the hardware stack.
; Contract: in BC,DE,HL,IX out A,carry,zero clobbers sign,parity,halfCarry
NHRTREQ:
            LD   (NHRTLEN),BC
            LD   (NHRTID),DE
            LD   (NHRTADR),HL
            LD   (NHRTCTX),IX
            LD   A,$FF
            LD   (NHRTSTAT),A
            LD   A,1
            LD   (NHRTPEND),A
            LD   A,(NHRTBNK)
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry
NHRTRET:
            XOR  A
            LD   (NHRTPEND),A
            LD   A,(NHRTSTAT)
            OR   A
            RET  Z
            CP   NHSCANCL
            JP   Z,NHASYERR
            SCF
            RET
NHASYERR:
            LD   (NHASYNC),A
            LD   SP,(CPABRTSP)
            SCF
            RET
