; Flat append-only target output. The operating adapter owns NOBJ framing,
; service destinations, image fill, CRC, and the two sequential spools.

; Emit entry opcode A followed by one retained zero-word fixup operand.
; Contract: in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZTENTPH:
            CALL EMITBYTE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,(EMCUR)
            LD   (EMDATFIX),HL
            LD   HL,0
            JP   EMITWORD

; Emit one terminal-state byte comparison. DE selects the runtime-state byte
; and C supplies the expected value.
; Contract: in C,DE out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZTTERM:
            PUSH BC
            CALL ZTSTADR
            LD   A,$3A                    ; LD A,(nn)
            CALL ZEOPWORD
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,$FE                    ; CP n
            CALL ZEOPBYTE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,ZTSELBT
            JP   EMITPAIR

; IX points at the stable compact descriptor supplied by the adapter.
; Contract: in IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
ZTFLAT:
            LD   A,TGOUTCLS
            LD   (TGOUTBNK),A
            LD   L,(IX+TDRTID)
            LD   H,(IX+TDRTID+1)
            LD   DE,RIABI
            OR   A
            SBC  HL,DE
            JP   NZ,ZTCFGERR
            LD   A,(IX+TDFLGS)
            CP   TDSETSTK+1
            JP   NC,ZTCFGERR
            LD   (TGSTKMOD),A
            ; Retain both checked descriptor regions as complete full-width
            ; word pairs. Their final MAP positions are not adjacent.
            PUSH IX
            POP  HL
            LD   DE,TDIMGBAS
            ADD  HL,DE
            LD   DE,TGIMGBAS
            LD   BC,4
            LDIR
            LD   DE,TGWRBAS
            LD   BC,4
            LDIR
            LD   HL,(TGIMGBAS)
            LD   DE,(TGIMGCAP)
            CALL ZTVALREG
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,(TGWRBAS)
            LD   DE,(TGWRCAP)
            CALL ZTVALREG
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZTCLASS
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            ; Determine the exact startup extent and validate the optional
            ; established stack before the adapter opens a generation.
            LD   HL,26                   ; JP/CALL main plus terminal dispatch
            CALL ZTLDMODE
            JR   Z,ZTSTBSS
            LD   DE,11                   ; LD HL/DE/BC plus LDIR
            ADD  HL,DE
ZTSTBSS:
            LD   DE,(PGBSSLEN)
            LD   A,D
            OR   E
            JR   Z,ZTSTSTK
            LD   DE,9                    ; LD HL/BC plus CALL InitializeBss
            ADD  HL,DE
ZTSTSTK:
            LD   A,(TGSTKMOD)
            OR   A
            JR   Z,ZTSTOK
            LD   DE,13                   ; save/select SP plus terminal restore
            ADD  HL,DE
            PUSH HL
            CALL ZTINITLN
            JR   C,ZTSTKERR
            LD   DE,(PGBSSLEN)
            ADD  HL,DE
            JR   C,ZTSTKERR
            LD   DE,TGSTKREQ+2
            ADD  HL,DE
            JR   C,ZTSTKERR
            CALL ZTSUBWCI
            JR   C,ZTSTKFIT
ZTSTKERR:
            POP  HL
            JR   ZTCAPERR
ZTSTKFIT:
            POP  HL
ZTSTOK:
            LD   (TGBOOTLN),HL
            LD   (TQBOOTLN),HL
            CALL ZTCMPBNK
            JP   NZ,ZTBANKED
            LD   HL,(ROILEN)
            CALL ZTLDMODE
            JR   Z,ZTFLROK
            LD   DE,(IMGLEN)
            ADD  HL,DE
            JR   C,ZTBEGCAP
            LD   DE,RIVECBYT+RISTBYT
            ADD  HL,DE
            JR   C,ZTBEGCAP
ZTFLROK:
            LD   (TGROLEN),HL
            LD   DE,RIBYTES+3
            ADD  HL,DE
            JR   C,ZTBEGCAP
            LD   DE,(TGBOOTLN)
            ADD  HL,DE
            JR   C,ZTBEGCAP
            EX   DE,HL                    ; DE is fixed prefix length
            LD   HL,(TGIMGCAP)
            OR   A
            SBC  HL,DE
            JR   C,ZTBEGCAP
            LD   A,H
            OR   L
            JR   Z,ZTBEGCAP ; at least one code byte is required
            LD   (EMLIM),HL           ; remaining code capacity after prefix
            LD   HL,(TGIMGBAS)
            ADD  HL,DE
            JR   C,ZTBEGCAP
            LD   (TGCODBAS),HL
            LD   HL,(EMLIM)
            LD   (TGCODCAP),HL
            CALL ZTLDMODE
            JR   NZ,ZTCODCAP
            LD   DE,(TGCODBAS)
            LD   HL,(TGWRBAS)
            OR   A
            SBC  HL,DE
            JR   C,ZTBEGCAP
            JR   Z,ZTBEGCAP
            LD   (TGCODCAP),HL
            JR   ZTCODCAP
ZTBEGCAP:
ZTCAPERR:
            CALL DGINLINE
            DB  DGTGTCAP
ZTCODCAP:
            CALL ZTBEGIN
            XOR  A
            CALL ZTINITBK
            LD   A,$C3
            CALL ZTENTPH
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF

            LD   HL,(EMCUR)
            LD   (TGLINKRT),HL
            ; The complete prefix and image end were checked before BEGIN, so
            ; this proper-prefix address walk cannot wrap.
            LD   DE,RIBYTES
            ADD  HL,DE
            LD   DE,(TGBOOTLN)
            ADD  HL,DE
            LD   (TGROBAS),HL
            CALL ZTPREPRT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            XOR  A
            CALL ZTRTIMG
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   ZTSTART

; Open one adapter generation from the retained full-width descriptor.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
ZTBEGIN:
            LD   IX,(TDPTR)
            CALL TSBEGIN
            JP   C,ZTOUTERR
            RET

; Compare the retained bank count with the flat-output count.
; Contract: out A,zero clobbers sign,parity,halfCarry
ZTCMPBNK:
            LD   A,(TDBNKVAL)
            DEC  A
            RET

; Load and test the selected target layout mode.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry
ZTLDMODE:
            LD   A,(TGLAYMOD)
            OR   A
            RET

; Contract: in A out A,HL
ZTINITBK:
            LD   (TGOUTBNK),A
            LD   HL,(TGIMGBAS)
            LD   (TQENTADR),HL
            LD   (TQIMGBAS),HL
            LD   (EMCUR),HL
            LD   HL,(TGIMGCAP)
            LD   (TQIMGCAP),HL
            LD   (EMLIM),HL
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,D,DE,HL
ZTSAVEBK:
            LD   A,(TGOUTBNK)
            CP   TGOUTCLS
            RET  Z
            CALL FTBKSTAD
            PUSH HL
            POP  DE
            LD   HL,EMCUR
            PUSH BC
            LD   BC,4
            LDIR
            POP  BC
            OR   A
            RET

; Select the bank that receives subsequent generated bytes and derive the
; bank-local aggregate-constant bounds carried by generated region checks.
; Contract: in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ZTSELBK:
            LD   C,A
            CALL ZTCMPBNK
            CP   C
            JP   C,ZTCFGERR
            LD   A,(TGOUTBNK)
            CP   C
            RET  Z
            CALL ZTSAVEBK
            LD   A,C
            LD   (TGOUTBNK),A
            CALL FTBKSTAD
            LD   DE,EMCUR
            LD   BC,4
            LDIR
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,D,DE,HL
ZTREFROB:
            LD   A,(TGOUTBNK)
            CALL FTBRLEAD
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            LD   (TGCROCAP),DE
            LD   HL,(TGIMGBAS)
            LD   DE,RIBYTES+3
            ADD  HL,DE
            LD   A,(TGOUTBNK)
            LD   D,A
            LD   A,(TDENTVAL)
            CP   D
            JR   NZ,ZTROBOK
            LD   DE,(TGBOOTLN)
            ADD  HL,DE
            PUSH HL
            CALL ZTINITLN
            POP  DE
            ADD  HL,DE
ZTROBOK:
            LD   (TGCRBAS),HL
            OR   A
            RET

; Consume DE bytes from the selected bank after one provider operation.
; Contract: in DE out A,carry,zero clobbers sign,parity,halfCarry,B,C,HL
ZTCONEXT:
            LD   HL,(EMLIM)
            OR   A
            SBC  HL,DE
            JP   C,ZTCAPERR
            LD   B,H
            LD   C,L
            LD   HL,(EMCUR)
            ADD  HL,DE
            JR   NC,ZTCONOK
            LD   A,B
            OR   C
            JP   NZ,ZTCAPERR
ZTCONOK:
            LD   (EMCUR),HL
            LD   (EMLIM),BC
            OR   A
            RET

; Ask the context-sensitive provider for one complete resolved runtime and
; consume its identity-fixed extent from the selected bank. Carry distinguishes
; the two fixed provider calls only until the call; the exact extent is kept on
; the stack so the provider may retain its full clobber contract.
; The initialized image always starts at the current output cursor.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
ZTRTINIT:
            LD   A,(TGOUTBNK)
            LD   HL,(EMCUR)
            LD   BC,RIVECBYT+RISTBYT
            OR   A
            JR   ZTRTPROV

; Contract: in A out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
ZTRTIMG:
            LD   HL,(TGLINKRT)
            LD   BC,RIBYTES
            LD   (TQRTLEN),BC
            SCF
ZTRTPROV:
            PUSH BC
            LD   DE,RIABI
            LD   IX,TGRTCTX
            JR   C,ZTRTPCOD
            CALL TSRTINIT
            JR   ZTRTPOK
ZTRTPCOD:
            CALL TSRTIMG
ZTRTPOK:
            POP  DE
            JP   C,ZTOUTERR
            JR   ZTCONEXT

%IF TargetStreamingOutput
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL,IX,IY
ZTSTATIC:
            CALL ZTRTINIT
            LD   HL,IMGBAS
            LD   BC,(IMGLEN)
            JP   ZEBLOCK
%ENDIF

; Banked output is always ROM. Seed each cursor/capacity pair when its bank is
; first visited and save it before advancing; the active final bank remains in
; EmitCursor/EmitLimit until the ordinary switch or final MAP save. Emit every
; uniform runtime, the entry-only startup/initial image, and then the
; declaration-ordered aggregate constants before source code.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
ZTBANKED:
            CALL ZTLDMODE
            JP   Z,ZTCFGERR
            LD   HL,(TGIMGBAS)
            LD   DE,3
            ADD  HL,DE
            LD   (TGLINKRT),HL
            LD   HL,0
            LD   (TGROBAS),HL
            CALL ZTPREPRT
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZTBEGIN
            XOR  A
            LD   C,A
            JR   ZTFRESH
ZTBKLOOP:
            LD   A,(TDENTVAL)
            CP   C
            JR   NZ,ZTBKEMPT
            LD   A,$C3
            PUSH BC
            CALL ZTENTPH
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JR   ZTBKRT
ZTBKEMPT:
            LD   DE,3
            PUSH BC
            CALL ZTCONEXT
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
ZTBKRT:
            PUSH BC
            LD   A,C
            CALL ZTRTIMG
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(TDENTVAL)
            CP   C
            JR   NZ,ZTBKNEXT
            LD   HL,(EMCUR)
            LD   DE,(TGBOOTLN)
            ADD  HL,DE
            JP   C,ZTCAPERR
            LD   (TGROBAS),HL
%IF CompilerDiagnosticReturns
%ELSE
            PUSH BC
%ENDIF
            CALL ZTSTART
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%IF CompilerDiagnosticReturns
            CALL ZTRTINIT
            RET  C
            PUSH BC
            LD   HL,IMGBAS
            LD   BC,(IMGLEN)
            CALL ZEBLOCK
            POP  BC
            RET  C
%ELSE
            CALL ZTSTATIC
            POP  BC
%ENDIF
ZTBKNEXT:
            CALL ZTSAVEBK
            INC  C
            LD   A,(TDBNKVAL)
            CP   C
            JP   Z,ZGBCONST
ZTFRESH:
            LD   A,C
            CALL ZTINITBK
            CALL ZTREFROB
            JR   ZTBKLOOP

; HL is a region base and DE a nonzero capacity. Carry reports every wrapped
; end except the legal exact mathematical end $10000.
; Contract: in DE,HL out A,carry,zero clobbers sign,parity,halfCarry,HL
ZTVALREG:
            LD   A,D
            OR   E
            JP   Z,ZTCAPERR
            ADD  HL,DE
            RET  NC
            LD   A,H
            OR   L
            JP   NZ,ZTCAPERR
            RET

; The two allocation walks arrive with a nonzero required extent. Decrementing
; it converts required <= capacity into one carry result, including equality.
; Contract: in HL out A,HL,carry,zero clobbers sign,parity,halfCarry,DE
ZTSUBWCI:
            DEC  HL
; Contract: in HL out A,HL,carry,zero clobbers sign,parity,halfCarry,DE
ZTSUBWC:
            LD   DE,(TGWRCAP)
            OR   A
            SBC  HL,DE
            RET

; Classify two checked nonempty regions without storing an exclusive $10000
; end in a word. Loaded means writable is wholly inside image; ROM means the
; half-open regions are disjoint. Every partial overlap is rejected.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
ZTCLASS:
            LD   HL,(TGWRBAS)
            LD   DE,(TGIMGBAS)
            OR   A
            SBC  HL,DE                    ; writable offset from image base
            JR   C,ZTWRBEF
            LD   DE,(TGIMGCAP)
            PUSH HL
            OR   A
            SBC  HL,DE
            POP  BC                       ; BC = writable offset
            JR   NC,ZTROMOK    ; starts at or after image end
            LD   HL,(TGIMGCAP)
            OR   A
            SBC  HL,BC                    ; remaining image capacity
            CALL ZTSUBWC
            JP   C,ZTCFGERR
            XOR  A
            JR   ZTMODEOK
ZTWRBEF:
            LD   HL,(TGIMGBAS)
            LD   DE,(TGWRBAS)
            OR   A
            SBC  HL,DE                    ; distance to image start
            CALL ZTSUBWC
            JP   C,ZTCFGERR
ZTROMOK:
            LD   A,TGLAYROM
ZTMODEOK:
            LD   (TGLAYMOD),A
            LD   B,A
            LD   A,(TGSTKMOD)
            ADD  A,A
            OR   B
            LD   H,A
            LD   L,1
            LD   (TQREV),HL
            RET

; Build the compiler-owned portion of the complete operating-layer link
; context. Service destinations are supplied by the adapter at this call.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
ZTPREPRT:
            LD   HL,(TGLINKRT)
            LD   (TCRTBAS),HL
            LD   HL,(TGWRBAS)
            LD   (TCWRBAS),HL
            LD   (TQWRBAS),HL
            LD   DE,(TGWRCAP)
            LD   (TCWRCAP),DE
            LD   (TQWRCAP),DE
            LD   (TCVECBAS),HL
            LD   DE,RIVECBYT
            LD   (TQVECLEN),DE
            ADD  HL,DE
            JR   C,ZTPCAP
            LD   (TCSTBAS),HL
            LD   DE,RISTBYT
            ADD  HL,DE
            JR   C,ZTPCAP
            LD   (TCDATBAS),HL
            ; Continue the address walk once to the BSS base, then form the
            ; independent initialized-plus-BSS capacity from the same static
            ; length. Both additions remain checked at full word width.
            LD   BC,(IMGLEN)
            ADD  HL,BC
            JR   C,ZTPCAP
            LD   (TGBSSBAS),HL
            LD   (TQBSSBAS),HL
            LD   DE,(PGBSSLEN)
            LD   (TQBSSLEN),DE
            LD   H,B
            LD   L,C
            ADD  HL,DE
            JR   C,ZTPCAP
            LD   (TCDATCAP),HL
            CALL ZTCMPBNK
            JR   Z,ZTPREPRO
            LD   HL,0
            LD   (TCROBAS),HL
            LD   (TCROCAP),HL
            JR   ZTROFIN
ZTPREPRO:
            LD   HL,(TGROBAS)
            CALL ZTLDMODE
            JR   Z,ZTROCTX
            ; This is a sub-walk of the already checked flat ROM prefix.
            PUSH HL
            CALL ZTINITLN
            POP  DE
            ADD  HL,DE
ZTROCTX:
            LD   (TCROBAS),HL
            LD   HL,(ROILEN)
            LD   (TCROCAP),HL
ZTROFIN:
            CALL ZTINITLN
            JR   C,ZTPCAP
            LD   DE,(PGBSSLEN)
            ADD  HL,DE
            JR   C,ZTPCAP
            CALL ZTSUBWCI
            JR   C,ZTALLOC
