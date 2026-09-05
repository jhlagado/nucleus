# Native ATOM resolver and memory maps

Development checkpoint, 2026-09-05, following `4972e3a`. This conversion
preserves executable bytes, memory layout and public host names. It does not
complete the source migration or publish a replacement NUC.COM.

## Source changes

The object client, source-plan provider and import resolver now assemble through
ATOM's native project resolver. The standalone production generator uses that
path. Ordered native includes and explicit layout parts replace textual
insertion in the resolver and source-plan proof entries. The 304 resolver/ABI
names and 52 memory names have checked-in output-only export maps. Call sites
use their native names; the host still receives its existing public names.

All four machine maps are native source. The hosted normal and debug maps had
identical core-limit branches, so their common value is now one declaration.
Resident-source defaults moved into their 20 entry headers. No address changed.

ATOM constants are words. Each map declares the highest address as
`MMLAST EQU $FFFF`; host output converts that explicitly mapped value to the exclusive
`AddressSpaceLimit` of 65,536. This conversion neither changes assembly input
nor patches bytes. Tests reject malformed values and incorrect output mappings,
and check that input objects and address-label dictionaries remain unchanged.

The CP/M proofs now import the real map and, where needed, platform ABI. The
source-provider test-only entry and numeric context were deleted; both remain
recoverable in Git. Original map and ABI exports are restored, including all
217 public names in the source-provider proof. Source-part capacity remains an
explicit proof setting checked against its compiler-state declaration.

## Preservation evidence

| Boundary | Result |
| --- | --- |
| Standalone resolver | 3,056 identical bytes at `8000..8BF0`, 312 public symbols, 153 address labels |
| Source-plan proof | Original sparse writes at `0010..0013`, `4000..4013`, `4200..4724`; 181 public symbols and 67 address labels |
| Memory maps | Complete original dictionaries for historical, hosted, hosted-debug, MON-3 and CP/M profiles; no emitted bytes |
| CP/M source provider with BDOS shim | 737 identical bytes; original 88 leaf exports plus 129 original map/ABI/configuration exports |
| Complete corrected CP/M compiler | 21,271 identical bytes and all 2,803 public symbols, address labels and sparse writes |

The complete CP/M comparison freshly assembles the clean `abbb2be` baseline
and this candidate with ATOM. The candidate SHA-256 remains
`1c047ac1ed5ff1c4e914321b66476b842a1b28cc0dfef4cfdb86f691ca037334`.
The code, workspace, runtime and generated-code layout deltas are zero at these
boundaries. The candidate assembly executes 705,174,863 emulator instructions;
this measures the build, not execution speed of a compiled program.

The generated resolver required a text-only refresh: native ATOM returns its
symbols in a different order from the transitional adapter. HEX and all 312
key/value pairs are identical. The generated-file check compares serialized
text, so the dictionary ordering must match the actual production route.

Focused verification passes 48 source-boundary tests, 43 CP/M/resolver/
source-plan tests and seven collateral platform/object/runtime-catalog tests.
The production-route test blocks both legacy adaptation modules and checks
fresh assembly against the frozen baseline and bundled serialization order.
Resolver behavior runs against both bundled and freshly assembled code; a
private entry mutation proves that the latter tests execute the fresh image.
Source-plan execution checks the actual return PC and stack pointer. Type
checking and whitespace checks pass. The final generated-image check passes
for all six compiler variants, six runtime profiles, Node runner, resolver and
CP/M embedded assets. Only the resolver dictionary ordering required a refresh.

Implementation, test development and independent review ran concurrently in
disjoint files. Reviews found no remaining semantic defect in this checkpoint.
The production resolver wrapper's pre-existing HALT/stack check does not check
the exact return PC; that is a separate proof-strengthening opportunity.

## Remaining work

The transitional compiler assembler is still present. The fresh census contains
4,610 long-name ledger entries and 15 conditional switches. Compiler state,
tokenizer/parser, generated grammar, remaining proof compositions and oversized
source parts still require conversion. Those counts describe source, not
resident bytes.

Full standalone/package qualification, clean Linux CI, coordinated release
artifacts, Triptych's pin and hosted verification follow translator removal.
No released compiler, Triptych disk, browser storage or hosted deployment was
changed by this checkpoint. These are host-model results; no ESP32 measurements
were made.
