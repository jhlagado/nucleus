; Correctness-first typed scalar declarations and expressions.
;
; Expression results return metadata in A and, when constant, a value in HL.
; The low two metadata bits are ScalarType*, and ScalarMetaConstant marks an
; exact compile-time value. Runtime expressions are emitted as a checked
; postfix stream of 16-bit carriers; u8 and boolean carriers have a zero high
; byte. The declared type, not the carrier, controls width and compatibility.

; Contract: out A,B,HL,carry,zero clobbers sign,parity,halfCarry,C,DE
TYMTFWNM:
            LD   A,(FWORD)
            OR   A
            RET  Z
            LD   HL,FWNAMPTR
            JP   TKRECEQ

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
TYNMEQMA:
            LD   HL,NAMEMAIN
            LD   B,4
            JP   TKNAMEEQ

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TYRTDCNM:
            CALL TYNMEQMA
            JR   C,TYDUNMER
            CALL TYMTFWNM
            JR   C,TYDUNMER
TYRDNMRD:
            LD   HL,DCNAMPTR
            CALL TKRETAIN
            LD   DE,DCNAMPOS
            CALL DGCOPYTK
            OR   A
            RET

TYDUNMER:
            CALL DGINLINE
            DB  DGDUPNAM

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
TYRCORNM:
            CALL SBFIND
            JR   C,TYDUNMER
            CALL TYNMEQMA
            JR   C,TYDUNMER
            OR   A
            RET

%IF AggregateCallSlices
; Carry identifies a source routine or predefined binding with the current
; spelling. Routine-scope declarations may shadow program symbols, but these
; callable and system names stay protected.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
S7CNIROP:
            CALL S7FIRTCU
            SCF
            RET  Z
            CALL TYNMEQMA
            RET  C
            JP   S8MTPRCU
%ENDIF

; Restore the retained declaration spelling as the current name token.
; Contract: out A,HL clobbers carry,zero,sign,parity,halfCarry
TYRSDCTK:
            LD   HL,(DCNAMPTR)
%IF NativeStreamingSource
            JP   SARESTOK
%ELSE
            LD   (TNLEXPTR),HL
            LD   A,(DCNAMLEN)
            LD   (TNLEN),A
            RET
%ENDIF

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TYPRCUWD:
            CALL TYRSDCTK
            PUSH BC
            PUSH DE
            LD   HL,DCNAMPOS
            CALL DGRESTTK
%IF AggregateCallSlices
%IF TargetStreamingOutput
%IF DebugHooks
            OUT  (DTDECL),A
%ENDIF
%ENDIF
%ENDIF
%IF AggregateCallSlices
            CALL S7RCDCNM
            JR   NC,TYPCRTCL
            POP  DE
            POP  BC
            RET
TYPCRTCL:
%ENDIF
            POP  DE
            POP  BC
            JP   SBPREPW
%IF AggregateCallSlices
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
TYPRRTWD:
            CALL TYRSDCTK
            LD   HL,DCNAMPOS
            CALL DGRESTTK
%IF TargetStreamingOutput
%IF DebugHooks
            OUT  (DTDECL),A
%ENDIF
%ENDIF
            CALL S7CNIROP
            JP   C,TYDUNMER
            JP   SBPREPRW
%ENDIF

; Emit one expression operation followed by a complete program address.
%IF AggregateCallSlices
; Contract: in A,BC out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
TYEOPBC:
            PUSH BC
            CALL TMEOPER
            POP  HL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   TMEWORD
%ENDIF

; Retain an operator that ParserPeek has already returned, then consume that
; cached token without asking ParserTake to peek a second time. Store the zero
; empty-lookahead marker before DEC restores the same $FF, carry-clear,
; zero-clear result that this helper has always returned.
; Contract: in A out A,carry,zero clobbers sign,parity,halfCarry
TYTKOP:
            LD   (EXOP),A
            XOR  A
            LD   (PSLOOK),A
            DEC  A
            RET
; Push one pending binary-expression context into the bounded compiler stack.
; Retaining the operator source offset is necessary because a nested operation
; may replace the global offset before the outer operation is reduced.
; Contract: in A out A,HL,carry,zero clobbers sign,parity,halfCarry,B,C,DE,IX,IY
TYEXADR:
            LD   E,A
            ADD  A,A
            ADD  A,E
            ADD  A,A
            ADD  A,A
            ADD  A,E
            LD   E,A
            LD   D,0
            LD   HL,EXSTKBAS
            ADD  HL,DE
            RET

TYEXPSH:
            LD   A,(EXSTKDEP)
            CP   EXSTKCAP
            JR   NC,TYEXSTFU
            CALL TYEXADR
            EX   DE,HL
            LD   HL,EXSAVE
            LD   BC,EXSTKESZ
            LDIR
            LD   HL,EXSTKDEP
            INC  (HL)
            LD   A,(HL)
            OR   A
            RET

TYEXSTFU:
            CALL DGINLINE
            DB  DGEXPCAP

; Store A/HL as the pending left result before pushing it.
%IF TargetStreamingOutput
; The three production left-associative loops have one saved AF above their
; caller. Retain this helper's continuation in DE while consuming that AF,
; then restore the continuation before falling through to TypedSaveLeft.
; Contract: noreturn
TYTOPSVL:
            POP  DE
            CALL TYTKOP
            POP  AF
            PUSH DE
%ENDIF
; Contract: in A,HL out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TYSVL:
%IF AggregateCallSlices
            CALL TYREQCMP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%ENDIF
            LD   (EXLMETA),A
            LD   (EXLVAL),HL
            JR   TYEXPSH

; Save the right result, then restore the most recent left result.
; Contract: in A,HL out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TYRSTOPS:
%IF AggregateCallSlices
            CALL TYREQCMP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%ENDIF
            LD   (EXRMETA),A
            LD   (EXRVAL),HL
            ; Every reduction follows TypedSaveLeft. Keep the defensive test so
            ; a future parser change cannot turn a broken invariant into a
            ; wrapped address beyond CompilerWorkspaceEnd.
            LD   HL,EXSTKDEP
            LD   A,(HL)
            OR   A
            JR   Z,TYEXSTUN
            DEC  A
            LD   (HL),A
            CALL TYEXADR
            LD   DE,EXSAVE
            LD   BC,EXSAVESZ
            LDIR
            LD   (EXLPOSPT),HL
            OR   A
            RET
TYEXSTUN:
            CALL DGINLINE
            DB  DGINTOP

TYVRNGER:
            LD   HL,EXVALPOS
            JR   TYREATPO
TYLRNGER:
            LD   HL,(EXLPOSPT)
TYREATPO:
            CALL DGRESTTK
TYRNGER:
            CALL DGINLINE
            DB  DGINTRNG
TYTYER:
            CALL DGINLINE
            DB  DGTYPMIS
TYDVER:
            LD   B,C                     ; statically selected divide width
            LD   C,DGDIVZER
            JR   TYCKFLT
TYNARER:
            LD   B,TYU8           ; u8(...) always has u8 result type
            LD   C,DGNAR
TYCKFLT:
            LD   A,(EXSUPFLT)
            OR   A
            JR   NZ,TYSUPFLT
            LD   A,C
            JP   DGSET
TYSUPFLT:
            LD   A,B
            LD   HL,0
            OR   MTCONST
            RET

; Resolve two integer operands. The four source metadata/value cells are live.
; C returns u8 or u16. Exact constants adopt the typed peer or expected type.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry
TYLTISBL:
            LD   A,(EXLMETA)
            AND  MTTYPMSK
            CP   TYBOOL
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry
TYDCSCTY:
            LD   A,(DCINFO)
            AND  MTTYPMSK
            RET

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TYRSINPR:
            CALL TYLTISBL
            JR   Z,TYTYER
            LD   D,A
            LD   A,(EXRMETA)
            AND  MTTYPMSK
            CP   TYBOOL
            JR   Z,TYTYER
            LD   E,A
            LD   A,D
            OR   A
            JR   NZ,TYRSLTY
            LD   A,E
            OR   A
            JR   NZ,TYRSEXL
            LD   A,(EXEXPTYP)
            AND  MTTYPMSK
            CP   TYBOOL
            JR   Z,TYRBEXDF
            OR   A
            JR   NZ,TYRBEXSE
TYRBEXDF:
            LD   A,(EXLMETA)
            LD   HL,EXRMETA
            OR   (HL)
            AND  MTNEG
            RRCA
            OR   TYU16
            LD   C,A
            JR   TYRVABEX
TYRBEXSE:
            LD   C,A
TYRVABEX:
            LD   HL,(EXLVAL)
            LD   A,(EXLMETA)
            CALL TYCVK
            JR   C,TYLRNGER
TYRSCVR:
            LD   HL,(EXRVAL)
            LD   A,(EXRMETA)
            CALL TYCVK
            JP   C,TYVRNGER
            RET
TYRSEXL:
            LD   C,E
            LD   HL,(EXLVAL)
            LD   A,(EXLMETA)
            CALL TYCVK
            JP   C,TYLRNGER
TYRSDN:
            RET
TYRSLTY:
            LD   A,E
            OR   A
            JR   NZ,TYRSBTY
            LD   C,D
            JR   TYRSCVR
TYRSBTY:
            LD   A,D
            CP   E
            JR   Z,TYRUSLTY
            CP   TYU16
            JR   Z,TYU16CR
            LD   A,E
            CP   TYU16
            JR   NZ,TYRSI16
            LD   A,D
            JR   TYU16CK
TYRSI16:
            LD   A,D
            CP   TYI8
            JR   Z,TYI16PL
            LD   A,E
            CP   TYI8
            JR   NZ,TYI16RD ; u8 with i16 needs no carrier change
            LD   C,0                     ; promote the right carrier
            JR   TYI16PRO
TYI16PL:
            LD   C,1                     ; promote the left carrier
TYI16PRO:
            LD   A,SMPRI8
            CALL PSEOPC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,C
            OR   A
            LD   HL,EXRVAL
            JR   Z,TYI16PK
            LD   HL,EXLVAL
TYI16PK:
            LD   A,(HL)
            RLCA
            SBC  A,A
            INC  HL
            LD   (HL),A
TYI16RD:
            LD   C,TYI16
            OR   A
            RET
TYRUSLTY:
            LD   C,D
            OR   A
            RET
TYU16CR:
            LD   A,E
TYU16CK:
            CP   TYU8
            JP   NZ,TYTYER
TYRSU16:
            LD   C,TYU16
            OR   A
            RET

; Contract: in A,D out A,D,carry,zero clobbers sign,parity,halfCarry
TYRSSYCL:
            AND  SYRECTYP+SYAGGFLG
            JP   NZ,TYTYER
            LD   A,D
            AND  SCMSK
            RET

; Return constant in A when both operands are constant.
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TYBK:
            LD   A,(EXLMETA)
            LD   HL,EXRMETA
            AND  (HL)
            AND  MTCONST
            RET

; Emit a width-selected binary operation. D=u8 ordinal; the u16 ordinal is next.
; Contract: in C,D out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TYEWOP:
            LD   A,C
            AND  2
            RRCA
            ADD  A,D
            JP   TMEOPER

