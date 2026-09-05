# CP/M materialized-name identity repair

Date: 2026-09-05. This is a correctness change against source revision
`6045257a11d791e34fccba607b60e79f629d3019`, separate from the source-syntax
migration to ATOM. Assembly and candidate generation used the pinned ATOM
toolchain. Published artifacts and distribution pins remain unchanged.

## Defect and repair

The released `NUC.COM` rejected ordinary routine parameter references with
hexadecimal diagnostic `39` (`DiagnosticUnknownName`, decimal 57). The minimal
case declares `emit(n as u8)` and evaluates `writeOutputByte(n)` in its body.
The same source compiles through the Node-hosted native compiler.

`Stage7InstallParameter` materializes a retained parameter name, then installs
it in the routine symbol table. Materialization updates the token pointer and
length while the parser's current source position remains later in the file.
`TokenRetainNameAtHL` passes those current position fields when retaining the
materialized spelling. The former CP/M implementation reused its materialized
handle only if the current position matched the original declaration. Otherwise
it allocated a handle pointing at the wrong source bytes.

The Node adapter in `src/compiler.ts` explicitly reuses materialized identity
after checking its scratch pointer, length and bytes, regardless of the current
parser position. The CP/M repair applies those same reuse checks before fresh
source-position validation. It uses the existing retained-name comparison
routine. Saved request registers are restored before any fresh-retain fallback;
the public retain entry also preserves IX across the comparison.

Fresh retains still require a nonempty name, valid part, nonwrapping source
extent and available handle capacity. Reuse does not allocate a handle. Changed
lengths or bytes follow the fresh-retain path. Comparison storage errors return
without modifying the retained table or count, and a later retry can succeed.

One pre-existing contract limitation remains: fresh CP/M requests identify names
by their supplied source position and do not independently compare arbitrary
caller-provided bytes against that source. The compiler must supply a matching
fresh token. Node performs the additional byte validation. Tests for changed
materialized scratch use valid replacement source positions; this repair does
not claim general validation of arbitrary fresh-pointer content.

## Regression evidence

Red-baseline commits are `858fa0e` and `ef2e073`. Before production changes:

- Full-transient scalar-parameter and open-array loop-bound programs failed
  with diagnostic `39` at their parameter references.
- Lower-level identity reuse at a later source position returned a different
  handle; reuse with a parser position past the source end incorrectly failed.
- Different-length and modified-byte replacement cases already passed and
  remain covered as discriminators against unconditional handle reuse.

After the repair:

- All 15 tests in `test/cpm22-source-provider.test.ts` pass, including exact
  identity reuse, caller registers, comparison failure/retry, unchanged
  retained-table bytes on rejection, and existing capacity/streaming cases.
- Eight executable tests in `test/cpm22-native-compiler.test.ts` pass. They
  include scalar/open-array parameter compilation and execution, invalid-bound
  diagnostics with old-output preservation, next-command recovery, COM/BIN/HEX,
  publisher rollback and measured layout.
- Provider, compiler and generated-COM test calls now check the exact return
  sentinel PC as well as SP. With this runtime, executing the sentinel HALT
  leaves PC one byte past the sentinel.
- Type checking and whitespace checks pass.

The full-transient release-byte comparison was deliberately excluded from the
post-repair run because `dist/NUC.COM` and its manifest still contain the
previous published release. That comparison passed before the repair. A release
regeneration and the complete package gate are still required before publication.

## Measured accounts

| Account | Baseline | Candidate | Change |
| --- | ---: | ---: | ---: |
| CP/M source-provider code | 722 bytes | 712 bytes | −10 bytes |
| CP/M source-provider workspace | 1,476 bytes | 1,476 bytes | 0 |
| Compiler-core extent | 16,314 bytes | 16,314 bytes | 0 |
| Unpadded transient | 21,281 bytes | 21,271 bytes | −10 bytes |
| Resident end address | `5421` | `5417` | −10 bytes |
| Resident-space headroom | 991 bytes | 1,001 bytes | +10 bytes |
| Existing `OK` compile instructions | 35,469 | 35,482 | +13 |
| Existing `OK` compile T-states | 965,911 | 966,040 | +129 |
| Existing generated `OK` execution | 270 instructions / 3,240 T-states | unchanged | 0 |

The core's extent is unchanged, but its bytes are not identical: 13 CALL/JP
operands targeting relocated host-adapter routines move down by 10 bytes. They
account for all 14 changed bytes within the core extent.

Cross-record materialized reuse takes 368 instructions and 3,646 T-states in
the provider proof. It uses 28 bytes below the provider entry SP, including the
proof's minimal BDOS shim. Tests measure that peak and preserve a canary below
the admitted 32-byte provider-test stack window. Balanced return SP alone would
not establish this bound. A real BDOS has its own additional stack requirements;
the proof measurement is not a total operating-system stack bound. The old
retain path used fewer nested calls, so unchanged workspace does not imply an
unchanged stack requirement.

## Private candidate and real-OS replay

Private candidate `NUC.COM` has SHA-256
`1c047ac1ed5ff1c4e914321b66476b842a1b28cc0dfef4cfdb86f691ca037334`.
The previous released transient remains SHA-256
`7b3da3c0b595a88b4906537fe0f76c44f7abd412e248d35d927d1aefd8971ef1`.

Independent root-agent replay installed the candidate into an in-memory copy of
Triptych revision `1c85df7dd2b31f91ea1cf3500c738376cbf02963`'s disk, SHA-256
`90afb240503a95b14620a9f829c8c9a63a4ba78798e4327bc16313639454a710`.
The existing Rust/WASM CPU, Triptych BIOS and released Portable CP/M residents
executed the tests. Scalar-parameter and open-array loop-bound programs compiled,
ran with exact output `A`, returned to the prompt and accepted `DIR`. A local
counted-loop control compiled and ran with output `ABC`.

A separate replay used the invalid-loop-bound source from the full-transient
test as `BAD.NU`, with an existing 128-byte `OUTPUT.COM` filled with `A5`:

```text
NUC BAD.NU OUTPUT.COM
Nucleus error 39 P=01 O=0037 L=0003 C=0011
```

The command returned to `A>` and preserved every old output byte. In the same
machine instance, compiling valid `GOOD.NU` to `OUTPUT.COM` succeeded; running
`OUTPUT` printed `OK` and returned to `A>`.

The baseline real-OS loop-bound diagnostic had continued executing without a
prompt after 19,976,770 instructions, whereas the isolated BDOS-double test
returned correctly. Both valid and invalid real-OS scenarios now return with
the candidate. This is observed integration recovery; it is not evidence of a
separately identified generic diagnostic-unwind defect. No browser working disk,
published website, on-disk distribution or ESP32 hardware was changed or tested.
