; Correctness-first direct-Z80 backend for the complete scalar-expression
; increment. All evaluation values use canonical 16-bit carriers on the Z80
; stack. Declared u8/boolean objects still occupy one byte; u16 occupies two.

; Typed dispatch and loop dispatch are currently mutually exclusive. These
; aliases make the temporary reuse visible; merging the dispatchers requires
; dedicated storage or a new liveness proof.
ZXTRPPOS   EQU EMLOOP
ZXWIDTH    EQU EMCODST
ZXDEST     EQU EMCODST+1

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL,IX,IY
ZXDISP:
            LD   HL,SMPAYBAS
            LD   (SMRDCUR),HL
            XOR  A
            LD   (EBFDEP),A
            LD   (ECFCNT),A
            LD   HL,ECLVBAS
%IF TargetStreamingOutput
            LD   B,ECLCAP*ECLSZ
%ELSE
            LD   B,ECLCAP
%ENDIF
ZXRSTLBL:
            LD   (HL),A
            INC  HL
            DJNZ ZXRSTLBL
            LD   A,(SMBUFBAS)
            OR   A
%IF TargetStreamingOutput
%IF DebugHooks
            JR   Z,ZXDONE
%ELSE
            RET  Z
%ENDIF
%ELSE
            RET  Z
%ENDIF
            LD   B,A
ZXNEXT:
            PUSH BC
%IF TargetStreamingOutput
%IF DebugHooks
            OUT  (DTSEMST),A
%ENDIF
%ENDIF
            CALL ZENEXTB
            SUB  SMDEFPU8
            CP   ZXOPCNT
            JR   NC,ZXINVPOP
            CALL ZXPREF
            LD   L,C
            LD   H,D
            ADD  HL,HL
            LD   DE,ZXOPTAB
            ADD  HL,DE
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            EX   DE,HL
            LD   DE,ZXRET
            PUSH DE
            JP   (HL)
ZXRET:
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            DJNZ ZXNEXT
%IF TargetStreamingOutput
%IF DebugHooks
            CALL ZCRESFIX
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
ZXDONE:
            OUT  (DTSEMEND),A
            RET
%ELSE
            JP   ZCRESFIX
%ENDIF
%ELSE
            JP   ZCRESFIX
%ENDIF
ZXINVPOP:
            POP  BC
ZXINTOP:
            JP   TYEXSTUN

ZXPFBITS:
            DB $05,$70,$00,$00,$C0,$81,$5F,$C2,$05,$00,$7C,$04,$C7

ZXOPTAB:
            DW ZXDEF8          ; 20
            DW ZXMAIN        ; 21
            DW ZXDECL8         ; 22
            DW ZXINTOP ; 23 retired literal8
            DW ZXLDPR8     ; 24
            DW ZXLDLC8       ; 25
            DW ZXINTOP ; 26 retired multiply8
            DW ZXINTOP ; 27 retired add8
            DW ZXSTPR8    ; 28
            DW ZXSTLC8      ; 29
            DW ZXWRITE8           ; 30
            DW ZXENDM          ; 31
            DW ZXDEF16         ; 32
            DW ZXDECL16        ; 33
            DW ZXLIT16        ; 34
            DW ZXLDPR16    ; 35
            DW ZXLDLC16      ; 36
            DW ZXADD8             ; 37
            DW ZXADD16            ; 38
            DW ZXSUB8        ; 39
            DW ZXSUB16       ; 40
            DW ZXMUL8        ; 41
            DW ZXMUL16       ; 42
            DW ZXDIV8          ; 43
            DW ZXDIV16         ; 44
            DW ZXNEG8          ; 45
            DW ZXNEG16         ; 46
            DW ZXNOT8             ; 47
            DW ZXNOT16            ; 48
            DW ZXNOTBL       ; 49
            DW ZXAND8             ; 50
            DW ZXAND16            ; 51
            DW TYPEDOR8              ; 52
            DW ZXOR16             ; 53
            DW ZXXOR8             ; 54
            DW ZXXOR16            ; 55
            DW ZXMOD8          ; 56
            DW ZXMOD16         ; 57
            DW ZXCMP          ; 58
            DW ZXCMP          ; 59
            DW ZXCMP          ; 60
            DW ZXNAR8          ; 61
            DW ZXSTPR16   ; 62
            DW ZXSTLC16     ; 63
            DW ZXBEGAND         ; 64
            DW ZXBEGOR          ; 65
            DW ZXENDBL       ; 66
            DW ZCLABEL       ; 67
            DW ZCBFALSE ; 68
            DW ZCJUMP        ; 69
            DW ZCFORSET    ; 70
            DW ZCFORTST     ; 71
            DW ZCFORNXT     ; 72
            DW ZCFORCLR  ; 73
            DW ZXBEGRT     ; 74
            DW ZXLDLC8       ; 75 parameter u8
            DW ZXLDLC16      ; 76 parameter u16
            DW ZXCALL       ; 77
            DW ZXRETURN     ; 78
            DW ZXSTLC8      ; 79 parameter u8
            DW ZXSTLC16     ; 80 parameter u16
            DW ZCENDRT       ; 81
