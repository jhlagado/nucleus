; Direct flat-image target sink for the CP/M compiler candidate.
;
; The trusted compiler still emits ordered IMAGE and PATCH operations. This
; sink materializes them immediately in a private TPA buffer; a later commit
; publishes the already-patched bytes transactionally as a COM file. Runtime
; catalogue transfer and CP/M file publication are provider operations and are
; measured outside this core.

DOMAPPTR    EQU DOWKBASE
DOACTIVE    EQU DOMAPPTR+2
DOUSED      EQU DOACTIVE+1
DOPATADR    EQU DOUSED+2
DOPATVAL    EQU DOPATADR+2
DORTOPER    EQU DOPATVAL+2
DORTLEN     EQU DORTOPER+1
DORTID      EQU DORTLEN+2
DORTCTX     EQU DORTID+2
DORANGE     EQU DORTCTX+2
DOWKEND     EQU DORANGE+2
DODIAG      EQU 97

DOCODE:
; Contract: in IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
DOBEGIN:
            XOR  A
            LD   (DOMAPPTR),A
            LD   (DOMAPPTR+1),A
            INC  A
            LD   (DOACTIVE),A
            LD   HL,DOBUF
            LD   DE,DOBUF+1
            LD   BC,DOIMGCAP-1
            XOR  A
            LD   (HL),A
            LDIR
            RET

; A is the byte, C the flat bank, and HL its logical target address.
; Contract: in A,C,HL out A,carry,zero clobbers sign,parity,halfCarry,DE
DOIMGBYT:
DOPATBYT:
            PUSH HL
            PUSH AF
            LD   A,C
            OR   A
            JR   NZ,DOBYTBAD
            CALL DOBYTE
            JR   C,DOBYTBAD
            POP  AF
            LD   (HL),A
            POP  HL
            XOR  A
            RET
DOBYTBAD:
            POP  AF
            POP  HL
            JP   DOINVAL

; C is the bank, DE the logical target address, and HL the replacement word.
; Contract: in C,DE,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
DOPATWRD:
            LD   A,C
            OR   A
            JP   NZ,DOINVAL
            LD   (DOPATADR),DE
            LD   (DOPATVAL),HL
            LD   HL,(DOPATADR)
            CALL DOWORD
            RET  C
            LD   D,H
            LD   E,L
            LD   HL,(DOPATVAL)
            LD   A,L
            LD   (DE),A
            INC  DE
            LD   A,H
            LD   (DE),A
            XOR  A
            RET

; The provider receives a physical destination in HL after the complete
; logical range has been validated. These two entries also reject the only
; invalid flat-bank ordinal before converting it into a catalogue operation.
; Contract: in A,BC,DE,HL,IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
DORTIMG:
            OR   A
            JP   NZ,DOINVAL
            XOR  A
            JR   DORT
; Contract: in A,BC,DE,HL,IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
DORTINIT:
            OR   A
            JP   NZ,DOINVAL
            LD   A,1
DORT:
            LD   (DORTOPER),A
            LD   (DORTLEN),BC
            LD   (DORTID),DE
            LD   (DORTCTX),IX
            CALL DORANGET
            RET  C
            LD   A,(DORTOPER)
            LD   BC,(DORTLEN)
            LD   DE,(DORTID)
            LD   IX,(DORTCTX)
            JP   CRPROVID

; Contract: in IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
DOMAP:
            LD   A,(IX+31)
            DEC  A
            JP   NZ,DOINVAL
            LD   (DOMAPPTR),IX
            XOR  A
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
DOCOMMIT:
            LD   IX,(DOMAPPTR)
            LD   A,IXH
            OR   IXL
            JP   Z,DOINVAL
            LD   L,(IX+32)
            LD   H,(IX+33)
            LD   DE,DOIMG
            OR   A
            SBC  HL,DE
            JP   C,DOINVAL
            LD   A,H
            OR   L
            JP   Z,DOINVAL
            LD   DE,DOIMGCAP
            PUSH HL
            OR   A
            SBC  HL,DE
            POP  HL
            JP   C,DOLENOK
            JP   NZ,DOINVAL
DOLENOK:
            LD   (DOUSED),HL
            CALL PBPUBL
            RET  C
            XOR  A
            LD   (DOACTIVE),A
            RET

; Contract: out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
DOABORT:
            XOR  A
            LD   (DOACTIVE),A
            LD   (DOMAPPTR),A
            LD   (DOMAPPTR+1),A
            JP   PBABORT

; Translate one logical target byte in HL to its physical private-image byte.
; Contract: in HL out A,HL,carry,zero clobbers sign,parity,halfCarry,DE
DOBYTE:
            PUSH HL
            LD   DE,DOIMG
            OR   A
            SBC  HL,DE
            JR   C,DOXFAIL
            LD   DE,DOIMGCAP
            OR   A
            SBC  HL,DE
            JR   NC,DOXFAIL
            POP  HL
            LD   DE,DOOFFSET
            ADD  HL,DE
            OR   A
            RET
DOXFAIL:
            POP  HL
            JP   DOINVAL

DOLASTLO    EQU (DOIMGEND-1)&$FF
DOLASTHI    EQU (DOIMGEND-1)/$100

; Contract: in HL out A,HL,carry,zero clobbers sign,parity,halfCarry,DE
DOWORD:
            LD   A,L
            CP   DOLASTLO
            JR   NZ,DOBYTE
            LD   A,H
            CP   DOLASTHI
            JP   Z,DOINVAL
            JR   DOBYTE

; BC is a nonempty length and HL the logical target start. Return the physical
; start only when the mathematical complete range lies inside the image.
; Contract: in BC,HL out A,HL,carry,zero clobbers sign,parity,halfCarry,DE
DORANGET:
            LD   A,B
            OR   C
            JP   Z,DOINVAL
            CALL DOBYTE
            RET  C
            LD   (DORANGE),HL
            ADD  HL,BC
            JR   C,DORNGERR
            LD   DE,DOBUFEND
            OR   A
            SBC  HL,DE
            JR   C,DOENDOK
            JR   NZ,DORNGERR
DOENDOK:
            LD   HL,(DORANGE)
            OR   A
            RET
DORNGERR:
            JP   DOINVAL

; Contract: out A,carry,zero clobbers sign,parity,halfCarry
DOINVAL:
            LD   A,DODIAG
            SCF
            RET
DOCODEND:
