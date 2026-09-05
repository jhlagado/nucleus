; Native windowed-source adapter. This code belongs to the Z80 host image,
; outside CompilerCodeEnd: it manages source storage lifetime without charging
; the 16 KiB compiler core. The compiler and host are linked against the same
; source-state ABI.

; Contract: in A out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
SAPARTS:
            DEC  A
            CP   SRCPARTS
            JP   NC,SAPRTERR
            LD   B,A
            XOR  A
            LD   HL,SSPINSEG
            LD   C,SSHOST-SSPINSEG+1
SHINITLP:
            LD   (HL),A
            INC  HL
            DEC  C
            JP   NZ,SHINITLP
            LD   A,B
            LD   (SSPREM),A
            JP   SHPART

; Contract: noreturn
SHBAD:
            LD   A,4                    ; native-host invalid status
            LD   (SSHOST),A
            LD   SP,(CPABRTSP)
            SCF
            RET

; Capture the provider's event part ID without exposing its BC clobber to the
; tokenizer. A/DE/HL remain the public event result.
; Contract: out A,carry,zero,DE,HL clobbers sign,parity,halfCarry
SHNEXT:
            PUSH BC
            CALL HVCHUNK
            JP   C,SHFAIL
            PUSH HL
            LD   HL,SSPROVID
            LD   (HL),C
            POP  HL
            POP  BC
            RET

; Contract: in HL,B,C,DE out A,HL,carry,zero clobbers sign,parity,halfCarry
SHRETAIN:
            CALL HVRETAIN
            RET  NC
            JP   SHFAIL

; Adapt the compiler's current-token cell to the host ABI's IX input. The
; compiler-side caller saves and restores its own IX around this entry.
; Contract: in HL,B out A,carry,zero,IX clobbers sign,parity,halfCarry,BC,DE,HL
SHCMPNAM:
            LD   IX,(TNLEXPTR)
            CALL HVCMPNAM
            RET  NC
            JP   SHFAIL

; Contract: in HL out A,B,HL,carry,zero clobbers sign,parity,halfCarry
SHMATNAM:
            CALL HVMATNAM
            RET  NC
; Contract: noreturn
SHFAIL:
            LD   (SSHOST),A
            LD   SP,(CPABRTSP)
            SCF
            RET

; Advance the compiler's full-width source position for the byte in A. This
; belongs with the native source adapter rather than the 16 KiB compiler. A
; newline is preflighted here and completed by TokenizerFinishLine.
; Contract: in A out A,carry,zero clobbers sign,parity,halfCarry,DE,HL
SHPOS:
            LD   D,A
            CP   13
            JP   Z,SHLINE
            CP   10
            JP   NZ,SHLINOK
SHLINE:
            LD   HL,(SSLINE)
            INC  HL
            LD   A,H
            OR   L
            JP   Z,SHPOSERR
SHLINOK:
            LD   HL,(SSOFF)
            INC  HL
            LD   A,H
            OR   L
            JP   Z,SHPOSERR
            PUSH HL
            LD   A,D
            CP   10
            JP   Z,SHSETOFF
            CP   13
            JP   Z,SHSETOFF
            LD   HL,(SSCOL)
            INC  HL
            LD   A,H
            OR   L
            JP   Z,SHCOLERR
            LD   (SSCOL),HL
SHSETOFF:
            POP  HL
            LD   (SSOFF),HL
            LD   A,D
            OR   A
            RET
SHCOLERR:
            POP  HL
SHPOSERR:
            LD   HL,SSOFF
            LD   DE,TNSTOFF
            CALL DGCOPYP
            CALL DGINLINE
            DB  DGSPCAP

; Contract: out HL
SHUNPIN:
            LD   HL,0
            LD   (SSPINCUR),HL
            RET

; Contract: out HL
SHPIN:
            LD   HL,1
            LD   (SSPINCUR),HL
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
SHPART:
            CALL SHNEXT
            CP   1
            JP   NZ,SHBAD
            LD   A,(SSPROVID)
            OR   A
            JP   Z,SHBAD
            LD   HL,0
            LD   D,H
            LD   E,L
            CALL SAINIT
            CALL SHREFILL
            OR   A
            RET

; Append the current live-chunk portion of an active token before a refill can
; invalidate it. Zero means no active token; one means no refill has occurred.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
SHPINPRE:
            LD   HL,(SSPINCUR)
            LD   A,H
            OR   L
            RET  Z
            DEC  HL
            LD   A,H
            OR   L
            JP   NZ,SHPINEXT
            LD   HL,(TNLEXPTR)
            LD   DE,MMTOKEN
            JP   SHCOPY
SHPINEXT:
            LD   HL,(SSPINSEG)
            LD   DE,(SSPINCUR)
            JP   SHCOPY

; Contract: in DE,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
SHCOPY:
            PUSH DE
            PUSH HL
            LD   HL,(SSCUR)
            POP  DE
            OR   A
            SBC  HL,DE
            LD   B,H
            LD   C,L
            PUSH DE
            POP  HL
            POP  DE
            LD   A,B
            OR   C
            RET  Z
            LDIR
            LD   (SSPINCUR),DE
            LD   HL,MMTOKEN
            LD   (TNLEXPTR),HL
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,DE,HL
SHPINEND:
            PUSH BC
            CALL SHPINDO
            POP  BC
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
SHPINDO:
            LD   HL,(SSPINCUR)
            LD   A,H
            OR   L
            RET  Z
            DEC  HL
            LD   A,H
            OR   L
            RET  Z
            LD   HL,(SSPINSEG)
            LD   DE,(SSPINCUR)
            JP   SHCOPY

; Contract: in DE out A,carry,zero,HL clobbers sign,parity,halfCarry,DE
SHBYTEVT:
            LD   A,D
            OR   E
            JP   Z,SHBAD
            PUSH BC
            LD   A,(SSPROVID)
            LD   C,A
            LD   A,(SSPARTID)
            CP   C
            JP   NZ,SHBAD
            CALL SHBYTES
            POP  BC
            RET
; Contract: out A,carry,zero,HL clobbers sign,parity,halfCarry,DE
SHREFILL:
            PUSH BC
            CALL SHPINPRE
            POP  BC
            CALL SHNEXT
            JP   SHREFEVT

; Contract: in A,DE,HL out A,carry,zero,HL clobbers sign,parity,halfCarry,DE
SHREFEVT:
            OR   A
            JP   Z,SHBYTEVT
            CP   2
            JP   NZ,SHBAD
            LD   A,(SSPROVID)
            LD   HL,SSPARTID
            CP   (HL)
            JP   NZ,SHBAD
            ; PinBeforeRefill already copied through SourceCursor. An end event
            ; supplies no replacement chunk, so make the remaining segment
            ; explicitly empty for SourcePinFinishToken.
            LD   HL,(SSCUR)
            LD   (SSPINSEG),HL
            LD   HL,SSPREM
            SET  6,(HL)
            SCF
            RET

; Contract: in DE,HL out A,carry,zero,HL clobbers sign,parity,halfCarry,DE
SHBYTES:
            LD   (SSCUR),HL
            ADD  HL,DE
            LD   (SSEND),HL
            LD   HL,(SSCUR)
            LD   DE,(SSPINCUR)
            LD   A,D
            OR   E
            CALL Z,SHUNPCHK
            RET  Z
            LD   (SSPINSEG),HL
            OR   A
            RET

; Contract: in HL out A,carry,zero,HL clobbers sign,parity,halfCarry
SHUNPCHK:
            LD   (TNLEXPTR),HL
            OR   A
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
SHEND:
            LD   A,(SSPROVID)
            OR   A
            RET  Z
            CALL SHNEXT
            CP   3
            JP   NZ,SHBAD
            XOR  A
            LD   (SSPROVID),A
            RET
