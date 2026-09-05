; Flat append-only target output. The operating adapter owns NOBJ framing,
; service destinations, image fill, CRC, and the two sequential spools.

; Emit entry opcode A followed by one retained zero-word fixup operand.
.routine in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
TargetEmitEntryPlaceholder:
            CALL EmitByte
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,(EMCUR)
            LD   (EMDATFIX),HL
            LD   HL,0
            JP   EmitWord

; Emit one terminal-state byte comparison. DE selects the runtime-state byte
; and C supplies the expected value.
.routine in C,DE out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
TargetEmitTerminalTest:
            PUSH BC
            CALL TargetStateAddress
            LD   A,$3A                    ; LD A,(nn)
            CALL EmitOpcodeWord
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,$FE                    ; CP n
            CALL EmitOpcodeByte
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,TargetTerminalSelectBytes
            JP   EmitPair

; IX points at the stable compact descriptor supplied by the adapter.
.routine in IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
BeginTargetFlatProgram:
            LD   A,TGOUTCLS
            LD   (TGOUTBNK),A
            LD   L,(IX+TDRTID)
            LD   H,(IX+TDRTID+1)
            LD   DE,RIABI
            OR   A
            SBC  HL,DE
            JP   NZ,TargetConfigurationFailure
            LD   A,(IX+TDFLGS)
            CP   TDSETSTK+1
            JP   NC,TargetConfigurationFailure
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
            CALL TargetValidateRegion
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,(TGWRBAS)
            LD   DE,(TGWRCAP)
            CALL TargetValidateRegion
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL TargetClassifyFlatLayout
.if CompilerDiagnosticReturns
            RET  C
.endif
            ; Determine the exact startup extent and validate the optional
            ; established stack before the adapter opens a generation.
            LD   HL,26                   ; JP/CALL main plus terminal dispatch
            CALL TargetLoadLayoutMode
            JR   Z,TargetStartupBss
            LD   DE,11                   ; LD HL/DE/BC plus LDIR
            ADD  HL,DE
TargetStartupBss:
            LD   DE,(PGBSSLEN)
            LD   A,D
            OR   E
            JR   Z,TargetStartupStack
            LD   DE,9                    ; LD HL/BC plus CALL InitializeBss
            ADD  HL,DE
TargetStartupStack:
            LD   A,(TGSTKMOD)
            OR   A
            JR   Z,TargetStartupReady
            LD   DE,13                   ; save/select SP plus terminal restore
            ADD  HL,DE
            PUSH HL
            CALL TargetInitializedLength
            JR   C,TargetStartupStackFailure
            LD   DE,(PGBSSLEN)
            ADD  HL,DE
            JR   C,TargetStartupStackFailure
            LD   DE,TGSTKREQ+2
            ADD  HL,DE
            JR   C,TargetStartupStackFailure
            CALL TargetSubtractWritableCapacityInclusive
            JR   C,TargetStartupStackFits
TargetStartupStackFailure:
            POP  HL
            JR   TargetCapacityFailure
TargetStartupStackFits:
            POP  HL
TargetStartupReady:
            LD   (TGBOOTLN),HL
            LD   (TQBOOTLN),HL
            CALL TargetCompareSingleBank
            JP   NZ,TargetBeginBankedProgram
            LD   HL,(ROILEN)
            CALL TargetLoadLayoutMode
            JR   Z,TargetFlatReadOnlyReady
            LD   DE,(IMGLEN)
            ADD  HL,DE
            JR   C,TargetBeginCapacityFailure
            LD   DE,RIVECBYT+RISTBYT
            ADD  HL,DE
            JR   C,TargetBeginCapacityFailure
TargetFlatReadOnlyReady:
            LD   (TGROLEN),HL
            LD   DE,RIBYTES+3
            ADD  HL,DE
            JR   C,TargetBeginCapacityFailure
            LD   DE,(TGBOOTLN)
            ADD  HL,DE
            JR   C,TargetBeginCapacityFailure
            EX   DE,HL                    ; DE is fixed prefix length
            LD   HL,(TGIMGCAP)
            OR   A
            SBC  HL,DE
            JR   C,TargetBeginCapacityFailure
            LD   A,H
            OR   L
            JR   Z,TargetBeginCapacityFailure ; at least one code byte is required
            LD   (EMLIM),HL           ; remaining code capacity after prefix
            LD   HL,(TGIMGBAS)
            ADD  HL,DE
            JR   C,TargetBeginCapacityFailure
            LD   (TGCODBAS),HL
            LD   HL,(EMLIM)
            LD   (TGCODCAP),HL
            CALL TargetLoadLayoutMode
            JR   NZ,TargetCodeCapacityReady
            LD   DE,(TGCODBAS)
            LD   HL,(TGWRBAS)
            OR   A
            SBC  HL,DE
            JR   C,TargetBeginCapacityFailure
            JR   Z,TargetBeginCapacityFailure
            LD   (TGCODCAP),HL
            JR   TargetCodeCapacityReady
