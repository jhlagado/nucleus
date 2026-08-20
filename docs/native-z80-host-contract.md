# Nucleus Native Z80 Host Contract 0.1

- Status: proposed implementation contract
- Date: 2026-08-20
- Applies to: Nucleus compiler hosts and NOBJ consumers

## 1. Purpose and authority

This document defines how the Z80 Nucleus compiler calls its operating host,
and how a separate Z80 program consumes a committed Nucleus object. It does not
define Nucleus source syntax or generated-program services.

The [language specification](specification.md) governs source meaning. The
[runtime and backend contract](z80-runtime-contract.md) governs generated code
and its runtime vector. The [target-system specification](target-system-specification.md)
governs placement and entry. The [NOBJ specification](nucleus-object-format.md)
governs stored object bytes. This document governs the Z80 calls used to supply
those facilities.

There are three distinct interfaces:

1. the **compiler-host ABI**, called while the compiler is running;
2. the **generated-program runtime vector**, called by a compiled program; and
3. the **NOBJ consumer-platform ABI**, called by a validator or loader.

An implementation may bind all three to one monitor, but it must not merge
their contracts. A compiler source read is not a Nucleus `readInputByte()`
call, and a loader bank selection is not a source-language service.

## 2. Common call rules

### 2.1 Ordinary completion

The compiler and consumer call host entries with ordinary Z80 `CALL`
instructions. Unless a specific entry says otherwise, on return:

- carry clear means success;
- carry set means failure;
- `A` contains the operation's result on success and a nonzero host status on
  failure; and
- the hardware stack is at the same depth as it was immediately before the
  `CALL`.

An entry may change only the registers and flags listed in its contract. It
preserves `IX` and `IY` unless it explicitly lists either as an input or
clobber. It does not change the selected target bank unless its contract says
that it does.

A failed entry publishes no partial logical operation. A stream write may
have transferred earlier, separately completed bytes; it must not publish part
of the current byte, record, retained name, or generation transition.

### 2.2 Status values

Host status values are private to this ABI. They do not become Nucleus failure
codes or trap reasons. Source transport, filesystem failure, and cancellation
are packaging or host failures, not Nucleus source diagnostics. They abort the
launch and are reported through the launch result.

The compiler-facing target adapter has a different `A` convention inherited
from the current compiler: carry set returns an existing compiler diagnostic.
It translates target-spool failure to `DiagnosticTargetOutput` and an invalid
or unavailable runtime identity or link context to
`DiagnosticTargetConfiguration`. Successful sink calls may preserve an input
value in `A`; callers use carry, not `A = 0`, to recognize success.

| Value | Name          | Meaning                                      |
| ----: | ------------- | -------------------------------------------- |
| `$00` | `ok`          | Operation completed.                         |
| `$01` | `end`         | Clean end of the requested sequential input. |
| `$02` | `capacity`    | A published host capacity was exceeded.      |
| `$03` | `storage`     | The underlying store failed.                 |
| `$04` | `invalid`     | Request or stored object was invalid.        |
| `$05` | `unavailable` | Requested provider or generation is absent.  |
| `$06` | `cancelled`   | The outer host cancelled a suspended call.   |

An entry whose contract uses a separate EOF result may return `end` with carry
set as stated by that entry. Other nonzero platform statuses return carry set.

### 2.3 Suspended calls

Every call is synchronous from the compiler or consumer's point of view. A
native monitor may finish it directly. A Debug80-backed host may suspend when
Node must perform asynchronous file or linker work.

Suspension uses a host-owned mailbox and a distinguished yield address:

1. the Z80 entry copies the complete bounded request into the mailbox;
2. it records its private continuation and reaches the yield address without
   returning to the compiler;
3. the outer driver writes one complete result after the operation finishes;
4. the driver resumes the saved continuation; and
5. the entry restores its call contract and returns once.

The mailbox, continuation, and saved stack belong to one launch generation.
Reset or cancellation invalidates them, aborts tentative output, and cannot
resume an earlier generation. No compiler source or semantic operation is
replayed after resumption.

