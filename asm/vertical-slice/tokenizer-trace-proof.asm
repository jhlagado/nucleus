; Native ATOM trace proof; immutable configuration is selected by its build helper.
%INCLUDE "memory-map.asmi"
%INCLUDE "loop-compiler-state.asmi"
%INCLUDE "aggregate-call-state.asmi"
%INCLUDE "tokenizer-trace-layout.asmi"
%INCLUDE "source-adapter.asm"
%INCLUDE "loop-tokenizer.asm"
%INCLUDE "tokenizer-trace-diagnostics.asm"
%INCLUDE "loop-keywords.asmi"

TTIEND:
TTCOREND:

            ORG MMSOURCE
TTPART1:
            DB  "< <= <> > >= << >> /"
TTP1END:
TTPART2:
            DB  "/",10
            DB  "//lf",10
            DB  "//crlf",13,10
            DB  "//eof"
TTP2END:
TTPART3:
            DB  "$f"
TTP3END:

TTPARTS:
            DB  1
            DW  TTPART1,TTP1END
            DB  2
            DW  TTPART2,TTP2END
            DB  3
            DW  TTPART3,TTP3END

            ORG MMPROOF
; Contract: out carry,zero clobbers sign,parity,halfCarry,A,BC,DE,HL,IX
TTSTART:
            LD   SP,STACKTOP
            XOR  A
            LD   (TTCASE),A
            LD   (TTSTATUS),A
            LD   A,3
            LD   HL,TTPARTS
            CALL SAPARTS
            JP   C,TTFAIL
            LD   IX,TTEXPECT

TTNEXT:
            CALL TKNEXT
            JP   C,TTFAIL
            CP   (IX+0)
            JP   NZ,TTFAIL

            LD   L,(IX+1)
            LD   H,(IX+2)
            LD   DE,(TNSTOFF)
            OR   A
            SBC  HL,DE
            JP   NZ,TTFAIL

            LD   L,(IX+3)
            LD   H,(IX+4)
            LD   DE,(TNSTLINE)
            OR   A
            SBC  HL,DE
            JP   NZ,TTFAIL

            LD   L,(IX+5)
            LD   H,(IX+6)
            LD   DE,(TNSTCOL)
            OR   A
            SBC  HL,DE
            JP   NZ,TTFAIL

            LD   DE,7
            ADD  IX,DE
            LD   A,(IX+0)
            INC  A
            JR   NZ,TTNEXT

            LD   A,$A5
            LD   (TTSTATUS),A
            HALT

TTFAIL:
            LD   A,1
            LD   (TTCASE),A
            LD   A,$E0
            LD   (TTSTATUS),A
            HALT

; token, offset, line, column. Offsets restart for each source part.
TTEXPECT:
            DB  TNLT
            DW  0,1,1
            DB  TNLTEQ
            DW  2,1,3
            DB  TNNOTEQ
            DW  5,1,6
            DB  TNGT
            DW  8,1,9
            DB  TNGTEQ
            DW  10,1,11
            DB  TNLT
            DW  13,1,14
            DB  TNLT
            DW  14,1,15
            DB  TNGT
            DW  16,1,17
            DB  TNGT
            DW  17,1,18
            DB  TNSLASH
            DW  19,1,20
            DB  TNNL
            DW  20,1,21
            DB  TNSLASH
            DW  0,1,1
            DB  TNNL
            DW  1,1,2
            DB  TNNUM
            DW  0,1,1
            DB  TNNL
            DW  2,1,3
            DB  TOKENEOF
            DW  2,1,3
            DB  $FF

TTSTATUS: DB 0
TTCASE:   DB 0
TTEND:
