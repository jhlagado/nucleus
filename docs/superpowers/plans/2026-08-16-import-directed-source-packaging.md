# Import-Directed Source Packaging Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the Node host discover ordered Nucleus source parts from leading `//% import "..."` comments while leaving the Z80 compiler, grammar, source bytes, diagnostics, D8 mappings, and explicit ordered-source APIs unchanged.

**Architecture:** A pure header scanner recognizes import comments without rewriting bytes. A filesystem resolver performs deterministic depth-first dependency ordering and returns the existing `NucleusSourcePart[]` shape. A separate `SP1` parser/serializer records the resolved order and bank ordinal for a future Z80 filesystem harness. Project schema v2 selects one entry file; project v1 and explicit multipart builds remain compatibility paths.

**Tech Stack:** TypeScript 5, Node 20 filesystem/path APIs, Vitest, existing Nucleus Host API 1 and Z80 multipart compiler ABI.

---

## File structure

- Create `src/source-imports.ts`: parse leading Nucleus import comments and resolve a filesystem dependency graph.
- Create `src/source-plan.ts`: canonical `SP1` source-plan parser and serializer.
- Modify `src/project.ts`: retain project v1 and add discriminated project v2 with one entry and optional logical source-bank mapping.
- Modify `src/cli.ts`: choose explicit v1 ordering or v2/single-entry dependency discovery, derive ordinal bank assignments, and preserve existing artifact publication.
- Modify `src/index.ts` and `package.json`: export the host packaging interfaces.
- Create `test/source-imports.test.ts` and `test/source-plan.test.ts`; extend `test/project.test.ts` and `test/cli.test.ts`.
- Modify `docs/specification.md`, `docs/host-api.md`, `docs/host-integration.md`, and `README.md`; create `docs/source-packaging.md` for the host/Z80 source-plan contract.

### Task 1: Import header scanner

**Files:**

- Create: `src/source-imports.ts`
- Create: `test/source-imports.test.ts`

- [ ] Write failing tests showing that `//% import "lib/io.nu"` is recognized only in the leading header; blank lines and ordinary comments may surround it; source bytes are not changed; LF, CRLF, and a missing final newline work; malformed or late directives fail with a `NucleusConfigurationError` and exact logical source/line context.
- [ ] Run `npx vitest run test/source-imports.test.ts` and verify failure because the module is absent.
- [ ] Implement `parseNucleusImportHeader(name: string, bytes: Uint8Array): readonly string[]`. Decode only accepted ASCII bytes, preserve the input array, accept horizontal space around directive components, require one quoted nonempty relative path, and reject trailing text.
- [ ] Run the focused test and verify it passes.

### Task 2: Deterministic dependency resolver

**Files:**

- Modify: `src/source-imports.ts`
- Modify: `test/source-imports.test.ts`

- [ ] Add failing temporary-directory tests for dependency-before-importer ordering, written sibling order, diamond deduplication, repeated imports, missing files, direct and indirect cycles with their chains, project-root escape, symlink/path alias ambiguity, and normalized project-relative `/` identities.
- [ ] Run the focused test and verify the new cases fail.
- [ ] Implement `resolveNucleusImports({ root, entry }): Promise<readonly NucleusSourcePart[]>` using three-state depth-first traversal. Resolve imports relative to the importer, canonicalize physical identity for graph state, reject escape from the real project root, and retain the first normalized project-relative logical identity only when it is unambiguous.
- [ ] Enforce the published source-part capacity before invoking the compiler.
- [ ] Run the focused test and verify it passes.

### Task 3: SP1 source plan

**Files:**

- Create: `src/source-plan.ts`
- Create: `test/source-plan.test.ts`

- [ ] Write failing tests for canonical LF serialization, LF/CRLF parsing, decimal count, `P <bank> <byte-length> <path>` records, normalized slash paths, required `END`, exact record count, length mismatch, invalid bank, invalid path bytes, trailing records, and serialize-parse-serialize stability.
- [ ] Run `npx vitest run test/source-plan.test.ts` and verify failure because the module is absent.
- [ ] Implement `NucleusSourcePlanPart`, `parseNucleusSourcePlan(text)`, and `serializeNucleusSourcePlan(parts)`. Keep the format ASCII, bounded by caller-supplied or exported capacities, and independent of target origins, services, and filesystem root.
- [ ] Run the focused test and verify it passes.

### Task 4: Project v2

**Files:**

- Modify: `src/project.ts`
- Modify: `test/project.test.ts`

- [ ] Add failing tests proving v1 still requires and preserves `sources`, while v2 requires `entry`, rejects `sources`, accepts an optional `sourceBanks` object keyed by normalized logical path, rejects invalid bank ordinals and unknown fields, and retains target/output handling.
- [ ] Run `npx vitest run test/project.test.ts` and verify failure.
- [ ] Introduce `NUCLEUS_PROJECT_V1_SCHEMA`, `NUCLEUS_PROJECT_V2_SCHEMA`, discriminated `NucleusProjectV1 | NucleusProjectV2`, and keep `NUCLEUS_PROJECT_SCHEMA` as the v1 compatibility alias.
- [ ] Run the focused test and verify it passes.

### Task 5: CLI discovery and bank derivation

**Files:**

- Modify: `src/cli.ts`
- Modify: `src/configuration.ts` only if project-derived `partBanks` requires a host-profile validation split.
- Modify: `test/cli.test.ts`

- [ ] Add failing CLI tests for one positional entry discovering imports, project v2 discovery, equivalent explicit/discovered NOBJ and D8 source identities, cycle/missing/late-directive configuration failures, and unchanged v1 explicit ordering.
- [ ] Add banked-project tests proving logical `sourceBanks` keys are joined after ordering, unspecified parts default to `entryBank`, unknown keys fail, and the entry part cannot be assigned away from `entryBank`.
- [ ] Run `npm run build && npx vitest run test/cli.test.ts` and verify the new cases fail for missing discovery.
- [ ] Implement the minimal integration. A single positional source and project v2 use discovery. Multiple positional sources and project v1 retain explicit order. Derive `partBanks[]` only after resolution and pass the existing ordered `sources` and target object to `compiler.build()`.
- [ ] Keep the low-level compiler and host APIs unchanged. If target-profile validation currently requires positional `partBanks` too early, separate authoring-profile validation from the final compiler target without changing the compiler descriptor.
- [ ] Rebuild and run the focused CLI tests until green.

### Task 6: Public exports and documentation

**Files:**

- Modify: `src/index.ts`
- Modify: `package.json`
- Create: `docs/source-packaging.md`
- Modify: `docs/specification.md`
- Modify: `docs/host-api.md`
- Modify: `docs/host-integration.md`
- Modify: `README.md`

- [ ] Export the import resolver and source-plan interfaces from the package root and explicit subpath exports.
- [ ] Document `//% import` as a packaging directive encoded in an ordinary comment, not a grammar token or declaration.
- [ ] Replace the specification claims that standard packaging performs no dependency discovery. Retain the flat ordered manifest as a compatibility convention.
- [ ] Specify that Nucleus source bytes remain byte-identical, whereas a future shared Atom adapter may use equal-length masking under a different emission policy.
- [ ] Document deterministic ordering, cycle/missing/root errors, stable logical identity, project v2, SP1, and the unchanged Z80 multipart boundary.
- [ ] Run focused Prettier or the repository's formatting convention over modified Markdown, JSON, and TypeScript files.

### Task 7: Verification and handoff

**Files:**

- Test only; no unrelated production changes.

- [ ] Run `npm run typecheck`.
- [ ] Run `npm run build`.
- [ ] Run `npm test`.
- [ ] Run `npm run check:compiler-images` and prove both shipping and D8 compiler images are unchanged.
- [ ] Run `git diff --check`.
- [ ] Inspect the complete diff for accidental Z80, grammar, NOBJ, runtime, or generated-image changes.
- [ ] Report that Z80 compiler code, immutable data, workspace, semantic transcript, generated program, and runtime deltas are all measured zero; report Node/host changes separately.
- [ ] Rebase or merge only after the compiler-rewrite branch is frozen, rerun the complete gates, then commit and push when requested.
