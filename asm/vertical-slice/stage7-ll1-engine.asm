; Packed LL(1) interpreter for the complete Stage 7 grammar.
; Token ordinals occupy $00..$3F, nonterminals $40..$7F, and explicit
; semantic or retained-expression actions $80..$FE. Productions store their
; right sides in reverse order so one bounded copy pushes a complete rule.

LLBODSYM     EQU $40+20
LLSTMMSK   EQU $FA
%IF AggregateCallSlices
%IF TargetStreamingOutput
LLDEPTH    EQU TGCWKEND
%ELSE
LLDEPTH    EQU SSMEND
%ENDIF
%ELSE
LLDEPTH    EQU S7WKEND
%ENDIF
LLSTACK     EQU LLDEPTH+1
%IF AggregateCallSlices
%IF TargetStreamingOutput
LLWKEND  EQU TGWKEND
%ELSE
LLWKEND  EQU LLSTACK+HYLLCAP
%ENDIF
%ELSE
LLWKEND  EQU LLSTACK+HYLLCAP
%ENDIF
DGLLCAP EQU 87

; Push the start symbol and run until the grammar stack is empty. Explicit
; actions return through HybridLL1ActionReturn with carry reporting failure.
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
LLPARSE:
            XOR  A
            LD   (LLDEPTH),A
            LD   A,LLSTART
            CALL LLPUSHS
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
LLLOOP:
            LD   A,(LLDEPTH)
            OR   A
            RET  Z
            CALL LLPOPS
            CP   $40
            JR   C,LLTERM
            CP   $80
            JR   C,LLNTERM

            ; Action ordinal -> absolute routine address. A retains the
            ; zero-based ordinal for parameterised physical handlers.
            SUB  $80
            LD   L,A
            LD   H,0
            ADD  HL,HL
            LD   DE,LLACTDIR
            ADD  HL,DE
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            EX   DE,HL
            LD   DE,LLACTRET
            PUSH DE
            JP   (HL)
LLACTRET:
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   LLLOOP

LLSTRSEL:
LLSELERR:
            CALL DGINLINE
            DB  DGSELCLS

LLTERM:
            LD   L,A
            CP   TOKENEND
            JR   NZ,LLTERMRD
            CALL PSPEEK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CP   TNELSE
            JR   Z,LLSTRSEL
            CP   TNCASE
            JR   Z,LLSTRSEL
LLTERMRD:
            LD   E,L
            CALL PSEXPECT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   LLLOOP

LLNTERM:
            ; A standalone handle can arrive while selecting the routine
            ; body, the local-list continuation, the statement sequence, or
            ; the statement itself. Those generated ordinals differ from the
            ; routine-body ordinal only in bits 0 and 2. Peek without
            ; consuming so all other prediction and diagnostics stay exact.
            LD   L,A
            SUB  LLBODSYM
            AND  LLSTMMSK
            JR   NZ,LLSTMRDY
            CALL PSPEEK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CP   TNHDL
            JR   NZ,LLSTMRDY
LLHANDLE:
            CALL DGINLINE
            DB  DGHDLINE
LLSTMRDY:
            LD   A,L
            SUB  $40
            LD   L,A
            CP   LLHIROW
            SBC  A,A
            INC  A
            LD   B,A
            LD   H,0
            ADD  HL,HL
            LD   DE,LLROWDIR
            ADD  HL,DE
            LD   E,(HL)
            INC  HL
            LD   A,(HL)
            PUSH AF
            LD   D,B
            LD   HL,LLROWS
            ADD  HL,DE
            CALL PSPEEK
%IF CompilerDiagnosticBranches
            JR   C,LLPEEKER
%ENDIF
            LD   C,A
LLPREDNX:
            LD   B,(HL)
            INC  HL
LLPREDTK:
            LD   A,(HL)
            LD   E,A
            AND  $7F
            CP   C
            JR   Z,LLPREDOK
            INC  HL
            BIT  7,E
            JR   Z,LLPREDTK
            BIT  7,B
            JR   NZ,LLPREDER
            JR   LLPREDNX
LLPREDER:
            POP  AF
            JP   DGSET
%IF CompilerDiagnosticBranches
LLPEEKER:
            POP  BC
            RET
%ENDIF
LLPREDOK:
            POP  AF
            LD   A,B
            AND  $7F
            CALL LLPUSHP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   LLLOOP

; A is a production ordinal. Adjacent directory offsets delimit its body.
; Contract: in A out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
LLPUSHP:
            CP   LLPRSPLT
            LD   DE,LLPRODS
            LD   HL,LLPRDIR
            JR   C,LLPRODRD
            SUB  LLPRSPLT
            LD   DE,LLPRHIGH
            LD   HL,LLPDHIGH
LLPRODRD:
            LD   C,A
            LD   B,0
            ADD  HL,BC
            LD   C,(HL)
            INC  HL
            LD   A,(HL)
            SUB  C
            LD   B,A
            LD   A,C
            LD   L,A
            LD   H,0
            ADD  HL,DE
            LD   A,B
            OR   A
            RET  Z
            LD   A,(LLDEPTH)
            LD   C,A
            ADD  A,B
            JR   C,LLCAPERR
            CP   HYLLCAP+1
            JR   NC,LLCAPERR
            LD   (LLDEPTH),A
            PUSH HL
            LD   A,C
            LD   E,A
            LD   D,0
            LD   HL,LLSTACK
            ADD  HL,DE
            EX   DE,HL
            POP  HL
            LD   C,B
            LD   B,0
            LDIR
            XOR  A
            RET

; Contract: in A out A,carry,zero clobbers sign,parity,halfCarry,C,DE,HL
LLPUSHS:
            LD   C,A
            LD   A,(LLDEPTH)
            CP   HYLLCAP
            JR   NC,LLCAPERR
            LD   L,A
            LD   H,0
            LD   DE,LLSTACK
            ADD  HL,DE
            LD   (HL),C
            LD   HL,LLDEPTH
            INC  (HL)
            XOR  A
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,DE,HL
LLPOPS:
            LD   A,(LLDEPTH)
            DEC  A
            LD   (LLDEPTH),A
            LD   L,A
            LD   H,0
            LD   DE,LLSTACK
            ADD  HL,DE
            LD   A,(HL)
            OR   A
            RET

LLCAPERR:
            CALL DGINLINE
            DB  DGLLCAP

LLENGEND:
