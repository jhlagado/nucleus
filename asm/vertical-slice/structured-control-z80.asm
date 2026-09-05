; Post-parse absolute-label and structured-loop lowering. All generated branch
; operands are compiler-private absolute words and are resolved before the
; generated program is published.

ZCCOUNT    EQU EMCODST
ZCMODE     EQU EMCODST+1
ZCSTEP     EQU EMLOOP
ZCTRPOFF   EQU EMEXIT
ZCTSTLBL   EQU EMFAIL
ZCEXTLBL   EQU EMFAIL+1

; C is a label ordinal and DE is the address of a generated word operand.
%IF TargetStreamingOutput
; Bit 7 on input distinguishes a cross-bank address operand. The four-byte
; fixup stores the full six-bit label separately from flags and site bank.
%ENDIF
; Contract: in C,DE out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ZCRECFIX:
            LD   A,C
            AND  $7F
            CP   ECLCAP
            JP   NC,CFLABER
            LD   A,(ECFCNT)
            CP   ECFCAP
            JR   NC,ZCFIXERR
            PUSH BC
            LD   L,A
            LD   H,0
            ADD  HL,HL
            ADD  HL,HL
            LD   BC,ECFBAS
            ADD  HL,BC
            POP  BC
            LD   A,C
            AND  $7F
            LD   (HL),A
            INC  HL
%IF TargetStreamingOutput
            LD   A,(TGOUTBNK)
            BIT  7,C
            JR   Z,ZCRFLAGS
            SET  7,A
ZCRFLAGS:
%ELSE
            XOR  A
%ENDIF
            LD   (HL),A
            INC  HL
            LD   (HL),E
            INC  HL
            LD   (HL),D
            LD   HL,ECFCNT
            INC  (HL)
; Contract: out A,carry,zero clobbers sign,parity,halfCarry
ZCENDRT:
            XOR  A
            RET
ZCFIXERR:
            CALL DGINLINE
            DB  DGCFXCAP

; Emit opcode A with a zero word operand and retain that operand for label C.
%IF TargetStreamingOutput
; Contract: in A,C out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ZCFARFIX:
            SET  7,C
%ENDIF
; Contract: in A,C out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ZCEMFIX:
            PUSH BC
            CALL EMITBYTE
%IF CompilerDiagnosticReturns
            POP  BC
            RET  C
            PUSH BC
%ENDIF
            LD   DE,(EMCUR)
            PUSH DE
            LD   HL,0
            CALL EMITWORD
            POP  DE
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   ZCRECFIX

%IF TargetStreamingOutput
; Contract: in A,C out A,BC,HL,carry,zero clobbers sign,parity,halfCarry
ZCLBLENT:
            ADD  A,A
            ADD  A,C
            LD   L,A
            LD   H,0
            LD   BC,ECLBAS
            ADD  HL,BC
            LD   A,(HL)
            OR   A
            RET
%ENDIF
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ZCLABEL:
            LD   C,A
; Contract: in C out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ZCDEFLBL:
            LD   A,C
            CP   ECLCAP
            JP   NC,CFLABER
%IF TargetStreamingOutput
            CALL ZCLBLENT
%ELSE
            LD   B,0
            LD   HL,ECLVBAS
            ADD  HL,BC
            LD   A,(HL)
            OR   A
%ENDIF
            JP   NZ,ZXINTOP
%IF TargetStreamingOutput
            LD   A,(TGOUTBNK)
            INC  A
            LD   (HL),A
%ELSE
            LD   (HL),1
%ENDIF
%IF TargetStreamingOutput
            INC  HL
%ELSE
            LD   L,C
            LD   H,0
            ADD  HL,HL
            LD   BC,ECLABAS
            ADD  HL,BC
%ENDIF
            LD   DE,(EMCUR)
            LD   (HL),E
            INC  HL
            LD   (HL),D
            XOR  A
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ZCBFALSE:
            LD   C,A
            PUSH BC
            LD   HL,ZCBFALSB
            CALL   ZETHREE
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,$CA                    ; JP Z,nn
            JR   ZCEMFIX

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ZCSKIPH:
ZCJUMP:
            LD   C,A
            LD   A,$C3                    ; JP nn
            JR   ZCEMFIX

; Compare one retained selector with an exact case word without consuming the
; selector. The case body label follows the word in the semantic transcript.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ZCCASE:
            LD   C,A                      ; selector type
            CALL ZEREADW
            PUSH BC
            PUSH DE
            POP  HL
            CALL ZELDHL               ; LD HL,case-value
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEPINLIN
            DB  ZEPDEPSD       ; retained selector -> DE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            BIT  1,C
            LD   HL,ZCCASE8
            JR   Z,ZCCASEOK
            LD   HL,ZCSUBDE
ZCCASEOK:
            CALL ZETHREE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZENEXTB
            LD   C,A
            LD   A,$CA                    ; JP Z,body
            JR   ZCEMFIX
ZCCASE8:
            DB  $7B,$BD,$00              ; LD A,E / CP L / NOP

; Resolve every retained absolute operand after all label locations are known.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ZCRESFIX:
%IF TargetStreamingOutput
            CALL ZTSAVEBK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%ENDIF
            LD   A,(ECFCNT)
            OR   A
            RET  Z
            LD   B,A
            LD   IX,ECFBAS
ZCRESNXT:
            LD   C,(IX+0)
            LD   E,(IX+2)
            LD   D,(IX+3)
%IF TargetStreamingOutput
            PUSH BC
            PUSH DE
            LD   D,(IX+1)
            LD   A,D
            AND  $03
            LD   E,A
            LD   (TGOUTBNK),A
%ENDIF
            LD   A,C
%IF TargetStreamingOutput
%ELSE
            CP   ECLCAP
            JR   NC,ZCRESERR
            PUSH BC
            PUSH DE
%ENDIF
%IF TargetStreamingOutput
            CALL ZCLBLENT
%ELSE
            LD   B,0
            LD   HL,ECLVBAS
            ADD  HL,BC
            LD   A,(HL)
            OR   A
%ENDIF
            JR   Z,ZCRESUNW
%IF TargetStreamingOutput
            DEC  A
            BIT  7,D
            JR   NZ,ZCRESBNK
            CP   E
            JR   NZ,ZCRESUNW
ZCRESBNK:
%ENDIF
%IF TargetStreamingOutput
            INC  HL
%ELSE
            LD   H,0
            LD   L,C
            ADD  HL,HL
            LD   BC,ECLABAS
            ADD  HL,BC
%ENDIF
            LD   C,(HL)
            INC  HL
            LD   H,(HL)
            LD   L,C
            POP  DE
            CALL ZEPWORD
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            INC  IX
            INC  IX
            INC  IX
            INC  IX
            DJNZ ZCRESNXT
%IF TargetStreamingOutput
            LD   A,TGOUTCLS
            LD   (TGOUTBNK),A
%ENDIF
            XOR  A
            RET
ZCRESUNW:
            POP  DE
            POP  BC
ZCRESERR:
            JP   ZXINTOP

; Emit the selected low-byte IX operation and its displaced counter offset.
; E selects the ordinary pair-table entry.
; Contract: in A,C,E out A,C,carry,zero clobbers sign,parity,halfCarry,B,D,DE,HL
ZCCNTPFX:
            LD   A,C
            CPL
            LD   C,A
            LD   A,E
            CALL ZEPINDEX
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,C
            JP   EMITBYTE

; Emit a local load into HL without pushing a new expression carrier.
; C is the byte offset, A bit 2 selects u16.
; Contract: in A,C out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ZCLDCNT:
            LD   E,ZELDIXL
            PUSH AF
            CALL ZCCNTPFX
            POP  DE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            BIT  2,D
            JR   NZ,ZCLDCNTH
            LD   A,ZEZEROH
            JP   ZEPINDEX
ZCLDCNTH:
            DEC  C
            CALL ZEPINLIN
            DB  ZELDIXH
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,C
            JP   EMITBYTE

; Store HL to counter byte offset C; A bit 2 selects u16.
; Contract: in A,C out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ZCSTCNT:
            LD   E,ZESTIXL
            PUSH AF
            CALL ZCCNTPFX
            POP  DE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            BIT  2,D
            RET  Z
            DEC  C
            CALL ZEPINLIN
            DB  ZESTIXH
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,C
            JP   EMITBYTE

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ZCFORSET:
            LD   C,A
            CALL ZENEXTB
            LD   B,A
            PUSH BC
            CALL ZEPINLIN
            DB  ZEPOPDEH
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,B
            CALL ZCSTCNT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEBINL
            DB  $D5                      ; PUSH DE, retained bound

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ZCFORTST:
            LD   C,A                      ; counter
%IF TargetStreamingOutput
            CALL ZEREADW
            LD   B,E                      ; mode
            LD   A,D                      ; exit label
%ELSE
            CALL ZENEXTB
            LD   B,A                      ; mode
            CALL ZENEXTB
            LD   D,A                      ; exit label
%ENDIF
            LD   (ZCEXTLBL),A
            PUSH BC
            CALL ZEPINLIN
            DB  ZEPDEPSD
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            PUSH BC
            LD   A,B
            CALL ZCLDCNT
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,B
            AND  $03
            ADD  A,RCLT
ZCFORCMP:
            BIT  3,B
            JR   Z,ZCFORCOK
            OR   $80
            BIT  2,B
            JR   NZ,ZCFORCOK
            OR   $40
ZCFORCOK:
            CALL ZXEMCMP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(ZCEXTLBL)
            LD   C,A
            CALL ZEPINLIN
            DB  ZETESTL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,$CA
            JP   ZCEMFIX

; Contract: in DE out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ZCLDDEI:
            LD   A,$11                    ; LD DE,nn
            PUSH DE
            CALL EMITBYTE
            POP  DE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   H,D
            LD   L,E
            JP   EMITWORD

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ZCLDSTPM:
            LD   DE,(ZCSTEP)
            CALL ZCLDDEI
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(ZCMODE)
            RET

; Read and retain the fixed-width ForNext operands in emitter scratch.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ZCFORNXT:
            LD   (ZCTSTLBL),A
            CALL ZENEXTB
            LD   (ZCEXTLBL),A
%IF TargetStreamingOutput
            CALL ZEREADW
            LD   (ZCCOUNT),DE
%ELSE
            CALL ZENEXTB
            LD   (ZCCOUNT),A
            CALL ZENEXTB
            LD   (ZCMODE),A
%ENDIF
            CALL ZEREADW
            LD   (ZCSTEP),DE
            CALL ZEREADW
            LD   (ZCTRPOFF),DE
            XOR  A
            CALL ZEPINLIN
            DB  ZEPDEPSD
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(ZCCOUNT)
            LD   C,A
            LD   A,(ZCMODE)
            CALL ZCLDCNT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEBINCHK
            DB  $E5                    ; preserve current counter
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(ZCMODE)
            BIT  1,A
            JR   NZ,ZCNEGDST
            CALL ZEBINCHK
            DB  $EB                    ; EX DE,HL => bound-current
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
ZCNEGDST:
            LD   HL,ZCSUBDE
            CALL   ZETHREE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(ZCMODE)
            AND  $0C
            CP   $08                    ; signed byte distance wraps modulo 256
            JR   NZ,ZCDSTWID
            CALL ZEPINLIN
            DB  ZEZEROH
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
ZCDSTWID:
            CALL ZCLDSTPM
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            AND  1
            LD   A,RCLT
            JR   NZ,ZCDSTCMP
            ; until exits when distance <= step; to exits when distance < step.
            LD   A,RCLE
ZCDSTCMP:
            CALL ZXEMCMP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,ZCTSTPOP
            CALL   ZETHREE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(ZCEXTLBL)
            LD   C,A
            LD   A,$C2                    ; JP NZ,exit cleanup
            CALL ZCEMFIX
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
ZCFORLD:
            CALL ZCLDSTPM
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            BIT  3,A
            JR   NZ,ZCSGNSTP
            BIT  1,A
            JR   NZ,ZCSUBSTP
            CALL ZEBINCHK
            DB  $19                    ; ADD HL,DE
            JR   ZCFORFIT
ZCSUBSTP:
            LD   HL,ZCSUBDE
            CALL   ZETHREE
ZCFORFIT:
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(ZCMODE)
            BIT  2,A
            JR   NZ,ZCFORST
            BIT  1,A
            JR   NZ,ZCFORST
            CALL ZEPINLIN
            DB  ZETESTH
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEBINCHK
            DB  $CA                    ; JP Z,fit
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
ZCFORTRP:
            LD   HL,(EMCUR)
            LD   (EMUPEXIT),HL
            LD   HL,0
            CALL EMITWORD
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,(ZCTRPOFF)
            LD   A,4
            CALL ZXTRBODY
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   DE,(EMUPEXIT)
            LD   HL,(EMCUR)
            CALL ZEPWORD
            JR   ZCFORST
ZCSGNSTP:
            CALL ZELDAI
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%IF TargetStreamingOutput
            LD   DE,ROSSTEP
            CALL ZXFAILRT
%ELSE
            LD   HL,RTSSTEP
            CALL ZXFAILCL
%ENDIF
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,(ZCTRPOFF)
            LD   (ZXTRPPOS),HL
            LD   A,4
            CALL ZXTRCUR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
ZCFORST:
            LD   A,(ZCCOUNT)
            LD   C,A
            LD   A,(ZCMODE)
            CALL ZCSTCNT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(ZCTSTLBL)
            JP   ZCJUMP

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
ZCFORCLR:
            CALL ZEBINL
            DB  $D1                      ; POP DE, discard retained bound

ZCSUBDE:        DB $B7,$ED,$52
ZCTSTPOP: DB $7D,$B7,$E1
