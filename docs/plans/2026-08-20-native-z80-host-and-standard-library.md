# Plan: native Z80 host, streaming compilation, and the first standard library

- Status: adversarially reviewed; approved as the implementation plan
- Date: 2026-08-20
- Baseline: `886cd95`

## 1. Purpose

Nucleus already runs as Z80 machine code, but its normal development path still
depends on a Node adapter that places all source text in a 2 KiB memory window,
records compiler output in a large Z80 log, then constructs a complete NOBJ and
complete bank images in JavaScript. Those are useful proof mechanisms. They
must not become requirements of the language or the native compiler.

This plan replaces that proof-shaped path with a host boundary that can run on
an actual Z80. The same Z80 host will first run under Debug80, with Node
providing devices beneath it. It can later bind to MON3 and TECM8 services
without changing the compiler or the Nucleus program being compiled.

The work also establishes the first shared Nucleus standard library. Console
and formatting routines are ordinary Nucleus source. They use the existing
portable byte services and behave the same under Node, MON3, CP/M, or another
provider.

This is an implementation plan. It does not amend source-language meaning, the
runtime ABI, or the NOBJ format. Normative changes found during implementation
must be made in the authority that owns them and reviewed separately.

## 2. Authority and terminology

The existing authorities retain their present roles:

- the language specification defines Nucleus source;
- the runtime contract defines generated Z80 and its service ABI;
- the target-system specification defines layout, startup, and target
  profiles; and
- the NOBJ specification defines the stored object stream and its commit
  protocol.

This plan uses these terms consistently:

- **host**: the system that runs the Z80 compiler and supplies its operating
  services;
- **compiler adapter**: the host-facing source, output, diagnostic, and target
  operations called by the compiler;
- **runtime provider**: the component that links the selected generated-program
  runtime and supplies its initial writable image;
- **NOBJ consumer**: a validator, loader, materializer, or ROM utility that
  reads a committed object and applies its patches;
- **shell**: an optional interactive command interface; and
- **trap**: a terminal safety failure in a generated Nucleus program.

“Harness” remains useful for tests, but it is not the name of the production
boundary.

## 3. Current implementation and temporary limits

### 3.1 Source

The current multipart entry receives one five-byte descriptor for each source
part:

```text
stable part id : u8
start          : u16 little-endian pointer
end            : u16 little-endian pointer
```

The descriptors and all source bytes remain resident throughout compilation.
The Node host places them in `SourceBase..SourceLimit`, currently a 2 KiB
window, and rejects a unit when

```text
5 * partCount + sum(part byte lengths) > sourceWindowBytes
```

This is a deployment capacity, not a language limit. The parser reads the
source once, but symbol entries and diagnostics can retain pointers into those
resident bytes. Removing the 2 KiB window therefore requires a new retained-name
representation as well as a new byte reader.

### 3.2 Output

The compiler already calls adapter operations for begin, image bytes, runtime
images, patches, map, commit, and abort. It does not require a target image at
its final address. The proof adapter, however, records those calls in a large
Z80 `AdapterLog`. Node later reads the log and builds NOBJ.

The TypeScript NOBJ sink has separate image and patch spools, but its commit
path concatenates both spools, the map, and the commit into one `Uint8Array`.
The public compile result then materializes a complete byte array for every
bank. This makes full materialization mandatory even when the caller only
wants a stored NOBJ.

### 3.3 Runtime selection

The compiler submits a runtime identity, address, and expected length. The
current TypeScript provider links the canonical runtime for the complete target
context and appends its bytes to the image spool. This ownership is correct;
the native host needs an equivalent provider interface rather than runtime
bytes inside the compiler.

### 3.4 What remains valid

The following design is retained:

- one source pass and one semantic-transcript consumption;
- declaration before use, with bounded explicit forward declarations;
- unresolved generated addresses emitted as placeholders and later PATCH
  records;
- separate sequential IMAGE and PATCH spools;
- NOBJ order `BEGIN IMAGE+ PATCH* MAP COMMIT EOF`;
- publication only after a valid terminal commit; and
- runtime linking outside compiler core and compiler workspace.

## 4. Final architecture

```text
source files / ROM library / TEC-FS
             |
             v
      source-part resolver
             |
             v
      native Z80 host ABI <--------- target profile
       |       |       |
       |       |       +----------> runtime provider
       |       |
       |       +------------------> IMAGE and PATCH spools
       |
       v
  Nucleus Z80 compiler
             |
             v
       committed NOBJ
             |
             v
  validator / RAM loader / ROM utility
```

The first deployment of this architecture runs every box through Debug80. The
compiler and native host are real Z80 code. Node implements the device and file
operations beneath the host. The second deployment replaces those Node-backed
operations with MON3 or TECM8 services.

Node must not become a private compiler pass. It may resolve imports, open
files, spool records, link the selected runtime, serialize NOBJ, and materialize
delivery formats because each is explicitly outside the source compiler.

## 5. Compiler-host ABI

The compiler-host ABI is a small vector table in always-visible memory. The
compiler calls it with ordinary Z80 `CALL` instructions. A MON3 binding may
implement an entry with `RST 10h`, but the compiler does not depend on MON3
service numbers. The Nucleus host ABI sits above the monitor so that MON3 can
change without relinking the compiler.

Each entry must document registers, flags, stack behavior, failure result, and
which state remains live across the call. An entry must either complete its
operation or report failure without publishing a partial logical operation.

A native entry is synchronous from the compiler's point of view, but its
Debug80 implementation may need an asynchronous Node operation. The common
host protocol therefore permits an entry to copy its bounded request into a
mailbox and yield at a stable Z80 continuation. The outer driver awaits the
operation, writes the exact result, and resumes that continuation. The compiler
remains blocked inside the original call throughout. Source refill, spool
flush, runtime linking, and final publication may all use this mechanism; none
causes the compiler to replay source or semantic work.

The ABI has four groups:

1. source input and retained-name access;
2. target object output;
3. runtime-provider requests; and
4. terminal diagnostics and host return.

The current memory-descriptor and AdapterLog paths remain as proof adapters
until their replacements pass differential tests. They are not the final ABI.

The host also owns the outer lifecycle. Its launch entry starts a fresh source,
name, diagnostic, and object generation; installs the target descriptor and
source-provider handle; resets compiler and adapter state; calls the public
compiler entry; and translates success or the exact diagnostic back to the
caller. It invokes abort on every non-success path. A second launch begins from
the same initial state regardless of how the preceding launch ended.

## 6. Windowed source input

### 6.1 Required behavior

The compiler must accept a source unit whose bytes do not all fit in its Z80
address space. Source-part count remains separately bounded. The host supplies
ordered raw parts, preserving their exact bytes, stable identities, and
part-relative offsets. It performs no newline normalization or UTF-8
decode/re-encode step.

The compiler retains its current position model:

```text
part id, byte offset, line, column
```

Part boundaries retain the existing zero-width newline behavior. Diagnostics
and D8 events continue to identify the original part and raw offset exactly.

### 6.2 Source provider

The native source provider realizes the event stream already defined by
Section 4.3 of the language specification:

- begin and end a compilation;
- begin and end an ordered source part;
- supply one or more raw byte chunks; and
- supply the zero-width boundary event when the part needs one.

The Z80 binding adds three name operations because current symbol records retain
a source pointer after tokenization and some parser paths later restore that
spelling as the current token:

- retain the current NAME spelling and return an opaque 16-bit handle;
- compare that handle with the current NAME spelling; and
- materialize a handle into bounded name scratch and return a temporary readable
  pointer valid through the consuming parser action.

The host copies or interns only retained identifier spellings. It does not
retain arbitrary source text. A handle denotes exact bytes, not a hash that can
collide. The existing pointer word in a symbol record becomes this handle; the
existing one-byte length remains available for a cheap inequality test. D8 and
diagnostic tools can associate the handle with the token's stable part identity
and offset without storing a filename in the compiler.

The handle store belongs to one compilation generation. Begin-compilation
starts it empty; success, diagnostic failure, output abort, and unexpected host
termination all release it. Retain either returns one complete exact handle or
fails without adding a visible entry. Its byte and entry capacities are host
capacities, published and proved separately from compiler symbol capacities.
No handle may be reused within a generation, and a collector must reject a
handle from an earlier generation.

The input adapter keeps the complete current token addressable until every
parser action that consumes its spelling has finished. Classification is not
the end of that lifetime: string-initializer decoding rereads the raw literal.
A refillable implementation must therefore pin or spool the largest raw token,
including a 255-byte string whose bytes all use `\xNN` escapes, plus required
lookahead. It must also handle the 255-byte identifier boundary without
invalidating `TokenLexemePointer`. This bounded token storage is host workspace
and is reported separately from compiler workspace. A ROM mapping or larger
RAM cache may implement the same contract without refills.

No compiler path may dereference a retained handle as though it were a source
pointer. Direct declaration restore, forward-routine retention, forward-name
comparison, and retained forward-parameter restoration must all use the three
operations above. The materialized-name scratch is host workspace, remains
stable until the caller finishes, and is separate from a refillable current
token window.

The host may supply chunks from RAM, ROM, a file, or a refillable page. A
sequential-only medium may spool the source part once before compilation. The
retained-name store and any source spool belong to external host storage, not
compiler workspace, and neither causes a second source pass by the compiler.

### 6.3 Compatibility entry

The existing five-byte resident descriptors remain supported by a compatibility
provider. Tests can therefore compare the resident and windowed paths from the
same raw bytes. New host APIs must not expose `sourceWindowBytes` as a language
capacity. They may report a cache size and source-part capacity separately.

### 6.4 Source proof obligations

The new path must prove:

- a unit larger than 2 KiB;
- a token, string literal, comment, and CRLF split at every cache boundary;
- a maximum decoded string written entirely with four-byte `\xNN` escapes;
- retained-name lookup after the containing source page has been replaced,
  including two different 255-byte names;
- restored declaration, forward-routine, and forward-parameter names after
  their original source pages have been replaced;
- a multipart diagnostic after several refills;
- import-comment bytes preserving later offsets;
- the existing exact part-count boundary;
- source-provider failure leaving no committed NOBJ;
- failed compilation followed by success with no stale name handle; and
- resident and windowed paths producing identical diagnostics, semantic
  transcripts, NOBJ, and D8 maps.

The conditional D8 trace ABI needs a provider-mode revision. Under the
resident compatibility provider, declaration and routine name words retain
their current raw-pointer meaning. Under the streaming provider, those words
are opaque handles and the collector resolves them through the current
generation's handle table to `(stable part identity, offset, length)`. Unknown,
stale, or spelling-mismatched handles invalidate D8 publication. The mode is
fixed when the collector starts; a word is never guessed to be a pointer or a
handle from its numeric value. Shipping layouts still contain no D8 hooks.

## 7. Streaming object output

### 7.1 Compiler sink

The compiler's logical sink operations remain unchanged. The production Z80
adapter sends each completed operation directly to the host instead of writing
an `AdapterLog`. Calls are bounded and synchronous from the compiler's point of
view. The host may buffer a short record payload, but it must not require a
complete target image, complete NOBJ, or complete bank in Z80 memory.

IMAGE and PATCH are different streams while compilation runs. Runtime-image
operations append to IMAGE after the provider verifies identity, linked length,
and helper layout. PATCH records append as their sites resolve. MAP and COMMIT
are not written until compilation and provider work succeed.

### 7.2 Host spools and commit

The operating layer owns two append-only temporary spools. At finalization it
forms the committed NOBJ by reading:

```text
BEGIN, image spool, patch spool, MAP, COMMIT
```

It updates record count and CRC incrementally. It must not concatenate the
spools into one resident byte array merely to calculate either value. A file
host may copy them into a temporary NOBJ and rename it. TEC-FS may chain
extents. Both implementations publish one generation atomically.

Abort closes or discards the tentative spools and leaves the previous committed
generation current. A truncated or failed stream has no COMMIT and is never
runnable.

The sink must also validate that PATCH extents do not overlap. A Node sink may
retain an interval index. A low-memory sink rescans the stored patch spool at
commit or uses an external bounded index; it does not grow a compiler- or
host-workspace table with the number of patches. The rescan is object
validation, not another source or compiler pass. An overlap aborts the
generation before COMMIT.

### 7.3 Node API

The Node API gains an output-consumer option. A successful target compile can
return:

- committed object metadata and a stream or stored-object reference; and,
  when requested,
- parsed NOBJ, materialized banks, HEX, or D8 artifacts.

In-memory NOBJ and materialized images remain convenience results for tests and
small programs. They are no longer mandatory fields in the basic successful
compile result. Existing callers receive a compatibility helper that requests
the old materialized result explicitly.

The parser and materializer also gain incremental forms. Their current
`Uint8Array` APIs remain convenience wrappers over those forms.

### 7.4 Output proof obligations

The streaming path must prove:

- NOBJ bytes identical to the current encoder for the same build;
- one object larger than every former adapter-log and materialized-output
  limit;
- IMAGE and PATCH records interleaved in production time but serialized in
  required NOBJ order;
- CRC and record count across spool boundaries;
- overlapping PATCH records rejected through the low-memory validation path;
- a late failure preserving an older committed generation;
- successful publication after that failure;
- provider failure after earlier IMAGE records;
- flat and four-bank output without resident bank arrays; and
- optional materialization producing bytes identical to the current helper.

## 8. Native NOBJ consumer

The compiler does not apply patches. A separate Z80 consumer reads NOBJ and
does so.

The consumer supports two distinct strategies.

With isolated private backing, a one-pass consumer:

1. validates `BEGIN` and the target profile;
2. writes monotonic IMAGE records into an isolated or non-runnable target
   extent;
3. applies PATCH records in stream order;
4. validates MAP, including used lengths and entry;
5. validates record count, CRC, COMMIT, and immediate EOF; and
6. only then publishes the image or enters the committed entry pair.

Without isolated backing, a stored-object consumer performs no target write in
pass one. It validates the complete locked or stable object, rewinds, then
materializes and revalidates it in pass two before entry. This is not a second
compiler pass. A direct wire load is permitted only under the first strategy,
where partial target bytes remain isolated and unrunnable until commit.

A banked loader selects physical backing for each bank while processing its
records. If the machine cannot isolate every bank during a direct receive, it
stores NOBJ first and materializes it later. It never attempts to hold four
complete 16 KiB banks beside the compiler.

ROM programming remains a separate utility. It validates and materializes the
same NOBJ before invoking a burner. The compiler and native RAM loader do not
write ROM.

The Z80 consumer is measured as host code, not compiler core or generated
runtime. It receives its own code, workspace, file-buffer, and cycle accounts.

### 8.1 Consumer-platform ABI

The NOBJ consumer has a platform ABI separate from the compiler-host ABI and
the generated-program runtime vector. Its minimum logical operations are:

- open the selected committed object generation;
- read the next byte and distinguish EOF from storage failure;
- rewind to the first byte;
- lock or otherwise verify that the generation cannot change between passes;
- select one physical bank while preserving fixed-memory loader state;
- publish the validated entry pair and map;
- enter that pair; and
- close or abort the load.

The flat implementation may write target RAM directly. The banked implementation
selects a bank, writes its visible window, then returns to always-visible loader
code. Storage calls and bank selection must preserve the consumer's documented
stack and workspace. `enter` is unreachable until every validation and
materialization step succeeds.

### 8.2 Loader memory map

Every deployment publishes half-open extents for:

- consumer code and immutable tables;
- consumer workspace and record buffer;
- consumer stack;
- memory-mapped object bytes, when used; and
- each visible target write region.

Within one selected address space, target writes must not overlap consumer
code, workspace, stack, the current record buffer, or immutable object storage.
Banked consumer code and state stay outside the switched window. A flat target
whose final image would cover the loader requires a relocated loader or private
backing and is rejected otherwise.

An in-place stored load first validates the complete object, then materializes
from a locked immutable generation. If the storage layer cannot lock a
generation, the second pass recomputes framing, record count, and CRC before
entry and rejects any difference; the partly written image remains
non-runnable. Direct-wire loading still requires isolated backing for the whole
target being received.

## 9. Runtime provider and native service layering

The runtime provider is an operating-layer component keyed by
`runtimeIdentity`. It receives the complete validated link context, assembles
or selects the canonical runtime, checks length and helper offsets, and streams
resolved bytes into IMAGE. The compiler never holds that image.

The Node reference provider may continue to invoke AZM beneath the host ABI.
That does not make AZM part of the compiler. An initial MON3/TECM8 deployment
may instead provide a bounded catalog of runtime images prelinked for its
supported target profiles and reject another link context before output. A
general native provider requires a Z80 assembler/linker service, such as the
future Atom toolchain, and is not silently assumed by this plan. Both provider
forms implement the same identity, context, length, and helper-layout checks.

Debug80 instruction stepping is synchronous while AZM linking is asynchronous.
The Node reference host therefore uses an explicit request/suspend/resume
protocol. A Z80 provider entry copies the bounded request into host workspace,
records a continuation, and reaches a distinguished stable yield point with
its call frame still owned by the host. The outer async driver observes that
state, awaits the provider, writes either the verified result reference or an
exact failure status into the mailbox, and resumes at the host continuation.
The continuation restores the documented registers, flags, stack, and selected
bank before returning to the compiler. Reset or cancellation while suspended
aborts the tentative generation and cannot resume the stale continuation.

The proof must cover success, unavailable identity, wrong length, asynchronous
provider failure, cancellation, and a second compilation after each failure.
A prelinked Node catalog may be used as an additional fast path, but it does
not substitute for proving the suspend protocol used by an asynchronous
provider.

The reference compiler deployment has three layers:

```text
Nucleus compiler
        -> compiler-host Z80 ABI
        -> Z80 host/provider implementation
        -> MON3-compatible RST gateway
        -> Node device implementation
```

Debug80 executes the first three as real Z80. Node handles terminal bytes,
files, clocks, and bank devices beneath the RST gateway. The later hardware
deployment replaces Node with MON3 or TECM8 implementations of the same
gateway.

Generated Nucleus programs use a different ABI: the RAM-resident runtime vector
defined by the runtime contract. The two tables may eventually share monitor
gateways, but their entry order, register contracts, failure model, and version
identity remain separate. Compiler-host services must never be exposed as
source-callable generated-program services by accident.

`RST 10h` is a synchronous firmware call, not an asynchronous interrupt. The
Z80 host preserves the registers, stack, and bank state required by each
Nucleus ABI entry. Interrupt handlers remain outside Nucleus as required by the
runtime contract.

## 10. Direct Z80 port access

`readPort` and `writePort` remain built-in Z80-specific extensions. They map
directly to `IN A,(C)` and `OUT (C),A`, use a full `u16` port, and add no runtime
vector or host service.

They remain because a Nucleus library cannot currently emit arbitrary machine
instructions and because replacing a direct hardware access with a monitor
round trip would change both availability and timing. The language and runtime
documents must label them clearly as target-specific extensions rather than
portable console facilities.

Their removal may be reconsidered only after a native extension mechanism has
been implemented and measured. It is not part of this plan.

## 11. Shared standard library

### 11.1 Routine-capacity prerequisite

The current compiler admits four non-main routines. The library below defines
twelve before any user routine, so it cannot be implemented against that
capacity. Splitting source files does not help because all parts share one
program scope.

Before adding library source, run an independently measured capacity change
with these minimum goals:

- sixteen ordinary routine entries, preserving four user routines after the
  twelve initial library routines;
- twenty-six retained parameter entries, preserving the current sixteen user
  parameter entries after the library's ten parameters; and
- at least sixty-four generated label slots.

The existing three-byte fixup entry cannot represent this change. It combines a
five-bit label, two-bit site bank, and far marker in one byte, and source calls
use that entry as well as structured control. Milestone 2 replaces it with a
four-byte entry:

```text
label       : u8, valid range 0..63
flags       : bits 0..1 site bank, bit 7 far; other bits zero
siteAddress : u16 little-endian
```

Fixup capacity remains 32. Structured-control labels remain below 31, `main`
uses label 31, and ordinary routines use labels 32 through 47. Source routine
labels therefore extend above 31 without being truncated into bank metadata. Definition,
local resolution, far resolution, range checking, and reset must all consume
the new fields explicitly.

The projected workspace cost is about 264 bytes: 96 for twelve additional
eight-byte routine entries, 40 for ten additional parameter entries, 96 for
expanding the generated label table from 32 to 64, and 32 for widening the 32
fixup entries by one byte. This is a hypothesis until assembly and execution
reproduce it. Core cost must fit the 251-byte headroom in Section 13 without
reducing control-label, fixup, symbol, source-part, or semantic capacities.
Proofs must discriminate labels 31, 32, 43, and 47 in local and cross-bank calls,
fill all sixteen routine entries and all twenty-six parameter entries, and
reject the next entry at its source position.

Routine capacity is not the only gate. All imported library bodies occupy the
single 511-byte semantic transcript. The experiment must measure payload use
for the console module alone, the formatting module with its console
dependency, and each combined with a representative user program and the
complete accepted Chapter 18 program. It must report remaining transcript
bytes and retain the existing exact-fill and first-overflow behavior. If the
initial library cannot leave useful program capacity, the work stops for a
separate transcript-streaming or library-scope design; it does not quietly
raise a memory constant or call the library practical because it fits by
itself.

The Milestone 2 draft measurements validate the modular split and also expose
the remaining boundary. With the 511-byte payload unchanged:

- `console/output.nu` uses 140 bytes and leaves 371;
- `console/input.nu` uses 157 bytes and leaves 354;
- output plus unsigned formatting uses 275 bytes and leaves 236;
- output plus unsigned and signed formatting uses 329 bytes and leaves 182;
- output plus hexadecimal formatting uses 199 bytes and leaves 312;
- output plus a representative user program uses 156 bytes and leaves 355;
- output plus unsigned formatting and that user program uses 364 bytes and
  leaves 147; and
- output plus the complete Section 18.1 program uses 397 bytes and leaves 114.

Adding unsigned formatting to the complete Section 18.1 program exceeds the
payload at source part 3, offset 482, with the existing semantic-capacity
diagnostic. These are measured test-only draft bodies, not a claim that the
finished formatting algorithms are smaller. The result permits the routine and
parameter expansion to stand, but it does not clear the complete standard
library for implementation. Before the finished library is retained, the
semantic transcript needs a separately reviewed streaming, external-spool, or
library-scope solution. The fixed 511-byte capacity is not raised silently.

### 11.2 Ownership

There is one Nucleus standard library, written in Nucleus source. Node and Z80
hosts do not provide different source libraries. They implement the same
standard byte-service vectors beneath it.

The initial console library is deliberately split so a program pays only for
the direction it uses. `console/input.nu` supplies:

```text
getChar() as u8 fails
readLine(destination as string[]) fails
```

`console/output.nu` supplies:

```text
printChar(value as u8) fails
printString(text as string[]) fails
printLine(text as string[]) fails
printNewline() fails
```

`getChar` and `printChar` are readable wrappers over `readInputByte` and
`writeOutputByte`. `printString` writes exactly the logical string bytes and no
line ending. `printLine` writes the string followed by one LF. `printNewline`
writes one LF.

Each output routine stops at the first `writeOutputByte` failure and propagates
that exact recoverable code. Bytes accepted before the failure remain written.
`printLine` attempts its LF only after every text byte succeeds. Input newline
normalization applies only to an interactive console provider; a file, pipe, or
other selected standard-input stream retains its defined bytes unless its own
adapter contract says otherwise.

The full names are intentional. `printString` names the accepted value type;
`printLine` names the added line-ending behavior. `println` and abbreviated
`printStr` aliases are not added.

Formatting is split for the same reason. `format/unsigned.nu` supplies
`printU8` and `printU16`; `format/signed.nu` adds `printI8` and `printI16` and
imports the unsigned module; `format/hex.nu` supplies `printHex8` and
`printHex16`. Importing every formatting family still provides the original
twelve-routine library surface, but ordinary programs need not spend transcript
or generated bytes on unused conversions.

Together the formatting modules supply the routines needed by programs and the
introductory documentation:

```text
printU8(value as u8) fails
printU16(value as u16) fails
printI8(value as i8) fails
printI16(value as i16) fails
printHex8(value as u8) fails
printHex16(value as u16) fails
```

They write directly through `printChar` and allocate no hidden string. Decimal
output has no leading zeroes except for the value zero. Signed output writes a
leading minus only for a negative value and must handle the minimum signed
value without first negating it in its original width. Hexadecimal output uses
uppercase `A` through `F` and fixed width: two digits for `u8`, four for `u16`.
These are library routines, so they add source bytes, semantic-transcript
bytes, and generated-program bytes but no compiler-core or selected-runtime
bytes.

### 11.3 `readLine`

The settled interface is:

```text
readLine(destination as string[]) fails
```

Its behavior is:

- reset `destination.length` to zero before reading;
- LF is the only logical line terminator;
- consume LF but do not store it;
- an immediate LF succeeds with an empty string;
- EOF before any byte fails with `endOfInput`;
- EOF after one or more bytes succeeds with that final partial line;
- filling the destination exactly and then reading LF succeeds;
- on additional content, retain the first `capacity` bytes, drain through the
  next LF, and fail with `lineTooLong`;
- EOF while draining an overlong line ends that line and still fails with
  `lineTooLong`;
- another input failure propagates after retaining the established prefix;
- embedded zero is ordinary content; and
- every successful length change uses the checked writable `string[]` length
  operation.

The library reserves:

```text
const lineTooLong = 5
```

Physical console adapters normalize Enter, CRLF, or platform-specific key
events to one LF byte before `getChar` sees them. The library does not contain a
second CRLF policy.

The destination must be backed by writable storage. The language's open-string
type also admits an aggregate constant or anonymous literal, and its settled
alias policy performs no dynamic read-only check. Passing such an object is
therefore permitted by the type system but does not satisfy the library
contract: mutation can disappear in ROM and take effect in RAM. Documentation
and examples always pass a mutable program variable or an alias rooted in one.

### 11.4 Packaging

The host import resolver places standard-library parts before their users in
the ordinary ordered source stream. The tokenizer treats the import directive
as an ordinary preserved comment, so compilation remains filesystem-unaware.

For a native machine, library source may live in ROM or TEC-FS. Windowed source
input prevents the library from consuming a fixed resident-source allowance.
The same source bytes and logical identities are used under Node so D8 maps and
diagnostics agree.

The preserved directive spelling is:

```text
//% import "path/to/file.nu"
```

A directive occupies one complete physical line in the leading comment header.
The header continues across import directives, blank lines, and ordinary
`//` comment lines; the first other line ends it. The host rejects a
directive-shaped line after that point instead of quietly changing dependency
order. Paths are printable ASCII, slash-separated, and at most 255 bytes. They
resolve relative to the importing source or a configured standard-library
root; normalization may consume `..` but must not escape the project root. The
resolver reports missing input, invalid path, root escape, and the complete
cycle chain before compilation.

Discovery is import-once by normalized physical identity. A depth-first
postorder places dependencies before importers while preserving directive order
among siblings. Stable source identities are assigned only after final order.
The exact raw bytes, including directive comments and original line endings,
reach the compiler unchanged.

Node CLI and API support and the native file resolver are both implementation
work in this plan; neither is assumed to exist. The two standard-library files
consume two of the current eight source parts, and all twelve routines are
emitted because Nucleus performs no dead-code elimination. Those effects are
measured explicitly. Increasing source-part capacity or adding library linking
would be a separate change rather than hidden in packaging.

## 12. Documentation and examples

Documentation must stop teaching calculations whose results cannot be
observed. The introductory program should:

1. import the console library;
2. call a small function that returns a scalar;
3. assign that result to a named local in `main`; and
4. print it through `printU8` or `printU16`.

Every complete worked program should have an observable effect. Small excerpts
may still omit output when they isolate one rule.

The reference documentation must explain the difference among:

- source imports resolved by the host;
- compiler standard services;
- ordinary Nucleus library routines;
- direct Z80 port extensions;
- the generated-program runtime provider; and
- the NOBJ loader.

The book and the repository examples must compile through the same public host
path. Documentation verification should execute representative examples and
check their output bytes, not only their acceptance.

## 13. Resource accounting

The measured production baseline at `886cd95` is 15,696 code bytes plus 437
immutable bytes, or 16,133 bytes of compiler core. It has 251 bytes of headroom
below 16 KiB and uses 3,613 workspace bytes. The selected target runtime is 899
bytes. These are current measurements, not the older figures in the historical
startup plan.

The narrow margin changes the implementation strategy. Production source and
sink adapters must replace current code paths rather than accumulate beside
them. Resident-source and AdapterLog compatibility adapters belong in
conditional proof layouts and do not remain in the shipping core. If a
milestone crosses 16 KiB, it stops for compression limited to the changed
boundary or restores its baseline; it does not borrow bytes from a published
capacity.

Every milestone reports these accounts separately:

- compiler code and immutable data;
- compiler workspace;
- semantic-transcript capacity, library use, and remaining user payload;
- source-provider cache and external source storage;
- Z80 host code and workspace;
- IMAGE and PATCH spool storage;
- NOBJ consumer code and workspace;
- generated program and selected runtime;
- Node/TypeScript adapter code; and
- proof instructions and T-states.

The compiler core remains below 16 KiB. Host and loader code do not count
against that gate, but their bytes must still be reported. A host feature does
not become a compiler saving merely because it moved outside the core.

Removing the resident-source and materialized-output assumptions must not be
paid for by lowering source-part count, semantic-transcript capacity, symbol
capacity, fixup capacity, bank count, or any other published limit.

## 14. Implementation sequence

Each numbered milestone is reviewed, committed, and pushed before the next one
depends on it.

### Milestone 1: contract and reference adapters

- publish this plan after adversarial review;
- define the exact Z80 host vector ABI and register contracts;
- define the separate NOBJ consumer-platform ABI and memory-map contract;
- isolate the existing resident-source and AdapterLog implementations behind
  compatibility adapters; and
- add differential fixtures that can drive both old and new adapters.

### Milestone 2: routine and parameter capacity

- expand the generated label table and replace packed three-byte fixups with
  the four-byte representation in Section 11.1;
- raise ordinary routine capacity to sixteen;
- raise retained parameter capacity to twenty-six;
- prove local and far calls to labels above 31; and
- measure core, workspace, semantic use with both library modules, generated
  code, and all exact boundaries.

### Milestone 3: streaming NOBJ in Node

Status: implemented, adversarially reviewed, and verified.

- make spool finalization incremental;
- add a streaming NOBJ reader and validator;
- add the low-memory patch-overlap rescan;
- make materialization optional in the public compile result;
- retain explicit compatibility helpers; and
- prove byte identity and atomic publication.

This is implemented before the Z80 output adapter so the latter has a real
consumer rather than another log.

### Milestone 4: native Z80 output adapter

- replace AdapterLog in the production path with host sink calls;
- run the adapter under Debug80 with Node-backed sequential spools;
- preserve the proof adapter for isolated compiler tests; and
- prove flat and banked objects without resident output arrays.

### Milestone 5: windowed source provider

- implement the specification's source-part and byte-chunk events;
- introduce generation-scoped exact retained-name handles;
- revise D8 pointer/handle collection modes;
- add the resident-descriptor compatibility provider;
- remove `sourceWindowBytes` from the language-facing capacity result; and
- prove units larger than the old 2 KiB window.

### Milestone 6: Z80 NOBJ consumer

- implement the stored flat loader first;
- add bank selection and banked materialization;
- enforce the consumer memory map and locked two-pass input;
- verify CRC, record order, overlaps, MAP, and COMMIT;
- keep partial output non-runnable; and
- test it beneath Debug80 before binding storage operations to TEC-FS.

### Milestone 7: native service host

- implement the stable Nucleus host vectors in Z80;
- implement a MON3-compatible RST gateway beneath them;
- run it under Node/Debug80 device services;
- prove provider request/suspend/resume and cancellation;
- test stack, bank, failure, reset, and sequential-run behavior; and
- document the later MON3/TECM8 binding work.

### Milestone 8: import resolver, standard library, and documentation

- implement `//% import` discovery in the Node host and native file resolver;
- add console source modules and executable tests;
- add formatting needed by the introductory examples;
- measure semantic payload for console alone, console plus formatting, and each
  required worked program, with remaining capacity stated explicitly;
- implement and prove `readLine` with the settled LF behavior;
- update repository examples, reference documentation, and the Nucleus book;
  and
- make documentation verification check actual output.

## 15. Review and verification gates

Each implementation milestone runs the scoped Nucleus tests, full Nucleus
suite, typecheck, formatting, `git diff --check`, and the Z80 stack-balance
checker over every changed assembly layout. Generated compiler images must be
rebuilt twice and the second run must be clean.

The final adversarial correctness review must trace:

- all source-provider success, EOF, refill, and failure exits;
- retained-name lifetime and exact diagnostic positions;
- every sink call's register, flag, and stack contract;
- output failure and abort after partial IMAGE and PATCH data;
- runtime-provider identity and length failures;
- CRC, record order, overlap, used-length, and terminal-EOF validation;
- flat and banked loader publication;
- reset between sequential compiler and program runs;
- console error propagation and every `readLine` boundary; and
- byte identity between compatibility and streaming paths.

After correctness is green, perform a focused size pass on the new compiler
boundary only. Follow it with a second read-only correctness-and-size review.
Do not recover compiler bytes through unrelated language changes or capacity
reductions.

## 16. Completion criteria

This plan is complete only when all of these statements are true:

- a real Z80 host implementation runs beneath Node/Debug80;
- the same ABI is suitable for a MON3/TECM8 binding;
- a compilation unit larger than 2 KiB compiles without whole-source
  residency;
- successful compilation can publish NOBJ without a complete NOBJ or bank
  image in Z80 or Node memory;
- a separate Z80 consumer validates NOBJ and applies its patches;
- flat and banked publication remain transactional;
- the shared Nucleus console library works under the reference host;
- `readLine` has the behavior in Section 11.3;
- direct port I/O remains documented as a Z80 extension;
- worked examples produce verified observable output; and
- current authorities, public API documentation, implementation, tests, and
  measurements agree.
