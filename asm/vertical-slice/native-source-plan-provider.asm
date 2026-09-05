; Native SP1 source-plan reader and source-event provider. This is host code,
; outside the 16 KiB compiler core. It obtains every stored byte through the
; common named-object service and supplies the existing four-event compiler
; source ABI.

SPPLANH     EQU $5A10
SPSRCH      EQU $5A12
SPPLCUR     EQU $5A14
SPPLEND     EQU $5A16
SPPARTN     EQU $5A18
SPPARTID    EQU $5A19
SPPHASE     EQU $5A1A
SPPATHN     EQU $5A1B
SPNAMESH    EQU $5A1C
SPNAMEND    EQU $5A1E
SPMATID     EQU $5A20
SPMATLEN    EQU $5A22
SPSVPTR     EQU $5A23
SPSVLEN     EQU $5A25
SPSVPART    EQU $5A26
SPSVOFF     EQU $5A27
SPNAMPOS    EQU $5A29
SPNAMHDR    EQU $5A2B
SPWKEND     EQU $5A2F

SPPLANBF    EQU $5A40
SPPLANLM    EQU $5B40
SPNAMBUF    EQU $5B40
SPNAMLM     EQU $5C40
; Comparison needs a second spelling buffer because the compiler may compare
; a current token materialized in NameScratch. This region is phase-overlaid
; by the NOBJ writer only after parsing has finished.
SPCMPBUF    EQU $5D00
SPCMPLIM    EQU $5E00

SPPHPART    EQU 0
SPPHBYTE    EQU 1
SPPHDONE    EQU 2

; The native resolver publishes this fixed tentative-plan name before launch.
; A platform binding maps the logical name into its own filesystem.
SPPLNAME:
            DB ".nucleus/source-plan.sp1"
SPPLNAML    EQU $-SPPLNAME
SPNMNAME:
            DB ".nucleus/retained-names.work"
SPNMNAML    EQU $-SPNMNAME

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
SPBEGIN:
            LD   HL,SPPLANH
            LD   DE,SPPLANH+1
            LD   BC,SPWKEND-SPPLANH-1
            XOR  A
            LD   (HL),A
            LDIR
            LD   HL,SPPLANBF
            LD   (SPPLCUR),HL
            LD   (SPPLEND),HL
            LD   HL,SPPLNAME
            LD   B,SPPLNAML
            LD   A,NOOPEN
            CALL SPOPEN
            RET  C
            LD   (SPPLANH),HL
            CALL SPRDHDR
            JR   C,SPCLNPLN
            LD   HL,SPNMNAME
            LD   B,SPNMNAML
            LD   A,NOBEGIN
            CALL SPOPEN
            JR   C,SPCLNPLN
            LD   (SPNAMESH),HL
            OR   A
            RET
SPCLNPLN:
            LD   (SPPATHN),A
            LD   HL,(SPPLANH)
            LD   A,NOCLOSE
            CALL SPTERM
            XOR  A
            LD   (SPPLANH),A
            LD   (SPPLANH+1),A
            LD   A,(SPPATHN)
            SCF
            RET

; Release every source-side handle. It is safe after success or source error.
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
SPEND:
            LD   HL,(SPSRCH)
            LD   A,H
            OR   L
            JR   Z,SPCLOPLN
            LD   A,NOCLOSE
            CALL SPTERM
            RET  C
            XOR  A
            LD   (SPSRCH),A
            LD   (SPSRCH+1),A
SPCLOPLN:
            LD   HL,(SPPLANH)
            LD   A,H
            OR   L
            JP   Z,SPABTNAM
            LD   A,NOCLOSE
            CALL SPTERM
            RET  C
            XOR  A
            LD   (SPPLANH),A
            LD   (SPPLANH+1),A
SPABTNAM:
            LD   HL,(SPNAMESH)
            LD   A,H
            OR   L
            RET  Z
            LD   A,NOABORT
            CALL SPTERM
            RET  C
            XOR  A
            LD   (SPNAMESH),A
            LD   (SPNAMESH+1),A
            RET

; Return one raw plan byte in A. Parser accumulators remain live across a
; refill, so this byte operation preserves their registers.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry
SPPLBYTE:
            PUSH BC
            PUSH DE
            PUSH HL
            CALL SPPLBODY
            POP  HL
            POP  DE
            POP  BC
            RET
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
SPPLBODY:
            LD   HL,(SPPLCUR)
            LD   DE,(SPPLEND)
            OR   A
            SBC  HL,DE
            JR   Z,SPREFILL
            ADD  HL,DE
            LD   A,(HL)
            INC  HL
            LD   (SPPLCUR),HL
            OR   A
            RET
SPREFILL:
            LD   HL,(SPPLANH)
            LD   DE,SPPLANBF
            LD   BC,SPPLANLM-SPPLANBF
            CALL SPREAD
            RET  C
            LD   A,B
            OR   C
            JP   Z,SPINVAL
            LD   HL,SPPLANBF
            LD   (SPPLCUR),HL
            ADD  HL,BC
            LD   (SPPLEND),HL
            JP   SPPLBODY

; HL points at an immutable literal and B is its length.
; Contract: in HL,B out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
SPEXPLIT:
            LD   C,B
SPLITLOP:
            CALL SPPLBYTE
            RET  C
            CP   (HL)
            JP   NZ,SPINVAL
            INC  HL
            DEC  C
            JR   NZ,SPLITLOP
            RET

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
SPEXPEOL:
            CALL SPPLBYTE
            RET  C
            CP   10
            RET  Z
            CP   13
            JP   NZ,SPINVAL
            CALL SPPLBYTE
            RET  C
            CP   10
            RET  Z
            JP   SPINVAL

SPHDRTXT:
            DB "SP1 "
SPRECTXT:
            DB "P "
SPENDTXT:
            DB "END"

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
SPRDHDR:
            LD   HL,SPHDRTXT
            LD   B,4
            CALL SPEXPLIT
            RET  C
            CALL SPPLBYTE
            RET  C
            SUB  '1'
            JP   C,SPINVAL
            CP   SRCPARTS
            JP   NC,SPINVAL
            INC  A
            LD   (SPPARTN),A
            JP   SPEXPEOL

; Parse one canonical decimal byte terminated by a space.
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
SPDECSP:
            CALL SPPLBYTE
            RET  C
            CP   '0'
            JP   C,SPINVAL
            CP   '9'+1
            JP   NC,SPINVAL
            SUB  '0'
            LD   E,A
            OR   A
            JR   NZ,SPDECMOR
            CALL SPPLBYTE
            RET  C
            CP   ' '
            JP   NZ,SPINVAL
            XOR  A
            RET
SPDECMOR:
            CALL SPPLBYTE
            RET  C
            CP   ' '
            JR   Z,SPDECOK
            CP   '0'
            JP   C,SPINVAL
            CP   '9'+1
            JP   NC,SPINVAL
            SUB  '0'
            LD   D,A
            LD   A,E
            ADD  A,A
            JP   C,SPINVAL
            LD   L,A
            ADD  A,A
            JP   C,SPINVAL
            ADD  A,A
            JP   C,SPINVAL
            ADD  A,L
            JP   C,SPINVAL
            ADD  A,D
            JP   C,SPINVAL
            LD   E,A
            JR   SPDECMOR
SPDECOK:
            LD   A,E
            RET

; Read the next P record, open its source object, and retain its path length.
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
SPNXTPRT:
            LD   HL,SPRECTXT
            LD   B,2
            CALL SPEXPLIT
            RET  C
            CALL SPDECSP
            RET  C
            ; Bank ordinals are target metadata. The target descriptor checks
            ; them independently; the source streamer only validates u8 syntax.
            CALL SPDECSP
            RET  C
            OR   A
            JP   Z,SPINVAL
            LD   (SPPATHN),A
            LD   B,A
            LD   HL,SPNAMBUF
SPPATHLP:
            CALL SPPLBYTE
            RET  C
            CP   32
            JP   C,SPINVAL
            CP   127
            JP   NC,SPINVAL
            CP   '\\'
            JP   Z,SPINVAL
            LD   (HL),A
            INC  HL
            DJNZ SPPATHLP
            CALL SPEXPEOL
            RET  C
            LD   HL,SPNAMBUF
            LD   A,(SPPATHN)
            LD   B,A
            LD   A,NOOPEN
            CALL SPOPEN
            RET  C
            LD   (SPSRCH),HL
            LD   A,(SPPARTID)
            INC  A
            LD   (SPPARTID),A
            LD   A,SPPHBYTE
            LD   (SPPHASE),A
            LD   A,(SPPARTID)
            LD   C,A
            LD   A,1
            OR   A
            RET

; Validate END, exact object EOF, and release the plan handle.
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
SPFINPLN:
            LD   HL,SPENDTXT
            LD   B,3
            CALL SPEXPLIT
            RET  C
            CALL SPEXPEOL
            RET  C
            LD   HL,(SPPLCUR)
            LD   DE,(SPPLEND)
            OR   A
            SBC  HL,DE
            JP   NZ,SPINVAL
            LD   HL,(SPPLANH)
            LD   DE,SPPLANBF
            LD   BC,1
            CALL SPREAD
            RET  C
            LD   A,B
            OR   C
            JP   NZ,SPINVAL
            LD   HL,(SPPLANH)
            LD   A,NOCLOSE
            CALL SPTERM
            RET  C
            XOR  A
            LD   (SPPLANH),A
            LD   (SPPLANH+1),A
            LD   A,SPPHDONE
            LD   (SPPHASE),A
            LD   A,3
            OR   A
            RET

; Read and validate the four-byte name record at the current scan position.
; Success leaves the spool cursor immediately after the header and B=length.
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
SPRDNHDR:
            LD   HL,(SPNAMESH)
            LD   DE,(SPSVOFF)
            CALL SPSEEK
            RET  C
            LD   HL,(SPNAMESH)
            LD   DE,SPNAMHDR
            LD   BC,4
            CALL SPREAD
            RET  C
            LD   A,B
            OR   A
            JP   NZ,SPINVAL
            LD   A,C
            CP   4
            JP   NZ,SPINVAL
            LD   A,(SPNAMHDR)
            OR   A
            JP   Z,SPINVAL
            LD   B,A
            RET

; HL is an opaque retained-name handle. Success proves it is exactly the start
; of a record in the current generation and returns B=length.
; Contract: in HL out A,B,carry,zero clobbers sign,parity,halfCarry,C,DE,HL
SPCHKNAM:
            LD   A,H
            OR   L
            JP   Z,SPINVAL
            DEC  HL
            LD   (SPNAMPOS),HL
            LD   HL,0
            LD   (SPSVOFF),HL
SPCHKLOP:
            LD   HL,(SPSVOFF)
            LD   DE,(SPNAMPOS)
            OR   A
            SBC  HL,DE
            JR   Z,SPCHKOK
            JP   NC,SPINVAL
            CALL SPRDNHDR
            RET  C
            LD   A,B
            LD   E,A
            LD   D,0
            LD   HL,(SPSVOFF)
            LD   BC,4
            ADD  HL,BC
            JP   C,SPINVAL
            ADD  HL,DE
            JP   C,SPINVAL
            LD   (SPSVOFF),HL
            LD   DE,(SPNAMEND)
            OR   A
            SBC  HL,DE
            JP   NC,SPCHKEND
            JR   SPCHKLOP
SPCHKEND:
            JP   NZ,SPINVAL
            LD   HL,(SPNAMPOS)
            LD   DE,(SPNAMEND)
            OR   A
            SBC  HL,DE
            JP   NZ,SPINVAL
            JP   SPINVAL
SPCHKOK:
            LD   HL,(SPSVOFF)
            LD   DE,(SPNAMEND)
            OR   A
            SBC  HL,DE
            JP   NC,SPINVAL
            JP   SPRDNHDR

; Compiler retained-name ABI: HL=bytes, B=length, C=part, DE=part offset.
; Contract: in HL,B,C,DE out A,HL,carry,zero clobbers sign,parity,halfCarry
SPRETAIN:
            PUSH BC
            PUSH DE
            CALL SPRETBOD
            POP  DE
            POP  BC
            RET
; Contract: in HL,B,C,DE out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
SPRETBOD:
            LD   (SPSVPTR),HL
            LD   A,B
            LD   (SPSVLEN),A
            LD   A,C
            LD   (SPSVPART),A
            LD   (SPSVOFF),DE
            LD   A,B
            OR   A
            JP   Z,SPINVAL
            LD   A,(SPPARTID)
            CP   C
            JP   NZ,SPINVAL

            ; A materialized spelling immediately retained again denotes the
            ; same logical name, not a second record.
            LD   HL,(SPMATID)
            LD   A,H
            OR   L
            JR   Z,SPAPPEND
            LD   A,(SPMATLEN)
            CP   B
            JR   NZ,SPAPPEND
            LD   A,(SPNAMHDR+1)
            LD   C,A
            LD   A,(SPSVPART)
            CP   C
            JR   NZ,SPAPPEND
            LD   HL,(SPSVOFF)
            LD   DE,(SPNAMHDR+2)
            OR   A
            SBC  HL,DE
            JR   NZ,SPAPPEND
            LD   HL,(SPSVPTR)
            LD   DE,SPNAMBUF
            OR   A
            SBC  HL,DE
            LD   HL,(SPMATID)
            RET  Z

