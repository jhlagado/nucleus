; Stage 6 aggregate layout and static-image construction.
;
; Types use one-byte IDs. Predefined scalars use contextual metadata values;
; dynamic IDs begin at AggregateFirstDynamicTypeId and index a bounded
; six-byte descriptor whose first four bytes are its structural identity and
; whose final word is its retained extent. Aggregate
; storage is allocated by top-level variables and aggregate constants.
; Initializer bytes are staged privately; the Z80 backend publishes them only
; after the complete source has succeeded.

; Contract: in A out A,HL clobbers carry,zero,sign,parity,halfCarry,DE
APFLDADR:
            LD   DE,AFTABBAS
            JR   APADR6

; Contract: in A out A,HL clobbers carry,zero,sign,parity,halfCarry,DE
APTYADR:
            SUB  AGDYNTYP
            LD   DE,ATTABBAS
; Contract: in A,DE out A,HL clobbers carry,zero,sign,parity,halfCarry,DE
APADR6:
            LD   L,A
            ADD  A,A
            ADD  A,L
            ADD  A,A
            LD   L,A
            LD   H,0
            ADD  HL,DE
            RET

%IF TargetStreamingOutput
; Contract: in A out A,HL clobbers carry,zero,sign,parity,halfCarry,D,DE
FTBKSTAD:
            LD   DE,TBBAS
            JR   APADR6

; Contract: in A out A,HL clobbers carry,zero,sign,parity,halfCarry,D,DE
FTBRLEAD:
            LD   DE,TBKROBAS
            JR   APADR6
%ENDIF

; Contract: in A out A,HL,carry,zero clobbers sign,parity,halfCarry,DE
APGETEXT:
            CP   AGDYNTYP
            JR   NC,APGEDYEX
            LD   HL,1
            BIT  1,A
            JR   NZ,APU16EXT
            OR   A
            RET
APU16EXT:
            INC  L
            OR   A
            RET
APGEDYEX:
            CALL APTYADR
            LD   DE,ATEXT
            ADD  HL,DE
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            EX   DE,HL
            OR   A
            RET

; Append the complete descriptor in AggregateCandidate*. No structural
; lookup is performed, so this entry creates nominal record identity.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
APAPPTY:
            LD   A,(ATCNT)
            CP   ATCAP
            JR   NC,APTYCAER
            ADD  A,AGDYNTYP
            CALL APTYADR
            LD   D,H
            LD   E,L
            LD   HL,ANKIND
            LD   BC,ATENTSZ
            LDIR
            LD   A,(ATCNT)
            ADD  A,AGDYNTYP
            LD   C,A
            LD   HL,ATCNT
            INC  (HL)
            LD   A,C
            OR   A
            RET
APTYCAER:
            CALL DGINLINE
            DB  DGTYPCAP

; Intern a structural string or array descriptor. CandidateKind/Aux/Length and
; CandidateExtent must already be complete. Extent is not part of structural
; identity; the first four bytes determine it for structural types.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
APINTY:
            LD   A,(ATCNT)
            OR   A
            JR   Z,APAPPTY
            LD   B,A
            LD   C,AGDYNTYP
APINLP:
            LD   A,C
            CALL APTYADR
            LD   DE,ANKIND
            PUSH BC
            LD   B,4
APINCMLP:
            LD   A,(DE)
            CP   (HL)
            JR   NZ,APINDF
            INC  DE
            INC  HL
            DJNZ APINCMLP
            POP  BC
            JR   APINFND
APINDF:
            POP  BC
APINNX:
            INC  C
            DJNZ APINLP
            JR   APAPPTY
APINFND:
            LD   A,C
            OR   A
            RET

; Collect array suffixes in source order. The complete type is formed only
; after the last suffix, so u8[3][2] can be interned as u8[2] and then as
; three elements of that row type.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry
APBGARTY:
            XOR  A
            LD   (ADCNT),A
            LD   (ATOAFLAG),A
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry
APROVWCU:
            LD   A,(ACTYPID)
            CP   AGOVIEW
            JP   NC,APTYSHER
            OR   A
            RET

; HL is one already-checked positive concrete dimension.
; Contract: in HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
APSVARDI:
            CALL APROVWCU
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(ADCNT)
            CP   ADCAP
            JR   NC,APTYCAER
            LD   C,L
            LD   B,H
            ADD  A,A
            ADD  A,A
            LD   E,A
            LD   D,0
            LD   HL,ADBAS
            ADD  HL,DE
            LD   (HL),C
            INC  HL
            LD   (HL),B
            INC  HL
            LD   DE,(TNSTOFF)
            LD   (HL),E
            INC  HL
            LD   (HL),D
            LD   HL,ADCNT
            INC  (HL)
            OR   A
            RET

; The only omitted array bound is the first suffix of a formal-parameter
; type. Later placement checks keep the completed view parameter-only.
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
APSOARDI:
            LD   A,(ADCNT)
            LD   B,A
            LD   A,(ATOAFLAG)
            OR   B
            JP   NZ,APTYSHER
            CALL APROVWCU
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   DE,ATOAPOS
            CALL DGCOPYTK
            LD   A,1
            LD   (ATOAFLAG),A
            OR   A
            RET

; Owning and result positions historically diagnose an illegal open array at
; its closing bracket. The recursive suffix collector has already buffered the
; following token, so restore the retained suffix position only for an open
; array; concrete types and string[] keep their existing diagnostic positions.
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
APROVWPL:
            LD   A,(ACTYPID)
            OR   A
            JP   P,APROVWCU
            LD   HL,ATOAPOS
            CALL DGRESTTK
            JR   APROVWCU

; Wrap AggregateCurrentTypeId in one concrete array dimension. HL is the
; dimension length and the previous current type becomes the exact element ID.
; Contract: in HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
APWRARCU:
            CALL APROVWCU
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   (ANAUX),A
            LD   (ANLEN),HL
            LD   B,H
            LD   C,L
            LD   A,(ANAUX)
            CALL APGETEXT
            LD   D,H
            LD   E,L
            LD   HL,0
APWAEXLP:
            ADD  HL,DE
%IF CompilerNonlocalDiagnostics
            JR   C,APPDCAER
%ELSE
            JP   C,APPDCAER
%ENDIF
%IF CompilerNonlocalDiagnostics
            PUSH BC
%ENDIF
            CALL APCKEXCA
%IF CompilerNonlocalDiagnostics
            POP  BC
%ENDIF
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            DEC  BC
            LD   A,B
            OR   C
            JR   NZ,APWAEXLP
            LD   (ANEXT),HL
            LD   A,ATKARRAY
            LD   (ANKIND),A
            CALL APINTY
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   (ACTYPID),A
            OR   A
            RET

; Apply saved concrete dimensions from innermost to outermost, then apply an
; optional outer open view. The buffer itself stays outside source-visible
; type identity and is reused by the next type parse.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
APFIARTY:
            LD   A,(ADCNT)
            OR   A
            JR   Z,APFIAROP
            LD   DE,(TNSTOFF)
            LD   (ATRESOFF),DE
            LD   B,A
            ADD  A,A
            ADD  A,A
            LD   E,A
            LD   D,0
            LD   HL,ADBAS
            ADD  HL,DE
APFIARLP:
            DEC  HL
            LD   D,(HL)
            DEC  HL
            LD   E,(HL)
            LD   (TNSTOFF),DE
            DEC  HL
            LD   D,(HL)
            DEC  HL
            LD   E,(HL)
            PUSH BC
            PUSH HL
            EX   DE,HL
            CALL APWRARCU
            POP  HL
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            DJNZ APFIARLP
            LD   DE,(ATRESOFF)
            LD   (TNSTOFF),DE
APFIAROP:
            LD   A,(ATOAFLAG)
            OR   A
            JR   Z,APFIARRD
            CALL APROVWCU
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            OR   AGOAMSK
            LD   (ACTYPID),A
APFIARRD:
            LD   A,(ACTYPID)
            OR   A
            RET

; The first compiler admits one aggregate object up to the selected complete
; program-data region. HL is a nonzero mathematical extent.
%IF SegmentedOutput
%IF CompilerNonlocalDiagnostics
; Production diagnostics never return, so B can select the exact
; capacity diagnostic without adding a second copy of the word predicate.
; Contract: in HL out A,HL,carry,zero clobbers sign,parity,halfCarry,B
APCKEXCA:
            LD   B,DGPDCAP
            JR   APCKSECA

; Contract: in HL out A,HL,carry,zero clobbers sign,parity,halfCarry,B
APCRDOCA:
            LD   B,DGROCAP
; Contract: in B,HL out A,HL,carry,zero clobbers sign,parity,halfCarry,B
APCKSECA:
            LD   A,H
            CP   4
            JR   C,APSECARD
            JR   NZ,APSECAER
            LD   A,L
            OR   A
            JR   NZ,APSECAER
APSECARD:
            OR   A
            RET
APSECAER:
            LD   A,B
            JP   DGSET
%ELSE
; Returning-diagnostic historical layouts retain independently balanced
; routines so their public preservation contracts remain unchanged.
; Contract: in HL out A,HL,carry,zero clobbers sign,parity,halfCarry
APCKEXCA:
            LD   A,H
            CP   4
            JR   C,APEXCARD
            JR   NZ,APEXCAER
            LD   A,L
            OR   A
            JR   NZ,APEXCAER
APEXCARD:
            OR   A
            RET
APEXCAER:
            CALL DGINLINE
            DB  DGPDCAP

; Contract: in HL out A,HL,carry,zero clobbers sign,parity,halfCarry
APCRDOCA:
            LD   A,H
            CP   4
            JR   C,APROCARD
            JR   NZ,APROCAER
            LD   A,L
            OR   A
            JR   NZ,APROCAER
APROCARD:
            OR   A
            RET
APROCAER:
            CALL DGINLINE
            DB  DGROCAP
%ENDIF
%ELSE
; Contract: in HL out A,HL,carry,zero clobbers sign,parity,halfCarry
APCKEXCA:
            LD   A,H
            OR   A
            JR   NZ,APEXCAER
APEXCARD:
            OR   A
            RET
APEXCAER:
            CALL DGINLINE
            DB  DGPDCAP
%ENDIF

%IF HybridLL1Full
APTYSHER:
            CALL DGINLINE
            DB  DGTYPBND
APPDCAER:
            CALL DGINLINE
            DB  DGPDCAP
APSTCAER:
            CALL DGINLINE
            DB  DGSTRCAP
%ELSE
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
APPBND:
            LD   A,TYU16
            CALL TYEXBGK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   D,A
            AND  MTCONST
            JP   Z,APTYSHER
            LD   E,TYU16
            LD   A,D
            CALL TYCKASG
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,H
            OR   L
            JR   Z,APTYSHER
            PUSH HL
            LD   E,TNRBRK
            CALL PSEXPECT
            POP  HL
            RET

APTYSHER:
            CALL DGINLINE
            DB  DGTYPBND

; Parse any admitted aggregate type. Bounds and complete extents are retained
; as words. Object allocation is still bounded by the selected program-data
; region, and exceeding that implementation capacity receives a capacity
; diagnostic rather than changing the source type.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
APPTY:
            CALL APBGARTY
            CALL PSTK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CP   TOKENU8
            JR   Z,APTYU8
            CP   TOKENU16
            JR   Z,APTYU16
            CP   TOKENI8
            JR   Z,APTYI8
            CP   TOKENI16
            JR   Z,APTYI16
            CP   TNBOOL
            JR   Z,APTYBL
            CP   TNSTR
            JR   Z,APPSTRTY
            CP   TNNAME
            JR   NZ,APTYSHER
            CALL SBLOOKUP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   D,A
            AND  SYRECTYP+SYAGGFLG
            CP   SYRECTYP
            JR   NZ,APTYSHER
            LD   A,C
            JR   APTYBARD
APTYU8:
            LD   A,ATIDU8
            JR   APTYBARD
APTYU16:
            LD   A,ATIDU16
            JR   APTYBARD
APTYI8:
            LD   A,ATIDI8
            JR   APTYBARD
APTYI16:
            LD   A,ATIDI16
            JR   APTYBARD
APTYBL:
            LD   A,ATIDBOOL
            JR   APTYBARD
APPSTRTY:
            LD   E,TNLBRK
            CALL PSEXPECT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL APPBND
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,H
            OR   A
            JP   NZ,APSTCAER
            LD   A,L
            OR   A
            JP   Z,APTYSHER
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
            CALL APINTY
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
APTYBARD:
            LD   (ACTYPID),A
APPASFLP:
            CALL PSPEEK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CP   TNLBRK
            JR   Z,APPARSFX
            JP   APFIARTY
APPARSFX:
            CALL PSTK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSPEEK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CP   TNRBRK
            JR   NZ,APPCARSF
            CALL PSTK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL APSOARDI
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   APPASFLP
APPCARSF:
            CALL APPBND
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL APSVARDI
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   APPASFLP
APPDCAER:
            CALL DGINLINE
            DB  DGPDCAP
APSTCAER:
            CALL DGINLINE
            DB  DGSTRCAP
%ENDIF

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
APCKFLDU:
            LD   A,(ACFLDCNT)
            OR   A
            RET  Z
            LD   C,A
            LD   A,(ACFLDST)
APFLDULP:
            PUSH AF
            PUSH BC
            CALL APFLDADR
            CALL TKRECEQ
            JR   C,APFLDUUN
            POP  BC
            POP  AF
            INC  A
            DEC  C
            JR   NZ,APFLDULP
            OR   A
            RET
APFLDUUN:
            POP  BC
            POP  AF
APFLDUER:
            JP   TYDUNMER

%IF HybridLL1Full
APREEMER:
            CALL DGINLINE
            DB  DGRECEMP
%ELSE
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
APPREATK:
            LD   E,TNNAME
            CALL PSEXPECT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
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
            CALL PSXLN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(AFCNT)
            LD   (ACFLDST),A
            XOR  A
            LD   (ACFLDCNT),A
            LD   H,A
            LD   L,A
            LD   (ACRECEXT),HL
APREFLLP:
            CALL PSPEEK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CP   TOKENEND
            JR   Z,APRECFIN
            CP   TNNAME
            JP   NZ,APTYSHER
            CALL PSTK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL APCKFLDU
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(AFCNT)
            LD   B,A
            LD   A,(ACFLDCNT)
            ADD  A,B
            CP   AFCAP
            JP   NC,APTYCAER
            PUSH AF
            CALL APFLDADR
            CALL TKRETAIN
            POP  AF
            PUSH HL
            CALL PSXAS
            POP  HL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            PUSH HL
            CALL APPTY
            POP  HL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   B,A
            INC  HL
            LD   (HL),B
            INC  HL
            LD   DE,(ACRECEXT)
            LD   (HL),E
            INC  HL
            LD   (HL),D
            PUSH DE
            LD   A,B
            CALL APGETEXT
            POP  DE
            ADD  HL,DE
            JP   C,APPDCAER
            CALL APCKEXCA
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   (ACRECEXT),HL
            CALL PSXLN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,ACFLDCNT
            INC  (HL)
            JR   APREFLLP
APRECFIN:
            LD   A,(ACFLDCNT)
            OR   A
            JR   Z,APREEMER
            CALL PSTK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXLN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,ATKREC
            LD   (ANKIND),A
            LD   A,(ACFLDST)
            LD   (ANAUX),A
            LD   A,(ACFLDCNT)
            LD   (ANLEN),A
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
            LD   A,(ACFLDCNT)
            LD   HL,AFCNT
            ADD  A,(HL)
            LD   (HL),A
            LD   HL,ARCNT
            INC  (HL)
%IF AggregateCallSlices
            JP   S7PTOPLV
%ELSE
            JP   TYPTOPLV
%ENDIF
APREEMER:
            CALL DGINLINE
            DB  DGRECEMP
%ENDIF

APINCAER:
            CALL DGINLINE
            DB  DGINICAP

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,HL
APINILV:
            LD   HL,AIDEP
            DEC  (HL)
            OR   A
            RET

; Contract: in A out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
APWRBY:
            LD   B,A
            LD   HL,(ACOBJOFF)
            LD   DE,AIBAS
            ADD  HL,DE
            LD   A,B
            LD   (HL),A
            LD   HL,(ACOBJOFF)
            INC  HL
            LD   (ACOBJOFF),HL
            OR   A
            RET

; Decode the already tokenized string literal directly from resident source.
; B is the fixed capacity. The enclosing object is already zeroed, so the
; final cursor advances over padding without rewriting it.
; Contract: in B out A,B,carry,zero clobbers sign,parity,halfCarry,C,D,DE,HL
APDECSTR:
            LD   A,(TNLEN)
            LD   C,A
            PUSH BC
            CALL APWRBY
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,B
            SUB  C
            LD   B,A
            LD   HL,(TNLEXPTR)
            INC  HL
APDESTLP:
            LD   A,C
            OR   A
            JR   Z,APDSADPA
            LD   A,(HL)
            INC  HL
            CP   $5C
            JR   NZ,APDESTWR
            LD   A,(HL)
            INC  HL
            CP   'x'
            JR   Z,APDESTHE
            CP   '0'
            JR   Z,APDESTRZ
            CP   'n'
            JR   Z,APDESTNL
            CP   'r'
            JR   Z,APDESTRE
            CP   't'
            JR   Z,APDESTTA
            JR   APDESTWR
APDESTHE:
            LD   A,(HL)
            INC  HL
            CALL TKHEX
            ADD  A,A
            ADD  A,A
            ADD  A,A
            ADD  A,A
            LD   D,A
            LD   A,(HL)
            INC  HL
            CALL TKHEX
            OR   D
            JR   APDESTWR
APDESTRZ:
            XOR  A
            JR   APDESTWR
APDESTNL:
            LD   A,10
            JR   APDESTWR
APDESTRE:
            LD   A,13
            JR   APDESTWR
APDESTTA:
            LD   A,9
APDESTWR:
            PUSH BC
            PUSH HL
            CALL APWRBY
            POP  HL
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            DEC  C
            JR   APDESTLP
APDSADPA:
            LD   E,B
            LD   D,0
            INC  DE                      ; permanent terminator at capacity+1
            LD   HL,(ACOBJOFF)
            ADD  HL,DE
            LD   (ACOBJOFF),HL
            OR   A
            RET

APINSHER:
            CALL DGINLINE
            DB  DGINISHP
APINCNER:
            CALL DGINLINE
            DB  DGINICNT

; Contract: out A,BC,carry,zero clobbers sign,parity,halfCarry,D,DE,HL
APPKPRBC:
            PUSH BC
            CALL PSPEEK
            POP  BC
            RET

; Contract: out A,BC,carry,zero clobbers sign,parity,halfCarry,D,DE,HL
APTKPRBC:
            PUSH BC
            CALL PSTK
            POP  BC
            RET

; Contract: in A,BC,zero out A,BC,carry,zero clobbers sign,parity,halfCarry,D,DE,HL
APXCPRBC:
            JR   Z,APINCNER
            CP   TNCOMMA
            JR   NZ,APINSHER
            JR   APTKPRBC

; Parse one type-directed static initializer at the current image cursor.
; Contract: in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
APPINI:
            CP   AGDYNTYP
            JR   C,APPSCINI
            LD   C,A
            CALL APPKPRBC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CP   TNNAME
            LD   A,C
            JP   Z,APPKINI
            PUSH AF
            CALL APTYADR
            LD   A,(HL)
            POP  DE
            LD   E,D
            LD   D,0
            CP   ATKSTR
            JR   Z,APPSTINI
            CP   ATKREC
            JR   Z,APPREINI
            CP   ATKARRAY
            JP   Z,APPARINI
            JR   APINSHER

APPSCINI:
            LD   E,A
            PUSH DE
            CALL TYEXBGK
            POP  DE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL TYCKASG
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            AND  MTCONST
            JP   Z,TYTYER
            LD   A,L
            PUSH DE
            PUSH HL
            CALL APWRBY
            POP  HL
            POP  DE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,E
            BIT  1,A
            JR   NZ,APU16HI
            OR   A
            RET
APU16HI:
            LD   A,H
            JP   APWRBY

APPSTINI:
            EX   DE,HL
            LD   A,L
            CALL APTYADR
            INC  HL
            LD   B,(HL)
            PUSH BC
            LD   E,TNSTRLIT
            CALL PSEXPECT
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(TNLEN)
            CP   B
            JR   C,APPSTDEC
            JR   Z,APPSTDEC
            CALL DGINLINE
            DB  DGSTRLEN
APPSTDEC:
            ; AggregateZeroCurrentObject already defined the complete object,
            ; so decoding need only overwrite the length and payload bytes.
            JP   APDECSTR

; Contract: in A,BC out A,BC,carry,zero clobbers sign,parity,halfCarry,D,DE,HL
APBGCMIN:
            PUSH AF
            CALL APPKPRBC
            POP  DE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CP   D
%IF TargetStreamingOutput
            JP   NZ,APINSHER
%ELSE
            JP   NZ,APINSHER
%ENDIF
            CALL APTKPRBC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(AIDEP)
            CP   AIDEPCAP
            JP   NC,APINCAER
            INC  A
            LD   (AIDEP),A
            OR   A
            RET

APPREINI:
            EX   DE,HL
            LD   A,L
            CALL APTYADR
            INC  HL
            LD   B,(HL)
            INC  HL
            LD   C,(HL)
            LD   A,TNLPAR
            CALL APBGCMIN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
APREINLP:
            PUSH BC
            LD   A,B
            CALL APFLDADR
            INC  HL
            INC  HL
            INC  HL
            LD   A,(HL)
            CALL APPINI
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            INC  B
            DEC  C
            JR   Z,APRINXCL
            CALL APPKPRBC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CP   TNRPAR
            CALL APXCPRBC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   APREINLP
APRINXCL:
            LD   BC,TNRPAR*256+TNRBRK
            JR   APINIXCL

APPARINI:
            EX   DE,HL
            LD   A,L
            CALL APTYADR
            INC  HL
            LD   C,(HL)
            INC  HL
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            PUSH BC
            PUSH DE
            LD   A,TNLBRK
            CALL APBGCMIN
            POP  DE
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
APARINLP:
            PUSH BC
            PUSH DE
            LD   A,C
            CALL APPINI
            POP  DE
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            DEC  DE
            LD   A,D
            OR   E
            JR   Z,APAINXCL
            PUSH DE
            CALL APPKPRBC
            POP  DE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CP   TNRBRK
            PUSH DE
            CALL APXCPRBC
            POP  DE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   APARINLP
APAINXCL:
            LD   BC,TNRBRK*256+TNRPAR

; Contract: in BC out A,BC,carry,zero clobbers sign,parity,halfCarry,D,DE,HL,IX,IY
APINIXCL:
            CALL APPKPRBC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CP   B
            JR   Z,APINTKCL
            CP   C
            JP   Z,APINSHER
            JP   APINCNER
APINTKCL:
            CALL PSTK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   APINILV

; Copy an earlier exact-type aggregate constant into the current initializer
; position. The symbol scan derives its offset in the declaration-ordered
; read-only staging suffix, avoiding another retained workspace field.
; Contract: in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
APPKINI:
            LD   C,A
            CALL APTKPRBC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(SYCNT)
            OR   A
            JR   Z,APKINMIS
            LD   B,A
            LD   IX,SYTABBAS
            LD   IY,(IMGLEN)
            LD   DE,IMGBAS
            ADD  IY,DE
APKINSCN:
            PUSH IX
            POP  HL
            CALL TKRECEQ
            JR   C,APKINICP
            LD   A,(IX+3)
            AND  SYAGGFLG+SCMSK
            CP   SYAGGFLG+SCCONST
            JR   NZ,APKININX
            LD   A,(IX+SYTYPID)
            CALL APGETEXT
            EX   DE,HL
            ADD  IY,DE
APKININX:
            LD   DE,SYENTSZ
            ADD  IX,DE
            DJNZ APKINSCN
APKINMIS:
            JP   SBLOOKNO
APKINICP:
            LD   A,(IX+3)
            AND  SYAGGFLG+SCMSK
            CP   SYAGGFLG+SCCONST
            JP   NZ,TYTYER
            LD   A,(IX+SYTYPID)
            CP   C
            JP   NZ,TYTYER
            CALL APGETEXT
            LD   B,H
            LD   C,L
            LD   DE,(ACOBJOFF)
            PUSH DE
            ADD  HL,DE
            LD   (ACOBJOFF),HL
            POP  HL
            LD   DE,AIBAS
            ADD  HL,DE
            EX   DE,HL
            PUSH IY
            POP  HL
            LDIR
            OR   A
            RET

; Zero exactly the candidate object's complete extent before applying an
; explicit initializer. This also defines every byte of a zero initializer.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
APZCUOBJ:
            LD   HL,(ACOBJOFF)
            LD   DE,AIBAS
            ADD  HL,DE
            LD   BC,(ACOBJEXT)
APZCURLP:
            LD   A,B
            OR   C
            RET  Z
            XOR  A
            LD   (HL),A
            INC  HL
            DEC  BC
            JR   APZCURLP

; The current token is the program variable name.
%IF HybridLL1Full
%ELSE
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
APPPGAVA:
            CALL TYRTDCNM
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXAS
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL APPTY
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   (ACTYPID),A
            CALL APGETEXT
            LD   (ACOBJEXT),HL
            LD   DE,(IMGLEN)
            LD   (ACOBJOFF),DE
            ADD  HL,DE
            JP   C,APPDCAER
            LD   A,H
            OR   A
            JP   NZ,APPDCAER
            LD   (ACOBJEND),HL
            CALL APZCUOBJ
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            XOR  A
            LD   (AIDEP),A
            LD   (AGHASINI),A
            CALL PSPEEK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CP   TNEQ
            JR   NZ,APPGINDN
            CALL PSTK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,(IMGLEN)
            LD   (ACOBJOFF),HL
            LD   A,(ACTYPID)
            LD   B,A
            PUSH BC
            CALL APPINI
%IF CompilerDiagnosticBranches
            JR   C,APPGINER
%ENDIF
            POP  BC
            LD   A,1
            LD   (AGHASINI),A
            LD   A,B
            LD   (ACTYPID),A
            LD   HL,(ACOBJOFF)
            LD   DE,(ACOBJEND)
            OR   A
            SBC  HL,DE
            JP   NZ,APINCNER
            JR   APPGINDN
%IF CompilerDiagnosticBranches
APPGINER:
            POP  BC
            SCF
            RET
%ENDIF
APPGINDN:
            CALL PSXLN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   BC,(IMGLEN)
            LD   A,(ACTYPID)
            CP   AGDYNTYP
            JR   C,APPGSCIN
            LD   D,SIAGPROG
            JR   APPGPRSY
APPGSCIN:
            OR   SCPROG
            LD   D,A
APPGPRSY:
            PUSH BC
            CALL TYPRCUWD
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(ACTYPID)
            INC  HL
            LD   (HL),A
            CALL SBCOMMIT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,(ACOBJEND)
            LD   (IMGLEN),HL
            LD   A,L
            LD   (NXPROG),A
%IF AggregateCallSlices
            JP   S7PTOPLV
%ELSE
            JP   TYPTOPLV
%ENDIF
%ENDIF

; Dedicated Stage 6 compile entry. Historical slices keep AggregateMode clear;
; this entry makes the complete static-image path authoritative.
%IF AggregateCallSlices
%ELSE
            ; Contract: in A,DE,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CPAGSL:
            CALL CPSLINIT
            LD   A,1
            LD   (AGMODE),A
%IF HybridLL1Full
            XOR  A
            LD   (C7RTN),A
            CALL LLPARSE
%ELSE
            CALL PSPPG
%ENDIF
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   TMFINISH
%ENDIF
