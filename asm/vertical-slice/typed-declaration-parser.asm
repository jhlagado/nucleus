; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TYEXBGRU:
            LD   (EXEXPTYP),A
%IF AggregateCallSlices
            XOR  A
            LD   (S8DIRFBL),A
            LD   (S8CARR),A
            INC  A
%ELSE
            LD   A,1
%ENDIF
            JR   TYEXBGRS
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TYEXBGK:
            LD   (EXEXPTYP),A
            XOR  A
; Contract: in A out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TYEXBGRS:
            LD   (EXEMITON),A
            XOR  A
            LD   (EXSUPFLT),A
            LD   (EXSTKDEP),A
            JP   TYPOR

; Parse one scalar type and return ScalarType* in A.
%IF HybridLL1Full
%ELSE
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TYPTY:
            CALL PSTK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CP   TOKENU8
            JR   Z,TYTYU8
            CP   TOKENU16
            JR   Z,TYTYU16
            CP   TOKENI8
            JR   Z,TYTYI8
            CP   TOKENI16
            JR   Z,TYTYI16
            CP   TNBOOL
            JR   Z,TYTYBL
            CALL DGINLINE
            DB  DXTYP
TYTYU8:       LD A,TYU8
                   OR A
                   RET
TYTYU16:      LD A,TYU16
                   OR A
                   RET
TYTYI8:       LD A,TYI8
                   OR A
                   RET
TYTYI16:      LD A,TYI16
                   OR A
                   RET
TYTYBL:  LD A,TYBOOL
                   OR A
                   RET
%ENDIF

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TYTYW:
            AND  2
            RRCA
            INC  A
            RET

; A completed integer constant returns to the exact integer category. Only a
; Boolean retains a concrete type; a negative signed result retains its sign.
; Contract: in A,HL out A,carry,zero clobbers sign,parity,halfCarry,D
TYINFKTY:
            LD   D,A
            AND  MTTYPMSK
            CP   TYBOOL
            RET  Z
            CP   TYI8
            JR   Z,TYINFKI8
            CP   TYI16
            JR   Z,TYINKI16
            LD   A,D
            AND  MTNEG
            RET
TYINFKI8:
            BIT  7,L
            JR   TYINFKSG
TYINKI16:
            BIT  7,H
TYINFKSG:
            LD   A,MTNEG
            RET  NZ
            XOR  A
            RET

; Emit a typed static program object. D=type, BC=offset, HL=value.
%IF HybridLL1Full
%ELSE
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TYEPGDEF:
            LD   A,D
            BIT  1,A
            LD   A,SMDEFPU8
            JR   Z,TYEPDEOP
            LD   A,SMDEFP16
TYEPDEOP:
            PUSH BC
            PUSH DE
            PUSH HL
            CALL TMOPER
            POP  HL
            POP  DE
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            PUSH BC
            PUSH DE
%IF CompilerDiagnosticReturns
            PUSH HL
            LD   A,C
            CALL TMPUT
            POP  HL
%ELSE
            LD   A,C
            CALL TMPUTHL
%ENDIF
            POP  DE
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            PUSH DE
            LD   A,L
%IF CompilerDiagnosticReturns
            PUSH HL
            CALL TMPUT
            POP  HL
%ELSE
            CALL TMPUTHL
%ENDIF
            POP  DE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,D
            BIT  1,A
            JR   NZ,TYEPDEHI
            OR   A
            RET
TYEPDEHI:
            LD   A,H
            JP   TMPUT

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TYPKANM:
            CALL TYRTDCNM
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXEQ
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,TYEXACT
            CALL TYEXBGK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL TYRINKEX
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(DCINFO)
            OR   SCCONST
            LD   D,A
            LD   BC,(DCPAY)
            CALL TYPRCUWD
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   SBCOMMIT

; Contract: in A,HL out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TYRTKEX:
            LD   D,A
            LD   A,(DCINFO)
            LD   E,A
            LD   A,D
            CALL TYCKASG
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            AND  MTCONST
            JP   Z,TYTYER
            LD   (DCPAY),HL
            JP   PSXLN

; Contract: in A,HL out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TYRINKEX:
            LD   D,A
            AND  MTCONST
            JP   Z,TYTYER
            LD   A,D
            CALL TYINFKTY
TYRKTYRD:
            LD   (DCINFO),A
            LD   (DCPAY),HL
            JP   PSXLN

