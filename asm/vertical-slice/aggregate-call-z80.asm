; Stage 7 direct-Z80 lowering for opaque aggregate carriers. Every source
; scalar and alias carrier occupies one canonical word on the evaluation
; stack; declared storage widths remain unchanged.

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX
ZABEGRT:
            LD   C,A
            CALL ZENEXTB     ; retained parameter count
%IF TargetStreamingOutput
            CALL ZENEXTB     ; target bank
            PUSH BC
            CALL ZTSELBK
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%ENDIF
ZADEFRT:
            CALL ZCDEFLBL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,ZEXFRBYT
            JP   ZEEIGHT

; Operands are exact type, negative-frame byte offset, and positive caller
; displacement. The prologue copies one canonical argument into this
; activation before any body statement runs.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ZABINDP:
            LD   (S7PATHT),A
            CALL ZENEXTB
            CPL
            LD   (S7PATHOF),A       ; -(destination + 1)
            CALL ZENEXTB
            LD   (S7ARGIDX),A    ; positive source displacement
            CALL S7PCOPST
            JR   Z,ZABINDOS
            CP   AGDYNTYP
            JR   NC,ZABINDW
            BIT  1,A
            JR   NZ,ZABINDW
            CALL ZEBINCHK
            DB  $3B                      ; DEC SP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,ZALDIXL
            CALL ZAARGIDX
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,ZASTIXL
            JR   ZAPATOFF
ZABINDOS:
            CALL ZEBINCHK
            DB  $3B                      ; third activation byte
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
ZABINDW:
            CALL ZEPINLIN
            DB  ZEDECSP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,ZALDIXL
            CALL ZAARGIDX
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEPINLIN
            DB  ZELDIXH
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(S7ARGIDX)
            INC  A
            CALL EMITBYTE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,ZASTIXL
            CALL ZAPATOFF
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEPINLIN
            DB  ZESTIXH
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(S7PATHOF)
            DEC  A
            CALL EMITBYTE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL S7PCOPST
            JR   Z,ZABINDCP
            OR   A
            RET
ZABINDCP:
            CALL ZEPINLIN
            DB  ZELDIXL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(S7ARGIDX)
            INC  A
            INC  A
            CALL EMITBYTE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEPINLIN
            DB  ZESTIXL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(S7PATHOF)
            DEC  A
            DEC  A
            JP   EMITBYTE

; Contract: in HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZAARGIDX:
            CALL EMITPAIR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(S7ARGIDX)
            JP   EMITBYTE

; Contract: in HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZAPATOFF:
            CALL EMITPAIR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(S7PATHOF)
            JP   EMITBYTE

; Emit a bounds trap after a target helper has returned carry. The branch
; around the trap is patched before normal lowering continues.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ZABOUNDS:
            CALL ZEJRNC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   (EMFAIL),DE
            LD   HL,(S7CALOFF)
            LD   A,1
            CALL ZXTRBODY
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   DE,(EMFAIL)
            JP   ZEPHERE

; Contract: out A,DE,HL,carry,zero clobbers sign,parity,halfCarry
ZACALOFF:
            CALL ZEREADW
            LD   (S7CALOFF),DE
            RET

; Retain the source position of a propagated failure. The root wrapper uses
; the last propagation site when failure finally leaves callable main.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZAFAILOF:
            LD   HL,(S7CALOFF)
            CALL ZELDHL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%IF TargetStreamingOutput
            LD   DE,RTTRPOFF-RTSTATE
            CALL ZTSTADR
%ELSE
            LD   HL,RTTRPOFF
%ENDIF
            LD   A,$22                    ; LD (nn),HL
            JP   ZEOPWORD

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,HL
ZARARGCT:
            CALL ZENEXTB
            LD   (S7ARGCNT),A
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL,IX,IY
ZAPEXIT:
            LD   DE,(EMEXIT)
            JP   ZEPHERE

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ZACALL:
            LD   (S7CALLBL),A
            AND  C8SVCFLG
            JR   NZ,ZARSVC
            CALL ZARARGCT
            CALL ZENEXTB
            LD   (S7CALRES),A
            CALL ZENEXTB
            LD   (E8CALFLG),A
            JR   ZARCALL
