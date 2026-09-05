; Transactional CP/M publisher for the direct materializer. The completed
; target image is already patched in TPA. COM and BIN are the same flat bytes
; loaded at $0100; HEX carries those bytes with their logical addresses.

PBFDMA      EQU 26
PBFOPEN     EQU 15
PBFCLOSE    EQU 16
PBFDEL      EQU 19
PBFWRITE    EQU 21
PBFMAKE     EQU 22
PBFREN      EQU 23
PBDMA       EQU $0080
PBPFXN      EQU (DOIMG-$0100)/128

; The enclosing publisher composes this head, the HEX renderer, and its tail.
PBCODE:
; IX and IY carry publisher state, but CP/M does not standardize their return
; values. Every BDOS edge therefore saves both rather than depending on an
; accidental property of an 8080-derived implementation.
; Reserve the output-derived temporary and backup names before compilation.
; CP/M is single-tasking, so absence reserves both for this transient.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
PBPREP:
            XOR  A
            LD   (PBSTATE),A
            CALL PBSETTMP
            CALL PBCHKABS
            RET  C
            CALL PBSETBAK
            CALL PBCHKABS
            RET  C
            LD   A,1
            LD   (PBSTATE),A
            XOR  A
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
PBCHKABS:
            LD   C,PBFOPEN
            CALL PBFCBCAL
            INC  A
            JR   Z,PBABSENT
            JP   DOINVAL
PBABSENT:
            XOR  A
            RET

; HL is the exact nonzero generated-image length beginning at logical $0800.
; The COM first receives the packed provider prefix plus zero fill through
; $07FF, then the already-patched image. CP/M's final physical record is zero
; padded from the materializer's previously cleared buffer.
; Contract: in HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
PBPUBL:
            LD   A,(PBSTATE)
            OR   A
            JP   Z,DOINVAL
            PUSH HL
            POP  IY
            CALL PBSETTMP
            LD   C,PBFMAKE
            CALL PBFCBCAL
            INC  A
            JP   Z,PBROLLER
            LD   A,(CCOUTFMT)
            CP   CCFMTHEX
            JP   Z,PBHEX
PBRAW:
            LD   IX,EMBPFX
            LD   A,PBPFXN
            LD   (PBPFXCNT),A
PBPFXLP:
            CALL PBCLRDMA
            LD   HL,EMBPFXEN
            PUSH IX
            POP  DE
            OR   A
            SBC  HL,DE
            LD   A,H
            OR   L
            JR   Z,PBPFXOK
            LD   BC,128
            OR   A
            SBC  HL,BC
            JR   NC,PBPFXFUL
            ADD  HL,BC
            LD   B,H
            LD   C,L
            JR   PBPFXCPY
PBPFXFUL:
            LD   BC,128
PBPFXCPY:
            PUSH IX
            POP  HL
            LD   DE,PBDMA
            LDIR
            PUSH HL
            POP  IX
PBPFXOK:
            LD   DE,PBDMA
            CALL PBWRREC
            JP   C,PBROLLER
            LD   HL,PBPFXCNT
            DEC  (HL)
            JR   NZ,PBPFXLP

            LD   IX,DOBUF
PBIMGLP:
            PUSH IX
            POP  DE
            CALL PBWRREC
            JP   C,PBROLLER
            PUSH IY
            POP  HL
            LD   DE,128
            OR   A
            SBC  HL,DE
            JP   C,PBTMPCLO
            LD   A,H
            OR   L
            JP   Z,PBTMPCLO
            PUSH HL
            POP  IY
            ADD  IX,DE
            JR   PBIMGLP

; Render the same logical $0100 image as addressed Intel HEX records. The
; resident prefix and generated image are disjoint physical buffers, so the
; zero-filled logical gap is emitted as bounded sixteen-byte segments.
PBHEX:
            CALL HXBEGIN
            LD   HL,EMBPFX
            LD   (HXFSRC),HL
            LD   HL,PBPFXLEN
            LD   (HXFLEFT),HL
            LD   HL,$0100
            LD   (HXFADDR),HL
            CALL HXSEG
            LD   HL,PBPFXPAD
            LD   (PBHGAPN),HL
PBHGAPLP:
            LD   HL,(PBHGAPN)
            LD   A,H
            OR   L
            JR   Z,PBHIMAGE
            LD   DE,16
            OR   A
            SBC  HL,DE
            JR   C,PBHGAPLT
            LD   (PBHGAPN),HL
            LD   HL,16
            JR   PBHGAPOK
PBHGAPLT:
            ADD  HL,DE
            LD   DE,0
            LD   (PBHGAPN),DE
PBHGAPOK:
            LD   (HXFLEFT),HL
            LD   HL,PBHZERO
            LD   (HXFSRC),HL
            CALL HXSEG
            JR   PBHGAPLP
PBHIMAGE:
            LD   HL,DOBUF
            LD   (HXFSRC),HL
            PUSH IY
            POP  HL
            LD   (HXFLEFT),HL
            CALL HXSEG
            CALL HXEND
            JP   C,PBROLLER

PBTMPCLO:
            LD   C,PBFCLOSE
            CALL PBFCBCAL
            INC  A
            JR   Z,PBROLLER

            CALL PBSETBAK
            CALL PBOUTCUR
            LD   C,PBFREN
            CALL PBFCBCAL
            INC  A
            JR   Z,PBNOBACK
            LD   A,3
            LD   (PBSTATE),A
PBNOBACK:
            CALL PBSETTMP
            CALL PBCUROUT
            LD   C,PBFREN
            CALL PBFCBCAL
            INC  A
            JR   Z,PBROLLER
            CALL PBSETBAK
            LD   C,PBFDEL
            CALL PBFCBCAL
            XOR  A
            LD   (PBSTATE),A
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
PBABORT:
            JP   PBROLL

PBROLLER:
            CALL PBROLL
            JP   DOINVAL

; Contract: in DE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
PBWRREC:
            LD   C,PBFDMA
            CALL BDOSCALL
            LD   C,PBFWRITE
            CALL PBFCBCAL
            OR   A
            RET  Z
            SCF
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
PBCLRDMA:
            LD   HL,PBDMA
            LD   DE,PBDMA+1
            LD   BC,127
            LD   (HL),0
            LDIR
            XOR  A
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
PBROLL:
            LD   A,(PBSTATE)
            OR   A
            RET  Z
            CALL PBSETTMP
            LD   C,PBFCLOSE
            CALL PBFCBCAL
            LD   C,PBFDEL
            CALL PBFCBCAL
            LD   A,(PBSTATE)
            AND  2
            JR   Z,PBROLLOK
            CALL PBSETBAK
            CALL PBCUROUT
            LD   C,PBFREN
            CALL PBFCBCAL
PBROLLOK:
            XOR  A
            LD   (PBSTATE),A
            RET

; Contract: in C out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL
PBFCBCAL:
            LD   DE,PBWKFCB
            JP   BDOSCALL

; Contract: out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL
PBCOPYON:
            LD   HL,CCOUTNAM
            LD   DE,PBWKFCB
            JP   FCBMAKE

; Contract: out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL,IX,IY
PBSETTMP:
            CALL PBCOPYON
            LD   HL,$2424
            LD   A,'$'
            JR   PBSETEXT

; Contract: out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL,IX,IY
PBSETBAK:
            CALL PBCOPYON
            LD   HL,$4142
            LD   A,'K'
PBSETEXT:
            LD   (PBWKFCB+9),HL
            LD   (PBWKFCB+11),A
            RET

; The current FCB name is the new name; install the selected output as old.
; Contract: out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL,IX,IY
PBOUTCUR:
            LD   HL,PBWKFCB
            LD   DE,PBWKFCB+16
            CALL PBCPYREN
            LD   HL,CCOUTNAM
            LD   DE,PBWKFCB
            JP   PBCPYREN

; Contract: in DE,HL out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL
PBCPYREN:
            LD   BC,12
            LDIR
            RET

; The current FCB name is old; install the selected output as its new name.
; Contract: out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL,IX,IY
PBCUROUT:
            LD   HL,CCOUTNAM
            LD   DE,PBWKFCB+16
            JP   PBCPYREN

PBWKBASE    EQU DOWKEND
PBWKFCB     EQU PBWKBASE
PBPFXCNT    EQU PBWKFCB+36
PBSTATE     EQU PBPFXCNT+1
PBHDMCUR    EQU PBSTATE+1
PBHDMCNT    EQU PBHDMCUR+2
PBHERROR    EQU PBHDMCNT+1
PBHLEFT     EQU PBHERROR+1
PBHSRC      EQU PBHLEFT+2
PBHADDR     EQU PBHSRC+2
PBHSIZE     EQU PBHADDR+2
PBHDLEFT    EQU PBHSIZE+1
PBHSUM      EQU PBHDLEFT+1
PBHGAPN     EQU PBHSUM+1
PBWKEND     EQU PBHGAPN+2

HXFDMA      EQU PBDMA
HXFFCB      EQU PBWKFCB
HXFDMCUR    EQU PBHDMCUR
HXFDMCNT    EQU PBHDMCNT
HXFERROR    EQU PBHERROR
HXFLEFT     EQU PBHLEFT
HXFSRC      EQU PBHSRC
HXFADDR     EQU PBHADDR
HXFSIZE     EQU PBHSIZE
HXFDLEFT    EQU PBHDLEFT
HXFSUM      EQU PBHSUM
