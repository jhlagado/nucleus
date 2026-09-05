; Fixed native CP/M runtime-catalogue provider. The offline-generated assets
; are already linked for the one loaded target placement and packet gateway.

CRDEST     EQU DOWKEND
CRCTX      EQU CRDEST+2
CRWRKEND   EQU CRCTX+2

CRCODEPA   EQU DOBUF+3
CRINITPA   EQU DOBUF+(DOWRBASE-DOIMG)
CRINITLN   EQU RIVECBYT+RISTBYT
CRDBOFF    EQU RIVECBYT+RODBASE
CRDCOFF    EQU RIVECBYT+RODCAP
CRBADCFG   EQU 95

CRCODE:
; Contract: in A,BC,DE,HL,IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CRPROVID:
            LD   (CRDEST),HL
            LD   (CRCTX),IX
            PUSH AF
            LD   A,D
            OR   A
            JR   NZ,CRBADPOP
            LD   A,E
            CP   RIABI
            JR   NZ,CRBADPOP
            POP  AF
            OR   A
            JR   Z,CRGETCOD
            DEC  A
            JR   NZ,CRBAD
            LD   HL,CRINITLN
            OR   A
            SBC  HL,BC
            JR   NZ,CRBAD
            LD   HL,(CRDEST)
            LD   DE,CRINITPA
            OR   A
            SBC  HL,DE
            JR   NZ,CRBAD
            LD   HL,EMBINIT
            JR   CRCPINIT
CRGETCOD:
            LD   HL,RIBYTES
            OR   A
            SBC  HL,BC
            JR   NZ,CRBAD
            LD   HL,(CRDEST)
            LD   DE,CRCODEPA
            OR   A
            SBC  HL,DE
            JR   NZ,CRBAD
            LD   HL,EMBRT
            LD   DE,(CRDEST)
            LD   BC,RIBYTES
            LDIR
            XOR  A
            RET
CRCPINIT:
            LD   DE,(CRDEST)
            LD   BC,CRINITLN
            LDIR
            LD   IX,(CRCTX)
            LD   HL,(CRDEST)
            LD   BC,CRDBOFF
            ADD  HL,BC
            LD   A,(IX+10)
            LD   (HL),A
            INC  HL
            LD   A,(IX+11)
            LD   (HL),A
            INC  HL
            LD   A,(IX+12)
            LD   (HL),A
            INC  HL
            LD   A,(IX+13)
            LD   (HL),A
            XOR  A
            RET
CRBADPOP:
            POP  AF
CRBAD:
            LD   A,CRBADCFG
            SCF
            RET
CRCODEND:
