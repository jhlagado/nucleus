; Shared Z80 client for named-object services ABI 1. This is host-tool code,
; outside the 16 KiB compiler core. Native development components share this
; request block because service calls are synchronous and never nest.

OCREQ       EQU $5A00

; Compatibility alias retained while existing clients move to the common
; names. Both labels in each pair denote the same assembled routine.
SPREQ       EQU OCREQ

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
OCRESET:
SPRESET:
            LD   HL,OCREQ
            LD   DE,OCREQ+1
            LD   BC,NORQSIZE-1
            XOR  A
            LD   (HL),A
            LDIR
            LD   A,NORQSIZE
            LD   (OCREQ+NOFSIZE),A
            LD   A,NOABI
            LD   (OCREQ+NOFABI),A
            RET

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
OCCALL:
SPCALL:
            LD   HL,OCREQ
            LD   C,NSOBJECT
            RST  $10
            RET

; A is openRead or beginWrite, HL is the name, and B is its byte length.
; Contract: in A,HL,B out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
OCOPEN:
SPOPEN:
            PUSH AF
            PUSH HL
            PUSH BC
            CALL OCRESET
            POP  BC
            POP  HL
            POP  AF
            LD   (OCREQ+NOFOPER),A
            LD   (OCREQ+NOFPTR),HL
            LD   A,B
            LD   (OCREQ+NOFLEN),A
            CALL OCCALL
            RET  C
            LD   HL,(OCREQ+NOFHAND)
            RET

; HL is the object handle, DE the destination, and BC the requested count.
; Contract: in HL,DE,BC out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
OCREAD:
SPREAD:
            PUSH HL
            PUSH DE
            PUSH BC
            CALL OCRESET
            POP  BC
            POP  DE
            POP  HL
            LD   A,NOREAD
            LD   (OCREQ+NOFOPER),A
            LD   (OCREQ+NOFHAND),HL
            LD   (OCREQ+NOFPTR),DE
            LD   (OCREQ+NOFLEN),BC
            CALL OCCALL
            RET  C
            LD   BC,(OCREQ+NOFRES)
            RET

; HL is the update handle, DE the source, and BC the exact write count.
; Contract: in HL,DE,BC out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
OCWRITE:
SPWRITE:
            PUSH HL
            PUSH DE
            PUSH BC
            CALL OCRESET
            POP  BC
            POP  DE
            POP  HL
            LD   A,NOWRITE
            LD   (OCREQ+NOFOPER),A
            LD   (OCREQ+NOFHAND),HL
            LD   (OCREQ+NOFPTR),DE
            LD   (OCREQ+NOFLEN),BC
            CALL OCCALL
            RET  C
            LD   HL,(OCREQ+NOFRES)
            LD   DE,(OCREQ+NOFLEN)
            OR   A
            SBC  HL,DE
            JP   NZ,OCINVAL
            RET

; HL is the object handle and DE is a 16-bit absolute offset.
; Contract: in HL,DE out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
OCSEEK:
SPSEEK:
            PUSH HL
            PUSH DE
            CALL OCRESET
            POP  DE
            POP  HL
            LD   A,NOSEEK
            LD   (OCREQ+NOFOPER),A
            LD   (OCREQ+NOFHAND),HL
            LD   (OCREQ+NOFOFF),DE
            JP   OCCALL

; HL is the object handle. Rewind is the sequential spool operation; it does
; not expose or require random positioning.
; Contract: in HL out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
OCREWIND:
            PUSH HL
            CALL OCRESET
            POP  HL
            LD   A,NOREWIND
            LD   (OCREQ+NOFOPER),A
            LD   (OCREQ+NOFHAND),HL
            JP   OCCALL

; A is close, commit, or abort and HL is the object handle.
; Contract: in A,HL out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
OCTERM:
SPTERM:
            PUSH AF
            PUSH HL
            CALL OCRESET
            POP  HL
            POP  AF
            LD   (OCREQ+NOFOPER),A
            LD   (OCREQ+NOFHAND),HL
            JP   OCCALL

; Contract: out A,carry,zero clobbers sign,parity,halfCarry
OCINVAL:
SPINVAL:
            LD   A,NSTATINV
            SCF
            RET
