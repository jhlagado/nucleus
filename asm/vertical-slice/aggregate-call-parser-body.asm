; Predictive aggregate paths, bounded routine signatures, forwards, and the
; predefined Stage 8 service surface. Runtime carriers are never entered in
; the source symbol model as integers.

; Contract: in A out A,HL,carry,zero clobbers sign,parity,halfCarry,DE
S7RTADR:
            LD   L,A
            LD   H,0
            ADD  HL,HL
            ADD  HL,HL
            ADD  HL,HL
            LD   DE,R7TABBAS
            ADD  HL,DE
            OR   A
            RET

; Contract: in A out A,HL,carry,zero clobbers sign,parity,halfCarry,DE
S7PARADR:
            LD   DE,P7TABBAS
; Contract: in A,DE out A,HL,carry,zero clobbers sign,parity,halfCarry,DE
S7ADR4:
            LD   L,A
            LD   H,0
            ADD  HL,HL
            ADD  HL,HL
            ADD  HL,DE
            OR   A
            RET

; Z returns one exact routine match and A its table index. NZ means that the
; current name is not a retained routine; it is not itself a diagnostic.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
S7FIRTCU:
            LD   A,(R7CNT)
            OR   A
            JR   Z,S7FIRTMI
            LD   C,A
            LD   B,0
S7FIRTLP:
            LD   A,B
            CALL S7RTADR
            CALL TKRECEQ
            JR   C,S7FIRTFN
            INC  B
            DEC  C
            JR   NZ,S7FIRTLP
S7FIRTMI:
            LD   A,(S8FMFLG)
            AND  R7MAIN
            JR   Z,S7FIRTAB
            CALL TYNMEQMA
            JR   NC,S7FIRTAB
            LD   A,S7MAINRT
            CP   A
            RET
S7FIRTAB:
            LD   A,$FF
            OR   A
            RET
S7FIRTFN:
            LD   A,B
            CP   A
            RET

S7CNMAHL EQU TKRECEQ

; Carry identifies a predefined service or error constant and A returns its
; dense ordinal. No match returns carry clear.
; Contract: out A,B,carry,zero clobbers sign,parity,halfCarry,C,D,DE,HL
S8MTPRCU:
            LD   HL,KWPREDEF
            LD   C,KWPRECNT
S8MTPRLP:
            LD   B,(HL)
            INC  HL
            LD   A,(TNLEN)
            CP   B
            JR   NZ,S8MTPRSK
            LD   DE,(TNLEXPTR)
S8MTPRBY:
            LD   A,(DE)
            CP   (HL)
            JR   NZ,S8MTPRSK
            INC  DE
            INC  HL
            DJNZ S8MTPRBY
            LD   A,KWPRECNT
            SUB  C
            SCF
            RET
S8MTPRSK:
            LD   E,B
            LD   D,0
            ADD  HL,DE
            DEC  C
            JR   NZ,S8MTPRLP
            OR   A
            RET

%IF TargetStreamingOutput
; Compile one multipart source stream and publish one append-only object.
; IX points at the stable compact target descriptor; A/HL retain the existing
; bounded source-part descriptor ABI.
; Contract: in A,HL,IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CTACPART:
            LD   (CPABRTSP),SP
            LD   (TDPTR),IX
            PUSH AF
            PUSH HL
            CALL CPSLRSST
            POP  HL
            POP  AF
            PUSH AF
            CALL SAPARTS
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,B
            LD   (TGSRCPTS),A
            ; Validate every bank-bearing descriptor field before source
            ; semantics can retain a bank ordinal. A is the bounded part count.
            LD   B,A
            LD   IX,(TDPTR)
            LD   A,(IX+TDBNKCNT)
            OR   A
            JR   Z,FTVACPER
            CP   TBKCAP+1
            JR   NC,FTVACPER
            LD   (TDBNKVAL),A
            LD   C,A
            LD   A,(IX+TDENTBNK)
            CP   C
            JR   NC,FTVACPER
            LD   (TDENTVAL),A
            LD   L,(IX+TDPBPTR)
            LD   H,(IX+TDPBPTR+1)
            LD   (TGPBPTR),HL
FTVPBKLP:
            LD   A,(HL)
            CP   C
            JR   NC,FTVACPER
            INC  HL
            DJNZ FTVPBKLP
%IF CompilerNonlocalDiagnostics
%ELSE
            LD   HL,TBKROBAS
            LD   B,TBKROLIM-TBKROBAS
            XOR  A
FTRBRLLP:
            LD   (HL),A
            INC  HL
            DJNZ FTRBRLLP
%ENDIF
            CALL CPAGCLRD
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            ; A diagnostic during generation restores this synthetic frame and
            ; returns directly through the one target-output abort path. A
            ; successful generation returns normally and discards the frame.
            LD   HL,ZTABORT
            PUSH HL
            LD   (CPABRTSP),SP
            CALL ZGPROG
            POP  HL
            RET
FTVACPER:
            JP   ZTCFGERR

; Return the bank mapped to the current manifest source-part ordinal.
; Contract: out A,carry,zero,sign,parity,halfCarry clobbers D,DE,HL,IX
FTCUSRBK:
            LD   A,(SSPREM)
            AND  SSPORDMS
            RRCA
            RRCA
            RRCA
            LD   E,A
            LD   D,0
            LD   IX,(TDPTR)
            LD   L,(IX+TDPBPTR)
            LD   H,(IX+TDPBPTR+1)
            ADD  HL,DE
            LD   A,(HL)
            OR   A
            RET

; Add the current source bank to flag byte A without disturbing low flags.
; Contract: in A out A,carry,zero clobbers sign,parity,halfCarry,B,D,DE,HL,IX
FTPKCUBK:
            LD   B,A
            CALL FTCUSRBK
            RLCA
            RLCA
            RLCA
            RLCA
            OR   B
            RET

; Extract the target bank stored in flag bits 4..5. The final rotate shifts a
; known zero bit through carry, so success returns carry clear.
; Contract: in A out A,carry,zero clobbers sign,parity,halfCarry
FTUPKBK:
            AND  TBKMSK
            RRCA
            RRCA
            RRCA
            RRCA
            RET

; Compare packed bank bits in D with the current source-part bank.
; Contract: in D out A,carry,zero clobbers sign,parity,halfCarry,B,D,DE,HL,IX
FTCUBKMT:
            LD   B,D
            CALL FTCUSRBK
            RLCA
            RLCA
            RLCA
            RLCA
            XOR  B
            AND  TBKMSK
            RET
; Contract: in D out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
FTRECUBK:
            CALL FTCUBKMT
            RET  Z
            JP   ZTCFGERR

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
FTRESRBK:
            CALL FTCUSRBK
            LD   D,A
            LD   A,(TDENTVAL)
            CP   D
            RET  Z
            JP   ZTCFGERR
%ENDIF

%IF TargetStreamingOutput
            ; The target entry initializes parts and calls the shared body.
%ELSE
; Contract: in A,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CPAGCLPT:
            PUSH AF
            PUSH HL
            CALL CPSLRSST
            POP  HL
            POP  AF
            CALL SAPARTS
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   CPAGCLRD
; Contract: in A,DE,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CPAGCLSL:
            CALL CPSLINIT
%ENDIF
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CPAGCLRD:
            INC  A
            LD   (AGMODE),A
            LD   HL,S7STATE
            LD   DE,S7STATE+1
            LD   BC,S7WKEND-S7STATE-1
            XOR  A
            LD   (HL),A
            LDIR
            LD   (CTNXLBL),A
