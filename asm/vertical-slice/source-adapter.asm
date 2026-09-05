; Ordered source-byte adapter. Compatibility builds retain resident part
; descriptors; the native build obtains bounded chunks from the host vector.

%IF AggregateCallSlices
%IF NativeStreamingSource
; The native Z80 host supplies SourceInitializeParts and the bounded refill,
; token-pinning, part-transition, and end-unit entries outside compiler core.

%ELSE
; A is a bounded part count and HL points to five-byte descriptors containing
; stable identity, source start, and source end. The source and descriptors
; remain resident until compilation finishes.
; Contract: in A,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
SAPARTS:
            DEC  A
            CP   SRCPARTS
            JR   NC,SAPRTERR
            LD   (SSPREM),A

; Load the descriptor at HL and retain the address of the following one.
; Contract: in HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
SALDPART:
            LD   A,(HL)
            INC  HL
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            INC  HL
            PUSH DE
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            INC  HL
            LD   (SSPDCUR),HL
            POP  HL
            ; Fall through with A=part, HL=start, and DE=end.
%ENDIF
%ENDIF

; Contract: in A,DE,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
SAINIT:
            LD   (SSPARTID),A
            LD   (SSCUR),HL
            EX   DE,HL
            LD   (SSEND),HL
            XOR  A
            LD   H,A
            LD   L,A
            LD   (SSOFF),HL
            LD   (SSLNTOK),HL
            INC  HL
            LD   (SSLINE),HL
            LD   (SSCOL),HL
            RET

%IF AggregateCallSlices
; Contract: noreturn
SAPRTERR:
            XOR  A
            LD   H,A
            LD   L,A
            LD   D,A
            LD   E,A
            CALL SAINIT
            CALL TKSTART
            CALL DGINLINE
            DB  DGSPTCAP
%ENDIF

; Consume one byte and advance byte offset and byte column. Newline handling
; is separate because LF and CRLF each advance the logical line only once.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,DE,HL
SATAKE:
            CALL SAPEEK
            RET  C
            INC  HL
            LD   (SSCUR),HL
%IF NativeStreamingSource
            JP   SHPOS
%ELSE
            LD   HL,(SSOFF)
            INC  HL
            LD   (SSOFF),HL
            LD   HL,(SSCOL)
            INC  HL
            LD   (SSCOL),HL
            RET
%ENDIF

; The tokenizer has three paths where a known-present byte is consumed and
; the following byte is inspected immediately. The helper falls through to
; SourcePeek so the pair retains full-width source state without a second
; call site.
; Contract: out A,carry,zero,HL clobbers sign,parity,halfCarry,DE
SATAKPEK:
            CALL SATAKE

; Return the current source byte in A. Carry denotes the separate EOF event.
; Contract: out A,carry,zero,HL clobbers sign,parity,halfCarry,DE
SAPEEK:
            LD   HL,(SSCUR)
            LD   DE,(SSEND)
            OR   A
            SBC  HL,DE
%IF NativeStreamingSource
            ADD  HL,DE
            JR   NZ,SAPEKBYT
            ; A completed unit still retains SourcePartEnded. Beginning the
            ; next part clears it before installing that part's first chunk,
            ; so this one state bit distinguishes refill from logical EOF.
            LD   A,(SSPREM)
            AND  SSPEND
            JR   NZ,SASTREND
            PUSH BC
            CALL SHREFILL
            POP  BC
            RET  C
            LD   HL,(SSCUR)
            JR   SAPEKBYT
SASTREND:
            SCF
            RET
%ELSE
%IF AggregateCallSlices
%IF TargetStreamingOutput
            CCF
            RET  C
            ADD  HL,DE
%ELSE
            ADD  HL,DE
            JR   NZ,SAPEKBYT
            SCF
            RET
%ENDIF
%ELSE
            ADD  HL,DE
            JR   NZ,SAPEKBYT
            SCF
            RET
%ENDIF
%ENDIF
; Contract: in HL out A,carry,zero,HL clobbers sign,parity,halfCarry
SAPEKBYT:
            LD   A,(HL)
            OR   A
            RET

%IF NativeStreamingSource
; Materialize one retained provider handle into the current-token cells. Both
; entry names share the same contract because every consumer needs the exact
; spelling length as well as its temporary readable pointer.
; Contract: in HL out A,HL,carry,zero clobbers sign,parity,halfCarry
SARESTOK:
SAMATTOK:
            PUSH BC
            PUSH DE
            CALL SHMATNAM
            LD   (TNLEXPTR),HL
            LD   A,B
            LD   (TNLEN),A
            POP  DE
            POP  BC
            RET
%ENDIF

%IF AggregateCallSlices
%ELSE
; Contract: out carry,zero clobbers sign,parity,halfCarry,A,HL
SALINE:
            LD   HL,(SSLINE)
            INC  HL
            LD   (SSLINE),HL
            LD   HL,1
            LD   (SSCOL),HL
            OR   A
            RET
%ENDIF
