; Predictive parser and fixed semantic checks for the first complete program.

; Store the first diagnostic at the current token start. Carry denotes failure.
.routine in A out A,carry clobbers zero,sign,parity,halfCarry,HL
CompilerSetDiagnostic:
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
.routine in DE out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
ParserExpect:
            PUSH DE
            CALL TKNEXT
            POP  DE
            RET  C
            CP   E
            RET  Z
            LD   A,D
            JP   CompilerSetDiagnostic

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
ParserExpectMain:
            LD   D,DXMAIN
            LD   E,TNNAME
            CALL ParserExpect
            RET  C
            LD   HL,NAMEMAIN
            LD   B,4
            CALL TKNAMEEQ
            JR   NC,ParserExpectMainNo
            OR   A
            RET
ParserExpectMainNo:
            LD   A,DXMAIN
            JP   CompilerSetDiagnostic

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
ParserExpectWrite:
            LD   D,DXWR
            LD   E,TNNAME
            CALL ParserExpect
            RET  C
            LD   HL,KWWRTOUT
            LD   B,15
            CALL TKNAMEEQ
            JR   NC,ParserExpectWriteNo
            OR   A
            RET
ParserExpectWriteNo:
            LD   A,DXWR
            JP   CompilerSetDiagnostic

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
ParserParseProgram:
            LD   D,DXSUB
            LD   E,TOKENSUB
            CALL ParserExpect
            RET  C
            CALL ParserExpectMain
            RET  C
            LD   D,DXLPAR
            LD   E,TNLPAR
            CALL ParserExpect
            RET  C
            LD   D,DXRPAR
            LD   E,TNRPAR
            CALL ParserExpect
            RET  C
            LD   D,DXFAILS
            LD   E,TNFAILS
            CALL ParserExpect
            RET  C
            LD   D,DXLINE
            LD   E,TNNL
            CALL ParserExpect
            RET  C

            CALL ParserExpectWrite
            RET  C
            LD   D,DXLPAR
            LD   E,TNLPAR
            CALL ParserExpect
            RET  C
            LD   D,DXCHAR
            LD   E,TNCHAR
            CALL ParserExpect
            RET  C
            LD   A,(TNVALUE)
            LD   (PSOUTBYT),A
            LD   D,DXRPAR
            LD   E,TNRPAR
            CALL ParserExpect
            RET  C
            LD   D,DXELSE
            LD   E,TNELSE
            CALL ParserExpect
            RET  C
            LD   D,DXFAIL
            LD   E,TNFAIL
            CALL ParserExpect
            RET  C
            LD   D,DXLINE
            LD   E,TNNL
            CALL ParserExpect
            RET  C

            LD   D,DXEND
            LD   E,TOKENEND
            CALL ParserExpect
            RET  C
            LD   D,DXLINE
            LD   E,TNNL
            CALL ParserExpect
            RET  C
            LD   D,DXEOF
            LD   E,TOKENEOF
            CALL ParserExpect
            RET  C
            LD   A,(PSOUTBYT)
            OR   A
            RET

; A is the stable source-part identity; HL..DE is the half-open byte range.
.routine in A,DE,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CompileVerticalSlice:
            CALL SAINIT
            XOR  A
            LD   (DGCODE),A
            LD   (DGPARTID),A
            CALL SemanticSinkReset
            CALL ParserParseProgram
            RET  C
            CALL SemanticSinkEmitProgram
            RET
