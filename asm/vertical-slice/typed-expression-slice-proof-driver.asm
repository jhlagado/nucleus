RTEND:

            ORG MMPROOF
; Contract: out carry,zero clobbers sign,parity,halfCarry,A,BC,DE,HL,IX,IY
FPSTART:
            LD   SP,STACKTOP
            XOR  A
            LD   (FPCASE),A
            LD   (FPSTATUS),A
            LD   (SVFAIL),A

            ; TokenEof shares zero with the empty lookahead marker. Repeated
            ; peeks therefore re-run the tokenizer, but must reproduce the
            ; same token, payload, flags, source cursor, and token position.
            LD   A,79
            LD   HL,QTECSE
            LD   DE,QTECSE
            CALL SAINIT
            XOR  A
            LD   (PSLOOK),A
            LD   BC,$FFFF
            CALL PSPEEK
            JP   C,QFEOLO
            JP   NZ,QFEOLO
            LD   A,B
            OR   C
            JP   NZ,QFEOLO
            LD   BC,$FFFF
            CALL PSPEEK
            JP   C,QFEOLO
            JP   NZ,QFEOLO
            LD   A,B
            OR   C
            JP   NZ,QFEOLO
            CALL PSTK
            JP   C,QFEOLO
            JP   NZ,QFEOLO
            LD   A,(PSLOOK)
            OR   A
            JP   NZ,QFEOLO
            LD   HL,(SSCUR)
            LD   DE,QTECSE
            OR   A
            SBC  HL,DE
            JP   NZ,QFEOLO
            LD   HL,(SSOFF)
            LD   A,H
            OR   L
            JP   NZ,QFEOLO
            LD   HL,(SSLINE)
            DEC  HL
            LD   A,H
            OR   L
            JP   NZ,QFEOLO
            LD   HL,(SSCOL)
            DEC  HL
            LD   A,H
            OR   L
            JP   NZ,QFEOLO
            LD   HL,(TNSTOFF)
            LD   A,H
            OR   L
            JP   NZ,QFEOLO
            LD   HL,(TNSTLINE)
            DEC  HL
            LD   A,H
            OR   L
            JP   NZ,QFEOLO
            LD   HL,(TNSTCOL)
            DEC  HL
            LD   A,H
            OR   L
            JP   NZ,QFEOLO
            LD   A,TNPLUS
            CALL TYTKOP
            JP   C,QFEOLO
            JP   Z,QFEOLO
            CP   $FF
            JP   NZ,QFEOLO
            LD   A,(PSLOOK)
            OR   A
            JP   NZ,QFEOLO
            LD   A,(EXOP)
            CP   TNPLUS
            JP   NZ,QFEOLO

            LD   A,80
            LD   HL,QTAS
            LD   DE,QTASE
            CALL CPSL
            JP   C,QFACCOMP
            CALL ZXPROG
            JP   C,QFACEN
            CALL RESET
            CALL QPCAGE
            JP   C,QFFR
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,QFACSTAT
            LD   A,(VOUTLEN)
            CP   1
            JP   NZ,QFACLE
            LD   A,(VOUTBAS)
            CP   1
            JP   NZ,QFACVA
            LD   A,(MMGEN+3)       ; out
            CP   1
            JP   NZ,QFACSTOR
            LD   A,(MMGEN+6)       ; final comparison conjunction
            CP   1
            JP   NZ,QFACBO
            LD   HL,(MMGEN+4)      ; widened add wraps 65535 + 1
            LD   A,H
            OR   L
            JP   NZ,QFACWO
            LD   HL,(GNSZ)
            LD   (QTGS),HL

            LD   A,90
            LD   HL,QTDS
            LD   DE,QTDSE
            CALL CPSL
            JP   C,QFDECO
            CALL ZXPROG
            JP   C,QFDEEN
            CALL RESET
            CALL QPCAGE
            JP   C,QFFR
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,QFDEST
            LD   A,(VOUTLEN)
            CP   1
            JP   NZ,QFDEOU
            LD   A,(VOUTBAS)
            OR   A
            JP   NZ,QFDEOU
            LD   HL,(MMGEN+4)      ; word defaults to zero
            LD   A,H
            OR   L
            JP   NZ,QFDEPR
            LD   A,(MMGEN+6)       ; false, then not, becomes true
            CP   1
            JP   NZ,QFDEBO

            LD   A,81
            LD   HL,QTNTS
            LD   DE,QTNTSE
            CALL CPSL
            JP   C,QFNACO
            CALL ZXPROG
            JP   C,QFNAEN
            CALL RESET
            CALL QPCAGE
            JP   C,QFFR
            LD   A,(RUNSTATE)
            CP   RTTRAP
            JP   NZ,QFNAST
            LD   A,(RTTRPNO)
            CP   2
            JP   NZ,QFNANU
            LD   HL,(RTTRPOFF)
            LD   DE,QTNTP-QTNTS
            OR   A
            SBC  HL,DE
            JP   NZ,QFNAOF
            LD   A,(MMGEN+3)
            CP   7
            JP   NZ,QFNAAT

            LD   A,82
            LD   HL,QTDTS
            LD   DE,QTDTSE
            CALL CPSL
            JP   C,QFDICO
            CALL ZXPROG
            JP   C,QFDIEN
            CALL RESET
            CALL QPCAGE
            JP   C,QFFR
            LD   A,(RUNSTATE)
            CP   RTTRAP
            JP   NZ,QFDIST
            LD   A,(RTTRPNO)
            CP   3
            JP   NZ,QFDINU
            LD   HL,(RTTRPOFF)
            LD   DE,QTDTP-QTDTS
            OR   A
            SBC  HL,DE
            JP   NZ,QFDIOF
            LD   A,(MMGEN+3)
            CP   9
            JP   NZ,QFDIAT

            LD   A,83
            LD   HL,QTINS
            LD   DE,QTINSE
            LD   C,DGTYPMIS
            CALL QPEXDI
            JP   C,QFIMNA
            LD   A,84
            LD   HL,QTBMS
            LD   DE,QTBMSE
            LD   C,DGTYPMIS
            CALL QPEXDI
            JP   C,QFBOMI
            LD   A,85
            LD   HL,QTCHAIN
            LD   DE,QTCHEND
            LD   C,DGCMPCHN
            CALL QPEXDI
            JP   C,QFCH
            LD   A,86
            LD   HL,QTCDS
            LD   DE,QTCDSE
            LD   C,DGDIVZER
            CALL QPEXDI
            JP   C,QFCODI
            LD   A,87
            LD   HL,QTCNS
            LD   DE,QTCNSE
            LD   C,DGNAR
            CALL QPEXDI
            JP   C,QFCONA
            LD   A,88
            LD   HL,QTLOS
            LD   DE,QTLOSE
            LD   C,DGLEX
            CALL QPEXDI
            JP   C,QFLIOV
            LD   A,89
            LD   HL,QTTCS
            LD   DE,QTTCSE
            LD   C,DGSNKCAP
            CALL QPEXDI
            JP   C,QFTRCA

            ; The byte stream still has room after 255 one-byte operations,
            ; but the independently published operation count does not. Lock
            ; the exact count and cursor before the 256th operation; its
            ; terminal diagnostic intentionally overlays that dead sink state.
            CALL TMRESET
            LD   C,255
QPFIOPCO:
            LD   A,SMLIT16
            CALL TMOPER
            JP   C,QFOPCAFI
            DEC  C
            JR   NZ,QPFIOPCO
            LD   A,(SKOPCNT)
            CP   255
            JP   NZ,QFOPCABO
            LD   HL,(SKCUR)
            LD   DE,SMBUFBAS+256
            OR   A
            SBC  HL,DE
            JP   NZ,QFOPCABO
            LD   A,SMLIT16
            CALL TMOPER
            JP   NC,QFOPCAAC
            LD   A,(DGCODE)
            CP   DGSNKCAP
            JP   NZ,QFOPCADI

            LD   A,91
            LD   HL,QTECS
            LD   DE,QTECSE
            LD   C,DGEXPCAP
            CALL QPEXDI
            JP   C,QFEXCA

            LD   A,92
            LD   HL,QTDZS
            LD   DE,QTDZSE
            LD   C,DGDIVZER
            CALL QPEXDI
            JP   C,QFDYZE
            LD   A,93
            LD   HL,QTUMOS
            LD   DE,QTUMOSE
            LD   C,DGINTRNG
            CALL QPEXDI
            JP   C,QFUNMIRA
            LD   A,94
            LD   HL,QTNOS
            LD   DE,QTNOSE
            LD   C,DGINTRNG
            CALL QPEXDI
            JP   C,QFNORA
            LD   A,95
            LD   HL,QTMHS
            LD   DE,QTMHSE
            LD   C,DGLEX
            CALL QPEXDI
            JP   C,QFMAHE
            LD   A,96
            LD   HL,QTMSS
            LD   DE,QTMSSE
            LD   C,DGLEX
            CALL QPEXDI
            JP   C,QFMASU

            ; Fault suppression removes the fault, not the operation's static
            ; type. Both skipped u8 operations must still make 300 invalid as
            ; the exact peer of a u8 comparison.
            LD   A,100
            LD   HL,QTSDTS
            LD   DE,QTSDTSE
            LD   C,DGINTRNG
            CALL QPEXDI
            JP   C,QFSUDITY
            LD   A,101
            LD   HL,QTSNTS
            LD   DE,QTSNTSE
            LD   C,DGINTRNG
            CALL QPEXDI
            JP   C,QFSUNATY
            LD   A,102
            LD   HL,QTMCRS
            LD   DE,QTMCRSE
            LD   C,DXRPAR
            CALL QPEXDI
            JP   C,QFMICORI
            LD   A,103
            LD   HL,QTMPRS
            LD   DE,QTMPRSE
            LD   C,DXRPAR
            CALL QPEXDI
            JP   C,QFMIPARI
            LD   A,104
            LD   HL,QTMALS
            LD   DE,QTMALSE
            LD   C,DGLEX
            CALL QPEXDI
            JP   C,QFMAAFLE

            ; Put the cursor three bytes below the transcript limit. The local
            ; declaration consumes two bytes and its literal operation consumes
            ; the third; the first literal operand must report capacity.
            LD   A,105
            LD   HL,QTDLCS
            LD   DE,QTDLCSE
            CALL SAINIT
            CALL TMRESET
            XOR  A
            LD   (PSLOOK),A
            CALL SBRESET
            LD   HL,SMBUFLIM-3
            LD   (SKCUR),HL
            CALL TYPLOCDC
            JP   NC,QFDELOCA
            LD   A,(DGCODE)
            CP   DGSNKCAP
            JP   NZ,QFDELOCA

            ; Exercise paths absent from the primary program: named u8 and
            ; Boolean constants, unary plus, u8 or, integer less-than, Boolean
            ; equality/inequality, constant division, and boundary narrowing.
            LD   A,97
            LD   HL,QTCOVER
            LD   DE,QTCOVEND
            CALL CPSL
            JP   C,QFCVCMP
            CALL ZXPROG
            JP   C,QFCVENC
            CALL RESET
            CALL QPCAGE
            JP   C,QFFR
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,QFCVST
            LD   A,(VOUTBAS)
            CP   255
            JP   NZ,QFCOOU
            LD   A,(MMGEN+4)       ; dynamic Boolean conjunction
            CP   1
            JP   NZ,QFCOBO

            ; The inner u8 conversion controls its arithmetic width even though
            ; the enclosing destination is u16: 200+100 wraps to 44, then widens.
            LD   A,98
            LD   HL,QTCCS
            LD   DE,QTCCSE
            CALL CPSL
            JP   C,QFCNCMP
            CALL ZXPROG
            JP   C,QFCNENC
            CALL RESET
            CALL QPCAGE
            JP   C,QFFR
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,QFCNST
            LD   HL,(MMGEN+4)
            LD   A,H
            OR   A
            JP   NZ,QFCOVA
            LD   A,L
            CP   44
            JP   NZ,QFCOVA

            ; A nested successful divide must not replace the outer divide's
            ; source offset when the outer operation traps.
            LD   A,99
            LD   HL,QTNDTS
            LD   DE,QTNDTSE
            CALL CPSL
            JP   C,QFNEDICO
            CALL ZXPROG
            JP   C,QFNEDIEN
            CALL RESET
            CALL QPCAGE
            JP   C,QFFR
            LD   A,(RUNSTATE)
            CP   RTTRAP
            JP   NZ,QFNEDIST
            LD   HL,(RTTRPOFF)
            LD   DE,QTDIVPOS
            OR   A
            SBC  HL,DE
            JP   NZ,QFNEDIOF
            LD   HL,(MMGEN+3)
            LD   DE,10
            OR   A
            SBC  HL,DE
            JP   NZ,QFNEDIAT

            ; A nested successful narrowing likewise must not replace the
            ; outer checked conversion's trap position.
            LD   A,100
            LD   HL,QTNNTS
            LD   DE,QTNNTSE
            CALL CPSL
            JP   C,QFNENACO
            CALL ZXPROG
            JP   C,QFNENAEN
            CALL RESET
            CALL QPCAGE
            JP   C,QFFR
            LD   A,(RUNSTATE)
            CP   RTTRAP
            JP   NZ,QFNENAST
            LD   HL,(RTTRPOFF)
            LD   DE,QTNARPOS
            OR   A
            SBC  HL,DE
            JP   NZ,QFNENAOF
            LD   A,(MMGEN+3)
            CP   7
            JP   NZ,QFNENAAT

            ; Defensive invariant failures use their own diagnostics rather
            ; than masquerading as semantic-transcript exhaustion.
            XOR  A
            LD   (EXSTKDEP),A
            LD   HL,1
            LD   A,MTCONST+TYU8
            CALL TYRSTOPS
            JP   NC,QFEXUN
            LD   A,(DGCODE)
            CP   DGINTOP
            JP   NZ,QFEXUN

            LD   A,EBFCAP
            LD   (EBFDEP),A
            LD   DE,0
            CALL ZXBLPUSH
            JP   NC,QFBOCA
            LD   A,(DGCODE)
            CP   DGBFXCAP
            JP   NZ,QFBOCA

            XOR  A
            LD   (EBFDEP),A
            LD   B,A
            CALL ZXBLPOP
            JP   NC,QFBOUN
            LD   A,(DGCODE)
            CP   DGINTOP
            JP   NZ,QFBOUN

            LD   A,1
            LD   (SMBUFBAS),A
            LD   A,SMLITU8
            LD   (SMPAYBAS),A
            CALL ZXDISP
            JP   NC,QFREOP
            LD   A,(DGCODE)
            CP   DGINTOP
            JP   NZ,QFREOP

            ; A unary template that exhausts the output after three bytes
            ; must return through both inline continuations with SP restored.
            ; The emitted prefix and untouched fourth byte lock the precise
            ; failure point of the returning-diagnostic historical layout.
            LD   HL,0
            ADD  HL,SP
            LD   (QPEXSP),HL
            XOR  A
            LD   (DGCODE),A
            LD   HL,MMGEN
            LD   (EMCUR),HL
            LD   HL,MMGEN+3
            LD   (EMLIM),HL
            LD   A,$CC
            LD   (MMGEN+3),A
            CALL ZXNEG16
            JP   NC,QFUNEMRE
            LD   HL,0
            ADD  HL,SP
            LD   DE,(QPEXSP)
            OR   A
            SBC  HL,DE
            JP   NZ,QFUNEMST
            LD   A,(DGCODE)
            CP   DGSNKCAP
            JP   NZ,QFUNEMDI
            LD   HL,(EMCUR)
            LD   DE,MMGEN+3
            OR   A
            SBC  HL,DE
            JP   NZ,QFUNEMCU
            LD   HL,(MMGEN)
            LD   DE,$AFE1
            OR   A
            SBC  HL,DE
            JP   NZ,QFUEPW
            LD   A,(MMGEN+2)
            CP   $95
            JP   NZ,QFUEPB
            LD   A,(MMGEN+3)
            CP   $CC
            JP   NZ,QFUNEMCA

            LD   A,1
            LD   (EBFDEP),A
            CALL ZXENDM
            JP   NC,QFUNBO
            LD   A,(DGCODE)
            CP   DGINTOP
            JP   NZ,QFUNBO

            CALL QPARFAST
            JP   C,QFARRU

            ; Restore the accepted compiler result for host-side inspection.
            LD   A,80
            LD   HL,QTAS
            LD   DE,QTASE
            CALL CPSL
            JP   C,QFACCOMP
            CALL ZXPROG
            JP   C,QFACEN
            LD   A,$A5
            LD   (FPSTATUS),A
            HALT

; A=part, HL..DE source, C=expected diagnostic. Carry means mismatch.
; Contract: in A,C,DE,HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
QPEXDI:
            PUSH BC
            CALL CPSL
            POP  BC
            JR   NC,QPEXDINO
            LD   A,(DGCODE)
            CP   C
            JR   NZ,QPEXDINO
            OR   A
            RET
QPEXDINO:
            SCF
            RET

; Execute a generated routine with a visible frame sentinel. Returning through
; local storage or a saved IX value cannot satisfy both observations.
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

; The runtime fast paths must preserve the full multiply/divide/modulo result
; matrix at their gating boundaries. Rows are dividend, divisor, quotient,
; remainder, and wrapped product.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX
QPARFAST:
            LD   IX,QPARCA
QPCHARRO:
            LD   L,(IX+0)
            LD   H,(IX+1)
            LD   E,(IX+2)
            LD   D,(IX+3)
            CALL RTDIV16
            JR   C,QPCHARNO
            LD   E,(IX+4)
            LD   D,(IX+5)
            OR   A
            SBC  HL,DE
            JR   NZ,QPCHARNO
            LD   L,(IX+0)
            LD   H,(IX+1)
            LD   E,(IX+2)
            LD   D,(IX+3)
            CALL RTMOD16
            JR   C,QPCHARNO
            LD   E,(IX+6)
            LD   D,(IX+7)
            OR   A
            SBC  HL,DE
            JR   NZ,QPCHARNO
            LD   L,(IX+0)
            LD   H,(IX+1)
            LD   E,(IX+2)
            LD   D,(IX+3)
            CALL RTMUL16
            JR   C,QPCHARNO
            LD   E,(IX+8)
            LD   D,(IX+9)
            OR   A
            SBC  HL,DE
            JR   NZ,QPCHARNO
            LD   DE,10
            ADD  IX,DE
            PUSH IX
            POP  HL
            LD   DE,QPARCAEN
            OR   A
            SBC  HL,DE
            JR   NZ,QPCHARRO

            LD   HL,1000
            LD   DE,0
            CALL RTDIV16
            JR   NC,QPCHARNO
            LD   HL,1000
            LD   DE,0
            CALL RTMOD16
            JR   NC,QPCHARNO
            LD   HL,37
            LD   DE,0
            CALL RTMUL16
            JR   C,QPCHARNO
            LD   A,H
            OR   L
            RET  Z
QPCHARNO:
            SCF
            RET

QFNE:              JP QF
QFACCOMP:     LD A,1
                              JR QFNE
QFACEN:      LD A,2
                              JR QFNE
QFACSTAT:       LD A,3
                              JR QFNE
QFACLE:      LD A,4
                              JR QFNE
QFACVA:       LD A,5
                              JR QFNE
QFACSTOR:       LD A,6
                              JR QFNE
QFACBO:     LD A,26
                              JR QFNE
QFACWO:        LD A,27
                              JR QFNE
QFDECO:      LD A,28
                              JR QFNE
QFDEEN:       LD A,29
                              JR QFNE
QFDEST:        LD A,30
                              JR QFNE
QFDEOU:       LD A,31
                              JR QFNE
QFDEPR:      LD A,32
                              JR QFNE
QFDEBO:      LD A,33
                              JR QFNE
QFNACO:       LD A,7
                              JR QFNE
QFNAEN:        LD A,8
                              JR QFNE
QFNAST:         LD A,9
                              JR QFNE
QFNANU:        LD A,10
                              JR QFNE
QFNAOF:        LD A,11
                              JR QFNE
QFNAAT:        LD A,12
                              JR QFNE
QFDICO:       LD A,13
                              JR QFNE
QFDIEN:        LD A,14
                              JR QFNE
QFDIST:         LD A,15
                              JR QFNE
QFDINU:        LD A,16
                              JR QFNE
QFDIOF:        LD A,17
                              JR QFNE
QFDIAT:        LD A,18
                              JR QFNE
QFIMNA:      LD A,19
                              JR QFNE
QFBOMI:          LD A,20
                              JR QFNE
QFCH:               LD A,21
                              JR QFNE
QFCODI:      LD A,22
                              JR QFNE
QFCONA:      LD A,23
                              JR QFNE
QFLIOV:     LD A,24
                              JP QF
QFTRCA:  LD A,25
                              JP QF
QFEXCA:  LD A,34
                              JP QF
QFEXUN: LD A,35
                              JP QF
QFBOCA:     LD A,36
                              JP QF
QFBOUN:    LD A,37
                              JP QF
QFREOP:    LD A,38
                              JP QF
QFUNBO:   LD A,39
                              JP QF
QFFR:               LD A,40
                              JP QF
QFDYZE:         LD A,41
                              JP QF
QFUNMIRA:     LD A,42
                              JP QF
QFNORA:            LD A,43
                              JP QF
QFMAHE:        LD A,44
                              JP QF
QFMASU:     LD A,45
                              JP QF
QFSUDITY: LD A,65
                              JP QF
QFSUNATY: LD A,66
                              JP QF
QFMICORI: LD A,67
                              JP QF
QFMIPARI:   LD A,68
                              JP QF
QFMAAFLE:  LD A,69
                              JP QF
QFDELOCA: LD A,70
                              JP QF
QFOPCAFI: LD A,71
                              JP QF
QFOPCABO: LD A,72
                              JP QF
QFOPCAAC: LD A,73
                              JP QF
QFOPCADI: LD A,74
                              JP QF
QFEOLO:       LD A,75
                              JP QF
QFUNEMRE:    LD A,76
                              JP QF
QFUNEMST:     LD A,77
                              JP QF
QFUNEMDI: LD A,78
                              JP QF
QFUNEMCU:    LD A,79
                              JP QF
QFUEPW: LD A,80
                              JP QF
QFUEPB: LD A,81
                              JP QF
QFUNEMCA:    LD A,82
                              JP QF
QFCVCMP:     LD A,46
                              JR QF
QFCVENC:      LD A,47
                              JR QF
QFCVST:       LD A,48
                              JR QF
QFCOOU:      LD A,49
                              JR QF
QFCOBO:     LD A,50
                              JR QF
QFCNCMP:   LD A,51
                              JR QF
QFCNENC:    LD A,52
                              JR QF
QFCNST:     LD A,53
                              JR QF
QFCOVA:     LD A,54
                              JR QF
QFNEDICO: LD A,55
                              JR QF
QFNEDIEN:  LD A,56
                              JR QF
QFNEDIST:   LD A,57
                              JR QF
QFNEDIOF:  LD A,58
                              JR QF
QFNEDIAT:  LD A,59
                              JR QF
QFNENACO: LD A,60
                              JR QF
QFNENAEN:  LD A,61
                              JR QF
QFNENAST:   LD A,62
                              JR QF
QFNENAOF:  LD A,63
                              JR QF
QFNENAAT:  LD A,64
                              JR QF
QFARRU:   LD A,71
QF:
            LD   (FPCASE),A
            LD   A,$E0
            LD   (FPSTATUS),A
            HALT

QTGS:           DW 0
QPEXSP:              DW 0
FPSTATUS:                  DB 0
FPCASE:                    DB 0
QPARCA:
            DW 1000,1,1000,0,1000
            DW 1000,2,500,0,2000
            DW 1000,255,3,235,58392
            DW 1000,256,3,232,59392
            DW 1000,257,3,229,60392
            DW 65535,65535,1,0,1
QPARCAEN:
FPEND:

QZTE             EQU MMGEN+857

            ORG MMSPARE
QTDZS:
            DB "var out as u8 = 1",10
            DB "sub main() fails",10
            DB "    out = out / 0",10
            DB "end",10
QTDZSE:

QTUMOS:
            DB "var bad as u8 = -256",10
QTUMOSE:
QTNOS:
            DB "var bad as u8 = not 256",10
QTNOSE:
QTMHS:
            DB "var bad as u16 = 0x2a",10
QTMHSE:
QTMSS:
            DB "var bad as u16 = 12u8",10
QTMSSE:

QTSDTS:
            DB "var byte as u8 = 1",10
            DB "var flag as boolean = false",10
            DB "sub main() fails",10
            DB "    flag = false and (byte / 0 = 300)",10
            DB "end",10
QTSDTSE:

QTSNTS:
            DB "var flag as boolean = false",10
            DB "sub main() fails",10
            DB "    flag = false and (u8(300) = 300)",10
            DB "end",10
QTSNTSE:

QTMCRS:
            DB "var out as u8 = 0",10
            DB "sub main() fails",10
            DB "    out = u8(1",10
            DB "end",10
QTMCRSE:

QTMPRS:
            DB "var out as u8 = 0",10
            DB "sub main() fails",10
            DB "    out = (1",10
            DB "end",10
QTMPRSE:

QTMALS:
            DB "var out as u8 = 0",10
            DB "sub main() fails",10
            DB "    out = 1 0x2a",10
            DB "end",10
QTMALSE:

QTDLCS:
            DB "local as u16",10
QTDLCSE:

QTCOVER:
            DB "const byteMask = u8(255)",10
            DB "const truth = true",10
            DB "const quotient = 8 / 2",10
            DB "var out as u8 = 0",10
            DB "var flag as boolean = false",10
            DB "sub main() fails",10
            DB "    var value as u8 = +1",10
            DB "    out = not 255",10
            DB "    out = -u8(255)",10
            DB "    out = value or byteMask",10
            DB "    flag = truth",10
            DB "    flag = (value < quotient) and (flag = truth) and (flag <> false)",10
            DB "    writeOutputByte(out) else fail",10
            DB "end",10
QTCOVEND:

QTCCS:
            DB "var out as u8 = 0",10
            DB "var word as u16 = 0",10
            DB "sub main() fails",10
            DB "    word = u8(200 + 100)",10
            DB "    out = u8(word)",10
            DB "    writeOutputByte(out) else fail",10
            DB "end",10
QTCCSE:

QTNDTS:
            DB "var result as u16 = 10",10
            DB "var left as u16 = 1",10
            DB "var right as u16 = 2",10
            DB "sub main() fails",10
            DB "    result = result "
QTNDO:
            DB "/ (left / right)",10
            DB "end",10
QTNDTSE:

QTNNTS:
            DB "var out as u8 = 7",10
            DB "var wide as u16 = 300",10
            DB "var small as u16 = 1",10
            DB "sub main() fails",10
            DB "    out = "
QTNNO:
            DB "u8(wide + u8(small))",10
            DB "end",10
QTNNTSE:
; Source-relative positions resolve after the later diagnostic corpus.
QTDIVPOS EQU QTNDO-QTNDTS
QTNARPOS EQU QTNNO-QTNNTS
