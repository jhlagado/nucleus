; Shared Z80 client for named-object services ABI 1. This is host-tool code,
; outside the 16 KiB compiler core. Native development components share this
; request block because service calls are synchronous and never nest.

NativeObjectRequest .equ $5A00

; Compatibility alias retained while existing clients move to the common
; names. Both labels in each pair denote the same assembled routine.
NativeSourceProviderRequest .equ NativeObjectRequest

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
NativeObjectResetRequest:
NativeSourceProviderResetRequest:
            LD   HL,NativeObjectRequest
            LD   DE,NativeObjectRequest+1
            LD   BC,NucleusObjectRequestSize-1
            XOR  A
            LD   (HL),A
            LDIR
            LD   A,NucleusObjectRequestSize
            LD   (NativeObjectRequest+NucleusObjectRequestSizeField),A
            LD   A,NucleusObjectAbiVersion
            LD   (NativeObjectRequest+NucleusObjectRequestAbi),A
            RET

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
NativeObjectCall:
NativeSourceProviderCallObject:
            LD   HL,NativeObjectRequest
            LD   C,NucleusServiceObject
            RST  $10
            RET

; A is openRead or beginWrite, HL is the name, and B is its byte length.
.routine in A,HL,B out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
NativeObjectOpen:
NativeSourceProviderOpen:
            PUSH AF
            PUSH HL
            PUSH BC
            CALL NativeObjectResetRequest
            POP  BC
            POP  HL
            POP  AF
            LD   (NativeObjectRequest+NucleusObjectRequestOperation),A
            LD   (NativeObjectRequest+NucleusObjectRequestPointer),HL
            LD   A,B
            LD   (NativeObjectRequest+NucleusObjectRequestLength),A
            CALL NativeObjectCall
            RET  C
            LD   HL,(NativeObjectRequest+NucleusObjectRequestHandle)
            RET

; HL is the object handle, DE the destination, and BC the requested count.
.routine in HL,DE,BC out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
NativeObjectRead:
NativeSourceProviderRead:
            PUSH HL
            PUSH DE
            PUSH BC
            CALL NativeObjectResetRequest
            POP  BC
            POP  DE
            POP  HL
            LD   A,NucleusObjectRead
            LD   (NativeObjectRequest+NucleusObjectRequestOperation),A
            LD   (NativeObjectRequest+NucleusObjectRequestHandle),HL
            LD   (NativeObjectRequest+NucleusObjectRequestPointer),DE
            LD   (NativeObjectRequest+NucleusObjectRequestLength),BC
            CALL NativeObjectCall
            RET  C
            LD   BC,(NativeObjectRequest+NucleusObjectRequestResult)
            RET

; HL is the update handle, DE the source, and BC the exact write count.
.routine in HL,DE,BC out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
NativeObjectWrite:
NativeSourceProviderWrite:
            PUSH HL
            PUSH DE
            PUSH BC
            CALL NativeObjectResetRequest
            POP  BC
            POP  DE
            POP  HL
            LD   A,NucleusObjectWrite
            LD   (NativeObjectRequest+NucleusObjectRequestOperation),A
            LD   (NativeObjectRequest+NucleusObjectRequestHandle),HL
            LD   (NativeObjectRequest+NucleusObjectRequestPointer),DE
            LD   (NativeObjectRequest+NucleusObjectRequestLength),BC
            CALL NativeObjectCall
            RET  C
            LD   HL,(NativeObjectRequest+NucleusObjectRequestResult)
            LD   DE,(NativeObjectRequest+NucleusObjectRequestLength)
            OR   A
            SBC  HL,DE
            JP   NZ,NativeObjectInvalid
            RET

; HL is the object handle and DE is a 16-bit absolute offset.
.routine in HL,DE out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
NativeObjectSeek:
NativeSourceProviderSeek:
            PUSH HL
            PUSH DE
            CALL NativeObjectResetRequest
            POP  DE
            POP  HL
            LD   A,NucleusObjectSeek
            LD   (NativeObjectRequest+NucleusObjectRequestOperation),A
            LD   (NativeObjectRequest+NucleusObjectRequestHandle),HL
            LD   (NativeObjectRequest+NucleusObjectRequestOffset),DE
            JP   NativeObjectCall

; HL is the object handle. Rewind is the sequential spool operation; it does
; not expose or require random positioning.
.routine in HL out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
NativeObjectRewind:
            PUSH HL
            CALL NativeObjectResetRequest
            POP  HL
            LD   A,NucleusObjectRewind
            LD   (NativeObjectRequest+NucleusObjectRequestOperation),A
            LD   (NativeObjectRequest+NucleusObjectRequestHandle),HL
            JP   NativeObjectCall

; A is close, commit, or abort and HL is the object handle.
.routine in A,HL out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
NativeObjectTerminal:
NativeSourceProviderTerminal:
            PUSH AF
            PUSH HL
            CALL NativeObjectResetRequest
            POP  HL
            POP  AF
            LD   (NativeObjectRequest+NucleusObjectRequestOperation),A
            LD   (NativeObjectRequest+NucleusObjectRequestHandle),HL
            JP   NativeObjectCall

.routine out A,carry,zero clobbers sign,parity,halfCarry
NativeObjectInvalid:
NativeSourceProviderInvalid:
            LD   A,NSTATINV
            SCF
            RET
