; Direct-Z80 encoder for the first checked four-operation stream.

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EncodeSemanticProgram:
            LD   HL,ProgramTemplate
            LD   DE,MMGEN
            LD   BC,PGSZ
            LDIR
            LD   A,(SMBUFBAS+2)
            LD   (MMGEN+1),A
            LD   HL,PGSZ
            LD   (GNSZ),HL
            OR   A
            RET
