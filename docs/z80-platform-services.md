# Nucleus Z80 Platform Services Architecture 0.1

- Status: settled architecture; concrete MON3 selector assignments remain provisional
- Applies to: native and emulated Z80 deployments
- Last reviewed: 2026-08-23

## 1. Purpose

Nucleus uses one platform-services layer on a Z80 system. The compiler, NOBJ
loader, and generated programs are different clients of that layer. They do not
require separate operating environments.

The [native Z80 adapter contract](native-z80-host-contract.md) defines the
register-level interfaces presented to the compiler and NOBJ loader. The
[runtime and backend contract](z80-runtime-contract.md) defines the vector
presented to generated programs. This document defines the common platform
boundary beneath those adapters.

The reference call path is:

```text
Nucleus compiler ---- compiler adapter ---\
                                          \
NOBJ loader -------- loader adapter --------> Z80 platform services
                                          /             |
Generated program -- runtime vector -----/              +-- MON3 and TEC-FS
                                                        +-- Node providers
                                                        +-- CP/M adapter
```

The adapters preserve their own register, flag, stack, and failure contracts.
They translate those contracts to one platform implementation. An adapter is
not another service layer.

On a TEC-family machine, MON3 and TEC-FS implement the platform services. In
the Node reference environment, the same Z80 adapters run under Debug80 and
Node implements the operations beneath them. A difference in provider does not
change compiler code, generated code, source semantics, or NOBJ.

## 2. Whole-program construction

Nucleus has no source-language linker. The source resolver reads `//% import`
headers, discovers each dependency once, orders the source parts, and streams
that ordered unit to the compiler. Every imported declaration and routine is
compiled as part of the program. Nucleus 0.1 performs no dead-code elimination.

Standard-library routines such as `printLine`, `readLine`, and integer
formatters are ordinary imported Nucleus source. They are not platform
services. Their lowest-level operations call the generated-program runtime
vector, which then reaches the platform.

NOBJ `PATCH` records also do not constitute linking. The compiler has already
calculated every replacement byte. The loader writes `IMAGE` bytes to their
destination and applies `PATCH` bytes in serialized order as part of loading.
It resolves no name, type, branch kind, library, or relocation expression.

## 3. Target runtime images

The target runtime contains compiler-selected Z80 helpers, the generated-
program service adapter, trap support, and fixed initial runtime state. It does
not contain imported Nucleus libraries.

A compilation selects a complete, pre-resolved runtime image from a catalog.
The lookup key contains the runtime identity and the exact validated placement
context used by that image: runtime base, writable and vector addresses,
service destinations, and the data bounds embedded by the runtime revision.
The selected entry records its exact length, helper offsets, vector layout, and
initial writable-state bytes.

The provider verifies an exact catalog match and appends the selected bytes as
ordinary NOBJ `IMAGE` records. It does not assemble, link, or relocate the
runtime during compilation. No runtime binding occurs while loading or running
the program. An unsupported placement context produces a target-configuration
failure.

An offline release process may use AZM to build catalog entries. That process
is not part of the compiler session, the NOBJ protocol, the loader, or the Z80
platform-services ABI. A fixed TEC-1 target can therefore ship one catalog
entry; a host that supports several exact target profiles can ship several.

Existing implementation names such as `runtimeImage` describe the operation
that appends a selected image. They do not authorize an operating-layer linker.
Names containing `LinkContext` are legacy implementation names for the runtime
placement context and should be replaced during the implementation increment.

## 4. Platform capabilities

The platform ABI is divided into capability groups. One versioned dispatcher
may expose all groups. A deployment profile states which groups are present.

### 4.1 Execution

The execution group is sufficient for an ordinary console program:

- read one byte from standard input;
- write one byte to standard output;
- terminate successfully;
- report an unhandled recoverable failure;
- report a Nucleus trap; and
- enter an operator-break path when the platform provides one.

The first two operations are the only console primitives required by the
standard library. Line handling, string traversal, number formatting, and
error propagation remain Nucleus source.

### 4.2 Sequential storage

The storage group supports source packaging, compiler output, object loading,
and source programs that explicitly use storage:

- open a named input object;
- read its next byte or bounded chunk, with EOF distinct from every byte value;
- close the input object;
- create a tentative output generation;
- append bytes to that generation;
- commit the complete generation;
- abort the tentative generation; and
- seek or rewind only where the selected client contract requires it.

The compiler adapter uses these operations to supply ordered source parts and
to maintain separate IMAGE and PATCH spools. The NOBJ loader uses them to read
one committed object. A source program receives only the storage operations
declared by the generated-program service vector; it does not inherit compiler
file handles or filesystem names.

### 4.3 Target control

The target-control group supports loading and banked execution:

- select a physical target bank from a validated logical bank binding;
- publish a validated target generation and entry pair;
- enter the published bank and address;
- perform a far call; and
- perform a far jump.

After selecting a bank, the NOBJ loader writes target memory directly. The
platform does not need a service for every deposited byte or patch. Loader
code, workspace, storage state, and stack must remain visible across bank
selection.

### 4.4 Development support

The development group contains state required specifically by the streaming
compiler adapter:

- supply ordered source-part events and bounded chunks;
- retain, compare, and temporarily materialize exact source names;
- begin, append to, commit, and abort an NOBJ generation; and
- select and append an exact pre-resolved runtime catalog entry.

These are adapter operations rather than general source-program services. A
native adapter may implement retained names and NOBJ spools with TEC-FS; the
Node adapter may implement them with host memory and files. Both implementations
present the same adapter contract to the compiler.

## 5. Deployment profiles

Three profiles define useful subsets of the one ABI.

| Profile | Required capability groups | Purpose |
| --- | --- | --- |
| Execution | execution, plus target control for banked code | run a previously loaded Nucleus program |
| Loader | sequential storage and target control | consume committed NOBJ and enter it |
| Development | execution, sequential storage, target control, and development support | resolve imports, compile, store, load, and run |

The development profile is a capability superset of the execution profile.
The compiler-host adapter is not a register-level superset of the generated-
program runtime vector: their operations and calling conventions differ. Both
terminate at the same platform dispatcher.

## 6. Client adapters

### 6.1 Compiler adapter

The compiler continues to call its stable fourteen-entry vector. The adapter
implements source events, retained names, NOBJ construction, runtime-catalog
selection, and publication by using the platform capability groups. The
compiler remains unaware of paths, directories, filesystems, MON3 selectors,
and Node.

The import resolver runs before this interface. It presents one ordered source
generation; the compiler does not read import directives or search for files.

### 6.2 NOBJ loader adapter

The loader continues to use its object and target-control entries. It opens a
committed NOBJ stream, deposits IMAGE bytes, applies PATCH bytes in serialized
order, checks MAP and COMMIT, publishes the validated target, and enters it.
A second pass over source or compiler output is not involved.

### 6.3 Generated-program runtime vector

Generated code continues to call the RAM-resident runtime vector. Its standard
entries cover byte input, byte output, the existing implicit storage streams,
terminal paths, far control transfer, and the packet gateway. The adapter
translates those entries to the platform ABI. A target may bind unused entries
to a defined unavailable-service result.

## 7. Common call discipline

The concrete MON3 binding uses `RST 10h` with the selector in `C`. Selector
numbers outside the already proved compiler range remain provisional until the
MON3 and TECM8 projects allocate the complete table.

Every synchronous service must define:

- input, result, preserved, and clobbered registers;
- flags defined on return;
- stack shape on success and failure;
- EOF or end-of-stream representation where applicable;
- selected-bank behavior;
- partial-effect rules; and
- status mapping at the client adapter.

Unless a service explicitly states otherwise, carry clear means success, carry
set means failure, `A` contains a nonzero platform status on failure, `IX` and
`IY` are preserved, and the hardware stack returns to its call-entry depth.
Platform statuses do not become Nucleus source diagnostics or recoverable
failure codes without an explicit adapter mapping.

An emulated provider may suspend the outer execution loop while Node completes
an asynchronous filesystem operation. The Z80 call remains synchronous: the
provider resumes the saved continuation once, without replaying parser or
backend work.

## 8. Publication and failure

Source input, retained names, output spools, D8 events, and runtime-catalog
selection belong to one compilation generation. A failed or interrupted
generation releases those resources and cannot replace the preceding committed
NOBJ or D8 artifact.

The NOBJ loader may leave bytes in a non-runnable destination after a late
validation or storage failure. It must not publish or enter that destination.
PATCH overlap is valid; the last serialized replacement wins.

The platform-services layer does not parse Nucleus source, resolve Nucleus
symbols, select source dependencies, reinterpret PATCH records, or generate
runtime machine code.

## 9. Required implementation work

The current Node and Z80 proof path establishes the compiler adapter and direct
NOBJ consumer. Completion of this architecture requires:

1. a formal MON3/TECM8 selector allocation for the common capability groups;
2. one Z80 platform gateway used by the compiler adapter, loader adapter, and
   generated-program runtime vector;
3. TEC-FS implementations of sequential source and object storage;
4. native retained-name and IMAGE/PATCH spool implementations;
5. target-bank selection, publication, entry, far-call, and far-jump services;
6. a pre-resolved runtime-image catalog for the first TEC-1 target profile;
7. replacement of the Node provider's compile-time runtime assembly with the
   same catalog-selection contract; and
8. end-to-end Node and TEC-1 proofs from imported source through console output.

The acceptance path is:

```text
TEC-FS source
  -> import resolver
  -> ordered source stream
  -> Z80 compiler
  -> committed NOBJ
  -> direct NOBJ loader
  -> patched target memory
  -> main
  -> platform byte output
```

The first native proof program prints `Total: 42` through the standard library.
