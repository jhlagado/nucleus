# Nucleus command-line compiler

The Node command-line harness runs the authoritative Z80 Nucleus compiler. It
discovers source dependencies, prepares the ordered multipart input, executes
the compiler through Debug80 Runtime, and publishes the committed object and
requested sidecars. It does not parse or compile Nucleus in TypeScript.

## Requirements

The harness requires Node 20 or later. `@jhlagado/azm` is a normal package
dependency because the operating layer links the selected Nucleus runtime for
the target addresses used by each build.

`@jhlagado/debug80-runtime` is also required at execution time. Its peer entry
is temporarily marked optional because that package has not yet been published
independently. A development installation supplies it from a Debug80 checkout:

```bash
cd /path/to/debug80/packages/debug80-runtime
npm link

cd /path/to/nucleus
npm install
npm link @jhlagado/debug80-runtime
npm run build
node dist/cli.js --help
```

Once Debug80 Runtime is published, an ordinary package installation can supply
both packages without the link step.

## First build

The repository and npm package contain an import-directed example. From a
Nucleus checkout:

```bash
node dist/cli.js build \
  --project examples/import-project/nucleus-project.json
```

An installed package keeps examples under its package directory. Copy the
example before building so its generated files remain in the application
workspace:

```bash
cp -R node_modules/@jhlagado/nucleus/examples/import-project ./nucleus-example
npx nucleus build --project nucleus-example/nucleus-project.json
```

The build writes:

- `build/program.nobj`, the canonical committed Nucleus object;
- `build/program.hex`, a flat Intel HEX launch image; and
- `build/program.d8.json`, the corresponding D8 source map.

The paths are relative to the project root, which is itself relative to the
project file.

## Import-directed source

A source file lists dependencies in its leading comment header:

```nucleus
//% import "lib/console.nu"
//% import "model.nu"

sub main()
end
```

The host resolves each path relative to the importing file. It visits imports
in written order, emits dependencies before their importer, and includes a
physical file once. Import directives may be separated by blank lines and
ordinary `//` comments. The first line containing Nucleus source closes the
header; a later import directive is an error.

The host passes every source byte to the compiler unchanged. The Z80 tokenizer
treats each directive as an ordinary comment, while diagnostics and D8 records
retain the original file, byte offset, line, and column.

One positional source enables import discovery:

```bash
nucleus build -o build/program.nobj src/main.nu
```

Two or more positional sources retain the older explicit order and do not
perform discovery:

```bash
nucleus build -o build/program.nobj src/model.nu src/main.nu
```

Use `--root` when positional source identities should be relative to a directory
other than the current working directory.

## Project files

`nucleus-project/v2` records one entry source and lets the host derive the
complete order:

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

The command is:

```bash
nucleus build --project nucleus-project.json
```

Project mode takes its root, target, and output paths from the document, so it
cannot be combined with positional sources or the corresponding command-line
switches. Version 1 projects remain available when an application must state
the complete source order explicitly.

A banked version 2 project may add `sourceBanks`, keyed by normalized
project-relative source identity. Unlisted dependencies use `entryBank`. The
host converts those names to the final ordinal `partBanks[]` array after
dependency resolution; filenames never cross the compiler boundary.

## Target profiles

Nucleus always produces NOBJ. Intel HEX additionally requires a flat target
profile:

```bash
nucleus build -o build/program.nobj \
  --hex-output build/program.hex \
  --d8-output build/program.d8.json \
  --target-profile nucleus-target.json \
  src/main.nu
```

The profile supplies image and writable regions, stack policy, and the eleven
external service destinations. A profile can be checked before compilation:

```bash
nucleus target validate nucleus-target.json
nucleus target validate --json nucleus-target.json
```

The target in the bundled example uses synthetic service addresses to
demonstrate the profile and artifact pipeline. A machine profile must replace
them with callable implementations supplied by that monitor, operating system,
or emulator.

Banked builds publish NOBJ and one D8 map per physical bank. Intel HEX output is
flat-only because one address-tagged HEX image cannot identify several physical
banks that share the same visible addresses.

## Compilation and launch

`nucleus build` ends after it publishes artifacts. It does not emulate the
compiled application or provide implementations for target services.

For a flat target, the HEX file is the launch image and the NOBJ map supplies
its entry address and memory layout. A loader must install the image, provide
the service destinations named by the target profile, establish any
machine-specific state, and enter the recorded address. Debug80 can load the
flat HEX artifact and its D8 sidecar. Its current project backend has not yet
adopted version 2 import discovery, so the standalone CLI should build the
artifacts before that handoff.

Banked execution requires an NOBJ-aware loader that preserves physical-bank
identity. The current Debug80 application launcher accepts only flat HEX, even
though the standalone compiler can produce banked NOBJ and bank-scoped maps.

A future `nucleus run` command would need a defined emulated target and service
implementation. Import discovery and compilation alone do not define those
machine behaviours.

## Diagnostics and automation

Human-readable diagnostics are the default. `--json` or
`--diagnostic-format json` writes structured success or failure records:

```bash
nucleus build --json -o build/program.nobj src/main.nu
```

Exit statuses are:

| Status | Meaning                                                                                                     |
| -----: | ----------------------------------------------------------------------------------------------------------- |
|    `0` | Compilation and requested publication succeeded.                                                            |
|    `1` | The Nucleus compiler rejected the source.                                                                   |
|    `2` | Command use, packaging, target configuration, filesystem access, compiler execution, or publication failed. |

`--quiet` suppresses successful path messages without changing diagnostics.
`nucleus capabilities --json` reports the compiler identity and current
capacities for scripts and editor integrations.

## Current capacities

The host rejects an input before compilation when dependency discovery exceeds
the compiler's public multipart limits:

- at most eight source parts;
- at most 2,048 source-window bytes, including five descriptor bytes per part;
- logical source identities of 1 through 255 printable ASCII bytes; and
- at most four target banks.

The capability command is the machine-readable authority for the values in an
installed compiler. The source-packaging document defines path normalization,
cycle detection, symbolic-link confinement, deduplication, SP1 plans, and
bank-assignment rules in detail.

## Package verification

Repository maintainers can exercise the same boundary as an installed user:

```bash
npm run build
npm run check:package
```

The package check creates a tarball and an isolated consumer, invokes the
installed `nucleus` binary, compiles the bundled version 2 project, and validates
its NOBJ, HEX, D8, capabilities, public NOBJ parser, source-failure status, and
usage-failure status. It then loads the flat image through Debug80 Runtime,
supplies terminal service stubs, enters the NOBJ entry address, and verifies
both successful termination and the program's stored result. This check also
prevents build-time-only dependencies from leaking into the command-line
runtime.