; Emit the selected operation, then retain both values only when the pair is
; compile-time constant. Carry reports emission failure; zero reports dynamic.
; Contract: in C,D out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TYPRKBN:
            CALL TYEWOP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL TYBK
            RET  Z
            LD   HL,(EXLVAL)
            LD   DE,(EXRVAL)
            RET

; Reduce +, -, *, /, integer and, or, xor. ExpressionOperator holds the token.
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TYRINTBN:
            CALL TYRSINPR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(EXOP)
            SUB  TNMIN
            JR   Z,TYRSUB
            DEC  A
            JR   Z,TYRADD
            DEC  A
            JR   Z,TYRMUL
            CP   TNSLASH-TNSTAR
            JR   Z,TYRDIV
            CP   TOKENAND-TNSTAR
            JR   Z,TYRAND
            SUB  TOKENXOR-TNSTAR
            JR   Z,TYRXOR
            DEC  A
            JR   Z,TYRMOD
TYROR:
            LD   D,SMOR8
            CALL TYPRKBN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,C
            RET  Z
            LD   A,L
            OR   E
            LD   L,A
            LD   A,H
            OR   D
            JR   TYRBIKDN
TYRXOR:
            LD   D,SMXOR8
            CALL TYPRKBN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,C
            RET  Z
            LD   A,L
            XOR  E
            LD   L,A
            LD   A,H
            XOR  D
            JR   TYRBIKDN
TYRAND:
            LD   D,SMAND8
            CALL TYPRKBN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,C
            RET  Z
            LD   A,L
            AND  E
            LD   L,A
            LD   A,H
            AND  D
TYRBIKDN:
            LD   H,A
            JR   TYRINKDN
TYRADD:
            LD   D,SMADD8
            CALL TYPRKBN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   Z,TYRINTMT
            ADD  HL,DE
            JR   TYRASUDN
TYRSUB:
            LD   D,SMSUB8
            CALL TYPRKBN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   Z,TYRINTMT
            OR   A
            SBC  HL,DE
TYRASUDN:
            JR   TYRINKDN
TYRMUL:
            LD   D,SMMUL8
            CALL TYPRKBN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   Z,TYRINTMT
            ; Constant multiplication modulo 65536, using sixteen shift/add
            ; steps.
            PUSH BC
            LD   BC,0
            LD   A,16
TYRMULLP:
            SRL  D
            RR   E
            JR   NC,TYRMULSK
            PUSH HL
            ADD  HL,BC
            LD   B,H
            LD   C,L
            POP  HL
TYRMULSK:
            ADD  HL,HL
            DEC  A
            JR   NZ,TYRMULLP
            LD   H,B
            LD   L,C
            POP  BC
; Contract: in C,HL out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TYRINKDN:
TYMSRESW:
            BIT  1,C
            JR   NZ,TYRINKMT
            LD   H,0
TYRINKMT:
            LD   A,C
            OR   MTCONST
            RET
TYRINTMT:
            LD   A,C
            OR   A
            RET
TYRDIV:
            LD   D,SMDIV8
            JR   TYRDVSEL
TYRMOD:
            LD   D,SMMOD8
TYRDVSEL:
            LD   A,C
            AND  TYSGNFLG
            JR   Z,TYDIVIDE
            LD   A,SMDIVSGN
            CALL TMEOPER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            BIT  1,C
            LD   A,$40
            JR   NZ,TYRDSGMD
            LD   A,$C0
TYRDSGMD:
            LD   D,A
            LD   A,(EXOP)
            CP   TOKENMOD
            LD   A,D
            JR   NZ,TYRDSMRD
            OR   1
TYRDSMRD:
            CALL TMEBYTE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   TYRDVPOS
TYDIVIDE:
            CALL TYEWOP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
TYRDVPOS:
            LD   HL,(EXOPOFF)
            CALL TMEWORD
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            ; A divisor known to be zero is invalid even when the dividend is
            ; dynamic. The fault helper also implements constant short-circuit
            ; suppression, so the unevaluated Boolean arm remains admissible.
            LD   A,(EXRMETA)
            RLCA
            JR   NC,TYRDVFLD
            LD   HL,(EXRVAL)
            LD   A,H
            OR   L
            JP   Z,TYDVER
TYRDVFLD:
            CALL TYBK
            JR   Z,TYRINTMT
            ; The earlier exact-divisor check proves DE is nonzero here.
            ; Constant unsigned division uses a bounded subtraction loop.
            LD   DE,(EXRVAL)
            LD   HL,(EXLVAL)
            PUSH BC
            LD   A,C
            AND  TYSGNFLG
            JR   Z,TYRDUSRD
            BIT  1,C
            JR   NZ,TYDIVSGR
            BIT  7,L
            JR   Z,TYRDSGR8
            LD   H,$FF
TYRDSGR8:
            BIT  7,E
            JR   Z,TYDIVSGR
            LD   D,$FF
TYDIVSGR:
            LD   B,0
            LD   C,B
            BIT  7,H
            JR   Z,TYRDDVRD
            SET  0,C
            CALL TYNEGKHL
TYRDDVRD:
            BIT  7,D
            JR   Z,TYSIGNS
            SET  1,C
            EX   DE,HL
            CALL TYNEGKHL
            EX   DE,HL
TYSIGNS:
            PUSH BC
            JR   TYRDCRRD
TYRDUSRD:
            LD   B,A                     ; unsigned-class test leaves A=0
            LD   C,A
            PUSH BC
TYRDCRRD:
            LD   C,B                     ; both selector paths establish B=0
TYRDVLP:
            OR   A
            SBC  HL,DE
            JR   C,TYRDVDN
            INC  BC
            JR   TYRDVLP
TYRDVDN:
            ADD  HL,DE
            POP  DE
            LD   A,(EXOP)
            CP   TOKENMOD
            JR   Z,TYRDMOSG
            LD   H,B
            LD   L,C
            LD   A,E
            RRCA
            XOR  E
            AND  1
            JR   TYRDAPSG
TYRDMOSG:
            LD   A,E
            AND  1
TYRDAPSG:
            JR   Z,TYRDRERD
            CALL TYNEGKHL
TYRDRERD:
            POP  BC
            OR   A
            JP   TYRINKDN

; Primary expressions.
TYPPRI:
            CALL PSTK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            PUSH AF
            PUSH BC
            LD   DE,EXVALPOS
            CALL DGCOPYTK
            POP  BC
            POP  AF
            CP   TNNUM
            JR   Z,TYPRINUM
            CP   TNCHAR
            JR   Z,TYPRICH
            CP   TNNAME
            JR   Z,TYPRINM
            CP   TNLPAR
            JP   Z,TYPRIPRN
            SUB  TNTRUE
            CP   2
            JR   C,TYPRBLTK
            INC  B                       ; successful keyword match leaves B=0
            CP   TOKENU8-TNTRUE+$100
            JR   Z,TYPRICVB
            INC  B
            CP   TOKENU16-TNTRUE+$100
            JR   NZ,TYPRSGCV
TYPRICVB:
            LD   A,B
            JP   TYPRCVIN
TYPRSGCV:
            SUB  TOKENI8-TNTRUE
            CP   2
            JP   NC,PSXSC
            ADD  A,TYI8
            JP   TYPRCVIN
TYPRINUM:
            LD   H,B
            LD   L,C
            LD   B,MTCONST+TYEXACT
            JR   TYPRETYK
TYPRICH:
            LD   H,B                     ; punctuation scan exhausts B
            LD   L,C
            JR   TYPRIU8K
TYPRBLTK:
            XOR  1
            LD   L,A
            LD   H,B                     ; successful keyword match leaves B=0
TYPRIBLK:
            LD   B,MTCONST+TYBOOL
            JR   TYPRETYK
TYPRIU8K:
            LD   B,MTCONST+TYU8
TYPRETYK:
            PUSH BC
            PUSH HL
            LD   A,SMLIT16
            CALL TMEOPER
            POP  HL
%IF CompilerDiagnosticBranches
            JR   C,TYPETKER
%ENDIF
            PUSH HL
            LD   A,(EXEXPTYP)
            CP   TYI8
            JR   NZ,TYPRKCAN
            LD   H,0
TYPRKCAN:
            CALL TMEWORD
            POP  HL
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,B
            OR   A
            RET
%IF CompilerDiagnosticBranches
TYPETKER:
            POP  BC
            RET
%ENDIF
TYPRINM:
%IF AggregateCallSlices
            CALL S8MTPRCU
            JR   NC,TYPRORNM
            CP   P8CONST
            JP   NC,S8TYPRIK
            CP   P8PORT
            JP   Z,S8TYPRSV
            LD   C,A
            AND  $FD                     ; readInput/readStorage map to zero
            JP   NZ,TYTYER
            LD   A,C
            JP   S8TYPRSV
TYPRORNM:
            CALL S7FIRTCU
            JP   Z,S7TYPRRT
            CALL SBLOOKUP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   D,A
            AND  SYAGGFLG
            JP   NZ,S7TPAGSY
            LD   A,D
            JR   TYPRNMRS
%ENDIF
%IF AggregateCallSlices
            ; The retained routine table handles scalar calls above.
%ELSE
            CALL TYMTFWNM
            JR   C,TYPRSCCL
%ENDIF
TYPRVANM:
            CALL SBLOOKUP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   D,A
TYPRNMRS:
            AND  MTTYPMSK
            LD   E,A
            LD   A,D
            CALL TYRSSYCL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   Z,TYPRIKNM
            RRCA
            RRCA
            CP   SCPAR/4
            JR   Z,TYPRPANM
            ADD  A,SMLDPU8-1
            BIT  1,E
            JR   Z,TYPRPGSE
            ADD  A,SMLDP16-SMLDPU8
TYPRPGSE:
            BIT  3,D
            JR   NZ,TYPRIELD
%IF AggregateCallSlices
            PUSH DE
            CALL TYEOPBC
            POP  DE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,E
            OR   A
            RET
%ELSE
            JR   TYPRIELD
%ENDIF
TYPRPANM:
            LD   A,SMLDPAR8
            BIT  1,E
            JR   Z,TYPRIELD
            INC  A
TYPRIELD:
            PUSH DE
            PUSH BC
            CALL TMEOPER
            POP  BC
            POP  DE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,C
            PUSH DE
            CALL TMEBYTE
            POP  DE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,E
            OR   A
            RET
TYPRIKNM:
            LD   H,B
            LD   L,C
            LD   B,D
            SET  7,B
%IF AggregateCallSlices
            JP   TYPRETYK
%ELSE
            JR   TYPRETYK
%ENDIF

; Parse one call to the retained scalar forward. The outer call position stays
; on the compiler stack while a nested argument call is parsed.
%IF AggregateCallSlices
            ; Kept only for the pre-aggregate expression proof layouts.
%ELSE
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TYPRSCCL:
            LD   HL,(TNSTOFF)
            PUSH HL
            CALL PSXL
%IF CompilerDiagnosticBranches
            JR   C,TYPRCLER
%ENDIF
            LD   A,(EXEXPTYP)
            LD   B,A
            LD   A,(FWPARTYP)
            LD   C,A
            PUSH BC
            LD   (EXEXPTYP),A
            CALL TYPOR
%IF CompilerDiagnosticBranches
            JR   C,TYCALLCX
%ENDIF
            LD   D,A
            PUSH DE
            PUSH HL
            CALL PSXR
%IF CompilerDiagnosticBranches
            JR   C,TYPCLRER
%ENDIF
            POP  HL
            POP  DE
            POP  BC
            LD   A,B
            LD   (EXEXPTYP),A
            LD   A,C
            LD   E,A
            LD   A,D
            CALL TYCKASG
%IF CompilerDiagnosticBranches
            JR   C,TYPRCLER
%ENDIF
            POP  HL
            PUSH HL
            LD   A,SMCALLSC
            CALL TMEOPER
%IF CompilerDiagnosticBranches
            JR   C,TYPCLEER
%ENDIF
            LD   A,(FWORD)
            CALL TMEBYTE
%IF CompilerDiagnosticBranches
            JR   C,TYPCLEER
%ENDIF
            LD   A,(FWRESTYP)
            CALL TMEBYTE
%IF CompilerDiagnosticBranches
            JR   C,TYPCLEER
%ENDIF
            POP  HL
            PUSH HL
            CALL TMEWORD
%IF CompilerDiagnosticBranches
            JR   C,TYPCLEER
%ENDIF
            POP  HL
            LD   A,(FWRESTYP)
            OR   A
            RET
TYPCLEER:
            POP  HL
            SCF
            RET
TYPCLRER:
            POP  HL
            POP  DE
TYCALLCX:
            POP  BC
            LD   A,B
            LD   (EXEXPTYP),A
TYPRCLER:
            POP  HL
            SCF
            RET
%ENDIF
%IF AggregateCallSlices
; A failable invocation remains consumable only while it is the complete,
; untouched expression. Preserve the expression result while checking that no
; pending direct failure is being enclosed by another expression form.
; Contract: in A,HL out A,HL,carry,zero clobbers sign,parity,halfCarry,BC,DE,IX,IY
TYREQCMP:
            LD   C,A
            LD   A,(S8DIRFBL)
            OR   A
            JP   NZ,LFERCX
            LD   A,C
            RET

%ENDIF
TYPRIPRN:
            CALL TYPOR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            PUSH AF
            PUSH HL
            CALL PSXR
%IF CompilerDiagnosticBranches
            JR   C,TYPRPRER
%ENDIF
            POP  HL
            POP  AF
%IF AggregateCallSlices
            JR   TYREQCMP
%ELSE
            RET
%ENDIF
%IF CompilerDiagnosticBranches
TYPRPRER:
            POP  HL
            POP  AF
            SCF
            RET
%ENDIF

TYPRCVIN:
            LD   C,A
            LD   HL,(TNSTOFF)
            LD   (EXOPOFF),HL
            PUSH AF                       ; destination type
            PUSH HL                       ; conversion trap position
            LD   A,C
            ; Parse the parenthesized operand under the conversion's expected
            ; type, then restore the enclosing expectation before continuing.
            LD   C,A
            LD   A,(EXEXPTYP)
            LD   B,A
            PUSH BC
            LD   A,C
            LD   (EXEXPTYP),A
            CALL PSXL
%IF CompilerDiagnosticBranches
            JR   C,TYPRCVER
%ENDIF
            CALL TYPOR
%IF CompilerDiagnosticBranches
            JR   C,TYPRCVER
%ENDIF
            LD   D,A
            PUSH DE
            PUSH HL
            CALL PSXR
%IF CompilerDiagnosticBranches
            JR   C,TYPCVRER
%ENDIF
            POP  HL
            POP  DE
            POP  BC
            LD   A,B
            LD   (EXEXPTYP),A
            LD   A,D
%IF AggregateCallSlices
            CALL TYREQCMP
%IF CompilerDiagnosticBranches
            JR   C,TYCONVCX
%ENDIF
%ENDIF
%IF CompilerDiagnosticBranches
            JR   TYPRCVRD
TYPCVRER:
            POP  HL
            POP  DE
TYPRCVER:
            POP  BC
            LD   A,B
            LD   (EXEXPTYP),A
            JR   TYCONVCX
TYPRCVRD:
%ENDIF
            LD   D,A
            LD   B,H
            LD   C,L
            POP  HL
            LD   (EXOPOFF),HL
            POP  AF
            PUSH AF                       ; destination type
            LD   H,B
            LD   L,C
            LD   A,D
            CALL TYREINMT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   D,A
            POP  AF
            LD   C,A
            LD   A,D
            AND  MTCONST
            JR   Z,TYPRDYCV
            LD   A,D
            CALL TYCVK
            JR   NC,TYPKCVRD
            LD   B,C
            JP   TYNARER
TYPKCVRD:
            JP   TYRINKMT
TYPRDYCV:
            LD   A,D
            AND  MTTYPMSK
            CP   C
            JR   Z,TYPDCVDN
            CP   TYU8
            JR   NZ,TYPDYCVE
            BIT  1,C
            JR   NZ,TYPDCVDN
TYPDYCVE:
%IF AggregateCallSlices
            LD   HL,(EXOPOFF)
            CALL TYEICVOP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%ELSE
            LD   A,SMNARU8
            CALL TMEOPER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,(EXOPOFF)
            CALL TMEWORD
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%ENDIF
TYPDCVDN:
            LD   A,C
            OR   A
            RET
%IF CompilerDiagnosticBranches
TYCONVCX:
            POP  HL
            POP  AF
            SCF
            RET
%ENDIF

; Publish a checked integer conversion from source metadata D to destination
; type C. HL is the source position used if the generated range check traps.
; Contract: in C,D,HL out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL,IX,IY
TYEICVOP:
            LD   (EXOPOFF),HL
            LD   A,SMCVTINT
            PUSH BC
            PUSH DE
            CALL TMEOPER
            POP  DE
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,D
            AND  MTTYPMSK
            CALL TMEBYTE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,C
            CALL TMEBYTE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,(EXOPOFF)
            JP   TMEWORD

; Check and fold one explicit constant integer conversion. A is source
; metadata, C is the destination type, and HL is the source payload.
; Contract: in A,C,HL out A,C,D,HL,carry,zero clobbers sign,parity,halfCarry,B,E,IX,IY
TYCVK:
            LD   D,A
            AND  MTTYPMSK
            BIT  4,A
            JR   Z,TYCSEOUS
            RRA
            JR   NC,TYCVI16
TYCVSRI8:
            BIT  7,L
            JR   Z,TYCSEOUS
            LD   H,$FF
            JR   TYCVNEG
TYCVI16:
            BIT  7,H
            JR   NZ,TYCVNEG
TYCSEOUS:
            LD   A,D
            AND  MTNEG
            JR   Z,TYCVPOS
TYCVNEG:
            BIT  4,C
            JR   Z,TYCVKER
            BIT  1,C
            JR   NZ,TYCVDN
            INC  H
            JR   NZ,TYCVKER
            BIT  7,L
            JR   Z,TYCVKER
            JR   TYCVDN
TYCVPOS:
            BIT  1,C
            JR   NZ,TYCVPOWD
            LD   A,H
            OR   A
            JR   NZ,TYCVKER
            BIT  4,C
            JR   Z,TYCVDN
            BIT  7,L
            JR   NZ,TYCVKER
            JR   TYCVDN
TYCVPOWD:
            BIT  4,C
            JR   Z,TYCVDN
            BIT  7,H
            JR   NZ,TYCVKER
TYCVDN:
            OR   A
            RET
TYCVKER:
            SCF
            RET

; Contract: in A out A,D,carry,zero clobbers sign,parity,halfCarry
TYREINMT:
            LD   D,A
            AND  MTTYPMSK
            CP   TYBOOL
            JP   Z,TYTYER
            AND  TYBASMSK
            CP   3
            JP   NC,TYTYER
            LD   A,D
            OR   A
            RET

; Unary +, -, and not bind above multiplicative operators.
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TYPUN:
            CALL PSPEEK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CP   TNPLUS
            JR   Z,TYUNADD
            CP   TNMIN
            JR   Z,TYUNNEG
            CP   TOKENNOT
            JP   Z,TYUNNOT
            JP   TYPPRI
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TYUNADD:
            CALL PSTK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL TYPUN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%IF AggregateCallSlices
            CALL TYREQCMP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%ENDIF
            JR   TYREINMT
TYUNNEG:
            CALL TYUNADD
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   D,A
            AND  MTTYPMSK
            JR   NZ,TYUNNETY
            LD   A,SMNEG16
            CALL TYEUNOP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,D
            AND  MTNEG
            JR   NZ,TYUNEWNE
            LD   A,H
            CP   $80
            JR   C,TYUNEXNE
            JP   NZ,TYVRNGER
            LD   A,L
            OR   A
            JP   NZ,TYVRNGER
TYUNEXNE:
            CALL TYNEGKHL
            LD   A,H
            OR   L
            LD   A,MTCONST+TYEXACT
            RET  Z
            OR   MTNEG
            RET
TYUNEWNE:
            CALL TYNEGKHL
            LD   A,MTCONST+TYEXACT
            OR   A
            RET
TYUNNETY:
            LD   A,D
            AND  MTTYPMSK
TYUNNERS:
            LD   C,A
            AND  2
            RRCA
            ADD  A,SMNEG8
TYUNNEGE:
            CALL TYEUNOP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,D
            AND  MTCONST
            LD   A,C
            RET  Z
            CALL TYNEGKHL
            JP   TYMSRESW

; Contract: in A,BC,DE,HL out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TYEUNOP:
            PUSH BC
            PUSH DE
            PUSH HL
            CALL TMEOPER
            POP  HL
            POP  DE
            POP  BC
            RET
; Contract: in HL out A,HL clobbers carry,zero,sign,parity,halfCarry
TYNEGKHL:
            XOR  A
            SUB  L
            LD   L,A
            SBC  A,A
            SUB  H
            LD   H,A
            RET
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TYPMUL:
            CALL TYPUN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
TYMULLP:
            PUSH AF
            PUSH HL
            CALL PSPEEK
%IF CompilerDiagnosticBranches
            JR   C,TYMUPKER
%ENDIF
            CP   TNSTAR
            JR   Z,TYMULOP
            CP   TNSLASH
            JR   Z,TYMULOP
            CP   TOKENMOD
            JR   NZ,TYMULDN
TYMULOP:
            CALL TYTKOP
%IF CompilerDiagnosticBranches
            JR   C,TYMUPKER
%ENDIF
            LD   HL,(TNSTOFF)
            LD   (EXOPOFF),HL
            POP  HL
            POP  AF
            CALL TYSVL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL TYPUN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL TYRSTOPS
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL TYRINTBN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   TYMULLP
TYMULDN:
            POP  HL
            POP  AF
            RET
%IF CompilerDiagnosticBranches
TYMUPKER:
            POP  HL
            POP  AF
            SCF
            RET
%ENDIF

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TYPADD:
            CALL TYPMUL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
TYADDLP:
            PUSH AF
            CALL PSPEEK
%IF CompilerDiagnosticBranches
            JR   C,TYADPKER
%ENDIF
            CP   TNPLUS
            JR   Z,TYADDOP
            CP   TNMIN
            JR   NZ,TYADDDN
TYADDOP:
%IF TargetStreamingOutput
            CALL TYTOPSVL
%ELSE
            CALL TYTKOP
%IF CompilerDiagnosticBranches
            JR   C,TYADPKER
%ENDIF
            POP  AF
            CALL TYSVL
%ENDIF
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL TYPMUL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL TYRSTOPS
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL TYRINTBN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   TYADDLP
TYADDDN:
            POP  AF
            RET
%IF CompilerDiagnosticBranches
TYADPKER:
            POP  AF
            SCF
            RET
%ENDIF

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TYCMPTK:
            LD   C,RCEQ
            CP   TNEQ
            SCF
            RET  Z
            SUB  TNLT
            CP   TNNOTEQ-TNLT+1
            RET  NC
            INC  A
            INC  A
            CP   RCGE+1
            JR   NZ,TYCMTKSE
            LD   A,RCNE
TYCMTKSE:
            LD   C,A
TYCMTKYE:
            SCF
            RET

TYPCMP:
            CALL TYPADD
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            PUSH AF
            PUSH HL
            CALL PSPEEK
%IF CompilerDiagnosticBranches
            JR   C,TYCMSTER
%ENDIF
            CALL TYCMPTK
            JR   NC,TYCMPNO
            LD   A,C
            CALL TYTKOP
%IF CompilerDiagnosticBranches
            JR   C,TYCMSTER
%ENDIF
            POP  HL
            POP  AF
            CALL TYSVL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL TYPADD
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL TYRSTOPS
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL TYRCMP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            PUSH AF
            PUSH HL
            CALL PSPEEK
%IF CompilerDiagnosticBranches
            JR   C,TYCMSTER
%ENDIF
            CALL TYCMPTK
            JR   C,TYCMPCH
TYCMPNO:
            POP  HL
            POP  AF
            RET
%IF CompilerDiagnosticBranches
TYCMSTER:
            POP  HL
            POP  AF
            SCF
            RET
%ENDIF
TYCMPCH:
            POP  HL
            POP  AF
            CALL DGINLINE
            DB  DGCMPCHN
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TYRCMP:
            LD   A,(EXRMETA)
            AND  MTTYPMSK
            LD   E,A
            LD   A,(EXLMETA)
            AND  MTTYPMSK
            CP   TYBOOL
            JR   NZ,TYCMPINT
            LD   A,E
            SUB  TYBOOL
            JP   NZ,TYTYER
            LD   A,(EXOP)
            CP   RCNE+1
            JP   NC,TYTYER
            LD   D,A                     ; successful Boolean test leaves A=0
            LD   A,SMCMPBL
            JR   TYCMPE
TYCMPINT:
            CALL TYRSINPR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,C
            LD   D,A
            AND  TYSGNFLG
            JR   NZ,TYCMPSG
            LD   D,A                     ; unsigned-class test leaves A=0
            LD   A,C
            AND  2
            RRCA
            ADD  A,SMCMP8
            JR   TYCMPE
TYCMPSG:
            BIT  1,D
            LD   D,$80                    ; signed word selector flag
            JR   NZ,TYCMSGRD
            LD   D,$C0                    ; signed byte selector flag
TYCMSGRD:
            LD   A,SMCMP16
TYCMPE:
            PUSH DE
            CALL TMEOPER
            POP  DE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(EXOP)
            OR   D
            CALL TMEBYTE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL TYBK
            LD   A,TYBOOL
            RET  Z
            LD   HL,(EXLVAL)
            LD   DE,(EXRVAL)
            LD   A,C
            AND  TYSGNFLG
            JR   Z,TYCMKSUB
            BIT  1,C
            JR   Z,TYCMKSG8
            LD   A,H
            XOR  $80
            LD   H,A
            LD   A,D
            XOR  $80
            LD   D,A
            JR   TYCMKSUB
TYCMKSG8:
            LD   A,L
            XOR  $80
            LD   L,A
            LD   A,E
            XOR  $80
            LD   E,A
TYCMKSUB:
            XOR  A
            SBC  HL,DE
            ; Classify the relation as equal/less/greater (0/1/2), then use
            ; the dense comparison ordinal to select one Boolean table cell.
            ; The table contains language truth values, never code addresses.
            LD   D,A                     ; XOR established A=0
            JR   Z,TYCMRERD
            INC  D
            JR   C,TYCMRERD
            INC  D
TYCMRERD:
            LD   A,(EXOP)
            LD   E,A
            ADD  A,A
            ADD  A,E
            ADD  A,D
            LD   E,A
            LD   D,0
            LD   HL,KWCMPRES
            ADD  HL,DE
            LD   L,(HL)
            LD   H,D
TYCMPKDN:
            LD   A,MTCONST+TYBOOL
            OR   A
            RET

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TYPCMENT:
            JP   TYPCMP

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TYUNNOT:
            CALL PSTK
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL TYPUN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%IF AggregateCallSlices
            CALL TYREQCMP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%ENDIF
            LD   D,A
            AND  MTTYPMSK
            LD   C,A
            CP   TYBOOL
            LD   A,SMNOTBL
            JR   Z,TYNOTE
            LD   A,C
            OR   A
            JR   NZ,TYNOTYIN
            LD   A,(EXEXPTYP)
            CP   TYU8
            JR   Z,TYNOEXU8
            LD   C,TYU16
            LD   A,SMNOT16
            JR   TYNOTE
TYNOEXU8:
            ; As with unary minus, validate the exact operand before applying
            ; the width-specific complement and masking the result.
            LD   A,D
            AND  MTCONST
            JR   Z,TYNEU8RD
            LD   A,H
            OR   A
            JP   NZ,TYVRNGER
TYNEU8RD:
            LD   C,TYU8
            LD   A,SMNOT8
            JR   TYNOTE
TYNOTYIN:
            CP   TYU8
            LD   A,SMNOT16
            JR   NZ,TYNOTE
            DEC  A
TYNOTE:
            CALL TYEUNOP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,D
            AND  MTCONST
            LD   A,C
            RET  Z
            CP   TYBOOL
            JR   NZ,TYNOINTK
            LD   A,L
            XOR  1
            LD   L,A
            JP   TYRINKMT
TYNOINTK:
            LD   A,L
            CPL
            LD   L,A
            LD   A,H
            CPL
            LD   H,A
            JP   TYMSRESW

; Boolean short circuit is represented by prefix/suffix operations so the
; Z80 backend can branch around the right operand. Integer and/or use the
; ordinary postfix reduction.
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TYPAND:
            CALL TYPCMENT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
TYANDLP:
            PUSH AF
            CALL PSPEEK
%IF CompilerDiagnosticBranches
            JP   C,TYBLPKER
%ENDIF
            CP   TOKENAND
%IF TargetStreamingOutput
            JR   NZ,TYBLDN
%ELSE
            JP   NZ,TYBLDN
%ENDIF
%IF TargetStreamingOutput
            CALL TYTOPSVL
%ELSE
            CALL TYTKOP
%IF CompilerDiagnosticBranches
            JP   C,TYBLPKER
%ENDIF
            POP  AF
            CALL TYSVL
%ENDIF
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL TYLTISBL
            JR   NZ,TYANDPR
            LD   C,0
            CALL TYBGBLSU
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
TYANDPR:
            CALL TYPCMENT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL TYRSTOPS
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL TYLTISBL
            JR   NZ,TYANDINT
            CALL TYRBL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   TYANDLP
TYANDINT:
            CALL TYRINTBN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   TYANDLP

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TYPOR:
            CALL TYPAND
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
TYORLP:
            PUSH AF
            CALL PSPEEK
%IF CompilerDiagnosticBranches
            JR   C,TYBLPKER
%ENDIF
            CP   TOKENXOR
            JR   Z,TYOROP
            CP   TOKENOR
            JR   NZ,TYBLDN
%IF AggregateCallSlices
            LD   A,(S8DIRFBL)
            OR   A
            JR   NZ,TYORERCX
            LD   A,TOKENOR
%ENDIF
TYOROP:
%IF TargetStreamingOutput
            CALL TYTOPSVL
%ELSE
            CALL TYTKOP
%IF CompilerDiagnosticBranches
            JR   C,TYBLPKER
%ENDIF
            POP  AF
            CALL TYSVL
%ENDIF
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(EXOP)
            CP   TOKENXOR
            JR   NZ,TYORBLL
            CALL TYLTISBL
            JP   Z,TYTYER
            JR   TYORPR
TYORBLL:
            CALL TYLTISBL
            JR   NZ,TYORPR
            LD   C,1
            CALL TYBGBLSU
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
TYORPR:
            CALL TYPAND
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL TYRSTOPS
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL TYLTISBL
            JR   NZ,TYORINT
            CALL TYRBL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   TYORLP
TYBLDN:
            POP  AF
            RET
%IF AggregateCallSlices
TYORERCX:
            CALL LFERCX
%ENDIF
%IF CompilerDiagnosticBranches
TYBLPKER:
            POP  AF
            SCF
            RET
%ENDIF
TYORINT:
            CALL TYRINTBN
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   TYORLP

; Contract: in C out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TYBGBLSU:
            LD   A,C
            ADD  A,SMBGAND
            CALL TMEOPER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
; Contract: in C out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TYBGSUP:
            LD   A,(EXLMETA)
            RLCA
            RET  NC
            LD   A,(EXLVAL)
            XOR  C
            RET  NZ
            LD   HL,EXSUPFLT
            INC  (HL)
            RET
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TYRBL:
            LD   A,(EXRMETA)
            AND  MTTYPMSK
            CP   TYBOOL
            JP   NZ,TYTYER
            LD   A,SMENDBL
            CALL TMEOPER
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL TYBK
            LD   A,TYBOOL
            RET  Z
            LD   HL,(EXRVAL)
            LD   A,(EXOP)
            CP   TOKENAND
            LD   A,(EXLVAL)
            JR   Z,TYBLKAND
            OR   L
            JR   TYBLKRD
TYBLKAND:
            AND  L
TYBLKRD:
            LD   L,A
TYBLK:
            JP   TYCMPKDN

; Assignment compatibility resolves exact constants and the value-preserving
; unsigned/signed widening family. A/HL is the expression; E is destination.
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TYCKASG:
            LD   D,A
            AND  MTTYPMSK
            JR   NZ,TYASGTY
            LD   A,E
            CP   TYBOOL
            JP   Z,TYTYER
            LD   C,E
            LD   A,D
            CALL TYCVK
            JP   C,TYVRNGER
            LD   A,D
            AND  MTCONST
            OR   C
            RET
TYASGTY:
            CP   E
            JR   Z,TYASGSAM
            CP   TYU8
            JR   Z,TYASFRU8
            CP   TYI8
            JP   NZ,TYTYER
            LD   A,E
            CP   TYI16
            JP   NZ,TYTYER
            LD   C,TYI16
            LD   HL,(EXVALPOS)
            PUSH DE
            CALL TYEICVOP
            POP  DE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,D
            AND  MTCONST
            JR   Z,TYASGSAM
            BIT  7,L
            JR   Z,TYASGSAM
            LD   H,$FF
            JR   TYASGSAM
TYASFRU8:
            LD   A,E
            CP   TYU16
            JR   Z,TYASGSAM
            CP   TYI16
            JP   NZ,TYTYER
TYASGSAM:
            LD   A,D
            AND  MTCONST
            OR   E
            RET
