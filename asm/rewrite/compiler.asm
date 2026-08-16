; R1 replacement compiler shell. The public entry scans the complete source and
; deliberately reports an internal-operation diagnostic because target
; generation is introduced only after the front end and transcript are proven.

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
RewriteReset:
            XOR  A
            LD   HL,RewriteStateBase
            LD   (HL),A
            LD   DE,RewriteStateBase+1
            LD   BC,CompilerAbortSp-RewriteStateBase-1
            LDIR
            RET

.routine noreturn
RewriteRaiseDiagnostic:
            LD   (DiagnosticCode),A
            LD   A,(SourcePartId)
            LD   (DiagnosticPartId),A
            LD   HL,TokenStartOffset
            LD   DE,DiagnosticOffset
            LD   BC,2
            LDIR
            LD   SP,(CompilerAbortSp)
            SCF
            RET

; Host API 1 entry: A is a bounded part count, HL addresses five-byte source
; descriptors, and IX addresses the stable target descriptor. R1 validates the
; complete lexical stream but does not begin target output.
.routine in A,HL,IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CompileTargetAggregateCallParts:
            LD   (CompilerAbortSp),SP
            PUSH AF
            PUSH HL
            CALL RewriteReset
            POP  HL
            POP  AF
            CALL RewriteSourceInitializeParts
RewriteCompileTokenLoop:
            CALL RewriteTokenizerNext
            CP   TokenEof
            JR   NZ,RewriteCompileTokenLoop
            LD   A,DiagnosticInternalOperation
            JP   RewriteRaiseDiagnostic