TargetBeginCapacityFailure:
TargetCapacityFailure:
            CALL DGINLINE
            .db  DGTGTCAP
TargetCodeCapacityReady:
            CALL TargetBeginOutput
            XOR  A
            CALL TargetInitializeOutputBank
            LD   A,$C3
            CALL TargetEmitEntryPlaceholder
.if CompilerDiagnosticReturns
            RET  C
.endif

            LD   HL,(EMCUR)
            LD   (TGLINKRT),HL
            ; The complete prefix and image end were checked before BEGIN, so
            ; this proper-prefix address walk cannot wrap.
            LD   DE,RIBYTES
            ADD  HL,DE
            LD   DE,(TGBOOTLN)
            ADD  HL,DE
            LD   (TGROBAS),HL
            CALL TargetPrepareRuntimeContext
.if CompilerDiagnosticReturns
            RET  C
.endif
            XOR  A
            CALL TargetEmitRuntimeImage
.if CompilerDiagnosticReturns
            RET  C
.endif
            JP   TargetEmitStartup

; Open one adapter generation from the retained full-width descriptor.
.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
TargetBeginOutput:
            LD   IX,(TDPTR)
            CALL TSBEGIN
            JP   C,TargetOutputFailure
            RET

; Compare the retained bank count with the flat-output count.
.routine out A,zero clobbers sign,parity,halfCarry
TargetCompareSingleBank:
            LD   A,(TDBNKVAL)
            DEC  A
            RET

; Load and test the selected target layout mode.
.routine out A,carry,zero clobbers sign,parity,halfCarry
TargetLoadLayoutMode:
            LD   A,(TGLAYMOD)
            OR   A
            RET

.routine in A out A,HL
TargetInitializeOutputBank:
            LD   (TGOUTBNK),A
            LD   HL,(TGIMGBAS)
            LD   (TQENTADR),HL
            LD   (TQIMGBAS),HL
            LD   (EMCUR),HL
            LD   HL,(TGIMGCAP)
            LD   (TQIMGCAP),HL
            LD   (EMLIM),HL
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,D,DE,HL
TargetSaveOutputBank:
            LD   A,(TGOUTBNK)
            CP   TGOUTCLS
            RET  Z
            CALL TargetBankStateAddress
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
.routine in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
TargetSelectOutputBank:
            LD   C,A
            CALL TargetCompareSingleBank
            CP   C
            JP   C,TargetConfigurationFailure
            LD   A,(TGOUTBNK)
            CP   C
            RET  Z
            CALL TargetSaveOutputBank
            LD   A,C
            LD   (TGOUTBNK),A
            CALL TargetBankStateAddress
            LD   DE,EMCUR
            LD   BC,4
            LDIR
.routine out A,carry,zero clobbers sign,parity,halfCarry,D,DE,HL
TargetRefreshReadOnlyBounds:
            LD   A,(TGOUTBNK)
            CALL TargetBankRoLengthAddress
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
            JR   NZ,TargetSelectRoBaseReady
            LD   DE,(TGBOOTLN)
            ADD  HL,DE
            PUSH HL
            CALL TargetInitializedLength
            POP  DE
            ADD  HL,DE
TargetSelectRoBaseReady:
            LD   (TGCRBAS),HL
            OR   A
            RET

; Consume DE bytes from the selected bank after one provider operation.
.routine in DE out A,carry,zero clobbers sign,parity,halfCarry,B,C,HL
TargetConsumeExtent:
            LD   HL,(EMLIM)
            OR   A
            SBC  HL,DE
            JP   C,TargetCapacityFailure
            LD   B,H
            LD   C,L
            LD   HL,(EMCUR)
            ADD  HL,DE
            JR   NC,TargetConsumeExtentReady
            LD   A,B
            OR   C
            JP   NZ,TargetCapacityFailure
TargetConsumeExtentReady:
            LD   (EMCUR),HL
            LD   (EMLIM),BC
            OR   A
            RET

; Ask the context-sensitive provider for one complete resolved runtime and
; consume its identity-fixed extent from the selected bank. Carry distinguishes
; the two fixed provider calls only until the call; the exact extent is kept on
; the stack so the provider may retain its full clobber contract.
; The initialized image always starts at the current output cursor.
.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
TargetEmitRuntimeInitialImage:
            LD   A,(TGOUTBNK)
            LD   HL,(EMCUR)
            LD   BC,RIVECBYT+RISTBYT
            OR   A
            JR   TargetEmitRuntimeProvider

.routine in A out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
TargetEmitRuntimeImage:
            LD   HL,(TGLINKRT)
            LD   BC,RIBYTES
            LD   (TQRTLEN),BC
            SCF
TargetEmitRuntimeProvider:
            PUSH BC
            LD   DE,RIABI
            LD   IX,TGRTCTX
            JR   C,TargetEmitRuntimeProviderCode
            CALL TSRTINIT
            JR   TargetEmitRuntimeProviderReady
TargetEmitRuntimeProviderCode:
            CALL TSRTIMG
TargetEmitRuntimeProviderReady:
            POP  DE
            JP   C,TargetOutputFailure
            JR   TargetConsumeExtent

.if TargetStreamingOutput
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL,IX,IY
TargetEmitInitialAndStatic:
            CALL TargetEmitRuntimeInitialImage
            LD   HL,IMGBAS
            LD   BC,(IMGLEN)
            JP   EmitBlock
.endif

; Banked output is always ROM. Seed each cursor/capacity pair when its bank is
; first visited and save it before advancing; the active final bank remains in
; EmitCursor/EmitLimit until the ordinary switch or final MAP save. Emit every
; uniform runtime, the entry-only startup/initial image, and then the
; declaration-ordered aggregate constants before source code.
.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
TargetBeginBankedProgram:
            CALL TargetLoadLayoutMode
            JP   Z,TargetConfigurationFailure
            LD   HL,(TGIMGBAS)
            LD   DE,3
            ADD  HL,DE
            LD   (TGLINKRT),HL
            LD   HL,0
            LD   (TGROBAS),HL
            CALL TargetPrepareRuntimeContext
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL TargetBeginOutput
            XOR  A
            LD   C,A
            JR   TargetStartFreshOutputBank
TargetEmitBankPrefixLoop:
            LD   A,(TDENTVAL)
            CP   C
            JR   NZ,TargetEmitBankEmptySlot
            LD   A,$C3
            PUSH BC
            CALL TargetEmitEntryPlaceholder
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            JR   TargetEmitBankRuntime
TargetEmitBankEmptySlot:
            LD   DE,3
            PUSH BC
            CALL TargetConsumeExtent
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
TargetEmitBankRuntime:
            PUSH BC
            LD   A,C
            CALL TargetEmitRuntimeImage
            POP  BC
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(TDENTVAL)
            CP   C
            JR   NZ,TargetEmitBankPrefixNext
            LD   HL,(EMCUR)
            LD   DE,(TGBOOTLN)
            ADD  HL,DE
            JP   C,TargetCapacityFailure
            LD   (TGROBAS),HL
.if CompilerDiagnosticReturns
.else
            PUSH BC
.endif
            CALL TargetEmitStartup
.if CompilerDiagnosticReturns
            RET  C
.endif
.if CompilerDiagnosticReturns
            CALL TargetEmitRuntimeInitialImage
            RET  C
            PUSH BC
            LD   HL,IMGBAS
            LD   BC,(IMGLEN)
            CALL EmitBlock
            POP  BC
            RET  C
.else
            CALL TargetEmitInitialAndStatic
            POP  BC
.endif
TargetEmitBankPrefixNext:
            CALL TargetSaveOutputBank
            INC  C
            LD   A,(TDBNKVAL)
            CP   C
            JP   Z,TargetEmitBankedAggregateConstants
TargetStartFreshOutputBank:
            LD   A,C
            CALL TargetInitializeOutputBank
            CALL TargetRefreshReadOnlyBounds
            JR   TargetEmitBankPrefixLoop

; HL is a region base and DE a nonzero capacity. Carry reports every wrapped
; end except the legal exact mathematical end $10000.
.routine in DE,HL out A,carry,zero clobbers sign,parity,halfCarry,HL
TargetValidateRegion:
            LD   A,D
            OR   E
            JP   Z,TargetCapacityFailure
            ADD  HL,DE
            RET  NC
            LD   A,H
            OR   L
            JP   NZ,TargetCapacityFailure
            RET

; The two allocation walks arrive with a nonzero required extent. Decrementing
; it converts required <= capacity into one carry result, including equality.
.routine in HL out A,HL,carry,zero clobbers sign,parity,halfCarry,DE
TargetSubtractWritableCapacityInclusive:
            DEC  HL
.routine in HL out A,HL,carry,zero clobbers sign,parity,halfCarry,DE
TargetSubtractWritableCapacity:
            LD   DE,(TGWRCAP)
            OR   A
            SBC  HL,DE
            RET

; Classify two checked nonempty regions without storing an exclusive $10000
; end in a word. Loaded means writable is wholly inside image; ROM means the
; half-open regions are disjoint. Every partial overlap is rejected.
.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
TargetClassifyFlatLayout:
            LD   HL,(TGWRBAS)
            LD   DE,(TGIMGBAS)
            OR   A
            SBC  HL,DE                    ; writable offset from image base
            JR   C,TargetWritableBeforeImage
            LD   DE,(TGIMGCAP)
            PUSH HL
            OR   A
            SBC  HL,DE
            POP  BC                       ; BC = writable offset
            JR   NC,TargetFlatRomReady    ; starts at or after image end
            LD   HL,(TGIMGCAP)
            OR   A
            SBC  HL,BC                    ; remaining image capacity
            CALL TargetSubtractWritableCapacity
            JP   C,TargetConfigurationFailure
            XOR  A
            JR   TargetLayoutModeReady
TargetWritableBeforeImage:
            LD   HL,(TGIMGBAS)
            LD   DE,(TGWRBAS)
            OR   A
            SBC  HL,DE                    ; distance to image start
            CALL TargetSubtractWritableCapacity
            JP   C,TargetConfigurationFailure
TargetFlatRomReady:
            LD   A,TGLAYROM
TargetLayoutModeReady:
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
.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
TargetPrepareRuntimeContext:
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
            JR   C,TargetPrepareCapacityFailure
            LD   (TCSTBAS),HL
            LD   DE,RISTBYT
            ADD  HL,DE
            JR   C,TargetPrepareCapacityFailure
            LD   (TCDATBAS),HL
            ; Continue the address walk once to the BSS base, then form the
            ; independent initialized-plus-BSS capacity from the same static
            ; length. Both additions remain checked at full word width.
            LD   BC,(IMGLEN)
            ADD  HL,BC
            JR   C,TargetPrepareCapacityFailure
            LD   (TGBSSBAS),HL
            LD   (TQBSSBAS),HL
            LD   DE,(PGBSSLEN)
            LD   (TQBSSLEN),DE
            LD   H,B
            LD   L,C
            ADD  HL,DE
            JR   C,TargetPrepareCapacityFailure
            LD   (TCDATCAP),HL
            CALL TargetCompareSingleBank
            JR   Z,TargetPrepareFlatRoData
            LD   HL,0
            LD   (TCROBAS),HL
            LD   (TCROCAP),HL
            JR   TargetContextRoDataFinished
TargetPrepareFlatRoData:
            LD   HL,(TGROBAS)
            CALL TargetLoadLayoutMode
            JR   Z,TargetContextRoDataReady
            ; This is a sub-walk of the already checked flat ROM prefix.
            PUSH HL
            CALL TargetInitializedLength
            POP  DE
            ADD  HL,DE
TargetContextRoDataReady:
            LD   (TCROBAS),HL
            LD   HL,(ROILEN)
            LD   (TCROCAP),HL
TargetContextRoDataFinished:
            CALL TargetInitializedLength
            JR   C,TargetPrepareCapacityFailure
            LD   DE,(PGBSSLEN)
            ADD  HL,DE
            JR   C,TargetPrepareCapacityFailure
            CALL TargetSubtractWritableCapacityInclusive
            JR   C,TargetWritableAllocationReady
TargetPrepareCapacityFailure:
            JP   TargetCapacityFailure
TargetWritableAllocationReady:
            XOR  A
            RET

; Emit a call to one identity-fixed helper in the context-linked runtime.
; DE is the helper offset published by nucleus-runtime-identity.asmi.
.routine in DE out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
EmitRuntimeCall:
            LD   HL,(TGLINKRT)
            ADD  HL,DE
            JP   EmitCall

; Resolve one identity-fixed writable-state offset for generated operands.
.routine in DE out A,HL,carry,zero clobbers sign,parity,halfCarry
TargetStateAddress:
            LD   HL,(TCSTBAS)
            ADD  HL,DE
            OR   A
            RET

.routine out DE,HL,carry clobbers halfCarry
TargetInitializedLength:
            LD   HL,(IMGLEN)
            LD   DE,RIVECBYT+RISTBYT
            ADD  HL,DE
            RET

; A is the identity-defined RAM-vector ordinal. The generated call reaches the
; writable vector rather than an address in the compiler's proof adapter.
.routine in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
EmitTargetVectorCall:
            CALL TargetVectorAddress
            JP   EmitCall
.routine in A out HL,carry,zero clobbers sign,parity,halfCarry,A,DE
TargetVectorAddress:
            LD   E,A
            ADD  A,A
            ADD  A,E
            LD   E,A
            LD   D,0
            LD   HL,(TCVECBAS)
            ADD  HL,DE
            RET

.routine in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
EmitTargetVectorJump:
            CALL TargetVectorAddress
            LD   A,$C3
            JP   EmitOpcodeWord

; Emit the implicit flat startup at the address already accounted for by
; TargetStartupLength. The entry-slot patch is resolved before source code,
; while the main operand remains the ordinary checked forward fixup.
.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
TargetEmitStartup:
            LD   DE,(EMDATFIX)
            LD   HL,(EMCUR)
            CALL PatchWord
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,(TGSTKMOD)
            OR   A
            JR   Z,TargetStartupCopy
            LD   HL,0
            CALL EmitLoadHl
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitByteInlineChecked
            .db  $39                    ; ADD HL,SP
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitByteInlineChecked
            .db  $EB                    ; EX DE,HL
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,(TGWRBAS)
            LD   DE,(TGWRCAP)
            ADD  HL,DE                    ; $0000 denotes mathematical $10000
            CALL EmitLoadHl
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitByteInlineChecked
            .db  $F9                    ; LD SP,HL
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitByteInlineChecked
            .db  $D5                    ; PUSH DE, saved incoming SP
.if CompilerDiagnosticReturns
            RET  C
.endif
TargetStartupCopy:
            CALL TargetLoadLayoutMode
            JR   Z,TargetStartupClear
            LD   HL,(TGROBAS)
            CALL EmitLoadHl
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   DE,(TGWRBAS)
            CALL EmitLoadDeImmediate
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL TargetInitializedLength
            CALL EmitLoadBcImmediate
.if CompilerDiagnosticReturns
            RET  C
.endif
            CALL EmitPairIndexedInline
            .db  EmitPairLDIR
.if CompilerDiagnosticReturns
            RET  C
.endif
TargetStartupClear:
            LD   HL,(PGBSSLEN)
            LD   A,H
            OR   L
            JR   Z,TargetStartupEntry
            LD   HL,(TGBSSBAS)
            CALL EmitLoadHl
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,(PGBSSLEN)
            CALL EmitLoadBcImmediate
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   DE,ROBSS
            CALL EmitRuntimeCall
.if CompilerDiagnosticReturns
            RET  C
.endif
TargetStartupEntry:
            LD   A,(TGSTKMOD)
            OR   A
            LD   A,$C3                    ; JP main when inheriting SP
            JR   Z,TargetStartupEmitEntry
            LD   A,$CD                    ; CALL main before restoring SP
TargetStartupEmitEntry:
            CALL TargetEmitEntryPlaceholder
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   HL,(EMCUR)
            LD   (TGTERM),HL
            LD   A,(TGSTKMOD)
            OR   A
            JR   Z,TargetStartupTerminalState
            LD   HL,TargetStartupRestoreBytes
            LD   B,3
            CALL EmitBytes
.if CompilerDiagnosticReturns
            RET  C
.endif
TargetStartupTerminalState:
            LD   DE,RUNSTATE-RTSTATE
            LD   C,RTSUCC
            CALL TargetEmitTerminalTest
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,6                      ; success vector
            CALL EmitTargetVectorJump
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   DE,RTTRPNO-RTSTATE
            LD   C,6                      ; unhandled trap number
            CALL TargetEmitTerminalTest
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,7                      ; unhandled-failure vector
            CALL EmitTargetVectorJump
.if CompilerDiagnosticReturns
            RET  C
.endif
            LD   A,8                      ; trap vector
            JP   EmitTargetVectorJump

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
FinishTargetFlatProgram:
            CALL TargetCompareSingleBank
            JR   NZ,FinishTargetBankedProgram
            LD   HL,(EMCUR)
            LD   DE,(TGCODBAS)
            OR   A
            SBC  HL,DE
            LD   (TGCODLEN),HL
            ; Loaded output appends the initialized run image after code. ROM
            ; output already emitted the same bytes before source code.
            CALL TargetLoadLayoutMode
            JR   NZ,TargetLoadedDataReady
            LD   HL,(TGWRBAS)
            LD   (EMCUR),HL
            XOR  A
            LD   (TGOUTBNK),A
            CALL TargetInitializedLength
            LD   (EMLIM),HL
.if CompilerDiagnosticBranches
            CALL TargetEmitRuntimeInitialImage
            JP   C,AbortTargetProgram
            LD   HL,IMGBAS
            LD   BC,(IMGLEN)
            CALL EmitBlock
            JP   C,AbortTargetProgram
.else
            CALL TargetEmitInitialAndStatic
.endif
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
TargetLoadedDataReady:
            CALL TargetSaveOutputBank
            JR   C,TargetFinishOutputFailureNear
            CALL TargetPrepareMapRequest
            JR   NZ,TargetFinishMapBanked
            CALL TSMAP
            JR   TargetFinishMapReady
TargetFinishMapBanked:
            CALL TSBANK
TargetFinishMapReady:
            JR   C,TargetFinishOutputFailureNear
            CALL TSCOMMIT
            JR   C,TargetFinishOutputFailureNear
            XOR  A
            RET

; The operating adapter already owns the descriptor, part-bank array, and
; NOBJ encoder. Give it the two compact retained per-bank tables plus the
; common layout state; it deterministically forms and validates the MAP.
.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
FinishTargetBankedProgram:
            JR   TargetLoadedDataReady

TargetConfigurationFailure:
            LD   A,DGTGTCFG
            JR   TargetDiagnosticReady
; Fixup resolution closes the bank selector before MAP/COMMIT, while the sink
; generation remains open. Abort that late phase here; the production
; diagnostic continuation subsequently sees TargetOutputClosed and therefore
; cannot issue a second abort.
TargetFinishOutputFailureNear:
TargetFinishOutputFailure:
            PUSH AF
            CALL TSABORT
            POP  AF
TargetOutputFailure:
            OR   A
            JR   NZ,TargetDiagnosticReady
            LD   A,DGTGTOUT
TargetDiagnosticReady:
            JP   DGSET

; Assemble the stable, versioned native-host MAP request after all lengths,
; cursors, and bank states are final. IX remains valid through the sink call;
; Z reports the flat one-bank case.
.routine out A,carry,zero,IX clobbers sign,parity,halfCarry,B,DE,HL
TargetPrepareMapRequest:
            LD   A,(TDENTVAL)
            LD   (TQENTBNK),A
            LD   (TQDLBNK),A
            LD   A,(TGSRCPTS)
            LD   (TQPARTCT),A
            LD   HL,(TGPBPTR)
            LD   (TQPBANKS),HL
            CALL TargetInitializedLength
            LD   (TQINILEN),HL
            LD   (TQDLLEN),HL
            LD   HL,TGSTKREQ
            LD   (TQSTKREQ),HL
            CALL TargetLoadLayoutMode
            LD   HL,(TGWRBAS)
            JR   Z,TargetMapRequestDataLoadAddressReady
            LD   HL,(TGROBAS)
TargetMapRequestDataLoadAddressReady:
            LD   (TQDLADR),HL
            LD   HL,TBBAS
            LD   (TQBNKST),HL
            LD   A,(TDBNKVAL)
            LD   (TQBNKCNT),A
            DEC  A
            LD   IX,TQBASE
            RET

.routine in A out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
AbortTargetProgram:
            PUSH AF
            LD   A,(TGOUTBNK)
            INC  A
            CALL NZ,TSABORT
            POP  AF
            SCF
            RET

TargetStartupRestoreBytes: .db $C1,$E1,$F9 ; discard CALL return / restore SP
TargetTerminalSelectBytes .equ TypedBeginAndBytes+3 ; JR NZ across one JP
