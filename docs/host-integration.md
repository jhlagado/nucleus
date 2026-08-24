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
The compiler adapter, NOBJ loader, and generated-program runtime vector sit
over the one boundary defined by the
[Z80 system-services architecture](z80-platform-services.md). Node is the
implemented desktop provider. The package now includes a standalone Z80 import
resolver and a Z80 SP1 source streamer. Both obtain stored bytes through
named-object ABI 1. A MON3 and TEC-FS implementation of that ABI remains
hardware work.

The ordinary Node project host performs import discovery and owns the IMAGE and
PATCH spools. The native-path proof instead runs the prebuilt Z80 resolver,
commits SP1, and lets the Z80 source provider stream that plan into the
compiler. Node supplies file effects beneath the object gateway; it does not
parse directives or order dependencies in that path. The remaining native
producer work is the Z80 IMAGE/PATCH spool and NOBJ writer.

The CLI always writes canonical NOBJ. It can also materialize a flat Intel HEX
launch artifact with `--hex-output`. HEX is a launch adapter; NOBJ remains the
compiler result and source of target-layout metadata.

`nucleus run` and `runNucleusNobj()` take the canonical object in the other
direction. They execute the packaged standalone Z80 consumer, which fills the
target image, applies PATCH records in order, validates the committed stream,
and requests entry. Node then runs the target through the standard
generated-program service vector. Flat and banked objects use the same path;
banked execution retains separate physical images behind the visible window
and exercises far call, return, and jump.

With `--d8-output`, the host runs a conditionally instrumented image of the
same Z80 compiler and derives a D8 sidecar without changing NOBJ or target
bytes. Flat builds write the requested map. Banked builds write one map for
each physical bank. The trace protocol and publication rules are defined in
[Nucleus D8 source maps](d8-source-maps.md).

A launch adapter supplies a target profile with real implementations of all
twelve vector destinations. The production Node runner installs its Z80
adapter at the package's default addresses. A hardware profile must replace
those addresses with callable entries in its own always-visible memory.

The native package uses a MON3-compatible transport beneath the compiler
adapter by default and retains the older direct transport for differential
proofs. The MON3 form relocates the
compiler to the `$8000..$C000` bank window, preserves monitor vectors and fixed
ROM, and calls sixteen bounded compiler operations through `RST 10h`. Node runs
this real Z80 gateway during ordinary and proof builds. These allocated
selectors are the implemented compiler group, not a second platform layer. A
hardware deployment
replaces only the provider below the common dispatcher. See the
[MON3-compatible platform binding](mon3-host-binding.md).

Debug80 loads either an explicit Nucleus project or its conventional project
layout, reads every source part in manifest order, and calls the standalone
compiler in process. It translates structured failures into editor
diagnostics, validates returned D8 through its ordinary importer, stores the
map beside the launch artifact, and uses that same map for line-level source
breakpoints and PC lookup. The sidecar retains byte columns even though the
current debugger behavior is line-oriented.

Debug80's application loader accepts one flat Intel HEX image. Its launch
backend therefore rejects profiles with `bankCount > 1` before compilation.
Standalone banked NOBJ and per-bank D8 production remain available; Debug80
does not flatten those objects or invent a selected-bank policy.

The package contains generated shipping and D8-instrumented compiler images,
the standalone import-resolver image, and the NOBJ consumer image. Each image
is paired with symbols from the same assembly. The reproducible image gate
assembles these layouts from checked AZM source and rejects stale embedded
bytes or symbol maps. Runtime compilation and execution use the generated
bytes and do not import AZM.

The package also contains a generated catalogue of pre-linked target runtime
images for its supported target profiles. A compiler session selects one of
those images and supplies the target's vector destinations and program-data
bounds as initial writable bytes. It does not invoke AZM. AZM remains an
offline build authority: the generation gate rebuilds the catalogue from the
runtime source and rejects stale entries. A custom placement must provide a
compatible `RuntimeImageProvider` prepared before compilation.

No normal build or run operation imports AZM. AZM belongs to package generation
and proof support. Assembly helpers must remain outside the published runtime
module graph so an installed Node package, a TEC-1G installation, and a CP/M
installation all consume the same prebuilt compiler and catalogue boundary.

`@jhlagado/debug80-runtime` is an operationally required peer. During local
development it is supplied by the linked Debug80 package; the optional npm
peer metadata only prevents isolated Git preparation from requesting an
unpublished registry package.

## Implemented Debug80 components

- `.nu` language registration, syntax highlighting, comments, and brackets;
- Nucleus project discovery and configuration without treating source as
  assembly;
- an in-process build backend beside the AZM and Glimmer backends;
- explicit ordered multipart loading and import-directed source discovery;
- NOBJ and flat launch-artifact publication;
- D8 validation, storage, source breakpoints, and PC lookup; and
- generated documentation reading editions pinned to standalone revisions.

## Compiler authority

The handwritten Z80 compiler is the sole executable compiler. A TypeScript
port is not part of the current architecture. Any future proposal for another
compiler would require differential evidence for accepted and rejected source,
diagnostics and positions, materialized program bytes, target layout, and
selected runtime before it could claim compatibility.
