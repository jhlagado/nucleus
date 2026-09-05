ECHVEND:

; ABI: out A,C,DE,HL,carry,zero clobbers sign,parity,halfCarry,B
ECLNEXT:
            XOR  A
            RET
; ABI: in HL,B,C,DE out A,HL,carry,zero clobbers sign,parity,halfCarry
ECLRETN:
            XOR  A
            RET
; ABI: in HL,IX,B out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
ECLCMP:
            XOR  A
            RET
; ABI: in HL out A,B,HL,carry,zero clobbers sign,parity,halfCarry
ECLMAT:
            XOR  A
            RET
; ABI: in IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
ECLBEGIN:
            XOR  A
            RET
; ABI: in A,C,HL out A,carry,zero clobbers sign,parity,halfCarry,DE
ECLIMAGE:
ECLPATB:
            XOR  A
            RET
; ABI: in C,DE,HL out A,carry,zero clobbers sign,parity,halfCarry
ECLPATW:
            XOR  A
            RET
; ABI: in A,BC,DE,HL,IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
ECLRUNT:
            XOR  A
            RET
; ABI: in IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
ECLMAP:
            XOR  A
            RET
; ABI: out A,carry,zero clobbers sign,parity,halfCarry
ECLCOMIT:
ECLABORT:
            XOR  A
            RET
ECLEND:

; End of source part.
