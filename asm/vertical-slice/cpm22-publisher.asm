; Transactional CP/M publisher: preserve head, renderer, then tail byte order.
; These are import-once ATOM parts, not textual includes.
%INCLUDE "cpm22-publisher-head.asm"
%INCLUDE "cpm22-final-image.asm"

PBCODEND:

PBHZERO:    DS 16,0
