; Host API proof adapter for the replacement compiler. This code is outside the
; compiler-core account. It captures the same append-only IMAGE/PATCH records
; consumed by the existing Host API NOBJ transaction.

; Reserve A bytes atomically and return their first address in IY.
.routine in A out A,IY,carry,zero clobbers sign,parity,halfCarry,D,DE,HL
RewriteTargetAdapterReserve:
            LD   E,A
            LD   A,(AdapterFailureCountdown)
            OR   A
            JR   Z,RewriteTargetAdapterReserveCapacity
            DEC  A
            LD   (AdapterFailureCountdown),A
            JR   NZ,RewriteTargetAdapterReserveCapacity
            LD   A,DiagnosticTargetOutput
            SCF
            RET
RewriteTargetAdapterReserveCapacity:
            LD   A,E
            LD   D,0
            LD   IY,(AdapterCursor)
            PUSH IY
            POP  HL
            ADD  HL,DE
            LD   DE,AdapterLogLimit
            OR   A
            SBC  HL,DE
            JR   C,RewriteTargetAdapterReserveReady
            JR   Z,RewriteTargetAdapterReserveReady
            LD   A,DiagnosticTargetOutput
            SCF
            RET
RewriteTargetAdapterReserveReady:
            ADD  HL,DE
            LD   (AdapterCursor),HL
            OR   A
            RET

.routine in IX out A,carry,zero clobbers sign,parity,halfCarry
RewriteTargetSinkBegin:
            LD   A,(AdapterOpen)
            OR   A
            JP   NZ,RewriteTargetSinkFailure
            INC  A
            LD   (AdapterOpen),A
            OR   A
            RET

.routine in A,C,HL out A,carry,zero clobbers sign,parity,halfCarry,DE,IY
RewriteTargetSinkImageByte:
            PUSH AF
            PUSH BC
            PUSH HL
            LD   A,7
            CALL RewriteTargetAdapterReserve
            JR   C,RewriteTargetSinkImageReserveFailure
            POP  HL
            POP  BC
            POP  AF
            LD   (IY+0),1
            LD   (IY+1),C
            LD   (IY+2),L
            LD   (IY+3),H
            LD   (IY+4),1
            LD   (IY+5),0
            LD   (IY+6),A
            OR   A
            RET
RewriteTargetSinkImageReserveFailure:
            LD   E,A
            POP  HL
            POP  BC
            POP  AF
            LD   A,E
            SCF
            RET

.routine in C,DE,HL out A,carry,zero clobbers sign,parity,halfCarry,IY
RewriteTargetSinkPatchWord:
            PUSH BC
            PUSH DE
            PUSH HL
            LD   A,8
            CALL RewriteTargetAdapterReserve
            POP  HL
            POP  DE
            POP  BC
            RET  C
            LD   (IY+0),2
            LD   (IY+1),C
            LD   (IY+2),E
            LD   (IY+3),D
            LD   (IY+4),2
            LD   (IY+5),0
            LD   (IY+6),L
            LD   (IY+7),H
            OR   A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry
RewriteTargetSinkCommit:
            LD   A,(AdapterCommitFailure)
            OR   A
            JR   NZ,RewriteTargetSinkFailure
            LD   A,(AdapterOpen)
            OR   A
            JR   Z,RewriteTargetSinkFailure
            XOR  A
            LD   (AdapterOpen),A
            INC  A
            LD   (AdapterCommitted),A
            OR   A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry
RewriteTargetSinkAbort:
            XOR  A
            LD   (AdapterOpen),A
            LD   A,(AdapterAborted)
            INC  A
            LD   (AdapterAborted),A
            OR   A
            RET

RewriteTargetSinkFailure:
            LD   A,DiagnosticTargetOutput
            SCF
            RET
