NNCEND:

            ORG LVPLBASE
NNPSTART:
            DB  "NC",0,1,8,8,0,0
            ; Start an explicit code section after the eight-byte header.
            ORG LVPLBASE+8
            JP   NNOPEN
            JP   NNREAD
            JP   NNREWIND
            JP   NNLOCK
            JP   NNSELECT
            JP   NNPUBL
            JP   NNENTER
            JP   NNCLOSE

; Contract: in HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
NNOPEN:
            LD   C,NSLDOPEN
            RST  $10
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry
NNREAD:
            PUSH BC
            LD   C,NSLDREAD
            RST  $10
            POP  BC
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
NNREWIND:
            LD   C,NSLDREW
            RST  $10
            RET

; Contract: out A,DE,HL,carry,zero clobbers sign,parity,halfCarry,BC
NNLOCK:
            LD   C,NSLDLOCK
            RST  $10
            RET

; Contract: in A,IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
NNSELECT:
            LD   C,NSMONBNK
            RST  $10
            RET

; Contract: in A,BC,DE,HL,IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX
NNPUBL:
            LD   (NNINBC),BC
            LD   C,NSLDPUBL
            RST  $10
            RET

; Contract: in A,HL,IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX
NNENTER:
            PUSH HL
            LD   C,NSLDENT
            RST  $10
            POP  HL
            RET  C
            JP   (HL)

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
NNCLOSE:
            LD   C,NSLDCLOS
            RST  $10
            RET
NNINBC:
            DW  0
NNPEND:

            ORG NNSVCBAS
NNSVCVEC:
            JP   NNRDIN
            JP   NNWRITE
            JP   NNRDSTOR
            JP   NNREW
            JP   NNWRSTOR
            JP   NNSEEK
            JP   NNSUCC
            JP   NNFAIL
            JP   NNTRAP
            JP   NNFARCL
            JP   NNFARJP
            JP   NNPACKET

NNRDIN:
            PUSH BC
            LD   C,NSRDIN
            RST  $10
            POP  BC
            RET
NNWRITE:
            PUSH BC
            LD   C,NSWROUT
            RST  $10
            POP  BC
            RET
NNRDSTOR:
            PUSH BC
            LD   C,NSRDSTOR
            RST  $10
            POP  BC
            RET
NNREW:
            PUSH BC
            LD   C,NSREWIND
            RST  $10
            POP  BC
            RET
NNWRSTOR:
            PUSH BC
            LD   C,NSWRSTOR
            RST  $10
            POP  BC
            RET
NNSEEK:
            PUSH BC
            LD   C,NSSEEK
            RST  $10
            POP  BC
            RET
NNSUCC:
            LD   C,NSSUCC
            RST  $10
            HALT
NNFAIL:
            LD   C,NSFAIL
            RST  $10
            HALT
NNTRAP:
            LD   C,NSTRAP
            RST  $10
            HALT
NNFARCL:
            LD   (NNTGTBNK),A
            LD   (NNTGTADR),HL
            LD   HL,(NNRTBASE)
            LD   DE,6
            ADD  HL,DE
            LD   A,(HL)
            DEC  A
            CP   8
            JP   NC,NNTRAP
            LD   (NNFARSLO),A
            LD   E,A
            LD   D,0
            LD   HL,(NNRTBASE)
            ADD  HL,DE
            LD   DE,9
            ADD  HL,DE
            PUSH HL
            LD   HL,(NNRTBASE)
            LD   DE,8
            ADD  HL,DE
            LD   A,(HL)
            POP  HL
            LD   (HL),A
            POP  DE
            LD   A,(NNFARSLO)
            ADD  A,A
            LD   C,A
            LD   B,0
            LD   HL,(NNRTBASE)
            ADD  HL,BC
            LD   BC,21
            ADD  HL,BC
            LD   (HL),E
            INC  HL
            LD   (HL),D
            LD   HL,NNFARRET
            PUSH HL
            LD   A,(NNTGTBNK)
            CALL NNBANK
            JP   C,NNTRAP
            LD   HL,(NNTGTADR)
            JP   (HL)
NNFARJP:
            CALL NNBANK
            JP   C,NNTRAP
            JP   (HL)
NNPACKET:
            LD   (NNPRGBC),BC
            LD   C,NSPACKET
            RST  $10
            RET
NNFARRET:
            PUSH HL
            PUSH AF
            LD   HL,(NNRTBASE)
            LD   DE,6
            ADD  HL,DE
            LD   A,(HL)
            DEC  A
            CP   8
            JP   NC,NNTRAP
            LD   (NNFARSLO),A
            LD   E,A
            LD   D,0
            LD   HL,(NNRTBASE)
            ADD  HL,DE
            LD   DE,9
            ADD  HL,DE
            LD   A,(HL)
            CALL NNBANK
            JP   C,NNTRAP
            LD   A,(NNFARSLO)
            ADD  A,A
            LD   C,A
            LD   B,0
            LD   HL,(NNRTBASE)
            ADD  HL,BC
            LD   BC,21
            ADD  HL,BC
            LD   C,(HL)
            INC  HL
            LD   B,(HL)
            POP  AF
            POP  HL
            PUSH BC
            RET
; Contract: in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E
NNBANK:
            LD   (NNTGTBNK),A
            LD   C,NSMONBNK
            RST  $10
            RET  C
            PUSH HL
            LD   HL,(NNRTBASE)
            LD   DE,8
            ADD  HL,DE
            LD   A,(NNTGTBNK)
            LD   (HL),A
            POP  HL
            OR   A
            RET
NNRTBASE:
            DW  0
NNPRGBC:
            DW  0
NNTGTADR:
            DW  0
NNTGTBNK:
            DB  0
NNFARSLO:
            DB  0
NNSVCEND:
