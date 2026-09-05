NHVECTOR EQU MMHOSTVC
            ORG NHVECTOR
ECHVST:
            DB "NH",0,1,8,14,0,0
; ABI: out A,C,DE,HL,carry,zero clobbers sign,parity,halfCarry,B
HVCHUNK:           JP ECLNEXT
; ABI: in HL,B,C,DE out A,HL,carry,zero clobbers sign,parity,halfCarry
HVRETAIN:         JP ECLRETN
; ABI: in HL,IX,B out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
HVCMPNAM:        JP ECLCMP
; ABI: in HL out A,B,HL,carry,zero clobbers sign,parity,halfCarry
HVMATNAM:           JP ECLMAT
; ABI: in IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
TSBEGIN:               JP ECLBEGIN
; ABI: in A,C,HL out A,carry,zero clobbers sign,parity,halfCarry,DE
TSBYTE:           JP ECLIMAGE
; ABI: in A,BC,DE,HL,IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
TSRTIMG:        JP ECLRUNT
; ABI: in A,BC,DE,HL,IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
TSRTINIT: JP ECLRUNT
; ABI: in A,C,HL out A,carry,zero clobbers sign,parity,halfCarry,DE
TSPATBYT:           JP ECLPATB
; ABI: in C,DE,HL out A,carry,zero clobbers sign,parity,halfCarry
TSPATWRD:           JP ECLPATW
; ABI: in IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
TSMAP:             JP ECLMAP
; ABI: in IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
TSBANK:           JP ECLMAP
; ABI: out A,carry,zero clobbers sign,parity,halfCarry
TSCOMMIT:              JP ECLCOMIT
; ABI: out A,carry,zero clobbers sign,parity,halfCarry
TSABORT:               JP ECLABORT
ECHVTEND:
