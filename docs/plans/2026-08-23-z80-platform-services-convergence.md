# Plan: one Z80 platform-services layer

- Status: Node reference and native TEC-FS named-object provider complete; native vertical slice pending
- Date: 2026-08-23
- Original implementation baseline: `46978f408c2b39f041d776e1d8bddf16d9db5651`
- Stage 1 documentation baseline: `b725dbaa44b3eba4b7a5a714c3f86f916e3eedb6`
- Authority: [Nucleus Z80 Platform Services Architecture](../z80-platform-services.md)

## 1. Outcome

The Nucleus compiler, direct NOBJ loader, and generated programs will use one
Z80 platform-services implementation. Their existing vectors remain as client
adapters because each has a different register and failure contract.

The complete native path will be:

```text
TEC-FS source
  -> import resolver
  -> ordered source stream
  -> Z80 compiler
  -> committed NOBJ
  -> direct NOBJ loader
  -> patched target memory
  -> main
  -> MON3 byte output
```

The Node path will execute the same Z80 adapters under Debug80. Node replaces
only the filesystem, console, catalog, and target-device providers.

This work changes no Nucleus syntax, accepted program, diagnostic, generated
program, runtime ABI, NOBJ record, or compiler capacity. Imported libraries
remain ordinary source compiled into the program.

## 2. Baseline and accounting

Before implementation, reproduce the current standalone gates and retain their
artifacts:

- normal compiler core: 16,314 bytes, 70 bytes free;
- D8 compiler core: 16,380 bytes, four bytes free;
- current MON3 compiler gateway: 981 external code bytes;
- current MON3 host workspace: 24 external writable bytes;
- semantic transcript capacity and exact-fill proof;
- loaded, ROM, banked, D8, import, standard-library, NOBJ-loader, failure, and
  sequential-reuse results; and
- NOBJ, generated image, selected runtime, diagnostics, instruction counts,
  and T-states for representative fixtures.

The ordinary implementation target is zero compiler-core bytes and zero
compiler-workspace bytes. Adapter, platform, runtime catalog, loader, and
generated-runtime costs remain separate accounts. Any compiler-core increase
requires a separate review before retention.

## 3. Terms and ownership

Use these terms consistently in source, APIs, diagnostics, and documentation:

- **platform services**: the one operating boundary implemented by Node,
  MON3/TEC-FS, or another environment;
- **compiler adapter**: the fourteen-entry vector used by the compiler;
- **loader adapter**: the object and target-control vector used by the direct
  NOBJ consumer;
- **runtime vector**: the RAM-resident entries used by generated programs;
- **runtime placement context**: the exact addresses and bounds embedded in one
  resolved runtime image;
- **runtime catalog**: immutable pre-resolved images indexed by identity and
  placement context; and
- **provider**: the implementation beneath the platform operation.

Do not use `runtime linking` for catalog lookup. Preserve a compatibility type
alias for public TypeScript clients if renaming `RuntimeLinkContext` would
otherwise cause an unnecessary API break, but mark it deprecated and use
`RuntimePlacementContext` internally and in new APIs.

## 4. Stage 1: platform inventory and MON3 allocation

Status: complete on 2026-08-23. The resulting allocation and audit are in the
[Z80 Platform Services ABI](../z80-platform-services-abi.md), with the
machine-readable constants and executable stub proof in
`asm/vertical-slice/platform-services-abi.asmi` and
`platform-services-abi-proof.asm`.

Read the current MON3, TECM8, TEC-FS, Nucleus compiler-adapter, runtime-vector,
and NOBJ-consumer contracts in full. Record:

- every occupied `RST 10h` selector;
- register, flag, stack, bank, and failure contracts;
- always-visible monitor, adapter, loader, workspace, and stack extents;
- filesystem operations already available;
- bank-switch and far-control services already available;
- console byte input and output services already available; and
- every existing selector that uses `C` as both service selector and client
  input.

Produce one versioned selector table grouped as execution, sequential storage,
target control, and development support. Retain `$70..$7F` only if the complete
allocation proves that range is safe. The existing saved-`BC` mailbox technique
may adapt calls whose client contract already uses `C`.

Do not force every adapter operation into a generic file call merely to reduce
the number of selector names. A high-level compiler operation may remain one
selector when implementing it inside the Z80 adapter would cost more code or
workspace. The single-layer rule concerns ownership and dispatch, not an
artificially uniform register signature.

Stage 1 ends with an exact ABI document and executable register-contract
stubs. No provider logic proceeds on an assumed selector allocation.

## 5. Stage 2: pre-resolved runtime catalog

Status: core selection is implemented for the Node reference profiles. A
standalone catalogue builder, artifact fingerprinting, and the first native
TEC-1 profile remain to be added.

Replace on-demand runtime assembly during compilation with catalog selection.

### 5.1 Catalog key

Runtime ABI revision 10 separates executable dependencies from per-program
initial state. An executable entry is selected by:

- runtime ABI revision;
- runtime base;
- writable-state base; and
- packet-service destination.

The provider validates the complete placement context. It then constructs the
twelve service vectors and initializes the program-data base and capacity for
the current compilation. These writable bytes are not part of the executable
catalog key.

The entry records:

- resolved runtime bytes;
- the executable placement values used to link them;
- exact start, end, and expected length symbols; and
- every published helper offset.

The provider requires exact equality for the executable key. It never
substitutes an entry built for another runtime base, writable-state base, or
packet-service destination.

### 5.2 Standard and custom targets

Bundle catalog entries for every target context used by the shipped CLI and
tests, then add the first TEC-1 profile when its addresses settle. A custom
target profile has two supported paths:

1. supply a previously prepared catalog entry; or
2. run an explicit offline host utility that assembles the entry before the
   compilation is started.

The second path is target preparation, not part of `nucleus build`. It produces
an immutable catalog artifact which later compilations can consume without AZM.
The native TEC-1 compiler never requires an assembler or linker service.

### 5.3 Transition proof

For every existing placement fixture, compare the catalog bytes with the
current AZM-produced bytes before removing the on-demand provider. Require exact
identity for runtime bytes, initial state, helper offsets, generated programs,
NOBJ, HEX, diagnostics, instruction counts, and T-states.

Only after those comparisons pass may the build path stop invoking AZM. Retain
AZM in the package build and catalog-generation tool; remove it from compiler-
session provider work.

## 6. Stage 3: common Node platform dispatcher

Status: implemented for the Node reference path. Compiler operations use the
MON3 transport by default and retain the direct transport for differential
proofs. The generated standalone consumer and runtime vector use the same
`RST 10h` selector boundary. The Node provider preserves physical banks; the
Z80 adapter implements far call, return, and jump.

Implement one Node provider for the complete platform selector table. Run it
beneath Debug80 Runtime so the Z80 compiler adapter, loader adapter, and runtime
vector all exercise their real machine-code gateways.

Required provider groups are:

- console byte input and output;
- named sequential input;
- tentative sequential output, append, commit, abort, and close;
- runtime-catalog lookup;
- target-bank selection;
- target publication and entry;
- far call and far jump; and
- terminal success, unhandled failure, and trap.

The existing direct proof-port transport may remain as differential evidence.
It is not a second public platform architecture. Every completed MON3 operation
must produce the same logical result as its direct counterpart.

Cancellation or emulator termination invalidates the current generation,
mailbox, saved continuation, retained names, spools, and D8 events. A later
launch starts from initialized state.

## 7. Stage 4: compiler adapter over platform services

Status: implemented. Direct and MON3 compiler transports are byte-identical;
the compiler core remains unchanged by the external gateway.

Keep the compiler's stable fourteen-entry vector and 16 KiB image unchanged.
Route its MON3 wrappers to the common selector table.

Prove:

- source chunks and part boundaries are unchanged;
- retained names remain exact across source refill;
- IMAGE and PATCH calls retain their production order;
- runtime requests select catalog entries without replaying compilation;
- commit and abort retain the previous published generation correctly;
- direct and MON3 transports produce byte-identical artifacts; and
- the compiler core and workspace accounts do not change.

The resolver continues to run before compiler entry. No import parser,
filesystem path, or source-ordering algorithm enters the compiler.

## 8. Stage 5: NOBJ loader over platform services

Status: implemented for flat and banked Node targets. The packaged generated
consumer loads, patches, validates, publishes, and enters NOBJ through the
public Node runner and CLI. The production path now shares the banked selection
evidence with the dedicated consumer fixtures.

Route the direct Z80 consumer's object and target-control adapter through the
same platform selector table.

Strategy zero remains one sequential object read:

1. validate the deployment profile and `BEGIN`;
2. deposit each `IMAGE` payload at its target bank and address;
3. apply each `PATCH` payload in serialized order, with the last write winning;
4. validate `MAP`, `COMMIT`, record count, CRC, and immediate EOF;
5. publish the target; and
6. enter its committed bank and address.

The loader resolves no symbol and performs no runtime linking. A failure may
leave a non-runnable destination dirty; it must not publish or enter it.

Prove flat RAM loading first, then a banked object with real selector changes
while loader code, stack, object cursor, CRC state, and filesystem access remain
available.

## 9. Stage 6: generated-program runtime adapter

Status: implemented for the Node reference path. The generated program
reaches console, sequential storage, terminal, packet, and raw-port Node
providers through the standard twelve-entry Z80 runtime vector. The imported
`Total: 42` library program is an end-to-end acceptance test. Cross-bank calls,
ordinary far returns, and a non-entry-bank trap using far jump are executable
acceptance tests.

Build the selected runtime catalog entry so every service vector destination
reaches the common platform dispatcher. Preserve the twelve-entry runtime
vector layout and all existing source-level service behavior.

The minimum vertical slice needs:

- `readInputByte`;
- `writeOutputByte`;
- terminal success;
- unhandled recoverable failure;
- trap reporting; and
- banked far call and far jump when the first target is banked.

The four implicit storage operations and packet gateway must have explicit
bindings before claiming complete runtime identity `$0009` conformance. An
environment may return the specified unavailable or storage failure for an
operation whose underlying device is absent; it may not leave a vector pointing
at an invalid address.

Prove the standard library through this path. `printLine`, `readLine`, and
integer formatting remain imported Nucleus routines and therefore test the
source-import and platform-byte boundaries together.

## 10. Stage 7: TEC-FS and MON3 providers

Status: the TECM8 repository implements the common named-object request beneath
private selector `$91`, including transactional commit/abort and exact bank,
register, and stack restoration. Native Nucleus client integration, runtime
catalogue, loader target control, and console bindings remain.

Implement the native provider beneath the already proved Z80 adapters:

- open and stream source files selected by the import resolver;
- retain names beyond source-buffer lifetime;
- maintain sequential IMAGE and PATCH spools;
- form and atomically commit the terminal NOBJ generation;
- reopen and stream committed NOBJ to the loader;
- select target banks without hiding loader or monitor state;
- publish and enter the target;
- provide console byte input and output; and
- select the fixed first-target runtime catalog entry.

The first implementation may target one exact TEC-1 memory profile. General
target-profile support follows only by adding prepared catalog entries and
validated deployment bindings; it does not require a native linker.

The filesystem may be slow. Calls remain synchronous from the Z80 client's
point of view, and no parser or backend operation is replayed.

## 11. Acceptance evidence

The Node acceptance suite must prove:

- direct and MON3 compilation equivalence for loaded, ROM, and banked targets;
- exact runtime-catalog selection and rejection of a near-matching context;
- no AZM invocation during a compiler session;
- one imported standard-library program compiled, loaded, and run entirely
  through the common platform dispatcher;
- failed compilation, provider failure, truncated NOBJ, and failed load followed
  by clean reuse;
- D8 publication only for the committed generation;
- patch overlap with last-serialized-write behavior;
- output-bank changes through the loader and generated far calls;
- unchanged compiler code, immutable data, workspace, transcript, runtime,
  generated program, NOBJ, instructions, and T-states; and
- separate measured accounts for every adapter and provider.

The native hardware milestone uses the same `Total: 42` program as the Node
proof. It begins with a source file in TEC-FS and ends with the text printed
through MON3 after loading committed NOBJ.

## 12. Commit sequence

Keep independently reviewable increments:

1. authority and terminology correction;
2. runtime catalog and Node catalog provider;
3. common Node platform selector implementation;
4. compiler adapter migration;
5. NOBJ loader migration;
6. generated-program runtime migration;
7. TEC-FS and MON3 native providers; and
8. hardware vertical-slice evidence and final documentation.

Each increment receives a focused correctness review before any size pass.
Compiler core, compiler workspace, external adapter code, external adapter
workspace, runtime catalog storage, selected runtime bytes, loader bytes, and
generated-program bytes remain separate measurements.

## 13. Exclusions

This work does not add:

- a source-language module linker;
- runtime or load-time symbol resolution;
- dead-code elimination;
- a second compiler pass;
- a filesystem or import resolver inside the compiler;
- new NOBJ records;
- a TypeScript Nucleus compiler;
- a native assembler dependency for compilation;
- dynamic libraries; or
- compiler-core code recovered by moving required state into an unreported
  Z80 account.
