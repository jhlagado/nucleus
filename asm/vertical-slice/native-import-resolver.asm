; Native Nucleus import resolver. This is a standalone host tool, not part of
; the 16 KiB compiler image. It reads preserved //% import headers through the
; common named-object service and commits an SP1 plan for the source streamer.
;
; Entry contract:
;   HL = normalized or normalizable entry-object name
;   B  = name length, 1..255
; Result:
;   carry clear, A = 0 after committing .nucleus/source-plan.sp1
;   carry set, A = canonical system status after aborting tentative output

IRPARTCP    EQU 8

IRPARTPT    EQU $5C40 ; eight little-endian pointers
IRPARTLN    EQU $5C50 ; eight bytes
IRPARTST    EQU $5C58 ; 0=new, 1=visiting, 2=done
IRPARTN     EQU $5C60
IRCURPRT    EQU $5C61
IRHDRACT    EQU $5C62
IRPLANH     EQU $5C63
IRSRCH      EQU $5C65
IRSRCOFF    EQU $5C67
IRRDCUR     EQU $5C69
IRRDEND     EQU $5C6B
IRCANDN     EQU $5C6D
IRRAWLEN    EQU $5C6E
IRSVSTAT    EQU $5C6F
IRBUILDL    EQU $5C70
IRNORMEN    EQU $5C72
IRFLOOR     EQU $5C74
IRDECBUF    EQU $5C76
IRPOOLEN    EQU $5C79
IRNAMEPT    EQU $5C7B
IRCOMPST    EQU $5C7D
IRCOMPLN    EQU $5C7F
IRCHILD     EQU $5C80
IRRESDEP    EQU $5C81
IRRESPRT    EQU $5C82
IRRESOFF    EQU $5C8A
IRRESHDR    EQU $5C9A
IRWKEND     EQU $5CA2

IRPOOL      EQU $6000
IRPOOLLM    EQU $6800
IRRDBUF     EQU $6800
IRRDLIM     EQU $6900
IRCAND      EQU $6900
IRCANDLM    EQU $6A00
IRRAW       EQU $6A00
IRRAWLIM    EQU $6B00
IRBUILD     EQU $6B00
IRBUILDM    EQU $6D00

IRSTNEW     EQU 0
IRSTBUSY    EQU 1
IRSTDONE    EQU 2

IRPLNAME:
            DB ".nucleus/source-plan.sp1"
IRPLNAML    EQU $-IRPLNAME
IRPLHEAD:
            DB "SP1 0",10
IRPLHDLN    EQU $-IRPLHEAD
IRPLEND:
            DB "END",10
IRPLENDL    EQU $-IRPLEND
IRSTDPFX:
            DB "@nucleus/"
IRSTDPXL    EQU $-IRSTDPFX

; Contract: in HL,B out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
IRRESOLV:
            PUSH HL
            PUSH BC
            CALL IRRESET
            POP  BC
            POP  HL
            LD   A,B
            OR   A
            JP   Z,IRINVAL
            LD   (IRCOMPLN),A
            LD   DE,IRBUILD
            LD   C,B
            LD   B,0
            LDIR
            LD   A,(IRCOMPLN)
            LD   L,A
            LD   H,0
            LD   (IRBUILDL),HL
            CALL IRNORM
            JP   C,IRRESERR
            CALL IRFINDAD
            JP   C,IRRESERR
            LD   (IRCURPRT),A
            LD   HL,IRPLNAME
            LD   B,IRPLNAML
            LD   A,NOBEGIN
            CALL SPOPEN
            JP   C,IRRESERR
            LD   (IRPLANH),HL
            LD   DE,IRPLHEAD
            LD   BC,IRPLHDLN
            CALL IRWRPLAN
            JP   C,IRRESERR
            LD   A,(IRCURPRT)
            CALL IRVISIT
            JP   C,IRRESERR
            LD   DE,IRPLEND
            LD   BC,IRPLENDL
            CALL IRWRPLAN
            JP   C,IRRESERR
            LD   HL,(IRPLANH)
            LD   DE,4
            CALL SPSEEK
            JP   C,IRRESERR
            LD   A,(IRPARTN)
            ADD  A,'0'
            LD   (IRDECBUF),A
            LD   DE,IRDECBUF
            LD   BC,1
            CALL IRWRPLAN
            JP   C,IRRESERR
            LD   HL,(IRPLANH)
            LD   A,NOCOMMIT
            CALL SPTERM
            JP   C,IRRESERR
            XOR  A
            LD   (IRPLANH),A
            LD   (IRPLANH+1),A
            RET
IRRESERR:
            LD   (IRSVSTAT),A
            CALL IRCLOSE
            LD   HL,(IRPLANH)
            LD   A,H
            OR   L
            JR   Z,IRFAILED
            LD   A,NOABORT
            CALL SPTERM
            XOR  A
            LD   (IRPLANH),A
            LD   (IRPLANH+1),A
IRFAILED:
            LD   A,(IRSVSTAT)
            SCF
            RET

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
IRRESET:
            LD   HL,IRPARTPT
            LD   DE,IRPARTPT+1
            LD   BC,IRWKEND-IRPARTPT-1
            XOR  A
            LD   (HL),A
            LDIR
            LD   HL,IRPOOL
            LD   (IRPOOLEN),HL
            LD   HL,IRRDBUF
            LD   (IRRDCUR),HL
            LD   (IRRDEND),HL
            RET

; Write BC exact bytes at DE to the tentative SP1 object.
; Contract: in DE,BC out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
IRWRPLAN:
            LD   HL,(IRPLANH)
            JP   SPWRITE

; Return part A's name in HL/B.
; Contract: in A out A,B,DE,HL,carry,zero clobbers sign,parity,halfCarry
IRPRTNAM:
            LD   E,A
            LD   D,0
            LD   HL,IRPARTLN
            ADD  HL,DE
            LD   B,(HL)
            LD   HL,IRPARTPT
            ADD  HL,DE
            ADD  HL,DE
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            EX   DE,HL
            RET

; Return a pointer to part A's visit-state byte in HL.
; Contract: in A out A,DE,HL,carry,zero clobbers sign,parity,halfCarry
IRPRTSTA:
            LD   E,A
            LD   D,0
            LD   HL,IRPARTST
            ADD  HL,DE
            RET

; Find Candidate[CandidateLength], or append it to the bounded name pool.
; Return its part ordinal in A.
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
IRFINDAD:
            LD   A,(IRPARTN)
            LD   C,A
            XOR  A
IRFINDLP:
            CP   C
            JR   Z,IRAPPEND
            PUSH AF
            CALL IRPRTNAM
            LD   A,(IRCANDN)
            CP   B
            JR   NZ,IRCANDNE
            LD   DE,IRCAND
IRCANDCP:
            LD   A,(DE)
            CP   (HL)
            JR   NZ,IRCANDNE
            INC  DE
            INC  HL
            DEC  B
            JR   NZ,IRCANDCP
            POP  AF
            OR   A
            RET
IRCANDNE:
            POP  AF
            INC  A
            JR   IRFINDLP

IRAPPEND:
            CP   IRPARTCP
            JP   NC,IRCAPERR
            PUSH AF
            LD   A,(IRCANDN)
            LD   C,A
            LD   B,0
            LD   HL,(IRPOOLEN)
            PUSH HL
            ADD  HL,BC
            JR   C,IRAPPOVR
            LD   DE,IRPOOLLM
            OR   A
            SBC  HL,DE
            JR   C,IRAPPROM
            JR   Z,IRAPPROM
IRAPPOVR:
            POP  HL
            POP  AF
            JP   IRCAPERR
IRAPPROM:
            ADD  HL,DE
            LD   (IRPOOLEN),HL
            POP  DE
            POP  AF
            PUSH AF
            PUSH DE
            LD   L,A
            LD   H,0
            ADD  HL,HL
            LD   BC,IRPARTPT
            ADD  HL,BC
            LD   (HL),E
            INC  HL
            LD   (HL),D
            POP  DE
            LD   HL,IRCAND
            LD   A,(IRCANDN)
            LD   C,A
            LD   B,0
            PUSH BC
            LDIR
            POP  BC
            POP  AF
            PUSH AF
            LD   E,A
            LD   D,0
            LD   HL,IRPARTLN
            ADD  HL,DE
            LD   (HL),C
            LD   HL,IRPARTST
            ADD  HL,DE
            LD   (HL),IRSTNEW
            LD   HL,IRPARTN
            INC  (HL)
            POP  AF
            OR   A
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry
IRCAPERR:
            LD   A,NSTATCAP
            SCF
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry
IRINVAL:
            LD   A,NSTATINV
            SCF
            RET

; Open part A for sequential scanning and reset the byte-refill state.
; Contract: in A out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
IROPEN:
            CALL IRPRTNAM
            LD   A,NOOPEN
            CALL SPOPEN
            RET  C
            LD   (IRSRCH),HL
            XOR  A
            LD   (IRSRCOFF),A
            LD   (IRSRCOFF+1),A
IRRDRSET:
            LD   HL,IRRDBUF
            LD   (IRRDCUR),HL
            LD   (IRRDEND),HL
            RET

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
IRCLOSE:
            LD   HL,(IRSRCH)
            LD   A,H
            OR   L
            RET  Z
            LD   A,NOCLOSE
            CALL SPTERM
            RET  C
            XOR  A
            LD   (IRSRCH),A
            LD   (IRSRCH+1),A
            RET

; Return one source byte in A. Carry reports storage failure; Z reports EOF.
; A returned byte always has Z clear, including a zero byte. Parser
; accumulators remain live across a refill.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry
IRRDBYTE:
            PUSH BC
            PUSH DE
            PUSH HL
            CALL IRRDBODY
            POP  HL
            POP  DE
            POP  BC
            RET
; Contract: out A,B,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
IRRDBODY:
            LD   HL,(IRRDCUR)
            LD   DE,(IRRDEND)
            OR   A
            SBC  HL,DE
            JR   Z,IRREFILL
            ADD  HL,DE
IRRDBUFD:
            LD   A,(HL)
            LD   (IRSVSTAT),A
            INC  HL
            LD   (IRRDCUR),HL
            LD   HL,(IRSRCOFF)
            INC  HL
            LD   (IRSRCOFF),HL
            LD   A,H
            OR   L
            JP   Z,IRCAPERR
            LD   A,(IRSVSTAT)
            LD   B,0
            DEC  B
            OR   A                       ; clear carry; zero fixed below
            LD   B,0
            DEC  B                       ; force NZ without changing A
            RET
IRREFILL:
            LD   HL,(IRSRCH)
            LD   DE,IRRDBUF
            LD   BC,IRRDLIM-IRRDBUF
            CALL SPREAD
            RET  C
            LD   A,B
            OR   C
            JR   Z,IRRDEOF
            LD   HL,IRRDBUF
            LD   (IRRDCUR),HL
            ADD  HL,BC
            LD   (IRRDEND),HL
            LD   HL,IRRDBUF
            JR   IRRDBUFD
IRRDEOF:
            XOR  A
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry
IRRDREQ:
            CALL IRRDBYTE
            RET  C
            RET  NZ
            JP   IRINVAL

; Visit part A in depth-first postorder.
; Contract: in A out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
IRVISIT:
            LD   (IRCURPRT),A
            CALL IRPRTSTA
            LD   A,(HL)
            CP   IRSTDONE
            JR   Z,IRVISDON
            CP   IRSTBUSY
            JR   Z,IRCYCLE
            LD   (HL),IRSTBUSY
            LD   A,(IRCURPRT)
            CALL IROPEN
            RET  C
            LD   A,1
            LD   (IRHDRACT),A
            CALL IRSCAN
            JR   C,IRVISERR
            CALL IRCLOSE
            RET  C
            LD   A,(IRCURPRT)
            CALL IRPRTSTA
            LD   (HL),IRSTDONE
            LD   A,(IRCURPRT)
            CALL IREMITPR
            RET
IRVISDON:
            OR   A
            RET
IRCYCLE:
            JP   IRINVAL
IRVISERR:
            LD   (IRSVSTAT),A
            CALL IRCLOSE
            LD   A,(IRSVSTAT)
            SCF
            RET

; Scan leading headers and reject every later //% line.
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
IRSCAN:
IRSCANLN:
            CALL IRRDBYTE
            RET  C
            RET  Z
IRLEADSP:
            CP   ' '
            JR   Z,IRMORESP
            CP   9
            JR   Z,IRMORESP
            CP   10
            JR   Z,IRSCANLN
            CP   13
            JR   Z,IRBLNKCR
            CP   '/'
            JR   NZ,IRSRCLIN
            CALL IRRDBYTE
            RET  C
            RET  Z
            CP   '/'
            JR   NZ,IRSRCLIN
            CALL IRRDBYTE
            RET  C
            RET  Z
            CP   '%'
            JR   Z,IRSCNDIR
            CALL IRSKIPLN
            RET  C
            JR   IRSCANLN
IRMORESP:
            CALL IRRDBYTE
            RET  C
            RET  Z
            JR   IRLEADSP
IRBLNKCR:
            CALL IRRDREQ
            RET  C
            CP   10
            JP   NZ,IRINVAL
            JR   IRSCANLN
IRSRCLIN:
            XOR  A
            LD   (IRHDRACT),A
            CALL IRSKIPLN
            RET  C
            JR   IRSCANLN
IRSCNDIR:
            LD   A,(IRHDRACT)
            OR   A
            JP   Z,IRINVAL
            CALL IRPARSED
            RET  C
            JR   IRSCANLN

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
IRSKIPLN:
            CALL IRRDBYTE
            RET  C
            RET  Z
            CP   10
            RET  Z
            JR   IRSKIPLN

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
IRPARSED:
            CALL IRRDREQ
            RET  C
            CP   ' '
            JR   Z,IRDIRSP
            CP   9
            JP   NZ,IRINVAL
IRDIRSP:
            CALL IRRDREQ
            RET  C
            CP   ' '
            JR   Z,IRDIRSP
            CP   9
            JR   Z,IRDIRSP
            CP   'i'
            JP   NZ,IRINVAL
            CALL IRRDREQ
            RET  C
            CP   'm'
            JP   NZ,IRINVAL
            CALL IRRDREQ
            RET  C
            CP   'p'
            JP   NZ,IRINVAL
            CALL IRRDREQ
            RET  C
            CP   'o'
            JP   NZ,IRINVAL
            CALL IRRDREQ
            RET  C
            CP   'r'
            JP   NZ,IRINVAL
            CALL IRRDREQ
            RET  C
            CP   't'
            JP   NZ,IRINVAL
            CALL IRRDREQ
            RET  C
            CP   ' '
            JR   Z,IRKEYSP
            CP   9
            JP   NZ,IRINVAL
IRKEYSP:
            CALL IRRDREQ
            RET  C
            CP   ' '
            JR   Z,IRKEYSP
            CP   9
            JR   Z,IRKEYSP
            CP   '"'
            JP   NZ,IRINVAL
            LD   DE,IRRAW
            LD   C,0
IRPATHBY:
            CALL IRRDREQ
            RET  C
            CP   '"'
            JR   Z,IRPATHOK
            CP   '/'
            JR   NZ,IRPATHRL
            LD   B,A
            LD   A,C
            OR   A
            JP   Z,IRINVAL
            LD   A,B
IRPATHRL:
            CP   $20
            JP   C,IRINVAL
            CP   $7F
            JP   NC,IRINVAL
            CP   '\\'
            JP   Z,IRINVAL
            LD   (DE),A
            INC  DE
            INC  C
            JP   Z,IRCAPERR
            JR   IRPATHBY
IRPATHOK:
            LD   A,C
            OR   A
            JP   Z,IRINVAL
            LD   A,C
            LD   (IRRAWLEN),A
IRDIRTAL:
            CALL IRRDBYTE
            RET  C
            JR   Z,IRDIROK
            CP   ' '
            JR   Z,IRDIRTAL
            CP   9
            JR   Z,IRDIRTAL
            CP   10
            JR   Z,IRDIROK
            CP   13
            JP   NZ,IRINVAL
            CALL IRRDREQ
            RET  C
            CP   10
            JP   NZ,IRINVAL
IRDIROK:
            JP   IRRESRAW

; Resolve RawPath relative to CurrentPart, falling back to @nucleus/RawPath.
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
IRRESRAW:
            CALL IRLOCAL
            RET  C
            CALL IRPROBE
            JR   NC,IRCANDOK
            CP   NSTATNF
            RET  NZ
            CALL IRSTD
            RET  C
            CALL IRPROBE
            RET  C
IRCANDOK:
            CALL IRFINDAD
            RET  C
            LD   (IRCHILD),A
            CALL IRSAVER
            RET  C
            CALL IRCLOSE
            JR   C,IRRAWRST
            LD   A,(IRCHILD)
            CALL IRVISIT
            JR   C,IRRAWRST
            XOR  A
            LD   (IRSVSTAT),A
IRRAWRST:
            JR   NC,IRRAWSVD
            LD   (IRSVSTAT),A
IRRAWSVD:
            CALL IRRESTR
            LD   A,(IRSVSTAT)
            OR   A
            JR   NZ,IRRAWERR
            LD   HL,(IRSRCOFF)
            LD   (IRBUILDL),HL
            LD   A,(IRCURPRT)
            CALL IROPEN
            RET  C
            LD   DE,(IRBUILDL)
            LD   (IRSRCOFF),DE
            LD   HL,(IRSRCH)
            CALL SPSEEK
            RET  C
            JP   IRRDRSET
IRRAWERR:
            LD   A,(IRSVSTAT)
            SCF
            RET

; Save and restore the parent part and source offset around one recursive
; dependency visit. The bounded arrays replace an unprovable hardware-stack
; convention and make the eight-part depth limit explicit.
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
IRSAVER:
            LD   A,(IRRESDEP)
            CP   IRPARTCP
            JP   NC,IRCAPERR
            LD   E,A
            LD   D,0
            LD   HL,IRRESPRT
            ADD  HL,DE
            LD   A,(IRCURPRT)
            LD   (HL),A
            LD   A,(IRRESDEP)
            LD   E,A
            LD   D,0
            LD   HL,IRRESHDR
            ADD  HL,DE
            LD   A,(IRHDRACT)
            LD   (HL),A
            LD   HL,IRRESOFF
            ADD  HL,DE
            ADD  HL,DE
            LD   (IRNAMEPT),HL
            LD   DE,(IRSRCOFF)
            LD   HL,(IRNAMEPT)
            LD   (HL),E
            INC  HL
            LD   (HL),D
            LD   HL,IRRESDEP
            INC  (HL)
            OR   A
            RET

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
IRRESTR:
            LD   HL,IRRESDEP
            DEC  (HL)
            LD   A,(HL)
            LD   E,A
            LD   D,0
            LD   HL,IRRESPRT
            ADD  HL,DE
            LD   A,(HL)
            LD   (IRCURPRT),A
            LD   HL,IRRESHDR
            ADD  HL,DE
            LD   A,(HL)
            LD   (IRHDRACT),A
            LD   HL,IRRESOFF
            ADD  HL,DE
            ADD  HL,DE
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            EX   DE,HL
            LD   (IRSRCOFF),HL
            RET

; Probe Candidate as a readable object without retaining the handle.
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
IRPROBE:
            LD   HL,IRCAND
            LD   A,(IRCANDN)
            LD   B,A
            LD   A,NOOPEN
            CALL SPOPEN
            RET  C
            LD   A,NOCLOSE
            JP   SPTERM

; Build dirname(CurrentPart)+RawPath in PathBuild, then normalize it.
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
IRLOCAL:
            LD   A,(IRCURPRT)
            CALL IRPRTNAM
            LD   (IRNAMEPT),HL
            LD   C,B
            LD   A,B
            OR   A
            JR   Z,IRNODIR
            LD   E,0
            XOR  A
            LD   (IRCOMPLN),A
IRFINDSL:
            LD   A,(HL)
            INC  E
            CP   '/'
            JR   NZ,IRNOTSL
            LD   A,E
            LD   (IRCOMPLN),A
IRNOTSL:
            INC  HL
            DEC  C
            JR   NZ,IRFINDSL
            LD   A,(IRCOMPLN)
            OR   A
            JR   Z,IRNODIR
            LD   C,A
            LD   B,0
            LD   HL,(IRNAMEPT)
            LD   DE,IRBUILD
            LDIR
            JR   IRAPPRAW
IRNODIR:
            LD   DE,IRBUILD
IRAPPRAW:
            LD   HL,IRRAW
            LD   A,(IRRAWLEN)
            LD   C,A
            LD   B,0
            LDIR
            LD   HL,IRBUILD
            EX   DE,HL
            OR   A
            SBC  HL,DE
            LD   (IRBUILDL),HL
            CALL IRNORM
            RET

; Build @nucleus/RawPath and normalize it inside the standard-library root.
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
IRSTD:
            LD   HL,IRSTDPFX
            LD   DE,IRBUILD
            LD   BC,IRSTDPXL
            LDIR
            LD   HL,IRRAW
            LD   A,(IRRAWLEN)
            LD   C,A
            LD   B,0
            LDIR
            LD   HL,IRBUILD
            EX   DE,HL
            OR   A
            SBC  HL,DE
            LD   (IRBUILDL),HL
            CALL IRNORM
            RET

; Normalize PathBuild into Candidate. Repeated separators and '.' collapse;
; '..' pops one component but may not escape the project or @nucleus/ root.
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
IRNORM:
            LD   HL,IRBUILD
            LD   BC,(IRBUILDL)
            LD   A,B
            OR   C
            JP   Z,IRINVAL
            ADD  HL,BC
            LD   (IRNORMEN),HL
            LD   HL,IRBUILD
            LD   A,(HL)
            CP   '/'
            JP   Z,IRINVAL
            LD   A,B
            OR   A
            JR   NZ,IRTRYSTD
            LD   A,C
            CP   IRSTDPXL
            JR   C,IRPRJFLR
IRTRYSTD:
            LD   DE,IRSTDPFX
            LD   C,IRSTDPXL
IRPFXCMP:
            LD   A,(DE)
            CP   (HL)
            JR   NZ,IRPRJFLR
            INC  DE
            INC  HL
            DEC  C
            JR   NZ,IRPFXCMP
            LD   HL,IRSTDPFX
            LD   DE,IRCAND
            LD   BC,IRSTDPXL
            LDIR
            LD   (IRFLOOR),DE
            LD   HL,IRBUILD+IRSTDPXL
            JR   IRCOMP
IRPRJFLR:
            LD   HL,IRBUILD
            LD   DE,IRCAND
            LD   (IRFLOOR),DE

IRCOMP:
            LD   BC,(IRNORMEN)
            LD   A,H
            CP   B
            JR   NZ,IRSKIPSL
            LD   A,L
            CP   C
            JP   Z,IRNORMOK
IRSKIPSL:
            LD   A,(HL)
            CP   '/'
            JR   NZ,IRCOMPBG
            INC  HL
            JP   IRCOMP
IRCOMPBG:
            LD   (IRCOMPST),HL
            LD   C,0
IRMEAS:
            LD   A,H
            LD   B,A
            LD   A,(IRNORMEN+1)
            CP   B
            JR   NZ,IRMEASBY
            LD   A,L
            LD   B,A
            LD   A,(IRNORMEN)
            CP   B
            JR   Z,IRMEASOK
IRMEASBY:
            LD   A,(HL)
            CP   '/'
            JR   Z,IRMEASOK
            INC  HL
            INC  C
            JP   Z,IRCAPERR
            JR   IRMEAS
IRMEASOK:
            LD   A,C
            LD   (IRCOMPLN),A
            LD   HL,(IRCOMPST)
            LD   A,C
            CP   1
            JR   NZ,IRDOTDOT
            LD   A,(HL)
            CP   '.'
            JR   Z,IRADVANC
IRDOTDOT:
            LD   A,C
            CP   2
            JR   NZ,IRCOPY
            LD   A,(HL)
            CP   '.'
            JR   NZ,IRCOPY
            INC  HL
            LD   A,(HL)
            DEC  HL
            CP   '.'
            JR   NZ,IRCOPY
            CALL IRPOP
            RET  C
            LD   HL,(IRCOMPST)
            JR   IRADVANC
IRCOPY:
            LD   A,C
            OR   A
            JR   Z,IRADVANC
            CALL IRADDSL
            RET  C
            LD   HL,(IRCOMPST)
            LD   A,(IRCOMPLN)
            LD   C,A
IRCOPYLP:
            LD   A,(HL)
            CP   $20
            JP   C,IRINVAL
            CP   $7F
            JP   NC,IRINVAL
            CP   '\\'
            JP   Z,IRINVAL
            LD   (DE),A
            INC  DE
            INC  HL
            LD   A,D
            CP   IRCANDLM>>8
            JR   NZ,IRCOPYOK
            LD   A,E
            CP   IRCANDLM&$FF
            JP   Z,IRCAPERR
IRCOPYOK:
            DEC  C
            JR   NZ,IRCOPYLP
            JP   IRCOMP
IRADVANC:
            LD   HL,(IRCOMPST)
            LD   A,(IRCOMPLN)
            LD   C,A
            LD   B,0
            ADD  HL,BC
            JP   IRCOMP
IRNORMOK:
            LD   HL,IRCAND
            EX   DE,HL
            OR   A
            SBC  HL,DE
            LD   A,H
            OR   A
            JP   NZ,IRCAPERR
            LD   A,L
            OR   A
            JP   Z,IRINVAL
            LD   (IRCANDN),A
            OR   A
            RET

; Add one separator unless Candidate is empty or already ends with '/'.
; Contract: in DE out A,DE,HL,carry,zero clobbers sign,parity,halfCarry
IRADDSL:
            LD   HL,IRCAND
            OR   A
            SBC  HL,DE
            RET  Z
            ADD  HL,DE
            DEC  DE
            LD   A,(DE)
            INC  DE
            CP   '/'
            RET  Z
            LD   A,D
            CP   IRCANDLM>>8
            JR   NZ,IRSLROOM
            LD   A,E
            CP   IRCANDLM&$FF
            JR   NZ,IRSLROOM
            LD   A,NSTATCAP
            SCF
            RET
IRSLROOM:
            LD   A,'/'
            LD   (DE),A
            INC  DE
            OR   A
            RET

; Pop the preceding normalized component, respecting the domain floor.
; Contract: in DE out A,DE,HL,carry,zero clobbers sign,parity,halfCarry
IRPOP:
            LD   HL,(IRFLOOR)
            OR   A
            SBC  HL,DE
            JR   NZ,IRPOPOK
            LD   A,NSTATINV
            SCF
            RET
IRPOPOK:
            ADD  HL,DE
IRPOPLP:
            DEC  DE
            LD   HL,(IRFLOOR)
            OR   A
            SBC  HL,DE
            JR   Z,IRPOPFLR
            ADD  HL,DE
            LD   A,(DE)
            CP   '/'
            JR   NZ,IRPOPLP
            RET
IRPOPFLR:
            LD   DE,(IRFLOOR)
            OR   A
            RET

; Append the completed part to SP1 in postorder: P 0 <length> <name> LF.
; Contract: in A out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
IREMITPR:
            LD   (IRCURPRT),A
            LD   A,'P'
            LD   (IRDECBUF),A
            LD   A,' '
            LD   (IRDECBUF+1),A
            LD   A,'0'
            LD   (IRDECBUF+2),A
            LD   A,' '
            LD   (IRDECBUF+3),A
            LD   DE,IRDECBUF
            LD   BC,4
            CALL IRWRPLAN
            RET  C
            LD   A,(IRCURPRT)
            CALL IRPRTNAM
            LD   A,B
            CALL IRWRDEC
            RET  C
            LD   A,' '
            LD   (IRDECBUF),A
            LD   DE,IRDECBUF
            LD   BC,1
            CALL IRWRPLAN
            RET  C
            LD   A,(IRCURPRT)
            CALL IRPRTNAM
            LD   D,H
            LD   E,L
            LD   C,B
            LD   B,0
            CALL IRWRPLAN
            RET  C
            LD   A,10
            LD   (IRDECBUF),A
            LD   DE,IRDECBUF
            LD   BC,1
            JP   IRWRPLAN

; Write unsigned A as one to three canonical decimal bytes.
; Contract: in A out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
IRWRDEC:
            LD   B,0
IRDECHUN:
            CP   100
            JR   C,IRDECTBG
            SUB  100
            INC  B
            JR   IRDECHUN
IRDECTBG:
            LD   C,0
IRDECTEN:
            CP   10
            JR   C,IRDECDIG
            SUB  10
            INC  C
            JR   IRDECTEN
IRDECDIG:
            LD   E,A
            LD   HL,IRDECBUF
            LD   D,0
            LD   A,B
            OR   A
            JR   Z,IRDECNOH
            ADD  A,'0'
            LD   (HL),A
            INC  HL
            INC  D
IRDECNOH:
            LD   A,C
            OR   B
            JR   Z,IRDECNOT
            LD   A,C
            ADD  A,'0'
            LD   (HL),A
            INC  HL
            INC  D
IRDECNOT:
            LD   A,E
            ADD  A,'0'
            LD   (HL),A
            INC  D
            LD   A,D
            LD   (IRCOMPLN),A
            LD   DE,IRDECBUF
            LD   A,(IRCOMPLN)
            LD   C,A
            LD   B,0
            JP   IRWRPLAN

IRRESEND:
