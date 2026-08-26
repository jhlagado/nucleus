# Nucleus documentation

Nucleus 0.1 is a small, safe, general-purpose structured language for Z80 and other constrained systems.

- [`specification.md`](specification.md) is the working Nucleus 0.1 Language Specification and governs source-language conformance at its current revision.
- [`language-tour.md`](language-tour.md) introduces the main source forms and
  links each summary back to the normative specification.
- [`host-api.md`](host-api.md) defines the supported Node, project-file and command-line interfaces.
- [`d8-source-maps.md`](d8-source-maps.md) defines the conditional trace ABI,
  validation rules, and D8 sidecar production.
- [`host-integration.md`](host-integration.md) records the implemented boundary
  between the standalone compiler and Debug80.
- [`target-system-specification.md`](target-system-specification.md) governs
  target profiles, program images, startup, entry, and banked-program
  composition.
- [`nucleus-object-format.md`](nucleus-object-format.md) governs the binary
  append-only object stream, patch records, integrity check, and commit.
- [`z80-runtime-contract.md`](z80-runtime-contract.md) governs packed representation, generated-code integrity, services, traps, and direct Z80 execution; the language specification remains authoritative for source-language meaning.
- [`z80-platform-services.md`](z80-platform-services.md) defines the native-first
  system-services architecture shared by the Z80 resolver, compiler adapter,
  NOBJ writer, loader, and generated program, with separate MON3, CP/M, and Node
  bindings.
- [`z80-object-services-abi.md`](z80-object-services-abi.md) defines the common
  request block and named-object operations used by Z80 development tools.
- [`z80-platform-services-abi.md`](z80-platform-services-abi.md) records the
  current MON3 selector binding and its transition to the common object
  services.
- [`native-z80-host-contract.md`](native-z80-host-contract.md) defines the
  compiler and NOBJ-loader adapter ABIs over that common platform boundary.
- [`mon3-host-binding.md`](mon3-host-binding.md) records the implemented
  compiler-side `RST 10h` deployment, memory map, allocated selectors,
  measurements, and the remaining common-platform work.
- [`tec1-native-host-roadmap.md`](tec1-native-host-roadmap.md) turns the common
  ABI into a concrete first TEC-1/TECM8 compile, load, and run milestone.
- [`implementation-plan.md`](implementation-plan.md) records the non-normative construction order, measurement accounts, capacity ledger, and readiness gates for the first Z80 implementation.
- [`reviewers-charter.md`](reviewers-charter.md) records the settled project directions, open measurements, and evidence expected from an adversarial review. It guides review work but does not override the normative authorities.
- [`oddities.md`](oddities.md) records deliberate first-time surprises and the
  language-finish backlog without overriding the specification.

Implementation records, deferred proposals, and active plans live in
[`plans/`](plans/); each file's status header says which it is. Machine-readable
grammar sources and generated LL(1) tables live in [`../grammar/`](../grammar/)
rather than under documentation.

The [native Z80 host and standard-library
plan](plans/2026-08-20-native-z80-host-and-standard-library.md) records the
streaming host, import resolver, console library, and MON3 gateway increments,
plus the remaining native filesystem integration.

The implemented [direct NOBJ loader
design](plans/2026-08-21-direct-nobj-loader.md) records the one-read loader
model: IMAGE bytes are deposited into their destination, PATCH records
overwrite them in stream order, and only valid COMMIT permits entry.

The active [one-platform convergence
plan](plans/2026-08-23-z80-platform-services-convergence.md) sequences runtime-
catalog selection, common Node and MON3 dispatch, compiler and loader adapters,
generated-program services, TEC-FS integration, and the native vertical slice.
Its Node compiler, NOBJ consumer, flat and banked runner, and generated-program
service stages are implemented. TECM8 now supplies the native named-object
provider; native resolver/compiler/writer/loader integration remains.
