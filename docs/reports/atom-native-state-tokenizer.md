# Native ATOM compiler state and tokenizer

Development checkpoint following `a023f7e`, 2026-09-05. The state and tokenizer
conversion preserves source-language behavior and existing host-symbol names.
The complete compiler still needs the transitional assembler for other source
families; this checkpoint is not a new release.

## Converted source

Five state files now use native ATOM constants and immutable conditionals:
`compiler-state.asmi`, `loop-compiler-state.asmi`, `aggregate-call-state.asmi`,
`target-output-state.asmi` and `loop-z80-state.asmi`. The explicit state export
map has 803 entries, including 23 case-only mappings for existing short names.
Their constants, aliases, declaration order and conditional values are unchanged.

The source adapter, tokenizer, keyword table and native source host also use
native syntax. Their export map has 136 entries: 129 long leaf names, one
case-only mapping and six bindings declared by surrounding compiler/host code.
The source-host local label retains its qualified public name,
`SourceInitializeParts._sourceInitializeNativeState`.

Seven keyword displacements are now explicit late EQU constants. ATOM
calculates them from the group labels and cell addresses; their values are
7, 24, 63, 92, 121, 169 and 184. A small output-only filter excludes those
private constants from the historical host dictionary, while preserving the
native generation, addresses and bytes. It rejects attempts to hide an address
label under a displacement name.

`TokenizerNext` remains an EQU in the streaming-output configuration and a
wrapper label in the earlier configuration. Its native EQU follows the target
label. Character operands use native character syntax; keyword and literal
strings are unchanged.

The grammar generator now emits physical state names for token and diagnostic
references. Grammar JSON, analysis results, logical action names and accepted
source syntax remain unchanged. Generated parser-table directives and parser
labels still require a later conversion.

## Verification boundaries

The ordinary tokenizer trace manifest uses the native helper through
`runProofManifest`. Its 810 code bytes, 437 immutable bytes and 228 proof bytes
are unchanged. Execution remains 2,872 Z80 instructions and 35,927 T-states;
the full dictionary contains 777 symbols and 111 address labels.

The streaming proof imports actual machine/state files and all four converted
source leaves. Only host transport and diagnostic bridges are test-specific.
Its 1,708 bytes match a frozen assembly of the same bridge with `a023f7e`
leaves, with SHA-256
`11f65314505d4ed13942bd00c7481f819dee4af3c85a8e880532837317188818`.
This proves the selected source-host behavior, not the entire compiler.

All six regenerated compiler variants retain their exact HEX strings and
complete public symbol values. Their dictionary counts remain 2,615, 2,616,
2,464, 2,465, 2,735 and 2,736 for normal, debug, native, native-debug, MON-3
and MON-3-debug respectively. Moving the native `TokenizerNext` EQU changes
dictionary insertion order, so the generated TypeScript has an ordering-only
refresh. Runtime catalog, Node runner, import resolver and CP/M embedded assets
remain textually identical to the preceding checkpoint.

State conversion, tokenizer conversion and baseline/test development ran in
parallel, followed by independent cross-reviews. Review found missing established
export maps in the first proof-helper draft; these were added before accepting
dictionary parity. The historical state profile also required conversion of
its actual source, rather than a numeric test substitute.

The final scoped checks passed: 51 source-adapter tests, 38 native state/tokenizer
and source-host tests, 43 CP/M/resolver/provider tests, the ordinary tokenizer
trace, and three grammar keyword/ordinal/reproducibility checks. Typechecking
and the complete compiler-image regeneration check also passed. One older
capacity assertion was updated to require the new native `EQU` spelling.
The 22 source-host execution cases do not newly cover source-position or
token-buffer overflow; broader compiler capacity qualification remains required.

A fresh full CP/M compiler assembly matches the corrected `abbb2be` baseline:
21,271 bytes, 2,803 public symbols, identical address dictionaries and sparse
writes, with SHA-256
`1c047ac1ed5ff1c4e914321b66476b842a1b28cc0dfef4cfdb86f691ca037334`.
This is the private corrected compiler, not the older published release.
These are host-model results, not ESP32 measurements.

## Remaining scope

The scanner currently reports 3,686 long-name ledger entries. Three parser
source sizes are 81,414 bytes for `typed-expression-parser.asm`, 74,882 for
`aggregate-call-parser.asm` and 62,273 for `stage7-ll1-actions.asm`. The first
two still exceed ATOM's 65,535-byte source-part limit before their own renaming
and splitting. These are source sizes, not executable-code measurements.

Generated grammar, parser/backend families, native host composition and remaining
proof inputs precede translator removal. Full standalone and packed-consumer
qualification, Linux CI, release publication, Triptych's immutable pin and hosted
verification remain pending. No browser disk, Triptych source, published compiler
or ESP32 hardware state was changed in this wave.
