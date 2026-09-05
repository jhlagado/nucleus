RTEND:

            ORG MMPROOF
; Contract: out carry,zero clobbers sign,parity,halfCarry,A,BC,DE,HL,IX,IY
FPSTART:
            LD   SP,STACKTOP
            XOR  A
            LD   (FPCASE),A
            LD   (FPSTATUS),A
            LD   (VINFAIL),A
            LD   (SVFAIL),A

            LD   A,40
            LD   HL,QAPS
            LD   DE,QAPSE
            CALL CPSL
            JP   C,QFCOMP
            LD   HL,SMBUFBAS
            LD   DE,QXAO
            LD   B,14
            CALL QPCOBY
            JP   C,QFOP
            CALL ZEARRAY
            JP   C,QFEN
            LD   HL,(GNSZ)
            LD   DE,ARYPGSZ
            OR   A
            SBC  HL,DE
            JP   NZ,QFSI
            LD   HL,GNARREND-4
            LD   DE,QXAB
            LD   B,4
            CALL QPCOBY
            JP   C,QFSTDA

            CALL QPCOSUIN
            CALL MMGEN
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,QFSUST
            LD   A,(VOUTLEN)
            CP   1
            JP   NZ,QFSUOU
            LD   A,(VOUTBAS)
            CP   'B'
            JP   NZ,QFSUBY
            LD   A,(VINCUR)
            CP   1
            JP   NZ,QFSUIN

            CALL QPCOBOIN
            CALL MMGEN
            LD   A,(RUNSTATE)
            CP   RTTRAP
            JP   NZ,QFBOST
            LD   A,(RTTRPNO)
            CP   1
            JP   NZ,QFBOTR
            LD   HL,(RTTRPOFF)
            LD   DE,ARYBOFF
            OR   A
            SBC  HL,DE
            JP   NZ,QFBOOF
            LD   A,(VOUTLEN)
            OR   A
            JP   NZ,QFBOOU
            LD   A,(VINCUR)
            CP   1
            JP   NZ,QFBOIN

            CALL QPCONOIN
            CALL MMGEN
            LD   A,(RUNSTATE)
            CP   RTTRAP
            JP   NZ,QFINST
            LD   A,(RTTRPNO)
            CP   6
            JP   NZ,QFINTR
            LD   A,(RTTRPERR)
            CP   1
            JP   NZ,QFINER
            LD   HL,(RTTRPOFF)
            LD   DE,ARYIFAIL
            OR   A
            SBC  HL,DE
            JP   NZ,QFINOF
            LD   A,(VOUTLEN)
            OR   A
            JP   NZ,QFINOU
            LD   A,(VINCUR)
            OR   A
            JP   NZ,QFINCU

            CALL QPCOOUFA
            CALL MMGEN
            LD   A,(RUNSTATE)
            CP   RTTRAP
            JP   NZ,QFOUST
            LD   A,(RTTRPNO)
            CP   6
            JP   NZ,QFOUTR
            LD   A,(RTTRPERR)
            CP   3
            JP   NZ,QFOUER
            LD   HL,(RTTRPOFF)
            LD   DE,ARYOFAIL
            OR   A
            SBC  HL,DE
            JP   NZ,QFOUOF
            LD   A,(VOUTLEN)
            OR   A
            JP   NZ,QFOUAT

            LD   A,41
            LD   HL,QBAS
            LD   DE,QBASE
            CALL CPSL
            JP   NC,QFBAAC
            LD   A,(DGCODE)
            CP   DXCOMMA
            JP   NZ,QFBACO
            LD   HL,(DGOFF)
            LD   DE,QBAV-QBAS
            OR   A
            SBC  HL,DE
            JP   NZ,QFBAPO
            LD   HL,(DGLINE)
            LD   DE,1
            OR   A
            SBC  HL,DE
            JP   NZ,QFBAPO
            LD   HL,(DGCOL)
            LD   DE,QBAV-QBAS+1
            OR   A
            SBC  HL,DE
            JP   NZ,QFBAPO

            LD   A,$5A
            LD   (RUNSTATE),A
            LD   A,40
            LD   HL,QAPS
            LD   DE,QAPSE
            CALL CPSL
            JP   C,QFCOMP
            LD   HL,MMGEN+10
            CALL ZEARRLIM
            JP   NC,QFCAPACC
            LD   A,(DGCODE)
            CP   DGSNKCAP
            JP   NZ,QFCACO
            LD   HL,(GNSZ)
            LD   DE,ARYPGSZ
            OR   A
            SBC  HL,DE
            JP   NZ,QFCAPU
            LD   HL,MMGEN
            LD   DE,MMBACK
            LD   B,ARYPGSZ
            CALL QPCOBY
            JP   C,QFCAPU
            LD   A,(RUNSTATE)
            CP   $5A
            JP   NZ,QFCAST

            ; Leave the complete Z80 program available for host inspection.
            LD   A,40
            LD   HL,QAPS
            LD   DE,QAPSE
            CALL CPSL
            JP   C,QFCOMP
            CALL ZEARRAY
            JP   C,QFEN

            LD   A,$A5
            LD   (FPSTATUS),A
            HALT

; Contract: out carry,zero clobbers sign,parity,halfCarry,A,B,C,HL
QPCOSUIN:
            CALL RESET
            XOR  A
            LD   (VINFAIL),A
            LD   (SVFAIL),A
            INC  A
            LD   (VINLEN),A
            LD   (VINBAS),A
            RET

; Contract: out carry,zero clobbers sign,parity,halfCarry,A,B,C,HL
QPCOBOIN:
            CALL RESET
            XOR  A
            LD   (VINFAIL),A
            LD   (SVFAIL),A
            INC  A
            LD   (VINLEN),A
            LD   A,4
            LD   (VINBAS),A
            RET

; Contract: out carry,zero clobbers sign,parity,halfCarry,A,B,C,HL
QPCONOIN:
            CALL RESET
            XOR  A
            LD   (VINFAIL),A
            LD   (SVFAIL),A
            LD   (VINLEN),A
            RET

; Contract: out carry,zero clobbers sign,parity,halfCarry,A,B,C,HL
QPCOOUFA:
            CALL RESET
            XOR  A
            LD   (VINFAIL),A
            INC  A
            LD   (SVFAIL),A
            LD   (VINLEN),A
            LD   A,2
            LD   (VINBAS),A
            RET

; Contract: in B,DE,HL out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
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

QFCOMP:           LD A,1
                            JR QF
QFOP:        LD A,2
                            JR QF
QFEN:            LD A,3
                            JR QF
QFSI:              LD A,4
                            JR QF
QFSTDA:        LD A,5
                            JR QF
QFSUST:      LD A,6
                            JR QF
QFSUOU:     LD A,7
                            JR QF
QFSUIN:      LD A,8
                            JR QF
QFBOST:       LD A,9
                            JR QF
QFBOTR:        LD A,10
                            JR QF
QFBOOF:      LD A,11
                            JR QF
QFBOOU:      LD A,12
                            JR QF
QFBOIN:       LD A,13
                            JR QF
QFINST:        LD A,14
                            JR QF
QFINTR:         LD A,15
                            JR QF
QFINER:        LD A,16
                            JR QF
QFINOF:       LD A,17
                            JR QF
QFINOU:       LD A,18
                            JR QF
QFINCU:       LD A,19
                            JR QF
QFOUST:       LD A,20
                            JR QF
QFOUTR:        LD A,21
                            JR QF
QFOUER:       LD A,22
                            JR QF
QFOUOF:      LD A,23
                            JR QF
QFOUAT:      LD A,24
                            JR QF
QFBAAC:       LD A,25
                            JR QF
QFBACO:           LD A,26
                            JR QF
QFBAPO:       LD A,27
                            JR QF
QFCAPACC:  LD A,28
                            JR QF
QFCACO:      LD A,29
                            JR QF
QFCAPU: LD A,30
                            JR QF
QFCAST:     LD A,31
                            JR QF
QFSUBY:       LD A,32
QF:
            LD   (FPCASE),A
            LD   A,$E0
            LD   (FPSTATUS),A
            HALT

QXAO:
            DB 8,SMARRU8,4,65,66,67,68
            DB SMRDIBYT,SMPROP,SMSTRSU8
            DB SMLDAU8,SMWROU8
            DB SMPROP,SMRET
QXAB:     DB 65,66,67,68
FPSTATUS:            DB 0
FPCASE:              DB 0
FPEND:
