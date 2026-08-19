# Nucleus language tour

Nucleus is a small statically typed language for direct Z80 compilation. The
[language specification](specification.md) defines every source rule; this page
shows the main forms together.

Programs declare storage and routines at top level. A routine declares all of
its scalar locals before its first statement:

```nucleus
var direction as u8 = 2

sub main() fails
    var result as u8

    result = direction + 1
    writeOutputByte(result) else fail
end
```

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
