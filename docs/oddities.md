# Nucleus oddities

Status: working notes; does not amend the language specification
Date: 2026-08-16

A first-time Nucleus programmer, coming from Pascal, BASIC, or Z80 assembler,
will recognize the spelling and still trip on the storage model, the open
views, and a handful of parse rules. This note records those places. Some are
the programming model. Some are furniture. Some are rough edges still intended
to be smoothed.

The [language specification](specification.md) remains the authority. It
currently trails the compiler in places: signed integers, open array
parameters, and bounded-string construction are in the implementation before
they are fully reflected here.

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
payload that may contain zero bytes. Construction, comparison, and formatting
belong in ordinary source libraries over `string[]`. The source operations are
`.length`, `.capacity` on the open view, and checked byte indexing. There is
no family of intrinsic `append`, `concat`, or `LEFT$` operations.

File names, directories, and open/close are not source constructs. Byte
streams and bulk storage are the language boundary. Filing systems sit in
libraries and in the host that selects those streams.

## The programming model

Routine locals are scalar only: `u8`, `u16`, `i8`, `i16`, and `boolean`.
Records, arrays, and strings live at program scope for the life of the
program. A routine that needs aggregate storage receives it as a parameter.
Arguments are the input and output path for aggregates. There are no source
pointers, no heap, and no local alias variable.

That is closer to FORTRAN than to Pascal, with Pascal-shaped syntax. Recursion
is legal. Shared global buffers are then a programmer problem, not a hidden
stack allocation.

The two parameter-only views are the generics:

| View        | Binds to                         | Retains              | Extra operations                          |
| ----------- | -------------------------------- | -------------------- | ----------------------------------------- |
| `string[]`  | any concrete `string[N]`         | actual capacity      | `.capacity`; checked `.length` assignment |
| `T[]`       | any complete `T[N]` of that `T`  | actual element count | `.length` as `u16`                        |

Neither is a slice. Each view is one complete object. You cannot take a
prefix, an offset, or a caller-chosen count. You cannot store the view, return
it, or put it in a record. Element type for `T[]` is exact: `u8[]` does not
accept `i8[N]`, and `string[16][]` does not accept `string[32][N]`. Arrays of
arrays are absent; a grid is an array of records that contain arrays.

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
variable named `Point` cannot coexist. A parameter cannot reuse a visible
global name. Locals occupy a contiguous prefix at the top of the routine;
`if` and `for` bodies declare nothing. The counted-loop counter must already
be a scalar local. Mutual recursion uses `forward`; the later body is `sub
name` with the signature omitted.

**`elseif` is one token.** `else if` is two tokens and is not a flat clause.
After `else`, the next token on that line cannot begin a nested `if`. `then`
is an identifier.

**Signed integers stop at the view plane.** `i8` and `i16` are scalar
arithmetic. Indexes, string `.length`, `.capacity`, array counts, and alias
carriers stay unsigned. Implicit widening is `u8` → `u16`, `i8` → `i16`, and
`u8` → `i16`. There is no implicit conversion between `u16` and `i16`. Mixed
`u8` and `i8` become `i16`. Mixed `u16` and `i16` is invalid: the machine has
no `i32`, and unsigned-wins would be the wrong default. `$FF` is 255, never
an `i8` bit pattern for −1. Unary minus belongs to signed types. Signed
division truncates toward zero; remainder follows the dividend. `-32768 / -1`
traps.

**Failure is a calling convention.** A failable call must be consumed at the
site with `else fail` or same-line `handle NAME`. It cannot sit inside an
argument or a `return`. `return` is success only. `handle` attaches to that
logical line; the name is an existing writable `u8`, not a new binding. Traps
are not recoverable.

**String literals are initializers, not values.** `output("Hi")` is not
admitted. You declare a concrete `string[N]` constant and pass that name.

**Aggregate constants are read-only by source path.** Direct assignment to
`Origin.x` is invalid. Pass `Origin` as an aggregate argument and the callee
may write through the parameter. Whether that write changes memory depends on
RAM versus ROM placement. Portable programs do not rely on it.

**A value routine needs a structural `return`.** Loops are assumed able to
finish, including `while true`. A function whose only live `return` sits
inside an infinite loop still needs a `return` after the loop, or the source
is invalid. That rule exists so fallthrough can be checked in one pass.

## Rough edges to smooth

These are legitimate. They are not the programming model.

1. **The specification trails the compiler.** Signed integers, `T[]`, and
   string construction should be described in the same revision a programmer
   reads first.
2. **`else if` versus `elseif`.** BASIC programmers will write the two-word
   form. A diagnostic that names the expected token, or acceptance of a nested
   `if` in that position, would remove a first-session parse failure.
3. **Same-line `handle`.** Failure consumption is the right idea. Tying the
   handler to the call's logical line is easy to miss and hard to explain.
4. **Literal text as an argument.** Requiring a named `string[N]` constant
   before `output("Hi")` is the first “is this unfinished?” moment. A
   contextual literal argument, still not a general string expression, would
   match how people actually write the first program.
5. **Fallthrough after `while true`.** A phantom `return` the machine will
   never execute is a compiler convenience in the language. A tighter
   non-return analysis for the obvious infinite loop would remove it.
6. **Mutation through an alias to an aggregate constant.** The direct-root
   rule is clear. The hole through a parameter is not, and it is
   target-dependent. Either close it or make the ROM/RAM rule a specified
   diagnostic.

## To add

**Port access.** The language has typed byte streams and no source-visible
machine ports. On a Z80 that is a real omission. `IN` and `OUT` belong in the
safe system boundary as typed operations, not as inline assembly or a leak
into `u16` addresses. Peek and poke of arbitrary memory should stay out.
Port I/O should come in.
