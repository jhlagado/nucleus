; Runtime-vector provider embedded at the front of a generated CP/M COM file.
; CP/M starts at $0100. The prefix calls the separately compiled Nucleus image
; at $0800, and terminal vector entries return through that call to the CCP.

PGTARGET   EQU $0800
PGBDOS     EQU $0005
PGFNIN     EQU 1
PGFNOUT    EQU 2
PGFNDMA    EQU 26
PGFNOPEN   EQU 15
PGFNCLOS   EQU 16
PGFNMAKE   EQU 22
PGFNRD     EQU 33
PGFNWR     EQU 34
PGINRDY    EQU 1
PGOUTRDY   EQU 2
PGCACHE    EQU $0080
PGCACHEN   EQU $0100

            ORG $0100
PGPREFIX:
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
PGENTRY:
            CALL PGINIT
            CALL PGTARGET
PGRETURN:
            RET

            ; Fixed addresses let the offline runtime catalogue bind ordinary
            ; vectors and the packet gateway without runtime linking.
            ORG $0107
PGVECTOR:
            JP   PGREADIN
            JP   PGWROUT
            JP   PGRDSTOR
            JP   PGREWIND
            JP   PGWRSTOR
            JP   PGSEEK
            JP   PGSUCC
            JP   PGFAIL
            JP   PGTRAP
            JP   PGFARCL
            JP   PGFARJP
PGPACKV:
            JP   PGPACKET
PGVECEND:

PGCODE:
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
PGINIT:
            XOR  A
            LD   HL,PGINCUR
            LD   DE,PGINCUR+1
            LD   BC,PGCLRLEN
            LD   (HL),A
            LDIR
            LD   HL,$005C
            LD   DE,PGINFCB
            CALL PGCPYFCB
            LD   HL,$006C
            LD   DE,PGOUTFCB
            CALL PGCPYFCB
            CALL PGOPENIN
            CALL PGOPENOT
            XOR  A
            RET

; Standard CP/M console input blocks, echoes, and performs the operating
; system's ordinary control processing. The portable profile is seven-bit.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry
PGREADIN:
            PUSH BC
            PUSH DE
            PUSH HL
            LD   C,PGFNIN
            CALL PGCALLBD
            POP  HL
            POP  DE
            POP  BC
            AND  $7F
            RET

; Contract: in A out A,carry,zero clobbers sign,parity,halfCarry
PGWROUT:
            PUSH BC
            PUSH DE
            PUSH HL
            LD   E,A
            LD   C,PGFNOUT
            CALL PGCALLBD
            POP  HL
            POP  DE
            POP  BC
            XOR  A
            RET

; CP/M standardizes only the 8080 register set. Preserve every Z80 register
; promised by the generated-program service vector around public BDOS calls.
; Contract: in C,DE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
PGCALLBD:
            PUSH IX
            PUSH IY
            CALL PGBDOS
            POP  IY
            POP  IX
            RET

; CP/M does not retain a byte count for the final 128-byte record. Each selected
; Nucleus storage file therefore begins with a private little-endian u16 payload
; length. Logical offset zero follows that header. One random-record cache is
; shared because service calls are synchronous.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry
PGRDSTOR:
            PUSH BC
            PUSH DE
            PUSH HL
            PUSH IX
            CALL PGRDBODY
            POP  IX
            POP  HL
            POP  DE
            POP  BC
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX
PGRDBODY:
            LD   A,(PGSTATE)
            AND  PGINRDY
            JR   Z,PGRDFAIL
            LD   HL,(PGINCUR)
            LD   DE,(PGINLEN)
            OR   A
            SBC  HL,DE
            JR   Z,PGRDEOF
            JR   NC,PGRDFAIL
            LD   HL,(PGINCUR)
            LD   IX,PGINFCB
            CALL PGRDLOG
            OR   A
            JP   NZ,PGIOFAIL
            LD   A,(HL)
            LD   HL,(PGINCUR)
            INC  HL
            LD   (PGINCUR),HL
            OR   A
            RET
PGRDEOF:
            LD   A,1
            SCF
            RET
PGRDFAIL:
            JP   PGIOFAIL

; Contract: out A,carry,zero clobbers sign,parity,halfCarry
PGREWIND:
            LD   A,(PGSTATE)
            AND  PGINRDY
            JR   Z,PGREWERR
            XOR  A
            LD   (PGINCUR),A
            LD   (PGINCUR+1),A
            RET
PGREWERR:
            JP   PGIOFAIL

; Contract: in A out A,carry,zero clobbers sign,parity,halfCarry
PGWRSTOR:
            LD   (PGWRVAL),A
            PUSH BC
            PUSH DE
            PUSH HL
            PUSH IX
            CALL PGWRBODY
            POP  IX
            POP  HL
            POP  DE
            POP  BC
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX
PGWRBODY:
            LD   A,(PGSTATE)
            AND  PGOUTRDY
            JR   Z,PGWRFAIL
            XOR  A
            LD   (PGAPPEND),A
            LD   HL,(PGOUTCUR)
            LD   DE,(PGOUTLEN)
            OR   A
            SBC  HL,DE
            JR   C,PGWRREC
            JR   NZ,PGWRFAIL
            LD   A,D
            AND  E
            INC  A
            JR   Z,PGWRFAIL
            LD   A,1
            LD   (PGAPPEND),A
PGWRREC:
            LD   HL,(PGOUTCUR)
            LD   IX,PGOUTFCB
            CALL PGRDLOG
            OR   A
            JR   Z,PGWRHAVE
            LD   B,A
            LD   A,(PGAPPEND)
            OR   A
            JR   Z,PGWRFAIL
            LD   A,B
            CP   1
            JR   Z,PGWRNEW
            CP   4
            JR   NZ,PGWRFAIL
PGWRNEW:
            CALL PGCLRCCH
            LD   HL,(PGOUTCUR)
            LD   IX,PGOUTFCB
            CALL PGPRELOG
PGWRHAVE:
            LD   A,(PGWRVAL)
            LD   (HL),A
            LD   IX,PGOUTFCB
            CALL PGWRCUR
            JR   C,PGWRFAIL
            LD   A,(PGAPPEND)
            OR   A
            JR   Z,PGWRADV
            LD   HL,(PGOUTLEN)
            INC  HL
            CALL PGSTOREH
            JR   C,PGWRFAIL
            LD   (PGOUTLEN),HL
PGWRADV:
            LD   HL,(PGOUTCUR)
            INC  HL
            LD   (PGOUTCUR),HL
            XOR  A
            RET
PGWRFAIL:
            JR   PGIOFAIL

; Contract: in HL out A,carry,zero clobbers sign,parity,halfCarry
PGSEEK:
            PUSH BC
            PUSH DE
            PUSH HL
            CALL PGSEEKB
            POP  HL
            POP  DE
            POP  BC
            RET

; Contract: in HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
PGSEEKB:
            LD   A,(PGSTATE)
            AND  PGOUTRDY
            JR   Z,PGSEEKER
            EX   DE,HL
            LD   HL,(PGOUTLEN)
            OR   A
            SBC  HL,DE
            JR   C,PGSEEKER
            LD   (PGOUTCUR),DE
            XOR  A
            RET
PGSEEKER:
; Contract: out A,carry,zero clobbers sign,parity,halfCarry
PGIOFAIL:
            LD   A,4
            SCF
            RET

; Copy a twelve-byte default FCB name and clear its mutable twenty-four-byte
; tail. The CCP's two default names overlap in page zero, so both copies happen
; before either private FCB is opened.
; Contract: in DE,HL out A clobbers sign,parity,halfCarry,BC,DE,HL,carry,zero
PGCPYFCB:
            LD   BC,12
            LDIR
            XOR  A
            LD   B,24
; Contract: in A,B,DE out B,DE
PGCLRFCB:
            LD   (DE),A
            INC  DE
            DJNZ PGCLRFCB
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
PGOPENIN:
            LD   A,(PGINFCB+1)
            CP   ' '
            RET  Z
            LD   DE,PGINFCB
            LD   C,PGFNOPEN
            CALL PGCALLBD
            INC  A
            RET  Z
            LD   IX,PGINFCB
            CALL PGLOADHD
            RET  C
            LD   (PGINLEN),HL
            LD   A,(PGSTATE)
            OR   PGINRDY
            LD   (PGSTATE),A
            XOR  A
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
PGOPENOT:
            LD   A,(PGOUTFCB+1)
            CP   ' '
            RET  Z
            LD   A,(PGSTATE)
            AND  PGINRDY
            JR   Z,PGOPENFL
            LD   HL,PGINFCB
            LD   DE,PGOUTFCB
            LD   B,12
PGCMPNAM:
            LD   A,(DE)
            CP   (HL)
            JR   NZ,PGOPENFL
            INC  DE
            INC  HL
            DJNZ PGCMPNAM
            RET
PGOPENFL:
            LD   DE,PGOUTFCB
            LD   C,PGFNOPEN
            CALL PGCALLBD
            INC  A
            JR   Z,PGCREATE
            LD   IX,PGOUTFCB
            CALL PGLOADHD
            RET  C
            JR   PGREADY
PGCREATE:
            XOR  A
            LD   B,24
            LD   DE,PGOUTFCB+12
            CALL PGCLRFCB
            LD   DE,PGOUTFCB
            LD   C,PGFNMAKE
            CALL PGCALLBD
            INC  A
            RET  Z
            CALL PGCLRCCH
            LD   IX,PGOUTFCB
            CALL PGRECZER
            CALL PGWRCUR
            RET  C
            LD   HL,0
PGREADY:
            LD   (PGOUTLEN),HL
            LD   (PGOUTCUR),HL
            LD   A,(PGSTATE)
            OR   PGOUTRDY
            LD   (PGSTATE),A
            XOR  A
            RET

; Contract: in IX out A,HL,carry,zero clobbers sign,parity,halfCarry,BC,DE
PGLOADHD:
            CALL PGRECZER
            CALL PGRDCUR
            RET  C
            LD   HL,(PGCACHE)
            XOR  A
            RET

; Contract: in IX,HL out A,HL,carry,zero clobbers sign,parity,halfCarry,BC,DE
PGRDLOG:
            CALL PGPRELOG
            PUSH HL
            CALL PGRDRAW
            POP  HL
            OR   A
            RET

; Map one logical payload offset through the two-byte length header. The random
; record field is 24-bit, so logical $FFFE correctly maps to physical $10000,
; record 512, byte zero instead of wrapping in a 16-bit calculation.
; Contract: in IX,HL out HL clobbers A,BC,DE,carry,zero,sign,parity,halfCarry
PGPRELOG:
            LD   DE,2
            ADD  HL,DE
            LD   A,0
            ADC  A,A
            ADD  A,A
            LD   (IX+34),A
            XOR  A
            LD   (IX+35),A
            LD   A,L
            AND  $7F
            LD   B,A
            LD   A,L
            RLCA
            AND  1
            LD   E,A
            LD   A,H
            ADD  A,A
            OR   E
            LD   (IX+33),A
            LD   HL,PGCACHE
            LD   C,B
            LD   B,0
            ADD  HL,BC
            RET

; Contract: in IX out A clobbers carry,zero,sign,parity,halfCarry
PGRECZER:
            XOR  A
            LD   (IX+33),A
            LD   (IX+34),A
            LD   (IX+35),A
            RET

; Contract: in IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
PGRDCUR:
            CALL PGRDRAW
            OR   A
            RET  Z
            JP   PGIOFAIL

; Contract: in IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
PGRDRAW:
            CALL PGSETDMA
            PUSH IX
            POP  DE
            LD   C,PGFNRD
            CALL PGCALLBD
            OR   A
            RET

; Contract: in IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
PGWRCUR:
            CALL PGSETDMA
            PUSH IX
            POP  DE
            LD   C,PGFNWR
            CALL PGCALLBD
            OR   A
            RET  Z
            JP   PGIOFAIL

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
PGSETDMA:
            LD   DE,PGCACHE
            LD   C,PGFNDMA
            JP   PGCALLBD

; Contract: in HL out A,HL,carry,zero clobbers sign,parity,halfCarry,BC,DE,IX
PGSTOREH:
            PUSH HL
            LD   IX,PGOUTFCB
            CALL PGRECZER
            CALL PGRDCUR
            POP  HL
            RET  C
            LD   (PGCACHE),HL
            PUSH HL
            CALL PGWRCUR
            POP  HL
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
PGCLRCCH:
            LD   HL,PGCACHE
            LD   DE,PGCACHE+1
            LD   BC,127
            LD   (HL),0
            LDIR
            XOR  A
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
PGCLOSE:
            LD   A,(PGSTATE)
            AND  PGINRDY
            JR   Z,PGCLOSOT
            LD   DE,PGINFCB
            LD   C,PGFNCLOS
            CALL PGCALLBD
PGCLOSOT:
            LD   A,(PGSTATE)
            AND  PGOUTRDY
            JR   Z,PGCLOSED
            LD   DE,PGOUTFCB
            LD   C,PGFNCLOS
            CALL PGCALLBD
PGCLOSED:
            XOR  A
            LD   (PGSTATE),A
            RET

; Terminal entries are reached by JP after the runtime has restored its root
; stack. RET therefore resumes CpmProgramEntry and then the CCP.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
PGSUCC:
            CALL PGCLOSE
            XOR  A
            RET
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
PGFAIL:
            LD   DE,PGFAILTX
            JR   PGTERMSG
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
PGTRAP:
            LD   DE,PGTRAPTX
PGTERMSG:
            CALL PGCLOSE
            LD   C,9
            CALL PGCALLBD
            XOR  A
            RET

; Flat CP/M images never require bank control. Reaching either entry is a
; provider fault; return the packet-service trap code so execution cannot
; silently continue with an invented transfer.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry
PGFARCL:
PGFARJP:
PGPACKET:
            LD   A,7
            SCF
            RET
PGCODEND:

PGCONST:
PGFAILTX:
            DB 13,10,"Unhandled Nucleus failure",13,10,"$"
PGTRAPTX:
            DB 13,10,"Nucleus trap",13,10,"$"
PGCONEND:

PGWORK:
PGINFCB:
            DS  36
PGOUTFCB:
            DS  36
PGINCUR:
            DW  0
PGINLEN:
            DW  0
PGOUTCUR:
            DW  0
PGOUTLEN:
            DW  0
PGSTATE:
            DB  0
PGWRVAL:
            DB  0
PGAPPEND:
            DB  0
PGWRKEND:
PGPREND:

; Derived after both labels so the earlier load is a single-symbol fixup.
PGCLRLEN   EQU PGSTATE-PGINCUR
