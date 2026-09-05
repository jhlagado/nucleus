; Checked semantic-operation transcript used by the direct-Z80 encoders. The
; leading byte is the operation count.

.routine out carry,zero clobbers sign,parity,halfCarry,A,HL
SemanticSinkReset:
            LD   HL,SMBUFBAS+1
            LD   (SKCUR),HL
            XOR  A
            LD   (SKOPCNT),A
            LD   (SMBUFBAS),A
            RET

.routine in A out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
SemanticSinkPut:
            LD   B,A
            LD   HL,(SKCUR)
            LD   DE,SMBUFLIM
            LD   A,H
            CP   D
            JR   NZ,SemanticSinkPutRoom
            LD   A,L
            CP   E
            JR   Z,SemanticSinkPutFull
SemanticSinkPutRoom:
            LD   A,B
            LD   (HL),A
            INC  HL
            LD   (SKCUR),HL
            OR   A
            RET
SemanticSinkPutFull:
            LD   A,DGSNKCAP
            JP   DGSET

.routine in A out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
SemanticSinkEmitProgram:
            LD   C,A
            LD   A,SMLDU8
            CALL SemanticSinkPut
            RET  C
            LD   A,C
            CALL SemanticSinkPut
            RET  C
            LD   A,SMWROBYT
            CALL SemanticSinkPut
            RET  C
            LD   A,SMPROP
            CALL SemanticSinkPut
            RET  C
            LD   A,SMRET
            CALL SemanticSinkPut
            RET  C
            LD   A,4
            LD   (SKOPCNT),A
            LD   (SMBUFBAS),A
            OR   A
            RET
