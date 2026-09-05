; E is the expected token ordinal. An ordinary mismatch reports the token
; ordinal with DiagnosticExpectedTokenBase set.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
PSXLN:
            LD   E,TNNL
; Contract: in E out A,C,carry,zero clobbers sign,parity,halfCarry,B,D,DE,HL
PSEXPECT:
            LD   L,E
            CALL PSTK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CP   L
            RET  Z
            LD   A,L
            OR   DXTOKBAS
            JR   DGSET

; The expression parser needs one token of lookahead. Token metadata remains
; current until another tokenizer request, so buffering kind and word payload
; is sufficient for names, positions, numbers, and characters.
; Contract: out A,BC,HL,carry,zero clobbers sign,parity,halfCarry,D,DE
PSPEEK:
            LD   BC,(PSLOOKV)
            LD   A,(PSLOOK)
            OR   A
            RET  NZ
PSPKEMP:
            PUSH HL
%IF TargetStreamingOutput
            CALL TKNEXTLP
%ELSE
            CALL TKNEXT
%ENDIF
            POP  HL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   (PSLOOK),A
            LD   (PSLOOKV),BC
            RET

; Expression reductions keep the left value in HL across lookahead consumption.
; Contract: out A,BC,HL,carry,zero clobbers sign,parity,halfCarry,D,DE
PSTK:
            CALL PSPEEK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   D,A
            XOR  A
            LD   (PSLOOK),A
            XOR  D
            RET

; Frequent token checks enter the common ParserExpect tail. These wrappers
; trade one shared seven-byte body for each repeated eight-byte inline check.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
PSXL:
            LD   E,TNLPAR
            JR   PSEXPECT
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
PSXR:
            LD   E,TNRPAR
            JR   PSEXPECT
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
PSXAS:
            LD   E,TOKENAS
            JR   PSEXPECT
%IF LegacyCompilerSlices
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
PSXU8:
            LD   E,TOKENU8
            JP   PSEXPECT

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
PSXASU8:
            CALL PSXAS
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   PSXU8
%ENDIF

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
PSXEQ:
            LD   E,TNEQ
            JR   PSEXPECT
%IF LegacyCompilerSlices
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
PSXSUB:
            LD   E,TOKENSUB
            JP   PSEXPECT
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
PSXLBR:
            LD   E,TNLBRK
            JP   PSEXPECT
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
PSXRBR:
            LD   E,TNRBRK
            JP   PSEXPECT
%ENDIF
%IF HybridLL1Full
%ELSE
; Contract: in B,D,HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
PSXNM:
            PUSH BC
            PUSH DE
            PUSH HL
            LD   E,TNNAME
            CALL PSEXPECT
            POP  HL
            POP  DE
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL TKNAMEEQ
            JR   NC,PSXNMNO
            OR   A
            RET
PSXNMNO:
            LD   A,D
            JP   DGSET

%IF LegacyCompilerSlices
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
PSXIX:
            LD   D,DXIDX
            LD   HL,KWINDEX
            LD   B,5
            JP   PSXNM

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
PSXBY:
            LD   D,DXBYTS
            LD   HL,KWBYTES
            LD   B,5
            JP   PSXNM

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
PSXRES:
            LD   D,DXRES
            LD   HL,KWRESULT
            LD   B,6
            JP   PSXNM
%ENDIF

; Compare the current name token with the one retained by the forward.
; Contract: in D out A,carry,zero clobbers sign,parity,halfCarry,B,D,DE,HL
PSISFWD:
            PUSH DE
%IF NativeStreamingSource
            LD   HL,FWNAMPTR
            CALL TKRECEQ
%ELSE
            LD   HL,(FWNAMPTR)
            LD   A,(FWNAMLEN)
            LD   B,A
            CALL TKNAMEEQ
%ENDIF
            POP  DE
            JR   NC,PSNOTFWD
            OR   A
            RET
PSNOTFWD EQU PSXNMNO

; Contract: in D out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
PSXFWNM:
            PUSH DE
            LD   E,TNNAME
            CALL PSEXPECT
            POP  DE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   PSISFWD

; Retain the current name token as the one complete forward signature.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,HL
PSRTFWNM:
%IF NativeStreamingSource
            PUSH BC
            LD   HL,FWNAMPTR
            CALL TKRETAIN
            POP  BC
%ELSE
            LD   HL,(TNLEXPTR)
            LD   (FWNAMPTR),HL
            LD   A,(TNLEN)
            LD   (FWNAMLEN),A
%ENDIF
            OR   A
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,HL
PSRTFWPA:
%IF NativeStreamingSource
            PUSH BC
            LD   HL,FWPARPTR
            CALL TKRETAIN
            POP  BC
%ELSE
            LD   HL,(TNLEXPTR)
            LD   (FWPARPTR),HL
            LD   A,(TNLEN)
            LD   (FWPARLEN),A
%ENDIF
            OR   A
            RET
%ENDIF

%IF LegacyCompilerSlices
; Contract: in D out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
PSXFWPAR:
            PUSH DE
            LD   E,TNNAME
            CALL PSEXPECT
            POP  DE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,(FWPARPTR)
            LD   A,(FWPARLEN)
            LD   B,A
            PUSH DE
            CALL TKNAMEEQ
            POP  DE
            JR   NC,PSFWPANO
            OR   A
            RET
PSFWPANO:
            LD   A,D
            JP   DGSET
%ENDIF

%IF LegacyCompilerSlices
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
PSXWR:
            LD   E,TNNAME
            CALL PSEXPECT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,KWWRTOUT
            LD   B,15
            CALL TKNAMEEQ
            JR   C,PSXWRYES
            LD   HL,KWINDEX
            LD   B,5
            CALL TKNAMEEQ
            JR   C,PSACCNT
            CALL DGINLINE
            DB  DXWR
PSACCNT:
            CALL DGINLINE
            DB  DGACTCTR
PSXWRYES:
            OR   A
            RET
%ENDIF

%IF LegacyCompilerSlices
; Contract: out A,C,carry,zero clobbers sign,parity,halfCarry,B,D,DE,HL
PSXNUM:
            LD   E,TNNUM
            CALL PSEXPECT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,C
            OR   A
            RET
%ENDIF

; Append one operation followed by the byte in C. The helper preserves the
; operand across the sink's internal cursor work.
; Contract: in A,C out A,carry,zero clobbers sign,parity,halfCarry,B,D,DE,HL
PSEOPC:
            CALL TMOPER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,C
            JP   TMPUT

%IF LegacyCompilerSlices
; A resolved scalar symbol is represented by its class in A and its storage
; ordinal in C. Expressions emit postfix operations, leaving evaluation order
; independent of either backend's register choices.
; Contract: in A,C out A,carry,zero clobbers sign,parity,halfCarry,B,D,DE,HL
PSESYMLD:
            CP   SIPU8
            JR   Z,PSEPGLD
            CP   SILU8
            JR   NZ,PSXSC
            LD   A,SMLDLU8
            JP   PSEOPC
PSEPGLD:
            LD   A,SMLDPU8
            JP   PSEOPC

; Contract: in A,C out A,carry,zero clobbers sign,parity,halfCarry,B,D,DE,HL
PSESYMST:
            CP   SIPU8
            JR   Z,PSEPGST
            CP   SILU8
            JR   NZ,PSXSC
            LD   A,SMSTLU8
            JP   PSEOPC
PSEPGST:
            LD   A,SMSTPU8
            JP   PSEOPC
%ENDIF

PSXSC:
            LD   A,DXSCA
            ; The legacy proof layouts put this target outside JR range.
%IF AggregateCallSlices
            JR   DGSET
%ELSE
            JP   DGSET
%ENDIF

%IF LegacyCompilerSlices
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
PSPSCPRI:
            CALL PSTK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CP   TNNUM
            JR   Z,PSPSCLIT
            CP   TNNAME
            JR   NZ,PSXSC
            CALL SBLOOKUP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   PSESYMLD
PSPSCLIT:
            LD   A,SMLITU8
            JP   PSEOPC

; Precedence climbing uses one loop for both admitted operators. B is the
; minimum precedence; recursive calls only represent nested precedence, not a
; separate parser routine per grammar level.
; Contract: in B out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
PSPSEXMI:
            PUSH BC
            CALL PSPSCPRI
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
PSPSEXLP:
            PUSH BC
            CALL PSPEEK
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CP   TNPLUS
            JR   Z,PSSCADD
            CP   TNSTAR
            JR   NZ,PSSCEXDN
            LD   C,2
            LD   D,SMMULU8
            JR   PSSCOP
PSSCADD:
            LD   C,1
            LD   D,SMADDU8
PSSCOP:
            LD   A,C
            CP   B
            JR   C,PSSCEXDN
            PUSH BC
            PUSH DE
            CALL PSTK
            POP  DE
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            PUSH BC
            PUSH DE
            LD   B,C
            INC  B
            CALL PSPSEXMI
            POP  DE
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,D
            PUSH BC
            CALL TMOPER
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   PSPSEXLP
PSSCEXDN:
            OR   A
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
PSPSCEX:
            LD   B,1
            JP   PSPSEXMI
%ENDIF

%IF HybridLL1Full
%ELSE
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
PSXRTHDR:
            LD   D,DXMAIN
            LD   HL,NAMEMAIN
            LD   B,4
            CALL PSXNM
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
            LD   E,TNFAILS
            CALL PSEXPECT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   PSXLN
%ENDIF

%IF LegacyCompilerSlices
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
PSXIXDC:
            LD   E,TOKENVAR
            CALL PSEXPECT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXIX
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXAS
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXU8
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   PSXEQ
%ENDIF

%IF HybridLL1Full
            ; Packed actions consume the active `else fail` grammar.
%ELSE
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
PSXEERLN:
            CALL PSXELSER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            ; The legacy proof layouts put this target outside JR range.
%IF AggregateCallSlices
            JR   PSXLN
%ELSE
            JP   PSXLN
%ENDIF

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
PSXELSER:
            LD   E,TNELSE
            CALL PSEXPECT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   E,TNFAIL
            ; The legacy proof layouts put this target outside JR range.
%IF AggregateCallSlices
            JR   PSEXPECT
%ELSE
            JP   PSEXPECT
%ENDIF
%ENDIF

%IF LegacyCompilerSlices
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
PSXPROLN:
            CALL PSXEERLN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,SMPROP
            JP   TMOPER

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
PSXENDLN:
            LD   E,TOKENEND
            CALL PSEXPECT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   PSXLN

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
PSLOOPSB:
            CALL PSXRTHDR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF

            CALL PSXIXDC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,SMDECLU8
            CALL TMOPER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXNUM
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL TMPUT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXLN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF

            LD   E,TOKENFOR
            CALL PSEXPECT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXIX
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXEQ
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,SMFORU8
            CALL TMOPER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXNUM
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL TMPUT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   E,TNUNT
            CALL PSEXPECT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXNUM
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL TMPUT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXLN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF

            CALL PSXWR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,SMWROBYT
            CALL TMOPER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   E,TNCHAR
            CALL PSEXPECT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,C
            CALL TMPUT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXPROLN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF

            CALL PSXENDLN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,SMENDLP
            CALL TMOPER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   PSFINRT
%ENDIF

; The first general scalar path admits bounded program variables and scalar
; locals, then parses a main body as assignment and output statements. The
; current token is the program variable's name on entry.
%IF LegacyCompilerSlices
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
PSSCALDC:
            LD   A,(NXPROG)
            LD   E,A
            LD   D,SIPU8
            CALL SBPREP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   PSSCLPRE
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
PSSCLPRE:
            CALL PSXASU8
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   PSSCLU8
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
PSSCLU8:
            CALL PSXEQ
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXNUM
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   B,0
            PUSH BC
            LD   A,SMDEFPU8
            CALL TMOPER
%IF CompilerDiagnosticBranches
            JR   C,PSSPOPER
%ENDIF
            LD   A,(NXPROG)
            CALL TMPUT
%IF CompilerDiagnosticBranches
            JR   C,PSSPOPER
%ENDIF
            POP  BC
            LD   A,C
            CALL TMPUT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXLN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL SBCOMMIT
            LD   HL,NXPROG
            INC  (HL)
            XOR  A
            RET
%IF CompilerDiagnosticBranches
PSSPOPER:
            POP  BC
            RET
%ENDIF

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
PSPSLODC:
            LD   E,TNNAME
            CALL PSEXPECT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(NXLOCAL)
            LD   E,A
            LD   D,SILU8
            CALL SBPREP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXASU8
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXEQ
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(NXLOCAL)
            LD   C,A
            LD   A,SMDLCLU8
            CALL PSEOPC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSPSCEX
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(NXLOCAL)
            LD   C,A
            LD   A,SMSTLU8
            CALL PSEOPC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXLN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL SBCOMMIT
            LD   HL,NXLOCAL
            INC  (HL)
            XOR  A
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
PSPSCASG:
            CALL SBLOOKUP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   B,A
            PUSH BC
            CALL PSXEQ
%IF CompilerDiagnosticBranches
            JR   C,PSSCASER
%ENDIF
            CALL PSPSCEX
%IF CompilerDiagnosticBranches
            JR   C,PSSCASER
%ENDIF
            POP  BC
            LD   A,B
            CALL PSESYMST
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   PSXLN
%IF CompilerDiagnosticBranches
PSSCASER:
            POP  BC
            RET
%ENDIF

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
PSPSCWR:
            LD   HL,(TNSTOFF)
            PUSH HL
            CALL PSXL
%IF CompilerDiagnosticBranches
            JR   C,PSSCWRER
%ENDIF
            CALL PSPSCEX
%IF CompilerDiagnosticBranches
            JR   C,PSSCWRER
%ENDIF
            CALL PSXR
%IF CompilerDiagnosticBranches
            JR   C,PSSCWRER
%ENDIF
            LD   A,SMWRVU8
            CALL TMOPER
%IF CompilerDiagnosticBranches
            JR   C,PSSCWRER
%ENDIF
            POP  HL
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
            JP   PSXEERLN
%IF CompilerDiagnosticBranches
PSSCWRER:
            POP  HL
            RET
%ENDIF

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
PSPSCSTM:
            CALL PSPEEK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CP   TOKENEND
            JR   Z,PSPSCEND
            CP   TNNAME
            JP   NZ,PSXSC
            CALL PSTK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,KWWRTOUT
            LD   B,15
            CALL TKNAMEEQ
            JR   NC,PSPSASST
            CALL PSPSCWR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   PSPSCSTM
PSPSASST:
            CALL PSPSCASG
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   PSPSCSTM
PSPSCEND:
            CALL PSTK
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

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
PSSCLTOP:
            CALL PSPEEK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CP   TOKENVAR
            JR   NZ,PSSCLMN
            CALL PSTK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   E,TNNAME
            CALL PSEXPECT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSSCALDC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   PSSCLTOP
PSSCLMN:
            CP   TOKENSUB
            JR   NZ,PSSXTOLV
            CALL PSTK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXRTHDR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,SMBGMAIN
            CALL TMOPER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
PSPSCLOC:
            CALL PSPEEK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CP   TOKENVAR
            JR   NZ,PSPSCSTM
            CALL PSTK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSPSLODC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   PSPSCLOC
PSSXTOLV:
            CALL DGINLINE
            DB  DXTOPLVL
%ENDIF

%IF HybridLL1Full
%ELSE
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
PSPPGAVA:
            LD   E,TNNAME
            CALL PSEXPECT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   TYPPGAVA
%ENDIF

; The older array slice is selected by the bracketed type suffix. Its body is
; still deliberately fixed; this split only keeps scalar names unrestricted.
%IF LegacyCompilerSlices
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
PSARRAY8:
            CALL PSXLBR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,SMARRU8
            CALL TMOPER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXNUM
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CP   4
            JR   Z,PSARLEYE
            CALL DGINLINE
            DB  DXARRLEN
PSARLEYE:
            CALL TMPUT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXRBR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXEQ
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXLBR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   C,4
PSARINI:
            PUSH BC
            CALL PSXNUM
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL TMPUT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            DEC  C
            JR   Z,PSARINDN
            PUSH BC
            LD   E,TNCOMMA
            CALL PSEXPECT
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   PSARINI
PSARINDN:
            CALL PSXRBR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXLN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF

            LD   E,TOKENSUB
            CALL PSEXPECT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXRTHDR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF

            CALL PSXIXDC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   D,DXRD
            LD   HL,KWREADIN
            LD   B,13
            CALL PSXNM
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
            LD   A,SMRDIBYT
            CALL TMOPER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXPROLN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,SMSTRSU8
            CALL TMOPER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF

            CALL PSXWR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXBY
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXLBR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXIX
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXRBR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,SMLDAU8
            CALL TMOPER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,SMWROU8
            CALL TMOPER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXPROLN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
PSFINRT:
            CALL PSXENDLN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,SMRET
            CALL TMOPER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   E,TOKENEOF
            JP   PSEXPECT
%ENDIF

; Parse the first general routine-call slice. It deliberately admits one
; retained forward signature while exercising exact completion and parameter
; lookup, scalar call/result flow, and direct recursion.
%IF LegacyCompilerSlices
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
PSCALLFW:
            CALL PSXSUB
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   E,TNNAME
            CALL PSEXPECT
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
            CALL PSRTFWPA
            CALL PSXASU8
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXASU8
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXLN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,1
            LD   (FWORD),A
            CALL PSXSUB
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXRTHDR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   E,TOKENVAR
            CALL PSEXPECT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXRES
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXASU8
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXEQ
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   D,DGFWDMIS
            CALL PSXFWNM
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,SMCLITU8
            CALL TMOPER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(FWORD)
            CALL TMPUT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXNUM
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL TMPUT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXLN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF

            CALL PSXWR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXRES
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,SMWRLU8
            CALL TMOPER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXEERLN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXENDLN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,SMENDRTN
            CALL TMOPER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF

            CALL PSXSUB
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
            LD   A,1
            LD   (FWDONE),A
            LD   A,SMFWDU8
            CALL TMOPER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(FWORD)
            CALL TMPUT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF

            LD   E,TOKENIF
            CALL PSEXPECT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   D,DXVAL
            CALL PSXFWPAR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXEQ
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,SMIFPARZ
            CALL TMOPER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXNUM
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            OR   A
            JP   NZ,PSXZ
            CALL TMPUT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXLN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF

            LD   E,TNRET
            CALL PSEXPECT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   D,DXVAL
            CALL PSXFWPAR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXLN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,SMRETPAR
            CALL TMOPER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXENDLN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,SMENDIF
            CALL TMOPER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF

            LD   E,TNRET
            CALL PSEXPECT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   D,DGFWDMIS
            CALL PSXFWNM
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   D,DXVAL
            CALL PSXFWPAR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   E,TNMIN
            CALL PSEXPECT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,SMRTSELF
            CALL TMOPER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(FWORD)
            CALL TMPUT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXNUM
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL TMPUT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXLN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL PSXENDLN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,SMENDRTN
            CALL TMOPER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(FWDONE)
            OR   A
            JR   Z,PSFWINC
            LD   E,TOKENEOF
            JP   PSEXPECT
PSXZ:
            CALL DGINLINE
            DB  DXNUM
PSFWINC:
            CALL DGINLINE
            DB  DGFWDINC
%ENDIF

%IF HybridLL1Full
%ELSE
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
PSPPG:
            CALL PSTK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CP   TOKENSUB
            JP   Z,TYPMAATK
            CP   TOKENVAR
            JP   Z,PSPPGAVA
            CP   TNFWD
            JP   Z,TYPFWATK
            CP   TNCONST
            JP   Z,TYPTLKAT
            CP   TNREC
            JP   Z,APPREATK
            CALL DGINLINE
            DB  DXTOPLVL
%ENDIF

; A is the stable source-part identity; HL..DE is the half-open byte range.
%IF LegacyCompilerSlices
; Contract: in A,DE,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CPLPSL:
            CALL CPSLINIT
            CALL PSTK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CP   TOKENSUB
            JP   NZ,PSSXTOLV
            CALL PSLOOPSB
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   TMFINISH
; Contract: in A,DE,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CPCLSL:
            CALL CPSLINIT
            CALL PSTK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CP   TNFWD
            JP   NZ,PSSXTOLV
            CALL PSCALLFW
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   TMFINISH
%ENDIF
%IF AggregateCallSlices
%ELSE
            ; Contract: in A,DE,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CPSL:
            CALL CPSLINIT
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
%IF TargetStreamingOutput
%ELSE
; Contract: in A,DE,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CPSLINIT:
%IF AggregateCallSlices
            PUSH AF
            XOR  A
            LD   (SSPREM),A
            POP  AF
%ENDIF
            CALL SAINIT
%ENDIF
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CPSLRSST:
%IF CompilerNonlocalDiagnostics
            ; The production entry resets state before SourceInitializeParts.
            ; Clear the complete live-state prefix, but retain the initializer
            ; and static-image buffers plus the later target descriptor and
            ; diagnostic-abort words.
            XOR  A
            LD   HL,CPSTBASE
            LD   (HL),A
            LD   DE,CPSTBASE+1
            LD   BC,AIBAS-CPSTBASE-1
            LDIR
            LD   HL,SMPAYBAS
            LD   (SKCUR),HL
            RET
%ELSE
            XOR  A
            LD   (DGCODE),A
            LD   (DGPARTID),A
%IF AggregateCallSlices
            LD   HL,SMPAYBAS
            LD   (SKCUR),HL
            LD   (SKOPCNT),A
            LD   (SMBUFBAS),A
%ELSE
            CALL TMRESET
%ENDIF
            XOR  A
            LD   (PSLOOK),A
%IF AggregateCallSlices
            LD   (SYCNT),A
            LD   (NXLOCAL),A
            LD   (NXPROG),A
%ELSE
            CALL SBRESET
%ENDIF
            XOR  A
            LD   HL,AGMODE
            LD   B,AGHASINI-AGMODE+1
CPSRAGLP:
            LD   (HL),A
            INC  HL
            DJNZ CPSRAGLP
            LD   (IMGLEN),A
            LD   (IMGLEN+1),A
%IF SegmentedOutput
            LD   (ROILEN),A
            LD   (ROILEN+1),A
%ENDIF
%IF AggregateCallSlices
            LD   (PGBSSLEN),A
            LD   (PGBSSLEN+1),A
%ENDIF
            LD   (FWDONE),A
            LD   (FWORD),A
            RET
%ENDIF
