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

// Full flat-proof assembly with native ATOM measured 145 seconds / 752,560,907
// emulated assembler instructions. This host deadline includes construction;
// the proof manifest's guest instruction, cycle and memory limits are unchanged.
const atomProofHostTimeoutMs = 300_000;

describe("manifest-driven ATOM and standalone Z80 runtime proofs", () => {
  it("publishes a flat target through the append-only logical sink", async () => {
    const outcome = await runProofManifest(
      proof("flat-target-z80-slice-proof"),
    );
    expect(outcome.memory[outcome.symbols.ProofStatus ?? -1]).toBe(0xa5);
    expect(outcome.memory[outcome.symbols.ProofCase ?? -1]).toBe(0);
    expect(outcome.instructions).toBe(874_979);
    expect(outcome.cycles).toBe(9_619_341);
    expect(outcome.extents).toEqual([
      { name: "compiler-code", bytes: 15_844 },
      { name: "compiler-immutable", bytes: 437 },
      { name: "compiler-core", bytes: 16_281 },
      { name: "compiler-workspace", bytes: 3_918 },
      { name: "selected-proof-runtime", bytes: 899 },
      { name: "proof-code-and-data", bytes: 2_355 },
    ]);
    expect(outcome.nobj?.parsed.begin.runtimeIdentity).toBe(10);
    expect(outcome.nobj?.parsed.map.entryAddress).toBe(0x8000);
    expect(outcome.nobj?.parsed.map.banks[0]?.usedLength).toBe(931);
    expect(outcome.nobj?.materialized.flatImage?.length).toBe(4096);
    expect(outcome.nobj?.memory[0x8000]).toBe(0xc3);
    expect(outcome.nobj?.memory[0x8003]).not.toBe(0xff);
    expect(
      Array.from(outcome.nobj?.memory.slice(0x8367, 0x8369) ?? []),
    ).toEqual([3, 0]);
    const generated = Array.from(
      outcome.nobj?.memory.slice(0x8369, 0x83a3) ?? [],
    );
    const contains = (wanted: readonly number[]): boolean =>
      generated.some((_, index) =>
        wanted.every((byte, offset) => generated[index + offset] === byte),
      );
    expect(contains([0x2a, 0x4d, 0x40])).toBe(true); // LD HL,($404D)
    expect(contains([0x22, 0x4d, 0x40])).toBe(true); // LD ($404D),HL
    expect(contains([0xcd, 0xba, 0x80])).toBe(true); // CALL linked MultiplyU16
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
  }, atomProofHostTimeoutMs);

  it("fits and executes the complete host-instrumented compiler layout", async () => {
    const outcome = await runProofManifest(
      proof("flat-target-debug-z80-slice-proof"),
    );
    expect(outcome.memory[outcome.symbols.ProofStatus ?? -1]).toBe(0xa5);
    expect(outcome.memory[outcome.symbols.ProofCase ?? -1]).toBe(0);
    expect(outcome.instructions).toBe(878_604);
    expect(outcome.cycles).toBe(9_659_306);
    expect(outcome.extents).toEqual([
      { name: "compiler-code", bytes: 15_910 },
      { name: "compiler-immutable", bytes: 437 },
      { name: "compiler-core", bytes: 16_347 },
      { name: "instrumented-core-gap", bytes: 8_229 },
      { name: "compiler-workspace", bytes: 3_918 },
      { name: "selected-proof-runtime", bytes: 899 },
      { name: "proof-code-and-data", bytes: 2_357 },
    ]);
  }, atomProofHostTimeoutMs);

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
    expect(wordAt(outcome.nobj?.memory ?? new Uint8Array(), 0x4039)).not.toBe(
      0,
    );
    expect(wordAt(outcome.nobj?.memory ?? new Uint8Array(), 0x403b)).toBe(0);
    expect(outcome.nobj?.memory[0x404f]).toBe(12);
    expect(outcome.nobj?.selectedBank).toBe(1);
  }, atomProofHostTimeoutMs);

  it("runs startup and main from bank 1 through committed banked NOBJ", async () => {
    const outcome = await runProofManifest(
      proof("banked-target-entry1-z80-slice-proof"),
    );
    expect(outcome.nobj?.parsed.map.entryBank).toBe(1);
    expect(outcome.nobj?.parsed.map.partBanks).toEqual([1]);
    expect(outcome.nobj?.memory[0x404d]).toBe(12);
    expect(outcome.nobj?.selectedBank).toBe(1);
  }, atomProofHostTimeoutMs);

  it("restores a cross-bank trap through the common terminal path", async () => {
    const outcome = await runProofManifest(
      proof("banked-target-trap-z80-slice-proof"),
    );
    expect(outcome.nobj?.memory[0x4025]).toBe(3);
    expect(outcome.nobj?.memory[0x402a]).toBe(0);
    expect(outcome.nobj?.selectedBank).toBe(0);
  }, atomProofHostTimeoutMs);

  it("executes loaded startup without copying initialized storage", async () => {
    const outcome = await runProofManifest(
      proof("flat-target-loaded-z80-slice-proof"),
    );
    expect(outcome.nobj?.parsed.map.romMode).toBe(false);
    expect(outcome.nobj?.parsed.map.banks[0]?.usedLength).toBe(0x104f);
    expect(outcome.nobj?.instructions).toBeGreaterThan(0);
  }, atomProofHostTimeoutMs);

  it("restores the established stack after a target trap", async () => {
    const outcome = await runProofManifest(
      proof("flat-target-trap-z80-slice-proof"),
    );
    expect(outcome.nobj?.parsed.map.establishedStack).toBe(true);
    expect(outcome.nobj?.memory[0x4025]).toBe(3);
  }, atomProofHostTimeoutMs);

  it("runs the Stage 8 propagation production path through committed flat NOBJ", async () => {
    const outcome = await runProofManifest(
      proof("flat-target-unhandled-z80-slice-proof"),
    );
    expect(outcome.nobj?.parsed.map.establishedStack).toBe(true);
    expect(outcome.nobj?.memory[0x4029]).toBe(7);
  }, atomProofHostTimeoutMs);

  it("runs the accepted Chapter 18 multipart program through committed NOBJ", async () => {
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
    const chapter18 = specification.slice(specification.indexOf("## 18."));
    const firstProgram = /```nucleus\n([\s\S]*?)```/.exec(chapter18)?.[1];
    expect(
      source("Chapter21TargetPart1", "Chapter21TargetPart1End") +
        source("Chapter21TargetPart2", "Chapter21TargetPart2End"),
    ).toBe(firstProgram);
    expect(outcome.nobj?.parsed.map.partBanks).toEqual([0, 0]);
    expect(outcome.nobj?.parsed.map.banks[0]?.usedLength).toBe(1836);
    expect(outcome.nobj?.memory[0x404d]).toBe(4);
    expect(outcome.nobj?.memory[0x7300]).toBe("Y".charCodeAt(0));
  }, atomProofHostTimeoutMs);

  it("retains the historical direct-Z80 Chapter 18 module proof", async () => {
    const outcome = await runProofManifest(
      proof("stage9-conformance-z80-slice-proof"),
    );
    expect(outcome.memory[outcome.symbols.ProofStatus ?? -1]).toBe(0xa5);
    expect(outcome.memory[outcome.symbols.ProofCase ?? -1]).toBe(0);
    expect(
      outcome.extents.find(({ name }) => name === "compiler-core")?.bytes,
    ).toBeLessThanOrEqual(16_384);
    expect(outcome.instructions).toBe(1_469_245);
    expect(outcome.cycles).toBe(14_811_727);
    expect(outcome.extents).toEqual([
      { name: "compiler-code", bytes: 15_274 },
      { name: "compiler-immutable", bytes: 437 },
      { name: "compiler-core", bytes: 15_711 },
      { name: "compiler-workspace", bytes: 3_887 },
      { name: "generated-z80-bound", bytes: 4_096 },
      { name: "z80-runtime", bytes: 921 },
      { name: "corpus-source-and-descriptors", bytes: 8_878 },
      { name: "proof-code-and-data", bytes: 2_102 },
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
    const chapter18 = specification.slice(specification.indexOf("## 18."));
    const specificationPrograms = Array.from(
      chapter18.matchAll(/```nucleus\n([\s\S]*?)```/g),
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
        "Chapter21_22",
        "Chapter21_22Boolean",
      ].map((name) => source(`${name}Source`, `${name}SourceEnd`)),
    ];
    expect(specificationPrograms).toHaveLength(39);
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
  }, atomProofHostTimeoutMs);

  it("retains the historical direct-Z80 Stage 8 module proof", async () => {
    const outcome = await runProofManifest(
      proof("stage8-failure-z80-slice-proof"),
    );
    expect(outcome.memory[outcome.symbols.ProofStatus ?? -1]).toBe(0xa5);
    expect(outcome.memory[outcome.symbols.ProofCase ?? -1]).toBe(0);
    expect(
      outcome.extents.find(({ name }) => name === "compiler-core")?.bytes,
    ).toBeLessThanOrEqual(16_384);
    expect(outcome.instructions).toBe(1_723_192);
    expect(outcome.cycles).toBe(17_126_791);
    expect(outcome.extents).toEqual([
      { name: "compiler-code", bytes: 15_274 },
      { name: "compiler-immutable", bytes: 437 },
      { name: "compiler-core", bytes: 15_711 },
      { name: "compiler-workspace", bytes: 3_887 },
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
  }, atomProofHostTimeoutMs);

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
    expect(outcome.instructions).toBe(2_872);
    expect(outcome.cycles).toBe(35_927);
    expect(outcome.extents).toEqual([
      { name: "compiler-code", bytes: 810 },
      { name: "compiler-immutable", bytes: 437 },
      { name: "compiler-core", bytes: 1_247 },
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
    expect(outcome.instructions).toBe(8_201);
    expect(outcome.cycles).toBe(85_552);
    expect(outcome.extents).toEqual([
      { name: "compiler-code", bytes: 921 },
      { name: "compiler-immutable", bytes: 38 },
      { name: "compiler-core", bytes: 959 },
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

    expect(outcome.instructions).toBe(4_425);
    expect(outcome.cycles).toBe(46_778);
    expect(outcome.extents).toEqual([
      { name: "common-front-end", bytes: 921 },
      { name: "z80-output-sink", bytes: 25 },
      { name: "compiler-code", bytes: 946 },
      { name: "compiler-immutable", bytes: 75 },
      { name: "compiler-core", bytes: 1_021 },
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
    expect(outcome.instructions).toBe(37_261);
    expect(outcome.cycles).toBe(405_408);
    expect(outcome.extents).toEqual([
      { name: "compiler-code", bytes: 8_592 },
      { name: "compiler-immutable", bytes: 279 },
      { name: "compiler-core", bytes: 8_871 },
      { name: "compiler-workspace", bytes: 1_694 },
      { name: "proof-code-and-data", bytes: 241 },
    ]);
    expect(outcome.memory[outcome.symbols.ProofStatus ?? -1]).toBe(0xa5);
    expect(outcome.memory[outcome.symbols.ProofCase ?? -1]).toBe(0);
    expect(outcome.memory[outcome.symbols.DiagnosticCode ?? -1]).toBe(
      outcome.symbols.DiagnosticExpectedEnd,
    );
  }, atomProofHostTimeoutMs);

  it("executes the counted loop as direct Z80", async () => {
    const outcome = await runProofManifest(proof("loop-z80-slice-proof"));
    const generatedBase = outcome.symbols.GeneratedBase ?? -1;
    const generatedSize = outcome.symbols.ProgramSize ?? -1;
    const generated = outcome.memory.slice(
      generatedBase,
      generatedBase + generatedSize,
    );

    expect(outcome.instructions).toBe(34_483);
    expect(outcome.cycles).toBe(372_040);
    expect(outcome.extents).toEqual([
      { name: "common-front-end", bytes: 8_592 },
      { name: "z80-output-sink", bytes: 1_511 },
      { name: "compiler-code", bytes: 10_103 },
      { name: "compiler-immutable", bytes: 279 },
      { name: "compiler-core", bytes: 10_382 },
      { name: "compiler-workspace", bytes: 1_694 },
      { name: "generated-z80", bytes: 54 },
      { name: "z80-runtime", bytes: 796 },
      { name: "z80-state", bytes: 21 },
      { name: "service-state", bytes: 28 },
      { name: "proof-code-and-data", bytes: 298 },
    ]);
    expect(Array.from(generated.slice(0, 7))).toEqual([
      0x16, 0x00, 0x16, 0x00, 0x7a, 0xfe, 0x03,
    ]);
  }, atomProofHostTimeoutMs);

  it("executes checked initialized-array selection as direct Z80", async () => {
    const outcome = await runProofManifest(proof("array-z80-slice-proof"));
    expect(outcome.instructions).toBe(51_057);
    expect(outcome.cycles).toBe(539_696);
    expect(outcome.extents).toEqual([
      { name: "common-front-end", bytes: 8_592 },
      { name: "source-adapter", bytes: 86 },
      { name: "tokenizer", bytes: 648 },
      { name: "semantic-sink", bytes: 88 },
      { name: "parser", bytes: 7_651 },
      { name: "z80-output-sink", bytes: 1_511 },
      { name: "compiler-code", bytes: 10_103 },
      { name: "compiler-immutable", bytes: 279 },
      { name: "compiler-core", bytes: 10_382 },
      { name: "compiler-workspace", bytes: 1_694 },
      { name: "generated-z80", bytes: 74 },
      { name: "z80-runtime", bytes: 796 },
      { name: "z80-state", bytes: 21 },
      { name: "service-state", bytes: 28 },
      { name: "proof-code-and-data", bytes: 661 },
    ]);

    expect(outcome.memory[outcome.symbols.ProofStatus ?? -1]).toBe(0xa5);
    expect(outcome.memory[outcome.symbols.ProofCase ?? -1]).toBe(0);
  }, atomProofHostTimeoutMs);

  it("executes a forward-declared recursive scalar value call", async () => {
    const outcome = await runProofManifest(proof("call-z80-slice-proof"));
    expect(outcome.instructions).toBe(57_229);
    expect(outcome.cycles).toBe(608_573);
    expect(outcome.extents).toEqual([
      { name: "common-front-end", bytes: 8_592 },
      { name: "source-adapter", bytes: 86 },
      { name: "tokenizer", bytes: 648 },
      { name: "semantic-sink", bytes: 88 },
      { name: "parser", bytes: 7_651 },
      { name: "call-parser-path", bytes: 336 },
      { name: "z80-output-sink", bytes: 1_511 },
      { name: "z80-call-backend", bytes: 337 },
      { name: "compiler-code", bytes: 10_103 },
      { name: "compiler-immutable", bytes: 279 },
      { name: "compiler-core", bytes: 10_382 },
      { name: "compiler-workspace", bytes: 1_694 },
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
  }, atomProofHostTimeoutMs);

  it("executes general scalar symbols and precedence as direct Z80", async () => {
    const outcome = await runProofManifest(proof("expression-z80-slice-proof"));
    const generatedSizeAddress = outcome.symbols.GeneratedSize ?? -1;
    const generatedSize =
      (outcome.memory[generatedSizeAddress] ?? 0) |
      ((outcome.memory[generatedSizeAddress + 1] ?? 0) << 8);

    expect(outcome.instructions).toBe(108_714);
    expect(outcome.cycles).toBe(1_154_485);
    expect(outcome.extents).toEqual([
      { name: "common-front-end", bytes: 8_592 },
      { name: "source-adapter", bytes: 86 },
      { name: "tokenizer", bytes: 648 },
      { name: "semantic-sink", bytes: 88 },
      { name: "symbol-table", bytes: 119 },
      { name: "parser", bytes: 7_651 },
      { name: "z80-output-sink", bytes: 3_403 },
      { name: "z80-expression-backend", bytes: 351 },
      { name: "compiler-code", bytes: 11_995 },
      { name: "compiler-immutable", bytes: 279 },
      { name: "compiler-core", bytes: 12_274 },
      { name: "compiler-workspace", bytes: 1_694 },
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
  }, atomProofHostTimeoutMs);

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
    expect(outcome.instructions).toBe(625_888);
    expect(outcome.cycles).toBe(6_460_971);
    expect(outcome.extents).toEqual([
      { name: "common-front-end", bytes: 8_592 },
      { name: "source-adapter", bytes: 86 },
      { name: "tokenizer", bytes: 648 },
      { name: "semantic-sink", bytes: 88 },
      { name: "symbol-table", bytes: 119 },
      { name: "parser", bytes: 7_651 },
      { name: "typed-z80-sink", bytes: 1_892 },
      { name: "compiler-code", bytes: 10_895 },
      { name: "compiler-immutable", bytes: 279 },
      { name: "compiler-core", bytes: 11_174 },
      { name: "compiler-workspace", bytes: 1_694 },
      { name: "generated-z80-bound", bytes: 857 },
      { name: "z80-runtime", bytes: 796 },
      { name: "proof-code-and-data", bytes: 1_930 },
    ]);
    expect(generatedSize).toBe(857);
  }, atomProofHostTimeoutMs);

  it("executes typed structured control as direct Z80", async () => {
    const outcome = await runProofManifest(
      proof("structured-control-z80-slice-proof"),
    );
    expect(outcome.symbols.StructuredLabelCapacitySource).toBe(0x9800);
    expect(outcome.symbols.ProofEnd).toBeLessThanOrEqual(0x9800);
    expect(outcome.symbols.StructuredLabelCapacitySourceEnd).toBeLessThanOrEqual(
      outcome.symbols.BackupBase ?? -1,
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
    expect(outcome.instructions).toBe(252_025);
    expect(outcome.cycles).toBe(2_680_233);
    expect(outcome.extents).toEqual([
      { name: "common-front-end", bytes: 8_592 },
      { name: "parser", bytes: 7_651 },
      { name: "structured-z80-sink", bytes: 1_892 },
      { name: "compiler-code", bytes: 10_895 },
      { name: "compiler-immutable", bytes: 279 },
      { name: "compiler-core", bytes: 11_174 },
      { name: "compiler-workspace", bytes: 1_694 },
      { name: "generated-z80-bound", bytes: 715 },
      { name: "z80-runtime", bytes: 796 },
      { name: "proof-code-and-data", bytes: 902 },
    ]);
  }, atomProofHostTimeoutMs);

  it("emits packed aggregate layouts and publishes one atomic static image", async () => {
    const outcome = await runProofManifest(proof("aggregate-z80-slice-proof"));
    expect(outcome.memory[outcome.symbols.ProofStatus ?? -1]).toBe(0xa5);
    expect(outcome.memory[outcome.symbols.ProofCase ?? -1]).toBe(0);
    expect(outcome.instructions).toBe(298_555);
    expect(outcome.cycles).toBe(3_033_464);
    expect(
      outcome.extents.find(({ name }) => name === "compiler-core")?.bytes,
    ).toBeLessThanOrEqual(16_384);
    expect(outcome.extents).toEqual([
      { name: "common-front-end", bytes: 7_273 },
      { name: "parser", bytes: 6_335 },
      { name: "typed-z80-sink", bytes: 1_938 },
      { name: "compiler-code", bytes: 9_622 },
      { name: "compiler-immutable", bytes: 263 },
      { name: "compiler-core", bytes: 9_885 },
      { name: "compiler-workspace", bytes: 1_694 },
      { name: "static-image", bytes: 255 },
      { name: "z80-runtime", bytes: 796 },
      { name: "proof-code-and-data", bytes: 1_343 },
    ]);
  }, atomProofHostTimeoutMs);

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
  }, atomProofHostTimeoutMs);
});