%IF Stage7LL1
            CALL LLPARSE
%ELSE
            CALL S7PTOPLV
%ENDIF
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   TMFINISH

; Reject a routine name that collides with an ordinary name or an earlier
; routine. The current token remains the name being checked.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
S7RCDCNM:
            CALL SBFIND
            JP   C,TYDUNMER
            CALL S7FIRTCU
            JP   Z,TYDUNMER
            CALL S8MTPRCU
            JP   C,TYDUNMER
            OR   A
            RET

%IF HybridLL1Full
%ELSE
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
S7PTOPLV:
            CALL PSPEEK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CP   TNREC
            JR   Z,S7TOLVRE
            CP   TOKENVAR
            JR   Z,S7TOLVVA
            CP   TNCONST
            JR   Z,S7TOPLVK
            CP   TOKENSUB
            JR   Z,S7TOLVRT
            CALL DGINLINE
            DB  DXTOPLVL
S7TOLVRE:
            CALL PSTK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   APPREATK
S7TOLVVA:
            CALL PSTK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   E,TNNAME
            CALL PSEXPECT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   APPPGAVA
S7TOPLVK:
            CALL PSTK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL TYPTLKAT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   S7PTOPLV
S7TOLVRT:
            CALL PSTK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   E,TNNAME
            CALL PSEXPECT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,NAMEMAIN
            LD   B,4
            CALL TKNAMEEQ
            JP   C,S7PMAANM
            JP   S7PRTANM
%ENDIF

; Check the current parameter name against the current signature prefix.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
S7CKPADU:
            LD   A,(C7PARCNT)
            OR   A
            RET  Z
            LD   C,A
            LD   A,(C7PARST)
            LD   B,A
S7CKPALP:
            LD   A,B
            CALL S7PARADR
            CALL TKRECEQ
            JP   C,TYDUNMER
            INC  B
            DEC  C
            JR   NZ,S7CKPALP
            OR   A
            RET

; Reject a parameter name that collides with a routine, a predefined binding,
; the routine whose signature is being parsed, or an earlier parameter in that
; signature. An older program symbol may be shadowed by this routine binding.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
S7CPDCNM:
            CALL S7CNIROP
            JP   C,TYDUNMER
            LD   A,(C7RTN)
            CALL S7RTADR
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            INC  HL
            LD   A,(HL)
            LD   B,A
            EX   DE,HL
            CALL TKNAMEEQ
            JP   C,TYDUNMER
            JR   S7CKPADU

; Append the current parameter name and its parsed type A.
; Contract: in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
S7APPPAR:
            LD   (S7PATHT),A
            LD   A,(P7CNT)
            CP   P7CAP
            JR   NC,S7PACAER
            CALL S7PARADR
            CALL TKRETAIN
            INC  HL
            LD   A,(S7PATHT)
            LD   (HL),A
            LD   HL,P7CNT
            INC  (HL)
            LD   HL,C7PARCNT
            INC  (HL)
            LD   A,(S7PATHT)
            OR   A
            RET
S7PACAER:
            CALL DGINLINE
            DB  DGPARCAP

; Parse the parameter list and optional result of the provisional routine.
%IF HybridLL1Full
%ELSE
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
S7PSIG:
            CALL PSXL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSPEEK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CP   TNRPAR
            JR   Z,S7SIGCL
S7SIGPAR:
            LD   E,TNNAME
            CALL PSEXPECT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL S7CPDCNM
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            PUSH HL
%IF NativeStreamingSource
            LD   HL,DCNAMPTR
            CALL TKRETAIN
%ELSE
            LD   HL,(TNLEXPTR)
            LD   (DCNAMPTR),HL
            LD   A,(TNLEN)
            LD   (DCNAMLEN),A
%ENDIF
            POP  HL
            CALL PSXAS
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL APPTY
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            PUSH AF
            CALL TYRSDCTK
            POP  AF
            CALL S7APPPAR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSPEEK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CP   TNCOMMA
            JR   NZ,S7SIGCL
            CALL PSTK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   S7SIGPAR
S7SIGCL:
            CALL PSXR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            XOR  A
            LD   (C7RESTYP),A
            CALL PSPEEK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CP   TOKENAS
            JR   NZ,S7SIGLN
            CALL PSTK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL APPTY
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   (C7RESTYP),A
S7SIGLN:
            JP   PSXLN
%ENDIF

; Install one retained parameter as an activation symbol and emit the copy
; from its caller-stack carrier into the routine's negative IX frame.
; Contract: in A,C out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
S7INSPAR:
            LD   (C7PARST),A
            LD   A,C
            LD   (S7ARGIDX),A
            LD   A,(C7PARST)
            CALL S7PARADR
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            INC  HL
            LD   B,(HL)
            INC  HL
            LD   A,(HL)
            LD   (S7PATHT),A
%IF NativeStreamingSource
            LD   H,D
            LD   L,E
            CALL SAMATTOK
%ELSE
            LD   (TNLEXPTR),DE
            LD   A,B
            LD   (TNLEN),A
%ENDIF
            LD   A,(NXLOCAL)
            LD   (S7PATHOF),A
            LD   C,A
            LD   B,0
            LD   A,(S7PATHT)
            CP   AGDYNTYP
            LD   D,SYAGGFLG+SCPAR
            JR   NC,S7INPASY
S7INSCPA:
            OR   SCPAR
            LD   D,A
S7INPASY:
            CALL SBAPPEND
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(S7PATHT)
            CALL SBCOMTY
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(S7PATHT)
            CP   AGOAMSK
            JR   C,S7INPUPA
            LD   A,TYU16          ; address word
            CALL S7PUPABN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,S7PATHOF
            INC  (HL)
            INC  (HL)
            LD   HL,S7ARGIDX
            INC  (HL)
            INC  (HL)
            LD   A,TYU16          ; retained count word
            CALL S7PUPABN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,4
            JR   S7INPARW
S7INPUPA:
            CALL S7PUPABN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(S7PATHT)
            CP   AGDYNTYP
            JR   C,S7ISCPAW
            CP   AGOSTR
            JR   C,S7IAGPAW
            LD   A,3
            JR   S7INPARW
S7IAGPAW:
            LD   A,2
            JR   S7INPARW
S7ISCPAW:
            CALL TYTYW
S7INPARW:
            LD   HL,NXLOCAL
            ADD  A,(HL)
            LD   (HL),A
            OR   A
            RET

; Contract: in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
S7PUPABN:
            LD   C,A
            LD   A,SMBINDP
            CALL PSEOPC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(S7PATHOF)
            CALL TMPUT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(S7ARGIDX)
            JP   TMPUT

; Current token is a non-main routine name.
%IF HybridLL1Full
%ELSE
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
S7PRTANM:
            LD   A,(R7CNT)
            CP   R7CAP
            JP   NC,S7RTCAER
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
            XOR  A
            LD   (C7PARCNT),A
            CALL S7PSIG
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(C7RTN)
            CALL S7RTADR
            LD   DE,R7PARCNT
            ADD  HL,DE
            LD   A,(C7PARCNT)
            LD   (HL),A
            INC  HL
            LD   A,(C7RESTYP)
            LD   (HL),A
            INC  HL
            LD   A,(C7RTN)
            ADD  A,R7LBLBAS
            LD   (HL),A
            LD   (S7CALLBL),A
            LD   HL,R7CNT
            INC  (HL)
            LD   A,(SYCNT)
            LD   (S7GLBCNT),A
            XOR  A
            LD   (NXLOCAL),A
            CALL CFRST
            LD   A,(C7RESTYP)
            OR   A
            LD   A,CRVAL
            JR   NZ,S7RTKDRD
            XOR  A
