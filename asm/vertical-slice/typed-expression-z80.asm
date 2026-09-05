; Native ATOM composition preserves the backend's emitted byte order.
; Includes are dependencies: each complete part precedes this wrapper.
%INCLUDE "typed-expression-z80-body.asm"
%INCLUDE "structured-control-z80.asm"
%IF AggregateCallSlices
%INCLUDE "aggregate-call-z80.asm"
%ENDIF
%INCLUDE "typed-expression-z80-templates.asmi"
%INCLUDE "structured-control-aliases.asmi"
%IF AggregateCallSlices
%INCLUDE "aggregate-call-aliases.asmi"
%ENDIF
