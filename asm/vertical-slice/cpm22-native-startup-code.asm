; CP/M transient entry, diagnostic printer, and fixed flat-target descriptor.

CUSTART:
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CUENTRY:
            ; The CCP stack lives inside the resident CP/M image and is far too
            ; small for the compiler. This transient is writable and cannot be
            ; re-entered, so retain the caller stack in one immediate operand
            ; and give the complete compilation its reserved stack.
            LD   (CURESTSP+1),SP
            LD   SP,STACKTOP
            CALL CURUN
CURESTSP:
            LD   SP,0
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CURUN:
            CALL CCPREP
            JR   C,CUHOSTER
            LD   A,(CCHELP)
            OR   A
            JR   NZ,CUHELP
            CALL CSBEGIN
            JR   C,CUHOSTER
            CALL PBPREP
            JR   C,CUHOSTER
            LD   A,(CSPARTN)
            LD   HL,0
            LD   IX,CUTARG
            CALL CTACPART
            JR   C,CUFAIL
            XOR  A
            RET

CUHELP:
            LD   DE,CUHELPXT
            CALL CUPRTXT
            XOR  A
            RET

CUFAIL:
            CALL DOABORT
            LD   A,(SSHOST)
            OR   A
            JR   NZ,CUHOSTER
            JR   CUDIAG

; Contract: in A out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CUHOSTER:
            PUSH AF
            LD   DE,CUHTEXT
            CALL CUPRTXT
            POP  AF
            CALL CUPRBYTE
            JR   CUPRNL

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CUDIAG:
            LD   DE,CUDTEXT
            CALL CUPRTXT
            LD   A,(DGCODE)
            CALL CUPRBYTE
            LD   DE,CUPTEXT
            CALL CUPRTXT
            LD   A,(DGPARTID)
            CALL CUPRBYTE
            LD   DE,CUOTEXT
            CALL CUPRTXT
            LD   HL,(DGOFF)
            CALL CUPRWORD
            LD   DE,CULTEXT
            CALL CUPRTXT
            LD   HL,(DGLINE)
            CALL CUPRWORD
            LD   DE,CUCTEXT
            CALL CUPRTXT
            LD   HL,(DGCOL)
            CALL CUPRWORD

CUPRNL:
            LD   DE,CUNL
; Contract: in DE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CUPRTXT:
            LD   C,9
            JP   BDOSCALL

; Contract: in HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CUPRWORD:
            PUSH HL
            LD   A,H
            CALL CUPRBYTE
            POP  HL
            LD   A,L
            JP   CUPRBYTE

; Contract: in A out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CUPRBYTE:
            PUSH AF
            RRCA
            RRCA
            RRCA
            RRCA
            CALL CUPRNIB
            POP  AF
; Contract: in A out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CUPRNIB:
            AND  $0F
            ADD  A,$30
            CP   $3A
            JR   C,CUPRDIG
            ADD  A,7
CUPRDIG:
            LD   E,A
            LD   C,2
            JP   BDOSCALL
CUSTAEND:
