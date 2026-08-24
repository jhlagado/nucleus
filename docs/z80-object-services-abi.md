# Nucleus named-object services ABI 1

- Status: specified; Node and native provider proofs pending
- ABI version: 1
- Applies to: Z80 import resolver, source streamer, NOBJ writer, and loader
- Last reviewed: 2026-08-25

## 1. Purpose

This ABI gives Z80 development tools one portable way to read and write named
byte objects. A named object may be a source file, source plan, compiler spool,
runtime-catalogue entry, or NOBJ file. The ABI describes the operation visible
to the client. It does not expose host paths, TEC-FS records, CP/M FCBs, Node
file descriptors, sectors, or allocation blocks.

The common entry is a numbered system service. The MON3 binding assigns it
selector `$91`; another platform may use a different transport while preserving
this request and result contract.

## 2. Call contract

The client places the platform's object-service selector in `C`, places the
address of a request block in `HL`, and calls the system-service gateway.

On return:

- carry clear and `A=0` mean success;
- carry set and nonzero `A` mean failure;
- `IX`, `IY`, the hardware stack depth, and the caller's selected bank are
  preserved;
- `BC`, `DE`, `HL`, and non-carry flags may be changed; and
- the provider retains no pointer from the request after returning.

The request block and any referenced name or transfer buffer must remain in
memory visible to the provider for the synchronous call. On a banked machine,
that normally means always-visible RAM.

## 3. Request block

Every request is exactly 16 bytes. Words and the double word are little-endian.

| Offset | Size | Field       | Meaning                                         |
| -----: | ---: | ----------- | ----------------------------------------------- |
|      0 |    1 | `size`      | must be 16                                      |
|      1 |    1 | `abi`       | must be 1                                       |
|      2 |    1 | `operation` | operation number from Section 4                 |
|      3 |    1 | `flags`     | must be zero in ABI 1                           |
|      4 |    2 | `handle`    | input or returned opaque handle                 |
|      6 |    2 | `pointer`   | name or transfer-buffer address                 |
|      8 |    2 | `length`    | name length or requested transfer length        |
|     10 |    4 | `offset`    | absolute byte offset for `seek`; otherwise zero |
|     14 |    2 | `result`    | transferred byte count; otherwise zero          |

Before every call, the client writes every field required by the operation and
zeros fields described as unused. The provider sets `result` to zero before
attempting an operation that can return a count. Reserved flag bits, a wrong
size, a wrong ABI revision, or nonzero unused fields produce `invalid`.

Object names are nonempty byte strings and are not zero-terminated. ABI 1
accepts 1 through 255 bytes, so the high byte of `length` is zero on open
operations. Names use the logical syntax defined by the source-packaging or
deployment contract. Their physical filesystem representation is
platform-specific.

Handles are opaque 16-bit values. A client may compare a handle only with a
handle returned by the same provider generation. Zero is reserved and is never
returned as a valid handle.

## 4. Operations

| Number | Operation    | Inputs                                                            | Success result                                  |
| -----: | ------------ | ----------------------------------------------------------------- | ----------------------------------------------- |
|      0 | `openRead`   | `pointer`, name `length`                                          | readable `handle` at offset zero                |
|      1 | `beginWrite` | `pointer`, name `length`                                          | tentative update `handle` at offset zero        |
|      2 | `read`       | readable or update `handle`, buffer `pointer`, requested `length` | `result` bytes copied                           |
|      3 | `write`      | writable `handle`, buffer `pointer`, requested `length`           | `result == length`                              |
|      4 | `rewind`     | readable or writable `handle`                                     | cursor becomes zero                             |
|      5 | `seek`       | readable or writable `handle`, 32-bit `offset`                    | cursor becomes `offset`                         |
|      6 | `close`      | readable `handle`                                                 | handle released                                 |
|      7 | `commit`     | writable `handle`                                                 | tentative generation published; handle released |
|      8 | `abort`      | writable `handle`                                                 | tentative generation discarded; handle released |

A zero-length `read` or `write` succeeds without transferring data. A nonzero
`read` may return fewer bytes than requested. `result == 0` on a nonzero read
means end of object; EOF is not a failure status. A successful nonzero write is
all-or-nothing and returns the requested length. Clients therefore need no
provider-specific partial-write loop.

`seek` is absolute and uses the unsigned 32-bit offset. Seeking beyond the
current end is permitted only when the platform can preserve the resulting
object semantics; otherwise it returns `unsupported`. Reading at or beyond the
end returns zero bytes. A write after a permitted seek defines every newly
created gap as zero bytes.

`beginWrite` creates a tentative replacement even when a committed object of
the same name exists. The returned update handle may read, write, rewind, and
seek within its own tentative bytes. This permits bounded work spools without
making an incomplete generation visible under its object name. Other
`openRead` calls continue to see the preceding committed object until `commit`
succeeds. `close` is valid only for a readable handle; an update handle must
finish with `commit` or `abort`. Successful `commit`, `abort`, and `close`
invalidate the handle.

## 5. Failure and publication

Canonical status values are:

| Value | Name          | Meaning                                                    |
| ----: | ------------- | ---------------------------------------------------------- |
|     1 | `invalid`     | malformed request, field, or handle use                    |
|     2 | `unavailable` | required service or capability is absent                   |
|     3 | `notFound`    | named committed object does not exist                      |
|     4 | `capacity`    | handle, storage, name, or deployment capacity is exhausted |
|     5 | `access`      | operation is not permitted for this object or deployment   |
|     6 | `storage`     | underlying storage failed                                  |
|     7 | `conflict`    | another live generation prevents the requested operation   |
|     8 | `cancelled`   | operator or outer host cancelled the operation             |
|     9 | `unsupported` | valid ABI operation is not supported for this object       |

Failure never changes a committed object. A failed open allocates no handle. A
failed read leaves its cursor unchanged; the destination buffer is unspecified.
A failed seek or rewind leaves its cursor unchanged. A failed write does not
advance the logical cursor, but the tentative object is no longer usable and
the client must abort it. A failed commit leaves the preceding committed object
current; the client must abort or retry according to the platform binding.

`abort` is terminal for the handle even when it reports that physical cleanup
was incomplete. The preceding committed object remains current. This rule lets
a Z80 shell recover its bounded handle table after an I/O failure.

## 6. Required profiles

The native import resolver and source streamer require `openRead`, `read`,
`rewind`, and `close`. The NOBJ writer additionally requires `beginWrite`,
`read`, `write`, `rewind`, `commit`, and `abort`. It rewinds and reads its
sequential IMAGE and PATCH work spools when it forms the final object. `seek`
is required only by a client whose own algorithm needs random access; the
streaming compiler and NOBJ writer do not.

The Node provider, TEC-FS binding, and later CP/M binding must pass the same
operation tests. Those tests cover chunk boundaries, short reads, EOF, failed
open, independent cursors, tentative replacement, abort preservation, commit
replacement, failure cleanup, 32-bit seek, stale handles, and exact register,
stack, and bank preservation at the Z80 gateway.
