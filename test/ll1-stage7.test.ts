import { readFileSync } from "node:fs";
import path from "node:path";

import { describe, expect, it } from "vitest";

import {
  analyzeStage7Grammar,
  generateStage7ProofActions,
  generateStage7Tables,
  readStage7Grammar,
  stage7ActionLayout,
  validateStage7PhysicalHandlers,
} from "../grammar/generate-stage7.js";
import { runProofManifest } from "../src/proof.js";

const proof = (name: string): string =>
  path.resolve(import.meta.dirname, "..", "proofs", `${name}.json`);

describe("Stage 7 packed LL(1)", () => {
  it("keeps every published keyword in one bounded length group", () => {
    const source = readFileSync(
      path.resolve(
        import.meta.dirname,
        "..",
        "asm",
        "vertical-slice",
        "loop-keywords.asmi",
      ),
      "utf8",
    );
    const table = source.match(
      /KeywordTable:\s*\n([\s\S]*?)KeywordCount\s+\.equ\s+(\d+)/,
    );
    expect(table).not.toBeNull();
    const entries = [
      ...(table?.[1]?.matchAll(
        /^\s*\.db\s+"([a-z0-9]+)",(Token[A-Za-z0-9]+)(\+\$80)?\s*$/gm,
      ) ?? []),
    ].map((entry) => [entry[1], entry[2], entry[3] !== undefined] as const);
    expect(entries).toHaveLength(Number(table?.[2]));
    expect(entries).toEqual([
      ["as", "TokenAs", false],
      ["u8", "TokenU8", false],
      ["i8", "TokenI8", false],
      ["or", "TokenOr", false],
      ["if", "TokenIf", false],
      ["to", "TokenTo", true],
      ["var", "TokenVar", false],
      ["u16", "TokenU16", false],
      ["i16", "TokenI16", false],
      ["xor", "TokenXor", false],
      ["mod", "TokenMod", false],
      ["and", "TokenAnd", false],
      ["not", "TokenNot", false],
      ["end", "TokenEnd", false],
      ["sub", "TokenSub", false],
      ["for", "TokenFor", true],
      ["true", "TokenTrue", false],
      ["fail", "TokenFail", false],
      ["else", "TokenElse", false],
      ["step", "TokenStep", false],
      ["exit", "TokenExit", true],
      ["false", "TokenFalse", false],
      ["const", "TokenConst", false],
      ["fails", "TokenFails", false],
      ["until", "TokenUntil", false],
      ["while", "TokenWhile", true],
      ["assert", "TokenAssert", false],
      ["return", "TokenReturn", false],
      ["elseif", "TokenElseIf", false],
      ["record", "TokenRecord", false],
      ["string", "TokenString", false],
      ["handle", "TokenHandle", true],
      ["boolean", "TokenBoolean", false],
      ["forward", "TokenForward", true],
      ["continue", "TokenContinue", true],
    ]);

    const offsets = source.match(
      /KeywordLengthOffsets:\s*\n([\s\S]*?)\n\s*PunctuationTable:/,
    );
    expect(offsets).not.toBeNull();
    expect(
      [...(offsets?.[1]?.matchAll(
        /^\s*\.db\s+KeywordLength(\d)-KeywordTable\s*$/gm,
      ) ?? [])].map((entry) => Number(entry[1])),
    ).toEqual([2, 3, 4, 5, 6, 7, 8]);
  });

  it("keeps generated grammar artifacts reproducible and conflict-free", () => {
    const analysis = analyzeStage7Grammar();
    const grammar = readStage7Grammar();
    expect(analysis.conflicts).toEqual([]);
    expect(analysis.first["compilation-unit"]).toEqual([
      "TokenAssert",
      "TokenConst",
      "TokenEof",
      "TokenForward",
      "TokenRecord",
      "TokenSub",
      "TokenVar",
    ]);
    expect(generateStage7Tables()).toBe(
      readFileSync(
        path.resolve(
          import.meta.dirname,
          "..",
          "grammar",
          "stage7-tables.asmi",
        ),
        "utf8",
      ),
    );
    expect(grammar.productions).toHaveLength(83);
    expect(generateStage7Tables()).toContain(
      "HybridLL1ProductionCount  .equ 73",
    );
    expect(generateStage7ProofActions()).toBe(
      readFileSync(
        path.resolve(
          import.meta.dirname,
          "..",
          "grammar",
          "stage7-proof-actions.asmi",
        ),
        "utf8",
      ),
    );
  });

  it("maps every logical action to one physical handler and parameter", () => {
    const grammar = readStage7Grammar();
    const logicalActions = [
      ...new Set(
        grammar.productions.flatMap(({ rhs }) =>
          rhs.filter(
            (symbol) => symbol.startsWith("a:") || symbol.startsWith("x:"),
          ),
        ),
      ),
    ];
    const layout = stage7ActionLayout();
    expect(layout.map(({ logical }) => logical)).toEqual(logicalActions);
    expect(new Set(layout.map(({ logical }) => logical)).size).toBe(
      logicalActions.length,
    );
    expect(layout.filter(({ parameter }) => parameter !== undefined)).toEqual([
      { logical: "a:EmitExit", handler: "EmitTransferAction", parameter: 45 },
      {
        logical: "a:EmitContinue",
        handler: "EmitTransferAction",
        parameter: 46,
      },
      { logical: "a:ForTo", handler: "SelectForBoundAction", parameter: 1 },
      {
        logical: "a:ForUntil",
        handler: "SelectForBoundAction",
        parameter: 0,
      },
      { logical: "a:TypeU8", handler: "SetScalarTypeAction", parameter: 1 },
      {
        logical: "a:TypeU16",
        handler: "SetScalarTypeAction",
        parameter: 2,
      },
      {
        logical: "a:TypeBoolean",
        handler: "SetScalarTypeAction",
        parameter: 3,
      },
      { logical: "a:TypeI8", handler: "SetScalarTypeAction", parameter: 4 },
      {
        logical: "a:TypeI16",
        handler: "SetScalarTypeAction",
        parameter: 5,
      },
    ]);
  });

  it("rejects invalid parameterised-action metadata", () => {
    const grammar = readStage7Grammar();
    expect(() =>
      stage7ActionLayout(grammar, [
        {
          handler: "MissingLogical",
          parameterStep: 1,
          members: [{ logical: "a:NotAnAction", parameter: 0 }],
        },
      ]),
    ).toThrow("unknown logical action a:NotAnAction");
    expect(() =>
      stage7ActionLayout(grammar, [
        {
          handler: "First",
          parameterStep: 1,
          members: [{ logical: "a:TypeU8", parameter: 1 }],
        },
        {
          handler: "Second",
          parameterStep: 1,
          members: [{ logical: "a:TypeU8", parameter: 2 }],
        },
      ]),
    ).toThrow("duplicate action-family member a:TypeU8");
    expect(() =>
      stage7ActionLayout(grammar, [
        {
          handler: "",
          parameterStep: 1,
          members: [{ logical: "a:TypeU8", parameter: 1 }],
        },
      ]),
    ).toThrow("missing physical action handler");
    expect(() =>
      stage7ActionLayout(grammar, [
        {
          handler: "OutOfRange",
          parameterStep: 1,
          members: [{ logical: "a:TypeU8", parameter: 256 }],
        },
      ]),
    ).toThrow("action parameter out of range for a:TypeU8");
    expect(() =>
      validateStage7PhysicalHandlers("", [
        {
          handler: "Absent",
          parameterStep: 1,
          members: [{ logical: "a:TypeU8", parameter: 1 }],
        },
      ]),
    ).toThrow("missing physical action handler HybridLL1Absent");

    const exitProduction = grammar.productions.findIndex(({ rhs }) =>
      rhs.includes("a:EmitExit"),
    );
    const productions = grammar.productions.map((production, index) =>
      index === exitProduction
        ? { ...production, rhs: [...production.rhs, "a:Inserted"] }
        : production,
    );
    expect(() => stage7ActionLayout({ ...grammar, productions })).toThrow(
      "noncontiguous action family EmitTransferAction",
    );
    const shiftedProductions = grammar.productions.map((production, index) =>
      index === 0
        ? { ...production, rhs: [...production.rhs, "a:Inserted"] }
        : production,
    );
    expect(() =>
      stage7ActionLayout({ ...grammar, productions: shiftedProductions }),
    ).toThrow("action ordinal offset mismatch for EmitTransferAction");
    expect(() =>
      stage7ActionLayout(grammar, [
        {
          handler: "BadParameters",
          parameterStep: 1,
          members: [
            { logical: "a:TypeU8", parameter: 1 },
            { logical: "a:TypeU16", parameter: 3 },
          ],
        },
      ]),
    ).toThrow("nonlinear action parameters for BadParameters");
  });

  it("executes the packed engine at its exact stack boundary", async () => {
    const outcome = await runProofManifest(proof("stage7-ll1-engine-proof"));
    expect(outcome.memory[outcome.symbols.ProofStatus ?? -1]).toBe(0xa5);
    expect(outcome.extents).toContainEqual({
      name: "ll1-engine",
      bytes: 227,
    });
    expect(outcome.extents).toContainEqual({
      name: "ll1-workspace",
      bytes: 65,
    });
  });

  it("runs the Stage 7 parser through the complete packed grammar", async () => {
    const outcome = await runProofManifest(
      proof("stage7-ll1-aggregate-call-z80-slice-proof"),
    );
    const extents = new Map(
      outcome.extents.map(({ name, bytes }) => [name, bytes]),
    );
    expect(outcome.memory[outcome.symbols.ProofStatus ?? -1]).toBe(0xa5);
    expect(outcome.instructions).toBe(1_919_241);
    expect(outcome.cycles).toBe(18_399_643);
    expect(outcome.extents).toContainEqual({ name: "parser", bytes: 9_556 });
    expect(outcome.extents).toContainEqual({
      name: "ll1-engine",
      bytes: 227,
    });
    expect(outcome.extents).toContainEqual({
      name: "ll1-tables",
      bytes: 831,
    });
    expect(outcome.extents).toContainEqual({
      name: "ll1-actions",
      bytes: 2_406,
    });
    expect(outcome.extents).toContainEqual({
      name: "compiler-core",
      bytes: 15_221,
    });
    expect(outcome.extents).toContainEqual({
      name: "compiler-code",
      bytes: 14_823,
    });
    expect(outcome.extents).toContainEqual({
      name: "compiler-immutable",
      bytes: 398,
    });
    expect(outcome.extents).toContainEqual({
      name: "compiler-workspace",
      bytes: 3_623,
    });
    expect(outcome.extents).toContainEqual({
      name: "z80-runtime",
      bytes: 921,
    });
    expect(
      (extents.get("parser") ?? -1) -
        (extents.get("ll1-engine") ?? -1) -
        (extents.get("ll1-tables") ?? -1) -
        (extents.get("ll1-actions") ?? -1),
    ).toBe(6_092);
  }, 30_000);

  it("executes every retained Stage 7 action family", async () => {
    const outcome = await runProofManifest(
      proof("stage7-ll1-parser-coverage-proof"),
    );
    expect(outcome.memory[outcome.symbols.ProofStatus ?? -1]).toBe(0xa5);
    expect(outcome.memory[outcome.symbols.ProofCase ?? -1]).toBe(0);
  }, 30_000);
});
