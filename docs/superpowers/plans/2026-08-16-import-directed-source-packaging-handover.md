# Handover: Import-Directed Nucleus Source Packaging

**Status:** Implementation complete on the isolated branch; post-repair adversarial review **SAFE**; final verification passed.

**Working tree:** `/Users/johnhardy/projects/debug80/.worktrees/nucleus-import-host`

**Branch:** `codex/nucleus-import-host`

**Base commit:** `562bf79d2b8a1a017c0bfcd35a539d2509d17b36` on `compiler-rewrite-12k`

**Primary implementation plan:** [2026-08-16-import-directed-source-packaging.md](./2026-08-16-import-directed-source-packaging.md)

## Objective

Finish the Node-host implementation of import-directed source packaging for Nucleus.

A Nucleus file may place directives such as this in its leading comment header:

```nu
//% import "lib/io.nu"
```

The host discovers dependencies, orders each source part once before its importer, and feeds the unchanged source bytes through the compiler's existing multipart ABI. The Z80 compiler remains unaware of imports and filesystems.

This is local host work for now. The shared resolver may eventually move into a package or app in the Debug80 monorepo and be shared with Atom, but do not modify Atom or Debug80 as part of this branch.

## Settled architecture

- `//% import` is host packaging syntax encoded as an ordinary Nucleus `//` comment.
- The directive is recognized only in the leading header. Blank lines and ordinary comments may appear in that header.
- The first actual Nucleus source line closes the header. A later import directive is an error.
- The host must pass every source file to the compiler byte-for-byte. Do not strip directives, normalize newlines, decode and re-encode UTF-8, or add synthetic bytes.
- Dependency traversal is depth-first and follows written import order. Dependencies precede importers. Repeated and diamond imports are deduplicated.
- Physical identity uses canonical real paths. Public source identity uses unique normalized project-relative `/` paths.
- Root escape, symlink escape, alias ambiguity, missing files, cycles, malformed directives, and late directives are packaging errors.
- The final graph must contain at most eight source parts.
- The exact compiler input-window limit is `5 * partCount + sum(raw source byte lengths) <= 2048`.
- Bank assignments are joined by logical source name only after final dependency order is known.
- Project schema v1 and explicit multipart CLI input remain compatibility paths. Project schema v2 and a single positional entry use discovery.
- `SP1` is a small portable source-plan format for a future filesystem-aware Z80 harness. It records final path order and bank ordinal only; it contains no target layout.

## Compiler boundary: do not change it

No grammar, token, keyword, parser table, workspace, runtime, or Z80 code change is required.

The host continues to call the existing multipart compiler entry with:

- `A = 1..8`, the ordered part count;
- `HL` pointing to stable five-byte descriptors `[id:u8, start:u16le, end:u16le]`;
- `IX` pointing to the stable fifteen-byte target descriptor;
- target descriptor word at offset `+13` pointing to one bank byte per final source-part ordinal.

Descriptors, the bank array, and unchanged source bytes must remain resident for the whole compile. Preserve per-part offset/line/column reset, boundary-newline behavior, diagnostic part identity, D8 raw-byte reconstruction, `main` in `entryBank`, and same-bank forward completion.

The compiler audit found that the existing tokenizer already ignores `//% import ...` exactly as an ordinary comment while advancing raw positions correctly. Import discovery therefore has a measured Z80 cost of zero bytes.

## Implemented files

New source and tests:

- `src/source-imports.ts`
- `src/source-plan.ts`
- `test/source-imports.test.ts`
- `test/source-plan.test.ts`
- `docs/source-packaging.md`

Modified host integration:

- `src/project.ts`
- `src/cli.ts`
- `src/configuration.ts`
- `src/index.ts`
- `package.json`
- `test/project.test.ts`
- `test/cli.test.ts`

Modified documentation:

- `README.md`
- `docs/specification.md`
- `docs/host-api.md`
- `docs/host-integration.md`

Generated host outputs currently include `dist/source-imports.*`, `dist/source-plan.*`, and updated host module outputs.

## Implemented behavior

The branch already contains:

1. A byte-preserving import-header scanner.
2. A deterministic filesystem dependency resolver with canonical-root and alias checks.
3. Source-part count and exact 2 KiB input-window capacity checks.
4. `SP1` parsing and serialization:

   ```text
   SP1 count
   P bank byteLength path
   ...
   END
   ```

5. Project v2 with `root`, one `entry`, `target`, optional logical `sourceBanks`, and outputs.
6. Project v1 compatibility with its explicit `sources` list.
7. Single-positional CLI discovery and explicit multi-positional compatibility.
8. Bank assignment after dependency ordering. Unspecified banked parts default to `entryBank`; the entry must be in `entryBank`; flat builds reject `sourceBanks`.
9. Layout-only validation for banked target profiles before project-derived `partBanks` exist. Direct compiler invocation remains strict.
10. Public exports and documentation for the resolver, project v2, and `SP1`.

Before the adversarial review cases were added, the focused matrix passed 30 tests, typecheck passed, and `git diff --check` passed.

## Resolved review record

The following findings describe the pre-repair snapshot. All listed repairs and
proof-strengthening cases are present in the current working tree.

Run:

```sh
npx vitest run test/source-plan.test.ts test/cli.test.ts --reporter=verbose
```

The original run produced three failures and ten passes. Those failures proved
the first three findings before their repairs were applied.

### R1: reject parent traversal in SP1

`parseNucleusSourcePlan()` currently accepts canonical `../main.nu`. The earlier test accidentally declared the wrong byte length, so it failed before testing traversal. The corrected test is now red.

Smallest fix in `src/source-plan.ts`, inside `validatePlanPath`, is to validate slash-separated components exactly as project v2 does. Reject empty, `.` and `..` components. This rejects parent traversal and the currently accepted trailing slash in `src/`.

```ts
if (
  value.split("/").some((part) => part === "" || part === "." || part === "..")
) {
  throw new NucleusSourcePlanError(
    "source path must be normalized and project-relative",
  );
}
```

Keep the existing absolute-path, backslash, empty-segment, `.` segment, ASCII, and normalization checks.

### R2: reject paths that cannot be serialized in SP1

`serializeNucleusSourcePlan()` currently accepts a path longer than 255 bytes and emits a plan that its own parser rejects.

After validating each path, compute its ASCII byte length and reject values outside `1..255` before emitting the record. Use that same measured length in the serialized record.

The red test expects:

```text
source path length must be in the range 1..255
```

### R3: use own-property bank lookups

The CLI currently uses:

```ts
sourceBankOverrides?.[source.name] ?? entryBank;
```

That reads inherited properties. A valid source named `constructor` or `toString` can therefore receive a prototype value instead of the default bank.

Replace it with an own-property check, for example:

```ts
const partBanks = sources.map((source) =>
  sourceBankOverrides !== undefined &&
  Object.hasOwn(sourceBankOverrides, source.name)
    ? sourceBankOverrides[source.name]!
    : entryBank,
);
```

Do not solve this by banning otherwise valid filenames.

### R4: do not let incomplete authoring profiles escape as compiler targets

`allowMissingPartBanks` is currently part of the exported assertion options accepted by `assertNucleusTarget()` and `parseNucleusTargetProfile()`. Those APIs can therefore return a value typed as a complete banked `NucleusTarget` even though `partBanks` is absent. Downstream code can silently manufacture an all-zero/default mapping from this incomplete value.

Keep layout-only validation private and distinct from the public complete-target assertion. The public target type and ordinary parser must continue to require `partBanks` for a banked compiler target. Project v2 may validate a target-profile document without `partBanks`, but that incomplete document must not be represented as a complete `NucleusTarget`; join `sourceBanks` to final ordinals first, then call the strict assertion.

Add a focused configuration/CLI discriminator proving:

- public `parseNucleusTargetProfile()` still rejects a banked target without `partBanks`;
- the project-v2/`target validate` authoring path can validate the same layout document through its explicitly incomplete profile validator;
- compilation receives a strict final target containing the derived ordinal array.

### R5: distinguish authoring names from the ordinal compiler contract

The active target authority says bank mapping is ordinal and does not key on filenames. Project v2's `sourceBanks` does not change that rule: it is an authoring convenience used by the host before compilation. The host resolves and orders sources, joins logical names to ordinals once, and passes only the final `partBanks[]` array through the existing compiler descriptor.

Update `docs/target-system-specification.md`, `docs/host-api.md`, and related wording so this separation is explicit. Do not describe an incomplete project-v2 target JSON object as a complete compiler target profile.

Also correct `docs/host-integration.md`: Debug80 does **not** yet consume project v2 or perform import discovery. This branch is intentionally local to the standalone Nucleus host. Debug80 integration and extraction into a shared package are later synchronization work.

### R6: make every published logical identity SP1-encodable

Project validation and the resolver currently accept control characters, non-ASCII names, and arbitrarily long logical paths, while SP1 requires printable ASCII and a one-byte path length. A valid project-v2 discovery result can therefore fail when serialized into the portable plan that is meant to carry the same identities.

Create one shared logical-identity validator and use it for project `entry`, project `sourceBanks` keys, resolver output identities, and SP1 parsing and serialization. The final identity must be normalized, project-relative, `/`-separated printable ASCII and 1–255 encoded bytes.

Import specifiers themselves may contain `..` when filesystem resolution remains within the canonical project root. Validate the final resolved identity, not every raw specifier with the stricter rule.

Add cross-surface tests for non-ASCII, control bytes, 255-byte acceptance, 256-byte rejection, `.`/`..` components, and trailing slash.

### R7: preserve lone-CR lexical behavior

The import scanner currently strips a final `\r` even when it is not followed by `\n`. Nucleus treats a lone CR as a lexical error. The host can therefore discover and read a dependency from malformed source before the compiler reports the intended lexical diagnostic.

Strip `\r` only from a line segment actually terminated by the `\n` split. Add a test whose final import-looking line ends in lone CR and prove it is not accepted as a valid packaging directive.

### Proof strengthening after repairs

Add or confirm:

- exact-fill and first-overflow tests for `5 * partCount + raw bytes <= 2048`;
- a v1 CLI regression proving explicit written source order is unchanged;
- end-to-end project-v2 JSON diagnostics for a cycle and a late directive.

## Remaining integration step

The branch base is still the current compiler head, `562bf79`. If that branch
moves before integration, rebase onto its frozen head and rerun every gate.
Otherwise the implementation is ready to commit and push from the isolated
branch.

## Verification commands

From the worktree root:

```sh
npx vitest run test/source-imports.test.ts test/source-plan.test.ts test/project.test.ts test/cli.test.ts test/compiler.test.ts --reporter=verbose
npm run typecheck
npm run build
npm test
npm run check:compiler-images
git diff --check
git status --short
```

Also inspect the complete diff and prove that no file under `asm/`, no grammar file, no runtime source, and no generated compiler image changed because of this host feature.

The post-repair run passed the compiler-image check on base `562bf79`; no
generated compiler image is part of this host feature's diff.

## Completion evidence to report

The final report should state:

- exact final base and host commit;
- focused and full test counts;
- typecheck, build, formatting, compiler-image, and diff-check results;
- byte identity of explicit versus discovered NOBJ and D8 source identity evidence;
- measured Z80 deltas: compiler code `0`, immutable data `0`, compiler core `0`, workspace `0`, semantic transcript `0`, generated program `0`, runtime `0`;
- Node/host files added or changed, reported separately;
- confirmation that project v1 and explicit multipart CLI behavior remain available;
- confirmation that no Atom or Debug80 shared-package migration was attempted in this increment;
- any intentionally deferred shared-package work.

## Do not do

- Do not implement imports in the Z80 compiler.
- Do not add a Nucleus grammar token or production.
- Do not strip or rewrite directive bytes.
- Do not implement Atom conditional preprocessing here.
- Do not move the resolver into Debug80 yet.
- Do not reduce the eight-part or 2 KiB capacities.
- Do not include unrelated compiler-rewrite generated files in the commit.
- Do not merge into the moving compiler branch before it is frozen.
