; Intel HEX renderer for finalized native images. The including publisher
; supplies the HXF* bindings so the renderer stays independent of
; the compiler, filesystem transaction, and target memory layout.

; Contract: out A clobbers carry,zero,sign,parity,halfCarry,HL
HXBEGIN:
            LD   HL,HXFDMA
            LD   (HXFDMCUR),HL
            XOR  A
            LD   (HXFDMCNT),A
            LD   (HXFERROR),A
            RET

; Contract: out A,carry clobbers zero,sign,parity,halfCarry,BC,DE,HL
HXSEG:
            LD   HL,(HXFLEFT)
            LD   A,H
            OR   L
            RET  Z
            LD   A,H
            OR   A
            LD   A,16
            JR   NZ,HXSIZOK
            LD   A,L
            CP   16
            JR   C,HXSIZOK
            LD   A,16
HXSIZOK:
            LD   (HXFSIZE),A
            LD   (HXFDLEFT),A
            LD   A,':'
            CALL HXPUT
            XOR  A
            LD   (HXFSUM),A
            LD   A,(HXFSIZE)
            CALL HXFIELD
            LD   HL,(HXFADDR)
            PUSH HL
            LD   A,H
            CALL HXFIELD
            POP  HL
            LD   A,L
            CALL HXFIELD
            XOR  A
            CALL HXFIELD
HXDATA:
            LD   A,(HXFDLEFT)
            OR   A
            JR   Z,HXCHKSUM
            LD   HL,(HXFSRC)
            LD   A,(HL)
            INC  HL
            LD   (HXFSRC),HL
            CALL HXFIELD
            LD   A,(HXFDLEFT)
            DEC  A
            LD   (HXFDLEFT),A
            JR   HXDATA
HXCHKSUM:
            LD   A,(HXFSUM)
            NEG
            CALL HXBYTE
            LD   A,13
            CALL HXPUT
            LD   A,10
            CALL HXPUT
            LD   A,(HXFSIZE)
            LD   E,A
            LD   D,0
            LD   HL,(HXFLEFT)
            OR   A
            SBC  HL,DE
            LD   (HXFLEFT),HL
            LD   HL,(HXFADDR)
            ADD  HL,DE
            LD   (HXFADDR),HL
            JR   HXSEG

; Contract: out A,carry clobbers zero,sign,parity,halfCarry,BC,DE,HL
HXEND:
            LD   HL,HXEOFTXT
            LD   B,13
HXEOFBYT:
            PUSH BC
            PUSH HL
            LD   A,(HL)
            CALL HXPUT
            POP  HL
            POP  BC
            INC  HL
            DJNZ HXEOFBYT
HXPAD:
            LD   A,(HXFDMCNT)
            OR   A
            JR   Z,HXDONE
            LD   A,$1A
            CALL HXPUT
            JR   HXPAD
HXDONE:
            LD   A,(HXFERROR)
            OR   A
            RET  Z
            SCF
            RET

; Contract: in A out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL
HXFIELD:
            PUSH AF
            LD   E,A
            LD   A,(HXFSUM)
            ADD  A,E
            LD   (HXFSUM),A
            POP  AF
; Contract: in A out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL
HXBYTE:
            PUSH AF
            RRCA
            RRCA
            RRCA
            RRCA
            CALL HXNIBBLE
            POP  AF
; Contract: in A out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL
HXNIBBLE:
            AND  $0F
            ADD  A,'0'
            CP   '9'+1
            JR   C,HXPUT
            ADD  A,7
; Contract: in A out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL
HXPUT:
            PUSH AF
            LD   A,(HXFERROR)
            OR   A
            JR   NZ,HXPTFAIL
            POP  AF
            LD   HL,(HXFDMCUR)
            LD   (HL),A
            INC  HL
            LD   (HXFDMCUR),HL
            LD   A,(HXFDMCNT)
            INC  A
            LD   (HXFDMCNT),A
            CP   128
            RET  NZ
; Contract: out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL
HXFLUSH:
            LD   DE,HXFDMA
            LD   C,PBFDMA
            CALL BDOSCALL
            LD   DE,HXFFCB
            LD   C,PBFWRITE
            CALL BDOSCALL
            OR   A
            JR   NZ,HXWRFAIL
            LD   HL,HXFDMA
            LD   (HXFDMCUR),HL
            XOR  A
            LD   (HXFDMCNT),A
            RET
HXWRFAIL:
            LD   A,1
            LD   (HXFERROR),A
            XOR  A
            LD   (HXFDMCNT),A
            RET
HXPTFAIL:
            POP  AF
            RET

HXEOFTXT: DB ':','0','0','0','0','0','0','0','1','F','F',13,10
