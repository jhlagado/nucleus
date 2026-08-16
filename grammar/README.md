# Nucleus grammar

This directory contains the machine-readable grammar used by the packed LL(1)
parser. The language specification remains authoritative for source-language
meaning; these files make its current Stage 7 syntax executable and testable.

| File                               | Purpose                                                                                                                       |
| ---------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| `stage7-grammar.json`              | Grammar productions, external parser islands, and prediction diagnostics.                                                     |
| `generate-stage7.ts`               | Computes nullable, FIRST, FOLLOW, and prediction sets; rejects conflicts and packed-field overflow.                           |
| `stage7-tables.asmi`               | Generated prediction, production, and action tables included by the compiler; each row marks its final production in-band.    |
| `stage7-proof-actions.asmi`        | Generated action aliases used only by the isolated engine proof.                                                              |
| `rewrite-semantic-operations.json` | Replacement-compiler semantic operations, operands, backend class, stack effect, source attribution, and global trace policy. |
| `rewrite-front-actions.json`       | Replacement front-end action instructions and the relocatable full-address handwritten-escape directory.                     |
| `rewrite-backend-recipes.json`     | Replacement backend recipes and shared target-byte fragments for recipe-class semantic operations.                           |

`scripts/generate-rewrite-operations.mjs` turns the replacement operation
source into Z80 ordinals, producer-facing operand offsets, record widths,
dispatcher descriptors, backend selectors, and the TypeScript boundary
decoder. `npm run check:rewrite-operations` rejects either generated view when
it differs from that source. Every replacement record has a fixed declared
width. Source and service calls, local and program handlers, and each direct or
forwarded open-view form use distinct operations rather than data-dependent
record lengths.

Each record starts with one dense operation ordinal. Its named operands follow
in declaration order; `byte` occupies one byte and `word` is an unsigned
little-endian word. The width table includes the ordinal. Generated
`Operand...Offset` equates address the operand-only staging buffer accepted by
`RewriteSemanticAppend`, so the first operand is at offset zero. Generated
`RecordOperand...Offset` equates address the published record and include its
ordinal, so the first operand is at offset one. The descriptor is five bytes:

1. complete record width;
2. operand count in bits 0–3, source class in bits 4–5, bit 6 reserved, and
   recipe/escape class in bit 7;
3. one bit per operand, set for a word and clear for a byte;
4. a dense selector in the recipe or escape namespace; and
5. abstract stack input and output in the high and low nibbles.

Stack effects 0–14 are literal carrier counts. Nibble `$F` is reserved for the
named `dynamic` effect used by calls; the source generator rejects numeric 15.
The source classes are zero for no attribution, one for the current direct
source context, and two for the resumed enclosing-construct context used for
compiler-generated closure. Backend selectors are namespace
ordinals, not addresses. Later backend milestones build complete full-address
directories from them without using an address bit or assuming a compiler
origin.

The top-level trace policy is `operation-start`: after validating the complete
transcript, the instrumented dispatcher reports one `$DD` event at each record
boundary and one `$DE` event after the successful walk. Trace policy is not
encoded redundantly in every descriptor.

The operation vocabulary is deliberately compact rather than universally
parameterised. Width-, storage-, and control-context variants have separate
ordinals while sharing backend selectors. This keeps the published 511-byte
transcript acceptance boundary identical to the production language and still
allows the replacement backend to use shared recipes.

Program loads also distinguish initialized and BSS storage by operation
ordinal. Their operands are complete 16-bit offsets relative to the named
segment; no address bit is used as a storage tag. `LoadProgramU8` and
`LoadProgram16` address initialized storage, while `LoadBssU8` and `LoadBss16`
address BSS. These two BSS operations are fresh replacement authority rather
than aliases for a frozen production record whose operand packed storage into
an address bit. Program handler destinations follow the same rule:
`BeginHandlerProgram` addresses initialized storage and `BeginHandlerBss`
addresses BSS. Both keep the frozen five-byte record width.

`ConvertInteger.targetType` uses bit 7 only as an operation operand mode: when
set, a failed signed-to-`u16` conversion reports the target bounds trap rather
than the ordinary narrowing trap. The low seven bits remain the complete
scalar type identity. This flag is semantic-record metadata, never part of a
compiler or generated-program address.

`scripts/generate-rewrite-actions.mjs` gives every front-end action instruction
a dense ordinal and fixed width, and gives every irregular escape a dense
selector. It also emits named action programs declared by the same JSON
authority; those `.db` rows are interpreter data, not hidden Z80 instructions.
The generated Z80 dispatcher indexes a directory of ordinary relocatable
16-bit handler addresses. The directory's `.dw` entries are address data, not
encoded instructions. Selectors are never packed into an address and the
directory discards no address bits, so it imposes no compiler-origin policy.
The generated TypeScript decoder rejects invalid ordinals, truncation, missing
`End`, and bytes after `End`. `npm run check:rewrite-actions` rejects stale
generated authority. An escape returns to the current action program and may
not invoke another action program: the compact machine intentionally owns one
cursor. If nested action execution ever becomes necessary, it requires an
explicit cursor stack and a separate liveness proof.

Expressions, name-led statements, and type-directed aggregate initializers are
deliberate external islands. They require precedence or symbol and type
information that token lookahead alone cannot supply.

`scripts/generate-rewrite-backend-recipes.mjs` validates the backend selectors
against the semantic-operation authority, resolves every named operand to its
operand-buffer offset, and emits the recipe directory and shared fragments.
Recipe directories and family-dispatch tables store complete 16-bit addresses.
Recipe instructions and emitted target templates are declared data: `.db`
contains recipe opcodes or target bytes, and `.dw` contains addresses. The Z80
instructions executed by the compiler remain ordinary AZM mnemonics. Literal
target runs are compared with AZM-assembled reference code in the R6 execution
proof. `npm run check:rewrite-backend-recipes` rejects stale generated output.

The packed statement grammar keeps failure consumption immediate: `else fail`
propagates a direct failable call, while same-line `handle NAME` opens its local
handler body. Boolean `or` remains entirely inside the expression island.

The packed Stage 7 tables are locked by `test/ll1-stage7.test.ts`. Replacement
operation outputs are locked by `npm run check:rewrite-operations` and
`test/rewrite-semantic.test.ts`. Replacement action outputs are locked by
`npm run check:rewrite-actions` and `test/rewrite-actions.test.ts`. Run the
relevant checks after changing either source or generator. Replacement backend
recipes are locked by `npm run check:rewrite-backend-recipes` and
`test/rewrite-backend-recipes.test.ts`.
