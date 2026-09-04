# Atom reconciliation checkpoint

2026-09-05. Integration is in progress on `reconcile-atom`. Image generation
now defaults to ATOM. Main-branch publication and downstream dependency pins
have not changed.

## Recovered history

The Atom conversion exists. It was developed in the former Debug80 monorepo,
including changes to both `packages/atom` and `packages/nucleus`. Inspecting only
standalone Nucleus `main` gave an incorrect account of that work.

The extracted Nucleus commit is
`e920bbb055b567f4e62c5ab346978436561dcb6f`. Its tree is identical to
`packages/nucleus` at Debug80 commit
`f867a0c845b02064de46422ec6e7c9b4a976c062`. It is now preserved on the public
[recovered-debug80-atom branch](https://github.com/jhlagado/nucleus/tree/recovered-debug80-atom).

That branch and standalone `main` diverged. Reconciliation starts from
`6bd2723cb1b6e35f3e3796dbbfdcda9c320d40c6`, retaining its native hosts, imports,
NOBJ consumer, signed integers, array/string support and public TypeScript API.
Replacing `main` with the recovered tree would discard newer work.

## Build boundary

The build path is authored assembly, deterministic Atom source
adaptation, native Atom assembly, then the existing generated image/catalogue
modules. Compilation and execution continue to use prebuilt images and
pre-resolved runtime catalogues. Runtime assembly is outside this design.

`scripts/atom-source-translation.mjs` contains the recovered source scanner,
symbol ledger and line translator used by `scripts/atom-source.mjs`. The unused
historical layout rewrites and migration CLI have been removed. The smaller
module produces identical prepared source, aliases and provenance for all nine
checked entry points. These include the six compiler variants, Node runner,
import resolver and CP/M program provider.

The adapter expands includes and conditionals, preserves original source
locations, and delays immutable EQU definitions until their dependencies are
defined. Forward multi-symbol table and immediate expressions become symbolic equates.
Unknown/cyclic equates fail. Location-dependent expressions may not move.
Native Atom resolves addresses and encodes instructions; no AZM symbol values
are supplied to Atom.

Generated link contexts append collision-free short aliases for symbols absent
from checked-in source. They do not renumber the source ledger. This is needed
for `RuntimePacketService`, which is supplied by the catalogue generator.

The source changes include an explicit byte literal (`SUB $F6`, formerly
`SUB -10`), guards around three proof-only equates whose `GeneratedBase` is
undefined in streaming builds, and explicit section placement described below.

ATOM is the assembler for new assembly work, production generation and future
proof migration. AZM is permitted only as an isolated, temporary comparison
oracle. Its features and placement quirks must not govern new source. The
comparison against saved, section-normalised outputs has passed for every
generated artifact. It checked decoded bytes, exact write coverage and complete
symbol values, allowing differences in HEX record boundaries and JSON property
order. The temporary oracle path and its unused register-contract options have
now been removed from the image generator. Its only assembler is ATOM.

## Placement discrepancy

`scripts/fixtures/atom-placement.asm` reduces the original native-image
difference to six lines. Under the development AZM toolchain, an ORG followed
by DB selects data placement. Later instructions are emitted at both the old
code cursor and the active data cursor. Atom uses one location counter.

The fixture emits NOP at `$0100`, a two-byte header at `$0200`, and RET at
`$0202`. AZM also emits RET at `$0101`. Its implementation is in
`assembly/placement.js` (`placementForOrg`) and
`assembly/program-emission.js` (`emitProgramInstruction`).

Explicit ORG statements after the native-host and Node-consumer headers remove
the duplicate writes. The MON3 host-vector include is emitted before the code
at `$4400` and `$8000`, giving both assemblers ascending sections. Against the
normalised references, all six compiler variants, the Node runner and import
resolver now match every byte, write address and exported symbol. The native
compiler has 2,464 matching symbols; the runner has 324.

Relative to the original main-branch images, the changes remove redundant
instruction copies outside the declared sections. Every exported address is
unchanged. Differences in byte values number 880/882 for native normal/debug,
950/952 for MON3 normal/debug, and 65 for the runner. The normal and debug
resident compiler images are unchanged. Removal of these duplicate writes is
intentional; this is not byte-for-byte equivalence to the original AZM quirk.

HEX output must also remain sparse. Binary materialisation fills ORG gaps;
using that result directly as HEX would write over unrelated host memory.
The adapter renders only emitted image addresses after applying validated
patches.

## Reproduction and remaining stages

`npm run test:atom-source` runs the adapter tests, including a real native Atom
assembly with forward table differences and a sparse-HEX assertion.
`npm run test:host-images` reruns the 23-file host/prebuilt-image subset after
building the distribution. It does not replace the source-assembly proofs.
`npm run check:atom-images -- native` compares the complete 64K memory image,
write coverage and exported symbol set against the checked artifact. Supported
variants are `normal`, `debug`, `native`, `native-debug`, `mon3`, `mon3-debug`,
`runner` and `resolver`. An optional second argument writes diagnostic JSON.
This command does not regenerate or approve reference artifacts.

Current focused evidence:

- 13 adapter/comparison tests pass, including actual ATOM execution of forward
  byte/word expressions and sparse-HEX checks.
- All six ATOM runtime profiles match the saved runtime catalogue, including
  its layout and helper-offset checks.
- The CP/M program provider assembles with AZM imports forbidden (88 symbols).
- The bounded worker path also assembles that provider successfully.
- Full ATOM generation passes. The four generated image/catalogue modules and
  CP/M embedded assets match the saved, section-normalised references.
- `npm run check:compiler-images` independently regenerates every artifact with
  ATOM and passes exact file-content comparison.
- The 23 prebuilt-image/host test files pass: 130 tests. These cover the CLI,
  host API, runner, MON3, imports, source services and D8 publication, alongside
  configuration and specification checks. No legacy source-assembly proof was
  substituted for this run.
- Type-checking, the TypeScript distribution build and the distribution
  boundary check pass. The installed runtime excludes both assemblers.

The host subset passed both before and after the final regeneration. An
intermediate concurrent run was stopped after failures in the MON3 flat-image
test (33.4 seconds against a 30-second limit) and a CLI test (5.1 seconds against
a 5-second limit). The isolated rerun passed all 130 tests without changing
the test limits or image contents. Keep image builds and wall-clock-limited
execution tests sequential on this machine.

At the image-generation checkpoint, the test inventory had 15 files importing
AZM directly and 18 importing the legacy proof/runtime assembler helpers.
Those 33 files were not rerun at that checkpoint. The earlier 556-test baseline
is not a result for the current tree.

Atom itself also retains AZM calls in `generate-native-core.mjs`,
`native-object-harness-builder.mjs` and `generate-cpm22.mjs`. Nucleus consumes
the pinned prebuilt ATOM package; replacing Atom's own bootstrap/release paths
is separate remaining work. This checkpoint does not claim that the whole
tool collection is AZM-free.

## Development-helper migration

The development-only `src/nucleus-runtime.ts` and `src/proof.ts` now call the
same ATOM source adapter as the image generator. Runtime linking uses in-memory
source overrides instead of temporary files. Both helpers consume HEX and
original-name symbols directly; no synthetic AZM debug artifacts are created.
Their error classes, region/extent checks, service-vector layout, helper
offsets and guest execution limits remain in place. The installed host still
uses prebuilt catalogues and excludes both development modules and assemblers.

The ATOM migration also covers the platform-service ABI, MON-3 packet gateway,
CP/M command and CP/M program-provider test builders. Existing execution
assertions remain. Static AZM register-contract analysis is no longer performed
by these paths. Interface files remain ABI documentation; checking their
existence is not register validation. Dynamic tests cover selected caller
registers, stack restoration, packet bounds, traps and recovery. They do not
establish a replacement whole-program static-analysis guarantee.

Fresh guarded checks, with AZM imports rejected before module evaluation:

- Runtime link: seven tests, including complete-image equality for all six
  catalogue profiles and invalid placement rejection.
- NOBJ: 30 tests passed.
- Platform-service ABI and packet gateway: 31 tests passed.
- CP/M command and generated-program provider: 25 tests passed.
- Manifest memory-map proof: one test passed, retaining four guest instructions,
  34 cycles, nine proof-code bytes and the exact 64 KiB region partition.
- Type-checking, distribution compilation and installed-runtime boundary checks
  passed. No guest binary was regenerated by these helper-only edits.

`npm run test:atom-boundaries` repeats the six-file/93-test boundary group.
The separate memory-map check is a focused selection from the proof harness.
At that checkpoint, eleven test files still imported AZM directly. The next
section records their subsequent migration; neither checkpoint qualifies the
complete source-assembly suite.

The initial broad manifest run reported the flat-target test at 167.918 seconds
against its old 30-second host deadline. The remaining batch was interrupted
after that test failure. An isolated assembly-only measurement then completed
in 144.948 seconds: 752,560,907 emulated assembler instructions, 2,615 symbols,
and a 16,281-byte compiler core. This distinguishes construction cost from
guest execution. The flat-target test now has a 300-second host allowance;
its original guest byte, cycle, instruction and state assertions are unchanged.
The focused rerun passed with AZM imports forbidden: 57.239 seconds for the
test, with the other 23 harness tests skipped. Host assembly time varies
between runs; the passing result qualifies this flat-target proof, not the
remaining harness.
Other full-size proofs still need measurement and qualification; a larger host
deadline by itself is not a passing proof.

A read-only adversarial review found no new blocking helper defect and
identified the static-versus-dynamic contract coverage distinction above.
No Nucleus main-branch publication or downstream pin update has occurred.

## CP/M and loader proof migration

Ten further test files now assemble with the same ATOM adapter: the CP/M
layout, complete compiler, output candidates, publisher, runtime provider and
source provider; the native source-plan provider; the NOBJ consumer; and the
Node object-service and runtime-catalogue gateways. Their existing execution,
failure, memory-region and size assertions remain. These paths no longer run
AZM static register-contract analysis, with the same coverage limitation as
the earlier helper migration.

The CP/M direct-output source required two named equates for the low and high
bytes of its last admitted address. ATOM rejected the original parenthesised
immediate operands. The named operands retain immediate CP encodings and
the existing word-patch boundary at `$64FF`; no host expression evaluator or
fallback assembler was added. The direct sink remains 288 bytes, with 18 bytes
of workspace. The runtime provider remains 127 bytes, its embedded runtime
732 bytes, and its initial state 77 bytes.

Guarded focused runs passed 86 tests across the ten files:

- Six provider/publisher/gateway files: 19 tests.
- Complete CP/M compiler, layout and NOBJ consumer: 65 tests.
- Direct-output candidate comparison and patch bounds: two tests.

The complete compiler proof compiles through BDOS, publishes the exact COM
bytes, executes the program and recovers after failed publication. Its measured
compile path remains 35,469 guest instructions and 965,911 T-states. The layout
proof retains a 16,314-byte compiler core and 3,922-byte workspace. These counts
describe their individual proof profiles, not interchangeable compiler builds.

Full-compiler construction now has a 300-second host allowance in the CP/M
compiler, layout and output-candidate checks. The layout test took 37.286 seconds
and the three-image candidate comparison 55.967 seconds in the focused run.
Guest instruction limits, expected cycles and capacity checks were unchanged.
`npm run test:atom-cpm` runs all eight CP/M test files sequentially.

The final combined rerun passed all 49 CP/M tests, including exact opcode
assertions for both immediate comparisons. The six-file/93-test ATOM boundary
group and all 13 adapter tests also passed with AZM imports forbidden.
Type-checking, distribution compilation and the installed-runtime boundary
check passed afterward. No generated guest image changed in this proof wave.

`test/compiler-relocation.test.ts` is the only remaining direct AZM test
builder. The pinned ATOM host rejects a one-byte target at `$FFFF` with
`AtomAssemblyError`, category `configuration`, code `target-range`: its current
target validation limits the exclusive end to `$FFFF`. Nucleus's existing
relocation proof includes a top-fitting compiler whose mathematical end is
`$10000`. Resolve that limitation before migrating and qualifying the proof;
do not remove the top-fitting case or move it down one byte to obtain a pass.
The minimal target-range probe establishes this restriction, not the result
of a complete relocated compiler run. The broader manifest suite and clean
publication remain unqualified.

The next stages are:

1. Resolve ATOM's top-address limitation, migrate the remaining relocation
   builder, and qualify the complete source-assembly and manifest suites.
   Remove AZM from the ordinary test, measurement and CI
   paths; do not retain AZM as a permanent contract-checking prerequisite.
2. Replace the remaining AZM bootstrap/release calls in Atom itself using its
   self-hosted assembler, with any transitional comparison kept explicit.
3. Verify clean-checkout installation/publication.
4. Publish the verified reconciliation and update Debug80 and workspace pins.
   Resume the workspace launcher after those pins are correct.

These are host-emulation checks, not ESP32 hardware measurements. The recovered
historical proof counts are not evidence that current standalone artifacts
have passed this reconciliation.
