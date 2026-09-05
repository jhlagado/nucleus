; Explicit semantic actions for the complete Stage 7 packed LL(1) grammar.
; These routines never select grammar productions. They consume only retained
; expression/type-directed external islands declared by the generated grammar.

; Aggregate initializer staging is dead while a routine body is parsed, so
; the for/flow action scratch safely reuses its first thirteen bytes.
LFFORMD       EQU AIBAS
LFFORSTP       EQU LFFORMD+1
LFFLSTBA EQU LFFORSTP+2
LFSTEND EQU LFFLSTBA+CFCAP

; Contract: out A,B,DE,carry,zero clobbers sign,parity,halfCarry,C,HL
LASTEPC:
            CALL SCPSTEP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(LFFORMD)
            OR   B
            LD   (LFFORMD),A
            LD   (LFFORSTP),DE
            OR   A
            RET

; The declared type has already selected the initializer shape. This external
; island retains the recursive, type-directed aggregate initializer machinery.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
LASTATIC:
            LD   A,(DCINFO)
            LD   B,A
            PUSH BC
            CALL APPINI
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,B
            LD   (DCINFO),A
            OR   A
            RET

LACLAUSE:
            CALL DGINLINE
            DB  DXEND

LASELERR EQU LACLAUSE

; --------------------------------------------------------------- type actions

; A is the logical action ordinal for the contiguous u8/u16/Boolean family.
LASCALAR:
            SUB  LATYU8-1
            CP   3
            JR   C,LFSECUTY
            ADD  A,13
LFSECUTY:
            LD   (ACTYPID),A
            OR   A
            RET

; Contract: out A,BC,carry,zero clobbers sign,parity,halfCarry,D,DE,HL,IX,IY
LARECTYP:
            CALL SBLOOKUP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   D,A
            LD   (DCINFO),A
            LD   (DCPAY),BC
            AND  SYRECTYP+SYAGGFLG
            CP   SYRECTYP
            JP   NZ,APTYSHER
            LD   A,C
            JR   LFSECUTY

LATYBND:
LFXU16:
            LD   A,TYU16
            JR   LFSVXTY

; Return the checked, positive, byte-sized constant bound in HL.
; Contract: out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B,C,IX,IY
LFCKBND:
            LD   A,(EXRMETA)
            LD   D,A
            AND  MTCONST
            JP   Z,APTYSHER
            LD   E,TYU16
            LD   A,D
            CALL TYCKASG
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,(EXRVAL)
            LD   A,H
            OR   L
            JP   Z,APTYSHER
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
LASTRTYP:
            CALL LFCKBND
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,H
            OR   A
            JP   NZ,APSTCAER
            LD   A,L
            CP   254
            JP   NC,APSTCAER
            LD   A,L
            LD   (ANAUX),A
            LD   (ANLEN),HL
            LD   A,ATKSTR
            LD   (ANKIND),A
            INC  HL
            INC  HL
            LD   (ANEXT),HL
LFINCUTY:
            CALL APINTY
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   LFSECUTY

; `string[]` is a parameter-only view rather than an interned object type.
LAOSTRTY:
            LD   A,AGOSTR
            JR   LFSECUTY

LAARRTYP EQU APBGARTY

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
LAARRDIM:
            CALL LFCKBND
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   APSVARDI

LAOARDIM EQU APSOARDI

LAARRFIN EQU APFIARTY

; --------------------------------------------------------- scalar constants

LARETNAM EQU TYRTDCNM

LFSVXTY:
            LD   (EXEXPTYP),A
            OR   A
            RET

; Contract: out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B,C,IX,IY
LACONEND:
            LD   HL,(EXRVAL)
            LD   A,(EXRMETA)
            LD   D,A
            AND  MTCONST
            JP   Z,TYTYER
            LD   A,D
            CALL TYINFKTY
LFKTYRD:
            LD   (DCINFO),A
            LD   HL,(EXRVAL)
            LD   (DCPAY),HL
            OR   A
            RET

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
LACONSET:
            LD   A,(DCINFO)
            OR   SCCONST
            LD   D,A
            LD   BC,(DCPAY)
            CALL TYPRCUWD
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   SBCOMMIT

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LAAGCSET:
%IF TargetStreamingOutput
            CALL S7ABKRDO
            LD   (DCINFO),A
            LD   (DCPAY),BC
            LD   A,(DCINFO)
            RLCA
            RLCA
            RLCA
            RLCA
            OR   SYAGGFLG+SCCONST
            LD   (DCINFO),A
%ENDIF
            LD   BC,(ROILEN)
            LD   D,SYAGGFLG+SCCONST
%IF TargetStreamingOutput
            LD   A,(DCINFO)
            LD   D,A
            LD   BC,(DCPAY)
%ENDIF
            CALL TYPRCUWD
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(ACTYPID)
            INC  HL
            LD   (HL),A
            CALL S7ARDOOB
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   SBCOMMIT

LAASSERT EQU TYRDNMRD

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
LAASRTEN:
            CALL LFRSSUNM
            LD   A,(EXRMETA)
            AND  MTCONST+MTTYPMSK
            CP   MTCONST+TYBOOL
            JR   NZ,LFASTYER
            LD   A,(EXRVAL)
            OR   A
            RET  NZ
            CALL DGINLINE
            DB  DGASSERT
LFASTYER:
            CALL DGINLINE
            DB  DGTYPMIS

; ------------------------------------------------------ program declarations

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
LAPROGTY:
LFSVOBTY:
            CALL APROVWPL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   (DCINFO),A
            CALL APGETEXT
            LD   (ACOBJEXT),HL
            LD   (ACOBJEND),HL
            LD   HL,0
            LD   (ACOBJOFF),HL
            CALL APZCUOBJ
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            XOR  A
            LD   (AIDEP),A
            LD   (AGHASINI),A
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
LAAGCTYP:
            LD   A,(ACTYPID)
            CP   AGDYNTYP
            JP   C,TYTYER
            JR   LFSVOBTY

LAPINIEN:
            LD   A,1
            LD   (AGHASINI),A
            LD   HL,(ACOBJOFF)
            LD   DE,(ACOBJEND)
            OR   A
            SBC  HL,DE
            JP   NZ,APINCNER
            OR   A
            RET

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LAPRGVAR:
            LD   A,(AGHASINI)
            OR   A
            JR   NZ,LFALDAOB
            JR   LFALBSOB
LFCMOBRD:
            PUSH BC
            LD   A,(DCINFO)
            CP   AGDYNTYP
            JR   C,LFPGSCIN
            LD   D,SIAGPROG
            JR   LFPGPRSY
LFPGSCIN:
            OR   SCPROG
            LD   D,A
LFPGPRSY:
            CALL TYPRCUWD
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(DCINFO)
            CALL SBCOMTY
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            OR   A
            RET

; Return the absolute target address of one initialized program object in BC.
; The complete prepared bytes are appended to the rodata-backed data image.
LFALDAOB:
            LD   DE,(IMGLEN)
            CALL LFALOBEN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            PUSH HL
            LD   DE,(ROILEN)
            ADD  HL,DE
            CALL APCKEXCA
            POP  HL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   (IMGLEN),HL
            LD   BC,(ROILEN)
            LD   A,B
            OR   C
            JR   Z,LFDASHRD
            LD   HL,IMGBAS
            LD   DE,(ACOBJOFF)
            ADD  HL,DE
            ADD  HL,BC
            DEC  HL
            LD   DE,(ACOBJEXT)
            PUSH HL
            ADD  HL,DE
            EX   DE,HL
            POP  HL
            LDDR
LFDASHRD:
            LD   BC,(ACOBJEXT)
            LD   HL,AIBAS
            LD   DE,(ACOBJOFF)
            PUSH HL
            LD   HL,IMGBAS
            ADD  HL,DE
            EX   DE,HL
            POP  HL
            LDIR
            LD   BC,(ACOBJOFF)
%IF TargetStreamingOutput
            ; Target transcripts retain a segment-relative offset. Bit 15 is
            ; clear for initialized data and set for BSS.
%ELSE
            LD   HL,MMDATA
            ADD  HL,BC
            LD   B,H
            LD   C,L
%ENDIF
            OR   A
            JR   LFCMOBRD

; Return the absolute target address of one default-initialized object in BC.
LFALBSOB:
            LD   DE,(PGBSSLEN)
            CALL LFALOBEN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   (PGBSSLEN),HL
            LD   B,D
            LD   C,E
%IF TargetStreamingOutput
            SET  7,B
%ELSE
            LD   HL,MMBSS
            ADD  HL,BC
            LD   B,H
            LD   C,L
%ENDIF
            OR   A
%IF TargetStreamingOutput
            JR   LFCMOBRD
%ELSE
            JP   LFCMOBRD
%ENDIF

; Add the current object extent to the selected segment length in DE. Return
; the old offset in DE and the checked mathematical end in HL.
; Contract: in DE out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B
LFALOBEN:
            LD   (ACOBJOFF),DE
            LD   HL,(ACOBJEXT)
            LD   DE,(ACOBJOFF)
            ADD  HL,DE
LFCPSEEN:
; Initialized data and BSS use the same exact 1 KiB extent rule and diagnostic
; as complete aggregate objects.
            JP   APCKEXCA

; ---------------------------------------------------------- record metadata

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
LARECORD:
            CALL TYRTDCNM
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(ATCNT)
            CP   ATCAP
            JP   NC,APTYCAER
            LD   A,(ARCNT)
            CP   ARCAP
            JP   NC,APTYCAER
            LD   A,(AFCNT)
            LD   (ACFLDST),A
            XOR  A
            LD   (ACFLDCNT),A
            LD   H,A
            LD   L,A
            LD   (ACRECEXT),HL
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
LAFIELD:
            CALL APCKFLDU
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(AFCNT)
            CP   AFCAP
            JP   NC,APTYCAER
            PUSH AF
            CALL APFLDADR
            CALL TKRETAIN
            POP  AF
            OR   A
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
LAFLDEND:
            CALL APROVWCU
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(AFCNT)
            CALL APFLDADR
            INC  HL
            INC  HL
            INC  HL
            LD   A,(ACTYPID)
            LD   (HL),A
            INC  HL
            LD   DE,(ACRECEXT)
            LD   (HL),E
            INC  HL
            LD   (HL),D
            LD   A,(ACTYPID)
            PUSH DE
            CALL APGETEXT
            POP  DE
            ADD  HL,DE
            JP   C,APPDCAER
            CALL APCKEXCA
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   (ACRECEXT),HL
            LD   HL,ACFLDCNT
            INC  (HL)
            LD   HL,AFCNT
            INC  (HL)
            XOR  A
            RET

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
LARECEND:
            LD   A,(ACFLDCNT)
            OR   A
            JP   Z,APREEMER
            LD   A,ATKREC
            LD   (ANKIND),A
            LD   HL,(ACFLDST)
            LD   (ANAUX),HL
            XOR  A
            LD   (ANLEN+1),A
            LD   HL,(ACRECEXT)
            LD   (ANEXT),HL
            CALL APAPPTY
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   (ACTYPID),A
            LD   D,SIRECTYP
            LD   A,(ACTYPID)
            LD   C,A
            LD   B,0
            CALL TYPRCUWD
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL SBCOMMIT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,ARCNT
            INC  (HL)
            XOR  A
            RET

; ----------------------------------------------------- Stage 7 routines/main

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,DE,HL
LABEFMN:
            LD   A,DXEOF

; A selects the exact diagnostic if the current signature is main. Ordinary
; routines return normally; compiler diagnostics retain the caller's token.
; Contract: in A out A,carry,zero clobbers sign,parity,halfCarry,D,DE,HL
LFRENOMA:
            LD   D,A
            LD   A,(C7RTN)
            INC  A
            RET  NZ
            LD   A,D
            JP   DGSET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL,IX,IY
LAREQMN:
            LD   A,(C7RTN)
            INC  A
            JR   Z,LFREORFW
            LD   A,(S8FMFLG)
            AND  S8RTNINC
            JR   NZ,LFINCFW
            JR   LFMISMAI
LFREORFW:
            LD   A,(R7CNT)
            LD   B,A
            XOR  A
            LD   C,A
LFREFWLP:
            LD   A,B
            OR   A
            RET  Z
            LD   A,C
            CALL S7RTADR
            LD   DE,R7FLGS
            ADD  HL,DE
            LD   A,(HL)
            AND  S8RTNINC
            JR   NZ,LFINCFW
            INC  C
            DEC  B
            JR   LFREFWLP
LFMISMAI:
            CALL DGINLINE
            DB  DXTOPLVL
LFINCFW:
            CALL DGINLINE
            DB  DGFWDINC

; The grammar deliberately treats the lexeme `main` as the same NAME token as
; ordinary routine names. This action is the one semantic discriminator.
LASUBNAM EQU TYRDNMRD

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
LFRSSUNM:
            CALL TYRSDCTK
            LD   HL,DCNAMPOS
            CALL DGRESTTK
            OR   A
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry
LFRPANRE:
            XOR  A
            LD   (C7PARCNT),A
            LD   (C7RESTYP),A
            RET

%IF CompilerDiagnosticReturns
%ELSE
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
LFCLSUNM:
            CALL LFRSSUNM
            CALL LABEFMN
            JP   TYNMEQMA
%ENDIF

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
LASUB:
%IF CompilerDiagnosticReturns
            CALL LFRSSUNM
            CALL LABEFMN
            RET  C
            CALL TYNMEQMA
%ELSE
            CALL LFCLSUNM
%ENDIF
            JR   C,LFBGMASI
            LD   A,(R7CNT)
            CP   R7CAP
            JR   NC,LFRTCAER
            CALL S7RCDCNM
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(R7CNT)
            LD   (C7RTN),A
            CALL S7RTADR
            CALL TKRETAIN
            INC  HL
            LD   A,(P7CNT)
            LD   (HL),A
            LD   (C7PARST),A
            CALL LFRPANRE
%IF TargetStreamingOutput
            CALL FTPKCUBK
%ENDIF
            LD   (C7FLGS),A
            RET
LFBGMASI:
%IF TargetStreamingOutput
            CALL FTRESRBK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%ENDIF
            LD   A,(S8FMFLG)
            AND  S8RTNINC
            JP   NZ,TYDUNMER
            CALL S7RCDCNM
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,$FF
            LD   (C7RTN),A
            CALL LFRPANRE
            LD   A,R7MAIN
%IF TargetStreamingOutput
            CALL FTPKCUBK
%ENDIF
            LD   (C7FLGS),A
            RET
LFRTCAER:
            CALL DGINLINE
            DB  DGRTNCAP

; A forward uses the ordinary signature builder, then publishes that sole
; signature without opening a body or emitting code.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
LAFORWRD:
            CALL LASUB
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   B,S8RTNINC
            JR   LFSERTFL

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
LAFWDEND:
            LD   A,(C7RTN)
            INC  A
            JR   Z,LFCMFWMA
            DEC  A
            CALL LFPUBRT
            XOR  A
            RET
LFCMFWMA:
            LD   A,(C7FLGS)
            LD   (S8FMFLG),A
            XOR  A
            LD   (C7RTN),A
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
LAPARNAM:
            LD   A,DXRPAR
            CALL LFRENOMA
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL S7CPDCNM
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,DCNAMPTR
            CALL TKRETAIN
%IF TargetStreamingOutput
%IF DebugHooks
            OUT  (DTDECL),A
%ENDIF
%ENDIF
            OR   A
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
LAPARSET:
            CALL TYRSDCTK
            LD   A,(ACTYPID)
            JP   S7APPPAR

LARESOK:
            LD   A,DXLINE
            JP   LFRENOMA

LARESTYP:
            CALL APROVWPL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   (C7RESTYP),A
            OR   A
            RET

LASUBFL:
            LD   B,R7FAILS
LFSERTFL:
            LD   A,(C7FLGS)
            OR   B
            LD   (C7FLGS),A
            OR   A
            RET

; Open the abbreviated body of one exact incomplete forward and recover its
; sole stored signature, including the original parameter spellings.
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LAFWDBDY:
%IF CompilerDiagnosticReturns
            CALL LFRSSUNM
            CALL LABEFMN
            RET  C
            CALL TYNMEQMA
%ELSE
            CALL LFCLSUNM
%ENDIF
            JR   C,LFBFMABD
            CALL S7FIRTCU
            JR   NZ,LFFWMIS
            LD   (C7RTN),A
            CALL S7RTADR
            LD   DE,R7PARST
            ADD  HL,DE
            LD   DE,C7PARST
            LD   BC,4
            LDIR
            LD   A,(HL)
            BIT  2,A
            JP   Z,TYDUNMER
%IF TargetStreamingOutput
            LD   D,A
            PUSH AF
            PUSH HL
            CALL FTRECUBK
%IF CompilerDiagnosticBranches
            JR   C,LFFWBKER
%ENDIF
            POP  HL
            POP  AF
%ENDIF
            AND  $FB
            LD   (HL),A
            LD   (C7FLGS),A
            JR   LFOPRTBD
%IF TargetStreamingOutput
%IF CompilerDiagnosticBranches
LFFWBKER:
            POP  HL
            POP  AF
            SCF
            RET
%ENDIF
%ENDIF
LFBFMABD:
%IF TargetStreamingOutput
            CALL FTRESRBK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%ENDIF
            LD   A,(S8FMFLG)
            BIT  2,A
            JR   Z,LFFWMIS
            AND  $FB
            LD   (C7FLGS),A
            LD   (S8FMFLG),A
            CALL LFRPANRE
            DEC  A
            LD   (C7RTN),A
%IF CompilerNonlocalDiagnostics
            JR   LFBGMABD
%ELSE
            JP   LFBGMABD
%ENDIF
LFFWMIS:
            CALL DGINLINE
            DB  DGUNKNAM

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LASUBODY:
            LD   A,(C7RTN)
            INC  A
%IF CompilerNonlocalDiagnostics
            JR   Z,LFBGMABD
%ELSE
            JP   Z,LFBGMABD
%ENDIF
            DEC  A
            CALL LFPUBRT
            JR   LFOPRTBD

; Contract: in A out A,BC,DE,HL clobbers carry,zero,sign,parity,halfCarry
LFPUBRT:
            CALL S7RTADR
            LD   DE,R7PARCNT
            ADD  HL,DE
            EX   DE,HL
            LD   A,(C7RTN)
            ADD  A,R7LBLBAS
            LD   (S7CALLBL),A
            LD   HL,C7PARCNT
            LD   BC,4
            LDIR
            LD   HL,R7CNT
            INC  (HL)
            RET
%IF TargetStreamingOutput
; Contract: in A out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
LFPTCUBK:
            CALL TMPUT
            LD   A,(C7FLGS)
            CALL FTUPKBK
            JP   TMPUT
%ENDIF

; Contract: out A,carry,zero clobbers sign,parity,halfCarry
LFSGRSLO:
            LD   A,(SYCNT)
            LD   (S7GLBCNT),A
            XOR  A
            LD   (NXLOCAL),A
            LD   (CTDEP),A
            RET
LFOPRTBD:
            CALL LFSGRSLO
%IF TargetStreamingOutput
%ELSE
            LD   A,(C7RESTYP)
            OR   A
            LD   A,CRVAL
            JR   NZ,LFRTKDRD
            XOR  A
LFRTKDRD:
            LD   (CRKIND),A
            LD   A,(C7RESTYP)
            LD   (CTRESTYP),A
%ENDIF
            LD   A,1
            LD   (CTFALLS),A
%IF TargetStreamingOutput
%IF DebugHooks
            OUT  (DTROUT),A
%ENDIF
%ENDIF
            LD   A,(S7CALLBL)
            LD   C,A
            LD   A,SMBGGRTN
            CALL PSEOPC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(C7PARCNT)
%IF TargetStreamingOutput
            CALL LFPTCUBK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%ELSE
            CALL TMPUT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%ENDIF
            LD   A,(C7PARCNT)
            LD   B,A
            LD   A,(C7PARST)
            LD   D,A
            XOR  A
            LD   E,A
LFINPALP:
            LD   A,B
            OR   A
            RET  Z
            CALL S7PAROFF
            LD   A,D
            PUSH DE
            PUSH BC
            CALL S7INSPAR
            POP  BC
            POP  DE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            INC  D
            INC  E
            DEC  B
            JR   LFINPALP

LFBGMABD:
            LD   A,(C7FLGS)
            LD   (S8FMFLG),A
%IF TargetStreamingOutput
%IF DebugHooks
            OUT  (DTROUT),A
%ENDIF
%ENDIF
            LD   A,SMBGCMN
            CALL TMOPER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(C7FLGS)
%IF TargetStreamingOutput
            CALL LFPTCUBK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%ELSE
            CALL TMPUT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%ENDIF
            CALL LFSGRSLO
%IF TargetStreamingOutput
%ELSE
            LD   (C7RESTYP),A
            LD   (CRKIND),A
%ENDIF

; Contract: out A,carry,zero clobbers sign,parity,halfCarry
LFSEFLTH:
            LD   A,1
            JR   LFSTFL

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LASUBEND:
            LD   A,(C7RTN)
            INC  A
            JR   Z,LFENMABD
            LD   A,(C7RESTYP)
            OR   A
            JR   Z,LFENDRTE
            LD   A,(CTFALLS)
            OR   A
            JP   NZ,TYRTFLER
LFENDRTE:
%IF TargetStreamingOutput
%IF DebugHooks
            OUT  (DTPOP),A
%ENDIF
%ENDIF
            CALL LFERTEND
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(C7RESTYP)
            CALL TMPUT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(S7GLBCNT)
            LD   (SYCNT),A
            XOR  A
            LD   (NXLOCAL),A
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
LFERTEND:
            CALL LFTSRTER
            LD   A,SMENGRTN
            JR   Z,LFERENSE
            LD   A,SMENFRTN
LFERENSE:
            JP   TMOPER

; Contract: out A,carry,zero clobbers sign,parity,halfCarry
LFTSRTER:
            LD   A,(C7FLGS)
            AND  R7FAILS
            RET
LFENMABD:
%IF TargetStreamingOutput
%IF DebugHooks
            OUT  (DTPOP),A
%ENDIF
%ENDIF
            CALL LFERTEND
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            XOR  A
            JP   TMPUT

; ------------------------------------------------------ recoverable failure

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
LAFAIL:
%IF TargetStreamingOutput
%IF DebugHooks
            OUT  (DTSOURCE),A
%ENDIF
%ENDIF
            CALL LFTSRTER
            JR   Z,LFERCX
            LD   HL,(TNSTOFF)
            LD   (S8FAIOFF),HL
            LD   A,TYU8
            JP   LFSVXTY

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LAFAILEN:
            LD   E,TYU8
            CALL LFCKERRE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,SMFAILRT
LFEROPRD:
            CALL TMOPER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,(S8FAIOFF)
            LD   A,L
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
            LD   A,H
            CALL TMPUT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
LFNOFL:
            XOR  A
; Contract: in A out A,carry,zero clobbers sign,parity,halfCarry
LFSTFL:
            LD   (CTFALLS),A
            OR   A
            RET

; Validate one scalar fail/return value and reject an unconsumed nested
; recoverable failure.
; Contract: in E out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B,C,IX,IY
LFCKERRE:
            LD   A,(EXRMETA)
            LD   HL,(EXRVAL)
            CALL TYCKASG
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   S8RNPNER
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
LFERCX:
            CALL DGINLINE
            DB  DGFAICTX

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
; Both callers have already observed a nonzero Stage8DirectFailable. The
; generic entry checks the token; the selected entry reuses its caller's peek.
S8CNSPRO:
            CALL PSPEEK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CP   TNELSE
            JR   NZ,LFERCX
S8CNPRSE:
            CALL LFTSRTER
            JR   Z,LFERCX
            CALL PSTK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   E,TNFAIL
            CALL PSEXPECT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSPEEK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CP   TNHDL
            JR   Z,LFERCX
            CP   TNELSE
            JR   Z,LFERCX
            LD   A,M8PROP
S8PRMDRD:
            LD   HL,(M8PTR)
            LD   (HL),A
            INC  HL
            INC  HL
            LD   A,(S8CARR)
            LD   (HL),A
S8CLPNER:
            XOR  A
            LD   (S8DIRFBL),A
            LD   (S8CARR),A
            RET

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
S8SEERCN:
            LD   A,(S8DIRFBL)
            OR   A
            JR   NZ,S8SEPNER
            LD   (S8CARR),A
            CALL PSPEEK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CP   TNELSE
            JR   Z,LFERCX
            CP   TNHDL
            JP   Z,LLHANDLE
            OR   A
            RET

; Address the selected field of the active control frame and load its byte.
; Callers have already established the frame precondition.
; Contract: in B out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
LFFLDTOC:
            CALL CFTOFRFL
            LD   C,(HL)
            LD   A,C
            RET

S8SEPNER:
            CALL PSPEEK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            DEC  A                       ; newline becomes zero
            JP   Z,LLHANDLE
            CP   TNELSE-1
            JR   Z,S8CNPRSE
            CP   TNHDL-1
            JR   NZ,LFERCX
            LD   B,CKHDL
            CALL LFFLOWLA
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL CFALCEXT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,(M8PTR)
            LD   (HL),M8HDL
            LD   B,CFLBLA
            CALL LFFLDTOC
            LD   HL,(M8PTR)
            INC  HL
            LD   (HL),C
            INC  HL
            LD   A,(S8CARR)
            LD   (HL),A
            JR   S8CLPNER

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
S8KEEPER:
            LD   A,1
            LD   (S8CARR),A
            JR   S8SEERCN

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LFLKDC:
            CALL SBLOOKUP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   (DCINFO),A
            LD   (DCPAY),BC
            LD   D,A
            RET

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LAHANDLE:
%IF TargetStreamingOutput
%IF DebugHooks
            OUT  (DTSOURCE),A
            OUT  (DTPUSH),A
%ENDIF
%ENDIF
            CALL LFLKDC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL TYRSSYCL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   Z,TYTYER
            CP   SCLOC
            JR   NZ,S8HNCNRD
            CALL CFCKACCN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
S8HNCNRD:
            CALL TYDCSCTY
            CP   TYU8
            JP   NZ,TYTYER
            LD   B,CFEXIT
            CALL LFFLDTOC
            LD   D,SMSKIPHD
            CALL CFEOPBY
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   B,CFLBLA
            CALL LFFLDTOC
            LD   D,SMBEGHDL
            CALL CFEOPBY
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(DCINFO)
            CALL TMPUT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            AND  SCMSK
            CP   SCPROG
            LD   HL,(DCPAY)
            JR   Z,LFBHPGPA
            LD   A,L
            CALL TMPUT
            JR   LFBHPARD
LFBHPGPA:
            CALL S7EWD
LFBHPARD:
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   LFSEFLTH

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LAHDLEND:
%IF TargetStreamingOutput
%IF DebugHooks
            OUT  (DTPOP),A
%ENDIF
%ENDIF
            LD   B,CFEXIT
            CALL LFFLDTOC
            LD   D,SMENDHDL
            CALL CFEOPBY
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,1
            JP   LFCMBFL

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
S8RNPNER:
            LD   A,(S8DIRFBL)
            OR   A
            RET  Z
            JP   LFERCX

; ------------------------------------------------------------- local scalars

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
LALOCTYP:
%IF TargetStreamingOutput
%IF DebugHooks
            OUT  (DTSOURCE),A
%ENDIF
%ENDIF
            LD   A,(ACTYPID)
            OR   SCLOC
            LD   (DCINFO),A
            LD   A,(NXLOCAL)
            LD   C,A
            LD   B,0
            LD   (DCPAY),BC
            PUSH BC
            LD   A,(DCINFO)
            LD   D,A
            CALL TYPRRTWD
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL TYDCSCTY
            CALL TYELOCDC
LFSLOXTY:
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL TYDCSCTY
            JP   LFSVXTY

LALOCINI:
            CALL TYDCSCTY
            JP   LFSVXTY

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
LALOCDEF:
            LD   A,1
            LD   (EXEMITON),A
            LD   A,SMLIT16
            CALL TMEOPER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,0
%IF CompilerNonlocalDiagnostics
            LD   (EXRVAL),HL
%ENDIF
            CALL TMEWORD
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL TYDCSCTY
            OR   MTCONST
            LD   (EXRMETA),A
%IF CompilerNonlocalDiagnostics
%ELSE
            LD   HL,0
            LD   (EXRVAL),HL
%ENDIF
            OR   A
            RET

; Contract: out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B,C,IX,IY
LALOCEND:
            CALL LFVADCEX
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(S8DIRFBL)
            OR   A
            JP   NZ,S8CNSPRO
            CALL PSPEEK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CP   TNELSE
            JP   Z,LFERCX
            OR   A
            RET

; Contract: out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B,C,IX,IY
LFVADCEX:
            CALL TYDCSCTY
            LD   E,A

; Contract: in E out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B,C,IX,IY
LFCKEXAS:
            LD   HL,(EXRVAL)
            LD   A,(EXRMETA)
            JP   TYCKASG

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LALOCSET:
            LD   A,(DCINFO)
            LD   D,A
            LD   A,(DCPAY)
            LD   C,A
            CALL TYESBYIN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL SBCOMMIT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL TYDCSCTY
            JP   S7ISCPAW

; ------------------------------------------------------------ simple statements

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LANAMSTM:
%IF TargetStreamingOutput
%IF DebugHooks
            OUT  (DTSOURCE),A
%ENDIF
%ENDIF
            CALL PSTK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,(TNSTOFF)
            LD   (EXCALOFF),HL
            LD   (S7CALOFF),HL
            CALL S8MTPRCU
            JR   NC,LFORNMST
            CP   P8CONST
            JP   NC,TYTYER
            LD   C,B
            CALL S8PSVCCL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   S8SEERCN
LFORNMST:
            CALL S7FIRTCU
            JR   NZ,LFPASG
            LD   C,0
            CALL S7PCL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   S8SEERCN
LFPASG:
            CALL LFLKDC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            AND  SYAGGFLG
            JP   NZ,S7PAGASG
            LD   A,D
            CALL TYRSSYCL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CP   SCLOC
            JR   NZ,LFSTCNCK
            CALL CFCKACCN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(DCINFO)
            LD   D,A
LFSTCNCK:
            LD   A,D
            AND  SCMSK
            JP   Z,TYTYER
            CALL PSXEQ
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL TYDCSCTY
            CALL TYEXBGRU
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   D,A
            CALL TYDCSCTY
            LD   E,A
            LD   A,D
            CALL TYCKASG
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL S8SEERCN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   BC,(DCPAY)
            LD   A,(DCINFO)
            LD   D,A
            JP   TYESBYIN
LARETVBG:
%IF TargetStreamingOutput
%IF DebugHooks
            OUT  (DTSOURCE),A
%ENDIF
%ENDIF
            LD   A,(C7RESTYP)
            OR   A
            RET  Z
            CP   AGDYNTYP
            RET  NC
            JP   LFSVXTY

%IF TargetStreamingOutput
; Contract: out A,carry,zero clobbers sign,parity,halfCarry
LFRERETY:
            LD   A,(C7RESTYP)
            OR   A
            JP   Z,TYRTFLER
            CP   AGDYNTYP
            RET
%ENDIF

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LARETVAL:
%IF TargetStreamingOutput
            CALL LFRERETY
%ELSE
            LD   A,(C7RESTYP)
            OR   A
            JP   Z,TYRTFLER
            CP   AGDYNTYP
%ENDIF
            JR   NC,LFRETAGV
            CALL TYEXBGRU
            JP   LFSVEXRE
LFRETAGV:
            CALL S7PAGV
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   (S7PATHT),A
            OR   A
            RET

LARETSET:
%IF TargetStreamingOutput
            CALL LFRERETY
%ELSE
            LD   A,(C7RESTYP)
            OR   A
            JP   Z,TYRTFLER
            CP   AGDYNTYP
%ENDIF
            JR   NC,LFCMAGRE
            LD   E,A
            CALL LFCKERRE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL LFTSRTER
            LD   A,SMRETSCA
            JR   Z,LFRESCSE
            LD   A,SMRTFS
LFRESCSE:
            CALL TMOPER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   LFRETCM
LFCMAGRE:
            LD   D,A
            LD   A,(S7PATHT)
            CP   D
            JP   NZ,TYTYER
            CALL S8RNPNER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL LFTSRTER
            LD   A,SMRETAGG
            JR   Z,LFREAGSE
            LD   A,SMRTFA
LFREAGSE:
            CALL TMOPER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
LFRETCM:
            JP   LFNOFL

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LARETNON:
            LD   A,(C7RESTYP)
            OR   A
            JP   NZ,TYRTFLER
            CALL LFERTEND
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            XOR  A
            CALL TMPUT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   LFRETCM

; A is the logical action ordinal. The two ordinals and tokens are contiguous.
LAXFER:
%IF TargetStreamingOutput
%IF DebugHooks
            OUT  (DTSOURCE),A
%ENDIF
%ENDIF
            DEC  A
LFEXF:
            LD   (DCINFO),A
            CALL CFFINDLP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   DE,CFEXIT
            LD   A,(DCINFO)
            CP   TNEXIT
            JR   Z,LFXFSEL
            LD   DE,CFCONT
LFXFSEL:
            ADD  HL,DE
            LD   C,(HL)
            JP   CFEJP

; ---------------------------------------------------------- structured flow

; Save the enclosing statement sequence's fallthrough bit, then push the
; control-frame kind supplied in B.
; Contract: in B out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B,C
LFPSFLFR:
            LD   A,(CTDEP)
            CP   CFCAP
            JP   NC,CFCAPER
            CALL LFFLADR
            LD   A,(CTFALLS)
            LD   (HL),A
            LD   A,B
            JP   CFPSHFR

; Contract: out A,DE,HL clobbers carry,zero,sign,parity,halfCarry
LFFLADR:
            LD   A,(CTDEP)
            LD   E,A
            LD   D,0
            LD   HL,LFFLSTBA
            ADD  HL,DE
            RET

; The frame has already been popped. Restore its enclosing sequence bit.
; Contract: out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B,C
LFRSTFL:
            CALL LFFLADR
            LD   A,(HL)
            JP   LFSTFL

; A is the completed compound statement's fallthrough bit.
; Contract: in A out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B,C
LFCMBFL:
            LD   B,A
            CALL CFPOPFR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL LFFLADR
            LD   A,(HL)
            AND  B
            JP   LFSTFL

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LFCKBLRE:
            LD   E,TYBOOL
LFCKTYRE:
            CALL S8RNPNER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   LFCKEXAS

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LAIF:
%IF TargetStreamingOutput
%IF DebugHooks
            OUT  (DTSOURCE),A
            OUT  (DTPUSH),A
%ENDIF
%ENDIF
            LD   B,CKIF
            CALL LFPSFLFR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL CFALCEXT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL CFALLABA
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   DE,CFCTR-CFLBLA
            ADD  HL,DE
            LD   (HL),1
LFXBL:
            LD   A,TYBOOL
            JP   LFSVXTY

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LAIFBODY:
            CALL LFCKBLRE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   B,CFLBLA

; Contract: in B out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LFBGCOBD:
            CALL CFTOFRFL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   C,(HL)
            CALL CFEBRFAL
LFCSFLTH:
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   LFSEFLTH

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LFBGBRCL:
            CALL SCREIFCL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   B,CFEXIT
            CALL LFFLDTOC
            CALL CFEJP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   B,CFLBLA
            JR   LFEFRLAB

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LAELSEIF:
%IF TargetStreamingOutput
%IF DebugHooks
            OUT  (DTSOURCE),A
%ENDIF
%ENDIF
            CALL LFBGBRCL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL CFALLABA
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   LFXBL

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LAELSE:
%IF TargetStreamingOutput
%IF DebugHooks
            OUT  (DTSOURCE),A
%ENDIF
%ENDIF
            CALL LFBGBRCL
            JR   LFCSFLTH

; Contract: out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B,C
LAELSEEN:
            CALL SCREIFCL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   B,CFMODE
            CALL CFTOFRFL
            LD   (HL),1
            XOR  A
            RET

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LAIFDONE:
            CALL SCREIFCL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   B,CFLBLA

; B selects a field in the active control frame. All callers have already
; established that frame; the helper preserves their existing precondition.
; Contract: in B out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LFEFRLAB:
            CALL LFFLDTOC
            JP   CFELAB

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LAIFEND:
%IF TargetStreamingOutput
%IF DebugHooks
            OUT  (DTPOP),A
%ENDIF
%ENDIF
            LD   B,CFEXIT
            CALL LFEFRLAB
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL CFTOPFR
            PUSH HL
            LD   DE,CFCTR
            ADD  HL,DE
            LD   A,(HL)
            POP  HL
            LD   DE,CFMODE
            ADD  HL,DE
            AND  (HL)
            XOR  1
            JP   LFCMBFL

; --------------------------------------------------------------- select/case

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LASELECT:
%IF TargetStreamingOutput
%IF DebugHooks
            OUT  (DTSOURCE),A
            OUT  (DTPUSH),A
%ENDIF
%ENDIF
            LD   B,CKSEL
            CALL LFPSFLFR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL CFALCEXT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            INC  HL
            LD   (HL),1                   ; all bodies non-fallthrough so far
            XOR  A                       ; exact selector context
            JP   LFSVXTY

; Retain the selector's concrete integer type in the active frame. Untyped
; exact values use the language's ordinary u16/i16 inference; typed selectors
; retain their declared width and signedness.
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LASELEXP:
            CALL S8RNPNER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(EXRMETA)
            LD   D,A
            AND  MTTYPMSK
            JR   NZ,LFSETYRD
LFINSETY:
            LD   A,D
            AND  MTNEG
            RRCA
            OR   TYU16
LFSETYRD:
            CP   TYBOOL
            JP   Z,TYTYER
            LD   C,A
            LD   B,CFMODE
            CALL CFTOFRFL
            LD   (HL),C
            RET

; Contract: out A,C,DE,HL,carry,zero clobbers sign,parity,halfCarry,B
LASELCAS:
%IF TargetStreamingOutput
%IF DebugHooks
            OUT  (DTSOURCE),A
%ENDIF
%ENDIF
            CALL CFALLABA
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            INC  B                       ; LabelA -> Continue
            JP   CFALCTO

; Case expressions are folded under the selector's exact type and never emit
; a runtime value of their own.
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LASELCON:
            LD   B,CFMODE
            CALL CFTOFRFL
            LD   A,(HL)
            CALL TYEXBGK
            JP   LFSVEXRE

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LACASVAL:
            LD   A,(EXEXPTYP)
            LD   E,A
            LD   A,(EXRMETA)
            OR   A
            JP   P,TYTYER
            CALL LFCKEXAS
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            AND  MTTYPMSK
            LD   C,A
            PUSH HL
            LD   A,SMSELCS
            CALL PSEOPC
            POP  HL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL S7EWD
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   B,CFLBLA
            CALL LFFLDTOC
            JP   TMPUT

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LACASBDY:
            LD   B,CFCONT
            CALL LFFLDTOC
            CALL CFEJP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   B,CFLBLA
            CALL LFEFRLAB
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LASELELS:
            CALL LFDSSECR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   LFSEFLTH

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LACASEND:
            CALL SCREIFCL
            LD   B,CFEXIT
            CALL LFFLDTOC
            CALL CFEJP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   B,CFCONT
            CALL LFEFRLAB
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   LFSEFLTH

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
LFDSSECR:
            LD   A,SMFCLEAN
            JP   TMOPER

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LASELEND:
            CALL SCREIFCL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(HL)
            XOR  1                       ; all non-fallthrough -> select result
