# MON3-compatible compiler host

## What this binding proves

The Nucleus compiler does not need Node, an emulator trap convention, or a
filesystem API built into the compiler. It calls a fixed Z80 host vector. The
MON3-compatible build implements that vector through `RST 10h`, with the
service selector in `C`.

The Node package can run either host transport:

```text
Nucleus compiler
        -> fixed compiler-host vector
        -> direct proof ports, or MON3-compatible RST 10h services
        -> Node providers
```

Running the second path under Debug80 Runtime is deliberate. It exercises the
same Z80 gateway that a native machine needs while Node still supplies source
files, runtime linking, NOBJ spools, and publication. Replacing Node with real
monitor and filesystem implementations does not change compiler code, source
semantics, generated code, or NOBJ.

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
| `$5800..$5818`  | 24 bytes of host workspace                                      |
| `$5900..$5939`  | target, launch, and result descriptors                          |
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
not pay their 66-byte cost. The MON3 gateway occupies 981 external Z80 code
bytes and 24 host-workspace bytes. None of those external bytes is counted as
compiler core.

## Service selectors

The current reference binding reserves expansion selectors `$70..$7F`. They
are provisional until the monitor project assigns them formally.

|   `C` | Operation                                                |
| ----: | -------------------------------------------------------- |
| `$70` | next source event or byte chunk                          |
| `$71` | retain current name                                      |
| `$72` | compare retained name                                    |
| `$73` | materialize retained name                                |
| `$74` | begin tentative target generation                        |
| `$75` | append one IMAGE byte                                    |
| `$76` | obtain and append a linked runtime image                 |
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
suspend its outer execution loop while runtime bytes are linked, then resume
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

The executable proof compares direct and MON3 transports for loaded, ROM, and
banked targets, including D8 collection. NOBJ bytes, MAP and COMMIT metadata,
diagnostics, and D8 maps are identical. A failed launch followed by a successful
launch proves generation reset. A bundled-library program is imported,
compiled through the MON3 path, loaded from committed NOBJ, and executed with
observable console output.

What remains outside this repository is the machine-specific provider: formal
MON3/TECM8 selector allocation, filesystem and console implementations, bank
device access, and a native runtime-image provider. Those services sit below
the contract above. Their absence does not justify adding filesystem knowledge
or monitor calls to the compiler core.
