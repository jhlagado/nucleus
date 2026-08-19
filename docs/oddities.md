# Nucleus oddities

Status: working notes checked against the current compiler; does not amend the
language specification
Date: 2026-08-16

A first-time Nucleus programmer, coming from Pascal, BASIC, or Z80 assembler,
will recognize the spelling and still trip on the storage model, the open
views, and a handful of parse rules. This note records those places. Some are
the programming model. Some are furniture. Some are rough edges still intended
to be smoothed.

The [language specification](specification.md) remains the authority. When an
observation here conflicts with the compiler or its conformance proofs, that
conflict is a documentation defect to resolve rather than a new language rule.
The current specification covers signed integers, open string and array
parameters, bounded-string construction, and nested fixed arrays.

## Not oddities

These are choices, not defects.

Names are case-sensitive. `Player` and `player` are different identifiers.
Keywords use their lowercase spelling only: `elseif` is the keyword, `ELSEIF`
is a name. That pair is consistent once you treat keywords as fixed tokens and
names as preserved spellings.

A logical newline ends a statement. There is no semicolon. A line break inside
`()` or `[]` is whitespace.

Integer literals are decimal, `$` hexadecimal, and `%` binary. Remainder is
the word `mod`. Not-equal is `<>`. In a statement `=` assigns; in an
expression it compares. Assignment is not an expression.

Bounded strings are Pascal strings: a capacity, a current length, and a
payload that may contain zero bytes. Static construction from a string literal
is built in. Runtime construction, comparison, and formatting belong in
ordinary source libraries over `string[]`. The source operations are
`.length`, `.capacity` on the open view, and checked byte indexing. There is no
family of intrinsic `append`, `concat`, or `LEFT$` operations.

File names, directories, and open/close are not source constructs. Byte
streams and bulk storage are the language boundary. Filing systems sit in
libraries and in the host that selects those streams.

Direct Z80 port I/O has two typed predefined routines. `readPort(u16)` returns
one `u8`; `writePort(u16, u8)` writes one byte. The port is the complete `BC`
I/O address, including its upper byte. These operations are infallible and do
not use `else fail` or `handle`.

`service(slot, packet)` is the deliberately narrow native escape hatch. The
slot is an exact byte constant, while the packet is writable `u8[N]` or `u8[]`
storage whose retained count bounds the provider. It is statement-only,
infallible at the source level, and target-specific: unsupported slots or
extents trap, while effects after valid native dispatch are not rolled back.
It exposes neither the packet address nor any Z80 register to source.

## The programming model

Routine locals are scalar only: `u8`, `u16`, `i8`, `i16`, and `boolean`.
Records, arrays, and strings live at program scope for the life of the
program. A routine that needs aggregate storage receives it as a parameter.
Arguments are the input and output path for aggregates. There are no source
pointers, no heap, and no local alias variable.

Recursion is legal. Shared global buffers are therefore a programmer concern,
not a hidden stack allocation.

Nucleus has two parameter-only complete-object views:

| View       | Binds to                         | Retains              | Extra operations                          |
| ---------- | -------------------------------- | -------------------- | ----------------------------------------- |
| `string[]` | any concrete `string[N]`         | actual capacity      | `.capacity`; checked `.length` assignment |
| `T[]`      | any complete `T[N]` of exact `T` | actual element count | `.length` as `u16`                        |

Neither is a slice. Each view is one complete object. You cannot take a
prefix, an offset, or a caller-chosen count. You cannot store the view, return
it, or put it in a record. Element type for `T[]` is exact: `u8[]` does not
accept `i8[N]`, and `string[16][]` does not accept `string[32][N]`.

Nested fixed arrays are ordinary nested types. Suffixes are outermost first:
`u8[3][2]` is three rows of `u8[2]`, and `grid[y][x]` selects in the same
order. An open view of those rows is `u8[][2]`; it can bind `u8[3][2]` or
`u8[10][2]`, but not `u8[3][3]`. The omitted bound is allowed only on the
outermost dimension of a formal parameter. `u8[2][]` and `u8[][]` are invalid.

A concrete `string[N]` can read `.length` and index existing bytes. It cannot
assign `.length` and has no `.capacity` property: the capacity is the type.
Length changes only through `string[]`:

```nucleus
sub clear(text as string[])
    text.length = 0
end

sub appendByte(text as string[], value as u8) as boolean
    var index as u8 = text.length

    if index = text.capacity
        return false
    end

    text.length = index + 1
    text[index] = value
    return true
end
```

A new length that exceeds capacity is a `bounds` trap. Shrink clears the
dropped bytes. Grow exposes the existing zero tail. You still cannot write
`text[text.length] = c`; the index must be below the current length, so a
library append extends first and then writes.

`T[N]` exposes `.length` on both the concrete object and the open view. String
capacity does not, because `N` is already the type. Array length is `u16`;
string length is `u8` (capacity 1 through 253).

## Remaining surprises

**One namespace, declaration before use.** A record named `Point` and a
variable named `Point` cannot coexist in program scope. A parameter or local
may reuse a visible program data, constant, or type name; the routine binding
wins inside that body. Routine names, `main`, and predefined names remain
protected. Locals occupy a contiguous prefix at the top of the routine; `if`
and `for` bodies declare nothing. The counted-loop counter must already be an
integer scalar local. Mutual recursion uses `forward`; the later body is `sub
name` with the signature omitted.

**`elseif` is one token.** `else if` is two tokens and is not a flat clause.
After `else`, the next token on that line cannot begin a nested `if`. `then`
is an identifier.

**Signed integers do not change lengths or capacities.** `i8` and `i16` are
ordinary integer types and may be used as indexes; a dynamic negative index
performs the same `bounds` trap as any other out-of-range index. String
lengths and capacities and array lengths remain unsigned values. Alias
carriers are not source integers at all. Implicit widening is `u8` → `u16`,
`i8` → `i16`, and `u8` → `i16`. Mixed `u8` and `i8` become `i16`. `u16` and
`i16` have no value-preserving common type, so their mixture requires an
explicit checked conversion. `$FF` is 255, never an `i8` bit pattern for −1.
Unary minus is modular in the operand's width and also accepts typed unsigned
integers. Signed division truncates toward zero; remainder follows the
dividend. The defined two's-complement result of `-32768 / -1` is `-32768`,
with remainder zero.

**Recoverable failure is consumed at the call.** A failable call must use
`else fail` or `handle NAME` on the call's logical line:

```nucleus
value = readStorageByte() else fail
value = readStorageByte() handle code
    return
end
```

A scalar local initializer admits only `else fail`; assignment and complete
call statements admit either form. A failable call cannot sit inside an
argument or a `return`. `return` is success only. The handler name is an
existing writable `u8`, not a new binding. Traps are not recoverable.

**String literals are contextual arguments, not general values.** Given `sub
writeText(text as string[])`, `writeText("Hi")` creates a distinct anonymous
program-lifetime string and passes the ordinary writable `string[]` carrier.
Mutation may persist in RAM and may have no physical effect in ROM. Portable
code treats literal arguments as immutable. Literals remain invalid as general
expressions, assignments, results, locals, and concrete aggregate arguments.

**Aggregate constants are read-only by source path.** Direct assignment to
`Origin.x` is invalid. Pass `Origin` as an aggregate argument and the callee
may write through the parameter. Whether that write changes memory depends on
RAM versus ROM placement. Portable programs do not rely on it. An earlier
aggregate constant may also supply any complete exact-type node in a static
initializer; this copies its established bytes during compilation rather than
reading it at runtime.

**Only a condition folded to constant `true` proves an indefinite loop.** It
makes a value routine non-fallthrough when no syntactic `exit` targets that
loop. An `exit` counts even after `return`, `fail`, or `continue`; an exit
belonging to a nested loop does not. Dynamic and constant-false conditions
retain the conservative fallthrough rule.

**`select` is ordered equality, not a switch table.** The selector is evaluated
once, and constant case values are tested from top to bottom. The first match
wins, duplicate values are permitted, and a selected body never falls through.
Comma-separated values are the only way to share one body. This version has no
case ranges or source-visible `break`; `exit` and `continue` remain loop-only.

## Language-finish backlog

These items are rough edges rather than objections to the programming model.
Priority reflects how early a programmer meets the problem and how much it
undermines an otherwise consistent rule.

### P0 — first-program friction

1. **Mutation through an alias to an aggregate constant.** The direct-root
   rule is clear; losing that marker through a parameter permits a write whose
   physical result depends on RAM versus ROM placement. Carry read-only
   provenance through aliases and reject the write, or define another
   target-independent rule with a discriminating proof. Portable source
   should not acquire different mutation semantics from placement policy.
2. **One current beginner path.** The language manual and examples need one
   short route that uses the implemented forms together: signed counters,
   `string[]`, `T[]`, nested arrays, `else fail`, and `handle`. This is a
   documentation deliverable, not another syntax feature.

### Ongoing release discipline

The standalone specification, grammar, implementation, generated compiler
images, conformance tests, and any Debug80 reading copy must identify the same
language revision. Signed integers, open views, string construction, and
nested arrays are already specified. Future language commits should update the
manual and reading copy in the same milestone rather than leaving a note like
this one to reconcile them later.
