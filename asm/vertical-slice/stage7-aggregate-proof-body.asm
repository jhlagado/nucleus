ORG MMPROOF
; Contract: out carry,zero clobbers sign,parity,halfCarry,A,BC,DE,HL,IX,IY
FPSTART:
            LD   SP,STACKTOP
            XOR  A
            LD   (FPCASE),A
            LD   (FPSTATUS),A
            LD   A,160
            LD   HL,P7CPYS
            LD   DE,P7CPYE
            CALL CPAGCLSL
            JP   C,PFFPACAP
            CALL ZGPROG
            JP   C,QFEN
            LD   HL,(GNSZ)
            LD   (PFCPGESZ),HL
            CALL RESET
            CALL QPCAGE
            JP   C,QFFR
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,PFFRUN
            LD   A,(VOUTLEN)
            CP   1
            JP   NZ,PFFOUT
            LD   A,(VOUTBAS)
            CP   $59
            JP   NZ,PFFOUT
            LD   A,(MMDATA)
            CP   1
            JP   NZ,PFFSTO
            LD   A,(MMBSS)
            CP   2
            JP   NZ,PFFSTO
            LD   A,160
            LD   HL,P7FWDS
            LD   DE,P7FWDE
            CALL CPAGCLSL
            JP   C,PFFFWCMP
            CALL ZGPROG
            JP   C,PFFFWENC
            LD   HL,(GNSZ)
            LD   (PFFWGESZ),HL
            CALL RESET
            CALL QPCAGE
            JP   C,PFFFWFRM
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,PFFFWRUN
            LD   A,(VOUTLEN)
            CP   1
            JP   NZ,PFFFWOUT
            LD   A,(VOUTBAS)
            CP   $59
            JP   NZ,PFFFWOUT
            LD   A,(MMDATA)
            CP   3
            JP   NZ,PFFFWSTO
            LD   A,(MMDATA+1)
            CP   9
            JP   NZ,PFFFWSTO
            LD   A,160
            LD   HL,P7STRS
            LD   DE,P7STRE
            CALL CPAGCLSL
            JP   C,PFFSTCMP
            CALL ZGPROG
            JP   C,PFFSTENC
            LD   HL,(GNSZ)
            LD   (PFSTGESZ),HL
            CALL RESET
            CALL QPCAGE
            JP   C,PFFSTFRM
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,PFFSTRUN
            LD   A,(VOUTLEN)
            CP   1
            JP   NZ,PFFSTOUT
            LD   A,(VOUTBAS)
            CP   $59
            JP   NZ,PFFSTOUT
            LD   A,(MMDATA)
            CP   3
            JP   NZ,PFFSTSTO
            LD   A,(MMDATA+1)
            CP   $41
            JP   NZ,PFFSTSTO
            LD   A,(MMDATA+2)
            CP   $59
            JP   NZ,PFFSTSTO
            LD   A,(MMDATA+3)
            CP   $43
            JP   NZ,PFFSTSTO
            LD   A,(MMDATA+4)    ; sealed byte at capacity+1
            OR   A
            JP   NZ,PFFSTSTO
            LD   A,161
            LD   HL,P7COSTRS
            LD   DE,P7COSTRE
            CALL CPAGCLSL
            JP   C,PFFBNCMP
            CALL ZGPROG
            JP   C,PFFBNENC
            LD   A,$FF                    ; L=255 remains invalid
            LD   (RORDATA),A
            CALL RESET
            CALL QPCAGE
            JP   C,PFFBNFRM
            LD   A,(RUNSTATE)
            CP   RTTRAP
            JP   NZ,PFFBNRUN
            LD   A,(RTTRPNO)
            CP   1
            JP   NZ,PFFBNRUN
            LD   HL,(RTTRPOFF)
            LD   DE,P7CSTLEO
            OR   A
            SBC  HL,DE
            JP   NZ,PFFBNRUN
            LD   A,163
            LD   HL,P7CSTIDS
            LD   DE,P7CSTIDE
            CALL CPAGCLSL
            JP   C,PFFBNCMP
            CALL ZGPROG
            JP   C,PFFBNENC
            LD   A,$FF                    ; indexing rejects the same corruption
            LD   (RORDATA),A
            CALL RESET
            CALL QPCAGE
            JP   C,PFFBNFRM
            LD   A,(RUNSTATE)
            CP   RTTRAP
            JP   NZ,PFFBNRUN
            LD   A,(RTTRPNO)
            CP   1
            JP   NZ,PFFBNRUN
            LD   HL,(RTTRPOFF)
            LD   DE,P7CSTIDO
            OR   A
            SBC  HL,DE
            JP   NZ,PFFBNRUN
            LD   A,162
            LD   HL,P7SEARRS
            LD   DE,P7SEARRE
            CALL CPAGCLSL
            JP   C,PFFSTCMP
            LD   HL,(PGBSSLEN)
            LD   DE,1020
            OR   A
            SBC  HL,DE
            JP   NZ,PFFSTSTO
            CALL ZGPROG
            JP   C,PFFSTENC
            LD   A,(MMBSS+1019)  ; terminator in final 255-byte element
            OR   A
            JP   NZ,PFFSTSTO
            CALL RESET
            CALL QPCAGE
            JP   C,PFFSTFRM
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,PFFSTRUN
            LD   A,(VOUTLEN)
            CP   1
            JP   NZ,PFFSTOUT
            LD   A,(VOUTBAS)
            CP   $59
            JP   NZ,PFFSTOUT
            LD   A,166
            LD   HL,P7LRDATS
            LD   DE,P7LRDATE
            CALL CPAGCLSL
            JP   C,PFFSTCMP
            LD   HL,(IMGLEN)
            LD   DE,510
            OR   A
            SBC  HL,DE
            JP   NZ,PFFSTSTO
            CALL ZGPROG
            JP   C,PFFSTENC
            LD   HL,(GNROSZ)
            LD   DE,510
            OR   A
            SBC  HL,DE
            JP   NZ,PFFSTSTO
            LD   HL,(GNDATSZ)
            LD   DE,510
            OR   A
            SBC  HL,DE
            JP   NZ,PFFSTSTO
            CALL RESET
            CALL QPCAGE
            JP   C,PFFSTFRM
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,PFFSTRUN
            LD   A,(VOUTBAS)
            CP   $59
            JP   NZ,PFFSTOUT
            LD   A,(MMDATA)
            CP   1
            JP   NZ,PFFSTSTO
            LD   A,(MMDATA+255)
            CP   1
            JP   NZ,PFFSTSTO
            LD   A,(MMDATA+256)
            CP   $42
            JP   NZ,PFFSTSTO
            LD   A,(MMDATA+509)
            OR   A
            JP   NZ,PFFSTSTO

            ; Four complete sealed strings plus a four-byte tail exactly fill
            ; the initialized-data and rodata regions. Startup must copy all
            ; 1024 bytes without changing the first byte beyond the region.
            LD   A,167
            LD   HL,P7DCAACS
            LD   DE,P7DCAACE
            CALL CPAGCLSL
            JP   C,PFFDCAAC
            LD   HL,(IMGLEN)
            LD   DE,1024
            OR   A
            SBC  HL,DE
            JP   NZ,PFFDCAAC
            CALL ZGPROG
            JP   C,PFFDCAAC
            LD   HL,(GNROSZ)
            LD   DE,1024
            OR   A
            SBC  HL,DE
            JP   NZ,PFFDCAAC
            LD   HL,(GNDATSZ)
            LD   DE,1024
            OR   A
            SBC  HL,DE
            JP   NZ,PFFDCAAC
            LD   A,$A5
            LD   (MMDATEND),A
            CALL RESET
            CALL QPCAGE
            JP   C,PFFDCAAC
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,PFFDCAAC
            LD   A,(MMDATA)
            OR   A
            JP   NZ,PFFDCAAC
            LD   A,(MMDATEND-1)
            OR   A
            JP   NZ,PFFDCAAC
            LD   A,(MMDATEND)
            CP   $A5
            JP   NZ,PFFDCAAC

            LD   A,168
            LD   HL,P7DCARES
            LD   DE,P7DCAREE
            LD   A,DGPDCAP
            LD   BC,P7DCAREO
            CALL PFEXCMDG
            JP   C,PFFDCARE
            LD   A,169
            LD   HL,P7DCAACS
            LD   DE,P7DCAACE
            CALL CPAGCLSL
            JP   C,PFFDCARE

            ; The same exact-fill and first-rejection boundary applies
            ; independently to default-initialized BSS storage.
            LD   A,170
            LD   HL,P7BCAACS
            LD   DE,P7BCAACE
            CALL CPAGCLSL
            JP   C,PFFBCAAC
            LD   HL,(PGBSSLEN)
            LD   DE,1024
            OR   A
            SBC  HL,DE
            JP   NZ,PFFBCAAC
            CALL ZGPROG
            JP   C,PFFBCAAC
            LD   HL,(GNBSSSZ)
            LD   DE,1024
            OR   A
            SBC  HL,DE
            JP   NZ,PFFBCAAC
            LD   A,$A5
            LD   (MMBSSEND),A
            CALL RESET
            CALL QPCAGE
            JP   C,PFFBCAAC
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,PFFBCAAC
            LD   A,(MMBSS)
            OR   A
            JP   NZ,PFFBCAAC
            LD   A,(MMBSSEND-1)
            CP   $59
            JP   NZ,PFFBCAAC
            LD   A,(MMBSSEND)
            CP   $A5
            JP   NZ,PFFBCAAC

            LD   A,171
            LD   HL,P7BCARES
            LD   DE,P7BCAREE
            LD   A,DGPDCAP
            LD   BC,P7BCAREO
            CALL PFEXCMDG
            JP   C,PFFBCARE
            LD   A,172
            LD   HL,P7BCAACS
            LD   DE,P7BCAACE
            CALL CPAGCLSL
            JP   C,PFFBCARE

            ; One record may exceed 255 bytes. Its word field offset, array
            ; length, 501-byte outer-array stride, nested element address and
            ; complete 501-byte copy must all survive. The array occupies 1002
            ; BSS bytes.
            LD   A,173
            LD   HL,P7WIDAGS
            LD   DE,P7WIDAGE
            CALL CPAGCLSL
            JP   C,PFFWIDAG
            LD   HL,(PGBSSLEN)
            LD   DE,1002
            OR   A
            SBC  HL,DE
            JP   NZ,PFFWIDAG
            CALL ZGPROG
            JP   C,PFFWIDAG
            CALL RESET
            CALL QPCAGE
            JP   C,PFFWIDAG
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,PFFWIDAG
            LD   A,(VOUTLEN)
            CP   1
            JP   NZ,PFFWIDAG
            LD   A,(VOUTBAS)
            CP   $59
            JP   NZ,PFFWIDAG
            LD   A,(MMBSS+499)
            CP   $59
            JP   NZ,PFFWIDAG
            LD   A,(MMBSS+1000)
            CP   $59
            JP   NZ,PFFWIDAG

            ; Growing an already-1024-byte field by one byte is rejected at
            ; the final field declaration rather than wrapping its extent.
            LD   A,174
            LD   HL,P7WRERES
            LD   DE,P7WREREE
            LD   A,DGPDCAP
            LD   BC,P7WREREO
            CALL PFEXCMDG
            JP   C,PFFWRECA

            ; Explicit initialization also crosses the old byte ceiling. The
            ; 256th source element must be retained and copied into RAM.
            LD   A,175
            LD   HL,P7WIINIS
            LD   DE,P7WIINIE
            CALL CPAGCLSL
            JP   C,PFFWIINI
            LD   HL,(IMGLEN)
            LD   DE,256
            OR   A
            SBC  HL,DE
            JP   NZ,PFFWIINI
            LD   A,(IMGBAS)
            CP   1
            JP   NZ,PFFWIINI
            LD   A,(IMGBAS+255)
            CP   1
            JP   NZ,PFFWIINI
            CALL ZGPROG
            JP   C,PFFWIINI
            CALL RESET
            CALL QPCAGE
            JP   C,PFFWIINI
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,PFFWIINI
            LD   A,(MMDATA)
            CP   1
            JP   NZ,PFFWIINI
            LD   A,(MMDATA+255)
            CP   1
            JP   NZ,PFFWIINI

            LD   A,176
            LD   HL,P7WLEINS
            LD   DE,P7WLEINE
            CALL CPAGCLSL
            JP   C,PFFWLEIN
            LD   A,(ATCNT)
            CP   2
            JP   NZ,PFFWLEIN

            LD   A,$34
            LD   (P7SACDIG),A
            LD   A,164
            LD   HL,P7SEARRS
            LD   DE,P7SEARRE
            CALL CPAGCLSL
            JP   NC,PFFSTCAP
            LD   A,(DGCODE)
            CP   DGSTRCAP
            JP   NZ,PFFSTCAP
            LD   HL,(DGOFF)
            LD   DE,P7SARCAO
            OR   A
            SBC  HL,DE
            JP   NZ,PFFSTCAP
            LD   A,$35
            LD   (P7SACDIG),A
            LD   A,165
            LD   HL,P7SEARRS
            LD   DE,P7SEARRE
            CALL CPAGCLSL
            JP   NC,PFFSTCAP
            LD   A,(DGCODE)
            CP   DGSTRCAP
            JP   NZ,PFFSTCAP
            LD   HL,(DGOFF)
            LD   DE,P7SARCAO
            OR   A
            SBC  HL,DE
            JP   NZ,PFFSTCAP
            LD   A,160
            LD   HL,P7BNDS
            LD   DE,P7BNDE
            CALL CPAGCLSL
            JP   C,PFFBNCMP
            CALL ZGPROG
            JP   C,PFFBNENC
            LD   HL,(GNSZ)
            LD   (PFBNGESZ),HL
            CALL RESET
            CALL QPCAGE
            JP   C,PFFBNFRM
            LD   A,(RUNSTATE)
            CP   RTTRAP
            JP   NZ,PFFBNRUN
            LD   A,(RTTRPNO)
            CP   1
            JP   NZ,PFFBNRUN
            LD   HL,(RTTRPOFF)
            LD   DE,134
            OR   A
            SBC  HL,DE
            JP   NZ,PFFBNRUN
            LD   A,(VOUTLEN)
            OR   A
            JP   NZ,PFFBNRUN
            LD   A,(MMDATA)
            CP   3
            JP   NZ,PFFBNSTO
            LD   A,(MMDATA+1)
            CP   7
            JP   NZ,PFFBNSTO
            LD   A,DGINTRNG
            LD   BC,86
            LD   HL,P7CSBNDS
            LD   DE,P7CSBNDE
            CALL PFEXCMDG
            JP   C,PFFCSBND
            LD   A,DGTYPMIS
            LD   BC,116
            LD   HL,P7NOMISS
            LD   DE,P7NOMISE
            CALL PFEXCMDG
            JP   C,PFFNOMIS
            LD   A,DGTYPMIS
            LD   BC,200
            LD   HL,P7TRMISS
            LD   DE,P7TRMISE
            CALL PFEXCMDG
            JP   C,PFFTRMIS
            LD   A,DGRTNCAP
            LD   BC,P7RTCAPO
            LD   HL,P7RTCAPS
            LD   DE,P7RTCAPE
            CALL PFEXCMDG
            JP   C,PFFRTCAP
            LD   A,DGPARCAP
            LD   BC,P7PACAPO
            LD   HL,P7PACAPS
            LD   DE,P7PACAPE
            CALL PFEXCMDG
            JP   C,PFFPACAP
            LD   A,DGEXPCAP
            LD   BC,118
            LD   HL,P7CADEPS
            LD   DE,P7CADEPE
            CALL PFEXCMDG
            JP   C,PFFCADEP
            LD   A,DGDUPNAM
            LD   BC,11
            LD   HL,P7PRTCLS
            LD   DE,P7PRTCLE
            CALL PFEXCMDG
            JP   C,PFFPRTCL
            LD   A,DGTYPMIS
            LD   BC,46
            LD   HL,P7SLEWRS
            LD   DE,P7SLEWRE
            CALL PFEXCMDG
            JP   C,PFFSLEWR
            LD   A,DGDUPNAM
            LD   BC,6
            LD   HL,P7MAPARS
            LD   DE,P7MAPARE
            CALL PFEXCMDG
            JP   C,PFFMAPAR
            LD   A,DXRPAR
            LD   BC,9
            LD   HL,P7MPASYS
            LD   DE,P7MPASYE
            CALL PFEXCMDG
            JP   C,PFFMPASY
            LD   A,DXLINE
            LD   BC,11
            LD   HL,P7MARESS
            LD   DE,P7MARESE
            CALL PFEXCMDG
            JP   C,PFFMARES
            LD   A,160
            LD   HL,P7RTFLSS
            LD   DE,P7RTFLSE
            CALL CPAGCLSL
            JP   C,PFFRTFLS
            LD   A,DXTOPLVL
            LD   BC,12
            LD   HL,P7MIMAIS
            LD   DE,P7MIMAIE
            CALL PFEXCMDG
            JP   C,PFFMIMAI
            LD   A,DXEOF
            LD   BC,15
            LD   HL,P7AFMAIS
            LD   DE,P7AFMAIE
            CALL PFEXCMDG
            JP   C,PFFAFMAI
            LD   A,DGDUPNAM
            LD   BC,4
            LD   HL,P7SVRTNS
            LD   DE,P7SVRTNE
            CALL PFEXCMDG
            JP   C,PFFSVRTN
            LD   A,DGDUPNAM
            LD   BC,6
            LD   HL,P7SVPARS
            LD   DE,P7SVPARE
            CALL PFEXCMDG
            JP   C,PFFSVPAR
            LD   A,DGDUPNAM
            LD   BC,4
            LD   HL,P7SVVARS
            LD   DE,P7SVVARE
            CALL PFEXCMDG
            JP   C,PFFSVVAR
            LD   A,DGTYPMIS
            LD   BC,245
            LD   HL,P7SSFPSS
            LD   DE,P7SSFPSE
            CALL PFEXCMDG
            JP   C,PFFSCSFX
            LD   A,DGTYPMIS
            LD   BC,66
            LD   HL,P7REIDXS
            LD   DE,P7REIDXE
            CALL PFEXCMDG
            JP   C,PFFREIDX
            LD   HL,P7SHCIRS
            LD   DE,P7SHCIRE
            CALL PFCNRUOK
            JP   C,PFFSHCIR
            LD   HL,P7STRTNS
            LD   DE,P7STRTNE
            CALL PFCNRUOK
            JP   C,PFFSTRTN
            LD   A,(VOUTLEN)
            CP   1
            JP   NZ,PFFSTRTN
            LD   A,(VOUTBAS)
            CP   $59
            JP   NZ,PFFSTRTN
            CALL PFRURECA
            JP   C,PFFRECAP
            CALL PFRUSFER
            JP   C,PFFSFCAP
            LD   A,DXCOMMA
            LD   BC,48
            LD   HL,P7TFEARS
            LD   DE,P7TFEARE
            CALL PFEXCMDG
            JP   C,PFFTFEAR
            LD   A,DXRPAR
            LD   BC,37
            LD   HL,P7TMAARS
            LD   DE,P7TMAARE
            CALL PFEXCMDG
            JP   C,PFFTMAAR
            LD   A,DGTYPMIS
            LD   BC,88
            LD   HL,P7SFOAGS
            LD   DE,P7SFOAGE
            CALL PFEXCMDG
            JP   C,PFFSFOAG
            LD   A,DGTYPMIS
            LD   BC,79
            LD   HL,P7AFOSCS
            LD   DE,P7AFOSCE
            CALL PFEXCMDG
            JP   C,PFFAFOSC
            LD   A,DGTYPMIS
            LD   BC,60
            LD   HL,P7SREAGS
            LD   DE,P7SREAGE
            CALL PFEXCMDG
            JP   C,PFFSREAG
            LD   A,DGTYPMIS
            LD   BC,59
            LD   HL,P7ARESCS
            LD   DE,P7ARESCE
            CALL PFEXCMDG
            JP   C,PFFARESC

            ; Aggregate constants retain their complete initialized bytes in
            ; the rodata suffix. A later data declaration shifts that suffix,
            ; direct reads/copies remain valid, and passing the alias to a
            ; writable parameter deliberately permits target mutation.
            LD   HL,P7AGCSTS
            LD   DE,P7AGCSTE
            CALL CPAGCLSL
            JP   C,PFFAGCST
            LD   HL,(IMGLEN)
            LD   DE,3
            OR   A
            SBC  HL,DE
            JP   NZ,PFFAGCST
            LD   HL,(ROILEN)
            LD   DE,11
            OR   A
            SBC  HL,DE
            JP   NZ,PFFAGCST
            LD   A,(IMGBAS)
            CP   1
            JP   NZ,PFFAGCST
            LD   A,(IMGBAS+3)
            CP   7
            JP   NZ,PFFAGCST
            LD   A,(IMGBAS+7)
            CP   2
            JP   NZ,PFFAGCST
            LD   A,(IMGBAS+9)
            CP   3
            JP   NZ,PFFAGCST
            LD   A,(IMGBAS+11)
            OR   A
            JP   NZ,PFFAGCST
            CALL ZGPROG
            JP   C,PFFAGCST
            LD   HL,(GNROSZ)
            LD   DE,14
            OR   A
            SBC  HL,DE
            JP   NZ,PFFAGCST
            LD   HL,(GNDATSZ)
            LD   DE,3
            OR   A
            SBC  HL,DE
            JP   NZ,PFFAGCST
            LD   A,$A5
            LD   (MMDATA+3),A
            CALL RESET
            CALL QPCAGE
            JP   C,PFFAGCST
            LD   A,(RUNSTATE)
            CP   RTSUCC
            JP   NZ,PFFAGCST
            LD   A,(VOUTLEN)
            CP   1
            JP   NZ,PFFAGCST
            LD   A,(VOUTBAS)
            CP   $59
            JP   NZ,PFFAGCST
            LD   A,(MMDATA)
            CP   9
            JP   NZ,PFFAGCST
            LD   A,(MMDATA+3)
            CP   $A5
            JP   NZ,PFFAGCST
            LD   A,(RORDATA+3)
            CP   9
            JP   NZ,PFFAGCST

            LD   A,DGROASGN
            LD   BC,P7ROWASO
            LD   HL,P7ROWASS
            LD   DE,P7ROWASE
            CALL PFEXCMDG
            JP   C,PFFRONAS
            LD   A,DGROASGN
            LD   BC,P7ROFASO
            LD   HL,P7ROFASS
            LD   DE,P7ROFASE
            CALL PFEXCMDG
            JP   C,PFFRONAS
            LD   A,DGROASGN
            LD   BC,P7ROAASO
            LD   HL,P7ROAASS
            LD   DE,P7ROAASE
            CALL PFEXCMDG
            JP   C,PFFRONAS
            LD   A,DGROASGN
            LD   BC,P7ROSASO
            LD   HL,P7ROSASS
            LD   DE,P7ROSASE
            CALL PFEXCMDG
            JP   C,PFFRONAS

            LD   A,DGINICNT
            LD   BC,P7ACSINO
            LD   HL,P7ACSINS
            LD   DE,P7ACSINE
            CALL PFEXCMDG
            JP   C,PFFACSIN
            LD   A,DGTYPMIS
            LD   BC,P7ACWTYO
            LD   HL,P7ACWTYS
            LD   DE,P7ACWTYE
            CALL PFEXCMDG
            JP   C,PFFACWTY
            LD   A,DGTYPMIS
            LD   BC,P7ACSRUO
            LD   HL,P7ACSRUS
            LD   DE,P7ACSRUE
            CALL PFEXCMDG
            JP   C,PFFACSRU
            LD   A,DGTYPMIS
            LD   BC,P7ACSTYO
            LD   HL,P7ACSTYS
            LD   DE,P7ACSTYE
            CALL PFEXCMDG
            JP   C,PFFACSTY

            LD   HL,P7ROCACS
            LD   DE,P7ROCACE
            CALL CPAGCLSL
            JP   C,PFFRONCA
            LD   HL,(ROILEN)
            LD   DE,1024
            OR   A
            SBC  HL,DE
            JP   NZ,PFFRONCA
            CALL ZGPROG
            JP   C,PFFRONCA
            LD   HL,(GNROSZ)
            LD   DE,1024
            OR   A
            SBC  HL,DE
            JP   NZ,PFFRONCA
            LD   HL,(GNDATSZ)
            LD   A,H
            OR   L
            JP   NZ,PFFRONCA
            LD   A,$A5
            LD   (RORDATA),A
            LD   A,$5A
            LD   (RORDATA+1023),A
            LD   A,DGROCAP
            LD   BC,P7ROCREO
            LD   HL,P7ROCRES
            LD   DE,P7ROCREE
            CALL PFEXCMDG
            JP   C,PFFRONCA
            LD   HL,(GNROSZ)
            LD   DE,1024
            OR   A
            SBC  HL,DE
            JP   NZ,PFFRONCA
            LD   A,(RORDATA)
            CP   $A5
            JP   NZ,PFFRONCA
            LD   A,(RORDATA+1023)
            CP   $5A
            JP   NZ,PFFRONCA
            ; The failed declaration must not poison the next compilation.
            LD   HL,P7AGCSTS
            LD   DE,P7AGCSTE
            CALL CPAGCLSL
            JP   C,PFFRONCA
            LD   B,0
            LD   C,2
            CALL PFRUINCP
            JP   C,PFFINCPS
            LD   B,2
            LD   C,0
            CALL PFRUINCP
            JP   C,PFFICPDS
            CALL PFCKENRL
            JP   C,PFFENRLB
            CALL PFCKSEOV
            JP   C,PFFSEOVR
            CALL PFCACABN
            JP   C,PFFACABN
            LD   A,$A5
            LD   (FPSTATUS),A
            HALT

; Exercise both public segmented-capacity entries directly. The three accepted
; mathematical ends and first/tall rejected words distinguish every branch of
; the shared predicate. The returning-diagnostic layout must restore both the
; caller's saved BC and the exact hardware stack before reporting failure.
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
PFCACABN:
            LD   HL,0
            ADD  HL,SP
            LD   (FPCAPSP),HL
            LD   HL,$0000
            CALL PFCPCAAC
            RET  C
            LD   HL,$0000
            CALL PFCROCAC
            RET  C
            LD   HL,$03FF
            CALL PFCPCAAC
            RET  C
            LD   HL,$03FF
            CALL PFCROCAC
            RET  C
            LD   HL,$0400
            CALL PFCPCAAC
            RET  C
            LD   HL,$0400
            CALL PFCROCAC
            RET  C
            LD   HL,$0401
            CALL PFCPCARE
            RET  C
            LD   HL,$0401
            CALL PFCROCRE
            RET  C
            LD   HL,$FFFF
            CALL PFCPCARE
            RET  C
            LD   HL,$FFFF
            CALL PFCROCRE
            RET  C
            XOR  A
            RET

; Contract: in HL out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
PFCPCAAC:
            LD   BC,$A55A
            CALL APCKEXCA
            JR   C,PFCASTER
            JR   PFCKCAST

; Contract: in HL out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
PFCROCAC:
            LD   BC,$A55A
            CALL APCRDOCA
            JR   C,PFCASTER
            JR   PFCKCAST

; Contract: in HL out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
PFCPCARE:
            LD   BC,$A55A
            CALL APCKEXCA
            JR   NC,PFCASTER
            LD   A,(DGCODE)
            CP   DGPDCAP
            JR   NZ,PFCASTER
            JR   PFCKCAST

; Contract: in HL out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
PFCROCRE:
            LD   BC,$A55A
            CALL APCRDOCA
            JR   NC,PFCASTER
            LD   A,(DGCODE)
            CP   DGROCAP
            JR   NZ,PFCASTER

; These entry routines tail-jump here with their own return word still present.
; Contract: in BC out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
PFCKCAST:
            PUSH BC
            POP  DE
            LD   HL,$A55A
            OR   A
            SBC  HL,DE
            JR   NZ,PFCASTER
            LD   HL,2
            ADD  HL,SP
            LD   DE,(FPCAPSP)
            OR   A
            SBC  HL,DE
            JR   NZ,PFCASTER
            OR   A
            RET
PFCASTER:
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

; Require one exact compile-time diagnostic and source offset. A is the
; diagnostic, BC the offset, and HL..DE the complete source range.
; Contract: in A,BC,DE,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
PFEXCMDG:
            LD   (PFEXPDG),A
            LD   (PFEXPOFF),BC
            LD   A,160
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
            JR   NZ,PFEXDGER
            XOR  A
            RET
PFEXDGER:
            SCF
            RET

; Compile, encode, and execute one source that must return normally without a
; generated trap. HL..DE is its complete source range.
; Contract: in DE,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
PFCNRUOK:
            LD   A,160
            CALL CPAGCLSL
            RET  C
            CALL ZGPROG
            RET  C
            CALL RESET
            CALL QPCAGE
            RET  C
            LD   A,(RUNSTATE)
            CP   RTSUCC
            RET  Z
            SCF
            RET

; The ninth active generated call must trap before entering the final body.
; Root unwinding restores SP/IX, clears activation depth, and leaves marker 0.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
PFRURECA:
            LD   A,160
            LD   HL,P7RECAPS
            LD   DE,P7RECAPE
            CALL CPAGCLSL
            RET  C
            CALL ZGPROG
            RET  C
            CALL RESET
            CALL QPCAGE
            RET  C
            LD   A,(RUNSTATE)
            CP   RTTRAP
            JR   NZ,PFRECAER
            LD   A,(RTTRPNO)
            CP   5
            JR   NZ,PFRECAER
            LD   HL,(RTTRPOFF)
            LD   DE,71
            OR   A
            SBC  HL,DE
            JR   NZ,PFRECAER
            LD   A,(RTDEPTH)
            OR   A
            JR   NZ,PFRECAER
            LD   A,(MMBSS)
            OR   A
            RET  Z
PFRECAER:
            SCF
            RET

; Exercise every saved-type unwind phase in the aggregate suffix parser. The
; field and index cases fail on late operands; length fails on its first byte.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
PFRUSFER:
            LD   A,170
            LD   HL,P7SFLENS
            LD   DE,P7SFLENE
            CALL PFPRESFX
            LD   A,ATKSTR
            LD   (ATTABBAS+ATKIND),A
            LD   A,3
            LD   (ATTABBAS+ATAUX),A
            LD   HL,SMBUFLIM
            LD   (SKCUR),HL
            LD   A,AGDYNTYP
            CALL PFEXSFCA
            RET  C

            LD   A,171
            LD   HL,P7SFFLDS
            LD   DE,P7SFFLDE
            CALL PFPRESFX
            LD   A,ATKREC
            LD   (ATTABBAS+ATKIND),A
            XOR  A
            LD   (ATTABBAS+ARFLDST),A
            INC  A
            LD   (ATTABBAS+ARFLDCNT),A
            XOR  A
            LD   (ATTABBAS+ARFLDCNT+1),A
            LD   HL,P7SFFLDS+1
            LD   (AFTABBAS),HL
            LD   A,5
            LD   (AFTABBAS+2),A
            LD   A,TYU8
            LD   (AFTABBAS+3),A
            XOR  A
            LD   (AFTABBAS+4),A
            LD   HL,SMBUFLIM-1
            LD   (SKCUR),HL
            LD   A,AGDYNTYP
            CALL PFEXSFCA
            RET  C

            LD   A,172
            LD   HL,P7SFIDXS
            LD   DE,P7SFIDXE
            CALL PFPRESFX
            LD   A,ATKARRAY
            LD   (ATTABBAS+ATKIND),A
            LD   A,TYU8
            LD   (ATTABBAS+ATAUX),A
            LD   A,2
            LD   (ATTABBAS+ATLEN),A
            LD   (ATTABBAS+ATEXT),A
            LD   HL,SMBUFLIM-7
            LD   (SKCUR),HL
            LD   A,AGDYNTYP
            CALL PFEXSFCA
            RET  C

            LD   A,173
            LD   HL,P7SFIDXS
            LD   DE,P7SFIDXE
            CALL PFPRESFX
            LD   A,ATKSTR
            LD   (ATTABBAS+ATKIND),A
            LD   A,3
            LD   (ATTABBAS+ATAUX),A
            LD   (ATTABBAS+ATLEN),A
            INC  A
            LD   (ATTABBAS+ATEXT),A
            LD   HL,SMBUFLIM-6
            LD   (SKCUR),HL
            LD   A,AGDYNTYP
            CALL PFEXSFCA
            RET  C

            LD   A,174
            LD   HL,P7SFIDXS
            LD   DE,P7SFIDXE
            CALL PFPRESFX
            LD   A,ATKREC
            LD   (ATTABBAS+ATKIND),A
            LD   A,AGDYNTYP
            CALL PFESTYER
            RET

; Contract: in A,DE,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
PFPRESFX:
            CALL CPSLINIT
            LD   A,1
            LD   (EXEMITON),A
            LD   A,TYU16
            LD   (EXEXPTYP),A
            XOR  A
            LD   (EXSUPFLT),A
            LD   (EXSTKDEP),A
            RET

; Contract: in A out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
PFEXSFCA:
            LD   (S7PATHT),A
            LD   HL,0
            ADD  HL,SP
            LD   (QPEXSP),HL
            LD   A,(S7PATHT)
            CALL S7PPTSFX
            JR   NC,PFSFXERR
            LD   A,(DGCODE)
            CP   DGSNKCAP
            JR   NZ,PFSFXERR
            JP   PFCKCUSP

; Contract: in A out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
PFESTYER:
            LD   (S7PATHT),A
            LD   HL,0
            ADD  HL,SP
            LD   (QPEXSP),HL
            LD   A,(S7PATHT)
            CALL S7PPTSFX
            JR   NC,PFSFXERR
            LD   A,(DGCODE)
            CP   DGTYPMIS
            JR   NZ,PFSFXERR
PFCKCUSP:
            LD   HL,0
            ADD  HL,SP
            LD   DE,(QPEXSP)
            OR   A
            SBC  HL,DE
            RET  Z
PFSFXERR:
            SCF
            RET

; Build one structurally valid Z80 stream with an intentionally invalid
; opaque carrier. Zero selects the prepared data object; nonzero selects the
; first address beyond the complete program-data region. The
; complete data bytes must survive either region-check trap unchanged.
; Contract: in B,C out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
PFRUINCP:
            LD   A,2
            LD   (IMGLEN),A
            LD   A,$11
            LD   (IMGBAS),A
            LD   A,$22
            LD   (IMGBAS+1),A
            LD   HL,SMBUFBAS
            LD   (HL),5
            INC  HL
            LD   (HL),SMBGMAIN
            INC  HL
            LD   (HL),SMLDPALS
            INC  HL
            LD   DE,MMDATA
            LD   A,B
            OR   A
            JR   Z,PFICDSRD
            LD   DE,MMREGEND
PFICDSRD:
            LD   (HL),E
            INC  HL
            LD   (HL),D
            INC  HL
            LD   (HL),SMLDPALS
            INC  HL
            LD   DE,MMDATA
            LD   A,C
            OR   A
            JR   Z,PFICPSRD
            LD   DE,MMREGEND
PFICPSRD:
            LD   (HL),E
            INC  HL
            LD   (HL),D
            INC  HL
            LD   (HL),SMCOPYAG
            INC  HL
            LD   (HL),1
            INC  HL
            LD   (HL),0
            INC  HL
            LD   (HL),$34
            INC  HL
            LD   (HL),$12
            INC  HL
            LD   (HL),SMENMAIN
            CALL ZGPROG
            JR   C,PFINCPER
            CALL RESET
            CALL QPCAGE
            JR   C,PFINCPER
            LD   A,(RUNSTATE)
            CP   RTTRAP
            JR   NZ,PFINCPER
            LD   A,(RTTRPNO)
            CP   1
            JR   NZ,PFINCPER
            LD   HL,(RTTRPOFF)
            LD   DE,$1234
            OR   A
            SBC  HL,DE
            JR   NZ,PFINCPER
            LD   A,(MMDATA)
            CP   $11
            JR   NZ,PFINCPER
            LD   A,(MMDATA+1)
            CP   $22
            JR   NZ,PFINCPER
            OR   A
            RET
PFINCPER:
            SCF
            RET

; Force failure after the staged image has diverged from the publication, then
; compare every formerly published byte with the transaction backup.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL,IX,IY
PFCKENRL:
            LD   HL,(GNSZ)
            LD   (PFEXPOFF),HL
            LD   HL,(GNROSZ)
            LD   (PFERDASZ),HL
            LD   A,$99
            LD   (IMGBAS),A
            LD   A,1
            LD   (IMGLEN),A
            LD   HL,SMBUFBAS
            LD   (HL),2
            INC  HL
            LD   (HL),SMBGMAIN
            INC  HL
            LD   (HL),SMENMAIN
            LD   HL,MMGEN+4
            CALL ZGPRGLIM
            JR   NC,PFENRLER
            LD   HL,(GNSZ)
            LD   DE,(PFEXPOFF)
            OR   A
            SBC  HL,DE
            JR   NZ,PFENRLER
            LD   HL,(GNROSZ)
            LD   DE,(PFERDASZ)
            OR   A
            SBC  HL,DE
            JR   NZ,PFENRLER
            LD   BC,(GNSZ)
            LD   HL,MMGEN
            LD   DE,MMBACK
PFENRLCM:
            LD   A,B
            OR   C
            JR   Z,PFENRLRD
            LD   A,(DE)
            CP   (HL)
            JR   NZ,PFENRLER
            INC  DE
            INC  HL
            DEC  BC
            JR   PFENRLCM
PFENRLRD:
            LD   BC,(GNROSZ)
            LD   HL,RORDATA
            LD   DE,MMBACK+(RORDATA-MMGEN)
PFERRDCM:
            LD   A,B
            OR   C
            JR   Z,PFERRDRD
            LD   A,(DE)
            CP   (HL)
            JR   NZ,PFENRLER
            INC  DE
            INC  HL
            DEC  BC
            JR   PFERRDCM
PFERRDRD:
            LD   A,(RORDATA)
            CP   $11
            JR   NZ,PFENRLER
            OR   A
            RET
PFENRLER:
            SCF
            RET

; A malformed target adapter must be rejected before publication. The
; compiler then restores the complete preceding code and rodata image.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
PFCKSEOV:
            LD   HL,MMGCEND
            CALL ZESEGBEG
            RET  C
            LD   HL,MMGENCOD+1
            LD   (SGROENT+SGENTBAS),HL
            CALL ZESEGVAL
            JR   NC,PFSEOVER
            LD   A,(DGCODE)
            CP   DGOUTSEG
            JR   NZ,PFSEOVER
            CALL ZESEGABT
            OR   A
            RET
PFSEOVER:
            SCF
            RET

QFCOMP: LD A,(DGCODE)
                  LD (FPSTATUS),A
                  LD A,(DGOFF)
                  JP QF
QFEN:  LD A,2
                  JP QF
QFFR:   LD A,3
                  JP QF
PFFRUN:     LD A,4
                  JP QF
PFFOUT:  LD A,5
                  JP QF
PFFSTO: LD A,6
                  JP QF
PFFFWCMP: LD A,7
                  JP QF
PFFFWENC: LD A,8
                  JP QF
PFFFWFRM: LD A,9
                  JP QF
PFFFWRUN: LD A,10
                  JP QF
PFFFWOUT: LD A,11
                  JP QF
PFFFWSTO: LD A,12
                  JP QF
PFFSTCMP: LD A,13
                  JP QF
PFFSTENC: LD A,14
                  JP QF
PFFSTFRM: LD A,15
                  JP QF
PFFSTRUN: LD A,16
                  JP QF
PFFSTOUT: LD A,17
                  JP QF
PFFSTSTO: LD A,18
                  JP QF
PFFBNCMP: LD A,19
                  JP QF
PFFBNENC: LD A,20
                  JP QF
PFFBNFRM: LD A,21
                  JP QF
PFFBNRUN: LD A,22
                  JP QF
PFFBNSTO: LD A,23
                  JP QF
PFFCSBND: LD A,24
                  JP QF
PFFNOMIS: LD A,25
                  JP QF
PFFTRMIS: LD A,26
                  JP QF
PFFRTCAP: LD A,27
                  JP QF
PFFPACAP: LD A,28
                  JP QF
PFFCADEP: LD A,29
                  JP QF
PFFINCPS: LD A,30
                  JP QF
PFFICPDS: LD A,31
                  JP QF
PFFENRLB: LD A,32
                  JP QF
PFFPRTCL: LD A,33
                  JP QF
PFFSLEWR: LD A,34
                           JP QF
PFFSTCAP: LD A,40
                         JP QF
PFFMAPAR: LD A,35
                  JP QF
PFFSVRTN: LD A,36
                  JP QF
PFFSVPAR: LD A,37
                  JP QF
PFFSVVAR: LD A,38
                  JP QF
PFFSCSFX: LD A,39
                  JP QF
PFFREIDX: LD A,40
                  JP QF
PFFSHCIR: LD A,41
                  JP QF
PFFSTRTN: LD A,42
                  JP QF
PFFRECAP: LD A,43
                  JP QF
PFFSFCAP: LD A,44
                  JP QF
PFFTFEAR: LD A,45
                  JP QF
PFFTMAAR: LD A,46
                  JP QF
PFFSFOAG: LD A,47
                  JP QF
PFFAFOSC: LD A,48
                  JP QF
PFFSREAG: LD A,49
                  JP QF
PFFARESC: LD A,50
                  JP QF
PFFMPASY: LD A,51
                  JP QF
PFFMARES: LD A,52
                  JP QF
PFFRTFLS: LD A,53
                  JP QF
PFFMIMAI: LD A,54
                  JP QF
PFFAFMAI: LD A,55
                  JP QF
PFFSEOVR: LD A,56
                  JP QF
PFFDCAAC: LD A,57
                  JP QF
PFFDCARE: LD A,58
                  JP QF
PFFBCAAC: LD A,59
                  JP QF
PFFBCARE: LD A,60
                  JP QF
PFFWIDAG: LD A,61
                  JP QF
PFFWRECA: LD A,62
                  JP QF
PFFWLEIN: LD A,64
                  JR QF
PFFWIINI: LD A,63
                  JP QF
PFFAGCST: LD A,65
                  JP QF
PFFRONAS: LD A,66
                  JP QF
PFFACSIN: LD A,67
                  JP QF
PFFRONCA: LD A,68
                  JP QF
PFFACWTY: LD A,69
                  JP QF
PFFACSRU: LD A,70
                  JP QF
PFFACSTY: LD A,71
                  JP QF
PFFACABN: LD A,72
QF:
            LD   (FPCASE),A
            HALT

QPEXSP: DW 0
PFEXPOFF: DW 0
PFERDASZ: DW 0
PFEXPDG: DB 0
FPCAPSP: DW 0
PFCPGESZ: DW 0
PFFWGESZ: DW 0
PFSTGESZ: DW 0
PFBNGESZ: DW 0
FPSTATUS:     DB 0
FPCASE:       DB 0
P7COSTRS:
            DB "var text as string[3] = \"\"",10
            DB "sub main() fails",10
            DB "if text."
P7CSTLEP:
            DB "length = 0",10
            DB "end",10
            DB "end",10
P7COSTRE:
P7CSTIDS:
            DB "var text as string[3] = \"\"",10
            DB "sub main() fails",10
            DB "if text"
P7CSTIDP:
            DB "[0] = 0",10
            DB "end",10
            DB "end",10
P7CSTIDE:
P7SEARRS:
            DB "var texts as string[25"
P7SACDIG:
            DB $33
P7SARCAP:
            DB "][4]",10
            DB "sub main() fails",10
            DB "texts[3] = texts[3]",10
            DB "if texts[3].length = 0",10
            DB "writeOutputByte('Y') else fail",10
            DB "end",10,"end",10
P7SEARRE:
FPEND:

; Large capacity fixtures live with proof data rather than consuming the
; bounded resident source window used by the behavioral corpus above.
P7RTCAPS:
            DB "sub a()",10,"end",10
            DB "sub b()",10,"end",10
            DB "sub c()",10,"end",10
            DB "sub d()",10,"end",10
            DB "sub e()",10,"end",10
            DB "sub f()",10,"end",10
            DB "sub g()",10,"end",10
            DB "sub h()",10,"end",10
            DB "sub i()",10,"end",10
            DB "sub j()",10,"end",10
            DB "sub k()",10,"end",10
            DB "sub l()",10,"end",10
            DB "sub m()",10,"end",10
            DB "sub n()",10,"end",10
            DB "sub o()",10,"end",10
            DB "sub p()",10,"end",10
            DB "sub "
P7RTCAPP:
            DB "q()",10,"end",10
P7RTCAPE:

            ; Additional adversarial source fixtures live after the Z80
            ; transaction backup rather than consuming the 2 KiB source bank.
            ORG MMBKEND

P7LRDATS:
            DB "var first as string[253] = \"A\"",10
            DB "var second as string[253] = \"B\"",10
            DB "sub main() fails",10
            DB "if first.length = 1 and second[0] = 'B'",10
            DB "writeOutputByte('Y') else fail",10
            DB "end",10
            DB "end",10
P7LRDATE:

P7DCAACS:
            DB "var a as string[253] = \"\"",10
            DB "var b as string[253] = \"\"",10
            DB "var c as string[253] = \"\"",10
            DB "var d as string[253] = \"\"",10
            DB "var tail as u8[4] = [0,0,0,0]",10
            DB "sub main()",10,"end",10
P7DCAACE:

P7DCARES:
            DB "var a as string[253] = \"\"",10
            DB "var b as string[253] = \"\"",10
            DB "var c as string[253] = \"\"",10
            DB "var d as string[253] = \"\"",10
            DB "var tail as u8[4] = [0,0,0,0]",10
            DB "var e as u8 = 1"
P7DCAREP:
            DB 10
P7DCAREE:

P7BCAACS:
            DB "var bytes as u8[1024]",10
            DB "sub main() fails",10
            DB "bytes[1023] = 'Y'",10
            DB "writeOutputByte(bytes[1023]) else fail",10
            DB "end",10
P7BCAACE:

P7BCARES:
            DB "var bytes as u8[1025"
P7BCAREP:
            DB $5D,10
P7BCAREE:

P7WIDAGS:
            DB "record Wide",10
            DB "padding as u8[300]",10
            DB "values as u8[200]",10
            DB "tail as u8",10
            DB "end",10
            DB "var items as Wide[2]",10
            DB "sub main() fails",10
            DB "items[0].values[199] = 'Y'",10
            DB "items[1] = items[0]",10
            DB "writeOutputByte(items[1].values[199]) else fail",10
            DB "end",10
P7WIDAGE:

P7WRERES:
            DB "record TooLarge",10
            DB "bytes as u8[1024]",10
            DB "extra as u8"
P7WREREP:
            DB 10
            DB "end",10
P7WREREE:

P7WIINIS:
            DB "var bytes as u8[256] = ["
            DB "1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,"
            DB "1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,"
            DB "1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,"
            DB "1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,"
            DB "1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,"
            DB "1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,"
            DB "1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,"
            DB "1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,"
            DB "1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,"
            DB "1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,"
            DB "1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,"
            DB "1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,"
            DB "1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,"
            DB "1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,"
            DB "1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,"
            DB "1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1]",10
            DB "sub main()",10,"end",10
P7WIINIE:

; These word lengths share their low byte. Structural interning must compare
; the high byte and retain two different array descriptors.
P7WLEINS:
            DB "var small as u8[1]",10
            DB "var wide as u8[257]",10
            DB "sub main() fails",10
            DB "end",10
P7WLEINE:

P7PRTCLS:
            DB "sub choose(choose as u8)",10
            DB "end",10
P7PRTCLE:

P7SLEWRS:
            DB "var text as string[3] = \"ABC\"",10
            DB "sub main()",10
            DB "text.length = 0",10
            DB "end",10
P7SLEWRE:

P7MAPARS:
            DB "sub f(main as u8)",10
            DB "end",10
            DB "sub main()",10
            DB "end",10
P7MAPARE:

P7MPASYS:
            DB "sub main(value as u8)",10
            DB "end",10
P7MPASYE:

P7MARESS:
            DB "sub main() as u8",10
            DB "end",10
P7MARESE:

P7RTFLSS:
            DB "sub f() fails",10
            DB "end",10
            DB "sub main()",10
            DB "end",10
P7RTFLSE:

P7MIMAIS:
            DB "sub f()",10
            DB "end",10
P7MIMAIE:

P7AFMAIS:
            DB "sub main()",10
            DB "end",10
            DB "var x as u8",10
P7AFMAIE:

P7SVRTNS:
            DB "sub writeOutputByte(value as u8)",10
            DB "end",10
P7SVRTNE:

P7SVPARS:
            DB "sub f(writeOutputByte as u8)",10
            DB "end",10
P7SVPARE:

P7SVVARS:
            DB "var writeOutputByte as u8",10
            DB "sub main()",10
            DB "end",10
P7SVVARE:

; Payload index 137 becomes StaticImageBase+138. Before the scalar-type guard,
; u8 descriptor underflow could reinterpret this controlled byte as a string
; descriptor and admit r.value.length.
P7SSFPSS:
            DB "var poison as string[140] = \""
            DB "AAAAAAAAAA","AAAAAAAAAA","AAAAAAAAAA","AAAAAAAAAA"
            DB "AAAAAAAAAA","AAAAAAAAAA","AAAAAAAAAA","AAAAAAAAAA"
            DB "AAAAAAAAAA","AAAAAAAAAA","AAAAAAAAAA","AAAAAAAAAA"
            DB "AAAAAAAAAA","AAAAAAA\\x05AA\"",10
            DB "record R",10
            DB "value as u8",10
            DB "end",10
            DB "var r as R",10
            DB "sub main()",10
            DB "writeOutputByte(r.value.length)",10
            DB "end",10
P7SSFPSE:

P7REIDXS:
            DB "record R",10
            DB "value as u8",10
            DB "end",10
            DB "var r as R",10
            DB "sub main()",10
            DB "writeOutputByte(r[0].value)",10
            DB "end",10
P7REIDXE:

P7SHCIRS:
            DB "record R",10
            DB "value as u8",10
            DB "end",10
            DB "var items as R[2]",10
            DB "sub main()",10
            DB "if false and items[2].value = 0",10
            DB "end",10
            DB "if true or items[2].value = 0",10
            DB "end",10
            DB "end",10
P7SHCIRE:

P7STRTNS:
            DB "record R",10
            DB "value as u8",10
            DB "end",10
            DB "var items as R[2]",10
            DB "sub identity(flag as boolean) as boolean",10
            DB "return flag",10
            DB "end",10
            DB "sub first(flag as boolean) as u8",10
            DB "if flag",10
            DB "return 1",10
            DB "else",10
            DB "return 0",10
            DB "end",10
            DB "end",10
            DB "sub second(word as u16) as u16",10
            DB "if word > 0",10
            DB "return word",10
            DB "else",10
            DB "return 0",10
            DB "end",10
            DB "end",10
            DB "sub main() fails",10
            DB "if identity(false and items[2].value = 0)",10
            DB "writeOutputByte('X') else fail",10
            DB "end",10
            DB "if identity(true or items[2].value = 0)",10
            DB "else",10
            DB "writeOutputByte('X') else fail",10
            DB "end",10
            DB "if first(true) = 1 and second(513) = 513",10
            DB "writeOutputByte('Y') else fail",10
            DB "end",10
            DB "end",10
P7STRTNE:

P7RECAPS:
            DB "var marker as u8",10
            DB "sub descend(level as u8)",10
            DB "if level = 0",10
            DB "marker = 1",10
            DB "else",10
            DB "descend(level - 1)",10
            DB "end",10
            DB "end",10
            DB "sub main()",10
            DB "descend(8)",10
            DB "end",10
P7RECAPE:

P7SFLENS: DB ".length",10
P7SFLENE:
P7SFFLDS: DB ".value",10
P7SFFLDE:
P7SFIDXS: DB "[0]",10
P7SFIDXE:

P7TFEARS:
            DB "sub pair(a as u8, b as u8)",10
            DB "end",10
            DB "sub main()",10
            DB "pair(1)",10
            DB "end",10
P7TFEARE:

P7TMAARS:
            DB "sub one(a as u8)",10
            DB "end",10
            DB "sub main()",10
            DB "one(1, 2)",10
            DB "end",10
P7TMAARE:

P7SFOAGS:
            DB "record R",10
            DB "value as u8",10
            DB "end",10
            DB "var r as R",10
            DB "var x as u8",10
            DB "sub take(item as R)",10
            DB "end",10
            DB "sub main()",10
            DB "take(x)",10
            DB "end",10
P7SFOAGE:

P7AFOSCS:
            DB "record R",10
            DB "value as u8",10
            DB "end",10
            DB "var r as R",10
            DB "sub take(value as u8)",10
            DB "end",10
            DB "sub main()",10
            DB "take(r)",10
            DB "end",10
P7AFOSCE:

P7SREAGS:
            DB "record R",10
            DB "value as u8",10
            DB "end",10
            DB "var r as R",10
            DB "sub get() as u8",10
            DB "return r",10
            DB "end",10
            DB "sub main()",10
            DB "end",10
P7SREAGE:

P7ARESCS:
            DB "record R",10
            DB "value as u8",10
            DB "end",10
            DB "var x as u8",10
            DB "sub get() as R",10
            DB "return x",10
            DB "end",10
            DB "sub main()",10
            DB "end",10
P7ARESCE:

P7AGCSTS:
            DB "record Pair",10
            DB "left as u8",10
            DB "right as u16",10
            DB "end",10
            DB "const Origin as Pair = (7, 300)",10
            DB "const Values as u8[3] = [1, 2, 3]",10
            DB "const Text as string[3] = \"A\\0B\"",10
            ; Declaring initialized data after constants forces the compiler
            ; to shift the read-only suffix without changing constant offsets.
            DB "var target as Pair = (1, 2)",10
            DB "sub mutate(item as Pair)",10
            DB "item.left = 9",10
            DB "end",10
            DB "sub returnOrigin() as Pair",10
            DB "return Origin",10
            DB "end",10
            DB "sub main() fails",10
            DB "target = Origin",10
            DB "if target.left = 7 and target.right = 300 and Values[1] = 2 and Text.length = 3 and Text[2] = 'B'",10
            DB "mutate(Origin)",10
            DB "if Origin.left = 9 and target.left = 7",10
            DB "target = returnOrigin()",10
            DB "if target.left = 9",10
            DB "writeOutputByte('Y') else fail",10
            DB "end",10,"end",10,"end",10,"end",10
P7AGCSTE:

P7ROWASS:
            DB "record Pair",10,"value as u8",10,"end",10
            DB "const Origin as Pair = (1)",10
            DB "var target as Pair",10,"sub main()",10
P7ROWASP:
            DB "Origin = target",10,"end",10
P7ROWASE:

P7ROFASS:
            DB "record Pair",10,"value as u8",10,"end",10
            DB "const Origin as Pair = (1)",10,"sub main()",10
P7ROFASP:
            DB "Origin.value = 2",10,"end",10
P7ROFASE:

P7ROAASS:
            DB "const Values as u8[2] = [1, 2]",10,"sub main()",10
P7ROAASP:
            DB "Values[0] = 2",10,"end",10
P7ROAASE:

P7ROSASS:
            DB "const Text as string[2] = \"AB\"",10,"sub main()",10
P7ROSASP:
            DB "Text[0] = 'C'",10,"end",10
P7ROSASE:

P7ACSINS:
            DB "record Pair",10,"left as u8",10,"right as u8",10,"end",10
            DB "const Bad as Pair = (1"
P7ACSINP:
            DB $29,10,"sub main()",10,"end",10
P7ACSINE:

P7ACWTYS:
            DB "const Bad as u8[1] = [true"
P7ACWTYP:
            DB $5D,10,"sub main()",10,"end",10
P7ACWTYE:

P7ACSRUS:
            DB "const Bad as u8[1] = [readInputByte()"
P7ACSRUP:
            DB $5D,10,"sub main()",10,"end",10
P7ACSRUE:

P7ACSTYS:
            DB "const Bad as u8 "
P7ACSTYP:
            DB "= [1]",10,"sub main()",10,"end",10
P7ACSTYE:

P7ROCACS:
            DB "const a as string[253] = \"\"",10
            DB "const b as string[253] = \"\"",10
            DB "const c as string[253] = \"\"",10
            DB "const d as string[253] = \"\"",10
            DB "const tail as u8[4] = [0,0,0,0]",10
            DB "sub main()",10,"end",10
P7ROCACE:

P7ROCRES:
            DB "const a as string[253] = \"\"",10
            DB "const b as string[253] = \"\"",10
            DB "const c as string[253] = \"\"",10
            DB "const d as string[253] = \"\"",10
            DB "const tail as u8[4] = [0,0,0,0]",10
            DB "const "
P7ROCREP:
            DB "extra as u8[1] = [0]",10
P7ROCREE:

            ; Continue after these fixtures, without reusing their $B000 base.
P7PACAPS:
            DB "forward sub a(x as u8, y as u8)",10
            DB "forward sub b(x as u8, y as u8)",10
            DB "forward sub c(x as u8, y as u8)",10
            DB "forward sub d(x as u8, y as u8)",10
            DB "forward sub e(x as u8, y as u8)",10
            DB "forward sub f(x as u8, y as u8)",10
            DB "forward sub g(x as u8, y as u8)",10
            DB "forward sub h(x as u8, y as u8)",10
            DB "forward sub i(x as u8, y as u8)",10
            DB "forward sub j(x as u8, y as u8)",10
            DB "forward sub k(x as u8, y as u8)",10
            DB "forward sub l(x as u8, y as u8)",10
            DB "forward sub m(x as u8, y as u8)",10
            DB "forward sub n(z as u8"
P7PACAPP:
            DB $29,10
            DB "end",10
P7PACAPE:
P7CAFIXE:

; Source positions are derived after the actual fixture labels, not frozen offsets.
P7CSTLEO EQU P7CSTLEP-P7COSTRS
P7CSTIDO EQU P7CSTIDP-P7CSTIDS
P7DCAREO EQU P7DCAREP-P7DCARES
P7BCAREO EQU P7BCAREP-P7BCARES
P7WREREO EQU P7WREREP-P7WRERES
P7SARCAO EQU P7SARCAP-P7SEARRS
P7RTCAPO EQU P7RTCAPP-P7RTCAPS
P7PACAPO EQU P7PACAPP-P7PACAPS
P7ROWASO EQU P7ROWASP-P7ROWASS
P7ROFASO EQU P7ROFASP-P7ROFASS
P7ROAASO EQU P7ROAASP-P7ROAASS
P7ROSASO EQU P7ROSASP-P7ROSASS
P7ACSINO EQU P7ACSINP-P7ACSINS
P7ACWTYO EQU P7ACWTYP-P7ACWTYS
P7ACSRUO EQU P7ACSRUP-P7ACSRUS
P7ACSTYO EQU P7ACSTYP-P7ACSTYS
P7ROCREO EQU P7ROCREP-P7ROCRES
