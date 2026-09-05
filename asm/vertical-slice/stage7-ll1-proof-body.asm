LGMEASEN:

            ORG MMSOURCE
LGTOKENS:
            DB TOKENSUB,TNNAME,TNLPAR,TNRPAR
            DB TNFAILS,TNNL,TOKENEND,TNNL,TOKENEOF
LGTOKEND:

            ORG MMPROOF
LGSTART:
            LD   SP,STACKTOP
            LD   HL,LGTOKENS
            LD   (LGCURSOR),HL
            XOR  A
            LD   (DGCODE),A
            CALL LLPARSE
            JP   C,LGFAIL
            LD   HL,(LGCURSOR)
            LD   DE,LGTOKEND
            OR   A
            SBC  HL,DE
            JP   NZ,LGFAIL

            ; Prediction must propagate a tokenizer/source failure without
            ; retaining the row diagnostic on the hardware stack.
            LD   HL,LGTOKENS
            LD   (LGCURSOR),HL
            LD   A,1
            LD   (LGPEEKFL),A
            LD   (LGSP),SP
            CALL LLPARSE
            JP   NC,LGFAIL
            CP   DXTOKBAS
            JP   NZ,LGFAIL
            LD   A,(DGCODE)
            CP   DXTOKBAS
            JP   NZ,LGFAIL
            LD   HL,0
            ADD  HL,SP
            LD   DE,(LGSP)
            OR   A
            SBC  HL,DE
            JP   NZ,LGFAIL
            XOR  A
            LD   (LGPEEKFL),A

            ; A four-symbol production exactly fills slots 60..63 without
            ; touching the action workspace immediately above the stack.
            LD   A,$5A
            LD   (LLSTACK+HYLLCAP),A
            LD   A,60
            LD   (LLDEPTH),A
            LD   A,31
            CALL LLPUSHP
            JR   C,LGFAIL
            LD   A,(LLDEPTH)
            CP   HYLLCAP
            JR   NZ,LGFAIL
            LD   A,(LLSTACK+HYLLCAP)
            CP   $5A
            JR   NZ,LGFAIL

            ; Both a single-symbol push at depth 64 and the same production
            ; at depth 63 fail atomically with the dedicated diagnostic.
            XOR  A
            CALL LLPUSHS
            JR   NC,LGFAIL
            LD   A,(DGCODE)
            CP   DGLLCAP
            JR   NZ,LGFAIL
            LD   A,(LLDEPTH)
            CP   HYLLCAP
            JR   NZ,LGFAIL
            LD   A,63
            LD   (LLDEPTH),A
            LD   A,31
            CALL LLPUSHP
            JR   NC,LGFAIL
            LD   A,(DGCODE)
            CP   DGLLCAP
            JR   NZ,LGFAIL
            LD   A,(LLDEPTH)
            CP   63
            JR   NZ,LGFAIL
            LD   A,(LLSTACK+HYLLCAP)
            CP   $5A
            JR   NZ,LGFAIL
            LD   A,$A5
            LD   (LGSTATUS),A
            HALT
LGFAIL:
            LD   A,$EE
            LD   (LGSTATUS),A
            HALT
