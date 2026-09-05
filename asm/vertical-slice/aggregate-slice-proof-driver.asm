RTEND:

            ORG MMPROOF
; Contract: out carry,zero clobbers sign,parity,halfCarry,A,BC,DE,HL,IX,IY
FPSTART:
            LD   SP,STACKTOP
            XOR  A
            LD   (FPCASE),A
            LD   (FPSTATUS),A
            LD   A,130
            LD   HL,QGAS
            LD   DE,QGASE
            CALL CPAGSL
            JP   C,QFACCOMP
            LD   A,(IMGLEN)
            CP   QGIMGLEN
            JP   NZ,QFSTLEN
            LD   HL,IMGBAS
            LD   DE,QGEI
            LD   B,QGIMGLEN
            CALL QPCOBY
            JP   C,QFSTBY
            ; Pixel offsets 0,1,2 and Entry offsets 0,2,5,11.
            LD   A,(AFTABBAS+AFOFF)
            OR   A
            JP   NZ,QFLA
            LD   A,(AFTABBAS+AFENTSZ+AFOFF)
            CP   1
            JP   NZ,QFLA
            LD   A,(AFTABBAS+AFENTSZ*2+AFOFF)
            CP   2
            JP   NZ,QFLA
            LD   A,(AFTABBAS+AFENTSZ*3+AFOFF)
            OR   A
            JP   NZ,QFLA
            LD   A,(AFTABBAS+AFENTSZ*4+AFOFF)
            CP   2
            JP   NZ,QFLA
            LD   A,(AFTABBAS+AFENTSZ*5+AFOFF)
            CP   5
            JP   NZ,QFLA
            LD   A,(AFTABBAS+AFENTSZ*6+AFOFF)
            CP   11
            JP   NZ,QFLA
            LD   A,(ATCNT)
            CP   5
            JP   NZ,QFLA
            LD   A,(ARCNT)
            CP   2
            JP   NZ,QFLA
            LD   A,(AFCNT)
            CP   7
            JP   NZ,QFLA
            LD   A,(SYTABBAS+SYENTSZ*2+SYTYPID)
            CP   AGDYNTYP+3
            JP   NZ,QFLA
            LD   A,(SYTABBAS+SYENTSZ*3+SYTYPID)
            CP   AGDYNTYP+3
            JP   NZ,QFLA
            LD   A,(SYTABBAS+SYENTSZ*4+SYTYPID)
            CP   AGDYNTYP+4
            JP   NZ,QFLA
            LD   A,(SYTABBAS+SYENTSZ*2+3)
            CP   SIAGPROG
            JP   NZ,QFLA
            LD   HL,(SYTABBAS+SYENTSZ*2+4)
            LD   A,H
            OR   L
            JP   NZ,QFLA
            LD   HL,(SYTABBAS+SYENTSZ*3+4)
            LD   DE,14
            OR   A
            SBC  HL,DE
            JP   NZ,QFLA
            LD   HL,(SYTABBAS+SYENTSZ*4+4)
            LD   DE,28
            OR   A
            SBC  HL,DE
            JP   NZ,QFLA
            CALL ZGPROG
            JP   C,QFACEN
            LD   HL,MMGEN+3
            LD   DE,QGEI
            LD   B,QGIMGLEN
            CALL QPCOBY
            JP   C,QFPUBY
            CALL RESET
            CALL QPCAGE
            JP   C,QFFR
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,QFRUST

            ; Force a failure during the static-image copy. The transactional
            ; publisher must restore the complete prior image and size. Change
            ; the first source byte so a missing rollback cannot pass by
            ; rewriting the same bytes that were already published.
            LD   HL,(GNSZ)
            LD   (QGSAVSZ),HL
            LD   A,$5A
            LD   (IMGBAS),A
            LD   HL,MMGEN+12
            CALL ZGPRGLIM
            JR   C,QGAFAE
            XOR  A
            LD   (IMGBAS),A
            JP   QFATAC
QGAFAE:
            XOR  A
            LD   (IMGBAS),A
            LD   HL,(GNSZ)
            LD   DE,(QGSAVSZ)
            OR   A
            SBC  HL,DE
            JP   NZ,QFATSI
            LD   HL,(QGSAVSZ)
            LD   A,H
            OR   A
            JP   NZ,QFATSI
            LD   B,L
            LD   HL,MMGEN
            LD   DE,MMBACK
            CALL QPCOBY
            JP   C,QFATBYTS

            LD   A,151
            LD   HL,QGBS
            LD   DE,QGBSE
            CALL CPAGSL
            JP   C,QFBO
            LD   A,(IMGLEN)
            CP   2
            JP   NZ,QFBO
            LD   A,(IMGBAS)
            OR   A
            JP   NZ,QFBO
            LD   A,(IMGBAS+1)
            CP   1
            JP   NZ,QFBO

            LD   A,152
            LD   HL,QGIS
            LD   DE,QGISE
            CALL CPAGSL
            JP   C,QFID
            LD   A,(SYTABBAS+4)
            CP   AGDYNTYP
            JP   NZ,QFID
            LD   A,(SYTABBAS+SYENTSZ+4)
            CP   AGDYNTYP+1
            JP   NZ,QFID
            LD   A,(SYTABBAS+SYENTSZ*2+SYTYPID)
            CP   AGDYNTYP+2
            JP   NZ,QFID
            LD   A,(SYTABBAS+SYENTSZ*3+SYTYPID)
            CP   AGDYNTYP+2
            JP   NZ,QFID
            LD   A,(ATCNT)
            CP   3
            JP   NZ,QFID
            LD   A,(ARCNT)
            CP   2
            JP   NZ,QFID

            ; The retained non-streaming parser uses the same outermost-first
            ; suffix collection and interns the inner u8[3] row before the
            ; outer two-row array.
            LD   A,157
            LD   HL,QGNAS
            LD   DE,QGNASE
            CALL CPAGSL
            JP   C,QFNEAR
            LD   HL,(IMGLEN)
            LD   DE,6
            OR   A
            SBC  HL,DE
            JP   NZ,QFNEAR
            LD   HL,IMGBAS
            LD   DE,QGNAE
            LD   B,6
            CALL QPCOBY
            JP   C,QFNEAR
            LD   A,(ATCNT)
            CP   2
            JP   NZ,QFNEAR
            LD   HL,MMGEN+3
            LD   DE,QGEI
            LD   B,QGIMGLEN
            CALL QPCOBY
            JP   C,QFATBYTS

            LD   A,131
            LD   HL,QGCS
            LD   DE,QGCSE
            LD   B,DGINICNT
            CALL QPEXDI
            JP   C,QFCOUNT
            LD   A,132
            LD   HL,QGSHAPE
            LD   DE,QGSSE
            LD   B,DGINISHP
            CALL QPEXDI
            JP   C,QFSH
            LD   A,137
            LD   HL,QGTMS
            LD   DE,QGTMSE
            LD   B,DGINICNT
            CALL QPEXDI
            JP   C,QFTOMA
            LD   A,138
            LD   HL,QGCSS
            LD   DE,QGCSSE
            LD   B,DGINISHP
            CALL QPEXDI
            JP   C,QFCLSH
            LD   A,139
            LD   HL,QGTS
            LD   DE,QGTSE
            LD   B,DGTYPMIS
            CALL QPEXDI
            JP   C,QFTY
            LD   A,140
            LD   HL,QGRNSS
            LD   DE,QGRNSSE
            LD   B,DGTYPMIS
            CALL QPEXDI
            JP   C,QFRESC
            LD   A,141
            LD   HL,QGOSS
            LD   DE,QGOSSE
            LD   B,DGTYPMIS
            CALL QPEXDI
            JP   C,QFOBSC
            LD   A,142
            LD   HL,QGOAS
            LD   DE,QGOASE
            LD   B,DGTYPMIS
            CALL QPEXDI
            JP   C,QFOBAS
            LD   A,145
            LD   HL,QGRSS
            LD   DE,QGRSSE
            LD   B,DGTYPMIS
            CALL QPEXDI
            JP   C,QFREST
            LD   HL,(DGOFF)
            LD   DE,QGRSP-QGRSS
            OR   A
            SBC  HL,DE
            JP   NZ,QFREST
            LD   A,143
            LD   HL,QGDFS
            LD   DE,QGDFSE
            LD   B,DGDUPNAM
            CALL QPEXDI
            JP   C,QFDUFI
            LD   HL,(DGOFF)
            LD   DE,QGDFP-QGDFS
            OR   A
            SBC  HL,DE
            JP   NZ,QFDUFI
            LD   A,133
            LD   HL,QGSLS
            LD   DE,QGSLSE
            LD   B,DGSTRLEN
            CALL QPEXDI
            JP   C,QFSTRLEN
            LD   A,153
            LD   HL,QGMES
            LD   DE,QGMESE
            LD   B,DGLEX
            CALL QPEXDI
            JP   C,QFMAES
            LD   A,154
            LD   HL,QGSECS
            LD   DE,QGSECSE
            LD   B,DGSTRCAP
            CALL QPEXDI
            JP   C,QFSTEXCA
            LD   HL,(DGOFF)
            LD   DE,QGSECP-QGSECS
            OR   A
            SBC  HL,DE
            JP   NZ,QFSTEXCA
            LD   A,'5'
            LD   (QGSECD),A
            LD   A,156
            LD   HL,QGSECS
            LD   DE,QGSECSE
            LD   B,DGSTRCAP
            CALL QPEXDI
            JP   C,QFSTEXCA
            LD   HL,(DGOFF)
            LD   DE,QGSECP-QGSECS
            OR   A
            SBC  HL,DE
            JP   NZ,QFSTEXCA
            LD   A,155
            LD   HL,QGSSBS
            LD   DE,QGSSBSE
            CALL CPAGSL
            JP   C,QFSTEXCA
            LD   HL,(IMGLEN)
            LD   DE,255
            OR   A
            SBC  HL,DE
            JP   NZ,QFSTEXCA
            LD   HL,IMGBAS
            LD   BC,255
