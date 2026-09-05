; Checked semantic-operation transcript used by the direct-Z80 encoders. The
; leading byte is the operation count.

; ABI: out carry,zero clobbers sign,parity,halfCarry,A,HL
TMRESET:
            LD   HL,SMBUFBAS+1
            LD   (SKCUR),HL
            XOR  A
            LD   (SKOPCNT),A
            LD   (SMBUFBAS),A
            RET

; ABI: in A out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
TMPUT:
            LD   B,A
            LD   HL,(SKCUR)
            LD   DE,SMBUFLIM
            LD   A,H
            CP   D
            JR   NZ,TMPUTOK
            LD   A,L
            CP   E
            JR   Z,TMPUTFUL
TMPUTOK:
            LD   A,B
            LD   (HL),A
            INC  HL
            LD   (SKCUR),HL
            OR   A
            RET
TMPUTFUL:
            LD   A,DGSNKCAP
            JP   DGSET

; ABI: in A out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
ESKEMIT:
            LD   C,A
            LD   A,SMLDU8
            CALL TMPUT
            RET  C
            LD   A,C
            CALL TMPUT
            RET  C
            LD   A,SMWROBYT
            CALL TMPUT
            RET  C
            LD   A,SMPROP
            CALL TMPUT
            RET  C
            LD   A,SMRET
            CALL TMPUT
            RET  C
            LD   A,4
            LD   (SKOPCNT),A
            LD   (SMBUFBAS),A
            OR   A
            RET
