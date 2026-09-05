; Native ATOM composition. Build flags are immutable entry metadata.

; Compile and execute the first Nucleus source program as direct Z80 code.

%INCLUDE "memory-map.asmi"
%INCLUDE "compiler-state.asmi"


%INCLUDE "z80-state.asmi"
%INCLUDE "early-z80-origin.asmi"
%INCLUDE "source-adapter.asm"
%INCLUDE "tokenizer.asm"
%INCLUDE "semantic-sink.asm"
%INCLUDE "parser.asm"
%INCLUDE "early-z80-sink-boundary.asmi"
%INCLUDE "z80-sink.asm"
%INCLUDE "early-z80-cases.asm"
%INCLUDE "z80-runtime.asm"
%INCLUDE "early-z80-driver.asm"
