; Checked semantic-operation buffer for the counted-loop and array slices.

%IF AggregateCallSlices
%ELSE
; Contract: out carry,zero clobbers sign,parity,halfCarry,A,HL
TMRESET:
            LD   HL,SMPAYBAS
            LD   (SKCUR),HL
            XOR  A
            LD   (SKOPCNT),A
            LD   (SMBUFBAS),A
            RET
%ENDIF

; Expression-only gated entries fall through to the raw sinks when emission
; is enabled. Keeping each entry beside its sink removes an absolute tail jump
; without changing the raw sink ABI used by statement actions.
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TMEWORD:
            PUSH HL
            LD   A,L
            CALL TMEBYTE
            POP  HL
%IF TargetStreamingOutput
%ELSE
            RET  C
%ENDIF
            LD   A,H
; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TMEBYTE:
            LD   D,A
            LD   A,(EXEMITON)
            OR   A
            LD   A,D
            RET  Z
; Contract: in A out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
TMPUT:
            LD   B,A
            LD   HL,(SKCUR)
            LD   DE,SMBUFLIM
            OR   A
            SBC  HL,DE
            ADD  HL,DE
            JR   Z,TMPUTFUL
TMPUTOK:
            LD   A,B
            LD   (HL),A
            INC  HL
            LD   (SKCUR),HL
            OR   A
            RET
TMPUTFUL:
            CALL DGINLINE
            DB  DGSNKCAP

%IF TargetStreamingOutput
; Contract: in A,HL out A,HL,carry,zero clobbers sign,parity,halfCarry,B,DE
TMPUTHL:
            PUSH HL
            CALL TMPUT
            POP  HL
            RET
%ENDIF

; Contract: out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry,IX,IY
TMEOPER:
            LD   D,A
            LD   A,(EXEMITON)
            OR   A
            LD   A,D
            RET  Z
; Contract: in A out A,carry,zero clobbers sign,parity,halfCarry,B,DE,HL
TMOPER:
%IF TargetStreamingOutput
            LD   HL,SMBUFBAS
            INC  (HL)
            JR   Z,TMPUTFUL
            JR   TMPUT
%ELSE
            LD   B,A
            LD   A,(SKOPCNT)
            CP   255
            JR   Z,TMPUTFUL
            LD   A,B
            CALL TMPUT
%IF AggregateCallSlices
%IF TargetStreamingOutput
%ELSE
            RET  C
%ENDIF
%ELSE
            RET  C
%ENDIF
            LD   HL,SKOPCNT
            INC  (HL)
            XOR  A
            RET
%ENDIF

; Contract: out A,carry,zero clobbers sign,parity,halfCarry
TMFINISH:
%IF TargetStreamingOutput
            LD   A,(SMBUFBAS)
%ELSE
            LD   A,(SKOPCNT)
            LD   (SMBUFBAS),A
%ENDIF
            OR   A
            RET
