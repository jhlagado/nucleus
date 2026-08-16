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
| `rewrite-front-actions.json`       | Replacement front-end action instructions and the full-address handwritten-escape dispatcher.                                 |

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
named `dynamic` effect used by calls; numeric 15 is not admitted by the source
generator. Source class zero means no source attribution, one means the
current direct source context, and two means the resumed enclosing construct
context used for compiler-generated closure. Backend selectors are namespace
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

`scripts/generate-rewrite-actions.mjs` gives every front-end action instruction
a dense ordinal and fixed width, and gives every irregular escape a dense
selector. The generated Z80 dispatcher uses ordinary full-address jumps;
selectors are never packed into an address.
The generated TypeScript decoder rejects invalid ordinals, truncation, missing
`End`, and bytes after `End`. `npm run check:rewrite-actions` rejects stale
generated authority. An escape returns to the current action program and may
not invoke another action program: the compact machine intentionally owns one
cursor. If nested action execution ever becomes necessary, it requires an
explicit cursor stack and a separate liveness proof.

Expressions, name-led statements, and type-directed aggregate initializers are
deliberate external islands. They require precedence or symbol and type
information that token lookahead alone cannot supply.

The packed statement grammar keeps failure consumption immediate: `else fail`
propagates a direct failable call, while same-line `handle NAME` opens its local
handler body. Boolean `or` remains entirely inside the expression island.

The packed Stage 7 tables are locked by `test/ll1-stage7.test.ts`. Replacement
operation outputs are locked by `npm run check:rewrite-operations` and
`test/rewrite-semantic.test.ts`. Replacement action outputs are locked by
`npm run check:rewrite-actions` and `test/rewrite-actions.test.ts`. Run the
relevant checks after changing either source or generator.
