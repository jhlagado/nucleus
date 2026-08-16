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
| `asm/`      | direct-Z80 compiler, runtime, and executable AZM proof fixtures         |
| `examples/` | small source programs, including a TEC-1-style console                  |
| `proofs/`   | bounded memory profiles and proof-harness manifests                     |
| `src/`      | Node compiler, CLI, target validation, NOBJ, D8, and publication        |
| `test/`     | grammar, contract, measurement, and direct-Z80 proof gates              |

## Host compiler

The Node interface runs the same Z80 compiler used on a small machine. It
loads source parts into an emulated compiler address space, executes the public
target entry, then validates and materializes the committed NOBJ stream.

```ts
import { compileNucleus } from "@jhlagado/nucleus";

const result = await compileNucleus([
  { name: "main.nu", source: "sub main()\nend\n" },
]);
```

Tool integrations should use the classified Host API 1 result:

```ts
import { createNucleusCompiler } from "@jhlagado/nucleus";

const compiler = createNucleusCompiler();
const result = await compiler.build({
  sources: [{ name: "main.nu", source: "sub main()\nend\n" }],
  target,
  artifacts: { hex: true, d8: true },
});
```

[Nucleus Host API 1](docs/host-api.md) defines target and project schemas,
classified failures, compiler identity, capabilities and artifact publication.
[Nucleus command-line compiler](docs/command-line.md) gives the complete
installation, import-directed build, target, output, diagnostic, and launch
handoff workflow.

The command-line interface writes the committed object directly. It can also
materialize a flat Intel HEX launch artifact while retaining NOBJ as the
canonical result:

```bash
nucleus build -o program.nobj src/main.nu
nucleus build -o program.nobj --hex-output program.hex \
  --target-profile nucleus-target.json src/main.nu
nucleus build -o program.nobj --hex-output program.hex \
  --d8-output program.d8.json \
  --target-profile nucleus-target.json src/main.nu
nucleus build --project nucleus-project.json
nucleus target validate nucleus-target.json
nucleus capabilities --json
```

With one positional source, the Node host reads leading dependency comments:

```nucleus
//% import "lib/console.nu"

sub main()
end
```

Dependencies are emitted before their importer as separate source parts. The
host passes every source byte unchanged, so the compiler treats the directive
as an ordinary `//` comment and retains exact diagnostics and D8 positions.
Projects may use `nucleus-project/v2` with one `entry`; version 1 and multiple
positional sources retain explicit written ordering. [Nucleus source
packaging](docs/source-packaging.md) defines discovery and the generated SP1
plan for filesystem-aware hosts.

The complete [`examples/import-project`](examples/import-project/) project is
also included in the npm package and is exercised by the package-installation
gate.

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
- [Nucleus Host API 1](docs/host-api.md)
- [Nucleus command-line compiler](docs/command-line.md)
- [Nucleus source packaging and SP1 source plans](docs/source-packaging.md)
- [Nucleus D8 Source Maps](docs/d8-source-maps.md)
- [Nucleus host and Debug80 integration](docs/host-integration.md)
- [Nucleus 0.1 Implementation Plan](docs/implementation-plan.md)
- [Nucleus reviewer's charter](docs/reviewers-charter.md)

## Method

Bottom up. Every claim about Z80 bytes or timing is produced by AZM and the
Debug80 Z80 runtime from a test in `test/`, or is labelled an estimate in the
document that makes it.

The specification grammar analyzer checks the grammar printed in the language
specification. The packed parser uses the machine-readable Stage 7 grammar in
`grammar/`; its generated tables are reproducible and conflict-free. Trap and
service assignments are checked against the direct-Z80 contract. The
type-metadata model covers every Nucleus type, including arrays of records and
bounded strings, without turning aggregate aliases into runtime types.
The host preserves ordered source-part identities and diagnostic names outside
the compiler core, whether order comes from a compatibility flat manifest or
import-directed packaging.

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

Compiler-image generation requires the current AZM checkout from the Debug80
workspace. The registry release `@jhlagado/azm` 0.3.9 cannot prove the
`noreturn` inline-operand convention used by the compiler's strict register and
stack contracts. Link the workspace package before regenerating or checking
compiler images:

```bash
cd /path/to/debug80
npm install
npm run build -w @jhlagado/azm
cd packages/azm
npm link
cd /path/to/nucleus
npm link @jhlagado/azm
npm run check:azm-toolchain
```

The Debug80 checkout must contain commit `3f2adb66` or a later implementation
of its `noreturn` inline-operand contract analysis. The compiler-image scripts
run the same capability check themselves. It tests the required behavior
because the linked and registry packages currently report the same version
number.

```bash
npm run proof
npm run measure
npm test
```
