# Nucleus compiler rewrite: coding-agent handover

## The assignment

Finish the ground-up replacement of the standalone Nucleus Z80 compiler. Work
autonomously from the frozen oracle and the current rewrite branch until the
replacement is the production compiler and the old implementation has been
removed. Do not narrow the language, preserve an architectural accident merely
because it exists in the old compiler, or call an intermediate substrate a
finished compiler.

The replacement must implement the complete Nucleus 0.1 language and preserve
the published Host API, diagnostics, runtime ABI, NOBJ, HEX, D8, banking,
failure, relocation, and artifact contracts. The production compiler core—code
plus immutable data—has a hard ceiling of 16,384 bytes. The design target is
12–14 KiB.

Use the `z80-engineering` skill throughout. Keep strict AZM register contracts
enabled. Commit and push every verified checkpoint, then start the next
checkpoint without waiting for another prompt.

## Repository and authority

- Standalone Nucleus worktree:
  `/Users/johnhardy/projects/debug80/.worktrees/nucleus-bounded-text`
- Branch: `codex/compiler-rewrite`
- Compiler-source base HEAD before this document-only handover commit:
  `dd6877bf3d1afae569c1d207bb4d1dcf804bc5ad`
- Last complete implementation checkpoint:
  `c426b0343a05b334b3a49cc88814d3a1aec701f8`
- Frozen baseline tag: `rewrite-baseline-2026-08-16`
- Frozen baseline commit: `0382f73fe3bc29e86496b92334287139c2de92f1`
- Architecture and milestone plan:
  `docs/plans/2026-08-16-ground-up-compiler-rewrite.md`
- Normative language authority: `docs/specification.md`
- Z80/runtime authority: `docs/z80-runtime-contract.md`
- Reviewer invariants: `docs/reviewers-charter.md`
- Frozen behavior fixture: `test/fixtures/rewrite-oracle.json`
- Frozen oracle gate: `test/rewrite-oracle.test.ts`

This is an existing linked worktree. Confirm the path, branch, HEAD, and status
before touching a file. Do not recreate the worktree and do not work from the
Debug80 repository root.

The specification outranks accidental baseline behavior. If the baseline and
specification conflict, make an explicit authority decision. Record every
deliberate conformance correction in the rewrite plan and lock it with a
permanent test. Otherwise preserve the exact accepted or rejected source and
the diagnostic code, part, byte offset, line, and column. Never move the
baseline tag or edit the oracle merely to make a replacement failure green.

## Exact state at handover

### Clean committed checkpoint

The last accepted implementation is `c426b034`. Commit `dd6877bf` adds the
previous handover document but does not change compiler behavior.

| Account | Value | Status |
| --- | ---: | --- |
| Replacement shipping code | 2,989 bytes | Measured |
| Replacement immutable data | 939 bytes | Measured |
| Replacement shipping core | 3,928 bytes | Measured |
| Replacement debug core | 3,932 bytes | Measured |
| Replacement workspace | 3,347 bytes | Measured |
| Frozen production core | 16,680 bytes | Measured |
| Full serial gate | 32 files / 331 tests | Measured |
| Overall rewrite completion | about 36 percent | Hypothesis |

The replacement is not yet a usable compiler. Its public entry validates the
lexical stream and then raises internal-operation diagnostic 67. The small core
therefore cannot be compared with the feature-complete baseline as if parity
had been reached.

### Uncommitted constant-expression prototype

The worktree is deliberately dirty. Preserve these files until their design has
been evaluated; do not discard or commit them blindly:

- modified `asm/rewrite/compiler-image.asmi`;
- modified `asm/rewrite/state.asmi`;
- untracked `asm/rewrite/constant-expression.asm`; and
- untracked `asm/rewrite/constant-expression-data.asmi`.

The prototype is the first mode of the shared R4 precedence-climbing engine. It
was brought forward because the R3 type parser must accept the complete scalar
constant-expression language in array and bounded-string bounds. A second,
literal-only bound evaluator would create two subtly different expression
languages and is not acceptable.

The draft currently contains:

- a compact token/precedence table for the binary operators;
- exact, typed, signed, unsigned, and Boolean constant carriers;
- literal, name, grouping, conversion, prefix, and binary parsing;
- exact adoption and typed-width conversion;
- arithmetic, signed and unsigned division/modulo, comparison, and Boolean
  reduction; and
- short-circuit fault suppression and source-offset state.

None of that is delivered yet. There is no execution proof and no accepted size
census for the prototype.

The current strict command is:

```sh
npx vitest run test/rewrite-metadata.test.ts --maxWorkers=1 --reporter=verbose
```

It fails before execution with exactly these two AZM contract diagnostics:

1. `RewriteExpressionEvaluateConstant` at
   `asm/rewrite/constant-expression.asm:35`: stack effect is unknown and the
   stack is reported unbalanced.
2. `RewriteExpressionParsePrecedence` at
   `asm/rewrite/constant-expression.asm:48`: the stack is reported unbalanced.

All earlier syntax, instruction, branch-range, and routine-contract errors in
the draft were repaired. A manual path audit suggests the direct recursive call
to `RewriteExpressionParsePrecedence` may be what prevents AZM from deriving a
summary, but that is a Hypothesis, not a diagnosed assembler defect. Check the
AZM implementation and construct a minimal strict-contract recursion probe
before deciding.

Do not suppress the diagnostic, disable strict contracts, or declare the
routine `noreturn`. If AZM can prove balanced recursion, repair the routine or
AZM with a focused positive and negative test. If strict direct recursion is not
a supported or desirable compiler idiom, replace the hardware-recursive parser
with an explicit bounded expression-frame machine. The latter is a valid fresh
architecture, but measure its code and workspace rather than assuming it is
smaller.

The prototype adds 14 bytes of expression control state before any explicit
frame stack. That workspace delta is Projected because strict assembly has not
completed. The clean checkpoint leaves 749 bytes below the 4,096-byte workspace
ceiling, so an explicit stack can fit only if its complete account remains
within that limit.

## Delivered checkpoints

### R0: frozen oracle and deployment contract

- Baseline tag, hashes, measurements, and representative behavior are frozen.
- Compiler origin, workspace, source, and adapter intervals are deployment
  inputs rather than compiler-address assumptions.
- Relocation is tested at unrelated low, middle, high, and highest-fitting
  origins.

### R1: source adapter and tokenizer

- Ordered multipart source and synthesized inter-part newlines.
- Exact part-relative offsets and Host line/column reconstruction.
- Complete token set, keywords, comments, based integers, strings, characters,
  escapes, and delimiter-kind tracking.
- Exact lexical capacities and transactional reset/reuse.
- Recorded corrections for mismatched delimiters, invalid bytes in comments,
  and character escapes.
- Source/token account is 1,099 bytes, one byte below the R1 exit limit (Measured).

### R2: semantic-stream authority

- `grammar/rewrite-semantic-operations.json` is the single record-format
  authority.
- `scripts/generate-rewrite-operations.mjs` generates Z80 ordinals, operand and
  record offsets, widths, descriptors, backend selectors, and the TypeScript
  decoder.
- The replacement authority contains 99 operation ordinals while preserving
  the producer-active production payload sizes and the 511-byte transcript
  boundary (Measured).
- Producers append atomically; the dispatcher validates the complete stream
  before observing an operation.
- D8 operation-start keys are checked against decoded record boundaries.

### R3 substrate: types, symbols, declarations, static storage

- Compact scalar identities for exact, `u8`, `u16`, `i8`, `i16`, and Boolean.
- Eight owned composite descriptors with separate full-word extents.
- Nominal records and structural bounded strings, fixed arrays, nested arrays,
  `string[]`, and `T[]` identities.
- Complete source-name pointers and lengths; no address truncation.
- Independent bounded directories for records, fields, non-main routines,
  retained parameters, and array suffixes.
- Direct and forward routine lifecycle, forward `main`, delayed parameter
  visibility, scope rewind, exact activation offsets, and namespace checks.
- Explicit eight-byte symbol records with a separate storage-segment byte and
  an unmodified full-width payload.
- Separate complete-initializer scratch, retained static image, and BSS
  accounting.
- Initialized data is a prefix and aggregate constants are a suffix. Inserting
  initialized data shifts constants high-to-low without changing their
  suffix-relative offsets.
- Exact-fill, first-overflow, rollback, guard-byte, reset, and segment-identity
  proofs.

### Front-action substrate

- `grammar/rewrite-front-actions.json` defines the fixed-width action
  instruction set and escape selectors.
- `scripts/generate-rewrite-actions.mjs` generates matching Z80 and TypeScript
  views.
- The current action set is `End`, `Expect`, `Escape`, and `Raise`.
- Escape dispatch uses dense selectors and a generated directory of complete
  16-bit handler addresses.
- Parser `peek` and `take` share one cached token.
- Action escapes are non-nested because the compact machine retains one cursor.
  Add a proved cursor stack before allowing recursive action execution.
- Source and distribution decoders reject invalid ordinals, escape selectors,
  truncation, missing `End`, and trailing bytes.

## First work for the receiving agent

### 1. Preserve and classify the prototype

Run:

```sh
cd /Users/johnhardy/projects/debug80/.worktrees/nucleus-bounded-text
git status --short --branch
git rev-parse HEAD
git diff --check
git diff -- asm/rewrite/compiler-image.asmi asm/rewrite/state.asmi
npx vitest run test/rewrite-metadata.test.ts --maxWorkers=1 --reporter=verbose
```

Read `asm/rewrite/constant-expression.asm` from beginning to end. Check every
hardware-stack path, including recursive binary parsing, prefix parsing,
grouping, conversions, short-circuit suppression, comparison rejection, and
the nonreturning diagnostic exits.

Then build a minimal strict AZM recursion fixture outside Nucleus. Determine
whether the remaining error is:

- a genuine PUSH/POP or control-flow defect in the draft;
- a missing routine boundary or contract;
- an AZM summary limitation for recursive calls; or
- evidence that explicit parser frames are the better architecture.

Report that result before changing AZM. AZM does not write the assembly source;
an invalid instruction or invalid stack design remains the compiler author's
responsibility.

### 2. Finish one reusable constant evaluator

The accepted evaluator must cover the specification's complete constant
expression language:

- integer, Boolean, character, and earlier scalar named constants;
- parentheses and the legal prefix operators;
- all arithmetic, comparison, and Boolean binary operators with the published
  precedence and left association;
- exact literal adoption, signed promotion, and explicit conversions;
- typed wrapping, exact overflow diagnostics, narrowing diagnostics, and
  divide/modulo by zero;
- single-comparison enforcement;
- Boolean short circuit without evaluating a suppressed fault; and
- exact diagnostic code and source position.

Do not infer correctness from assembly alone. Add a strict executable proof and
a TypeScript test that discriminate at least:

- every precedence level and left association;
- grouped and nested expressions;
- both left and right mixed signed-width promotion;
- exact minima and maxima for all integer types;
- one-outside narrowing and exact-range failures;
- signed division and modulo, including the minimum divided by negative one;
- comparison-chain rejection;
- `false and` and `true or` suppressing a divide-by-zero right side;
- unknown-name, non-constant-name, non-scalar, and wrong-context failures;
- exact maximum expression nesting and first overflow; and
- reset and successful evaluation immediately after a failure.

Only after that proof is green should the constant evaluator become a committed
checkpoint.

### 3. Build the shared source type parser over that evaluator

Use one parser for variables, constants, fields, parameters, locals, and
routine results. It must cover:

- the five concrete scalar types;
- earlier record names;
- concrete `string[N]`, where the evaluated capacity is in the published
  range;
- parameter-only `string[]`;
- fixed-array suffixes with full-word positive evaluated bounds;
- nested arrays applied innermost-first;
- parameter-only outer `T[]`; and
- the exact suffix-capacity boundary and illegal inner or repeated open forms.

Concrete bounds use the just-proved evaluator. Never introduce a literal-only
shortcut. Apply retained suffixes in reverse because the collector stores them
outermost-first. Preserve the closing-bracket token position when an owning or
result position rejects an open view; existing oracle cases distinguish that
position from the following newline or equals token.

### 4. Finish R3 declaration programs and initializers

Generate real front-action programs for constants, variables, records, fields,
routine headers, parameters, results, failure clauses, locals, `main`, and EOF
completeness. The generator must validate every boundary, operand, escape, and
final `End`.

Keep parameter names invisible until the complete header succeeds. Preserve
the established capacity precedence. Keep main outside the ordinary routine
directory and preserve the direct/forward-main lifecycle.

Preflight static destinations before building scratch so source-visible
capacity diagnostics retain their precedence. Zero the complete candidate,
then construct scalars, records, arrays, nested arrays, bounded strings,
aggregate constants, and initialized variables recursively. On failure, do not
publish a symbol or alter retained bytes, counters, or guard values.

R3 exits only when the complete declaration/type/initializer oracle is green
and the migrated family is at least 20 percent smaller than its frozen resident
account (Projected gate until the complete family can be measured).

## Remaining subsystem sequence

### R4: runtime expressions, postfix paths, and calls

Extend the same expression parser into runtime mode. Use one primary engine and
one type-directed postfix engine for fields, indexing, `.length`, `.capacity`,
calls, assignment targets, and arguments. Preserve exact adoption, signed
promotion, open views, nested calls, recursion, failable-call consumption,
trap offsets, and semantic-record widths.

Exit gate: at least 25 percent smaller than the frozen expression/path/call
family (Projected), with accepted source, diagnostics, transcript boundaries,
target behavior, and stack restoration proved.

### R5: statements and structured control

Implement assignment, calls, `if`/`elseif`/`else`, `while`, programmer-typed
counted loops, `return`, `fail`, `exit`, `continue`, `else fail`, and `handle`.
Use action programs for regular sequencing and measured handwritten escapes for
stateful control frames. Preserve signed and unsigned loop behavior,
overshoot-before-store, fallthrough analysis, failure cleanup, and exact source
attribution.

### R6: scalar backend recipes

Build a generated recipe interpreter and migrate a representative scalar
operation group before committing to it. Recipes may emit literal runs,
operands, runtime calls, labels, fixups, and width/signed variants. Measure any
runtime-kernel trade against compiler bytes, runtime bytes, generated-program
bytes, instructions, and T-states.

### R7: complete backend and artifacts

Finish aggregates, calls, strings, open arrays, control flow, failure paths,
banked output, target layout, runtime linking, NOBJ, HEX, D8, and transactional
publication. Normal and debug compilers must produce byte-identical target
artifacts for the same source. D8 must accept only real semantic-record
boundaries.

### R8: parity, cutover, and removal

Run the entire frozen corpus and every recorded conformance correction through
both compilers. Prove Host diagnostics, flat and banked artifacts, runtime
behavior, traps, source maps, failure recovery, subsequent compilation, and
relocation. Enforce the 16,384-byte hard gate and report the final measured
core. Only then switch the Host to the replacement, remove the old compiler and
stage lattice, regenerate shipped artifacts, update all documentation, and tag
the cutover.

## Architectural rules that cannot be traded away

1. **No origin assumptions.** Compiler code may be deployed anywhere it fits
   in the Z80 address space. Code addresses and data pointers remain complete
   16-bit values. Never steal a supposedly unused address bit.
2. **No disguised compiler instructions.** Do not encode compiler-executed Z80
   instructions with `.db` or `.dw`. Those directives are valid for tables,
   action programs, recipes, target-code templates, proof input, and full-width
   directories. Label non-obvious data explicitly. If AZM cannot express a
   legal instruction, report and justify the assembler workaround first.
3. **No `RST` compression.** Preserve ordinary calls and deployment freedom.
4. **Diagnostics are terminal.** The compiler uses a proved nonreturning SP
   restore. Do not reintroduce carry-propagation ladders. This compile-time
   mechanism is separate from source-level `fails`, `else fail`, and `handle`.
5. **Target failures stay explicit.** Generated programs retain the published
   conditional-return/branch ABI, cleanup, traps, and error values.
6. **The semantic stream remains transactional.** Preserve record widths,
   exact-fill behavior, atomic append, validation-before-observation, and D8
   boundary checks.
7. **Strict contracts remain on.** Every proof uses
   `registerContracts: "strict"`. Any stack or contract finding blocks the
   checkpoint.
8. **Workspace remains bounded.** The ceiling is 4,096 bytes. Measure every
   addition and prefer an explicit proved overlay or deployment-backed bulk
   store over silent growth.
9. **The old compiler remains the oracle until cutover.** Remove it only in R8
   after complete parity and artifact gates pass.
10. **No undocumented compression trick.** If an optimization depends on code
    as data, a generated template, unusual stack behavior, or an assembler
    limitation, explain the mechanism and prove it before committing.

## Checkpoint gate

Run focused tests while editing. Before every checkpoint, run:

```sh
npm run check:azm-toolchain
npm run check:rewrite-operations
npm run check:rewrite-actions
npm run check:compiler-images
npm run check:rewrite-oracle
npm run check:compiler-relocation
npm run typecheck
npm run build
npm test
git diff --check
```

`npm test` is intentionally serial. A timeout under load is not semantic
success; rerun the exact test alone and then restore the full serial gate.

After `npm run build`, compare the source and distribution generated modules.
Both are shipped. Generated authorities and compiler images are checked in, so
stale output blocks publication.

For compiler census, use a target-enabled proof or the current replacement
metadata/action proof. Never use `stage9-conformance`; it omits target output
and understates the production compiler.

For each checkpoint, report compiler code, immutable data, core, remaining
headroom, workspace, largest generated program, runtime, NOBJ, instructions,
and T-states when the stage can affect them. Mark every numerical account as
Measured, Projected, or Hypothesis. Measure after the stage rather than batching
several stages into one census.

## Commit discipline

A checkpoint is ready only when:

- the focused proof is discriminating and green;
- normal and debug layouts assemble under strict contracts;
- relocation is proved at unrelated origins;
- exact-fill and first-overflow behavior execute;
- diagnostic code and complete source position are locked;
- failure leaves counters, retained bytes, and guard values unchanged;
- generated authorities, source modules, distribution modules, and compiler
  images are synchronized;
- the full serial gate passes;
- measurements and plan ledgers are current; and
- an adversarial review has no unresolved important finding.

Commit only the files belonging to that checkpoint. Push the branch, verify the
remote commit, and continue. Do not fold the current unproved expression draft
into an unrelated documentation or substrate commit.

## Definition of finished

The work is finished only when the replacement compiles the complete Nucleus
0.1 language, the frozen and corrected conformance corpus passes, normal and
debug target artifacts match, all Host and runtime contracts pass, the compiler
relocates without origin assumptions, the measured production core is no more
than 16,384 bytes, the Host uses the replacement, and the old compiler has been
removed. A parser substrate, a semantic decoder, or a small incomplete image is
progress, not completion.
