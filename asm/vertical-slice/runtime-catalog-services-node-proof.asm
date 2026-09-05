%INCLUDE "platform-services-abi.asmi"

LPRCPORT   EQU $E2
LPSTACK    EQU $7F00

            ORG $0010
LPRCGATE:
            OUT  (LPRCPORT),A
            RET

            ORG $4000
FPSTART:
            LD   SP,LPSTACK
            LD   (LPENTSP),SP
            LD   IX,$1357
            LD   IY,$2468

            LD   HL,LPREQ
            LD   C,NSRTCAT
            RST  $10
            JP   C,FPFAIL
            LD   HL,(LPREQ+NCFRES)
            LD   DE,2
            OR   A
            SBC  HL,DE
            JP   NZ,FPFAIL
            LD   HL,(LPBUFFER)
            LD   DE,$3322
            OR   A
            SBC  HL,DE
            JP   NZ,FPFAIL

            LD   A,NCINIT
            LD   (LPREQ+NCFOPER),A
            LD   A,1
            LD   (LPREQ+NCFFLAG),A
            LD   A,3
            LD   (LPREQ+NCFBANK),A
            LD   HL,5
            LD   (LPREQ+NCFLEN),HL
            LD   HL,0
            LD   (LPREQ+NCFOFF),HL
            LD   HL,5
            LD   (LPREQ+NCFCAP),HL
            LD   HL,LPREQ
            LD   C,NSRTCAT
            RST  $10
            JP   C,FPFAIL
            LD   HL,(LPREQ+NCFRES)
            LD   DE,5
            OR   A
            SBC  HL,DE
            JP   NZ,FPFAIL
            LD   HL,LPEXINIT
            LD   DE,LPBUFFER
            LD   B,5
LPCMP:
            LD   A,(DE)
            CP   (HL)
            JP   NZ,FPFAIL
            INC  DE
            INC  HL
            DJNZ LPCMP

            PUSH IX
            POP  HL
            LD   DE,$1357
            OR   A
            SBC  HL,DE
            JP   NZ,FPFAIL
            PUSH IY
            POP  HL
            LD   DE,$2468
            OR   A
            SBC  HL,DE
            JP   NZ,FPFAIL
            LD   HL,0
            ADD  HL,SP
            LD   DE,(LPENTSP)
            OR   A
            SBC  HL,DE
            JP   NZ,FPFAIL
            XOR  A
            LD   (LPRES),A
            HALT

FPFAIL:
            LD   A,1
            LD   (LPRES),A
            HALT

LPENTSP: DW 0
LPRES:  DB $FF
LPCTX: DW $8003,$4000,$1000,$4024,$4000,$404D,$0010,0,0
LPREQ:
            DB NCRQSIZE
            DB NCABI
            DB NCCODE,0,0,0
            DW $000A,4,LPCTX,1,LPBUFFER,2,0,0
LPBUFFER:          DB 0,0,0,0,0
LPEXINIT: DB 1,2,3,3,5