ZARSVC:
            LD   A,(S7CALLBL)
            AND  V8RESU8
            RLCA
            RLCA
            RLCA
            LD   (S7CALRES),A
ZARCALL:
            CALL ZACALOFF
            LD   DE,E8CALMOD
            LD   B,3
ZARCLOOP:
            CALL ZENEXTB          ; mode, handler, retained carriers
            LD   (DE),A
            INC  DE
            DJNZ ZARCLOOP
            LD   A,(S7CALLBL)
            AND  C8SVCFLG
            JP   NZ,ZAINVSVC
%IF TargetStreamingOutput
            LD   DE,ROACLM
            CALL ZXFAILRT
%ELSE
            LD   HL,RTACLM
            CALL ZXFAILCL
%ENDIF
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   (EMEXIT),DE
            LD   HL,(S7CALOFF)
            LD   A,5
            CALL ZXTRBODY
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZAPEXIT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(S7CALLBL)
            AND  C8SRCMSK
            LD   C,A
%IF TargetStreamingOutput
            CALL ZASRCCL
%ELSE
            LD   A,$CD
            CALL ZCEMFIX
%ENDIF
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(E8CALFLG)
            AND  R7FAILS
            JR   NZ,ZASRCFAL
%IF TargetStreamingOutput
            LD   DE,ROAREL
            CALL ZTRTCALL
%ELSE
            LD   HL,RTAREL
            CALL EMITCALL
%ENDIF
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   ZACSUCC

%IF TargetStreamingOutput
; Emit an ordinary local CALL when the target routine shares the current bank.
; A cross-bank call supplies destination bank A and address HL to vector 9;
; the adapter switches, calls, restores the caller bank, and preserves the
; ordinary source-routine result/failure ABI.
; Contract: in C out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ZASRCCL:
            LD   A,(E8CALFLG)
            CALL FTUPKBK
            LD   D,A
            LD   A,(TGOUTBNK)
            CP   D
            JR   NZ,ZAFARCL
            LD   A,$CD
            JP   ZCEMFIX
ZAFARCL:
            PUSH BC
            PUSH DE
            LD   C,D
            LD   A,C                      ; destination bank
            CALL ZELDAI
            POP  DE
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,$21                    ; LD HL,target address
            CALL ZCFARFIX
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,9                      ; far-call vector ordinal
            JP   ZTVCCALL
%ENDIF
ZASRCFAL:
            CALL ZEBINCHK
            DB  $F5                    ; PUSH AF result discriminant/code
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%IF TargetStreamingOutput
            LD   DE,ROAREL
            CALL ZTRTCALL
%ELSE
            LD   HL,RTAREL
            CALL EMITCALL
%ENDIF
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEBINCHK
            DB  $F1                    ; POP AF
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
ZACFAIL:
            CALL ZEJRNC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   (EMEXIT),DE
            CALL ZAFAIL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
ZACFLRDY:
            CALL ZAPEXIT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
ZACSUCC:
            LD   A,(S7ARGCNT)
            LD   C,A
            CALL ZADISCAR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(S7CALRES)
            OR   A
            RET  Z
            LD   A,(S7CALLBL)
            AND  C8KEEP
            RET  Z
            LD   A,(S7CALLBL)
            AND  C8SVCFLG
            JR   NZ,ZASVCRSL
            CALL ZEBINL
            DB  $E5                      ; PUSH HL result carrier
ZASVCRSL:
            LD   HL,ZAERRCRB
            JP   EMITFOUR

; Contract: in C out A,C,carry,zero clobbers sign,parity,halfCarry,B,D,DE,HL
ZADISCAR:
            LD   A,C
            OR   A
            RET  Z
ZADISC:
            CALL ZEBINCHK
            DB  $D1                    ; POP DE carrier
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            DEC  C
            JR   ZADISCAR


; Failable completion uses carry plus A privately: carry clear denotes success;
; carry set carries one u8 error code in A. Source code cannot inspect this ABI.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ZAFAILRT:
            CALL ZACALOFF
            CALL ZAFAILOF
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEPINLIN
            DB  ZEPHLTOA
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   ZAFAILTL

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ZAFAILM:
            CALL ZACALOFF
            CALL ZEPINLIN
            DB  ZEPHLTOA
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,(S7CALOFF)
            CALL ZELDHL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEUNHPFX
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   ZXTREND

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ZARETOK:
            CALL ZXPOPHL           ; result carrier
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   ZASUCTL

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ZAENDFRT:
            OR   A
            RET  NZ
ZASUCTL:
            CALL ZEXRSTFR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,ZASRETB
            JP   EMITPAIR

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ZABEGHDL:
            LD   C,A
            CALL ZCDEFLBL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZENEXTB
            LD   (E8CALFLG),A
            LD   HL,ZAERRCRB
            CALL EMITFOUR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(E8CALFLG)
            AND  SCMSK
            CP   SCPROG
            JP   Z,ZXSTPR8
            JP   ZXSTLC8

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ZAENDHDL:
            LD   C,A
            JP   ZCDEFLBL

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ZAFAIL:
            LD   A,(E8CALMOD)
            OR   A
            JP   Z,ZXINTOP
            CP   M8HDL
            JR   Z,ZAFAILH
            CALL ZAFAILOF
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
ZAFAILTL:
            CALL ZEXRSTFR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,ZAFRETB
            JP   EMITPAIR
ZAFAILH:
            CALL ZEBINCHK
            DB  $4F                    ; LD C,A error code
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(S7ARGCNT)
            LD   HL,E8CARR
            ADD  A,(HL)
            LD   C,A
            CALL ZADISCAR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEBINCHK
            DB  $79                    ; LD A,C
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(E8HDLLBL)
            JP   ZCSKIPH

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ZAINVSVC:
            LD   A,(S7CALLBL)
            AND  V8ARGMSK
            JR   Z,ZASVCADR
            CP   V8ARGU16
            JR   Z,ZASVCARG
            CALL ZEPINLIN
            DB  ZEPHLTOA
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   ZASVCADR
ZASVCARG:
            CALL ZXPOPHL           ; offset
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
ZASVCADR:
            LD   A,(S7CALLBL)
            AND  C8SVCMSK
%IF TargetStreamingOutput
            CALL ZTVCCALL
%ELSE
            ADD  A,A
            LD   E,A
            LD   D,0
            LD   HL,ZASVCTAB
            ADD  HL,DE
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            EX   DE,HL
            CALL EMITCALL
%ENDIF
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            XOR  A
ZANOARG:
            LD   (S7ARGCNT),A
            JP   ZACFAIL

%IF TargetStreamingOutput
%ELSE
ZASVCTAB:
            DW RTREADIN
            DW RTWRITE
            DW RTREADST
            DW RTREWIND
            DW RTWRSTOR
            DW RTSEEK
%ENDIF

; Startup is a terminal wrapper around main's ordinary callable body. The
; source body therefore has the same frame, return, recursion, and failure ABI
; as every other result-free routine; only this wrapper converts final failure
; into unhandled-error and final success into host completion.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ZAMAIN:
            LD   (E8CALFLG),A
%IF TargetStreamingOutput
            CALL ZENEXTB
            CALL ZTSELBK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%ENDIF
            CALL ZXPGFRAM
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   C,S7MAINLB
            LD   A,$CD
            CALL ZCEMFIX
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(E8CALFLG)
            AND  R7FAILS
            JR   Z,ZAMAINOK
            CALL ZEJRNC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   (EMEXIT),DE
%IF TargetStreamingOutput
            CALL ZEBINCHK
            DB  $F5                    ; PUSH AF
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   DE,RTTRPOFF-RTSTATE
            CALL ZTSTADR
            LD   A,$2A                    ; LD HL,(nn)
            CALL ZEOPWORD
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEBINCHK
            DB  $F1                    ; POP AF
%ELSE
            LD   HL,ZARFLOFB
            CALL EMITFIVE
%ENDIF
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEUNHPFX
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZXTREND
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZAPEXIT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
ZAMAINOK:
            CALL ZXRSTRT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZESUCRET
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   C,S7MAINLB
            JP   ZADEFRT

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ZAENDRT:
            OR   A
            RET  NZ
            CALL ZEXRSTFR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEBINL
            DB  $C9

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ZALDPRAL:
            CALL ZEXPGADR
            JR   ZALDALOK

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ZALDROAL:
            CALL ZEREADW
%IF TargetStreamingOutput
            LD   HL,(TGCRBAS)
            ADD  HL,DE
%ELSE
            LD   HL,(IMGLEN)
            ADD  HL,DE
            LD   DE,RORDATA
            ADD  HL,DE
%ENDIF
ZALDALOK:
            LD   A,$21                    ; LD HL,nn
            JP   ZXOPWPHL


; Contract: out A,DE,carry,zero clobbers sign,parity,halfCarry,HL
ZARPATH:
            CALL ZEREADW
            LD   (S7PATHOF),DE
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ZAFIELD:
            CALL ZARPATH
            CALL ZEPINLIN
            DB  ZEPHLLDD
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,(S7PATHOF)
            CALL EMITWORD
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,ZAADDEPS
            JP   EMITPAIR

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ZAINDEX:
            CALL ZARPATH      ; length
            CALL ZAREXTOF ; stride and source position
            CALL ZEPINLIN
            DB  ZEPOPDEH
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,(S7PATHOF)
            CALL ZELDBCI
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   ZAIDXBND

; Open arrays use the retained caller count for the bound, but retain the
; concrete element extent in the semantic stream for ordinary scaling.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ZAOAIDX:
            CALL ZARARGCT
            CALL ZAREXTOF
            CALL ZEPINLIN
            DB  ZEPOPDEH
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,ZALDIXC
            CALL ZAODCAP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,S7ARGCNT
            INC  (HL)
            LD   HL,ZALDIXB
            CALL ZAODCAP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ZAIDXBND:
%IF TargetStreamingOutput
            LD   DE,ROARRIX
            CALL ZTRTCALL
%ELSE
            LD   HL,RTARRIX
            CALL EMITCALL
%ENDIF
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZABOUNDS
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEBINCHK
            DB  $E5                    ; retain base
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,(S7PATHEX)
            CALL ZELDHL               ; LD HL,nn stride
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%IF TargetStreamingOutput
            LD   DE,ROMUL16
            CALL ZTRTCALL
%ELSE
            LD   HL,RTMUL16
            CALL EMITCALL
%ENDIF
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,ZAPDEADD
            JP   ZETHREE

; Concrete array length is static, but its base carrier has already been
; evaluated. Discard that carrier before producing the canonical u16 count.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ZAARRLEN:
            CALL ZEREADW
            LD   (S7PATHEX),DE
            CALL ZXPOPHL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,(S7PATHEX)
            LD   A,$21                    ; LD HL,nn
            JP   ZXOPWPHL

; Open array length is the retained u16 word in the parameter activation.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ZAOALEN:
            CALL ZXPOPHL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   ZXLDLC16

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ZALDIND8:
            LD   HL,ZALDI8B
            LD   B,6
            JP   ZEBYTES
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ZALDINDW:
            LD   HL,ZALDI16B
            JP   EMITFIVE
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ZASTIND8:
            LD   HL,ZASTI8B
            JP   ZETHREE
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ZASTINDW:
            LD   HL,ZASTI16B
            JP   EMITFIVE

; Both full-region calls complete before LDIR is emitted. A failed first or
; second check reaches bounds with the destination still untouched.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ZACOPY:
            CALL ZAREXTOF
            LD   HL,ZACPYPRE
            CALL   EMITFOUR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZAREGCHK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZASAVREG
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEPINLIN
            DB  ZEPHLDE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,(S7PATHEX)
            CALL ZELDBCI
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,ZELDIR
            JP   ZEPINDEX

; Contract: out A,DE,HL,carry,zero clobbers sign,parity,halfCarry
ZAREXTOF:
            CALL ZEREADW
            LD   (S7PATHEX),DE
            JP   ZACALOFF

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ZASAVREG:
            CALL ZXPOPHL           ; source
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEBINCHK
            DB  $E5                    ; retain source
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ZAREGCHK:
            CALL ZAREGPFX
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,(S7PATHEX)
            CALL ZELDBCI
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   ZAREGINV

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ZAREGPFX:
%IF TargetStreamingOutput
            LD   DE,(TGCRBAS)
            CALL ZCLDDEI
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,(TGCROCAP)
            PUSH HL
            CALL ZEBINCHK
            DB  $FD
            POP  HL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   ZELDHL
%ELSE
            LD   DE,MMREGEND
            CALL ZCLDDEI
            RET
%ENDIF

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ZAREGINV:
%IF TargetStreamingOutput
            LD   DE,ROREGCHK
            CALL ZTRTCALL
%ELSE
            LD   HL,RTREGCHK
            CALL EMITCALL
%ENDIF
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   ZABOUNDS

; Contract: out A,DE,carry,zero clobbers sign,parity,halfCarry,HL
ZARSTREX:
            CALL ZARARGCT
            LD   L,A
            LD   H,0
            INC  HL
            INC  HL
            LD   (S7PATHEX),HL
            JP   ZACALOFF

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ZASTRLEN:
            CALL ZARSTREX
            CALL ZASAVREG
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZXPOPHL           ; carrier
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%IF TargetStreamingOutput
            LD   DE,ROSTRLEN
%ELSE
            LD   HL,RTSTRLEN
%ENDIF
            JP   ZASTRCHK

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ZASTRIDX:
            CALL ZARSTREX
            CALL ZASTRIPF
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZAREGCHK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEPINLIN
            DB  ZEPHLDE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%IF TargetStreamingOutput
            LD   DE,ROSTRIDX
%ELSE
            LD   HL,RTSTRIDX
%ENDIF
            JP   ZASTRCHK

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ZASTRIPF:
            CALL ZEPINLIN
            DB  ZEPOPDEH
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,ZAPSHDEH
            JP   EMITPAIR

; Open string operations read the caller-supplied concrete capacity from the
; hidden activation byte. The ordinary source value remains one address path.
; Contract: out A,DE,carry,zero clobbers sign,parity,halfCarry,HL
ZAROSOFF:
            CALL ZARARGCT
            JP   ZACALOFF

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ZAOSLEN:
            CALL ZAROSOFF
            CALL ZXPOPHL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEBINCHK
            DB  $E5                    ; retain carrier
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZAORCHK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZXPOPHL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%IF TargetStreamingOutput
            LD   DE,ROSTRLEN
%ELSE
            LD   HL,RTSTRLEN
%ENDIF
            JR   ZAOSCHK

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ZAOSIDX:
            CALL ZAROSOFF
            CALL ZASTRIPF
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZAORCHK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEPINLIN
            DB  ZEPHLDE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%IF TargetStreamingOutput
            LD   DE,ROSTRIDX
%ELSE
            LD   HL,RTSTRIDX
%ENDIF

%IF TargetStreamingOutput
; Contract: in DE out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
%ELSE
; Contract: in HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
%ENDIF
ZAOSCHK:
%IF TargetStreamingOutput
            PUSH DE
%ELSE
            PUSH HL
%ENDIF
            CALL ZAOCAPC
%IF TargetStreamingOutput
            POP  DE
%ELSE
            POP  HL
%ENDIF

%IF TargetStreamingOutput
; Contract: in DE out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
%ELSE
; Contract: in HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
%ENDIF
ZASTRCFN:
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%IF TargetStreamingOutput
            CALL ZTRTCALL
%ELSE
            CALL EMITCALL
%ENDIF
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZABOUNDS
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEBINL
            DB  $E5                      ; push length or addressed byte

; Emit BC = hidden concrete capacity + two representation bytes, then perform
; the ordinary complete-region guard before a generic string may be touched.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ZAORCHK:
            CALL ZAREGPFX
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZAOCAPC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,ZAOEXTB
            CALL EMITFOUR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   ZAREGINV

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ZAOCAPC:
            LD   HL,ZALDIXC

; Contract: in HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ZAODCAP:
            CALL EMITPAIR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(S7ARGCNT)
            CPL
            JP   EMITBYTE

; Convert a just-evaluated address carrier into the internal open-argument
; pair. Modes zero/one carry or forward a string capacity byte. Modes two/three
; carry or forward a complete array count word.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ZAOARG:
            LD   (S7ARGIDX),A
            CP   2
            JR   NC,ZAROARG
            CALL ZARARGCT
            JR   ZAOARGOK
ZAROARG:
            CALL ZARPATH
ZAOARGOK:
            CALL ZEBINCHK
            DB  $D1                    ; POP DE address carrier
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(S7ARGIDX)
            CP   2
            JR   NC,ZAOAARG
            OR   A
            JR   NZ,ZAFWDARG
            LD   A,(S7ARGCNT)
            LD   L,A
            LD   H,0
            CALL ZELDHL
            JR   ZAOARGPS
ZAFWDARG:
            LD   HL,ZALDIXL
            CALL ZAODCAP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEPINLIN
            DB  ZEZEROH
ZAOARGPS:
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,ZAPSHHLD
            JP   EMITPAIR

ZAOAARG:
            AND  1
            JR   NZ,ZAFWDARR
            LD   HL,(S7PATHOF)
            CALL ZELDHL
            JR   ZAOARGPS
ZAFWDARR:
            LD   A,(S7PATHOF)
            LD   (S7ARGCNT),A
            LD   HL,ZALDIXL
            CALL ZAODCAP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,S7ARGCNT
            INC  (HL)
            LD   HL,ZALDIXH
            CALL ZAODCAP
            JR   ZAOARGPS

%IF TargetStreamingOutput
; Contract: in DE out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
%ELSE
; Contract: in HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
%ENDIF
ZASTRCHK:
%IF TargetStreamingOutput
            PUSH DE
%ELSE
            PUSH HL
%ENDIF
            LD   A,(S7ARGCNT)
            LD   C,A
            LD   A,$0E                    ; LD C,n capacity
            CALL ZEOPBYTE
%IF TargetStreamingOutput
            POP  DE
%ELSE
            POP  HL
%ENDIF
            JP   ZASTRCFN

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ZASTRCAP:
            CALL ZARARGCT
            CALL ZXPOPHL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZAORCHK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZAOCAPC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,ZACAPCAR
            JP   EMITFOUR

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ZASTRSIZ:
            CALL ZARARGCT
            CALL ZACALOFF
            CALL ZEPINLIN
            DB  ZEPOPDEH           ; new length, carrier
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,ZAPSHDEH         ; preserve both across region check
            CALL EMITPAIR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZAORCHK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEPINLIN
            DB  ZEPHLDE           ; carrier, new length
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZAOCAPC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%IF TargetStreamingOutput
            LD   DE,RORESIZE
            CALL ZTRTCALL
%ELSE
            LD   HL,RTRESIZE
            CALL EMITCALL
%ENDIF
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   ZABOUNDS

ZALDBI:     DB $06
ZAOFFSET:      DB $5F,$16,$00,$19,$E5
ZALDI16B:DB $E1,$5E,$23,$56,$D5
ZASTI16B:DB $D1,$E1,$73,$23,$72
ZAPDEADD:       DB $D1,$19,$E5
ZAPSHDEH:           DB $D5,$E5
ZALDIXC:            DB $DD,$4E
; This target template is written as a normal Z80 instruction. The compiler
; copies its two-byte opcode prefix and emits the retained-count displacement.
ZALDIXB:
            LD   B,(IX+0)
ZAOEXTB:    DB $06,$00,$03,$03
; Target template assembled from ordinary Z80 mnemonics: capacity C becomes
; the canonical word carrier pushed on the generated evaluation stack.
ZACAPCAR:
            LD   L,C
            LD   H,0
            PUSH HL

ZAFRETB: DB $37,$C9      ; SCF / RET
ZASRETB: DB $B7,$C9      ; OR A / RET
%IF TargetStreamingOutput
%ELSE
ZARFLOFB:
            DB $F5,$2A                   ; PUSH AF / LD HL,(nn)
            DW RTTRPOFF
            DB $F1                       ; POP AF
%ENDIF
