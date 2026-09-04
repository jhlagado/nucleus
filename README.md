# Nucleus

A small typed language compiled directly to machine code for sixteen-kilobyte
Z80 systems.

Nucleus is an autonomous project. Its language, grammar, direct compiler,
runtime contract, and conformance rules are defined here. Material outside this
package does not govern Nucleus.

## Layout

|             |                                                                         |
| ----------- | ----------------------------------------------------------------------- |
| `docs/`     | language and runtime authorities, implementation plan, and charter      |
| `grammar/`  | machine-readable production grammar, generator, and packed LL(1) tables |
| `asm/`      | direct-Z80 compiler, runtime, and executable proof fixtures             |
| `examples/` | small source programs, including a TEC-1-style console                  |
| `library/`  | importable console and integer-output routines written in Nucleus       |
| `proofs/`   | bounded memory profiles and proof-harness manifests                     |
| `src/`      | Node compiler, CLI, target validation, NOBJ, D8, and publication        |
| `test/`     | grammar, contract, measurement, and direct-Z80 proof gates              |

## Host compiler

The Node interface runs the same Z80 compiler used on a small machine. It
streams ordered source parts through the native compiler-host ABI, receives a
committed NOBJ stream, and materializes launch artifacts only when requested.

```ts
import { createNucleusCompiler } from "@jhlagado/nucleus";

const compiler = createNucleusCompiler();
const result = await compiler.build({
  sources: [{ name: "main.nu", source: "sub main()\nend\n" }],
  target,
  artifacts: { bin: true, hex: true, d8: true },
});
```

BIN contains the used extent of a flat image; it does not include the unused
capacity filled by the target profile. `compileNucleusTo()` exposes the same streaming path to a caller-owned
transactional NOBJ destination. `compileNucleus()` remains as a
resident-source compatibility API for older integrations and differential
proofs.

[Nucleus Host API 1](docs/host-api.md) defines target and project schemas,
classified failures, compiler identity, capabilities and artifact publication.

The command-line interface writes the committed object directly. It can also
materialize a flat Intel HEX launch artifact while retaining NOBJ as the
canonical result:

```bash
nucleus build -o program.nobj src/main.nu
nucleus build --host-transport mon3 -o program.nobj src/main.nu
nucleus build -o program.nobj --hex-output program.hex \
  --target-profile nucleus-target.json src/main.nu
nucleus build -o program.nobj --hex-output program.hex \
  --d8-output program.d8.json \
  --target-profile nucleus-target.json src/main.nu
nucleus build --project nucleus-project.json
nucleus run program.nobj
nucleus target validate nucleus-target.json
nucleus capabilities --json
```

`nucleus run` does not bypass the target architecture. It starts the packaged
standalone Z80 NOBJ consumer under Debug80 Runtime. That consumer reads the
object once, writes IMAGE bytes to target memory, applies PATCH records in
order, validates MAP and COMMIT, and only then enters the program. Program
console calls pass through the standard Z80 service vector and the MON3
`RST 10h` selector boundary to Node. Direct source port I/O remains ordinary
Z80 I/O. For a banked target, Node preserves one physical image per bank while
the Z80 sees
the selected window; cross-bank calls and non-returning jumps use the same
far-control ABI required on hardware.

A launch target profile supplies image and writable layout plus every external
service destination. The compiler library retains its synthetic default target
for conformance and tooling, but a host must not mistake those proof addresses
for a machine integration.
[`test/fixtures/host-target.json`](test/fixtures/host-target.json) shows the
JSON shape with synthetic addresses. A machine profile must replace every
service destination with a callable implementation for that target.

The host accepts flat and bounded banked target descriptors. Optional D8 output
is derived from a conditionally instrumented build of the same Z80 compiler;
the instrumentation changes neither the shipping compiler nor any target
artifact. [Nucleus D8 source maps](docs/d8-source-maps.md) defines the trace
ABI, validation, recoverable publication, and per-bank output rules.

The current authorities are:

- [Nucleus 0.1 Language Specification](docs/specification.md)
- [Nucleus Target System Specification](docs/target-system-specification.md)
- [Nucleus Object Stream Format](docs/nucleus-object-format.md)
- [Nucleus Z80 Runtime and Backend Contract](docs/z80-runtime-contract.md)
- [Nucleus Z80 Platform Services Architecture](docs/z80-platform-services.md)
- [Nucleus Host API 1](docs/host-api.md)
- [Nucleus standard library](docs/standard-library.md)
- [Nucleus on CP/M 2.2](docs/cpm22-command-line.md)
- [Nucleus D8 Source Maps](docs/d8-source-maps.md)
- [Nucleus host and Debug80 integration](docs/host-integration.md)
- [MON3-compatible platform binding](docs/mon3-host-binding.md)
- [Nucleus 0.1 Implementation Plan](docs/implementation-plan.md)
- [Nucleus reviewer's charter](docs/reviewers-charter.md)

## Method

Bottom up. Byte and timing claims require assembly and execution evidence, or
an explicit estimate label. ATOM is the build assembler; Debug80 Runtime
executes the Z80 code. Historical results from another assembler do not
establish ATOM-build correctness by themselves.

The specification grammar analyzer checks the grammar printed in the language
specification. The packed parser uses the machine-readable Stage 7 grammar in
`grammar/`; its generated tables are reproducible and conflict-free. Trap and
service assignments are checked against the direct-Z80 contract. The
type-metadata model covers every Nucleus type, including arrays of records and
bounded strings, without turning aggregate aliases into runtime types.
The flat-manifest adapter preserves ordered source-part identities and
diagnostic names outside the compiler core.

The host NOBJ boundary encodes, validates, and materializes the strict
append-only object stream. Image and patch records use independent sequential
spools, while an atomic generation reference prevents an aborted or corrupted
object from replacing the last committed artifact. A machine-readable runtime
identity selects the canonical source revision, ABI, link rules, and expected
layout; the operating-layer provider deterministically links fully resolved
bytes for each validated target context.

Proof manifests may opt into a second, NOBJ-aware execution. The runner commits
the producer's bounded logical sink calls, validates and materializes the
object into fresh memory, and enters only its committed target entry. A small
package-local bank-window hook supports synthetic multi-bank runner evidence
without moving NOBJ policy into the general Debug80 runtime.

Aggregate constants use the same complete record, fixed-array, and bounded-
string initializers as program variables. Their direct named roots are
read-only; ordinary aggregate aliases deliberately carry no transitive
read-only qualification.

Recoverable errors remain explicit and local: `else fail` propagates one
failable call, same-line `handle NAME ... end` handles it, and `return` denotes
success only. These forms lower to ordinary Z80 conditional control flow, not
exceptions or stack unwinding.

The parameter-only type `string[]` lets one source routine accept every bounded
`string[N]` capacity while retaining the actual capacity for `.length` and checked
indexing. The [`tec1-console.nu`](examples/tec1-console.nu) example implements
text output as an ordinary failable Nucleus routine and implements hexadecimal
formatting in ordinary Nucleus routines. The compiler and runtime measurements are
recorded in the [implementation account](docs/implementation-plan.md#parameter-only-string-and-retirement-of-the-string-intrinsics).

## Development toolchain

ATOM is the assembler for new source and production image generation. Its
revision is pinned in `devDependencies`. A build-time adapter translates the
existing source spelling and symbol names into ATOM's supported syntax; ATOM
resolves addresses and emits the bytes. Installed Nucleus packages use prebuilt
images and do not invoke an assembler while compiling or running programs.

```bash
npm ci
npm run test:atom-source
npm run build
npm run test:host-images
npm run check:compiler-images
npm run check:runtime-boundary
npm run test:package
```

Use normal `npm ci` for a source checkout. The pinned Git dependencies compile
their JavaScript during package preparation; `npm ci --ignore-scripts` omits
those files. This differs from installing an already prepared package archive.

AZM is historical. The image-generation comparison against its saved outputs
has passed, and the temporary oracle path has been removed from the generator.
Image generation uses ATOM only, with no fallback.

`test:host-images` runs the 23 host/prebuilt-image test files. It is a scoped
execution check, not the complete language-conformance suite.

`test:package` packs the current distribution and installs it in an isolated
consumer project. The check imports every public export, compiles and runs a
small program through both the library and command-line interfaces, and checks
that a rejected build leaves the preceding object file intact. Neither ATOM
nor AZM is installed in that consumer: published Nucleus packages compile and
run programs from their prebuilt images.

The proof/measurement helpers and CI now use pinned ATOM revision
`802b5c2d320bec777f427755ff2d7338e3b80a05`. CI no longer checks out Debug80 to
build or link AZM. The complete final-worktree release gate passes: all 564
tests, deterministic compiler-image generation, the runtime-boundary check and
the installed-package consumer proof. Both push and pull-request Linux gates
passed, and pull request 1 was merged to `main` at revision
`7d3f6d2e01773d58226c758059c26b8009a18460`. The
[reconciliation report](docs/reports/atom-reconciliation.md) records the earlier
migration, and the [relocation checkpoint](docs/reports/atom-relocation-qualification.md)
records the current dependency and remaining release checks.

The CP/M release build emits the exact unpadded transient plus a machine-readable
manifest. A disk-image builder may add CP/M's final 128-byte record padding; it
must verify the manifest digest before doing so.

```sh
npm run build:cpm22
```

The outputs are `dist/NUC.COM` and `dist/NUC.manifest.json`. Normal builds use
ATOM exclusively; AZM is not a supported alternative release path.
