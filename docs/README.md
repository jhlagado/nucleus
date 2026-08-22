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
- [`native-z80-host-contract.md`](native-z80-host-contract.md) defines the
  compiler-host ABI, streaming source and object boundaries, and the separate
  Z80 NOBJ consumer-platform ABI.
- [`mon3-host-binding.md`](mon3-host-binding.md) records the implemented
  `RST 10h` deployment, memory map, service selectors, measurements, and the
  remaining machine-specific provider work.
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