%IF CompilerDiagnosticReturns
            LD   B,A
%ENDIF
            JR   LFENDSEL

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LASELNON:
            CALL LFDSSECR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%IF CompilerNonlocalDiagnostics
            LD   A,1                     ; no else always permits fallthrough
%ELSE
            LD   B,1                     ; no else always permits fallthrough
%ENDIF
LFENDSEL:
%IF TargetStreamingOutput
%IF DebugHooks
            OUT  (DTPOP),A
%ENDIF
%ENDIF
%IF CompilerNonlocalDiagnostics
            PUSH AF
%ELSE
            PUSH BC
%ENDIF
            LD   B,CFEXIT
            CALL LFEFRLAB
%IF CompilerNonlocalDiagnostics
            POP  AF
%ELSE
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,B
%ENDIF
            JP   LFCMBFL

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LAWHILE:
%IF TargetStreamingOutput
%IF DebugHooks
            OUT  (DTSOURCE),A
            OUT  (DTPUSH),A
%ENDIF
%ENDIF
            LD   B,CKWHILE
            CALL LFFLOWLA
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            INC  HL
            LD   (HL),C
            CALL CFALCEXT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   B,CFLBLA
            CALL LFEFRLAB
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   LFXBL

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LAWHBODY:
            CALL LFCKBLRE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            ; Folded Boolean values are canonical zero or one in L. Turn the
            ; constant bit in A into a mask, then retain constant true only.
            RLCA
            SBC  A,A
            AND  L
            LD   C,A
            LD   B,CFMODE
            CALL CFTOFRFL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   (HL),C
            LD   B,CFEXIT
            JP   LFBGCOBD

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LAWHEND:
%IF TargetStreamingOutput
%IF DebugHooks
            OUT  (DTPOP),A
%ENDIF
%ENDIF
            LD   B,CFCONT
            CALL LFFLDTOC
            CALL CFEJP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   B,CFEXIT
            CALL LFEFRLAB
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   B,CFMODE
            CALL LFFLDTOC
            XOR  CTWHTRUE
            JP   LFCMBFL

LFPARSFL:
            CALL CFPOPFR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   LFRSTFL

; -------------------------------------------------------------- counted loop

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LAFOR:
%IF TargetStreamingOutput
%IF DebugHooks
            OUT  (DTSOURCE),A
            OUT  (DTPUSH),A
%ENDIF
%ENDIF
            ; The streaming parser has consumed the counter name before this
            ; action. Convert its retained source pointer through the current
            ; multipart descriptor; parser lookahead may advance part-local
            ; cursor metadata beyond the token whose action is now running.
%IF NativeStreamingSource
            LD   HL,(TNSTOFF)
%ELSE
%IF TargetStreamingOutput
            LD   HL,(SSPDCUR)
            LD   DE,-4                  ; current descriptor's source start
            ADD  HL,DE
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            LD   HL,(TNLEXPTR)
            OR   A
            SBC  HL,DE
%ELSE
            LD   HL,(TNSTOFF)
%ENDIF
%ENDIF
            LD   (S7FOROFF),HL
            CALL LFLKDC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            AND  SCMSK
            CP   SCLOC
            JP   NZ,SCCNTER
            LD   A,D
            AND  TYBASMSK
            JP   Z,SCCNTER
            CALL CFCKACCN
            JP   LFSLOXTY

LFCKFOIN:
            CALL LFVADCEX
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   S8RNPNER

; A is the logical action ordinal for the contiguous to/until family.
LAFORBND:
            AND  1
LFFOBNSE:
            LD   (LFFORMD),A
            CALL LALOCEND
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
LFXFOBND:
            JP   LFSLOXTY

; Contract: out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,B,C,IX,IY
LFCKFOBN:
            CALL TYDCSCTY
            LD   E,A
            JP   LFCKTYRE

LASTEPSV EQU LFCKFOBN

LASTEPDF:
            CALL LFCKFOBN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   DE,1
            LD   (LFFORSTP),DE
            XOR  A
            RET

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LAFORBDY:
            LD   B,CKFOR
            CALL LFFLOWLA
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   B,CFCONT
            CALL CFALCTO
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL CFALCEXT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   B,CFCTR
            CALL CFTOFRFL
            LD   A,(DCPAY)
            LD   (HL),A
            INC  HL
            CALL TYDCSCTY
            LD   D,A
            AND  TYSGNFLG
            RRCA
            LD   E,A
            LD   A,D
            AND  TYU16
            RLCA
            OR   E
            LD   E,A
            LD   A,(LFFORMD)
            OR   E
            LD   (HL),A
            INC  HL
            LD   DE,(LFFORSTP)
            LD   (HL),E
            INC  HL
            LD   (HL),D
            INC  HL
            LD   DE,(S7FOROFF)
            LD   (HL),E
            INC  HL
            LD   (HL),D
            CALL CFTOPFR
            CALL SCEFOSET
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   B,CFLBLA
            CALL LFEFRLAB
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL SCEFOTST
            JP   LFCSFLTH

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LAFOREND:
%IF TargetStreamingOutput
%IF DebugHooks
            OUT  (DTPOP),A
%ENDIF
%ENDIF
            LD   B,CFCONT
            CALL LFEFRLAB
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL SCEFORNX
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   B,CFEXIT
            CALL LFEFRLAB
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL LFDSSECR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   LFPARSFL
LFACTEND:
