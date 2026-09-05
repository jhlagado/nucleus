%INCLUDE "platform-services-abi.asmi"

LPOPORT    EQU $E1
LPSTACK    EQU $7F00

            ORG $0010
LPOGATE:
            OUT  (LPOPORT),A
            RET

            ORG $4000
FPSTART:
            LD   SP,LPSTACK
            LD   (LPENTSP),SP
            LD   IX,$1357
            LD   IY,$2468

            LD   HL,LPOREQ
            LD   C,NSOBJECT
            RST  $10
            JP   C,FPFAIL
            LD   HL,(LPOREQ+NOFHAND)
            LD   A,H
            OR   L
            JP   Z,FPFAIL

            LD   A,NOREAD
            LD   (LPOREQ+NOFOPER),A
            LD   HL,LPRDBUF
            LD   (LPOREQ+NOFPTR),HL
            LD   HL,3
            LD   (LPOREQ+NOFLEN),HL
            LD   HL,LPOREQ
            LD   C,NSOBJECT
            RST  $10
            JP   C,FPFAIL
            LD   HL,(LPOREQ+NOFRES)
            LD   DE,3
            OR   A
            SBC  HL,DE
            JP   NZ,FPFAIL

            LD   A,NOCLOSE
            LD   (LPOREQ+NOFOPER),A
            LD   HL,0
            LD   (LPOREQ+NOFPTR),HL
            LD   (LPOREQ+NOFLEN),HL
            LD   (LPOREQ+NOFRES),HL
            LD   HL,LPOREQ
            LD   C,NSOBJECT
            RST  $10
            JP   C,FPFAIL

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

LPENTSP:      DW 0
LPRES:       DB $FF
LPONAME:   DB "source.nu"
LPOREQ:
            DB NORQSIZE,NOABI
            DB NOOPEN,0
            DW 0,LPONAME,9,0,0,0
LPRDBUF:   DB 0,0,0
FPEND:
