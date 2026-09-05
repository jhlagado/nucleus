; Direct-Z80 runtime and bounded output adapter for the counted-loop slice.

            %INCLUDE "nucleus-runtime-identity.asmi"

%IF RuntimeProofServices
; Contract: out carry,zero clobbers sign,parity,halfCarry,A,B,C,HL
Reset:
            XOR  A
            LD   HL,RTTRPNO
            LD   B,StateEnd-RTTRPNO
            CALL RTZERO
            LD   A,RTACTCAP
            LD   (RTACTLIM),A
            XOR  A
            LD   HL,ServiceFailureCall
            LD   B,ServiceInputLength-ServiceFailureCall
            CALL RTZERO
            LD   (ServiceInputCursor),A
            LD   (ServiceInputFailure),A
            LD   (ServiceStorageInputCursor),A
            LD   (ServiceStorageInputFailure),A
            LD   HL,ServiceStorageOutputLength
            LD   B,ServiceStateEnd-ServiceStorageOutputLength
            CALL RTZERO
            LD   A,RunReady
            LD   (RunState),A
            OR   A
            RET

; Contract: in A,B,HL out B,HL clobbers zero,sign,parity,halfCarry
RTZERO:
            LD   (HL),A
            INC  HL
            DJNZ RTZERO
            RET
%ENDIF

; Begin one scalar activation atomically. A is the copied u8 argument. The
; packed arena stores exactly the overwritten byte; Z80 CALL/RET carries the
; Z80 return address separately. Carry reports activation-capacity with
; trap number 5 and leaves depth, arena, and the active scalar unchanged.
; Contract: in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,HL
RTAPUSH:
            LD   B,A
            CALL RTACLM
            RET  C
            LD   A,(RTSCALAR)
            PUSH BC
            LD   B,0
            LD   HL,RTACTMEM
            ADD  HL,BC
            POP  BC
            LD   (HL),A
            LD   A,B
            LD   (RTSCALAR),A
            XOR  A
            RET

; Pop one successful scalar activation. The result is preserved by the
; generated caller while this helper restores its previous scalar byte.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,HL
RTAPOP:
            LD   A,(RTDEPTH)
            DEC  A
            LD   (RTDEPTH),A
            LD   C,A
            LD   B,0
            LD   HL,RTACTMEM
            ADD  HL,BC
            LD   A,(HL)
            LD   (RTSCALAR),A
            XOR  A
            RET

; The integrated typed-call path keeps parameters and locals in each Z80
; stack frame. These helpers therefore account only for bounded active depth;
; they preserve HL so a checked argument or returned carrier can cross them.
; Contract: out A,C,carry,zero clobbers sign,parity,halfCarry
RTACLM:
            LD   A,(RTDEPTH)
            LD   C,A
            LD   A,(RTACTLIM)
            CP   C
            JR   Z,RTACFULL
            LD   A,C
            CP   RTACTCAP
            JR   NC,RTACFULL
            INC  A
            LD   (RTDEPTH),A
            XOR  A
            RET
RTACFULL:
            LD   A,5
            SCF
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry
RTAREL:
            LD   A,(RTDEPTH)
            DEC  A
            LD   (RTDEPTH),A
            XOR  A
            RET

%IF AggregateCallSlices
; Carry reports an out-of-domain u16 index. BC is the retained word length and
; DE is the canonical index carrier.
; Contract: in BC,DE out A,carry,zero clobbers sign,parity,halfCarry
RTARRIX:
            LD   A,E
            SUB  C
            LD   A,D
            SBC  A,B
            JR   NC,RTBNDERR
RTARRDY:
            OR   A
            RET

; C is the declared capacity and HL a bounded-string carrier. On success HL is
; the canonical current length. A corrupted length above capacity is rejected.
; Contract: in C,HL out A,HL,carry,zero clobbers sign,parity,halfCarry,C
RTSTRLEN:
            INC  C
            LD   A,(HL)
            CP   C
            JR   NC,RTBNDERR
RTSLRDY:
            LD   L,A
            LD   H,0
            OR   A
            RET

; C is the declared capacity, HL a bounded-string carrier, and DE the canonical
; index. On success HL is the addressed payload byte; no byte is read before
; the length invariant and logical-index checks.
; Contract: in C,DE,HL out A,HL,carry,zero clobbers sign,parity,halfCarry,BC,DE
RTSTRIDX:
            LD   A,D
            OR   A
            JR   NZ,RTBNDERR
            LD   A,(HL)
            LD   B,A
            INC  C
            CP   C
            JR   NC,RTBNDERR
