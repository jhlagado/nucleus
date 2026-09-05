ORG $D400
; Contract: out carry,zero clobbers sign,parity,halfCarry,A,BC,DE,HL,IX,IY
FPSTART:
            LD   SP,STACKTOP
            XOR  A
            LD   (FPSTATUS),A
            LD   (FPCASE),A
            LD   (PFMAXGEN),A
            LD   (PFMAXGEN+1),A

            LD   A,2
            LD   HL,C1DSCS
            CALL CPAGCLPT
            JP   C,FPCOMPFL
            CALL ZGPROG
            JP   C,PFENCERR
            CALL PFUPMAGE
            CALL RESET
            CALL QPCAGE
            JP   C,PFRUNERR
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,PFRUNERR
            LD   A,(VOUTLEN)
            CP   1
            JP   NZ,PFRUNERR
            LD   A,(VOUTBAS)
            CP   $59
            JP   NZ,PFRUNERR
            LD   A,(RTDEPTH)
            OR   A
            JP   NZ,PFRUNERR

            LD   A,2
            LD   (FPCASE),A
            LD   A,12
            LD   HL,C2S
            LD   DE,C2E
            CALL PFBLDONE
            JP   C,QF
            CALL PFRSTSVC
            LD   A,1
            LD   (VINLEN),A
            LD   A,$41
            LD   (VINBAS),A
            CALL QPCAGE
            JP   C,QF
            LD   A,$41
            CALL PFCKOUT
            JP   C,QF

            LD   A,3
            LD   (FPCASE),A
            LD   A,13
            LD   HL,C3S
            LD   DE,C3E
            CALL PFRUNONE
            JP   C,QF
            LD   A,4
            CALL PFCKOUT
            JP   C,QF

            LD   A,4
            LD   (FPCASE),A
            LD   A,14
            LD   HL,C4S
            LD   DE,C4E
            CALL PFRUNONE
            JP   C,QF
            LD   A,$59
            CALL PFCKOUT
            JP   C,QF

            LD   A,5
            LD   (FPCASE),A
            LD   A,15
            LD   HL,C5S
            LD   DE,C5E
            CALL PFRUNONE
            JP   C,QF
            LD   A,$52
            CALL PFCKOUT
            JP   C,QF

            LD   A,6
            LD   (FPCASE),A
            LD   A,16
            LD   HL,C6S
            LD   DE,C6E
            CALL PFRUNONE
            JP   C,QF
            LD   A,7
            CALL PFCKOUT
            JP   C,QF

            LD   A,7
            LD   (FPCASE),A
            LD   A,17
            LD   HL,C7S
            LD   DE,C7E
            CALL PFRUNONE
            JP   C,QF
            CALL PFCONOOU
            JP   C,QF
            LD   A,(VSOLEN)
            CP   2
            JP   NZ,QF
            LD   A,(VSOCUR)
            CP   1
            JP   NZ,QF
            LD   A,(VSOBAS)
            CP   $5A
            JP   NZ,QF
            LD   A,(VSOBAS+1)
            CP   $42
            JP   NZ,QF

            LD   A,8
            LD   (FPCASE),A
            LD   A,18
            LD   HL,C8S
            LD   DE,C8E
            CALL PFRUNONE
            JP   C,QF
            CALL PFCONOOU
            JP   C,QF

            LD   A,9
            LD   (FPCASE),A
            LD   A,19
            LD   HL,C9BNDS
            LD   DE,C9BNDE
            CALL PFBLDONE
            JP   C,QF
            CALL PFRSTSVC
            LD   A,1
            LD   (VINLEN),A
            LD   A,2
            LD   (VINBAS),A
            CALL QPCAGE
            JP   C,QF
            LD   A,1
            LD   BC,C9BNDP-C9BNDS
            CALL PFCKTRP
            JP   C,QF

            LD   A,10
            LD   (FPCASE),A
            LD   A,20
            LD   HL,C9DIVS
            LD   DE,C9DIVE
            CALL PFBLDONE
            JP   C,QF
            CALL PFRSTSVC
            LD   A,1
            LD   (VINLEN),A
            XOR  A
            LD   (VINBAS),A
            CALL QPCAGE
            JP   C,QF
            LD   A,3
            LD   BC,C9DIVP-C9DIVS
            CALL PFCKTRP
            JP   C,QF

            LD   A,21
            LD   (FPCASE),A
            LD   A,51
            LD   B,DGHDLINE
            LD   IX,C10UNCOP-C10UNCOS
            LD   HL,C10UNCOS
            LD   DE,C10UNCOE
            CALL PFEXDGON
            JP   C,QF

            LD   A,22
            LD   (FPCASE),A
            LD   A,52
            LD   B,DGTYPMIS
            LD   IX,C10NOMP+5-C10NOMS
            LD   HL,C10NOMS
            LD   DE,C10NOME
            CALL PFEXDGON
            JP   C,QF

            LD   A,23
            LD   (FPCASE),A
            LD   A,53
            LD   B,DGINICNT
            LD   IX,C10INIP-C10INIS
            LD   HL,C10INIS
            LD   DE,C10INIE
            CALL PFEXDGON
            JP   C,QF

            LD   A,24
            LD   (FPCASE),A
            LD   A,54
            LD   B,DXTYP
            LD   IX,C10AGLOP-C10AGLOS
            LD   HL,C10AGLOS
            LD   DE,C10AGLOE
            CALL PFEXDGON
            JP   C,QF

            LD   A,25
            LD   (FPCASE),A
            LD   A,55
            LD   B,DGRTNFLW
            LD   IX,C10RTFLP+3-C10RTFLS
            LD   HL,C10RTFLS
            LD   DE,C10RTFLE
            CALL PFEXDGON
            JP   C,QF

            LD   A,26
            LD   (FPCASE),A
            LD   A,56
            LD   B,DGUNKNAM
            LD   IX,C10LATRP-C10LATRS
            LD   HL,C10LATRS
            LD   DE,C10LATRE
            CALL PFEXDGON
            JP   C,QF

            LD   A,27
            LD   (FPCASE),A
            LD   A,57
            LD   B,DXRPAR
            LD   IX,C10MASIP-C10MASIS
            LD   HL,C10MASIS
            LD   DE,C10MASIE
            CALL PFEXDGON
            JP   C,QF

            LD   A,28
            LD   (FPCASE),A
            LD   A,58
            LD   B,DGACTCTR
            LD   IX,C10ACNAM-C10ACCTS
            LD   HL,C10ACCTS
            LD   DE,C10ACCTE
            CALL PFEXDGON
            JP   C,QF

            LD   A,60
            LD   (FPCASE),A
            LD   A,69
            LD   B,DGINTRNG
            LD   IX,C10EXUSP-C10EXUSS
            LD   HL,C10EXUSS
            LD   DE,C10EXUSE
            CALL PFEXDGON
            JP   C,QF
            LD   HL,(DGLINE)
            LD   DE,5
            OR   A
            SBC  HL,DE
            JP   NZ,QF
            LD   HL,(DGCOL)
            LD   DE,9
            OR   A
            SBC  HL,DE
            JP   NZ,QF

            LD   A,61
            LD   (FPCASE),A
            LD   A,70
            LD   B,DGINTRNG
            LD   IX,C10EXNEP-C10EXNES
            LD   HL,C10EXNES
            LD   DE,C10EXNEE
            CALL PFEXDGON
            JP   C,QF
            LD   HL,(DGLINE)
            LD   DE,5
            OR   A
            SBC  HL,DE
            JP   NZ,QF
            LD   HL,(DGCOL)
            LD   DE,10
            OR   A
            SBC  HL,DE
            JP   NZ,QF

            LD   A,62
            LD   (FPCASE),A
            LD   A,71
            LD   B,DGTYPMIS
            LD   IX,C10BAINP-C10BAINS
            LD   HL,C10BAINS
            LD   DE,C10BAINE
            CALL PFEXDGON
            JP   C,QF

            LD   A,63
            LD   (FPCASE),A
            LD   A,72
            LD   B,DGTYPMIS
            LD   IX,C10IABOP-C10IABOS
            LD   HL,C10IABOS
            LD   DE,C10IABOE
            CALL PFEXDGON
            JP   C,QF

            LD   A,29
            LD   (FPCASE),A
            LD   A,59
            LD   B,DGLEX
            LD   IX,C10HEXP-C10HEXS
            LD   HL,C10HEXS
            LD   DE,C10HEXE
            CALL PFEXDGON
            JP   C,QF

            LD   A,64
            LD   (FPCASE),A
            LD   A,73
            LD   B,DGLEX
            LD   IX,C10BINP-C10BINS
            LD   HL,C10BINS
            LD   DE,C10BINE
            CALL PFEXDGON
            JP   C,QF

            LD   A,30
            LD   (FPCASE),A
            LD   A,2
            LD   B,DGUNKNAM
            LD   C,2
            LD   IX,C11BADP+4-C11BPT2
            LD   HL,C11BADS
            CALL PFEXDGPT
            JP   C,QF
            LD   HL,(DGLINE)
            LD   DE,12
            OR   A
            SBC  HL,DE
            JP   NZ,QF
            LD   HL,(DGCOL)
            LD   DE,5
            OR   A
            SBC  HL,DE
            JP   NZ,QF

            LD   A,31
            LD   (FPCASE),A
            LD   A,2
            LD   HL,CBNDDSC
            CALL CPAGCLPT
            JP   C,QF
            CALL ZGPROG
            JP   C,QF
            CALL PFUPMAGE
            CALL PFRSTSVC
            CALL QPCAGE
            JP   C,QF
            LD   A,1
            CALL PFCKOUT
            JP   C,QF

            LD   A,32
            LD   (FPCASE),A
            LD   A,8
            LD   HL,CCAPDSC
            CALL CPAGCLPT
            JP   C,QF
            CALL ZGPROG
            JP   C,QF
            CALL PFUPMAGE
            CALL PFRSTSVC
            CALL QPCAGE
            JP   C,QF
            CALL PFCONOOU
            JP   C,QF

            LD   A,33
            LD   (FPCASE),A
            LD   A,9
            LD   B,DGSPTCAP
            LD   C,0
            LD   IX,0
            LD   HL,CCAPDSC
            CALL PFEXDGPT
            JP   C,QF

            LD   A,36
            LD   (FPCASE),A
            LD   A,1
            LD   HL,CONEDSC
            CALL CPAGCLPT
            JP   C,QF
            CALL ZGPROG
            JP   C,QF
            CALL PFUPMAGE
            CALL PFRSTSVC
            CALL QPCAGE
            JP   C,QF
            CALL PFCONOOU
            JP   C,QF

            LD   A,34
            LD   (FPCASE),A
            LD   A,2
            LD   B,DGLEX
            LD   C,71
            LD   IX,COPENP1E-COPENP1
            LD   HL,COPENDS
            CALL PFEXDGPT
            JP   C,QF

            LD   A,35
            LD   (FPCASE),A
            LD   A,2
            LD   HL,CBNDDSC
            CALL CPAGCLPT
            JP   C,QF
            CALL ZGPROG
            JP   C,QF
            CALL PFUPMAGE
            CALL PFRSTSVC
            CALL QPCAGE
            JP   C,QF
            LD   A,1
            CALL PFCKOUT
            JP   C,QF

            LD   A,12
            LD   (FPCASE),A
            LD   A,22
            LD   HL,C12S
            LD   DE,C12E
            CALL PFRUNONE
            JP   C,QF
            LD   A,6
            CALL PFCKOUT
            JP   C,QF

            LD   A,13
            LD   (FPCASE),A
            LD   A,23
            LD   HL,C13S
            LD   DE,C13E
            CALL PFRUNONE
            JP   C,QF
            LD   A,$59
            CALL PFCKOUT
            JP   C,QF

            LD   A,14
            LD   (FPCASE),A
            LD   A,24
            LD   HL,C14S
            LD   DE,C14E
            CALL PFRUNONE
            JP   C,QF
            LD   A,$59
            CALL PFCKOUT
            JP   C,QF

            LD   A,15
            LD   (FPCASE),A
            LD   A,25
            LD   HL,C15S
            LD   DE,C15E
            CALL PFRUNONE
            JP   C,QF
            LD   A,$59
            CALL PFCKOUT
            JP   C,QF

            LD   A,65
            LD   (FPCASE),A
            LD   A,74
            LD   HL,C16S
            LD   DE,C16E
            CALL PFRUNONE
            JP   C,QF
            LD   A,176
            CALL PFCKOUT
            JP   C,QF

            LD   A,66
            LD   (FPCASE),A
            LD   A,75
            LD   HL,C17S
            LD   DE,C17E
            CALL PFRUNONE
            JP   C,QF
            LD   A,$5A
            CALL PFCKOUT
            JP   C,QF

            LD   A,67
            LD   (FPCASE),A
            LD   A,76
            LD   B,DGTYPMIS
            LD   IX,C17BOOLP-C17BOOLS
            LD   HL,C17BOOLS
            LD   DE,C17BOOLE
            CALL PFEXDGON
            JP   C,QF

            LD   A,68
            LD   (FPCASE),A
            LD   A,77
            LD   HL,C18S
            LD   DE,C18E
            CALL PFRUNONE
            JP   C,QF
            LD   A,10
            CALL PFCKOUT
            JP   C,QF

            LD   A,69
            LD   (FPCASE),A
            LD   A,78
            LD   B,DGDIVZER
            LD   IX,C18ZEROP-C18ZEROS
            LD   HL,C18ZEROS
            LD   DE,C18ZEROE
            CALL PFEXDGON
            JP   C,QF

            LD   A,70
            LD   (FPCASE),A
            LD   A,79
            LD   HL,C9MODS
            LD   DE,C9MODE
            CALL PFBLDONE
            JP   C,QF
            CALL PFRSTSVC
            LD   A,1
            LD   (VINLEN),A
            XOR  A
            LD   (VINBAS),A
            CALL QPCAGE
            JP   C,QF
            LD   A,3
            LD   BC,C9MODP-C9MODS
            CALL PFCKTRP
            JP   C,QF

            LD   A,71
            LD   (FPCASE),A
            LD   A,80
            LD   HL,C19S
            LD   DE,C19E
            CALL PFRUNONE
            JP   C,QF
            LD   A,128
            CALL PFCKOUT
            JP   C,QF
            LD   A,83
            LD   HL,C19CTRLS
            LD   DE,C19CTRLE
            CALL PFBLDONE
            JP   C,QF
            CALL PFCMPUPR
            JP   C,QF

            LD   A,72
            LD   (FPCASE),A
            LD   A,81
            LD   B,DGASSERT
            LD   IX,C19FALP-C19FALS
            LD   HL,C19FALS
            LD   DE,C19FALE
            CALL PFEXDGON
            JP   C,QF

            LD   A,73
            LD   (FPCASE),A
            LD   A,82
            LD   B,DGTYPMIS
            LD   IX,C19TYP-C19TYS
            LD   HL,C19TYS
            LD   DE,C19TYE
            CALL PFEXDGON
            JP   C,QF

            LD   A,74
            LD   (FPCASE),A
            LD   A,83
            LD   HL,C20S
            LD   DE,C20E
            CALL PFRUNONE
            JP   C,QF
            LD   A,$59
            CALL PFCKOUT
            JP   C,QF

            LD   A,75
            LD   (FPCASE),A
            LD   A,84
            LD   B,DGROASGN
            LD   IX,C20RDONP-C20RDONS
            LD   HL,C20RDONS
            LD   DE,C20RDONE
            CALL PFEXDGON
            JP   C,QF

            LD   A,76
            LD   (FPCASE),A
            LD   A,85
            LD   B,DGLEX
            LD   IX,P9BADHXP-P9BADHXS
            LD   HL,P9BADHXS
            LD   DE,P9BADHXE
            CALL PFEXDGON
            JP   C,QF
            LD   HL,(DGLINE)
            LD   DE,1
            OR   A
            SBC  HL,DE
            JP   NZ,QF
            LD   HL,(DGCOL)
            LD   DE,27
            OR   A
            SBC  HL,DE
            JP   NZ,QF

            LD   A,77
            LD   (FPCASE),A
            LD   A,86
            LD   B,DGLEX
            LD   IX,P9SHRHXP-P9SHRHXS
            LD   HL,P9SHRHXS
            LD   DE,P9SHRHXE
            CALL PFEXDGON
            JP   C,QF
            LD   HL,(DGLINE)
            LD   DE,1
            OR   A
            SBC  HL,DE
            JP   NZ,QF
            LD   HL,(DGCOL)
            LD   DE,27
            OR   A
            SBC  HL,DE
            JP   NZ,QF

            LD   A,78
            LD   (FPCASE),A
            LD   A,87
            LD   HL,C22S
            LD   DE,C22E
            CALL PFRUNONE
            JP   C,QF
            LD   A,7
            CALL PFCKOUT
            JP   C,QF

            LD   A,79
            LD   (FPCASE),A
            LD   A,88
            LD   B,DGTYPMIS
            LD   IX,C22BOOLP+4-C22BOOLS
            LD   HL,C22BOOLS
            LD   DE,C22BOOLE
            CALL PFEXDGON
            JP   C,QF

            LD   A,$A5
            LD   (FPSTATUS),A
            XOR  A
            LD   (FPCASE),A
            HALT

; Contract: in A,DE,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
PFBLDONE:
            CALL CPAGCLSL
            RET  C
            CALL ZGPROG
            RET  C
            JR   PFUPMAGE

; Contract: in A,DE,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
PFRUNONE:
            CALL PFBLDONE
            RET  C
            CALL PFRSTSVC
            JP   QPCAGE

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
PFUPMAGE:
            LD   HL,(GNSZ)
            LD   DE,(GNROSZ)
            ADD  HL,DE
            LD   B,H
            LD   C,L
            LD   DE,(PFMAXGEN)
            OR   A
            SBC  HL,DE
            JR   C,PFUPMADO
            JR   Z,PFUPMADO
            LD   H,B
            LD   L,C
            LD   (PFMAXGEN),HL
            LD   HL,(GNSZ)
            LD   (PFMAGECO),HL
            LD   HL,(GNROSZ)
            LD   (PFMGRODA),HL
            LD   HL,(GNDATSZ)
            LD   (PFMAGEDA),HL
            LD   HL,(GNBSSSZ)
            LD   (PFMAGEBS),HL
PFUPMADO:
            XOR  A
            RET

; The just-published image must match the preceding image retained by
; BeginProgram. This directly proves that a successful assert contributes no
; semantic operation or generated byte.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
PFCMPUPR:
            LD   HL,(GNSZ)
            LD   DE,(PUSZ)
            OR   A
            SBC  HL,DE
            JR   NZ,PFCMPUNO
            LD   HL,(GNROSZ)
            LD   DE,(PUROSZ)
            OR   A
            SBC  HL,DE
            JR   NZ,PFCMPUNO
            LD   HL,(GNDATSZ)
            LD   DE,(PUDATSZ)
            OR   A
            SBC  HL,DE
            JR   NZ,PFCMPUNO
            LD   HL,(GNBSSSZ)
            LD   DE,(PUBSSSZ)
            OR   A
            SBC  HL,DE
            JR   NZ,PFCMPUNO
            LD   BC,(GNSZ)
            LD   HL,MMGEN
            LD   DE,MMBACK
PFCMPULP:
            LD   A,B
            OR   C
            JR   Z,PFCPRODA
            LD   A,(DE)
            CP   (HL)
            JR   NZ,PFCMPUNO
            INC  DE
            INC  HL
            DEC  BC
            JR   PFCMPULP
PFCPRODA:
            LD   BC,(GNROSZ)
            LD   HL,RORDATA
            LD   DE,MMBACK+(RORDATA-MMGEN)
PFCPRDLP:
            LD   A,B
            OR   C
            RET  Z
            LD   A,(DE)
            CP   (HL)
            JR   NZ,PFCMPUNO
            INC  DE
            INC  HL
            DEC  BC
            JR   PFCPRDLP
PFCMPUNO:
            SCF
            RET

; Contract: in A,B,DE,HL,IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
PFEXDGON:
            LD   (PFEXPPT),A
            LD   A,B
            LD   (PFEXPDG),A
            PUSH IX
            POP  BC
            LD   (PFEXPOFF),BC
            LD   A,(PFEXPPT)
            LD   (QPEXSP),SP
            CALL CPAGCLSL
            JR   NC,PFDGERR
            LD   HL,0
            ADD  HL,SP
            LD   DE,(QPEXSP)
            OR   A
            SBC  HL,DE
            JR   NZ,PFDGERR
            JR   PFCKDG

; Contract: in A,B,C,HL,IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
PFEXDGPT:
            LD   (PFPTCNT),A
            LD   A,B
            LD   (PFEXPDG),A
            LD   A,C
            LD   (PFEXPPT),A
            PUSH IX
            POP  BC
            LD   (PFEXPOFF),BC
            LD   A,(PFPTCNT)
            CALL CPAGCLPT
            JR   NC,PFDGERR
PFCKDG:
            LD   A,(PFEXPDG)
            LD   HL,DGCODE
            CP   (HL)
            JR   NZ,PFDGERR
            LD   A,(PFEXPPT)
            LD   HL,DGPARTID
            CP   (HL)
            JR   NZ,PFDGERR
            LD   HL,(DGOFF)
            LD   DE,(PFEXPOFF)
            OR   A
            SBC  HL,DE
            RET  Z
PFDGERR:
            SCF
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,HL
PFRSTSVC:
            CALL RESET
            XOR  A
            LD   (VINLEN),A
            LD   (VSILEN),A
            RET

; Contract: in A out A,carry,zero clobbers sign,parity,halfCarry,B,HL
PFCKOUT:
            LD   B,A
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JR   NZ,PFCKERR
            LD   A,(VOUTLEN)
            CP   1
            JR   NZ,PFCKERR
            LD   A,(VOUTBAS)
            CP   B
            JR   NZ,PFCKERR
            LD   A,(RTDEPTH)
            OR   A
            RET  Z
PFCKERR:
            SCF
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,HL
PFCONOOU:
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JR   NZ,PFCKERR
            LD   A,(VOUTLEN)
            OR   A
            JR   NZ,PFCKERR
            LD   A,(RTDEPTH)
            OR   A
            RET  Z
            SCF
            RET

; Contract: in A,BC out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
PFCKTRP:
            LD   (PFEXPTRP),A
            LD   (PFEXPOFF),BC
            LD   A,(RUNSTATE)
            CP   RTTRAP
            JR   NZ,PFCKERR
            LD   A,(PFEXPTRP)
            LD   HL,RTTRPNO
            CP   (HL)
            JR   NZ,PFCKERR
            LD   HL,(RTTRPOFF)
            LD   DE,(PFEXPOFF)
            OR   A
            SBC  HL,DE
            JR   NZ,PFCKERR
            LD   A,(RTDEPTH)
            OR   A
            RET  Z
            SCF
            RET

; Generated code must restore the root SP and IX on every terminal path.
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
            JR   NZ,PFCALLNO
            LD   HL,0
            ADD  HL,SP
            LD   DE,(QPEXSP)
            OR   A
            SBC  HL,DE
            RET  Z
PFCALLNO:
            SCF
            RET

FPCOMPFL: LD A,1
                     JR QF
PFENCERR:  LD A,2
                     JR QF
PFRUNERR:     LD A,3
QF:
            LD   (FPCASE),A
            HALT

QPEXSP: DW 0
PFEXPOFF: DW 0
PFEXPTRP: DB 0
PFMAXGEN: DW 0
PFMAGECO: DW 0
PFMGRODA: DW 0
PFMAGEDA: DW 0
PFMAGEBS: DW 0
PFEXPDG: DB 0
PFEXPPT: DB 0
PFPTCNT: DB 0
FPSTATUS:     DB 0
FPCASE:       DB 0
FPEND:
