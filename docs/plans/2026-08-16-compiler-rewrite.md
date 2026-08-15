# Goal: rewrite the Nucleus compiler toward 12K

Status: active goal
Date: 2026-08-16
Planning baseline: `25cd8be` (core 15,290 bytes at `e38291d` plus this docs tree)
Target: **12,288 bytes** compiler core (code + immutable), with the existing
16 KiB bank remaining the hard failure gate

## Purpose

Rebuild the compiler's *expression* of the language so a feature-complete
Nucleus 0.1 fits with margin. The language is not to be weakened. Pointers and
heap stay banished. `string[]`, `T[]`, `i8`/`i16`, and nested arrays `T[N][M]`
are required in the destination, not optional extras.

This is redesign. It is not a size pass on the current handlers. Implementation
may change grammar encoding, parser engines, emit representation, and runtime
kernel policy. Source meaning, traps, diagnostics, and the proof harness do
not.

## Aim

| Account | Now | Aim |
| --- | ---: | ---: |
| Compiler core (code + immutable) | 15,290 | **12,288** |
| 16 KiB bank headroom | 1,094 | ≥ 4,096 |
| Language | shipping subset | complete 0.1 including in-development features |

12K is the working target, not a soft band. Estimates that only reach 13–14K
are not done. A candidate that lands above 12,288 with the complete language
still incomplete is not the destination.

Workspace, generated programs, and runtime remain separate accounts. Moving
bytes into the runtime kernel is allowed when the compiler shrinks and the
runtime stays inside its own budget. Do not claim a 12K win by hiding compiler
work in unreported storage.

## Keep

- No pointers, no heap, no address arithmetic.
- Exact nominal types; interned descriptors; one implicit widening lattice.
- Newline-terminated, keyword-led statements.
- Streaming one-pass compilation, source-backed names, noreturn diagnostics.
- Private checked semantic stream; no public bytecode product.
- Scalar locals only; owned aggregates at program scope; opaque aggregate
  carriers.
- The proof harness and byte-accounted fixtures before any compression.

## Change

Express the specification as small interpreters over tables rather than as
hand-laid instruction sequences.

1. **One parsing discipline per stratum.** Operator-precedence climbing for
   expressions. Keep LL(1) tables for statements, with parameterized action
   byte-code instead of one routine per production. One shared postfix engine
   for paths and calls.
2. **Emit as recipes.** Semantic operations map to short emit scripts plus a
   small interpreter. Irregular control (`for` next-value, fixups) stays as
   code, invoked as a recipe primitive.
3. **Runtime kernel for repeated sequences.** Any emitted run longer than about
   six bytes that appears in more than one recipe becomes a kernel call when
   the complete compiler-plus-runtime account still fits.
4. **Pending features as table rows.** Signed scalars, open views, and nested
   arrays parameterize the same engines. They must not grow another parser
   ladder or another 90 handlers.

Hold a unified compiler byte-code (parser actions and emit recipes as one
instruction set) in reserve. Take it only if 12K is still missed after the
three stages above. It costs AZM contract checking and D8 mapping on the
interpreted core.

## Sequence

Rewrite in place. Keep a working, proved compiler at every commit.

1. Backend recipes, one semantic op at a time.
2. Precedence-climbing expression core; semantic stream unchanged so proofs
   diff.
3. Statement action byte-code under the existing LL(1) tables.
4. Land `string[]`, `T[]`, `i8`/`i16`, and nested arrays in the new idioms
   between stages, where they cost least.
5. Delete gated legacy strata only after migrated proofs replace them.

Do not start a big-bang tree. Do not compress an unreviewed correctness
baseline. Do not treat a settled language rule as a defect to delete.

## Language

Do not drop features to make the compiler fit. Better abstractions are welcome
when they increase expressivity and still compile smaller: for example a
contextual string-literal argument, or typed port `IN`/`OUT`. Those are
separate language decisions and still need owner approval. They are not a
substitute for the 12K compiler goal.

## Evidence

Re-census the current assembled core before acting on any historical site
count. Record baseline, result, and deltas for compiler code, immutable data,
workspace, generated code, runtime, instructions, and T-states. Reject a
change that improves one account by stealing from another without saying so.
