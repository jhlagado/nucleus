# Native ATOM source closure

Date: 2026-09-05. Comparison baseline:
`1cb0331e0802e4faca1d93621a498d62fa670b1e`, captured from a separate pristine
worktree before this conversion. Development remains on `atom-source-native`.

## Result

The production Node/NOBJ runner and the remaining historical compiler proofs
now assemble through ATOM's native project resolver. The image generator and
manifest proof runner have explicit native entry routes; unknown entries fail.
The source translator and its obsolete composition files are removed.

The previous production compiler conversion remains intact. This change keeps
the emitted instructions, source corpora, public symbol values, address
classifications and sparse writes of all 27 newly converted entry profiles.
The output maps contain 1,644 additional readable short-name bindings: 143
early-proof names, 454 middle-proof names, 727 stage-proof names and 320 NOBJ
names. Shared names have one mapping. The full 20-map collection has 5,542
unique public names and native names.

## Source and output boundaries

Each entry imports its actual source dependencies in the original byte order.
Named parts separate origins, code, state, source corpora, runtime and proof
drivers. Historical proofs retain their historical state layouts; they do not
import the larger production state as a substitute. The common helper supplies
immutable build choices. Preprocessor-only defaults do not add public symbols
that were absent from the original profile.

ATOM resolves source-authored late EQUs for four middle-proof offsets and
seventeen stage-proof offsets. The private names remain in ATOM's generation;
explicit filters remove them only from the public dictionary. Every filter
rejects address-classified entries. No numeric address snapshot or automatic
input rewriting replaces those expressions.

The NOBJ runner proof has two separate metadata cases. `LPLOGLEN` is a late EQU
for the adapter-log length and is omitted only from public output.
`LPMEMEND EQU $FFFF` represents the last address; the helper restores the
host-only `ProofMemoryEnd` to 65,536 after checking the raw EQU and its class.
The control-top consumer's real zero sentinel remains zero in executable
code and metadata.

## Removed files

The following files were tracked and unchanged at the comparison baseline.
Only their owned contents were removed; the pristine worktree and Git history
retain them for comparison and recovery.

| File | Baseline lines removed | Replacement |
| --- | ---: | --- |
| `scripts/atom-source.mjs` | 1–264 | Native source helpers and explicit output maps |
| `scripts/atom-source-translation.mjs` | 1–700 | Checked-in ATOM syntax and native project resolution |
| `scripts/atom-source.d.mts` | 1–11 | Native helper declarations |
| `scripts/atom-source.test.mjs` | 1–113 | Native boundary tests; two image-comparison checks retained separately |
| `scripts/fixtures/atom-placement.asm` | 1–6 | Historical AZM placement characterization retired |
| `asm/vertical-slice/compiler-profile-legacy.asmi` | 1–33 | Immutable native profile tables |
| `asm/vertical-slice/nucleus-target-runtime-link.asm` | 1–9 | Existing native runtime composition |
| `asm/vertical-slice/nucleus-runtime-link-context.asmi` | 1–45 | Existing native context generation |
| `asm/vertical-slice/target-z80-runtime.asm` | 1–7 | Existing native runtime composition |

Historical reports retain their original descriptions of those files.
The normal source gate checks their absence, supported assembly directives,
short global and scoped local declarations, source-part size, output-map
collisions, coverage of every executable proof manifest and prohibited imports.
Deletion-safe test hooks reject legacy module imports before module resolution.

## Verification

Four parallel source groups used frozen pre-conversion results. Tests compare
every sparse HEX record, full public dictionary and address-only dictionary.
Canonical-source checks compare the bytes ATOM reads with the actual files;
official preprocessing may blank directives and inactive text only.

| Group | Exact entry comparisons | Additional evidence |
| --- | ---: | --- |
| Early compiler, dispatch and CP/M layout | 9 | Native declarations, source provenance and unknown-entry rejection |
| Middle compiler proofs | 6 | Four raw derived offsets and ordinary call-proof execution with legacy imports blocked |
| Stage 7–9 proofs | 4 | Original proof execution, success status and restored stack; ordinary coverage route with legacy imports blocked |
| Node runner and NOBJ/service proofs | 8 | Full-width end, zero sentinel, raw log length and production runner with legacy imports blocked |

The integrated early/NOBJ behavior run passed 77 tests across six files. The
packaged-image host subset passed 150 tests across 23 files. These are separate
checks, not a claim that the full repository conformance suite has passed.
Middle qualification passed eight tests; stage qualification passed six.

The isolated stage coverage subprocess took 63 seconds on this host, exceeding
its initial 60-second timeout. Its host timeout is now 180 seconds. No guest
instruction, cycle, memory or expected-result limit changed.

Three source authors cross-reviewed disjoint changes. Two fresh independent
reviewers found no actionable defects. Their checks covered native routing,
retirement, output metadata and source equivalence. One independently compared
all 19 historical compositions with the pristine baseline; both inspected the
NOBJ compositions and shared leaves. They ran the inexpensive boundary tests,
but did not repeat the full assembly matrices. The assembly and execution
results above are separate from their reviews.

Production-image regeneration passed after translator removal. All six
compiler image exports, runtime catalog, import resolver and CP/M embedded
assets remain text-identical to `1cb0331`. Only the Node runner's dictionary
ordering changed; comparison of its complete symbol values, bytes and sparse
write coverage passed. The normal native-source suite passed all 63 tests.
The subsequent regeneration check passed. A final six-file rerun of native
NOBJ, host bindings, tokenizer, grammar, resolver and diagnostic checks passed
all 90 tests with the translator files absent.

The TypeScript distribution build, runtime-boundary check and isolated installed
package consumer passed. The consumer imported all public exports, compiled and
ran programs through the API and CLI, and preserved the previous object after
a failed build, with no assembler installed. This package check used the
unchanged released CP/M binary; it does not qualify a replacement `NUC.COM`.
Three rebuilt distribution image files also changed dictionary order only;
their complete values, bytes and sparse write coverage match the baseline.

All 15 selected historical cases in the existing manifest-driven proof suite
passed, including their original instruction, cycle, extent and behavioral
assertions. Nine unchanged production-target cases were excluded from that
invocation. The full compiler relocation check passed at its four existing
origins, including the top-fitting image, with the legacy files absent.

## Remaining release work

The released version remains 0.3.0. Its `NUC.COM` is 21,281 bytes; the previously
repaired source produces 21,271 bytes. This known difference predates this
conversion and has not been approved by changing the release baseline.
The release gate, complete repository conformance, clean Linux CI,
publication, Triptych's immutable pin and hosted verification remain open.
No ESP32 hardware result is claimed.
