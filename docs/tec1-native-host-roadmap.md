# Nucleus native TEC-1 host roadmap

- Status: implementation handoff
- Nucleus ABI: platform services version 1, runtime revision 10, NOBJ 0.1
- Firmware audit: MON3 `898045c`, TECM8 `f1fa719`
- First target: flat loaded RAM program

## 1. What the first native system must prove

The first useful TEC-1 milestone is one complete path:

```text
TEC-FS source files
  -> import resolver
  -> ordered source-part stream
  -> Nucleus compiler in an expansion-ROM bank
  -> committed NOBJ in TEC-FS
  -> NOBJ consumer in an expansion-ROM bank
  -> loaded program in RAM
  -> program service vector
  -> MON3 console and TEC-FS streams
  -> return to the TECM8 shell
```

The compiler, object consumer, and generated program remain three Z80 clients
of one platform-services layer. They run at different times and may reuse RAM,
but they do not acquire separate filesystem or console architectures.

The first milestone does not burn ROM and does not load a newly compiled
program into banked ROM. Producing a banked ROM image remains a build activity
for a host utility or later TEC-side burner. The Node runner proves the banked
NOBJ and far-control contracts independently.

## 2. Existing pieces

Nucleus already supplies:

- the 16 KiB streaming Z80 compiler and stable compiler adapter;
- direct and MON3-compatible compiler transports;
- the import convention and deterministic source ordering rules;
- a 3,018-byte standalone Z80 import-resolver image that commits flat SP1;
- a bounded Z80 SP1 reader, source streamer, and retained-name spool;
- runtime revision 10 and a pre-resolved executable catalogue;
- the append-only NOBJ producer;
- the 2,425-byte one-read Z80 NOBJ consumer with 381 bytes of workspace;
- the generated-program vector and service contracts; and
- flat and banked Node execution through the same Z80 boundaries.

The Node package supplies both the ordinary desktop resolver and a native-path
proof. The latter runs the generated Z80 resolver and source streamer while
Node implements only named-object effects below selector `$91`. The TEC-FS
binding for those object calls and the Z80 NOBJ writer are not yet implemented.
The current resolver emits flat bank-zero plans; native source-bank policy is a
later input to the banked build path.

`asm/vertical-slice/node-nobj-consumer.asm` is a Node reference image, not a
ROM image to flash. Its loader and generated-program adapters use the native
`RST 10h` selector ABI, but the file also installs a three-byte emulator shim
at `$0010`. A TEC-1 build omits that shim because fixed MON3 ROM already owns
the restart vector. It must never replace the hardware vector with the Node
shim.

TECM8 already supplies:

- fixed MON3 `RST 10h` dispatch and bank services `$50..$54`;
- expansion service registration;
- TEC-FS sector, catalogue, path, source-page, and bounded artifact services;
- a resident shell, editor, assembler, and runner workflow;
- source files represented as 32-byte records, with three resident pages in
  the current editor path; and
- a 512-byte binary/map artifact save and load path.

The current 512-byte artifact operation is not sufficient for NOBJ. Even a
small Nucleus program contains the runtime image and record framing, and the
compiler requires separate sequential IMAGE and PATCH spools before final
serialization.

## 3. First deployment profile

Use the already-proved loaded layout:

| Extent | Owner during program execution |
| --- | --- |
| `$4000..$6000` | startup, runtime executable, read-only data, and generated code |
| `$6000..$7000` | runtime vector, runtime state, initialized data, BSS, and established stack |
| `$7000..$704B` | always-visible TEC-1 generated-program service adapter |
| `$8000..$C000` | selected expansion-ROM tool bank; no longer needed after program entry |
| `$C000..$10000` | fixed MON3 ROM |

The target descriptor is:

```text
imageBase        $4000
imageCapacity    $3000
writableBase     $6000
writableCapacity $1000
establishStack   true
services         $7000, $7003, ... in the runtime-vector order
```

