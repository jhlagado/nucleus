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

The standalone Nucleus host now resolves a project-v2 entry and its leading
`//% import` comments. Debug80 has not yet adopted that project path. A later
integration increment can call the same exported resolver or a shared package;
it must preserve the ordered source parts and unchanged bytes supplied to the
compiler.

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
- ordered multipart source loading;
- NOBJ and flat launch-artifact publication;
- D8 validation, storage, source breakpoints, and PC lookup; and
- generated documentation reading editions pinned to standalone revisions.

Import-directed project-v2 discovery remains a planned Debug80 adoption item.
The implementation currently belongs to the standalone Nucleus host package.

## Next host integration increment

Debug80 should adopt project version 2 through the standalone package rather
than implement another dependency scanner. The integration work is bounded:

1. move the CLI's project loading and final ordinal bank derivation behind one
   exported host function;
2. have Debug80 call that function for `.nu` project builds while retaining its
   existing diagnostics, D8 validation, and artifact publication;
3. compare explicit version 1 and discovered version 2 builds for identical
   NOBJ, HEX, D8, source identities, and target mappings; and
4. retain the current flat-only Debug80 launch gate until its loader has a
   physical-bank selection model.

The standalone `nucleus` command remains a compiler and artifact publisher.
A generic `run` command would require a separately reviewed emulated target,
including input, output, storage, terminal, trap, and far-transfer service
behaviour. The source resolver does not supply that machine policy.

## Compiler authority

The handwritten Z80 compiler is the sole executable compiler. A TypeScript
port is not part of the current architecture. Any future proposal for another
compiler would require differential evidence for accepted and rejected source,
diagnostics and positions, materialized program bytes, target layout, and
selected runtime before it could claim compatibility.
