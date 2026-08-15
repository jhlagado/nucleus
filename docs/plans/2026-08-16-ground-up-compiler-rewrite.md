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

The rewrite must compile every program accepted by the baseline, reject every
program rejected by the baseline, report the same diagnostic code and exact
source position, and generate the same target artifacts unless a separately
approved target-runtime revision changes an artifact contract. Internal token,
type, action, and semantic-operation ordinals may change because none is a
published format.

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

## Measured baseline

These measurements were reproduced from the normal generated compiler image
at the tagged baseline. They supersede the older 15,290-byte table in the
review brief.

| Resident region | Bytes | Status |
| --- | ---: | --- |
| source adapter | 141 | Measured |
| tokenizer | 869 | Measured |
| semantic sink | 58 | Measured |
| symbols | 106 | Measured |
| complete parser region | 9,794 | Measured |
| backend and target-output region | 5,302 | Measured |
| compiler code | 16,270 | Measured |
| immutable compiler data | 410 | Measured |
| compiler core | 16,680 | Measured |
| excess over 16 KiB | 296 | Measured |
| peak compiler workspace | 3,639 | Measured |
| selected proof runtime | 899 | Measured |
| target-enabled proof instructions | 1,025,324 | Measured |
| target-enabled proof T-states | 9,980,322 | Measured |

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
escape instructions. Every escape directory stores a full 16-bit address.
The rewrite does not force difficult semantics into a bytecode merely to make
the source look uniform.

### Source and token layer

The source adapter retains the current ordered multipart contract and exact
position state. The tokenizer becomes one table-directed scanner with four
handwritten families: names and keywords, integers, quoted literals, and
punctuation. Newline synthesis, CRLF handling, comment termination, escape
rules, literal limits, and diagnostic anchors remain exactly as specified.

Keyword descriptors use ordinary data offsets or full addresses. High-bit
termination may mark characters because keyword bytes are character data; it
must not reduce a code or source address. Packing is accepted only after the
complete scanner plus table is smaller than the straightforward form.

The tokenizer publishes a fixed token record containing the token ordinal,
token-start source identity and offset, and the bounded payload state required
by names and literals. Parser lookahead stores one such record. No later phase
reconstructs a diagnostic position from a changed cursor.

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

The rewrite uses one symbol entry format with class-specific payload
directories only where a complete measurement proves that split entries are
smaller. Names continue to refer to retained source bytes. Forward routine
signatures, activation layout, and aggregate carriers remain bounded and
explicit.

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
checked descriptor table defines every operation:

- complete record width;
- operand count and operand widths;
- recipe or handwritten backend class;
- stack-value effect;
- source-attribution eligibility; and
- debugging trace behaviour.

The descriptor uses ordinary bytes and full addresses or directory indices.
It does not assume that four operand shapes cover the language. The dispatcher
validates the record boundary before reading any operand and prefetches the
declared fields into a fixed operand area. Handlers never advance the live
semantic cursor themselves.

The grammar/action generator and D8 decoder consume the same generated
operation-format authority. A build fails if a producer, dispatcher, recipe,
or D8 width disagrees. The transcript keeps its current published capacity
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
the diagnostic code, source part, byte offset, line, and byte column before it
restores the armed compiler entry stack. Parsing and generation use separate
armed continuations, so generation failure performs exactly one target-output
abort while parse failure never consults post-parse overlay state.

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

| Replacement region | Allocation | Status |
| --- | ---: | --- |
| source adapter and tokenizer code | 850 | Projected |
| symbol and type-engine code | 850 | Projected |
| grammar and action-machine code | 2,200 | Projected |
| expression, postfix, call, and folding code | 2,400 | Projected |
| transcript, diagnostics, and shared compiler control | 600 | Projected |
| target layout and NOBJ production code | 1,400 | Projected |
| backend recipe engine and handwritten backend code | 2,400 | Projected |
| all immutable keywords, grammar, operation, and recipe data | 2,200 | Projected |
| allocated compiler core | 12,900 | Projected |
| unallocated margin below 14 KiB | 1,436 | Projected |

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

### R1 — Replacement shell and source contract

Create the new composition, workspace map, public entry, diagnostic unwind,
source adapter, token record, and tokenizer. The test host can select the new
image explicitly. No old implementation source is included.

Prove every token, token payload, source position, source-part boundary,
newline form, comment, literal limit, malformed escape, and lexical capacity
against the oracle.

Exit gate: the replacement token/diagnostic layer is origin-independent, strict
AZM is green, and its complete source/token account is at most 1,100 core bytes.

### R2 — Generated operation authority

Define the semantic operation source, generator, producer helpers, dispatcher
descriptors, D8 widths, and recipe boundaries. Implement transcript reset,
append, exact fill, first overflow, validation, semantic trace start, and the
single success end event.

Exit gate: deliberate width, key, count, and boundary corruptions all prevent
generation or D8 publication; recovery compilation starts from clean state.

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

### R4 — Expressions, paths, and calls

Implement the common primary, precedence, postfix, type-resolution, folding,
conversion, and call engines. Cover constant and runtime modes, exact literals,
all four integer types, Boolean short-circuiting, concrete and open aggregate
paths, nested calls, recursion, results, and left-to-right evaluation.

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

## First implementation move

R0 comes next. Add the oracle manifest and a test-only compiler-image selector,
but no replacement compiler logic. That checkpoint makes every later rewrite
stage compare against one frozen, reproducible baseline and prevents a new
internal format from quietly changing language or target behaviour.
