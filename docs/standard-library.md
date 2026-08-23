# Nucleus standard library

The first Nucleus library covers console input and output. It is ordinary
Nucleus source, not compiler machinery. A Node provider, MON3 binding, CP/M
adapter, or another environment supplies the same byte-oriented operations
through the common
[Z80 platform-services boundary](z80-platform-services.md).

Library imports use the normal source header:

```nucleus
//% import "console/output.nu"
```

The host first looks beside the importing source and then in the installed
Nucleus library. Installed library parts have stable identities beginning with
`@nucleus/`, which keeps diagnostics and D8 maps distinct from project files.

## Text output

`console/output.nu` provides:

```nucleus
printChar(value as u8) fails
printString(text as string[]) fails
printNewline() fails
printLine(text as string[]) fails
```

`printString` writes the logical bytes in the string and adds nothing.
`printNewline` writes one LF byte. `printLine` writes the string and then that
LF. Each routine stops at the first output failure and propagates its exact
recoverable code; bytes accepted before the failure remain written.

`printChar` lives in the smaller dependency `console/char.nu`. Applications
normally import `console/output.nu`; numeric modules import `char.nu`
automatically so they do not pay for unused string routines.

## Decimal integers

Decimal output is split by source type because Nucleus emits every imported
routine and does not eliminate unused code:

| Import           | Routine                        | Dependencies      |
| ---------------- | ------------------------------ | ----------------- |
| `console/u8.nu`  | `printU8(value as u8) fails`   | `console/char.nu` |
| `console/i8.nu`  | `printI8(value as i8) fails`   | `console/u8.nu`   |
| `console/u16.nu` | `printU16(value as u16) fails` | `console/char.nu` |
| `console/i16.nu` | `printI16(value as i16) fails` | `console/u16.nu`  |

The routines use decimal without leading zeroes. Signed routines add `-` only
for negative values and handle `-128` and `-32768` without overflowing while
forming their magnitudes.

Import the narrowest module that provides the operation you need. For example:

```nucleus
//% import "console/i16.nu"

sub main() fails
    var result as i16 = -1200
    printI16(result) else fail
end
```

## Character and line input

`console/input.nu` provides:

```nucleus
readChar() as u8 fails
readLine(destination as string[]) fails
```

`readChar` obtains one byte from standard input and propagates `endOfInput` or
another input failure unchanged.

`readLine` uses LF as its only logical terminator. It resets the destination
length, consumes but does not store LF, accepts embedded zero, and behaves as
follows:

- immediate LF succeeds with an empty string;
- EOF before any byte fails with `endOfInput`;
- EOF after some bytes succeeds with the final partial line;
- exact capacity followed by LF succeeds;
- additional content is drained through LF and fails with `lineTooLong`;
- EOF while draining still fails with `lineTooLong`; and
- another input failure propagates unchanged.

The library declares `lineTooLong` as recoverable code 5. A console adapter may
normalize Enter or CRLF into LF before the library sees it. Files and pipes keep
their own byte contract.

The destination must be writable. Pass a bounded-string variable, not an
aggregate constant or anonymous literal whose bytes may reside in ROM.

## Capacity accounting

Library source consumes semantic-transcript and generated-program capacity, but
adds no compiler-core, compiler-workspace, or selected-runtime bytes. The
executable proofs currently measure these complete library-plus-caller cases
against the 511-byte transcript:

| Proof program                    | Used | Remaining |
| -------------------------------- | ---: | --------: |
| text output                      |  188 |       323 |
| `u8` and `i8` output             |  263 |       248 |
| `u16` and `i16` output           |  291 |       220 |
| successful `readLine` caller     |  341 |       170 |
| introductory `Total: 42` program |  367 |       144 |

These values are regression gates, not estimates. The type-specific module
split is what leaves useful room for application code without adding dead-code
elimination to the compiler.