ZTPCAP:
            JP   ZTCAPERR
ZTALLOC:
            XOR  A
            RET

; Emit a call to one identity-fixed helper in the context-linked runtime.
; DE is the helper offset published by nucleus-runtime-identity.asmi.
; Contract: in DE out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZTRTCALL:
            LD   HL,(TGLINKRT)
            ADD  HL,DE
            JP   EMITCALL

; Resolve one identity-fixed writable-state offset for generated operands.
; Contract: in DE out A,HL,carry,zero clobbers sign,parity,halfCarry
ZTSTADR:
            LD   HL,(TCSTBAS)
            ADD  HL,DE
            OR   A
            RET

; Contract: out DE,HL,carry clobbers halfCarry
ZTINITLN:
            LD   HL,(IMGLEN)
            LD   DE,RIVECBYT+RISTBYT
            ADD  HL,DE
            RET

; A is the identity-defined RAM-vector ordinal. The generated call reaches the
; writable vector rather than an address in the compiler's proof adapter.
; Contract: in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZTVCCALL:
            CALL ZTVCADR
            JP   EMITCALL
; Contract: in A out HL,carry,zero clobbers sign,parity,halfCarry,A,DE
ZTVCADR:
            LD   E,A
            ADD  A,A
            ADD  A,E
            LD   E,A
            LD   D,0
            LD   HL,(TCVECBAS)
            ADD  HL,DE
            RET

; Contract: in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZTVCJUMP:
            CALL ZTVCADR
            LD   A,$C3
            JP   ZEOPWORD

; Emit the implicit flat startup at the address already accounted for by
; TargetStartupLength. The entry-slot patch is resolved before source code,
; while the main operand remains the ordinary checked forward fixup.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
ZTSTART:
            LD   DE,(EMDATFIX)
            LD   HL,(EMCUR)
            CALL ZEPWORD
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(TGSTKMOD)
            OR   A
            JR   Z,ZTSTCOPY
            LD   HL,0
            CALL ZELDHL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEBINCHK
            DB  $39                    ; ADD HL,SP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEBINCHK
            DB  $EB                    ; EX DE,HL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,(TGWRBAS)
            LD   DE,(TGWRCAP)
            ADD  HL,DE                    ; $0000 denotes mathematical $10000
            CALL ZELDHL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEBINCHK
            DB  $F9                    ; LD SP,HL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEBINCHK
            DB  $D5                    ; PUSH DE, saved incoming SP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
ZTSTCOPY:
            CALL ZTLDMODE
            JR   Z,ZTSTCLR
            LD   HL,(TGROBAS)
            CALL ZELDHL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   DE,(TGWRBAS)
            CALL ZCLDDEI
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZTINITLN
            CALL ZELDBCI
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEPINLIN
            DB  ZELDIR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
ZTSTCLR:
            LD   HL,(PGBSSLEN)
            LD   A,H
            OR   L
            JR   Z,ZTSTENT
            LD   HL,(TGBSSBAS)
            CALL ZELDHL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,(PGBSSLEN)
            CALL ZELDBCI
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   DE,ROBSS
            CALL ZTRTCALL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
ZTSTENT:
            LD   A,(TGSTKMOD)
            OR   A
            LD   A,$C3                    ; JP main when inheriting SP
            JR   Z,ZTSTEMIT
            LD   A,$CD                    ; CALL main before restoring SP
ZTSTEMIT:
            CALL ZTENTPH
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,(EMCUR)
            LD   (TGTERM),HL
            LD   A,(TGSTKMOD)
            OR   A
            JR   Z,ZTSTTERM
            LD   HL,ZTSTRSTB
            LD   B,3
            CALL ZEBYTES
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
ZTSTTERM:
            LD   DE,RUNSTATE-RTSTATE
            LD   C,RTSUCC
            CALL ZTTERM
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,6                      ; success vector
            CALL ZTVCJUMP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   DE,RTTRPNO-RTSTATE
            LD   C,6                      ; unhandled trap number
            CALL ZTTERM
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,7                      ; unhandled-failure vector
            CALL ZTVCJUMP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,8                      ; trap vector
            JP   ZTVCJUMP

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
ZTFINFLT:
            CALL ZTCMPBNK
            JR   NZ,ZTFINBK
            LD   HL,(EMCUR)
            LD   DE,(TGCODBAS)
            OR   A
            SBC  HL,DE
            LD   (TGCODLEN),HL
            ; Loaded output appends the initialized run image after code. ROM
            ; output already emitted the same bytes before source code.
            CALL ZTLDMODE
            JR   NZ,ZTLOADOK
            LD   HL,(TGWRBAS)
            LD   (EMCUR),HL
            XOR  A
            LD   (TGOUTBNK),A
            CALL ZTINITLN
            LD   (EMLIM),HL
%IF CompilerDiagnosticBranches
            CALL ZTRTINIT
            JP   C,ZTABORT
            LD   HL,IMGBAS
            LD   BC,(IMGLEN)
            CALL ZEBLOCK
            JP   C,ZTABORT
%ELSE
            CALL ZTSTATIC
%ENDIF
            ; Loaded mode temporarily used EmitLimit as the initialized byte
            ; count. Restore the bank-state meaning required by the MAP ABI:
            ; remaining capacity from the final initialized-data end to the
            ; mathematical image end. Modular subtraction also represents a
            ; legal image end at $10000.
            LD   HL,(TGIMGBAS)
            LD   DE,(TGIMGCAP)
            ADD  HL,DE
            LD   DE,(EMCUR)
            OR   A
            SBC  HL,DE
            LD   (EMLIM),HL
ZTLOADOK:
            CALL ZTSAVEBK
            JR   C,ZTFERRNR
            CALL ZTMAPREQ
            JR   NZ,ZTFMBANK
            CALL TSMAP
            JR   ZTFMOK
ZTFMBANK:
            CALL TSBANK
ZTFMOK:
            JR   C,ZTFERRNR
            CALL TSCOMMIT
            JR   C,ZTFERRNR
            XOR  A
            RET

; The operating adapter already owns the descriptor, part-bank array, and
; NOBJ encoder. Give it the two compact retained per-bank tables plus the
; common layout state; it deterministically forms and validates the MAP.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
ZTFINBK:
            JR   ZTLOADOK

ZTCFGERR:
            LD   A,DGTGTCFG
            JR   ZTDIAG
; Fixup resolution closes the bank selector before MAP/COMMIT, while the sink
; generation remains open. Abort that late phase here; the production
; diagnostic continuation subsequently sees TargetOutputClosed and therefore
; cannot issue a second abort.
ZTFERRNR:
ZTFERR:
            PUSH AF
            CALL TSABORT
            POP  AF
ZTOUTERR:
            OR   A
            JR   NZ,ZTDIAG
            LD   A,DGTGTOUT
ZTDIAG:
            JP   DGSET

; Assemble the stable, versioned native-host MAP request after all lengths,
; cursors, and bank states are final. IX remains valid through the sink call;
; Z reports the flat one-bank case.
; Contract: out A,carry,zero,IX clobbers sign,parity,halfCarry,B,DE,HL
ZTMAPREQ:
            LD   A,(TDENTVAL)
            LD   (TQENTBNK),A
            LD   (TQDLBNK),A
            LD   A,(TGSRCPTS)
            LD   (TQPARTCT),A
            LD   HL,(TGPBPTR)
            LD   (TQPBANKS),HL
            CALL ZTINITLN
            LD   (TQINILEN),HL
            LD   (TQDLLEN),HL
            LD   HL,TGSTKREQ
            LD   (TQSTKREQ),HL
            CALL ZTLDMODE
            LD   HL,(TGWRBAS)
            JR   Z,ZTMAPADR
            LD   HL,(TGROBAS)
ZTMAPADR:
            LD   (TQDLADR),HL
            LD   HL,TBBAS
            LD   (TQBNKST),HL
            LD   A,(TDBNKVAL)
            LD   (TQBNKCNT),A
            DEC  A
            LD   IX,TQBASE
            RET

; Contract: in A out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
ZTABORT:
            PUSH AF
            LD   A,(TGOUTBNK)
            INC  A
            CALL NZ,TSABORT
            POP  AF
            SCF
            RET

ZTSTRSTB: DB $C1,$E1,$F9 ; discard CALL return / restore SP