%IF AggregateCallSlices
            DW ZABEGRT    ; 82
            DW ZABINDP   ; 83
            DW ZACALL            ; 84
            DW ZARETAG ; 85
            DW ZAENDRT      ; 86
            DW ZALDPRAL ; 87
            DW ZALDPAL ; 88
            DW ZAFIELD     ; 89
            DW ZAINDEX     ; 90
            DW ZALDIND8   ; 91
            DW ZALDINDW  ; 92
            DW ZASTIND8  ; 93
            DW ZASTINDW ; 94
            DW ZACOPY   ; 95
            DW ZASTRLEN    ; 96
            DW ZASTRIDX     ; 97
            DW ZAFAILRT     ; 98
            DW ZAFAILM        ; 99
            DW ZARETOK   ; 100
            DW ZARETOK   ; 101
            DW ZAENDFRT ; 102
            DW ZCSKIPH     ; 103
            DW ZABEGHDL    ; 104
            DW ZAENDHDL      ; 105
            DW ZAMAIN ; 106
            DW ZALDROAL ; 107
            DW ZAOSLEN ; 108
            DW ZAOSIDX  ; 109
            DW ZAOARG ; 110
            DW ZASTRCAP ; 111
            DW ZASTRSIZ   ; 112
            DW ZAARRLEN    ; 113
            DW ZAOALEN ; 114
            DW ZAOAIDX ; 115
            DW ZXCONV  ; 116
            DW ZXDIVSGN    ; 117
            DW ZXPRMI8   ; 118
            DW ZXRPDISC ; 119
            DW ZXRPORT        ; 120
            DW ZXWPORT       ; 121
            DW ZXPACKET ; 122
            DW ZCCASE ; 123
ZXOPCNT    EQU 104
%ELSE
ZXOPCNT    EQU 62
%ENDIF

; Direct typed port access uses the complete u16 address in BC. A result-bearing
; read pushes a canonical u8 carrier; a discarded read leaves no carrier.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL,IX,IY
ZXRPORT:
            LD   B,7
            JR   ZXERPORT
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL,IX,IY
ZXRPDISC:
            LD   B,3
ZXERPORT:
            LD   HL,ZXRPBYT
            JP   ZEBYTES
ZXRPBYT:
            DB  $C1,$ED,$78             ; POP BC / IN A,(C)
            DB  $6F,$26,$00,$E5         ; LD L,A / LD H,0 / PUSH HL

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL,IX,IY
ZXWPORT:
            LD   HL,ZXWPBYT
            JP   EMITFOUR
ZXWPBYT:
            DB  $D1,$C1,$ED,$59         ; POP DE / POP BC / OUT (C),E

; Invoke the target-defined packet gateway with A=slot, HL=packet address and
; BC=packet extent. DE privately carries the statement offset to the shared
; runtime wrapper, which turns provider validation failure into a trap.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ZXPACKET:
%IF TargetStreamingOutput
            CALL ZELDAI
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEPINLIN
            DB  ZEPHLBC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   DE,(TGTERM)
            CALL ZCLDDEI
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEBINCHK
            DB  $D5                    ; PUSH DE, terminal dispatcher
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEREADW
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZCLDDEI
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,11                     ; packet-service vector ordinal
            JP   ZTVCCALL
%ELSE
            JP   ZXINTOP
%ENDIF

; Operand-prefetch metadata is deliberately separate from the full-width
; handler addresses. C returns the zero-based operation index. For marked
; operations A returns the first operand; otherwise A is scratch.
; Contract: in A out A,C,D,carry,zero clobbers sign,parity,halfCarry,B,E,HL
ZXPREF:
            LD   C,A
            AND  7
            LD   B,A
            INC  B
            LD   A,C
            RRCA
            RRCA
            RRCA
            AND  $1F
            LD   E,A
            LD   D,0
            LD   HL,ZXPFBITS
            ADD  HL,DE
            LD   A,(HL)
ZXPFBIT:
            RRCA
            DJNZ ZXPFBIT
            RET  NC
            JP   ZENEXTB

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
ZXDEF8:
            CALL ZENEXTB     ; value
            JP   EMITBYTE

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
ZXDEF16:
            CALL ZXDEF8
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   ZXDEF8

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZXMAIN:
            CALL ZXPGFRAM
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,ZEXFRBYT
            JP   ZEEIGHT

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZXPGFRAM:
            LD   DE,(EMDATFIX)
            LD   HL,(EMCUR)
            CALL ZEPWORD
            JP   ZXSAVRT

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
ZXDECL8:
            CALL ZEBINL
            DB  $3B                      ; DEC SP

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
ZXDECL16:
            XOR  A                       ; EmitPairDecSp2
            JP   ZEPINDEX

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZXLIT16:
            LD   C,A
            CALL ZENEXTB
            LD   H,A
            LD   L,C
            LD   A,$21                    ; LD HL,nn
; Contract: in A,HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZXOPWPHL:
            CALL ZEOPWORD
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEBINL
            DB  $E5                      ; PUSH HL

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ZXLDPR8:
            CALL ZEXPGADR
            LD   A,$3A                    ; LD A,(nn)
            CALL ZEOPWORD
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,ZXATOHL
            JP   EMITFOUR

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ZXLDPR16:
            CALL ZEXPGADR
            LD   A,$2A                    ; LD HL,(nn)
            JR   ZXOPWPHL

; C receives -(byte offset + 1), the displacement of the low byte from IX.
; Contract: out A,C,carry,zero clobbers sign,parity,halfCarry,B,D,DE,HL
ZXLOCDSP:
            CALL ZENEXTB
            CPL
            LD   C,A
            OR   A
            RET

; Contract: in C,HL out A,C,carry,zero clobbers sign,parity,halfCarry,B,D,DE,HL
ZXINDEX:
            LD   B,2
            CALL ZEBYTES
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,C
            JP   EMITBYTE

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
ZXPOPHL:
            CALL ZEBINL
            DB  $E1                      ; POP HL

; Contract: out A,C,carry,zero clobbers sign,parity,halfCarry,B,D,DE,HL
ZXLDLOIX:
            CALL ZXLOCDSP
            LD   HL,ZXLDLO
            JR   ZXINDEX

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ZXLDLC8:
            CALL ZXLDLOIX
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,ZXZEROHP
            JP   ZETHREE

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ZXLDLC16:
            CALL ZXLDLOIX
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            DEC  C
            LD   HL,ZXLDHI
            CALL ZXINDEX
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEBINL
            DB  $E5

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
ZXPOPOPS:
            LD   HL,ZXPOPOB
            JP   EMITPAIR

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
ZXPUSHHL:
            CALL ZEBINL
            DB  $E5

; Contract: in C,HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZXSEQ:
            PUSH HL
            CALL ZXPOPOPS
            POP  HL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   B,C
            CALL ZEBYTES
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   ZXPUSHHL

; C is the zero-based semantic-operation index retained by the dispatcher.
; The two step-two ordinal runs scale directly onto the adjacent emit-pair
; rows after their symbolic group bias is applied.
; Contract: in C out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL,IX,IY
ZXBINSEL:
ZXADD8     EQU ZXBINSEL
ZXSUB8     EQU ZXBINSEL
ZXAND8     EQU ZXBINSEL
TYPEDOR8   EQU ZXBINSEL
ZXXOR8     EQU ZXBINSEL
            LD   A,C
            CP   SMAND8-SMDEFPU8
            JR   NC,ZXBINBIT
            ADD  A,ZEADD8*2-(SMADD8-SMDEFPU8)
            JR   ZXBINSCL
ZXBINBIT:
            ADD  A,ZEAND8*2-(SMAND8-SMDEFPU8)
ZXBINSCL:
            RRCA                         ; all adjusted selectors are even
            LD   C,A
; Contract: in C out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZXBIN8:
            CALL ZXPOPOPS
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,C
            CALL ZEPINDEX
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,ZXATOHL
            JP   EMITFOUR

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZXXOR16:
            LD   HL,ZXXOR16B
            JR   ZXBIN6
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZXAND16:
            LD   HL,ZXAND16B
            JR   ZXBIN6
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZXOR16:
            LD   HL,ZXOR16B
; Contract: in HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZXBIN6:
            LD   C,6
            JR   ZXSEQ

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZXADD16:
            LD   HL,ZXADD16B
            LD   C,1
            JR   ZXSEQ
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZXSUB16:
            LD   HL,ZXSUB16B
            LD   C,3
            JR   ZXSEQ

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZXMUL8:
            CALL ZXMUL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEPINLIN
            DB  ZEZEROH
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   ZXPUSHHL
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZXMUL16:
            CALL ZXMUL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   ZXPUSHHL
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZXMUL:
            CALL ZXPOPOPS
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%IF TargetStreamingOutput
            LD   DE,ROMUL16
            JP   ZTRTCALL
%ELSE
            LD   HL,RTMUL16
            JP   EMITCALL
%ENDIF

; Emit a call whose carry-clear success path must skip a generated failure
; outcome. DE returns the branch operand for the caller to patch.
%IF TargetStreamingOutput
%ELSE
; Contract: in HL out A,DE,carry,zero clobbers sign,parity,halfCarry,B,C,HL
ZXFAILCL:
            CALL EMITCALL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   ZEJRNC
%ENDIF

%IF TargetStreamingOutput
; Contract: in DE out A,DE,carry,zero clobbers sign,parity,halfCarry,B,C,HL
ZXFAILRT:
            CALL ZTRTCALL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   ZEJRNC
%ENDIF

; Contract: out A,DE,HL,carry,zero clobbers sign,parity,halfCarry
ZXRTRPOS:
            CALL ZEREADW
            LD   (ZXTRPPOS),DE
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
ZXRTRPOP:
            CALL ZXRTRPOS
            JP   ZXPOPHL

; Contract: in DE out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZXTRHEAD:
            LD   (EMEXIT),DE
            LD   HL,(ZXTRPPOS)
            JP   ZELDHL

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL,IX,IY
ZXDIV8:
            LD   C,$80
            JR   ZXDIV
; Contract: in B out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL,IX,IY
ZXDIV16:
            LD   C,B                     ; operand-prefetch loop leaves B=0
            JR   ZXDIV
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL,IX,IY
ZXMOD8:
            LD   C,$81
            JR   ZXDIV
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL,IX,IY
ZXMOD16:
            LD   C,1
            JR   ZXDIV
; Contract: in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL,IX,IY
ZXDIVSGN:
            LD   C,A
ZXDIV:
            CALL ZXRTRPOS
            LD   A,C
            LD   (ZXWIDTH),A
            CALL ZXPOPOPS
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%IF TargetStreamingOutput
            LD   DE,RODIV16
%ELSE
            LD   HL,RTDIV16
%ENDIF
            LD   A,(ZXWIDTH)
            BIT  6,A
            JR   NZ,ZXDIVSCL
            BIT  0,A
            JR   Z,ZXDIVCL
%IF TargetStreamingOutput
            LD   DE,ROMOD16
%ELSE
            LD   HL,RTMOD16
%ENDIF
ZXDIVCL:
%IF TargetStreamingOutput
            CALL ZXFAILRT
%ELSE
            CALL ZXFAILCL
%ENDIF
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,3
            CALL ZXTRCUR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(ZXWIDTH)
            BIT  7,A
            JR   Z,ZXDIVPSH
            CALL ZEPINLIN
            DB  ZEZEROH
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
ZXDIVPSH:
            JP   ZXPUSHHL

ZXDIVSCL:
            LD   A,(ZXWIDTH)
            CALL ZELDAI
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%IF TargetStreamingOutput
            LD   DE,ROSDIV
%ELSE
            LD   HL,RTSDIV
%ENDIF
            JR   ZXDIVCL

%IF AggregateCallSlices
; Promote the selected i8 operand in an i16 common expression. The production
; parser emits mode 0 for the right carrier and mode 1 for the left carrier.
; Contract: in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL,IX,IY
ZXPRMI8:
            LD   (ZXWIDTH),A
            CALL ZXPOPOPS
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(ZXWIDTH)
            CALL ZELDAI
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%IF TargetStreamingOutput
            LD   DE,ROI8PAIR
            CALL ZTRTCALL
%ELSE
            LD   HL,RTI8PAIR
            CALL EMITCALL
%ENDIF
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,ZXPSHOB
            JP   EMITPAIR
%ENDIF

; Contract: noreturn
ZXUNARY:
            POP  HL
            LD   B,(HL)
            INC  HL
            CALL ZEBYTES
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   ZXPUSHHL

; The length byte is compiler metadata.  The following ordinary Z80
; instructions are the target template copied by TypedUnaryInline; the
; noreturn call keeps the compiler from ever executing through the data.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL,IX,IY
ZXNEG8:
            CALL ZXUNARY
            DB  6
ZXNEG8B:
            POP  HL
            XOR  A
            SUB  L
            LD   L,A
            LD   H,0
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL,IX,IY
ZXNEG16:
            CALL ZXUNARY
            DB  8
ZXNEG16B:
            POP  HL
            XOR  A
            SUB  L
            LD   L,A
            LD   A,0
            SBC  A,H
            LD   H,A
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL,IX,IY
ZXNOT8:
            CALL ZXUNARY
            DB  6
ZXNOT8B:
ZXPHLTOA   EQU ZXNOT8B
            POP  HL
            LD   A,L
            CPL
            LD   L,A
            LD   H,0
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL,IX,IY
ZXNOT16:
            CALL ZXUNARY
            DB  7
ZXNOT16B:
            POP  HL
            LD   A,L
            CPL
            LD   L,A
            LD   A,H
            CPL
            LD   H,A
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZXNOTBL:
            CALL ZXUNARY
            DB  7
ZXNOTBLB:
            POP  HL
            LD   A,L
            XOR  1
            LD   L,A
            LD   H,0

; Contract: in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZXEMCMP:
            CALL ZELDAI
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%IF TargetStreamingOutput
            LD   DE,ROCMP16
            JP   ZTRTCALL
%ELSE
            LD   HL,RTCMP16
            JP   EMITCALL
%ENDIF

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZXCMP:
            LD   C,A
            CALL ZXPOPOPS
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,C
            CALL ZXEMCMP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   ZXPUSHHL

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZXNAR8:
            CALL ZXRTRPOP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEPINLIN
            DB  ZETESTH
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,$28                    ; JR Z,success
            CALL ZEREL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,2
ZXTRPUSH:
            CALL ZXTRCUR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   ZXPUSHHL

; Convert one canonical integer carrier. The semantic operands are source
; type, destination type, and the conversion's trap position.
; Contract: in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ZXCONV:
            LD   (ZXWIDTH),A
            CALL ZENEXTB
            LD   (ZXDEST),A
            CALL ZXRTRPOP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(ZXWIDTH)
            CALL ZELDAI
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            ; Deliberate partial target instruction: the compiler emits the
            ; LD C,n opcode now and the dynamic destination-type byte below.
            ; AZM cannot spell an instruction whose immediate is supplied at
            ; compiler runtime; this byte is target data, not compiler code.
            CALL ZEBINCHK
            DB  $0E                      ; LD C,n
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(ZXDEST)
            CALL EMITBYTE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%IF TargetStreamingOutput
            LD   DE,ROCONV
            CALL ZXFAILRT
%ELSE
            LD   HL,RTCONV
            CALL ZXFAILCL
%ENDIF
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(ZXDEST)
            RLCA
            LD   A,2
            JR   NC,ZXCNVTRP
            DEC  A                        ; signed index conversion uses bounds
ZXCNVTRP:
            JR   ZXTRPUSH

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ZXSTPR8:
            CALL ZEXPGADR
            PUSH HL
            CALL ZEPINLIN
            DB  ZEPHLTOA
            POP  HL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,$32
            JP   ZEOPWORD
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ZXSTPR16:
            CALL ZEXPGADR
            PUSH HL
            CALL ZXPOPHL
            POP  HL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,$22
            JP   ZEOPWORD