SPAPPEND:
            XOR  A
            LD   (SPMATID),A
            LD   (SPMATID+1),A
            LD   HL,(SPNAMEND)
            PUSH HL
            LD   DE,4
            ADD  HL,DE
            JP   C,SPRETCAP
            LD   A,(SPSVLEN)
            LD   E,A
            LD   D,0
            ADD  HL,DE
            JP   C,SPRETCAP
            LD   (SPNAMPOS),HL
            POP  HL
            INC  HL
            LD   (SPMATID),HL
            DEC  HL

            LD   DE,(SPSVOFF)
            LD   A,(SPSVLEN)
            LD   (SPNAMHDR),A
            LD   A,(SPSVPART)
            LD   (SPNAMHDR+1),A
            LD   (SPNAMHDR+2),DE

            EX   DE,HL
            LD   HL,(SPNAMESH)
            CALL SPSEEK
            RET  C
            LD   HL,(SPNAMESH)
            LD   DE,SPNAMHDR
            LD   BC,4
            CALL SPWRITE
            RET  C
            LD   HL,(SPNAMESH)
            LD   DE,(SPSVPTR)
            LD   A,(SPSVLEN)
            LD   C,A
            LD   B,0
            CALL SPWRITE
            RET  C
            LD   HL,(SPNAMPOS)
            LD   (SPNAMEND),HL
            LD   HL,(SPMATID)
            XOR  A
            LD   (SPMATLEN),A
            RET
SPRETCAP:
            POP  HL
            LD   A,NSTATCAP
            SCF
            RET

; Compiler compare ABI: HL=handle, IX=current bytes, B=length; Z reports equal.
; Contract: in HL,IX,B out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
SPCMPNAM:
            LD   A,B
            LD   (SPSVLEN),A
            CALL SPCHKNAM
            RET  C
            LD   A,(SPSVLEN)
            CP   B
            JR   NZ,SPNEQUAL
            LD   C,B
            LD   B,0
            LD   HL,(SPNAMESH)
            LD   DE,SPCMPBUF
            CALL SPREAD
            RET  C
            LD   A,B
            OR   A
            JP   NZ,SPINVAL
            LD   A,(SPSVLEN)
            CP   C
            JP   NZ,SPINVAL
            LD   B,A
            PUSH IX
            POP  DE
            LD   HL,SPCMPBUF
SPCMPLOP:
            LD   A,(DE)
            CP   (HL)
            JR   NZ,SPNEQUAL
            INC  DE
            INC  HL
            DJNZ SPCMPLOP
            XOR  A
            RET
SPNEQUAL:
            LD   A,1
            OR   A
            RET

; Compiler materialize ABI: HL=handle; returns HL=stable bytes and B=length.
; Contract: in HL out A,B,HL,carry,zero clobbers sign,parity,halfCarry
SPMATNAM:
            PUSH BC
            PUSH DE
            CALL SPMATBOD
            PUSH HL
            PUSH AF
            LD   A,B
            LD   (SPMATLEN),A
            POP  AF
            POP  HL
            POP  DE
            POP  BC
            PUSH AF
            LD   A,(SPMATLEN)
            LD   B,A
            POP  AF
            RET
; Contract: in HL out A,BC,DE,HL,carry,zero,sign,parity,halfCarry
SPMATBOD:
            LD   (SPMATID),HL
            CALL SPCHKNAM
            RET  C
            LD   A,B
            LD   (SPMATLEN),A
            LD   C,A
            LD   B,0
            LD   HL,(SPNAMESH)
            LD   DE,SPNAMBUF
            CALL SPREAD
            RET  C
            LD   A,B
            OR   A
            JP   NZ,SPINVAL
            LD   A,(SPMATLEN)
            CP   C
            JP   NZ,SPINVAL
            LD   B,A
            LD   HL,SPNAMBUF
            XOR  A
            RET

; Existing compiler source-provider ABI: A=event, C=part, HL=bytes, DE=count.
; Contract: out A,C,DE,HL,carry,zero clobbers sign,parity,halfCarry,B
SPNEXT:
            XOR  A
            LD   (SPMATID),A
            LD   (SPMATID+1),A
            LD   A,(SPPHASE)
            CP   SPPHBYTE
            JR   Z,SPBYTES
            CP   SPPHDONE
            JP   Z,SPINVAL
            LD   A,(SPPARTID)
            LD   HL,SPPARTN
            CP   (HL)
            JP   Z,SPFINPLN
            JP   SPNXTPRT
SPBYTES:
            LD   HL,(SPSRCH)
            LD   DE,SRCCHUNK
            LD   BC,MMCHKEND-SRCCHUNK
            CALL SPREAD
            RET  C
            LD   A,B
            OR   C
            JR   Z,SPENDPRT
            LD   D,B
            LD   E,C
            LD   HL,SRCCHUNK
            LD   A,(SPPARTID)
            LD   C,A
            XOR  A
            RET
SPENDPRT:
            LD   HL,(SPSRCH)
            LD   A,NOCLOSE
            CALL SPTERM
            RET  C
            XOR  A
            LD   (SPSRCH),A
            LD   (SPSRCH+1),A
            LD   (SPPHASE),A
            LD   A,(SPPARTID)
            LD   C,A
            LD   A,2
            OR   A
            RET