RTSILRDY:
            LD   A,B
            CP   E
            JR   C,RTBNDERR
            JR   Z,RTBNDERR
            INC  HL
            ADD  HL,DE
            OR   A
            RET

%IF RuntimeProofServices
%IF TargetStreamingOutput
%ELSE
; Historical proof ABI using the supplied exclusive data end.
; Contract: in BC,DE,HL out A,carry,zero clobbers sign,parity,halfCarry,DE,HL,IY
RTREGCHK:
            PUSH DE
            POP  IY
%IF AggregateCallSlices
            PUSH HL
            LD   DE,MMDATA
            CALL RTREGONE
            POP  HL
            RET  NC
            LD   DE,RORDATA
            LD   IY,MMROEND
%ELSE
            LD   DE,MMGEN+3
%ENDIF
            JP   RTREGONE
%ENDIF

; Contract: in BC,DE,HL,IY out A,carry,zero clobbers sign,parity,halfCarry,DE,HL
RTREGONE:
            OR   A
            SBC  HL,DE
            JR   C,RTREGERR
            ADD  HL,DE
            ADD  HL,BC
            JR   C,RTREGERR
            PUSH IY
            POP  DE
            OR   A
            SBC  HL,DE
            JR   C,RTREGOK
            JR   Z,RTREGOK
%ELSE
; Target-linked ABI: DE/IY carry the bank-local read-only base/capacity. The
; writable base/capacity is initialized runtime state. Capacities preserve a
; legal nonempty region ending at mathematical $10000 without making the
; helper image depend on one source program's data and BSS lengths.
; Contract: in BC,DE,HL,IY out A,carry,zero clobbers sign,parity,halfCarry,DE,HL,IY
RTREGCHK:
            PUSH DE
            PUSH IY
            PUSH HL
            LD   DE,(RTDBWORD)
            LD   IY,(RTDCWORD)
            CALL RTREGONE
            POP  HL
            POP  IY
            POP  DE
            RET  NC
            JR   RTREGONE

; Contract: in BC,DE,HL,IY out A,carry,zero clobbers sign,parity,halfCarry,DE,HL
RTREGONE:
            OR   A
            SBC  HL,DE
            JR   C,RTREGERR
            ADD  HL,BC
            JR   C,RTREGERR
            PUSH IY
            POP  DE
            OR   A
            SBC  HL,DE
            JR   C,RTREGOK
            JR   Z,RTREGOK
%ENDIF
RTREGERR:
            SCF
            RET
RTREGOK:
            OR   A
            RET

RTBNDERR:
            SCF
            RET

%IF AggregateCallSlices
; Clear one complete BSS segment before main. BC is a nonzero published size
; and HL is the fixed target-adapter base.
; Contract: in BC,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,D,HL
RTBSS:
            LD   A,B
            OR   C
            RET  Z
            LD   D,0
RTBSSLP:
            LD   (HL),D
            INC  HL
            DEC  BC
            LD   A,B
            OR   C
            JR   NZ,RTBSSLP
            OR   A
            RET
%ENDIF
%ENDIF

; Unsigned low-byte multiplication for generated expression code. A and B are
; the operands; the result wraps modulo 256 exactly as MUL8 requires.
; Contract: in A,B out A,carry,zero clobbers sign,parity,halfCarry,B,C
RTMUL8:
            LD   C,A
            XOR  A
            INC  B
RTM8LOOP:
            DEC  B
            RET  Z
            ADD  A,C
            JR   RTM8LOOP

; Full-width multiplication for typed generated expressions. Small nonzero
; powers of two shift directly; the general sixteen-round path returns the low
; sixteen bits, matching u16 wraparound.
; Contract: in DE,HL out HL,carry,zero clobbers sign,parity,halfCarry,A,BC,DE
RTMUL16:
            LD   A,D
            OR   A
            JR   NZ,RTM16GEN
            LD   A,E
            OR   A
            JR   Z,RTM16GEN
            DEC  A
            AND  E
            JR   NZ,RTM16GEN
            LD   A,E
RTM16POW:
            SRL  A
            JR   Z,RTM16PEN
            ADD  HL,HL
            JR   RTM16POW
RTM16PEN:
            OR   A
            RET
RTM16GEN:
            LD   BC,0
            LD   A,16
RTM16LP:
            SRL  D
            RR   E
            JR   NC,RTM16SKP
            PUSH HL
            ADD  HL,BC
            LD   B,H
            LD   C,L
            POP  HL
RTM16SKP:
            ADD  HL,HL
            DEC  A
            JR   NZ,RTM16LP
            LD   H,B
            LD   L,C
            OR   A
            RET

; Unsigned quotient. Carry reports a zero divisor without producing a value.
; Contract: in DE,HL out HL,carry,zero clobbers sign,parity,halfCarry,A,BC,DE
RTDIV16:
            CALL RTD16COR
            RET  C
            LD   H,B
            LD   L,C
            OR   A
            RET

; Contract: in DE,HL out HL,carry,zero clobbers sign,parity,halfCarry,A,BC,DE
RTMOD16:
            JR   RTD16COR

; Contract: in DE,HL out BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,A
RTD16COR:
            LD   A,D
            OR   E
            JR   Z,RTD16ZER
            LD   A,D
            OR   A
            JR   NZ,RTD16GEN
            LD   A,E
            DEC  A
            AND  E
            JR   NZ,RTD16GEN
            LD   A,E
            DEC  A
            AND  L
            LD   D,A
            LD   A,E
RTD16POW:
            SRL  A
            JR   Z,RTD16PEN
            SRL  H
            RR   L
            JR   RTD16POW
RTD16PEN:
            LD   B,H
            LD   C,L
            LD   L,D
            LD   H,0
            OR   A
            RET
RTD16GEN:
            LD   BC,0
RTD16LP:
            OR   A
            SBC  HL,DE
            JR   C,RTD16END
            INC  BC
            JR   RTD16LP
RTD16END:
            ADD  HL,DE
            OR   A
            RET
RTD16ZER:
            SCF
            RET

; A selects Comparison*. Both integer widths and booleans use canonical u16
; carriers here; the parser has already restricted Boolean relations to =/<>.
; Contract: in A,DE,HL out HL,carry,zero clobbers sign,parity,halfCarry,A,BC,DE,IX,IY
RTCMP16:
            BIT  7,A
            JP   NZ,RTSCMP
            LD   B,A
            OR   A
            SBC  HL,DE
            PUSH AF
            POP  DE
            LD   A,B
            CP   RCEQ
            JR   Z,RTCMPEQ
            CP   RCNE
            JR   Z,RTCMPNE
            CP   RCLT
            JR   Z,RTCMPLT
            CP   RCLE
            JR   Z,RTCMPLE
            CP   RCGT
            JR   Z,RTCMPGT
RTCMPGE:
            PUSH DE
            POP  AF
            JR   NC,RTCMPYES
            JR   RTCMPNO
RTCMPEQ:
            PUSH DE
            POP  AF
            JR   Z,RTCMPYES
            JR   RTCMPNO
RTCMPNE:
            PUSH DE
            POP  AF
            JR   NZ,RTCMPYES
            JR   RTCMPNO
RTCMPLT:
            PUSH DE
            POP  AF
            JR   C,RTCMPYES
            JR   RTCMPNO
RTCMPLE:
            PUSH DE
            POP  AF
            JR   C,RTCMPYES
            JR   Z,RTCMPYES
            JR   RTCMPNO
RTCMPGT:
            PUSH DE
            POP  AF
            JR   C,RTCMPNO
            JR   Z,RTCMPNO
RTCMPYES:
            LD   HL,1
            OR   A
            RET
RTCMPNO:
            LD   HL,0
            OR   A
            RET

%IF AggregateCallSlices
; Resize a validated bounded-string region. C is capacity, DE is the
; canonical u8 new length, and HL is the carrier. Every rejection precedes
; mutation; shrinking clears the removed payload before publishing length.
; Contract: in C,DE,HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,HL,IX,IY
RTRESIZE:
            LD   A,(HL)
            LD   B,A                     ; old length
            LD   A,C
            CP   B
            RET  C
            CP   E
            RET  C
RTRSZCAP:
            LD   A,B
            SUB  E
            JR   C,RTRSZSET
            JR   Z,RTRSZSET
            LD   B,A                     ; bytes new+1 through old
            PUSH HL
            INC  HL
            ADD  HL,DE
            XOR  A
RTRSZCLR:
            LD   (HL),A
            INC  HL
            DJNZ RTRSZCLR
            POP  HL
RTRSZSET:
            LD   (HL),E
            OR   A
            RET
%ENDIF

; Checked numeric conversion among u8, u16, i8 and i16. A is the source type,
; C is the destination type, and HL is the canonical source carrier. Carry
; reports an out-of-range value without changing HL.
RTTYBASE   EQU $03
RTTYSIGN EQU $10
RTTYMETA   EQU $13
RTTYU16        EQU $02
RTTYI8         EQU $11
RTTYI16        EQU $12
; Contract: in A,C,HL out HL,carry,zero clobbers sign,parity,halfCarry,A,B,C,D,E,IX,IY
RTCONV:
            LD   D,A
            AND  RTTYMETA
            CP   RTTYI8
            JR   Z,RTCNVI8
            CP   RTTYI16
            JR   Z,RTCNVI16
            JR   RTCNVPOS
RTCNVI8:
            BIT  7,L
            JR   Z,RTCNVPOS
            LD   H,$FF
            JR   RTCNVNEG
RTCNVI16:
            BIT  7,H
            JR   Z,RTCNVPOS
RTCNVNEG:
            BIT  4,C
            JR   Z,RTCNVERR
            BIT  1,C
            JR   NZ,RTCNVOK
            INC  H
            JR   NZ,RTCNVERR
            BIT  7,L
            JR   Z,RTCNVERR
            JR   RTCNVOK
RTCNVPOS:
            BIT  1,C
            JR   NZ,RTCNVWRD
            LD   A,H
            OR   A
            JR   NZ,RTCNVERR
            BIT  4,C
            JR   Z,RTCNVOK
            BIT  7,L
            JR   NZ,RTCNVERR
            JR   RTCNVOK
RTCNVWRD:
            BIT  4,C
            JR   Z,RTCNVOK
            BIT  7,H
            JR   NZ,RTCNVERR
RTCNVOK:
            OR   A
            RET
RTCNVERR:
            SCF
            RET

; A carries the ordinary comparison selector in bits 0..5, the signed marker
; in bit 7, and byte width in bit 6. Bias the relevant sign bit, then reuse the
; unsigned comparison core.
; Contract: in A,DE,HL out HL,carry,zero clobbers sign,parity,halfCarry,A,BC,DE,IX,IY
RTSCMP:
            LD   B,A
            BIT  6,B
            JR   Z,RTSCMP16
            LD   H,0
            LD   D,0
            LD   A,L
            XOR  $80
            LD   L,A
            LD   A,E
            XOR  $80
            LD   E,A
            JR   RTSCMRDY
RTSCMP16:
            LD   A,H
            XOR  $80
            LD   H,A
            LD   A,D
            XOR  $80
            LD   D,A
RTSCMRDY:
            LD   A,B
            AND  $3F
            JP   RTCMP16

; Signed quotient/remainder. A bit 0 selects remainder and bit 7 requests a
; canonical i8 result. Inputs are canonical carriers in HL and DE.
; Contract: in A,DE,HL out HL,carry,zero clobbers sign,parity,halfCarry,A,BC,DE
RTSDIV:
            LD   C,A
            BIT  7,A
            JR   Z,RTSDVWID
            BIT  7,L
            JR   Z,RTSDVR8
            LD   H,$FF
RTSDVR8:
            BIT  7,E
            JR   Z,RTSDVWID
            LD   D,$FF
RTSDVWID:
            LD   A,C
            AND  $81
            LD   C,A
            BIT  7,H
            JR   Z,RTSDVNUM
            SET  1,C                     ; remainder sign
            SET  2,C                     ; quotient sign, toggled by divisor
            CALL RTSDVNEG
RTSDVNUM:
            BIT  7,D
            JR   Z,RTSDVSGN
            LD   A,C
            XOR  4
            LD   C,A
            EX   DE,HL
            CALL RTSDVNEG
            EX   DE,HL
RTSDVSGN:
            LD   A,C
            PUSH AF
            CALL RTD16COR
            POP  DE                     ; D=mode without replacing core flags
            RET  C
            BIT  0,D
            JR   NZ,RTSDVREM
            LD   H,B
            LD   L,C
            BIT  2,D
            JR   Z,RTSDVRES
            CALL RTSDVNEG
            JR   RTSDVRES
RTSDVREM:
            BIT  1,D
            JR   Z,RTSDVRES
            CALL RTSDVNEG
RTSDVRES:
            BIT  7,D
            JR   Z,RTSDVOK
            LD   H,0
RTSDVOK:
            OR   A
            RET
; Contract: in HL out A,HL,carry,zero clobbers sign,parity,halfCarry
RTSDVNEG:
            XOR  A
            SUB  L
            LD   L,A
            LD   A,0
            SBC  A,H
            LD   H,A
            RET

; Advance one signed counted-loop counter. A carries the loop mode: bit 1
; selects subtraction and bit 2 selects i16 rather than canonical i8. HL is
; the counter and DE the unsigned positive step magnitude. Check that complete
; magnitude against the mathematical distance to the selected type boundary;
; treating E or DE as a signed addend would mis-handle steps 128..65535. Carry
; reports signed continuation overflow; a successful i8 result retains H=0.
; Contract: in A,DE,HL out HL,carry,zero clobbers sign,parity,halfCarry,A,BC,DE,IX,IY
RTSSTEP:
            LD   C,A
            BIT  2,C
            JR   NZ,RTSS16
            LD   A,D
            OR   A
            JR   NZ,RTSSERR
            BIT  1,C
            LD   A,L
            JR   NZ,RTSS8NEG
            LD   A,$7F
            SUB  L                       ; positive distance to 127
            JR   RTSS8CHK
RTSS8NEG:
            SUB  $80                     ; negative distance to -128
RTSS8CHK:
            CP   E
            JR   C,RTSSERR
            LD   A,L
            BIT  1,C
            JR   NZ,RTSS8SUB
            ADD  A,E
            JR   RTSS8SET
RTSS8SUB:
            SUB  E
RTSS8SET:
            LD   L,A
            LD   H,0
            JR   RTSSOK
RTSS16:
            PUSH AF
            LD   B,H
            LD   C,L
            BIT  1,A
            JR   NZ,RTSSWNEG
            LD   A,$FF
            SUB  C
            LD   C,A
            LD   A,$7F
            SBC  A,B
            LD   B,A                     ; BC = 32767 - counter
            JR   RTSSWCHK
RTSSWNEG:
            LD   A,B
            SUB  $80
            LD   B,A                     ; BC = counter - (-32768)
RTSSWCHK:
            LD   A,B
            CP   D
            JR   C,RTSSWERR
            JR   NZ,RTSSWADD
            LD   A,C
            CP   E
            JR   C,RTSSWERR
RTSSWADD:
            POP  AF
            BIT  1,A
            JR   NZ,RTSSWSUB
            ADD  HL,DE
            JR   RTSSOK
RTSSWSUB:
            OR   A
            SBC  HL,DE
RTSSOK:
            OR   A
            RET
RTSSWERR:
            POP  AF
RTSSERR:
            SCF
            RET

; Promote one canonical i8 carrier within a pending binary pair. A=0 selects
; DE (the right carrier) and A=1 selects HL (the left carrier).
; Contract: in A,DE,HL out DE,HL,carry,zero clobbers sign,parity,halfCarry,A
RTI8PAIR:
            OR   A
            JR   Z,RTI8RHS
            BIT  7,L
            JR   Z,RTI8RDY
            DEC  H
RTI8RDY:
            RET
RTI8RHS:
            BIT  7,E
            RET  Z
            DEC  D
            RET

%IF RuntimeProofServices
; Carry returns endOfInput, a configured input failure, or success in A.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,HL
RTREADIN:
            LD   C,2
            LD   HL,ServiceInputLength
            JR   RTREADSV

; Bulk input shares the same length/cursor/failure/buffer record shape. Its
; configured failure is normalized to the stable storageFailure code in C.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,HL
RTREADST:
            LD   C,4
            LD   HL,ServiceStorageInputLength
            JR   RTREADSV
; Contract: in C,HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,HL
RTREADSV:
            INC  HL
            INC  HL
            LD   A,(HL)
            OR   A
            JR   Z,RTRDRDY
            LD   A,C
            SCF
            RET
RTRDRDY:
            DEC  HL
            DEC  HL
            LD   A,(HL)
            INC  HL
            LD   C,(HL)
            CP   C
            JR   Z,RTRDEND
            PUSH HL
            INC  HL
            INC  HL
            LD   B,0
            ADD  HL,BC
            LD   A,(HL)
            LD   B,A
            INC  C
            LD   A,C
            POP  HL
            LD   (HL),A
            LD   A,B
            OR   A
            RET
RTRDEND:
            LD   A,1
            SCF
            RET

; Input A is the byte. Carry returns a recoverable outputFailure code.
; D is preserved because this slice allocates its scalar counter there.
; Contract: in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,E,HL
RTWRITE:
            LD   E,A
            LD   A,(ServiceCallCount)
            INC  A
            LD   (ServiceCallCount),A
            LD   C,A
            LD   A,(ServiceFailureCall)
            OR   A
            JR   Z,RTWRSET
            CP   C
            JR   Z,RTWRERR
RTWRSET:
            LD   A,(ServiceOutputLength)
            CP   ServiceOutputCapacity
            JR   NC,RTWRERR
            LD   C,A
            LD   B,0
            LD   HL,ServiceOutputBase
            ADD  HL,BC
            LD   A,E
            LD   (HL),A
            LD   A,(ServiceOutputLength)
            INC  A
            LD   (ServiceOutputLength),A
            XOR  A
            RET
RTWRERR:
            LD   A,3
            SCF
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry
RTREWIND:
            LD   A,(ServiceStorageInputFailure)
            OR   A
            JR   NZ,RTSTERR
            LD   (ServiceStorageInputCursor),A
            RET

; Input A is written at the current bulk-output cursor. Every check precedes
; the first cursor, length, or output-byte mutation.
; Contract: in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,HL
RTWRSTOR:
            LD   D,A
            LD   A,(ServiceStorageOutputFailure)
            OR   A
            JR   NZ,RTSTERR
            LD   A,(ServiceStorageOutputCursor)
            LD   C,A
            LD   A,(ServiceStorageOutputLength)
            CP   C
            JR   C,RTSTERR
            JR   NZ,RTWRADDR
            LD   A,C
            CP   ServiceStorageOutputCapacity
            JR   NC,RTSTERR
            INC  A
            LD   (ServiceStorageOutputLength),A
RTWRADDR:
            LD   B,0
            LD   HL,ServiceStorageOutputBase
            ADD  HL,BC
            LD   (HL),D
            INC  C
            LD   A,C
            LD   (ServiceStorageOutputCursor),A
            XOR  A
            RET

; Input HL is an unsigned offset. Only existing positions and the exact end
; are admitted; failure leaves the cursor unchanged.
; Contract: in HL out A,carry,zero clobbers sign,parity,halfCarry
RTSEEK:
            LD   A,H
            OR   A
            JR   NZ,RTSTERR
            LD   A,(ServiceStorageOutputFailure)
            OR   A
            JR   NZ,RTSTERR
            LD   A,(ServiceStorageOutputLength)
            CP   L
            JR   C,RTSTERR
            LD   A,L
            LD   (ServiceStorageOutputCursor),A
            OR   A
            RET

RTSTERR:
            LD   A,4
            SCF
            RET
%ENDIF

%IF RuntimePacketGateway
; DE is a private source offset retained only by the common wrapper. The native
; provider sees the public A/HL/BC packet ABI and may clobber DE.
; Contract: noreturn in A,BC,DE,HL out A,BC,DE,HL,IX,carry,zero clobbers sign,parity,halfCarry
RTPACKET:
            PUSH DE
            CALL RTPKTVEC
            POP  DE
            JR   C,RTPKTERR
            POP  HL                      ; generated continuation
            POP  BC                      ; discard terminal dispatcher
            JP   (HL)
; Contract: noreturn in A,DE out A,HL,IX clobbers B,C,D,E,sign,parity,halfCarry,carry,zero
RTPKTERR:
            POP  HL                      ; discard generated continuation
            POP  BC                      ; terminal dispatcher
            LD   (RTTRPNO),A
            LD   (RTTRPOFF),DE
            LD   SP,(RootSP)
            LD   IX,(RootIX)
            XOR  A
            LD   (RTTRPRTN),A
            LD   (RTDEPTH),A
            LD   A,RTTRAP
            LD   (RunState),A
            LD   H,B
            LD   L,C
            JP   (HL)
%ENDIF