S7RTKDRD:
            LD   (CRKIND),A
            LD   A,(C7RESTYP)
            LD   (CTRESTYP),A
            LD   A,1
            LD   (CTFALLS),A
            LD   A,SMBGGRTN
            CALL TMOPER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(S7CALLBL)
            CALL TMPUT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(C7PARCNT)
            CALL TMPUT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   B,A
            LD   A,(C7PARST)
            LD   D,A
            XOR  A
            LD   E,A
S7RTPALP:
            LD   A,B
            OR   A
            JR   Z,S7RTLOC
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
            JR   S7RTPALP

S7RTLOC:
            CALL TYPLORUN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
S7RTSTM:
            CALL TYPSTM
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(C7RESTYP)
            OR   A
            JR   Z,S7RTENTK
            LD   A,(CTFALLS)
            OR   A
            JP   NZ,TYRTFLER
S7RTENTK:
            LD   E,TOKENEND
            CALL PSEXPECT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXLN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,SMENGRTN
            CALL TMOPER
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
            JP   S7PTOPLV
S7RTCAER:
            CALL DGINLINE
            DB  DGRTNCAP

; Main is the final declaration in this increment. `fails` is accepted but
; its full call/failure surface remains Stage 8.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
S7PMAANM:
            CALL S7RCDCNM
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSPEEK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CP   TNFAILS
            JR   NZ,S7MAINLN
            CALL PSTK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
S7MAINLN:
            CALL PSXLN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,SMBGMAIN
            CALL TMOPER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(SYCNT)
            LD   (S7GLBCNT),A
            XOR  A
            LD   (NXLOCAL),A
            LD   (C7RESTYP),A
            LD   (CRKIND),A
            CALL CFRST
            LD   A,1
            LD   (CTFALLS),A
S7MAILOC:
            CALL TYPLORUN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
S7MAISTM:
            CALL TYPSTM
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
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
            LD   E,TOKENEOF
            JP   PSEXPECT
%ENDIF

; Return the positive IX displacement of the current source argument. Every
; later source parameter contributes one address/scalar word; each later open
; view contributes its hidden count/capacity word as well.
; Contract: in B,D out A,B,C,D,E,carry,zero clobbers sign,parity,halfCarry,HL
S7PAROFF:
            PUSH BC
            PUSH DE
            LD   A,B
            ADD  A,A
            ADD  A,2
            LD   C,A
            DEC  B
            JR   Z,S7OFFEND
            LD   A,D
            INC  A
            CALL S7PARADR
S7OFFLP:
            INC  HL
            INC  HL
            INC  HL
            LD   A,(HL)
            CP   AGOVIEW
            JR   C,S7OFFNX
            INC  C
            INC  C
S7OFFNX:
            INC  HL                      ; next four-byte parameter entry
            DJNZ S7OFFLP
S7OFFEND:
            LD   A,C
            POP  DE
            POP  BC
            LD   C,A
            OR   A
            RET

; Return aggregate symbol info in D, word payload in BC, and exact type ID in
; A. All fields are contiguous in the ordinary symbol-table entry.
; Contract: out A,BC,D,carry,zero clobbers sign,parity,halfCarry,E,HL
S7LKAGCU:
            CALL SBFIND
            JP   NC,SBLOOKNO
            INC  HL
            INC  HL
            INC  HL
            LD   D,(HL)
            INC  HL
            LD   C,(HL)
            INC  HL
            LD   B,(HL)
            INC  HL
            LD   A,(HL)
            OR   A
            RET

; Stage 7 structural operands are emitted whenever their owning operation is
; emitted. They are not expression values and therefore do not consult the
; constant-folding emission flag used by TypedEmitWord.
; Contract: in HL out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
S7EWD:
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
            JP   TMPUT

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
S7EEACOF:
            LD   HL,(S7PATHEX)
            CALL S7EWD
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,(S7CALOFF)
            JR   S7EWD

; Contract: in A out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
S7EOAPOF:
            CALL TMOPER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,(S7PATHOF)
            JR   S7EWD

; D is the symbol class and BC its byte offset. Emit its opaque root carrier
; and return the exact aggregate type in A.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
S7EASYRO:
            CALL S7LKAGCU
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   (S7PATHT),A
            CP   AGOVIEW
            JR   C,S7EAROCL
            LD   A,C
            INC  A
            INC  A
            LD   (S7OVCOFF),A
S7EAROCL:
            LD   A,D
            AND  SCMSK
            JR   Z,S7EARRDO
            CP   SCPROG
            JR   NZ,S7EAROPA
            LD   A,SMLDPALS
S7EAROAD:
            PUSH BC
            CALL TMOPER
            POP  HL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL S7EWD
            JR   S7EARORD
S7EARRDO:
%IF TargetStreamingOutput
            PUSH BC
            CALL FTRECUBK
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%ENDIF
            LD   A,SMLDROAL
            JR   S7EAROAD
S7EAROPA:
            CP   SCPAR
            JP   NZ,TYTYER
            LD   A,SMLDPARA
S7EAROSE:
            CALL PSEOPC
S7EARORD:
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(S7PATHT)
            OR   A
            RET

; Emit one checked postfix chain. A is the current aggregate type and one
; carrier is live on the generated evaluation stack. D returns zero for an
; address path, one when a property has produced a scalar value, or two when
; assignment parsing has retained a bounded-string carrier for `.length =`.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry
S7PCOPST:
            LD   A,(S7PATHT)
            CP   AGOSTR
            RET

; These retained expression actions live here so the path and call parsers can
; reuse their result-saving tail under strict one-pass register contracts.
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LACONEXP:
            XOR  A                       ; ScalarTypeExact
            CALL TYEXBGK
            JR   LFSVEXRE

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LARTEXP:
            LD   A,(EXEXPTYP)
            CALL TYEXBGRU
; Contract: in A,BC,DE,HL out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
LFSVEXRE:
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   (EXRMETA),A
            LD   (EXRVAL),HL
            OR   A
            RET

; Contract: in A out A,D,carry,zero clobbers sign,parity,halfCarry,B,C,E,HL,IX,IY
S7PPTSFX:
            LD   D,0
S7PTSFLP:
            PUSH AF
            CALL PSPEEK
%IF CompilerDiagnosticBranches
            JP   C,S7PTSFER
%ENDIF
            CP   TOKENDOT
            JR   Z,S7PTFLCM
            CP   TNLBRK
            JP   Z,S7PTIXCM
            POP  AF
            LD   D,0
            OR   A
            RET
S7PTFLCM:
            POP  AF
            LD   (S7PATHT),A
            CALL S8RNPNER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(S7PATHT)
            PUSH AF
S7PTFLD:
            CALL PSTK
%IF CompilerDiagnosticBranches
            JP   C,S7PTSFER
%ENDIF
            LD   E,TNNAME
            CALL PSEXPECT
%IF CompilerDiagnosticBranches
            JP   C,S7PTSFER
%ENDIF
            POP  AF
            PUSH AF
            CP   AGDYNTYP
%IF CompilerDiagnosticBranches
            JP   C,S7PFTYER
%ENDIF
            CP   AGOSTR
            JR   Z,S7PTSTFL
            CP   AGOAMSK
            JR   NC,S7PTARFL
            CALL APTYADR
            LD   A,(HL)
            CP   ATKSTR
            JR   Z,S7PTSTFL
            CP   ATKARRAY
            JR   Z,S7PTARFL
            JP   S7PTREFL
