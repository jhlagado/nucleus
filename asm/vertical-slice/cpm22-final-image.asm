; Intel HEX renderer for finalized native images. The including publisher
; supplies the ZTS_CPM_FINAL_* aliases so the renderer stays independent of
; the compiler, filesystem transaction, and target memory layout.

.routine out A clobbers carry,zero,sign,parity,halfCarry,HL
ZTS_CPM_HEX_BEGIN:
            LD   HL,ZTS_CPM_FINAL_DMA
            LD   (ZTS_CPM_FINAL_DMA_CURSOR),HL
            XOR  A
            LD   (ZTS_CPM_FINAL_DMA_COUNT),A
            LD   (ZTS_CPM_FINAL_ERROR),A
            RET

.routine out A,carry clobbers zero,sign,parity,halfCarry,BC,DE,HL
ZTS_CPM_HEX_SEGMENT:
            LD   HL,(ZTS_CPM_FINAL_REMAINING)
            LD   A,H
            OR   L
            RET  Z
            LD   A,H
            OR   A
            LD   A,16
            JR   NZ,ZTS_CPM_HEX_SIZE_READY
            LD   A,L
            CP   16
            JR   C,ZTS_CPM_HEX_SIZE_READY
            LD   A,16
ZTS_CPM_HEX_SIZE_READY:
            LD   (ZTS_CPM_FINAL_SIZE),A
            LD   (ZTS_CPM_FINAL_DATA_LEFT),A
            LD   A,':'
            CALL ZTS_CPM_HEX_PUT
            XOR  A
            LD   (ZTS_CPM_FINAL_SUM),A
            LD   A,(ZTS_CPM_FINAL_SIZE)
            CALL ZTS_CPM_HEX_FIELD
            LD   HL,(ZTS_CPM_FINAL_ADDRESS)
            PUSH HL
            LD   A,H
            CALL ZTS_CPM_HEX_FIELD
            POP  HL
            LD   A,L
            CALL ZTS_CPM_HEX_FIELD
            XOR  A
            CALL ZTS_CPM_HEX_FIELD
ZTS_CPM_HEX_DATA:
            LD   A,(ZTS_CPM_FINAL_DATA_LEFT)
            OR   A
            JR   Z,ZTS_CPM_HEX_CHECKSUM
            LD   HL,(ZTS_CPM_FINAL_SOURCE_CURSOR)
            LD   A,(HL)
            INC  HL
            LD   (ZTS_CPM_FINAL_SOURCE_CURSOR),HL
            CALL ZTS_CPM_HEX_FIELD
            LD   A,(ZTS_CPM_FINAL_DATA_LEFT)
            DEC  A
            LD   (ZTS_CPM_FINAL_DATA_LEFT),A
            JR   ZTS_CPM_HEX_DATA
ZTS_CPM_HEX_CHECKSUM:
            LD   A,(ZTS_CPM_FINAL_SUM)
            NEG
            CALL ZTS_CPM_HEX_BYTE
            LD   A,13
            CALL ZTS_CPM_HEX_PUT
            LD   A,10
            CALL ZTS_CPM_HEX_PUT
            LD   A,(ZTS_CPM_FINAL_SIZE)
            LD   E,A
            LD   D,0
            LD   HL,(ZTS_CPM_FINAL_REMAINING)
            OR   A
            SBC  HL,DE
            LD   (ZTS_CPM_FINAL_REMAINING),HL
            LD   HL,(ZTS_CPM_FINAL_ADDRESS)
            ADD  HL,DE
            LD   (ZTS_CPM_FINAL_ADDRESS),HL
            JR   ZTS_CPM_HEX_SEGMENT

.routine out A,carry clobbers zero,sign,parity,halfCarry,BC,DE,HL
ZTS_CPM_HEX_END:
            LD   HL,ZTS_CPM_HEX_EOF_TEXT
            LD   B,13
ZTS_CPM_HEX_EOF_BYTE:
            PUSH BC
            PUSH HL
            LD   A,(HL)
            CALL ZTS_CPM_HEX_PUT
            POP  HL
            POP  BC
            INC  HL
            DJNZ ZTS_CPM_HEX_EOF_BYTE
ZTS_CPM_HEX_PAD:
            LD   A,(ZTS_CPM_FINAL_DMA_COUNT)
            OR   A
            JR   Z,ZTS_CPM_HEX_DONE
            LD   A,$1A
            CALL ZTS_CPM_HEX_PUT
            JR   ZTS_CPM_HEX_PAD
ZTS_CPM_HEX_DONE:
            LD   A,(ZTS_CPM_FINAL_ERROR)
            OR   A
            RET  Z
            SCF
            RET

.routine in A out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL
ZTS_CPM_HEX_FIELD:
            PUSH AF
            LD   E,A
            LD   A,(ZTS_CPM_FINAL_SUM)
            ADD  A,E
            LD   (ZTS_CPM_FINAL_SUM),A
            POP  AF
.routine in A out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL
ZTS_CPM_HEX_BYTE:
            PUSH AF
            RRCA
            RRCA
            RRCA
            RRCA
            CALL ZTS_CPM_HEX_NIBBLE
            POP  AF
.routine in A out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL
ZTS_CPM_HEX_NIBBLE:
            AND  $0F
            ADD  A,'0'
            CP   '9'+1
            JR   C,ZTS_CPM_HEX_PUT
            ADD  A,7
.routine in A out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL
ZTS_CPM_HEX_PUT:
            PUSH AF
            LD   A,(ZTS_CPM_FINAL_ERROR)
            OR   A
            JR   NZ,ZTS_CPM_HEX_PUT_FAILED
            POP  AF
            LD   HL,(ZTS_CPM_FINAL_DMA_CURSOR)
            LD   (HL),A
            INC  HL
            LD   (ZTS_CPM_FINAL_DMA_CURSOR),HL
            LD   A,(ZTS_CPM_FINAL_DMA_COUNT)
            INC  A
            LD   (ZTS_CPM_FINAL_DMA_COUNT),A
            CP   128
            RET  NZ
.routine out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL
ZTS_CPM_HEX_FLUSH:
            LD   DE,ZTS_CPM_FINAL_DMA
            LD   C,CpmPublishDmaFunction
            CALL BDOSCALL
            LD   DE,ZTS_CPM_FINAL_FCB
            LD   C,CpmPublishWriteFunction
            CALL BDOSCALL
            OR   A
            JR   NZ,ZTS_CPM_HEX_WRITE_FAILED
            LD   HL,ZTS_CPM_FINAL_DMA
            LD   (ZTS_CPM_FINAL_DMA_CURSOR),HL
            XOR  A
            LD   (ZTS_CPM_FINAL_DMA_COUNT),A
            RET
ZTS_CPM_HEX_WRITE_FAILED:
            LD   A,1
            LD   (ZTS_CPM_FINAL_ERROR),A
            XOR  A
            LD   (ZTS_CPM_FINAL_DMA_COUNT),A
            RET
ZTS_CPM_HEX_PUT_FAILED:
            POP  AF
            RET

ZTS_CPM_HEX_EOF_TEXT: .db ':','0','0','0','0','0','0','0','1','F','F',13,10
