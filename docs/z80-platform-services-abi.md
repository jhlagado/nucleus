# MON3 binding for Nucleus system services ABI 1

- Status: implemented compiler binding; native storage provider incomplete
- ABI version: 1
- Audit date: 2026-08-23
- Nucleus revision: `b725dbaa44b3eba4b7a5a714c3f86f916e3eedb6`
- MON3 revision: `898045c5fdd5c5190d41bf3de63c14870ac2bb31`
- TECM8 revision: `f1fa7193b36a0705a5e1fcb4b8f5b27a2cc69ec4`

## 1. Scope

This document allocates the MON3 `RST 10h` selectors currently used by Nucleus
and defines the TEC-1G binding at that boundary. It is not the
platform-independent system-services architecture. That architecture is
defined in [Nucleus Z80 system services](z80-platform-services.md).

The compiler, loader, and generated-program vectors are compatibility client
interfaces. Their adapters translate to the common service meanings and then
to this binding. A CP/M implementation preserves the common meanings but need
not reproduce these selector numbers, MON3 register damage, or `RST 10h`.

The selector is always in `C`. Unless an entry below says otherwise, carry
clear means success, carry set means failure with a nonzero platform status in
`A`, `IX` and `IY` are preserved, the selected bank on return is the caller's
bank, and `SP` returns to its entry value. An adapter maps platform status to
its own failure convention.

## 2. Audited selector space

| Range      | Owner                                     | State                        |
| ---------- | ----------------------------------------- | ---------------------------- |
| `$00..$3E` | classic MON3 `RST 10h` table              | occupied                     |
| `$3F..$4F` | MON3                                      | reserved; not allocated here |
| `$50..$54` | fixed bank control                        | occupied                     |
| `$55..$5F` | MON3                                      | reserved; not allocated here |
| `$60..$64` | TECM8 VDU, TEC-FS mount, RTC, GLCD, input | occupied                     |
| `$65..$6F` | Nucleus execution and implicit streams    | allocated below              |
| `$70..$7F` | Nucleus compiler/development adapter      | allocated below              |
| `$80..$83` | TECM8 shell                               | occupied                     |
| `$84..$8A` | Nucleus NOBJ loader                       | allocated below              |
| `$8B..$8F` | expansion                                 | reserved                     |
| `$90`      | TECM8 nested-call ABI proof               | occupied by proof builds     |
| `$91..$FF` | expansion                                 | unallocated                  |

MON3 routes every selector at or above `$60` to the installed expansion
dispatcher. Bank 0's registry therefore owns the concrete mapping for every
Nucleus selector. Unknown or unavailable services return carry set. A
deployment must not silently reuse an allocated selector for another service.

## 3. Execution and implicit streams

These entries back runtime-vector ordinals 0 through 8, 11, and the platform
identity query. Far control uses the fixed entries in Section 6.

| Selector | Name                     | Entry                                                         | Success                  | Preserved                   | Failure                |
| -------: | ------------------------ | ------------------------------------------------------------- | ------------------------ | --------------------------- | ---------------------- |
|    `$65` | `NUCLEUS_PLATFORM_INFO`  | none                                                          | `A=1`, `DE=capabilities` | `BC,HL,IX,IY`               | never                  |
|    `$66` | `NUCLEUS_READ_INPUT`     | none                                                          | `A=byte`                 | `BC,DE,HL,IX,IY`            | platform input status  |
|    `$67` | `NUCLEUS_WRITE_OUTPUT`   | `A=byte`                                                      | `A=0`                    | `BC,DE,HL,IX,IY`            | platform output status |
|    `$68` | `NUCLEUS_READ_STORAGE`   | none                                                          | `A=byte`                 | `BC,DE,HL,IX,IY`            | EOF or storage status  |
|    `$69` | `NUCLEUS_REWIND_STORAGE` | none                                                          | `A=0`                    | `BC,DE,HL,IX,IY`            | storage status         |
|    `$6A` | `NUCLEUS_WRITE_STORAGE`  | `A=byte`                                                      | `A=0`                    | `BC,DE,HL,IX,IY`            | storage status         |
|    `$6B` | `NUCLEUS_SEEK_STORAGE`   | `HL=offset`                                                   | `A=0`                    | `BC,DE,HL,IX,IY`            | storage status         |
|    `$6C` | `NUCLEUS_EXIT_SUCCESS`   | exit record in fixed RAM                                      | does not return          | n/a                         | n/a                    |
|    `$6D` | `NUCLEUS_EXIT_FAILURE`   | failure record in fixed RAM                                   | does not return          | n/a                         | n/a                    |
|    `$6E` | `NUCLEUS_EXIT_TRAP`      | trap record in fixed RAM                                      | does not return          | n/a                         | n/a                    |
|    `$6F` | `NUCLEUS_PACKET`         | `A=slot`, `HL=packet`, original `BC=count` in adapter mailbox | `A=0`                    | `IX,IY`, caller bank, stack | platform packet status |

Capability bits returned in `DE` are: bit 0 execution, bit 1 sequential
storage, bit 2 target control, bit 3 development support, bit 4 operator break,
and bits 5 through 15 zero. Version 1 callers reject `A != 1` or a missing
required capability before using the rest of the table.

`C` cannot simultaneously carry a selector and a client value. Adapters for
packet count and any other `BC` input save the original pair in fixed RAM or a
private parameter block before loading `C`. The expansion service reconstructs
the client value before entering provider code.

The conformance profiles report these exact masks:

| Profile           | Required mask | Meaning                                |
| ----------------- | ------------: | -------------------------------------- |
| execution, flat   |       `$0001` | console and terminal services          |
| execution, banked |       `$0005` | execution plus target control          |
| loader            |       `$0006` | sequential storage plus target control |
| development       |       `$000F` | every mandatory group                  |

Operator break adds `$0010` to any profile but is never mandatory. The default
Node compiler transport and the production Node NOBJ runner now exercise this
selector boundary and provide the required groups. The retained direct-port
transport is differential evidence and does not claim ABI version 1. The
current TECM8 ROM still predates the complete dispatcher; the native provider
must pass the Stage 7 acceptance tests before it claims `$000F`.

## 4. Compiler compatibility entries

Selectors `$70..$7F` retain the existing meanings and contracts in
`asm/vertical-slice/mon3-host-services.asmi`: source-next, retain-name,
compare-name, materialize-name, target-begin, image-byte, runtime-image,
runtime-initial-image, patch-byte, patch-word, map-flat, map-banked, commit,
abort, launch-begin, and launch-end, in that order.

This is a high-level compatibility boundary for the existing 16 KiB compiler.
It is not a second filesystem interface. The source resolver, source streamer,
runtime-catalogue provider, and NOBJ writer implement these entries with the
common named-object and sequential-storage services. The compiler itself never
receives a path or handle.

The current Node provider implements the high-level entries directly. The
native increment must factor their storage effects through the common object
operations before claiming a complete TEC-1G development profile. New Z80
tools, including the native import resolver, call the common object operations
instead of adding more compiler-specific selectors.

Calls whose client contract uses `BC` save it in `NativeHostMon3InputBC`
before loading the selector. Entries documented as preserving `IX/IY` must do
so even though the raw TECM8 expansion gateway treats those registers as
scratch. Entries already documented as clobbering them need no extra save.

## 5. NOBJ-loader entries

| Selector | Name                     | Client contract                                                                           |
| -------: | ------------------------ | ----------------------------------------------------------------------------------------- |
|    `$84` | `NUCLEUS_NOBJ_OPEN`      | `HL=name`; returns `A/carry`; clobbers `BC,DE,HL`; preserves `IX,IY`                      |
|    `$85` | `NUCLEUS_NOBJ_READ_BYTE` | returns `A/carry`; preserves `BC,DE,HL,IX,IY`                                             |
|    `$86` | `NUCLEUS_NOBJ_REWIND`    | returns `A/carry`; clobbers `BC,DE,HL`; preserves `IX,IY`                                 |
|    `$87` | `NUCLEUS_NOBJ_LOCK`      | returns `A,DE,HL/carry`; clobbers `BC`; preserves `IX,IY`                                 |
|    `$88` | `NUCLEUS_NOBJ_PUBLISH`   | `A,BC,DE,HL,IX` as loader contract; preserves `IY`                                        |
|    `$89` | `NUCLEUS_NOBJ_ENTER`     | `A=bank`, `HL=entry`, `IX=binding`; does not return on success; preserves `IY` on failure |
|    `$8A` | `NUCLEUS_NOBJ_CLOSE`     | returns `A/carry`; clobbers `BC,DE,HL`; preserves `IX,IY`                                 |

The loader adapter owns any saved-`BC` mailbox or parameter block required by
`$88`. Its select-target-bank entry does not use an expansion selector. It
validates the logical binding, then invokes fixed `MON_BANK_SELECT` `$52`
directly. An ordinary expansion call cannot implement this operation because
its fixed-ROM return path restores the caller's bank. Successful selection
therefore requires the loader's code, object cursor, workspace, stack, and
filesystem state to remain visible in every selected bank. A failed selection
leaves the caller's bank unchanged. `ENTER` is the only loader operation
permitted to abandon the caller's continuation on success.

## 6. Fixed target-control entries

Nucleus reuses, rather than duplicates, the TECM8 fixed services:

| Selector | Name              | Control inputs                                                      |
| -------: | ----------------- | ------------------------------------------------------------------- |
|    `$50` | `MON_SYS_GET`     | none                                                                |
|    `$51` | `MON_SYS_SET`     | monitor-defined mask/value                                          |
|    `$52` | `MON_BANK_SELECT` | physical bank                                                       |
|    `$53` | `MON_BANK_CALL`   | `B=bank`, `C=$53`, `HL=target` after helper saves client `AF,DE,HL` |
|    `$54` | `MON_FAR_JUMP`    | `B=bank`, `C=$54`, `HL=target` after helper saves client state      |

The raw gateway may clobber `B,C,IX,IY`. A normal banked target returns with
`RET`; fixed ROM restores the previous `SYS_CTRL`, preserves the callee's final
`AF`, and restores the caller's original stack depth. Nucleus runtime wrappers
must additionally preserve any register promised by the generated-program
vector contract. Unlike `$53`, the low-level `$52` selector intentionally
leaves the requested bank selected on success.

## 7. Memory and bank requirements

The audited TECM8 map is fixed monitor `$C000..$FFFF`, banked expansion
`$8000..$BFFF`, and always-visible RAM `$0000..$7FFF`. The current Nucleus MON3
deployment uses host/gateway code near `$4000`, compiler workspace
`$6000..$7000`, token/source buffers `$7000..$7800`, stack `$7E00..$7F00`, and
the compiler in the banked window.

Consequently:

- every mailbox, parameter block, loader cursor, return trampoline, and stack
  used across a bank call lives below `$8000` or in fixed ROM;
- a provider in another expansion bank is entered through `$53`, not by
  selecting its bank and calling its address directly;
- `$53` restores the compiler or loader bank before returning; and
- a buffer address passed to a banked provider must identify always-visible
  RAM, never private bytes in the caller's bank.

TEC-FS already supplies a bank-2 dispatcher and high-level source/artifact
operations. Its present public `$61` entry is mount only; Stage 7 must add
registry bindings for the exact operations required here rather than treating
the current prototypes as a completed filesystem ABI.

## 8. Failure and effect rules

EOF is distinct from all byte values. A failed read does not advance its
cursor. A failed write, seek, commit, or publication does not claim success;
the client-specific contract defines whether tentative bytes may remain.
Compiler generations publish only after commit. Loader failure may leave an
unpublished target dirty but may not enter it. PATCH application is ordered and
the last serialized write wins.

Terminal services never return. Operator break is a platform capability, not
a new runtime-vector ordinal. A platform without it reports capability bit 4
clear.

## 9. Conformance boundary

`asm/vertical-slice/platform-services-abi.asmi` is the machine-readable
allocation. `platform-services-abi-proof.asm` proves the version/capability
query, ordinary return discipline, saved-`BC` reconstruction, `IX/IY`
preservation, nested bank restoration, returned `AF`, and exact stack
restoration against executable stubs. Terminal calls are specified here but
cannot be proved until a provider owns the control layer to which they exit.
Provider implementations must repeat the applicable proofs against their real
dispatcher before claiming a profile.
