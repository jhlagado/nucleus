# Design: direct NOBJ loading and in-place patch application

- Status: implemented; correctness-cleared and size-reviewed
- Date: 2026-08-21
- Scope: NOBJ consumers and native Z80 loaders

## 1. Why this document exists

The approved NOBJ design already permits a loader to read a committed object
once, write its IMAGE records into destination memory, and apply its PATCH
records to those bytes before entry. The target-system specification says the
same thing.

The first native Z80 consumer nevertheless implemented only a locked two-pass
strategy. Its implementation note treated exhaustive pairwise PATCH-overlap
validation as a prerequisite for direct loading. That check has no useful
loader consequence. It required either a table proportional to the patch count
or another read of stored input solely to reject a deterministic result.

That implementation restriction must not replace the architecture. Direct
loading is the ordinary loader model. A separate development-system validator
may inspect compiler output when wanted, but strict validation is not part of
the small execution loader.

## 2. The boundaries

Three operations must remain distinct.

1. The compiler produces one append-only NOBJ generation. It never seeks
   backwards or changes an earlier output byte.
2. The storage sink publishes the NOBJ file only after its COMMIT record is
   complete. This is file-generation atomicity.
3. A loader later reads that file, materializes IMAGE bytes in their selected
   destination, applies PATCH bytes there, validates the terminal records, and
   enters the program only after success.

Patch application belongs to the loader or materializer. It is not a second
compiler pass and does not require a separately saved patched image.

A caller may still request a materialized BIN, Intel HEX file, CP/M COM file,
or ROM image. Those are optional derived artifacts. NOBJ remains sufficient to
load and run the program directly.

## 3. Direct loader algorithm

The direct strategy consumes one sequential read of one committed NOBJ file.

1. Open the selected stored generation and validate BEGIN against the deployed
   target profile.
2. Prove that the image and writable extents do not overlap the loader, its
   stack, its workspace, its platform vectors, or any other live control data.
3. Select each destination bank as required and fill its declared image extent
   with `imageFill`.
4. For every IMAGE record, validate its bank and half-open target extent, then
   copy its payload directly to that destination.
5. For every PATCH record, validate its bank and half-open target extent, then
   overwrite the addressed destination bytes immediately.
6. Validate the MAP facts needed to select the deployed target and entry.
7. Validate COMMIT, record count, CRC, entry pair, and immediate end of file.
8. Only then publish the logical loaded generation or transfer control through
   its entry pair.

The destination is tentative until step 7. On failure it may contain partial
or patched bytes, but the loader does not enter it or advertise it as a valid
program. A transient loader does not have to restore the preceding bytes.

To preserve a running or previously loaded program, the installer supplies an
inactive RAM bank, another slot, or private backing. Preservation is a
deployment feature, not a universal requirement imposed on every loader.

## 4. PATCH ordering

PATCH records are applied in stream order. Their addresses need not increase.
The direct loader checks that each write lies inside the deployed destination,
then performs it. If two PATCH records touch the same byte, the later record
wins. The same ordinary stream-order rule applies to any repeated destination
write. This is deterministic and requires no special case.

The loader does not retain patch intervals, calculate pairwise overlap, sort
records, rescan input, or diagnose duplicate destinations. Such a diagnostic
would reveal only a possible producer defect; it would not make the loaded
result safer or better defined. Producer tests may still look for accidental
duplicate patches, but that is not part of the object-consumer contract.

This is the authority correction that removes the false two-pass dependency.

## 5. Flat and banked targets

A flat loader writes directly into the declared Z80 destination when that
extent is non-runnable during loading and does not cover the loader itself.
With origin `$4000`, IMAGE bytes addressed at `$4000` are written there and a
later PATCH for `$4001` overwrites that operand there.

A banked loader maps the NOBJ bank ordinal through the deployment profile,
selects the corresponding physical bank, and performs the same IMAGE or PATCH
write in the visible window. The loader, stack, object cursor, CRC, MAP state,
and bank-selection code remain in always-visible memory.

Direct banked loading is valid when the physical banks themselves are the
isolated destination: no bank becomes executable until COMMIT succeeds. The
loader does not need enough linear RAM to hold all banks simultaneously.

## 6. Optional materialization elsewhere

Some platforms cannot safely dirty the final destination before the file is
known to be complete. They can load into another bank or buffer, or construct a
derived BIN, HEX, COM, or ROM image on a development system. That is a choice of
destination, not a reason to rescan PATCH records.

The two useful policies are therefore:

| Strategy              | Reads | Destination before COMMIT       | Intended use                          |
| --------------------- | ----: | ------------------------------- | ------------------------------------- |
| direct loader         |   one | tentative and non-runnable      | normal RAM or isolated-bank loading   |
| buffered materializer |   one | private buffer or inactive bank | preserved artifacts and ROM utilities |

## 7. Intel HEX observation

Intel HEX type-00 data records already contain a byte count, address, and data.
A purpose-built loader can therefore encode initial image records first and
later patch records at the same addresses. Processing records in file order
applies the patches while loading.

This is mechanically possible, but it is not a portable interchange convention:
generic HEX tools do not all promise the same treatment of overlapping data
records. Intel HEX also lacks NOBJ's bank ordinals, target MAP, runtime identity,
writable extents, entry-bank rules, record count, and whole-generation COMMIT
and CRC.

For those reasons NOBJ remains the executable object stream. A Nucleus-specific
HEX stream could be a transport for a flat target, while an ordinary exported
HEX artifact should normally be produced from the completed materialized image.

## 8. Implemented changes

The completed consumer increment:

1. make direct loading the native consumer's ordinary strategy;
2. remove mandatory object lock, rewind, and second-pass machinery;
3. fill selected target backing before the first IMAGE record;
4. write IMAGE and PATCH payloads during the validation read;
5. retain no IMAGE or PATCH interval tables;
6. delay `PublishTarget` and `EnterTarget` until valid COMMIT and EOF;
7. keep strict development validation, if desired, in host tooling rather than
   the execution loader;
8. update the NOBJ and target authorities so PATCH stream-order semantics and
   the two validation policies cannot be confused again; and
9. replaced the stale Milestone 6 statement that called direct loading a
   future extension.

No compiler, language, generated-program, runtime, or NOBJ record encoding
change is required.

## 9. Required evidence

The direct strategy must prove:

- one sequential object read and no rewind or lock call;
- IMAGE deposition followed by in-place PATCH replacement;
- patches applied in their serialized order, including proof that the last of
  two writes to one byte wins;
- CRC, truncation, missing COMMIT, bad MAP, and immediate-EOF rejection;
- no publication or entry after any failure;
- dirty but non-runnable destination after a late failure;
- exact `$10000` image ends;
- flat loaded, flat ROM, and banked destinations;
- alternating bank selection while loader state remains visible;
- protected image and writable extents;
- successful entry only after COMMIT;
- a following clean load after failure; and
- byte identity with the existing materializer for every valid fixture.

The implementation reports consumer code, workspace, instruction count, and
T-states separately from the 16 KiB compiler account. Its correctness and size
reviews were completed before the implementation was committed.
