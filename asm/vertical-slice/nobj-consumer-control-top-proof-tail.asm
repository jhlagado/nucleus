LPCCEND:

            ORG LVCTLBA
LPRUNDSC:
            DB  10,0,1,0
            DW  1,LPDEPLY,LPRESULT
LPDEPLY:
            DB  18,1,0
            DW  1
            DB  1,$EE
            DW  $8000,$0100,$8080,$0020
            DB  0
            DW  0
LPRESULT:
            DB  0,0,0,0
FPSTATUS:
            DB  0