## 3. Host and compiler lifecycle

### 3.1 Launch inputs

The host starts a compilation with:

- a 14-byte launch descriptor;
- a source-provider generation handle;
- a bounded ordered source-part count;
- the existing stable 15-byte target descriptor;
- a fresh tentative output generation; and
- an optional D8 collector mode fixed for the whole launch.

The host calls `NucleusHostCompile` with `IX` pointing to this stable launch
descriptor:

| Offset | Field                     | Type  | Meaning                          |
| -----: | ------------------------- | ----- | -------------------------------- |
|      0 | `descriptorSize`          | `u8`  | exactly 14                       |
|      1 | `hostAbiMajor`            | `u8`  | 0                                |
|      2 | `hostAbiMinor`            | `u8`  | 1                                |
|      3 | `sourcePartCount`         | `u8`  | 1 through 8                      |
|      4 | `sourceGenerationHandle`  | `u16` | opaque provider handle           |
|      6 | `targetDescriptorPointer` | `u16` | stable 15-byte target descriptor |
|      8 | `resultPointer`           | `u16` | stable nine-byte result block    |
|     10 | `targetContextHandle`     | `u16` | validated host target context    |
|     12 | `d8Mode`                  | `u8`  | 0 none, 1 resident, 2 streaming  |
|     13 | `reserved`                | `u8`  | zero                             |

The result block contains `outcome:u8`, `code:u8`, `partId:u8`, then
`offset:u16`, `line:u16`, and `column:u16`. Outcome 0 is success with code zero.
Outcome 1 is a compiler diagnostic with the exact diagnostic and position.
Outcome 2 is a host or packaging failure whose code is a private status from
Section 2.2; its position fields are zero. The routine returns carry clear only
for outcome 0. On either failure it returns carry set with `A = outcome`.

`NucleusHostCompile` may clobber `AF`, `BC`, `DE`, `HL`, `IX`, and `IY`. It
returns with the caller's hardware stack depth restored. The descriptor, target
descriptor, result block, and part-bank array remain addressable until it
returns.

The target context binds the tentative output generation to the complete host
profile information omitted from the compact descriptor: `imageFill`, device
and bank mappings, service destinations, runtime link context, and publication
destination. Before any source or output operation, the host cross-checks its
runtime identity, bases, capacities, bank count, entry bank, stack policy, and
part-bank mapping against the compact descriptor. A handle mismatch is a host
`invalid` outcome, not a partially opened compilation.

The target descriptor retains its existing byte layout. Its part-bank pointer
addresses one byte per final source-part ordinal. The host derives those
ordinals after import discovery; filenames never cross the compiler boundary.

### 3.2 Launch sequence

The Z80 host launch routine:

1. rejects a launch while another generation is active;
2. clears source, retained-name, diagnostic, suspension, and output state;
3. opens the source generation and tentative target generation;
4. installs the target descriptor and source-part count;
5. calls the public compiler entry;
6. as part of `TargetSinkCommit`, prevalidates and copies every requested D8
   source/name correlation while source and name handles remain valid;
7. on success, requires a successfully committed target generation;
8. on every other return, requests target abort; and
9. releases generation-scoped source and retained-name state.

The existing `CompileTargetAggregateCallParts` entry remains the compatibility
entry for resident sources. The streaming entry may have another private
launch shape, but it produces identical source order, diagnostics, semantic
operations, NOBJ, and D8 correlations.

A second launch starts from the same state whether the previous launch
succeeded, diagnosed source, failed output, was cancelled while suspended, or
terminated unexpectedly.

### 3.3 Compiler-host vector

The reference binding exposes a versioned eight-byte header followed by
fourteen consecutive three-byte `JP` entries in always-visible host memory.
The deployment linker supplies `HostVectorBase`; it is not a source or
target-profile address. A compatible replacement keeps that base unchanged, so
the compiler image does not change when monitor service numbers or host
implementations change.

| Offset | Field       | Required value |
| -----: | ----------- | -------------- |
|      0 | magic       | ASCII `NH`     |
|      2 | major       | 0              |
|      3 | minor       | 1              |
|      4 | header size | 8              |
|      5 | entry count | 14             |
|      6 | flags       | zero for 0.1   |
|      7 | reserved    | zero           |

The compiler deployment validates the header before accepting a launch. Entry
zero begins at `HostVectorBase + 8`; entry `n` begins at `+8 + 3*n`.

| Ordinal | Entry                           |
| ------: | ------------------------------- |
|       0 | `HostSourceNextChunk`           |
|       1 | `HostRetainCurrentName`         |
|       2 | `HostCompareCurrentName`        |
|       3 | `HostMaterializeName`           |
|       4 | `TargetSinkBegin`               |
|       5 | `TargetSinkImageByte`           |
|       6 | `TargetSinkRuntimeImage`        |
|       7 | `TargetSinkRuntimeInitialImage` |
|       8 | `TargetSinkPatchByte`           |
|       9 | `TargetSinkPatchWord`           |
|      10 | `TargetSinkMapFlat`             |
|      11 | `TargetSinkMapBanked`           |
|      12 | `TargetSinkCommit`              |
|      13 | `TargetSinkAbort`               |

The 50-byte header and table belong to host code, not compiler core. A proof layout may
resolve these labels directly without emitting the table, but the register and
failure contracts remain the same. The yield address used for suspension is a
host implementation detail, not a fifteenth callable entry.

## 4. Compiler source-provider ABI

### 4.1 Source events

The source provider presents the ordered events defined by the language
specification:

```text
begin unit
  begin part, raw byte chunks, end part
  ...
end unit
```

Each part has a stable nonzero byte identity. Raw bytes are not decoded,
normalized, or rewritten. The compiler retains part-relative byte offset,
1-based line, and 1-based byte column. The provider reports the same zero-width
part-boundary newline condition as the resident adapter.

The compiler may request the next byte or a refill. Source requests move only
forwards. If a sequential medium cannot meet token pinning, the host spools
that part before compilation.

The Z80 binding returns one event per `HostSourceNextChunk` call:

| `A` | Event      | Other result                                        |
| --: | ---------- | --------------------------------------------------- |
|   0 | bytes      | `C = part id`, `HL = first byte`, `DE = byte count` |
|   1 | begin part | `C = stable part id`                                |
|   2 | end part   | `C = stable part id`                                |
|   3 | end unit   | no other result                                     |

The call returns carry clear for an event and carry set with a nonzero host
status for failure. A bytes event has a nonzero `DE` count. Its memory remains
readable until the next source-provider call. The source adapter copies a token
into token scratch before any refill can invalidate the token's first byte.
This includes a token whose final byte is the last byte of a chunk: the
tokenizer must refill to discover its delimiter, so it pins the token before
that call. A token whose delimiter is already present in the same chunk can
remain in place until the consuming parser action finishes.

`HostSourceNextChunk` clobbers `AF`, `BC`, `DE`, and `HL` and preserves `IX`,
`IY`, and the selected target bank.

### 4.2 Current-token lifetime

The provider keeps the complete current token readable until the consuming
parser action finishes. Classification alone does not end this lifetime.
Aggregate string decoding, in particular, rereads the raw string token.

The published token-cache capacity admits:

- a 255-byte identifier;
- a 255-byte decoded string written entirely as `\xNN` escapes, including
  delimiters; and
- tokenizer lookahead.

That escaped string occupies 1,022 raw bytes before lookahead. An
implementation may use a window plus a token spool instead of one contiguous
source page. Neither is compiler workspace.

### 4.3 Retained names

Symbol records retain a two-byte exact name handle and one-byte name length.
A streaming compiler never dereferences the handle as a source pointer.

The provider supplies three operations:

| Operation            | Input              | Success result           |
| -------------------- | ------------------ | ------------------------ |
| `retainCurrentName`  | current NAME token | `HL = exact u16 handle`  |
| `compareCurrentName` | `HL = handle`      | `Z = 1` iff bytes equal  |
| `materializeName`    | `HL = handle`      | `HL = temporary pointer` |

`retainCurrentName` returns one complete handle or fails without creating a
visible entry. Handles are unique within a generation and are not hashes. The
provider records the source part, offset, and length for D8 and diagnostics.

`compareCurrentName` checks length and exact bytes. It returns carry clear;
equality is reported through zero. An unknown or stale handle returns
`invalid` with carry set.

`materializeName` copies the exact spelling into bounded host scratch. The
bytes remain stable until the consuming parser action returns. Declaration
restoration, forward routine names, and retained parameter names use it.

Begin-launch starts the handle store empty. Success, failure, abort,
cancellation, and abnormal termination release it. Entry count and byte
capacity are published host capacities and do not reduce compiler symbol
capacities.

The Node reference binding admits 1,024 retained entries and 65,535 total
spelling bytes per generation. It preflights both limits before allocating a
handle. Another host may choose different published limits, but it must still
fail atomically before truncating a spelling, wrapping a handle, or reusing a
handle from the active generation.

The reference register binding is:

| Entry                    | Inputs                                               | Success result           | Clobbers      |
| ------------------------ | ---------------------------------------------------- | ------------------------ | ------------- |
| `HostRetainCurrentName`  | `HL = bytes, B = length, C = part, DE = part offset` | `HL = handle`            | `AF,HL`       |
| `HostCompareCurrentName` | `HL = handle, IX = bytes, B = length`                | `Z = 1` iff equal        | `AF,BC,DE,HL` |
| `HostMaterializeName`    | `HL = handle`                                        | `HL = bytes, B = length` | `AF,B,HL`     |

All three preserve `IX` except that `HostCompareCurrentName` consumes its value
as a read-only input; they preserve `IY`, `SP`, and the selected target bank.
`HostCompareCurrentName` returns carry clear for either equal or unequal. It
sets carry only for an invalid handle or host failure.

The compiler calls these raw entries through checked source adapters. A raw
carry-set result is not a Nucleus diagnostic: the adapter records the host
status, restores the launch boundary stack, returns carry set to the launch
host, and prevents further parsing or target output. This translation is used
immediately after source refill, retain, compare, and materialize calls.

### 4.4 Resident compatibility provider

The resident provider continues to accept one to eight five-byte descriptors:

```text
stablePartId:u8, start:u16le, end:u16le
```

It may retain raw pointers internally. This does not permit the streaming
compiler to infer whether a word is a pointer or handle from its value.

### 4.5 Source-position capacity

The first Z80 compiler stores part-relative offset, line, and byte column as
unsigned 16-bit counters. Their published maxima are therefore:

- source-part raw length: 65,535 bytes;
- zero-based byte offset: 65,535;
- one-based line: 65,535; and
- one-based byte column: 65,535.

Position changes are mathematical and atomic. Consuming an ordinary byte
increments offset and column; LF increments offset and line and resets column
to one; CRLF increments offset by two and line by one and resets column to one.
A zero-width boundary newline increments line and resets column without
changing offset. If the complete update would exceed any maximum, the compiler
reports `DiagnosticSourcePositionCapacity = 101` at the last representable
position. It never wraps, saturates, truncates, or turns the condition into a
filesystem failure. Position counters reset for each source part.

Proofs admit every counter at 65,535 when no further update is required and
reject the first byte, physical newline, CRLF, or synthesized boundary newline
that would exceed it. Chunk boundaries do not change these results.

## 5. Compiler target-output ABI

### 5.1 Generation rules

The sink owns a tentative generation containing separate IMAGE and PATCH
spools. Calls occur in production order; final NOBJ serialization remains:

```text
BEGIN, IMAGE+, PATCH*, MAP, COMMIT, EOF
```

The host may flush either spool at any time. It does not require a complete
image, bank, AdapterLog, or NOBJ in Z80 memory. Abort discards the tentative
generation and leaves the previous committed generation unchanged.

### 5.2 Calls

The production adapter preserves the current logical calls and contracts:

| Entry                           | Inputs                                               | Clobbers            |
| ------------------------------- | ---------------------------------------------------- | ------------------- |
| `TargetSinkBegin`               | `IX = 15-byte target descriptor`                     | `AF,BC,DE,HL,IX,IY` |
| `TargetSinkImageByte`           | `A = byte, C = bank, HL = target address`            | flags, `DE`         |
| `TargetSinkRuntimeImage`        | `A = bank, BC = length, DE = identity, HL = address, IX = 18-byte compiler link context` | `AF,BC,DE,HL,IX,IY` |
| `TargetSinkRuntimeInitialImage` | same as runtime image                                | `AF,BC,DE,HL,IX,IY` |
| `TargetSinkPatchByte`           | `A = byte, C = bank, HL = target address`            | flags, `DE`         |
| `TargetSinkPatchWord`           | `C = bank, DE = address, HL = replacement`           | flags               |
| `TargetSinkMapFlat`             | `IX = 38-byte map request`                           | `AF,BC,DE,HL,IX,IY` |
| `TargetSinkMapBanked`           | `IX = 38-byte map request`                           | `AF,BC,DE,HL,IX,IY` |
| `TargetSinkCommit`              | current generation                                   | flags               |
| `TargetSinkAbort`               | current generation, if any                           | flags               |

Every entry returns the common `A` and carry result. Both map calls receive the
same stable, versioned request:

| Offset | Field                         | Type  |
| -----: | ----------------------------- | ----- |
|      0 | request revision              | `u8`  |
|      1 | MAP flags                     | `u8`  |
|      2 | entry bank                    | `u8`  |
|      3 | entry address                 | `u16` |
|      5 | image base                    | `u16` |
|      7 | image capacity                | `u16` |
|      9 | writable base                 | `u16` |
|     11 | writable capacity             | `u16` |
|     13 | vector length                 | `u16` |
|     15 | initialized run length        | `u16` |
|     17 | BSS base                      | `u16` |
|     19 | BSS length                    | `u16` |
|     21 | stack requirement             | `u16` |
|     23 | data-load bank                | `u8`  |
|     24 | data-load address             | `u16` |
|     26 | data-load length              | `u16` |
|     28 | source-part count             | `u8`  |
|     29 | part-bank array pointer       | `u16` |
|     31 | bank count                    | `u8`  |
|     32 | bank-state pointer            | `u16` |
|     34 | identity-fixed runtime length | `u16` |
|     36 | startup length                | `u16` |

Request revision is 1. MAP flags use the NOBJ definitions: bit 0 is ROM mode,
bit 1 is established-stack mode, and all other bits are zero. The bank-state
pointer addresses one six-byte record per bank: `cursor:u16`,
`remainingCapacity:u16`, and `aggregateConstantLength:u16`. Flat output has one
such record. The compiler-facing adapter finalizes this request from its live
layout before the call; the sink neither reads private compiler cells nor
discovers addresses through an assembler symbol map.

The sink derives `usedLength` as the 16-bit modular difference from image base,
then requires `usedLength + remainingCapacity == imageCapacity`. This admits a
legal final cursor of zero when the mathematical image end is `$10000` without
treating zero as an empty image. It derives each bank's read-only and
aggregate extents from the fixed image order, entry bank, runtime length,
startup length, initialized length, and aggregate length. It serializes the
exact NOBJ MAP payload and validates every relationship in the NOBJ authority.
The request and both pointed arrays remain valid until the call returns.

`TargetSinkImageByte` appends one complete IMAGE byte. The host may coalesce
adjacent calls without changing bank, address, or order. `TargetSinkPatchWord`
appends low then high byte as one atomic logical patch.

### 5.3 Runtime requests

Runtime-image calls request provider work; they do not pass a pointer to linked
bytes. The compiler passes its source-dependent portion of the link context in
the existing 18-byte `TargetRuntimeContext`: runtime base, writable base and
capacity, state base, vector base, program-data base and capacity, and
read-only-data base and capacity, all as little-endian words in that order.
The provider combines it with the retained target context's service
destinations, verifies identity,
exact length, and helper offsets, then appends resolved bytes to IMAGE at the
supplied bank and address.

Node may suspend the Z80 host while AZM links the canonical runtime. A native
fixed target may use a prelinked catalog. Another context returns
`unavailable`; it is not silently linked with wrong addresses.

### 5.4 Commit validation

Before commit, the sink validates framing, target extents, monotonic
nonoverlapping IMAGE ranges, nonoverlapping PATCH ranges, MAP used lengths,
record count, and CRC. A low-memory sink may rescan its patch spool instead of
retaining all intervals in RAM. This is object validation, not a second
compiler pass.

Only COMMIT publishes the generation. Failure after earlier output calls
leaves the preceding committed object and D8 sidecar current.

## 6. Diagnostics and D8

The compiler remains the authority for diagnostic code, part identity, offset,
line, and column. A host error does not replace a source diagnostic already
selected by the compiler.

The D8 collector mode is fixed at launch:

- resident mode interprets retained-name words as source pointers;
- streaming mode resolves them through the current handle generation.

The collector never guesses the mode from a numeric word. Unknown, stale, or
spelling-mismatched handles fail the requested D8 preflight before NOBJ commit.
Source bytes, semantic keys, and IMAGE bytes retain the conditional trace ABI
in [Nucleus D8 Source Maps](d8-source-maps.md).

When D8 is requested, `TargetSinkCommit` first validates all trace structure
and resolves or copies every handle-backed correlation. Failure at this
preflight aborts the tentative object before COMMIT. Once COMMIT succeeds,
later JSON formatting or filesystem publication failure is a separate artifact
error: it leaves the valid NOBJ committed and leaves any previous D8 sidecar
unchanged. It does not report that abort restored an already committed object.

A D8 preflight failure is a host-failure outcome from `NucleusHostCompile`, not
a compiler diagnostic returned through the ordinary sink convention. The host
aborts the tentative sink generation and unwinds the compiler call without
changing the accepted source set or any diagnostic code or position.

## 7. NOBJ consumer-platform ABI

### 7.1 Separation

The NOBJ consumer is a separate Z80 program. It validates and materializes a
committed object; it does not parse Nucleus source, resolve symbols, or invoke
the compiler. A second read of a stored object is not a second compiler pass.

### 7.2 Required operations

The consumer starts with a platform deployment profile supplied by its caller
or fixed in its build. It contains the admitted runtime identity, image base
and capacity, writable regions, stack and entry ABI, and the mapping from NOBJ
bank ordinals to physical selector values and device offsets. This profile is
outside NOBJ. Before any non-isolated target write or publication, the consumer
cross-checks `BEGIN`, the complete `MAP`, runtime identity, used extents, bank
count, and entry pair against it. An isolated backing area may receive IMAGE
and PATCH bytes before MAP arrives, but remains unreachable and unpublished
until the same cross-check succeeds. An ordinal has no hardware meaning until
its deployment mapping succeeds.

The host calls `NobjConsumerRun` with `IX` pointing to this ten-byte descriptor:

| Offset | Field                      | Type  | Meaning                       |
| -----: | -------------------------- | ----- | ----------------------------- |
|      0 | `descriptorSize`           | `u8`  | exactly 10                    |
|      1 | `consumerAbiMajor`         | `u8`  | 0                             |
|      2 | `consumerAbiMinor`         | `u8`  | 1                             |
|      3 | `strategy`                 | `u8`  | 0 locked two-pass, 1 isolated |
|      4 | `objectSelector`           | `u16` | platform object selector      |
|      6 | `deploymentProfilePointer` | `u16` | stable validated profile      |
|      8 | `resultPointer`            | `u16` | stable four-byte result block |

The result block is `outcome:u8`, `status:u8`, `recordOrdinal:u16`. Outcome
zero is used only by a validation-only proof binding; the runnable loader does
not return after success. Outcome one is an NOBJ validation failure and outcome
two is a platform failure. `status` is the exact validator or platform code.

The consumer-platform vector has an eight-byte `NC`, version 0.1 header with
the same header layout as Section 3.3, followed by eight three-byte `JP`
entries in the table order below. Its total size is 32 bytes. The deployment
linker fixes its base, and `NobjConsumerRun` validates the header before opening
the object.

| Operation          | Required behavior                                              |
| ------------------ | -------------------------------------------------------------- |
| `objectOpen`       | open one committed generation and return a stable handle       |
| `objectReadByte`   | return the next byte, clean EOF, or storage failure            |
| `objectRewind`     | return to the first byte of the same generation                |
| `objectLock`       | prevent replacement, or provide detectable generation identity |
| `selectTargetBank` | select a physical bank while loader code remains visible       |
| `publishTarget`    | publish the validated map and entry pair atomically            |
| `enterTarget`      | enter the published bank/address under its entry ABI           |
| `objectClose`      | release the object without changing target publication         |

`objectReadByte` must distinguish all 256 byte values from EOF. Each concrete
binding states its byte/EOF discriminator; no byte value is reserved as EOF.

`selectTargetBank` preserves the loader stack, object cursor, CRC state, and
record state. Loader code, workspace, and stack remain always visible.
`enterTarget` is unreachable until validation, materialization, MAP, COMMIT,
and immediate EOF all succeed.

The reference register binding keeps one opened object implicit in the
consumer-platform adapter:

| Entry              | Inputs                                                      | Success result                    | Clobbers           |
| ------------------ | ----------------------------------------------------------- | --------------------------------- | ------------------ |
| `ObjectOpen`       | `HL = platform object selector`                             | opened generation becomes current | `AF,BC,DE,HL`      |
| `ObjectReadByte`   | current generation                                          | `A = byte`                        | `AF`               |
| `ObjectRewind`     | current generation                                          | cursor at first byte              | `AF,BC,DE,HL`      |
| `ObjectLock`       | current generation                                          | `DE:HL = generation identity`     | `AF,BC,DE,HL`      |
| `SelectTargetBank` | `A = logical NOBJ bank ordinal`                             | mapped physical bank selected     | `AF,BC,DE,HL`      |
| `PublishTarget`    | `A = entry bank, HL = entry, IX = MAP payload, BC = length` | new target generation published   | `AF,BC,DE,HL,IX`   |
| `EnterTarget`      | `A = entry bank, HL = entry`                                | no return                         | target entry state |
| `ObjectClose`      | current generation                                          | no object open                    | `AF,BC,DE,HL`      |

`ObjectReadByte` uses carry clear for a byte. Carry set with `A = end` means
clean EOF; carry set with another status means failure. This entry is the
exception to the ordinary success rule in Section 2.1 because all 256 values
of `A` are valid input bytes. `ObjectLock` returns an exact identity spanning
two register pairs; a platform with a shorter native identity zero-extends it.

All consumer calls preserve `IY` and the consumer stack. They preserve `IX`
except where it is an explicit input. `SelectTargetBank`, `PublishTarget`, and
`EnterTarget` all receive logical NOBJ bank ordinals. The initialized platform
adapter maps them to selector values; the consumer never passes a hardware
selector in `A`. `SelectTargetBank` may change only the physical target window,
and the adapter restores any storage bank needed by the opened object before
the next read. `EnterTarget` establishes the target's documented entry-bank
and stack policy and does not return on success. A failure before control
transfer returns under the ordinary rule.

The `PublishTarget` MAP pointer addresses the exact validated NOBJ MAP payload
and remains readable for the duration of the call. The platform copies any
metadata it needs before returning; it does not retain the consumer buffer
pointer.

### 7.3 Loading strategies

An isolated target or private backing permits one pass: validate records while
writing only into storage that cannot run or replace the current program, then
publish after COMMIT and EOF.

Otherwise the consumer uses a locked stored object:

1. pass one validates it without target writes;
2. it rewinds the same generation;
3. pass two materializes it; and
4. it rechecks framing, record count, CRC, COMMIT, and EOF before entry.

If the store cannot lock, pass two detects a changed generation. Partial target
writes remain non-runnable. Direct wire loading is legal only with isolated
backing for the complete received target.

### 7.4 Consumer memory map

Every deployment publishes half-open extents for:

- consumer code and immutable tables;
- consumer workspace and record buffer;
- consumer stack;
- mapped or buffered object bytes; and
- every visible target write region.

No target write overlaps consumer code, workspace, stack, the current record
buffer, or immutable object storage. Banked consumer state stays outside the
switched window. A flat image that would overwrite the loader requires
relocation or isolated backing and is otherwise rejected.

ROM burning is not a loader operation. A burner utility validates and
materializes NOBJ before applying its device protocol.

## 8. Reference bindings

### 8.1 Compiler-host memory map

Every deployment publishes half-open extents for:

- compiler code and immutable data;
- compiler workspace and compiler stack;
- host vector, host code, and immutable tables;
- host workspace, mailbox, saved continuation, and suspended-call stack;
- current-token scratch, materialized-name scratch, and source cache;
- mapped source or source spool buffers;
- IMAGE and PATCH spool buffers; and
- every switched target window visible while compiling.

These extents do not overlap while simultaneously live. Host vectors,
mailbox, continuation state, compiler stack, and all state needed to return
from a host call remain visible under every target bank selector. A platform
that shares a window between source, object storage, and target banks must
switch it only inside an entry whose contract saves and restores the previous
mapping.

The deployment reports peak simultaneously live bytes. It does not add the
capacities of buffers whose lifetimes are proved disjoint, and it does not
overlay buffers merely because current tests happen not to exercise them
together.

### 8.2 Debug80-backed host

The first reference binding runs the real Z80 host and compiler under Debug80.
Node supplies files, spools, AZM runtime linking, and publication beneath the
Z80 calls. It may inspect the explicit mailbox and yield state; it does not
parse Nucleus or replay compiler work.

This binding proves asynchronous provider success, failure, cancellation, and
a following clean launch. Its output is compared byte for byte with the
resident-source and AdapterLog compatibility path.

### 8.3 MON3 and TECM8

The native binding implements the same calls through a Z80 layer over monitor
and filesystem services. MON3 service numbers are private to that layer.
Changing the monitor does not change compiler code, Nucleus source, the
generated-program runtime vector, or NOBJ.

An early fixed target may select a prelinked runtime catalog. General
target-derived runtime linking requires a native assembler/linker provider and
is not presumed here.

## 9. Capacity and conformance

The host publishes and boundary-tests these separate capacities:

- source-part count;
- source-part length and source-position counters;
- source cache and maximum pinned raw token;
- retained-name entries and bytes;
- mailbox and record buffer;
- IMAGE and PATCH spool storage;
- consumer record buffer and stack; and
- prelinked runtime-catalog entries, when present.

None is compiler workspace. None silently reduces the semantic transcript,
symbol, routine, parameter, control-label, fixup, bank, or generated-program
capacities.

Conformance requires at least:

- resident and windowed identity for diagnostics, semantics, NOBJ, and D8;
- a source unit larger than the former 2 KiB deployment window;
- maximum escaped-string pinning and retained names across refills;
- output larger than the former AdapterLog and image regions;
- flat and four-bank streamed output;
- provider suspension, failure, cancellation, and sequential reset;
- late output failure preserving a previous object;
- low-memory overlapping-patch rejection;
- one-pass isolated and two-pass locked consumer proofs; and
- exact stack, register, flag, bank, CRC, count, MAP, COMMIT, and EOF behavior.

Compiler-core, compiler-workspace, host-code, host-workspace, consumer-code,
consumer-workspace, generated-program, runtime, proof-byte, instruction, and
T-state accounts remain separate.