This is loaded mode because writable storage lies wholly inside the image.
The runtime begins at `$4003`; the vector and state begin at `$6000` and
`$6024`. The package already builds the corresponding pre-resolved runtime
executable. The native catalogue entry differs only if the packet-service
destination differs from the settled `$7021` entry.

The loader tool may live in an expansion-ROM bank because the flat target does
not switch that bank while loading. Its 381-byte workspace, descriptor, result,
and stack must live outside `$4000..$704B`. The audited first plausible range
is low RAM starting at `$1800`, after the current MON3 display workspace and
before TECM8's `$3B00` parameter area. Exact addresses remain a TECM8 memory-map
decision and require the normal overlap proof.

## 4. Common storage services over TEC-FS

Do not solve this by materializing the complete source unit, compiler output,
or target image in RAM. Add a bounded sequential work-file facility beneath
the Nucleus provider. It implements the same named-object and chunk-transfer
contract used by a later CP/M binding:

```text
openRead, beginWrite, read, write, rewind, seek, close, commit, abort
```

The TEC-FS binding maps those operations to catalogue entries, records, and
fixed work slots. The resolver, compiler adapter, NOBJ writer, and loader all
use this one facility. Compiler selectors `$70..$7F` remain compatibility
entries above it; they are not another storage API.

One compilation generation needs:

1. a read cursor for the current source part;
2. an IMAGE spool;
3. a PATCH spool;
4. a tentative NOBJ output; and
5. one previously committed NOBJ that remains runnable until replacement.

The smallest TEC-FS design is a fixed set of preallocated work files or file
slots. Each has a known maximum extent and supports open, append byte or chunk,
rewind, read byte or chunk, close, and publish-length-last. The compiler writes
IMAGE and PATCH independently, then serializes IMAGE, PATCH, MAP, and COMMIT
into the tentative NOBJ. Successful terminal metadata replaces the published
generation. Abort or reset discards only tentative lengths; it does not need a
general transaction journal or general-purpose dynamic allocator.

This facility must exceed the present 512-byte artifact limit. Its exact bound
must be derived from the selected TEC-1 development profile and available
TEC-FS blocks. The Nucleus protocol permits much larger streams; a smaller
native-host bound is acceptable only when reported as a host capacity failure,
not as a compiler or language limit.

## 5. Source resolver and stream

The resolver belongs to the shell or Nucleus launcher, before compiler entry.
The implemented standalone image takes an entry-object name in `HL/B`, reads
preserved `//% import` headers through named-object ABI 1, detects missing files
and cycles, includes each canonical name once, and commits dependency order to
`.nucleus/source-plan.sp1`. Version 1 admits at most eight source parts because
that is the compiler's published capacity. A TEC-FS provider must supply a
canonical object namespace or reject aliases.

TECM8's 32-byte source records are a storage representation. The source
provider must expose their logical bytes and LF line endings to the compiler;
record padding must not become source text. It should refill a bounded window
as the compiler advances. The current three-page editor buffer may be used as
a cache, but it must not become a 1,536-byte source-language limit. A file may
be reopened or read page by page through TEC-FS.

The resolver retains exact source identities for diagnostics and D8. The
compiler receives ordered part boundaries, bytes, and stable name handles. It
does not receive paths or parse import directives.

## 6. Compiler provider

Bind selectors `$70..$7F` to the existing compiler adapter contracts. Their
implementation uses the common object services from Section 4. The source
streamer owns source refills and retained identities; the NOBJ writer owns the
two spools, MAP/COMMIT serialization, and generation reset; the catalogue
provider owns exact runtime selection. These components share a platform
binding but retain separate state.

Store the one native runtime catalogue entry in ROM beside the host tool or in
another immutable bank. Compilation performs an exact lookup and copies bytes;
it does not run AZM, link, or relocate the runtime. AZM is used only while
constructing and verifying the release image on a development system.

After a successful compile, close the source and spool cursors before returning
to the shell. After any diagnostic, storage failure, operator cancellation, or
unexpected tool exit, run the established reset path and leave the preceding
committed NOBJ selected.

## 7. NOBJ loader provider

Package the existing consumer in a loader tool bank. For the first flat target:

- `Open`, `ReadByte`, and `Close` use the committed TEC-FS NOBJ cursor;
- `SelectTargetBank(0)` is a validated no-op;
- IMAGE writes go directly to `$4000..$6FFF`;
- PATCH writes overwrite those bytes in serialized order;
- MAP and COMMIT are validated after the writes;
- publication records that the RAM image is runnable; and
- entry leaves the loader bank and jumps to `$4000`.

A late failure may leave `$4000..$6FFF` dirty, but it must return to the shell
without entering it. The loader never needs a second object read and never
resolves a symbol.

## 8. Generated-program services

Install the twelve-entry adapter at `$7000` before entry. Its ordinary stream
wrappers call the platform selectors `$66..$6B`. Terminal entries `$6C..$6E`
return control and the initialized Nucleus runtime-state result to the shell.
The packet entry `$6F` preserves the original count while adapting `C` to the
MON3 selector. Unavailable storage or packet operations return their specified
status; no vector may point at uninitialized memory.

The first flat profile does not execute far call or far jump, but those vector
slots still bind to defined unavailable or checked routines. The later banked
runtime adapter uses MON3 `$53` and `$54`, not direct writes to `SYS_CTRL`. Its
far-call wrapper must use the activation-indexed caller-bank and return-address
arenas in runtime state, preserve the existing hardware-stack argument layout,
update the selected-bank byte after each successful hardware switch, and return
through an always-visible address.

Console input/output are byte services. `readLine`, `printLine`, and numeric
formatting remain imported Nucleus library source.

## 9. Acceptance sequence

Implement and prove these increments in order:

1. common named-object and chunk-transfer calls over a narrow Node provider;
2. the same calls over preallocated TEC-FS work files larger than 512 bytes;
3. one source-file byte stream, exact EOF, and diagnostic identity;
4. native import resolution for two files and then the eight-part boundary;
5. compiler IMAGE/PATCH spools and committed NOBJ publication;
6. runtime-catalogue selection for the `$4000/$6000/$7000` profile;
7. the flat consumer loading and rejecting corrupt NOBJ without entry;
8. the `$7000` execution adapter with console success, failure, and trap;
9. the imported `Total: 42` program from TEC-FS to console output; and
10. failure followed by a clean compile/load/run on the same system.

Keep compiler core, compiler workspace, loader code, loader workspace, provider
ROM, provider RAM, catalogue bytes, generated runtime, generated program, NOBJ
storage, instructions, and T-states as separate accounts.

Steps 1, 3, and the Node-backed proof of step 4 are complete. Step 2 is the
next hardware-facing dependency. Step 5 is the next repository implementation
increment and must reuse the object-client helpers already exercised by the
resolver and source streamer.

## 10. CP/M compatibility

No CP/M implementation is required for this milestone. The common service
contract must nevertheless permit a real CP/M implementation without changing
the resolver, source streamer, compiler, NOBJ writer, or flat loader.

A later CP/M binding maps names and handles to FCBs, chunk transfers to buffered
BDOS records, console bytes to BDOS, and terminal control to CP/M. It keeps NOBJ
on disk, exits the compiler before loading the target, and assembles the same
consumer source at a TPA-compatible address. Its first profile is flat and
loaded. It does not need MON3 selectors, TEC-FS records, bank control, Node, or
AZM in its compile-and-run path.

## 11. Explicit non-goals

The first TEC-1 implementation does not require:

- a general TEC-FS transaction journal;
- arbitrary multi-block file allocation for every TECM8 client;
- source or output materialization in one RAM array;
- a linker, runtime linker, or second compiler pass;
- writing newly compiled code into ROM;
- a banked native run before the flat loaded path works; or
- a CP/M implementation.
