# MON3-compatible platform binding

## Proven paths

Nucleus uses the common boundary defined by the
[Z80 system-services architecture](z80-platform-services.md). The compiler,
NOBJ loader, and generated programs retain separate client adapters because
their register contracts differ. Each adapter ultimately reaches the same
MON3-compatible `RST 10h` dispatcher, with the service selector in `C`.

This file defines one platform binding. It does not define the common storage
model or make `RST 10h` a requirement for CP/M or another Z80 system.

The implemented MON3 slice proves the compiler adapter. The production Node
runner now drives the Z80 NOBJ consumer and generated-program vector through
the same `RST 10h` selector boundary. Node supplies an emulator provider below
the restart vector; a native TEC-1 supplies MON3 and TEC-FS there.

The Node package can run either host transport:

```text
Nucleus compiler -> fixed compiler vector --\
NOBJ loader -----> loader adapter -----------> MON3-compatible RST 10h
generated code --> runtime vector ----------/             |
                                                           +-- Node providers
                                                           +-- TEC-FS and MON3
```

Running the compiler path under Debug80 Runtime exercises the same Z80 gateway
that a native machine needs while Node supplies source files, pre-resolved
runtime images, NOBJ spools, and publication. Replacing Node with TEC-FS and
MON3 providers does not change compiler code, source semantics, generated code,
or NOBJ.

The Node runtime-image provider selects an exact pre-resolved catalogue entry.
AZM produces those entries during package generation, not during a compiler
session. Compilation, loading, and execution perform no runtime linking. The
same division is required on hardware: a TEC-1 installation stores the entry
for its fixed target profile and supplies it when the compiler requests that
runtime revision and placement.

Select the proof path from the command line with:

```bash
nucleus build --host-transport mon3 -o program.nobj src/main.nu
```

The API equivalent is `hostTransport: "mon3"` on `NucleusBuildRequest`, or on
the options passed to `compileNucleusTo()`. Direct transport remains the
default.

## Reference memory map

The MON3-compatible compiler image uses this Z80 layout:

| Extent          | Use                                                             |
| --------------- | --------------------------------------------------------------- |
| `$4000..$43D5`  | compiler-host vector, gateway, source adapter, and launch shell |
| `$4400..$4965`  | named-object source provider and common-service dispatcher      |
| `$5800..$5818`  | 24 bytes of host workspace                                      |
| `$5900..$5939`  | target, launch, and result descriptors                          |
| `$5A00..$5E00`  | source provider and NOBJ-writer workspace, overlaid by phase    |
| `$5FFF`         | native-host return sentinel                                     |
| `$6000..$7000`  | compiler workspace                                              |
| `$7000..$7500`  | retained-token scratch                                          |
| `$7500..$7800`  | streaming source refill window                                  |
| `$7E00..$7F00`  | compiler stack extent; initial `SP = $7F00`                     |
| `$8000..$C000`  | 16 KiB compiler bank                                            |
| `$C000..$10000` | fixed monitor ROM, untouched by this image                      |

The low reset and restart vectors remain available to the monitor. The Node
proof installs a three-byte `OUT`/`RET` shim at `$0010` only after loading the
image. That shim is an emulator device adapter, not part of the compiler image
or the hardware ABI.

Normal compiler core is 16,314 bytes and ends at `$BFBA`, leaving 70 bytes in
the bank. The D8-instrumented host image is 16,380 bytes and ends at `$BFFC`,
leaving four bytes. D8 hooks remain conditional: the normal native image does
not pay their 66-byte cost. The compiler-host vector occupies 981 external Z80
code bytes. The object client, source provider, NOBJ writer, and dispatcher add
2,913 external code bytes. The writer accounts for 1,312 of those bytes and
448 bytes of external workspace, including its 256-byte transfer buffer. None
of these bytes is counted as compiler core.

The platform writes the validated target's `imageFill` byte into
`NativeNobjImageFill` before launch. Parsing may use the writer's transfer
buffer as a second retained-name comparison buffer; the transcript barrier
ends all source parsing before target generation reuses that memory.

The import resolver is a separate tool image. Its current proof image occupies
`$8000..$8BDA` and uses bounded RAM below `$6D00`. A shell runs it first,
selects the compiler bank second, and leaves only the committed SP1 object
between those steps. Its copy of the shared object-client code belongs to that
tool image and does not consume compiler-bank headroom.

## Compiler-adapter selectors

Platform ABI 1 allocates compiler-adapter selectors `$70..$7F`. These are
compiler operations within the complete platform table; they do not replace
the execution, storage, target-control, and development groups.

|   `C` | Operation                                                |
| ----: | -------------------------------------------------------- |
| `$70` | next source event or byte chunk                          |
| `$71` | retain current name                                      |
| `$72` | compare retained name                                    |
| `$73` | materialize retained name                                |
| `$74` | begin tentative target generation                        |
| `$75` | append one IMAGE byte                                    |
| `$76` | select and append a pre-resolved runtime image           |
| `$77` | obtain and append the entry bank's initial runtime image |
| `$78` | append a one-byte PATCH                                  |
| `$79` | append a two-byte PATCH                                  |
| `$7A` | append a flat MAP                                        |
| `$7B` | append a banked MAP                                      |
| `$7C` | commit the generation                                    |
| `$7D` | abort the generation                                     |
| `$7E` | begin a compiler launch                                  |
| `$7F` | finish a compiler launch                                 |

Each wrapper adapts this selector convention to the register, flag, stack, and
failure contract of the stable compiler-host vector. The exact RST contracts
are checked by AZM from
`asm/vertical-slice/mon3-host-services.asmi`. A monitor implementation must
match those contracts; it must not merely dispatch to a routine with a similar
purpose.

Several stable vector entries already use `C` for a source-part or target-bank
value. The RST dispatcher needs `C` for its selector, so the gateway saves the
original `BC` in its two-byte request mailbox before those calls. The selected
service reads that saved value. This mailbox is part of the measured 24-byte
host workspace; it is not compiler workspace and is never live across two
concurrent launches.

The calls are synchronous from the compiler's point of view. A native service
may block while a slow filesystem operation completes. The Node proof may
suspend its outer execution loop while provider work completes, then resume
the same Z80 call. Neither path replays parsing or backend generation.

## Object and loader boundary

The target calls write an append-only NOBJ generation. IMAGE records carry
ordinary target bytes. PATCH records arrive later and overwrite their addressed
bytes in stream order when an NOBJ consumer loads or materializes the object.
The last patch to an address wins. COMMIT is the only permission to enter or
publish the resulting program.

The compiler host does not need enough RAM to retain the target image. On a
native system, source and object streams may be backed by a filesystem. When a
program is launched, the loader deposits IMAGE bytes at their target addresses,
applies PATCH records, validates the terminal COMMIT, and then enters the
program. Producing a materialized binary or Intel HEX file is an optional host
utility operation, not a compiler pass.

## Evidence and remaining hardware work

The compiler proof compares direct and MON3 transports for loaded, ROM, and
banked targets, including D8 collection. NOBJ bytes, MAP and COMMIT metadata,
diagnostics, and D8 maps are identical. A failed launch followed by a successful
launch proves generation reset. Separately, the production Node runner uses the
Z80 consumer to load committed NOBJ and runs a bundled-library program through
the generated-program vector with observable console output. That runner also
proves nested physical-bank calls and non-entry-bank terminal transfer. It does
not claim that the still-missing native TEC-1 wrappers already exist.

The remaining work is the machine-specific platform implementation: bind the
allocated MON3/TECM8 selectors, add TEC-FS source and object storage, provide
console byte I/O, bank selection and entry, and far control transfer, then
install the catalogue entry for the chosen TEC-1 target profile. The Node
catalogue and provider already prove the selection boundary. The compiler,
loader, and generated program reach the native facilities through their
existing adapters. Their absence does not justify adding filesystem knowledge
or monitor calls to the compiler core. The concrete order, memory map, storage
gap, and acceptance tests are in the
[native TEC-1 host roadmap](tec1-native-host-roadmap.md).
