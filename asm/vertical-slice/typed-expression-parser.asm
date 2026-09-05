; Keep expression reduction, declaration parsing, then structured control
; in their historical emitted order. Each physical source part fits ATOM.
%INCLUDE "typed-expression-core.asm"
%INCLUDE "typed-declaration-parser.asm"
%INCLUDE "structured-control-parser.asm"
