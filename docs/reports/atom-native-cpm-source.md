# Native ATOM CP/M source-provider conversion

2026-09-05. Development branch `atom-cpm-provider`, based on runtime conversion
`dfada0f` and parameter-repair integration `a5dc8d5`. The byte reference is the
reviewed repair at `8f8dd7b304249fde16ad6013826675bc9aceae1e`, not the older
released compiler with the parameter defect.

## Converted scope

`cpm22-bdos-call.asm` and `cpm22-source-provider.asm` now use native ATOM
symbols and EQU declarations. Register/flag contracts remain in comments.
The 88-name map is explicit and output-only; one existing short name changes
case only. Shared references were updated in 24 assembly files. The other
files retain their existing composition until their own conversion stages.

The dedicated proof uses ATOM's real project resolver and assembler through
`assembleNativeSource`. Its four parts are a numeric context, the two canonical
leaf sources, and the entry header. ATOM processes the include header;
Nucleus performs no source rewriting on this path. The old adapter remains in
the complete CP/M build and other proofs, with output-only name restoration
for these converted symbols.

The proof context has six provider inputs and a separately exported test-only
workspace limit. Tests check the corresponding production-map expressions and
status values. This fixture does not replace the production machine map.

## Preserved accounts

The native proof matches all 737 corrected baseline bytes at `$4100..$43E1`,
all 88 public symbol values and the exact emitted-address set. Its one extra
export is the test-only workspace limit. The frozen reference was captured
once with ATOM from the clean repair checkout; normal proof execution does not
invoke the legacy adapter.

| Component | Code | Workspace | SHA-256 of proof code |
| --- | ---: | ---: | --- |
| BDOS call / FCB helper | 25 bytes | 0 | `e31ad64fb487c6476c87cbea9c80d14dd309b205adab0c012bcfd38beb073757` |
| Source provider | 712 bytes | 1,476 bytes | `0811520157c1d4ec09144f11c511e6912d8550a252e339af6cd4239168702a77` |

These accounts and the provider's measured instruction, cycle and stack checks
are unchanged from the corrected baseline. The earlier correctness repair's
costs are recorded separately in
[the identity-repair report](cpm-materialized-name-identity.md).

## Verification and review

- All 21 focused tests pass: the 15 existing provider cases, two native
  byte/context checks, and four BDOS/FCB contract cases.
- The direct helper tests cover returned flags, IX/IY preservation, ordinary
  register clobbers, exact return PC/SP, stack guards, all twelve copied name
  bytes, twenty-four zeroed tail bytes, page crossings and memory canaries.
- Command, publisher and full-transient tests pass 32 cases. The comparison
  with the previous release artifact was explicitly excluded: its old bytes
  must not be substituted for the corrected candidate during this migration.
- The full compiler-image check passes without changing generated files,
  including all six compiler variants, all six runtime profiles, the Node
  runner, import resolver and CP/M embedded assets.
- The complete newly assembled transient matches the corrected private
  candidate byte for byte: 21,271 bytes, SHA-256
  `1c047ac1ed5ff1c4e914321b66476b842a1b28cc0dfef4cfdb86f691ca037334`.
- All 36 source-boundary tests and type checking pass.
- Independent review verified the mechanical changes across all 24 assembly
  files, the preserved repair/control-flow sequence, the native proof boundary,
  exact output dictionary and context drift checks. No unresolved finding
  remains in this slice.

Review corrected two proof assumptions: adjacent HEX records need not be
coalesced, and ATOM itself masks include headers. The context guard was also
tightened to compare complete expressions, and the symbol assertion now
rejects unexpected exports.

This completes the two leaves and their dedicated native proof. It does not
complete the CP/M composition, compiler-family migration or translator removal.
The corrected release artifact, manifest and immutable distribution input still
require coordinated regeneration and qualification before publication. No
released artifact, website, user disk or ESP32 firmware was changed.

Next: convert another bounded CP/M provider family, then integrate its native
entry dependencies and output contracts through the same byte and behavior
checks. Run final release qualification without overlapping CPU-heavy assembly
jobs that can exhaust short host-test deadlines.
