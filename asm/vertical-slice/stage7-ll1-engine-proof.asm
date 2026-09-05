; Native proof of the production packed LL(1) engine and tables.
; Source/mock input and action aliases retain the frozen proof byte order.
%INCLUDE "memory-map.asmi"
%INCLUDE "loop-compiler-state.asmi"
%INCLUDE "aggregate-call-state.asmi"
%INCLUDE "stage7-ll1-proof-prelude.asm"
%INCLUDE "stage7-ll1-parser.asm"
%INCLUDE "stage7-ll1-proof-body.asm"
%INCLUDE "../../grammar/stage7-proof-actions.asmi"

LGSTATUS:     DB 0
LGCURSOR: DW 0
LGPEEKFL: DB 0
LGSP: DW 0
LGEND:
