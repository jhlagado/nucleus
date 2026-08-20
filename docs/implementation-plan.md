# Nucleus 0.1 Implementation Plan

## Status and authority

This document records the construction order, measurement method, and readiness
gates for the first Nucleus compiler and Z80 execution system. It is
non-normative. The Nucleus language specification governs source syntax and
semantics. The [Nucleus Target System Specification](target-system-specification.md)
governs target profiles, startup, entry, and banking. The
[Nucleus Z80 Runtime and Backend Contract](z80-runtime-contract.md) governs
packed representation, generated-code integrity, services, traps, and runtime
obligations. The [Nucleus Object Stream Format](nucleus-object-format.md)
governs binary output framing, image and patch records, integrity, and commit.
When this plan conflicts with an authority, the plan must be corrected.

The compiler and target runtime are handwritten Z80 assembly. Direct Z80 code
generation is the sole active implementation path. The compiler's checked
semantic-operation stream remains an internal boundary between analysis and
emission; it is not a portable bytecode product. Host tests assemble and run the
generated Z80 directly, then inspect output, state, diagnostics, and traps
against the source-level expectation.

## Project objective

The first implementation must demonstrate that the complete Nucleus 0.1
language can be compiled safely on a small Z80 system. The compiler core and all
immutable data required during compilation must fit in one 16 KiB bank. Compiler
workspace, generated output, the selected target runtime, and execution storage
have separate bounded accounts.

The implementation must preserve one language. A missed size target triggers an
architecture investigation supported by measurements; it does not silently
remove syntax, weaken diagnostics, or create a smaller standard profile.

The 16 KiB compiler-core gate is the acceptance limit for the first
implementation, not a language-conformance rule. Construction proceeds from
measured components rather than from an unmeasured top-down estimate. Every
module reports its code and immutable-data contribution when it first runs, and
the running total is updated before work broadens. During early construction, a
projected total in the 12–13 KiB range triggered a representation and
control-flow review because the remaining integration margin was small. The
final current census appears below.

Compact handwritten assembly may use shared tails, jump tables, overlays,
specialized entry points, and other byte-saving control flow that would be
undesirable in ordinary application code. Register contracts and executable
proofs must still make every entry, exit, clobber, and failure path explicit.
Implementers select such transformations from measured complete paths, not
from source-line count or stylistic preference. A proposed language cut remains
a redesign and requires evidence that implementation economies cannot recover
the required margin.

The compiler image is origin-independent. The `$0000` address in the current
proof memory map is only a host measurement choice; deployment policy may place
the compiler anywhere its complete image fits, including `$0100` under CP/M or
`$8000` on a TEC-1 configuration. All compiler pointers remain full-width
16-bit addresses. Pointer-bit tagging, address truncation, and metadata schemes
that depend on the current origin are prohibited. A dispatcher-prefetch
prototype that marked handlers with address bit 15 was rejected and restored
before commit because it would have silently restricted the compiler to the
low 32 KiB. Future relocation-sensitive compression must use address-independent
metadata and pass the low/high-origin relocation proof.

## Settled implementation boundary

The first implementation follows these directions unless the project owner
explicitly reopens them:

- source is consumed as an ordered multipart byte stream;
- compilation reads source once and consumes the checked semantic transcript
  once;
- output is one append-only object stream: target-addressed image records,
  resolved replacement-byte patch records, one map, and a terminal commit;
- the compiler performs no per-bank emission replay, output seek, or complete
  bank-image rollback;
- the compiler builds no abstract syntax tree;
- declarations precede use, with complete forward routine signatures as the
  sole exception;
- a packed LL(1) interpreter parses declaration and statement structure, with
  precedence expressions and bounded semantic decisions retained as explicit
  external islands;
- one precedence-driven loop parses binary expressions;
- the parser completes a call before classifying `else fail` consumption;
- all routine-local variables are scalar;
- all owned aggregate storage belongs to top-level program variables,
  aggregate constants, and their inline subobjects;
- concrete aggregate parameters and results use typed, opaque address carriers;
  `string[]` parameters additionally retain the argument's actual capacity;
- aggregate assignment copies only the exact concrete representation;
- the compiler emits checked semantic operations into a direct-Z80 backend and
  initially uses fixed templates without register allocation or whole-program
  optimization;
- each working increment then receives a proof-preserving size pass that may
  share tails and prefixes, exploit fall-through and live flags, or replace
  repeated inline sequences with calls when the measured byte trade is
  favorable;
- every bounded compiler resource has a capacity diagnostic; and
- every runtime-dependent safety condition has the specified trap behavior.

These rules do not expose pointers in the source language. An address carrier is
compiler-managed state with an exact retained referent type, not a source value.

## Existing evidence

The repository already contains executable foundations for the implementation:

| Evidence                         | Present role                                                                                      |
| -------------------------------- | ------------------------------------------------------------------------------------------------- |
| `src/grammar-analysis.ts`        | Checks the collected grammar for recursion, reachability, productivity, and predictive conflicts. |
| `src/type-metadata.ts`           | Exercises bounded representations for every admitted source type.                                 |
| `src/runtime-contract.ts`        | Records the machine-readable direct-runtime trap and service assignments.                         |
| `asm/vertical-slice/*-z80-*.asm` | Implements and proves the active direct-Z80 compiler slices.                                      |
| `test/`                          | Checks grammar, type metadata, runtime-contract synchronization, and measured direct-Z80 proofs.  |

This host-side evidence is executable design evidence. It does not count toward
the Z80 compiler or target-runtime budget, and it cannot override either
authority.

## Initial target configuration

Bring-up uses the flat 64 KiB abstraction permitted by the specifications, with
AZM and the Debug80 runtime providing the first execution environment. The
compiler core is still linked and measured as one self-contained 16 KiB bank.
This configuration exposes ordinary Z80 addressing while the implementation
measures the compiler, target runtime, and workspace independently.

Physical proof begins on constrained Z80 hardware. A TEC-1 adapter is an early
adapter rather than an architectural target; CP/M and other Z80 environments
use the same compiler and service boundaries. Target adapters must not add
source syntax or enter the compiler-core account unless compilation requires
them to be resident.

Before Stage 2 begins, the implementation records a concrete memory map for:

- compiler core and immutable tables;
- compiler workspace;
- source and diagnostic adapter state;
- append-only generated-object output or bulk storage;
- Z80 runtime helpers and service adapters;
- generated Z80 code and program data;
- activation storage; and
- service buffers.

Before Stage 3 begins, a small adapter contract must carry ordered source-part
events, source bytes, generated output bytes, and diagnostics. The first adapter
may use host callbacks or bulk-storage fixtures, provided it supplies the
compiler core through the same bounded event interface that a Z80 target
adapter will implement.

## Measurement accounts

Every implementation report keeps these accounts separate:

| Account            | Recorded quantity                                                                                                       |
| ------------------ | ----------------------------------------------------------------------------------------------------------------------- |
| Compiler core      | Z80 code plus immutable tables and constants required while compiling.                                                  |
| Compiler workspace | Peak simultaneously live writable tokenizer, parser, symbol, type, fixup, diagnostic, and emission state.               |
| Generated output   | Append-only Z80 image records, resolved patch records, map, commit, and required startup bytes.                         |
| Z80 runtime        | Shared checks, arithmetic helpers, service adapters, call machinery, and fixed writable runtime state.                  |
| Execution storage  | Program data, completion carriers, activation storage, generated code, and service buffers.                             |
| Execution cost     | Executed Z80 instructions and T-states for named programs and input conditions.                                         |
| Complete system    | Compiler plus the selected target runtime and one named generated program, with mutually exclusive paths kept separate. |

A report labels each number **Measured**, **Projected**, or **Hypothesis**.
Measured entries name the assembly and harness. Projected entries give their
measured basis and arithmetic. Unknown values remain open.

## Backend decision rule

Direct Z80 is the implementation path. New vertical slices implement, measure,
and optimize that path only.

The front end still produces checked semantic operations as it parses and
retains no abstract syntax tree or parser-specific program record. The current
proof sink records a bounded transcript and the Z80 backend consumes it only
after parsing succeeds. This preserves diagnostic and output atomicity. The
transcript is an internal compiler representation whose ordinals and layout may
change whenever a smaller proven representation is found.

An earlier experiment emitted Z80 code while the parser remained active. It
needed more compiler code and more simultaneously live workspace, so the
post-parse transcript remains the smaller measured arrangement. Later slices
must remeasure it when a general statement or expression dispatcher can replace
enough fixed encoder code to pay for another organization.

Host verification now has two independent layers. AZM checks the compiler and
generated-program register contracts; Debug80 runs the emitted Z80 and exposes
its output, state, trap record, and instruction count. A host-side source
expectation checks those observations directly.

## Current readiness baseline

Stages 2 through 8 remain executable historical evidence for the direct-Z80
compiler increments. Stage 9 compiles and executes the complete Chapter 18
corpus, including ordered multipart input, and locks the final resource
accounts. Each completed increment has a correctness baseline and a measured
compression pass. The resident Stage 9 size is the current implementation
plateau.

| Area             | Current evidence                                                                                                                                         | Continuing duty                                                                |
| ---------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| Specifications   | The language, target, NOBJ, runtime, Host API, and D8 authorities describe the implemented system.                                                       | Review each affected authority before changing an implemented contract.        |
| Grammar          | The production grammar and packed LL(1) tables regenerate exactly; external expression and name-statement islands have focused tests.                    | Preserve the grammar and diagnostics unless a normative language change lands. |
| Type metadata    | Interned ordinals name four-byte structural descriptors; alias-category separation and exhaustion have executable tests.                                 | Remeasure any alternative against the complete compiler.                       |
| Source corpus    | Every Chapter 18 program is byte-locked and has a direct output, state, diagnostic, or trap proof; broader focused tests cover the remaining constructs. | Add a discriminator whenever a language or implementation change needs one.    |
| Z80 evidence     | The complete corpus runs through the direct compiler with the final measured accounts below.                                                             | Preserve the byte, layout, register, stack, size, and timing gates.            |
| Host integration | Host API 1, CLI, flat and banked NOBJ, HEX, D8, and Debug80's flat launch path have end-to-end tests.                                                    | Keep source identity, target layout, and publication failure behavior exact.   |

`npx vitest run test/proof-harness.test.ts --reporter=verbose` from the
standalone Nucleus repository is the focused
assembly-proof gate. The broader Nucleus package suite runs only after that
gate passes. AZM and Debug80 dependencies are rebuilt only when their outputs
are absent or stale; an ordinary Nucleus change does not trigger a monorepo-wide
rebuild.

## AZM and Debug80 proof architecture

The first Z80 implementation follows the proof-driven approach established in
TECM8, with a smaller and more regular harness. A proof is an AZM source program
that includes or links the production assembly under test, runs at a declared
address in a declared memory map, and exposes a small set of named observations.
The host assembles the proof, loads it into Debug80, executes it with a finite
instruction or cycle limit, and compares those observations with the host
expectation for that source program.

Use three proof scales:

1. **Module proofs** exercise one tokenizer, parser, emitter, or runtime-helper
   boundary with minimal machine state.
2. **Boundary proofs** exercise a complete contract between two components,
   such as compiler emission followed by generated-code execution, or service
   invocation followed by completion handling.
3. **Milestone proofs** execute one visible end-to-end program for the current
   build stage. They do not replace the smaller proofs.

Every production routine has an AZM register contract. Calls into code not
assembled from the same annotated source use a small `.asmi` interface rather
than copied declarations. Strict contract checking is part of the normal Z80
gate, not an occasional audit.

A proof reports through named symbols and bounded state, chosen from:

- a terminal pass, diagnostic, trap, or error marker;
- emitted bytes and the output cursor;
- the current source position;
- selected compiler tables and their high-water marks;
- generated-Z80 registers, scalar storage, data bytes, activation state, and
  service output; and
- instruction, cycle, code-size, and writable-memory totals.

The host harness owns assembly, machine construction, step limits, symbol
lookup, expectation comparison, and failure diagnostics. Individual proof manifests
provide only the source file, memory profile, entry and stopping conditions,
fixtures, and expected observations. This keeps new proofs data-driven and
avoids a separate TypeScript runner for every assembly file. A failed proof must
report at least the program counter, stack pointer, recent program counters,
terminal marker, and the observation that differed.

Fresh AZM output is the measurement authority. Checked-in binaries and
last-run reports, if retained for inspection, are never used as the build or
size baseline. Manual Debug80 sessions supplement automated proofs; they are not
release gates by themselves.

Each stage adds its module and boundary proofs before its milestone proof. The
ordinary repository gate assembles and runs the fast proof set, checks register
contracts, and enforces hard code and memory budgets. Longer full-corpus and
target-profile proofs may run as a second named gate, but the command is
generated from the proof manifest rather than maintained as a chain of script
names.

## Build order

### Completed foundation: direct compiler spine

The completed foundation consumes source through the bounded adapter, tokenizes
and parses it, records checked semantic operations, emits Z80, and runs the
generated program through Debug80. Success, malformed source, output failure,
checked array access, counted loops, forward calls, bounded recursion, and typed
scalar expressions have executable proofs.

The Stage 6 production build is 9,863 bytes of code and immutable data with
1,085 bytes of peak workspace. The structured-control program is 715 bytes,
the comprehensive typed-expression bound is 857 bytes, and the shared target
runtime is 358 code bytes. These are narrow-slice accounts, not projections for
the completed language. Historical proof configurations retain the fixed
parsers and encoders needed to rerun their original evidence; those fixtures
are excluded from the production Stage 6 account.
The detailed path-by-path measurements for the active Z80 implementation are
recorded below.

Before each new stage, the current increment reaches a measured size plateau,
passes its direct-Z80 proofs, and receives adversarial review.

### Stage 5: scalars, expressions, and structured control

Add scalar constants, program variables, scalar parameters and locals,
precedence-driven expressions, conversions, assignment, `if`, `while`, and
counted `for`. Emit branches through bounded fixup state and preserve the
specified left-to-right and short-circuit behavior.

The stage ends with scalar recursion and every scalar safety trap, including the
wide-bound `u8` counted-loop case.

#### First Stage 5 increment: bounded scalar symbols and precedence

The first increment replaces the fixed scalar names used by earlier slices with
a six-entry exact-name table. Each five-byte entry retains a pointer and length
into resident source, one class-and-type byte, and one storage ordinal. An entry
remains provisional while its initializer is checked, so a declaration cannot
refer to itself and a failed declaration never becomes visible. The seventh
name produces a positioned capacity diagnostic.

The accepted proof declares one program `u8`, two per-activation local `u8`
values, assigns through a postfix operation stream, and executes
`left + right * 4`. A single precedence-climbing routine gives multiplication
priority over addition. The generated Z80 writes byte 14, stores 14 in the
program object, and reports a forced output failure at the exact source byte.
Companion cases reject a duplicate name, an unknown name, a missing right
operand, and the seventh symbol at their exact positions. The representative
program deliberately calls its scalar `bytes`; type-suffix dispatch proves that
the old fixed array slice no longer reserves that otherwise ordinary name.

The direct compiler is now 3,883 bytes of code and immutable data with 103 bytes
of peak workspace. Its measured components are 2,369 bytes for the common front
end, including a 121-byte symbol module and 1,596-byte parser, and 1,383 bytes
for the Z80 sink, including a 362-byte expression backend. The generated
program is 101 bytes. The shared Z80 runtime is 204 bytes of code plus 17
bytes of writable state.

The first correct form measured 3,900 compiler bytes. Sharing retained emission
fragments reduced that to 3,866. Removing the accidental `bytes` reservation
added ten bytes of real generality, and sharing the expression push tail
recovered four. The final audit then replaced a truncated one-byte source
position with the required 16-bit operand; an execution proof places the output
call at byte 284 and checks the full trap offset. That correction adds eleven
compiler bytes and one workspace byte, producing the 3,883-byte plateau. A
proposed common indirect dispatcher for the call and expression tables was rejected because its
synthetic return stack could not satisfy strict AZM stack-contract proof. The
proven duplicated dispatch kernels remain until a different representation has
a measurable complete-path saving.

The 33-byte semantic transcript is exactly full in this proof. It records the
limit that forced the next representation change; it is no longer the active
capacity.

#### Second Stage 5 increment: typed scalar expressions

The correctness build generalizes scalar constants, program variables, and
locals to `u8`, `u16`, and `boolean`. Decimal literals cover 0 through 65,535.
The parser applies the specified literal resolution, implicit `u8` widening,
checked explicit narrowing, conversions, unary operations, arithmetic,
comparisons, Boolean operations, and short-circuit evaluation. Constant folding
uses the same selected width, wraparound, division, and narrowing rules as
runtime evaluation. A folded fault in an unevaluated short-circuit operand is
suppressed; the corresponding evaluated operation still produces its required
diagnostic or trap.

Every emitted runtime expression uses a canonical 16-bit carrier. Declared
storage remains one byte for `u8` and `boolean` and two bytes for `u16`. A dense
semantic-operation table selects the direct-Z80 lowering. The pre-review build
deliberately retained explicit type metadata, a seven-byte expression-stack
entry, and repeated legacy paths so the first adversarial review could assess
semantics before representation changes obscured them. The compression pass
keeps the explicit metadata while sharing only paths proved equivalent.

The active transcript contains one operation-count byte and at most 255 payload
bytes. A proof with 52 assignments reaches its capacity diagnostic. Expression
metadata has sixteen seven-byte entries. Each entry retains the type and value
state, suppression state, pending operator, and that operator's 16-bit source
offset. A seventeen-deep pending expression
reaches its separate capacity diagnostic. Failed compilation publishes neither
a partial symbol nor a successful transcript.

Boolean-fixup exhaustion has a distinct capacity diagnostic. A retired
operation, an unbalanced Boolean transcript, a Boolean-fixup underflow, or an
expression-reduction underflow reports an internal-operation diagnostic rather
than attributing the failure to transcript capacity. Direct boundary proofs
exercise each defensive path.

The accepted proofs cover default initialization, both integer widths, Boolean
values, all comparison families, conversions, width-specific wraparound,
operator precedence, short-circuit suppression, static folding, named constants,
unary plus, and direct output. Separate programs prove positioned dynamic
narrowing and division traps without changing their destinations. Every
generated return path checks the exact stack pointer and an IX sentinel, so a
trap cannot appear to succeed after returning through local storage or a saved
frame word. Nested division and narrowing cases check that the outer trapping
operator retains its own source offset. Rejected programs cover implicit
narrowing, Boolean and integer mixing, chained comparisons, a constant-zero
divisor with a dynamic dividend, out-of-range unary operands, malformed decimal
adjacency, lexical overflow, transcript exhaustion, and expression-stack
exhaustion. Suppressed divide and narrowing proofs also require the skipped
operation to retain its statically selected `u8` result type. Missing closing
parentheses and a tokenizer failure after a complete left operand must propagate
through every stacked parser exit. A direct near-capacity case makes a default
local's first literal operand fail, proving that default initialization cannot
mask transcript exhaustion. A named-constant capacity case also proves that
saved symbol metadata is unwound before the failure returns. The existing call
proof exercises preservation of one-byte scalar state across recursive
activations; typed-local recursion remains an integration obligation for the
call and structured-control increment.

Before compression, fresh assembly measured 7,780 compiler-code bytes plus 177
immutable bytes, for a 7,957-byte core with 505 bytes of workspace. The first
adversarial review found incorrect trap-frame exits, incomplete constant-zero
division checking, width leaks in unary operations and conversions, unstable
nested trap positions, malformed decimal adjacency, and a suppressed-fault type
leak. Each repair gained a discriminating proof before compression began.

The retained compression pass shares conversion parsing, Boolean reduction and
fault paths, expression-stack address calculation, generated address and trap
position helpers, and equal-width binary-handler tails. It overlaps identical
immutable template bytes, removes inert padding from Z80 scalar sequences,
and deletes redundant register and flag setup. One conversion refactor exposed
and repaired several error-carry propagation bugs. A later adversarial pass
found and repaired an unbalanced named-constant capacity exit before allowing
the additional size work to proceed. The malformed and capacity forms now have
discriminating proofs.

The complete pass reduces the compiler by 143 bytes without reducing the proof
surface: 7,637 code bytes plus 177 immutable bytes, for a 7,814-byte core. The
common front end is 5,185 bytes. The retained Z80 emission paths occupy 2,452
bytes, including 1,069 bytes of typed lowering. Workspace remains 505 bytes.
The accepted generated program is 799 bytes and the shared Z80 runtime is 324
bytes. The complete proof driver executes 943,921 instructions and 8,796,591
T-states across its accepted, rejected, capacity, and trap cases. The higher
proof count comes from stronger correctness cases and shared compiler helpers,
not from generated-program growth.

The follow-up began at the reviewed 7,854-byte plateau. Balancing the
named-constant failure exit added two bytes. Immutable-template overlap, dead
register and flag setup, and the five- and six-byte binary-handler tails removed
28 bytes. Sharing the three trap-position readers removed another 14 bytes.
The net follow-up reduction is therefore 40 bytes. Larger shared trap tails and
a table-driven comparison-token recognizer remain unmeasured hypotheses and are
not included in the current account.

Completion evidence:

- the representative arithmetic, comparison, conversion, and width-boundary
  vectors produce the specified values or diagnostics;
- paired constant and runtime vectors exercise the selected width and
  wraparound rules;
- success and trap returns preserve the generated frame and report the trapping
  operator's source offset;
- direct and mutual recursion preserve active one-byte scalar state;
- every bounded table and nesting stack has an exercised capacity diagnostic;
  and
- compiler, selected-runtime, generated-program, activation, and timing deltas
  are recorded by feature group.

#### Third Stage 5 increment: structured control and scalar recursion

The third increment integrates typed expressions with `if`, `elseif`, `else`,
`while`, immutable-local counted `for`, nearest-loop `exit` and `continue`, and
one complete forward-declared scalar value routine. Boolean, `u8`, and `u16`
parameters and results use the same canonical scalar carriers as ordinary
expressions. Z80 routine frames preserve scalar parameters and locals across
recursion. Every success and trap path restores the root stack pointer and IX.

The structured parser retains at most eight ten-byte control frames. Z80
emission reuses that storage for 31 dynamic labels, with ordinal 31 reserved for
the retained routine, and 32 three-byte absolute fixups. A label allocation
that would collide with the routine label fails during parsing. The counted
loop lowering retains the bound once, rejects source writes to an active local
counter, and traps before storing a continuing `u8` value that does not fit.

Routine flow summaries are structural. A value routine is complete when its
statement sequence cannot fall through. An `if` has that property only when it
has an `else` and every clause is non-fallthrough; loops remain conservative.
Statements following an unconditional return do not change the summary.
Routine terminators require `end`, so an outer `else` or `elseif` cannot close a
routine. The retained forward name, its parameter, `main`, and scalar
declarations share the required ordinary-namespace collision checks.

Z80 output publication is transactional. The encoder copies the previous
published image to a dedicated 4 KiB backup region before writing
`GeneratedBase`. Every retained encoder restores the complete prior image and
size after a failed emission; successful fixup completion publishes the new
size. The bounded-array boundary proof forces a failure after the first write
and compares every restored byte with the backup.

The correctness-complete form measured 10,597 code bytes plus 224 immutable
bytes, for a 10,821-byte compiler core with 704 bytes of workspace. The size
pass replaced the six-way comparison-token chain with a dense pair table,
inlined two one-caller namespace checks, and shared the identical `while`/`for`
completion tail. It also groups the four transactional encoder wrappers around
one result-and-rollback tail. Those changes remove 50 bytes. The current
plateau is 10,547 code bytes plus 224 immutable bytes, for a 10,771-byte core.
The common front end is 6,987 bytes, including a 6,099-byte parser; retained
Z80 emission is 3,560 bytes, including 2,115 bytes for typed and structured
lowering. Workspace remains 704 bytes. The structured proof executes 296,855
instructions and 2,906,759 T-states across its accepted, trap, namespace,
capacity, and publication cases.

The proof set covers all-return Boolean conditionals, unreachable statements,
recursive scalar calls, activation capacity, exact root-frame restoration,
wide-bound `u8` loop range, active-counter assignment, outer stray branch
tokens, forward and `main` name collisions, label capacity, and complete-image
rollback. The representative accepted program combines nested selection,
loops, transfers, descending iteration, recursion, scalar storage, and output.

### Stage 6: aggregate layout and static images

Add nominal records, fixed arrays, bounded strings, recursive positional
program initializers, packed offsets, and initializer records. Aggregate
storage is allocated only while processing top-level program declarations.

Completion evidence:

- emitted layouts match the language layout rules byte for byte in generated
  Z80 data;
- zero and explicit initializers produce the required static-data images;
- incorrect counts, nesting, types, and string lengths produce diagnostics;
- Z80 startup exposes no partially applied data image; and
- type-metadata and initializer workspace limits are measured.

The first correctness-complete build uses eight dynamic type descriptors, five
record descriptors, twelve field entries, four active initializer levels,
thirty-two initializer nodes including the root, and a 255-byte static-image
region. The representative program defines nested records, a bounded string,
and fixed arrays. Its zero and explicit declarations produce a 52-byte packed
image. The publisher copies that image ahead of the generated entry code and
restores the previous generated image and size after a forced mid-publication
failure.

The correctness baseline measured 12,231 code bytes plus 240 immutable bytes,
for a 12,471-byte compiler core. Workspace was 1,121 bytes. The first
adversarial review found scalar use of record and aggregate symbols, duplicate
field acceptance, and a record type admitted as a counted-loop step. Each
repair gained a whole-source proof. The same review strengthened the rollback
case so the failed publication writes bytes different from the previous image,
and added exact initializer-node and metadata-capacity boundaries.

The compression pass separates historical fixed-slice parsers and encoders from
the production configuration while preserving their standalone executable
proofs. It also narrows extents, offsets, and static-image counters after the
255-byte capacity checks; compacts type and field records; shares token and
parser paths; interns structural type descriptors; and stops rewriting string
padding that the zeroed image already supplies. Fresh production assembly now
measures 9,652 code bytes plus 211 immutable bytes, for a 9,863-byte compiler
core. The common front end is 7,171 bytes, including a 6,151-byte parser. The
retained typed and aggregate Z80 sink is 2,163 bytes. Workspace is 1,085
bytes and the selected Z80 runtime is 358 bytes.

The compression pass removes 2,608 core bytes and 36 workspace bytes from the
correctness baseline. It also leaves the Stage 6 compiler 908 bytes smaller
than the reviewed Stage 5 plateau. The expanded aggregate proof executes
338,164 instructions and 3,195,501 T-states and occupies 1,075 proof bytes. It
checks lowercase and uppercase hexadecimal escapes, canonical Boolean image
bytes, nominal record identity, structural array interning, the 255-byte type
extent boundary, and atomic publication in addition to the original layout and
initializer cases.

The final size reviews found another 73 resident bytes. Four structured-control
templates now alias identical typed-expression bytes; three one-caller token
wrappers are inlined in the production configuration; and repeated diagnostic
tails share their existing implementations. The first follow-up shared Boolean
and `u8` literal emission. Its fresh census exposed the same body in numeric
literals, so the final form selects metadata once and sends all three forms
through one balanced emitter. The final census then routed named constants
through the same checked path. Its symbol byte already contains only the scalar
type, so the final form sets the constant metadata bit directly. The additional
compiler-side save and restore work changes proof timing but leaves generated
code unchanged. The figures above include all follow-ups.

### Stage 7: aggregate calls, results, and copying

Add aggregate parameter carriers, checked selection, transient aggregate
results, carrier preservation across intervening calls, and exact-type
aggregate assignment.

The initial correctness form retains four direct routine declarations, eight
parameters across those declarations, and four nested compiler call frames.
Aggregate arguments enter generated routines as canonical address words and
are copied into distinct activation storage before the routine body runs.
Aggregate results reuse the scalar result carrier but remain statically typed;
source expressions cannot convert, compare, calculate with, or store the
carrier itself. Field and array selection derive another checked carrier, while
bounded-string `length` produces a read-only scalar value.

Exact-type aggregate assignment uses the Z80 `LDIR` instruction after two
complete-region checks. Both checks finish before the first destination write.
The fixed Stage 6 extent limit of 255 bytes makes the copy count representable
in one retained extent byte and in `BC`. The proof also supplies an invalid
source carrier and an invalid destination carrier independently, then verifies
that neither case changes either destination byte.

The initial correctness draft measured 12,440 code bytes plus 219 immutable
bytes, for a 12,659-byte compiler core. The first adversarial review found
unbalanced suffix-capacity exits, two namespace omissions, a scalar suffix
escaping into aggregate metadata, and a suppressed bounds fault that still
produced a diagnostic. The repairs add exact diagnostics, stack-pointer checks,
short-circuit controls, call-shape mismatches, and an activation-capacity trap
that verifies the source position and restored root frame.

Fresh assembly after those repairs measures 12,521 code bytes plus 219 immutable
bytes, for a 12,740-byte compiler core. Workspace is 1,198 bytes. The common
front end is 9,272 bytes, including an 8,252-byte parser. The typed and aggregate
Z80 sink occupies 2,931 bytes, and the selected runtime is 419 bytes. The
four generated proof programs remain 523, 600, 341, and 239 bytes. The expanded
Stage 7 proof executes 597,738 instructions and 5,674,804 T-states and occupies
1,666 proof bytes. These figures describe the repaired correctness baseline;
the second correctness review cleared it for size work without another
production repair.

The measured compression pass removes 216 compiler-core bytes. It shares the
Z80 publication header, indexed-local emitter, control-frame field lookup,
control-label allocation and store, and constant binary preparation. Constant
multiplication consumes the values prepared by that shared path. Four trailing
generated `NOP` bytes and one no-effect compiler instruction are also gone. A
final census aliases eight byte-identical or contained Z80 templates and
inlines four single-caller reset and allocation wrappers. The OR/AND fold merge
no longer pays after the shared constant path, and spilling counted-loop
registers would trade a small remaining code saving for more workspace and a
new liveness obligation, so neither experiment is retained.

Fresh assembly after that compression measures 12,305 code bytes plus 219
immutable bytes, for a 12,524-byte compiler core. A follow-up review then
removed another 212 bytes. It shared fixed-length emission, local-declaration
parsing, call-offset reads, aggregate-region checks, branch-clause prefixes,
constant-expression preparation, and repeated identifier comparisons. One
proposed initializer shortcut was rejected because it would overwrite a live
constant result.

The adopted packed LL(1) build measures 11,656 code bytes plus the same 219
immutable bytes, for an 11,875-byte compiler core. Workspace is 1,276 bytes.
The 7,683-byte parser consists of 4,929 bytes of retained precedence and
semantic support, a 230-byte interpreter, 620 bytes of generated tables, and
1,904 bytes of semantic actions. The main Stage 7 proof executes 823,997
instructions and 7,640,666 T-states. A separate coverage program exercises
constants, default and explicit scalar locals,
`elseif`, `while`, both counted-loop directions, default, named, and signed
steps, and nearest-loop `exit` and `continue`. It compiles and runs those forms,
then checks the generated program's output and retained local values.

Prediction rows mark their final production in the production ordinal's high
bit instead of storing a separate row terminator. This caps the generated
grammar at 127 productions; Stage 7 uses 63.

Completion evidence:

- Chapter 18 caller-supplied destination and selection-forwarding programs
  produce their required output;
- no source operation can inspect, store, convert, compare, or calculate with
  an address carrier;
- every aggregate result is consumed in its containing operation;
- nested calls preserve live transient carriers; and
- copy lowering validates both complete regions before the first store.

### Stage 8: complete calls, failures, services, and validation

Complete packed activations, sixteen argument positions, early returns,
recoverable failure, local handling, propagation, all services, and all traps.
Complete the corresponding load, fixup, and compiler-controlled image-integrity
rules for generated Z80.

Completion evidence:

- every applicable language behavior has a direct-Z80 execution or rejection
  proof;
- activation byte and depth exhaustion are atomic;
- every service and failure path preserves its specified destination and
  cursor effects; and
- image-integrity cost is measured separately from execution code.

The Stage 8 implementation includes the complete scalar and aggregate
call ABI, sixteen argument positions, direct and mutual recursion, forward
signatures including an abbreviated `main` body, direct and forward-visible
calls to `main`, early return, recoverable
failure, propagation, immediate same-line handling, and result-free call
propagation. The six standard services and four stable error constants share
one predefined-name table. Direct runtime calls preserve the specified cursor,
byte, and atomic-failure behavior, and `Reset` clears prior service failures.

The combined active-LL(1) proof exercises all five runtime traps plus
`unhandled-error`, exact trap locations, root SP/IX restoration, handler bypass,
all service success and error families, same-destination handling, sixteen
arguments, mutual forward recursion, direct and forward-visible `main`
recursion, result-free call propagation, and
predefined-name and service-signature rejections. Compiler-controlled image
integrity is checked at assembly/proof time: generated-size arithmetic, the
final publication cursor, target-map non-overlap, fixed runtime entry ranges,
bounded fixups and tables, and rollback of a divergent failed publication. A
hostile-code loader or opcode validator remains outside the selected contract.

The correctness-cleared precompression account was 14,059 core bytes. After
measured compression and the final branch-encoding pass, fresh assembly
measures 13,344 code bytes plus 368 immutable bytes, for a 13,712-byte compiler
core. Workspace is 1,398 bytes; the selected runtime is 561 bytes. The common
front end is 9,916 bytes, including an 8,904-byte parser, and the retained Z80
sink is 3,428 bytes, of which the typed and aggregate portion is 3,091 bytes.
The combined proof occupies 2,953 bytes and executes 1,515,084 instructions in
14,125,764 T-states. The compiler core is 347 bytes smaller than the
correctness-cleared baseline and remains 2,672 bytes inside the hard 16 KiB
gate. Exact test locks record these figures as the Stage 8 size plateau.

The final branch-encoding pass removes 95 resident bytes. Seventy-six direct
transfers use relative encodings; six branches to the next instruction are
deleted; one call-and-return tail becomes a direct relative transfer; and two
redundant flag operations are removed. Four transfers that fit the production
layout remain absolute because at least one historical proof configuration
places their targets outside the signed relative range. Generated programs,
workspace, immutable data, and runtime size are unchanged.

### Stage 9: complete corpus and final accounting

Compile every accepted Chapter 18 program with the Z80 compiler, run it through
the selected execution path, and reject every invalid program before execution.
Report all resource accounts for the complete implementation.

The architecture passes only when the compiler core and immutable compilation
data fit the 16 KiB gate and every conformance program fits the published
capacities. If it fails, use the component ledger to select a semantics-
preserving representation or lowering experiment. Do not infer the cause from
source size or host measurements.

The completed harness locks all twenty-four `nucleus` code fences in Chapter 18
byte for byte. It compiles and runs every accepted program, checks both
specified runtime-trap cases at their exact source offsets, and rejects all
ten invalid programs before execution with their required diagnostic class
and position. The generated terminal paths restore the root stack pointer, IX,
and activation depth. The largest generated program in this corpus is 945
bytes.

The Section 18.1 program is assembled from the literal flat manifest
`model.nu`, a blank line, and `main.nu`. The host adapter preserves written
order, gives duplicate names distinct stable identities, and maps a diagnostic
from identity 2 back to `main.nu`. The Z80 adapter accepts one through eight
five-byte source descriptors. Its proof covers counts 1, 8, and 9, a missing
physical newline, an open delimiter at a part boundary, a positioned failure
in the second part, and successful compilation after earlier multipart and
capacity failures.

The correctness-cleared build measured 13,501 code bytes plus 368 immutable
bytes, for a 13,869-byte compiler core with 1,402 bytes of workspace. The size
pass removes 51 core bytes and one workspace byte. It eliminates a redundant
descriptor-pointer sentinel, folds the pending-boundary flag into the high bit
of the remaining-part count, shares existing source-position initialization,
uses fall-through at the two compilation-entry joins, inlines the sole
multipart-initialization caller, and selects relative transfers for the new
in-range tails. Fresh assembly measured 13,450 code bytes plus 368 immutable
bytes, for a 13,818-byte compiler core. Workspace was 1,401 bytes and the
selected runtime was 561 bytes.

The inferred-constant pass removes the scalar-type phrase from constant
declarations and records integer constants as exact values while retaining
Boolean constants as Boolean. The Chapter 18 proof uses one integer constant
in both `u8` and `u16` contexts and rejects an out-of-range use rather than its
declaration. Regenerated LL(1) tables and actions reduce the active compiler by
seven code bytes. Fresh assembly measures 13,443 code bytes plus 368 immutable
bytes, for a 13,811-byte compiler core with 1,401 bytes of workspace. The
largest generated program remains 945 bytes and the selected runtime remains
561 bytes. The expanded 1,326-byte proof executes 1,141,034 instructions in
10,733,651 T-states. The core remains 2,573 bytes inside the 16 KiB gate.

The sealed-string representation caps `string[N]` at 253 and gives every
string a permanent zero byte after its payload capacity. The length byte,
payload, and sealed byte therefore occupy at most 255 bytes. Every complete
aggregate extent remains a direct, nonzero byte from 1 through 255. Runtime
length checks reject a corrupted `L = 255` before `.length` or indexing can use
it. The representative Stage 7 string program grew because generated string
operations now perform complete-region and length-invariant validation; the
permanent zero itself adds one static-data byte per string object.

The original implementation milestone, before the later 255-byte object
correction, measured 13,616 code bytes plus 368 immutable bytes, for a
13,984-byte compiler core with 1,405 bytes of workspace. The selected runtime
is 585 bytes. The unchanged 1,326-byte Chapter 18 proof executes 1,147,209
instructions in 10,800,907 T-states. Relative to the inferred-constant
baseline, the sealed-string change adds 173 core bytes, four workspace bytes,
and 24 runtime bytes. Those figures include the retired 256-byte object paths;
they are historical evidence, not the current cost of the sealed byte. The core
remains 2,400 bytes inside the 16 KiB gate.

The subsequent correctness review found that an incompatible exact constant
was diagnosed at the end of its expression rather than at the constant name.
The repaired parser retains offset, line, and column for both operands in each
pending expression entry. The Chapter 18 proof now locks the direct and nested
use positions and rejects named Boolean and integer constants in the opposite
category. Additional aggregate proofs reject a corrupted length through both
`.length` and indexing and distinguish the accepted `string[253]` boundary
from rejected capacities 254 and 255.

Before the follow-up size pass, fresh assembly measures 13,687 code bytes plus
368 immutable bytes, for a 14,055-byte compiler core with 1,509 bytes of
workspace. The selected runtime remains 585 bytes and the largest Chapter 18
program remains 1,019 bytes. The expanded 1,449-byte Chapter 18 proof executes
1,188,701 instructions in 11,211,558 T-states. These figures are the repaired
correctness baseline, not a size plateau.

A follow-up state-liveness audit found that the six-byte retained declaration
position overlapped four bytes of the retained expression position. The state
layout now gives those positions disjoint storage, and the Stage 8 proof
retains a declaration name across a nontrivial initializer before checking its
exact duplicate-name offset, line, and column.

The follow-up size pass avoids copying the left operand's six-byte position
into a second workspace cell. Each pending-expression entry already retains
that position, so the reducer now keeps a two-byte pointer to the live entry.
The range-error tail falls through to the common diagnostic path. The final
local pass inlines the single-use constant multiply and divide paths, removes
the second divisor-zero test after the first has proved a constant divisor
nonzero, folds two Boolean-suppression selectors into their call sites,
shortens the expression-entry address calculation, and uses `JR` for the final
range-qualified call-argument failure branch. Fresh assembly measures 13,649
code bytes plus 368 immutable bytes, for a 14,017-byte compiler core with 1,509
bytes of workspace. The selected runtime remains 585 bytes, and the largest
Chapter 18 program remains 1,019 bytes. The 1,449-byte Chapter 18 proof executes
1,188,358 instructions in 11,202,292 T-states.

Three arithmetically promising rewrites were rejected by executable evidence:
a shared six-byte position-copy helper disturbed the Stage 9 proof; inlining
the fixed-width `ForNext` semantic reader changed the first Chapter 18
program's runtime result; and conditional calls could not replace the two
initializer-capacity helpers because successful `CP` paths deliberately retain
carry. The proven inline copies, reader boundary, and capacity helpers remain.

The first post-Stage-9 language increment adds `$` hexadecimal and `%` binary
integer literals. Their scanners share base-dependent accumulation but retain
separate four- and sixteen-digit overflow guards; the decimal value guard is
unchanged. The Chapter 18 corpus accepts both spellings at their 16-bit
boundaries and rejects a fifth hexadecimal digit and seventeenth binary digit
at the literal position. Fresh assembly measures 13,736 compiler-code bytes
plus 372 immutable bytes, for a 14,108-byte compiler core with 1,509 bytes of
workspace. The largest generated program remains 1,019 bytes and the selected
runtime remains 585 bytes. The expanded 1,501-byte Chapter 18 proof executes
1,248,626 instructions in 11,767,489 T-states. Relative to the Stage 9 plateau,
the feature adds 87 compiler-code bytes and four immutable descriptor bytes,
for 91 compiler-core bytes in total; it changes no workspace, generated, or
runtime account.

The next increment adds integer-only `xor` at the same precedence as `or`.
The existing integer-pair resolver supplies exact-constant adoption, widening,
and Boolean rejection; the backend adds width-specific semantic operations and
direct Z80 templates, while the constant path folds both bytes. The Chapter 18
corpus proves left association, constant folding, runtime `u8` and `u16`
execution, and rejection at a Boolean `xor`. Fresh assembly measures 13,803
compiler-code bytes plus 377 immutable bytes, for a 14,180-byte compiler core
with 1,509 bytes of workspace. The largest generated program remains 1,019
bytes and the selected runtime remains 585 bytes. The 1,553-byte Chapter 18
proof executes 1,316,919 instructions in 12,402,392 T-states. Relative to the
numeric-literal commit, `xor` adds 67 compiler-code bytes and five immutable
bytes, for 72 compiler-core bytes in total; it changes no workspace, maximum
generated-program, or runtime account.

The following increment adds integer `mod` at multiplicative precedence. The
constant folder retains the remainder already produced by its division loop;
the generated backend selects a shared runtime division core whose quotient
and remainder entry points preserve the same zero-divisor trap. The Chapter 18
corpus proves constant folding, runtime `u8` and `u16` remainder, and rejection
of a constant zero divisor at that divisor. Fresh assembly measures 13,847
compiler-code bytes plus 382 immutable bytes, for a 14,229-byte compiler core
with 1,509 bytes of workspace. The largest generated program remains 1,019
bytes. The selected runtime is 596 bytes. The 1,653-byte Chapter 18 proof
executes 1,428,311 instructions in 13,446,134 T-states. Relative to the `xor`
commit, `mod` adds 44 compiler-code bytes and five immutable bytes, for 49
compiler-core bytes, and 11 runtime bytes; workspace and maximum generated
program size do not change.

The next increment changes only the target runtime. `MultiplyU16` and the
shared divide/modulo core recognize nonzero power-of-two operands whose high
byte is zero. Multiplication shifts left; division shifts the quotient right
while retaining the remainder required by `mod`. Operands at or above 256 stay
on the existing general paths, where repeated division is already bounded and
the shortcut would be slower. Direct runtime proofs cover zero, 1, 2, 255,
256, 257, and 65,535 for quotient, remainder, and wrapped product. Measured
compiler code remains 13,847 bytes, immutable data 382 bytes, compiler core
14,229 bytes, workspace 1,509 bytes, and maximum generated program 1,019
bytes. The selected runtime grows by 53 bytes, from 596 to 649. The unchanged
1,653-byte Chapter 18 proof executes 1,428,272 instructions in 13,445,707
T-states. This is a runtime-only increment: no compiler-core, workspace, or
generated-output account moves.

The final Track A increment adds top-level compile-time `assert`. The packed
grammar delegates its operand to the existing constant-expression island; one
action accepts only a constant Boolean result, rejects false with a dedicated
diagnostic at `assert`, and emits no semantic operation. The Chapter 18 proof
accepts a true relationship, rejects false and exact-integer operands at the
keyword, and compares the generated image against an equal-position comment
control byte for byte. Fresh assembly measures 13,895 compiler-code bytes plus
390 immutable bytes, for a 14,285-byte compiler core with 1,509 bytes of
workspace. The largest generated program remains 1,019 bytes and the selected
runtime remains 649 bytes. The 1,786-byte Chapter 18 proof executes 1,502,625
instructions in 14,130,034 T-states. Relative to the runtime-fast-path commit,
`assert` adds 48 compiler-code bytes and eight immutable bytes, for 56
compiler-core bytes; it changes no workspace, maximum generated-program, or
runtime account.

The subsequent segmented-output experiment separates code, read-only load
bytes, initialized RAM, and zero-initialized RAM. It widens total program-data
accounting to independent 1 KiB initialized-data and BSS regions, but does not
widen an individual aggregate object. Exact-fill proofs use four 255-byte
sealed-string objects plus a four-byte tail. The first rejected byte is
diagnosed in both regions, and startup copies or clears exactly 1,024 bytes
without changing the following canary.

The 255-byte object correction removes the retired zero-means-256 extent
encoding, 256-byte array-stride path, and special 256-byte copy and region
cases while retaining the sealed byte. Fresh production assembly measures
14,300 compiler-code bytes plus 390 immutable bytes, for a 14,690-byte compiler
core with 2,564 bytes of workspace. The selected runtime is 657 bytes. The
Stage 7 proof executes 1,359,658 instructions in 12,670,276 T-states; the
Stage 8 proof executes 1,620,565 instructions in 15,105,354 T-states; and the
Stage 9 proof executes 1,510,705 instructions in 14,226,734 T-states. Relative
to the immediately preceding segmented-output plateau, the correction removes
49 compiler-code bytes, one workspace byte, and four selected-runtime bytes.

The following aggregate-width correction supersedes that object ceiling.
Dynamic descriptors now retain a 16-bit array length and a separate 16-bit
complete extent. Record-field offsets and record extents are also words.
Selection, region validation, and exact-type aggregate copying consume those word values;
arrays use the element's complete word extent as their stride. Bounded strings
remain capped at `string[253]`, but participate in the same complete-extent,
allocation, region-checking, and copying paths as every other aggregate.

The active segmented compiler admits one complete object up to the enclosing
1,024-byte initialized-data or BSS region. This is an allocation capacity, not
a type-system ceiling: the source array bound remains 1 through 65,535, and a
later memory-map profile can enlarge the program-data regions without another
aggregate-representation change. The proof constructs and copies a 501-byte
record containing two wide arrays, indexes through its word field offset and
word stride, accepts an exact 1,024-byte array, rejects the first 1,025-byte
object, and publishes an explicit 256-byte initialized array.

Fresh production assembly measures 14,311 compiler-code bytes plus 390
immutable bytes, for a 14,701-byte compiler core. Workspace is 3,623 bytes,
including the 1,024-byte object-building scratch and 511-byte semantic
transcript. The selected runtime is 655 bytes, and the largest Chapter 18
generated program is 1,040 bytes. The expanded Stage 7 proof executes
1,701,877 instructions in 15,720,339 T-states and occupies 3,044 proof bytes.

The post-correctness compression pass saves 41 compiler-core bytes without
changing workspace, generated-program, or runtime accounts. The first measured
pass removes 23 bytes through direct word-table address arithmetic, one
explicit-initializer flag, a shared bounded-string extent reader, and compact
descriptor publication. The final 18 bytes come from folding call-offset reads
into that string reader, inlining the sole initializer-entry and field-lookup
paths, and removing two one-call wrappers and a redundant return. A shared
RD/LL(1) array-extent helper was rejected after it grew the selected production
image by five bytes. Executable proof also rejected a proposed manual
descriptor-copy loop, so the proven `LDIR` form remains.

The recoverable-error consumption redesign replaces `or fail` with same-line
`else fail`, replaces delayed `on error` attachment with immediate
`handle NAME ... end`, and makes `return` success-only. The grammar and
generated tables now keep Boolean `or` independent from propagation, while
`on` and `error` are ordinary identifiers. Handler eligibility no longer
survives a statement newline; the retained call-mode patch and control frame
are selected while `handle` is the current token.

The measured pre-change account at commit `0cc5a6f` was 14,311 code bytes plus
390 immutable bytes, for a 14,701-byte compiler core. The parser was 9,226
bytes: 230 engine, 760 tables, 2,791 actions, and 5,445 residual islands.
Workspace was 3,623 bytes; the largest Chapter 18 generated program was 1,040
bytes; and the selected runtime was 655 bytes. The Stage 7 proof occupied
3,044 bytes and executed 1,701,877 instructions in 15,720,339 T-states.

After correctness review and the focused size pass, fresh assembly measures
14,208 code bytes plus 387 immutable bytes, for a 14,595-byte core. The parser
is 9,123 bytes: 230 engine, 746 tables, 2,699 actions, and 5,448 residual
islands. Workspace is 3,622 bytes; the largest Chapter 18 generated program
remains 1,040 bytes; and the selected runtime remains 655 bytes. The Stage 7
proof occupies 3,046 bytes and executes 1,698,773 instructions in 15,699,547
T-states. The expanded Stage 8 proof occupies 3,575 bytes and executes
1,960,585 instructions in 18,249,735 T-states. The Chapter 18 proof remains
1,883 bytes and executes 1,516,312 instructions in 14,282,612 T-states.

The exact compiler-core saving is 106 bytes: 103 code and three immutable
keyword bytes. Keyword retirement contributes the three immutable bytes, and
the grammar tables contribute 14 code bytes. Semantic actions fall by 92
bytes overall. Within that action total, success-only return removes 104 bytes
and obsolete delayed-handler state removes 22 bytes plus one workspace byte;
the immediate-consumer checks and lowering add back 43 bytes. The final size
pass removes another nine action bytes by relying on the already-proved
pending-call entry invariant and converting three in-range absolute branches
to relative branches. The expression island adds three bytes to reject a
pending failable call before Boolean `or`. These component changes sum to the
measured 103-byte code reduction. Generated output and runtime size do not
move; proof execution changes reflect the new spellings and stronger accepted
and rejected coverage.

Source-defined routines and predefined services now publish and lower through
one completed-call path. A service selector packs the dense target, its fixed
zero-or-one-argument signature, successful-result category, and keep/discard
choice into one byte. Source calls retain their variable parameter metadata,
while both kinds share scalar-argument validation, call publication, failure
selection, retained-carrier cleanup, and successful-result handling. Only the
activation-backed source invocation and fixed-runtime service invocation tails
remain distinct. The source language, runtime bytes, and four-call nesting
capacity are unchanged. The only generated/diagnostic difference corrects a
pre-existing nested-call source offset, as recorded below.

The clean baseline at `04f83233` measured 14,208 code bytes plus 387 immutable
bytes, for a 14,595-byte core and 3,622 bytes of workspace. The unified path
measures 14,083 code bytes plus 393 immutable bytes, for a 14,476-byte core and
3,613 bytes of workspace. The parser removes 88 bytes and the callable backend
removes 37; the six-byte immutable service-selector table makes the exact net
core saving 119 bytes. Eight workspace bytes come from four eight-byte call
frames and one from folding service keep/discard into the selector. Source call
records shrink from 11 to 10 transcript bytes and service records from eight to
seven. The parser is 9,035 bytes: 230 engine, 746 tables, 2,699 actions, and
5,360 residual islands. The selected runtime remains 655
bytes and the largest Chapter 18 generated program remains 1,040 bytes. A
temporary comparison matched 81 of 83 baseline generated publications exactly.
The remaining two keep the same size and differ only in one immediate source-
offset byte: a failable service whose argument contains an infallible source
call now correctly records the outer service call rather than the nested call.
This diagnostic correction is deliberate; every other generated byte matches.
The Stage 7 proof remains 3,046 bytes and executes 1,696,273 instructions in
15,674,472 T-states; Stage 8 grows to 3,692 bytes for the nested-call failure
position and four-frame service-argument discriminators and executes 2,025,763
in 18,849,650; Chapter 18 remains
1,883 bytes and executes 1,513,884 in 14,258,168.

The packed action dispatcher now groups three measured families behind
parameterised physical handlers while preserving all 71 logical action names
and their `$80..$C6` ordinals. The existing two-byte direct action directory
remains the smallest representation: a second physical-handler directory
would cost more than the few profitable groups save. The dispatcher already
leaves the zero-based action ordinal in A, so the shared handlers need no
engine instructions, parameter table, or writable state.

The clean baseline at `bcfccd19` measured a 230-byte engine, 746 bytes of
tables, and 2,699 bytes of action code. The tables comprise an 80-byte row
directory, 210 prediction-row bytes, 77 production-directory bytes, 237
production-body bytes, and the 142-byte action directory. The seven retained
`x:` entries occupy 213 bytes within the action extent; the other retained
parser islands occupy 5,360 bytes. The three scalar-type entries shrink by
eight bytes, `exit`/`continue` by five, and `to`/`until` by three. Engine, tables,
directory, external entries, and residual islands do not move. The resulting
parser is 9,019 bytes: 230 engine, 746 tables, 2,683 actions, and 5,360 residual
islands. Compiler code is 14,067 bytes plus 393 immutable bytes, for a
14,460-byte core; workspace remains 3,613 bytes.

Other audited families do not pay. The declaration, parameter, local, and
result type-retention actions have different saved-state and failure-unwind
contracts. Initializer and control-frame actions differ before their already
shared tails. Fixed-operation and flow actions are either singletons or
already share their complete profitable suffix. The substantial `x:` islands
retain distinct parser/result contracts and remain direct entries.

All existing semantic-buffer hashes and active generated-program hashes match
the baseline, as do the selected runtime bytes. The largest generated program
therefore remains 1,040 bytes and the selected runtime remains 655 bytes. The
Stage 7 proof remains 3,046 bytes and executes 1,696,205 instructions in
15,673,656 T-states; Stage 8 remains 3,692 bytes and executes 2,025,638 in
18,848,156; Chapter 18 remains 1,883 bytes and executes 1,513,817 in
14,257,361.

A subsequent current-core compression pass shares the segmented startup-entry
tail with the ordinary program-header emitter, tail-enters the existing exact
1 KiB aggregate-capacity check from program-segment allocation, removes one
zero-displacement branch, and converts one terminal call/return to a tail
jump. The header merge saves 16 bytes after pricing its required two-byte
bridge; the capacity-tail merge saves 15; and the two local tails save three.
Compiler code is therefore 14,033 bytes plus 393 immutable bytes, for a
14,426-byte core. The parser is 9,001 bytes: 230 engine, 746 tables, 2,665
actions, and 5,360 residual islands. The typed/aggregate sink is 3,243 bytes.
Workspace remains 3,613 bytes, the largest generated program remains 1,040
bytes, and the selected runtime remains 655 bytes. Baseline/current comparison
keeps complete semantic buffers, active generated publications, and runtime
bytes identical. The Stage 7 proof executes 1,696,249 instructions in
15,674,079 T-states; Stage 8 executes 2,025,638 in 18,848,024; and Chapter 18
executes 1,513,833 in 14,257,474.

The next semantics-preserving compression pass removes another 105 code bytes.
Three declaration lookups share one LL(1)-action prelude, saving 11 bytes;
overlapping Z80 templates share their existing immutable bytes, saving 16;
ordinary and forward routine publication share one routine-table writer,
saving 23; and three routine-end sites share selection and semantic emission,
saving 29. The string length and index checks share their generated-code tail,
saving 19 bytes. A scalar-path tail saves four more bytes, and unary negation
and complement share their emission setup for two; the resulting scalar-path
transfer is then relative, saving the final byte.

Fresh assembly measures 13,928 code bytes plus 393 immutable bytes, for a
14,321-byte core. The parser is 8,931 bytes: 230 engine, 746 tables, 2,602
actions, and 5,353 residual islands. The typed/aggregate sink is 3,208 bytes.
Workspace remains 3,613 bytes, the largest generated program remains 1,040
bytes, and the selected runtime remains 655 bytes. The Stage 7 proof remains
3,046 bytes and executes 1,696,451 instructions in 15,676,452 T-states; Stage
8 remains 3,692 bytes and executes 2,025,934 in 18,851,465; and Chapter 18
remains 1,883 bytes and executes 1,514,048 in 14,259,956.

The next measured compression pass removes 200 compiler-code bytes, 13
workspace bytes, and 73 selected-runtime bytes. Shared retained-name
comparison and publication account for 65 compiler bytes; source-position
copying saves eight; tokenizer token and escape paths save 22; and interning
ten duplicate grammar productions saves 12 table bytes. Configuration-specific
reset inlining saves 11 bytes. Root-frame, trap, failable-call, aggregate
carrier, arithmetic, and routine-frame sharing remove 77 bytes, and five newly
reachable relative transfers remove the last five. The parser is 8,844 bytes:
230 engine, 734 tables, 2,573 actions, and 5,307 residual islands. The
typed/aggregate sink is 3,133 bytes.

Fresh assembly therefore measures 13,728 code bytes plus 393 immutable bytes,
for a 14,121-byte compiler core. The LL(1) action scratch now overlays inactive
aggregate-initializer staging, reducing workspace from 3,613 to 3,600 bytes.
Runtime reset, activation-capacity, index/length checks, and byte-service reads
reduce the selected runtime from 655 to 582 bytes. The largest generated
program remains 1,040 bytes. Baseline comparison keeps every semantic
transcript identical. Generated publications keep the same sizes and bytes
except for absolute `CALL` operands relocated to the same named entries in the
smaller runtime. The Stage 7 proof remains 3,046 bytes and executes 1,702,331
instructions in 15,737,944 T-states; Stage 8 remains 3,692 bytes and executes
2,032,759 in 18,918,203; and Chapter 18 remains 1,883 bytes and executes
1,520,260 in 14,322,659.

A focused helper pass removes another 116 compiler-code bytes. Five repeated
compiler operations—exact `main` comparison, Boolean-left classification,
declaration-type extraction, expected-type publication, and emitted `POP
HL`—account for 76 bytes. Shared opcode-and-push, comparison-emission, and
control-frame-label tails remove 32 more. The two validation helpers save only
seven bytes: their diagnostic exits require a caller-side carry return, a cost
that the initial byte estimate omitted. A newly reachable relative transfer
removes the final byte. This leaves the parser at 8,765 bytes:
230 engine, 734 tables, 2,510 actions, and 5,291 residual islands. The typed
and aggregate sink is 3,096 bytes.

Fresh assembly measures 13,612 code bytes plus 393 immutable bytes, for a
14,005-byte compiler core. Workspace remains 3,600 bytes, the largest generated
program remains 1,040 bytes, and the selected runtime remains 582 bytes. A
temporary baseline comparison keeps generated publications and selected
runtime bytes identical. The Stage 7 proof remains 3,046 bytes and executes
1,702,823 instructions in 15,743,156 T-states; Stage 8 remains 3,692 bytes and
executes 2,034,307 in 18,936,135; and Chapter 18 remains 1,883 bytes and
executes 1,521,339 in 14,334,990.

The aggregate-constant increment adds explicitly typed record, fixed-array,
and bounded-string constants. Initialized program data remains the prefix of
the generated read-only segment; constant bytes form a suffix, and symbols
retain offsets relative to that suffix. Declaring initialized data after a
constant shifts the suffix without changing those offsets. Startup still
copies only the initialized-data prefix. Direct constant-rooted assignments
are rejected, while an ordinary aggregate alias deliberately carries no
read-only marker.

The correctness form measured 13,851 compiler-code bytes. A focused pass
removed 40 bytes by sharing root emission and alias-load tails, computing the
combined published length directly, simplifying constant commit, and moving
the data-length update out of its temporary stack lifetime. A shared two-region
runtime predicate removes 12 bytes from the first correct region-check form.

Fresh final assembly measures 13,811 compiler-code bytes plus 393 immutable
bytes, for a 14,204-byte compiler core. The parser is 8,943 bytes: 230 engine,
755 tables, 2,627 actions, and 5,331 residual islands. The typed/aggregate sink
is 3,117 bytes. Workspace is 3,602 bytes, the largest generated program remains
1,040 bytes, and the selected runtime is 596 bytes. The Stage 7 proof is 3,501
bytes and executes 2,171,678 instructions in 20,115,678 T-states; Stage 8 is
3,692 bytes and executes 2,035,400 in 18,945,941; and Chapter 18 is 1,935 bytes
and executes 1,655,345 in 15,585,591. Relative to the preceding plateau, the
feature adds 199 compiler-core bytes, two workspace bytes, and 14 selected
runtime bytes; immutable compiler data and the largest generated program do
not change.

## Target-system implementation increment

This section is the historical construction record for the implemented target
system. All seven recorded stages and the final review are complete; future
tense below describes the plan used at the time, not pending work.

The [target-system specification](target-system-specification.md) defines the
approved shape for target profiles, startup, runtime vectors, and one-program
banking. The [object-stream format](nucleus-object-format.md) defines the exact
NOBJ 0.1 wire representation. This section records implementation order,
budget, and unresolved compiler representations only. It does not amend either
specification or the Z80 runtime contract.

The `d611a696` baseline is 13,811 compiler-code bytes plus 393 immutable bytes,
for a 14,204-byte core. Workspace is 3,602 bytes and the selected runtime is
596 bytes. The 16 KiB gate leaves 2,180 compiler-core bytes. Aggregate constants
measured 199 compiler-core bytes against an earlier 80–150-byte estimate, so
the target-system increment must not rely on the earlier optimistic ranges.

The present bottom-up projection is 405–780 compiler-core bytes before that
estimation correction. Plan around approximately 700 bytes, test feasibility
against a 1,000-byte increment, and stop for design and compression review when
the measured increment reaches 600 bytes. Every retained step reports compiler
code, immutable data, core, workspace, generated output by bank, runtime,
instruction count, and T-states separately.

The multi-bank representation is settled. The compiler submits image bytes to
one sequential operating-layer spool and resolved replacement bytes to another.
Image records carry bank ordinals and target addresses. The compiler retains
only currently unresolved fixup sites and releases each site after the patch
spool accepts its final bytes. The sink serializes the image spool before the
patch spool, then appends the map and terminal commit. The compiler does not
retain complete bank images or generated routines, replay the semantic
transcript per bank, or ask the consumer to resolve symbols or branch kinds.

The target layout places generated read-only data before generated code. The
parser publishes initialized-data and per-bank aggregate-constant lengths before
emission; startup and runtime lengths are also fixed. The backend can therefore
derive read-only bases, code bases, aggregate-constant addresses, and the ROM
copy-source address without patching them. Remaining patches cover generated
control-flow sites, genuine routine forwards, and the entry transfer to `main`.

The operating layer owns the canonical runtime source revision and its
deterministic linker or assembler. The compiler retains only the runtime
identity, expected linked length, vector layout, helper offsets, and the compact
values needed to form the complete link context. At each derived runtime
address it calls a bounded runtime-image provider with the runtime base,
writable/vector state addresses, service destinations, and relevant data and
read-only bounds. The provider links the selected source, verifies the
resulting length and helper offsets, and appends fully resolved bytes to the
image spool as ordinary `IMAGE` records. NOBJ remains non-relocatable. The
provider implementation and canonical source are external-service resources,
not compiler core or workspace; the compiler-side call path must still be
measured, and every emitted per-bank copy must be reported as selected-runtime
bytes and as occupancy in its bank image.

NOBJ 0.1 uses a three-byte record header, dense record tags, little-endian
fields, a fixed versioned begin record, one variable map, and a CRC-16-covered
terminal commit. The compiler-facing logical calls may be smaller than the wire
encoder, because the storage sink supplies profile-only fields, framing, and
the running CRC. Patch calls may arrive while image emission continues and in
an address order determined by target resolution. The sink preserves that order
in its patch spool and places the complete spool after all image records.

The storage adapter owns atomic generations. An aborted or truncated pair of
spools has no commit and cannot replace the preceding committed object. This
removes the compiler-side generated-image and rollback buffers while preserving
the separate external-storage account. TEC-FS needs two sequential temporary
spools and atomic commit, not random writes. It may copy the patch spool after
the image spool or join their storage chains. A RAM loader or host ROM utility
materializes the committed stream and applies its byte patches later.

Direct wire materialization is a flat-target facility unless the receiver has
isolated writable backing for every selected physical bank. A banked receiver
without that backing first spools the NOBJ, validates its commit, and then
materializes each bank during another read. This is an operating-layer storage
requirement, not compiler workspace.

The current proof memory map reserves 4,096 bytes for generated output and
4,096 bytes for its rollback copy. Streaming makes both regions unnecessary, a
projected release of 8,192 Z80 address-space bytes before any small transport
state is measured. This is not a compiler-core saving. The current structured
fixup capacity remains 32 four-byte unresolved-site records, or 128 compiler
workspace bytes. Separate label and flag bytes preserve all six label bits
without sharing them with target-bank and far-call flags. NOBJ adds six framing
bytes around each patch payload, so a
one-byte patch occupies seven external bytes and a word patch occupies eight.

The target-system specification settles runtime layout independently of that
experiment: every bank carries one complete selected helper image linked for
the validated common bank runtime and writable layout.
This costs device-image bytes rather than compiler-core bytes and preserves one
runtime identity and helper-offset table. Per-bank helper subsetting is not a
candidate for this increment.

Every bank also reserves a three-byte entry slot. Only the entry bank emits
`JP startup`; all selected runtime images begin at `bankWindowBase + 3`. Record
the three-byte capacity cost in every bank and the emitted-byte cost in the
entry bank separately.

Implementation was organized in these measured increments:

1. add the compact target descriptor, complete runtime link context,
   runtime-provider lookup, and identity, length, and helper-layout rejection;
2. derive loaded and ROM layouts with read-only data before code and report
   first-free image addresses;
3. merge runtime vectors, initialized variables, and BSS into the upward
   writable allocation;
4. add inherited and top-of-writable established stack modes, proving incoming
   `SP` restoration on success, unhandled failure, and traps;
5. add the two-spool append-only NOBJ sink with deliberately unequal compiler
   and target addresses, plus runtime-image provider, byte-exact image,
   arbitrary-order patch, deferred used-length validation, spool serialization,
   map, CRC, commit, and abort proofs;
6. install and call the RAM-resident service and terminal vectors;
7. implement source-part bank mapping, bank-tagged output records, and one
   entry pair, including entry-bank source ordering and exact bank-capacity
   diagnostics, with the uniform three-byte bank-entry slot;
8. implement local versus far-call lowering and all three cross-bank aggregate
   restrictions;
9. force a divergent late failure after image output and prove that the new
   stream has no commit while the previous committed generation remains
   current; separately reject a missing commit and an invalid patch; and
10. obtain a read-only correctness review, perform measured compression, and
    obtain a final correctness-and-size review before commit.

The target-system and NOBJ authorities were implemented in these stages. The
600-byte cumulative target-system checkpoint governed that work and is retained
here as part of the decision record; the later final review did not replace its
contemporaneous evidence.

### Target-system Stage 1: strict host NOBJ boundary

Stage 1 implements the NOBJ 0.1 encoder, validator, materializer, two-spool
generation sink, and atomic current-generation store in host TypeScript. The
sink validates complete `BEGIN`, `IMAGE`, `PATCH`, `MAP`, and `COMMIT` records;
preserves arbitrary non-overlapping patch order; checks deferred used extents;
and publishes only after the record count, duplicated entry pair, and
CRC-16/CCITT-FALSE pass. Aborts, truncation, unavailable or mismatched runtime
images, and late map failures leave the preceding committed generation current.

The Stage 1 operating-layer runtime provider assembles the selected 596-byte
helper image in the proof layout from the same AZM source used by the
executable proofs. Stage 3 replaces that fixed proof context with the complete
validated target link context. Its identity is
the machine-readable `NucleusRuntimeIdentity` assembly symbol; TypeScript reads
that symbol rather than maintaining a second numeric table or a copied runtime
blob.

Measured Stage 1 compiler accounts are unchanged from the approved baseline:
13,811 code bytes plus 393 immutable bytes, for a 14,204-byte compiler core;
3,602 workspace bytes; a 1,040-byte largest generated program; and a 596-byte
selected runtime. The new encoder, validator, materializer, provider, spools,
and generation reference are host or operating-layer resources and therefore
add zero bytes to compiler code, immutable compiler data, compiler workspace,
generated Z80, and selected runtime. The runtime-identity include defines a
symbol only and emits no Z80 byte.

The exact-record-count fixture reaches 458,724 bytes in its in-memory image
spool. That is measured external sequential-storage occupancy for 65,532
one-byte `IMAGE` records, not compiler workspace; a production sink may stream
the same spool to a file or filesystem extent chain. Patch-spool high water is
reported independently.

Executable host evidence covers flat and banked objects, fill gaps, image and
fill patches, alternating banks, descending patch order, exact image-region and
record-count boundaries, 1/65,532/65,533-byte payload boundaries, malformed
framing and maps, every record-class truncation, runtime identity and length
rejection, flat direct materialization, banked stored materialization, and
successful publication after abort, truncation, and divergent late failure.

### Target-system Stage 2: committed-object proof execution

Stage 2 extends the manifest proof runner with an optional NOBJ path while
leaving every legacy manifest and `ProofOutcome` field intact. The producer Z80
execution writes a bounded proof-only sequence of logical image, runtime-image,
and patch calls. The host sink commits and strictly reparses the object, the
materializer creates fresh target memory, and a second Debug80 runtime enters
only the committed `(entryBank, entryAddress)`. No byte is copied from the
producer's generated-output region into that second runtime.

The synthetic flat proof uses a 20-byte adapter log, a 92-byte committed NOBJ,
a 256-byte materialized image, and three generated-program instructions. Its
write to `$8081` appears only in fresh target memory; the producer memory at
that address remains zero. The synthetic banked proof commits two 256-byte bank
images, executes through a Nucleus-local bank-window selector, calls bank-local
code, restores bank zero, and leaves the expected common-RAM state. A missing commit, a
patch before any image, and a bad CRC all fail strict validation before a
Debug80 target runtime is created.

Measured compiler accounts remain 13,811 code bytes plus 393 immutable bytes,
14,204 core bytes, 3,602 workspace bytes, a 1,040-byte largest production
program, and a 596-byte selected runtime. Stage 2 adds zero compiler, workspace,
generated-program, or runtime bytes. Its adapter log, serialized NOBJ,
materialized images, bank-window copy, and fresh 64 KiB Debug80 memory are
proof-runner external accounts.

### Target-system Stage 3: flat append-only compiler output

Stage 3 adds the compact eleven-byte flat descriptor and a logical output ABI
for begin, image byte, runtime image, byte or word patch, map, commit, and
abort. Generated emission maintains a target cursor and remaining capacity; it
never writes a generated byte or fixup into compiler-address-space output. The
host proof adapter turns the bounded logical-operation log into NOBJ, strictly
reparses it, and materializes it into fresh target memory.

Runtime identity `$0003` selects a 364-byte canonical source and ABI layout,
eleven three-byte vectors, 21 fixed writable-state bytes, deterministic link
rules, and checked helper offsets. The provider links that source against the
complete context, including runtime, vector, state, service, program-data, and
read-only-data addresses. The same identity therefore produces different
fully resolved bytes at the default layout and at runtime `$8003`; both linked
forms execute the checked activation helper at their own state addresses.

Fresh Stage 3 assembly measures 14,636 compiler-code bytes plus 393 immutable
bytes, for a 15,029-byte compiler core. Workspace is 3,604 bytes. The focused
flat proof emits 479 target-image bytes: a three-byte entry placeholder, the
364-byte linked runtime, 56 initialized read-only bytes, and 56 generated-code
bytes. Its selected historical proof runtime remains a separate 596-byte
account. Proof code and data occupy 1,156 bytes. The committed NOBJ is 1,263
bytes; the final proof-only logical-operation log reaches 847 bytes. Image and
patch spools remain external accounts. The proof executes 126,843 compiler
instructions in 1,222,146 T-states before host
materialization.

The proof accepts a nonempty region ending at mathematical `$10000`, rejects
the first wrap, rejects partial image/writable overlap, and compiles both loaded
and ROM layouts. The loaded case rejects writable storage that begins before
code can end, derives its read-only context without the ROM initialization
image, and places initialized bytes at their run address. Separate late image
and map failures both abort without commit; a subsequent compilation succeeds.
The materialized ROM program contains target `$4036` program-data operands and
a call to the linked multiply helper at `$80B9`, excluding compiler-address
leakage. Stage 4 supplies executable startup, runtime-vector/state
initialization, BSS clear, and stack modes; Stage 3 deliberately materializes
without entering the incomplete startup image.

### Target-system Stage 4: startup, writable storage, and stack modes

Stage 4 replaces the provisional zero-filled runtime prefix with one provider-
owned 54-byte initialization image: eleven resolved three-byte service and
terminal vectors followed by the identity-fixed 21-byte initial runtime state.
The compiler requests those bytes through `runtimeInitialImage` using the same
validated link context as `runtimeImage`; both operations serialize only
ordinary NOBJ `IMAGE` records. The compiler retains neither byte sequence.

Flat entry remains a three-byte `JP` at `imageBase`, and the linked runtime
still begins at `imageBase + 3` (including the required `$8003` layout). The
entry patch targets a bounded startup continuation immediately after the
runtime. ROM startup establishes the optional stack, copies the complete
vector/state/program initialized block, clears BSS, and enters `main`. Loaded
startup omits the copy and clears BSS at the already initialized run address.
The initialized run begins at `writableBase`, BSS follows its used length, and
no source instruction executes before either path completes.

The established-stack path reserves the published 3,840-byte stack account
plus two saved-incoming-SP bytes. It selects the mathematical writable end,
retains the incoming SP on the new stack, and restores it on normal success,
unhandled recoverable failure, and trap. Each terminal path then dispatches
through the provider-initialized success, unhandled-failure, or trap vector.
Inherited-stack mode never writes SP.

Fresh focused evidence executes ROM and loaded objects from committed NOBJ,
discriminates copy-before-clear and the absence of a loaded copy, checks the
nonzero vector and runtime-state bytes, admits the exact established-stack fit,
rejects its first-byte shortfall, and executes normal, trap, and unhandled-
failure terminal paths with exact SP restoration.

After the focused correctness and size pass, Stage 4 measures 15,124 compiler-
code bytes plus 393 immutable bytes, for a 15,517-byte compiler core. The
parser extent is 8,944 bytes. Workspace remains 3,604 bytes: the final 40-byte
compiler map exactly overlays dead startup, terminal-address, and runtime-link-
context storage instead of extending the workspace. The selected linked
runtime remains 364 bytes; the historical proof runtime is 596 bytes. The
representative ROM object uses 540 target-image bytes, including 54 adapter-
owned vector/state bytes, and commits a 1,380-byte NOBJ. Its proof code/data is
1,673 bytes. Compiler-side proof execution is 257,742 instructions and
2,597,781 T-states; the committed target program executes 79 instructions and
1,920 T-states. Relative to Stage 3, the compiler core grows by 488 bytes;
immutable data and workspace do not grow. The core remains 867 bytes below the
16 KiB stop gate.

### Target-system Stage 5: one-program banking and far calls

Stage 5 widens the compact target descriptor to fifteen bytes, retains one
cursor and exact remaining-capacity word for each of four banks, and packs the
source-part bank into existing routine, symbol, and control metadata. The
compiler still consumes one ordered source stream and publishes one NOBJ. Each
selected bank reserves the common entry slot, receives the complete linked
runtime at `bankWindowBase + 3`, places its read-only data before its code, and
maintains monotonic image addresses independently of the other banks.

Runtime identity `$0004` keeps the 364-byte helper source and checked helper
offsets while extending fixed writable state from 21 to 37 bytes. The new
sixteen-byte far-return arena uses activation slot `ActivationDepth - 1`, so
the existing depth-eight boundary occupies slots zero through seven without
changing the hardware-stack argument layout. Local calls remain ordinary
`CALL`; cross-bank calls and terminal transfers use the provider-initialized
far-call and far-jump vectors. Runtime copies are byte-identical across banks
because their runtime base and complete writable/vector context are common.

The operating-layer provider treats the identity as a canonical source, ABI,
vector/helper layout, link rules, and expected length rather than one address-
bound byte sequence. It deterministically links against the complete validated
context, verifies the linked length and helper offsets, and emits fully
resolved ordinary `IMAGE` bytes. Executable provider evidence links and runs
the same identity at the default layout and at runtime `$8003`, where the
writable, vector, service, program-data, and read-only addresses all differ.
NOBJ remains non-relocatable and contains no runtime relocation records.

The final reviewed assembly measures 15,887 compiler-code bytes plus 393
immutable bytes, for a 16,280-byte compiler core. The parser extent is 9,268
bytes and workspace is 3,604 bytes. The selected historical proof runtime
remains 596 bytes; each committed bank contains one 364-byte linked runtime
copy. Fixed runtime state is 37 bytes, and the established activation storage
remains 3,840 bytes. The core is 104 bytes below the 16 KiB stop gate.

The representative flat object uses 556 of 4,096 target-image bytes and
commits a 1,396-byte NOBJ. Its external image spool reaches 1,300 bytes across
124 records with 556 payload bytes; its patch spool reaches 24 bytes across
three records with six payload bytes. The compiler proof occupies 2,232 bytes
and executes 815,614 instructions in 7,937,048 T-states; the committed program
executes 79 instructions in 2,256 T-states.

The banked success object uses 813 bytes in bank zero and 589 in bank one,
commits a 5,228-byte NOBJ, and materializes two external 4,096-byte bank
images. Its image spool reaches 5,023 bytes across 604 records with 1,399
payload bytes; its patch spool reaches 122 bytes across sixteen records with
26 payload bytes. The committed program executes 492 instructions in 6,095
T-states. The independent cross-bank trap object uses 594 and 454 bytes,
commits 2,674 NOBJ bytes, and executes 137 instructions in 2,796 T-states.

The proof covers local and far scalar calls, recursion, exact error-code
propagation, a trap restored through the common terminal path, caller-bank
restoration, the depth-eight return slot, entry-bank selection, forward/body
bank agreement, invalid ordinals, per-bank and entry-bank overflow, and all
three aggregate restrictions. Fixup completion closes the active bank before
MAP publication, and each bank retains both cursor and remaining capacity so a
legal image ending at mathematical `$10000` can be reselected without a false
wrap diagnosis.

### Target-system Stage 6: staging retirement and committed publication

Stage 6 removes the active target compiler's complete-image publication path.
The production proof memory map does not define `GeneratedBase`,
`GeneratedLimit`, or `BackupBase`; any active reference to those historical
symbols therefore fails assembly. `EmitByte`, `EmitWord`, fixup completion,
runtime requests, map publication, and abort all use the append-only logical
sink. The old direct sink and rollback routines remain conditional evidence for
historical module proofs and are excluded from the active compiler extent.

The target proof map now assigns the former generated-output range
`$5800..$6800` and rollback range `$A000..$B000` to released address space.
This recovers 8,192 bytes of Z80 address space. It does not reduce compiler
workspace or an NOBJ spool. The Stage 6 proof deliberately stores source and
proof-only adapter data in portions of those ranges, which distinguishes usable
released memory from a renamed reservation.

The current-generation proof uses three real compiler outputs. It commits the
ordinary flat program as artifact A. The Z80 compiler then emits image and
patch operations for the different trap program B and fails during its late
map operation. Replaying B's saved tentative operations against the same host
generation store with a rejected final map leaves A current byte for byte. The
compiler's Chapter 18 output becomes artifact C, which replaces A only after a
valid commit and executes from a fresh materialization. No step restores
compiler-resident output bytes.

The production target proof also compiles and executes the established Stage 7
aggregate-call program, the Stage 8 propagation program, and the accepted
multipart program from Chapter 18.1 through NOBJ. The complete historical
Stage 7, Stage 8, and Chapter 18 direct proofs remain module evidence only and
do not claim target-system conformance.

Fresh Stage 6 assembly measures 15,717 compiler-code bytes plus 393 immutable
bytes, for a 16,110-byte compiler core. This is 170 core bytes smaller than
Stage 5 and leaves 274 bytes below the 16 KiB gate. The parser remains 9,268
bytes and workspace remains 3,604 bytes. The selected production-proof runtime
is 574 bytes after the historical aggregate-region entry is excluded; each
committed target bank still contains the same 364-byte linked runtime. Fixed
runtime state remains 37 bytes and activation storage remains 3,840 bytes.

The expanded producer proof is 2,300 bytes and executes 1,016,419 instructions
in 9,951,207 T-states. The representative flat and banked artifact sizes remain
1,396 and 5,228 NOBJ bytes, with used bank extents of 556 and 813/589 bytes.
The Chapter 18 object uses 1,461 of 4,096 target-image bytes and commits 7,913
NOBJ bytes. Its external image spool reaches 7,635 bytes across 1,029 records
with 1,461 payload bytes; its patch spool reaches 205 bytes across 27 records
with 43 payload bytes. Its committed target execution uses 1,696 instructions
and 17,926 T-states.

### Target-system Stage 7: final review and publication

The final adversarial review traced sink failures, fixup publication, target
and source addresses, the complete runtime link context, map arithmetic, stack
restoration, bank switching, aggregate-bank restrictions, generation
atomicity, and the proof runner's fresh-memory boundary. The operating-layer
provider keys each linked runtime by its canonical identity and the complete
validated context: runtime base, writable and vector state, service addresses,
program data, and read-only bounds. It checks the linked length and every
published helper offset before appending resolved IMAGE bytes. NOBJ remains
non-relocatable and contains no runtime link records.

The compression pass removed five transfers to the immediately following
instruction (10 bytes), shortened six absolute jumps whose signed range holds
in every supported layout (6 bytes), shared the three target entry/fixup
emitters (23 bytes), and shared the two terminal-state comparison emitters (13
bytes). The complete Stage 7 saving is 52 compiler-code bytes. A shared
segment-capacity checker was rejected: its three-byte saving added 26,393
instructions to the wide-array proof because the check lies inside the extent
loop. The residual branch census contains
only two production-layout-relative candidates that exceed range in retained
historical configurations; no no-op transfer or CALL/RET tail remains. The
residual duplicate census has three unrelated 14–16-byte runs whose complete
contract-safe factoring does not establish a further target-system saving.

Fresh Stage 7 assembly measures 15,665 compiler-code bytes plus 393 immutable
bytes, for a 16,058-byte compiler core and 326 bytes of headroom below 16 KiB.
The parser is 9,264 bytes. Workspace remains 3,604 bytes. The selected proof
runtime remains 574 bytes, each target bank still receives the same 364-byte
linked runtime, fixed runtime state remains 37 bytes, and activation storage
remains 3,840 bytes. The producer proof remains 2,300 bytes and executes
1,016,467 instructions in 9,951,675 T-states.

All seven production NOBJ fixtures are byte-identical to their Stage 6
counterparts: flat ROM, flat loaded, flat trap, flat unhandled failure, banked
success, banked trap, and Chapter 18. Their generated extents, NOBJ sizes,
image and patch spool high-water marks, selected runtime, and committed target
execution therefore remain unchanged. The full proof harness, package suite,
strict AZM register contracts, typecheck, formatting, prose, and diff checks
form the final publication gate.

A post-publication target-focused compression pass starts from that exact
`26120b24` account. It caches the validated bank count and entry bank in two
bytes after the parser-stack/layout overlay, shares three checked 16-bit image
copy loops, shares five writable-state store prefixes, folds the flat and
banked map/commit ending, compacts bank-state initialization and bank
validation, and shares two LL(1) control-action families.

The subsequent correctness pass found that emitting the entry placeholder
destroyed the current-bank register. An entry bank other than zero was
therefore published as bank zero and its startup was skipped. The repair
preserves that register across placeholder emission. A separate two-bank proof
now enters bank one, runs its startup and `main`, and checks the resulting
program state and selected bank.

After the repair and its focused compression pass, fresh assembly measures
15,521 compiler-code bytes plus the unchanged 393 immutable bytes, or 15,914
bytes of compiler core. Headroom is 470 bytes. Workspace remains 3,606 bytes;
the two bytes above the Stage 7 account are the descriptor cache. The parser is
9,239 bytes: 230 bytes of engine, 755 bytes of tables, 2,680 bytes of actions,
and 5,574 bytes of retained parser code. The selected proof runtime remains 574
bytes. The expanded producer proof is 2,345 bytes and executes 1,043,134
instructions in 10,193,352 T-states. The higher proof cost comes from compiling
and executing the additional entry-bank-one program. All seven pre-existing
production NOBJ fixtures remain byte-identical to the frozen `b7337e2d`
baseline, including every linked runtime image.

A second measured compression pass shares the Boolean and counted-loop result
checks, routine-state reset sequences, scalar expected-type tails, initialized-
data length calculation, and the low-byte local-load prefix. These changes
remove 39 compiler-code bytes: 23 from the packed parser actions, 13 from target
layout and startup calculation, and three from the Z80 expression sink. Fresh
assembly measures 15,482 compiler-code bytes plus 393 immutable bytes, or
15,875 bytes of compiler core. Headroom is 509 bytes. The parser is 9,216
bytes: 230 bytes of engine, 755 bytes of tables, 2,657 bytes of actions, and
5,574 bytes of retained parser code. Workspace remains 3,606 bytes, the
selected proof runtime remains 574 bytes, and the largest generated program
remains 1,040 bytes. The producer proof remains 2,345 bytes and executes
1,043,353 instructions in 10,196,561 T-states. All seven pre-existing NOBJ
fixtures remain byte-identical to `f0c6643c`, including generated code and each
linked runtime image.

### Host D8 source-map instrumentation

The standalone Node package contains a second generated compiler layout with
`DebugHooks = 1`. Conditional two-byte `OUT (n),A` instructions report source,
declaration, structured-context, routine, semantic-dispatch, and target-adapter
IMAGE events. The host records and validates those events, then publishes D8
only after a valid NOBJ commit. The semantic transcript, NOBJ format, target
records, generated program, selected runtime, and language are unchanged.

At the D8 checkpoint, the shipping `DebugHooks = 0` layout measured 15,482-byte compiler
code plus 393 immutable bytes, for a 15,875-byte compiler core and 509 bytes of
headroom. Workspace remains 3,606 bytes, parser extent remains 9,216 bytes,
the largest generated program remains 1,040 bytes, and the selected proof
runtime remains 574 bytes. Its 2,345-byte producer proof executes 1,043,353
instructions in 10,196,561 T-states. A baseline/current binary comparison and
flat and banked host compiles keep the shipping compiler, semantic transcript,
generated publications, runtime, NOBJ, and Intel HEX bytes identical.

At that checkpoint, the instrumented layout measured 15,539 code bytes plus the same 393 immutable
bytes, for a 15,932-byte core. It adds no workspace or transcript storage. The
parser grows by 50 bytes to 9,266: 48 action bytes for eleven source marks, one
declaration mark, four pushes, six pops, and two routine marks, plus a two-byte
declaration mark in the retained parser. The semantic dispatcher adds seven
bytes: two trace instructions and the conditional success bridges required to
emit exactly one end event. Total instrumented compiler-core cost is therefore
57 bytes. The proof-owned target adapter adds one two-byte IMAGE event outside
the compiler-core account, increasing proof code/data from 2,345 to 2,347
bytes.

The complete instrumented producer proof executes 1,047,813 instructions in
10,245,645 T-states. Its compiler image fits the host proof map. Flat and
three-bank Node evidence validates original source pointers, CRLF and
synthesized part boundaries, balanced nested contexts, one source operation
followed immediately by another, exact normal/debug diagnostics, successful
compilation after failure, routine anchors, repeated visible addresses in
different physical banks, and byte-identical target artifacts.

The Node collector and D8 writer are host resources and add zero compiler code,
immutable compiler data, workspace, transcript, generated-program, and runtime
bytes. The CLI emits one sidecar for a flat target or one existing-schema D8
map per physical bank. Debug80 publishes flat NOBJ, HEX, and D8 as one
generation and validates the D8 document through its normal importer before
publication. Byte columns remain in the sidecar; the initial debugger path is
line-oriented.

A post-integration acceptance pass tightened host-only boundaries without
changing either compiler layout. D8 publication now replaces the complete
flat-or-banked sidecar group, including removal of obsolete bank files, and the
collector compares the ordered `$DF` stream with every compiler-adapter
`IMAGE` byte before publication. Provider-owned runtime and initialization
images remain intentionally outside that comparison and unattributed. These
events dominate host trace volume: the representative CRLF two-routine compile
reports 187 `$DF` callbacks for 13 semantic operations. The collector also
decodes the finalized variable-width semantic transcript independently and
requires every `$DD` key to name an actual operation boundary and the decoded
end to equal the semantic read cursor captured at `$DE`. These
checks add zero compiler, adapter, workspace, transcript, generated-program,
runtime, NOBJ, or HEX bytes.

### Retired checkpoints: `print` and bounded-string operators

The measurements in this section record superseded implementation checkpoints.
Neither `print` nor the bounded-string operators described here belong to the
current language.

The next pass began from `proofs/chapter21-target-z80-slice-proof.json` at
standalone HEAD `a782cc9dc83c395e4b7fc7dd536584d7541f0a4f`. The baseline was
reproduced before editing: 15,482 compiler-code bytes plus 393 immutable
bytes, for a 15,875-byte core and 509 bytes of headroom. Workspace was 3,606
bytes; the selected proof runtime was 574 bytes; proof code and data were 2,345
bytes; and the proof executed 1,043,353 instructions in 10,196,561 T-states.
Its Chapter 18 NOBJ was 7,913 bytes and used 1,461 target-image bytes.

The compression pass introduced checked inline operands for tail diagnostics
and single-byte emission, then shared only register-contract-compatible parser
and backend tails. AZM's stack and register checker now treats a call to a
declared `noreturn` helper as a terminal control-flow edge. The helper's return
address can therefore select one following data byte without that byte entering
the caller's reachable instruction stream. The checker neither decodes that byte nor propagates reachability through the
tail. A conventional D8 disassembler still renders that inline data byte as an
instruction; this is a cosmetic listing limitation, not executable code or a
source-map error. Every generated program, semantic transcript, NOBJ, Intel HEX image, and
selected runtime remained byte-identical to the baseline. The final compressed
checkpoint, measured with the same manifest before the `print` edits, contained
15,375 code bytes plus 393 immutable bytes, or 15,768
core bytes, leaving 616 bytes of headroom. Workspace remained 3,606 bytes. A
relative branch that fit the target-enabled image but failed a retained
historical layout was restored to `JP`; both conditional compiler layouts and
all retained proof layouts therefore assemble strictly.

`print` is a predefined, result-free, failable call rather than a statement or
grammar production. The ordinary parser recognizes its name and accepts any
bounded-string capacity at that call site. The semantic transcript reuses the
retired operation byte 23 and carries the static capacity, source offset, and
existing three-byte failure state. The backend checks the stored logical
length against that capacity before calling a shared runtime helper. The helper
then sends bytes through the existing `writeOutputByte` vector and introduces
no System Service.

Fresh assembly of `proofs/chapter21-target-z80-slice-proof.json` measures
15,504 shipping compiler-code bytes plus 399 immutable bytes, or 15,903 bytes
of core and 481 bytes of headroom.
The instrumented proof in `proofs/flat-target-debug-z80-slice-proof.json`
measures 15,561 code bytes plus 399 immutable bytes, or 15,960 bytes of core.
Relative to the compressed checkpoint, `print` adds 129
code bytes and six immutable name bytes, for a 135-byte compiler-core delta.
This remained below the 150-byte review threshold after a focused pass reused
the retired dispatch slot and shared the no-argument failable-call tail with
ordinary services. The shared tail saves four core bytes and adds five compiler
instructions and 60 T-states to the retained console build; its NOBJ, Intel
HEX, and materialized-image hashes remain byte-identical. The earlier form
measured 156 added core bytes and was not retained. A generated bounds-trap
helper was rejected because it would trade scarce compiler-core bytes for
target bytes, and the only remaining shipping-layout `JP`-to-`JR` candidate
failed the retained parser layouts. Compiler workspace and the 511-byte
semantic payload capacity are unchanged.

Runtime identity `$0005` adds the 18-byte `PrintString` helper at offset 364.
`test/nobj.test.ts` measures the default-context canonical linked runtime at
382 bytes. `proofs/chapter21-target-z80-slice-proof.json` measures a 592-byte
selected runtime, while `proofs/stage9-conformance-z80-slice-proof.json`
measures the 614-byte historical direct-proof form. The
target-enabled producer proof remains 2,345 bytes and executes 1,043,067
instructions in 10,189,213 T-states. Its ordinary Chapter 18 source does not
call `print`; its larger 1,479-byte image and 7,931-byte NOBJ come from the
selected runtime revision. Generated-code length and instruction topology,
initialized-data contents, and source semantics remain unchanged, but the
larger runtime moves target placement and therefore changes layout-dependent
address operands, NOBJ, and Intel HEX bytes.

The `supports a measured TEC-1-style menu and value display` case in
`91b52cf4ccee824dda8f8f78fcf2fdb961acd25e:test/print.test.ts`, using that
test's fixed flat target and service addresses,
locks the following account. The retained console is a 1,034-byte source file. It uses
five static messages across four distinct capacities (`string[2]`,
`string[8]`, `string[20]`, and `string[40]`), three ordinary numeric-formatting
routines, and direct `print` calls for its banner, menu, labels, and newline.
It compiles in 311,823 instructions and 3,101,255 T-states, emits a 13,837-byte
NOBJ, uses 2,299 target-image bytes, and contains 1,706 generated code bytes and
158 total read-only bytes, of which 88 are aggregate constants. Execution of the word
choice produces the exact menu and `1234` display text.

This console needs no string comparison, search, or copy routine. Its three
formatter routines transform integers and belong to the separate
number-formatting tier. For this program, the measured non-output string-routine
count is zero. A later design decision added logical string equality and
widening string assignment because both operate on existing bounded values
without a new carrier or source type. Search, slicing, splicing, and `string[]`
remain deferred until a concrete program supplies requirements against which
they can be designed and measured.

The console uses four of the eight aggregate-type entries. A separate boundary
case in `91b52cf4ccee824dda8f8f78fcf2fdb961acd25e:test/print.test.ts` admits eight distinct bounded-string capacities
with `print` and rejects the ninth with the existing aggregate-type-capacity
diagnostic. This proves that `print` allocates no hidden wildcard type, but it
does not prove that eight entries suit every application. The capacity remains
eight for now, with no 48-byte workspace increase.

The bounded-string operator pass began at standalone HEAD
`91b52cf4ccee824dda8f8f78fcf2fdb961acd25e`. Measured baseline: 15,504
compiler-code bytes plus 399 immutable bytes, or 15,903 bytes of compiler core
with 481 bytes of headroom. Measured workspace: 3,606 bytes. The target-enabled
Chapter 18 proof selected a measured 592-byte runtime, emitted a measured
7,931-byte NOBJ using 1,479 image bytes, and executed a measured 1,043,067
compiler instructions in 10,189,213 T-states.

The pass adds logical equality between bounded strings of any capacities through the
existing `=` operator. It compares length and payload rather than representation
or alias identity. Existing assignment syntax now admits `string[M]` on the
right of `string[N]` when `M <= N`; the generated operation validates both
complete regions and the source length before copying, then clears the unused
destination tail. Narrowing assignment remains invalid. Routine parameters and
results retain exact type identity because they transfer aliases rather than
values. The grammar and generated LL(1) tables are unchanged. Semantic
operations 26 and 27 reuse retired typed-dispatch slots and each occupy five
transcript bytes.

The operator experiment was measured while it remained in the working tree,
then removed without an archived source checkpoint. Its transient counts are
therefore not published as reproducible measurements. The retained conclusion
is qualitative: the operators consumed compiler core and runtime bytes that the
more general `string[]` facility could replace with source routines.

The uncommitted operator experiment distinguished equality across capacities,
embedded zero bytes, empty strings, widening assignment, destination-tail
clearing, narrowing and ordering rejection, grouped operands, nested calls,
field and transient sources, corrupt lengths and carrier regions, capacity-253
boundaries, banked calls, D8 decoding, and normal/debug NOBJ identity. Those
fixtures were removed with the operators, so this paragraph records design
history rather than current proof evidence.
The pass also repairs constant `*`, `/`, and `mod` folding so the result value
cannot contaminate its type metadata. `find`, slice, splice, string-literal call
arguments, and capacity-widening aggregate parameters are not part of this pass.

### Parameter-only `string[]` and retirement of the string intrinsics

The `print` and bounded-string-operator checkpoints above are retained as
historical measurements, not as the current language. The next experiment
showed that a source-defined routine can accept `string[]` safely without a
runtime helper. The parameter is one source binding represented internally by
an address and the concrete argument capacity. A caller may pass any
`string[N]` storage path or forward another `string[]`. The callee may read
`.length` and read or write existing indexed bytes; each access validates the
dynamic complete extent and stored length. The view owns no storage and cannot
be used as a variable, constant, field, array element, local, result,
whole-object assignment operand, or comparison operand.

The semantic transcript adds measured fixed-width operations 108, 109, and
110 for open-string length, indexing, and call preparation. An open parameter
uses a measured three activation bytes: two for its address and one for its
actual capacity. Forwarding preserves both. The grammar admits the empty bound
only in a formal parameter, and the implementation allocates no aggregate-type
entry for the view. Tests execute capacities 1, 5, 12, and 253, embedded zero
bytes, mutation, forwarding through an abbreviated forward body, nested calls,
recursion, transient aggregate results, mixed scalar and open parameters, a
corrupted stored length, and a two-bank normal/debug build. They also reject
every owning or result position, whole-object assignment and comparison through
the view, and forwarding an open view across a bank boundary. `print` remains
available as an ordinary user-defined routine name.

After that proof, the predefined `print`, logical bounded-string equality, and
cross-capacity bounded-string assignment were removed. Exact-capacity string
assignment remains ordinary exact-type aggregate copying. A source library can
implement output and comparison over `string[]`; cross-capacity copying remains
deferred until the language defines a length-changing operation and its source
semantics. At that checkpoint, string literals remained contextual static
initializers, so a direct call such as `emit("hello")` was not admitted and
required a named concrete bounded-string constant. A later increment below
adds the narrower direct `string[]` argument position without changing the open
carrier.

The focused post-correctness compression pass removes a measured 128 compiler
code bytes. It walks retained parameter records directly, shares the concrete
and open `.length`, index, and backend-check tails, shortens proven branches,
shares existing two-byte templates, and removes redundant parser state loads.
The semantic operation numbers and widths remain fixed. The pass changes no
immutable compiler data, workspace, semantic transcript, generated program,
runtime, NOBJ, HEX, or D8 bytes. CLI builds of `examples/hello.nu` and
`examples/tec1-console.nu` reproduce the saved pre-compression NOBJ and D8
sidecars byte for byte.

A later production-layout gate removes another measured 137 compiler-code
bytes. Conditional assembly excludes the obsolete scalar-forward expression
parser (105 bytes), legacy `else fail` token helpers (16 bytes), and two
non-streaming proof entry wrappers (16 bytes) from the shipping and
instrumented layouts. The historical non-streaming proofs retain their entry
wrappers. Their selected compiler layouts also omit the 121 bytes of legacy
parser code. A local comparison against clean baseline
`89f51a61267ff5ff9e0fd59c071f4c5220710abd` built each example with
`test/fixtures/host-target.json` and requested NOBJ, HEX, and D8 output. The
post-gate files reproduce all six baseline SHA-256 values:

```text
8cbe545ed1feb4415aac0f778d8960fa758e6177f5af193f41e639eb496e57fd  hello.nobj
94fe3f78cb7c9d66bf5a01a5844c8ab255b6116b206aeaa9ad0f08607547c0ff  hello.hex
f3b61adfec15eeaaf91683e22b39243077dfea0e492012cbda32ffadbdb0d1c7  hello.d8
af9003849ac15b894e1c1acd531a194edd6611eca0fb45a747dad061ea4d4f99  tec1.nobj
5fabecabbe79658c3a2ad78a3db655f00fdfb82be3728278ed53c8bff939146b  tec1.hex
b0811c6ec8eb12b08d56c922ac41ffb5c445287d4ca3d18e70fd5f09c026d8a1  tec1.d8
```

At production-layout commit `e4f231d83bcfb38426bfbb8d8e08aa9093aaa936`,
`proofs/chapter21-target-z80-slice-proof.json` measured the shipping assembly at
15,726 compiler-code bytes plus 393 immutable bytes, or 16,119 compiler-core
bytes with 265 bytes of 16 KiB headroom. It also measured 3,607 bytes of
complete target workspace, a one-byte increase from the earlier compressed
checkpoint. `proofs/flat-target-debug-z80-slice-proof.json` measured the
instrumented host image at 15,783 code bytes plus 393 immutable bytes, or
16,176 core bytes, inside its separate 17 KiB host-only core reservation.
`test/nobj.test.ts` measures the canonical runtime at identity `$0004` and 364
bytes. The target-enabled Chapter 18 proof selects 574 runtime bytes;
the current assembly of `proofs/stage9-conformance-z80-slice-proof.json`
measures 14,006 compiler-code bytes, 393 immutable bytes, and the 596-byte
runtime used by that historical direct proof.

The intermediate source that combined all three retired features with
`string[]` was not retained as a reproducible checkpoint, so this account does
not publish an isolated compiler- or runtime-byte saving for their removal.
The current reproducible figures are the compiler and runtime measurements
above. `proofs/chapter21-target-z80-slice-proof.json` emits a measured
7,913-byte NOBJ with a 1,461-byte used image. It executes 1,044,685 compiler
instructions in 10,209,748 T-states before the focused compression pass and
1,044,583 instructions in 10,208,611 T-states after it; proof code and data
measure 2,345 bytes in both builds.

### Production single-unwind diagnostic checkpoint

The production streaming compiler now has one nonlocal exit for compile-time
diagnostics. `CompileTargetAggregateCallParts` saves its incoming stack pointer
before parsing. `CompilerSetDiagnostic` records the same code, part, offset,
line, and column as before, restores that pointer, and returns directly to the
public caller. After parsing succeeds, the entry pushes `AbortTargetProgram` as
a synthetic continuation and saves the new stack pointer before generation.
A generation diagnostic therefore returns through exactly one guarded abort
path. Successful generation discards the synthetic word normally.

The late MAP and COMMIT path remains a deliberate exception to catch-owned
abort. Fixup resolution has already set `TargetOutputBank` to the closed value
before either operation, although the sink transaction remains open. A MAP or
COMMIT failure therefore calls `TargetSinkAbort` locally before raising its
diagnostic; the synthetic continuation observes the closed bank selector and
does not call it again. The counting proof adapter distinguishes zero aborts
before BEGIN, one abort during generation, one abort after either MAP or
COMMIT, and a successful compilation immediately after those failures. It also
checks the exact public stack pointer after representative parse, generation,
MAP, COMMIT, and success returns. Historical non-streaming layouts retain their
ordinary carry-propagation boundaries.

Measured after this checkpoint, the shipping image is 15,744 compiler-code
bytes plus 393 immutable bytes, or 16,137 compiler-core bytes with 247 bytes of
16 KiB headroom. Workspace is 3,609 bytes; the new saved stack pointer accounts
for its two-byte increase. The instrumented image is 15,801 code bytes plus 393
immutable bytes, or 16,194 core bytes, leaving 1,214 bytes in its separate 17
KiB reservation. The expanded normal proof is 2,487 bytes and executes
1,072,121 instructions in 10,485,046 T-states. The instrumented proof is 2,489
bytes and executes 1,076,761 instructions in 10,536,112 T-states. These timing
figures are not a before-and-after compiler-speed comparison: the checkpoint
adds a complete failing COMMIT compilation to the proof workload. The selected
runtime remains 574 bytes. Existing flat, loaded, and banked golden tests retain
their exact NOBJ, generated-image, runtime, HEX, and D8 results.

This checkpoint changes only the terminal diagnostic route. Existing
`RET C`, `JR C`, and `JP C` propagation remains in place and is unreachable
after a production diagnostic. Removing those sites is a separate measured
migration, not part of this checkpoint.

### Typed-generation diagnostic propagation removal

The first removal stage starts from checkpoint
`fb043c986622720b478ebb99b76830c6dbfce677`. It covers the typed expression,
aggregate call, structured-control, and aggregate driver modules. Their
fallible generation calls either reach `CompilerSetDiagnostic` through the
streaming emitter or raise an internal compiler diagnostic directly. Neither
path returns in the production layout. The source contains 217 corresponding
`RET C` sites; 208 are active in the shipping layout and 209 in the
instrumented layout. `CompilerDiagnosticReturns` retains every return in the
historical non-streaming layouts.

Measured after this stage, shipping compiler code is 15,536 bytes. Immutable
data remains 393 bytes, so compiler core is 15,929 bytes with 455 bytes of 16
KiB headroom. The instrumented compiler is 15,592 code bytes plus 393 immutable
bytes, or 15,985 core bytes, leaving 1,423 bytes in its 17 KiB reservation.
Workspace remains 3,609 bytes and the selected runtime remains 574 bytes.

With the same expanded proof workload, the shipping proof executes 1,070,342
instructions in 10,476,151 T-states: 1,779 fewer instructions and 8,895 fewer
T-states than the single-unwind checkpoint. The instrumented proof executes
1,074,971 instructions in 10,527,162 T-states, reductions of 1,790 instructions
and 8,950 T-states. Proof code and data remain 2,487 bytes in the shipping
layout and 2,489 bytes in the instrumented layout. Fresh CLI builds of both
examples reproduce the six NOBJ, HEX, and D8 SHA-256 values listed above.
Parser propagation and the general emit-sink layer are unchanged and remain
separate stages.

### Streaming emit-sink diagnostic propagation removal

The second removal stage starts from typed-generation checkpoint
`b93e907e95122bf053274648bd32485112b829d1`. It covers the general Z80 emitter
and target-output adapter. Those files contain 160 source-level `RET C` sites;
51 are active in each production streaming layout. Output-capacity, target
configuration, adapter, patch, and fixup failures already enter the nonlocal
diagnostic path. Historical encoders retain all 160 returns through
`CompilerDiagnosticReturns`.

Measured after this stage, shipping compiler code is 15,485 bytes. With 393
immutable bytes, compiler core is 15,878 bytes and 506 bytes remain in the 16
KiB shipping region. The instrumented compiler is 15,541 code bytes plus 393
immutable bytes, or 15,934 core bytes, leaving 1,474 bytes in its 17 KiB host
reservation. Workspace remains 3,609 bytes and the selected runtime remains 574
bytes.

The unchanged expanded shipping proof executes 1,067,291 instructions in
10,460,896 T-states, 3,051 instructions and 15,255 T-states fewer than the
typed-generation checkpoint. The instrumented proof executes 1,071,920
instructions in 10,511,907 T-states, the same reductions. Proof code and data
remain 2,487 and 2,489 bytes. Fresh CLI builds again reproduce the six saved
NOBJ, HEX, and D8 hashes. Parser propagation is unchanged and remains the next
stage.

### Parser diagnostic-return removal

The third removal stage starts from emit-sink checkpoint
`baa4df3bae0d8a5b087089623227901b7fc8777b`. It classifies the `RET C` sites in
the LL(1) engine and actions, scalar and aggregate expression parsers,
structured-control parser, aggregate parser, and their common parser driver.
All 746 source-level sites remain in historical layouts. The production build
omits only returns reached after a fallible parser or semantic-sink operation;
tokenizer EOF, character comparisons, symbol-search results, and predictive
selection carry remain unchanged.

The shipping compiler now measures 15,190 code bytes plus 393 immutable bytes,
or 15,583 compiler-core bytes with 801 bytes of 16 KiB headroom. This is a
measured 295-byte core reduction from the emit-sink checkpoint. The instrumented
compiler measures 15,246 code bytes plus 393 immutable bytes, or 15,639 core
bytes, leaving 1,769 bytes in its 17 KiB reservation. Workspace remains 3,609
bytes and the selected runtime remains 574 bytes.

The unchanged expanded shipping proof executes 1,058,364 instructions in
10,416,261 T-states, reductions of 8,927 instructions and 44,635 T-states. The
instrumented proof executes 1,062,993 instructions in 10,467,272 T-states, with
the same reductions. Proof code and data remain 2,487 and 2,489 bytes. Fresh
CLI builds reproduce the six saved NOBJ, HEX, and D8 hashes. This stage removes
diagnostic-return instructions only; conditional diagnostic branches and their
cleanup shims remain candidates for later, separately measured work.

### Parser conditional diagnostic-branch removal

The next stage starts from parser-return checkpoint
`f43235243bf9341e6cb43176b1a26d0de497db38`. It classifies conditional carry
branches in the typed-expression parser, aggregate-call parser, common scalar
parser, aggregate parser, and LL(1) parser and actions. Production layouts omit
72 branches whose preceding call either raises a diagnostic through
`CompilerSetDiagnostic` or succeeds. Historical layouts retain them. Carry
branches that report tokenizer EOF, symbol lookup, name comparison, arithmetic
or capacity results, and LL(1) terminal classification remain active.

Shipping compiler code now measures 15,068 bytes. Immutable data remains 393
bytes, so compiler core is 15,461 bytes with 923 bytes of 16 KiB headroom. This
is a measured 122-byte core reduction from the parser-return checkpoint. The
instrumented compiler measures 15,124 code bytes plus 393 immutable bytes, or
15,517 core bytes, leaving 1,891 bytes in its 17 KiB reservation. Workspace
remains 3,609 bytes and the selected runtime remains 574 bytes.

The expanded shipping proof executes 1,056,478 instructions in 10,402,378
T-states, reductions of 1,886 instructions and 13,883 T-states. The
instrumented proof executes 1,061,107 instructions in 10,453,389 T-states,
with the same reductions. Proof code and data remain 2,487 and 2,489 bytes.
Fresh CLI builds reproduce the six saved NOBJ, HEX, and D8 hashes. The cleanup
labels reached only by these historical branches remain in this checkpoint;
their removal is the next separately measured stage.

### Parser diagnostic cleanup removal

The cleanup stage starts from conditional-branch checkpoint
`0bf3f0dac73c2addaa2cd7241038dac13f420261`. It conditionally removes the
stack-restoration and carry-return blocks whose only incoming edges are the 72
historical branches classified in the preceding stage. Production source-error
and capacity paths still enter `CompilerSetDiagnostic` at the original point;
local carry-result paths retain their existing cleanup.

Shipping compiler code measures 14,976 bytes plus 393 immutable bytes, or
15,369 bytes of compiler core with 1,015 bytes of 16 KiB headroom. The measured
reduction is 92 compiler-code bytes. The instrumented image measures 15,032
code bytes plus 393 immutable bytes, or 15,425 core bytes with 1,983 bytes left
in its 17 KiB reservation. Workspace remains 3,609 bytes and the selected
runtime remains 574 bytes.

The shipping and instrumented proofs retain the preceding checkpoint's exact
instruction and T-state counts because none of the removed instructions was
reachable. Proof code and data remain 2,487 and 2,489 bytes. The historical
layouts assemble and execute with their branches and cleanup blocks present.
Fresh CLI builds reproduce the six saved NOBJ, HEX, and D8 hashes.

### Generation-driver diagnostic-branch removal

The generation-driver stage starts from cleanup checkpoint
`f2912144749e9ad3c9438146c3b503309f68e2e6`. It removes eight production carry
branches after typed trap emission, target initialization, runtime/static-image
emission, and semantic dispatch, together with the trap-emission cleanup block
that those branches alone reached. Each called operation either succeeds or
raises a diagnostic through the armed generation continuation. Branches that
convert sink failure into a diagnostic, perform arithmetic or comparison, or
implement MAP and COMMIT rollback remain active.

Shipping compiler code now measures 14,949 bytes plus 393 immutable bytes, or
15,342 compiler-core bytes with 1,042 bytes of 16 KiB headroom. This stage saves
27 code bytes. The instrumented image measures 15,005 code bytes plus 393
immutable bytes, or 15,398 core bytes with 2,010 bytes left in its 17 KiB
reservation. Workspace remains 3,609 bytes and the selected runtime remains
574 bytes.

The shipping proof executes 1,056,413 instructions in 10,401,797 T-states, 65
instructions and 581 T-states fewer than the cleanup checkpoint. The
instrumented proof has the same reductions and executes 1,061,042 instructions
in 10,452,808 T-states. Proof code and data remain 2,487 and 2,489 bytes.
Historical layouts retain the ordinary branches and cleanup path. Fresh CLI
builds reproduce the six saved NOBJ, HEX, and D8 hashes.

### Checked inline-byte emission

The checked inline-byte stage starts from generation-driver checkpoint
`8f7271ffdf3284ae7e2a879a861c6215d1427d20`. Forty-three source sites had the
same checked sequence: load a fixed byte, call `EmitByte`, and propagate carry.
The replacement call stores the byte immediately after its call instruction.
Its shared helper reads that byte, retains the following instruction address on
the compiler stack, and calls `EmitByte`. Success returns to the retained
instruction address. In historical layouts, an ordinary carry failure discards
that address and returns to the enclosing routine's caller. Production output
failure still takes the nonlocal diagnostic continuation.

The initial helper sketch retained its continuation in `HL`, but the real
`EmitByte` contract clobbers `HL`; strict register checking rejected that form.
The retained ten-byte helper uses the stack instead. The AZM capability gate
now models the real `HL` clobber and both success and failure stack paths.

Only 23 converted sites are resident in the shipping layout. After paying for
the shared helper, shipping compiler code measures 14,936 bytes plus 393
immutable bytes, or 15,329 compiler-core bytes with 1,055 bytes of 16 KiB
headroom. The measured saving is 13 code bytes. The instrumented image measures
14,992 code bytes plus 393 immutable bytes, or 15,385 core bytes with 2,023
bytes left in its 17 KiB reservation. Workspace remains 3,609 bytes and the
selected runtime remains 574 bytes.

The extra helper instructions trade compilation speed for resident space. The
shipping proof executes 1,057,362 instructions in 10,412,236 T-states, an
increase of 949 instructions and 10,439 T-states. The instrumented proof has
the same increase and executes 1,061,991 instructions in 10,463,247 T-states.
Proof code and data remain 2,487 and 2,489 bytes. The inline data bytes can
appear as instructions in a raw compiler disassembly; they do not affect D8
source attribution or operation-key decoding. Fresh CLI builds reproduce the
six saved NOBJ, HEX, and D8 hashes.

### Indexed inline-pair emission

The indexed inline-pair stage starts from checked inline-byte checkpoint
`7e5ee504f6813b80c52b038b43ab57dd17713d4b`. Thirty-one source sites loaded
a fixed two-byte template and called `EmitPair`; thirty of those sites are
resident in the shipping layout. Each replacement stores a one-byte table
index after the call. The shared helper retains the following instruction
address on the compiler stack, resolves the index in a fourteen-entry table,
and enters the existing `EmitPair` path. Dynamic-template calls and tail jumps
still pass their original `HL` pointers.

A direct two-byte inline operand was rejected during the prototype. AZM's
strict contract analysis skips the established one-byte operand after a
nonreturning helper call, but it decoded the second byte as compiler code. In
particular, an inline `$DD,$6E` appeared to modify `IX`. The retained indexed
form uses the already-proved one-byte convention and requires no weaker
register contract. Four two-byte templates with no remaining users were then
removed.

Shipping compiler code measures 14,911 bytes. With 393 immutable bytes,
compiler core is 15,304 bytes and 1,080 bytes remain in the 16 KiB region. The
measured saving is 25 code bytes. The instrumented image measures 14,967 code
bytes plus 393 immutable bytes, or 15,360 core bytes, leaving 2,048 bytes in
its 17 KiB reservation. Workspace remains 3,609 bytes and the selected runtime
remains 574 bytes.

The table lookup adds work to every converted emission. The shipping proof
executes 1,057,884 instructions in 10,416,296 T-states, increases of 522
instructions and 4,060 T-states. The instrumented proof has the same increases
and executes 1,062,513 instructions in 10,467,307 T-states. Proof code and data
remain 2,487 and 2,489 bytes. The complete functional proof set retains the
same generated program, runtime, NOBJ, HEX, and D8 results.

### Remaining fixed diagnostic tails

The fixed diagnostic-tail stage starts from indexed inline-pair checkpoint
`913afdf7732f2767a23e406ec5c5e1a564b4e74a`. Twenty source sites still
loaded a fixed diagnostic byte and jumped to `CompilerSetDiagnostic`. They now
use the existing `SetDiagInline` helper. Only one of those bytes is resident in
the shipping layout, so shipping compiler code falls to 14,910 bytes. With 393
immutable bytes, compiler core is 15,303 bytes and 1,081 bytes remain in the
16 KiB region. The instrumented image measures 14,966 code bytes and 15,359
core bytes, leaving 2,049 bytes in its separate reservation. The historical
Stage 8 and Stage 9 layouts each save two code bytes. Four legacy sites retain
their direct jumps because their smallest proof layouts do not include the
shared helper contract.

The full shipping and instrumented proofs keep the preceding instruction and
T-state counts because they do not enter the converted diagnostic sites. The
packed Stage 7 proof exercises those paths and measures twelve more compiler
instructions and 174 more T-states. Generated program, runtime, NOBJ, HEX, and
D8 results remain unchanged.

Two nearby prototypes were rejected. Fixed token and Z80-opcode tails cannot
store their raw values after a nonreturning call because multi-byte opcode
values desynchronise AZM's strict routine decoder; an indirect encoding costs
at least the byte it would save. Sharing four open-string type guards saved
three additional production bytes but added 59 compiler instructions and
1,062 T-states to the target proof. The direct guards remain.

### Production inline-byte return path

The production-only return-path stage starts from fixed diagnostic-tail
checkpoint `ade652678d9cd85a3643a3c1a88e0195856eed21`. The resuming
`EmitByteInlineChecked` helper retains its full carry-return path in historical
layouts. In the production layout, an emission diagnostic takes the nonlocal
compiler exit and cannot return to the helper. The helper can therefore jump
to `EmitByte` after placing the corrected continuation on the stack; the
ordinary `EmitByte` return resumes the enclosing routine.

The production branch is three code bytes smaller. Shipping compiler code is
14,907 bytes. With 393 immutable bytes, compiler core is 15,300 bytes and
1,084 bytes remain in the 16 KiB region. The instrumented image measures
14,963 code bytes and 15,356 core bytes, leaving 2,052 bytes in its separate
reservation. Workspace remains 3,609 bytes and the selected runtime remains
574 bytes.

The shipping proof executes 1,057,695 instructions in 10,412,887 T-states,
reductions of 189 instructions and 3,409 T-states. The instrumented proof has
the same reductions and executes 1,062,324 instructions in 10,463,898
T-states. Proof code and data remain 2,487 and 2,489 bytes. Generated program,
runtime, NOBJ, HEX, and D8 results remain unchanged.

### Keyword table bound

The keyword-bound correction starts from inline-byte checkpoint
`7790c69ec3d3801867d8cb7865ddff8300a92480`. `KeywordTable` contains 33
physical entries, but its scan count was 34. A non-keyword identifier therefore
examined one extra pseudo-entry beginning at the punctuation table. The first
byte of that table is `"="`, so the extra comparison could not classify a
valid Nucleus name as a keyword, but it performed an invalid table traversal on
every ordinary name. `KeywordCount` now matches the physical entry count. A
static test locks the count, and an execution test distinguishes every exact
keyword from the corresponding identifier with an added `x`.

The correction changes no resident bytes. Shipping compiler code remains
14,907 bytes and compiler core remains 15,300 bytes, with 1,084 bytes of 16 KiB
headroom. Workspace remains 3,609 bytes and the selected runtime remains 574
bytes. The shipping proof executes 1,055,198 instructions in 10,393,365
T-states, reductions of 2,497 instructions and 19,522 T-states. The
instrumented proof has the same reductions and executes 1,059,827 instructions
in 10,444,376 T-states.

A high-bit-terminated keyword table was measured and rejected. It removed 33
immutable length bytes but added eight scanner-code bytes, for a net 25-byte
core saving. Without the length prefilter, the scanner compared each name
against keyword characters that the current representation skips. The shipping
proof added 120,085 instructions and 1,245,777 T-states, and several bounded
historical proofs exceeded their execution budgets. The length-prefixed table
remains.

### Semantic operand preservation

The semantic-operand stage starts from keyword-bound checkpoint
`60920ef929ea5593137566f2bf054091a6de3867`. Eleven source sites preserve
`HL` around `SemanticSinkPut`; seven are resident in the production compiler.
A six-byte production-only wrapper replaces their five-byte local
push/call/pop sequences with three-byte calls. Historical layouts retain the
original sequences and therefore keep their code placement and execution
results.

Shipping compiler code measures 14,899 bytes. With 393 immutable bytes,
compiler core is 15,292 bytes and 1,092 bytes remain in the 16 KiB region. The
measured saving is eight code bytes. The instrumented image measures 14,955
code bytes and 15,348 core bytes, leaving 2,060 bytes in its separate
reservation. Workspace remains 3,609 bytes and the selected runtime remains
574 bytes.

The wrapper adds one compiler call and return whenever a converted operand is
published. The shipping proof executes 1,055,336 instructions in 10,395,228
T-states, increases of 138 instructions and 1,863 T-states. The instrumented
proof has the same increases and executes 1,059,965 instructions in 10,446,239
T-states. Generated program, runtime, NOBJ, HEX, and D8 results remain
unchanged.

### Final relative helper tails

The branch pass starts from semantic-operand checkpoint
`d25551d4d0907d050b1b8e7adc022c599ff5a4f0`. A fresh normal/debug listing
census found eight absolute jumps with a relative encoding in range. Six had
displacements between 119 and 127 bytes in magnitude and remain absolute. The
two retained changes enter `EmitByte` at −47 bytes and `EmitPair` at +77 bytes,
with the same safe classification in both production images.

Shipping compiler code measures 14,897 bytes. With 393 immutable bytes,
compiler core is 15,290 bytes and 1,094 bytes remain in the 16 KiB region. The
instrumented image measures 14,953 code bytes and 15,346 core bytes, leaving
2,062 bytes in its separate reservation. Workspace remains 3,609 bytes and the
selected runtime remains 574 bytes.

The proof instruction counts are unchanged. Relative jumps take two more
T-states than absolute jumps, so the 248 executed helper transfers add 496
T-states. The shipping proof executes 1,055,336 instructions in 10,395,724
T-states; the instrumented proof executes 1,059,965 instructions in 10,446,735
T-states. Generated program, runtime, NOBJ, HEX, and D8 results remain
unchanged.

### Bounded-text construction through open views

This increment starts from checkpoint
`e38291d665938bcd93e02d5ac85946944cbdd178`. The measured baseline is 14,897
compiler-code bytes plus 393 immutable bytes, or 15,290 compiler-core bytes,
with 1,094 bytes of 16 KiB headroom. Workspace is 3,609 bytes. The selected
proof runtime is 574 bytes. The target-enabled proof occupies 2,487 bytes and
executes 1,055,336 instructions in 10,395,724 T-states.

The retained language surface puts both construction properties on the
parameter-only `string[]` view. `.capacity` returns the actual capacity carried
by the binding. `.length` remains readable and becomes a checked assignment
target on that view. Concrete `string[N]` paths retain read-only `.length` and
do not expose `.capacity` directly. A concrete object can still bind to an
ordinary source routine with a `string[]` parameter, so this distinction keeps
construction capacity-polymorphic without duplicating concrete and open
compiler paths.

The compiler assigns private semantic operation 111 to open-string capacity;
its complete transcript width is two bytes. Operation 112 performs checked
open-string resize and has a four-byte width. A boundary proof fills all 511
semantic payload bytes with 98 operations, including 30 resize operations; the
next resize is rejected before publication. No transcript capacity changed.

Fresh production assembly measures 15,069 compiler-code bytes and 401
immutable bytes, or 15,470 compiler-core bytes. The measured feature cost is
180 core bytes, leaving 914 bytes of 16 KiB headroom. The partition is 107
parser and type-checking bytes, four semantic-dispatch bytes, 61 backend bytes,
and the eight immutable bytes in `capacity`. Workspace grows by two bytes to
3,611. The instrumented compiler is 15,125 code bytes plus 401 immutable bytes,
or 15,526 core bytes in its separate reservation.

The canonical runtime advances to identity 5 and measures 390 bytes, 26 bytes
above identity 4. The selected target proof runtime is 600 bytes. The resize
helper validates the complete region, old length, and new length before it
writes. It clears a shrinking tail and stores the new length last. The existing
bounds trap carries the source location, so the runtime service table and
public failure codes do not change.

D8-attributed executable ranges measure 76 generated bytes for a complete
open `.capacity` statement and 120 bytes for a complete open `.length`
assignment statement, including carrier preparation, region checks, and trap
lowering. The corresponding direct concrete properties are absent and generate
no code: concrete `.capacity` and writable concrete `.length` are positioned
type errors. The largest retained generated-program proof remains 1,040 bytes.
The accepted Chapter 18 target image uses 1,487 bytes after the 26-byte runtime
increase.

A real inline-resize prototype assembled the resize algorithm from ordinary
Z80 mnemonics, emitted it at each assignment site, and passed all 16 focused
construction proofs. It measured 15,502 compiler-core bytes, 32 bytes more than
the retained helper design, and increased the resize statement range from 120
to 147 bytes. The inline algorithm itself is 30 bytes, replacing a three-byte
runtime call and adding 27 generated bytes per site. Removing the then-unused
helper would recover 26 runtime bytes. The shared helper uses 29 target bytes
for one resize site, one byte fewer than the inline algorithm; each additional
site widens that advantage by 27 bytes. The helper design also preserves 32
bytes of the binding compiler-core budget and is retained.

An earlier prototype exposed both properties on concrete strings as well as
open views. It measured a 280-byte compiler-core increase, including 151 parser
and type bytes, four dispatch bytes, 117 backend bytes, and eight immutable
bytes. Its first runtime helper measured 39 bytes and used five workspace
bytes. The open-view design saves 100 compiler-core bytes, three workspace
bytes, and six runtime bytes while retaining the source-library use case.

`examples/text.nu` contains ordinary `clear` and `appendByte` routines.
`examples/text-capacity.nu` supplies the optional ordinary `capacity` wrapper.
The compiler assigns no special meaning to those routine names. Tests compile
the files as earlier ordered source parts and cover several concrete
capacities, embedded zero bytes, full-buffer atomic failure, nested forwarding,
capacity 253, corrupted old lengths, exact memory-region boundaries, banked
execution, parser reset, and exact diagnostics.

The final target-enabled proof executes 1,051,848 instructions in 10,357,287
T-states. Proof code and data remain 2,487 bytes. The instrumented proof
executes 1,056,425 instructions in 10,407,726 T-states and retains 2,489 proof
bytes. The historical direct Chapter 18 and Stage 8 layouts measure 14,160 code
bytes plus 401 immutable bytes, 3,605 workspace bytes, and 622 runtime bytes;
their exact instruction and timing locks are 1,657,395 / 15,616,178 and
2,036,906 / 18,975,165 respectively.

### Complete-array views through open parameters

This increment starts from checkpoint
`77d75ea3de4f47f89b4c64db6327cab4210c48c5`. The measured baseline is
15,069 compiler-code bytes plus 401 immutable bytes, or 15,470 compiler-core
bytes, with 914 bytes of 16 KiB headroom. Workspace is 3,611 bytes. The
selected proof runtime is 600 bytes. The target-enabled proof occupies 2,487
bytes and executes 1,051,848 instructions in 10,357,287 T-states.

The retained source form is a parameter-only complete-array view, written
`T[]`. A binding carries the address of the first element and the concrete
element count as an unsigned 16-bit word. Its element type remains exact and
invariant. The view supports read-only `.length`, checked indexed reads, and
checked indexed writes. It does not own storage, rebind, resize, compare or
copy a whole array, represent a slice, or appear in variables, constants,
fields, array elements, locals, or routine results. Concrete arrays also gain
read-only `.length`. Nested arrays remain outside the implemented type system.

The selected compiler representation uses a contextual byte: bit 7 marks an
open-array parameter and the remaining seven bits retain the concrete element
type identifier. It consumes no aggregate-type entry. An interned descriptor
was considered but not retained: it is projected to add 50--90 compiler-core
bytes and would consume one of the eight shared aggregate-type entries for
each distinct open-array view. The contextual representation preserves those
entries for concrete records, arrays, and bounded strings.

Fresh production assembly measures 15,493 compiler-code bytes and 401
immutable bytes, or 15,894 compiler-core bytes. The measured feature cost is
424 code bytes and zero immutable bytes, leaving 490 bytes of 16 KiB headroom.
Workspace remains 3,611 bytes. The instrumented compiler is 15,549 code bytes
plus 401 immutable bytes, or 15,950 core bytes in its separate reservation.

The measured production-code partition is:

| Component                                |   Bytes |
| ---------------------------------------- | ------: |
| parameter activation publication         |      35 |
| path dispatch                            |      11 |
| concrete and open `.length` parsing      |      66 |
| open indexing parser                     |      30 |
| call compatibility                       |      55 |
| open-call publication                    |      53 |
| grammar/type actions and packed actions  |      54 |
| semantic dispatch table                  |       6 |
| parameter binding adjustment             |       2 |
| generated `.length` and indexing backend |      55 |
| generated open-argument backend          |      53 |
| `LD B,(IX+0)` target template            |       4 |
| **total**                                | **424** |

The semantic transcript assigns operations 113, 114, and 115 to concrete
array length, open-array length, and open-array indexing. Their complete widths
are three, two, and six bytes. Existing operation 110 retains its three-byte
forms for bounded strings and gains four-byte forms for concrete and forwarded
array arguments. The semantic payload capacity remains 511 bytes, and the D8
decoder validates the same widths and operation boundaries as the production
dispatcher. A boundary proof fills all 511 payload bytes with 172 operations,
including concrete array length, and rejects the first following operation
without publishing a D8 map.

An open-array activation uses two ordinary retained word bindings: address
nearest the return address and count below it. This costs 28 generated bytes in
the callee prologue. A concrete call prepares count and address in six bytes;
forwarding an existing view takes nine. After the carrier has been evaluated,
concrete `.length` takes five generated bytes and open `.length` takes eight.
A representative D8 build measured complete statement ranges of 60 bytes for
a concrete call, 66 for a forwarded call, 13 for a concrete-length assignment,
19 for an open-length assignment, and 81 for an open indexed read assignment.

The focused size pass retained the two existing word-binding operations instead
of adding a special four-byte activation binder, and made operation 110's width
mode-dependent instead of allocating another semantic opcode. A shared
fixed/open index tail recovered 19 bytes. A custom hidden-count binder grew the
compiler by 23 bytes and was rejected; retaining the count through call
compatibility grew it by one byte and was also rejected. The final cost exceeds
the preferred 220-byte estimate and the 260-byte review threshold, but remains
inside the hard 16 KiB gate with 490 measured bytes free. No unrelated
compression was mixed into this increment.

The selected runtime remains 600 bytes and byte-identical to the baseline;
there is no new service. The largest generated proof remains 1,040 bytes.
Shipping proof execution is 1,052,746 instructions and 10,364,340 T-states;
the instrumented proof is 1,057,323 instructions and 10,414,779 T-states.
Proof code/data remains 2,487/2,489 bytes. Historical Stage 9 and Stage 8
layouts measure 14,610 code bytes plus 401 immutable bytes and execute
1,658,495 / 15,624,796 and 2,037,227 / 18,977,822 instructions/T-states.

The retained count is a full word and is proved at 1, 255, 256, and 65,535
through recursive forwarding. That proves the parameter ABI and arithmetic;
it does not enlarge the separate complete-object allocation limit. With stack
establishment disabled, concrete `u8[255]`, `u8[256]`, and `u8[1024]` objects
compile. The default target reserves most writable memory for its stack, so its
available object capacity is correspondingly smaller.

### Recovery sequence after complete-array views

The recovery work starts at `ec4724bce90344a8737e5fde29b898b4cceacded`.
Measured production assembly is 15,493 compiler-code bytes plus 401 immutable
bytes, or 15,894 compiler-core bytes, leaving 490 bytes below 16 KiB.
Workspace is 3,611 bytes. The target-enabled proof uses the 600-byte selected
runtime, occupies 2,487 proof code/data bytes, and executes 1,052,746
instructions in 10,364,340 T-states. The instrumented compiler measures
15,549 code bytes plus 401 immutable bytes.

Recovery is divided into checkpoints so that a large projected total cannot
hide an unsafe or unproductive individual change:

1. Mechanical shortening and small shared tails were initially projected to
   recover 110--125 compiler-core bytes. A fresh source-and-listing census found
   that estimate included changes already retained, earlier rejected
   experiments, proof-only code, and branches that fit only the production
   layout. Each remaining family is therefore assembled and measured on its
   own. A family is retained only when it saves resident bytes without changing
   accepted source, diagnostics, semantic bytes, generated target artifacts,
   or runtime selection. Conditional branches must remain in range in the
   normal, instrumented, and retained historical layouts.
2. Unifying the parallel open-string and open-array paths is a 40--90-byte
   hypothesis. This follows the mechanical checkpoint because it changes
   shared parser and backend control flow and therefore needs a separate ABI,
   stack, and diagnostic-order review.
3. Dispatcher-side operand prefetch is a 120--170-byte hypothesis, not a
   committed design. It changes how semantic operands reach many handlers and
   must first prove every operation width, operation 110's mode-dependent
   forms, the exact semantic-start keys used by D8, and both flat and banked
   target output. It will be prototyped and accepted or rejected as one isolated
   checkpoint rather than mixed into local compression.

High-bit keyword packing is not part of this sequence. The previous measured
prototype saved 25 compiler-core bytes but added 120,085 compiler instructions
and 1,245,777 T-states to the target-enabled proof. It remains rejected unless
a new representation changes that measured trade.

Every checkpoint strictly assembles the shipping and instrumented compilers and
all retained proof layouts, reproduces the compiler census, and runs exact
diagnostic, semantic-transcript, NOBJ, HEX, D8, runtime, and generated-program
identity gates. Nested arrays remain a 50--100-byte hypothesis and signed
integer core support remains a 250--400-byte hypothesis; neither estimate is
treated as available headroom until the corresponding feature is implemented
and measured.

The mechanical checkpoint retains two changes. Seven handlers now share the
seven-byte sequence that reads one semantic operand into
`Stage7ArgumentCount`; replacing seven six-byte sequences with seven calls
saves 14 compiler-code bytes. Two absolute conditional branches in the
aggregate index parser have relative displacements of 116 and 97 bytes in both
shipping layouts and remain in range in every retained historical layout.
Their relative encodings save two more bytes. No instruction is represented as
raw `.db` or `.dw` data by this checkpoint.

Measured production code is 15,477 bytes plus 401 immutable bytes, or 15,878
compiler-core bytes, leaving 506 bytes below 16 KiB. The measured reduction is
16 code bytes. The instrumented compiler is 15,533 code bytes plus 401
immutable bytes. Workspace remains 3,611 bytes and the selected runtime remains
600 bytes. The shipping proof executes 1,052,768 instructions in 10,364,607
T-states; the instrumented proof executes 1,057,345 instructions in 10,415,046
T-states. The shared read adds 22 instructions and 267 T-states to each proof.

Three broader mechanical candidates were measured and rejected. A shared
semantic-byte-to-`C` helper recovered only six production bytes, added 146 more
shipping-proof instructions, and enlarged small historical layouts that had too
few callers to amortize it. Two additional relative branches fit the shipping
images but exceeded the signed displacement range by 6 and 12 bytes in the
historical Stage 8 and Stage 9 layouts. High-bit keyword packing remains the
separately measured rejection recorded above. The next recovery checkpoint is
therefore open-view unification, not another undifferentiated peephole sweep.

The first open-view unification checkpoint starts from
`d34a24eb86a96732cf21327117de6a147bc4f1fc`.
Concrete and forwarded string arguments publish a one-byte capacity, while
array arguments publish a two-byte count, so most of their apparent symmetry
does not survive an ABI-level comparison. Both paths did, however, finish by
locating the retained call frame, incrementing its argument-word count, and
returning success. The array path now enters the string path's existing
completion tail after publishing its word operand.

The source-level merge removes nine bytes; branch-layout effects make the
measured resident reduction eight bytes in every retained layout. Production
code is 15,469 bytes plus 401 immutable bytes, or 15,870 compiler-core bytes,
leaving 514 bytes below 16 KiB. The instrumented compiler is 15,525 code bytes
plus 401 immutable bytes. Workspace remains 3,611 bytes and runtime selection
remains 600 bytes. The target-enabled and historical proof instruction and
T-state counts are unchanged because their fixed census programs do not enter
the merged array-publication tail; focused concrete, forwarded, recursive,
banked, failure, transcript-boundary, and D8 open-view proofs execute it.

This checkpoint does not claim the original 40--90-byte hypothesis. The byte
capacity and word count forms deliberately retain different semantic widths,
activation layouts, region checks, and generated-code sequences. Further
unification must identify another identical boundary rather than erase those
differences. The next large isolated experiment remains dispatcher-side
operand prefetch.

The compiler-origin audit at `f9a3d18f363e0f42f87754618b327c7ed0e7ba7b`
classified every active address directory and every production bit operation.
The two active compiler code-pointer directories are `TypedOperationTable` and
`HybridLL1ActionDirectory`; both contain complete `.dw` addresses and neither
encodes metadata in a pointer. Source cursors, retained source-name pointers,
semantic cursors, output cursors, fixups, and call-frame pointers are also
complete words. The relocation gate now assembles the compiler at `$0000`,
`$0100`, `$8000`, and `$C000`, checks every code label's displacement, and
checks every word in both active code-pointer directories against the relocated
handler label.

The remaining production bit operations act on byte-sized counters, token or
type metadata, control flags, or a bounded target-storage offset. In the last
case, `ExpressionProgramAddress` uses one semantic bit to select initialized or
BSS storage and adds the remaining relative offset to a full 16-bit target
base. The target offset is bounded by the published 4,096-byte region; it is not
a compiler pointer, an absolute target address, or an assumption about compiler
origin. The audit found no compiler address mask, pointer tag, truncated code
address, or low/high-memory dependency.

The retained dispatcher-prefetch experiment stores its classification in a
separate twelve-byte bitset. The 96 handler-table entries remain untouched
full-width addresses. Marked handlers receive their first semantic operand in
`A`; unmarked handlers retain their existing reads. Operations 22 and 33 share
the `TypedDeclare8` entry, so both bits are set even though the shared entry
removes only one operand read. Focused open-array execution distinguishes this
alias: omitting operation 33's bit reaches the internal-operation diagnostic.

The earlier 120--170-byte estimate did not survive assembly. The measured
reduction is 16 compiler-code bytes. Production code is 15,453 bytes plus 401
immutable bytes, or 15,854 compiler-core bytes, leaving 530 bytes below 16 KiB.
The instrumented compiler is 15,509 code bytes plus 401 immutable bytes.
Workspace remains 3,611 bytes and the selected runtime remains 600 bytes. The
shipping proof increases from 1,052,768 to 1,062,343 instructions and from
10,364,607 to 10,425,959 T-states; the instrumented proof increases by the same
9,575 instructions and 61,352 T-states. This compilation-time cost is retained
because the project gives resident compiler bytes priority and generated
program execution is unchanged.

The helper does not amortize in the smaller historical module compositions.
Their typed-sink and compiler-core accounts each grow by 14 bytes because they
retain the common dispatcher but expose fewer converted handlers. Those layouts
remain proof fixtures rather than the shipping compiler, stay well below their
memory limits, and continue to assemble and execute. The production account is
the acceptance boundary for this optimization.

A fresh comparison against the pushed pre-experiment compiler used a program
that combines an open `u16[]` parameter, a counted loop, indexing, a `u16`
local, and a source call. Normal and instrumented builds produced identical
3,652-byte NOBJ streams, 4,096-byte materialized images, HEX output, and D8
maps. The NOBJ SHA-256 was
`5b93a1af62fde90346622fb9bc2cfef4e7ae23195c9c6e72c5a235c69b29289f`;
the materialized-image SHA-256 was
`6a4a1acac3434c1d60d4752ccad371af177b011b722b9f395f3da1e2d716d381`.

The following local-recovery pass starts from the later dispatcher checkpoint
`e3637574991d951db774f2a9b623cbbe9d420ae7`. This distinction matters because
the proposed work sheet used the earlier 15,469-byte open-view checkpoint as
its baseline. At `e3637574`, measured shipping code was 15,453 bytes and the
dispatcher experiment had already recovered the intervening sixteen bytes.

Each family was assembled under strict register contracts and retained only
after the shipping extent decreased. The complete proof harness and 191-test
suite passed after every retained family. The measured progression was:

| Retained family                              | Code bytes | Family delta | Instructions |   T-states |
| -------------------------------------------- | ---------: | -----------: | -----------: | ---------: |
| `e3637574` baseline                          |     15,453 |            - |    1,062,343 | 10,425,959 |
| streaming-only relative branches             |     15,447 |           -6 |    1,062,343 | 10,425,957 |
| shared writable-capacity subtraction         |     15,439 |           -8 |    1,062,439 | 10,427,253 |
| shared record-table indexing                 |     15,433 |           -6 |    1,062,487 | 10,427,901 |
| open-view and nested-array rejection helpers |     15,414 |          -19 |    1,062,672 | 10,429,835 |
| shared extent emission and local-width tail  |     15,401 |          -13 |    1,062,685 | 10,429,965 |
| retained-carrier and path-offset helpers     |     15,385 |          -16 |    1,062,701 | 10,430,125 |

The first family required one correction to the proposed site classification.
The `Stage7PathIndexRangeFailure` relative displacement is valid in both
streaming compilers but is +134 in the current Stage 8 and Stage 9 layouts. It
therefore uses the same `TargetStreamingOutput`-guarded `JR`/`JP` form as the
other layout-sensitive sites. No relative branch in this pass relies only on
the shipping placement.

The measured total reduction is 68 shipping code bytes. The final normal
compiler is 15,385 code bytes plus 401 immutable bytes, or 15,786
compiler-core bytes, leaving 598 bytes below 16 KiB. The instrumented compiler
is 15,441 code bytes plus 401 immutable bytes, leaving 1,566 bytes in its
separate reservation. Workspace remains 3,611 bytes and the selected proof
runtime remains 600 bytes. The shipping and instrumented proofs each add 358
compiler instructions and 4,166 T-states, or about 61 T-states per recovered
byte.

The current historical accounts are 14,514 code plus 401 immutable bytes for
both the Stage 8 and Stage 9 compositions. Stage 9 executes 1,684,890
instructions in 15,795,811 T-states; Stage 8 executes 2,066,406 instructions in
19,165,762 T-states. The complete packed-grammar proof executes 2,203,194
instructions in 20,349,926 T-states, with 9,298 parser bytes and 2,556 action
bytes. The legacy aggregate-only composition remains 9,353 code plus 254
immutable bytes and executes 377,231 instructions in 3,544,851 T-states.

A detached comparison against `e3637574` compiled a two-part program with an
open `u16[]` parameter, a counted loop, indexing, local `u16` values, and a
source routine call. Both versions produced the same 3,653-byte NOBJ stream,
4,096-byte materialized image, Intel HEX, D8 map, and 35-operation semantic
transcript. The NOBJ SHA-256 was
`b547d35a4b79a4d50219669e15cf1f20c5d94430e4652b2b72b42157807fce94`;
the image SHA-256 was
`ac1268639d85102280480d673f43869209b2cd16d77f24e7523fc2e9e3838848`;
the HEX SHA-256 was
`5b98477da59a228da901e29c5704dd5287b0699dfe63d9d66cd656bdb5861887`;
and the D8 SHA-256 was
`3a80f459dd0fc60f4fe3ee4822ce2cf22e09d72f22fe1a48f61ad8d35fd622b2`.
Normal and instrumented builds also produced identical NOBJ bytes. This pass
adds no raw instruction encodings, pointer tags, address truncation, workspace,
runtime support, or generated-program bytes.

### Signed integers and programmer-selected counted-loop types

The signed-integer milestone adds `i8` and `i16` as ordinary scalar types. It
uses exact negative constants, two's-complement storage, signed ordering,
truncating signed division, a remainder with the dividend's sign, checked
conversion among all four integer types, and signed indexes for concrete
arrays, open arrays, and bounded strings. Semantic operations 116, 117, and
118 carry checked conversion, signed division or modulo, and mixed `u8`/`i8`
pair promotion. The D8 semantic decoder uses the same operation widths as the
compiler dispatcher.

Counted loops retain the type declared by the programmer. A predeclared
counter may be `u8`, `u16`, `i8`, or `i16`; the compiler neither forces `i16`
nor silently widens a smaller counter. The start and bound must be compatible
with that declaration. The generated continuation check uses the declared
width and signedness. It computes the mathematical next value, then tests that
value against the loop bound before storing it. An overshoot ends the loop without a store; a
value that would continue must fit the counter type; otherwise it performs
`loop-range`.
The execution proof covers all four counter types, including `i16` from -100
through 100, traversal across zero, exact opposite endpoints, and positive and
negative overshoot at both signed widths.

The contemporaneous pre-feature record was 15,972 compiler-code bytes plus 410
immutable bytes, or 16,382 core bytes; workspace was 3,611 bytes. The selected
proof runtime was 837 bytes and used runtime identity 7. This checkpoint existed
only in the working feature branch: it has no detached revision or retained
proof lock and is not independently reproducible from the current tree.

The measured signed result is 16,110 compiler-code bytes plus 410 immutable
bytes, or 16,520 core bytes. It is 136 bytes above the 16,384-byte project gate.
The project owner explicitly selected language correctness before another
compression and organization pass, so the overrun is recorded rather than
hidden in another account. Workspace measures 3,613 bytes. The proof layout
places its workspace at `$6000`; that address is proof and deployment policy,
not part of the compiler ABI.

The measured selected proof runtime is 899 bytes. Canonical runtime identity 8
measures 689 bytes under the default link context; the historical Stage 8 and
Stage 9 proof context measures 921 bytes. The runtime revision adds checked
conversion, signed comparison, signed division and modulo, signed loop
continuation, and mixed-byte promotion. The ordinary target-enabled proof
publishes a 1,721-byte NOBJ with 881 used image bytes. The Chapter 18 proof
publishes an 8,238-byte NOBJ with 1,786 used image bytes. Its maximum generated
program remains 1,040 bytes.

The measured shipping proof executes 1,019,079 compiler instructions in
9,924,743 T-states. The instrumented compiler measures 16,166 code bytes plus
410 immutable bytes, or 16,576 core bytes, and executes 1,022,870 instructions
in 9,966,534 T-states. Both layouts use 3,613 workspace bytes and the same
899-byte selected proof runtime. Normal and instrumented compilation produce
identical target artifacts for the same signed source.

Runtime identity 8 changes the linked runtime length and helper offsets, so an
otherwise unaffected program is not byte-identical to its runtime-7 NOBJ, HEX,
or materialized image. Its source-level behavior and generated instruction
topology remain the regression boundary; absolute helper operands and later
target addresses relocate with the new runtime. Signed programs add generated
operations only where the new types require them.

The relocation gate assembles the complete compiler at `$0000`, `$0100`,
`$8000`, and the highest origin at which the image fits. It executes the public
compiler entry at every origin through a fixed external trampoline and checks
the same exact diagnostic, restored stack pointer, and relocated full-width
handler directories. A deployment may place the compiler anywhere in the Z80
address space where its code, immutable data, workspace, source, stack, and
target regions do not overlap. No compiler pointer may donate address bits to
metadata or depend on a repository proof origin.

### Nested fixed arrays and open row views

This milestone starts from `d2913fc73455478f83549335c49a8cfe4d18b346`.
The measured baseline is 16,110 compiler-code bytes plus 410 immutable bytes,
or 16,520 compiler-core bytes. Workspace is 3,613 bytes. The compiler was
already 136 bytes above the 16 KiB implementation gate after signed integers;
the project owner retained the language-first sequence for this milestone.

Array suffixes now form nested fixed arrays in source order. `u8[3][2]` is
three rows of exact type `u8[2]`, and the existing index operation implements
`grid[y][x]` as two independently checked selections. An omitted outer bound
remains a parameter-only view: `u8[][2]` accepts complete arrays whose elements
are exact `u8[2]` rows. An omitted inner bound, open-view storage, comma
indexing, and flattened multidimensional descriptors remain invalid.

The parser collects at most four concrete suffixes, then interns them from the
last suffix to the first. Every row uses the existing four-byte dynamic-type
descriptor and retained word extent. The first prototype overlaid the suffix
buffer on aggregate initializer storage. A retained non-streaming proof showed
that the same addresses contain the accumulated static image in that layout,
so the overlay was rejected. The selected implementation has a dedicated
26-byte workspace: a count, an outer-open flag, four entries containing a
length and source offset, a saved parser offset, and the complete
offset/line/column position of an omitted outer bound. The retained position
preserves the established diagnostic for an illegal owning or result `T[]` at
its closing bracket. No live state is overlaid.

Measured production assembly is 16,270 compiler-code bytes plus 410 immutable
bytes, or 16,680 compiler-core bytes. The feature adds 160 code bytes and no
immutable bytes. It adds 26 workspace bytes, for a final workspace extent of
3,639 bytes. The compiler is therefore 296 bytes above the 16,384-byte gate.
The instrumented compiler grows by the same 160 code bytes to 16,326 code plus
410 immutable, or 16,736 core bytes. The final code delta is ten bytes above
the approximate 150-byte review threshold because preserving the established
open-array diagnostic position requires retaining and restoring its complete
six-byte source position; the type representation and indexer remain
unchanged.

The selected runtime remains identity 8 and 899 proof bytes. The existing
target proof's runtime, generated program, NOBJ, and materialized output remain
unchanged. Its compiler execution rises from 1,019,079 instructions and
9,924,743 T-states to 1,025,324 instructions and 9,980,322 T-states because
every parsed type now enters and finishes bounded suffix collection. The
instrumented proof measures 1,029,115 instructions and 10,022,113 T-states.
The largest retained generated program remains 1,040 bytes.

Focused production proofs execute nested initialization, per-dimension reads,
writes and traps, row assignment, row parameters, `.length`, exact open-row
compatibility, type-table reuse and exhaustion, and the four/five-dimension
boundary. The retained non-streaming parser separately compiles and checks a
nested initialized object. Normal and instrumented banked builds produce
identical NOBJ and materialized bank bytes for the same nested-array program.
The implementation introduces no raw machine-instruction data, pointer tags,
origin assumptions, semantic operations, runtime helpers, or target services.

### Same-line `handle` diagnostic

This increment starts from the released 0.2.0 compiler at
`9d78d1535f3f597153d5b91afd849a4b3ac8c213`. It appends diagnostic 98 without
renumbering an existing diagnostic. The compiler now reports that `handle NAME`
must follow an eligible failable call on the same logical line when a direct
failable assignment or call reaches its newline without a consumer, when
`handle` begins an ordinary statement, and when an infallible assignment or
call is followed by `handle`. Categorically unsupported contexts, including a
scalar-local initializer, retain the general failure-context diagnostic.

The parser checks the four generated statement-dispatch nonterminals before
ordinary LL(1) prediction. Their ordinals form one masked group, which avoids a
new table. The failure-consumer action classifies newline, `else`, and `handle`
from their existing token ordinals. No token beyond the current logical line is
read or consumed. The accepted grammar, semantic transcript, generated Z80,
runtime, and published capacities are unchanged.

The final compressed implementation adds 25 production code bytes and no
immutable data or workspace. Production is 14,768 code bytes plus 398 immutable
bytes, or 15,166 compiler-core bytes, leaving 1,218 bytes below the 16 KiB
limit. The instrumented compiler is 14,824 code bytes plus 398 immutable bytes,
or 15,222 core bytes. Historical returning-diagnostic layouts measure 14,376
code bytes plus 398 immutable bytes, or 14,774 core bytes, with 3,623 workspace
bytes. Production workspace remains 3,613 bytes.

The flat proof executes 881,892 instructions in 9,517,580 T-states; the debug
proof executes 885,683 instructions in 9,559,371 T-states. The historical
Chapter 18 proof executes 1,417,919 instructions in 14,018,507 T-states, the
Stage 8 failure proof executes 1,723,350 instructions in 16,752,593 T-states,
and the complete LL(1) proof executes 1,920,597 instructions in 18,411,051
T-states. The largest increase is 1.08 percent in Stage 8 instructions and 0.85
percent in Stage 8 T-states. The selected proof runtime remains 899 bytes, the
historical runtime remains 921 bytes, the generated-program maximum remains
4,096 bytes, and the semantic transcript remains bounded at 511 payload bytes
and 255 operations; the exact-fill transcript proofs remain unchanged.

### Literal `while true` fallthrough

This increment starts from the same-line `handle` diagnostic commit
`3a28b85ad350b5ffa3d454192695e70527b0dd6d`. A value routine may now end after
an exact `while true` loop when no syntactic `exit` targets that loop. An exit
counts even when an earlier statement makes it unreachable. Exits targeting a
nested loop do not count. Parenthesized, compound, named, and dynamic Boolean
conditions retain the conservative fallthrough rule.

The one-pass parser marks a candidate only when the condition starts with the
`true` token and its completed semantic transcript contains exactly the one
operation expected for that literal. The active while frame records the
candidate in its existing mode byte. Finding an `exit` clears the mode byte of
the particular while frame selected by the existing nearest-loop search. No
AST, control-flow graph, delayed pass, workspace byte, semantic operation, or
generated Z80 is added.

After the feature-local size pass, the implementation adds 60 production code
bytes and no immutable data or workspace. Production is 14,828 code bytes plus
398 immutable bytes, or 15,226 compiler-core bytes, leaving 1,158 bytes below
the 16 KiB limit. The instrumented compiler is 14,884 code bytes plus 398
immutable bytes, or 15,282 core bytes. Historical returning-diagnostic layouts
are 14,436 code bytes plus 398 immutable bytes, or 14,834 core bytes, with
3,623 workspace bytes. Production workspace remains 3,613 bytes.

The flat proof remains 881,892 instructions and 9,517,580 T-states, and the
debug proof remains 885,683 instructions and 9,559,371 T-states. The historical
Chapter 18 proof is 1,417,934 instructions and 14,018,627 T-states; Stage 8 is
unchanged at 1,723,350 instructions and 16,752,593 T-states; the complete LL(1)
proof is unchanged at 1,920,597 instructions and 18,411,051 T-states. The
selected proof runtime remains 899 bytes, the historical runtime remains 921
bytes, the generated-program maximum remains 4,096 bytes, and transcript
capacities remain 511 payload bytes and 255 operations.

### Contextual string-literal arguments

This increment starts from the literal-`while true` commit
`ae0fe6c41a663e58b89737f0997dade4e3c78ed0`. A string literal may now occupy an
argument position selected by a `string[]` formal. Each occurrence creates one
distinct program-lifetime bounded-string object. Its inferred capacity is the
decoded length, except that an empty literal has capacity one. The ordinary
address-and-capacity carrier and the existing open-string operations are
unchanged. Literals remain invalid as general expressions, assignments,
results, locals, and concrete aggregate arguments.

The compiler appends anonymous objects to the existing declaration-ordered
read-only staging image. A flat target publishes them after named aggregate
constants. A banked target retains the source bank in a compiler-private final
byte until publication, restores the permanent zero, and emits the object only
in that bank. A literal cannot cross a bank boundary because the runtime
carrier has no bank identity. Each argument contributes six existing semantic
transcript bytes. Generated argument materialization is the same ten-byte
carrier sequence used for a named bounded-string object, and the complete
simple-call fixture remains 60 bytes. Target storage is `N + 2` bytes per
decoded literal, or three bytes for an empty literal. Runtime and provider
images gain no bytes.

The first sound prototype added 296 production core bytes. Its feature-only
compression pass shares named and anonymous read-only allocation and append
paths, keeps the literal bank and offset on the compiler stack in the nonlocal
production layout, and reuses the existing bank-check tail. The retained result
adds 185 production code bytes and no immutable data or workspace. Production
is 15,013 code bytes plus 398 immutable bytes, or 15,411 compiler-core bytes,
leaving 973 bytes below the 16 KiB limit. The instrumented compiler is 15,069
code bytes plus 398 immutable bytes, or 15,467 core bytes. Historical
returning-diagnostic layouts are 14,550 code bytes plus 398 immutable bytes, or
14,948 core bytes. Workspace remains 3,613 production bytes and 3,623
historical bytes. Semantic capacity remains 511 payload bytes and 255
operations, and the generated-program maximum remains 4,096 bytes.

The flat proof executes 881,986 instructions in 9,518,684 T-states, an increase
of 94 instructions and 1,104 T-states. Debug has the same increase at 885,777
instructions and 9,560,475 T-states. The historical Chapter 18 proof is
1,417,992 instructions and 14,019,163 T-states; Stage 8 is 1,723,424 and
16,753,301; the complete LL(1) proof is 1,920,739 and 18,412,361. Every
instruction and T-state change remains below 0.02 percent.

### Typed direct Z80 port access

This increment starts from standalone `main` at
`b06fc7eb331b04bc4cc9be6e1b09dc9ac4fbe7e6`. It adds the infallible predefined
operations `readPort(port as u16) as u8` and
`writePort(port as u16, value as u8)`. The port is the complete Z80 `BC` I/O
address. The backend emits direct `IN A,(C)` and `OUT (C),A` instructions, so
the feature adds no service ID, runtime vector, provider operation, runtime
byte, or writable runtime state.

The first correct prototype added 111 production code bytes and 19 immutable
name bytes, or 130 core bytes. Its feature-only compression pass encodes the
discarded-read, retained-read, and write forms as one two-bit selector, shares
the scalar-argument path, derives the result type from the selector's low bit,
and uses the final in-range relative parser branch. The retained result adds 96
production code bytes and 19 immutable bytes: production is 15,109 code plus
417 immutable, or 15,526 compiler-core bytes. This is 115 bytes above the
15,411-byte baseline and leaves 858 bytes below the 16 KiB limit. Debug is
15,165 code plus 417 immutable, or 15,582 core bytes. Historical returning-
diagnostic layouts are 14,651 code plus 417 immutable, or 15,068 core bytes.
Workspace is unchanged at 3,613 production bytes and 3,623 historical bytes.

Each call contributes one semantic-operation byte in addition to the ordinary
argument-expression operations. Transcript capacities remain 511 payload
bytes and 255 operations. A retained read emits seven target bytes, a discarded
read emits three, and a write emits five. The generated-program maximum remains
4,096 bytes; target runtime, vector, provider, and adapter storage costs are
zero. Proof adapters gained observation callbacks only, with no target image
bytes.

The flat proof executes 885,594 instructions in 9,547,723 T-states, increases
of 0.4091 and 0.3051 percent. Debug executes 889,385 instructions in 9,589,514
T-states. The historical Chapter 18 proof executes 1,424,200 instructions in
14,069,055 T-states; Stage 8 executes 1,730,834 in 16,812,478; and the complete
LL(1) proof executes 1,926,869 in 18,461,393. The largest measured increase is
0.4378 percent in instructions and 0.3559 percent in T-states. Flat and banked
execution proofs observe ports 0, 1, 255, `$1234`, `$ABCD`, `$FEDC`, and
`$FFFF`, dynamic ports and values, left-to-right evaluation, canonical read
results, exact generated bytes, reset after rejection, and exact type and arity
diagnostics.

### Target-specific packet services

This increment starts from standalone `main` at
`0b7a2791c3ac79f756a434fd070d355237514708`. It adds the result-free statement
`service(slot, packet)`. The slot is an exact byte constant. The packet is a
writable complete or open `u8` array whose existing address-and-count carrier
defines the provider's entire accessible region. Source exposes no pointer,
register, raw address, recoverable status, or arbitrary call target.

The retained implementation reuses the existing aggregate-path parser and open
array carrier. One four-byte operation records the exact slot and statement
offset after the existing four-byte carrier operation, for eight semantic
transcript bytes per use. The transcript remains bounded at 511 payload bytes
and 255 operations. A simple statement emits ten existing carrier bytes and a
14-byte dispatch, for a 24-byte call site. The dispatch supplies `A = slot`,
`HL = address`, and `BC = count`; its private source offset and terminal
continuation are consumed by the shared runtime gateway.

The first complete backend emitted the terminal trap body at every call site.
The feature-only size pass moved that policy into one runtime helper, reduced a
simple statement from 56 to 24 generated bytes, reused the indexed instruction-
pair table, and compressed the MON-3 provider to 37 bytes. The final compiler
adds 164 production code bytes and eight immutable bytes. Production is 15,273
code bytes plus 425 immutable bytes, or 15,698 compiler-core bytes, leaving 686
bytes below 16 KiB. Debug is 15,329 code bytes plus 425 immutable bytes, or
15,754 core bytes. Historical returning-diagnostic layouts are 14,800 code
bytes plus 425 immutable bytes, or 15,225 core bytes. Workspace is unchanged at
3,613 production bytes and 3,623 historical bytes.

Runtime identity `$0009` appends vector ordinal 11, increasing the vector from
33 to 36 bytes, and appends a 42-byte packet gateway to the 689-byte canonical
runtime, for 731 bytes total. Fixed writable runtime state remains 37 bytes.
The reference MON-3 provider implements slot 1 as `scanKeys`, validates a
three-byte extent before `RST $10`, and writes canonical key, pressed, and new-
press bytes. Other targets may bind different slot contracts, but every
provider must remain callable in every selected bank and must validate before
native dispatch or packet mutation.

The flat proof executes 875,383 instructions in 9,430,916 T-states, and debug
executes 879,008 in 9,470,881. The historical Chapter 18 proof executes
1,427,422 instructions in 14,095,150 T-states; Stage 8 executes 1,734,602 in
16,842,722; and the complete LL(1) proof executes 1,930,029 in 18,486,787.
Every increase from the pre-feature checkpoint is below 0.3 percent, while the
shipping flat and debug compiler proofs improve. Flat and banked execution
tests cover exact slots 0, 1, and 255; concrete and open packets; nested paths;
provider confinement; canonical MON-3 results; exact source attribution;
terminal stack restoration; reset; and exact generated bytes.

### Ordered integer `select` / `case`

This increment starts from standalone `main` at
`a04379337407bec7ad22e91ce2ad777c2b7c1d50`. It adds ordered integer
`select`/`case` with comma-separated constant values, first-match selection,
an optional final `else`, and no fallthrough. The selector is evaluated once.
The compiler normalizes every case constant to the selector's exact integer
type and rejects Boolean, aggregate, dynamic, and out-of-range cases.

The parser uses the existing structured-control frame, label, and fixup
capacities. Each case item contributes a five-byte semantic operation holding
the selector type, normalized word, and body label. Each case body and the
final else-or-no-match path contribute one existing cleanup operation. The
payload and operation capacities remain 511 bytes and 255 operations. No
workspace, runtime helper, vector, provider, runtime-state, or target ABI byte
was added.

The first complete implementation added 410 compiler-core bytes. The focused
feature-only size pass removed 61 bytes by combining select endings and flow
summaries, reusing existing type and cleanup paths, reducing the grammar,
sharing body-entry cleanup, and using relative branches where every layout
proved the displacement. The retained result adds 337 production code bytes
and 12 immutable keyword bytes. Production is 15,610 code bytes plus 437
immutable bytes, or 16,047 compiler-core bytes, leaving 337 bytes below 16
KiB. Debug is 15,674 code bytes plus 437 immutable bytes, or 16,111 core
bytes. Historical returning-diagnostic layouts are 15,156 code bytes plus 437
immutable bytes, or 15,593 core bytes. Workspace remains 3,613 production
bytes and 3,623 historical bytes.

The historical parser extent grows from 9,738 to 10,049 bytes. Within it, the
packed LL(1) engine grows from 248 to 271 bytes, tables from 831 to 933 bytes,
and semantic actions from 2,349 to 2,535 bytes. The grammar has 47
nonterminals, 93 logical productions, 82 packed physical productions, and 91
actions. Two consecutive generator runs produce identical table files.

Against an empty 897-byte target image, representative empty-body selections
with 2, 4, and 8 case clauses use 938, 974, and 1,046 bytes: generated-code
deltas of 41, 77, and 149 bytes. Their complete NOBJ streams use 1,898, 2,198,
and 2,798 bytes, compared with 1,563 bytes for the empty program. The selected
proof runtime remains 899 bytes.

The flat compiler proof executes 885,239 instructions in 9,492,254 T-states,
increases of 1.126 and 0.650 percent. Debug executes 888,864 instructions in
9,532,219 T-states. Stage 8 executes 1,759,208 instructions in 17,002,694
T-states, and the complete LL(1) proof executes 1,950,941 instructions in
18,619,555 T-states; both changes remain below two percent. The expanded
Chapter 18 proof executes 1,483,742 instructions in 14,606,024 T-states. Its
larger change includes compilation and execution of the new accepted select
program plus the new rejected Boolean-selector program, so it is not a
fixed-workload timing comparison.

The final compression audit found no further complete saving in the feature
scope. In particular, replacing the backend's proved register transfer with an
exchange failed strict register-contract analysis, while further grammar
factoring either retained the same packed rows or increased code. The retained
form stays one byte below the 350-byte focused-review threshold and within the
16 KiB gate.

### Tight-binding unary `not`

This language correction makes `not` share the unary `+` and `-` precedence
level. The parser consumes it through the existing right-recursive unary path;
the Boolean and integer complement reducers and generated Z80 are unchanged.
The complete grammar consequently has 188 expanded BNF rules over 101
nonterminals.

Measured production accounting remains 15,566 code bytes plus 437 immutable
bytes, or 16,003 compiler-core bytes, with 3,613 workspace bytes and 381 bytes
of 16 KiB headroom. The historical returning-diagnostic layout shrinks by one
code byte to 15,137 plus 437 immutable, or 15,574 core. The selected proof
runtime remains 899 bytes and the flat proof remains 2,346 bytes. The flat
proof executes 884,952 instructions in 9,491,133 T-states; the instrumented
proof executes 888,577 in 9,531,098. The complete LL(1) proof executes
1,948,519 instructions in 18,597,591 T-states. No compiler workspace, semantic
transcript, generated-program, runtime, target-layout, or NOBJ capacity changes.

### Routine bindings shadow program bindings

Parameters and scalar locals may now repeat an earlier program variable,
constant, aggregate constant, record type, or aggregate type name. The routine
binding wins throughout that routine body. Same-scope duplicates remain
diagnostics, and source-routine names, `main`, and predefined names remain
protected. The symbol table is searched newest first, so the rule needs no new
workspace, scope table, or binding field.

Measured production accounting is 15,629 code bytes plus 437 immutable bytes,
or 16,066 compiler-core bytes, with 3,613 workspace bytes and 318 bytes of 16
KiB headroom. This is 63 added production-core bytes. The instrumented layout
is 15,695 code plus 437 immutable, or 16,132 core. The historical
returning-diagnostic layout is 15,198 code plus 437 immutable, or 15,635 core,
with 3,623 workspace bytes. The selected proof runtime remains 899 bytes; the
flat proof remains 2,346 bytes; generated programs, semantic capacity, target
layout, and NOBJ encoding are unchanged.

The flat proof executes 881,732 instructions in 9,463,334 T-states; the
instrumented proof executes 885,357 in 9,503,299. The complete LL(1) proof
executes 1,942,692 instructions in 18,546,159 T-states. The lower compilation
cost comes from replacing repeated program-first searches with one newest-first
symbol scan; symbol capacity is unchanged.

### Constant-expression counted-loop steps

The counted-loop step magnitude now uses the ordinary compile-time expression
folder. Forms such as `step 1 + 1`, `step Rows * Columns`, and `step
-(Rows + 1)` are accepted when the folded magnitude is a nonzero non-Boolean
integer through 65,535; the optional leading sign still selects direction.
Runtime values and negative folded magnitudes remain invalid. This reuses the
established constant-expression diagnostics and removes the former bespoke
number/name scanner.

Measured production accounting falls to 15,600 code bytes plus 437 immutable
bytes, or 16,037 compiler-core bytes, with 3,613 workspace bytes and 347 bytes
of 16 KiB headroom. This is a 29-byte production-core saving. The instrumented
layout is 15,666 code plus 437 immutable, or 16,103 core. The historical
returning-diagnostic layout falls by 30 bytes to 15,168 code plus 437
immutable, or 15,605 core, with 3,623 workspace bytes. The selected proof
runtime remains 899 bytes; the flat proof remains 2,346 bytes; generated loop
code, semantic capacity, target layout, and NOBJ encoding are unchanged.

The flat proof remains 881,732 instructions in 9,463,334 T-states, and the
instrumented proof remains 885,357 in 9,503,299. The complete LL(1) proof
remains 1,942,692 instructions in 18,546,159 T-states. The explicit-step
historical structured-control proof executes 251,612 instructions in 2,676,537
T-states because step expressions now traverse the shared constant folder.

