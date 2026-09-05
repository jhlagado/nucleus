; Bounded exact-name table for the first general scalar slice.

%IF AggregateCallSlices
%ELSE
; Contract: out A,carry,zero clobbers sign,parity,halfCarry
SBRESET:
            XOR  A
            LD   (SYCNT),A
            LD   (NXLOCAL),A
            LD   (NXPROG),A
            RET
%ENDIF

; Compare the current NAME token with committed entries, newest first so a
; routine binding naturally precedes the program binding it shadows. Carry
; returns a matching entry in HL. The provisional entry is invisible.
; Contract: out A,carry,zero,HL clobbers sign,parity,halfCarry,B,C,D,DE
SBFIND:
            LD   A,(SYCNT)
            OR   A
            RET  Z
            LD   C,A
            LD   B,A
            LD   HL,SYTABBAS-SYENTSZ
            LD   DE,SYENTSZ
SBFINDAD:
            ADD  HL,DE
            DJNZ SBFINDAD
SBFINDLP:
            CALL TKRECEQ
            RET  C
            LD   DE,-SYENTSZ
            ADD  HL,DE
            DEC  C
            JR   NZ,SBFINDLP
            OR   A
            RET

; Compatibility entry for the older slices: D is class/type information and E
; is a byte-sized payload. New typed declarations call the word entry below.
%IF LegacyCompilerSlices
; Contract: in D,E out A,carry,zero,HL clobbers sign,parity,halfCarry,B,C,D,DE
SBPREP:
            LD   B,0
            LD   C,E
%ENDIF
; Contract: in D,BC out A,carry,zero,HL clobbers sign,parity,halfCarry,B,C,D,DE
SBPREPW:
            PUSH BC
            PUSH DE
            CALL SBFIND
            POP  DE
            POP  BC
            JP   C,TYDUNMER
            JR   SBAPPEND

; Routine bindings may repeat an older program symbol, but not a parameter or
; local already installed in this routine. The newest match is the routine
; binding when one exists; bit 3 identifies both local symbol classes.
%IF AggregateCallSlices
; Contract: out A,carry,zero,HL clobbers sign,parity,halfCarry,B,C,D,DE
SBPREPRW:
            CALL SBFIND
            JR   NC,SBPREPRD
            INC  HL
            INC  HL
            INC  HL
            BIT  3,(HL)
            JP   NZ,TYDUNMER
SBPREPRD:
            LD   A,(DCINFO)
            LD   D,A
            LD   BC,(DCPAY)
            JP   SBAPPEND
%ENDIF
; Contract: in D,BC out A,carry,zero,HL clobbers sign,parity,halfCarry,B,C,D,DE
SBAPPEND:
            LD   A,(SYCNT)
            CP   SYCAP
            JR   NC,SBPREPFL
            PUSH BC
            LD   C,A
            LD   B,0
            LD   H,0
            LD   L,C
            ADD  HL,HL
            ADD  HL,HL
            ADD  HL,BC
            ADD  HL,BC
            ADD  HL,BC
            LD   BC,SYTABBAS
            ADD  HL,BC
            CALL TKRETAIN
            INC  HL
            LD   (HL),D
            INC  HL
            POP  BC
            LD   (HL),C
            INC  HL
            LD   (HL),B
            OR   A
            RET
SBPREPFL:
            LD   A,DGSYMCAP
            JR   DGSET

; Retain A as the exact type ordinal in the prepared symbol entry. HL points
; at the high byte of its payload until the symbol is committed.
; Contract: in A,BC,HL out A,BC,carry,zero clobbers sign,parity,halfCarry,HL
SBCOMTY:
            INC  HL
            LD   (HL),A
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,HL
SBCOMMIT:
            LD   HL,SYCNT
            INC  (HL)
            XOR  A
            RET

; Return the current name's class/type in A and word payload in BC.
; Contract: out A,BC,carry,zero clobbers sign,parity,halfCarry,D,DE,HL
SBLOOKUP:
            CALL SBFIND
            JR   NC,SBLOOKNO
            INC  HL
            INC  HL
            INC  HL
            LD   A,(HL)
            INC  HL
            LD   C,(HL)
            INC  HL
            LD   B,(HL)
            OR   A
            RET
SBLOOKNO:
            LD   A,DGUNKNAM
