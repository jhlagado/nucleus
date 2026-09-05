; Direct-Z80 encoder for the first checked four-operation stream.

; ABI: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EENCODE:
            LD   HL,EPRGTPL
            LD   DE,MMGEN
            LD   BC,PGSZ
            LDIR
            LD   A,(SMBUFBAS+2)
            LD   (MMGEN+1),A
            LD   HL,PGSZ
            LD   (GNSZ),HL
            OR   A
            RET
