# Native ATOM release qualification

Date: 2026-09-05. This checkpoint prepares version 0.3.1 from the native source
closure at `9008dbf8ef31dce3c623572719028a17c3a75974`. Publication still requires
the complete release gate and clean Linux CI. The existing `nucleus-v0.3.0`
release and Triptych's installed input remain unchanged at this checkpoint.

## Release identity

| Property | Value |
| --- | --- |
| Version | `0.3.1` |
| ATOM revision | `802b5c2d320bec777f427755ff2d7338e3b80a05` |
| Load and entry | `$0100` |
| Exclusive end | `$5417` |
| Unpadded bytes | 21,271 |
| SHA-256 | `1c047ac1ed5ff1c4e914321b66476b842a1b28cc0dfef4cfdb86f691ca037334` |

An independent fresh assembly produced these bytes before the release baseline
was changed. The normal release builder then reproduced them exactly. Package,
lock, baseline and artifact-manifest versions are updated together.

The ten-byte reduction from 0.3.0 comes from the separately reviewed
[materialized-name identity repair](cpm-materialized-name-identity.md).
The native source conversion preserves that corrected candidate. Source-provider
code is 712 bytes; its workspace is unchanged. The compiler core remains
16,314 bytes, with 1,001 bytes of CP/M resident headroom. This release does not
change the language or host contracts.

## Independent real-OS replay

The fresh candidate ran in private memory disks through the existing Rust/WASM
CPU, Triptych BIOS and Portable CP/M revision
`579657f9177b31e1fccf0c05f72ba2ee76f3d052`. The base disk digest was
`90afb240503a95b14620a9f829c8c9a63a4ba78798e4327bc16313639454a710`.
Its disk and bootstrap bytes matched hosted Triptych revision
`1c85df7dd2b31f91ea1cf3500c738376cbf02963`. The local browser build had an older,
dirty revision label; this replay is not a clean host rebuild or a deployment
qualification.

Scalar-parameter and open-array loop-bound programs each printed exactly `A`.
A local-loop control printed `ABC`; the bundled sample printed `OK`. Each
returned to the prompt and accepted `DIR`.

The invalid-bound program reported
`Nucleus error 39 P=01 O=0037 L=0003 C=0011` and preserved all 128 bytes of an
existing `$A5`-filled `OUTPUT.COM`. In the same machine instance, a valid source
then compiled to `OUTPUT.COM`, printed `OK` and accepted `DIR`. No compiler
temporary or backup files remained. No saved user disk was changed.

## Development and compatibility gates

The full Linux development suite now runs on Node 24. Four source-isolation
tests use `--experimental-transform-types`; an actual Node 20.20.2 invocation
rejects that flag before test execution. A separate Node 20 CI job builds the
package, checks its runtime boundary and verifies an isolated installed
consumer. The advertised package runtime minimum remains Node 20.

Local verification under Node 20.20.2 passed the runtime-boundary check and
isolated package test: all public exports, API/CLI compilation and execution,
version/help output, failed-build preservation and absence of a development
assembler. This checks the prepared package; the complete Linux build remains
a separate condition.

The first complete local suite began against the old committed release artifact
and finished with 736 passing tests and its expected byte-comparison failure
across 69 files in 2,021.55 seconds. After preparing 0.3.1, the
complete focused CP/M native-compiler suite passed all nine tests, including
the byte-comparison check, in 40.54 seconds. Source migration evidence is
recorded in the [source-closure report](atom-native-source-closure.md); neither
that evidence nor the private replay substitutes for the full release gate.

## Linux timing correction and parallel execution

[The first Linux release run](https://github.com/jhlagado/nucleus/actions/runs/33950230658)
passed all 63 source checks, deterministic image generation and type checking.
Its full test suite passed 719 tests but skipped 18 dependent tests after the
native-host setup exceeded Vitest's default ten-second hook allowance. That
suite took 11.132 seconds before reporting the timeout; no byte or execution
assertion failed. The complete run took 45 minutes 50 seconds and did not pass
the release gate.

The setup now has an explicit 30-second allowance, matching the existing
isolated four-profile assembly check. Guest instruction limits and all source,
byte, register, flag and stack assertions are unchanged. The affected group
then passed all 20 tests locally in 19.94 seconds. This existing failing suite
is the regression check; no timing-sensitive synthetic test was added.

The local release command retains its original checks through shared source
and package stage scripts. CI runs those stages separately, splits the full
Vitest file set into four isolated shards with one worker each, and retains
the independent Node 20 build/consumer job. The aggregate release job requires
success from every stage and the complete shard matrix; failure, cancellation
or a skipped prerequisite cannot approve publication. Independent checks of
Vitest's actual file sequencer partitioned all 69 files into groups of
18, 17, 17 and 17, with no omissions or duplicates. Testing all 256 combinations
of successful, failed, cancelled and skipped prerequisite results accepted only
complete success. A fresh complete Linux run remains required after these
changes.

After qualification, publish a new immutable source tag and matching executable
and manifest, then advance Triptych's verified-release input. Preserve the old
release, saved working disks and historical CP/M fixtures. ESP32 hardware and
physical mobile-device behavior remain unmeasured.
