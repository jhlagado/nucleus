# Handover: Import-Directed Nucleus Source Packaging

**Status:** Complete, reviewed, verified, committed, and pushed.

**Branch:** `codex/nucleus-import-host`

**Implementation base:** `562bf79d2b8a1a017c0bfcd35a539d2509d17b36`

**Current branch commit:** `bcc9ecf5892d339f2b975803bd2325dcc202d3cb`

**Implementation plan:** [2026-08-16-import-directed-source-packaging.md](./2026-08-16-import-directed-source-packaging.md)

## Result

The Node host supports import-directed source packaging for Nucleus. A source
file may place dependency directives in its leading comment header:

```nu
//% import "lib/io.nu"
```

The host resolves the dependency graph, emits every source once before its
importer, and passes the original bytes through the compiler's multipart ABI.
The Z80 compiler treats each directive as an ordinary `//` comment. Import
discovery adds no compiler code, immutable data, workspace, semantic transcript,
generated-program, or runtime bytes.

The public project-host API now exposes the same preparation path used by the
CLI and Debug80 integration. It returns ordered source parts, dependency
metadata, the complete compiler target, output paths, and a canonical SP1
source plan.

## Settled host behavior

- The scanner recognizes `//% import` only in the leading header. Blank lines
  and ordinary comments may appear there. The first Nucleus source line closes
  the header, and a later directive is a packaging error.
- The host preserves every source byte. It does not strip directives, normalize
  newlines, decode and re-encode text, or add synthetic bytes.
- Dependency traversal is depth-first in written import order. Dependencies
  precede importers, and repeated or diamond imports are emitted once.
- Physical identity uses canonical real paths. Public identity uses unique,
  normalized, project-relative `/` paths that are printable ASCII and between
  1 and 255 bytes.
- The resolver rejects root escape, symlink escape, alias ambiguity, missing
  files, cycles, malformed directives, late directives, and a final lone CR in
  directive-looking text.
- The final graph contains at most eight source parts and satisfies the exact
  compiler input-window bound:

  ```text
  5 * partCount + sum(raw source byte lengths) <= 2048
  ```

- Project schema v1 and multiple positional CLI sources retain explicit written
  order. Project schema v2 and one positional entry use dependency discovery.
- Logical `sourceBanks` names are an authoring join only. The host derives the
  final ordinal `partBanks[]` after ordering, then submits a complete target to
  the compiler. The compiler contract remains ordinal and filename-free.
- Unspecified banked parts use `entryBank`; the entry source must use
  `entryBank`; flat targets reject `sourceBanks`.
- The public target parser accepts only complete compiler targets. A distinct
  layout-document validator admits a banked authoring profile before the host
  derives `partBanks[]`.

## Compiler boundary

No grammar, token, keyword, parser table, compiler workspace, runtime, or Z80
source changed for import discovery.

The host still calls the multipart compiler entry with:

- `A = 1..8`, the ordered part count;
- `HL` pointing to stable five-byte descriptors
  `[id:u8, start:u16le, end:u16le]`;
- `IX` pointing to the stable fifteen-byte target descriptor; and
- target-descriptor word `+13` pointing to one bank byte per final source-part
  ordinal.

The descriptors, bank array, and source bytes remain resident for the complete
compile. Per-part positions begin at offset 0, line 1, column 1. Boundary
newlines, diagnostic identity, D8 reconstruction, the `main` bank rule, and
same-bank forward completion retain their existing behavior.

## Public host surfaces

The implementation includes:

- `resolveNucleusImportGraph()` for deterministic discovery with direct
  dependency metadata;
- `resolveNucleusImports()` as the source-list compatibility wrapper;
- `prepareNucleusProject()` for one reusable project preparation path;
- `buildNucleusProject()` for preparation plus an injected or default compiler;
- `parseNucleusSourcePlan()` and `serializeNucleusSourcePlan()` for SP1; and
- CLI project and single-entry modes routed through the shared project path.

Each prepared dependency records its logical name, direct imports, raw byte
length, and SHA-256 digest. `sourcePlan` records the final order and bank ordinal
for a portable filesystem-host handoff; it contains no target layout.

## SP1 source plan

SP1 is intentionally small enough for a filesystem-aware Z80 host:

```text
SP1 count
P bank byteLength path
...
END
```

Paths are normalized project-relative printable ASCII identities of 1 through
255 bytes. The parser and serializer reject absolute paths, backslashes, empty
segments, `.` or `..` segments, trailing separators, control bytes, non-ASCII
bytes, and lengths outside the encoded range.

## Review repairs

The adversarial review found and the implementation repaired these defects:

1. SP1 accepted canonical parent traversal.
2. The serializer could emit a path longer than its parser could decode.
3. Filename-to-bank lookup read inherited object properties such as
   `constructor`.
4. A public assertion option could represent an incomplete banked layout as a
   complete compiler target.
5. The documents did not distinguish filename-based project authoring from the
   ordinal compiler contract.
6. Resolver identities were not all guaranteed to be SP1-encodable.
7. The scanner treated a final lone CR as though it terminated a CRLF line.

The strengthened tests cover exact source-window fill and first overflow, v1
explicit order, cycles, late directives, path boundaries, prototype-bearing
filenames, strict target assertion, bank derivation, D8 identity, and Debug80's
shared project path.

## Verification

The final Nucleus branch passed:

- 176 tests;
- typecheck and build;
- compiler-image verification;
- package installation and public-API smoke testing;
- focused formatting and prose checks; and
- `git diff --check`.

The installed-package smoke test compiles and launches the packaged
`examples/import-project` project and verifies its dependency hashes. Explicit
v1 ordering and discovered v2 ordering produce byte-identical NOBJ and D8
source identities for equivalent inputs.

Debug80 consumes the shared Nucleus project preparation path on
`codex/nucleus-node-host`; it no longer contains a second dependency resolver.
Its integration tests cover v1 projects, v2 discovery, flat-target launch, and
the explicit/discovered artifact differential.

## Deliberate boundaries

- The dependency resolver remains in the standalone Nucleus host for now. A
  later synchronization may move shared host services into the Debug80
  monorepo.
- Atom has not been modified as part of this work.
- Machine profiles remain host-owned. No TEC-1 or CP/M profile is published
  until its external service destinations and launch behavior are complete and
  tested.
- Running is target-specific. SP1 is the portable source-order handoff; it is
  not a generic target runner or memory-layout format.
- Registry publication of `@jhlagado/debug80-runtime` remains an external
  release step. The package, isolated smoke gate, `prepublishOnly` checks, and
  GitHub release workflow are ready, but npm authentication or trusted-publisher
  authorization is required before the first release.
