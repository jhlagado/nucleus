RTEND:

            ORG MMPROOF
; Contract: out carry,zero clobbers sign,parity,halfCarry,A,BC,DE,HL,IX,IY
FPSTART:
            LD   SP,STACKTOP
            XOR  A
            LD   (FPCASE),A
            LD   (FPSTATUS),A
            LD   (SVFAIL),A

            LD   A,110
            LD   HL,QCAS
            LD   DE,QCASE
            CALL CPSL
            JP   C,QFACCOMP
            CALL ZXPROG
            JP   C,QFACEN
            CALL RESET
            CALL QPCAGE
            JP   C,QFACFR
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,QFACSTAT
            LD   A,(VOUTLEN)
            CP   1
            JP   NZ,QFACOU
            LD   A,(VOUTBAS)
            LD   (QVOO),A
            ; The harness independently checks the observed byte while this
            ; proof continues to discriminate storage and final counters.
            LD   A,(MMGEN+3)
            LD   (QVOS),A
            LD   A,(MMGEN+4)
            LD   (QVOC),A
            LD   HL,(MMGEN+5)
            LD   (QVOD),HL
            LD   HL,(GNSZ)
            LD   (QCGS),HL

            ; A failed Z80-emission transaction must leave the published
            ; program byte-for-byte runnable.
            LD   A,(MMGEN)
            LD   (QMOB),A
            LD   HL,MMGEN+1
            CALL ZEBEGIN
            XOR  A
            CALL EMITBYTE
            JP   C,QFATSE
            CALL EMITBYTE
            JP   NC,QFATAC
            CALL ZEABORT
            LD   A,(MMGEN)
            LD   B,A
            LD   A,(QMOB)
            CP   B
            JP   NZ,QFATBYTE
            LD   HL,(GNSZ)
            LD   DE,(QCGS)
            OR   A
            SBC  HL,DE
            JP   NZ,QFATSI

            ; The same program must unwind a capacity trap from recursive
            ; routine depth back to the outer machine frame.
            CALL RESET
            LD   A,3
            LD   (RTACTLIM),A
            CALL QPCAGE
            JP   C,QFCAFR
            LD   A,(RUNSTATE)
            CP   RTTRAP
            JP   NZ,QFCAST
            LD   A,(RTTRPNO)
            CP   5
            JP   NZ,QFCANU
            LD   A,(RTDEPTH)
            OR   A
            JP   NZ,QFCADE
            LD   HL,(RTTRPOFF)
            LD   DE,QCARC-QCAS
            OR   A
            SBC  HL,DE
            JP   NZ,QFCAOF

            LD   A,111
            LD   HL,QCRS
            LD   DE,QCRSE
            CALL CPSL
            JP   C,QFRACO
            CALL ZXPROG
            JP   C,QFRAEN
            CALL RESET
            CALL QPCAGE
            JP   C,QFRAFR
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,QFRAST
            LD   A,(RTDEPTH)
            OR   A
            JP   NZ,QFRAOF
            LD   A,(MMGEN+3)
            LD   (QROE),A
            CP   1
            JP   NZ,QFRAEF
            LD   A,(MMGEN+4)
            LD   (QROA),A
            CP   120
            JP   NZ,QFRAAT

            LD   A,112
            LD   HL,QCACS
            LD   DE,QCACSE
            LD   B,DGACTCTR
            LD   IX,QCACN-QCACS
            CALL QPEXDI
            LD   A,(DGCODE)
            LD   (QIOD),A
            LD   HL,(DGOFF)
            LD   (QIOO),HL

            LD   A,113
            LD   HL,QCEOS
            LD   DE,QCEOSE
            LD   B,DXLOOP
            LD   IX,QCEOP-QCEOS
            CALL QPEXDI
            LD   A,(DGCODE)
            LD   (QJOD),A
            LD   HL,(DGOFF)
            LD   (QJOO),HL

            LD   A,114
            LD   HL,QCZSS
            LD   DE,QCZSSE
            LD   B,DGLOPSTP
            LD   IX,QCZSP-QCZSS
            CALL QPEXDI
            LD   A,(DGCODE)
            LD   (QSOD),A
            LD   HL,(DGOFF)
            LD   (QSOO),HL

            LD   A,115
            LD   HL,QCBFS
            LD   DE,QCBFSE
            CALL CPSL
            JP   C,QFBOFLCO
            CALL ZXPROG
            JP   C,QFBOFLEN
            CALL RESET
            CALL QPCAGE
            JP   C,QFBOFLFR
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,QFBOFLST
            LD   A,(MMGEN+3)
            CP   1
            JP   NZ,QFBOFLVA

            LD   A,116
            LD   HL,QCSES
            LD   DE,QCSESE
            LD   B,DXEND
            LD   IX,QCSEP-QCSES
            CALL QPEXDI
            JP   C,QFSTEL
            LD   A,117
            LD   HL,QCSEIS
            LD   DE,QCSEISE
            LD   B,DXEND
            LD   IX,QCSEIP-QCSEIS
            CALL QPEXDI
            JP   C,QFSTELIF

            LD   A,118
            LD   HL,QCSFS
            LD   DE,QCSFSE
            LD   B,DGDUPNAM
            LD   IX,QCSFP-QCSFS
            CALL QPEXDI
            JP   C,QFSEFO
            LD   A,119
            LD   HL,QCPGFWS
            LD   DE,QCPGFWE
            LD   B,DGDUPNAM
            LD   IX,QCPGFWP-QCPGFWS
            CALL QPEXDI
            JP   C,QFPRFO
            LD   A,120
            LD   HL,QCLFS
            LD   DE,QCLFSE
            LD   B,DGDUPNAM
            LD   IX,QCLFP-QCLFS
            CALL QPEXDI
            JP   C,QFLOFO
            LD   A,121
            LD   HL,QCMFS
            LD   DE,QCMFSE
            LD   B,DGDUPNAM
            LD   IX,QCMFP-QCMFS
            CALL QPEXDI
            JP   C,QFMAFO
            LD   A,122
            LD   HL,QCPAFWS
            LD   DE,QCPAFWE
            LD   B,DGDUPNAM
            LD   IX,QCPAFWP-QCPAFWS
            CALL QPEXDI
            JP   C,QFPAFO
            LD   A,124
            LD   HL,QCPGMNS
            LD   DE,QCPGMNE
            LD   B,DGDUPNAM
            LD   IX,QCPGMNP-QCPGMNS
            CALL QPEXDI
            JP   C,QFPRMA
            LD   A,125
            LD   HL,QCLMS
            LD   DE,QCLMSE
            LD   B,DGDUPNAM
            LD   IX,QCLMP-QCLMS
            CALL QPEXDI
            JP   C,QFLOMA
            LD   A,126
            LD   HL,QCPAMNS
            LD   DE,QCPAMNE
            LD   B,DGDUPNAM
            LD   IX,QCPAMNP-QCPAMNS
            CALL QPEXDI
            JP   C,QFPAMA
            LD   A,123
            LD   HL,QCLCS
            LD   DE,QCLCSE
            LD   B,DGCLBCAP
            LD   IX,QCLABPOS
            CALL QPEXDI
            JP   C,QFLACA

            LD   A,$A5
            LD   (FPSTATUS),A
            HALT

; A part, HL..DE source, B diagnostic, IX expected offset.
; Contract: in A,B,DE,HL,IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IY
QPEXDI:
            PUSH BC
            PUSH IX
            CALL CPSL
            POP  IX
            POP  BC
            RET  NC
            LD   A,(DGCODE)
            CP   B
            JR   NZ,QPEXDINO
            LD   HL,(DGOFF)
            PUSH IX
            POP  DE
            OR   A
            SBC  HL,DE
            RET  Z
QPEXDINO:
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

QFACCOMP:     LD A,1
                              JP QF
QFACEN:      LD A,2
                              JP QF
QFACFR:       LD A,3
                              JP QF
QFACSTAT:       LD A,4
                              JP QF
QFACOU:      LD A,5
                              JP QF
QFACVA:       LD A,6
                              JP QF
QFACSTOR:       LD A,7
                              JP QF
QFACCNTR:     LD A,8
                              JP QF
QFACDE:  LD A,9
                              JP QF
QFNE:              JP QF
QFCAFR:       LD A,21
                              JR QFNE
QFCAST:       LD A,22
                              JR QFNE
QFCANU:      LD A,23
                              JR QFNE
QFCADE:       LD A,24
                              JR QFNE
QFCAOF:      LD A,25
                              JR QFNE
QFRACO:        LD A,10
                              JR QFNE
QFRAEN:         LD A,11
                              JR QFNE
QFRAFR:          LD A,12
                              JR QFNE
QFRAST:          LD A,13
                              JR QFNE
QFRANU:         LD A,14
                              JR QFNE
QFRAOF:         LD A,15
                              JR QFNE
QFRAEF:         LD A,16
                              JR QFNE
QFRAAT:         LD A,17
                              JR QFNE
QFACTCNT:       LD A,18
                              JR QFNE
QFEXOU:         LD A,19
                              JR QFNE
QFZEST:            LD A,20
                              JR QFNE
QFATSE:         LD A,26
                              JR QFNE
QFATAC:      LD A,27
                              JR QFNE
QFATBYTE:          LD A,28
                              JR QFNE
QFATSI:          LD A,29
                              JR QFNE
QFBOFLCO:  LD A,30
                              JR QFNE
QFBOFLEN:   LD A,31
                              JR QFNE
QFBOFLFR:    LD A,32
                              JR QFNE
QFBOFLST:    LD A,33
                              JR QFNE
QFBOFLVA:    LD A,34
                              JR QFNE
QFSTEL:           LD A,35
                              JR QFNE
QFSTELIF:         LD A,36
                              JR QFNE
QFSEFO:       LD A,37
                              JR QFNE
QFPRFO:      LD A,38
                              JR QFNE
QFLOFO:        LD A,39
                              JR QFNE
QFMAFO:         LD A,40
                              JR QFNE
QFPAFO:    LD A,41
                              JR QF
QFLACA:       LD A,42
                              JR QF
QFPRMA:         LD A,43
                              JR QF
QFLOMA:           LD A,44
                              JR QF
QFPAMA:       LD A,45
QF:
            LD   (FPCASE),A
            LD   A,$E0
            LD   (FPSTATUS),A
            HALT

QPEXSP:              DW 0
QCGS:     DW 0
QVOO:      DB 0
QVOS:       DB 0
QVOC:     DB 0
QVOD:  DW 0
QROE:         DB 0
QROA:         DB 0
QIOD:    DB 0
QIOO:        DW 0
QJOD:      DB 0
QJOO:          DW 0
QSOD:      DB 0
QSOO:          DW 0
QMOB:          DB 0
FPSTATUS:                  DB 0
FPCASE:                    DB 0
QZTE            EQU MMGEN+715
FPEND:

            ; Retain the fixture at $9800 while emitting images in address order.
            ORG MMSPARE
QCLCS:
            DB "sub main() fails",10
            DB "    if true",10,"    end",10
            DB "    if true",10,"    end",10
            DB "    if true",10,"    end",10
            DB "    if true",10,"    end",10
            DB "    if true",10,"    end",10
            DB "    if true",10,"    end",10
            DB "    if true",10,"    end",10
            DB "    if true",10,"    end",10
            DB "    if true",10,"    end",10
            DB "    if true",10,"    end",10
            DB "    if true",10,"    end",10
            DB "    if true",10,"    end",10
            DB "    if true",10,"    end",10
            DB "    if true",10,"    end",10
            DB "    if true",10,"    end",10
            DB "    "
QCLCP:
            DB "if true",10,"    end",10
            DB "end",10
QCLCSE:
; Label-capacity diagnostic position within its later source corpus.
QCLABPOS EQU QCLCP-QCLCS
