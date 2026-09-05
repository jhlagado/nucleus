# Native ATOM release completion

2026-09-05. The source-migration and Triptych-integration goal is complete.
[Nucleus 0.3.1](https://github.com/jhlagado/nucleus/releases/tag/nucleus-v0.3.1)
publishes the qualified native ATOM source and compiler. Triptych's hosted
distribution now contains that exact compiler and passes the tested development
session. This report supersedes the pending-release status in the earlier
[qualification checkpoint](atom-native-release-qualification.md).

## Source and release boundary

The release tag resolves to `b5276a85fd36600a10dbd65039f0af3afc033f0d`.
Nucleus PR #4 merged it at `61e15b01e393ce215052662f99b340bc4aced341`; the merge
contains the tested commit and has an identical complete tree. The release
retains its exact tested source identity even when later documentation changes.

The [source-closure report](atom-native-source-closure.md) records the removed
translator, obsolete compositions, explicit native entry routes and output-only
symbol maps. All 223 maintained assembly parts satisfy the native source gate.
Generated context uses ATOM syntax and canonical source leaves. ATOM performs
source resolution and assembly; host-name and full-width endpoint restoration
operate on returned metadata only.

Frozen profile tests compare sparse HEX, complete symbol values and address
classifications. Source-provenance checks inspect the files supplied to ATOM.
The six production compiler images, Node runner, runtime catalog and import
resolver regenerate through native routes. The compiler-core limit and guest
execution, stack and failure assertions remain in force.

The separate [CP/M parameter-name repair](cpm-materialized-name-identity.md)
accounts for the ten-byte executable reduction. It is not an unexplained
source-conversion difference. Scalar-parameter and open-array loop-bound
programs, exact diagnostics, preservation of a prior output on failure and
successful compilation afterward were exercised with Triptych's real guest
OS in private emulated disks. Those tests do not establish a whole-OS stack
bound or hardware behavior.

## Qualification evidence

| Boundary | Evidence |
| --- | --- |
| Full Nucleus release gate | [PR run 33952873447](https://github.com/jhlagado/nucleus/actions/runs/33952873447) and [push run 33952873304](https://github.com/jhlagado/nucleus/actions/runs/33952873304): 737 tests across 69 files, all 63 source checks, deterministic images, type checking and package stages passed. |
| Installed consumers | Linux Node 20 and Node 24 builds and isolated package consumers passed. The macOS package passed API/CLI execution and failed-build preservation; all 373 packed files matched the committed tree. No assembler was installed in those consumers. |
| Final source-boundary review | Two fresh independent reviewers found no actionable issue. They checked native routing, generated source, retired paths, sparse-output and metadata tests; their 28- and 25-test lightweight subsets passed. They did not repeat the heavy assembly matrices. |
| Triptych integration | The six-file pin/report update passed 62 focused tests, the full local check, clean release build and eight final browser tests. Independent review verified the public tag, exact raw assets, unchanged other component pins and saved-disk behavior. |
| Linux machine release | [Pages run 33954140938](https://github.com/jhlagado/triptych/actions/runs/33954140938), exact Triptych revision `04e78c24523781d9012fa3ecd4eb07ec1d70d105`, passed the full check, headless replay, clean release and browser tests, then deployed successfully. |

Triptych's full check passed 275 JavaScript tests across 22 files, eight browser
tests, 18 Rust tests and native-terminal/native-WASM parity checks. Its separate
headless replay passed 34 scenarios and 39 sessions. That replay retains
historical fixtures; the new pinned distribution was exercised by the
distribution, browser and parity gates.

## Published and hosted identities

The published `NUC.COM` has 21,271 bytes, load and entry address `$0100`, and
exclusive end `$5417`. Its SHA-256 is
`1c047ac1ed5ff1c4e914321b66476b842a1b28cc0dfef4cfdb86f691ca037334`.
The unchanged upstream manifest SHA-256 is
`ea2555944622b59b45bc89c9aec63e0575eb9ae6d4a1e9c9430942d905132388`.
Downloaded public assets matched the committed files before Triptych's pin
advanced. The selected ATOM revision remains
`802b5c2d320bec777f427755ff2d7338e3b80a05`.

After deployment, `tools/prove-hosted-browser.mjs` in Triptych compared all
17 hosted assets against downloaded CI artifact `9965847241`. The isolated
browser session passed ATOM/run and Edit/NUC/run/save/reload/reopen/run.
Separate extraction from both CI and hosted disks reproduced all 21,271
compiler bytes and exactly 105 trailing `$1A` record-padding bytes.

The hosted disk SHA-256 is
`6f03fe40c4d45f8b8f7ff57949261f5ed5d6f687870d1234af208a3393b1df7e`;
the deployment-manifest SHA-256 is
`bc0ca71bf94bb1219a1c0e43cbdce162d16e870b8cb64254c99a61b2500e7529`.
[Triptych checkpoint wasm-04e78c2](https://github.com/jhlagado/triptych/releases/tag/wasm-04e78c2)
retains the exact tested `artifact.tar`, SHA-256
`fdb44a16589c00f47a619a14c0aaaf415189bfb9f333af42bd20decbf68d7db2`.
A fresh release download matched the CI archive byte-for-byte.

## Preserved work and subsequent tasks

The Nucleus `atom-source-native` worktree contains the published source
and these completion notes. The older `compiler-rewrite-12k` checkout and its
dirty files remain separate. Triptych's normal checkout was fast-forwarded to
the published main revision only after its clean state was checked. Existing
releases, historical fixtures and saved user disks were preserved.

Fresh distributions include Nucleus 0.3.1. Restored browser and native working
disks retain their installed compiler and saved files; testing the new default
in a separate browser profile does not replace another profile's disk.

Debug80's Node-package and CP/M release pins can now advance through their own
consumer checks. In parallel, Z80 Tool Services can migrate its remaining AZM
proof assembly to ATOM. Those are separate follow-up changes; this report does
not declare every repository AZM-free. Physical ESP32 and mobile-keyboard
qualification remain outside this completed software goal.
