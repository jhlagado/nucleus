; Native ATOM composition. Build flags are immutable entry metadata.

; Source proof for the u8-local and counted-loop compiler slice.

%INCLUDE "memory-map.asmi"


%INCLUDE "loop-compiler-state.asmi"
%INCLUDE "early-loop-origin.asmi"
%INCLUDE "source-adapter.asm"
%INCLUDE "loop-tokenizer.asm"
%INCLUDE "loop-semantic-sink.asm"
%INCLUDE "loop-symbols.asm"

%INCLUDE "loop-parser.asm"
%INCLUDE "early-loop-immutable.asmi"
%INCLUDE "loop-keywords.asmi"
%INCLUDE "early-loop-cases.asm"
