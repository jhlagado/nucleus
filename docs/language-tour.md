# Nucleus language tour

Nucleus is a small statically typed language for direct Z80 compilation. The
[language specification](specification.md) defines every source rule; this page
shows the main forms together.

Programs declare storage and routines at top level. This first program imports
two small console modules, calculates a value in a function, stores the result,
and prints it:

```nucleus
//% import "console/output.nu"
//% import "console/u16.nu"

const Label as string[8] = "Total: "

sub total(price as u16, quantity as u16) as u16
    return price * quantity
end

sub main() fails
    var result as u16

    result = total(7, 6)
    printString(Label) else fail
    printU16(result) else fail
    printNewline() else fail
end
```

It writes `Total: 42` followed by LF. `//% import` is a host directive kept as
an ordinary comment in the source seen by the compiler. The host resolves each
dependency once and places library parts before this file in the source stream.
The routines are ordinary Nucleus code; only the byte-oriented console service
comes from the target. The explicit `else fail` propagates an output failure
from `main`.

A routine declares its scalar locals before its first statement. Programs use
`main` as their entry routine.

The integer types are `u8`, `u16`, `i8`, and `i16`. Boolean values have the
separate type `boolean`. Records, fixed arrays, bounded strings, `string[]`,
and open arrays provide statically checked aggregate storage and aliases.

`if` selects by Boolean conditions. `while` and counted `for` provide loops;
`exit` and `continue` apply to the innermost loop. `select` performs ordered
integer equality selection:

```nucleus
select direction
case 0
    stop()
case 1, 2
    move()
else
    wait()
end
```

The selector is evaluated once. Case values are compile-time integer
constants converted to the selector's exact type. They are tested in source
order, so the first match wins. Comma-separated values share one body, and a
selected body does not fall through. The final `else` is optional; no match
without `else` performs no action. This form has no ranges or `break`, and a
`select` does not change the target of `exit` or `continue`.

Failable routines declare `fails`. A direct failable call must either propagate
with same-line `else fail` or attach a same-line `handle NAME ... end` where
that form is permitted. Safety traps remain separate from recoverable failure.

The complete syntax, type rules, capacities, and conformance examples are in
the [specification](specification.md). Target stack, generated-code, service,
and trap obligations are in the
[Z80 runtime contract](z80-runtime-contract.md).
