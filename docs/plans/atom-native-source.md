# Native ATOM source migration

Status: active, 2026-09-05. Baseline: published Nucleus main
`6045257a11d791e34fccba607b60e79f629d3019`. The released CP/M artifact remains
`nucleus-v0.3.0` at `52cca195d1b557ebfbbc3a6d924ca3d6ea657829` until a qualified
replacement is published. The ATOM dependency is pinned to
`802b5c2d320bec777f427755ff2d7338e3b80a05`.

## Outcome and invariants

Authoritative assembly, including normally generated assembly, must use ATOM's
supported source syntax and project-resolution rules directly. Remove the
Nucleus dialect translator, automatic input-symbol renaming, textual include
expansion, EQU scheduling and expression rewriting. ATOM remains the sole
assembler; there is no AZM execution or fallback in this migration.

Preserve language behaviour, diagnostics, recovery, generated code, memory
regions, relocation, runtime identities, source attribution and installed host
interfaces. Preserve sparse write coverage as well as byte values. A wrapped
16-bit end label is distinct from the mathematical exclusive end of 65,536.
The 16 KiB compiler-core gate remains unchanged; CP/M provider and runtime
accounts remain separate.

The public compiler fingerprint includes the symbol dictionary. Therefore,
byte equality alone is insufficient: keep promised long host-symbol keys and
addresses through an explicit output-only export map. That map must never
transform source input. Any unavoidable observable difference requires its own
review and report; no golden-file refresh may silently approve it.

## Parallel work

| Lane | Independent work | Integration boundary |
| --- | --- | --- |
| Source migration | Convert and prove assigned source families in isolated worktrees or disjoint files. | One integrator manages shared composition, export maps and generated artifacts. |
| Workspace clarity | Inventory current and stale checkouts; identify a safe current entry point and pinned suite. | Preserve divergent branches and dirty files. No reset, deletion or pruning as an incidental migration step. |
| Practical qualification | Exercise richer programs using the released NUC and real Triptych OS in private disks. | Keep baseline defects separate from source conversion. Add exact regressions before repairs. |
| Adversarial review | Independent read-only reviews of each bounded migration and its evidence. | The integrator verifies findings and reruns the combined checks. |

Workers may develop tests against the released compiler while source conversion
continues. Shared generated outputs and package locks have one writer. Final
release, downstream pin updates and hosted verification follow integration.
Physical ESP32 and mobile-device measurements remain separate work.

The [runtime conversion report](../reports/atom-native-runtime.md) records the
next native source family and its parallel CP/M qualification work. Runtime
catalog generation and development linking now bypass source translation;
legacy compiler/proof callers remain for subsequent stages.

The [CP/M source-provider report](../reports/atom-native-cpm-source.md) records
the next two converted leaves and their direct proof. The separately reviewed
parameter repair is integrated in this development branch; its released
artifact and Triptych pin have not yet been replaced.

## Source inventory

The baseline contains 119 assembly files and 44,764 lines under `asm/`, including
comments and blank lines. Its scanner finds 5,574 declared names, of which
5,538 exceed eight characters. There are 15 conditional switches, 1,788 `.if`
blocks and 300 textual include occurrences. Five files exceed the native
65,535-byte source-part limit. These are migration measurements, not target
code-size measurements.

The current adapter converts directives and characters, suppresses `.routine`
and `.end`, expands textual includes, selects mutable conditional definitions,
shortens names, handles special proof endpoints, schedules EQUs and inserts
temporary equates for unresolved expressions. The generator and several tests
also emit legacy assembly strings. All these inputs belong in the inventory;
converting only checked-in compiler instructions would leave the migration open.

## Selected structure

Use ATOM's public `resolveAtomProject` and `assembleResolvedAtomProject` APIs,
or `assembleAtomProject` for small complete projects. Keep only result-format
and compatibility work around them: sparse HEX, diagnostics and declared
host-symbol exports.

Entry headers select immutable configuration and ordered `%INCLUDE`
dependencies. Includes are import-once dependencies, not textual insertion.
Move extent labels into their actual source components and split interleaved
compositions at named boundaries. Split oversized files at routine or section
boundaries, while checking the 255-part project limit. Origin belongs to the
target configuration or an explicit native source part, not to a dialect shim.

Use checked-in, readable short symbols, with module vocabulary and meaningful
local names where references remain within one anchor. Preserve register and
flag contracts in comments. Put dependent EQU declarations after the labels
they require and write necessary forward-expression aliases explicitly in
source. Generated context files must emit valid ATOM syntax directly.

Two independent design sketches agreed on this structure. They proposed
different pilots: the small MON-3 packet provider or the full target runtime.
Start with the provider to test direct assembly cheaply, then use the runtime
to test composition and exported identities. Reject per-entry flattened copies,
a replacement handwritten preprocessor, and automatic opaque name generation:
each would retain or increase the source-maintenance problem.

## Stages and evidence gates

1. **Baseline and pilot.** Record source/workspace state, assemble the current
   native image and preserve its bytes, sparse writes and 2,464 symbols. Convert
   the MON-3 provider through the genuine ATOM resolver. Require the same 37
   bytes at low, ordinary, high and top-fitting origins, plus existing service
   success/failure, mutation, flag and stack tests. Obtain two independent reviews.
2. **Runtime and composition.** Convert the canonical runtime and generated
   profile contexts. Prove all six runtime profiles, helper offsets, long host
   exports and sparse output. Test malformed composition and source-part limits.
   Remove the old path for this migrated family. The target and historical
   proof runtimes share one body: inspect its caller closure before assigning
   edits. Its conversion may require the shared-symbol portion of stage 3 in
   the same integration wave. Do not create a second authoritative runtime to
   make the work appear independent.
3. **Compiler families in parallel.** Assign maps/state, tokenizer/parser,
   backend/emitter, and native/CP/M providers and proofs to disjoint work.
   Integrate shared entry graphs and export maps serially. Compare assembled
   extents and behavior after each family; preserve readable source rather than
   simply committing opaque translator output.
4. **Closure and removal.** Convert every generated caller and proof entry.
   Remove the translator and remaining input-adaptation machinery. Verify all
   six compiler variants, Node runner, import resolver, runtime catalog and
   NUC.COM; run relocation and complete source/host/package checks. Add a normal
   gate that prevents legacy source adaptation from returning.
5. **Qualified publication.** Complete adversarial review and clean Linux CI,
   publish source and compiler artifacts, advance Triptych's immutable input,
   and verify its full check, native/WASM workflows and exact hosted artifact.
   Preserve user working disks and the prior release for recovery.

Workspace clarity and practical qualification proceed throughout these stages.
Newly discovered baseline defects receive separate failing tests and repair
commits; they must not disappear inside source-renaming changes. The milestone
is complete only after source-path removal and downstream qualification, not
when a pilot or a renamed adapter passes.
