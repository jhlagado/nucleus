; Streaming direct-Z80 encoder for the counted-loop semantic stream.

; Contract: in A out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
EMITBYTE:
%IF TargetStreamingOutput
            LD   B,A
            LD   HL,(EMLIM)
            LD   A,H
            OR   L
            JP   Z,ZTCAPERR
            DEC  HL
            LD   (EMLIM),HL
            LD   HL,(EMCUR)
            PUSH BC
            LD   A,(TGOUTBNK)
            LD   C,A
            LD   A,B
            PUSH HL
            CALL TSBYTE
            POP  HL
            POP  BC
            JP   C,ZTOUTERR
            INC  HL
            LD   (EMCUR),HL
            OR   A
            RET
%ELSE
            LD   B,A
            LD   HL,(EMCUR)
            LD   DE,(EMLIM)
            OR   A
            SBC  HL,DE
            ADD  HL,DE
            JP   Z,TMPUTFUL
ZEBROOM:
            LD   A,B
            LD   (HL),A
            INC  HL
            LD   (EMCUR),HL
            OR   A
            RET
%ENDIF

; Contract: noreturn
ZEBINL:
            POP  HL
            LD   A,(HL)
            JR   EMITBYTE

; Contract: noreturn
ZEBINCHK:
            POP  HL
            LD   A,(HL)
            INC  HL
            PUSH HL
%IF CompilerDiagnosticReturns
            CALL EMITBYTE
            RET  NC
            POP  HL
            RET
%ELSE
            JR   EMITBYTE
%ENDIF

; Contract: noreturn
ZEPINLIN:
            POP  HL
            LD   A,(HL)
            INC  HL
            PUSH HL
; Contract: in A out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
ZEPINDEX:
            ADD  A,A
            LD   L,A
            LD   H,0
            LD   DE,ZEPAIRT
            ADD  HL,DE
%IF TargetStreamingOutput
            JR   EMITPAIR
%ELSE
            JP   EMITPAIR
%ENDIF

ZEDECSP    EQU 0
ZELDIXL    EQU 1
ZELDIXH    EQU 2
ZESTIXL    EQU 3
ZESTIXH    EQU 4
ZEPOPDEH   EQU 5
ZEPDEPSD   EQU 6
ZETESTL    EQU 7
ZETESTH    EQU 8
ZEPHLTOA   EQU 9
ZEPHLLDD   EQU 10
ZEPHLDE    EQU 11
ZEZEROH    EQU 12
ZELDIR     EQU 13
ZEADD8     EQU 14
ZESUB8     EQU 15
ZEAND8     EQU 16
ZEOR8      EQU 17
ZEXOR8     EQU 18
ZEPHLBC    EQU 19
ZEPAIRT:
            DB  $3B,$3B                 ; DEC SP / DEC SP
            DB  $DD,$6E                 ; LD L,(IX+n)
            DB  $DD,$66                 ; LD H,(IX+n)
            DB  $DD,$75                 ; LD (IX+n),L
            DB  $DD,$74                 ; LD (IX+n),H
            DB  $D1,$E1                 ; POP DE / POP HL
            DB  $D1,$D5                 ; POP DE / PUSH DE
            DB  $7D,$B7                 ; LD A,L / OR A
            DB  $7C,$B7                 ; LD A,H / OR A
            DB  $E1,$7D                 ; POP HL / LD A,L
            DB  $E1,$11                 ; POP HL / LD DE,nn
            DB  $E1,$D1                 ; POP HL / POP DE
            DB  $26,$00                 ; LD H,0
            DB  $ED,$B0                 ; LDIR
            DB  $7D,$83                 ; LD A,L / ADD A,E
            DB  $7D,$93                 ; LD A,L / SUB E
            DB  $7D,$A3                 ; LD A,L / AND E
            DB  $7D,$B3                 ; LD A,L / OR E
            DB  $7D,$AB                 ; LD A,L / XOR E
            DB  $E1,$C1                 ; POP HL / POP BC

; Contract: in HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
EMITWORD:
            LD   C,H
            LD   A,L
            CALL EMITBYTE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,C
            JR   EMITBYTE

; Copy B retained opcode bytes. Shared fixed sequences are cheaper as data
; once two or more encoder paths need four or more emitted bytes.
; Contract: in B,HL out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
ZEBYTES:
%IF TargetStreamingOutput
            PUSH BC
            LD   C,B
            LD   B,0
            CALL ZEBLOCK
            POP  BC
            RET
%ELSE
            LD   A,(HL)
            INC  HL
            PUSH BC
            PUSH HL
            CALL EMITBYTE
            POP  HL
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            DJNZ ZEBYTES
            OR   A
            RET
%ENDIF

%IF TargetStreamingOutput
; Copy the complete BC-byte region through the checked output sink.
; Contract: in BC,HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZEBLOCK:
            LD   A,B
            OR   C
            RET  Z
            LD   A,(HL)
            INC  HL
            PUSH BC
            PUSH HL
            CALL EMITBYTE
            POP  HL
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            DEC  BC
            JR   ZEBLOCK
%ENDIF

; Contract: in HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZEEIGHT:
            LD   B,8
            JR   EMITGO
; Contract: in HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
EMITFIVE:
            LD   B,5
            JR   EMITGO
; Contract: in HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
EMITFOUR:
            LD   B,4
            JR   EMITGO
; Contract: in HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZETHREE:
            LD   B,3
            JR   EMITGO
; Contract: in HL out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
EMITPAIR:
            LD   B,2
; Contract: in B,HL out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
EMITGO:
            JR   ZEBYTES

; Patch one Z80 relative displacement. DE is the operand and HL the target.
; Contract: in DE,HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL,IX,IY
ZEPREL:
            LD   (EMPATCH),DE
            INC  DE
            OR   A
            SBC  HL,DE
            LD   C,L
            LD   A,C
            ADD  A,A
            SBC  A,A
            CP   H
            JR   NZ,ZEPINVAL
ZEPSTORE:
%IF TargetStreamingOutput
            LD   B,C
            LD   HL,(EMPATCH)
            LD   A,(TGOUTBNK)
            LD   C,A
            LD   A,B
            CALL TSPATBYT
            JP   C,ZTOUTERR
            OR   A
            RET
%ELSE
            LD   DE,(EMPATCH)
            LD   A,C
            LD   (DE),A
            OR   A
            RET
%ENDIF
ZEPINVAL:
            CALL DGINLINE
            DB  DGFIXRNG

%IF TargetStreamingOutput
%ELSE
; Contract: in HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
ZEBEGIN:
            LD   (EMLIM),HL
            LD   BC,(GNSZ)
            LD   (PUSZ),BC
            LD   A,B
            OR   C
            JR   Z,ZEBEGOK
            LD   HL,MMGEN
            LD   DE,MMBACK
            LDIR
ZEBEGOK:
            LD   HL,MMGEN
            LD   (EMCUR),HL
            OR   A
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
ZEABORT:
            LD   BC,(PUSZ)
            LD   A,B
            OR   C
            JR   Z,ZEABSIZE
            LD   HL,MMBACK
            LD   DE,MMGEN
            LDIR
ZEABSIZE:
            LD   HL,(PUSZ)
            LD   (GNSZ),HL
            SCF
            RET
%ENDIF

%IF AggregateCallSlices
%IF TargetStreamingOutput
%ELSE
; Initialize the fixed adapter table, retain all previously published segment
; sizes, and back up both image-bearing segments before tentative emission.
; Contract: in HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
ZESEGBEG:
            PUSH HL
            LD   HL,GNSZ
            LD   DE,PUSZ
            LD   BC,8
            LDIR
            LD   BC,(GNSZ)
            LD   HL,MMGENCOD
            LD   DE,MMBACK
            CALL ZESEGCOP
            LD   BC,(GNROSZ)
            LD   HL,RORDATA
            LD   DE,MMBACK+(RORDATA-MMGEN)
            CALL ZESEGCOP
            LD   HL,ZESEGINI
            LD   DE,SGTABBAS
            LD   BC,SGENTSZ*SGCAP
            LDIR
            POP  HL
            LD   (SGCDENT+SGENTLIM),HL

            CALL ZESEGVAL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            XOR  A
            RET

ZESEGINI:
            DW MMGENCOD,MMGCEND
            DW RORDATA,MMROEND
            DW MMDATA,MMDATEND
            DW MMBSS,MMBSSEND

; Contract: in BC,DE,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
ZESEGCOP:
            LD   A,B
            OR   C
            RET  Z
            LDIR
            OR   A
            RET

; Only the two image-bearing segments are selectable by the byte emitter. A is
; an internal SegmentCode/SegmentRoData ordinal supplied at the two call sites.
; Their current cursors remain cached in EmitCursor/EmitLimit and are written
; back to the bounded table at each segment switch and at publication.
; Contract: in A out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
ZESEGSEL:
            OR   A
            JR   NZ,ZESEGRO
            LD   DE,(EMCUR)
            LD   (SGROCUR),DE
            LD   HL,SGCDENT
            JR   ZESEGOK
ZESEGRO:
            LD   HL,SGROENT
ZESEGOK:
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            LD   (EMCUR),DE
            INC  HL
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            LD   (EMLIM),DE
            OR   A
            RET

; The adapter owns two ordered ROM-image segments and two ordered RAM
; segments. Reject malformed or overlapping target maps before one byte can
; be published.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
ZESEGVAL:
            LD   IX,SGTABBAS
            LD   B,SGCAP
ZESEGENT:
            LD   L,(IX+SGENTBAS)
            LD   H,(IX+SGENTBAS+1)
            LD   E,(IX+SGENTLIM)
            LD   D,(IX+SGENTLIM+1)
            OR   A
            SBC  HL,DE
            JR   NC,ZESEGERR
            LD   DE,SGENTSZ
            ADD  IX,DE
            DJNZ ZESEGENT
            LD   HL,(SGCDENT+SGENTLIM)
            LD   DE,(SGROENT+SGENTBAS)
            CALL ZESEGRQR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,(SGDATENT+SGENTLIM)
            LD   DE,(SGBSSENT+SGENTBAS)
; Contract: in DE,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
ZESEGRQR:
            OR   A
            SBC  HL,DE
            JR   C,ZESEGORD
            RET  Z
            JR   ZESEGERR
ZESEGORD:
            OR   A
            RET
ZESEGERR:
            CALL DGINLINE
            DB  DGOUTSEG

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
ZESEGABT:
            LD   BC,(PUSZ)
            LD   HL,MMBACK
            LD   DE,MMGENCOD
            CALL ZESEGCOP
            LD   BC,(PUROSZ)
            LD   HL,MMBACK+(RORDATA-MMGEN)
            LD   DE,RORDATA
            CALL ZESEGCOP
            LD   HL,PUSZ
            LD   DE,GNSZ
            LD   BC,8
            LDIR
            SCF
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,DE,HL
ZESEGFIN:
            LD   HL,(EMCUR)
            LD   DE,MMGENCOD
            OR   A
            SBC  HL,DE
            LD   (GNSZ),HL
            LD   HL,(SGROCUR)
            LD   DE,RORDATA
            OR   A
            SBC  HL,DE
            LD   (GNROSZ),HL
            LD   HL,(IMGLEN)
            LD   (GNDATSZ),HL
            LD   HL,(PGBSSLEN)
            LD   (GNBSSSZ),HL
            OR   A
            RET
%ENDIF
%ENDIF

%IF LegacyEncoders
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
ZELOOP:
            CALL ZELOOPBD
            JR   ZERESULT
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
ZECALLPG:
            CALL ZECPBODY
            JR   ZERESULT
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
ZEEXPRPG:
            CALL ZEXPBODY
            JR   ZERESULT
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
ZEARRAY:
            LD   HL,MMGENLIM
            JR   ZEARRLIM
