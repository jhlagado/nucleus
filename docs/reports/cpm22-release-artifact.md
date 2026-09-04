# CP/M release artifact checkpoint

Date: 2026-09-05

## Boundary

Nucleus now publishes its self-contained CP/M compiler as `dist/NUC.COM`
beside the JavaScript package. The artifact is owned and built by Nucleus;
Triptych and other Z80 machines are consumers. Its machine-independent public
contract remains `docs/cpm22-command-line.md`.

`npm run build:cpm22` assembles
`asm/vertical-slice/cpm22-native-compiler.asm` with the exact ATOM dependency
selected in `package.json`. It takes the used transient range from
`CpmCompilerTransientStart` through `CpmCompilerResidentEnd`; no Triptych,
Debug80 source tree or AZM executable participates.

The committed baseline and generated manifest fix these values:

| Property       | Value                                                              |
| -------------- | ------------------------------------------------------------------ |
| Version        | `0.3.0`                                                            |
| Load and entry | `$0100`                                                            |
| End            | `$5421`                                                            |
| Bytes          | 21,281                                                             |
| SHA-256        | `7b3da3c0b595a88b4906537fe0f76c44f7abd412e248d35d927d1aefd8971ef1` |
| ATOM revision  | `802b5c2d320bec777f427755ff2d7338e3b80a05`                         |

The `.COM` file is the exact used byte range, not a complete CP/M record. A
disk builder may add final 128-byte record padding after it has verified the
logical artifact digest. Keeping padding out of the source release avoids
making a disk-allocation detail part of the compiler identity.

## Verification

The failing-first package check rejected a package without `NUC.COM`. It now
requires both the binary and `NUC.manifest.json`, then checks version, size and
digest before testing an isolated installed consumer.

The CP/M native-compiler suite compares the committed binary byte-for-byte
with a fresh ATOM assembly before running its existing BDOS compilation,
execution, rollback, command-line and memory-layout proofs. The focused run
passed six tests. ATOM executed 790,722,029 emulated instructions to construct
the release image; that host build count is not the guest compiler's runtime.

The complete release gate passed 564 tests in 57 files, rebuilt every checked
compiler image, reconstructed `NUC.COM`, checked the published runtime boundary
and then installed the packed package without a development assembler. The
final package contained 237 files and 3,888,862 unpacked bytes, with
integrity
`sha512-i+U03GdrCeqfuf0sfJjUCAIouTZhyXtRKol6PDn4mo0TEaMlbNVCKKRLUtAxtWSBEqd1rFSohVC6I/3caJHQ2Q==`.
Linux CI remains required before tagging the release.

Next: run the complete `npm run prepublishOnly` gate, open and merge the
`cpm-release` pull request, then attach `NUC.COM` and its manifest to the
versioned GitHub release.
