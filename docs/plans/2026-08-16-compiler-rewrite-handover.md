# Nucleus compiler rewrite handover

## Assignment

Finish the ground-up replacement of the standalone Nucleus Z80 compiler. Work
autonomously from the frozen baseline and the current rewrite branch until the
replacement is the production compiler and the old compiler has been removed.
Do not narrow the language or declare success at an intermediate checkpoint.

The finished compiler must preserve the complete Nucleus 0.1 language and all
published Host API, diagnostic, runtime, NOBJ, HEX, D8, banking, failure, and
artifact contracts. Its production compiler core—code plus immutable
data—must not exceed 16,384 bytes. The design target is 12–14 KiB.

Use the `z80-engineering` skill throughout. Use an independent adversarial
review before committing each substantial checkpoint. Commit and push every
verified checkpoint, then continue to the next one without waiting to be
prompted.

## Repository and authority

- Standalone repository worktree:
  `/Users/johnhardy/projects/debug80/.worktrees/nucleus-bounded-text`
- Branch: `codex/compiler-rewrite`
- Implementation checkpoint immediately preceding this handover:
  `c426b0343a05b334b3a49cc88814d3a1aec701f8`
- Frozen baseline tag: `rewrite-baseline-2026-08-16`
- Frozen baseline commit: `0382f73fe3bc29e86496b92334287139c2de92f1`
- Detailed architecture and milestone plan:
  `docs/plans/2026-08-16-ground-up-compiler-rewrite.md`
- Normative language authority: `docs/specification.md`
- Z80/runtime authority: `docs/z80-runtime-contract.md`
- Frozen oracle fixture: `test/fixtures/rewrite-oracle.json`
- Frozen oracle gate: `test/rewrite-oracle.test.ts`

The specification outranks accidental baseline behavior. A deliberate
specification correction must be recorded in the rewrite plan's conformance
ledger and locked by a permanent test. Otherwise preserve the baseline's exact
accepted/rejected source, diagnostic code, part, byte offset, line, and column.

Never regenerate or silently move the baseline tag. Do not update the oracle
merely to make a replacement failure green.

Begin by confirming the worktree, branch, HEAD, and clean status. This is an
existing linked worktree; do not recreate it or accidentally work from the
Debug80 repository root.

## Current measured state

At `c426b034`:

| Account                    |         Measurement |
| -------------------------- | ------------------: |
| Replacement shipping code  |         2,999 bytes |
| Replacement immutable data |           941 bytes |
| Replacement shipping core  |         3,940 bytes |
| Replacement debug core     |         3,944 bytes |
| Replacement workspace      |         3,347 bytes |
| Frozen production core     |        16,680 bytes |
| Full test gate             | 32 files, 331 tests |

The 3,940-byte replacement is incomplete and is not yet a usable Nucleus
compiler. Its public entry currently validates the lexical stream and then
raises internal-operation diagnostic 67. Do not compare its present size with
the complete baseline as though feature parity had been reached.

Estimated overall rewrite completion at handover is about 36 percent. This is
a planning estimate, not a measured conformance percentage.

## What has been delivered

### R0: frozen oracle and deployment contract

- Baseline tag, commit, hashes, measurements, and representative behavior are
  frozen.
- Compiler origin, workspace, source, and adapter intervals are supplied by
  deployment composition.
- Relocation is tested at zero, `$0100`, `$6000` with relocated workspace,
  `$8000`, and the highest fitting origin.

### R1: source adapter and tokenizer

- Ordered multipart source input and synthesized inter-part newlines.
- Exact part-relative byte positions and Host line/column reconstruction.
- Complete token set, keywords, comments, based integers, quoted strings and
  characters, escapes, delimiter-kind stack, and exact lexical capacities.
- Specification corrections for mismatched delimiters, invalid bytes inside
  comments, and character escapes are recorded and tested.
- Source/token account is exactly 1,100 bytes, the R1 exit limit.

### R2: semantic stream authority

- `grammar/rewrite-semantic-operations.json` is the single operation-format
  authority.
- `scripts/generate-rewrite-operations.mjs` generates Z80 ordinals, operand
  offsets, widths, descriptors, backend selectors, and the TypeScript decoder.
- The 99 replacement operations retain every producer-active production
  record width and the 511-byte transcript acceptance boundary.
- Producers append atomically; the dispatcher validates the complete stream
  before observing an operation.
- D8 operation-start keys are checked against decoded record boundaries.

### R3: types, symbols, declarations, and static substrate

- Compact scalar identities for exact, `u8`, `u16`, `i8`, `i16`, and Boolean.
- Eight owned composite descriptors with separate full-word extents.
- Nominal records, structural bounded strings and fixed arrays, nested arrays,
  `string[]`, and `T[]` identities.
- Complete source-name pointers and lengths; no truncated addresses.
- Independent bounded directories for records, fields, non-main routines,
  retained parameters, and array suffixes.
- Direct and forward routine lifecycle, forward `main`, delayed parameter
  visibility, scope rewind, exact activation offsets, and namespace checks.
- Explicit eight-byte symbol records. Storage identity is a separate byte:
  none, initialized, BSS, read-only, or activation. The full 16-bit payload is
  never used to hide a segment flag.
- A 1,024-byte complete-initializer scratch image, a separate 1,024-byte
  retained static image, and an independent 1,024-byte BSS counter.
- Initialized data is the retained prefix and aggregate constants are the
  suffix. Inserting initialized data shifts constants high-to-low while
  preserving their suffix-relative offsets.
- Exact-fill, first-overflow, rollback, zero-length, reset/reuse, and
  initialized/BSS segment-identity proofs.

### Front-action substrate

- `grammar/rewrite-front-actions.json` defines fixed-width front-action
  instructions and handwritten escape selectors.
- `scripts/generate-rewrite-actions.mjs` generates Z80 and TypeScript views.
- Current instructions are `End`, `Expect`, `Escape`, and `Raise`.
- Escapes use dense selectors but a generated directory of complete 16-bit
  addresses. No origin or spare-address-bit assumption is present.
- Parser `peek` and `take` share one cached token.
- Action escapes are deliberately non-nested because the compact machine has
  one retained cursor. Add a proved cursor stack before permitting recursive
  action execution.
- Source and distribution decoders reject invalid ordinals, invalid escape
  selectors, truncation, missing `End`, and trailing bytes.

## Non-negotiable engineering rules

1. **No origin assumptions.** Compiler code may be deployed anywhere in the
   Z80's 64 KiB address space. Every pointer and code address remains a full
   16-bit value. Never take metadata from a supposedly unused address bit.
2. **No disguised instructions.** Do not write compiler-executed Z80 opcodes
   with `.db` or `.dw`. Those directives are valid for tables, action programs,
   recipes, target-code templates, proof input, and full-address directories;
   label them as data. If AZM cannot express a legal instruction, report the
   assembler limitation before using a documented workaround.
3. **No `RST` compression.** Preserve ordinary calls and deployment freedom.
4. **Diagnostics are terminal.** The compiler's diagnostic exit is a proved
   nonreturning SP restore. Do not reintroduce hundreds of carry-propagation
   returns. This compiler mechanism is separate from source-level `fails`,
   `else fail`, and `handle` semantics in generated programs.
5. **Preserve target failure behavior.** Source failures remain explicit
   conditional returns/branches with the established target ABI, cleanup, and
   traps. Do not replace them with compiler-style nonlocal exit.
6. **Measure complete accounts.** Report code, immutable data, core, workspace,
   generated program, runtime, NOBJ, instructions, and T-states when the stage
   touches them. Label estimates as Projected or Hypothesis; do not present
   them as measurements.
7. **Keep strict contracts on.** Every new proof assembly uses
   `registerContracts: "strict"`. A stack-balance or contract diagnostic is a
   blocker.
8. **Workspace remains bounded.** The plan's ceiling is 4,096 bytes. Current
   usage is 3,347, leaving only 749 bytes. Prefer proved lifetime overlays or
   moving bulk compiler data behind the deployment adapter over silently
   exceeding the ceiling.
9. **Do not remove the old compiler early.** Keep it as the executable oracle
   until the replacement passes complete parity, artifact, and target-runtime
   gates. Delete it only in R8 after cutover is proved.
10. **Commit and push milestones.** Keep the tree clean between checkpoints.

## Immediate next work

The active task is R3 declaration programs plus type-directed static
initialization. Implement it in the following order.

### 1. Shared source type parser

Build one authoritative parser used by variables, constants, fields,
parameters, locals, and routine results. It must cover:

- all five concrete scalar types;
- earlier record-type names;
- concrete `string[N]` with capacity 1–253;
- parameter-only `string[]`;
- concrete fixed-array suffixes with full-word positive bounds;
- nested arrays, applied innermost-first;
- parameter-only outer `T[]` views; and
- the exact four-suffix boundary and every illegal inner/repeated open form.

Do not settle on literal-only array bounds. Bounds accept the specification's
constant-expression language, including earlier scalar constants and checked
operators. Reuse the eventual R4 constant evaluator rather than creating a
second expression language. It is acceptable to bring the shared constant
expression core forward as an R3 dependency.

Preserve the original suffix token position when an owning or result position
rejects an open view. Existing oracle tests distinguish the closing bracket
from the following newline or equals token.

### 2. Generated declaration action programs

Extend `rewrite-front-actions.json` with real programs for:

- scalar and aggregate constants;
- program variables with zero or explicit initialization;
- record headers and fields;
- direct and forward routine headers;
- formal parameters and optional result/failure clauses;
- scalar locals; and
- `main` and EOF completeness.

The generator must validate every program boundary, instruction operand,
escape selector, and final `End`. Do not rely only on runtime interpretation of
handwritten `.db` programs. Keep irregular type formation, static initializer
descent, and signature reconciliation as measured handwritten escapes.

Parameter names must remain invisible until the whole header is valid. Retain
the established capacity precedence: duplicate seventeenth parameter reports
55, distinct seventeenth reports 85; a fifth ordinary routine reports 84 before
duplicate-name checks.

### 3. Type-directed initializer escape

Preflight the destination before touching scratch:

- initialized program object overflow reports 81;
- aggregate-constant/read-only overflow reports 93;
- BSS overflow reports 81; and
- initializer nesting beyond four reports 77 at the established source anchor.

The raw 1,024-byte scratch append also has a diagnostic-77 safety boundary, but
source-visible oversized objects must reach 81 or 93 first. Do not let scratch
capacity change diagnostic precedence.

Zero the complete candidate scratch object before applying an explicit
initializer. Then recursively construct:

- scalar constant leaves in little-endian width;
- positional records with exact field count;
- fixed arrays with exact element count;
- nested arrays;
- bounded strings as length byte, payload, zero tail, and permanent
  terminator; and
- complete aggregate constants and initialized variables.

A failed declaration must not publish a symbol or alter retained static bytes,
lengths, or the guard byte. A successful declaration publishes the explicit
storage segment and full segment-relative offset before committing the symbol.

### 4. R3 exit proof and size decision

Run the complete declaration/type/initializer oracle, including every exact
capacity and source-position boundary. Re-measure the entire migrated family,
including action interpreter and programs. It must be at least 20 percent
smaller than the corresponding frozen resident account. If not, stop and
review the action instruction set and escape split; do not paper over the miss
with unrelated compression.

## Remaining subsystem sequence

### R4: expressions, paths, and calls

Implement one precedence-climbing engine, one primary engine, and one postfix
engine. Constant and runtime modes share parsing and type resolution. Preserve
signed promotion, exact literal adoption, short-circuit behavior, failable-call
consumption, open-view access, nested calls, recursion, and trap offsets.

Exit target: at least 25 percent smaller than the frozen expression/path/call
region, with accepted source, diagnostics, transcript intent, target behavior,
and stack restoration proved.

### R5: statements and control

Implement assignment, calls, `if`/`elseif`/`else`, `while`, counted loops,
`return`, `fail`, `exit`, `continue`, `else fail`, and `handle`. Use action
programs for regular sequencing and handwritten escapes for stateful control
frames. Preserve signed/unsigned loop behavior, overshoot-before-store,
flow/fallthrough analysis, and exact failure cleanup.

### R6: scalar backend recipes

Build the generated recipe interpreter and migrate a representative group
before committing to the architecture. Recipes emit literal runs, operands,
runtime calls, labels, fixups, and width/signed variants. Any repeated emitted
sequence longer than roughly six bytes is a runtime-kernel candidate, measured
against both compiler and generated-program size.

### R7: complete backend and artifacts

Finish aggregates, calls, strings, open arrays, control flow, failure paths,
banked output, target layout, runtime linking, NOBJ, HEX, D8, and transactional
publication. Normal and debug compilers must produce byte-identical target
artifacts for the same source. D8 must validate every semantic operation key as
an actual record boundary before publication.

### R8: parity, cutover, and removal

Run the complete frozen corpus and all conformance corrections through both
compilers. Prove exact Host diagnostics, flat and banked artifacts, runtime
behavior, traps, source maps, failure recovery, subsequent compilation, and
relocation. Enforce the 16,384-byte hard gate and report the measured 12–14 KiB
result. Only then switch the Host to the replacement, remove the old compiler
and obsolete stage lattice, regenerate published artifacts, update all docs,
and tag the cutover.

## Gate commands

Run focused tests while editing, then all of these before a checkpoint:

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

`npm test` is deliberately serial. Do not weaken it because proof programs take
several minutes. If one historical proof times out under load, rerun that exact
test alone; do not treat a timeout as semantic success without the isolated
pass.

After `npm run build`, compare new `src` and `dist` generated modules. Both
views are shipped and must contain the same validation. Generated files are
checked in; a stale generated authority is a publication blocker.

For compiler-size census, use a target-enabled proof or the current replacement
metadata/action proof. Never use `stage9-conformance` as the production census;
it omits target output and understates the compiler.

## Review checklist for every checkpoint

- accepted and rejected source agree with the specification/oracle;
- diagnostic code, part, offset, line, and column are discriminating;
- exact fill and first overflow execute;
- failed transactions preserve counters, contents, and guard bytes;
- normal and debug layouts assemble under strict contracts;
- code assembles at multiple unrelated origins and the highest fitting origin;
- no pointer or target address is truncated or packed;
- every `.db`/`.dw` is genuine data and is documented when non-obvious;
- semantic widths agree in producer, dispatcher, decoder, and D8;
- target output is byte-identical where the change is compiler-internal;
- workspace growth is measured and justified;
- plan and implementation ledgers use fresh measured figures; and
- independent reviewers have no unresolved important finding.

## Final warning

Do not optimize around the current proof origin, the current `$6000` workspace,
or a handler presently located below `$4000`. Those are deployment choices,
not architectural facts. The compiler may ultimately live at `$0100`, `$8000`,
or any other fitting address. Every future representation must remain correct
for the full Z80 address space.
