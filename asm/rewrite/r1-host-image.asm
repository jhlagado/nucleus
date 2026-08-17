; Test-only R1 replacement image at a representative deployment origin.

CompilerWorkBase   .equ $6000
SourceBase         .equ $5000
SourceLimit        .equ $5800
RewriteAdapterBase .equ $D000
RewriteAdapterLimit .equ $D100
DebugHooks          .equ 0

            .org $8000
            .include "compiler-image.asmi"
