; Minimal direct-Z80 runtime and target-independent output service adapter.

.routine out carry,zero clobbers sign,parity,halfCarry,A,HL
Reset:
            XOR  A
            LD   (RTTRPNO),A
            LD   (RTTRPRTN),A
            LD   (RTTRPERR),A
            LD   (VOUTLEN),A
            LD   (ServiceOutputByte),A
            LD   HL,0
            LD   (RTTRPOFF),HL
            LD   A,RUNREADY
            LD   (RUNSTATE),A
            OR   A
            RET

; Input A is the byte. Carry returns a recoverable failure, with A as its code.
.routine in A out A,carry,zero clobbers sign,parity,halfCarry,B
RTWRITE:
            LD   B,A
            LD   A,(ServiceForceFailure)
            OR   A
            JR   NZ,RTWRERR
            LD   A,B
            LD   (ServiceOutputByte),A
            LD   A,1
            LD   (VOUTLEN),A
            XOR  A
            RET
RTWRERR:
            LD   A,3
            SCF
            RET
