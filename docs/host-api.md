# Nucleus Host API 1

## Status and authority

This document defines the supported Node and command-line interfaces for the
standalone Nucleus 0.1 compiler package. The language specification governs
source syntax and meaning. The target-system specification governs target
layout. This interface transports those inputs to the authoritative Z80
compiler and returns its committed artifacts.

Host API 1 does not expose compiler workspace addresses, trace collection or
AZM symbols. Those details may change while the interface in this document
remains compatible.

## Compiler object

Create one compiler object and reuse it for successive builds:

```ts
import { createNucleusCompiler } from "@jhlagado/nucleus";

const compiler = createNucleusCompiler();
const result = await compiler.build({
  sources: [
    {
      name: "src/main.nu",
      source: new TextEncoder().encode("sub main()\nend\n"),
    },
  ],
  target,
  artifacts: { hex: true, d8: true },
});
```

`sources` is an ordered array. `name` is the exact diagnostic source identity;
D8 renders its path separators as `/`. When D8 is requested, these portable
names must be unique, so `a\\b.nu` and `a/b.nu` conflict. `source` accepts a
string or `Uint8Array`. The host preserves source bytes, CRLF handling and
synthesized final-newline behaviour defined by Nucleus 0.1.

`artifacts.hex` requests a flat Intel HEX launch image. `artifacts.d8` requests
one D8 artifact for a flat target or one artifact for every physical bank. NOBJ
is always present after a successful build and remains the canonical compiler
result.

`compileNucleus()` remains available as the low-level compatibility API. New
tool integrations should use the compiler object because its result classifies
all supported failure kinds.

## Results and failures

A successful result contains:

- in-memory NOBJ and each requested launch or debug artifact;
- the validated materialized NOBJ image;
- executed instruction and T-state counts.

A failed result has one of these `kind` values:

| Kind            | Meaning                                                                       |
| --------------- | ----------------------------------------------------------------------------- |
| `source`        | The Z80 compiler rejected source and returned an exact positioned diagnostic. |
| `configuration` | The target, source set, artifact request, or target capacity is invalid.      |
| `execution`     | The emulator, compiler image or output adapter failed to complete normally.   |

The stable API returns these failures rather than mixing source-result objects
with unclassified `Error` and `RangeError` exceptions. A source failure carries
the numeric code, source-part ordinal, diagnostic name, byte offset, line and
byte column emitted by the Z80 compiler.

`formatNucleusDiagnostic()` formats a diagnostic for people.
`nucleusDiagnosticMessage()` returns its descriptive message. Hosts should keep
the numeric code in logs and machine-readable output.

## Target profiles

`parseNucleusTargetProfile()` parses and validates a complete compiler target
from JSON. `validateNucleusTarget()` validates an existing JavaScript value.
Both require the ordinal `partBanks` array for a banked target. A profile may
declare this schema identity:

```json
{
  "schema": "nucleus-target/v1",
  "imageBase": 32768,
  "imageCapacity": 4096,
  "imageFill": 255,
  "writableBase": 16384,
  "writableCapacity": 4096,
  "establishStack": true,
  "services": {
    "readInputByte": 28672,
    "writeOutputByte": 28675,
    "readStorageByte": 28678,
    "rewindStorageInput": 28681,
    "writeStorageByte": 28684,
    "seekStorageOutput": 28687,
    "success": 28690,
    "unhandledFailure": 28693,
    "trap": 28696,
    "farCall": 28699,
    "farJump": 28702
  }
}
```

`imageFill` is an optional byte and defaults to 255. A banked profile uses two
to four banks; a flat profile omits `bankCount`, `entryBank`, and `partBanks`.
A flat writable region
wholly inside the image selects loaded mode; a wholly separate region selects
ROM mode. Partial overlap is invalid, and banked writable storage must remain
outside the bank window.

Validation rejects unknown fields, non-word addresses, zero-length regions, invalid bank ordinals,
source-bank count mismatches and regions that extend beyond the Z80 address
space. A launch build requires all eleven service addresses. The library's
omitted-target defaults remain available to conformance tests, but they are
synthetic addresses rather than a machine integration.

`partBanks` remains the ordinal mapping required by every complete banked
compiler target. A project-v2 banked layout document omits it: the project
resolver derives the array from logical `sourceBanks` after dependency
ordering, then performs strict target validation. The filename-keyed project
field never crosses the compiler boundary.

`validateNucleusTargetLayoutProfileDocument()` and `nucleus target validate`
validate an authoring layout document before the source graph is known. They do
not return a `NucleusTarget`. The final project build must derive and validate
every ordinal against `bankCount` before invoking the compiler.

## Project files

A project file records ordered source, target and output identities:

```json
{
  "schema": "nucleus-project/v1",
  "root": ".",
  "sources": ["src/model.nu", "src/main.nu"],
  "target": "nucleus-target.json",
  "outputs": {
    "nobj": "build/program.nobj",
    "hex": "build/program.hex",
    "d8": "build/program.d8.json"
  }
}
```

Paths are resolved from `root`, which is resolved from the project file's
directory. Source order is significant. Version 1 remains the explicit-order
compatibility format.

Version 2 names one entry source and discovers its leading comment-shaped
imports:

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

The host recognizes `//% import "relative/path.nu"` only in the leading
comment header. It visits dependencies in written order, emits them before
their importer and passes every file to the compiler unchanged as a separate
source part. The directive remains an ordinary Nucleus `//` comment rather
than becoming an import declaration.

For a banked target, `sourceBanks` maps normalized project-relative source
identities to bank ordinals after discovery. Unlisted parts default to
`entryBank`; the entry source must use `entryBank`. Flat projects omit the
mapping.

`parseNucleusProject()` validates the document without reading its files. The
public project host performs the filesystem work:

```ts
import { buildNucleusProject, prepareNucleusProject } from "@jhlagado/nucleus";

const prepared = await prepareNucleusProject("nucleus-project.json");
const { result } = await buildNucleusProject("nucleus-project.json");
```

`prepareNucleusProject()` resolves paths, reads source bytes, orders v2
dependencies, derives ordinal bank assignments, validates the complete target,
and returns absolute publication paths. The returned `sourcePlan` is the
canonical SP1 handoff for a filesystem-aware host. Its `dependencies` array
follows final source order. Each entry contains the logical source identity,
direct import identities, raw byte length, and SHA-256 hash. Version 1 entries
have no import edges because their order is explicit.

`buildNucleusProject()` performs the same preparation and invokes either the
supplied compiler object or a new compiler object. It returns the prepared
project beside the ordinary classified build result. The API does not publish
files; callers may pass the returned artifacts and `prepared.outputs` to
`publishNucleusBuildOutputs()`.

The CLI uses this API for project builds. Other hosts should use it rather than
repeat source discovery or filename-to-bank joining. The source-packaging
contract defines the generated SP1 plan for a future filesystem-aware Z80
host.

## Compiler information

`await compiler.info()` returns:

- host API and language versions;
- runtime identity;
- one SHA-256 fingerprint for each normal or D8 compiler image together with
  the exact symbol map paired with it;
- host source, execution and target limits;
- flat and banked target capabilities.

Release builds contain compiler images generated from the checked AZM source.
`npm run check:compiler-images` assembles both layouts afresh and rejects stale
embedded bytes or symbol maps. AZM remains the build-time authority; the Node
package and Debug80 execute the generated Z80 images directly.

The repository retains `dist` so a commit-pinned Git dependency can run without
assembling the compiler during npm's isolated Git preparation. The
`prepublishOnly` gate verifies and rebuilds those files before registry
publication, and CI verifies that the embedded compiler images match the AZM
sources.

`@jhlagado/debug80-runtime` remains operationally required. Debug80 supplies
its workspace package. A standalone Nucleus checkout uses `npm link` to bind
the compatible Runtime checkout. The peer entry is optional in package metadata
only so Git dependency preparation does not request a registry package.

## Filesystem publication

The compiler API returns bytes and text without writing files.
`publishNucleusBuildOutputs()` optionally publishes NOBJ, HEX and the complete
flat-or-banked D8 group as one recoverable best-effort transaction. It writes
temporary files beside their destinations, backs up the previous generation,
promotes the new set and restores the previous set after a caught promotion
failure. Sequential filesystem renames are not atomic to concurrent readers or
across a process or machine failure.

Debug80 validates every in-memory D8 artifact through its normal D8 validator
before calling this publication function.

## Command line

The [command-line guide](command-line.md) gives the complete installed-package
and import-directed project workflow. This section records the stable interface.

```text
nucleus build [options] source.nu [more.nu ...]
nucleus build --project nucleus-project.json
nucleus target validate target.json
nucleus capabilities --json
```

One positional source is an import-discovery entry. Two or more positional
sources retain explicit written ordering for compatibility. The existing
`-o`, `--hex-output`, `--d8-output` and `--target-profile`
switches remain compatible. Host integrations can select
`--diagnostic-format json` or `--json`. JSON mode also covers usage,
configuration, filesystem and compiler-execution failures. Human-readable
diagnostics include a descriptive message and stable numeric code.

Exit status zero means success. Status one means the requested build failed.
Status two means command use, configuration, filesystem or compiler execution
failed before a successful build could be published.
