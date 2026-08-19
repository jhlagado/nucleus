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
  it("keeps the statement-dispatch nonterminals in the compact handle group", () => {
    const generated = readFileSync(
      path.resolve(import.meta.dirname, "..", "grammar", "stage7-tables.asmi"),
      "utf8",
    );
    expect(generated).toMatch(
      /HybridLL1Row20: ; routine-body[\s\S]*HybridLL1Row21: ; local-list[\s\S]*HybridLL1Row24: ; statement-sequence[\s\S]*HybridLL1Row25: ; statement/,
    );
  });

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
      ["case", "TokenCase", false],
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
      ["select", "TokenSelect", false],
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
    const relativeGroups = [
      ...(offsets?.[1]?.matchAll(
        /^\s*\.db\s+KeywordLength(\d)-\(KeywordLengthOffsets\+(\d)\)\s*$/gm,
      ) ?? []),
    ].map((entry) => [Number(entry[1]), Number(entry[2])] as const);
    expect(relativeGroups).toEqual([
      [2, 0],
      [3, 1],
      [4, 2],
      [5, 3],
      [6, 4],
      [7, 5],
      [8, 6],
    ]);

    let byteOffset = 7;
    const groupOffsets = new Map<number, number>();
    for (const [spelling] of entries) {
      if (!groupOffsets.has(spelling.length)) {
        groupOffsets.set(spelling.length, byteOffset);
      }
      byteOffset += spelling.length + 1;
    }
    expect(
      relativeGroups.map(
        ([length, cell]) => (groupOffsets.get(length) ?? 0) - cell,
      ),
    ).toEqual([7, 24, 63, 92, 121, 169, 184]);

    const basedSuffixes = [
      ...source.matchAll(
        /^\s*\.db\s+"\$",5\s*\n\s*\.db\s+"%",17\s*\nPunctuationCount\s+\.equ\s+(\d+)$/gm,
      ),
    ].map((match) => Number(match[1]));
    expect(basedSuffixes).toEqual([8, 7]);
  });

  it("keeps arithmetic token ordinals aligned with their selectors", () => {
    const source = readFileSync(
      path.resolve(
        import.meta.dirname,
        "..",
        "asm",
        "vertical-slice",
        "loop-compiler-state.asmi",
      ),
      "utf8",
    );
    const tokenValue = (name: string): number => {
      const match = source.match(
        new RegExp(`^${name}\\s+\\.equ\\s+(\\d+)$`, "m"),
      );
      expect(match).not.toBeNull();
      return Number(match?.[1]);
    };

    expect(tokenValue("TokenGreater") - tokenValue("TokenLess")).toBe(
      ">".charCodeAt(0) - "<".charCodeAt(0),
    );
    expect(tokenValue("TokenPlus") - tokenValue("TokenMinus")).toBe(1);
    expect(tokenValue("TokenStar") - tokenValue("TokenMinus")).toBe(2);
    expect(tokenValue("TokenMod") - tokenValue("TokenXor")).toBe(1);
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
    expect(grammar.productions).toHaveLength(93);
    expect(generateStage7Tables()).toContain(
      "HybridLL1ProductionCount  .equ 82",
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
      bytes: 273,
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
    expect(outcome.symbols.SourceDelimiterDepth).toBe(
      (outcome.symbols.SourceLineHasToken ?? -2) + 1,
    );
    expect(outcome.instructions).toBe(1_942_692);
    expect(outcome.cycles).toBe(18_546_159);
    expect(outcome.extents).toContainEqual({ name: "parser", bytes: 10_063 });
    expect(outcome.extents).toContainEqual({
      name: "ll1-engine",
      bytes: 273,
    });
    expect(outcome.extents).toContainEqual({
      name: "ll1-tables",
      bytes: 933,
    });
    expect(outcome.extents).toContainEqual({
      name: "ll1-actions",
      bytes: 2_529,
    });
    expect(outcome.extents).toContainEqual({
      name: "compiler-core",
      bytes: 15_635,
    });
    expect(outcome.extents).toContainEqual({
      name: "compiler-code",
      bytes: 15_198,
    });
    expect(outcome.extents).toContainEqual({
      name: "compiler-immutable",
      bytes: 437,
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
    ).toBe(6_328);
  }, 30_000);

  it("executes every retained Stage 7 action family", async () => {
    const outcome = await runProofManifest(
      proof("stage7-ll1-parser-coverage-proof"),
    );
    expect(outcome.memory[outcome.symbols.ProofStatus ?? -1]).toBe(0xa5);
    expect(outcome.memory[outcome.symbols.ProofCase ?? -1]).toBe(0);
  }, 30_000);
});