QGSSZL:
            LD   A,(HL)
            OR   A
            JP   NZ,QFSTEXCA
            INC  HL
            DEC  BC
            LD   A,B
            OR   C
            JR   NZ,QGSSZL
            LD   A,148
            LD   HL,QGERS
            LD   DE,QGERSE
            LD   B,DGRECEMP
            CALL QPEXDI
            JP   C,QFEMRE
            LD   A,149
            LD   HL,QGRCS
            LD   DE,QGRCSE
            LD   B,DGTYPCAP
            CALL QPEXDI
            JP   C,QFRECA
            LD   A,150
            LD   HL,QGFCS
            LD   DE,QGFCSE
            LD   B,DGTYPCAP
            CALL QPEXDI
            JP   C,QFFICA
            LD   A,134
            LD   HL,QGMS
            LD   DE,QGMSE
            LD   B,DGTYPCAP
            CALL QPEXDI
            JP   C,QFME
            LD   A,135
            LD   HL,QGDS
            LD   DE,QGDSE
            LD   B,DGINICAP
            CALL QPEXDI
            JP   C,QFDE
            LD   A,146
            LD   HL,QGECAS
            LD   DE,QGECASE
            CALL CPAGSL
            JP   C,QFELBO
            LD   A,147
            LD   HL,QGECRS
            LD   DE,QGECRSE
            CALL CPAGSL
            JP   C,QFELBO
            LD   A,136
            LD   HL,QGDCS
            LD   DE,QGDCSE
            LD   B,DGPDCAP
            CALL QPEXDI
            JP   C,QFDACA
            LD   HL,(DGOFF)
            LD   DE,QGDCP-QGDCS
            OR   A
            SBC  HL,DE
            JP   NZ,QFDACA
            LD   A,144
            LD   HL,QGTECS
            LD   DE,QGTECSE
            LD   B,DGPDCAP
            CALL QPEXDI
            JP   C,QFTYEXCA

            LD   A,$A5
            LD   (FPSTATUS),A
            HALT

; Contract: in A,B,DE,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
QPEXDI:
            PUSH BC
            CALL CPAGSL
            POP  BC
            RET  NC
            LD   A,(DGCODE)
            CP   B
            RET  Z
            SCF
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

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
QPCAGE:
            LD   HL,0
            ADD  HL,SP
            LD   (QPEXSP),HL
            LD   IX,$A55A
            CALL MMGEN
            PUSH IX
            POP  DE
            LD   HL,$A55A
            OR   A
            SBC  HL,DE
            JR   NZ,QPCAGENO
            LD   HL,0
            ADD  HL,SP
            LD   DE,(QPEXSP)
            OR   A
            SBC  HL,DE
            RET  Z
QPCAGENO:
            SCF
            RET

QFACCOMP: LD A,1
                           JP QF
QFSTLEN:    LD A,2
                           JP QF
QFSTBY:     LD A,3
                           JP QF
QFLA:          LD A,4
                           JP QF
QFACEN:  LD A,5
                           JP QF
QFPUBY:  LD A,6
                           JP QF
QFFR:           LD A,7
                           JP QF
QFRUST:        LD A,8
                           JP QF
QFATAC:  LD A,9
                           JP QF
QFATSI:      LD A,10
                           JP QF
QFATBYTS:     LD A,11
                           JP QF
QFCOUNT:           LD A,12
                           JP QF
QFSH:           LD A,13
                           JP QF
QFSTRLEN:    LD A,14
                           JP QF
QFME:        LD A,15
                           JP QF
QFDE:           LD A,16
                           JP QF
QFDACA:    LD A,17
                           JP QF
QFTOMA:          LD A,18
                           JP QF
QFCLSH:       LD A,19
                           JP QF
QFTY:             LD A,20
                           JP QF
QFRESC:     LD A,21
                           JP QF
QFOBSC:     LD A,22
                           JP QF
QFOBAS: LD A,23
                           JP QF
QFREST:       LD A,26
                           JP QF
QFELBO:  LD A,27
                           JP QF
QFEMRE:      LD A,28
                           JP QF
QFRECA:   LD A,29
                           JP QF
QFFICA:    LD A,30
                           JP QF
QFBO:          LD A,31
                           JP QF
QFID:         LD A,32
                           JP QF
QFMAES:  LD A,33
                           JP QF
QFSTEXCA: LD A,34
                           JP QF
QFNEAR:      LD A,35
                           JP QF
QFDUFI:   LD A,24
                           JP QF
QFTYEXCA: LD A,25
QF:
            LD   (FPCASE),A
            HALT

QPEXSP:       DW 0
QGSAVSZ:   DW 0
FPSTATUS:           DB 0
FPCASE:             DB 0
QGEI:
            ; zero Entry
            DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0
            ; one Entry
            DB 1,2,1,2,3,2,65,175,0,0,0,4,5,6
            ; many[0]
            DB 1,0,7,8,9,2,120,121,0,0,0,10,11,12
            ; many[1]
            DB 2,0,13,14,15,0,0,0,0,0,0,16,17,18
QGEIE:
; Expected image size is defined by the actual initialized table.
QGIMGLEN EQU QGEIE-QGEI
QGNAE:
            DB 1,2,3,4,5,6
QGNAS:
            DB "var grid as u8[2][3] = [[1,2,3],[4,5,6]]",10
            DB "sub main() fails",10,"end",10
QGNASE:
QGSSBS:
            DB "var full as string[253]",10
            DB "sub main() fails",10,"end",10
QGSSBSE:
FPEND:
