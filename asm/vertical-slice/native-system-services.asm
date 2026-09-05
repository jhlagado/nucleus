; MON3-compatible development dispatcher. Source and retained-name services
; and target-stream services are implemented by Z80 code. Named objects and
; runtime-catalogue chunks continue through the narrow platform provider.

SYSTATUS    EQU SPWKEND
SYSAVA      EQU SYSTATUS+1

; Contract: in A,C out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
SYDISPT:
            LD   (SYSAVA),A
            LD   A,C
            CP   NSCOMPF+0
            JR   Z,SYSOURCE
            CP   NSCOMPF+1
            JR   Z,SYRETAIN
            CP   NSCOMPF+2
            JR   Z,SYCMPNAM
            CP   NSCOMPF+3
            JR   Z,SYMATNAM
            CP   NSCOMPF+4
            JP   Z,SYBEGIN
            CP   NSCOMPF+5
            JP   Z,SYIMAGE
            CP   NSCOMPF+6
            JP   Z,SYRUNTIM
            CP   NSCOMPF+7
            JP   Z,SYRUNTIM
            CP   NSCOMPF+8
            JP   Z,SYPATCH
            CP   NSCOMPF+9
            JP   Z,SYPATWD
            CP   NSCOMPF+10
            JP   Z,SYMAP
            CP   NSCOMPF+11
            JP   Z,SYMAP
            CP   NSCOMPF+12
            JP   Z,SYCOMMIT
            CP   NSCOMPF+13
            JP   Z,SYABORT
            CP   NSCOMPF+14
            JP   Z,SYLAUNCH
            CP   NSCOMPF+15
            JP   Z,SYFINISH
SYEXTERN:
            LD   A,(SYSAVA)
            OUT  (HPMON3),A
            RET

SYSOURCE:
            LD   A,(SYSAVA)
            JP   SPNEXT

SYRETAIN:
            LD   A,(SYSAVA)
            LD   BC,(NHM3BC)
            JP   SPRETAIN

SYCMPNAM:
            LD   A,(SYSAVA)
            JP   SPCMPNAM

SYMATNAM:
            LD   A,(SYSAVA)
            JP   SPMATNAM

SYBEGIN:
            JP   NJBEGIN

SYIMAGE:
            LD   A,(SYSAVA)
            LD   BC,(NHM3BC)
            PUSH BC
            PUSH HL
            PUSH IX
            PUSH IY
            CALL NJIMAGE
            POP  IY
            POP  IX
            POP  HL
            POP  BC
            RET

SYRUNTIM:
            LD   A,(NHRTOP)
            LD   BC,(NHM3BC)
            CALL NJRUNTIM
            JR   C,SYRTFAIL
            XOR  A
SYRTSTAT:
            LD   (NHRTSTAT),A
            RET
SYRTFAIL:
            SCF
            JR   SYRTSTAT

SYPATCH:
            LD   A,(SYSAVA)
            LD   BC,(NHM3BC)
            PUSH BC
            PUSH HL
            PUSH IX
            PUSH IY
            CALL NJPATCH
            POP  IY
            POP  IX
            POP  HL
            POP  BC
            RET

SYPATWD:
            LD   BC,(NHM3BC)
            PUSH BC
            PUSH DE
            PUSH HL
            PUSH IX
            PUSH IY
            CALL NJPATWD
            POP  IY
            POP  IX
            POP  HL
            POP  DE
            POP  BC
            RET

SYMAP:
            JP   NJMAP

SYCOMMIT:
            PUSH BC
            PUSH DE
            PUSH HL
            PUSH IX
            PUSH IY
            CALL NJCOMMIT
            POP  IY
            POP  IX
            POP  HL
            POP  DE
            POP  BC
            RET

SYABORT:
            PUSH BC
            PUSH DE
            PUSH HL
            PUSH IX
            PUSH IY
            CALL NJABORT
            POP  IY
            POP  IX
            POP  HL
            POP  DE
            POP  BC
            RET

SYLAUNCH:
            LD   A,(SYSAVA)
            CALL SPBEGIN
            RET  C
            LD   C,NSCOMPF+14
            OUT  (HPMON3),A
            RET  NC
            LD   (SYSTATUS),A
            CALL SPEND
            LD   A,(SYSTATUS)
            SCF
            RET

SYFINISH:
            LD   A,(SYSAVA)
            LD   (SYSTATUS),A
            CALL SPEND
            RET  C
            LD   A,(SYSTATUS)
            LD   C,NSCOMPF+15
            OUT  (HPMON3),A
            RET

SYEND:
