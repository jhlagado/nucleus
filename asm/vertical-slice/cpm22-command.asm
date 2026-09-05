; CP/M command-tail parser and source preflight for native Nucleus. Accepted
; forms are no arguments, SOURCE, SOURCE OUTPUT, and ?.

CCTAILN     EQU $0080
CCTAIL      EQU $0081
CCINFCB     EQU $005C
CCOUTFCB    EQU $006C
CCFREAD     EQU 20
CCFOPEN     EQU 15
CCFDMA      EQU 26

CCWKBASE    EQU CSWKEND
CCDESC      EQU CCWKBASE
CCLAUNCH    EQU CCDESC+2
CCOUTNAM    EQU CCLAUNCH+9
CCOUTFMT    EQU CCOUTNAM+12
CCHELP      EQU CCOUTFMT+1
CCWKEND     EQU CCHELP+1

CCFMTCOM    EQU 0
CCFMTBIN    EQU 1
CCFMTHEX    EQU 2

CCCODE:
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CCPREP:
            XOR  A
            LD   (CCHELP),A
            LD   HL,CCDEFIN
            CALL CCCPPAIR
            LD   A,1
            LD   (CSPARTN),A
            LD   A,(CCTAILN)
            LD   B,A
            LD   HL,CCTAIL
            CALL CCSKIPSP
            JR   Z,CCNAMSOK
            CP   '?'
            JR   NZ,CCFIRST
            INC  HL
            DEC  B
            CALL CCSKIPSP
            JR   NZ,CCBADPRE
            LD   A,1
            LD   (CCHELP),A
            XOR  A
            RET
CCFIRST:
            CALL CCPARSE
            JR   C,CCBADPRE
            CALL CCSKIPSP
            JR   Z,CCCPSING
            CALL CCPARSE
            JR   C,CCBADPRE
            CALL CCSKIPSP
            JR   NZ,CCBADPRE
CCCPNAMS:
            LD   HL,CCINFCB
            LD   A,4
            CALL CCCPPAIR
            JR   CCNAMSOK
CCCPSING:
            LD   HL,CCINFCB
            LD   DE,CSDESCS
            LD   BC,12
            LDIR
            LD   HL,CSDESCS+9
            LD   A,(HL)
            CP   ' '
            JR   NZ,CCEXTOK
            LD   (HL),'N'
            INC  HL
            LD   (HL),'U'
CCEXTOK:
            LD   HL,CSDESCS
            LD   DE,CCOUTNAM
            LD   BC,12
            LDIR
            LD   HL,CCOUTNAM+9
            LD   (HL),'C'
            INC  HL
            LD   (HL),'O'
            INC  HL
            LD   (HL),'M'
CCNAMSOK:
            CALL CCSELFMT
            JR   C,CCBADPRE
            LD   HL,CSDESCS
            LD   DE,CCOUTNAM
            CALL CCNAMEEQ
            JP   Z,CCCONFL
            LD   HL,CSDESCS
            CALL CCSCAN
            RET  C
            XOR  A
            RET
CCBADPRE:
            JP   CCINVAL

; Select the materialized delivery format from the explicit output suffix.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
CCSELFMT:
            LD   DE,CCEXTS
            LD   B,3
            XOR  A
CCFMTLP:
            PUSH AF
            PUSH BC
            PUSH DE
            LD   HL,CCOUTNAM+9
            LD   B,3
CCTYPELP:
            LD   A,(DE)
            CP   (HL)
            JR   NZ,CCTYPDIF
            INC  DE
            INC  HL
            DJNZ CCTYPELP
            POP  DE
            POP  BC
            POP  AF
            LD   (CCOUTFMT),A
            OR   A
            RET
CCTYPDIF:
            POP  DE
            LD   HL,3
            ADD  HL,DE
            EX   DE,HL
            POP  BC
            POP  AF
            INC  A
            DJNZ CCFMTLP
            SCF
            RET

; Read one selected source sequentially to establish its exact logical length.
; Text EOF terminates a part; byte 65,536 fails before descriptor publication.
; Contract: in HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CCSCAN:
            LD   DE,CSSTRFCB
            CALL FCBMAKE
            LD   (CCDESC),HL
            LD   DE,CSSTRFCB
            LD   C,CCFOPEN
            CALL BDOSCALL
            INC  A
            JR   Z,CCNOFILE
            LD   DE,SRCCHUNK
            LD   C,CCFDMA
            CALL BDOSCALL
            LD   HL,0
CCSRCREC:
            PUSH HL
            LD   DE,CSSTRFCB
            LD   C,CCFREAD
            CALL BDOSCALL
            POP  HL
            OR   A
            JR   Z,CCSRCSCN
            DEC  A
            JR   NZ,CCIOERR
            JR   CCSRCEND
CCSRCSCN:
            LD   B,128
            LD   DE,SRCCHUNK
CCSRCBYT:
            LD   A,(DE)
            CP   $1A
            JR   Z,CCSRCEND
            INC  DE
            INC  HL
            LD   A,H
            OR   L
            JR   Z,CCCAPERR
            DJNZ CCSRCBYT
            JR   CCSRCREC
CCSRCEND:
            EX   DE,HL
            LD   HL,(CCDESC)
            LD   (HL),E
            INC  HL
            LD   (HL),D
            XOR  A
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry
CCNOFILE:
            LD   A,NSTATNF
            SCF
            RET
; Contract: out A,carry,zero clobbers sign,parity,halfCarry
CCCAPERR:
            LD   A,NSTATCAP
            SCF
            RET
; Contract: out A,carry,zero clobbers sign,parity,halfCarry
CCIOERR:
            LD   A,NSTATIO
            SCF
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry
CCINVAL:
            LD   A,NSTATINV
            SCF
            RET
; Contract: out A,carry,zero clobbers sign,parity,halfCarry
CCCONFL:
            LD   A,NSTATCF
            SCF
            RET

; Raw command-tail helpers validate exact arity and current-drive 8.3 syntax.
; Contract: in B,HL out A,B,HL,zero clobbers carry,sign,parity,halfCarry
CCSKIPSP:
            LD   A,B
            OR   A
            RET  Z
            LD   A,(HL)
            CP   ' '
            RET  NZ
            INC  HL
            DEC  B
            JR   CCSKIPSP

; Contract: in B,HL out A,B,HL,carry clobbers zero,sign,parity,halfCarry,C,D
CCPARSE:
            LD   D,8
            LD   C,0
CCFNBYTE:
            LD   A,B
            OR   A
            JR   Z,CCFNDONE
            LD   A,(HL)
            CP   ' '
            JR   Z,CCFNDONE
            CP   '.'
            JR   NZ,CCFNDATA
            LD   A,D
            CP   8
            JR   NZ,CCFNBAD
            LD   A,C
            OR   A
            JR   Z,CCFNBAD
            LD   D,3
            LD   C,0
            JR   CCFNTAKE
CCFNDATA:
            CALL CCFNCHAR
            RET  C
            INC  C
            LD   A,D
            CP   C
            JR   C,CCFNBAD
CCFNTAKE:
            INC  HL
            DEC  B
            JR   CCFNBYTE
CCFNDONE:
            LD   A,C
            OR   A
            JR   Z,CCFNBAD
            RET
CCFNBAD:
            SCF
            RET

; Contract: in A out A,carry clobbers zero,sign,parity,halfCarry
CCFNCHAR:
            CP   '!'
            RET  C
            CP   $7F
            JR   NC,CCFNERR
            CP   '*'
            JR   C,CCFNHI
            CP   '-'
            JR   C,CCFNERR
            CP   '/'
            JR   Z,CCFNERR
            CP   ':'
            JR   C,CCFNHI
            CP   '@'
            JR   C,CCFNERR
CCFNHI:
            CP   '['
            JR   C,CCFNOK
            CP   '^'
            JR   C,CCFNERR
            CP   '_'
            JR   Z,CCFNERR
CCFNOK:
            OR   A
            RET
CCFNERR:
            SCF
            RET

; Contract: in DE,HL out A,zero clobbers carry,sign,parity,halfCarry,B,DE,HL
CCNAMEEQ:
            LD   B,12
CCNAMEBY:
            LD   A,(DE)
            CP   (HL)
            RET  NZ
            INC  DE
            INC  HL
            DJNZ CCNAMEBY
            XOR  A
            RET

; Copy two twelve-byte FCB name fields separated by A bytes in the source.
; Contract: in A,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CCCPPAIR:
            LD   DE,CSDESCS
            LD   BC,12
            LDIR
            LD   C,A
            ADD  HL,BC
            LD   DE,CCOUTNAM
            LD   BC,12
            LDIR
            RET

CCCODEND:

CCCONST:
CCDEFIN:  DB 0,"INPUT   ","NU "
CCDEFOUT: DB 0,"OUTPUT  ","COM"
CCEXTS: DB "COM","BIN","HEX"
CCCONEND:
