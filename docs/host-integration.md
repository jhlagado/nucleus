# Nucleus host and Debug80 integration

## Repository boundary

The standalone Nucleus repository owns the language specification, grammar,
Z80 compiler, runtime contract, NOBJ implementation, conformance programs, and
Node compiler package. Debug80 consumes a versioned or commit-pinned Nucleus
package; it does not govern the language or contain another compiler.

Debug80 owns editor registration, project discovery, build orchestration,
artifact loading, source breakpoints, and PC-to-source lookup. The separate
Debug80 documentation project publishes generated reading editions pinned to
identified standalone Nucleus revisions.

## Implemented host path

The Node compiler executes the Z80 compiler through Debug80 Runtime. It uses
the same ordered multipart source ABI and target descriptor as a native
invocation and accepts only a terminally committed NOBJ generation. Host API 1
classifies configuration, source, and execution failures. Exact compiler
diagnostics retain source-part identity, byte offset, line, and byte column.

The CLI always writes canonical NOBJ. It can also materialize a flat Intel HEX
launch artifact with `--hex-output`. HEX is a launch adapter; NOBJ remains the
compiler result and source of target-layout metadata.

With `--d8-output`, the host runs a conditionally instrumented image of the
same Z80 compiler and derives a D8 sidecar without changing NOBJ or target
bytes. Flat builds write the requested map. Banked builds write one map for
each physical bank. The trace protocol and publication rules are defined in
[Nucleus D8 source maps](d8-source-maps.md).

A launch adapter supplies a target profile with real implementations of all
eleven vector destinations. The library's default addresses describe the
synthetic conformance target; they are not Debug80 or monitor entry points.

The standalone Nucleus host resolves a project-v2 entry and its leading
`//% import` comments. Debug80 calls `prepareNucleusProject()` from that package,
so the CLI and debugger use the same source order, unchanged bytes, target-bank
derivation, and target validation. Debug80 contains no dependency scanner.

The existing Debug80 backend translates structured failures into editor
diagnostics, validates returned D8 through its ordinary importer, stores the
map beside the launch artifact, and uses that map for line-level source
breakpoints and PC lookup. The sidecar retains byte columns even though the
current debugger behavior is line-oriented.

Debug80's application loader accepts one flat Intel HEX image. Its launch
backend therefore rejects profiles with `bankCount > 1` before compilation.
Standalone banked NOBJ and per-bank D8 production remain available; Debug80
does not flatten those objects or invent a selected-bank policy.

The package contains generated shipping and D8-instrumented compiler images.
Each image is paired with the symbols from that exact assembly. The
reproducible image gate assembles both layouts from checked AZM source and
rejects stale embedded bytes or symbol maps. Node and Debug80 execute those
Z80 images directly.

`@jhlagado/debug80-runtime` is an operationally required peer. During local
development it is supplied by the linked Debug80 package; the optional npm
peer metadata only prevents isolated Git preparation from requesting an
unpublished registry package.

## Implemented Debug80 components

- `.nu` language registration, syntax highlighting, comments, and brackets;
- Nucleus project discovery and configuration without treating source as
  assembly;
- an in-process build backend beside the AZM and Glimmer backends;
- explicit and import-directed multipart source loading through the standalone
  host API;
- NOBJ and flat launch-artifact publication;
- D8 validation, storage, source breakpoints, and PC lookup; and
- generated documentation reading editions pinned to standalone revisions.

## Target profiles and execution

A named machine-profile registry belongs to the operating host. A registry
entry may select a complete Nucleus target profile, runtime service provider,
and loader, but the name and registry do not enter source or the Z80 compiler.
No built-in TEC-1 or CP/M profile should be published until its memory map and
all service destinations have executable implementations and conformance
tests.

The standalone `nucleus` command remains a compiler and artifact publisher.
A runner is target-specific: it must implement input, output, storage,
terminal, trap, far-transfer, memory, and bank-selection behaviour required by
its profile. Import discovery does not define those machine operations, so the
host API has no generic `run` method.

`prepareNucleusProject()` also returns the canonical SP1 source plan. A
filesystem-aware Z80 host can consume that bounded plan while Node and Debug80
continue to use the richer project document and dependency metadata.

## Compiler authority

The handwritten Z80 compiler is the sole executable compiler. A TypeScript
port is not part of the current architecture. Any future proposal for another
compiler would require differential evidence for accepted and rejected source,
diagnostics and positions, materialized program bytes, target layout, and
selected runtime before it could claim compatibility.
