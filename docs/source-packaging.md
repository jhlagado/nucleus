# Nucleus source packaging and SP1 source plans

## Status and boundary

This document defines the standard host convention that turns files into the
ordered multipart input accepted by the Nucleus compiler. It does not add a
token, declaration, scope, namespace, or filesystem operation to the Nucleus
language.

The Z80 compiler continues to receive only ordered source parts. Each part has
unchanged source bytes, a stable identity, and an optional diagnostic name.
The host opens files, discovers dependencies, suppresses duplicates, orders
parts, and assigns target banks before invoking that interface.

The first implementation belongs to the standalone Nucleus Node package.
Debug80 or a common host-services package may later adopt the graph and source-
plan components. That extraction must preserve this contract and does not make
Debug80 part of the Nucleus compiler.

## Import header

A file may begin with import directives:

```nucleus
//% import "lib/hardware.nu"
//% import "lib/display.nu"

sub main()
end
```

The directive has this host grammar:

```text
import-directive ::= horizontal-space* "//%" horizontal-space+
                     "import" horizontal-space+ '"' relative-path '"'
                     horizontal-space*
```

`relative-path` is nonempty, uses `/` separators, and is resolved relative to
the importing file. It may not be absolute or escape the selected project root.

The import header may contain blank lines, ordinary `//` comments, and import
directives. The first line containing Nucleus source ends the header. A later
`//% import` is a packaging error so that a misplaced dependency cannot become
a silently ignored comment.

The resolver does not remove or replace the directive. The complete original
file, including directive bytes and its original line endings, becomes the
source part. The Nucleus tokenizer consumes the directive through its ordinary
`//` comment rule. Diagnostics and D8 therefore continue to use positions in
the original file.

## Resolution

Resolution begins with one entry file and performs a depth-first traversal.
Imports are visited in their written order. A dependency is emitted before its
importer, and a physical file is emitted once. This gives deterministic
declaration order and suppresses both repeated imports and diamonds.

The resolver rejects before compilation:

- a missing or unreadable file;
- a malformed or late directive;
- a path outside the project root, including a symbolic-link escape;
- two logical identities for one physical file;
- a dependency cycle, reported with its complete chain;
- a resolved part count or source-window extent beyond the compiler's
  published capacity; or
- a source-bank entry that does not name a resolved logical source.

The canonical physical path is used only for graph identity. The normalized
project-relative `/` path is the diagnostic name, D8 file identity, source-plan
path, and source-bank key. This logical identity is printable ASCII and occupies
1 through 255 bytes.

The Node resolver also returns the ordered dependency graph. Every entry
records its logical identity, direct import identities, raw byte length, and
SHA-256 hash. Editors and watch processes can use that metadata without reading
or resolving the files a second time.

## Project files

`nucleus-project/v1` remains the explicit ordered-source format. Version 2
selects one entry and lets the resolver derive the order:

```json
{
  "schema": "nucleus-project/v2",
  "root": ".",
  "entry": "src/main.nu",
  "target": "nucleus-target.json",
  "sourceBanks": {
    "src/lib/display.nu": 1
  },
  "outputs": {
    "nobj": "build/program.nobj",
    "hex": "build/program.hex",
    "d8": "build/program.d8.json"
  }
}
```

On a banked target, a listed logical source uses its assigned bank; every
unlisted source defaults to `entryBank`. The entry source must use `entryBank`.
The host derives the ordinal `partBanks[]` array after dependency ordering, so
the project-v2 target layout document omits the positional array. The completed
compiler target contains the derived array and no source names. A flat project
omits `sourceBanks`.

One positional CLI source is an import-discovery entry. Multiple positional
sources retain explicit written ordering for compatibility.

## SP1 source plan

SP1 is a generated, line-oriented plan for a filesystem-aware host, including
a future Z80 operating harness. It is machine-generated but readable. Project
JSON remains the richer Node authoring format.

```text
SP1 3
P 0 13 src/lib/io.nu
P 1 18 src/lib/display.nu
P 0 11 src/main.nu
END
```

The header gives the decimal part count. Each `P` record gives a decimal bank
ordinal, the decimal byte length of the path, and that many printable ASCII
path bytes. Paths are normalized project-relative identities using `/`.
Record order is source-part order. Flat plans use bank zero. The required
`END` record and declared counts reject truncation.

The part count, bank ordinal, and path byte length each occupy the range
0 through 255 in the format; the part count itself must be at least one.

The project root is supplied separately. SP1 contains no target origins,
capacities, service addresses, conditionals, comments, or blank lines. It does
not enter the Nucleus source stream, and the Z80 compiler does not parse it.

## Relation to Atom

Nucleus and Atom may share path, graph, provenance, and SP1 infrastructure.
Their source emission policies remain different:

```text
Nucleus  recognize imports, resolve them, preserve every source byte
Atom     process its directives, mask removed bytes while preserving newlines
```

Nucleus does not adopt Atom's `%define` or conditional source engine through
that common infrastructure.
