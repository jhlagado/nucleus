# Native ATOM CP/M adapter conversion

2026-09-05. Development branch `atom-source-native`, based on
`abbb2bea1b20d6ccfe11bdf936f48b525b0d88a6`. The baseline includes the separately
reviewed parameter-identity repair. The published compiler and Triptych pin
remain unchanged.

## Source and build changes

The program provider, runtime provider, command parser, direct-output sink,
publisher and Intel HEX renderer now use native ATOM source. Two explicit
maps preserve 301 existing long output names. Shared assembly references were
renamed in the same change; the remaining legacy adapter applies these maps
only to returned symbols.

The publisher has an explicit head, renderer and tail composition. Its
workspace EQU declarations precede their dependent renderer bindings, with no
emitted bytes moved. Embedded assets precede the publisher because its prefix
length expressions require both asset endpoints. Its sixteen initialized zero
bytes remain distinct from uninitialized storage.

Program initialization uses a named length derived after the workspace labels:
`PGCLRLEN EQU PGSTATE-PGINCUR`. ATOM resolves the earlier single-symbol
instruction reference directly. This private constant is excluded only from
the program proof's compatibility dictionary; tests also check its value
against the assembled workspace difference. No host expression scheduler is
used on this path.

All five canonical CP/M proof entries use `assembleNativeCpmProof`, which calls
ATOM's public resolver and assembler. The production image generator uses this
same native entry for the generated-program prefix. Its other, unmigrated
entries still use the legacy adapter. Generated embedded assets now have
native DB directives and explicit short start/end labels; their 1,685 payload
bytes are unchanged.

Four adapter proofs share one frozen numeric context under `asm/`. This is a
proof fixture, not another production memory map. The production authorities
remain `cpm22-target-memory-map.asmi` and `platform-services-abi.asmi`. Proof
context checks and the complete transient comparison guard this temporary
boundary. The program provider is self-contained and uses no copied context.

## Preserved accounts

| Component | Code | Immutable data | Workspace |
| --- | ---: | ---: | ---: |
| Program provider | 703 bytes | 47 bytes | 83 bytes |
| Runtime provider | 127 bytes | shared embedded assets | 4 bytes |
| Command parser | 427 bytes | 33 bytes | 25 bytes |
| Direct-output sink | 288 bytes | 0 | 18 bytes |
| Publisher, including HEX renderer | 759 bytes | 16 initialized zero bytes | 53 bytes |

The program prefix has an 876-byte physical extent. Its two 36-byte FCB
reservations produce no writes. The complete proof emits 807 bytes across
`$0100..$0419`, `$0461..$046C` and `$0800..$0803`, using half-open ranges.
Its 88 public symbol values and sparse bytes match the baseline. Dense prefix
materialization for the embedded asset retains the existing zero-fill policy;
its SHA-256 is
`6d423cebffa3656fad983575276fa5065ea0d96c9daf446bcd0490bae048680c`.
The prefix also contains 43 entry/vector bytes before the provider-code
account in the table.

No runtime instruction or data sequence changed in this refactor. Structural
comparison and focused execution are separate evidence: 35 behavior tests pass
through the native entries, with exact return-PC checks added beside the
existing stack checks. The historical NOBJ size comparison was excluded from
that focused run, then passed separately against the old producer/materializer
comparison path. The combined adapter, preservation and previous BDOS/source
provider run passed 63 tests; its sole excluded test was that separately
verified size comparison.

## Verification status

Independent read-only reviews found no actionable issue in the converted
leaves, publisher ordering, sparse storage or production prefix route. The
combined 38 source-boundary tests pass; type checking and whitespace checks
pass. Seven additional preservation checks compare all five proofs with the
frozen baseline, including exact bytes, sparse writes, retained symbol keys,
native source bytes and the complete expressions for proof-context inputs.
Unused inherited machine-map and packet-ABI exports omitted from the smaller
proofs are listed explicitly in the fixture; adapter and runtime-identity
exports are retained. This changes proof dictionaries only, not the public
compiler dictionaries.

The complete generated-image check passes: all six compiler variants, all six
runtime profiles, the Node runner, import resolver and CP/M embedded assets
match their checked-in outputs. The complete CP/M transient also matches
`abbb2be`: all 2,803 symbol values, label addresses, sparse writes and bytes are
unchanged. Its 21,271 bytes match the corrected private candidate, SHA-256
`1c047ac1ed5ff1c4e914321b66476b842a1b28cc0dfef4cfdb86f691ca037334`.

This is a bounded source conversion, not a release qualification. The full
compiler family, production memory-map composition, remaining generated source
and legacy translator still require migration. Fresh package/Linux checks,
the corrected release artifact, Triptych pin and hosted workflow remain later
gates. No user disk, hosted asset or ESP32 firmware was changed.
