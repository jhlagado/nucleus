# ATOM relocation qualification

2026-09-05. This is a checkpoint in the unpublished `reconcile-atom` worktree,
not a Nucleus release. The earlier reconciliation and separate root-checkout
compiler rewrite are preserved.

## Assembler input

The test uses the packed ATOM candidate from commit
`7692c2938a3d3fa08112988516d29aff6897a680`, published on
`jhlagado/atom` branch `range-and-bootstrap`. ATOM's guarded release check
passed all 366 tests. The package archive SHA-256 is
`65279e3b9e7c2059031c75b7de3da647dc7a1da89e87c3669adb83b110681c47`.

The package was installed offline at
`/tmp/atom-final-byte-pack.j8d9MQ/consumer`. A development-only Node import hook
selects it for the initial checks while another hook rejects AZM imports.
The reconciliation worktree's package declaration and lockfile now select the
published commit above. These edits remain unpublished; Triptych's dependency
pin is unchanged.

## Migration and proof

`test/compiler-relocation.test.ts` now uses `assembleAtomSource`. The temporary
AZM project and debug-map conversion have been removed. The shared helper
accepts target geometry and returns label addresses separately from equates,
using ATOM's debug-map classification.

The four origins are zero, `$0100`, `$8000`, and the highest origin at which
the complete compiler fits. The test preserves full-width label and dispatch
table comparisons, all 104 prefetch selectors, and diagnostic execution with
stack restoration at every origin. The highest image must end physically at
`$10000`; its end label is a wrapped 16-bit zero. Initialized HEX record ranges
must cover the image contiguously, with neither holes nor overlaps.

The first source-adapter regression failed against the old helper at final-byte
output. After migration, the old ATOM pin failed descriptor validation. The
first packed-candidate run assembled every image but failed an assertion that
incorrectly required the HEX parser to merge adjacent records. The corrected
assertion checks contiguous coverage across individual records. The focused
relocation test then passed in 186.14 seconds with AZM unavailable. The
wall-clock allowance is five minutes because ATOM itself runs under Z80
emulation; its instruction and cycle ceilings were not increased.

All 14 source-adapter tests and TypeScript checking passed. Logs:

- `/tmp/nucleus-atom-final-byte-source-tests.log`
- `/tmp/nucleus-atom-relocation-old-pin.log`
- `/tmp/nucleus-atom-relocation-packed-final.log`
- `/tmp/nucleus-atom-relocation-typecheck.log`

The obsolete `check:azm-toolchain` script and AZM development dependency were
removed. The script remains recoverable from Git. ATOM does not perform AZM's
static register-contract analysis; this migration does not claim that proof.
The installed Nucleus runtime continues to use prebuilt images rather than
assembling at application runtime.

## Output equivalence and fresh installation

The flat-output comparison failed at its 30-second wall-clock limit while
rebuilding its baseline through emulated ATOM. The focused log reports a
timeout, not an artifact mismatch. The three baseline-building comparisons now
allow 180 seconds each. Their exact NOBJ, Intel HEX and D8 assertions and the
proof manifests' guest instruction/cycle budgets are unchanged. All three
passed with the packed candidate: flat 58.003 seconds, banked 73.249 seconds,
and entry-bank-one 72.140 seconds. The log is
`/tmp/nucleus-equivalence-atom-wallclock.log`.

A separate source snapshot at `/private/tmp/nucleus-pinned-consumer.wmGpWy`
uses a fresh npm cache and the new Git pin. Its first installation used
`npm ci --ignore-scripts`, which omitted the runtime and tool-services compiled
JavaScript. Normal `npm ci` with a second empty cache prepared those files.
The normal installation resolves ATOM from its own `node_modules`, without the
development import override, and has no installed AZM package. All 14 adapter
tests, type checking and the installed-runtime boundary check pass there.
The generated-image check also passes there: all six compiler variants, six
runtime profiles, the runner, resolver and CP/M embedded assets rebuild through
ATOM and match their checked-in files exactly. The snapshot's assembly, source,
source adapter and lockfile matched the reconciliation worktree at that check.
The later CP-immediate adaptation is described below. The four-origin
relocation proof also passes in 240.874 seconds against the fresh installation.
All 36 tests in the compiler test file pass there in 227.89 seconds.

Fresh-install logs:

- `/tmp/nucleus-pinned-install.log` (scripts disabled; incomplete runtime)
- `/tmp/nucleus-pinned-install-prepared.log` (normal installation)
- `/tmp/nucleus-pinned-source-tests-prepared.log`
- `/tmp/nucleus-pinned-typecheck-prepared.log`
- `/tmp/nucleus-pinned-runtime-boundary.log`
- `/tmp/nucleus-pinned-generated-images-prepared.log`
- `/tmp/nucleus-pinned-relocation.log`
- `/tmp/nucleus-pinned-compiler-tests.log`

The CI workflow now installs the pinned dependencies and runs the adapter tests
before the existing full release gate. Its historical Debug80/AZM checkout,
build and link steps are removed. This workflow edit is local and has not
established a passing Linux run.

## Forward comparison operand

The broad manifest suite reported 16 failures among 24 proofs. A focused
aggregate-layout run failed at `aggregate-z80-slice-proof.asm:245`, where
`CP AggregateExpectedImageEnd-AggregateExpectedImage` precedes the two labels.
The adapter already scheduled forward multi-symbol expressions in data and
LD operands, but omitted CP immediates.

A small real-ATOM regression reproduced the statement rejection. The adapter
now emits a deferred symbolic EQU for that CP form; ATOM still resolves every
address and encodes the instruction. Parenthesized memory operands are excluded.
All 15 adapter tests pass. The aggregate proof then passed in 27.235 seconds
with its original instruction, cycle, extent and memory assertions unchanged.
Type checking also passes. The nine checked compiler/provider entry points
produce identical prepared source before and after this extension.

Logs:

- `/tmp/nucleus-cp-forward-red.log`
- `/tmp/nucleus-cp-forward-green.log`
- `/tmp/nucleus-pinned-aggregate-proof-failure.log`
- `/tmp/nucleus-cp-forward-proofs.log`
- `/tmp/nucleus-cp-forward-typecheck.log`

At this checkpoint, the paired structured-control proof still failed on
descending or overlapping IMAGE records at `loop-z80-runtime.asm:8`.
The subsequent [proof-ordering report](atom-proof-ordering.md) records the
correction and the complete broad-run failure classification. The passing
aggregate proof does not qualify the entire suite.

## Remaining qualification

The broad test run in `/tmp/nucleus-reconciliation-all-tests.log` started before
the HEX-coverage assertion was corrected. Its relocation failure is superseded
by the passing focused run, but the broad run is not an all-green result.
Collect its other findings, complete source/manifest and generated-image
checks, and repeat the release gates using the published ATOM pin before
publishing Nucleus or advancing downstream consumers. No ESP32, mobile-device
or new Linux qualification is claimed here.
