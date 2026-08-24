# Nucleus Z80 runtime-catalogue services ABI 1

- Status: specified; Node reference provider and Z80 gateway proof implemented
- ABI version: 1
- Applies to: native NOBJ writers and compiler-host adapters
- Last reviewed: 2026-08-25

## 1. Purpose

The runtime catalogue supplies bytes that were assembled and resolved before a
compilation starts. The compiler identifies the runtime ABI and supplies its
placement context. It does not carry the runtime image in its 16 KiB core, and
the NOBJ writer does not assemble, link, or relocate it.

This ABI lets a Z80 NOBJ writer read the selected runtime in bounded chunks.
Node may serve generated package data, a TEC-1G installation may copy a ROM
catalogue entry, and CP/M may read a catalogue file. Each provider returns the
same selected bytes for the same request.

The common MON3 binding assigns selector `$92`. Another platform may use a
different call transport while preserving the request and result contract.

## 2. Call contract

The client places the platform selector in `C`, the address of a 22-byte
request in `HL`, and calls the common system-service gateway.

Carry clear with `A=0` means success. Carry set with a nonzero canonical system
status means failure. The call preserves `IX`, `IY`, the hardware stack depth,
and the selected bank. It may change `BC`, `DE`, `HL`, and non-carry flags. The
provider retains no request, context, or destination pointer after returning.

The request, the 18-byte runtime link context, and the destination buffer must
remain in always-visible memory for the synchronous call.

## 3. Request block

All words are little-endian.

| Offset | Size | Field | Meaning |
| ---: | ---: | --- | --- |
| 0 | 1 | `size` | exactly 22 |
| 1 | 1 | `abi` | exactly 1 |
| 2 | 1 | `operation` | 0 runtime code; 1 initial writable image |
| 3 | 1 | `flags` | bit 0 banked; every other bit zero |
| 4 | 1 | `bank` | selected logical bank ordinal |
| 5 | 1 | reserved | zero |
| 6 | 2 | `identity` | required runtime ABI identity |
| 8 | 2 | `expectedLength` | complete selected image length |
| 10 | 2 | `contextPointer` | compiler-supplied 18-byte link context |
| 12 | 2 | `offset` | first requested byte in the selected image |
| 14 | 2 | `pointer` | destination buffer |
| 16 | 2 | `capacity` | maximum bytes to return |
| 18 | 2 | `result` | returned byte count |
| 20 | 2 | reserved | zero |

A flat request has flags zero and bank zero. A banked request sets bit 0 and
supplies the logical bank. The flag affects the initial image only: the
provider writes that bank ordinal into the runtime's identity-defined current
bank state. Runtime code bytes remain identical between banks.

The link context contains nine words in this order:

```text
runtimeBase, writableBase, writableCapacity, writableStateBase, vectorBase,
programDataBase, programDataCapacity, readOnlyBase, readOnlyCapacity
```

Platform service destinations belong to the selected platform binding. They
do not occupy compiler workspace and do not appear in this request.

## 4. Chunk behavior

The provider selects one exact catalogue entry from `identity`, the link
context, and its own platform-service destinations. It rejects a missing entry,
an identity mismatch, or a selected image whose complete length differs from
`expectedLength`.

On success it copies at most `capacity` bytes beginning at `offset`, writes the
count to `result`, and returns carry clear. `offset == expectedLength` returns
zero bytes. An offset beyond the image is invalid. A zero-capacity request is
valid and returns zero.

The NOBJ writer starts at offset zero and repeats calls until it has received
exactly `expectedLength` bytes. A premature zero result is a provider failure.
The writer frames the returned bytes as ordinary NOBJ `IMAGE` payload. The
runtime-catalogue operation has no NOBJ record kind of its own.

Failure writes no destination byte and leaves `result` zero. Canonical status
values are shared with the named-object ABI. Catalogue absence is
`unavailable`; malformed requests and inconsistent catalogue entries are
`invalid`; a platform read failure is `storage`.

## 5. Publication and reproducibility

Catalogue entries are immutable for one tool release. AZM may build them during
package or ROM generation, but normal compilation never invokes AZM. The
generated catalogue and its Z80 proof are reproducible build artifacts.

The NOBJ writer treats catalogue bytes as tentative IMAGE data. A catalogue
failure aborts its IMAGE and PATCH work objects and prevents NOBJ commit. The
previous committed NOBJ remains current.
