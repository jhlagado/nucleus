RTEND:

            ORG MMPROOF
; Contract: out carry,zero clobbers sign,parity,halfCarry,A,BC,DE,HL,IX,IY
FPSTART:
            LD   SP,STACKTOP
            XOR  A
            LD   (FPCASE),A
            LD   (FPSTATUS),A
            LD   A,60
            LD   HL,QKPS
            LD   DE,QKPSE
            CALL CPCLSL
            JP   C,QFCOMP
            LD   A,(SMBUFBAS)
            CP   9
            JP   NZ,QFOP
            CALL ZECALLPG
            JP   C,QFEN
            LD   HL,(GNSZ)
            LD   DE,CLPROGSZ
            OR   A
            SBC  HL,DE
            JP   NZ,QFSI
            LD   HL,(SMRDCUR)
            LD   DE,SMBUFBAS+$10
            OR   A
            SBC  HL,DE
            JP   NZ,QFTREN

            CALL RESET
            CALL MMGEN
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,QFSUST
            LD   A,(VOUTLEN)
            CP   1
            JP   NZ,QFSUOU
            LD   A,(VOUTBAS)
            OR   A
            JP   NZ,QFSUBY
            LD   A,(RTDEPTH)
            OR   A
            JP   NZ,QFSUAC
            LD   A,(RTACTMEM+3)
            CP   1
            JP   NZ,QFSUPE

            CALL RESET
            LD   A,$A5
            LD   (RTACTMEM+3),A
            LD   A,3
            LD   (RTACTLIM),A
            CALL MMGEN
            LD   A,(RUNSTATE)
            CP   RTTRAP
            JP   NZ,QFCAST
            LD   A,(RTTRPNO)
            CP   5
            JP   NZ,QFCATR
            LD   A,(VOUTLEN)
            OR   A
            JP   NZ,QFCAOU
            LD   A,(RTDEPTH)
            OR   A
            JP   NZ,QFCAPACT
            LD   HL,(RTTRPOFF)
            LD   DE,CLCAPOFF
            OR   A
            SBC  HL,DE
            JP   NZ,QFCAOF
            LD   A,(RTACTMEM+2)
            CP   2
            JP   NZ,QFCAPE
            LD   A,(RTACTMEM+3)
            CP   $A5
            JP   NZ,QFCAAT

            CALL RESET
            LD   A,1
            LD   (SVFAIL),A
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
            LD   DE,CLFAIL
            OR   A
            SBC  HL,DE
            JP   NZ,QFOUOF
            LD   A,(VOUTLEN)
            OR   A
            JP   NZ,QFOUBY
            LD   A,(RTDEPTH)
            OR   A
            JP   NZ,QFOUAC

            LD   A,61
            LD   HL,QBCS
            LD   DE,QBCSE
            CALL CPCLSL
            JP   NC,QFBAAC
            LD   A,(DGCODE)
            CP   DGFWDMIS
            JP   NZ,QFBACO
            LD   HL,(DGOFF)
            LD   DE,QBCN-QBCS
            OR   A
            SBC  HL,DE
            JP   NZ,QFBAPO

            ; Leave the complete successful program available to host tests.
            LD   A,60
            LD   HL,QKPS
            LD   DE,QKPSE
            CALL CPCLSL
            JP   C,QFCOMP
            CALL ZECALLPG
            JP   C,QFEN

            LD   A,$A5
            LD   (FPSTATUS),A
            HALT

QFCOMP:             LD A,1
                              JR QF
QFOP:          LD A,2
                              JR QF
QFEN:              LD A,3
                              JR QF
QFSI:                LD A,15
                              JR QF
QFSUST:        LD A,4
                              JR QF
QFSUOU:       LD A,5
                              JR QF
QFSUBY:         LD A,6
                              JR QF
QFSUAC:   LD A,7
                              JR QF
QFCAST:       LD A,8
                              JR QF
QFCATR:        LD A,9
                              JR QF
QFCAOU:      LD A,10
                              JR QF
QFCAPACT:  LD A,11
                              JR QF
QFBAAC:         LD A,12
                              JR QF
QFBACO:             LD A,13
                              JR QF
QFBAPO:         LD A,14
                              JR QF
QFTREN:       LD A,16
                              JR QF
QFSUPE:         LD A,17
                              JR QF
QFCAOF:      LD A,18
                              JR QF
QFCAPE:        LD A,19
                              JR QF
QFCAAT:      LD A,20
                              JR QF
QFOUST:         LD A,21
                              JR QF
QFOUTR:          LD A,22
                              JR QF
QFOUER:         LD A,23
                              JR QF
QFOUOF:        LD A,24
                              JR QF
QFOUBY:         LD A,25
                              JR QF
QFOUAC:   LD A,26
QF:
            LD   (FPCASE),A
            LD   A,$E0
            LD   (FPSTATUS),A
            HALT

FPSTATUS:            DB 0
FPCASE:              DB 0
FPEND:
