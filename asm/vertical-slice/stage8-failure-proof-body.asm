ORG $D000
; Contract: out carry,zero clobbers sign,parity,halfCarry,A,BC,DE,HL,IX,IY
FPSTART:
            LD   SP,STACKTOP
            XOR  A
            LD   (FPSTATUS),A
            LD   (FPCASE),A

            LD   A,170
            LD   HL,P8MAINFS
            LD   DE,P8MAINFE
            CALL CPAGCLSL
            JP   C,FPCOMPFL
            CALL ZGPROG
            JP   C,PFENCERR
            CALL RESET
            CALL QPCAGE
            JP   C,PFFRMERR
            LD   A,(RUNSTATE)
            CP   RTTRAP
            JP   NZ,PFTRSTER
            LD   A,(RTTRPNO)
            CP   6
            JP   NZ,PFTRRSER
            LD   A,(RTTRPERR)
            CP   7
            JP   NZ,PFTRERER
            LD   HL,(RTTRPOFF)
            LD   DE,P8MAINFP-P8MAINFS
            LD   (PFACTROF),HL
            LD   (PFEXTROF),DE
            OR   A
            SBC  HL,DE
            JP   NZ,PFTROFER
            LD   A,(RTDEPTH)
            OR   A
            JP   NZ,PFACTERR

            LD   A,DGFAICTX
            LD   BC,P8INFFP-P8INFFS
            LD   HL,P8INFFS
            LD   DE,P8INFFE
            CALL QPEXDI
            JP   C,PFINFERR

            LD   A,DGINTRNG
            LD   BC,P8ERRNGP+5-P8ERRNGS
            LD   HL,P8ERRNGS
            LD   DE,P8ERRNGE
            CALL QPEXDI
            JP   C,PFRNGERR

            LD   A,DGRTNFLW
            LD   BC,P8ERFLWP-1-P8ERFLWS
            LD   HL,P8ERFLWS
            LD   DE,P8ERFLWE
            CALL QPEXDI
            JP   C,PFFLWERR

            LD   A,172
            LD   HL,P8PROOKS
            LD   DE,P8PROOKE
            CALL CPAGCLSL
            JP   C,PFPOCMER
            CALL ZGPROG
            JP   C,PFPOENER
            CALL RESET
            CALL QPCAGE
            JP   C,PFPORUER
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,PFPORUER
            LD   A,(VOUTLEN)
            CP   1
            JP   NZ,PFPORUER
            LD   A,(VOUTBAS)
            CP   $41
            JP   NZ,PFPORUER

            LD   A,173
            LD   HL,P8PRERRS
            LD   DE,P8PRERRE
            CALL CPAGCLSL
            JP   C,PFPECMER
            CALL ZGPROG
            JP   C,PFPEENER
            CALL RESET
            CALL QPCAGE
            JP   C,PFPERUER
            LD   A,(RUNSTATE)
            CP   RTTRAP
            JP   NZ,PFPERUER
            LD   A,(RTTRPNO)
            CP   6
            JP   NZ,PFPERUER
            LD   A,(RTTRPERR)
            CP   10
            JP   NZ,PFPERUER
            LD   HL,(RTTRPOFF)
            LD   DE,P8PRERRP-P8PRERRS
            OR   A
            SBC  HL,DE
            JP   NZ,PFPERUER

            LD   A,174
            LD   HL,P8BARETS
            LD   DE,P8BARETE
            CALL CPAGCLSL
            JP   C,PFBRCMER
            CALL ZGPROG
            JP   C,PFBRENER
            CALL RESET
            CALL QPCAGE
            JP   C,PFBRRUER
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,PFBRRUER
            LD   A,(VOUTLEN)
            CP   1
            JP   NZ,PFBRRUER
            LD   A,(VOUTBAS)
            OR   A
            JP   NZ,PFBRRUER

            LD   A,175
            LD   HL,P8SIARGS
            LD   DE,P8SIARGE
            CALL CPAGCLSL
            JP   C,PFSICMER
            CALL ZGPROG
            JP   C,PFSIENER
            CALL RESET
            CALL QPCAGE
            JP   C,PFSIRUER
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,PFSIRUER
            LD   A,(VOUTLEN)
            CP   1
            JP   NZ,PFSIRUER
            LD   A,(VOUTBAS)
            CP   16
            JP   NZ,PFSIRUER

            LD   A,176
            LD   HL,P8LOCRTS
            LD   DE,P8LOCRTE
            CALL CPAGCLSL
            JP   C,PFHNCMER
            CALL ZGPROG
            JP   C,PFHNENER
            CALL RESET
            CALL QPCAGE
            JP   C,PFHNRUER
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,PFHNRUER
            LD   A,(VOUTLEN)
            CP   1
            JP   NZ,PFHNRUER
            LD   A,(VOUTBAS)
            CP   7
            JP   NZ,PFHNRUER

            LD   A,204
            LD   HL,P8PRHNDS
            LD   DE,P8PRHNDE
            CALL CPAGCLSL
            JP   C,PFPHCMER
            CALL ZGPROG
            JP   C,PFPHENER
            CALL RESET
            CALL QPCAGE
            JP   C,PFPHRUER
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,PFPHRUER
            LD   A,(RTDEPTH)
            OR   A
            JP   NZ,PFPHRUER
            LD   A,(MMBSS)
            CP   7
            JP   NZ,PFPHRUER
            LD   A,(VOUTLEN)
            CP   1
            JP   NZ,PFPHRUER
            LD   A,(VOUTBAS)
            CP   8
            JP   NZ,PFPHRUER

            LD   A,177
            LD   HL,P8RINOKS
            LD   DE,P8RINOKE
            CALL CPAGCLSL
            JP   C,PFROCMER
            CALL ZGPROG
            JP   C,PFROENER
            CALL RESET
            LD   A,1
            LD   (VINLEN),A
            LD   A,$51
            LD   (VINBAS),A
            CALL QPCAGE
            JP   C,PFRORUER
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,PFRORUER
            LD   A,(VINCUR)
            CP   1
            JP   NZ,PFRORUER
            LD   A,(VOUTBAS)
            CP   $51
            JP   NZ,PFRORUER
            CALL RESET
            LD   A,1
            LD   (VINLEN),A
            LD   A,$51
            LD   (VINBAS),A
            LD   A,1
            LD   (SVFAIL),A
            CALL QPCAGE
            JP   C,PFRORUER
            LD   A,(RUNSTATE)
            CP   RTTRAP
            JP   NZ,PFRORUER
            LD   A,(RTTRPERR)
            CP   3
            JP   NZ,PFRORUER
            LD   HL,(RTTRPOFF)
            LD   DE,P8RINSVP-P8RINOKS
            OR   A
            SBC  HL,DE
            JP   NZ,PFRORUER

            LD   A,117
            LD   (FPCASE),A
            LD   A,178
            LD   HL,P8SFRBNS
            LD   DE,P8SFRBNE
            CALL CPAGCLSL
            JP   C,PFRDEERR
            CALL ZGPROG
            JP   C,PFRDEERR
            CALL RESET
            CALL QPCAGE
            JP   C,PFRDEERR
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,PFRDEERR
            LD   A,(VOUTLEN)
            CP   1
            JP   NZ,PFRDEERR
            LD   A,(VOUTBAS)
            CP   1
            JP   NZ,PFRDEERR
            LD   A,(RTDEPTH)
            OR   A
            JP   NZ,PFRDEERR

            LD   A,178
            LD   HL,P8RINHNS
            LD   DE,P8RINHNE
            CALL CPAGCLSL
            JP   C,PFRHCMER
            CALL ZGPROG
            JP   C,PFRHENER
            CALL RESET
            XOR  A
            LD   (VINLEN),A
            CALL QPCAGE
            JP   C,PFRHRUER
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,PFRHRUER
            LD   A,(VINCUR)
            OR   A
            JP   NZ,PFRHRUER
            LD   A,(VOUTLEN)
            CP   1
            JP   NZ,PFRHRUER
            LD   A,(VOUTBAS)
            CP   1
            JP   NZ,PFRHRUER

            ; The same handler must receive inputFailure without advancing the
            ; cursor or converting the recoverable error into a trap.
            CALL RESET
            LD   A,2
            LD   (VINFAIL),A
            CALL QPCAGE
            JP   C,PFRHRUER
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,PFRHRUER
            LD   A,(VINCUR)
            OR   A
            JP   NZ,PFRHRUER
            LD   A,(VOUTBAS)
            CP   2
            JP   NZ,PFRHRUER

            ; A distinct reset run must not inherit the configured failure.
            CALL RESET
            LD   A,(VINFAIL)
            OR   A
            JP   NZ,PFRHRUER
            LD   A,1
            LD   (VINLEN),A
            LD   A,$51
            LD   (VINBAS),A
            CALL QPCAGE
            JP   C,PFRHRUER
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,PFRHRUER
            LD   A,(VINCUR)
            CP   1
            JP   NZ,PFRHRUER
            LD   A,(VOUTBAS)
            CP   $51
            JP   NZ,PFRHRUER

            LD   A,179
            LD   HL,P8CSTSS
            LD   DE,P8CSTSE
            CALL CPAGCLSL
            JP   C,PFCSSCMP
            CALL ZGPROG
            JP   C,PFCSSENC
            CALL RESET
            CALL QPCAGE
            JP   C,PFCSSRUN
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,PFCSSRUN
            LD   A,(VOUTBAS)
            CP   $43
            JP   NZ,PFCSSRUN

            LD   A,180
            LD   HL,P8STOOKS
            LD   DE,P8STOOKE
            CALL CPAGCLSL
            JP   C,PFSTCMER
            CALL ZGPROG
            JP   C,PFSTENER
            CALL RESET
            XOR  A
            LD   (VSIFAIL),A
            LD   (VSOFAIL),A
            INC  A
            LD   (VSILEN),A
            LD   A,$41
            LD   (VSIBAS),A
            CALL QPCAGE
            JP   C,PFSTRUER
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,PFSTRUER
            LD   A,(VSICUR)
            CP   1
            JP   NZ,PFSTRUER
            LD   A,(VSOLEN)
            CP   2
            JP   NZ,PFSTRUER
            LD   A,(VSOCUR)
            CP   1
            JP   NZ,PFSTRUER
            LD   A,(VSOBAS)
            CP   $5A
            JP   NZ,PFSTRUER
            LD   A,(VSOBAS+1)
            CP   $42
            JP   NZ,PFSTRUER
            LD   A,(VOUTBAS)
            CP   $41
            JP   NZ,PFSTRUER

            LD   A,181
            LD   HL,P8WRERRS
            LD   DE,P8WRERRE
            CALL CPAGCLSL
            JP   C,PFWRERCM
            CALL ZGPROG
            JP   C,PFWREREN
            CALL RESET
            LD   A,1
            LD   (VSOFAIL),A
            LD   (VSOCUR),A
            INC  A
            LD   (VSOLEN),A
            LD   A,$58
            LD   (VSOBAS),A
            LD   A,$59
            LD   (VSOBAS+1),A
            CALL QPCAGE
            JP   C,PFWRERRU
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,PFWRERRU
            LD   A,(VSOLEN)
            CP   2
            JP   NZ,PFWRERRU
            LD   A,(VSOCUR)
            CP   1
            JP   NZ,PFWRERRU
            LD   A,(VSOBAS)
            CP   $58
            JP   NZ,PFWRERRU
            LD   A,(VSOBAS+1)
            CP   $59
            JP   NZ,PFWRERRU
            LD   A,(VOUTBAS)
            CP   4
            JP   NZ,PFWRERRU

            LD   A,182
            LD   HL,P8SEERRS
            LD   DE,P8SEERRE
            CALL CPAGCLSL
            JP   C,PFSEERCM
            CALL ZGPROG
            JP   C,PFSEEREN
            CALL RESET
            XOR  A
            LD   (VSOFAIL),A
            INC  A
            LD   (VSOCUR),A
            INC  A
            LD   (VSOLEN),A
            CALL QPCAGE
            JP   C,PFSEERRU
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,PFSEERRU
            LD   A,(VSOCUR)
            CP   1
            JP   NZ,PFSEERRU
            LD   A,(VOUTBAS)
            CP   4
            JP   NZ,PFSEERRU

            LD   A,183
            LD   HL,P8REERRS
            LD   DE,P8REERRE
            CALL CPAGCLSL
            JP   C,PFREERCM
            CALL ZGPROG
            JP   C,PFREEREN
            CALL RESET
            LD   A,1
            LD   (VSIFAIL),A
            INC  A
            LD   (VSICUR),A
            CALL QPCAGE
            JP   C,PFREERRU
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,PFREERRU
            LD   A,(VSICUR)
            CP   2
            JP   NZ,PFREERRU
            LD   A,(VOUTBAS)
            CP   4
            JP   NZ,PFREERRU

            LD   A,184
            LD   HL,P8RSTERS
            LD   DE,P8RSTERE
            CALL CPAGCLSL
            JP   C,PFRSERCM
            CALL ZGPROG
            JP   C,PFRSEREN
            CALL RESET
            XOR  A
            LD   (VSIFAIL),A
            LD   (VSILEN),A
            CALL QPCAGE
            JP   C,PFRSERRU
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,PFRSERRU
            LD   A,(VSICUR)
            OR   A
            JP   NZ,PFRSERRU
            LD   A,(VOUTBAS)
            CP   1
            JP   NZ,PFRSERRU

            LD   A,185
            LD   HL,P8WOUERS
            LD   DE,P8WOUERE
            CALL CPAGCLSL
            JP   C,PFWOERCM
            CALL ZGPROG
            JP   C,PFWOEREN
            CALL RESET
            LD   A,1
            LD   (SVFAIL),A
            CALL QPCAGE
            JP   C,PFWOERRU
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,PFWOERRU
            LD   A,(VOUTLEN)
            OR   A
            JP   NZ,PFWOERRU
            XOR  A
            LD   (SVFAIL),A

            LD   A,186
            LD   HL,P8MUFWDS
            LD   DE,P8MUFWDE
            CALL CPAGCLSL
            JP   C,PFMUCMER
            CALL ZGPROG
            JP   C,PFMUENER
            CALL RESET
            CALL QPCAGE
            JP   C,PFMURUER
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,PFMURUER
            LD   A,(VOUTLEN)
            CP   1
            JP   NZ,PFMURUER
            LD   A,(VOUTBAS)
            CP   $4D
            JP   NZ,PFMURUER

            LD   A,DGFWDINC
            LD   BC,P8INFWDE-P8INFWDS
            LD   HL,P8INFWDS
            LD   DE,P8INFWDE
            CALL QPEXDI
            JP   C,PFINFWER

            LD   A,DGDUPNAM
            LD   BC,P8PRVARP-P8PRVARS
            LD   HL,P8PRVARS
            LD   DE,P8PRVARE
            CALL QPEXDI
            JP   C,PFPRVAER
            LD   HL,(DGLINE)
            LD   DE,1
            OR   A
            SBC  HL,DE
            JP   NZ,PFPRVAER
            LD   HL,(DGCOL)
            LD   DE,5
            OR   A
            SBC  HL,DE
            JP   NZ,PFPRVAER

            LD   A,DGDUPNAM
            LD   BC,P8PRRTNP-P8PRRTNS
            LD   HL,P8PRRTNS
            LD   DE,P8PRRTNE
            CALL QPEXDI
            JP   C,PFPRRTER

            LD   A,DGDUPNAM
            LD   BC,P8PRPARP-P8PRPARS
            LD   HL,P8PRPARS
            LD   DE,P8PRPARE
            CALL QPEXDI
            JP   C,PFPRPAER

            LD   A,DGTYPMIS
            LD   BC,P8WSTTYP+4-P8WSTTYS
            LD   HL,P8WSTTYS
            LD   DE,P8WSTTYE
            CALL QPEXDI
            JP   C,PFWSTYER

            LD   A,DGTYPMIS
            LD   BC,P8SSTTYP+4-P8SSTTYS
            LD   HL,P8SSTTYS
            LD   DE,P8SSTTYE
            CALL QPEXDI
            JP   C,PFSSTYER

            LD   A,DGDUPNAM
            LD   BC,P8SEFWDP-P8SEFWDS
            LD   HL,P8SEFWDS
            LD   DE,P8SEFWDE
            CALL QPEXDI
            JP   C,PFSEFWER

            LD   A,DGUNKNAM
            LD   BC,P8UNCMPP-P8UNCMPS
            LD   HL,P8UNCMPS
            LD   DE,P8UNCMPE
            CALL QPEXDI
            JP   C,PFUNCMER

            LD   A,DGHDLINE
            LD   BC,P8UNSVCP-1-P8UNSVCS
            LD   HL,P8UNSVCS
            LD   DE,P8UNSVCE
            CALL QPEXDI
            JP   C,PFUNSVER

            LD   A,DGFAICTX
            LD   BC,P8NESVCP-P8NESVCS
            LD   HL,P8NESVCS
            LD   DE,P8NESVCE
            CALL QPEXDI
            JP   C,PFNESVER

            LD   A,DGFAICTX
            LD   BC,P8SVARGP+15-P8SVARGS
            LD   HL,P8SVARGS
            LD   DE,P8SVARGE
            CALL QPEXDI
            JP   C,PFSVARER

            LD   A,DGFAICTX
            LD   BC,P8COFLBP-P8COFLBS
            LD   HL,P8COFLBS
            LD   DE,P8COFLBE
            CALL QPEXDI
            JP   C,PFCOFLER

            LD   A,DGFAICTX
            LD   BC,P8ASFFLP-P8ASFFLS
            LD   HL,P8ASFFLS
            LD   DE,P8ASFFLE
            CALL QPEXDI
            JP   C,PFASFLER

            LD   A,DGFAICTX
            LD   BC,P8IDFLBP-P8IDFLBS
            LD   HL,P8IDFLBS
            LD   DE,P8IDFLBE
            CALL QPEXDI
            JP   C,PFIDFLER

            LD   A,DGFAICTX
            LD   BC,P8AARFLP-P8AARFLS
            LD   HL,P8AARFLS
            LD   DE,P8AARFLE
            CALL QPEXDI
            JP   C,PFAAFLER

            LD   A,192
            LD   HL,P8NEFRMS
            LD   DE,P8NEFRME
            CALL CPAGCLSL
            JP   C,PFNFCMER
            CALL ZGPROG
            JP   C,PFNFENER
            CALL RESET
            CALL QPCAGE
            JP   C,PFNFRUER
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,PFNFRUER
            LD   A,(VOUTLEN)
            CP   1
            JP   NZ,PFNFRUER
            LD   A,(VOUTBAS)
            CP   $4E
            JP   NZ,PFNFRUER
            LD   A,(RTDEPTH)
            OR   A
            JP   NZ,PFNFRUER

            LD   A,193
            LD   HL,P8PRSTES
            LD   DE,P8PRSTEE
            CALL CPAGCLSL
            JP   C,PFPSCMER
            CALL ZGPROG
            JP   C,PFPSENER
            CALL RESET
            CALL QPCAGE
            JP   C,PFPSRUER
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,PFPSRUER
            LD   A,(VOUTLEN)
            CP   2
            JP   NZ,PFPSRUER
            LD   A,(VOUTBAS)
            CP   $53
            JP   NZ,PFPSRUER
            LD   A,(VOUTBAS+1)
            CP   $53
            JP   NZ,PFPSRUER

            LD   A,115
            LD   (FPCASE),A
            LD   A,198
            LD   HL,P8REFLDS
            LD   DE,P8REFLDE
            CALL CPAGCLSL
            JP   C,PFRFCMER
            LD   HL,(M8PTR)
            INC  HL
            INC  HL
            LD   A,(HL)
            CP   1
            JP   NZ,PFRFVAER
            INC  HL
            LD   A,(HL)
            CP   SMSTIND8
            JP   NZ,PFRFWIER

            LD   A,194
            LD   HL,P8INDHDS
            LD   DE,P8INDHDE
            CALL CPAGCLSL
            JP   C,PFIHCMER
            CALL ZGPROG
            JP   C,PFIHENER
            CALL RESET
            CALL QPCAGE
            JP   C,PFIHRUER
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,PFIHRUER
            LD   A,(VOUTLEN)
            CP   2
            JP   NZ,PFIHRUER
            LD   A,(VOUTBAS)
            CP   7
            JP   NZ,PFIHRUER
            LD   A,(VOUTBAS+1)
            CP   9
            JP   NZ,PFIHRUER
            LD   A,(RTDEPTH)
            OR   A
            JP   NZ,PFIHRUER

            LD   A,195
            LD   HL,P8ACPHNS
            LD   DE,P8ACPHNE
            CALL CPAGCLSL
            JP   C,PFACHCER
            CALL ZGPROG
            JP   C,PFACHEER
            CALL RESET
            CALL QPCAGE
            JP   C,PFACHRER
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,PFACHRER
            LD   A,(VOUTLEN)
            CP   3
            JP   NZ,PFACHRER
            LD   A,(VOUTBAS)
            CP   5
            JP   NZ,PFACHRER
            LD   A,(VOUTBAS+1)
            CP   7
            JP   NZ,PFACHRER
            LD   A,(VOUTBAS+2)
            CP   5
            JP   NZ,PFACHRER
            LD   A,(RTDEPTH)
            OR   A
            JP   NZ,PFACHRER

            LD   A,196
            LD   HL,P8RERSTS
            LD   DE,P8RERSTE
            CALL CPAGCLSL
            JP   C,PFRRCMER
            CALL ZGPROG
            JP   C,PFRRENER
            CALL RESET
            LD   A,4
            LD   (VSIFAIL),A
            CALL QPCAGE
            JP   C,PFRRRUER
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,PFRRRUER
            LD   A,(VOUTLEN)
            CP   1
            JP   NZ,PFRRRUER
            LD   A,(VOUTBAS)
            CP   4
            JP   NZ,PFRRRUER
            LD   A,(RTDEPTH)
            OR   A
            JP   NZ,PFRRRUER

            LD   A,197
            LD   HL,P8ISVHNS
            LD   DE,P8ISVHNE
            CALL CPAGCLSL
            JP   C,PFISCMER
            CALL ZGPROG
            JP   C,PFISENER
            CALL RESET
            XOR  A
            LD   (VINLEN),A
            CALL QPCAGE
            JP   C,PFISRUER
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,PFISRUER
            LD   A,(VOUTLEN)
            CP   2
            JP   NZ,PFISRUER
            LD   A,(VOUTBAS)
            CP   1
            JP   NZ,PFISRUER
            LD   A,(VOUTBAS+1)
            CP   9
            JP   NZ,PFISRUER
            LD   A,(RTDEPTH)
            OR   A
            JP   NZ,PFISRUER

            LD   A,187
            LD   HL,P8TBYHNS
            LD   DE,P8TBYHNE
            CALL CPAGCLSL
            JP   C,PFTBCMER
            CALL ZGPROG
            JP   C,PFTBENER
            CALL RESET
            LD   A,2
            LD   (RTACTLIM),A
            CALL QPCAGE
            JP   C,PFTBFRER
            LD   A,(RUNSTATE)
            CP   RTTRAP
            JP   NZ,PFTBRUER
            LD   A,(RTTRPNO)
            CP   5
            JP   NZ,PFTBRUER
            LD   HL,(RTTRPOFF)
            LD   DE,P8TRECAP-P8TBYHNS
            OR   A
            SBC  HL,DE
            JP   NZ,PFTBRUER
            LD   A,(RTDEPTH)
            OR   A
            JP   NZ,PFTBRUER
            LD   A,(VOUTLEN)
            OR   A
            JP   NZ,PFTBRUER

            LD   A,188
            LD   HL,P8RFRRES
            LD   DE,P8RFRREE
            CALL CPAGCLSL
            JP   C,PFRFRCER
            CALL ZGPROG
            JP   C,PFRFREER
            CALL RESET
            CALL QPCAGE
            JP   C,PFRFRRER
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,PFRFRRER
            LD   A,(VOUTLEN)
            CP   1
            JP   NZ,PFRFRRER
            LD   A,(VOUTBAS)
            CP   $52
            JP   NZ,PFRFRRER
            LD   A,(RTDEPTH)
            OR   A
            JP   NZ,PFRFRRER

            LD   A,189
            LD   HL,P8FWMAIS
            LD   DE,P8FWMAIE
            CALL CPAGCLSL
            JP   C,PFFMCMER
            CALL ZGPROG
            JP   C,PFFMENER
            CALL PFVALPUB
            JP   C,PFPUBERR
            CALL RESET
            CALL QPCAGE
            JP   C,PFFMRUER
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,PFFMRUER
            LD   A,(VOUTLEN)
            CP   1
            JP   NZ,PFFMRUER
            LD   A,(VOUTBAS)
            CP   $4D
            JP   NZ,PFFMRUER
            LD   A,(RTDEPTH)
            OR   A
            JP   NZ,PFFMRUER

            LD   A,191
            LD   HL,P8REMAIS
            LD   DE,P8REMAIE
            CALL CPAGCLSL
            JP   C,PFRMCMER
            CALL ZGPROG
            JP   C,PFRMENER
            CALL RESET
            CALL QPCAGE
            JP   C,PFRMRUER
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,PFRMRUER
            LD   A,(VOUTLEN)
            CP   1
            JP   NZ,PFRMRUER
            LD   A,(VOUTBAS)
            CP   $44
            JP   NZ,PFRMRUER
            LD   A,(RTDEPTH)
            OR   A
            JP   NZ,PFRMRUER

            LD   A,DGFWDINC
            LD   BC,P8IFWMAE-P8IFWMAS
            LD   HL,P8IFWMAS
            LD   DE,P8IFWMAE
            CALL QPEXDI
            JP   C,PFIFMAER

            LD   A,1
            LD   BC,P8BNTRPP-P8BNTRPS
            LD   HL,P8BNTRPS
            LD   DE,P8BNTRPE
            CALL PFEXRUTR
            JP   C,PFBNTRER

            LD   A,2
            LD   BC,P8NATRPP-P8NATRPS
            LD   HL,P8NATRPS
            LD   DE,P8NATRPE
            CALL PFEXRUTR
            JP   C,PFNATRER

            LD   A,3
            LD   BC,P8DITRPP-P8DITRPS
            LD   HL,P8DITRPS
            LD   DE,P8DITRPE
            CALL PFEXRUTR
            JP   C,PFDITRER

            LD   A,190
            LD   HL,P8LRNTRS
            LD   DE,P8LRNTRE
            CALL PFEXRUOK
            JP   C,PFLRTRER

            LD   A,198
            LD   HL,P8IMCONS
            LD   DE,P8IMCONE
            CALL CPAGCLSL
            JP   C,PFRDEERR
            CALL ZGPROG
            JP   C,PFRDEERR
            CALL RESET
            CALL QPCAGE
            JP   C,PFRDEERR
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,PFRDEERR
            LD   A,(VOUTLEN)
            CP   2
            JP   NZ,PFRDEERR
            LD   A,(VOUTBAS)
            CP   $48
            JP   NZ,PFRDEERR
            LD   A,(VOUTBAS+1)
            CP   7
            JP   NZ,PFRDEERR
            LD   A,(RTDEPTH)
            OR   A
            JP   NZ,PFRDEERR

            LD   A,116
            LD   (FPCASE),A
            LD   A,199
            LD   HL,P8HNPROS
            LD   DE,P8HNPROE
            CALL CPAGCLSL
            JP   C,PFRDEERR
            CALL ZGPROG
            JP   C,PFRDEERR
            CALL RESET
            LD   A,1
            LD   (SVFAIL),A
            CALL QPCAGE
            JP   C,PFRDEERR
            LD   A,(RUNSTATE)
            CP   RTTRAP
            JP   NZ,PFRDEERR
            LD   A,(RTTRPNO)
            CP   6
            JP   NZ,PFRDEERR
            LD   A,(RTTRPERR)
            CP   3
            JP   NZ,PFRDEERR
            LD   HL,(RTTRPOFF)
            LD   DE,P8HNEXFP-P8HNPROS
            OR   A
            SBC  HL,DE
            JP   NZ,PFRDEERR
            LD   A,(RTDEPTH)
            OR   A
            JP   NZ,PFRDEERR

            LD   A,117
            LD   (FPCASE),A
            LD   A,DGFAICTX
            LD   BC,P8BALOCP-P8BALOCS
            LD   HL,P8BALOCS
            LD   DE,P8BALOCE
            CALL QPEXDI
            JP   C,PFRDEERR
            LD   A,118
            LD   (FPCASE),A
            LD   A,DGHDLINE
            LD   BC,P8BAASNP-P8BAASNS
            LD   HL,P8BAASNS
            LD   DE,P8BAASNE
            CALL QPEXDI
            JP   C,PFRDEERR
            LD   A,119
            LD   (FPCASE),A
            LD   A,DGFAICTX
            LD   BC,P8LEORFP-P8LEORFS
            LD   HL,P8LEORFS
            LD   DE,P8LEORFE
            CALL QPEXDI
            JP   C,PFRDEERR
            LD   A,120
            LD   (FPCASE),A
            LD   A,DGHDLINE
            LD   BC,P8LONERP-P8LONERS
            LD   HL,P8LONERS
            LD   DE,P8LONERE
            CALL QPEXDI
            JP   C,PFRDEERR
            LD   A,121
            LD   (FPCASE),A
            LD   A,DGFAICTX
            LD   BC,P8INPROP-P8INPROS
            LD   HL,P8INPROS
            LD   DE,P8INPROE
            CALL QPEXDI
            JP   C,PFRDEERR
            LD   A,122
            LD   (FPCASE),A
            LD   A,DGHDLINE
            LD   BC,P8INFHDP-P8INFHDS
            LD   HL,P8INFHDS
            LD   DE,P8INFHDE
            CALL QPEXDI
            JP   C,PFRDEERR
            LD   A,123
            LD   (FPCASE),A
            LD   A,DGFAICTX
            LD   BC,P8DBCONP-P8DBCONS
            LD   HL,P8DBCONS
            LD   DE,P8DBCONE
            CALL QPEXDI
            JP   C,PFRDEERR
            LD   A,124
            LD   (FPCASE),A
            LD   A,DXLINE
            LD   BC,P8LOCHDP-P8LOCHDS
            LD   HL,P8LOCHDS
            LD   DE,P8LOCHDE
            CALL QPEXDI
            JP   C,PFRDEERR
            LD   A,125
            LD   (FPCASE),A
            LD   A,DGFAICTX
            LD   BC,P8RREPRP-P8RREPRS
            LD   HL,P8RREPRS
            LD   DE,P8RREPRE
            CALL QPEXDI
            JP   C,PFRDEERR
            LD   A,126
            LD   (FPCASE),A
            LD   A,DGRTNFLW
            LD   BC,P8FREPRP-P8FREPRS
            LD   HL,P8FREPRS
            LD   DE,P8FREPRE
            CALL QPEXDI
            JP   C,PFRDEERR

            LD   A,127
            LD   (FPCASE),A
            LD   A,DXNAME
            LD   BC,P8MHNNAP-P8MHNNAS
            LD   HL,P8MHNNAS
            LD   DE,P8MHNNAE
            CALL QPEXDI
            JP   C,PFRDEERR
            LD   A,128
            LD   (FPCASE),A
            LD   A,DGUNKNAM
            LD   BC,P8UHNNAP-P8UHNNAS
            LD   HL,P8UHNNAS
            LD   DE,P8UHNNAE
            CALL QPEXDI
            JP   C,PFRDEERR
            LD   A,129
            LD   (FPCASE),A
            LD   A,DGTYPMIS
            LD   BC,P8WHNNAP-P8WHNNAS
            LD   HL,P8WHNNAS
            LD   DE,P8WHNNAE
            CALL QPEXDI
            JP   C,PFRDEERR
            LD   A,130
            LD   (FPCASE),A
            LD   A,DGTYPMIS
            LD   BC,P8CNHNDP-P8CNHNDS
            LD   HL,P8CNHNDS
            LD   DE,P8CNHNDE
            CALL QPEXDI
            JP   C,PFRDEERR
            LD   A,131
            LD   (FPCASE),A
            LD   A,DGTYPMIS
            LD   BC,P8AHNNAP-P8AHNNAS
            LD   HL,P8AHNNAS
            LD   DE,P8AHNNAE
            CALL QPEXDI
            JP   C,PFRDEERR
            LD   A,132
            LD   (FPCASE),A
            LD   A,DGACTCTR
            LD   BC,P8CTHNDP-P8CTHNDS
            LD   HL,P8CTHNDS
            LD   DE,P8CTHNDE
            CALL QPEXDI
            JP   C,PFRDEERR

            XOR  A
            LD   (FPCASE),A
            LD   A,$A5
            LD   (FPSTATUS),A
            HALT

; A is the expected diagnostic, BC its offset, HL/DE the source range.
; Contract: in A,BC,DE,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
QPEXDI:
            LD   (PFEXPDG),A
            LD   (PFEXPOFF),BC
            LD   A,171
            CALL CPAGCLSL
            JR   NC,PFEXDGER
            LD   A,(PFEXPDG)
            LD   HL,DGCODE
            CP   (HL)
            JR   NZ,PFEXDGER
            LD   HL,(DGOFF)
            LD   DE,(PFEXPOFF)
            OR   A
            SBC  HL,DE
            RET  Z
PFEXDGER:
            SCF
            RET

; Check publication before a later diagnostic overlays the emission cursor.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,DE,HL
PFVALPUB:
            LD   HL,(GNSZ)
            LD   DE,MMGEN
            ADD  HL,DE
            LD   DE,(EMCUR)
            OR   A
            SBC  HL,DE
            RET  Z
            SCF
            RET

; A/BC select the exact trap and source offset; HL/DE select the source. Input
; byte zero is supplied for the bounds/division cases and is inert otherwise.
; Contract: in A,BC,DE,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
PFEXRUTR:
            LD   (PFEXPTRP),A
            LD   (PFEXPOFF),BC
            LD   A,190
            CALL CPAGCLSL
            RET  C
            CALL ZGPROG
            RET  C
            CALL RESET
            LD   A,1
            LD   (VINLEN),A
            LD   A,(PFEXPTRP)
            CP   1
            LD   A,0
            JR   NZ,PFTRINRD
            LD   A,2
PFTRINRD:
            LD   (VINBAS),A
            CALL QPCAGE
            RET  C
            LD   A,(RUNSTATE)
            CP   RTTRAP
            JR   NZ,PFERTRER
            LD   A,(PFEXPTRP)
            LD   HL,RTTRPNO
            CP   (HL)
            JR   NZ,PFERTRER
            LD   HL,(RTTRPOFF)
            LD   DE,(PFEXPOFF)
            OR   A
            SBC  HL,DE
            JR   NZ,PFERTRER
            LD   A,(RTDEPTH)
            OR   A
            JR   NZ,PFERTRER
            LD   A,(VOUTLEN)
            OR   A
            RET  Z
PFERTRER:
            SCF
            RET

; A selects a source part and HL/DE its source range. The generated program
; must complete without a trap, output, or leaked activation.
; Contract: in A,DE,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
PFEXRUOK:
            CALL CPAGCLSL
            RET  C
            CALL ZGPROG
            RET  C
            CALL RESET
            CALL QPCAGE
            RET  C
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JR   NZ,PFEROKER
            LD   A,(RTTRPNO)
            OR   A
            JR   NZ,PFEROKER
            LD   A,(RTDEPTH)
            OR   A
            JR   NZ,PFEROKER
            LD   A,(VOUTLEN)
            OR   A
            RET  Z
PFEROKER:
            SCF
            RET

; Generated code must restore the root SP and IX on terminal failure.
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

FPCOMPFL:     LD A,1
                         JP QF
PFENCERR:      LD A,2
                         JP QF
PFFRMERR:       LD A,3
                         JP QF
PFTRSTER:   LD A,4
                         JP QF
PFTRRSER:  LD A,5
                         JP QF
PFTRERER:   LD A,6
                         JP QF
PFTROFER:  LD A,7
                         JP QF
PFACTERR:  LD A,8
                         JP QF
PFINFERR:  LD A,9
                         JP QF
PFRNGERR:       LD A,10
                         JP QF
PFFLWERR:        LD A,11
                         JP QF
PFPOCMER: LD A,12
                         JP QF
PFPOENER:  LD A,13
                         JP QF
PFPORUER:     LD A,14
                         JP QF
PFPECMER: LD A,15
                         JP QF
PFPEENER:  LD A,16
                         JP QF
PFPERUER:     LD A,17
                         JP QF
PFBRCMER: LD A,18
                         JP QF
PFBRENER:  LD A,19
                         JP QF
PFBRRUER:     LD A,20
                         JP QF
PFSICMER:    LD A,21
                         JP QF
PFSIENER:     LD A,22
                         JP QF
PFSIRUER:        LD A,23
                         JP QF
PFHNCMER:    LD A,24
                         JP QF
PFHNENER:     LD A,25
                         JP QF
PFHNRUER:        LD A,26
                         JP QF
PFROCMER: LD A,27
                         JP QF
PFROENER:  LD A,28
                         JP QF
PFRORUER:     LD A,29
                         JP QF
PFRHCMER: LD A,30
                         JP QF
PFRHENER:  LD A,31
                         JP QF
PFRHRUER:     LD A,32
                         JP QF
PFCSSCMP:   LD A,33
                         JP QF
PFCSSENC:    LD A,34
                         JP QF
PFCSSRUN:       LD A,35
                         JP QF
PFSTCMER:     LD A,36
                         JP QF
PFSTENER:      LD A,37
                         JP QF
PFSTRUER:         LD A,38
                         JP QF
PFWRERCM:       LD A,39
                         JP QF
PFWREREN:        LD A,40
                         JP QF
PFWRERRU:           LD A,41
                         JP QF
PFSEERCM:        LD A,42
                         JP QF
PFSEEREN:         LD A,43
                         JP QF
PFSEERRU:            LD A,44
                         JP QF
PFREERCM:      LD A,45
                         JP QF
PFREEREN:       LD A,46
                         JP QF
PFREERRU:          LD A,47
                         JP QF
PFRSERCM: LD A,48
                         JP QF
PFRSEREN:  LD A,49
                         JP QF
PFRSERRU:     LD A,50
                         JP QF
PFWOERCM: LD A,51
                         JP QF
PFWOEREN:  LD A,52
                         JP QF
PFWOERRU:     LD A,53
                         JP QF
PFMUCMER:      LD A,54
                         JP QF
PFMUENER:       LD A,55
                         JP QF
PFMURUER:          LD A,56
                         JP QF
PFINFWER:  LD A,57
                         JP QF
PFPRVAER: LD A,58
                         JP QF
PFPRRTER:  LD A,59
                         JP QF
PFPRPAER: LD A,60
                         JP QF
PFWSTYER:   LD A,61
                         JP QF
PFSSTYER:    LD A,62
                         JP QF
PFSEFWER:      LD A,63
                         JP QF
PFUNCMER:  LD A,64
                         JP QF
PFUNSVER:  LD A,65
                         JP QF
PFNESVER:      LD A,66
                         JP QF
PFTBCMER:  LD A,67
                         JP QF
PFTBENER:   LD A,68
                         JP QF
PFTBFRER:    LD A,69
                         JP QF
PFTBRUER:      LD A,70
                         JP QF
PFRFRCER: LD A,71
                         JP QF
PFRFREER:  LD A,72
                         JP QF
PFRFRRER:     LD A,73
                         JP QF
PFFMCMER: LD A,74
                         JP QF
PFFMENER:  LD A,75
                         JP QF
PFFMRUER:     LD A,76
                         JP QF
PFIFMAER: LD A,77
                         JP QF
PFPUBERR:          LD A,78
                         JP QF
PFBNTRER:           LD A,79
                         JP QF
PFNATRER:           LD A,80
                         JP QF
PFDITRER:           LD A,81
                         JP QF
PFLRTRER:        LD A,82
                         JP QF
PFRMCMER: LD A,83
                         JP QF
PFRMENER:  LD A,84
                         JP QF
PFRMRUER:     LD A,85
                         JP QF
PFSVARER:      LD A,86
                         JP QF
PFCOFLER:     LD A,87
                         JP QF
PFASFLER: LD A,88
                         JP QF
PFIDFLER:        LD A,89
                         JP QF
PFAAFLER: LD A,102
                         JP QF
PFNFCMER:   LD A,90
                         JP QF
PFNFENER:    LD A,91
                         JP QF
PFNFRUER:       LD A,92
                         JP QF
PFPSCMER: LD A,93
                         JP QF
PFPSENER: LD A,94
                         JP QF
PFPSRUER:    LD A,95
                         JP QF
PFIHCMER: LD A,96
                         JP QF
PFIHENER: LD A,97
                         JP QF
PFIHRUER:   LD A,98
                         JP QF
PFACHCER: LD A,99
                         JP QF
PFACHEER: LD A,100
                         JP QF
PFACHRER: LD A,101
                         JP QF
PFRRCMER: LD A,103
                         JP QF
PFRRENER: LD A,104
                         JP QF
PFRRRUER: LD A,105
                         JP QF
PFISCMER: LD A,106
                         JP QF
PFISENER: LD A,107
                         JP QF
PFISRUER: LD A,108
                         JP QF
PFRFCMER: LD A,109
                         JP QF
PFRFVAER: LD A,110
                         JP QF
PFRFWIER: LD A,111
                         JP QF
PFPHCMER: LD A,112
                         JP QF
PFPHENER: LD A,113
                         JP QF
PFPHRUER: LD A,114
                         JP QF
PFRDEERR:
            HALT
QF:
            LD   (FPCASE),A
            HALT

QPEXSP:         DW 0
PFACTROF:   DW 0
PFEXTROF: DW 0
PFEXPOFF:     DW 0
PFEXPDG: DB 0
PFEXPTRP:       DB 0
FPSTATUS:             DB 0
FPCASE:               DB 0
FPEND:
