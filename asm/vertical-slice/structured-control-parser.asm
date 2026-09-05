; Bounded structured-control parser layered over typed scalar expressions.
; Parser frames live only during source checking. Z80 emission reuses their
; workspace after the complete semantic transcript has been published.

%IF HybridLL1Full
%ELSE
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,HL
CFRST:
            XOR  A
            LD   (CTDEP),A
%IF AggregateCallSlices
            RET
%ELSE
            LD   (CTNXLBL),A
            RET
%ENDIF
%ENDIF

; Contract: in A out A,DE,HL,carry,zero clobbers sign,parity,halfCarry
CFFRADR:
            LD   L,A
            LD   H,0
            ADD  HL,HL
            LD   E,L
            LD   D,H
            ADD  HL,HL
            ADD  HL,HL
            ADD  HL,DE
            LD   DE,CFBAS
            ADD  HL,DE
            OR   A
            RET

; A is ControlKind*. Return the new frame base in HL.
; Contract: in A out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B,C
CFPSHFR:
            LD   B,A
            LD   A,(CTDEP)
            CP   CFCAP
            JR   NC,CFCAPER
            INC  A
            LD   (CTDEP),A
            DEC  A
            CALL CFFRADR
            LD   (HL),B
            INC  HL
            LD   B,CFSZ-1
            XOR  A
CFCLRFR:
            LD   (HL),A
            INC  HL
            DJNZ CFCLRFR
            LD   DE,CFCTR-CFSZ
            ADD  HL,DE
            DEC  (HL)                    ; cleared zero -> ControlNoCounter
            LD   DE,-CFCTR
            ADD  HL,DE
            OR   A
            RET
CFCAPER:
            CALL DGINLINE
            DB  DGCTLCAP

; Contract: out A,DE,HL,carry,zero clobbers sign,parity,halfCarry
CFTOPFR:
            LD   A,(CTDEP)
            OR   A
            JR   Z,CFLPER
            DEC  A
            JR   CFFRADR

; Contract: in B out A,DE,HL,carry,zero clobbers sign,parity,halfCarry
CFTOFRFL:
            CALL CFTOPFR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   E,B
            LD   D,0
            ADD  HL,DE
            OR   A
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,HL
CFPOPFR:
            LD   HL,CTDEP
            LD   A,(HL)
            OR   A
            JR   Z,CFLPER
            DEC  (HL)
            XOR  A
            RET

%IF HybridLL1Full
; Contract: out A,C,DE,HL,carry,zero clobbers sign,parity,halfCarry,B
CFALCEXT:
            LD   B,CFEXIT
%ENDIF
; Contract: in B out A,C,DE,HL,carry,zero clobbers sign,parity,halfCarry
CFALCTO:
            LD   A,(CTNXLBL)
%IF AggregateCallSlices
            CP   S7CTLLIM
%ELSE
            ; Ordinal 31 is the retained routine entry.
            CP   CRLBL
%ENDIF
            JR   NC,CFLABER
            LD   C,A
            INC  A
            LD   (CTNXLBL),A
            CALL CFTOFRFL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   (HL),C
            RET

%IF HybridLL1Full
; Contract: in B out A,C,DE,HL,carry,zero clobbers sign,parity,halfCarry,B
LFFLOWLA:
            CALL LFPSFLFR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
; Contract: out A,B,C,DE,HL,carry,zero clobbers sign,parity,halfCarry
CFALLABA:
            LD   B,CFLBLA
%IF TargetStreamingOutput
            JR   CFALCTO
%ELSE
            JP   CFALCTO
%ENDIF
%ENDIF

CFLABER:
            CALL DGINLINE
            DB  DGCLBCAP
CFLPER:
            CALL DGINLINE
            DB  DXLOOP

; Emit operation D followed by byte C.
; Contract: in C,D out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
CFEOPBY:
            LD   A,D
            CALL TMOPER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,C
            JP   TMPUT

; Contract: in C out A,carry,zero clobbers sign,parity,halfCarry,B,D,DE,HL
CFELAB:
            LD   D,SMCTLLBL
            JR   CFEOPBY
; Contract: in C out A,carry,zero clobbers sign,parity,halfCarry,B,D,DE,HL
CFEBRFAL:
            LD   D,SMBRFALS
            JR   CFEOPBY
; Contract: in C out A,carry,zero clobbers sign,parity,halfCarry,B,D,DE,HL
CFEJP:
            LD   D,SMJUMP
            JR   CFEOPBY

; Return the nearest enclosing while/for frame in HL. A syntactic exit marks
; the particular while frame it targets; continues and counted loops retain
; their existing state.
; Contract: out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B,C
CFFINDLP:
            LD   A,(CTDEP)
            OR   A
            JR   Z,CFLPER
CFFILPNX:
            DEC  A
            PUSH AF
            CALL CFFRADR
            LD   A,(HL)
            CP   CKWHILE
            JR   Z,CFFILPFN
            CP   CKFOR
            JR   Z,CFFILPFN
            POP  AF
            OR   A
            JR   NZ,CFFILPNX
            JR   CFLPER
CFFILPFN:
            LD   E,A
            LD   A,(DCINFO)
            ADD  A,E
            CP   CKWHILE+TNEXIT
            JR   NZ,CFFILPRD
            PUSH HL
            LD   DE,CFMODE
            ADD  HL,DE
            LD   (HL),0
            POP  HL
CFFILPRD:
            POP  AF
            OR   A
            RET

; C is a local byte offset. Reject a source write or nested counter reuse while
; that exact local is the counter of any active counted loop.
; Contract: in C out A,carry,zero clobbers sign,parity,halfCarry,B,D,DE,HL
CFCKACCN:
            LD   A,(CTDEP)
            OR   A
            RET  Z
CFCKCNNX:
            DEC  A
            PUSH AF
            CALL CFFRADR
            LD   A,(HL)
            CP   CKFOR
            JR   NZ,CFCKCNCT
            LD   DE,CFCTR
            ADD  HL,DE
            LD   A,(HL)
            CP   C
            JR   Z,CFACCNER
CFCKCNCT:
            POP  AF
            OR   A
            JR   NZ,CFCKCNNX
            RET
CFACCNER:
            POP  AF
            CALL DGINLINE
            DB  DGACTCTR

%IF HybridLL1Full
%ELSE
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
SCPBLHDR:
            LD   A,TYBOOL
            CALL TYEXBGRU
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   E,TYBOOL
            CALL TYCKASG
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   PSXLN

; Parse an if/elseif/else chain. TokenIf has already been consumed.
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
SCPIF:
            LD   A,CKIF
            CALL CFPSHFR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   B,CFEXIT
            CALL CFALCTO
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   B,CFLBLA
            CALL CFALCTO
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   DE,CFCTR-1
            ADD  HL,DE
            LD   (HL),1
SCPIFCON:
            CALL SCPBLHDR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL CFTOPFR
            INC  HL
            LD   C,(HL)
            CALL CFEBRFAL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL TYPSTM
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL SCREIFCL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSPEEK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CP   TNELSEIF
            JR   Z,SCPELSIF
            CP   TNELSE
            JR   Z,SCPELS
            CP   TOKENEND
            JP   NZ,PSXSC
            CALL CFTOPFR
            INC  HL
            LD   C,(HL)
            CALL CFELAB
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   SCPIFEND
SCPELSIF:
            CALL SCEXITLA
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   B,CFLBLA
            CALL CFALCTO
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSTK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   SCPIFCON
SCPELS:
            CALL SCEXITLA
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSTK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXLN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL TYPSTM
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL SCREIFCL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   B,CFMODE
            CALL CFTOFRFL
            LD   (HL),1
            CALL PSPEEK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CP   TOKENEND
            JP   NZ,PSXSC
SCPIFEND:
            CALL PSTK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXLN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   B,CFEXIT
            CALL CFTOFRFL
            LD   C,(HL)
            CALL CFELAB
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   B,CFCTR
            CALL CFTOFRFL
            PUSH HL
            LD   A,(HL)
            POP  HL
            LD   DE,CFMODE-CFCTR
            ADD  HL,DE
            AND  (HL)
            XOR  1
            PUSH AF
            CALL CFPOPFR
            POP  AF
            RET

; Contract: out A,C,DE,HL,carry,zero clobbers sign,parity,halfCarry,B
SCEXITLA:
            LD   B,CFEXIT
            CALL CFTOFRFL
            LD   C,(HL)
            CALL CFEJP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL CFTOPFR
            INC  HL
            LD   C,(HL)
            JP   CFELAB
%ENDIF

; Contract: out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B
SCREIFCL:
            LD   B,CFCTR
            CALL CFTOFRFL
            LD   A,(CTFALLS)
            OR   A
            RET  Z
            LD   (HL),0
            XOR  A
            RET

; TokenWhile has already been consumed.
%IF HybridLL1Full
%ELSE
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
SCPWH:
            LD   A,CKWHILE
            CALL CFPSHFR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   B,CFLBLA
            CALL CFALCTO
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            INC  HL
            LD   (HL),C
            LD   B,CFEXIT
            CALL CFALCTO
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL CFTOPFR
            INC  HL
            LD   C,(HL)
            CALL CFELAB
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL SCPBLHDR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   B,CFEXIT
            CALL CFTOFRFL
            LD   C,(HL)
            CALL CFEBRFAL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL TYPSTM
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSPEEK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CP   TOKENEND
            JP   NZ,PSXSC
            LD   B,CFCONT
            CALL CFTOFRFL
            LD   C,(HL)
            CALL CFEJP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   B,CFEXIT
            CALL CFTOFRFL
            LD   C,(HL)
            CALL CFELAB
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
SCCMPLP:
            CALL PSTK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXLN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   CFPOPFR

; Parse bare exit/continue. The token has already been consumed.
; Contract: in A out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
SCPLPXF:
            LD   (DCINFO),A
            CALL CFFINDLP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   DE,CFEXIT
            LD   A,(DCINFO)
            CP   TNEXIT
            JR   Z,SCLPXFSE
            LD   DE,CFCONT
SCLPXFSE:
            ADD  HL,DE
            LD   C,(HL)
            CALL CFEJP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   PSXLN
%ENDIF

; Parse one compile-time integer expression. B returns direction bit 1 and DE
; returns the nonzero magnitude.
; Contract: out A,B,DE,carry,zero clobbers sign,parity,halfCarry,C,HL
SCPSTEP:
            CALL PSPEEK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   B,0
            CP   TNPLUS
            JR   Z,SCSTTKSG
            CP   TNMIN
            JR   NZ,SCSTEPEX
            LD   B,2
SCSTTKSG:
            PUSH BC
            CALL PSTK
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
SCSTEPEX:
            PUSH BC
            XOR  A
            CALL TYEXBGK
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   D,A
            AND  MTCONST
            JR   Z,SCSTEPER
            LD   A,D
            AND  MTTYPMSK
            CP   TYBOOL
            JR   Z,SCSTEPER
            LD   A,D
            CALL TYINFKTY
            OR   A
            JR   NZ,SCSTEPER
            LD   A,H
            OR   L
            JR   Z,SCSTEPER
            EX   DE,HL
            OR   A
            RET
SCSTEPER:
            LD   HL,EXVALPOS
            CALL DGRESTTK
            CALL DGINLINE
            DB  DGLOPSTP

; TokenFor has already been consumed.
%IF HybridLL1Full
%ELSE
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
SCPFOR:
            LD   E,TNNAME
            CALL PSEXPECT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,(TNSTOFF)
            LD   (EXCALOFF),HL
            CALL SBLOOKUP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   (DCINFO),A
            LD   (DCPAY),BC
            LD   D,A
            AND  SCMSK
            CP   SCLOC
            JP   NZ,SCCNTER
            LD   A,D
            AND  MTTYPMSK
            CP   TYBOOL
            JP   Z,SCCNTER
            CALL CFCKACCN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXEQ
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(DCINFO)
            AND  MTTYPMSK
            CALL TYEXBGRU
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   D,A
            LD   A,(DCINFO)
            AND  MTTYPMSK
            LD   E,A
            LD   A,D
            CALL TYCKASG
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSTK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CP   TOKENTO
            LD   B,1
            JR   Z,SCFORBND
            CP   TNUNT
            JP   NZ,SCCNTER
            LD   B,0
SCFORBND:
            PUSH BC
            LD   A,(DCINFO)
            AND  MTTYPMSK
            CALL TYEXBGRU
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   D,A
            PUSH BC
            LD   A,(DCINFO)
            AND  MTTYPMSK
            LD   E,A
            LD   A,D
            CALL TYCKASG
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   DE,1
            PUSH BC
            PUSH DE
            CALL PSPEEK
            POP  DE
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CP   TNSTEP
            JR   NZ,SCFOSTRD
            PUSH BC
            CALL PSTK
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            PUSH BC
            CALL SCPSTEP
            LD   A,B
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            OR   B
            LD   B,A