; Contract: out A,C,carry,zero clobbers sign,parity,halfCarry,B,D,DE,HL
ZXSTLC8:
            CALL ZXLOCDSP
            CALL ZXPOPHL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,ZXSTLO
            JP   ZXINDEX
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ZXSTLC16:
            CALL ZXSTLC8
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            DEC  C
            LD   HL,ZXSTHI
            JP   ZXINDEX

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZXWRITE8:
            CALL ZXRTRPOS
            CALL ZEPINLIN
            DB  ZEPHLTOA
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%IF TargetStreamingOutput
            LD   A,1
            CALL ZTVCCALL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEJRNC
%ELSE
            LD   HL,RTWRITE
            CALL ZXFAILCL
%ENDIF
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZXTRHEAD
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEUNHPFX
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   ZXTRTAIL

; Every terminal typed-expression trap must dismantle the routine frame before
; emitting the common trap record and RET. Without this epilogue the generated
; return consumes local bytes or the saved IX value as its return address.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZXTREND:
            CALL ZXRSTRT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEBINCHK
            DB  $F5                    ; PUSH AF, preserve trap reason
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEBINCHK
            DB  $AF                    ; XOR A
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%IF TargetStreamingOutput
            LD   DE,RTDEPTH-RTSTATE
            CALL ZESTSTA
%ELSE
            LD   HL,RTDEPTH
            CALL ZESTA
%ENDIF
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEBINCHK
            DB  $F1                    ; POP AF
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   ZETRPEND

; Emit the common terminal trap body for source position HL and trap code A.
; The caller owns and patches the conditional branch around this terminal path.
; Contract: in A,HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZXTRBODY:
            PUSH AF
            CALL ZELDHL
%IF CompilerDiagnosticBranches
            JR   C,ZXTRFAIL
%ENDIF
            POP  AF
            CALL ZELDAI
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   ZXTREND
%IF CompilerDiagnosticBranches
ZXTRFAIL:
            LD   L,A
            POP  BC
            LD   A,L
            SCF
            RET
%ENDIF

; Emit and patch a terminal trap using the retained typed-expression source
; position. A is the trap code and DE the success-branch operand.
; Contract: in A,DE out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZXTRCUR:
            PUSH AF
            CALL ZXTRHEAD
%IF CompilerDiagnosticBranches
            JR   C,ZXTRFAIL
%ENDIF
            POP  AF
            CALL ZELDAI
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZXTRTAIL:
            CALL ZXTREND
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   DE,(EMEXIT)
ZXPHERE:
            JP   ZEPHERE

; Contract: in B out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL,IX,IY
ZXENDBL:
            CALL ZXBLPOP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   ZXPHERE

; Save the outer machine frame before main allocates locals, and restore that
; exact frame on every terminal trap, including a trap inside recursive calls.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZXSAVRT:
            LD   HL,ZXSTSPPF
            JR   ZXROOTOK

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZXRSTRT:
            LD   HL,ZXLDSPPF
; Contract: in HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZXROOTOK:
            PUSH HL
            CALL   EMITPAIR
            POP  HL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            PUSH HL
%IF TargetStreamingOutput
            LD   DE,ROOTSP-RTSTATE
            CALL ZTSTADR
%ELSE
            LD   HL,ROOTSP
%ENDIF
            CALL EMITWORD
            POP  HL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            INC  HL
            INC  HL
            CALL   EMITPAIR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%IF TargetStreamingOutput
            LD   DE,ROOTIX-RTSTATE
            CALL ZTSTADR
%ELSE
            LD   HL,ROOTIX
%ENDIF
            JP   EMITWORD

; Begin the single retained value routine. Operand bytes are routine ordinal
; and parameter type. HL carries the copied argument into this entry.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ZXBEGRT:
            CALL ZENEXTB
            LD   (ZXWIDTH),A
            LD   C,CRLBL
            CALL ZCDEFLBL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,ZEXFRBYT
            CALL   ZEEIGHT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(ZXWIDTH)
            BIT  1,A
            LD   HL,ZXPAR8B
            LD   B,4
            JR   Z,ZXRTARG
            LD   HL,ZXPAR16B
            LD   B,8
ZXRTARG:
            JP   ZEBYTES

; Evaluate has already left the copied argument as one canonical carrier.
; Claim activation capacity before the callee begins, then call the fixed
; forward label. The result returns in HL and becomes the enclosing carrier.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ZXCALL:
            CALL ZENEXTB     ; result type
            LD   (ZXWIDTH),A
            CALL ZXRTRPOP      ; trap position, argument
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
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
            LD   A,5
            CALL ZXTRCUR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   C,CRLBL
            LD   A,$CD                    ; CALL nn
            CALL ZCEMFIX
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
            CALL ZEBINL
            DB  $E5                      ; PUSH HL result carrier

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
ZXRETURN:
            CALL ZXPOPHL           ; result
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEXRSTFR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEBINL
            DB  $C9

; Contract: in DE out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZXBLPUSH:
            LD   HL,EBFDEP
            LD   A,(HL)
            CP   EBFCAP
            JR   NC,ZXBLCAP
            INC  (HL)
            INC  HL
            LD   C,A
            LD   B,0
            ADD  HL,BC
            ADD  HL,BC
            LD   (HL),E
            INC  HL
            LD   (HL),D
            INC  A
            OR   A
            RET
ZXBLCAP:
            CALL DGINLINE
            DB  DGBFXCAP

; Contract: in B out A,carry,zero,DE clobbers sign,parity,halfCarry,B,C,HL
ZXBLPOP:
            LD   HL,EBFDEP
            LD   A,(HL)
            DEC  A
            JP   M,ZXINTOP
            LD   (HL),A
            INC  HL
            LD   C,A
            ADD  HL,BC
            ADD  HL,BC
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            OR   A
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL,IX,IY
ZXBEGAND:
            LD   HL,ZXBEGADB
            JR   ZXBEGBL
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZXBEGOR:
            LD   HL,ZXBEGORB
ZXBEGBL:
            LD   B,6
            CALL ZEBYTES
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEJR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   ZXBLPUSH

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL,IX,IY
ZXENDM:
            LD   A,(EBFDEP)
            OR   A
            JP   NZ,ZXINTOP
            CALL ZEXRSTFR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   ZESUCRET

; Entry point used by the typed-expression proof.
ZXBEGIN:
%IF TargetStreamingOutput
%ELSE
; Contract: in HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ZXPGHEAD:
            CALL ZEBEGIN
%IF AggregateCallSlices
            JR   ZXPGENT

; Emit startup into the code segment. Prepared bytes are copied from rodata
; into initialized RAM, then the complete BSS allocation is cleared before the
; existing entry jump transfers to main.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
ZXSGHEAD:
            LD   HL,(IMGLEN)
            LD   A,H
            OR   L
            JR   Z,ZXSEGBSS
            LD   HL,RORDATA
            CALL ZELDHL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   DE,MMDATA
            CALL ZCLDDEI
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,(IMGLEN)
            CALL ZELDBCI
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEPINLIN
            DB  ZELDIR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
ZXSEGBSS:
            LD   HL,(PGBSSLEN)
            LD   A,H
            OR   L
            JR   Z,ZXSEGENT
            LD   HL,MMBSS
            CALL ZELDHL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,(PGBSSLEN)
            CALL ZELDBCI
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%IF TargetStreamingOutput
            LD   DE,ROBSS
            CALL ZTRTCALL
%ELSE
            LD   HL,RTBSS
            CALL EMITCALL
%ENDIF
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
ZXSEGENT:
%ENDIF
ZXPGENT:
            CALL ZEBINCHK
            DB  $C3
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,(EMCUR)
            LD   (EMDATFIX),HL
            LD   HL,0
            JP   EMITWORD

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
ZXPROG:
            LD   HL,MMGENLIM
            CALL ZXPGHEAD
            JP   C,ZEABORT
%IF AggregateCallSlices
            JP   ZGDISP
%ELSE
            CALL ZXDISP
            JP   C,ZEABORT
            JP   ZEFINISH
%ENDIF
ZXEND:
%ENDIF

%IF AggregateCallSlices
ZXSEGCOP: DB $ED,$B0           ; LDIR
%ENDIF
