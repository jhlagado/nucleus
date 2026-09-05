# Native ATOM grammar, host bindings and diagnostics

Development checkpoint after `5764b04`, 2026-09-05. Three parallel source
conversions preserve the existing language, compiler memory layout and host
interfaces. This is not a release or completion of the whole source migration.

## Canonical source and composition

The packed Stage 7 engine and generated tables now use native ATOM syntax.
The parser composition imports the engine before the tables and retains the
original end labels. Its export map has 271 entries, including logical action
handler names and the two parser bindings used by the engine. Grammar analysis
and public action metadata keep their logical names; generated assembly uses
the explicit native names.

The generator emits 131 private, derived EQU constants after their target
labels. Directory cells reference those constants. No host calculation replaces
a relocated label difference. An output-only filter omits these private names
from the historical public dictionary and rejects address labels with those
names. The assembly generation and sparse bytes remain intact.

The native host composition imports zero-byte host state, the vector body,
the source host and the launch shell in that order. The CP/M vector uses native
syntax too. The host export map has 103 entries, including its external
compiler-entry binding. Compiler core, host code and host workspace retain
separate accounts.

Five diagnostic and position-copy entries now form one canonical native leaf.
Their original position before the remaining parser instructions is unchanged,
including nearby relative branches. Three remaining long names have an explicit
diagnostic export map. Direct native compositions receive immutable derived
flags from `compiler-profile.mjs`. The unchanged historical flag derivation is
isolated in `compiler-profile-legacy.asmi` until its remaining legacy entry
compositions are converted; no new inference was added to the source translator.

## Boundary evidence

The ordinary Stage 7 engine proof now assembles through the native helper.
Its frozen `5764b04` comparison includes sparse HEX, all 949 public symbols,
266 address labels and physical extents. Engine code remains 273 bytes and
generated tables remain 933 bytes. The proof exercises the exact parser-stack
boundary, failure paths and surrounding canary.

The standalone diagnostic compositions retain 29 local-return bytes and
33 nonlocal-return bytes. Their complete dictionaries contain 674 and 817
symbols respectively. Execution tests check exact return PC and SP, diagnostic
publication, inline-continuation bypass, six-byte position copies, surrounding
guards and incoming carry/zero flag combinations.

The four host fragments retain 913/915 bytes for direct transport and 981/983
bytes for MON3, without/with debug hooks. Their baseline dictionaries contain
934 direct-transport and 944 MON3 symbols. Five explicit test-only compiler
link addresses come from the frozen complete images; these fragment checks do
not substitute for a complete compiler launch.

The CP/M vector and its three register-preserving wrappers retain 104 bytes
and all 34 fixture symbols at origins `$0100` and `$8013`. Tests install
providers that overwrite register pairs, then check wrapper restoration,
returned status/flags and the exact return PC and SP.

Complete regeneration preserves all six compiler HEX strings and all public
dictionary keys and values against `5764b04`. The generated TypeScript refresh
only changes dictionary entry order. Runtime catalogue,
Node runner, import resolver and CP/M embedded assets remain textually identical.
A fresh CP/M compiler assembly also matches the corrected `abbb2be` baseline:
21,271 bytes, 2,803 public symbols, identical address dictionaries and sparse
writes, with SHA-256
`1c047ac1ed5ff1c4e914321b66476b842a1b28cc0dfef4cfdb86f691ca037334`.
This remains the private corrected compiler, not a replacement published release.
At these measured boundaries, code, immutable data, workspace and runtime byte
deltas are zero.

The scoped suites passed 57 source/profile/filter tests, 33 diagnostic tests,
5 native grammar tests, 20 native host-binding tests, 14 existing host/MON3
tests, all 9 existing LL(1) tests, and 81 tokenizer/CP/M/resolver regressions.
Typechecking and the complete regenerated-image check passed. Tests also
disable both transitional assembly imports and
exercise native helper calls; the grammar guard includes the ordinary proof
manifest route. Original source bytes are compared with actual files.

Independent peer reviews checked the other workers' changes, shared name maps,
profile flags and integration. They confirmed complete compiler-image parity
and the host instruction sequences. A test initially inspected the emulator's
input memory copy rather than its active memory; that assertion was corrected
before acceptance. These reused peer contexts are cross-reviews, not a fresh
independent review panel. Full-compiler semantic tests remain necessary because
the engine proof intentionally substitutes tokenizer and action callbacks.

## Remaining scope

The current scanner lists 3,300 remaining long-name entries across 5,731 source
declarations. These are migration counts, not executable size or a percentage
of completion. The larger parser and backend families, other host services,
remaining proof inputs and full compiler entry compositions still require
conversion before the transitional translator can be deleted.

Final standalone/package checks, Linux CI, a qualified release, Triptych's
immutable compiler pin and hosted verification remain later gates. All current
measurements use host execution; no ESP32 hardware claim is made.
