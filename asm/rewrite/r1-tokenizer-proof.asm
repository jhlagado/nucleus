; Execute the R1 tokenizer over a multipart corpus and retain every fixed token
; record for host inspection. Source bytes and expected results belong to the
; proof account, not the replacement compiler core.

CompilerWorkBase    .equ $6000
SourceBase          .equ $5000
SourceLimit         .equ $5800
RewriteAdapterBase  .equ $A000
RewriteAdapterLimit .equ $A100
DebugHooks           .equ 0

            .org $1000
ProofStart:
            LD   SP,$FF00
            LD   HL,ProofDiagnostic
            PUSH HL
            LD   (CompilerAbortSp),SP
            CALL RewriteReset
            LD   A,3
            LD   HL,ProofParts
            CALL RewriteSourceInitializeParts
            LD   HL,ProofTokenBuffer
            LD   (ProofTokenCursor),HL
            XOR  A
            LD   (ProofTokenCount),A
ProofTokenLoop:
            CALL RewriteTokenizerNext
            PUSH AF
            LD   (TokenKind),A
            LD   (TokenValue),BC
            LD   A,(SourcePartId)
            LD   (TokenPartId),A
            LD   HL,TokenKind
            LD   DE,(ProofTokenCursor)
            LD   BC,RewriteTokenRecordSize
            LDIR
            LD   (ProofTokenCursor),DE
            LD   HL,ProofTokenCount
            INC  (HL)
            POP  AF
            CP   TokenEof
            JR   NZ,ProofTokenLoop
            LD   A,$A5
            LD   (ProofStatus),A
            HALT
ProofDiagnostic:
            LD   A,$E1
            LD   (ProofStatus),A
            HALT

ProofTokenCursor:   .dw 0
ProofTokenCount:    .db 0
ProofStatus:        .db 0

            .org $4000
ProofPart1:
            .db "var as u8 u16 i8 i16 boolean true false const or xor mod "
            .db "assert and not fail end sub fails for until forward return if "
            .db "elseif else while to step exit continue record string handle "
            .db "variable i Print"
ProofPart1End:
ProofPart2:
            .db "name_1 = 65535'A', $fF, %1010 + - * / . < <= <> > >= 'A' "
            .db $27,"\\0",$27," ",$27,"\\n",$27," ",$27,"\\r",$27," "
            .db $27,"\\t",$27," ",$27,"\\",$27,$27," ",$27,"\\",$22,$27," "
            .db $27,"\\\\",$27," ",$27,"\\x41",$27," "
            .db $22,"a\\n\\x42\\",$22,$22
            .db " // ignored",13,10
ProofPart2End:
ProofPart3:
            .db "(",10,"1 +",10,"2",10,")",10,10,"// only",10,9,"last"
ProofPart3End:
ProofParts:
            .db 1
            .dw ProofPart1,ProofPart1End
            .db 2
            .dw ProofPart2,ProofPart2End
            .db 3
            .dw ProofPart3,ProofPart3End

            .org $7000
ProofTokenBuffer:
            .ds $0800
ProofTokenBufferEnd:

            .org $8000
            .include "compiler-image.asmi"
