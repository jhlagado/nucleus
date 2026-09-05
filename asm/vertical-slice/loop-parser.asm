; Native frontend order is also a control-flow contract: loop-symbols falls
; through into DGSET, the first byte of compiler-diagnostics.asm.
; The entry composition supplies immutable compiler-profile definitions.
%INCLUDE "compiler-diagnostics.asm"
%INCLUDE "loop-parser-body.asm"
%INCLUDE "typed-expression-parser.asm"
%INCLUDE "aggregate-parser.asm"
%IF AggregateCallSlices
%INCLUDE "aggregate-call-parser.asm"
%ENDIF
