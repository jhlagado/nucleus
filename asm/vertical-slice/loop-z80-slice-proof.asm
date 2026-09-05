; Native ATOM composition. Build flags are immutable entry metadata.

; Compile and execute the counted-loop source as direct Z80 code.

%INCLUDE "memory-map.asmi"


%INCLUDE "loop-compiler-state.asmi"
%INCLUDE "loop-z80-state.asmi"
%INCLUDE "early-loop-z80-origin.asmi"
%INCLUDE "source-adapter.asm"
%INCLUDE "loop-tokenizer.asm"
%INCLUDE "loop-semantic-sink.asm"
%INCLUDE "loop-symbols.asm"

%INCLUDE "loop-parser.asm"
%INCLUDE "early-loop-z80-sink-boundary.asmi"
%INCLUDE "loop-z80-sink.asm"
%INCLUDE "early-loop-z80-immutable.asmi"
%INCLUDE "loop-keywords.asmi"
%INCLUDE "early-loop-z80-cases.asm"
%INCLUDE "proof-z80-runtime.asm"
%INCLUDE "early-loop-z80-driver.asm"