S7PTSTFL:
            LD   HL,KWLENGTH
            LD   B,6
            CALL TKNAMEEQ
            JR   C,S7PTSTLE
            LD   HL,KWCAP
            LD   B,8
            CALL TKNAMEEQ
            JP   NC,S7PFTYER
            CALL S7PCOPST
            JP   NZ,S7PFTYER
            LD   A,(S7OVCOFF)
            LD   C,A
            LD   A,SMSTRCAP
            CALL PSEOPC
%IF CompilerDiagnosticBranches
            JP   C,S7PTSFER
%ENDIF
            JR   S7PSSCRD
S7PTSTLE:
            LD   A,(S7PASMOD)
            OR   A
            JR   Z,S7STRLEN
            CALL S7PCOPST
            JP   NZ,S7PFTYER
            LD   A,(S7OVCOFF)
            LD   (S7SROFF),A
            POP  AF
            LD   D,2
            OR   A
            RET
S7STRLEN:
            CALL S7PCOPST
            JR   Z,S7POSLRD
            CALL S7STRCAP
            LD   C,A
            LD   A,SMSTRLEN
            JR   S7LENRD
S7POSLRD:
            LD   A,(S7OVCOFF)
            LD   C,A
            LD   A,SMOSLEN
S7LENRD:
            CALL PSEOPC
%IF CompilerDiagnosticBranches
            JP   C,S7PTSFER
%ENDIF
            LD   HL,(TNSTOFF)
            CALL S7EWD
%IF CompilerDiagnosticBranches
            JP   C,S7PTSFER
%ENDIF
S7PSSCRD:
            POP  AF
            LD   A,TYU8
            JR   S7PSPRRD
S7PTARFL:
            LD   HL,KWLENGTH
            LD   B,6
            CALL TKNAMEEQ
            JP   NC,S7PFTYER
            LD   A,(S7PASMOD)
            OR   A
            JP   NZ,S7PFTYER
            LD   A,(S7PATHT)
            CP   AGOAMSK
            JR   NC,S7POARLE
            CALL APTYADR
            INC  HL
            INC  HL
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            LD   (S7PATHOF),DE
            LD   A,SMARRLEN
            CALL S7EOAPOF
%IF CompilerDiagnosticBranches
            JP   C,S7PTSFER
%ENDIF
            JR   S7PALERD
S7POARLE:
            LD   A,(S7OVCOFF)
            LD   C,A
            LD   A,SMOALEN
            CALL PSEOPC
%IF CompilerDiagnosticBranches
            JP   C,S7PTSFER
%ENDIF
S7PALERD:
            POP  AF
            LD   A,TYU16
S7PSPRRD:
            LD   D,1
            OR   A
            RET
S7FLDMIS:
            CALL DGINLINE
            DB  DGUNKNAM
S7PTREFL:
            POP  AF
            CALL APTYADR
            LD   A,(HL)
            CP   ATKREC
            JP   NZ,TYTYER
            INC  HL
            LD   B,(HL)
            INC  HL
            LD   D,(HL)
S7PRFLLP:
            LD   A,D
            OR   A
            JR   Z,S7FLDMIS
            LD   A,B
            CALL APFLDADR
            PUSH DE
            CALL TKRECEQ
            POP  DE
            JR   C,S7PRFLFN
            INC  B
            DEC  D
            JR   S7PRFLLP
S7PRFLFN:
            LD   DE,AFTYPID
            ADD  HL,DE
            LD   A,(HL)
            INC  HL
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            OR   A
            PUSH AF
            LD   (S7PATHOF),DE
            LD   A,SMSELFLD
            CALL S7EOAPOF
%IF CompilerDiagnosticBranches
            JP   C,S7PTSFER
%ENDIF
            POP  AF
            JP   S7PTSFLP
S7PTIXCM:
            POP  AF
            LD   (S7PATHT),A
            CALL S8RNPNER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(S7OVCOFF)
            PUSH AF
            LD   A,(S7PATHT)
            PUSH AF
S7PTIX:
            LD   HL,(TNSTOFF)
            PUSH HL
            CALL PSTK
%IF CompilerDiagnosticBranches
            JP   C,S7PTIXER
%ENDIF
            LD   A,(EXEXPTYP)
            PUSH AF
            LD   A,(EXEMITON)
            PUSH AF
            LD   A,1
            LD   (EXEMITON),A
            LD   A,TYU16
            LD   (EXEXPTYP),A
            CALL TYPOR
%IF CompilerDiagnosticBranches
            JP   C,S7PIEXER
%ENDIF
            CALL TYREQCMP
%IF CompilerDiagnosticBranches
            JP   C,S7PIEXER
%ENDIF
            CALL LFSVEXRE
            POP  AF
            LD   (EXEMITON),A
            POP  AF
            LD   (EXEXPTYP),A
            LD   A,(EXRMETA)
            AND  MTTYPMSK
            CP   TYBOOL
            JP   Z,S7PITYER
            CALL S7PRINIX
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   E,TNRBRK
            CALL PSEXPECT
%IF CompilerDiagnosticBranches
            JP   C,S7PTIXER
%ENDIF
            POP  HL
            LD   (S7CALOFF),HL
            POP  AF
            LD   E,A
            POP  BC
            LD   A,B
            LD   (S7OVCOFF),A
            LD   A,E
            CP   AGDYNTYP
            JP   C,TYTYER
            PUSH AF
            CP   AGOSTR
            JR   Z,S7POSTIX
            CP   AGOAMSK
            JR   NC,S7POARIX
            CALL APTYADR
            LD   A,(HL)
            CP   ATKSTR
            JR   Z,S7PTSTIX
            CP   ATKARRAY
            JP   NZ,S7PFTYER
            INC  HL
            LD   A,(HL)                  ; element type
            LD   (S7PATHT),A
            INC  HL
            LD   C,(HL)                  ; fixed length
            INC  HL
            LD   B,(HL)
            LD   A,(EXRMETA)
            AND  MTCONST
            JR   Z,S7PTIXDY
            LD   HL,(EXRVAL)
            OR   A
            SBC  HL,BC
%IF CompilerNonlocalDiagnostics
            JR   NC,S7PIRNER
%ELSE
            JP   NC,S7PIRNER
%ENDIF
S7PTIXDY:
            LD   (S7PATHOF),BC
            LD   A,(S7PATHT)
            CALL APGETEXT
            LD   (S7PATHEX),HL
            LD   A,SMSELIDX
            CALL S7EOAPOF
%IF CompilerDiagnosticBranches
            JR   C,S7PTSFER
%ENDIF
            JR   S7PAIXTA
S7POARIX:
            AND  AGOAELEM
            LD   (S7PATHT),A
            CALL APGETEXT
            LD   (S7PATHEX),HL
            LD   A,(S7OVCOFF)
            LD   C,A
            LD   A,SMOAIDX
            CALL PSEOPC
%IF CompilerDiagnosticBranches
            JR   C,S7PTSFER
%ENDIF
S7PAIXTA:
            CALL S7EEACOF
%IF CompilerDiagnosticBranches
            JR   C,S7PTSFER
%ENDIF
            POP  AF
            LD   A,(S7PATHT)
            JP   S7PTSFLP
S7PTSTIX:
            INC  HL
            LD   C,(HL)                  ; capacity
            LD   A,SMSTRIDX
            JR   S7PSIXRD
S7POSTIX:
            LD   A,(S7OVCOFF)
            LD   C,A
            LD   A,SMOSIDX
S7PSIXRD:
            CALL PSEOPC
%IF CompilerDiagnosticBranches
            JR   C,S7PTSFER
%ENDIF
            LD   HL,(S7CALOFF)
            CALL S7EWD
%IF CompilerDiagnosticBranches
            JR   C,S7PTSFER
%ENDIF
            POP  AF
            LD   A,TYU8
            JP   S7PTSFLP
%IF CompilerDiagnosticBranches
S7PTSFER:
            POP  AF
            SCF
            RET
%ENDIF
S7PITYER:
            POP  HL
            POP  AF
            POP  BC
            JP   TYTYER

; Convert a signed dynamic index to checked u16 before the existing unsigned
; upper-bound operation. Exact negatives are diagnosed at the index value.
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
S7PRINIX:
            LD   C,TYU16
            LD   A,(EXRMETA)
            LD   D,A
            AND  MTCONST
            JR   NZ,S7PREXIX
            LD   A,D
            AND  TYSGNFLG
            RET  Z
            SET  7,C                     ; range failure is an index bounds trap
            LD   HL,(EXVALPOS)
            JP   TYEICVOP
S7PREXIX:
            LD   HL,(EXRVAL)
            LD   A,D
            CALL TYCVK
            JP   C,TYVRNGER
            OR   A
            RET
%IF CompilerDiagnosticBranches
S7PTIXER:
            POP  HL
            POP  AF
            POP  BC
            SCF
            RET
S7PIEXER:
            POP  AF
            LD   (EXEMITON),A
            POP  AF
            LD   (EXEXPTYP),A
            JR   S7PTIXER
%ENDIF
S7PIRNER:
            LD   A,(EXSUPFLT)
            OR   A
%IF CompilerNonlocalDiagnostics
            JR   NZ,S7PTIXDY
%ELSE
            JP   NZ,S7PTIXDY
%ENDIF
            LD   HL,(S7CALOFF)
            LD   (TNSTOFF),HL
            POP  AF
            JP   TYRNGER
S7PFTYER:
            POP  AF
            JP   TYTYER

; Address one bounded nested-call frame. Eight bytes retain the source-call
; metadata that nested argument calls may overwrite. The scalar parser keeps
; only its balanced expression context, a source frame keeps its result flag,
; and a service keeps only its source offset temporarily on the compiler
; hardware stack.
; Contract: in A out HL,carry,zero clobbers A,sign,parity,halfCarry,D,DE
S7CLFRAD:
            ADD  A,F7RTNIDX
            JP   S7RTADR

; Contract: out HL,carry,zero clobbers A,sign,parity,halfCarry,D,DE
S7CUCLFR:
            LD   A,(S7CALDEP)
            DEC  A
            JR   S7CLFRAD

; Parse and validate one scalar argument against the expected type in A while
; preserving the enclosing expression context across nested calls.
; Contract: in A out A,HL,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,IX,IY
S7PSCARG:
            LD   D,A
            LD   A,(EXEXPTYP)
            LD   B,A
            LD   A,(EXEMITON)
            LD   C,A
            PUSH BC
            PUSH DE
            LD   A,D
            LD   (EXEXPTYP),A
            LD   A,1
            LD   (EXEMITON),A
            CALL TYPOR
%IF CompilerDiagnosticBranches
            JR   C,S7SCARER
%ENDIF
            CALL LFSVEXRE
            POP  DE
            POP  BC
            LD   A,C
            LD   (EXEMITON),A
            LD   A,B
            LD   (EXEXPTYP),A
            LD   E,D
            JP   LFCKERRE
%IF CompilerDiagnosticBranches
S7SCARER:
            LD   L,A
            POP  DE
            POP  BC
            LD   A,C
            LD   (EXEMITON),A
            LD   A,B
            LD   (EXEXPTYP),A
            LD   A,L
            SCF
            RET
%ENDIF

; Parse one call to a retained routine. A is the routine-table index and C is
; zero when the result is discarded or one when its carrier remains live.
; Contract: in A,C out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
S7PCL:
            LD   B,A
            LD   A,(S7CALDEP)
            CP   F7CAP
            JR   C,S7PCFRSP
            CALL DGINLINE
            DB  DGEXPCAP
S7PCFRSP:
            CALL S7CLFRAD
            LD   A,C
            PUSH AF
            PUSH HL
            LD   A,B
            CP   S7MAINRT
            JR   Z,S7PMCLFR
            CALL S7RTADR
            INC  HL
            INC  HL
            INC  HL
            LD   D,(HL)                  ; parameter start
            INC  HL
            LD   E,(HL)                  ; parameter count
            INC  HL
            LD   B,(HL)                  ; result
            INC  HL
            LD   A,(HL)                  ; label
            INC  HL
            LD   C,(HL)                  ; failure flags
            JR   S7PCFRRD
S7PMCLFR:
            LD   DE,0                    ; parameter start/count
            LD   B,D                     ; result-free
            LD   A,(S8FMFLG)
            LD   C,A
            LD   A,S7MAINLB
S7PCFRRD:
            POP  HL
            LD   (HL),A
            POP  AF
            OR   A
            JR   Z,S7PCFLRD
            SET  6,(HL)
S7PCFLRD:
            INC  HL
            LD   (HL),B
            INC  HL
            LD   (HL),D
            INC  HL
            LD   (HL),E
            INC  HL
            LD   (HL),E                  ; original argument count
            INC  HL
            LD   DE,(TNSTOFF)
            LD   (HL),E
            INC  HL
            LD   (HL),D
            INC  HL
            LD   (HL),C
            LD   HL,S7CALDEP
            INC  (HL)
            CALL PSXL
%IF CompilerDiagnosticBranches
            JP   C,S7CLER
%ENDIF
S7CLARLP:
            CALL S7CUCLFR
            INC  HL
            INC  HL
            INC  HL
            LD   A,(HL)
            OR   A
            JP   Z,S7CLARDN
            DEC  HL
            LD   A,(HL)                  ; current parameter table index
            CALL S7PARADR
            INC  HL
            INC  HL
            INC  HL
            XOR  A
            LD   (S8DIRFBL),A
            LD   A,(HL)
            CP   AGOSTR
            JR   NZ,S7CCSTAR
            CALL PSPEEK
%IF CompilerDiagnosticBranches
            JP   C,S7CLER
%ENDIF
            CP   TNSTRLIT
            JR   Z,S7CSLIAR
            LD   A,(HL)
S7CCSTAR:
            CP   AGDYNTYP
            JR   NC,S7CLAGAR
            CALL S7PSCARG
%IF CompilerDiagnosticBranches
            JP   C,S7CLER
%ENDIF
            JP   S7CLARRD
S7CSLIAR:
%IF CompilerDiagnosticReturns
            CALL S7PSLIAR
            JP   C,S7CLER
            JP   S7CLARRD
%ENDIF
; Materialize one contextual string literal as a distinct bank-local constant.
; The object remains anonymous: only its bank-local read-only offset enters the
; semantic stream, and target publication walks it after the named constants.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
S7PSLIAR:
            CALL PSTK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(TNLEN)
            CP   254
            JP   NC,APSTCAER
            OR   A
            JR   NZ,S7SLCARD
            INC  A
S7SLCARD:
            LD   (S7ARGCNT),A
            LD   L,A
            LD   H,0
            INC  HL
            INC  HL
            LD   (ACOBJEXT),HL
%IF TargetStreamingOutput
            CALL S7CUCLFR
            LD   DE,F7FLGS
            ADD  HL,DE
            LD   D,(HL)
            CALL FTRECUBK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
S7SLBKRD:
%ENDIF
%IF TargetStreamingOutput
            LD   H,A                     ; successful bank match leaves A=0
            LD   L,A
%ELSE
            LD   HL,0
%ENDIF
            LD   (ACOBJOFF),HL
            CALL APZCUOBJ
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(S7ARGCNT)
            LD   B,A
            CALL APDECSTR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL S7CSLIOB
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            PUSH HL
            LD   A,SMLDROAL
            CALL TMOPER
            POP  HL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL S7EWD
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            XOR  A
            JP   S7POSTRD
S7CLAGAR:
            CALL S7PAGV
%IF CompilerDiagnosticBranches
            JP   C,S7CLER
%ENDIF
            PUSH AF
            CALL S7CUCLFR
            INC  HL
            INC  HL
            LD   A,(HL)
            CALL S7PARADR
            INC  HL
            INC  HL
            INC  HL
            LD   D,(HL)
            POP  AF
            LD   (S7PATHT),A
            LD   A,D
            LD   (S7CALRES),A
            CP   AGOSTR
            JR   Z,S7COSTTY
            CP   AGOAMSK
            JR   NC,S7COARTY
            LD   A,(S7PATHT)
            CP   D
            JP   NZ,S7CLTYER
            JR   S7CATYRD
S7COSTTY:
            CALL S7PCOPST
            JR   Z,S7CATYRD
            CALL S7STRCAP
%IF CompilerDiagnosticBranches
            JP   C,S7CLER
%ENDIF
            JR   S7CATYRD
S7COARTY:
            AND  AGOAELEM
            LD   B,A                      ; preserve C: direct-root bank flag
            LD   A,(S7PATHT)
            LD   D,A
            LD   A,(S7CALRES)
            CP   D
            JR   Z,S7CATYRD
            LD   A,D
            CP   AGOVIEW
            JP   NC,S7CLTYER
            CP   AGDYNTYP
            JP   C,S7CLTYER
            CALL APTYADR
            LD   A,(HL)
            CP   ATKARRAY
            JP   NZ,S7CLTYER
            INC  HL
            LD   A,(HL)
            CP   B
            JP   NZ,S7CLTYER
S7CATYRD:
%IF TargetStreamingOutput
            ; A cross-bank aggregate parameter must originate at a direct
            ; program root. Diagnose through the ordinary call-frame unwind.
            CALL S7CUCLFR
            LD   DE,F7FLGS
            ADD  HL,DE
            LD   D,(HL)
            CALL FTCUBKMT
            JR   Z,S7CABKRD
            LD   A,C
            OR   A
            JR   NZ,S7CABKRD
            LD   A,DGTGTCFG
            CALL DGSET
%IF CompilerDiagnosticBranches
            JP   S7CLER
%ENDIF
S7CABKRD:
%ENDIF
            CALL S8RNPNER
%IF CompilerDiagnosticBranches
            JP   C,S7CLER
%ENDIF
            LD   A,(S7CALRES)
            CP   AGOSTR
            JR   Z,S7CPOPST
            CP   AGOAMSK
            JR   C,S7CLARRD
%IF CompilerNonlocalDiagnostics
            JP   S7POARAR
%ELSE
            CALL S7POARAR
%IF CompilerDiagnosticBranches
            JP   C,S7CLER
%ENDIF
            JR   S7CLARRD
%ENDIF
S7CPOPST:
%IF CompilerNonlocalDiagnostics
            JR   S7POSTAR
%ELSE
            CALL S7POSTAR
%IF CompilerDiagnosticBranches
            JP   C,S7CLER
%ENDIF
%ENDIF
S7CLARRD:
            CALL S7CUCLFR
            INC  HL
            INC  HL
            INC  (HL)
            INC  HL
            DEC  (HL)
            JP   Z,S7CLARDN
            LD   E,TNCOMMA
            CALL PSEXPECT
%IF TargetStreamingOutput
%IF CompilerDiagnosticBranches
            JP   C,S7CLER
%ENDIF
%ELSE
%IF CompilerDiagnosticBranches
            JP   C,S7CLER
%ENDIF
%ENDIF
            JP   S7CLARLP

; Append the prepared sealed object to the declaration-ordered read-only
; image and retain its bank-local offset. In banked output the compiler-only
; terminator byte carries the source bank until target publication replaces
; it with the required permanent zero.
; Contract: out A,HL,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,IX,IY
S7CSLIOB:
%IF TargetStreamingOutput
            CALL S7ABKRDO
%IF CompilerNonlocalDiagnostics
            PUSH BC
%ELSE
            LD   (ACTYPID),A
            LD   (ACOBJOFF),BC
%ENDIF
            LD   HL,AIBAS
            LD   DE,(ACOBJEXT)
            ADD  HL,DE
            DEC  HL
%IF CompilerNonlocalDiagnostics
%ELSE
            LD   A,(ACTYPID)
%ENDIF
            LD   (HL),A
%ELSE
            LD   BC,(ROILEN)
            LD   (ACOBJOFF),BC
%ENDIF
            CALL S7ARDOOB
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%IF TargetStreamingOutput
%IF CompilerNonlocalDiagnostics
            POP  HL
%ELSE
            LD   HL,(ACOBJOFF)
%ENDIF
%ELSE
            LD   HL,(ACOBJOFF)
%ENDIF
            RET

%IF TargetStreamingOutput
; Reserve the current object's extent in its source bank's read-only stream.
; Return the source bank in A and the object's old bank-local offset in BC.
; Contract: out A,BC,carry,zero clobbers sign,parity,halfCarry,D,DE,HL,IX,IY
S7ABKRDO:
            CALL FTCUSRBK
            PUSH AF
            CALL FTBRLEAD
            LD   C,(HL)
            INC  HL
            LD   B,(HL)
            LD   DE,(ACOBJEXT)
            EX   DE,HL
            ADD  HL,BC
            EX   DE,HL
            LD   (HL),D
            DEC  HL
            LD   (HL),E
            POP  AF
            RET
%ENDIF

; Append the prepared object to the shared declaration-ordered read-only
; staging image. Named constants and anonymous literals use the same checked
; capacity and copy path.
; Contract: out A,BC,carry,zero clobbers sign,parity,halfCarry,D,DE,HL
S7ARDOOB:
            LD   BC,(ROILEN)
            LD   HL,(ACOBJEXT)
            ADD  HL,BC
%IF CompilerNonlocalDiagnostics
            PUSH HL
%ENDIF
            LD   DE,(IMGLEN)
            ADD  HL,DE
%IF CompilerNonlocalDiagnostics
            PUSH BC
%ENDIF
            CALL APCRDOCA
%IF CompilerNonlocalDiagnostics
            POP  BC
%ENDIF
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%IF CompilerNonlocalDiagnostics
            POP  HL
%ELSE
            OR   A
            SBC  HL,DE
%ENDIF
            LD   (ROILEN),HL
            LD   HL,IMGBAS
            ADD  HL,DE
            ADD  HL,BC
            EX   DE,HL
            LD   HL,AIBAS
            LD   BC,(ACOBJEXT)
            LDIR
            OR   A
            RET

; Convert one concrete or already-open bounded-string carrier into the two-word
; internal call form: actual capacity below the ordinary address carrier.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
S7POSTAR:
            CALL S7PCOPST
            JR   Z,S7PFOPST
            CALL S7STRCAP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   (S7ARGCNT),A
            XOR  A
            JR   S7POSTRD
S7PFOPST:
            LD   A,(S7OVCOFF)
            LD   (S7ARGCNT),A
            LD   A,1
S7POSTRD:
            LD   C,A
            LD   A,SMOPENAR
            CALL PSEOPC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(S7ARGCNT)
            CALL TMPUT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
S7CMOPAR:
            CALL S7CUCLFR
            LD   DE,F7ARGCNT
            ADD  HL,DE
            INC  (HL)
%IF CompilerNonlocalDiagnostics
            JP   S7CLARRD
%ELSE
            OR   A
            RET
%ENDIF

; Convert a concrete or forwarded open-array carrier into the shared two-word
; call form. The retained array count remains a complete u16 word.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
S7POARAR:
            CALL S7POARCR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   S7CMOPAR

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
S7POARCR:
            LD   A,(S7PATHT)
            CP   AGOAMSK
            JR   NC,S7PFOPAR
            CALL APTYADR
            INC  HL
            INC  HL
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            EX   DE,HL
            LD   A,2
            JR   S7POARRD
S7PFOPAR:
            LD   A,(S7OVCOFF)
            LD   L,A
            LD   H,0
            LD   A,3
S7POARRD:
            LD   C,A
            LD   (S7PATHOF),HL
            LD   A,SMOPENAR
            CALL PSEOPC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,(S7PATHOF)
            JP   S7EWD
S7CLARDN:
            CALL PSXR
%IF TargetStreamingOutput
%IF CompilerDiagnosticBranches
            JP   C,S7CLER
%ENDIF
%ELSE
%IF CompilerDiagnosticBranches
            JR   C,S7CLER
%ENDIF
%ENDIF
            CALL S7CUCLFR
            LD   A,(HL)
            LD   (S7CALLBL),A
            INC  HL
            LD   A,(HL)
            LD   (S7CALRES),A
            INC  HL
            INC  HL
            INC  HL
            LD   A,(HL)
            LD   (S7ARGCNT),A
            INC  HL
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            LD   (S7CALOFF),DE
            INC  HL
            LD   A,(HL)
            LD   (S8CALFLG),A
            LD   HL,S7CALDEP
            DEC  (HL)
%IF TargetStreamingOutput
            LD   A,(S7CALRES)
            CP   AGDYNTYP
            JR   C,S7CRBKRD
            LD   A,(S8CALFLG)
            LD   D,A
            CALL FTRECUBK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
S7CRBKRD:
%ENDIF
            LD   A,(S8CALFLG)
            AND  R7FAILS
            JR   Z,S7CECLRD
            LD   A,(S7CALDEP)
            OR   A
            JP   NZ,LFERCX
S7CECLRD:
; Publish one completed call description. Stage7CallLabel contains the packed
; target, kind, and keep-result choice. Target-specific signature fields are
; present only for source routines.
S7PUBCL:
            LD   A,(S7CALLBL)
            LD   C,A
            LD   A,SMCALLG
            CALL PSEOPC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            AND  C8SVCFLG
            JR   NZ,S7PUCLCO
            LD   A,(S7ARGCNT)
            CALL TMPUT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(S7CALRES)
            CALL TMPUT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(S8CALFLG)
            CALL TMPUT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
S7PUCLCO:
            LD   HL,(S7CALOFF)
            CALL S7EWD
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL S8EERPHL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(S8CALFLG)
            AND  R7FAILS
            LD   (S8DIRFBL),A
            LD   A,(S7CALRES)
            OR   A
            RET
S7CLTYER:
            LD   HL,S7CALDEP
            DEC  (HL)
            JP   TYTYER
%IF CompilerDiagnosticBranches
S7CLER:
            LD   HL,S7CALDEP
            DEC  (HL)
            SCF
            RET
%ENDIF

; Parse a name-rooted aggregate path or aggregate-returning call. The result
; must still be an address path; scalar selection is rejected by this entry.
%IF TargetStreamingOutput
; Contract: out A,C,carry,zero clobbers sign,parity,halfCarry,B,D,DE,HL,IX,IY
%ELSE
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
%ENDIF
S7PAGV:
            LD   E,TNNAME
            CALL PSEXPECT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL S7FIRTCU
            JR   NZ,S7AGVSYM
            LD   C,1
            CALL S7PCL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CP   AGDYNTYP
            JP   C,TYTYER
%IF TargetStreamingOutput
            LD   C,0
%ENDIF
            JR   S7AGVSFX
S7AGVSYM:
            CALL S7LKAGCU
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,D
            AND  SYAGGFLG
            JP   Z,TYTYER
%IF TargetStreamingOutput
            LD   A,D
            AND  SCMSK
            LD   C,0
            CP   SCPROG
            JR   NZ,S7AVRORD
            INC  C
S7AVRORD:
            PUSH BC
            CALL S7EASYRO
%IF CompilerDiagnosticBranches
            JR   C,S7AVROER
%ENDIF
            POP  BC
            LD   A,(S7PATHT)
            JR   S7AGVSFX
%IF CompilerDiagnosticBranches
S7AVROER:
            POP  BC
            SCF
            RET
%ENDIF
%ELSE
            CALL S7EASYRO
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%ENDIF
S7AGVSFX:
%IF TargetStreamingOutput
            PUSH BC
            CALL S7PPTSFX
%IF CompilerDiagnosticBranches
            JR   C,S7AVSFER
%ENDIF
            POP  BC
%ELSE
            CALL S7PPTSFX
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%ENDIF
            LD   E,A
            LD   A,D
            OR   A
            JP   NZ,TYTYER
            LD   A,E
            CP   AGDYNTYP
            JP   C,TYTYER
            OR   A
            RET
%IF TargetStreamingOutput
%IF CompilerDiagnosticBranches
S7AVSFER:
            POP  BC
            SCF
            RET
%ENDIF
%ENDIF

; Convert a scalar address path to an ordinary typed expression carrier.
; Contract: in A,D out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
S7FISCPT:
            CP   AGDYNTYP
            JP   NC,TYTYER
            LD   (S7PATHT),A
            LD   A,D
            LD   (S7ARGCNT),A
            OR   A
            JR   NZ,S7SCPTRD
            LD   A,(S7PATHT)
            AND  2
            RRCA
            ADD  A,SMLDIND8
S7SCPTE:
            CALL TMOPER
%IF CompilerDiagnosticBranches
            JR   C,S7SCPTER
%ENDIF
S7SCPTRD:
            LD   A,(S7PATHT)
            OR   A
            RET
%IF CompilerDiagnosticBranches
S7SCPTER:
            SCF
            RET
%ENDIF

; Hooks entered by the scalar primary parser after it has consumed the NAME.
S7TYPRRT:
            LD   C,1
            CALL S7PCL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            OR   A
            JP   Z,TYTYER
            CP   AGDYNTYP
            JR   NC,S7TPRTAG
            OR   A
            RET
S7TPRTAG:
            CALL S7PPTSFX
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   S7FISCPT

; Contract: in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
S8TYPRSV:
            LD   HL,(TNSTOFF)
            LD   (S7CALOFF),HL
            LD   C,1
            JR   S8PSVCCL

; Contract: in A,B out A,B,HL,carry,zero clobbers sign,parity,halfCarry,C,D,DE,IX,IY
S8TYPRIK:
            SUB  P8CONST-1
            LD   L,A
            LD   H,B
            LD   B,MTCONST+TYU8
            JP   TYPRETYK

; A is the dense service ID, B is the match loop's proven zero, and C says
; whether a successful u8 result is kept.
; Contract: in A,B,C out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
S8PSVCCL:
            CP   P8PKTSVC
            JR   Z,S8PPKSVC
            CP   P8PORT
            JP   NC,S8PPORCL
            LD   E,A
            LD   D,B
            LD   HL,KWSIGTAB
            ADD  HL,DE
            LD   A,(HL)
            DEC  C
            JR   NZ,S8SVDSRD
            OR   C8KEEP
S8SVDSRD:
            LD   (V8ID),A
            CALL PSXL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(V8ID)
            RRCA
            RRCA
            RRCA
            AND  $03
            JR   Z,S8SVCXR
            LD   D,A
S8SVCARG:
            LD   HL,(S7CALOFF)
            PUSH HL
            LD   A,D
            CALL S7PSCARG
            POP  HL
            LD   (S7CALOFF),HL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
S8SVCXR:
            CALL PSXR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(V8ID)
            LD   (S7CALLBL),A
            AND  V8RESU8
            RLCA
            RLCA
            RLCA
S8SRTYRD:
            LD   (S7CALRES),A
            LD   A,R7FAILS
            LD   (S8CALFLG),A
            JP   S7PUBCL

; Parse the target-defined, infallible packet gateway. The slot is an exact
; u8 constant; the packet is a writable complete u8 array or forwarded u8[]
; carrier. The existing open-array preparation operation publishes address
; and count, while the terminal operation retains only slot and source offset.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
S8PPKSVC:
            CALL PSXL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,TYU8
            CALL TYEXBGK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            PUSH HL
            LD   HL,EXVALPOS
            CALL DGRESTTK
            POP  HL
            LD   E,TYU8
            CALL TYCKASG
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            AND  MTCONST
            JP   Z,TYTYER
            LD   A,L
            LD   (V8ID),A
            LD   E,TNCOMMA
            CALL PSEXPECT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSPEEK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL S7LKAGCU
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            BIT  2,D                     ; program or parameter, never constant
            JP   Z,TYTYER
S8PKRORD:
            LD   DE,EXVALPOS
            CALL DGCOPYTK
            CALL S7PAGV
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,EXVALPOS
            CALL DGRESTTK
            LD   (S7PATHT),A
            CP   AGOAMSK
            JR   NC,S8PKOPAR
            CP   AGDYNTYP
            JP   C,TYTYER
            CALL APTYADR
            LD   A,(HL)
            CP   ATKARRAY
            JP   NZ,TYTYER
            INC  HL
            LD   A,(HL)
            CP   TYU8
            JP   NZ,TYTYER
            JR   S8PKTYRD
S8PKOPAR:
            CP   AGOAMSK+TYU8
            JP   NZ,TYTYER
S8PKTYRD:
            CALL S7POARCR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(V8ID)
            LD   C,A
            LD   A,SMPKTSVC
            CALL PSEOPC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,(S7CALOFF)
            CALL S7EWD
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            XOR  A
            RET

; Return the declared byte capacity of a bounded-string type ordinal.
; Contract: in A out A,carry,zero clobbers sign,parity,halfCarry,DE,HL
S7STRCAP:
            CALL APTYADR
            LD   A,(HL)
            CP   ATKSTR
            JP   NZ,TYTYER
            INC  HL
            LD   A,(HL)
            OR   A
            RET

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
S8EERPHL:
            LD   HL,(SKCUR)
            LD   (M8PTR),HL
            LD   C,3
            XOR  A
S8ERPHLP:
            CALL TMPUT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            DEC  C
            JR   NZ,S8ERPHLP
            RET

S7TPAGSY:
            CALL S7EASYRO
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   S7TPRTAG

; Parse one infallible direct Z80 port operation. The source port is the full
; u16 BC address used by IN/OUT (C). The stored selector is zero for a discarded
; read, one for a retained read, and two for a write.
; Contract: in A,C out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
S8PPORCL:
            SUB  P8PORT
            ADD  A,A
            OR   C
            LD   (V8ID),A
            CALL PSXL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,TYU16
            CALL S7PSCARG
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(V8ID)
            CP   2
            JR   C,S8POARDN
            LD   E,TNCOMMA
            CALL PSEXPECT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,TYU8
            CALL S7PSCARG
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
S8POARDN:
            CALL PSXR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(V8ID)
            LD   C,A
            ADD  A,SMRDPRTD
            CALL TMOPER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,C
            AND  TYU8
            RET

; Current routine name has already been consumed as a complete statement.
%IF HybridLL1Full
%ELSE
S7PCLSTM:
            LD   C,0
            CALL S7PCL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXLN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   TYPSTMCT

; Return one exact aggregate alias and mark the structured path non-fallthrough.
S7PAGRET:
            LD   A,(C7RESTYP)
            PUSH AF
            CALL S7PAGV
%IF CompilerDiagnosticBranches
            JR   C,S7AGREER
%ENDIF
            LD   D,A
            POP  AF
            CP   D
            JP   NZ,TYTYER
            CALL PSXLN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,SMRETAGG
            CALL TMOPER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            XOR  A
            LD   (CTFALLS),A
            JP   TYPSTMCT
%IF CompilerDiagnosticBranches
S7AGREER:
            POP  AF
            SCF
            RET
%ENDIF
%ENDIF

; D contains the aggregate symbol info and DeclarationPayload its root offset.
S7PAGASG:
            LD   A,D
            AND  SCMSK
            JR   NZ,S7AGASWR
            CALL DGINLINE
            DB  DGROASGN
S7AGASWR:
            CALL S7EASYRO
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,1
            LD   (S7PASMOD),A
            LD   A,(S7PATHT)
            CALL S7PPTSFX
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   E,A
            XOR  A
            LD   (S7PASMOD),A
            LD   A,D
            CP   2
            JR   Z,S7STRSAS
            OR   A
            JP   NZ,TYTYER
            LD   A,E
            LD   (S7PATHT),A
            CALL PSXEQ
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,(TNSTOFF)
            LD   (S7CALOFF),HL
            LD   A,(S7PATHT)
            CP   AGDYNTYP
            JR   NC,S7AGCPAS
            LD   E,A
            CALL TYEXBGRU
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   D,A
            LD   A,(S7PATHT)
            LD   E,A
            LD   A,D
            CALL TYCKASG
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL S8KEEPER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(S7PATHT)
            AND  2
            RRCA
            ADD  A,SMSTIND8
S7SCASGE:
%IF Stage7LL1
            JP   TMOPER
%ELSE
            CALL TMOPER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   PSXLN
%ENDIF
S7AGCPAS:
            PUSH AF
            CALL S7PAGV
%IF CompilerDiagnosticBranches
            JR   C,S7AGCPER
%ENDIF
            LD   D,A
            POP  AF
            CP   AGOVIEW
            JP   NC,TYTYER
            CP   D
            JP   NZ,TYTYER
            CALL APGETEXT
            LD   (S7PATHEX),HL
            CALL S8KEEPER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,SMCOPYAG
            CALL TMOPER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%IF Stage7LL1
            JP   S7EEACOF
%ELSE
            CALL S7EEACOF
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   PSXLN
%ENDIF
S7STRSAS:
            CALL PSXEQ
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,TYU8
            CALL TYEXBGRU
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   D,A
            LD   E,TYU8
            CALL TYCKASG
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL S8KEEPER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(S7SROFF)
            LD   C,A
            LD   A,SMSTRRSZ
            CALL PSEOPC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,(EXVALPOS)
%IF Stage7LL1
            JP   S7EWD
%ELSE
            CALL S7EWD
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   PSXLN
%ENDIF
%IF CompilerDiagnosticBranches
S7AGCPER:
            POP  AF
            SCF
            RET
%ENDIF
