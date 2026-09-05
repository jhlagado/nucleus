; Strict-link proof for the native Nucleus compiler inside the CP/M 2.2 TPA.
; Provider entries are inert because this proof establishes relocation and
; simultaneous memory extents only. Executable BDOS bindings are separate.

DebugHooks .equ 0
NativeStreamingSource .equ 1
            .include "cpm22-target-memory-map.asmi"
            .include "nucleus-runtime-identity.asmi"

            .org MMCORE
            .include "flat-target-compiler-image.asmi"

NHVECTOR .equ MMHOSTVC
            .org NHVECTOR
CpmHostVectorStart:
            .db "NH",0,1,8,14,0,0
.routine out A,C,DE,HL,carry,zero clobbers sign,parity,halfCarry,B
HVCHUNK:           JP CpmLayoutSourceNext
.routine in HL,B,C,DE out A,HL,carry,zero clobbers sign,parity,halfCarry
HVRETAIN:         JP CpmLayoutRetainName
.routine in HL,IX,B out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
HVCMPNAM:        JP CpmLayoutCompareName
.routine in HL out A,B,HL,carry,zero clobbers sign,parity,halfCarry
HVMATNAM:           JP CpmLayoutMaterializeName
.routine in IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
TSBEGIN:               JP CpmLayoutTargetBegin
.routine in A,C,HL out A,carry,zero clobbers sign,parity,halfCarry,DE
TSBYTE:           JP CpmLayoutImageByte
.routine in A,BC,DE,HL,IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
TSRTIMG:        JP CpmLayoutRuntimeImage
.routine in A,BC,DE,HL,IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
TSRTINIT: JP CpmLayoutRuntimeImage
.routine in A,C,HL out A,carry,zero clobbers sign,parity,halfCarry,DE
TSPATBYT:           JP CpmLayoutPatchByte
.routine in C,DE,HL out A,carry,zero clobbers sign,parity,halfCarry
TSPATWRD:           JP CpmLayoutPatchWord
.routine in IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
TSMAP:             JP CpmLayoutMap
.routine in IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
TSBANK:           JP CpmLayoutMap
.routine out A,carry,zero clobbers sign,parity,halfCarry
TSCOMMIT:              JP CpmLayoutCommit
.routine out A,carry,zero clobbers sign,parity,halfCarry
TSABORT:               JP CpmLayoutAbort
CpmHostVectorTableEnd:

            .include "native-source-host.asm"
CpmHostVectorEnd:

.routine out A,C,DE,HL,carry,zero clobbers sign,parity,halfCarry,B
CpmLayoutSourceNext:
            XOR  A
            RET
.routine in HL,B,C,DE out A,HL,carry,zero clobbers sign,parity,halfCarry
CpmLayoutRetainName:
            XOR  A
            RET
.routine in HL,IX,B out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CpmLayoutCompareName:
            XOR  A
            RET
.routine in HL out A,B,HL,carry,zero clobbers sign,parity,halfCarry
CpmLayoutMaterializeName:
            XOR  A
            RET
.routine in IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CpmLayoutTargetBegin:
            XOR  A
            RET
.routine in A,C,HL out A,carry,zero clobbers sign,parity,halfCarry,DE
CpmLayoutImageByte:
CpmLayoutPatchByte:
            XOR  A
            RET
.routine in C,DE,HL out A,carry,zero clobbers sign,parity,halfCarry
CpmLayoutPatchWord:
            XOR  A
            RET
.routine in A,BC,DE,HL,IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CpmLayoutRuntimeImage:
            XOR  A
            RET
.routine in IX out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
CpmLayoutMap:
            XOR  A
            RET
.routine out A,carry,zero clobbers sign,parity,halfCarry
CpmLayoutCommit:
CpmLayoutAbort:
            XOR  A
            RET
CpmLayoutResidentEnd:

            .end
