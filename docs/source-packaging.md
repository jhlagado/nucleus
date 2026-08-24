# Nucleus source packaging

## Packaging boundary

The Nucleus compiler receives an ordered stream of source parts. It has no
filesystem interface and does not search for dependencies. Each source part
retains its original bytes and has one stable path identity for diagnostics and
D8 maps. Project sources use project-relative identities. Bundled library
sources use the reserved `@nucleus/` prefix.

The packaging layer turns stored source objects into that stream. A native
machine runs the Z80 resolver and source streamer. The ordinary desktop path
uses the Node resolver; the native-path proof runs the same prebuilt Z80 tools
through Debug80 Runtime. Each path reads import headers, includes one object
for each canonical source identity, orders dependencies before their users,
and supplies the resulting parts to the compiler. Dependency discovery does
not add a language declaration or a compiler pass.

The resolver uses the common named-object services defined by the
[Z80 system-services architecture](z80-platform-services.md). It may retain a
bounded dependency plan, but it does not concatenate every source byte in RAM.
After discovery, the source streamer reopens each ordered part and transfers
bounded chunks to the compiler.

## Import headers

A source file may begin with import directives:

```nucleus
//% import "library/display.nu"
//% import "library/input.nu"

sub main()
end
```

An import directive occupies one physical line and has this form:

```text
horizontal-space* "//%" horizontal-space+ "import" horizontal-space+
    '"' relative-path '"' horizontal-space*
```

The leading header may also contain blank lines and ordinary `//` comments.
The first Nucleus source line ends the header. A later `//%` directive is a
packaging error, since accepting it as an ordinary comment would silently omit
a dependency.

The host preserves every directive byte and the original line endings. To the
compiler, `//% import` is an ordinary `//` comment. Source offsets, lines,
columns, diagnostics, and D8 attribution therefore refer to the file the
programmer edited.

Import paths use printable ASCII and `/` separators. The host first resolves a
path from the importing file. When that path does not exist, it resolves the
same spelling from the bundled standard-library root. A project file can
therefore provide a deliberate local replacement, while an import such as
`console/output.nu` finds the installed library without an absolute path.

`..` is accepted only when normalization remains inside the source's own root.
Project and standard-library roots are checked independently. Absolute paths,
root escapes, symbolic-link escapes, missing files, and two logical paths
naming the same physical file are configuration errors. A native named-object
provider must therefore expose a canonical namespace or reject aliases; the
resolver deduplicates canonical names and does not inspect directory metadata.

## Dependency order

Resolution starts at one entry file and visits imports in their written order.
A depth-first postorder traversal places each dependency before its importer.
The host emits one part for a physical file even when several files import it.

For example:

```text
main.nu imports left.nu and right.nu
left.nu imports shared.nu
right.nu imports shared.nu
```

The source order is:

```text
shared.nu
left.nu
right.nu
main.nu
```

A cycle is rejected with its complete path. The resolved graph is also
available through the Node API with each file's direct dependencies, raw byte
length, and SHA-256 hash. Editors and watch processes can use that result
without discovering the graph again.

Nucleus currently accepts at most eight source parts, and each part may contain
at most 65,535 bytes. There is no total 2 KiB source limit: the native host
supplies source through a refill window.

## Command line

With one positional source, the command line treats that file as the entry and
discovers its imports:

```text
nucleus build --target-profile target.json -o build/program.nobj src/main.nu
```

Several positional sources retain the explicit ordering written on the command
line. This compatibility form performs no dependency reordering:

```text
nucleus build library.nu main.nu
```

For repeatable projects, `nucleus-project/v2` records one entry instead of an
ordered source array:

```json
{
  "schema": "nucleus-project/v2",
  "root": ".",
  "entry": "src/main.nu",
  "target": "nucleus-target.json",
  "outputs": {
    "nobj": "build/program.nobj",
    "hex": "build/program.hex",
    "d8": "build/program.d8.json"
  }
}
```

`nucleus-project/v1` remains the explicit ordered-source format.

## Bank assignments

A version 2 banked project assigns banks by logical source identity:

```json
{
  "sourceBanks": {
    "src/display.nu": 1
  }
}
```

An unlisted file uses `entryBank`. The entry file must be in `entryBank`. After
dependency ordering, the host converts these names into the ordinal
`partBanks[]` array required by the compiler. A version 2 banked target profile
therefore omits `partBanks`; specifying both forms is an error.

## SP1 source plans

The resolver commits the resolved order as a compact line-oriented SP1 plan:

```text
SP1 3
P 0 13 src/lib/io.nu
P 1 18 src/lib/display.nu
P 0 11 src/main.nu
END
```

The header gives the decimal part count. Each `P` record contains the bank
ordinal, path-byte length, and printable ASCII source identity. `END` and the
declared counts detect a truncated plan. Flat plans use bank zero.

SP1 contains no source bytes, target origins, service addresses, or conditional
logic. The standalone Z80 resolver reads one entry-source name, traverses
imports in depth-first postorder, and commits `.nucleus/source-plan.sp1`
through named-object ABI 1. The Z80 source streamer then reopens each named
source and supplies bounded chunks to the compiler. The resolver and compiler
run as separate tool images, so neither program must coexist with the other in
the Z80 address space.

The implemented native resolver emits flat plans with bank zero. Source-bank
assignment remains in the desktop project host until a native bank-assignment
input is specified. The Nucleus compiler parses neither import directives nor
SP1.
