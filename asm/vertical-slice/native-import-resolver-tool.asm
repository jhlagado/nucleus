; Shipping standalone Z80 import resolver. A shell passes the entry object name
; in HL/B, calls NativeImportResolve, and then selects the compiler tool bank.

%INCLUDE "platform-services-abi.asmi"
%INCLUDE "native-import-resolver-layout.asmi"
%INCLUDE "native-object-client.asm"
%INCLUDE "native-source-plan-provider.asm"
%INCLUDE "native-import-resolver.asm"

IRCODEND:
