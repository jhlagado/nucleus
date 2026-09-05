; Predictive parser and fixed semantic checks for the first complete program.

; Store the first diagnostic at the current token start. Carry denotes failure.
; ABI: in A out A,carry clobbers zero,sign,parity,halfCarry,HL
DGSET:
            LD   (DGCODE),A
            LD   A,(SSPARTID)
            LD   (DGPARTID),A
            LD   HL,(TNSTOFF)
            LD   (DGOFF),HL
            LD   HL,(TNSTLINE)
            LD   (DGLINE),HL
            LD   HL,(TNSTCOL)
            LD   (DGCOL),HL
            SCF
            RET

; D is the diagnostic code and E the expected token ordinal.
; ABI: in DE out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
PSEXPECT:
            PUSH DE
            CALL TKNEXT
            POP  DE
            RET  C
            CP   E
            RET  Z
            LD   A,D
            JP   DGSET

; ABI: out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
EPEXMAIN:
            LD   D,DXMAIN
            LD   E,TNNAME
            CALL PSEXPECT
            RET  C
            LD   HL,NAMEMAIN
            LD   B,4
            CALL TKNAMEEQ
            JR   NC,EPEXMNNO
            OR   A
            RET
EPEXMNNO:
            LD   A,DXMAIN
            JP   DGSET

; ABI: out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
PSXWR:
            LD   D,DXWR
            LD   E,TNNAME
            CALL PSEXPECT
            RET  C
            LD   HL,KWWRTOUT
            LD   B,15
            CALL TKNAMEEQ
            JR   NC,EPEXWRNO
            OR   A
            RET
EPEXWRNO:
            LD   A,DXWR
            JP   DGSET

; ABI: out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
PSPPG:
            LD   D,DXSUB
            LD   E,TOKENSUB
            CALL PSEXPECT
            RET  C
            CALL EPEXMAIN
            RET  C
            LD   D,DXLPAR
            LD   E,TNLPAR
            CALL PSEXPECT
            RET  C
            LD   D,DXRPAR
            LD   E,TNRPAR
            CALL PSEXPECT
            RET  C
            LD   D,DXFAILS
            LD   E,TNFAILS
            CALL PSEXPECT
            RET  C
            LD   D,DXLINE
            LD   E,TNNL
            CALL PSEXPECT
            RET  C

            CALL PSXWR
            RET  C
            LD   D,DXLPAR
            LD   E,TNLPAR
            CALL PSEXPECT
            RET  C
            LD   D,DXCHAR
            LD   E,TNCHAR
            CALL PSEXPECT
            RET  C
            LD   A,(TNVALUE)
            LD   (PSOUTBYT),A
            LD   D,DXRPAR
            LD   E,TNRPAR
            CALL PSEXPECT
            RET  C
            LD   D,DXELSE
            LD   E,TNELSE
            CALL PSEXPECT
            RET  C
            LD   D,DXFAIL
            LD   E,TNFAIL
            CALL PSEXPECT
            RET  C
            LD   D,DXLINE
            LD   E,TNNL
            CALL PSEXPECT
            RET  C

            LD   D,DXEND
            LD   E,TOKENEND
            CALL PSEXPECT
            RET  C
            LD   D,DXLINE
            LD   E,TNNL
            CALL PSEXPECT
            RET  C
            LD   D,DXEOF
            LD   E,TOKENEOF
            CALL PSEXPECT
            RET  C
            LD   A,(PSOUTBYT)
            OR   A
            RET

; A is the stable source-part identity; HL..DE is the half-open byte range.
; ABI: in A,DE,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
ECOMPSL:
            CALL SAINIT
            XOR  A
            LD   (DGCODE),A
            LD   (DGPARTID),A
            CALL TMRESET
            CALL PSPPG
            RET  C
            CALL ESKEMIT
            RET
