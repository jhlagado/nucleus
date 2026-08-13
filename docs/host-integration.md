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

The initial implementation assembles the compiler from its checked AZM source
once per Node process and caches that image. A release build may replace this
step with an embedded compiler image after a reproducible-image gate compares
the embedded bytes and symbols with fresh AZM output.

`@jhlagado/debug80-runtime` is currently an unpublished peer package. Standalone
CI therefore builds that peer from a pinned Debug80 revision. Publishing the
runtime package removes this bootstrap without changing the compiler API.

## Debug80 stages

1. Register `.nu` as a Nucleus source language with syntax highlighting and
   comment/bracket configuration.
2. Add a Nucleus build backend beside the AZM and Glimmer backends. It invokes
   `compileNucleus`, writes NOBJ and launchable target artifacts, and translates
   structured diagnostics into Debug80 diagnostics.
3. Add Nucleus targets to project discovery and configuration without treating
   `.nu` as assembly.
4. Publish a checked-in documentation snapshot from a pinned Nucleus revision.
5. Define a D8-compatible source-map sidecar before enabling Nucleus source
   breakpoints and stepping.

## Reference compiler

A TypeScript compiler may be developed later. The emulated Z80 compiler remains
the executable oracle until differential tests establish identical accepted and
rejected programs, diagnostics and positions, materialized program bytes,
target layout, and selected runtime. NOBJ record segmentation need not match
unless a later format revision makes segmentation canonical.
