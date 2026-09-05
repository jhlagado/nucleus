# Native ATOM runtime conversion

2026-09-05. Baseline `7260a06` on `atom-source-native`. This is stage 2 of the
[source migration](../plans/atom-native-source.md). The compiler families and
their legacy proof composition remain to be converted.

## Source and build boundary

The canonical runtime body and ABI identity source now use native ATOM
directives, readable short symbols, and comment-based register/flag contracts.
The explicit 171-name map in `asm/atom-runtime-symbols.json` preserves existing
host-facing names in output dictionaries. It does not transform native source.
Shared assembly references were renamed in the same change.

`assembleNativeSource` calls ATOM's public project resolver and assembler. Its
remaining responsibilities are sparse Intel HEX output, required exports, and
output-name collision checks. It rejects ambiguous flat local-label exports.
ATOM supplies source diagnostics, dependency ordering, preprocessing, symbol
resolution and source/output capacity enforcement.

Catalog generation and development runtime linking both call
`assembleNativeRuntime`. This helper emits native context declarations from
validated numeric inputs, copies the two canonical assembly files verbatim to
a temporary project, and supplies immutable configuration to ATOM. Ordered
dependencies place the context and origin before the runtime body. The helper
removes its temporary directory after success or failure.

The installed runtime provider still uses the bundled catalog. Installed
program execution does not acquire an assembler dependency. The old generated
runtime override path and duplicated context-string generators were removed.

Remaining compiler/proof callers still use the legacy adapter. That adapter
now accepts the shared body's native include and conditional spellings, and
restores the migrated names in output dictionaries. This transitional support
keeps one authoritative runtime body while the other source families migrate.
It is not completion of the adapter-removal stage.

## Verification

- The combined source gate passes 36 tests: 15 existing adapter tests, 13 direct
  ATOM boundary tests, and eight native runtime tests.
- All six catalog profiles retain exact bytes, sparse write coverage, runtime
  identity, helper offsets, vector length and state layout. Each runtime is
  732 bytes; no target instruction sequence or storage requirement changed.
- A runtime beginning at `$FD24` ends physically at 65,536 with end-label value
  zero. Moving it one byte higher fails. Numeric context fields reject negative,
  oversized, fractional and non-finite values.
- Seven development runtime-link tests pass, including deep equality against
  all six bundled runtime images and invalid-placement rejection.
- The combined service-provider and runtime-link run passes all 41 tests.
- Type checking passes.
- The native compiler comparison retains all 2,464 symbols, all emitted bytes
  and all sparse write ranges. ATOM used 592,011,386 assembly instructions for
  this check; this is assembler execution, not compiled-program performance.

An independent reviewer reversed the explicit rename map and normalized only
directive spelling and routine annotations across all 33 changed assembly
files. Every ordered code line matched the baseline. No opcode, operand,
expression or ordering change was found. The reviewer also checked output-only
name restoration and the absence of renamed local-label anchors.

A second independent reviewer checked the host boundary, including cleanup
after source-copy and assembly failures, sparse patches, invalid inputs and
the installed import graph. The review found inconsistent end-label arithmetic
in catalog generation for a future top-fitting profile. Catalog generation
now uses the physical high-water value and separately checks the wrapped label,
as the development loader already did.

The complete generated-image check passed for all six compiler variants, all
six runtimes, the Node runner, import resolver and CP/M embedded assets. A fresh
run after the endpoint consistency correction also passed. The broader
manifest-driven proof run at this runtime checkpoint passed 23 cases and hit
one five-second host deadline while other assembly jobs were running. That
tokenizer trace passed in isolation in 2.154 seconds with unchanged assertions
and guest limits. This is a timeout plus a successful isolated rerun, not a
claim of one completely green combined run. Full release/package qualification,
Linux CI and downstream publication remain pending. No release, Triptych input
pin or user disk was changed by this stage.

## Separate CP/M repair

The parameter-name repair was developed on `cpm-parameter-recovery`, separately
from the byte-preserving source conversion. Candidate commit `8f8dd7b` follows
failing regression commits `858fa0e` and `ef2e073`. It is not part of this
runtime conversion's byte-equality claim.

The lead replayed the candidate in the existing Triptych WASM system with a
private copy of the pinned disk. Scalar-parameter and array-parameter loop
programs both compiled, printed `A`, returned to the prompt and accepted `DIR`.
The ordinary counted-loop example printed `ABC`. A separate worker verified
invalid-source recovery, preservation of the old output, and successful next
compilation in the same real-OS session.

The private candidate is 21,271 bytes, SHA-256
`1c047ac1ed5ff1c4e914321b66476b842a1b28cc0dfef4cfdb86f691ca037334`.
The pinned disk remains SHA-256
`90afb240503a95b14620a9f829c8c9a63a4ba78798e4327bc16313639454a710`.
These are software-model proofs, not ESP32 measurements. The repair's separate
report records its code, timing and peak-stack changes; publication requires
integration and fresh artifact qualification.
