# Plan: one compiler source stream and a 255-file project loader

- Status: approved direction; implementation handoff
- Date: 2026-09-07
- Baseline: Nucleus main `11d9732`
- Scope: Nucleus compiler, loaders, host APIs, NOBJ/D8 metadata, and consumers

## Decision

Nucleus will remove its compiler-level source-part model. The compiler will
receive one concatenated byte stream for each compilation. It will no longer
receive file counts, file identities, begin-file events, end-file events, or
file-relative positions.

The project loader will accept an ordered list of 1 through 255 source files.
It will validate and concatenate those files before compilation. A list of 256
files is invalid even when the files are empty or the combined source is below
the byte limit. ATOM retains its own multipart project model and is outside
this change.

The loader will also retain the information that cannot live in the compiler
byte stream:

- the mapping from concatenated offsets to original files and positions;
- the source hash and original stored-file hash for each input;
- the bank assignment for each source range on a banked target; and
- the publication transaction that protects the previous executable.

This is a replacement of an implemented feature. The current source-part
model is used by diagnostics, D8, bank placement, retained names, host
adapters, NOBJ metadata, and conformance proofs. Those uses must be migrated;
they must not be deleted without an equivalent mechanism.

## Verified baseline

ATOM assembled every committed compiler image at `11d9732` without changing a
generated file. The committed image symbols report:

| Image | Compiler code | Immutable data | Compiler core | Free in 16 KiB |
| --- | ---: | ---: | ---: | ---: |
| resident proof compiler | 15,844 | 437 | 16,281 | 103 |
| native streaming compiler | 15,877 | 437 | 16,314 | 70 |
| native streaming compiler with D8 | 15,943 | 437 | 16,380 | 4 |

The migration must fit all three images. Host code and host workspace remain
separate accounts and cannot conceal compiler-core growth.

The current implementation has these distinct limits:

- the compiler accepts 1 through 8 source parts;
- each source part and each part-relative position is limited to 65,535 bytes;
- native source arrives through a 768-byte refill window;
- retained names have independent entry and byte capacities; and
- Triptych's existing generated single-input file is limited to 65,535 bytes.

Increasing the project file count does not increase the concatenated-source,
token-cache, retained-name, semantic-transcript, symbol, routine, generated
program, or target-image capacities.

## Current dependencies on source parts

The migration has six coupled surfaces.

1. The public Node and project APIs accept `NucleusSourcePart[]`. Import
   discovery orders those values and currently rejects the ninth file.
2. The compiler source-provider ABI sends begin-part, bytes, end-part, and
   end-unit events. Compiler state packs the current part ordinal, later-part
   count, pending boundary newline, and consumed end-part state into one byte.
3. Diagnostics contain a part ID and part-relative offset, line, and column.
   D8 trace collection uses the same identity and retained-name records store
   part plus offset.
4. A banked target supplies one bank ordinal per source part. The compiler
   reads that table when it records declarations and decides between local and
   far calls.
5. NOBJ MAP revision 1 serializes `partCount` and `partBanks[]`. Consumers
   validate those values, although target loading uses the already generated
   bank-tagged image records rather than the source-part list.
6. Native and CP/M providers, launch descriptors, proof adapters, documents,
   and release integrations reproduce the same model.

Triptych already implements most of the required loader behavior for released
single-file `NUC.COM`. Its source bundle preserves order, rejects name
collisions, validates source boundaries, inserts a missing final LF, hashes
the stored and logical bytes, checks a 65,535-byte total, maps a compiler offset
back to the saved file, and stages the generated source and map together. Its
project reader currently imposes a separate 16-file limit.

## Selected replacement

### Loader-owned bundle

The shared loader operation will accept this conceptual input:

```text
source files: 1..255 ordered records
record: stable name, raw bytes, target bank
maximum concatenated bytes: 65,535
```

It will produce:

```text
bytes: one concatenated compiler input
source map: original file ranges, inserted separators, hashes
placement map: concatenated half-open ranges and bank ordinals
```

Each occurrence in the ordered list is a distinct source file. The loader
rejects duplicate logical identities, canonical-name collisions, aliases to
one physical file, the output and scratch-name collisions already checked by
the relevant host, and any reserved namespace collision.

The loader copies or snapshots every input before publication. An asynchronous
hash or write must not mix bytes from different source generations.

### Boundary rule

The loader preserves every source byte up to the host's documented text-EOF
rule. It inserts one LF after a file that does not already end in LF. It inserts
nothing after LF or CRLF. The inserted LF belongs to the preceding file for
diagnostic mapping and bank placement and maps to that file's EOF with a
synthetic-boundary flag.

Before concatenation, a small boundary scanner rejects a file that ends inside
a quoted literal, parenthesized expression, or bracketed expression. It also
rejects a lone CR and the established invalid source-byte repertoire. The
scanner recognizes only the lexical state needed to prove a source boundary;
it does not parse Nucleus, resolve imports, or type-check source.

This rule preserves the old guarantee that another file cannot continue a
token, literal, delimiter context, or comment from the preceding file. Ordinary
language diagnostics remain the compiler's responsibility.

### Source map and diagnostics

The compiler will count one global byte offset, line, and column across the
concatenated input. Its diagnostic result will contain the diagnostic code and
that global position. It will contain no source ID or file ordinal.

The loader will map the global offset to the original file segment and
recompute the file-relative offset, line, and column from the snapshotted
bytes. A position on an inserted LF maps to the preceding file's EOF. EOF after
the complete bundle maps to the final file's EOF. The public Node and command
line results may continue to report `sourceName`, file-relative offset, line,
and column, but those are loader results rather than compiler fields.

The map must be validated against the ordered names, stored-byte hashes,
logical-byte hashes, complete bundle hash, and bundle length before it is used.
A stale map is an error, never a best-effort attribution.

### Retained names

The compiler will pass a global source offset to the host retain-name entry.
The host will validate the complete `[offset, offset + length)` range
against the one bundle and retain that offset with the bytes. Comparison and
materialization keep their present contracts.

This removes source identity from retained-name entries. A native provider may
materialize the bundle as one named object or implement random reads over the
ordered source snapshot. The compiler contract is the same in either case.

### Bank placement without file parts

Bank assignment remains target-placement metadata rather than Nucleus syntax.
The loader converts each file's bank assignment into concatenated placement
ranges. Adjacent ranges with the same bank may be merged. Every source-provider
bytes result includes the bank ordinal for that complete chunk, and a chunk
must not cross a placement-range boundary.

The compiler retains only `currentSourceBank`. It validates the ordinal against
`bankCount` when it accepts a chunk. A bank change can occur only after the
loader's boundary LF, so no token or declaration spans two bank assignments.
Declaration metadata and local/far-call selection continue to use the current
bank exactly as they do now.

The target descriptor will therefore lose the part-bank pointer. The loader
still verifies that the entry file uses `entryBank`; the compiler still checks
that `main` is emitted in `entryBank` and that a forward declaration and its
completion use the same bank.

This shape was selected over two alternatives:

- Encoding file or bank directives into the generated source would make
  accepted source depend on a private textual transformation and would expose
  placement to the tokenizer.
- Assigning the whole bundle to one bank would remove current banked-project
  behavior and turn existing local calls into an incompatible layout.

Chunk bank metadata preserves placement while removing file identity and file
boundaries from the compiler.

### D8 maps

D8 collection will record global source offsets. Before a D8 artifact is
published, the host will translate each source mark and retained routine name
through the validated loader source map. The resulting D8 files will continue
to name original sources and contain original file-relative lines and columns.

The D8 preflight remains part of the compile transaction. A missing, stale, or
inconsistent source map aborts the tentative NOBJ generation when D8 was
requested.

### NOBJ

Source-file ordinals do not affect target loading. NOBJ MAP revision 2 will
remove `partCount` and `partBanks[]`; the bank-entry table will follow the
fixed prefix directly. Bank-tagged IMAGE and PATCH records, entry bank, bank
extents, and generated far-call operands preserve all executable placement.

Writers will emit revision 2. Nucleus-owned readers and loaders will be updated
in the same migration. A compatibility reader may continue to accept revision
1 objects, but new objects must not synthesize a one-part list merely to keep
the retired field. Whether a released external consumer needs revision-1 read
compatibility is a release-integration check, not a reason to retain multipart
inside the compiler.

The NOBJ major/minor header version or MAP revision must identify the new
layout unambiguously. A reader must not infer the layout from payload length.

## Public interfaces

The preferred public term is **source file** at the project boundary and
**source bundle** at the compiler boundary.

The Node/project build path will continue to accept ordered source files for
compatibility, but it will bundle them before calling the Z80 compiler. A
single-file caller follows the same path and produces a one-segment map.

The compiler information result will publish:

- `sourceFiles: 255` for the loader boundary;
- `sourceBytes: 65535` for the complete concatenated input; and
- the unchanged token, retained-name, transcript, declaration, and output
  capacities.

It will no longer publish a compiler `sourceParts` capacity or five-byte source
descriptors. Target validation will accept file-keyed `sourceBanks` in project
configuration and will reduce them to placement ranges instead of
`partBanks[]`.

The native launch descriptor will remove `sourcePartCount`; the source
generation handle identifies one bundle. The diagnostic result block will
remove `partId`. ABI versions and sizes will change rather than reusing the old
layout under version 0.1.

The resident proof entry, if retained, will accept one `[start,end)` source
descriptor and one initial bank. It will not accept a count or descriptor
array. Tests that need several logical files must call the loader first.

## Transaction and failure rules

The loader completes discovery, ordering, collision checks, boundary checks,
capacity checks, hashes, source-map construction, and placement-map
construction before compiler output can replace a published program.

A failure during bundle preparation publishes none of the bundle, source map,
NOBJ, launch image, or executable. A compiler diagnostic aborts tentative NOBJ
output. An output or D8 failure also aborts the generation. Where a platform
uses named files and backups, the existing staged rename and backup policy
continues to protect the previous executable.

No migration step may modify or delete user source media. Temporary bundles,
maps, spools, and backups remain host-owned objects with explicit generation
lifetime.

## Capacity proofs

The implementation is incomplete until tests distinguish all of these cases:

- 1 source file accepted;
- 255 ordered small files accepted;
- 256 files rejected before compilation;
- concatenated length 65,535 accepted;
- concatenated length 65,536 rejected, including inserted LFs;
- an empty source file if the current host admits it;
- LF, CRLF, missing-final-newline, comment-at-EOF, and inserted-LF boundaries;
- a literal or delimiter left open at a file boundary rejected at that file;
- deterministic import postorder and explicit command-line order;
- duplicate identity, canonical collision, physical alias, output collision,
  and scratch collision rejected;
- a compiler diagnostic mapped to the first, middle, and final file;
- a position on an inserted LF mapped to the preceding EOF;
- stale source or bundle bytes rejected by the mapper;
- retained names crossing native refill boundaries but never file boundaries;
- same-bank and cross-bank calls with a bank change between adjacent files;
- a forward declaration and completion in matching and mismatching banks;
- flat and four-bank NOBJ revision-2 output and consumer validation;
- D8 source, line text, symbols, and segments attributed to original files;
- failed compilation followed by a clean compilation;
- late NOBJ or D8 failure preserving the previous publication; and
- reset or cancellation clearing the bundle generation and mapping state.

Tests for 255 and 256 files must use small files. They prove the file-count
boundary independently from the byte-capacity boundary.

## Migration sequence

Each stage should be a reviewable commit with focused tests. A later stage may
not conceal a failing earlier contract.

1. Add a Nucleus source-bundle module and tests. Reuse the proven Triptych
   boundary and mapping behavior, generalized to 1 through 255 files and bank
   placement ranges. Keep the current compiler call behind the adapter during
   this stage.
2. Change the Node project, import, CLI, and host paths to build one bundle.
   Preserve public file-relative diagnostics and D8 output through remapping.
3. Replace compiler source events with bytes-plus-bank and end-input. Convert
   source positions and retained names to global offsets. Remove part count,
   IDs, packed boundary state, descriptor iteration, and part-capacity
   diagnostics from compiler code and workspace.
4. Remove the part-bank pointer from the target descriptor. Update native,
   MON3, CP/M, resident-proof, and configuration adapters to supply banked
   chunks and validate the new ABI versions.
5. Emit and consume the NOBJ MAP revision without source-part fields. Update
   D8 preflight and every Nucleus-owned consumer before changing release pins.
6. Amend the language, runtime, target, NOBJ, native-host, host-API, source-
   packaging, reviewer, oddities, and implementation-plan documents. Remove
   multipart conformance requirements and add the loader contract.
7. Qualify Nucleus release artifacts, then update Debug80 and Triptych pins in
   their own repositories. Change Triptych's project count from 1..16 to
   1..255 only when its active disk work has released exclusive ownership of
   the browser files.

The first implementation unit is the source-bundle module and its boundary,
mapping, collision, capacity, and placement-range tests. It supplies a stable
host contract before assembly or object-format code changes.

## Verification and accounting

All production assembly and generated artifacts use ATOM. AZM is not a build
fallback or compatibility target.

For every assembly stage, record compiler code, immutable data, compiler core,
compiler workspace, host code, host workspace, NOBJ bytes, generated-program
bytes, runtime bytes, proof instructions, and T-states separately. Removing a
compiler field while adding the same required state to compiler immutable data
or workspace is not a core saving.

Run focused tests after each stage. Before each retained assembly commit, run
the applicable native-source checks, compiler-image check, typecheck, complete
test suite, proof suite, diff check, and the Z80 stack-balance checker over all
production `.asm` and `.asmi` files. Final qualification also rebuilds CP/M
artifacts and checks downstream artifact identities and pins.

The compiler-core limit remains 16,384 bytes. The native D8 image starts with
only four free bytes, so the source-state removal must land in the same commit
as any new compiler-side bank validation. A temporary non-building midpoint
must stay on a development branch and must not be pushed as a usable commit.

## Effort and risk

The Triptych file-count change is small once its browser files are available:
one validation change, boundary tests, and a release-asset check.

The complete Nucleus migration is medium-to-large. It has one modest loader
module, then four high-risk compatibility seams: compiler source state,
bank placement, diagnostic/D8 attribution, and NOBJ/consumer versioning. The
native and CP/M providers add another bounded adapter stage. The expected work
is five to seven coherent implementation commits plus separate downstream pin
updates, not one broad rewrite.

The main risks are:

- losing source-file attribution after a late emitter diagnostic;
- changing bank ownership at the exact boundary between files;
- allowing a token or delimiter context to cross a file boundary;
- retaining a revision-1 NOBJ layout under an ambiguous version;
- exceeding the native D8 compiler-core limit during an intermediate change;
- accepting 255 files while overflowing the 65,535-byte bundle; and
- publishing a bundle or executable assembled from mismatched source
  generations.

The selected split keeps the compiler small: file count, names, hashes,
mapping, boundary policy, and publication live in the loader; the compiler
retains a global source position and current bank only. Exact byte savings are
a measurement outcome. No saving should be claimed until the final ATOM images
and separate accounts are compared with this baseline.

## Completion gate

The migration is complete when the Nucleus compiler has no source-part count,
ID, descriptor array, begin/end-part event, part-relative position, part-bank
table, part-capacity diagnostic, or multipart conformance path; all supported
project loaders accept exactly 1 through 255 ordered files; diagnostics and D8
still name original files; banked programs preserve their current placement
and call behavior; Nucleus-owned NOBJ readers accept the versioned new map; all
publication and reset proofs pass; the ATOM-built images fit their published
limits; and the separately owned consumer repositories use a qualified Nucleus
release.
