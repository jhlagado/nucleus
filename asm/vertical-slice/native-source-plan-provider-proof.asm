            .include "platform-services-abi.asmi"

SourcePartCapacity     .equ 8
NativeSourceChunkBase  .equ $7500
NativeSourceChunkLimit .equ $7800
ObjectNodeGatewayPort  .equ $E1

            .org $0010
ObjectNodeGateway:
            OUT  (ObjectNodeGatewayPort),A
            RET

            .org $4000
ProofInitialize:
            JP   NativeSourceProviderLaunchBegin
ProofNext:
            JP   NativeSourceProviderNext
ProofFinish:
            JP   NativeSourceProviderLaunchEnd
ProofRetainName:
            JP   NativeSourceProviderRetainName
ProofCompareName:
            JP   NativeSourceProviderCompareName
ProofMaterializeName:
            JP   NativeSourceProviderMaterializeName
ProofReturnSentinel:
            HALT

            .org $4200
NativeSourceProviderCodeStart:
            .include "native-source-plan-provider.asm"
NativeSourceProviderCodeEnd:
