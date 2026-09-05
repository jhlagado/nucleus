# Native ATOM production compiler

Development work after `c75099927ecc10cbcc4a8994d137ec2d598cf6d2`,
2026-09-05. This conversion preserves the compiler language, emitted programs,
memory layout and host interfaces. Publication and downstream updates remain
separate gates.

## Source and composition

The frontend, backend and MON3 services were converted in parallel. The
frontend map contains 791 names, the backend map 547, the services map 94,
the shared compiler/startup map 75 and the flat proof map 158. The runtime
map also preserves the historical `Reset` spelling for native `RESET`.
These maps restore public output names; they never transform source input.

The production entries now import canonical ATOM parts. The compiler-state
wrapper is named `compiler-production-state.asmi`; the older
`compiler-state.asmi` remains unchanged for its historical proofs. Boundary
parts preserve all existing compiler extents. No byte separates symbol lookup's
missing-name path from the diagnostic routine into which it falls through.

The typed parser is split at its expression/declaration boundary. Backend
templates retain their original position after the code. Dependent, zero-byte
aliases follow the templates; no host calculation substitutes numeric addresses.
MON3 retains vector, services and relocated compiler order. CP/M retains its
transient jump, compiler, host vector, providers, startup and embedded assets.
Its saved caller stack still uses the immediate operand of the writable startup
instruction.

The publisher has two source-authored, zero-byte length constants after the
embedded assets. This makes its forward expressions directly assemblable in
the complete CP/M image as well as the isolated proof. An output-only filter
omits those two private names and rejects address labels with the same names.

The complete compiler helper supplies explicit immutable profile flags and
uses ATOM's own project resolver and assembler. The image generator and ordinary
flat proof route call it directly. The release builder also uses this route,
while retaining its existing release-baseline guard. Relocation qualification
uses one canonical source composition and ATOM's target start address, with
the original callback stubs and behavioral assertions.

## Verification and review

The frozen comparison fixture contains all six `c750999` compiler HEX strings
and public dictionaries. It is independent of current generated output and
does not read Git during tests. Tests compare actual source files with the
resolver's original bytes and check that only ATOM's own directive masking
changes compiler input. A separate execution test disables both legacy assembly
imports before using the ordinary image and proof routes.

Independent cross-reviews checked each worker's other source family and the
shared compositions. Static comparisons covered all 128 backend flag
combinations and 2,048 frontend combinations. Four existing small historical
proofs passed with their original extent, instruction and cycle assertions.
These source-family checks used reused peer contexts. Two additional fresh
reviewers examined the final integration independently and found no actionable
defects. Both noted the same regression-test limitation: the six frozen profile
fixtures contain values and HEX, but not complete address-versus-EQU dictionaries.
Generic native assembly tests, relocation and the independent complete-CP/M
comparison cover that distinction separately; a permanent classification
fixture for every profile would strengthen future regression checks.

Integration checks identified and repaired several problems: a new
state-wrapper filename initially collided with the historical state file;
packed-token operands needed ATOM-compatible arithmetic spelling; and the flat
proof needed the zero-byte runtime identity before its compiler. The state file
was restored exactly, and the original proofs were rerun. No golden output was
changed to accept these errors.

The scoped source/profile/filter suite passed all 61 tests. CP/M qualification
passed eight guest compiler behaviors, the actual complete-image layout check
and seven frozen native proofs. Its remaining artifact test fails against the
unchanged released 21,281-byte executable in `dist/`; the private corrected
source already produced 21,271 bytes before this conversion. The existing test
and release-baseline guard remain intact pending release qualification.

## Complete-image evidence

All eight native compiler tests passed: the six exact image/dictionary
comparisons, the fixed profile matrix, and the ordinary executable proof with
both legacy assembly imports disabled. Public dictionary sizes remain
2,615/2,616 for resident proof profiles, 2,464/2,465 for direct native profiles
and 2,735/2,736 for MON3, without/with debug hooks.

| Profile | Compiler code | Immutable data | Complete core | Workspace |
| --- | ---: | ---: | ---: | ---: |
| Resident proof | 15,844 | 437 | 16,281 | 3,918 |
| Resident proof, debug | 15,910 | 437 | 16,347 | 3,918 |
| Native/MON3/CP/M | 15,877 | 437 | 16,314 | 3,922 |
| Native/MON3, debug | 15,943 | 437 | 16,380 | 3,922 |

Each byte account is unchanged from the frozen baseline. Independent native
assembly of the complete CP/M transient also matches the corrected `abbb2be`
baseline: all 2,803 public values, address classifications and sparse bytes,
with 21,271 materialized bytes and SHA-256
`1c047ac1ed5ff1c4e914321b66476b842a1b28cc0dfef4cfdb86f691ca037334`.

The complete CP/M assembly used 527,655,109 emulated assembler instructions.
The six compiler profiles used 506,310,689; 506,810,512; 410,304,346;
410,779,574; 493,591,594; and 494,095,855 respectively, in resident,
resident-debug, native, native-debug, MON3 and MON3-debug order. These are build
workloads, not instruction counts for the generated programs.

A further 144 focused tests passed for native diagnostics, grammar and host
bindings, open parameters, aggregate constants, string arguments and host
execution. The exact CP/M compile/run instruction and cycle assertions passed
unchanged. Publication and complete package qualification remain pending.

Complete regeneration preserves all six HEX strings and every public
dictionary key/value against `c750999`. The generated compiler TypeScript
changes dictionary ordering only; compiler fingerprints already sort those
entries. The runtime catalogue, Node runner, import resolver and CP/M embedded
assets remain textually identical.

The final regenerated-image check and typecheck passed. Native relocation
passed at `$0000`, `$0100`, `$8000` and the computed top-fitting origin `$C067`.
Its physical end is `$10000`, while the final word label wraps to zero. Existing
address-table, contiguous-write, prefetch-selector and diagnostic/stack
assertions remain unchanged. No exact return-PC or canary claim is inferred
from that relocation test.

## Remaining work

The Node NOBJ runner and remaining historical/generated proof inputs still
require conversion. Their source translator remains temporary development
machinery. The migration is not complete until those callers are converted,
the translator is removed, and standalone/package qualification passes.

The released CP/M baseline remains version 0.3.0, 21,281 bytes. The separately
repaired private compiler is 21,271 bytes; its reviewed release-baseline update,
publication, Triptych pin and hosted qualification remain pending. This source
conversion does not silently update that release guard. All measurements are
from host execution, not ESP32 hardware.