; Current token is the variable name.
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TYPPGAVA:
            LD   A,(AGMODE)
            OR   A
            JP   NZ,APPPGAVA
            CALL TYRTDCNM
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXAS
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL TYPTY
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   (DCINFO),A
%IF LegacyCompilerSlices
            ; Preserve the legacy initialized-array proof behind u8[...].
            CP   TYU8
            JR   NZ,TYPGSC
            CALL PSPEEK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CP   TNLBRK
            JR   NZ,TYPGSC
            LD   A,(NXPROG)
            LD   C,A
            LD   B,0
            LD   D,SIPU8
            CALL TYPRCUWD
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   PSARRAY8
%ENDIF
TYPGSC:
            CALL PSPEEK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CP   TNEQ
            JR   Z,TYPGXP
            LD   HL,0
            LD   A,(DCINFO)
            OR   MTCONST
            JR   TYPGHVEX
TYPGXP:
            CALL PSTK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(DCINFO)
            CALL TYEXBGK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
TYPGHVEX:
            CALL TYRTKEX
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(NXPROG)
            LD   C,A
            LD   B,0
            LD   (EXLVAL),BC
            PUSH BC
            LD   A,(DCINFO)
            OR   SCPROG
            LD   D,A
            CALL TYPRCUWD
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL SBCOMMIT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   BC,(EXLVAL)
            LD   HL,(DCPAY)
            LD   A,(DCINFO)
            LD   D,A
            CALL TYEPGDEF
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(DCINFO)
            CALL TYTYW
            LD   HL,NXPROG
            ADD  A,(HL)
            LD   (HL),A
            JP   TYPTOPLV

TYPTOPLV:
            CALL PSPEEK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CP   TOKENVAR
            JR   Z,TYTOLVVA
            CP   TNCONST
            JR   Z,TYTOPLVK
            CP   TNFWD
            JR   Z,TYTOLVFW
            CP   TOKENSUB
            JP   Z,TYPMAIN
            CP   TNREC
            JR   Z,TYTOLVRE
            CALL DGINLINE
            DB  DXTOPLVL
TYTOLVVA:
            CALL PSTK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   E,TNNAME
            CALL PSEXPECT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   TYPPGAVA
TYTOPLVK:
            CALL PSTK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   E,TNNAME
            CALL PSEXPECT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL TYPKANM
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   TYPTOPLV
TYTOLVFW:
            CALL PSTK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   TYPFWATK
TYTOLVRE:
            CALL PSTK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   APPREATK
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TYPTLKAT:
            LD   E,TNNAME
            CALL PSEXPECT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL TYPKANM
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   TYPTOPLV

; TokenForward has already been consumed. Nucleus 0.1 permits a bounded
; retained signature; this first Z80 increment supports one scalar
; parameter and one scalar result, with exact completion after main.
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TYPFWATK:
            LD   E,TOKENSUB
            CALL PSEXPECT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   E,TNNAME
            CALL PSEXPECT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(FWORD)
            OR   A
            JP   NZ,TYDUNMER
            CALL TYRCORNM
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSRTFWNM
            CALL PSXL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   E,TNNAME
            CALL PSEXPECT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%IF NativeStreamingSource
            LD   HL,FWNAMPTR
            CALL TKRECEQ
%ELSE
            LD   HL,(FWNAMPTR)
            LD   A,(FWNAMLEN)
            LD   B,A
            CALL TKNAMEEQ
%ENDIF
            JP   C,TYDUNMER
            CALL TYRCORNM
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSRTFWPA
            CALL PSXAS
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL TYPTY
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   (FWPARTYP),A
            CALL PSXR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXAS
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL TYPTY
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   (FWRESTYP),A
            CALL PSXLN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,1
            LD   (FWORD),A
            XOR  A
            LD   (FWDONE),A
            JP   TYPTOPLV

TYPMAIN:
            CALL PSTK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
TYPMAATK:
            CALL PSXRTHDR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,SMBGMAIN
            CALL TMOPER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL CFRST
            LD   A,(SYCNT)
            LD   (CTGLBCNT),A
            XOR  A
            LD   (CRKIND),A
TYPLOC:
            CALL TYPLORUN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
TYPMASTM:
            CALL TYPSTM
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   TYPENMAI

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TYPLOCDC:
            LD   E,TNNAME
            CALL PSEXPECT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL TYRTDCNM
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXAS
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL TYPTY
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            OR   SCLOC
            LD   (DCINFO),A
            LD   A,(NXLOCAL)
            LD   C,A
            LD   B,0
            LD   (DCPAY),BC
            PUSH BC
            LD   A,(DCINFO)
            LD   D,A
            CALL TYPRCUWD
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(DCINFO)
            AND  MTTYPMSK
            CALL TYELOCDC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSPEEK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CP   TNEQ
            JR   Z,TYLOCXP
            LD   A,1
            LD   (EXEMITON),A
            LD   A,SMLIT16
            CALL TMEOPER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,0
            CALL TMEWORD
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(DCINFO)
            AND  MTTYPMSK
            OR   MTCONST
            JR   TYLOHVEX
TYLOCXP:
            CALL PSTK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(DCINFO)
            AND  MTTYPMSK
            CALL TYEXBGRU
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
TYLOHVEX:
            LD   D,A
            LD   A,(DCINFO)
            AND  MTTYPMSK
            LD   E,A
            LD   A,D
            CALL TYCKASG
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXLN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
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
            LD   A,(DCINFO)
            AND  MTTYPMSK
            CALL TYTYW
            LD   HL,NXLOCAL
            ADD  A,(HL)
            LD   (HL),A
            OR   A
            RET

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TYPLORUN:
            CALL PSPEEK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CP   TOKENVAR
            JR   Z,TYPLRUTK
            OR   A
            RET
TYPLRUTK:
            CALL PSTK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL TYPLOCDC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   TYPLORUN
%ENDIF

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TYELOCDC:
            BIT  1,A
            LD   A,SMDLCLU8
            JR   Z,TYELDCSE
            LD   A,SMDECL16
TYELDCSE:
            CALL TMOPER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(NXLOCAL)
            JP   TMPUT

; D is symbol info and C its byte offset.
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TYESBYIN:
            LD   A,D
            AND  SCMSK
            RRCA
            RRCA
            JP   Z,TYTYER
            CP   SCPAR/4
            JR   Z,TYSTPAR
            ADD  A,SMSTPU8-1
            BIT  1,D
            JR   Z,TYSTSEL
            ADD  A,SMSTP16-SMSTPU8
            JR   TYSTSEL
TYSTPAR:
            LD   A,SMSTPAR8
            BIT  1,D
            JR   Z,TYSTSEL
            INC  A
TYSTSEL:
%IF AggregateCallSlices
            BIT  3,D
            JP   Z,TYEOPBC
%ENDIF
            JP   PSEOPC

%IF HybridLL1Full
%ELSE
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TYPSTM:
            LD   A,1
            LD   (CTFALLS),A
TYPSTMCT:
            CALL PSPEEK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CP   TOKENEND
            RET  Z
            CP   TNELSEIF
            RET  Z
            CP   TNELSE
            RET  Z
            CP   TNRET
            JR   Z,TYSTMRET
            LD   C,A
TYSTMDSP:
            LD   A,C
            CP   TOKENIF
            JR   Z,TYSTMIF
            CP   TNWHILE
            JR   Z,TYSTMWH
            CP   TOKENFOR
            JR   Z,TYSTMFOR
            CP   TNEXIT
            JP   Z,TYSTMXF
            CP   TNCONT
            JP   Z,TYSTMXF
            CP   TNNAME
            JP   NZ,PSXSC
            CALL PSTK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,KWWRTOUT
            LD   B,15
            CALL TKNAMEEQ
            JP   C,TYPWR
%IF AggregateCallSlices
            CALL S7FIRTCU
            JP   Z,S7PCLSTM
%ENDIF
            CALL TYPASG
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   TYPSTMCT
TYSTMIF:
            CALL PSTK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(CTFALLS)
            PUSH AF
            CALL SCPIF
%IF CompilerDiagnosticBranches
            JR   C,TYSTCFER
%ENDIF
            LD   C,A
            POP  AF
            AND  C
            LD   (CTFALLS),A
            JP   TYPSTMCT
TYSTMWH:
            CALL PSTK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(CTFALLS)
            PUSH AF
            CALL SCPWH
            JR   TYSTLPCM
TYSTMFOR:
            CALL PSTK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(CTFALLS)
            PUSH AF
            CALL SCPFOR
TYSTLPCM:
%IF CompilerDiagnosticBranches
            JR   C,TYSTCFER
%ENDIF
            POP  AF
            LD   (CTFALLS),A
            JP   TYPSTMCT
%IF CompilerDiagnosticBranches
TYSTCFER:
            POP  AF
            SCF
            RET
%ENDIF
TYSTMRET:
            CALL PSTK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%IF AggregateCallSlices
            LD   A,(C7RESTYP)
            CP   AGDYNTYP
            JP   NC,S7PAGRET
%ENDIF
            LD   A,(CRKIND)
            CP   CRVAL
            JR   NZ,TYRTFLER
            LD   A,(CTRESTYP)
            CALL TYEXBGRU
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   D,A
            LD   A,(CTRESTYP)
            LD   E,A
            LD   A,D
            CALL TYCKASG
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXLN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,SMRETSCA
            CALL TMOPER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            XOR  A
            LD   (CTFALLS),A
            JP   TYPSTMCT
%ENDIF
TYRTFLER:
            CALL DGINLINE
            DB  DGRTNFLW
%IF HybridLL1Full
%ELSE
TYSTMXF:
            LD   (DCINFO),A
            CALL PSTK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(DCINFO)
            CALL SCPLPXF
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   TYPSTMCT
TYPWR:
            LD   HL,(TNSTOFF)
            LD   (EXCALOFF),HL
            CALL PSXL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,TYU8
            CALL TYEXBGRU
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   E,TYU8
            CALL TYCKASG
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,SMWRVU8
            CALL TMOPER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,(EXCALOFF)
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
            CALL PSXEERLN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   TYPSTMCT

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TYPASG:
            CALL SBLOOKUP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   (DCINFO),A
            LD   (DCPAY),BC
            LD   D,A
%IF AggregateCallSlices
            AND  SYAGGFLG
            JP   NZ,S7PAGASG
            LD   A,D
%ENDIF
            AND  SYRECTYP+SYAGGFLG
            JP   NZ,TYTYER
            LD   A,D
            AND  SCMSK
            CP   SCLOC
            JR   NZ,TYASCNCK
            CALL CFCKACCN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
TYASCNCK:
            LD   A,D
            AND  SCMSK
            JP   Z,TYTYER
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
            LD   BC,(DCPAY)
            LD   A,(DCINFO)
            LD   D,A
            CALL TYESBYIN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   PSXLN

TYPENMAI:
            LD   E,TOKENEND
            CALL PSEXPECT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXLN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,SMENMAIN
            CALL TMOPER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(FWORD)
            OR   A
            JR   NZ,TYPFWCMP
            LD   E,TOKENEOF
            JP   PSEXPECT

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TYPFWCMP:
            CALL PSPEEK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CP   TOKENSUB
            JP   NZ,TYFWINC
            CALL PSTK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   D,DGFWDMIS
            CALL PSXFWNM
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXLN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(CTGLBCNT)
            LD   (SYCNT),A
            XOR  A
            LD   (NXLOCAL),A
            LD   HL,(FWPARPTR)
%IF NativeStreamingSource
            CALL SAMATTOK
%ELSE
            LD   (TNLEXPTR),HL
            LD   A,(FWPARLEN)
            LD   (TNLEN),A
%ENDIF
            LD   A,(FWPARTYP)
            OR   SCPAR
            LD   D,A
            LD   BC,0
            CALL SBPREPW
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL SBCOMMIT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(FWPARTYP)
            CALL TYTYW
            LD   (NXLOCAL),A
            LD   A,CRVAL
            LD   (CRKIND),A
            LD   A,(FWRESTYP)
            LD   (CTRESTYP),A
            LD   A,1
            LD   (CTFALLS),A
            LD   A,SMBEGRTN
            CALL TMOPER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(FWORD)
            CALL TMPUT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(FWPARTYP)
            CALL TMPUT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
TYPRTLOC:
            CALL TYPLORUN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
TYPRTSTM:
            CALL TYPSTM
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(CTFALLS)
            OR   A
            JP   NZ,TYRTFLER
            LD   E,TOKENEND
            CALL PSEXPECT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXLN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,SMENTRTN
            CALL TMOPER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,1
            LD   (FWDONE),A
            LD   E,TOKENEOF
            JP   PSEXPECT
%ENDIF
TYFWINC:
            CALL DGINLINE
            DB  DGFWDINC
