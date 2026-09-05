KCIMMEND:
KCEND:

            ORG MMSOURCE
EACCLP:
            DB "sub main() fails",10
            DB "    var index as u8 = 0",10
            DB "    for index = 0 until 3",10
            DB "        writeOutputByte('A') else fail",10
            DB "    end",10
            DB "end",10
EACCLPEN:

EZEROLP:
            DB "sub main() fails",10
            DB "    var index as u8 = 0",10
            DB "    for index = 0 until 0",10
            DB "        writeOutputByte('A') else fail",10
            DB "    end",10
            DB "end",10
EZEROLEN:

ECTRWRS:
            DB "sub main() fails",10
            DB "    var index as u8 = 0",10
            DB "    for index = 0 until 3",10
ECTRWST:
            DB "        index = 1",10
            DB "    end",10
            DB "end",10
ECTRWSEN:

EMISEND:
            DB "sub main() fails",10
            DB "    var index as u8 = 0",10
            DB "    for index = 0 until 3",10
            DB "        writeOutputByte('A') else fail",10
            DB "    end",10
EMISSEND:

            ORG MMPROOF
; ABI: out carry,zero clobbers sign,parity,halfCarry,A,BC,DE,HL,IX,IY
FPSTART:
            LD   SP,STACKTOP
            XOR  A
            LD   (FPCASE),A
            LD   (FPSTATUS),A

            LD   A,10
            LD   HL,EACCLP
            LD   DE,EACCLPEN
            CALL CPLPSL
            JP   C,EFACC
            LD   HL,SMBUFBAS
            LD   DE,EEXPLPOP
            LD   B,11
            CALL QPCOBY
            JP   C,QFOP

            LD   A,11
            LD   HL,EZEROLP
            LD   DE,EZEROLEN
            CALL CPLPSL
            JP   C,EFZERO
            LD   A,(SMBUFBAS+5)
            OR   A
            JP   NZ,EFZEROB

            LD   A,12
            LD   HL,ECTRWRS
            LD   DE,ECTRWSEN
            CALL CPLPSL
            JP   NC,EFCTRACC
            LD   A,(DGCODE)
            CP   DGACTCTR
            JP   NZ,EFCTRCD
            LD   HL,(DGOFF)
            LD   DE,ECTRWST-ECTRWRS+8
            OR   A
            SBC  HL,DE
            JP   NZ,EFCTROFF

            LD   A,13
            LD   HL,EMISEND
            LD   DE,EMISSEND
            CALL CPLPSL
            JP   NC,EFMISACC
            LD   A,(DGCODE)
            CP   DXEND
            JP   NZ,EFMISCD
            LD   A,(DGPARTID)
            CP   13
            JP   NZ,EFMISPT
            LD   HL,(DGOFF)
            LD   DE,EMISSEND-EMISEND
            OR   A
            SBC  HL,DE
            JP   NZ,EFMISPOS
            LD   HL,(DGLINE)
            LD   DE,6
            OR   A
            SBC  HL,DE
            JP   NZ,EFMISPOS
            LD   HL,(DGCOL)
            LD   DE,1
            OR   A
            SBC  HL,DE
            JP   NZ,EFMISPOS

            LD   A,$A5
            LD   (FPSTATUS),A
            HALT

; ABI: in B,DE,HL out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
QPCOBY:
            LD   A,(DE)
            CP   (HL)
            JR   NZ,QPCOBYNO
            INC  DE
            INC  HL
            DJNZ QPCOBY
            OR   A
            RET
QPCOBYNO:
            SCF
            RET

EFACC:       LD A,1
                         JR QF
QFOP:     LD A,2
                         JR QF
EFZERO:           LD A,3
                         JR QF
EFZEROB:      LD A,4
                         JR QF
EFCTRACC: LD A,5
                         JR QF
EFCTRCD:    LD A,6
                         JR QF
EFCTROFF:  LD A,7
                         JR QF
EFMISACC: LD A,8
                         JR QF
EFMISCD:    LD A,9
                         JR QF
EFMISPT:    LD A,10
                         JR QF
EFMISPOS: LD A,11
QF:
            LD   (FPCASE),A
            LD   A,$E0
            LD   (FPSTATUS),A
            HALT

EEXPLPOP:
            DB 6,SMDECLU8,0,SMFORU8,0,3
            DB SMWROBYT,$41,SMPROP
            DB SMENDLP,SMRET
FPSTATUS:             DB 0
FPCASE:               DB 0
FPEND:

; End of source part.
