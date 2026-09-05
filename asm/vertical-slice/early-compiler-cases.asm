KCCODEND:

KCIMM:
EKWSUB:
            DB  "sub"
EKWFAILS:
            DB  "fails"
EKWELSE:
            DB  "else"
EKWFAIL:
            DB  "fail"
EKWEND:
            DB  "end"
NAMEMAIN:
            DB  "main"
KWWRTOUT:
            DB  "writeOutputByte"
KCIMMEND:
KCEND:

            ORG MMSOURCE
EACCSRC:
            DB  "sub main() fails",10
            DB  "    writeOutputByte('A') else fail",10
            DB  "end",10
EACCSEND:

EBADSRC:
            DB  "sub main() fails",10
            DB  "    writeOutputByte('A') else fail",10
EBADSEND:

            ORG MMPROOF
; ABI: out carry,zero clobbers sign,parity,halfCarry,A,BC,DE,HL
FPSTART:
            LD   SP,STACKTOP
            XOR  A
            LD   (FPCASE),A
            LD   (FPSTATUS),A

            LD   A,7
            LD   HL,EACCSRC
            LD   DE,EACCSEND
            CALL ECOMPSL
            JP   C,QFACCOMP
            LD   A,(DGCODE)
            OR   A
            JP   NZ,EFACCDG
            LD   HL,SMBUFBAS
            LD   DE,EEXPOPS
            LD   B,6
            CALL QPCOBY
            JP   C,EFACCOPS

            LD   A,9
            LD   HL,EBADSRC
            LD   DE,EBADSEND
            CALL ECOMPSL
            JP   NC,QFMAAC
            LD   A,(DGCODE)
            CP   DXEND
            JP   NZ,QFMACO
            LD   A,(DGPARTID)
            CP   9
            JP   NZ,EFBADPT
            LD   HL,(DGOFF)
            LD   DE,EBADSEND-EBADSRC
            OR   A
            SBC  HL,DE
            JP   NZ,EFBADOFF
            LD   HL,(DGLINE)
            LD   DE,3
            OR   A
            SBC  HL,DE
            JP   NZ,EFBADLIN
            LD   HL,(DGCOL)
            LD   DE,1
            OR   A
            SBC  HL,DE
            JP   NZ,EFBADCOL
            LD   A,(SMBUFBAS)
            OR   A
            JP   NZ,EFBADOUT

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

QFACCOMP:
            LD   A,1
            JR   QF
EFACCDG:
            LD   A,2
            JR   QF
EFACCOPS:
            LD   A,3
            JR   QF
QFMAAC:
            LD   A,4
            JR   QF
QFMACO:
            LD   A,5
            JR   QF
EFBADPT:
            LD   A,6
            JR   QF
EFBADOFF:
            LD   A,7
            JR   QF
EFBADLIN:
            LD   A,8
            JR   QF
EFBADCOL:
            LD   A,9
            JR   QF
EFBADOUT:
            LD   A,10
QF:
            LD   (FPCASE),A
            LD   A,$E0
            LD   (FPSTATUS),A
            HALT

EEXPOPS:
            DB  4,SMLDU8,$41,SMWROBYT
            DB  SMPROP,SMRET

FPSTATUS:
            DB  0
FPCASE:
            DB  0
FPEND:

; End of source part.
