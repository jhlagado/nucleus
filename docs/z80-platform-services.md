# Nucleus Z80 tool-service architecture

- Architecture status: settled
- Register-level implementation: platform ABI 1 in transition
- Applies to: native and emulated Z80 development and execution
- Last reviewed: 2026-08-25

## 1. Purpose

Nucleus is intended to compile and run on a Z80 without depending on Node,
Debug80, AZM, or a particular monitor. Import resolution, source streaming,
compilation, NOBJ writing, and NOBJ loading use one private tool-service
boundary. It belongs to the compiler and its development environment, not to
Nucleus source programs.

The compiler is one client of that boundary. It is not the boundary itself and
does not require a private filesystem architecture. Generated programs use
their separate twelve-entry runtime vector. A platform may implement both
interfaces over the same BDOS, firmware, or Node primitives, but it must not
give generated programs compiler sources, spools, catalogues, or publication
operations.

This document defines that common architecture. The
[native Z80 adapter contract](native-z80-host-contract.md) defines the existing
interfaces presented to the compiler and NOBJ loader. The
[runtime contract](z80-runtime-contract.md) defines the interface presented to
generated programs. The [MON3 binding](mon3-host-binding.md) maps the private
tool services to TEC-1G firmware. The implemented CP/M compiler and
generated-program adapters use public BDOS calls; the common named-object CP/M
binding remains incomplete.
The [named-object ABI](z80-object-services-abi.md) fixes the request block and
operation semantics used by native development tools.

## 2. Terms and boundaries

The following terms have distinct meanings.

- A **tool service** is a private, platform-independent operation available to
  a compiler, resolver, writer, or loader, such as reading a console byte,
  reading from an open object, or committing tentative output.
- A **client interface** is the call shape already used by one component. The
  compiler-host vector and NOBJ-loader adapter are tool client interfaces.
- A **client adapter** translates a client interface into tool-service calls.
- A **platform binding** translates tool-service calls into MON3, TEC-FS,
  CP/M BDOS, Node, or another implementation.
- A **provider** performs the external effect beneath a platform binding.

Client interfaces may differ because existing code already calls them and
because the compiler's 16 KiB limit makes call-site bytes important. Those
differences do not justify separate console, storage, or target-control
systems. New Z80 development components call the common tool services directly
unless a measured compatibility constraint requires an adapter.

## 3. Complete native path

A self-contained Z80 development system performs this sequence:

```text
entry source name
  -> Z80 import resolver
  -> ordered source-part plan
  -> Z80 source streamer
  -> Z80 compiler
  -> Z80 NOBJ writer
  -> committed NOBJ object
  -> Z80 NOBJ loader
  -> generated program
```

The resolver and NOBJ writer are part of the development environment. The
16 KiB compiler core remains filesystem-unaware, but the complete system does
not. The resolver must open named source objects, and the NOBJ writer must
create, write, commit, and abort stored objects.

The source streamer does not concatenate the complete program in RAM. After
dependency discovery, it reopens each source part in dependency order and
supplies bounded chunks. The compiler reads each source byte once and emits
logical IMAGE, PATCH, MAP, COMMIT, and ABORT operations. The NOBJ writer stores
those operations without materialising the generated target image.

## 4. Common tool services

The common layer is divided by capability. A deployment reports the groups it
implements. A client checks its required groups before beginning work.

### 4.1 Identity and capabilities

Every binding reports:

- the tool-services ABI revision;
- implemented capability groups;
- service availability; and
- any deployment capacity that the client must check before an operation.

An unavailable operation returns a defined status. It never jumps to
uninitialised memory or silently substitutes another operation.

### 4.2 Console and terminal control

The execution group provides:

- read one byte from standard input;
- write one byte to standard output;
- terminate successfully;
- terminate with an unhandled recoverable failure;
- terminate with a Nucleus trap; and
- enter an operator-break path when the platform provides one.

Line editing, string traversal, number formatting, and standard-library
routines remain Nucleus source. The system layer transfers bytes and terminal
results.

### 4.3 Named object and sequential storage

The storage group provides one common object model for source files, work
spools, NOBJ files, runtime-catalogue entries, and program-selected storage.
Its logical operations are:

```text
openRead(name) -> handle
beginWrite(name) -> tentative handle
read(handle, destination, capacity) -> count or EOF
write(handle, source, count)
rewind(handle)
seek(handle, offset)
close(handle)
commit(handle)
abort(handle)
```

A handle is an opaque bounded value owned by the provider. A name is a bounded
byte string supplied by the resolver, shell, or loader. The compiler core never
receives a path or handle merely because the common layer supports them.

`read` and `write` transfer bounded chunks. A byte-oriented client may keep a
small local buffer over those operations. TEC-FS records, CP/M DMA records,
Node file descriptors, sectors, allocation blocks, and directory structures
remain inside their platform bindings.

Tentative output becomes visible only after `commit`. `abort` releases the
tentative generation without replacing the preceding committed object. A
platform with weaker filesystem primitives may implement this with fixed work
files, publish-length-last, or a bounded copy at commit; it must preserve the
observable generation rule.

### 4.4 Runtime catalogue

Compilation selects an exact pre-resolved runtime image by ABI identity and
placement context. The selected bytes may reside in ROM, a file, or another
immutable object. The system layer returns or streams an existing entry. It
does not assemble, link, or relocate a runtime during compilation.

A fixed TEC-1G installation may contain one catalogue entry beside the host
tool. A CP/M installation may keep a catalogue file. A desktop package may
embed several generated entries. The lookup and storage differ; the bytes and
identity checks do not.

The bounded Z80 request and chunk contract is defined by the
[runtime-catalogue services ABI](z80-runtime-catalog-services-abi.md). The
catalogue service returns resolved bytes; it does not own NOBJ framing or
publication.

### 4.5 Target control

The target-control group provides:

- select a validated physical target bank;
- publish a validated loaded generation and entry pair;
- enter the published program;
- perform a far call; and
- perform a far jump.

The loader deposits IMAGE bytes and applies PATCH bytes directly to the target
destination. The system layer does not need a service call for every deposited
byte when the destination is locally writable.

## 5. Private gateway discipline

The private Z80 ABI uses a numbered service gateway. A platform binding supplies
one callable gateway to each client image. Platform ABI 1 places the selector
in `C`. Existing compiler wrappers preserve a conflicting `BC` value in a
private mailbox. The converged object-service calls will instead use bounded
request blocks, so `BC` has no second meaning at the common boundary.

Unless an operation states otherwise:

- carry clear reports success;
- carry set reports failure with a nonzero platform status in `A`;
- `IX` and `IY` are preserved;
- `SP` returns to its entry value;
- the selected bank is unchanged; and
- a failed operation publishes none of that operation's logical effect.

Request blocks and transfer buffers remain valid for the synchronous duration
of the call. A banked provider may require them to occupy always-visible RAM.
The provider does not retain their addresses after return.

The gateway transport is a platform-binding detail:

```text
TEC-1G: client adapter -> selector in C -> RST 10h -> MON3/TEC-FS
CP/M:   client adapter -> selector in C -> CP/M binding -> CALL 0005h
Node:   client adapter -> same Z80 gateway -> narrow external provider
```

CP/M BDOS function numbers and MON3 selectors are not Nucleus source semantics.
A CP/M binding maps a Nucleus service to the required BDOS operation and adapts
its request block, registers, status, buffering, and partial-effect rules.

## 6. Client mappings

The components share primitive services while retaining private algorithms and
state:

| Common facility   | Resolver                  | Compiler adapter        | NOBJ writer               | Loader                 | Generated program     |
| ----------------- | ------------------------- | ----------------------- | ------------------------- | ---------------------- | --------------------- |
| console bytes     | optional diagnostics      | no                      | no                        | optional diagnostics   | standard input/output |
| named-object open | source discovery          | through source streamer | work-object creation      | NOBJ open              | unavailable           |
| chunk read        | import headers and source | next-source callback    | spool serialization       | NOBJ records           | selected storage only |
| chunk write       | optional plan             | no direct call          | IMAGE, PATCH, and NOBJ    | no                     | selected storage only |
| commit and abort  | optional plan             | generation callbacks    | NOBJ publication          | target publication     | unavailable           |
| runtime catalogue | no                        | exact runtime request   | serializes returned bytes | validates identity     | unavailable           |
| target control    | no                        | records target map      | no                        | select, publish, enter | far control only      |

The table describes capability use, not permission inheritance. The generated
program column describes the separate runtime provider, not access to the
tool-service gateway. A generated program cannot open a compiler source or
publish compiler output, and a resolver cannot publish a target.

### 6.1 Import resolver and source streamer

The resolver starts with one entry-source name. It uses named-object services
to read only the preserved `//% import` headers, resolves each source once,
detects cycles, and records dependency order. It then closes its discovery
cursors.

The source streamer reopens each ordered source object and supplies begin,
name, byte-chunk, and end events to the compiler. Source identities remain
stable for diagnostics and D8. The resolver may store a compact ordered plan;
it never needs to store the combined source text.

### 6.2 Compiler

The existing compiler calls a fourteen-entry compiler-host vector. That vector
is a compatibility interface, not a second operating system. Its adapter maps:

```text
next source chunk       -> source streamer over common object reads
retain or compare name  -> resolver-owned identity storage
begin output            -> tentative common objects for IMAGE and PATCH
append IMAGE or PATCH   -> buffered common object writes
runtime image request   -> common runtime-catalogue lookup
commit or abort         -> common generation operations
```

The existing call sites remain compact while the compiler is constrained to
16 KiB. A later measured change may collapse some entries into direct
tool-service calls, but no implementation may create another filesystem or
console boundary beneath the compiler vector.

### 6.3 NOBJ writer and loader

The NOBJ writer owns the IMAGE and PATCH spools, record framing, integrity
fields, MAP serialization, and final COMMIT. It uses the same named-object and
sequential-storage services as the resolver.

The loader opens one committed NOBJ, deposits IMAGE records, applies PATCH
records in order, validates MAP and COMMIT, publishes the target, and enters
it. It uses common storage and target-control services. It does not resolve
source names, call AZM, or replay compiler work.

### 6.4 Generated programs

Generated programs currently call a twelve-entry RAM-resident runtime vector.
That vector is a separate program interface over target runtime services. Its
entries cover six standard streams, three terminal paths, far call, far jump,
and the target-specific packet gateway.

The twelve entries do not measure the private tool-service boundary. They are
the fixed operations required directly by runtime ABI revision 10. The packet
entry supplies a bounded program-extension namespace. Compiler, resolver, and
loader services are not exposed to generated programs.

## 7. Platform mappings

### 7.1 TEC-1G

The TEC-1G binding uses MON3's `RST 10h` dispatcher and TEC-FS. The binding
must provide named-object and sequential work-file operations larger than the
current 512-byte artifact path. It buffers the compiler's byte and chunk calls,
keeps request blocks and cursors visible across bank changes, and implements
generation commit without retaining the complete source, NOBJ, or target image
in RAM.

### 7.2 CP/M

The first CP/M profile is flat and loaded. Its binding maps named objects to
FCBs, sequential transfers to buffered BDOS records, console bytes to BDOS
console operations, and terminal return to CP/M. The Z80 resolver, source
streamer, compiler, NOBJ writer, and flat loader remain the same components.
Only the binding and deployment memory map change.

Generated CP/M programs enter BDOS at `$0005`. Standard input uses blocking
console input, including CP/M echo, control processing, and operator-break
behavior. The returned console byte is seven-bit; portable console text is
ASCII `$00..$7F`. Standard output uses the ordinary BDOS console-output
operation. High-bit storage bytes remain unchanged because named-object and
generated-program storage do not pass through the console capability.

CP/M is therefore a real deployment target, not an analogy used to justify a
Node API. A design that requires Node memory, JavaScript callbacks, AZM, or an
emulator-only I/O trap in the compilation path is not a conforming CP/M path.

### 7.3 Node and Debug80

Node supplies the same external effects during desktop use and executable
proofs. The narrow provider may read host files, append to host spools, display
console bytes, and maintain physical bank images. The Z80 clients retain the
same call paths and service contracts.

The proof-only direct-port transport may compare results with the real gateway,
but it is not a platform architecture. A native-path proof must run the Z80
resolver, source streamer, compiler adapter, NOBJ writer, loader, and generated
program being claimed. Node may implement services beneath their gateway; it
must not replace those Z80 components with hidden orchestration while claiming
native completion.

## 8. AZM boundary

AZM is an offline construction and verification tool. It may:

- assemble the compiler and host images during package generation;
- assemble the finite runtime catalogue during package generation;
- assemble proof programs and compare checked artifacts; and
- verify that committed generated sources are reproducible.

Normal `nucleus build`, `compileNucleusTo`, NOBJ loading, and generated-program
execution do not call AZM. A native Z80 installation stores the assembled
compiler, host components, loader, and required runtime-catalogue entries. A
CP/M installation does the same in files or system images.

Production Node modules must not import AZM as a latent runtime fallback.
Assembly helpers belong to package-generation or test support and must remain
outside the published runtime module graph.

## 9. Implementation state

The following paths are implemented:

- Node import discovery and deterministic ordering;
- common named-object services with a Node provider and Z80 client;
- a TECM8/MON3 named-object provider over a bounded TEC-FS private arena;
- the standalone Z80 import resolver and bounded SP1 source streamer;
- the streaming Z80 compiler and fourteen-entry compiler adapter;
- the MON3-compatible compiler gateway exercised under Debug80;
- sequential Node-backed IMAGE and PATCH spools;
- pre-generated runtime-catalogue selection and its bounded Z80 chunk gateway;
- the flat and banked Z80 NOBJ writer over those object and catalogue gateways;
- the Z80 NOBJ consumer;
- flat and banked generated-program execution under Node;
- the native CP/M compiler adapter with FCB-backed source input, addressed
  output, and transactional publication;
- the generated CP/M program adapter with public BDOS console and storage
  operations; and
- one end-to-end native proof from Z80 import resolution through cross-bank
  generated-program execution.

The following hardware bindings and packaging inputs remain incomplete:

- the TEC-FS binding beneath the Z80 resolver, source streamer, and retained-name provider;
- TEC-FS IMAGE, PATCH, and tentative-NOBJ work objects;
- native source-bank assignment for the Z80 resolver;
- the hardware NOBJ loader binding and generated-program adapter; and
- the common named-object CP/M binding beneath the resolver, streamer, writer,
  and loader.

The MON3-compatible emulator path proves the Z80 algorithms, register
contracts, and service selectors. TECM8 separately proves the named-object
effect provider, media-failure atomicity, and hardware bank restoration. The
combined native compiler-to-loader path and its complete hardware memory map
remain unproved.

## 10. Implementation order and acceptance

Implementation proceeds from the common services upward:

1. define and prove the named-object and chunk-transfer request blocks;
2. implement a narrow Node provider for those exact calls;
3. implement the Z80 resolver and source streamer against that provider;
4. define and implement native source-bank assignment for the Z80 resolver;
5. run resolver, compiler, writer, loader, and generated program end to end;
6. bind the proved calls to TEC-FS and MON3; and
7. add the flat CP/M binding without changing the Z80 clients.

The first native acceptance program begins as source files in TEC-FS and ends
by printing `Total: 42` after loading the committed NOBJ. The corresponding
CP/M proof begins as CP/M source files and follows the same component sequence.
Every proof reports provider code, provider workspace, compiler core, compiler
workspace, external object storage, loader, runtime, generated program,
instructions, and T-states as separate accounts.

## 11. Rules for later work

Later implementation work follows these rules:

- Define a common tool service before adding a Node callback, MON3 selector,
  CP/M wrapper, compiler entry, or runtime-vector entry for the same effect.
- Keep dependency discovery and named-object access outside the 16 KiB compiler
  core, but implement them as Z80 components for a native development profile.
- Do not claim native completion when Node performs source resolution, NOBJ
  construction, loading, or runtime linking in place of the specified Z80
  component.
- Do not call AZM during compilation, object loading, or generated-program
  execution. Ship preassembled compiler and runtime-catalogue bytes.
- Do not materialise the complete ordered source, compiler output, NOBJ, or
  banked target merely to cross a service boundary. Use bounded buffers and
  sequential objects.
- Treat the compiler-host vector and loader adapter as private tool client
  interfaces. Keep the generated-program vector separate; sharing lower-level
  platform primitives does not grant compiler-development capabilities.
- Prove a new common service under the narrow Node provider and at least one
  real Z80 binding. Emulator-only port interception is differential evidence,
  not the native transport.