; Contract: in HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
ZEARRLIM:
            CALL ZEARRBD
ZERESULT:
            RET  NC
            JP   ZEABORT

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
ZELOOPBD:
            LD   HL,MMGENLIM
            CALL ZEBEGIN

            LD   A,(SMBUFBAS+2)
            CALL ZELDDI
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(SMBUFBAS+4)
            CALL ZELDDI
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF

            LD   HL,(EMCUR)
            LD   (EMLOOP),HL
            CALL ZEBINCHK
            DB  $7A
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(SMBUFBAS+5)
            CALL ZECMPI
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEJRNC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   (EMEXIT),DE

            LD   A,(SMBUFBAS+7)
            CALL ZELDAI
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,RTWRITE
            CALL EMITCALL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,$38
            CALL ZEREL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   (EMFAIL),DE
            CALL ZEBINCHK
            DB  $7A
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(SMBUFBAS+5)
            DEC  A
            CALL ZECMPI
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEJRNC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   (EMUPEXIT),DE
            CALL ZEBINCHK
            DB  $14
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEJR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,(EMLOOP)
            CALL ZEPREL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF

            LD   DE,(EMEXIT)
            CALL ZEPHERE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   DE,(EMUPEXIT)
            CALL ZEPHERE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZESUCRET
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF

            LD   DE,(EMFAIL)
            CALL ZEPHERE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,LPFAIL
            CALL ZELDHL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEUNHPFX
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZETRPEND
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF

            JP   ZEFINISH
%ENDIF

; Small instruction emitters shared by the direct back end. Multiple entry
; points share the opcode-plus-operand tails rather than repeating them in
; every semantic operation.
; Contract: in A,HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZEOPWORD:
            PUSH HL
            CALL EMITBYTE
            POP  HL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%IF TargetStreamingOutput
            JR   EMITWORD
%ELSE
            JP   EMITWORD
%ENDIF

; Contract: in HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
EMITCALL:
            LD   A,$CD
            JR   ZEOPWORD

; Contract: in HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZELDHL:
            LD   A,$21
            JR   ZEOPWORD

; Contract: in HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZELDBCI:
            LD   A,$01
            JR   ZEOPWORD

; Contract: in HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZESTA:
            LD   A,$32
            JR   ZEOPWORD

%IF TargetStreamingOutput
; Emit LD (state-base+DE),A through the target-linked writable-state address.
; Contract: in DE out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZESTSTA:
            CALL ZTSTADR
            JR   ZESTA
%ENDIF

; Contract: in A,C out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
ZEOPBYTE:
            CALL EMITBYTE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,C
            JP   EMITBYTE

; Contract: in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZELDAI:
            LD   C,A
            LD   A,$3E
            JR   ZEOPBYTE

%IF LegacyEncoders
; Contract: in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZELDDI:
            LD   C,A
            LD   A,$16
            JP   ZEOPBYTE

; Contract: in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZECMPI:
            LD   C,A
            LD   A,$FE
            JP   ZEOPBYTE
%ENDIF

%IF LegacyEncoders
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZELDSCAL:
            LD   HL,RTSCALAR
            LD   A,$3A
            JP   ZEOPWORD

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZERSTCAL:
            CALL ZEBINCHK
            DB  $F5
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,RTAPOP
            CALL EMITCALL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,$F1
            JP   EMITBYTE
%ENDIF

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZESUCRET:
            LD   A,RTSUCC
            JR   ZERUNEND

; At runtime A carries the trap number and HL carries the source offset.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZETRPEND:
%IF TargetStreamingOutput
            LD   DE,RTTRPNO-RTSTATE
            CALL ZESTSTA
%ELSE
            LD   HL,RTTRPNO
            CALL ZESTA
%ENDIF
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEBINCHK
            DB  $AF
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%IF TargetStreamingOutput
            LD   DE,RTTRPRTN-RTSTATE
            CALL ZESTSTA
%ELSE
            LD   HL,RTTRPRTN
            CALL ZESTA
%ENDIF
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%IF TargetStreamingOutput
            LD   DE,RTTRPOFF-RTSTATE
            CALL ZTSTADR
%ELSE
            LD   HL,RTTRPOFF
%ENDIF
            LD   A,$22
            CALL ZEOPWORD
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,RTTRAP
; Contract: in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZERUNEND:
            CALL ZELDAI
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%IF TargetStreamingOutput
            LD   DE,RUNSTATE-RTSTATE
            CALL ZESTSTA
%ELSE
            LD   HL,RUNSTATE
            CALL ZESTA
%ENDIF
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
%IF TargetStreamingOutput
            LD   A,(TDENTVAL)
            LD   D,A
            LD   A,(TGOUTBNK)
            CP   D
            JR   Z,ZERUNLOC
            LD   A,D
            CALL ZELDAI
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,(TGTERM)
            CALL ZELDHL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,10                     ; far-jump vector ordinal
            JP   ZTVCJUMP
ZERUNLOC:
            LD   HL,(TGTERM)
            LD   A,$C3
            JR   ZEOPWORD
%ELSE
            LD   A,$C9
            JP   EMITBYTE
%ENDIF

; At runtime A carries an unhandled error and HL the failing source offset.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZEUNHPFX:
%IF TargetStreamingOutput
            LD   DE,RTTRPERR-RTSTATE
            CALL ZESTSTA
%ELSE
            LD   HL,RTTRPERR
            CALL ZESTA
%ENDIF
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,6
            JR   ZELDAI

; Contract: out A,carry,zero,DE clobbers sign,parity,halfCarry,B,HL
ZEJR:
            LD   A,$18
            JR   ZEREL
; Contract: out A,carry,zero,DE clobbers sign,parity,halfCarry,B,HL
ZEJRNC:
            LD   A,$30
; Contract: in A out A,carry,zero,DE clobbers sign,parity,halfCarry,B,HL
ZEREL:
            CALL EMITBYTE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,(EMCUR)
            PUSH HL
            XOR  A
            CALL EMITBYTE
            POP  DE
            RET

%IF LegacyEncoders
; Contract: out A,carry,zero,DE clobbers sign,parity,halfCarry,B,HL
ZEJRC:
            LD   A,$38
            JP   ZEREL
%ENDIF

; Contract: in DE,HL out A,carry,zero clobbers sign,parity,halfCarry,DE,HL
ZEPWORD:
%IF TargetStreamingOutput
            PUSH BC
            LD   A,(TGOUTBNK)
            LD   C,A
            CALL TSPATWRD
            POP  BC
            JP   C,ZTOUTERR
            OR   A
            RET
%ELSE
            LD   A,L
            LD   (DE),A
            INC  DE
            LD   A,H
            LD   (DE),A
            OR   A
            RET
%ENDIF

; Patch a stored displacement to the current output position.
; Contract: in DE out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL,IX,IY
ZEPHERE:
            LD   HL,(EMCUR)
            JP   ZEPREL

%IF TargetStreamingOutput
%ELSE
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,DE,HL
ZEFINISH:
            LD   HL,(EMCUR)
            LD   DE,MMGEN
            OR   A
            SBC  HL,DE
            LD   (GNSZ),HL
            OR   A
            RET
%ENDIF

; Read one operand from the checked semantic transcript. The operation count
; bounds dispatch; individual handlers know the fixed width of their operands.
ZECBEGIN:
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,HL
ZENEXTB:
            LD   HL,(SMRDCUR)
            LD   A,(HL)
            INC  HL
            LD   (SMRDCUR),HL
            OR   A
            RET

; Contract: out A,DE,carry,zero clobbers sign,parity,halfCarry,HL
ZEREADW:
            CALL ZENEXTB
            LD   E,A
            CALL ZENEXTB
            LD   D,A
            RET

; Dense ordinal dispatcher for the first non-positional backend. A pushed
; continuation turns the Z80's JP (HL) into a compact indirect call. This
; entry is post-parse only: SemanticSinkFinish must have published the complete
; transcript before emitter scratch overlays the retained forward signature.
%IF LegacyEncoders
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL,IX,IY
ZECDISP:
            LD   HL,SMPAYBAS
            LD   (SMRDCUR),HL
            LD   A,(SMBUFBAS)
            OR   A
            RET  Z
            LD   B,A
ZECNEXT:
            PUSH BC
            CALL ZENEXTB
            SUB  SMCLITU8
            CP   ZECOPCNT
            JR   NC,ZECINVAL
            ADD  A,A
            LD   E,A
            LD   D,0
            LD   HL,ZECOPTAB
            ADD  HL,DE
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            EX   DE,HL
            LD   DE,ZECRET
            PUSH DE
            JP   (HL)
ZECRET:
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            DJNZ ZECNEXT
            OR   A
            RET
ZECINVAL:
            POP  BC
            CALL DGINLINE
            DB  DGSNKCAP

ZECOPTAB:
            DW ZECLIT
            DW ZECWRLOC
            DW ZECFWDB
            DW ZECIFPZ
            DW ZECRPARM
            DW ZECENDIF
            DW ZECRSELF
            DW ZECENDRT
ZECOPCNT   EQU 8

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL,IX,IY
ZECLIT:
            CALL ZENEXTB
            CALL ZENEXTB
            CALL ZELDAI
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,RTAPUSH
            CALL EMITCALL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEJRC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   (EMEXIT),DE
            CALL ZEBINCHK
            DB  $CD
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,(EMCUR)
            LD   (EMRTNCFX),HL
            LD   HL,0
            CALL EMITWORD
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZERSTCAL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   DE,(EMEXIT)
            CALL ZEPHERE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEJRC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   (EMUPEXIT),DE
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZECWRLOC:
            LD   HL,RTWRITE
            CALL EMITCALL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEJRC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   (EMFAIL),DE
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZECFWDB:
            CALL ZENEXTB
            LD   HL,(EMCUR)
            LD   (EMRTNADR),HL
            LD   DE,(EMRTNCFX)
            JP   ZEPWORD

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZECIFPZ:
            CALL ZENEXTB
            CALL ZELDSCAL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEBINCHK
            DB  $B7
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,$20
            CALL ZEREL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   (EMIFFIX),DE
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZECRPARM:
            CALL ZELDSCAL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,$C9
            JP   EMITBYTE

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL,IX,IY
ZECENDIF:
            LD   DE,(EMIFFIX)
            JP   ZEPHERE

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZECRSELF:
            CALL ZENEXTB
            CALL ZENEXTB
            LD   C,A
            PUSH BC
            CALL ZELDSCAL
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,$D6
            CALL ZEOPBYTE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,RTAPUSH
            CALL EMITCALL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEBINCHK
            DB  $D8
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,(EMRTNADR)
            CALL EMITCALL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZERSTCAL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,$C9
            JP   EMITBYTE

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL,IX,IY
ZECENDRT:
            LD   HL,(EMRTNADR)
            LD   A,H
            OR   L
            RET  NZ
            CALL ZESUCRET
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   DE,(EMUPEXIT)
            CALL ZEPHERE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,CLCAPOFF
            CALL ZELDHL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZETRPEND
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   DE,(EMFAIL)
            CALL ZEPHERE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,CLFAIL
            CALL ZELDHL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEUNHPFX
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   ZETRPEND

; Compile the routine slice from its variable-width semantic stream.
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
ZECPBODY:
            LD   HL,MMGENLIM
            CALL ZEBEGIN
            LD   HL,0
            LD   (EMRTNADR),HL
            CALL ZECDISP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   ZEFINISH
ZECEND:
%ENDIF

; Dense postfix-expression backend. Program data follows an initial JP, so its
; address is known before the code entry is patched. Scalar locals use an IX
; frame and therefore remain per activation; the evaluation stack lies below
; that frame and is empty at every statement boundary.
%IF LegacyEncoders
ZEXBEGIN:
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL,IX,IY
ZEXDISP:
            LD   HL,SMPAYBAS
            LD   (SMRDCUR),HL
            LD   A,(SMBUFBAS)
            OR   A
            RET  Z
            LD   B,A
ZEXNEXT:
            PUSH BC
            CALL ZENEXTB
            SUB  SMDEFPU8
            CP   ZEXOPCNT
            JR   NC,ZEXINVAL
            ADD  A,A
            LD   E,A
            LD   D,0
            LD   HL,ZEXOPTAB
            ADD  HL,DE
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            EX   DE,HL
            LD   DE,ZEXRET
            PUSH DE
            JP   (HL)
ZEXRET:
            POP  BC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            DJNZ ZEXNEXT
            OR   A
            RET
ZEXINVAL:
            POP  BC
            CALL DGINLINE
            DB  DGSNKCAP

ZEXOPTAB:
            DW ZEXDEFPG
            DW ZEXMAIN
            DW ZEXDLOC
            DW ZEXLIT
            DW ZEXLDPRG
            DW ZEXLDLOC
            DW ZEXMUL
            DW ZEXADD
            DW ZEXSTPRG
            DW ZEXSTLOC
            DW ZEXWRITE
            DW ZEXENDM
ZEXOPCNT   EQU 12
%ENDIF

; Contract: out A,HL,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,IX,IY
ZEXPGADR:
%IF AggregateCallSlices
            CALL ZEREADW
%IF TargetStreamingOutput
            BIT  7,D
            JR   Z,ZEXTDADR
            RES  7,D
            LD   HL,(TGBSSBAS)
            JR   ZEXTAOK
ZEXTDADR:
            LD   HL,(TCDATBAS)
ZEXTAOK:
            ADD  HL,DE
            OR   A
            RET
%ELSE
            LD   H,D
            LD   L,E
            OR   A
            RET
%ENDIF
%ELSE
            CALL ZENEXTB
            LD   E,A
            LD   D,0
            LD   HL,MMGEN+3
            ADD  HL,DE
            RET
%ENDIF

%IF LegacyEncoders
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
ZEXDEFPG:
            CALL ZENEXTB
            CALL ZENEXTB
            JP   EMITBYTE

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZEXMAIN:
            LD   DE,(EMDATFIX)
            LD   HL,(EMCUR)
            CALL ZEPWORD
            LD   HL,ZEXFRBYT
            JP   ZEEIGHT

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
ZEXDLOC:
            CALL ZENEXTB
            LD   A,$3B
            JP   EMITBYTE

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZEXLIT:
            CALL ZENEXTB
            CALL ZELDAI
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
ZEXPUSHA:
            LD   A,$F5
            JP   EMITBYTE

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ZEXLDPRG:
            CALL ZENEXTB
            CALL ZEXPGADR
            LD   A,$3A
            CALL ZEOPWORD
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   ZEXPUSHA

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZEXLDLOC:
            CALL ZENEXTB
            CPL
            LD   C,A
            CALL ZEBINCHK
            DB  $DD
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,$7E
            CALL ZEOPBYTE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   ZEXPUSHA

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZEXMUL:
            CALL ZEBINCHK
            DB  $C1
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEBINCHK
            DB  $F1
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,RTMUL8
            CALL EMITCALL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,$F5
            JP   EMITBYTE

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
ZEXADD:
            LD   HL,ZEXADDB
            JP   EMITFOUR

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,DE,HL
ZEXSTPRG:
            CALL ZENEXTB
            CALL ZEXPGADR
            PUSH HL
            LD   A,$F1
            CALL EMITBYTE
            POP  HL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,$32
            JP   ZEOPWORD

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZEXSTLOC:
            CALL ZENEXTB
            CPL
            LD   C,A
            CALL ZEBINCHK
            DB  $F1
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEBINCHK
            DB  $DD
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,$77
            JP   ZEOPBYTE

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZEXWRITE:
            CALL ZENEXTB
            LD   C,A
            CALL ZENEXTB
            LD   H,A
            LD   L,C
            LD   (EMLOOP),HL
            CALL ZEBINCHK
            DB  $F1
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,RTWRITE
            CALL EMITCALL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEJRC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   (EMFAIL),DE
            RET
%ENDIF

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
ZEXRSTFR:
            LD   HL,ZEXRSTB
            JP   EMITFOUR

%IF LegacyEncoders
; Contract: out A,carry,zero clobbers sign,parity,halfCarry,B,C,DE,HL
ZEXENDM:
            CALL ZEXRSTFR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZESUCRET
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   DE,(EMFAIL)
            CALL ZEPHERE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEXRSTFR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,(EMLOOP)
            CALL ZELDHL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEUNHPFX
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   ZETRPEND

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
ZEXPBODY:
            LD   HL,MMGENLIM
            CALL ZEBEGIN
            CALL ZEBINCHK
            DB  $C3
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,(EMCUR)
            LD   (EMDATFIX),HL
            LD   HL,0
            CALL EMITWORD
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEXDISP
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            JP   ZEFINISH
%ENDIF
ZEXFRBYT:
            DB $DD,$E5,$DD,$21,$00,$00,$DD,$39
%IF LegacyEncoders
ZEXADDB:
            DB $C1,$F1,$80,$F5
%ENDIF
ZEXRSTB:
            DB $DD,$F9,$DD,$E1
%IF LegacyEncoders
ZEXEND:

; Default entry and proof-only bounded entry for the checked-array program.
; Contract: in HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
ZEARRBD:
            CALL ZEBEGIN

            LD   HL,RTREADIN
            CALL EMITCALL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEJRNC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   (EMEXIT),DE
            LD   HL,ARYIFAIL
            CALL ZELDHL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEJR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   (EMFAIL),DE

            LD   DE,(EMEXIT)
            CALL ZEPHERE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,(SMBUFBAS+2)
            CALL ZECMPI
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEJRNC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   (EMUPEXIT),DE
            CALL ZEBINCHK
            DB  $5F
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            XOR  A
            CALL ZELDDI
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEBINCHK
            DB  $21
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,(EMCUR)
            LD   (EMDATFIX),HL
            LD   HL,0
            CALL EMITWORD
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEBINCHK
            DB  $19
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEBINCHK
            DB  $7E
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,RTWRITE
            CALL EMITCALL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEJRNC
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   (EMLOOP),DE
            LD   HL,ARYOFAIL
            CALL ZELDHL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEJR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   (EMCODST),DE

            LD   DE,(EMLOOP)
            CALL ZEPHERE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZESUCRET
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF

            LD   DE,(EMUPEXIT)
            CALL ZEPHERE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,ARYBOFF
            CALL ZELDHL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEBINCHK
            DB  $AF
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   HL,RTTRPERR
            CALL ZESTA
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   A,1
            CALL ZELDAI
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEJR
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   (EMEXIT),DE

            LD   DE,(EMFAIL)
            CALL ZEPHERE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   DE,(EMCODST)
            CALL ZEPHERE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZEUNHPFX
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            LD   DE,(EMEXIT)
            CALL ZEPHERE
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            CALL ZETRPEND
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF

            LD   HL,(EMCUR)
            LD   DE,(EMDATFIX)
            CALL ZEPWORD
            LD   HL,SMBUFBAS+3
            LD   C,4
ZEARRDAT:
            LD   A,(HL)
            PUSH HL
            CALL EMITBYTE
            POP  HL
%IF CompilerDiagnosticReturns
            RET  C
%ENDIF
            INC  HL
            DEC  C
            JR   NZ,ZEARRDAT
            JP   ZEFINISH
%ENDIF