### Folded constant-true loop completion

The return-flow summary now treats every `while` condition folded to Boolean
constant `true` like the original exact `while true` form. It reads the
expression's existing constant metadata and canonical Boolean value. The old
token peek and semantic-operation-count test are removed. Dynamic and
constant-false conditions remain fallthrough-capable, and the existing
nearest-loop `exit` summary is unchanged.

Measured production accounting falls by 19 bytes to 15,581 code bytes plus
437 immutable bytes, or 16,018 compiler-core bytes, with 3,613 workspace bytes
and 366 bytes of 16 KiB headroom. The instrumented layout is 15,647 code plus
437 immutable, or 16,084 core. The historical returning-diagnostic layout
falls by 20 bytes to 15,148 code plus 437 immutable, or 15,585 core, with 3,623
workspace bytes. Runtime, generated programs, semantic capacity, target
layout, NOBJ encoding, instruction counts, and T-states are unchanged.

### Aggregate constants in static initializers

Any complete aggregate initializer node may now name an earlier aggregate
constant of the exact required concrete type. The parser scans the committed
symbol table in declaration order while advancing a read-only-image cursor
over earlier aggregate constants. A match copies the established complete
object into initializer scratch; scalar constants, types, variables, and
routines consume no read-only bytes. This adds no retained index, cache, or
workspace. Later and self references remain unknown names, while mutable
aggregate objects and nominally different types remain type mismatches.

Measured production accounting is 15,696 code bytes plus 437 immutable bytes,
or 16,133 compiler-core bytes, with 3,613 workspace bytes and 251 bytes of 16
KiB headroom. This is 115 added production-core bytes, within the feature's
120-byte retention budget. The instrumented layout is 15,762 code plus 437
immutable, or 16,199 core. The historical returning-diagnostic layout is
15,264 code plus 437 immutable, or 15,701 core, with 3,623 workspace bytes.
The selected runtime remains 899 bytes and the historical proof runtime
remains 921 bytes. Immutable data, compiler workspace, semantic capacity,
generated Z80, runtime, target layout, and NOBJ encoding are unchanged.

The flat proof executes 881,953 instructions in 9,465,725 T-states; the
instrumented proof executes 885,578 instructions in 9,505,690 T-states. The
historical Stage 9 proof executes 1,490,424 instructions in 14,683,285
T-states; Stage 8 executes 1,753,158 in 16,949,785; and the complete LL(1)
proof executes 1,943,560 in 18,555,025. Focused execution discriminates whole
record copies, aggregate constants nested as fixed-array elements, the sealed
bounded-string representation including an embedded zero, intervening scalar
and mutable declarations, exact-type rejection, declaration order, and an
earlier source part assigned to another target bank.

### Source-library routine capacity

The source-library baseline raises non-main routine capacity from four to
sixteen and retained parameter capacity from sixteen to twenty-six. Callable
`main` uses label 31 and ordinary routines use labels 32 through 47. Structured
fixups now keep the complete label in its own byte and keep site-bank and
far-call flags in a second byte; this avoids truncating labels above 31.

Measured production accounting is 15,706 code bytes plus 437 immutable bytes,
or 16,143 compiler-core bytes, leaving 241 bytes of 16 KiB headroom. Workspace
grows by 264 bytes, from 3,613 to 3,877: 96 bytes for twelve additional routine
entries, 40 bytes for ten additional parameter entries, 96 bytes for 32
additional label entries, and 32 bytes for the widened fixup records. The
selected runtime remains 899 bytes. Semantic transcript, generated-program,
target-layout, runtime, and NOBJ capacities are unchanged. The instrumented
layout is 15,772 code plus 437 immutable, or 16,209 core; the tracing adapter
still lies outside shipping core accounting. The largest retained historical
generated program remains 1,040 bytes.

The flat proof executes 874,179 instructions in 9,608,830 T-states. The
instrumented proof executes 877,804 instructions in 9,648,795 T-states. The
complete LL(1) proof, including the expanded routine and parameter boundaries,
executes 2,019,670 instructions in 19,662,246 T-states. Executed local calls
discriminate labels 31, 32, 43, and 47; executed cross-bank calls discriminate
labels 43 and 47 with the separate far-call flag. Capacity proofs accept sixteen routines and
twenty-six retained parameters, then reject the next declaration at its exact
source position. The historical returning-diagnostic layout is 15,274 code plus
437 immutable, or 15,711 core, with 3,887 workspace bytes and a 921-byte proof
runtime. Its Chapter 18 proof executes 1,469,245 instructions in 14,811,727
T-states; its Stage 8 proof executes 1,723,192 instructions in 17,126,791
T-states.

### Incremental Node NOBJ path

The Node reference host can now finalize and validate NOBJ without joining the
image spool, patch spool, map, and commit into one resident byte array.
`commitTo` updates CRC and byte count as each chunk is written. The incremental
reader accepts arbitrary chunk boundaries, including one byte at a time, and
the optional chunk materializer reproduces the compatibility bank images. The
file destination publishes by temporary-file rename only after COMMIT.

The low-memory producer and rewindable-reader paths rescan stored PATCH records
pairwise. They retain at most two framed records rather than an interval table
proportional to the number of patches. Tests distinguish an overlap detected before the first
committed-output byte, storage failure with abort, late preflight failure with
the previous file unchanged, and successful publication after validation. The
compatibility encoder and `compileNucleusTo` produce byte-identical NOBJ,
including record count and CRC. This host-only increment changes no compiler
code, immutable data, workspace, semantic transcript, generated program,
selected runtime, instruction count, or T-state count.

### Native Z80 output adapter

The production `compileNucleusTo` path now links the compiler to the versioned
native host vector. Its fixed Z80 entries yield BEGIN, IMAGE, runtime-provider,
PATCH, MAP, COMMIT, and ABORT operations directly to Node-backed sequential
spools. The 92-byte reference vector and its `OUT`/`RET` stubs are host code,
outside compiler-core accounting. The proof-only AdapterLog remains available
for isolated assembly evidence, and the materializing/D8 API remains a named
compatibility path until its consumers become sequential.

The compiler supplies one stable 38-byte MAP request and passes its existing
18-byte source-dependent runtime link context to the runtime provider. This
removes private target-layout and MAP symbol reads from the production host;
the embedded reference image still uses its public symbol map for entry,
diagnostic, source-window, and host-vector locations. Flat and
banked `compileNucleusTo` results are byte-identical to the compatibility NOBJ,
including record order, MAP, record count, CRC, generated program, and selected
runtime. Separate flat and banked discriminators place the exact used image end
at mathematical `$10000`, where the retained 16-bit cursor is zero, and still
produce byte-identical compatibility and native NOBJ.

Measured production accounting is 15,844 code bytes plus 437 immutable bytes,
or 16,281 compiler-core bytes, leaving 103 bytes of 16 KiB headroom. Workspace
is 3,918 bytes: the increment adds one retained source-part count, one retained
part-bank pointer, and the 38-byte stable MAP request. The selected runtime
remains 899 bytes and the largest retained historical generated program remains
1,040 bytes. The instrumented compatibility layout is 15,910 code plus 437
immutable, or 16,347 core. The flat proof executes 874,979 instructions in
9,619,341 T-states; the instrumented proof executes 878,604 instructions in
9,659,306 T-states. The
feature-local size pass moved the MAP request into dead post-parse LL(1) stack
storage, reused values at their existing production sites, merged flat/banked
MAP routing, and retained the part-bank pointer for a measured four-core-byte,
two-workspace-byte trade. The account is below the hard limit but leaves little
reserve; further compiler-core growth requires a new measured compression or
replacement.

### Native windowed source and D8 handle mode

The production host now supplies source through begin-part, byte-chunk,
end-part, and end-unit events. A 768-byte source window is refilled as the
tokenizer advances. If a token survives a refill, the Z80 host copies its raw
spelling into a separate 1,280-byte cache before the old window is reused. The
cache admits the tokenizer's maximum escaped string token. Source parts are no
longer constrained by the resident compatibility window; the published
per-part limit is the 65,535-byte source-position range.

Names retained beyond the current token are generation-scoped host handles.
The compiler compares a current token with a handle through the native host and
materializes a retained spelling into bounded scratch only for parser actions
that require a readable pointer. D8 uses the same handles to recover routine
names and declaration positions. Its trace preflight completes before NOBJ
commit, so an invalid or stale handle cannot publish either the object or its
sidecar correlation.

The stable Node compiler and command line use this native path for ordinary and
D8 builds. `compileNucleus()` retains the 2,048-byte resident-source adapter as
an explicit compatibility API. Tests cover a 3,000-byte source with D8, tokens
ending at and crossing a refill boundary, a 1,014-byte maximum accepted
bounded-string token, the tokenizer's exact 1,022-byte raw string-token
boundary, exact 65,535-byte parts, the first overflowing offset, line and column, and
flat and banked NOBJ/D8 identity.

The resident compatibility layout remains 15,844 code plus 437 immutable
bytes, or 16,281 core bytes. The production native-source layout is 15,877 code
plus 437 immutable, or 16,314 core bytes, leaving 70 bytes below the 16 KiB
gate. Its compiler workspace is 3,922 bytes. The separately accounted native
host vector and source adapter occupy 491 bytes. The instrumented native layout
is 15,943 code plus 437 immutable, or 16,380 core bytes, leaving four bytes; its
host image is 493 bytes.

The final account keeps retained-name record decoding and the materialization
that publishes parser token cells inside compiler core. Raw source pinning,
retained-name storage, and output-provider operations live in the separately
reported host image. The feature-local size pass merged the two retained-token
materialization paths, shared their length publication, shortened native name
comparison, and removed a redundant source-provider state test. Against the
cleared native correctness build, it reduced the honestly accounted compiler
core by 16 bytes without changing the host image. Workspace, generated
programs, selected runtime, semantic transcript, NOBJ bytes, and compatibility
proof timings are unchanged.

### Native Z80 NOBJ consumer

The native consumer is a standalone Z80 component rather than compiler core.
It accepts a stored, rewindable NOBJ generation, validates it completely, then
rewinds and materializes the same locked generation. IMAGE and PATCH bytes do
not become runnable until CRC, MAP, COMMIT, terminal EOF, deployment-profile,
and protected-memory checks have all passed. PATCH overlap is proved by bounded
rescans, so the consumer does not retain a patch table proportional to the
object.

The reference consumer supports flat loaded, flat ROM, and banked objects. Its
consumer-platform vector separates object access, target-bank selection,
publication, and entry from the object parser. The revision-one implementation
accepts only the locked two-pass strategy. A direct isolated one-pass strategy
is reserved because resolution-ordered PATCH records cannot yet be checked for
arbitrary overlap through the fixed platform interface.

The measured consumer is 2,887 code bytes with 399 workspace bytes, including
a 325-byte maximum MAP payload buffer. The flat proof executes 22,876
instructions and the two-bank proof executes 26,416. Fifty-five executable
cases cover framing, truncation, CRC, record order, IMAGE and PATCH overlap,
loaded and ROM layout, banking, mathematical `$10000` ends, protected memory,
platform failure, publication, and sequential reset. Compiler code, compiler
workspace, generated program, and target runtime are unchanged.

### Native Z80 launch shell under Debug80

The first native launch shell calls the streaming compiler through
`NucleusHostCompile` rather than entering a compiler-private routine from
TypeScript. Its fourteen-byte launch descriptor binds source, target, output,
and D8 generations. Its nine-byte result distinguishes success, an exact
compiler diagnostic, and a private host failure.

Runtime linking uses a bounded host mailbox. The Z80 entry records the complete
request, yields to the Debug80 device binding, and resumes the same compiler
call frame after Node supplies a status. Cancellation takes the compiler's
nonlocal target-abort continuation and cannot resume stale asynchronous work.
D8 preflight failure follows the same host-outcome path instead of halting the
emulator inside an output callback.

`NucleusHostInitialize` clears cold host state. `NucleusHostReset` releases one
active tentative generation after an interrupted outer run, clears the same
workspace, and permits the image to be reused. Direct shell proofs cover exact
diagnostic and host results, malformed and concurrent launches, ordinary and
initial runtime requests, same-image reuse, one failing shell-owned abort, and
stack restoration.

The measured non-D8 host is 913 code bytes; the D8 host is 915. Both use 22
bytes of host workspace. This is an external-host account: the native shipping
compiler remains 15,877 code plus 437 immutable bytes, or 16,314 core bytes.
The MON3-compatible RST gateway is the next deployment increment and is not
claimed by this checkpoint.

A final branch experiment tried the apparently in-range transfers in the new
shell as `JR`. AZM's current forward/local resolution rejected even the nearby
reset tail with a spurious displacement above 28,000. The exact source was
restored and regenerated; the retained `JP` instructions are a toolchain
constraint, not unmeasured resident headroom.

## Capacity ledger

The first implementation fixes a numeric limit before each bounded structure is
used. Each row records the selected Z80 or host representation and its evidence.

| Resource                                |      Limit | Representation                                                                        | Excess diagnostic or trap                                                        | Evidence                                                                                                         |
| --------------------------------------- | ---------: | ------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| source part count                       |          8 | external five-byte descriptors plus three compiler-workspace bytes                    | capacity diagnostic                                                              | accepted 1- and 8-part units; rejected ninth part                                                                |
| source-part raw bytes                   |     65,535 | native host stream with word offset, line, and column counters                        | source-position-capacity diagnostic before any counter wraps                     | exact 65,535-byte part; first overflowing offset, line, and column                                               |
| native source chunk bytes               |        768 | refillable host window; old bytes are dead after token pinning                        | host source failure                                                              | exact-boundary and cross-boundary identifier proofs                                                              |
| native raw-token cache bytes            |      1,280 | pinned token spelling outside the refillable source window                            | host source failure before overwrite                                             | accepted 1,014-byte bounded-string token and exact 1,022-byte tokenizer boundary across refills                  |
| native retained-name entries            |      1,024 | generation-scoped exact handles in host storage                                       | host capacity failure before handle allocation                                   | exact entry capacity, first excess, and reset to an empty generation                                             |
| native retained-name spelling bytes     |     65,535 | exact copied bytes in host storage                                                    | host capacity failure before copying or publishing a handle                      | exact byte capacity, first excess, and atomic retained usage                                                     |
| native launch-shell code bytes          |    913/915 | always-visible external Z80 host image without/with D8                                | deployment memory-map rejection                                                  | generated-symbol locks; compiler core remains 16,314 bytes                                                       |
| native launch-shell workspace bytes     |         22 | launch lifecycle, result pointers, and one bounded runtime-request mailbox            | deployment memory-map rejection                                                  | cold initialization, interrupted reset, suspended request, and same-image reuse proofs                           |
| compatibility source window bytes       |      2,048 | complete source retained only by the compatibility API                                | compatibility packaging error                                                    | differential resident-source fixtures                                                                            |
| diagnostic-name bytes                   |   external | retained by the host manifest adapter, not by the compiler core                       | packaging diagnostic                                                             | exact `model.nu` and `main.nu` mapping                                                                           |
| identifier bytes                        |        255 | source-backed name plus one-byte length                                               | lexical diagnostic                                                               | scanner wrap guard                                                                                               |
| ordinary binding symbols                |         16 | one shared table of six-byte source-backed scalar and aggregate entries               | capacity diagnostic                                                              | accepted sixteen aggregate variables; rejected seventeenth binding                                               |
| non-main routine entries                |         16 | one shared table of eight-byte direct or forward entries                              | capacity diagnostic                                                              | local labels 32, 43, and 47; cross-bank labels 43 and 47; accepted sixteen entries and rejected seventeenth      |
| retained parameter entries              |         26 | one global table of four-byte scalar or aggregate parameter entries                   | capacity diagnostic                                                              | accepted twenty-six total entries; rejected twenty-seventh across routines                                       |
| nested compiler call frames             |          4 | eight-byte parser frames                                                              | capacity diagnostic                                                              | rejected fifth nested call                                                                                       |
| LL(1) grammar symbols                   |         64 | byte stack; thirteen bytes of action scratch overlay inactive initializer state       | parser-capacity diagnostic                                                       | exact-fill and atomic internal-overflow engine proof                                                             |
| dynamic types, records, and fields      | 8 / 5 / 12 | four-byte type, two-byte record, and six-byte field entries                           | capacity diagnostic                                                              | shared nested-row interning, exact-fill, and first-overflow proofs                                               |
| concrete array suffixes per type        |          4 | dedicated 20-byte suffix workspace with four length-and-source-offset entries         | type-metadata capacity diagnostic before a fifth suffix is retained              | accepted four-dimensional type and rejected fifth suffix                                                         |
| fixed-array element count               |     65,535 | retained word; allocation is bounded separately by complete extent                    | program-data capacity diagnostic when the object cannot fit                      | accepted and indexed `u8[1024]`; rejected allocated `u8[1025]`                                                   |
| bounded-string capacity                 |        253 | descriptor byte; object extent is capacity plus two                                   | `bounded-string-capacity`; an open view reports the retained capacity            | accepted 253 and rejected 254/255; construction, zero-tail, and sealed-byte proof                                |
| complete aggregate type extent          |     65,535 | retained word shared by records, arrays, and bounded strings                          | program-data capacity diagnostic when an allocated object cannot fit             | 501-byte nested record; exact 1,024-byte object; rejected 1,025-byte object                                      |
| expression nesting                      |         16 | thirteen-byte metadata entries retaining operand value, type, and position            | capacity diagnostic                                                              | seventeen-deep pending-expression proof                                                                          |
| semantic transcript payload bytes       |        511 | counted variable-width stream                                                         | capacity diagnostic                                                              | scalar-assignment exact-fill and first-overflow proof                                                            |
| semantic transcript operations          |        255 | one-byte published operation count                                                    | capacity diagnostic                                                              | pre-append operation-count guard                                                                                 |
| Boolean fixups                          |         16 | two-byte generated addresses                                                          | capacity diagnostic                                                              | exhaustion and underflow boundary proofs                                                                         |
| active control frames                   |          8 | ten-byte parser frames                                                                | capacity diagnostic                                                              | nested structured-control proofs                                                                                 |
| parser control-label ordinals           |         31 | byte ordinals 0–30; 31 is reserved for callable `main`                                | capacity diagnostic                                                              | nested control and select/case exact allocation boundaries                                                       |
| emitter label entries                   |         64 | three-byte streaming entries addressable by a full six-bit ordinal                    | capacity diagnostic                                                              | local labels 31, 32, 43, and 47; cross-bank labels 43 and 47; reserved headroom through ordinal 63               |
| branch fixups                           |         32 | four-byte label/flags/address records                                                 | capacity diagnostic                                                              | bounded resolver, generated branch proofs, and full six-bit source-routine labels                                |
| object-stream total records             |     65,535 | NOBJ `COMMIT.recordCount` word                                                        | output-service failure or capacity diagnostic before count wrap                  | accepted exactly 65,535 records; rejected first additional data record atomically                                |
| object-stream patch records             |     65,531 | external sequential patch spool; exact maximum when one required image record is used | output-service failure or total-record capacity diagnostic before partial record | resolution-order submission, image-before-patch serialization, and count boundary                                |
| object-stream image or patch bytes      |     65,532 | one NOBJ record with a word payload length and three-byte bank/address prefix         | output-service failure or target-capacity diagnostic                             | accepted 1 and 65,532 bytes; rejected 65,533 before append                                                       |
| committed object generations            |          1 | storage-layer current-generation reference; incomplete generation remains uncommitted | output-service failure; previous commit remains current                          | A retained after divergent image-plus-patch B failure; C committed and executed                                  |
| native NOBJ consumer MAP bytes          |        325 | fixed consumer-workspace payload buffer                                               | MAP validation failure before buffer overflow                                    | exact maximum derived from eight parts and four ten-byte bank entries; malformed and truncated MAP proofs        |
| native NOBJ consumer target banks       |          4 | four image ends and four patch ends in fixed consumer workspace                       | deployment-profile or target-extent failure                                      | flat, two-bank, alternating-bank, invalid-bank, and exact-boundary proofs                                        |
| structured-initializer depth            |          4 | recursive parser state; total nodes are streamed and not retained                     | capacity diagnostic                                                              | nested record/array boundary and wide 256-element initializer                                                    |
| initialized program-data bytes          |      1,024 | prefix of the private compiler image plus a retained word length                      | program-data capacity diagnostic                                                 | exact four-string-plus-tail image and rejected following byte                                                    |
| aggregate-constant bytes                |      1,024 | private-image suffix shared by named constants and anonymous literal arguments        | read-only-data capacity diagnostic                                               | record/array/string constants, distinct `N + 2` literal objects, exact 1,024-byte suffix, and rejected next byte |
| total generated read-only-data bytes    |      1,024 | initialized-data prefix followed by aggregate-constant suffix                         | diagnostic for the declaration class that first exceeds the combined region      | mixed data/constant shifting and exact separate boundary proofs                                                  |
| zero-initialized program-data bytes     |      1,024 | retained word length; no stored image bytes                                           | capacity diagnostic                                                              | exact four-string-plus-tail BSS and rejected following byte                                                      |
| emitted Z80 image bytes per bank        |      4,096 | four cursor-plus-remaining entries; independent monotonic target streams              | target-capacity diagnostic before append                                         | flat 881 bytes; banked 1,138/914 bytes; per-bank and entry-bank overflow proofs                                  |
| physical target banks                   |          4 | target descriptor and four per-bank cursor/remaining entries                          | target-configuration diagnostic                                                  | accepted four-bank profiles; rejected fifth bank                                                                 |
| activation bytes                        |      3,840 | reserved machine-stack region; frame size is bounded by retained declarations         | `activation-capacity` or fixed memory-map rejection                              | memory-map proof, sixteen-position call, and depth boundary                                                      |
| activation depth                        |          8 | counter plus generated hardware-stack frames                                          | `activation-capacity`                                                            | recursive handler-bypass and root-frame trap proof                                                               |
| service stream and bulk-storage extents |          4 | proof adapter byte arrays with independent cursors                                    | stable service error                                                             | success, end, configured failure, overwrite, append, rewind, and seek proofs                                     |

No implementation may wrap, truncate, drop state, or change source meaning when
one of these limits is exceeded.

## Working discipline

Implementation changes follow a short evidence loop:

1. identify the governing language and direct-runtime rules;
2. add or select an executable proof case;
3. implement the smallest complete semantic path;
4. assemble and measure it;
5. compare generated-Z80 behavior with the source-level expected result;
6. inspect any structure that now occurs twice and select a consolidation
   candidate;
7. assemble the candidate and retain it only when the complete resident account
   or another declared binding account improves;
8. repeat the proof and measurement pass until no remaining structural
   candidate has credible evidence of a net saving;
9. update the cost and capacity ledgers; and
10. classify any proposed change as a correctness repair, a
    semantics-preserving economy, or a redesign requiring project-owner
    approval.

The next feature does not begin until the current increment reaches this local
plateau. Micro-optimizations may remain in the ledger for a later pass, but a
known duplicated representation, fixed-program scaffold, or avoidable lifetime
overlap must be measured before the compiler grows around it.

An implementation experiment may remain on a branch or behind a harness. It
must not alter the published language merely because it is smaller in isolation.
Measurements compare complete accounting boundaries and equivalent semantics.

Use `JR` for a direct transfer whenever the Z80 has the required relative form
and every supported assembly configuration places the target within the signed
eight-bit displacement range. Use `JP` when the condition has no relative form
or any supported configuration exceeds that range. After a layout change, run
the branch census and the complete scoped proof set again; newly reachable
relative transfers may be converted, while an AZM range failure requires the
affected transfer to fall back to `JP`.

## Continued implementation checklist

Before a new language stage begins:

- outstanding adversarial findings for the current stage are resolved;
- the language, target-system, NOBJ, and direct-Z80 authorities, reviewer
  charter, and published editions agree;
- machine-readable trap and service assignments match the direct runtime
  contract;
- every Chapter 18 program has a source-level expected result;
- the Z80 memory map identifies the compiler bank, compiler workspace, generated
  program destination, target-runtime regions, program code and data, and
  activation arena without overlap; and
- the measurement harness reports compiler bytes, immutable data, peak
  workspace, target-runtime bytes, runtime state, emitted bytes, and T-states
  as separate accounts.
