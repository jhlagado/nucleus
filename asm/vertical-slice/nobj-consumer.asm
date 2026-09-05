; Standalone NOBJ 0.1 stored-object consumer.
;
; This module owns no filesystem or target device policy. It calls the fixed
; NC platform vector from native-z80-host-contract.md and keeps all tentative
; target writes unpublished until one complete sequential read has reached a
; valid COMMIT and immediate EOF.

; Contract: in IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX
LCRUN:
            PUSH IY
            CALL LCRUNBD
            POP  IY
            RET

; Contract: in IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
LCRUNBD:
            LD   (LVSDPTR),IX
            LD   HL,0
            LD   (LVRECNO),HL
            CALL LCVALDSC
            JR   C,LCRETFL
            CALL LCVALVEC
            JR   C,LCRETFL
            CALL LCVALDEP
            JR   C,LCRETFL

            LD   IX,(LVSDPTR)
            LD   L,(IX+4)
            LD   H,(IX+5)
            CALL LVOPEN
            JR   C,LCCLOSFL
            CALL LCPASS
            JR   C,LCOPENFL

            CALL LVCLOSE
            JR   C,LCCLOSFL

            LD   A,(LVENTBNK)
            LD   HL,(LVIMBASE)
            LD   IX,LVMAPBUF
            LD   BC,(LVMAPLEN)
            LD   DE,(LVSPPTR)
            CALL LVPUBL
            JR   C,LCCLOSFL

            LD   A,(LVENTBNK)
            LD   HL,(LVIMBASE)
            LD   IX,(LVSPPTR)
            CALL LVENTER
            ; A successful entry never returns.
            JR   LCCLOSFL

LCOPENFL:
            CALL LVCLOSE
            JR   LCRETFL

LCCLOSFL:
            CALL LCSETPF

; Contract: out A,carry clobbers zero,sign,parity,halfCarry,BC,DE,HL,IX
LCRETFL:
            LD   HL,(LVSRPTR)
            LD   A,H
            OR   L
            JR   Z,LCRETBF
            LD   A,(LVFLOUT)
            LD   (HL),A
            INC  HL
            LD   A,(LVFLSTAT)
            LD   (HL),A
            INC  HL
            LD   DE,(LVRECNO)
            LD   (HL),E
            INC  HL
            LD   (HL),D
LCRETBF:
            LD   A,(LVFLSTAT)
            SCF
            RET

; Contract: in A out A,carry clobbers zero,sign,parity,halfCarry
LCSETVF:
            LD   (LVFLSTAT),A
            LD   A,LVOINVAL
            LD   (LVFLOUT),A
            SCF
            RET

; Contract: in A out A,carry clobbers zero,sign,parity,halfCarry
LCSETPF:
            LD   (LVFLSTAT),A
            LD   A,LVOPLAT
            LD   (LVFLOUT),A
            SCF
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
LCVALDSC:
            LD   IX,(LVSDPTR)
            PUSH IX
            POP  HL
            LD   DE,10
            CALL LCCTREXT
            JR   C,LCDSCBAR
            LD   IX,(LVSDPTR)
            LD   A,(IX+0)
            CP   10
            JR   NZ,LCDSCBAR
            LD   A,(IX+1)
            OR   A
            JR   NZ,LCDSCBAR
            LD   A,(IX+2)
            CP   1
            JR   NZ,LCDSCBAR
            LD   A,(IX+3)
            OR   A
            JR   NZ,LCDSCBAR
            LD   L,(IX+8)
            LD   H,(IX+9)
            LD   A,H
            OR   L
            JR   Z,LCDSCBAR
            PUSH HL
            LD   DE,4
            CALL LCCTREXT
            POP  HL
            JR   C,LCDSCBAR
            LD   (LVSRPTR),HL
            LD   IX,(LVSDPTR)
            LD   L,(IX+6)
            LD   H,(IX+7)
            LD   A,H
            OR   L
            JR   Z,LCDSCERR
            PUSH HL
            LD   DE,18
            CALL LCCTREXT
            POP  HL
            JR   C,LCDSCERR
            LD   (LVSPPTR),HL
            OR   A
            RET
LCDSCBAR:
            LD   HL,0
            LD   (LVSRPTR),HL
LCDSCERR:
            LD   A,LVSDESC
            JR   LCSETVF

; HL=start, DE=length. Carry means the complete extent is not inside the
; caller-owned control region that remains live until target entry.
; Contract: in DE,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
LCCTREXT:
            LD   BC,LVCTLBA
            OR   A
            SBC  HL,BC
            JR   C,LCCTRERR
            ADD  HL,BC
            ADD  HL,DE
            JR   NC,LCCTREND
            LD   A,H
            OR   L
            JR   NZ,LCCTRERR
            LD   BC,LVCTLLIM
            LD   A,B
            OR   C
            JR   Z,LCCTROK
            JR   LCCTRERR
LCCTREND:
            LD   BC,LVCTLLIM
            LD   A,B
            OR   C
            JR   Z,LCCTROK
            OR   A
            SBC  HL,BC
            JR   C,LCCTROK
            RET  Z
LCCTRERR:
            SCF
            RET
LCCTROK:
            OR   A
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
LCVALVEC:
            LD   HL,LVPLBASE
            LD   DE,LCVECSIG
            LD   B,8
LCVECLP:
            LD   A,(DE)
            CP   (HL)
            JR   NZ,LCVECERR
            INC  DE
            INC  HL
            DJNZ LCVECLP
            RET
LCVECERR:
            LD   A,LVSVECT
            JP   LCSETVF

LCVECSIG:
            DB  "NC",0,1,8,8,0,0

; Validate the exact revision-one deployment record, derive loaded/ROM mode,
; and reject a target window that can overwrite the resident consumer.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
LCVALDEP:
            LD   IX,(LVSPPTR)
            LD   A,(IX+0)
            CP   18
            JP   NZ,LCDEPERR
            LD   A,(IX+1)
            CP   1
            JP   NZ,LCDEPERR
            LD   A,(IX+2)
            AND  $FC
            JP   NZ,LCDEPERR
            LD   A,(IX+2)
            LD   (LVPRFLAG),A
            LD   L,(IX+3)
            LD   H,(IX+4)
            LD   (LVRTID),HL
            LD   A,(IX+5)
            LD   (LVBKCNT),A
            LD   B,A
            LD   A,(IX+6)
            LD   (LVFILL),A
            LD   L,(IX+7)
            LD   H,(IX+8)
            LD   (LVIMBASE),HL
            LD   E,(IX+9)
            LD   D,(IX+10)
            LD   (LVIMCAP),DE
            LD   A,D
            OR   E
            JR   Z,LCDEPERR
            CALL LCEXTEND
            JR   C,LCDEPERR
            LD   L,(IX+11)
            LD   H,(IX+12)
            LD   (LVWRBASE),HL
            LD   E,(IX+13)
            LD   D,(IX+14)
            LD   (LVWRCAP),DE
            LD   A,D
            OR   E
            JR   Z,LCDEPERR
            CALL LCEXTEND
            JR   C,LCDEPERR
            LD   A,(IX+15)
            LD   (LVENTBNK),A

            LD   A,(LVPRFLAG)
            BIT  0,A
            JR   NZ,LCVALBNK
            LD   A,(LVBKCNT)
            LD   B,A
            LD   A,B
            CP   1
            JR   NZ,LCDEPERR
            LD   A,(LVENTBNK)
            OR   A
            JR   NZ,LCDEPERR
            LD   A,(IX+16)
            OR   (IX+17)
            JR   NZ,LCDEPERR
            CALL LCFLMODE
            JR   C,LCDEPERR
            JR   LCVALPRO

LCVALBNK:
            LD   A,(LVBKCNT)
            LD   B,A
            LD   A,B
            CP   2
            JR   C,LCDEPERR
            CP   5
            JR   NC,LCDEPERR
            LD   A,(LVENTBNK)
            CP   B
            JR   NC,LCDEPERR
            LD   A,(IX+16)
            OR   (IX+17)
            JR   Z,LCDEPERR
            CALL LCWROUT
            JR   C,LCDEPERR
            LD   A,1
            LD   (LVROM),A
            CALL LCVALBND
            JR   C,LCDEPERR

LCVALPRO:
            CALL LCIMGPRO
            RET  NC
LCPROERR:
            LD   A,LVSPROT
            JP   LCSETVF
LCDEPERR:
            LD   A,LVSDEPLY
            JP   LCSETVF

; HL=base, DE=capacity. Carry means the mathematical end exceeds $10000.
; Contract: in DE,HL out A,HL,carry,zero clobbers sign,parity,halfCarry,BC
LCEXTEND:
            LD   B,H
            LD   C,L
            ADD  HL,DE
            RET  NC
            LD   A,H
            OR   L
            RET  Z
            SCF
            RET

; Derive the flat mode without a profile mode bit. Carry means partial overlap.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
LCFLMODE:
            LD   HL,(LVWRBASE)
            LD   DE,(LVIMBASE)
            OR   A
            SBC  HL,DE                  ; writable offset from image base
            JR   C,LCWRBELO
            LD   DE,(LVIMCAP)
            PUSH HL
            OR   A
            SBC  HL,DE
            POP  HL
            JR   NC,LCWRABOV
            EX   DE,HL                  ; DE=offset, HL=image capacity
            OR   A
            SBC  HL,DE                  ; remaining image capacity
            LD   DE,(LVWRCAP)
            OR   A
            SBC  HL,DE
            JR   C,LCPARTOL
            XOR  A                      ; loaded mode
            LD   (LVROM),A
            RET
LCWRBELO:
            LD   HL,(LVIMBASE)
            LD   DE,(LVWRBASE)
            OR   A
            SBC  HL,DE                  ; distance to image base
            LD   DE,(LVWRCAP)
            OR   A
            SBC  HL,DE
            JR   C,LCPARTOL
LCWRABOV:
            LD   A,1                    ; disjoint ROM mode
            LD   (LVROM),A
            OR   A
            RET
LCPARTOL:
            SCF
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
LCWROUT:
            CALL LCFLMODE
            RET  C
            LD   A,(LVROM)
            OR   A
            RET  NZ
            SCF
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
LCVALBND:
            LD   IX,(LVSPPTR)
            LD   L,(IX+16)
            LD   H,(IX+17)
            LD   A,(LVBKCNT)
            ADD  A,A                     ; 2n
            LD   E,A
            ADD  A,A                     ; 4n
            ADD  A,E                     ; 6n
            LD   E,A
            LD   D,0
            CALL LCCTREXT
            RET  C
            LD   IX,(LVSPPTR)
            LD   L,(IX+16)
            LD   H,(IX+17)
            LD   A,(LVBKCNT)
            LD   B,A
LCBINDLP:
            INC  HL                      ; selector is opaque
            LD   A,(HL)                  ; reserved byte
            OR   A
            JR   NZ,LCBNDERR
            LD   DE,5
            ADD  HL,DE
            DJNZ LCBINDLP
            OR   A
            RET
LCBNDERR:
            SCF
            RET

; Carry means either target-write region overlaps a resident protected extent.
; The image check is independent of which physical bank is selected.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
LCIMGPRO:
            LD   BC,LVCBASE
            LD   DE,LVCLIMIT
            CALL LCTGINT
            RET  C
            LD   BC,LVWKBASE
            LD   DE,LVWKEND
            CALL LCTGINT
            RET  C
            LD   BC,LVSTKBAS
            LD   DE,LVSTKLIM
            CALL LCTGINT
            RET  C
            LD   BC,LVPCLBAS
            LD   DE,LVPCLLIM
            CALL LCTGINT
            RET  C
            LD   BC,LVCTLBA
            LD   DE,LVCTLLIM
            CALL LCTGINT
            RET  C
            LD   BC,LVOBJBA
            LD   DE,LVOBJLIM
            LD   A,B
            OR   C
            OR   D
            OR   E
            RET  Z

; BC=fixed start, DE=fixed limit. Carry means image or writable intersects it.
; Contract: in BC,DE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
LCTGINT:
            PUSH BC
            PUSH DE
            LD   HL,(LVIMBASE)
            LD   IX,(LVIMCAP)
            CALL LCREGINT
            POP  DE
            POP  BC
            RET  C
            LD   HL,(LVWRBASE)
            LD   IX,(LVWRCAP)

; HL=target base, IX=capacity, BC=fixed start, DE=fixed exclusive limit.
; Both inputs are valid half-open extents; a zero fixed limit means $10000.
; Contract: in BC,DE,HL,IX out A,carry,zero clobbers sign,parity,halfCarry,DE,HL,IX,IY
LCREGINT:
            LD   A,D
            OR   E
            JR   Z,LCREGBEF
            PUSH HL
            OR   A
            SBC  HL,DE
            POP  HL
            JR   NC,LCDISJNT
LCREGBEF:
            PUSH IX
            POP  DE
            ADD  HL,DE
            JR   C,LCINTER
            OR   A
            SBC  HL,BC
            JR   C,LCDISJNT
            RET  Z
LCINTER:
            SCF
            RET
LCDISJNT:
            OR   A
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX
LCPASS:
            XOR  A
            LD   (LVPHASE),A
            LD   (LVIMSEEN),A
            LD   HL,$FFFF
            LD   (LVCRC),HL
            LD   DE,LVIMENDS
            LD   B,16
LCRSTEND:
            LD   (DE),A
            INC  DE
            DJNZ LCRSTEND

LCRECLP:
            CALL LCRECHD
            RET  C
            LD   A,(LVRECKND)
            CP   LVKBEGIN
            JR   Z,LCBEGIN
            CP   LVKIMAGE
            JP   Z,LCIMAGE
            CP   LVKPATCH
            JP   Z,LCPATCH
            CP   LVKMAP
            JP   Z,LCMAP
            CP   LVKCOMIT
            JP   Z,LCCOMMIT
            LD   A,LVSFRAME
            JP   LCSETVF

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
LCRECHD:
            CALL LCRCRCB
            RET  C
            LD   (LVRECKND),A
            LD   HL,(LVRECNO)
            INC  HL
            LD   A,H
            OR   L
            JR   Z,LCCNTERR
            LD   (LVRECNO),HL
            CALL LCRCRCW
            RET  C
            LD   (LVPLEN),HL
            RET
LCCNTERR:
            LD   A,LVSORDER
            JP   LCSETVF

; Carry clear returns one required byte. Carry set records either a truncated
; validator result or the exact platform status.
; Contract: out A,carry,zero,sign,parity,halfCarry clobbers BC,DE,HL,IX,IY
LCREQBYT:
            CALL LVREAD
            RET  NC
            CP   LVPLEND
            JR   NZ,LCREQPFL
            LD   A,LVSTRUNC
            JP   LCSETVF
LCREQPFL:
            JP   LCSETPF

; Contract: out A,carry,zero,sign,parity,halfCarry clobbers BC,DE,HL,IX,IY
LCRCRCB:
            CALL LCREQBYT
            RET  C
            PUSH AF
            CALL LCCRCB
            POP  AF
            OR   A
            RET

; CRC-16/CCITT-FALSE, polynomial $1021, no reflection.
; Contract: in A out carry,zero clobbers sign,parity,halfCarry,A,B,HL
LCCRCB:
            LD   HL,(LVCRC)
            XOR  H
            LD   H,A
            LD   B,8
LCCRCBIT:
            ADD  HL,HL
            JR   NC,LCCRCNXT
            LD   A,H
            XOR  $10
            LD   H,A
            LD   A,L
            XOR  $21
            LD   L,A
LCCRCNXT:
            DJNZ LCCRCBIT
            LD   (LVCRC),HL
            OR   A
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
LCBEGIN:
            LD   A,(LVPHASE)
            OR   A
            JP   NZ,LCORDERR
            LD   HL,(LVRECNO)
            DEC  HL
            LD   A,H
            OR   L
            JP   NZ,LCORDERR
            LD   HL,(LVPLEN)
            LD   DE,15
            OR   A
            SBC  HL,DE
            JP   NZ,LCFRMERR
            LD   DE,LCBGNBYT
            LD   B,6
LCBEGSIG:
            PUSH BC
            CALL LCRCRCB
            POP  BC
            RET  C
            EX   DE,HL
            CP   (HL)
            EX   DE,HL
            JP   NZ,LCFRMERR
            INC  DE
            DJNZ LCBEGSIG
            CALL LCRCRCB          ; BEGIN flags
            RET  C
            LD   (LVBGFLAG),A
            AND  $FE
            JR   NZ,LCFRMERR
            CALL LCRCRCW
            RET  C
            LD   DE,(LVRTID)
            OR   A
            SBC  HL,DE
            JR   NZ,LCDEPMIS
            CALL LCRCRCB          ; bank count
            RET  C
            LD   B,A
            LD   A,(LVBKCNT)
            CP   B
            JR   NZ,LCDEPMIS
            CALL LCRCRCB          ; fill
            RET  C
            LD   B,A
            LD   A,(LVFILL)
            CP   B
            JR   NZ,LCDEPMIS
            CALL LCRCRCW
            RET  C
            LD   DE,(LVIMBASE)
            OR   A
            SBC  HL,DE
            JR   NZ,LCDEPMIS
            CALL LCRCRCW
            RET  C
            LD   DE,(LVIMCAP)
            OR   A
            SBC  HL,DE
            JR   NZ,LCDEPMIS
            LD   A,(LVBGFLAG)
            AND  1
            LD   B,A
            LD   A,(LVPRFLAG)
            AND  1
            CP   B
            JR   NZ,LCDEPMIS
            CALL LCFILL
            RET  C
            LD   A,LVPIMAGE
            LD   (LVPHASE),A
            JP   LCRECLP

LCBGNBYT:
            DB  "NOBJ",0,1

; Contract: out A,HL,carry,zero,sign,parity,halfCarry clobbers BC,DE,IX,IY
LCRCRCW:
            CALL LCRCRCB
            RET  C
            PUSH AF
            CALL LCRCRCB
            JR   C,LCCRCWFL
            LD   H,A
            POP  AF
            LD   L,A
            RET
LCCRCWFL:
            POP  HL
            SCF
            RET

LCDEPMIS:
            LD   A,LVSDEPLY
            JP   LCSETVF
LCFRMERR:
            LD   A,LVSFRAME
            JP   LCSETVF
LCORDERR:
            LD   A,LVSORDER
            JP   LCSETVF

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
LCIMAGE:
            LD   A,(LVPHASE)
            CP   LVPIMAGE
            JR   NZ,LCORDERR
            CALL LCIMGHDR
            RET  C
            LD   A,(LVCURBNK)
            LD   HL,LVIMENDS
            CALL LCBKWORD
            LD   E,(HL)
            INC  HL
            LD   D,(HL)                  ; previous end offset
            LD   HL,(LVCURADR)
            LD   BC,(LVIMBASE)
            OR   A
            SBC  HL,BC                   ; current start offset
            OR   A
            SBC  HL,DE
            JR   C,LCIMGORD
            LD   A,(LVCURBNK)
            LD   HL,LVIMENDS
            CALL LCBKWORD
            LD   DE,(LVCUREND)
            LD   (HL),E
            INC  HL
            LD   (HL),D
            LD   A,1
            LD   (LVIMSEEN),A
            CALL LCIMGBYT
            RET  C
            JP   LCRECLP
LCIMGORD:
            LD   A,LVSIMORD
            JP   LCSETVF

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX
LCPATCH:
            LD   A,(LVPHASE)
            CP   LVPIMAGE
            JR   Z,LCPATRDY
            CP   LVPPATCH
            JR   NZ,LCORDERR
LCPATRDY:
            LD   A,(LVIMSEEN)
            OR   A
            JR   Z,LCORDERR
            LD   A,LVPPATCH
            LD   (LVPHASE),A
            CALL LCIMGHDR
            RET  C
            LD   A,(LVCURBNK)
            LD   HL,LVPATEND
            CALL LCBKWORD
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            LD   BC,(LVCUREND)
            EX   DE,HL
            OR   A
            SBC  HL,BC
            JR   NC,LCPATEND
            LD   A,(LVCURBNK)
            LD   HL,LVPATEND
            CALL LCBKWORD
            LD   DE,(LVCUREND)
            LD   (HL),E
            INC  HL
            LD   (HL),D
LCPATEND:
            CALL LCIMGBYT
            RET  C
            JP   LCRECLP

; Read bank/address, validate the nonempty extent, and retain the modular end
; as an offset from imageBase. The replacement/data bytes remain unread.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
LCIMGHDR:
            LD   HL,(LVPLEN)
            LD   DE,4
            OR   A
            SBC  HL,DE
            JP   C,LCFRMERR
            CALL LCRCRCB
            RET  C
            LD   (LVCURBNK),A
            LD   B,A
            LD   A,(LVBKCNT)
            DEC  A
            CP   B
            JR   C,LCTGTERR
            CALL LCRCRCW
            RET  C
            LD   (LVCURADR),HL
            LD   DE,(LVIMBASE)
            OR   A
            SBC  HL,DE
            JR   C,LCTGTERR
            LD   BC,(LVPLEN)
            DEC  BC
            DEC  BC
            DEC  BC                       ; byte count, known nonzero
            ADD  HL,BC                    ; end offset
            JR   C,LCTGTERR
            LD   DE,(LVIMCAP)
            PUSH HL
            OR   A
            SBC  HL,DE
            POP  HL
            JR   C,LCIMGRDY
            JR   NZ,LCTGTERR
LCIMGRDY:
            LD   (LVCUREND),HL
            OR   A
            RET
LCTGTERR:
            LD   A,LVSTGEXT
            JP   LCSETVF

; Contract: in A,HL out A,HL,carry,zero clobbers sign,parity,halfCarry,DE
LCBKWORD:
            ADD  A,A
            LD   E,A
            LD   D,0
            ADD  HL,DE
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX
LCIMGBYT:
            LD   A,(LVCURBNK)
            LD   IX,(LVSPPTR)
            CALL LVSELECT
            JR   C,LCIMGFL
            LD   HL,(LVCURADR)
            LD   BC,(LVPLEN)
            DEC  BC
            DEC  BC
            DEC  BC
LCIMGLP:
            PUSH BC
            PUSH HL
            CALL LCRCRCB
            POP  HL
            POP  BC
            RET  C
            LD   (HL),A
            INC  HL
            DEC  BC
            LD   A,B
            OR   C
            JR   NZ,LCIMGLP
            RET
LCIMGFL:
            JP   LCSETPF

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX
LCMAP:
            LD   A,(LVPHASE)
            CP   LVPIMAGE
            JR   Z,LCMAPRDY
            CP   LVPPATCH
            JP   NZ,LCORDERR
LCMAPRDY:
            LD   A,(LVIMSEEN)
            OR   A
            JP   Z,LCORDERR
            LD   HL,(LVPLEN)
            LD   DE,41
            OR   A
            SBC  HL,DE
            JR   C,LCMAPERR
            LD   HL,LVMAPCAP
            LD   DE,(LVPLEN)
            OR   A
            SBC  HL,DE
            JR   C,LCMAPERR
            LD   (LVMAPLEN),DE
            LD   HL,LVMAPBUF
            LD   BC,(LVPLEN)
LCMAPLP:
            PUSH BC
            PUSH HL
            CALL LCRCRCB
            POP  HL
            POP  BC
            RET  C
            LD   (HL),A
            INC  HL
            DEC  BC
            LD   A,B
            OR   C
            JR   NZ,LCMAPLP
            CALL LCVALMAP
            RET  C
            LD   A,LVPMAP
            LD   (LVPHASE),A
            JP   LCRECLP
LCMAPERR:
            LD   A,LVSMAP
            JP   LCSETVF

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX
LCVALMAP:
            LD   IX,LVMAPBUF
            LD   A,(IX+0)
            CP   1
            JR   NZ,LCMAPERR
            LD   A,(IX+LVMFLAGS)
            AND  $FC
            JR   NZ,LCMAPERR
            LD   A,(IX+LVMFLAGS)
            AND  1
            LD   B,A
            LD   A,(LVROM)
            CP   B
            JR   NZ,LCMAPERR
            LD   A,(IX+LVMFLAGS)
            AND  2
            LD   B,A
            LD   A,(LVPRFLAG)
            AND  2
            CP   B
            JR   NZ,LCMAPERR
            LD   A,(IX+LVMENTBK)
            LD   B,A
            LD   A,(LVENTBNK)
            CP   B
            JR   NZ,LCMAPERR
            LD   L,(IX+LVMENTRY)
            LD   H,(IX+LVMENTRY+1)
            LD   DE,(LVIMBASE)
            OR   A
            SBC  HL,DE
            JR   NZ,LCMAPERR
            LD   L,(IX+LVMWRBAS)
            LD   H,(IX+LVMWRBAS+1)
            LD   DE,(LVWRBASE)
            OR   A
            SBC  HL,DE
            JR   NZ,LCMAPERR
            LD   L,(IX+LVMWRCAP)
            LD   H,(IX+LVMWRCAP+1)
            LD   DE,(LVWRCAP)
            OR   A
            SBC  HL,DE
            JR   NZ,LCMAPERR

            LD   A,(IX+LVMPARTS)
            OR   A
            JR   Z,LCMAPERR
            LD   C,A
            LD   B,0
            LD   HL,LVMAPBUF+29
LCPARTLP:
            LD   A,(HL)
            LD   D,A
            LD   A,(LVBKCNT)
            DEC  A
            CP   D
            JR   C,LCMAPERR
            INC  HL
            DEC  BC
            LD   A,B
            OR   C
            JR   NZ,LCPARTLP
            LD   A,(HL)                  ; bank entry count
            LD   B,A
            LD   A,(LVBKCNT)
            CP   B
            JP   NZ,LCMAPERR

            ; Exact payload length: 30 + partCount + 10*bankCount.
            LD   A,(LVBKCNT)
            LD   L,A
            LD   H,0
            ADD  HL,HL                   ; 2n
            LD   D,H
            LD   E,L
            ADD  HL,HL                   ; 4n
            ADD  HL,HL                   ; 8n
            ADD  HL,DE                   ; 10n
            LD   A,(IX+LVMPARTS)
            LD   E,A
            LD   D,0
            ADD  HL,DE
            LD   DE,30
            ADD  HL,DE
            LD   DE,(LVMAPLEN)
            OR   A
            SBC  HL,DE
            JP   NZ,LCMAPERR

            CALL LCVALWR
            RET  C
            JP   LCMAPBNK

; Validate the fixed writable, data-load, and stack relationships.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
LCVALWR:
            LD   IX,LVMAPBUF
            LD   L,(IX+LVMVBASE)
            LD   H,(IX+LVMVBASE+1)
            LD   DE,(LVWRBASE)
            OR   A
            SBC  HL,DE
            JP   NZ,LCMAPERR
            LD   L,(IX+LVMIBASE)
            LD   H,(IX+LVMIBASE+1)
            LD   DE,(LVWRBASE)
            OR   A
            SBC  HL,DE
            JP   NZ,LCMAPERR
            LD   E,(IX+LVMVLEN)
            LD   D,(IX+LVMVLEN+1)
            LD   A,D
            OR   E
            JP   Z,LCMAPERR
            LD   L,(IX+LVMILEN)
            LD   H,(IX+LVMILEN+1)
            PUSH HL
            OR   A
            SBC  HL,DE
            POP  HL
            JP   C,LCMAPERR
            LD   E,(IX+LVMBLEN)
            LD   D,(IX+LVMBLEN+1)
            ADD  HL,DE
            JP   C,LCMAPERR
            LD   DE,(LVWRCAP)
            PUSH HL
            OR   A
            SBC  HL,DE
            POP  HL
            JR   C,LCWRFIT
            JP   NZ,LCMAPERR
LCWRFIT:
            ; BSS starts at writableBase + initializedRunLength, modulo $10000.
            LD   E,(IX+LVMILEN)
            LD   D,(IX+LVMILEN+1)
            LD   HL,(LVWRBASE)
            ADD  HL,DE
            LD   E,(IX+LVMBBASE)
            LD   D,(IX+LVMBBASE+1)
            OR   A
            SBC  HL,DE
            JP   NZ,LCMAPERR
            ; data-load length is the complete initialized run length.
            LD   L,(IX+LVMDLLEN)
            LD   H,(IX+LVMDLLEN+1)
            LD   E,(IX+LVMILEN)
            LD   D,(IX+LVMILEN+1)
            OR   A
            SBC  HL,DE
            JP   NZ,LCMAPERR

            LD   A,(LVPRFLAG)
            BIT  1,A
            JR   Z,LCSTKRDY
            ; free = writableCapacity - initializedLength - bssLength
            LD   HL,(LVWRCAP)
            LD   E,(IX+LVMILEN)
            LD   D,(IX+LVMILEN+1)
            OR   A
            SBC  HL,DE
            LD   E,(IX+LVMBLEN)
            LD   D,(IX+LVMBLEN+1)
            OR   A
            SBC  HL,DE
            JP   C,LCMAPERR
            LD   E,(IX+LVMSTACK)
            LD   D,(IX+LVMSTACK+1)
            LD   A,D
            CP   $FF
            JR   NZ,LCSTKRET
            LD   A,E
            CP   $FE
            JP   NC,LCMAPERR
LCSTKRET:
            INC  DE
            INC  DE
            OR   A
            SBC  HL,DE
            JP   C,LCMAPERR
LCSTKRDY:
            LD   A,(LVROM)
            OR   A
            JR   NZ,LCVALROM
            LD   A,(IX+LVMDLBNK)
            OR   A
            JP   NZ,LCMAPERR
            LD   L,(IX+LVMDLADR)
            LD   H,(IX+LVMDLADR+1)
            LD   DE,(LVWRBASE)
            OR   A
            SBC  HL,DE
            JP   NZ,LCMAPERR
            RET
LCVALROM:
            LD   A,(LVPRFLAG)
            BIT  0,A
            JR   Z,LCROMBNK
            LD   A,(IX+LVMDLBNK)
            LD   B,A
            LD   A,(LVENTBNK)
            CP   B
            JP   NZ,LCMAPERR
LCROMBNK:
            LD   A,(IX+LVMDLBNK)
            LD   B,A
            LD   A,(LVBKCNT)
            DEC  A
            CP   B
            JP   C,LCMAPERR
            OR   A
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX
LCMAPBNK:
            CALL LCMBKPTR
            PUSH HL
            POP  IX
            XOR  A
            LD   (LVCURBNK),A
LCMAPBLP:
            LD   L,(IX+0)
            LD   H,(IX+1)                ; used length
            LD   A,H
            OR   L
            JP   Z,LCMAPERR
            LD   DE,(LVIMCAP)
            PUSH HL
            OR   A
            SBC  HL,DE
            POP  HL
            JR   C,LCMAPCAP
            JP   NZ,LCMAPERR
LCMAPCAP:
            PUSH HL
            LD   A,(LVCURBNK)
            CALL LCEXPUSD
            EX   DE,HL                    ; DE=expected
            POP  HL                      ; HL=map used
            OR   A
            SBC  HL,DE
            JP   NZ,LCMAPERR

            LD   E,2
            CALL LCMAPOPT
            JP   C,LCMAPERR

            LD   E,6
            CALL LCMAPOPT
            JP   C,LCMAPERR
            LD   A,D
            OR   E
            JR   Z,LCMAPAGG
            LD   A,(IX+4)
            OR   (IX+5)
            JP   Z,LCMAPERR
            ; aggregateBase >= readOnlyBase
            LD   L,C
            LD   H,B
            LD   E,(IX+2)
            LD   D,(IX+3)
            OR   A
            SBC  HL,DE
            JP   C,LCMAPERR
            ; aggregate offset within read-only plus its length.
            LD   E,(IX+8)
            LD   D,(IX+9)
            ADD  HL,DE
            JP   C,LCMAPERR
            LD   E,(IX+4)
            LD   D,(IX+5)
            OR   A
            SBC  HL,DE
            JR   C,LCMAPAGG
            JP   NZ,LCMAPERR
LCMAPAGG:
            LD   DE,10
            ADD  IX,DE
            LD   A,(LVCURBNK)
            INC  A
            LD   (LVCURBNK),A
            LD   B,A
            LD   A,(LVBKCNT)
            CP   B
            JP   NZ,LCMAPBLP

            LD   A,(LVROM)
            OR   A
            JR   NZ,LCROMMAP
            JR   LCLOADEN
LCROMMAP:
            JP   LCROMEXT

; E=base-field offset within the current ten-byte bank entry; IX=entry.
; Returns BC=base and DE=length so the caller can continue validating the
; selected extent. IX is preserved.
; Contract: in E,IX out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
LCMAPOPT:
            PUSH IX
            POP  HL
            LD   D,0
            ADD  HL,DE
            LD   C,(HL)
            INC  HL
            LD   B,(HL)
            INC  HL
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            LD   L,(IX+0)
            LD   H,(IX+1)                ; used length
            PUSH BC
            PUSH DE
            CALL LCVALEXT
            POP  DE
            POP  BC
            RET

; HL=used length, BC=optional base, DE=optional length.
; Contract: in BC,DE,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
LCVALEXT:
            LD   A,D
            OR   E
            JR   NZ,LCEXTPRS
            LD   A,B
            OR   C
            RET  Z
            SCF
            RET
LCEXTPRS:
            PUSH HL                      ; used length
            LD   H,B
            LD   L,C
            LD   BC,(LVIMBASE)
            OR   A
            SBC  HL,BC                   ; offset
            JR   C,LCEXTPOP
            ADD  HL,DE
            JR   C,LCEXTPOP
            POP  DE                      ; used length
            OR   A
            SBC  HL,DE
            JR   C,LCEXTOK
            RET  Z
            SCF
            RET
LCEXTPOP:
            POP  HL
            SCF
            RET
LCEXTOK:
            OR   A
            RET

; Contract: out A,HL,carry clobbers halfCarry,DE
LCMBKPTR:
            LD   A,(LVMAPBUF+LVMPARTS)
            LD   E,A
            LD   D,0
            LD   HL,LVMAPBUF+30
            ADD  HL,DE
            RET

; Contract: in A out A,HL,carry,zero clobbers sign,parity,halfCarry,BC,DE
LCEXPUSD:
            PUSH AF
            LD   HL,LVIMENDS
            CALL LCBKWORD
            LD   C,(HL)
            INC  HL
            LD   B,(HL)
            POP  AF
            LD   HL,LVPATEND
            CALL LCBKWORD
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            LD   H,B
            LD   L,C
            OR   A
            SBC  HL,DE
            JR   C,LCEXPPAT
            LD   H,B
            LD   L,C
            RET
LCEXPPAT:
            LD   H,D
            LD   L,E
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
LCLOADEN:
            CALL LCMBKPTR
            LD   C,(HL)
            INC  HL
            LD   B,(HL)                  ; bank zero used length
            LD   HL,(LVWRBASE)
            LD   DE,(LVIMBASE)
            OR   A
            SBC  HL,DE
            PUSH BC
            LD   DE,LVMAPBUF+LVMILEN
            LD   A,(DE)
            INC  DE
            LD   C,A
            LD   A,(DE)
            LD   D,A
            LD   E,C
            ADD  HL,DE
            POP  BC
            JP   C,LCMAPERR
            OR   A
            SBC  HL,BC
            JP   NZ,LCMAPERR
            LD   HL,(LVIMBASE)
            LD   DE,(LVWRBASE)
            OR   A
            SBC  HL,DE
            JP   NC,LCMAPERR
            OR   A
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
LCROMEXT:
            LD   A,(LVMAPBUF+LVMDLBNK)
            LD   C,A
            CALL LCMBKPTR
            LD   A,C
            OR   A
            JR   Z,LCROMENT
            LD   DE,10
LCROMSEK:
            ADD  HL,DE
            DEC  A
            JR   NZ,LCROMSEK
LCROMENT:
            LD   C,(HL)
            INC  HL
            LD   B,(HL)                  ; used length
            LD   HL,(LVMAPBUF+LVMDLADR)
            LD   DE,(LVIMBASE)
            OR   A
            SBC  HL,DE
            JP   C,LCMAPERR
            LD   DE,(LVMAPBUF+LVMDLLEN)
            ADD  HL,DE
            JP   C,LCMAPERR
            OR   A
            SBC  HL,BC
            JR   C,LCROMFIT
            JP   NZ,LCMAPERR
LCROMFIT:
            OR   A
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
LCCOMMIT:
            LD   A,(LVPHASE)
            CP   LVPMAP
            JP   NZ,LCORDERR
            LD   HL,(LVPLEN)
            LD   DE,7
            OR   A
            SBC  HL,DE
            JP   NZ,LCFRMERR
            CALL LCRCRCW          ; record count
            RET  C
            LD   DE,(LVRECNO)
            OR   A
            SBC  HL,DE
            JR   NZ,LCCOMERR
            CALL LCRCRCB          ; entry bank
            RET  C
            LD   B,A
            LD   A,(LVENTBNK)
            CP   B
            JR   NZ,LCCOMERR
            CALL LCRCRCW          ; canonical entry address
            RET  C
            LD   DE,(LVIMBASE)
            OR   A
            SBC  HL,DE
            JR   NZ,LCCOMERR
            CALL LCREQBYT          ; stored CRC is excluded from CRC
            RET  C
            PUSH AF
            CALL LCREQBYT
            JR   C,LCCOMCRF
            LD   H,A
            POP  AF
            LD   L,A
            LD   DE,(LVCRC)
            OR   A
            SBC  HL,DE
            JR   NZ,LCCRCERR
            CALL LCEXPEOF
            RET  C
            LD   A,LVPCOMIT
            LD   (LVPHASE),A
            OR   A
            RET
LCCOMCRF:
            POP  HL
            SCF
            RET
LCCOMERR:
            LD   A,LVSCOMIT
            JP   LCSETVF
LCCRCERR:
            LD   A,LVSCRC
            JP   LCSETVF

; Contract: out A,carry,zero clobbers sign,parity,halfCarry
LCEXPEOF:
            CALL LVREAD
            JR   NC,LCTRAIL
            CP   LVPLEND
            JR   NZ,LCEOFFL
            OR   A
            RET
LCTRAIL:
            LD   A,LVSTRAIL
            JP   LCSETVF
LCEOFFL:
            JP   LCSETPF

; Fill every selected bank before the one materializing read. The destination
; remains unpublished until COMMIT and immediate EOF have passed.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX
LCFILL:
            XOR  A
            LD   (LVCURBNK),A
LCFILLBK:
            LD   A,(LVCURBNK)
            LD   IX,(LVSPPTR)
            CALL LVSELECT
            JR   C,LCFILLFL
            LD   HL,(LVIMBASE)
            LD   BC,(LVIMCAP)
            LD   A,(LVFILL)
LCFILLBY:
            LD   (HL),A
            INC  HL
            DEC  BC
            LD   D,A
            LD   A,B
            OR   C
            LD   A,D
            JR   NZ,LCFILLBY
            LD   A,(LVCURBNK)
            INC  A
            LD   (LVCURBNK),A
            LD   B,A
            LD   A,(LVBKCNT)
            CP   B
            JR   NZ,LCFILLBK
            OR   A
            RET
LCFILLFL:
            JP   LCSETPF
