import path from "node:path";
import { readFileSync } from "node:fs";

import { describe, expect, it } from "vitest";

import { runProofManifest } from "../src/proof.js";
import { ServiceError, Trap } from "../src/runtime-contract.js";
import { buildSourceParts } from "../src/source-manifest.js";

const proof = (name: string): string =>
  path.resolve(import.meta.dirname, "..", "proofs", `${name}.json`);

const wordAt = (memory: Uint8Array, address: number): number =>
  (memory[address] ?? 0) | ((memory[address + 1] ?? 0) << 8);

describe("manifest-driven AZM and Debug80 proofs", () => {
  it("publishes a flat target through the append-only logical sink", async () => {
    const outcome = await runProofManifest(
      proof("flat-target-z80-slice-proof"),
    );
    expect(outcome.memory[outcome.symbols.ProofStatus ?? -1]).toBe(0xa5);
    expect(outcome.memory[outcome.symbols.ProofCase ?? -1]).toBe(0);
    expect(outcome.instructions).toBe(881_837);
    expect(outcome.cycles).toBe(9_538_860);
    expect(outcome.extents).toEqual([
      { name: "compiler-code", bytes: 14_988 },
      { name: "compiler-immutable", bytes: 398 },
      { name: "compiler-core", bytes: 15_386 },
      { name: "compiler-workspace", bytes: 3_613 },
      { name: "selected-proof-runtime", bytes: 899 },
      { name: "proof-code-and-data", bytes: 2_346 },
    ]);
    expect(outcome.nobj?.parsed.begin.runtimeIdentity).toBe(8);
    expect(outcome.nobj?.parsed.map.entryAddress).toBe(0x8000);
    expect(outcome.nobj?.parsed.map.banks[0]?.usedLength).toBe(881);
    expect(outcome.nobj?.materialized.flatImage?.length).toBe(4096);
    expect(outcome.nobj?.memory[0x8000]).toBe(0xc3);
    expect(outcome.nobj?.memory[0x8003]).not.toBe(0xff);
    expect(
      Array.from(outcome.nobj?.memory.slice(0x8335, 0x8337) ?? []),
    ).toEqual([3, 0]);
    const generated = Array.from(
      outcome.nobj?.memory.slice(0x8337, 0x8371) ?? [],
    );
    const contains = (wanted: readonly number[]): boolean =>
      generated.some((_, index) =>
        wanted.every((byte, offset) => generated[index + offset] === byte),
      );
    expect(contains([0x2a, 0x46, 0x40])).toBe(true); // LD HL,($4046)
    expect(contains([0x22, 0x46, 0x40])).toBe(true); // LD ($4046),HL
    expect(contains([0xcd, 0xb9, 0x80])).toBe(true); // CALL linked MultiplyU16
    const word = (name: string): number =>
      wordAt(outcome.memory, outcome.symbols[name] ?? -1);
    expect(outcome.symbols.ProofEnd).toBeLessThanOrEqual(
      outcome.symbols.AdapterLoadedLogBase ?? -1,
    );
    for (const [base, length, next] of [
      [
        "AdapterLoadedLogBase",
        "AdapterLoadedLogLength",
        "AdapterSuccessLogBase",
      ],
      ["AdapterSuccessLogBase", "AdapterLogLength", "AdapterTrapLogBase"],
      ["AdapterTrapLogBase", "AdapterTrapLogLength", "AdapterUnhandledLogBase"],
      [
        "AdapterUnhandledLogBase",
        "AdapterUnhandledLogLength",
        "AdapterBankedTrapLogBase",
      ],
      [
        "AdapterBankedTrapLogBase",
        "AdapterBankedTrapLogLength",
        "AdapterLogBase",
      ],
      ["AdapterLogBase", "AdapterBankedLogLength", "AdapterFailedLogBase"],
      [
        "AdapterFailedLogBase",
        "AdapterFailedLogLength",
        "AdapterEntry1LogBase",
      ],
      [
        "AdapterEntry1LogBase",
        "AdapterEntry1LogLength",
        "AdapterChapter21LogBase",
      ],
      [
        "AdapterChapter21LogBase",
        "AdapterChapter21LogLength",
        "AdapterLogLimit",
      ],
    ] as const) {
      const endAddress = (outcome.symbols[base] ?? -1) + word(length);
      expect(
        endAddress,
        `${base} must not overlap ${next}`,
      ).toBeLessThanOrEqual(outcome.symbols[next] ?? -1);
    }
  }, 30_000);

  it("fits and executes the complete host-instrumented compiler layout", async () => {
    const outcome = await runProofManifest(
      proof("flat-target-debug-z80-slice-proof"),
    );
    expect(outcome.memory[outcome.symbols.ProofStatus ?? -1]).toBe(0xa5);
    expect(outcome.memory[outcome.symbols.ProofCase ?? -1]).toBe(0);
    expect(outcome.instructions).toBe(885_628);
    expect(outcome.cycles).toBe(9_580_651);
    expect(outcome.extents).toEqual([
      { name: "compiler-code", bytes: 15_044 },
      { name: "compiler-immutable", bytes: 398 },
      { name: "compiler-core", bytes: 15_442 },
      { name: "instrumented-core-gap", bytes: 9_134 },
      { name: "compiler-workspace", bytes: 3_613 },
      { name: "selected-proof-runtime", bytes: 899 },
      { name: "proof-code-and-data", bytes: 2_348 },
    ]);
  }, 30_000);

  it("runs the Stage 7 aggregate-call production path through committed banked NOBJ", async () => {
    const outcome = await runProofManifest(
      proof("banked-target-z80-slice-proof"),
    );
    expect(outcome.nobj?.parsed.begin.banked).toBe(true);
    expect(outcome.nobj?.parsed.map.partBanks).toEqual([1, 0]);
    expect(outcome.nobj?.materialized.banks).toHaveLength(2);
    expect(
      Array.from(outcome.nobj?.materialized.banks[0]?.slice(3, 367) ?? []),
    ).toEqual(
      Array.from(outcome.nobj?.materialized.banks[1]?.slice(3, 367) ?? []),
    );
    expect(wordAt(outcome.nobj?.memory ?? new Uint8Array(), 0x4036)).not.toBe(
      0,
    );
    expect(wordAt(outcome.nobj?.memory ?? new Uint8Array(), 0x4038)).toBe(0);
    expect(outcome.nobj?.memory[0x4048]).toBe(12);
    expect(outcome.nobj?.selectedBank).toBe(1);
  }, 30_000);

  it("runs startup and main from bank 1 through committed banked NOBJ", async () => {
    const outcome = await runProofManifest(
      proof("banked-target-entry1-z80-slice-proof"),
    );
    expect(outcome.nobj?.parsed.map.entryBank).toBe(1);
    expect(outcome.nobj?.parsed.map.partBanks).toEqual([1]);
    expect(outcome.nobj?.memory[0x4046]).toBe(12);
    expect(outcome.nobj?.selectedBank).toBe(1);
  }, 30_000);

  it("restores a cross-bank trap through the common terminal path", async () => {
    const outcome = await runProofManifest(
      proof("banked-target-trap-z80-slice-proof"),
    );
    expect(outcome.nobj?.memory[0x4022]).toBe(3);
    expect(outcome.nobj?.memory[0x4027]).toBe(0);
    expect(outcome.nobj?.selectedBank).toBe(0);
  }, 30_000);

  it("executes loaded startup without copying initialized storage", async () => {
    const outcome = await runProofManifest(
      proof("flat-target-loaded-z80-slice-proof"),
    );
    expect(outcome.nobj?.parsed.map.romMode).toBe(false);
    expect(outcome.nobj?.parsed.map.banks[0]?.usedLength).toBe(0x1048);
    expect(outcome.nobj?.instructions).toBeGreaterThan(0);
  }, 30_000);

  it("restores the established stack after a target trap", async () => {
    const outcome = await runProofManifest(
      proof("flat-target-trap-z80-slice-proof"),
    );
    expect(outcome.nobj?.parsed.map.establishedStack).toBe(true);
    expect(outcome.nobj?.memory[0x4022]).toBe(3);
  }, 30_000);

  it("runs the Stage 8 propagation production path through committed flat NOBJ", async () => {
    const outcome = await runProofManifest(
      proof("flat-target-unhandled-z80-slice-proof"),
    );
    expect(outcome.nobj?.parsed.map.establishedStack).toBe(true);
    expect(outcome.nobj?.memory[0x4026]).toBe(7);
  }, 30_000);

  it("runs the accepted Chapter 21 multipart program through committed NOBJ", async () => {
    const outcome = await runProofManifest(
      proof("chapter21-target-z80-slice-proof"),
    );
    const source = (start: string, end: string): string =>
      new TextDecoder().decode(
        outcome.memory.slice(
          outcome.symbols[start] ?? -1,
          outcome.symbols[end] ?? -1,
        ),
      );
    const specification = readFileSync(
      path.resolve(import.meta.dirname, "..", "docs", "specification.md"),
      "utf8",
    );
    const chapter21 = specification.slice(specification.indexOf("## 21."));
    const firstProgram = /```nucleus\n([\s\S]*?)```/.exec(chapter21)?.[1];
    expect(
      source("Chapter21TargetPart1", "Chapter21TargetPart1End") +
        source("Chapter21TargetPart2", "Chapter21TargetPart2End"),
    ).toBe(firstProgram);
    expect(outcome.nobj?.parsed.map.partBanks).toEqual([0, 0]);
    expect(outcome.nobj?.parsed.map.banks[0]?.usedLength).toBe(1786);
    expect(outcome.nobj?.memory[0x4046]).toBe(4);
    expect(outcome.nobj?.memory[0x7300]).toBe("Y".charCodeAt(0));
  }, 30_000);

  it("retains the historical direct-Z80 Chapter 21 module proof", async () => {
    const outcome = await runProofManifest(
      proof("stage9-conformance-z80-slice-proof"),
    );
    expect(outcome.memory[outcome.symbols.ProofStatus ?? -1]).toBe(0xa5);
    expect(outcome.memory[outcome.symbols.ProofCase ?? -1]).toBe(0);
    expect(
      outcome.extents.find(({ name }) => name === "compiler-core")?.bytes,
    ).toBeLessThanOrEqual(16_384);
    expect(outcome.instructions).toBe(1_406_402);
    expect(outcome.cycles).toBe(13_947_856);
    expect(outcome.extents).toEqual([
      { name: "compiler-code", bytes: 14_556 },
      { name: "compiler-immutable", bytes: 398 },
      { name: "compiler-core", bytes: 14_954 },
      { name: "compiler-workspace", bytes: 3_623 },
      { name: "generated-z80-bound", bytes: 4_096 },
      { name: "z80-runtime", bytes: 921 },
      { name: "corpus-source-and-descriptors", bytes: 8_465 },
      { name: "proof-code-and-data", bytes: 1_935 },
    ]);

    const symbol = (name: string): number => {
      const address = outcome.symbols[name];
      expect(address, `${name} must be retained`).toBeDefined();
      return address ?? -1;
    };
    expect(wordAt(outcome.memory, symbol("ProofMaxGenerated"))).toBe(1_040);
    const source = (start: string, end: string): string =>
      new TextDecoder().decode(
        outcome.memory.slice(symbol(start), symbol(end)),
      );
    const specification = readFileSync(
      path.resolve(import.meta.dirname, "..", "docs", "specification.md"),
      "utf8",
    );
    const chapter21 = specification.slice(specification.indexOf("## 21."));
    const specificationPrograms = Array.from(
      chapter21.matchAll(/```nucleus\n([\s\S]*?)```/g),
      (match) => match[1] ?? "",
    );
    const proofPrograms = [
      source("Chapter21_1Part1", "Chapter21_1Part1End") +
        source("Chapter21_1Part2", "Chapter21_1Part2End"),
      ...[
        "Chapter21_2",
        "Chapter21_3",
        "Chapter21_4",
        "Chapter21_5",
        "Chapter21_6",
        "Chapter21_7",
        "Chapter21_8",
        "Chapter21_9Bounds",
        "Chapter21_9Divide",
        "Chapter21_9Modulo",
        "Chapter21_10Unconsumed",
        "Chapter21_10Nominal",
        "Chapter21_10Initializer",
        "Chapter21_10AggregateLocal",
        "Chapter21_10RoutineFlow",
        "Chapter21_10Later",
        "Chapter21_10MainSignature",
        "Chapter21_10ActiveCounter",
        "Chapter21_10ExactUse",
        "Chapter21_10Hex",
        "Chapter21_10Binary",
        "Chapter21_12",
        "Chapter21_13",
        "Chapter21_14",
        "Chapter21_15",
        "Chapter21_16",
        "Chapter21_17",
        "Chapter21_17Boolean",
        "Chapter21_18",
        "Chapter21_18Zero",
        "Chapter21_19",
        "Chapter21_19False",
        "Chapter21_19Type",
        "Chapter21_20",
        "Chapter21_20ReadOnly",
        "Chapter21_21",
      ].map((name) => source(`${name}Source`, `${name}SourceEnd`)),
    ];
    expect(specificationPrograms).toHaveLength(37);
    expect(proofPrograms).toEqual(specificationPrograms);

    const manifestParts = buildSourceParts("model.nu\n\nmain.nu\n", (name) =>
      name === "model.nu"
        ? outcome.memory.slice(
            symbol("Chapter21_1Part1"),
            symbol("Chapter21_1Part1End"),
          )
        : outcome.memory.slice(
            symbol("Chapter21_1Part2"),
            symbol("Chapter21_1Part2End"),
          ),
    );
    expect(
      manifestParts.map(({ ordinal, diagnosticName, stableIdentity }) => ({
        ordinal,
        diagnosticName,
        stableIdentity,
      })),
    ).toEqual([
      {
        ordinal: 1,
        diagnosticName: "model.nu",
        stableIdentity: "1:model.nu",
      },
      {
        ordinal: 2,
        diagnosticName: "main.nu",
        stableIdentity: "2:main.nu",
      },
    ]);
    expect(
      new TextDecoder().decode(manifestParts[0]?.bytes ?? new Uint8Array()) +
        new TextDecoder().decode(manifestParts[1]?.bytes ?? new Uint8Array()),
    ).toBe(specificationPrograms[0]);
    expect(manifestParts[1]?.diagnosticName).toBe("main.nu");
  }, 30_000);

  it("retains the historical direct-Z80 Stage 8 module proof", async () => {
    const outcome = await runProofManifest(
      proof("stage8-failure-z80-slice-proof"),
    );
    expect(outcome.memory[outcome.symbols.ProofStatus ?? -1]).toBe(0xa5);
    expect(outcome.memory[outcome.symbols.ProofCase ?? -1]).toBe(0);
    expect(
      outcome.extents.find(({ name }) => name === "compiler-core")?.bytes,
    ).toBeLessThanOrEqual(16_384);
    expect(outcome.instructions).toBe(1_717_661);
    expect(outcome.cycles).toBe(16_744_435);
    expect(outcome.extents).toEqual([
      { name: "compiler-code", bytes: 14_556 },
      { name: "compiler-immutable", bytes: 398 },
      { name: "compiler-core", bytes: 14_954 },
      { name: "compiler-workspace", bytes: 3_623 },
      { name: "generated-z80-bound", bytes: 4_096 },
      { name: "z80-runtime", bytes: 921 },
      { name: "proof-code-and-data", bytes: 3_730 },
    ]);

    const symbol = (name: string): number => {
      const address = outcome.symbols[name];
      expect(
        address,
        `${name} must be retained by the assembled proof`,
      ).toBeDefined();
      return address ?? -1;
    };
    const generatedBase = symbol("GeneratedBase");
    const generatedLimit = symbol("GeneratedLimit");
    const generatedSize = wordAt(outcome.memory, symbol("GeneratedSize"));
    expect(generatedBase + generatedSize).toBeLessThanOrEqual(generatedLimit);

    const runtimeStart = symbol("RuntimeCodeStart");
    const runtimeEnd = symbol("RuntimeCodeEnd");
    for (const entry of [
      "ReadInputByte",
      "WriteOutputByte",
      "ReadStorageByte",
      "RewindStorageInput",
      "WriteStorageByte",
      "SeekStorageOutput",
      "ActivationClaim",
      "ActivationRelease",
    ]) {
      expect(
        symbol(entry),
        `${entry} must lie in the selected runtime`,
      ).toBeGreaterThanOrEqual(runtimeStart);
      expect(
        symbol(entry),
        `${entry} must lie in the selected runtime`,
      ).toBeLessThan(runtimeEnd);
    }
    expect(generatedLimit).toBeLessThanOrEqual(runtimeStart);
    expect(runtimeEnd).toBeLessThanOrEqual(symbol("TargetRuntimeLimit"));
  }, 30_000);

  it("locks the bounded vertical-slice memory map", async () => {
    const outcome = await runProofManifest(proof("memory-map-proof"));

    expect(outcome.instructions).toBe(4);
    expect(outcome.cycles).toBe(34);
    expect(outcome.extents).toEqual([{ name: "proof-code", bytes: 9 }]);
    expect(outcome.regions.map(({ name, bytes }) => ({ name, bytes }))).toEqual(
      [
        { name: "compiler-core", bytes: 16_384 },
        { name: "compiler-workspace", bytes: 4_096 },
        { name: "source", bytes: 2_048 },
        { name: "generated-output", bytes: 4_096 },
        { name: "target-runtime", bytes: 4_096 },
        { name: "execution-state", bytes: 4_096 },
        { name: "service-state", bytes: 2_048 },
        { name: "proof-state", bytes: 2_048 },
        { name: "unassigned", bytes: 22_528 },
        { name: "machine-stack", bytes: 3_840 },
        { name: "high-reserved", bytes: 256 },
      ],
    );
    expect(
      outcome.regions.reduce((total, region) => total + region.bytes, 0),
    ).toBe(65_536);
  });

  it("traces comparison and slash tokens through multipart line endings", async () => {
    const outcome = await runProofManifest(proof("tokenizer-trace-proof"));

    expect(outcome.memory[outcome.symbols.ProofStatus ?? -1]).toBe(0xa5);
    expect(outcome.memory[outcome.symbols.ProofCase ?? -1]).toBe(0);
    expect(outcome.instructions).toBe(2_904);
    expect(outcome.cycles).toBe(36_503);
    expect(outcome.extents).toEqual([
      { name: "compiler-code", bytes: 855 },
      { name: "compiler-immutable", bytes: 398 },
      { name: "compiler-core", bytes: 1_253 },
      { name: "proof-code-and-data", bytes: 228 },
    ]);
    expect(outcome.symbols.TokenLessEqual).toBe(
      (outcome.symbols.TokenLess ?? -1) + 1,
    );
    expect(outcome.symbols.TokenGreaterEqual).toBe(
      (outcome.symbols.TokenGreater ?? -1) + 1,
    );
    expect(outcome.symbols.TokenNotEqual).toBe(37);
  });

  it("compiles the fixed source and rejects a malformed source by position", async () => {
    const outcome = await runProofManifest(proof("compiler-slice-proof"));

    expect(outcome.memory[outcome.symbols.ProofStatus ?? -1]).toBe(0xa5);
    expect(outcome.memory[outcome.symbols.ProofCase ?? -1]).toBe(0);
    expect(outcome.instructions).toBe(8_199);
    expect(outcome.cycles).toBe(85_556);
    expect(outcome.extents).toEqual([
      { name: "compiler-code", bytes: 922 },
      { name: "compiler-immutable", bytes: 38 },
      { name: "compiler-core", bytes: 960 },
      { name: "compiler-workspace", bytes: 55 },
      { name: "proof-code-and-data", bytes: 191 },
    ]);
    expect(outcome.extents[0]?.bytes).toBeLessThan(
      outcome.extents[2]?.bytes ?? 0,
    );
    expect(outcome.extents[2]?.bytes).toBeLessThanOrEqual(16_384);
  });

  it("executes the same checked operations as a direct-Z80 program", async () => {
    const outcome = await runProofManifest(proof("z80-slice-proof"));
    const generatedBase = outcome.symbols.GeneratedBase ?? -1;
    const generatedSize = outcome.symbols.ProgramSize ?? -1;
    const generated = outcome.memory.slice(
      generatedBase,
      generatedBase + generatedSize,
    );

    expect(outcome.instructions).toBe(4_424);
    expect(outcome.cycles).toBe(46_780);
    expect(outcome.extents).toEqual([
      { name: "common-front-end", bytes: 922 },
      { name: "z80-output-sink", bytes: 25 },
      { name: "compiler-code", bytes: 947 },
      { name: "compiler-immutable", bytes: 75 },
      { name: "compiler-core", bytes: 1_022 },
      { name: "compiler-workspace", bytes: 55 },
      { name: "generated-z80", bytes: 37 },
      { name: "z80-runtime", bytes: 51 },
      { name: "z80-state", bytes: 6 },
      { name: "service-state", bytes: 3 },
      { name: "proof-code-and-data", bytes: 207 },
    ]);
    expect(Array.from(generated.slice(0, 3))).toEqual([0x3e, 0x41, 0xcd]);
    expect(generated[3] | ((generated[4] ?? 0) << 8)).toBe(
      outcome.symbols.WriteOutputByte,
    );
    expect(Array.from(generated.slice(5, 8))).toEqual([0x38, 0x06, 0x3e]);
    expect(outcome.memory[outcome.symbols.ProofSuccessOutput ?? -1]).toBe(0x41);
    expect(outcome.memory[outcome.symbols.TrapNumber ?? -1]).toBe(
      Trap.unhandledError,
    );
    expect(outcome.memory[outcome.symbols.TrapError ?? -1]).toBe(
      ServiceError.outputFailure,
    );
  });

  it("checks the scalar-local and counted-loop source slice", async () => {
    const outcome = await runProofManifest(proof("loop-compiler-slice-proof"));
    expect(outcome.instructions).toBe(37_531);
    expect(outcome.cycles).toBe(409_736);
    expect(outcome.extents).toEqual([
      { name: "compiler-code", bytes: 8_562 },
      { name: "compiler-immutable", bytes: 267 },
      { name: "compiler-core", bytes: 8_829 },
      { name: "compiler-workspace", bytes: 1_566 },
      { name: "proof-code-and-data", bytes: 241 },
    ]);
    expect(outcome.memory[outcome.symbols.ProofStatus ?? -1]).toBe(0xa5);
    expect(outcome.memory[outcome.symbols.ProofCase ?? -1]).toBe(0);
    expect(outcome.memory[outcome.symbols.DiagnosticCode ?? -1]).toBe(
      outcome.symbols.DiagnosticExpectedEnd,
    );
  }, 20_000);

  it("executes the counted loop as direct Z80", async () => {
    const outcome = await runProofManifest(proof("loop-z80-slice-proof"));
    const generatedBase = outcome.symbols.GeneratedBase ?? -1;
    const generatedSize = outcome.symbols.ProgramSize ?? -1;
    const generated = outcome.memory.slice(
      generatedBase,
      generatedBase + generatedSize,
    );

    expect(outcome.instructions).toBe(34_693);
    expect(outcome.cycles).toBe(375_472);
    expect(outcome.extents).toEqual([
      { name: "common-front-end", bytes: 8_562 },
      { name: "z80-output-sink", bytes: 1_509 },
      { name: "compiler-code", bytes: 10_071 },
      { name: "compiler-immutable", bytes: 267 },
      { name: "compiler-core", bytes: 10_338 },
      { name: "compiler-workspace", bytes: 1_566 },
      { name: "generated-z80", bytes: 54 },
      { name: "z80-runtime", bytes: 796 },
      { name: "z80-state", bytes: 21 },
      { name: "service-state", bytes: 28 },
      { name: "proof-code-and-data", bytes: 298 },
    ]);
    expect(Array.from(generated.slice(0, 7))).toEqual([
      0x16, 0x00, 0x16, 0x00, 0x7a, 0xfe, 0x03,
    ]);
  }, 20_000);

  it("executes checked initialized-array selection as direct Z80", async () => {
    const outcome = await runProofManifest(proof("array-z80-slice-proof"));
    expect(outcome.instructions).toBe(51_307);
    expect(outcome.cycles).toBe(544_001);
    expect(outcome.extents).toEqual([
      { name: "common-front-end", bytes: 8_562 },
      { name: "source-adapter", bytes: 87 },
      { name: "tokenizer", bytes: 688 },
      { name: "semantic-sink", bytes: 88 },
      { name: "parser", bytes: 7_589 },
      { name: "z80-output-sink", bytes: 1_509 },
      { name: "compiler-code", bytes: 10_071 },
      { name: "compiler-immutable", bytes: 267 },
      { name: "compiler-core", bytes: 10_338 },
      { name: "compiler-workspace", bytes: 1_566 },
      { name: "generated-z80", bytes: 74 },
      { name: "z80-runtime", bytes: 796 },
      { name: "z80-state", bytes: 21 },
      { name: "service-state", bytes: 28 },
      { name: "proof-code-and-data", bytes: 661 },
    ]);

    expect(outcome.memory[outcome.symbols.ProofStatus ?? -1]).toBe(0xa5);
    expect(outcome.memory[outcome.symbols.ProofCase ?? -1]).toBe(0);
  }, 20_000);

  it("executes a forward-declared recursive scalar value call", async () => {
    const outcome = await runProofManifest(proof("call-z80-slice-proof"));
    expect(outcome.instructions).toBe(57_514);
    expect(outcome.cycles).toBe(613_352);
    expect(outcome.extents).toEqual([
      { name: "common-front-end", bytes: 8_562 },
      { name: "source-adapter", bytes: 87 },
      { name: "tokenizer", bytes: 688 },
      { name: "semantic-sink", bytes: 88 },
      { name: "parser", bytes: 7_589 },
      { name: "call-parser-path", bytes: 336 },
      { name: "z80-output-sink", bytes: 1_509 },
      { name: "z80-call-backend", bytes: 337 },
      { name: "compiler-code", bytes: 10_071 },
      { name: "compiler-immutable", bytes: 267 },
      { name: "compiler-core", bytes: 10_338 },
      { name: "compiler-workspace", bytes: 1_566 },
      { name: "generated-z80", bytes: 99 },
      { name: "z80-runtime", bytes: 796 },
      { name: "z80-state", bytes: 21 },
      { name: "service-state", bytes: 28 },
      { name: "proof-code-and-data", bytes: 414 },
    ]);
    const generatedSizeAddress = outcome.symbols.GeneratedSize ?? -1;
    expect(
      (outcome.memory[generatedSizeAddress] ?? 0) |
        ((outcome.memory[generatedSizeAddress + 1] ?? 0) << 8),
    ).toBe(99);
    const semanticBase = outcome.symbols.SemanticBufferBase ?? -1;
    expect(
      Array.from(outcome.memory.slice(semanticBase, semanticBase + 16)),
    ).toEqual([9, 12, 1, 3, 13, 19, 14, 1, 15, 0, 16, 17, 18, 1, 1, 19]);
    expect(outcome.memory[outcome.symbols.ProofStatus ?? -1]).toBe(0xa5);
    expect(outcome.memory[outcome.symbols.ProofCase ?? -1]).toBe(0);
    const emitUpdateExitFixup = outcome.symbols.EmitUpdateExitFixup ?? -1;
    const tokenStartOffset = outcome.symbols.TokenStartOffset ?? -1;
    const tokenStartEnd = (outcome.symbols.TokenStartColumn ?? -1) + 2;
    expect(
      emitUpdateExitFixup + 2 <= tokenStartOffset ||
        emitUpdateExitFixup >= tokenStartEnd,
    ).toBe(true);
    expect(
      (outcome.symbols.CallProofRecursiveCall ?? -1) -
        (outcome.symbols.CallProofSource ?? -1),
    ).toBe(outcome.symbols.CallCapacityOffset);
    expect(
      (outcome.symbols.CallProofOutputCall ?? -1) -
        (outcome.symbols.CallProofSource ?? -1),
    ).toBe(outcome.symbols.CallFailureOffset);
    expect(
      new Set(
        [
          "CallLiteral",
          "CallWriteLocal",
          "CallBeginForward",
          "CallIfParameterZero",
          "CallReturnParameter",
          "CallEndIf",
          "CallReturnSelfMinus",
          "CallEndRoutine",
        ].map((name) => outcome.symbols[name] ?? -1),
      ).size,
    ).toBe(8);
  }, 20_000);

  it("executes general scalar symbols and precedence as direct Z80", async () => {
    const outcome = await runProofManifest(proof("expression-z80-slice-proof"));
    const generatedSizeAddress = outcome.symbols.GeneratedSize ?? -1;
    const generatedSize =
      (outcome.memory[generatedSizeAddress] ?? 0) |
      ((outcome.memory[generatedSizeAddress + 1] ?? 0) << 8);

    expect(outcome.instructions).toBe(109_431);
    expect(outcome.cycles).toBe(1_162_141);
    expect(outcome.extents).toEqual([
      { name: "common-front-end", bytes: 8_562 },
      { name: "source-adapter", bytes: 87 },
      { name: "tokenizer", bytes: 688 },
      { name: "semantic-sink", bytes: 88 },
      { name: "symbol-table", bytes: 110 },
      { name: "parser", bytes: 7_589 },
      { name: "z80-output-sink", bytes: 3_391 },
      { name: "z80-expression-backend", bytes: 351 },
      { name: "compiler-code", bytes: 11_953 },
      { name: "compiler-immutable", bytes: 267 },
      { name: "compiler-core", bytes: 12_220 },
      { name: "compiler-workspace", bytes: 1_566 },
      { name: "generated-z80", bytes: 116 },
      { name: "z80-runtime", bytes: 796 },
      { name: "z80-state", bytes: 21 },
      { name: "service-state", bytes: 28 },
      { name: "proof-code-and-data", bytes: 496 },
    ]);
    expect(outcome.memory[outcome.symbols.ProofStatus ?? -1]).toBe(0xa5);
    expect(outcome.memory[outcome.symbols.ProofCase ?? -1]).toBe(0);
    expect(generatedSize).toBeGreaterThan(0);
    expect(outcome.memory[(outcome.symbols.GeneratedBase ?? -1) + 3]).toBe(0);
  }, 20_000);

  it("executes typed scalar expressions and traps atomically as direct Z80", async () => {
    const outcome = await runProofManifest(
      proof("typed-expression-z80-slice-proof"),
    );
    expect(outcome.memory[outcome.symbols.ProofStatus ?? -1]).toBe(0xa5);
    expect(outcome.memory[outcome.symbols.ProofCase ?? -1]).toBe(0);
    const sizeAddress = outcome.symbols.TypedGeneratedSize ?? -1;
    const generatedSize =
      (outcome.memory[sizeAddress] ?? 0) |
      ((outcome.memory[sizeAddress + 1] ?? 0) << 8);
    expect(outcome.instructions).toBe(626_047);
    expect(outcome.cycles).toBe(6_469_999);
    expect(outcome.extents).toEqual([
      { name: "common-front-end", bytes: 8_562 },
      { name: "source-adapter", bytes: 87 },
      { name: "tokenizer", bytes: 688 },
      { name: "semantic-sink", bytes: 88 },
      { name: "symbol-table", bytes: 110 },
      { name: "parser", bytes: 7_589 },
      { name: "typed-z80-sink", bytes: 1_882 },
      { name: "compiler-code", bytes: 10_853 },
      { name: "compiler-immutable", bytes: 267 },
      { name: "compiler-core", bytes: 11_120 },
      { name: "compiler-workspace", bytes: 1_566 },
      { name: "generated-z80-bound", bytes: 857 },
      { name: "z80-runtime", bytes: 796 },
      { name: "proof-code-and-data", bytes: 1_929 },
    ]);
    expect(generatedSize).toBe(857);
  }, 30_000);

  it("executes typed structured control as direct Z80", async () => {
    const outcome = await runProofManifest(
      proof("structured-control-z80-slice-proof"),
    );
    expect(outcome.memory[outcome.symbols.ProofStatus ?? -1]).toBe(0xa5);
    expect(outcome.memory[outcome.symbols.ProofCase ?? -1]).toBe(0);
    const structuredSizeAddress = outcome.symbols.StructuredGeneratedSize ?? -1;
    const structuredSize =
      (outcome.memory[structuredSizeAddress] ?? 0) |
      ((outcome.memory[structuredSizeAddress + 1] ?? 0) << 8);
    expect(structuredSize).toBe(715);
    expect(outcome.memory[outcome.symbols.AcceptedObservedOutput ?? -1]).toBe(
      9,
    );
    expect(outcome.memory[outcome.symbols.AcceptedObservedStore ?? -1]).toBe(9);
    expect(outcome.memory[outcome.symbols.AcceptedObservedCounter ?? -1]).toBe(
      3,
    );
    const descending = outcome.symbols.AcceptedObservedDescending ?? -1;
    expect(
      (outcome.memory[descending] ?? 0) |
        ((outcome.memory[descending + 1] ?? 0) << 8),
    ).toBe(0);
    expect(outcome.memory[outcome.symbols.RangeObservedEffect ?? -1]).toBe(1);
    expect(outcome.memory[outcome.symbols.RangeObservedAtomic ?? -1]).toBe(120);
    const readWord = (name: string): number => {
      const address = outcome.symbols[name] ?? -1;
      return (
        (outcome.memory[address] ?? 0) |
        ((outcome.memory[address + 1] ?? 0) << 8)
      );
    };
    expect(outcome.memory[outcome.symbols.ActiveObservedDiagnostic ?? -1]).toBe(
      36,
    );
    expect(readWord("ActiveObservedOffset")).toBe(
      (outcome.symbols.StructuredActiveCounterName ?? 0) -
        (outcome.symbols.StructuredActiveCounterSource ?? 0),
    );
    expect(outcome.memory[outcome.symbols.ExitObservedDiagnostic ?? -1]).toBe(
      72,
    );
    expect(readWord("ExitObservedOffset")).toBe(
      (outcome.symbols.StructuredExitOutsidePoint ?? 0) -
        (outcome.symbols.StructuredExitOutsideSource ?? 0),
    );
    expect(outcome.memory[outcome.symbols.StepObservedDiagnostic ?? -1]).toBe(
      74,
    );
    expect(readWord("StepObservedOffset")).toBe(
      (outcome.symbols.StructuredZeroStepPoint ?? 0) -
        (outcome.symbols.StructuredZeroStepSource ?? 0),
    );
    expect(
      outcome.extents.find(({ name }) => name === "compiler-core")?.bytes,
    ).toBeLessThanOrEqual(16_384);
    expect(outcome.instructions).toBe(252_546);
    expect(outcome.cycles).toBe(2_689_153);
    expect(outcome.extents).toEqual([
      { name: "common-front-end", bytes: 8_562 },
      { name: "parser", bytes: 7_589 },
      { name: "structured-z80-sink", bytes: 1_882 },
      { name: "compiler-code", bytes: 10_853 },
      { name: "compiler-immutable", bytes: 267 },
      { name: "compiler-core", bytes: 11_120 },
      { name: "compiler-workspace", bytes: 1_566 },
      { name: "generated-z80-bound", bytes: 715 },
      { name: "z80-runtime", bytes: 796 },
      { name: "proof-code-and-data", bytes: 902 },
    ]);
  }, 30_000);

  it("emits packed aggregate layouts and publishes one atomic static image", async () => {
    const outcome = await runProofManifest(proof("aggregate-z80-slice-proof"));
    expect(outcome.memory[outcome.symbols.ProofStatus ?? -1]).toBe(0xa5);
    expect(outcome.memory[outcome.symbols.ProofCase ?? -1]).toBe(0);
    expect(outcome.instructions).toBe(301_423);
    expect(outcome.cycles).toBe(3_061_874);
    expect(
      outcome.extents.find(({ name }) => name === "compiler-core")?.bytes,
    ).toBeLessThanOrEqual(16_384);
    expect(outcome.extents).toEqual([
      { name: "common-front-end", bytes: 7_243 },
      { name: "parser", bytes: 6_273 },
      { name: "typed-z80-sink", bytes: 1_928 },
      { name: "compiler-code", bytes: 9_580 },
      { name: "compiler-immutable", bytes: 251 },
      { name: "compiler-core", bytes: 9_831 },
      { name: "compiler-workspace", bytes: 1_566 },
      { name: "static-image", bytes: 255 },
      { name: "z80-runtime", bytes: 796 },
      { name: "proof-code-and-data", bytes: 1_343 },
    ]);
  }, 30_000);

  it("measures dense semantic dispatch against a comparison chain", async () => {
    const outcome = await runProofManifest(proof("dispatcher-measurement"));
    const direct = await runProofManifest(
      proof("dispatcher-offset-direct-measurement"),
    );
    const trampoline = await runProofManifest(
      proof("dispatcher-offset-trampoline-measurement"),
    );
    expect(outcome.extents.slice(0, 2)).toEqual([
      { name: "table-dispatch-selection", bytes: 37 },
      { name: "comparison-chain-selection", bytes: 42 },
    ]);
    expect(direct.extents).toEqual([
      { name: "page-offset-direct-selection", bytes: 23 },
    ]);
    expect(trampoline.extents).toEqual([
      { name: "page-offset-trampoline-selection", bytes: 47 },
    ]);
  }, 20_000);
});
