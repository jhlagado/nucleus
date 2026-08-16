# Ground-up Nucleus compiler rewrite

## Status

This document is the implementation plan for a new standalone Z80 Nucleus
compiler. The rewrite starts from the annotated Git tag
`rewrite-baseline-2026-08-16`, which resolves to commit
`0382f73fe3bc29e86496b92334287139c2de92f1`.

The baseline compiler remains the behavioural oracle while the replacement is
under construction. The replacement does not include, wrap, or gradually
modify the old compiler implementation. It lives beside it until it passes the
complete language, target, object, D8, diagnostic, relocation, and resource
gates. The production composition changes to the replacement only after that
point. The tag preserves the old implementation if later investigation needs
it; the production package does not retain both compilers after cutover.

This is an implementation redesign, not a language revision. The Nucleus 0.1
language specification remains authoritative. The target-system, Z80 runtime,
NOBJ, D8, Host API, and CLI contracts remain authoritative at their existing
boundaries.

## Objective

Build a complete origin-independent Z80 compiler for the current Nucleus 0.1
language with a measured compiler core between 12 and 14 KiB. The working
target is at most 14,336 bytes. The absolute acceptance gate remains 16,384
bytes. Code and immutable compiler data both count toward these totals.

The rewrite must compile every conforming program accepted by the baseline,
reject every conforming program rejected by the baseline, report the same
diagnostic code and exact source position, and generate the same target
artifacts unless a separately approved correction or target-runtime revision
changes a published contract. The frozen compiler is evidence, not permission
to preserve a contradiction with a higher authority. Every such contradiction
must appear in the conformance-correction ledger below and have a permanent
discriminating test. Internal token, type, action, and semantic-operation
ordinals may change because none is a published format.

The target is not a source-line reduction. It is a simpler compiler with fewer
independent mechanisms, fewer handwritten policy paths, and explicit data
formats that can be measured as complete resident accounts.

## Authority and invariants

The rewrite reads these authorities in order:

1. `docs/specification.md` for source syntax and semantics;
2. `docs/target-system-specification.md` for target selection and placement;
3. `docs/z80-runtime-contract.md` for representation, calls, traps, services,
   and generated-code obligations;
4. `docs/nucleus-object-format.md` for NOBJ production and publication;
5. `docs/d8-source-maps.md` for trace collection and source-map publication;
6. `docs/host-api.md` for the Node and CLI boundary; and
7. `docs/reviewers-charter.md` for review classification and settled project
   decisions.

The replacement preserves the following properties throughout development:

- Zilog Z80 is the machine authority. Undocumented emulator behaviour is not
  an implementation technique.
- The compiler image may be assembled at any origin at which its complete
  16-bit address range fits. Deployment policy selects the origin.
- All code and data pointers are full 16-bit addresses. Address bits never
  carry tags, lengths, operation classes, or other metadata.
- The source language gains no pointers, heap, address arithmetic, AST, or
  unbounded compiler structure.
- Ordered multipart source identity and byte positions remain exact.
- The compiler retains a bounded checked semantic transcript and does not
  publish it as a portable object format.
- Parsing must succeed before target output begins. A failed compilation never
  publishes a partial target generation.
- NOBJ remains append-only and ends in one valid `COMMIT`; D8 remains a
  tentative sidecar published only with a valid target build.
- Evaluation order, conversion points, failure consumption, trap timing,
  aggregate aliasing, copy atomicity, banking, and activation semantics remain
  unchanged.
- Debug instrumentation is conditionally absent from the shipping image.
- Compiler code, immutable compiler data, workspace, semantic transcript,
  runtime, generated program, and execution storage remain separate accounts.
- Ordinary Z80 instructions use AZM mnemonics. Raw `.db` or `.dw` encodings
  may represent tables, recipe programs, emitted target templates, or other
  declared data, but may not conceal an instruction executed by the compiler.
  If AZM cannot express a required legal Z80 instruction, work stops for an
  assembler report and an explicit exception decision.
- The rewrite does not use `RST`, self-modifying compiler code, or
  platform-owned vectors unless a later deployment contract explicitly makes
  them available.

### Conformance-correction ledger

R1 found three lexical defects inherited from the frozen compiler. The
replacement follows Chapter 3 of the language specification in each case:

| Source case                                                                       | Frozen compiler                                           | Required replacement behaviour                       |
| --------------------------------------------------------------------------------- | --------------------------------------------------------- | ---------------------------------------------------- |
| `(]`, `[)`, or crossed `([)]` delimiters                                          | reaches the parser and reports a later grammar diagnostic | report lexical diagnostic 1 at the mismatched closer |
| `\0`, `\n`, `\r`, `\t`, `\'`, `\"`, `\\`, or `\xHH` escape in a character literal | rejects the literal                                       | accept it and return the one decoded byte            |
| `$00`–`$08`, `$0B`–`$0C`, `$0E`–`$1F`, or `$7F`–`$FF` inside `//`                 | ignores the byte and may compile the program              | report lexical diagnostic 1 at that source byte      |

R3 found one declaration-order defect inherited from the frozen compiler:

| Source case                                              | Frozen compiler                     | Required replacement behaviour                                                                                                                            |
| -------------------------------------------------------- | ----------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| any top-level declaration after the complete `main` body | reports expected-EOF diagnostic 128 | process it under the ordinary compilation-unit sequence: accept a valid declaration and apply the normal grammar or semantic diagnostic to an invalid one |

R4 found one postfix-diagnostic defect inherited from the frozen compiler:

| Source case | Frozen compiler | Required replacement behaviour |
| --- | --- | --- |
| a missing field selected through a valid nested record path | fails to terminate within the Host execution limit | report unknown-name diagnostic 57 at the missing field name |

These are bounded corrections to the oracle, not language additions. The
accepted source-byte repertoire, typed delimiter rule, literal escapes, and
ordered top-level declaration sequence that does not require `main` to be last
were already normative before the baseline tag was created. All other
comparisons continue to require exact frozen-compiler parity.

The consolidated capacity ledger also omitted the already implemented
255-byte decoded-literal limit and 255-level delimiter limit. R1 publishes both
limits with exact boundary evidence. This is a documentation correction; it
does not change the frozen compiler's counters or accepted capacity boundary.

## Measured baseline

These measurements were reproduced from the normal generated compiler image
at the tagged baseline. They supersede the older 15,290-byte table in the
review brief.

| Resident region                   |     Bytes | Status   |
| --------------------------------- | --------: | -------- |
| source adapter                    |       141 | Measured |
| tokenizer                         |       869 | Measured |
| semantic sink                     |        58 | Measured |
| symbols                           |       106 | Measured |
| complete parser region            |     9,794 | Measured |
| backend and target-output region  |     5,302 | Measured |
| compiler code                     |    16,270 | Measured |
| immutable compiler data           |       410 | Measured |
| compiler core                     |    16,680 | Measured |
| excess over 16 KiB                |       296 | Measured |
| peak compiler workspace           |     3,639 | Measured |
| selected proof runtime            |       899 | Measured |
| target-enabled proof instructions | 1,025,324 | Measured |
| target-enabled proof T-states     | 9,980,322 | Measured |

The parser region contains 6,292 bytes before the 221-byte packed LL(1)
engine, 831 bytes of generated LL(1) tables and directories, and 2,450 bytes
of LL(1) actions. The backend region contains 1,825 bytes of common emission
and target-output code followed by 3,477 bytes of typed and aggregate backend
code. These subdivisions use assembled boundary symbols and are useful design
coordinates; they are not separate accounting categories.

The existing compiler already uses one precedence-driven loop for binary
expressions. Replacing a hypothetical seven-routine precedence ladder cannot
produce the saving claimed in the supplied review. The new expression design
must reduce the complete expression, postfix, call, folding, conversion, and
type-checking path.

The existing typed dispatcher also has a separate 13-byte first-operand
prefetch bitmap. The experiment demonstrates that address-independent metadata
works, but a one-bit first-operand classification does not describe the full
semantic stream. The rewrite starts with a complete operation format instead
of extending that bitmap piecemeal.

Fresh baseline verification passed:

- `npm run check:azm-toolchain`;
- `npm run check:compiler-images`;
- all 23 cases in `test/proof-harness.test.ts`;
- compiler relocation at `$0000`, `$0100`, `$8000`, and the highest fitting
  origin; and
- `npm run typecheck`.

The complete serial test suite remains the final baseline and milestone gate.

## Architectural choice

The replacement uses two small interpreters with explicit handwritten escape
paths:

1. a front-end machine executes grammar and semantic-action programs; and
2. a backend recipe machine converts checked semantic operations to target
   output.

The machines use different instruction sets. Grammar actions manipulate
tokens, symbols, types, declarations, flow state, and semantic publication.
Backend recipes manipulate target bytes, operands, labels, fixups, runtime
calls, bank state, and NOBJ records. A universal compiler virtual machine is
deferred because it would couple unrelated state, weaken register-contract
coverage, and make the first size result difficult to attribute.

Irregular operations remain handwritten Z80 routines reached through explicit
escape instructions. Generated dispatch uses ordinary full 16-bit jumps.
The rewrite does not force difficult semantics into a bytecode merely to make
the source look uniform.

### Source and token layer

The source adapter retains the current ordered multipart contract and exact
part-relative byte offset. The tokenizer becomes one table-directed scanner
with four handwritten families: names and keywords, integers, quoted literals,
and punctuation. Newline synthesis, CRLF handling, comment termination, escape
rules, literal limits, and diagnostic anchors remain exactly as specified.

Keyword descriptors use ordinary data offsets or full addresses. High-bit
termination may mark characters because keyword bytes are character data; it
must not reduce a code or source address. Packing is accepted only after the
complete scanner plus table is smaller than the straightforward form.

The tokenizer returns the token ordinal and payload in registers while
retaining the token-start byte offset, source pointer, and bounded name or
literal length. Parser lookahead stores that result when it must survive
another operation. For lexical diagnostics, the compiler selects the
authoritative source part and byte offset; the Node host reconstructs the
one-based line and byte column from the original source bytes. D8 uses the
same reconstruction routine, so both publications have one definition of
CRLF and byte-column handling. Later front-end milestones must preserve any
oracle diagnostic whose byte-offset and display anchors differ, either with a
second byte anchor or explicit position fields. The public diagnostic remains
exact in either representation.

### Symbols and types

Primitive type ordinals have an intentional bit layout for width, signedness,
Boolean classification, and exact literals. Composite type ordinals index a
bounded descriptor table. Descriptor fields continue to describe kind,
element or field type, count or capacity, and complete extent without exposing
an address to source code.

Nested fixed arrays are descriptor chains. `T[]` and `string[]` are
parameter-only views whose retained dynamic extent or capacity lives in the
activation representation, not in an address bit. Records, concrete arrays,
bounded strings, and open views share type-query primitives for kind, element,
extent, mutability, and compatibility.

The rewrite uses one symbol entry format with class-specific payloads and an
explicit storage-segment byte; it never hides segment identity in an address.
Separate directories exist only where a complete measurement proves that split
entries are smaller. Names continue to refer to retained source bytes. Forward
routine signatures, activation layout, and aggregate carriers remain bounded
and explicit.

### Front-end machine

The front-end machine replaces the current split between generated LL(1)
productions and 2,450 bytes of individually dispatched action routines.
Generated productions contain terminals, nonterminals, and calls into compact
semantic-action programs. A small action instruction set covers repeated work:

- expect or consume a token;
- save or restore a source anchor;
- set or query a declaration class or type;
- look up, reserve, and commit a symbol;
- begin, append, and finish a composite type;
- begin and finish a routine or control frame;
- select an expression context;
- publish a semantic operation and its operands;
- test flow, failure, mutability, and compatibility predicates; and
- raise a diagnostic through the single nonreturning exit.

Each action instruction has a declared byte width and register/stack contract.
The generator verifies every action program boundary, operand width, branch
target, maximum call depth, and grammar-stack effect. An action may invoke a
full-address handwritten escape for type formation, aggregate initialization,
call preparation, or another path whose measured bytecode is larger than Z80
code.

The grammar remains predictive and retains no AST. The generated machine data
is an implementation of the current grammar, not a second language authority.
Grammar regeneration must remain exact and deterministic.

### Expressions, paths, and calls

One precedence-climbing engine parses binary expressions. One primary engine
handles literals, conversions, names, calls, and grouping. One postfix engine
handles fields, concrete indexes, open indexes, and `.length`. Assignment
targets, argument values, initializers, conditions, and return expressions use
the same engines with an explicit context record.

The principal redesign is not precedence climbing itself; the baseline already
has that. The replacement removes policy duplicated around the loop:

- a table maps a token to precedence, associativity, operation family, and
  admitted operand classes;
- a common resolver performs exact-literal adoption and the specified integer
  conversions;
- constant and runtime expressions share parsing and type resolution, with an
  evaluation-mode callback for folding or semantic publication;
- postfix selection produces one path record used by reads, writes, arguments,
  and aggregate results; and
- call parsing records a complete result and failure category before the
  enclosing statement selects propagation or handling.

Tables express dense policy only when the complete table, selector, default
path, and exceptional handlers are smaller than code. Signed arithmetic,
open-view compatibility, and nested-array selection must remain visible in
executable boundary tests rather than disappearing behind an unverified type
matrix.

### Semantic transcript

The semantic transcript remains the atomic boundary between parsing and target
generation. The rewrite may renumber or reshape internal operations, but one
checked generated authority defines every operation. Its per-operation
descriptor contains:

- complete record width;
- operand count and operand widths;
- recipe or handwritten backend class;
- stack-value effect;
- source-attribution class; and
- a selector in the recipe or handwritten-backend namespace.

The top-level authority separately defines the global debugging trace policy.
Descriptors contain ordinary bytes and one-byte directory selectors, never
shortened addresses. Later backend milestones construct full-address
directories from those selectors. The format does not assume that four
operand shapes cover the language. The dispatcher validates the record
boundary before reading any operand and prefetches the declared fields into a
fixed operand area. Handlers never advance the live semantic cursor themselves.

The grammar/action generator and D8 decoder consume the same generated
operation-format authority. The generated-authority and publication checks
fail if a producer, dispatcher, recipe, or D8 width disagrees. The transcript
keeps its current published capacity
until a separately measured change updates the specification, tests, and first
overflow diagnostic together.

### Backend recipe machine

The recipe machine is the largest planned saving. A recipe contains only
declared data instructions, such as:

- emit a literal run;
- emit an operand byte or word;
- emit a target address or runtime-helper call;
- load, store, exchange, or discard the target evaluation carrier;
- allocate or release activation words;
- create, bind, or patch a label;
- select an 8- or 16-bit sequence from scalar type bits;
- select signed or unsigned comparison and arithmetic support;
- request a checked region, index, conversion, or failure sequence; and
- escape to a full-address handwritten handler.

Recipes are data and may use `.db` and `.dw`. Their format is documented beside
the interpreter, and the generator disassembles them as recipes rather than as
Z80 instructions. Z80 executed by the compiler always uses mnemonics. Target
instruction templates stored as data remain clearly labelled target bytes and
are checked against AZM-assembled reference sequences.

The interpreter owns semantic operand access, output failure propagation, and
the current source attribution. A recipe cannot read the semantic cursor or
write the NOBJ sink directly. This makes malformed recipes detectable before
they can desynchronise the transcript or partially publish an output record.

Control-flow fixups, calls and activations, aggregate region checks, failable
completion, bank transitions, and final target layout begin as handwritten
escapes. They migrate into recipes only when a complete-family measurement
shows a net saving and the resulting recipe remains easier to verify than the
routine it replaces.

### Runtime boundary

Runtime identity 8 and its helper layout remain frozen during compiler parity.
The replacement must first produce byte-identical runtime selection, generated
programs, NOBJ, HEX, materialized images, and D8 maps for the oracle corpus.

Moving repeated generated sequences into new runtime helpers is a separate
post-parity project. It changes runtime identity, absolute target addresses,
artifacts, program execution time, and sometimes banking pressure. Combining
that work with the compiler rewrite would make a compiler-size saving
impossible to distinguish from a target-layout redesign.

### Diagnostics and abort

All compiler diagnostics enter one nonreturning routine. That routine captures
the diagnostic code and its source anchors before it restores the armed
compiler entry stack. The R1 image declares offset-only diagnostics, so the
Node host derives line and byte column from the retained source. A later image
may publish an independent display anchor when the frozen oracle requires one.
Parsing and generation use separate armed continuations, so generation failure
performs exactly one target-output abort while parse failure never consults
post-parse overlay state.

The replacement is designed around this model from its first instruction.
There is no compatibility configuration with per-frame diagnostic carry
propagation. Local carry results for EOF, comparisons, capacity checks, target
services, and other recoverable operations remain ordinary routine results and
must not enter the diagnostic unwind accidentally.

### D8 instrumentation

The shipping image conditionally omits every trace instruction. The
instrumented image emits the same eight-port event ABI already documented.
Source and declaration marks occur at front-end action boundaries; semantic
start and end events occur in the new dispatcher; image-byte events occur in
the target adapter.

The rewrite must preserve the final D8 source ranges and routine symbols for
the oracle corpus. Internal semantic keys may change with the transcript, but
the collector validates them against the generated operation-format authority.
No event may be inferred from a compiler program counter.

## Resident budget

The following is a design budget, not a claim that the result has already been
measured.

| Replacement region                                          | Allocation | Status    |
| ----------------------------------------------------------- | ---------: | --------- |
| source adapter and tokenizer code                           |        850 | Projected |
| symbol and type-engine code                                 |        850 | Projected |
| grammar and action-machine code                             |      2,200 | Projected |
| expression, postfix, call, and folding code                 |      2,400 | Projected |
| transcript, diagnostics, and shared compiler control        |        600 | Projected |
| target layout and NOBJ production code                      |      1,400 | Projected |
| backend recipe engine and handwritten backend code          |      2,400 | Projected |
| all immutable keywords, grammar, operation, and recipe data |      2,200 | Projected |
| allocated compiler core                                     |     12,900 | Projected |
| unallocated margin below 14 KiB                             |      1,436 | Projected |

These allocations partition the resident account: recipe and action programs
appear only in immutable data, not again in their interpreter code rows. A
region may exceed its allocation when another region supplies the margin, but
every milestone reports the complete core as well as the local change. Moving
code into recipes does not save a byte unless the complete code plus immutable-
data total falls. The 1,436-byte margin covers estimation error and integration
bridges; it is not preassigned to a feature.

Peak workspace must remain at or below 4,096 bytes. The initial rewrite keeps
the existing public capacities and the 511-byte semantic payload. A proposed
workspace overlay requires a liveness proof for success, diagnostic, output
failure, and subsequent-compilation paths.

Compilation speed is subordinate to resident size, but it remains measured.
The target is no more than three times the baseline instruction and T-state
counts on the target-enabled proof. Crossing that threshold triggers a review;
it does not permit a correctness or size failure.

## Repository strategy

Development begins in a new `asm/rewrite/` tree. The directory contains no
includes from the old compiler's implementation files. It may include stable
machine interfaces and generated authorities whose contents are independently
checked against the specifications.

During development, the Host package exposes the replacement only to tests by
an explicit compiler-image selection. The public default remains the baseline
compiler. A test-only incomplete compiler may support a bounded vertical slice,
but it is never described as a Nucleus language profile and is never published.

Each milestone records:

- baseline and result commits;
- assembled code, immutable, core, workspace, and transcript extents;
- normal and instrumented results;
- generated program, runtime, NOBJ, HEX, image, and D8 comparisons;
- compiler instructions and T-states;
- accepted, rejected, capacity, failure, and trap discriminators; and
- retained and rejected architectural experiments.

## Milestones

### R0 — Freeze the oracle

The baseline tag and current branch are recorded. Add a rewrite-oracle manifest
containing representative flat and banked programs, every diagnostic family,
all published capacity boundaries, multipart/CRLF/final-newline cases, D8
maps, and normal/instrumented target identity. Store hashes only for artifacts
whose bytes are contractually expected to remain unchanged; retain structured
expectations for source diagnostics and runtime observations.

Exit gate:

- the oracle reproduces from the tag;
- the current full suite passes serially;
- normal and debug compiler images are paired with their exact symbol maps;
- the four-origin relocation proof passes; and
- all baseline accounts reconcile with assembled symbols.

Checkpoint result, measured on 16 August 2026:

- the oracle fixture records the annotated baseline tag and commit, combined
  image-and-symbol fingerprints, published Host API capacities, representative
  flat and banked artifacts, multipart newline cases, D8 maps, exact diagnostic
  records, and the test files that prove every row in the capacity ledger;
- the internal image selector is absent from the package export map and requires
  an explicit image-and-symbol pair, so the public Host API and CLI remain bound
  to the production images;
- `npm test` passed 24 files and 253 tests in serial execution, and the focused
  proof harness passed all 23 target proofs;
- the AZM capability gate, generated-image check, TypeScript check, build, and
  relocation proof at `$0000`, `$0100`, `$8000`, and the highest fitting origin
  passed; and
- the build corrected a stale distribution image whose core was 16,667 bytes.
  Source generation and the distribution build now produce the same measured
  16,270-byte code region, 410-byte immutable region, 16,680-byte core, and
  3,639-byte peak workspace.

### R1 — Replacement shell and source contract

Create the new composition, workspace map, public entry, diagnostic unwind,
source adapter, token record, and tokenizer. The test host can select the new
image explicitly. No old implementation source is included.

Prove every token, token payload, source position, source-part boundary,
newline form, comment, literal limit, malformed escape, and lexical capacity
against the oracle.

Exit gate: the replacement token/diagnostic layer is origin-independent, strict
AZM is green, and its complete source/token account is at most 1,100 core bytes.

Checkpoint result, measured on 16 August 2026:

- the replacement includes no old compiler implementation source and assembles
  at `$0000`, `$0100`, `$6000`, `$8000`, and the highest origin at which the
  complete image fits; the `$6000` case moves workspace and adapter intervals
  to prove that their addresses are deployment policy rather than code-origin
  assumptions;
- the shell is 66 bytes, the source adapter is 94 bytes, the tokenizer is 821
  bytes, and its immutable keyword, escape, and punctuation data is 184 bytes;
- the complete source/token account is 1,099 bytes, the shell plus that
  account is 1,165 bytes, and the workspace is 350 bytes, including the
  255-byte typed-delimiter stack;
- the multipart proof publishes 77 exact tokens and completes in 47,268
  instructions and 451,940 T-states; it covers a synthesized part newline,
  CRLF, blank and comment-only lines, tab columns, all character escapes, and
  final-newline synthesis;
- exact Host diagnostics match the frozen compiler for 16 lexical cases,
  including CRLF reconstruction, based-number fusion, and numeric limits;
- separate normative proofs lock the three conformance corrections in the
  ledger above;
- the same comprehensive single-part scan and diagnostic-unwind paths execute
  with the expected returned stack pointer at every tested origin; and
- direct replacement proofs distinguish the accepted 255-byte name, decoded
  literal, and delimiter-depth limits from their first rejected values. They
  separately cover malformed and crossed delimiters, invalid comment bytes,
  multipart delimiter failure, source-part counts 1 and 8, and rejected counts
  0 and 9;
- the complete serial suite passes 25 files and 257 tests, including all 23
  target proof cases and the unchanged production diagnostic anchors.

### R2 — Generated operation authority

Define the semantic operation source, generator, producer helpers, dispatcher
descriptors, D8 widths, and recipe boundaries. Implement transcript reset,
append, exact fill, first overflow, validation, semantic trace start, and the
single success end event.

R2 exit gate: stale generated authority fails the generated-authority and
publication checks; the Z80 boundary
rejects invalid ordinals, truncation, trailing bytes, and capacity overflow
before dispatch or tracing; the TypeScript boundary rejects wrong observed
keys and counts. Recovery starts from clean state. Production D8 publication
uses this authority only after the replacement reaches the later backend and
D8 integration gate.

Checkpoint result, measured on 16 August 2026:

- one JSON authority defines 99 compact operations, their named byte or word
  operands, backend recipe or escape selector, abstract stack effect,
  source-attribution class, and one global operation-start trace policy;
- all operation records have fixed declared widths from one to ten bytes.
  Source and service calls, local and program handlers, and direct and
  forwarded open arguments are separate operations rather than records whose
  length depends on an operand value;
- width, storage, signed-promotion, and direct/enclosing control variants keep
  the production record widths while sharing backend selectors. The common
  literal-plus-program-store pair remains six transcript bytes, so the signed
  exact-fill corpus does not lose accepted source;
- direct and enclosing labels, jumps, ordinary routine ends, and failable
  routine ends have separate ordinals. Their record widths and backend
  selectors remain shared, while source attribution no longer has to guess
  whether an operation came from source or from compiler-generated closure;
- divide, modulo, conversion, aggregate copy, and index operations retain the
  source offsets required by runtime traps. Open string capacity and writable
  length records carry activation displacements, not invented literal
  capacities;
- the generator produces Z80 ordinals, named producer offsets and widths, a
  99-byte width table, a 495-byte descriptor table, recipe and escape selector
  namespaces, and the TypeScript boundary decoder. The checked operation-data
  account is 594 bytes;
- the shipping transcript code is 220 bytes. Together with 15 bytes added to
  reset and the generated data, R2 adds 829 bytes and brings the replacement
  to 1,995 bytes. The instrumented image adds only the two conditional trace
  instructions and is 1,999 bytes;
- workspace is 879 bytes: the R1 account plus the published 512-byte counted
  transcript, two complete cursors, validation state, and a nine-byte
  operand-prefetch area;
- a producer checks the operation and complete record capacity before writing
  any byte. The exact-fill proof publishes 128 operations occupying all 511
  payload bytes, rejects the next operation with diagnostic 40, and then
  completes a clean one-operation transcript after reset;
- separate proofs reject a four-byte record atomically when only three payload
  bytes remain, and distinguish 255 accepted one-byte operations from the
  rejected 256th operation while 256 payload bytes are still free;
- the dispatcher validates the complete counted stream before copying any
  operands. Z80 proofs reject invalid ordinals, truncated records, and trailing
  bytes before any trace; TypeScript separately rejects supplied wrong event
  keys and counts; and
- the four-operation instrumented proof completes in 483 instructions and
  5,567 T-states and reports keys 0, 1, 4, and 14 through four `$DD` events,
  followed by exactly one `$DE` event. No trace event is emitted for a rejected
  transcript; and
- the complete serial suite passes 26 files and 268 tests, including all
  frozen-oracle, production proof, relocation, diagnostic, and artifact gates.

### R3 — Types, declarations, and static storage

Implement primitive and composite types, symbol lookup, constants, records,
nested arrays, bounded strings, open parameter views, static initializers,
program storage, routine signatures, and forward declarations. Introduce the
front-end action machine only for this coherent family; retain handwritten
escapes for irregular work.

Exit gate: all declaration/type/initializer tests and exact diagnostics match
the oracle, including all capacity boundaries. The complete migrated family,
including action programs and interpreter share, must be at least 20 percent
smaller than its baseline resident account before the action-machine design is
accepted.

R3 substrate checkpoint (Measured, in progress):

- primitive identities retain explicit width, signedness, and Boolean bits;
  eight owned composite identities index four-byte descriptors plus separate
  full-word extents;
- records append nominal identities, while arrays and bounded strings intern
  by descriptor and complete extent. A nested `u8[3][2]` proof constructs the
  inner row before the outer array and recovers the six-byte outer extent;
- `string[]` and `T[]` remain parameter-only identities. Their compact type
  encodings contain no address bits; dynamic capacity or count belongs to the
  activation representation introduced with routine parameters;
- the initial substrate's seven-byte symbol record retains a complete source
  pointer, name length, class, type metadata, and full-word payload. The later
  static-storage checkpoint adds an eighth, explicit storage-segment byte.
  Exact constants retain a negative-domain bit, so `-1` and `65535` remain
  distinct even though both payload words are `$FFFF`. The sixteenth committed
  symbol succeeds, the seventeenth fails, and a provisional symbol remains
  invisible until commit;
- nominal/structural identity, exact duplicate and capacity diagnostics,
  diagnostic recovery, and a retained name at `$9000` execute under strict
  register contracts; and
- the metadata engine is 324 code bytes. Reset integration adds six code bytes,
  making the current shipping rewrite 1,547 code + 778 immutable = 2,325 core
  bytes. Workspace is 1,049 bytes. These are intermediate R3 accounts, not the
  complete declaration-family measurement or the R3 exit gate.

The next R3 oracle matrix fixes the directory interaction before replacement
declaration code is written. Record names share the 16-entry ordinary namespace
with variables and constants. Parameters occupy that same scoped table only
after the complete header has been checked and the body opens; the retained
16-entry parameter directory accumulates across routine-scope rewinds. The four
non-main routine entries and five record-layout entries are separate bounded
directories. Executable oracle cases now prove 11 variables plus five record
names, eight dynamic types, twelve fields, and four zero-parameter routines in
one program; four routines with sixteen retained parameters in another; each
first overflow diagnostic; and the independent four/five suffix boundary.

R3 directory checkpoint (Measured):

- the replacement now owns separate five-entry record, twelve-entry field,
  four-entry non-main routine, sixteen-entry retained-parameter, and four-entry
  suffix directories. Their record widths are 2, 6, 8, 4, and 4 bytes;
- routine entry publishes remain provisional until commit. Active parameter
  symbols are rewound to the saved global prefix, while the retained spelling,
  type, parameter start, and count survive for calls and forward matching;
- parameter headers reject duplicates before appending to the retained
  directory. The retained formal parameters are published into the routine's
  scoped symbol table only when a body opens. A duplicate seventeenth parameter
  therefore reports 55, while a distinct seventeenth reports 85;
- record fields preserve full source pointers, one-byte types, and word
  offsets. The proof retains `$1234`, so a byte-truncated field layout cannot
  pass. Suffix entries likewise retain `$0100` counts and word source offsets;
- exact record/field/routine/parameter/suffix fills and first overflows,
  duplicate field/routine names, empty records, repeated open suffixes, and an
  open suffix following a concrete suffix execute through the nonreturning
  diagnostic path and clean reset; and
- directory code adds 412 bytes and the generalized control-prefix reset adds
  six bytes. The shipping rewrite is now 1,965 code + 778 immutable = 2,743
  core bytes, with 1,262 bytes of workspace. R3 declaration grammar, static
  initialization, signature reconciliation, and the complete 20-percent
  comparison remain ahead.

R3 namespace and routine-lifecycle checkpoint (Measured):

- one source-name authority now rejects collisions across active declarations,
  retained routines, `main`, and ten predefined names—six services and four
  error constants. Its immutable table stores complete spellings and never
  packs an address bit or assumes a compiler origin;
- routine lifecycle is split into signature publication, body opening, and
  scope closing. A direct signature is visible before recursion begins, while
  its parameter symbols remain live until the body closes;
- an abbreviated forward body reopens its existing routine entry without a
  second capacity charge. Retained parameter names and types are republished
  into a routine scope above the then-current global prefix, so a global
  introduced after the forward still causes the established duplicate-name
  diagnostic;
- opening a valid abbreviated forward body clears the incomplete flag in
  place. Ordinary missing and repeated completions retain diagnostics 57 and
  55; an absent or already completed forward `main` reports 57. Every forward
  main left incomplete at EOF reports 54; once main is defined, any incomplete
  ordinary forward also reports 54. Forward `main` remains outside the
  four-entry non-main routine directory;
- formal parameters remain invisible while their complete header is checked.
  They become active together only when a direct or forwarded body opens, so
  an earlier parameter cannot become the type or bound of a later parameter;
- active parameter payloads are per-routine activation offsets, not retained
  directory ordinals. Byte scalars advance by one byte; word scalars and
  concrete aliases by two; open strings by three; and open arrays by four. A
  separate calculation retains the caller-stack displacement, including the
  hidden word carried by every later open view;
- successful EOF requires a defined `main` before incomplete ordinary forwards
  are considered. Top-level declarations remain legal before and after the
  main body, as required by the compilation-unit grammar; the frozen compiler's
  main-last restriction is recorded as a conformance correction above;
- action proofs distinguish publication before body close, scope rewind,
  forward reopening, later-global collision, missing and repeated completion,
  incomplete-forward rejection, forward `main`, routine-capacity diagnostic
  precedence, provisional routine-name rejection, mixed-width parameter
  layout, predefined-parameter rejection, and `main` after four ordinary
  routines. Main activation layout is reset on both direct and forwarded body
  entry; and
- the namespace/lifecycle engine adds 573 code bytes and 157 immutable bytes.
  The shipping rewrite is 2,538 code + 935 immutable = 3,473 core bytes; the
  instrumented rewrite is 3,477 core bytes. Workspace is 1,271 bytes. The R3
  grammar/action programs, static initialization, and complete 20-percent
  comparison remain ahead.

R3 static-storage checkpoint (Measured):

- one 1,024-byte scratch image can hold a complete structured initializer, and
  one separate 1,024-byte retained image holds all emitted static bytes. The
  retained image keeps initialized program data as its prefix and aggregate
  constants as its suffix;
- a later initialized declaration shifts the constant suffix upward before it
  copies the new bytes. Constant-relative offsets therefore remain stable even
  when source declarations interleave constants and initialized variables. The
  append API returns each suffix-relative offset for the later declaration
  action to publish in its symbol;
- zero-initialized program data has an independent word counter and 1,024-byte
  boundary. It consumes no retained image bytes;
- every program symbol carries a separate storage-segment byte alongside its
  complete 16-bit segment-relative offset. Initialized offset zero and BSS
  offset zero are therefore distinct without stealing an address bit;
- initialized-data, read-only-data, BSS, and initializer-scratch overflow use
  diagnostics 81, 93, 81, and 77. Every complete end and the first rejected
  byte execute through strict proofs; a rejected append preserves counters,
  image bytes, and the byte immediately beyond the admitted region;
- zero-length internal appends are explicit no-ops, preventing a Z80 `LDIR`
  count of zero from becoming a 65,536-byte copy;
- declaration actions must preflight the destination segment before building
  an initializer. A source object that cannot fit therefore reports program
  data diagnostic 81 or read-only diagnostic 93; diagnostic 77 remains the
  independent internal scratch-capacity boundary; and
- the transaction layer and explicit storage-segment metadata add 335 code
  bytes and 2,073 workspace bytes. The shipping rewrite is 2,873 code + 935
  immutable = 3,808 core bytes; the instrumented rewrite is 3,812 core bytes.
  Workspace is 3,344 bytes. Static initializer grammar and type-directed
  initializer construction remain ahead.

R3 front-action substrate checkpoint (Measured):

- one cached-token layer gives generated actions stable `peek` and `take`
  operations without making the tokenizer own parser lookahead;
- a generated instruction authority currently defines `End`, token `Expect`,
  handwritten `Escape`, and immediate `Raise`, each with one fixed width. Its
  TypeScript decoder rejects invalid ordinals, truncated operands, missing
  `End`, and trailing bytes;
- handwritten escapes are selected by a dense byte but invoked through a
  generated dispatcher using complete 16-bit jumps. The first real escape
  resets initializer scratch; no origin or spare-address-bit assumption enters
  the format. Escapes do not recursively invoke the action machine, whose one
  retained cursor is deliberately non-reentrant;
- strict execution proofs distinguish successful token consumption plus escape
  return, an exact token-mismatch diagnostic, and an invalid action ordinal;
  and
- the parser/action interpreter adds 117 code bytes, its authority adds four
  immutable bytes, and lookahead/action state adds three workspace bytes. The
  shipping rewrite is 2,989 code + 939 immutable = 3,928 core bytes; the
  instrumented rewrite is 3,932 core bytes. Workspace is 3,347 bytes. Complete
  generated declaration programs and the type-directed initializer escape
  remain ahead.

R3/R4 constant-expression checkpoint (Measured):

- one precedence-climbing engine now evaluates the complete scalar constant
  expression operator set. It handles exact and typed integers, Boolean and
  character values, earlier scalar constants, grouping, conversions, prefix
  operators, signed promotion, typed wraparound, comparison, signed and
  unsigned division and modulo, and Boolean short circuit;
- operator source offsets survive recursive right operands. The proof locks
  the frozen compiler's distinct anchors for left-Boolean `xor`, right-side
  type failures, conversion failures, unary failures, range errors, division
  by zero, comparison chains, and unknown names;
- the published expression capacity counts pending binary contexts rather
  than parentheses. Sixteen nested pending additions succeed, and the
  seventeenth reports diagnostic 65 at its operator. A separate proof accepts
  all 255 delimiter levels and returns with the original stack pointer;
- strict execution covers 39 successful values and 19 diagnostics. The value
  proof completes in 375,465 instructions and 3,420,269 T-states; the
  diagnostic and recovery proof completes in 39,040 instructions and 398,668
  T-states;
- the expression engine is 1,589 code bytes and its fourteen-entry operator
  table is 28 immutable bytes. It adds 16 workspace bytes. At that checkpoint,
  the shipping replacement was 4,578 code + 967 immutable = 5,545 core bytes;
  the instrumented replacement was 5,549 core bytes, and workspace was 3,363
  bytes;
- AZM commit `ce284fde5fcd329ef4e984e2217661f690b66f9e` is the first toolchain
  checkpoint that proves the recursive, nonreturning paths while retaining
  compatibility with the frozen compiler proofs. CI uses that exact
  unpublished commit; and
- this checkpoint supplies the bound evaluator required by the shared source
  type parser. Runtime expression publication, postfix paths, calls, and the
  complete R4 size comparison remain ahead.

R3 shared source-type checkpoint (Measured):

- one 496-byte parser now handles all five scalar types, nominal record names,
  concrete and open bounded strings, fixed arrays, nested fixed arrays, and the
  parameter-only outer open-array form. It collects suffixes outermost-first
  and resolves them innermost-first, so `u8[3][2]`, `u8[][2]`, and
  `string[16][]` share one formation path;
- bounds use the proved constant-expression engine. Exact and unsigned typed
  bounds remain admitted, signed typed bounds retain diagnostic 60, negative
  exact bounds retain diagnostic 61 at the operand, zero retains diagnostic
  83, and bounded-string capacity 254 retains diagnostic 90;
- concrete object extent is still checked at type formation. The proof admits
  exactly 1,024 bytes and reports diagnostic 81 for 1,025 bytes at the closing
  bracket. It also distinguishes four accepted suffixes from the fifth, eight
  interned owned types from the ninth, and the historical placement anchors of
  `string[]` and `T[]`;
- strict execution covers 17 accepted formations in 35,188 instructions and
  319,406 T-states, 20 exact diagnostics in 45,373 instructions and 434,041
  T-states, and the eight/nine type-capacity boundary in 23,471 instructions
  and 211,469 T-states; and
- at that checkpoint, the shipping replacement was 5,074 code + 967 immutable
  = 6,041 core bytes. The instrumented replacement was 6,045 core bytes, and
  workspace was 3,364 bytes. That left 10,343 bytes beneath the 16,384-byte
  hard gate and 732 bytes in the 4,096-byte workspace account.

R3 generated scalar-declaration checkpoint (Measured):

- the front-action JSON now owns complete named programs as well as instruction
  and escape definitions. The generator validates every instruction name,
  operand count, escape selector, terminating `End`, and complete program
  width before emitting Z80 interpreter data and the TypeScript boundary view;
- the first two generated programs compile scalar `const` and `assert`
  declarations. Constant names occupy an invisible provisional symbol entry
  until the expression and newline are valid. Integer constants normalize to
  the exact domain, signed negative values retain the negative metadata bit,
  and Boolean remains the sole retained inferred scalar type;
- assertions retain the `assert` keyword position. False assertions report
  diagnostic 91 there, non-Boolean expressions report diagnostic 60 there,
  and expression diagnostics retain their own inner positions. Proofs also
  lock duplicate-name 55, expected-equals 135, division-by-zero 62,
  unpublished failed symbols, and clean compilation after failure;
- successful declarations execute in 21,370 instructions and 194,224 T-states.
  Five diagnostic and recovery cases execute in 16,820 instructions and
  161,193 T-states; and
- the action interpreter and dispatcher are now 147 code bytes, the scalar
  declaration escapes are 110 code bytes, and the action authority is 34
  immutable bytes, including 30 bytes for the two programs. The shipping
  replacement is 5,214 code + 997 immutable = 6,211 core bytes; the
  instrumented replacement is 6,215 core bytes. Workspace is 3,366 bytes,
  leaving 10,173 core bytes and 730 workspace bytes beneath their gates.

R3 generated program-variable checkpoint (Measured):

- two additional generated action programs compile uninitialised program
  variables and explicitly initialised scalar program variables. Both use the
  shared source-type parser and keep the provisional symbol unpublished until
  the complete source line has passed;
- uninitialised variables reserve their complete static extent in the BSS
  account. Scalar initialisers append one or two bytes to the initialised
  image and publish an explicit storage-segment tag plus a full 16-bit
  segment-relative offset. The proof distinguishes equal offsets in the two
  segments rather than deriving storage identity from any address bit;
- the scalar path supplies the declared type as the expected expression type,
  so `u8 = 255 + 1` uses byte-width modular arithmetic. It then applies the
  source compatibility rule without narrowing an already typed operand. The
  permanent proof covers exact negative adoption, all three implicit integer
  widenings (`u8` to `u16`, `u8` to `i16`, and `i8` to `i16`), Boolean
  initialisation, and complete emitted initial bytes;
- the expression engine retains the full source offset of the last
  value-producing atom. Declaration-time range failures therefore identify
  the numeric operand through unary prefixes and nested parentheses instead
  of attributing the failure to a grouping delimiter;
- exact diagnostics cover owning-position rejection of `T[]` and `string[]`,
  typed incompatibility, integer range at the offending operand,
  self-reference while the provisional symbol is invisible, and duplicate
  publication while preserving the first committed entry;
- eight successful variables execute in 35,095 instructions and 323,647
  T-states. Seven diagnostic cases execute in 28,595 instructions and 271,482
  T-states. The longer escape dispatcher also moves the retained scalar
  constant proof to 21,384 instructions and 194,498 T-states and its five-case
  diagnostic proof to 16,830 instructions and 161,597 T-states; and
- the action interpreter and dispatcher are 171 code bytes, the front
  declaration region is 304 code bytes, and the generated action authority is
  79 immutable bytes. The shipping replacement is 5,436 code + 1,042
  immutable = 6,478 core bytes; the instrumented replacement is 6,482 core
  bytes. Workspace is 3,368 bytes. The checkpoint therefore leaves 9,906 core
  bytes and 728 workspace bytes beneath their gates.

R3 generated record-declaration checkpoint (Measured):

- three generated action programs handle the record header, each field line,
  and the closing `end`. The record name occupies an unpublished shared-symbol
  entry until the closing newline passes. A field name is checked and retained
  before its type, preserving duplicate-before-invalid-type precedence;
- record fields use the shared type parser, reject both parameter-only open
  views at the frozen field position, and retain complete type and word-offset
  metadata. Field offsets and the current record extent are checked against
  the exact 1,024-byte object boundary before either field count advances;
- record descriptors are nominal even when layouts match. The proof constructs
  `Pair` and `Box`, reuses one field spelling in the two separate record scopes,
  nests the earlier record and a fixed array, and checks the exact three type
  extents, four field offsets, two record slices, and two published symbol
  identities;
- exact diagnostics cover an empty record, duplicate field before an unknown
  duplicate type, self-reference while the record name is still provisional,
  open array and open string fields, aggregate extent overflow, and duplicate
  record publication. Seven diagnostic cases execute in 55,933 instructions
  and 491,336 T-states; the accepted record pair executes in 21,248
  instructions and 189,685 T-states; and
- the action interpreter and dispatcher are 201 code bytes, the front
  declaration region is 441 code bytes, and the action authority is 118
  immutable bytes. The shipping replacement is 5,619 code + 1,081 immutable =
  6,700 core bytes; the instrumented replacement is 6,704 core bytes.
  Workspace remains 3,368 bytes, leaving 9,684 core bytes and 728 workspace
  bytes beneath their gates.

R3 recursive static-initializer checkpoint (Measured):

- one recursive, type-directed engine now constructs scalar leaves, nominal
  records, fixed arrays, nested arrays, and bounded strings for both aggregate
  constants and initialized aggregate program variables. It uses the same
  declared-type descriptors and constant-expression compatibility rules as
  the earlier declaration checkpoints rather than introducing an initializer-
  specific type system;
- bounded strings are retained in their complete physical representation:
  length byte, decoded payload, zero tail, and permanent terminator. The proof
  distinguishes ordinary bytes, `\0`, and `\xHH`, including an embedded zero;
- initialized data remains the static-image prefix and aggregate constants the
  suffix. Adding initialized objects after constants shifts the suffix without
  changing any constant-relative identity. Symbols retain explicit segment
  tags and complete word offsets;
- each destination is checked against the combined 1,024-byte static account
  before the first initializer token is interpreted. A rejected declaration
  therefore leaves symbols, segment lengths, and retained bytes unpublished,
  and diagnostics 81 or 93 take precedence over malformed initializer input;
- exact oracle diagnostics cover scalar types in aggregate-constant syntax,
  wrong delimiter shape, too few elements, overlong strings, and the fourth/
  fifth recursive composite boundary. Codes 60, 77, 78, 79, and 80 retain
  their exact source part and byte offset;
- the accepted mixed-object proof executes in 40,924 instructions and 372,366
  T-states. It checks a record array, an escaped `string[5]`, an initialized
  record, a nested signed-byte array, the complete 20-byte retained image, and
  all four segment-relative symbol payloads; and
- the action interpreter and its 18-target escape dispatcher are 219 code
  bytes. Nine generated programs occupy 166 immutable bytes. The front
  declaration region is 979 code bytes. The shipping replacement is 6,220
  code + 1,129 immutable = 7,349 core bytes; the instrumented replacement is
  7,353 core bytes. Workspace is 3,369 bytes, leaving 9,035 core bytes and 727
  workspace bytes beneath their gates.

R3 generated routine-header checkpoint (Measured):

- generated programs now frame direct headers, forward headers, abbreviated
  forward bodies, routine `end`, and compilation EOF. One iterative signature
  escape handles formal parameters and the optional result and `fails` suffix;
  it reuses the shared type parser and the already-proved directory lifecycle;
- parameter spellings remain invisible throughout the complete header. They
  are retained for duplicate checking, then published together only when a
  direct or abbreviated body opens. The execution proof distinguishes byte,
  word, three-byte open-string, and four-byte open-array activation offsets;
- ordinary forward signatures retain parameter names and types, results, and
  effects. Abbreviated completion republishes those exact bindings without a
  second routine charge. `main` remains outside the four-entry routine table,
  admits only its fixed empty data signature, and independently retains its
  `fails` effect;
- EOF first requires one completed `main`, then scans the ordinary directory
  for incomplete forwards. Exact diagnostics cover missing main, incomplete
  forward, duplicate parameter at the parameter name, parameter-header
  isolation, a parameterized main, and a result-bearing main;
- the accepted header proof executes in 37,212 instructions and 334,580
  T-states. It checks two retained routines, five retained parameters, the
  corresponding active activation offsets, forward completion, main flags,
  scope rewind, and successful EOF; and
- the 23-target action dispatcher is 249 code bytes, fourteen generated
  programs occupy 214 immutable bytes, and the front declaration region is
  1,298 code bytes. The shipping replacement is 6,569 code + 1,177 immutable
  = 7,746 core bytes; the instrumented replacement is 7,750 core bytes.
  Workspace remains 3,369 bytes, leaving 8,638 core bytes and 727 workspace
  bytes beneath their gates.

R3 generated default-local checkpoint (Measured):

- one generated action program now parses and publishes default-initialized
  scalar locals. The admitted types are exactly `u8`, `u16`, `i8`, `i16`, and
  `boolean`; records, arrays, bounded strings, and open views remain invalid
  local types;
- a provisional local retains its complete source spelling, exact type,
  activation-storage tag, and byte offset. Publication occurs only after the
  complete declaration and newline have succeeded. Routine close rewinds the
  local bindings with the rest of the routine scope;
- every default declaration emits one width-specific declaration record, one
  zero `Literal16`, and one width-specific store record. Five declarations
  produce fifteen checked operations and 35 transcript bytes. Boolean and
  byte integers consume one activation byte; word integers consume two;
- the mixed-parameter proof starts locals after a `u16` parameter and a
  three-byte `string[]` carrier. It locks local offsets 5 and 6 and the final
  eight-byte activation prefix, rather than assuming that local storage begins
  at zero;
- exact diagnostics retain the frozen distinctions: a concrete aggregate
  local reports 59 at the type token, an open-array suffix reports 129 at its
  opening bracket, a duplicate reports 55 at the second name, and the
  seventeenth active binding reports 56 at its name;
- the five-type proof executes in 23,559 instructions and 212,494 T-states.
  The mixed-parameter proof executes in 22,933 instructions and 206,498
  T-states; and
- the 27-target action dispatcher is 273 code bytes, fifteen generated
  programs occupy 235 immutable bytes, and the front declaration region is
  1,482 code bytes. The shipping replacement is 6,777 code + 1,198 immutable
  = 7,975 core bytes; the instrumented replacement is 7,979 core bytes.
  Workspace remains 3,369 bytes, leaving 8,409 core bytes and 727 workspace
  bytes beneath their gates.

Runtime-expression initializers are deliberately not approximated with a
constant-only shortcut. They are the first consumer of R4's runtime expression
mode, including ordinary expressions and direct failable calls followed by
`else fail`.

R4 runtime-atom checkpoint (Measured):

- the expression engine now has separate constant and runtime modes. Runtime
  mode accepts one primary atom and emits its value while retaining the same
  exact type and known-value metadata used by constant folding;
- admitted atoms cover integer and character literals, Boolean literals,
  named constants, parameters, earlier locals, initialized program objects,
  and BSS program objects. A declaration is still provisional while its
  initializer is parsed, so self-reference reports unknown name 57 at the
  name rather than observing a half-published binding;
- initialized and BSS storage use distinct semantic operations with complete
  16-bit segment-relative offsets. This preserves the explicit storage tag
  introduced in R3 and does not donate an address bit or assume any compiler
  or target origin;
- scalar compatibility is checked before publication. Exact values are range
  checked, same-type values need no conversion record, `u8` widens directly
  to `u16` or `i16`, and dynamic `i8` to `i16` emits the declared integer
  conversion record;
- the first consumer is deliberately named `LocalInitializedAtom`. It does
  not claim complete expression syntax: binary reduction, Boolean
  short-circuiting, postfix paths, calls, and failure consumption remain R4
  work;
- the accepted proof emits 22 operations and executes in 63,459 compiler
  instructions and 574,089 T-states. Exact failures retain type mismatch 60
  at offset 31, self-reference 57 at offset 25, and a trailing token 129 at
  offset 27; and
- the authority now contains 101 operations. The 29-target action dispatcher
  is 285 code bytes, sixteen generated programs occupy 261 immutable bytes,
  the expression region is 1,904 code bytes, and the declaration region is
  1,510 code bytes. The shipping replacement is 7,128 code + 1,236 immutable
  = 8,364 core bytes; the instrumented replacement is 8,368 core bytes.
  Workspace is 3,371 bytes, leaving 8,020 core bytes and 725 workspace bytes
  beneath their gates.

### R4 — Expressions, paths, and calls

Implement the common primary, precedence, postfix, type-resolution, folding,
conversion, and call engines. Cover constant and runtime modes, exact literals,
all four integer types, Boolean short-circuiting, concrete and open aggregate
paths, nested calls, recursion, results, and left-to-right evaluation.

R4 scalar-precedence checkpoint (Measured):

- one precedence-climbing engine now serves both constant and runtime scalar
  expressions. The runtime path covers prefix `+`, prefix `-`, `not`, all
  arithmetic and bitwise binary operators, all six comparisons, parentheses,
  explicit scalar conversions, and the complete precedence and associativity
  table;
- mixed `i8` pairs publish `PromoteI8Pair` with an explicit left/right mode
  before the selected width-specific operation. The proof distinguishes both
  directions, the `u8`/`i8` common `i16` case, and the forbidden `u16`/`i16`
  pair;
- unsigned division and modulo retain their operator source offset in the
  width-specific record. Signed division and modulo retain the same full
  offset plus the byte/word, quotient/remainder mode. A statically zero divisor
  reports 62 at the frozen operand position;
- Boolean `and` and `or` publish begin/end records around the right operand.
  Compile-time fault suppression is enabled only when the left carrier is
  known, so a dynamic false-looking placeholder cannot suppress a real fault.
  The proof includes a zero divisor in a statically skipped arm and exact
  begin/end ordering;
- the accepted proof publishes 79 operations spanning loads, literals,
  promotions, unary reductions, arithmetic, integer logic, comparisons,
  Boolean short-circuiting, and stores. Its complete transcript is checked
  byte for byte and it executes in 126,748 compiler instructions and
  1,136,185 T-states;
- runtime-specific rejected cases lock division-zero 62 at offset 29,
  Boolean `xor` mismatch 60 at offset 52, comparison chaining 64 at offset 45,
  and mixed word signedness 60 at offset 51; and
- the expression region is 2,380 code bytes. The shipping replacement is
  7,604 code + 1,236 immutable = 8,840 core bytes; the instrumented
  replacement is 8,844 core bytes. Workspace is 3,374 bytes, leaving 7,544
  core bytes and 722 workspace bytes beneath their gates.

R4 postfix-path checkpoint (Measured):

- one iterative, type-directed engine now serves record-field selection,
  concrete and open array indexing, bounded and open string indexing, and the
  `length`/`capacity` properties. It accepts a complete aggregate carrier and
  delays the indirect scalar load until the path reaches its leaf;
- roots distinguish BSS/program, read-only aggregate-constant, concrete
  parameter, open-array parameter, and open-string parameter carriers without
  encoding storage or placement in an address bit. Open-view counts remain
  explicit activation offsets and every program/read-only offset remains a
  complete word;
- recursive index expressions preserve the outer path on the hardware stack.
  A dynamic signed index publishes the bounds-mode integer conversion with its
  exact value position, while fixed-array selection retains the full count,
  element extent, and bracket source offset;
- the accepted proof publishes and checks 61 complete operations byte for
  byte. It covers nested records, nested fixed arrays, bounded strings, both
  open views, concrete aggregate parameters, read-only constants, BSS roots,
  scalar materialisation, and left-to-right binary composition. It executes
  in 108,264 compiler instructions and 962,787 T-states;
- exact rejected cases cover fixed-string `capacity` (60), an out-of-range
  fixed index (61), a Boolean index (60), a negative exact index (61), and the
  conformance-corrected missing record field (57). Each proof checks part and
  byte offset before publishing its status; and
- the path state overlays dead left-reduction slots and adds no workspace.
  The expression region is 3,306 code bytes. The shipping replacement is
  8,530 code + 1,250 immutable = 9,780 core bytes; the instrumented replacement
  is 9,784 core bytes. Workspace remains 3,374 bytes, leaving 6,604 core bytes
  and 722 workspace bytes beneath their gates.

R4 call and immediate-failure checkpoint (Measured):

- one bounded four-frame call engine now handles retained source routines and
  all six predefined services. It parses scalar, exact aggregate, open-string,
  and open-array actuals left to right and publishes complete source offsets,
  selectors, argument-word counts, result types, effects, and call modes;
- open arguments preserve the concrete bounded-string capacity or fixed-array
  count. Forwarded open views retain their hidden activation offsets. A
  separate transcript proof passes concrete string and array routine results
  directly to open formals, so transient aliases do not rely on a wildcard
  type or an address tag;
- failable calls remain pending until the containing local initializer consumes
  exactly `else fail`. Ordinary failable routines and failable `main` publish
  distinct propagation modes. Infallible calls reject a stray consumer, and a
  failable call nested in another call, grouping, conversion, unary operation,
  index, or binary expression reports diagnostic 87 at the frozen context
  anchor;
- four nested source-call frames succeed and release the complete compiler-side
  call state. The fifth reports diagnostic 65 at the innermost routine name.
  Exact call diagnostics also cover missing and excess actuals, a wrong scalar
  type, and a literal passed directly to an open-string formal. A separate
  current-routine proof publishes an exact recursive call transcript in 14,393
  instructions and 130,607 T-states;
- the main accepted call proof publishes and checks 30 operations byte for byte
  in 98,362 compiler instructions and 882,722 T-states. The main-mode proof
  takes 12,287 instructions and 111,600 T-states; the four-frame proof takes
  22,482 instructions and 201,658 T-states; and the transient-open-view proof
  takes 39,861 instructions and 360,748 T-states;
- source-forward lifecycle flags are masked to the target-visible failure bit
  before transcript publication. The proof therefore distinguishes an
  internal incomplete-forward marker from the published call effect; and
- the call work adds 940 bytes to the expression region, nine bytes to the
  declaration region, six immutable service-signature bytes, and 40 workspace
  bytes. The shipping replacement is 9,492 code + 1,256 immutable = 10,748
  core bytes; the instrumented replacement is 10,752 core bytes. Workspace is
  3,414 bytes, leaving 5,636 core bytes and 682 workspace bytes beneath their
  gates.

R4 architectural stop-rule review (Measured):

- AZM source mappings put the active frozen typed-expression parser at 2,525
  bytes. The parameter-offset, postfix-path, source/service-call, and primary
  extension in `aggregate-call-parser.asm` contributes another 1,572 bytes.
  The comparable frozen family is therefore 4,097 bytes. Structured control
  is mapped separately and is not credited to this comparison;
- the replacement expression/path/call region is 4,246 bytes: 149 bytes, or
  3.6 percent, larger than the comparable frozen family. It therefore does
  not meet the provisional 25 percent local-saving threshold. The earlier
  5,457-byte estimate included structured control and was not an
  apples-to-apples R4 baseline;
- this result triggers the required design review. The 4,246-byte R4
  implementation remains the proved semantic reference, not the accepted
  size architecture. R4.1 must replace repeated postfix, call-frame, and
  integer-resolution control code with compact data-directed machinery before
  the replacement is declared locally smaller; and
- R5 may establish independent statement semantics against that reference.
  Production cutover still requires the combined front end and backend to
  meet the final core gate. No placement assumption, address-bit
  donation, or encoded-instruction data is an admissible way to close the
  difference.

Exit gate: accepted source, exact diagnostics, transcript intent, target
behaviour, traps, and stack restoration match. The complete expression/path/
call region must be at least 25 percent smaller than its measured baseline
counterpart. A result below that threshold triggers a design review because
the current compiler already uses precedence climbing.

### R5 — Statements, control, and recoverable failure

Complete routine bodies, assignment, calls, `if`/`elseif`/`else`, `while`, all
counted loops, `return`, `fail`, `exit`, `continue`, `else fail`, and `handle`.
Use front-end action programs for regular sequencing and handwritten escapes
for stateful control-frame transitions.

R5 scalar-assignment checkpoint (Measured):

- one generated action program and three origin-independent escapes parse,
  validate, and publish scalar assignments to initialized program storage,
  BSS, routine locals, and parameters. The target retains an explicit class,
  storage segment, scalar type, and full payload; no address bit is metadata;
- `StoreBssU8` and `StoreBss16` are now distinct semantic operations, so equal
  initialized/BSS offsets cannot select the wrong target segment. The accepted
  proof checks thirteen operation records byte for byte, including all four
  destination classes, including both byte- and word-width activation stores,
  in 39,611 instructions and 353,876 T-states;
- exact frozen diagnostics cover an unknown target (57 at byte 11), a constant
  target (60 at byte 23), and an incompatible value (60 at byte 31). Store
  publication occurs only after expression, failure-consumer, and newline
  validation have all succeeded; and
- the statement region is 174 code bytes. The operation authority contains
  103 operations, the action authority contains 32 escapes and 277 immutable
  bytes, and its interpreter/dispatch code is 303 bytes. The shipping
  replacement is 9,684 code + 1,284 immutable = 10,968 core bytes; the
  instrumented replacement is 10,972 core bytes. Workspace remains 3,414
  bytes, leaving 5,416 core bytes and 682 workspace bytes beneath their gates.

Exit gate: flow analysis, exact error positions, balanced construct contexts,
loop overshoot, signed counters, failure propagation/handling, empty bodies,
and post-failure reset match the oracle.

### R6 — Scalar backend recipes

Implement the recipe engine and migrate a representative set of at least 24
scalar semantic operations: literals, loads, stores, unary operations, binary
operations at both widths, comparisons, conversions, Boolean fixups, and
runtime calls.

The prototype is retained only if interpreter code plus recipes plus escapes
is at least 20 percent smaller than the replaced handlers. It must generate
byte-identical target code and preserve every output-failure boundary. A failed
prototype is recorded and removed rather than extended on hope.

### R7 — Complete backend and target output

Add routines, activations, aggregate aliases, region checks, indexes, copies,
open views, structured control, failure, traps, runtime linking, flat and
banked target layout, NOBJ image/patch/map/commit production, and conditional
D8 image tracing.

Exit gate: normal and instrumented replacement compilers produce identical
target artifacts; replacement and oracle artifacts are byte-identical for the
complete oracle corpus; PATCH attribution, bank identity, abort atomicity, and
post-failure recovery all pass.

### R8 — Complete conformance and cutover

Run the complete current test suite against the replacement, then run a new
adversarial correctness review. Repair every important finding. Perform a
focused size pass over the replacement's own repetition, followed by a separate
correctness-and-size review and full gate repetition.

Cutover requires:

- every Nucleus 0.1 accepted and rejected case;
- exact diagnostic code, part, offset, line, and byte column;
- all capacity exact-fill and first-overflow cases;
- byte-identical runtime selection, generated programs, NOBJ, HEX,
  materialized flat/banked images, and D8 output where the contracts require
  identity;
- normal/debug target identity;
- strict register and stack contracts;
- four-origin relocation and no address-derived metadata;
- compiler core at or below 16,384 bytes, with 14,336 bytes the project target;
- workspace at or below 4,096 bytes;
- generated-image and symbol-map synchronization;
- full tests, typecheck, formatting, and diff checks; and
- documentation updated from measured final accounts.

After cutover, remove the old compiler from the production composition and npm
payload. Historical proof sources may remain only when they still provide
unique executable evidence; they must not keep old compiler code resident.

## Prototype decisions and stop rules

The rewrite uses measurements to decide architecture before broad migration:

- A front-end action machine must save at least 20 percent across a complete
  migrated family, including interpreter and data.
- The expression/path/call redesign must save at least 25 percent across the
  complete family because precedence climbing alone is already present.
- A backend recipe machine must save at least 20 percent across the first 24
  representative operations, including recipe data and escape machinery.
- A table or bytecode conversion that moves bytes from code into immutable data
  without reducing compiler core is rejected.
- A change that assumes an origin, donates pointer bits, narrows an address, or
  depends on table placement is rejected without further size discussion.
- A change that hides compiler-executed instructions in `.db` or `.dw` is
  rejected. A legal instruction missing from AZM becomes an AZM issue and an
  explicit project decision.
- A compiler-internal rewrite that changes target artifacts is rejected until
  the discrepancy is explained and approved as a separate runtime/backend
  contract change.
- A milestone that cannot reproduce exact diagnostics or failure atomicity is
  repaired before size work continues.

The 14 KiB target is a design goal, not permission to claim unmeasured savings.
If the complete conforming replacement finishes between 14,337 and 16,384
bytes, it remains a valid replacement and receives a second architecture
review. If it exceeds 16,384 bytes, it cannot replace the production compiler.

## Designs rejected at the outset

- **Address-bit tagging.** Compiler placement is deployment policy across the
  complete 64 KiB address space.
- **Two-bit universal operand shapes.** Current operations require more shapes;
  the descriptor must state the complete record width.
- **Deleting the transcript for direct parse-time emission.** The current
  atomic parse/generate boundary, banked layout, and tentative D8 publication
  justify the bounded intermediate form.
- **Changing the runtime during compiler parity.** Runtime movement obscures
  artifact comparison and changes a separate account.
- **A single universal compiler bytecode in the first rewrite.** Separate
  front-end and backend machines keep state, verification, and size attribution
  comprehensible.
- **An AST, heap, unbounded buffers, or source pointers as language values.**
  These mechanisms contradict the small-system and source-safety boundary.
- **Copying old routines into the new tree and compressing them later.** The
  old compiler is an oracle; the rewrite is the opportunity to remove its
  construction history from the architecture.

## Next implementation move

R0, R1, and R2 are complete. R3 has delivered the type, symbol, directory,
routine-lifecycle, static-storage, front-action, scalar constant-expression,
shared source-type, record, and recursive static-initializer substrates.
Generated programs now cover scalar and aggregate constants, assertions,
uninitialised variables, scalar- and aggregate-initialised variables, records,
fields, direct and forward routine headers, formal parameters, results,
failure clauses, `main`, default scalar locals, routine close, and EOF
completeness. R4 now has runtime atoms, complete scalar precedence reduction,
mixed signed promotion, conversions, comparisons, Boolean short-circuiting,
explicit expression-initialized locals, the shared postfix path engine, typed
source/service calls, concrete and forwarded open arguments, nested calls, and
immediate `else fail` propagation. The next work is the R4 size comparison and
focused compression review before R5 begins statement and control parsing. The
replacement remains test-selected until the complete cutover gate passes.
