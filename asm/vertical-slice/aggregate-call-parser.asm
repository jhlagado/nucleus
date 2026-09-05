; Preserve call-parser body, packed engine/tables, then action handlers.
%INCLUDE "aggregate-call-parser-body.asm"
%IF Stage7LL1
%INCLUDE "stage7-ll1-parser.asm"
%INCLUDE "stage7-ll1-actions.asm"
%ENDIF
