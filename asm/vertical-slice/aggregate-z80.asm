; Aggregate Z80 publisher. The complete checked initialized-data and constant
; image is emitted after
; the initial JP and before main's first instruction. TypedBeginMain
; patches the JP operand to the first code byte, so source execution cannot
; observe initialization in progress.

%IF TargetStreamingOutput
; Emit every aggregate constant exactly once in declaration order. Symbols
; retain per-bank offsets, while IY walks the single declaration-ordered
; compiler backing image. Switching banks never replays source or semantics.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
ZGBCONST:
            LD   IY,IMGBAS
            LD   DE,(IMGLEN)
            ADD  IY,DE
            LD   A,(SYCNT)
            OR   A
            LD   B,A
            JR   Z,ZGBSTR
            LD   C,0
            LD   IX,SYTABBAS
ZGCSYMLP:
            LD   A,(IX+3)
            LD   D,A
            AND  SYAGGFLG+SCMSK
            CP   SYAGGFLG+SCCONST
            JR   NZ,ZGCNEXT
            LD   A,D
            CALL FTUPKBK
            PUSH BC
            CALL ZTSELBK
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(IX+SYTYPID)
            CALL APGETEXT
            EX   DE,HL
ZGCBYTLP:
            LD   A,D
            OR   E
            JR   Z,ZGCNEXT
            LD   A,(IY+0)
            INC  IY
            PUSH BC
            PUSH DE
            CALL EMITBYTE
            POP  DE
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            DEC  DE
            JR   ZGCBYTLP
ZGCNEXT:
            LD   DE,SYENTSZ
            ADD  IX,DE
            INC  C
            DJNZ ZGCSYMLP

; Anonymous literal objects follow all named aggregate constants in the
; staging image. Their compiler-only final byte retains the source bank;
; publish the preceding sealed bytes and restore the permanent zero.
ZGBSTR:
            LD   HL,IMGBAS
            LD   DE,(IMGLEN)
            ADD  HL,DE
            LD   DE,(ROILEN)
            ADD  HL,DE
            PUSH HL
            POP  IX                      ; end of staged read-only bytes
            PUSH IY
            POP  HL                      ; first anonymous literal
ZGSTRLP:
            PUSH IX
            POP  DE
            OR   A
            SBC  HL,DE
            RET  Z
            ADD  HL,DE                   ; restore the current object
            LD   C,(HL)
            LD   A,C
            OR   A
            JR   NZ,ZGSTREXT
            INC  BC                      ; empty literal capacity is one
ZGSTREXT:
            INC  BC
            INC  BC
            PUSH HL
            PUSH BC
            ADD  HL,BC
            DEC  HL
            LD   A,(HL)                  ; compiler-only source bank
            LD   (HL),0                  ; publish the permanent terminator
            CALL ZTSELBK
            POP  BC
            POP  HL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEBLOCK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   ZGSTRLP
%ENDIF

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ZGPROG:
%IF TargetStreamingOutput
            LD   IX,(TDPTR)
            CALL ZTFLAT
%IF CompilerDiagnosticBranches
            JP   C,ZTABORT
%ENDIF
%ELSE
%IF AggregateCallSlices
            LD   HL,MMGCEND
%ELSE
            LD   HL,MMGENLIM
%ENDIF
%ENDIF
; Contract: in HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ZGPRGLIM:
%IF TargetStreamingOutput
            CALL ZTCMPBNK
            JR   NZ,ZGDISP
            ; BeginTargetFlatProgram already selected the first read-only byte.
            CALL ZTLDMODE
            JR   Z,ZGLOADRO
            CALL ZTRTINIT
%IF CompilerDiagnosticBranches
            JP   C,ZGABORT
%ENDIF
            JR   ZGCOPYOK
ZGLOADRO:
            LD   HL,IMGBAS
            LD   DE,(IMGLEN)
            ADD  HL,DE
            LD   BC,(ROILEN)
            JR   ZGCOPYSL
ZGCOPYOK:
%ELSE
%IF AggregateCallSlices
            CALL ZESEGBEG
            JP   C,ZESEGABT
            LD   A,SGRODAT
            CALL ZESEGSEL
%ELSE
            CALL ZXPGHEAD
            JP   C,ZEABORT
%ENDIF
%ENDIF
%IF SegmentedOutput
            LD   HL,(ROILEN)
            LD   BC,(IMGLEN)
            ADD  HL,BC
            LD   B,H
            LD   C,L
            LD   HL,IMGBAS
%ELSE
            LD   HL,IMGBAS
            LD   BC,(IMGLEN)
%ENDIF
%IF TargetStreamingOutput
ZGCOPYSL:
            CALL ZEBLOCK
%IF CompilerDiagnosticBranches
            JP   C,ZGABORT
%ENDIF
%ELSE
            LD   A,B
            OR   C
            JR   Z,ZGDISP
ZGCOPYLP:
            LD   A,(HL)
            INC  HL
            PUSH BC
            PUSH HL
            CALL EMITBYTE
            POP  HL
            POP  BC
            JP   C,ZGABORT
            DEC  BC
            LD   A,B
            OR   C
            JR   NZ,ZGCOPYLP
%ENDIF
ZGDISP:
%IF TargetStreamingOutput
            CALL ZTCMPBNK
            JR   NZ,ZGBOUNDS
            LD   HL,(EMCUR)
            LD   (TGCODBAS),HL
            CALL ZTLDMODE
            JR   NZ,ZGCODEOK
            LD   HL,(TGCODCAP)
            LD   (EMLIM),HL
ZGCODEOK:
            LD   HL,(TCROBAS)
            LD   (TGCRBAS),HL
            LD   HL,(TCROCAP)
            LD   (TGCROCAP),HL
ZGBOUNDS:
%ELSE
%IF AggregateCallSlices
            LD   A,SGCODE
            CALL ZESEGSEL
            CALL ZXSGHEAD
            JP   C,ZESEGABT
%ENDIF
%ENDIF
            CALL ZXDISP
%IF CompilerDiagnosticBranches
            JP   C,ZGABORT
%ENDIF
%IF TargetStreamingOutput
            JP   ZTFINFLT
%ELSE
%IF AggregateCallSlices
            JP   ZESEGFIN
%ELSE
            JP   ZEFINISH
%ENDIF
%ENDIF

%IF TargetStreamingOutput
ZGABORT    EQU ZTABORT
%ELSE
%IF AggregateCallSlices
ZGABORT    EQU ZESEGABT
%ELSE
ZGABORT    EQU ZEABORT
%ENDIF
%ENDIF
