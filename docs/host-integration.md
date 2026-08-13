# Nucleus host and Debug80 integration

## Repository boundary

The Nucleus repository owns the language specification, grammar, Z80 compiler,
runtime contract, NOBJ implementation, conformance programs, and the Node
compiler package. Debug80 consumes released Nucleus artifacts; it does not
govern the language or carry a second compiler implementation.

Debug80 owns editor registration, project configuration, build orchestration,
artifact loading, debugging, and publication of a versioned documentation
snapshot. The published documentation records the Nucleus revision from which
it was copied.

## First host compiler

The first Node compiler executes the Z80 compiler through Debug80 Runtime. It
uses the same multipart source ABI and target descriptor as a native invocation
and accepts only a terminally committed NOBJ generation. The host reports the
compiler's diagnostic code, source-part identity, byte offset, line, and column.
The CLI always writes canonical NOBJ and can additionally materialize the flat
target as Intel HEX with `--hex-output`. The HEX file is a launch adapter; NOBJ
remains the stored compiler result and source of target metadata.
With `--d8-output`, the host runs a conditionally instrumented image of the same
Z80 compiler and derives a native D8 sidecar without changing NOBJ or target
bytes. Flat builds write the requested map; banked builds write one map per
physical bank. The trace protocol and publication rules are defined in
[Nucleus D8 source maps](d8-source-maps.md).
A launch adapter must supply a target profile with real implementations of all
eleven vector destinations. The library's default addresses describe the
synthetic conformance target; they are not Debug80 or monitor entry points.
The current Debug80 backend compiles its selected `.nu` file as a one-part
manifest. A project-level ordered multipart manifest remains a separate
integration step; the Nucleus CLI and compiler API already accept several
ordered source files.
Debug80's application loader currently accepts one flat Intel HEX image, so
the Nucleus launch backend rejects profiles with `bankCount > 1` before
invoking the compiler. Standalone banked NOBJ and per-bank D8 production remain
available; Debug80 does not flatten those objects or invent a selected-bank
policy.

The implementation assembles the compiler from its checked AZM source and
caches the shipping and D8-instrumented images separately. Each image is paired
with the symbols from that exact assembly. A release build may replace this
step with embedded compiler images after a reproducible-image gate compares the
embedded bytes and symbols with fresh AZM output.

`@jhlagado/debug80-runtime` is a required peer and is not yet published.
Standalone CI therefore builds it from a pinned Debug80 revision. Publishing
the runtime package removes this bootstrap without changing the compiler API.

## Debug80 stages

1. Register `.nu` as a Nucleus source language with syntax highlighting and
   comment/bracket configuration.
2. Add a Nucleus build backend beside the AZM and Glimmer backends. It invokes
   the standalone `nucleus build` CLI, writes NOBJ and launchable target
   artifacts, and translates structured diagnostics into Debug80 diagnostics.
3. Add Nucleus targets to project discovery and configuration without treating
   `.nu` as assembly.
4. Publish a checked-in documentation snapshot from a pinned Nucleus revision.
5. Produce a validated D8 sidecar from Z80 trace events and enable line-level
   Nucleus source breakpoints and PC lookup through Debug80's normal map path.

## Reference compiler

A TypeScript compiler may be developed later. The emulated Z80 compiler remains
the executable oracle until differential tests establish identical accepted and
rejected programs, diagnostics and positions, materialized program bytes,
target layout, and selected runtime. NOBJ record segmentation need not match
unless a later format revision makes segmentation canonical.
