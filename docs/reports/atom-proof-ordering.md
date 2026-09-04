# ATOM proof ordering and host deadlines

2026-09-05. This extends the [relocation checkpoint](atom-relocation-qualification.md)
in the unpublished `reconcile-atom` worktree. Production compiler code,
language rules and runtime interfaces are unchanged.

## Completed diagnostic run

The broad run completed with 540 passing and 23 failing tests across 57 files
in 1,713.70 seconds. It started before the earlier corrections and is not a
fixed release-snapshot qualification. Its log is
`/tmp/nucleus-reconciliation-all-tests.log`.

| Failure category                        | Count | Correction                                                           |
| --------------------------------------- | ----: | -------------------------------------------------------------------- |
| Host wall-clock timeout                 |    18 | Allow emulated ATOM construction time; retain guest execution limits |
| Descending or overlapping IMAGE records |     3 | Correct explicit proof-section order and one overlapping fixture     |
| Unsupported forward CP expression       |     1 | Use the adapter's deferred symbolic equate mechanism                 |
| HEX record-range representation         |     1 | Check contiguous coverage instead of requiring merged records        |

The CP and HEX corrections and the three compiler-equivalence timeout fixes
were qualified in the preceding checkpoint. The remaining deadline changes
are in `test/proof-harness.test.ts`, `test/ll1-stage7.test.ts` and
`test/nobj-proof-runner.test.ts`. The manifest proofs use a five-minute host
allowance; the NOBJ publication test uses three minutes. These limits include
assembly. No guest instruction, cycle, extent or memory limit was increased.
An isolated instrumented-compiler run reproduced its 30-second timeout after
55.86 seconds of work; it then passed with the corrected allowance.

## Explicit proof placement

`structured-control-z80-slice-proof.asm` emitted the `$9800` capacity fixture
before returning to the `$6800` runtime. The fixture block is now after the
runtime and proof code, still at `$9800`. New assertions retain that address
and keep the fixture clear of the `$A000` backup region.

`stage7-ll1-aggregate-call-z80-slice-proof.asm` emitted its `$B000` fixtures
before the lower runtime and proof code. It also selected `$B000` again for
the parameter-capacity fixture. The higher fixtures now follow the proof
code, and the parameter fixture continues immediately after the preceding
fixture instead of overwriting its start. Tests require that exact adjacency
and keep the fixture end below the stack floor. The parameter fixture's
address intentionally changes; the compiler and runtime placements do not.

`stage8-failure-z80-slice-proof.asm` likewise returned from its higher source
fixtures to the `$6800` runtime. The runtime block now precedes those fixtures.
Its address and the proof's `$D000` entry remain unchanged.

All three files retain identical non-ORG assembly statements and source-string
statements compared with their Git baseline. This text comparison checks for
accidental edits during movement; execution tests remain the correctness proof.
All three corrected proof cases pass with their retained assertions:

| Proof                       | Compiler core bytes | Workspace bytes | Runtime bytes | Guest instructions | Guest cycles |
| --------------------------- | ------------------: | --------------: | ------------: | -----------------: | -----------: |
| Structured control          |              11,174 |           1,694 |           796 |            252,025 |    2,680,233 |
| Stage 7 packed grammar      |              15,711 |           3,887 |           921 |          2,019,670 |   19,662,246 |
| Stage 8 failure propagation |              15,711 |           3,887 |           921 |          1,723,192 |   17,126,791 |

These results match the retained expected counts; they are not measurements
from a new execution of the historical assembler. The structured proof took
20.235 seconds, Stage 7 took 64.166 seconds and Stage 8 took 62.292 seconds.
Type checking passes.

Logs:

- `/tmp/nucleus-structured-placement.log`
- `/tmp/nucleus-stage7-failure-details.log` (before correction)
- `/tmp/nucleus-stage7-nobj-corrected.log`
- `/tmp/nucleus-stage8-placement.log`
- `/tmp/nucleus-instrumented-deadline-red.log`
- `/tmp/nucleus-placement-typecheck.log`

## Complete manifest suite

The combined Stage 7/NOBJ run passes all 13 tests in 188.36 seconds. The
publication case retains compiled A after divergent B output, then commits and
executes C. The corrected manifest rerun passes all 24 tests in 944.72 seconds.
It includes every large compiler layout, the NOBJ execution paths, the fixed
memory-map cases and the direct-Z80 semantic proofs. The run selected the
packed published ATOM revision through a development hook and blocked AZM
imports. Its log is `/tmp/nucleus-manifest-corrected.log`.

## Installed package

`npm run test:package` creates a package archive, installs it into an isolated
consumer project and exercises both public interfaces. The consumer imports
every declared export, compiles and runs a byte-echo program through the API,
then repeats the build and execution through the command line. A deliberately
invalid second build returns failure without replacing the preceding object.
Neither assembler is installed in the consumer.

The final worktree package check contains 234 files and 3,863,275 unpacked
bytes. Its
archive integrity is
`sha512-2tE2FMQWCPbmIQWWzg6BOH8Rp4bOq0V5kUJU5SoENahcHfjnxUcWWxYBcc9LsIXmCK/4tvsM7BvGk+1D9aKvag==`.
This archive records the current unpublished worktree; it is not the final
release archive. The package check now runs at the end of `prepublishOnly`.

A new snapshot at `/private/tmp/nucleus-release-candidate.3sVlJd` includes these
fixture edits and deadline changes. Normal `npm ci` with an empty cache passes,
as do all 15 source-adapter tests. It uses the pinned Git dependency without
the package override, with AZM imports blocked. Its former complete
`prepublishOnly` gate passes: image regeneration checks, type checking, all 563
tests across 57 files, distribution build and runtime-boundary checking. The
test suite took 1,684.82 seconds. Logs:

- `/tmp/nucleus-release-candidate-install.log`
- `/tmp/nucleus-release-candidate-adapter.log`
- `/tmp/nucleus-release-candidate-gate.log`

The snapshot's 277 build/test input files have aggregate SHA-256
`322cfc66659faf7366897bae3a8e7237781f063500c246c31d1ee142c1d281b6`.
This covers `asm`, `src`, `scripts`, `test`, `proofs`, `grammar`, `library`,
the package declaration/lockfile and both TypeScript configurations. The hash
input is each sorted relative path followed by NUL and its raw SHA-256 digest.
It identifies this unpublished source snapshot, not a release commit.

The final worktree pins ATOM revision
`802b5c2d320bec777f427755ff2d7338e3b80a05`. A clean install from an empty npm
cache passes all 15 adapter tests. The complete guarded `prepublishOnly` gate
then passes in the worktree: deterministic compiler-image checks, type
checking, 563 tests across 57 files, image regeneration, the distribution
build, runtime-boundary checking and the installed-package consumer proof. The
test suite took 1,726.60 seconds. The final gate log is
`/tmp/nucleus-final-release-gate-802b5c2.log`.

This qualifies the local source state for commit. It does not claim a published
Nucleus release or Linux CI result. Hardware and browser qualification remain
outside this report.
