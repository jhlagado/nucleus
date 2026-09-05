# Native ATOM source pilot

2026-09-05. Baseline `6045257a11d791e34fccba607b60e79f629d3019`; development
branch `atom-source-native`. This is the first bounded source conversion in the
[migration plan](../plans/atom-native-source.md), not completion of that plan.

## Converted provider

`asm/providers/mon3-packet-service.asm` now uses ATOM syntax directly. Its
constants have short names, `PKTSVC` is the entry, and `.keys`/`.fail` are local
branches. The register/flag contract remains in a comment. Two unused labels
were removed; neither emitted bytes.

The fixture uses ATOM's leading `%INCLUDE`. Its test calls the public
`assembleAtomProject` API directly and supplies the target origin. The Nucleus
translator is no longer involved in this provider's assembly. ATOM's package
does not supply TypeScript declarations, so a narrow test-only declaration
records the two public functions used here; it adds no runtime wrapper.

Before editing, the existing ATOM-based path produced these 37 bytes at `$7021`:

```text
FE 01 20 1D 78 B7 20 05 79 FE 03 38 14 0E 10 D7
F5 D1 72 23 7B 07 07 E6 01 77 23 7B E6 01 77 B7
C9 3E 07 37 C9
```

The direct-source tests reproduce those exact bytes at `$0100`, `$7021`,
`$8000` and `$FFDB`. The last case checks both the wrapped end-label value zero
and physical high-water value 65,536. There is no target-code, required-data,
workspace or instruction-sequence change. No new timing measurement is claimed.

## Verification and review

- Fresh installation: `npm ci` passed, with no audit vulnerabilities reported.
- `npm run test:atom-source`: all 15 tests passed before and after the pilot.
- Baseline `npm run check:atom-images -- native`: zero byte, sparse-coverage
  or symbol differences; all 2,464 expected symbols matched.
- After conversion, `npx vitest run test/service-gateway.test.ts --maxWorkers=1`:
  all 34 tests passed, including the four new origin cases. Existing execution
  checks retain packet mutation boundaries, key flags, errors, traps, stack and
  register restoration.
- `npm run typecheck`: passed after adding the test-only declarations.
- `npm run check:compiler-images`: passed after conversion. It reassembled all
  six compiler variants, six runtime profiles, the Node runner, import resolver
  and CP/M embedded assets without changing their checked generated files.
- Two independent read-only reviewers found no actionable pilot defect. Both
  required the generated-image check because removing long names from a file
  can renumber aliases in the remaining global scanner; that check then passed.

The complete release/package gate and Linux CI have not been rerun for this
pilot. No new release or Triptych pin was published. The existing translator
still handles the rest of Nucleus until later stages migrate its callers.

## Parallel findings

The workspace lane identified a clean, stale local main checkout and
fast-forwarded it from `6bd2723` to `6045257`. The primary experimental checkout,
its modified lockfile and untracked files were unchanged. Other divergent or
dirty worktrees remain preserved. The optional suite launcher's 18 tests pass,
but its existing managed ATOM, Nucleus and Debug80 checkouts remain drifted;
the manifest update alone did not replace them.

The practical-qualification lane reproduced a pre-existing CP/M compiler gap.
The following program compiles through Node but the released NUC reports
hexadecimal error `39` (unknown name) at the parameter use:

```text
sub emit(n as u8) fails
writeOutputByte(n) else fail
end
sub main() fails
emit(65) else fail
end
```

The lead independently reproduced this result on the pinned Triptych disk
`90afb240503a95b14620a9f829c8c9a63a4ba78798e4327bc16313639454a710`, using
private in-memory storage. The published NUC bytes were unchanged. A related
array-parameter loop case also failed to return to the real CP/M prompt after
its diagnostic in the worker's bounded probe. The diagnostic-return case
passes under the isolated BDOS test double, so the integration failure needs
its own trace; it is not evidence that every diagnostic return is broken.

Separate regression work uses branch `cpm-parameter-recovery`. Correctness
repairs must remain distinct from this source-preserving pilot. The earlier
hosted OK/YK workflow did not exercise routine parameters and cannot establish
their CP/M qualification.

Next: coordinate the shared runtime/source-symbol conversion and its caller
tests while the practical lane reduces the CP/M parameter and return failures.