SCFOSTRD:
            PUSH BC
            PUSH DE
            CALL PSXLN
            POP  DE
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            PUSH BC
            PUSH DE
            LD   A,CKFOR
            CALL CFPSHFR
            POP  DE
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            PUSH BC
            PUSH DE
            LD   B,CFLBLA
            CALL CFALCTO
            POP  DE
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            PUSH BC
            PUSH DE
            LD   B,CFCONT
            CALL CFALCTO
            POP  DE
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            PUSH BC
            PUSH DE
            LD   B,CFEXIT
            CALL CFALCTO
            POP  DE
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            PUSH DE
            CALL CFTOPFR
            POP  DE
            PUSH HL
            INC  HL
            INC  HL
            INC  HL
            INC  HL
            LD   A,(DCPAY)
            LD   (HL),A
            INC  HL
            LD   A,(DCINFO)
            AND  MTTYPMSK
            LD   C,A
            BIT  4,C
            JR   Z,SCFOUSMD
            SET  3,B
SCFOUSMD:
            BIT  1,A
            JR   Z,SCFOMDRD
            SET  2,B
SCFOMDRD:
            LD   A,B
            LD   (HL),A
            INC  HL
            LD   (HL),E
            INC  HL
            LD   (HL),D
            INC  HL
            LD   DE,(EXCALOFF)
            LD   (HL),E
            INC  HL
            LD   (HL),D
            POP  HL
            CALL SCEFOSET
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL CFTOPFR
            INC  HL
            LD   C,(HL)
            CALL CFELAB
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL SCEFOTST
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL TYPSTM
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSPEEK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CP   TOKENEND
            JP   NZ,PSXSC
            LD   B,CFCONT
            CALL CFTOFRFL
            LD   C,(HL)
            CALL CFELAB
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL SCEFORNX
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   B,CFEXIT
            CALL CFTOFRFL
            LD   C,(HL)
            CALL CFELAB
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,SMFCLEAN
            CALL TMOPER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   SCCMPLP
%ENDIF
SCCNTER:
            CALL DGINLINE
            DB  DGLOPCTR

; Emit the fixed-width counted-loop records from the current frame.
; Contract: in A,HL out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
SCEFOPFX:
            PUSH HL
            CALL TMOPER
            POP  HL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   DE,CFCTR
            ADD  HL,DE
            LD   A,(HL)
%IF CompilerDiagnosticReturns
            PUSH HL
            CALL TMPUT
            POP  HL
%ELSE
            CALL TMPUTHL
%ENDIF
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            INC  HL
            RET

; Contract: in HL out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
SCEFOSET:
            LD   A,SMFORSET
            CALL SCEFOPFX
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(HL)
            JP   TMPUT

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
SCEFOTST:
            CALL CFTOPFR
            LD   A,SMFTEST
            CALL SCEFOPFX
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(HL)                  ; mode
%IF CompilerDiagnosticReturns
            PUSH HL
            CALL TMPUT
            POP  HL
%ELSE
            CALL TMPUTHL
%ENDIF
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   B,CFEXIT
            CALL CFTOFRFL
            LD   A,(HL)                  ; exit label
            JP   TMPUT
SCEFRBY:
            LD   A,(HL)
            PUSH BC
%IF CompilerDiagnosticReturns
            PUSH HL
            CALL TMPUT
            POP  HL
%ELSE
            CALL TMPUTHL
%ENDIF
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            INC  HL
            DJNZ SCEFRBY
            RET

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
SCEFORNX:
            CALL CFTOPFR
            PUSH HL
            LD   A,SMFNEXT
            CALL TMOPER
            POP  HL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   DE,CFLBLA
            ADD  HL,DE
            LD   A,(HL)                  ; test label
%IF CompilerDiagnosticReturns
            PUSH HL
            CALL TMPUT
            POP  HL
%ELSE
            CALL TMPUTHL
%ENDIF
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            INC  HL                     ; continue label
            INC  HL                     ; exit label
            LD   A,(HL)
%IF CompilerDiagnosticReturns
            PUSH HL
            CALL TMPUT
            POP  HL
%ELSE
            CALL TMPUTHL
%ENDIF
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            INC  HL                     ; counter
            LD   B,6                    ; counter, mode, step, trap offset
            JR   SCEFRBY
