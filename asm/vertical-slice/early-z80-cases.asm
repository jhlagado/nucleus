KCSNKEND:
KCCODEND:

KCIMM:
EKWSUB:
            DB  "sub"
EKWFAILS:
            DB  "fails"
EKWELSE:
            DB  "else"
EKWFAIL:
            DB  "fail"
EKWEND:
            DB  "end"
NAMEMAIN:
            DB  "main"
KWWRTOUT:
            DB  "writeOutputByte"
EPRGTPL:
            DB  $3E,$00
            DB  $CD
            DW  RTWRITE
            DB  $38,$06
            DB  $3E,RTSUCC,$32
            DW  RUNSTATE
            DB  $C9
            DB  $32
            DW  RTTRPERR
            DB  $AF,$32
            DW  RTTRPRTN
            DB  $21
            DW  EFAILOFF
            DB  $22
            DW  RTTRPOFF
            DB  $3E,$06,$32
            DW  RTTRPNO
            DB  $3E,RTTRAP,$32
            DW  RUNSTATE
            DB  $C9
KCIMMEND:
KCEND:

            ORG MMSOURCE
EPRFSRC:
            DB  "sub main() fails",10
            DB  "    writeOutputByte('A') else fail",10
            DB  "end",10
EPRFSEND:

            ORG MMRUN
RTSTART:
