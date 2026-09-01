# Nucleus on CP/M 2.2

The native compiler is installed as `NUC.COM`. It runs the Z80 compiler directly
and uses ordinary CP/M BDOS calls for source input, console diagnostics, and
output files.

## Commands

With no arguments, Nucleus reads `INPUT.NU` and writes `OUTPUT.COM`:

```text
A>NUC
```

One argument names the source and derives a `.COM` output with the same base
name:

```text
A>NUC HELLO
A>NUC HELLO.NU
```

Both commands read `HELLO.NU` and write `HELLO.COM`. If the source has another
extension, Nucleus preserves it:

```text
A>NUC PROGRAM.NEW
```

That command reads `PROGRAM.NEW` and writes `PROGRAM.COM`.

A second argument selects the output name and format:

```text
A>NUC HELLO.NU HELLO.COM
A>NUC HELLO.NU HELLO.BIN
A>NUC HELLO.NU HELLO.HEX
```

`COM` and `BIN` contain the same flat image beginning at logical address
`$0100`. A CP/M loader can run the `.COM` form; a monitor, emulator, or image
builder can load the `.BIN` form at `$0100`. The `.HEX` form contains the same
bytes as addressed Intel HEX records.

The help form prints the command summary without opening a source file:

```text
A>NUC ?
```

CP/M filenames use the current drive and the normal 8.3 limit. Wildcards,
drive prefixes, extra arguments, and output extensions other than `COM`, `BIN`,
or `HEX` are rejected.

## Output replacement

Nucleus writes a temporary file before replacing an existing output. If a disk
write or rename fails, the preceding output remains in place. The temporary
and backup names use the selected output base name with `.$$$` and `.BAK`
extensions; these names must be free when compilation begins.

## Source files

The current self-contained `NUC.COM` command reads one physical source file.
The native import resolver and multipart source streamer are separate Z80
components built around the common named-object services. A later CP/M binding
will place those components in front of the same compiler, allowing leading
`//% import` headers without changing the compiler core or this command shape.
