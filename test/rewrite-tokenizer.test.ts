import { mkdtemp, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";

import { compile } from "@jhlagado/azm/compile";
import { createZ80Runtime, parseIntelHex } from "@jhlagado/debug80-runtime";
import { describe, expect, it } from "vitest";

import {
  nucleusCompilerImages,
  type NucleusCompilerImagePair,
  type NucleusCompilerImageSelection,
} from "../src/compiler-image-internal.js";
import {
  compileNucleus,
  type NucleusCompileOptions,
  type NucleusSourcePart,
} from "../src/compiler.js";
import { sourcePositionAtOffset } from "../src/source-position-internal.js";

const rewriteDirectory = path.resolve(import.meta.dirname, "../asm/rewrite");

interface AssembledImage {
  readonly hex: string;
  readonly symbols: Readonly<Record<string, number>>;
}

const assemble = async (source: string): Promise<AssembledImage> => {
  const result = await compile(source, {
    emitHex: true,
    emitD8m: true,
    registerContracts: "strict",
  });
  const errors = result.diagnostics.filter(
    ({ severity }) => severity === "error",
  );
  expect(errors, source).toEqual([]);
  const hex = result.artifacts.find((artifact) => artifact.kind === "hex");
  const d8m = result.artifacts.find((artifact) => artifact.kind === "d8m");
  if (hex?.kind !== "hex" || d8m?.kind !== "d8m") {
    throw new Error(`AZM omitted rewrite artifacts for ${source}`);
  }
  return {
    hex: hex.text,
    symbols: Object.fromEntries(
      d8m.json.symbols.flatMap((entry) => {
        const value = entry.address ?? entry.value;
        return value === undefined ? [] : [[entry.name, value]];
      }),
    ),
  };
};

const wordAt = (memory: Uint8Array, address: number): number =>
  (memory[address] ?? 0) | ((memory[address + 1] ?? 0) << 8);

const writeWord = (
  memory: Uint8Array,
  address: number,
  value: number,
): void => {
  memory[address] = value & 0xff;
  memory[address + 1] = value >>> 8;
};

interface ExpectedToken {
  readonly kind: string;
  readonly part: number;
  readonly offset: number;
  readonly line: number;
  readonly column: number;
  readonly value?: number;
  readonly length?: number;
}

const keywords = [
  "var",
  "as",
  "u8",
  "u16",
  "i8",
  "i16",
  "boolean",
  "true",
  "false",
  "const",
  "or",
  "xor",
  "mod",
  "assert",
  "and",
  "not",
  "fail",
  "end",
  "sub",
  "fails",
  "for",
  "until",
  "forward",
  "return",
  "if",
  "elseif",
  "else",
  "while",
  "to",
  "step",
  "exit",
  "continue",
  "record",
  "string",
  "handle",
] as const;

const keywordKinds = [
  "TokenVar",
  "TokenAs",
  "TokenU8",
  "TokenU16",
  "TokenI8",
  "TokenI16",
  "TokenBoolean",
  "TokenTrue",
  "TokenFalse",
  "TokenConst",
  "TokenOr",
  "TokenXor",
  "TokenMod",
  "TokenAssert",
  "TokenAnd",
  "TokenNot",
  "TokenFail",
  "TokenEnd",
  "TokenSub",
  "TokenFails",
  "TokenFor",
  "TokenUntil",
  "TokenForward",
  "TokenReturn",
  "TokenIf",
  "TokenElseIf",
  "TokenElse",
  "TokenWhile",
  "TokenTo",
  "TokenStep",
  "TokenExit",
  "TokenContinue",
  "TokenRecord",
  "TokenString",
  "TokenHandle",
] as const;

const expectedTokens = (): readonly ExpectedToken[] => {
  const result: ExpectedToken[] = [];
  let offset = 0;
  for (let index = 0; index < keywords.length; index += 1) {
    const keyword = keywords[index] ?? "";
    result.push({
      kind: keywordKinds[index] ?? "",
      part: 1,
      offset,
      line: 1,
      column: offset + 1,
      length: keyword.length,
    });
    offset += keyword.length + 1;
  }
  for (const name of ["variable", "i", "Print"] as const) {
    result.push({
      kind: "TokenName",
      part: 1,
      offset,
      line: 1,
      column: offset + 1,
      length: name.length,
    });
    offset += name.length + 1;
  }
  result.push({
    kind: "TokenNewline",
    part: 1,
    offset: offset - 1,
    line: 1,
    column: offset,
  });

  const part2 =
    String.raw`name_1 = 65535'A', $fF, %1010 + - * / . < <= <> > >= 'A' '\0' '\n' '\r' '\t' '\'' '\"' '\\' '\x41' "a\n\x42\"" // ignored` +
    "\r\n";
  const part2Tokens = [
    ["TokenName", "name_1", 0, 6],
    ["TokenEquals", "=", 0, 0],
    ["TokenNumber", "65535", 65_535, 0],
    ["TokenCharacter", "'A'", 65, 0],
    ["TokenComma", ",", 0, 0],
    ["TokenNumber", "$fF", 255, 0],
    ["TokenComma", ",", 0, 0],
    ["TokenNumber", "%1010", 10, 0],
    ["TokenPlus", "+", 0, 0],
    ["TokenMinus", "-", 0, 0],
    ["TokenStar", "*", 0, 0],
    ["TokenSlash", "/", 0, 0],
    ["TokenDot", ".", 0, 0],
    ["TokenLess", "<", 0, 0],
    ["TokenLessEqual", "<=", 0, 0],
    ["TokenNotEqual", "<>", 0, 0],
    ["TokenGreater", ">", 0, 0],
    ["TokenGreaterEqual", ">=", 0, 0],
    ["TokenCharacter", "'A'", 65, 0],
    ["TokenCharacter", String.raw`'\0'`, 0, 0],
    ["TokenCharacter", String.raw`'\n'`, 10, 0],
    ["TokenCharacter", String.raw`'\r'`, 13, 0],
    ["TokenCharacter", String.raw`'\t'`, 9, 0],
    ["TokenCharacter", String.raw`'\''`, 0x27, 0],
    ["TokenCharacter", String.raw`'\"'`, 0x22, 0],
    ["TokenCharacter", String.raw`'\\'`, 0x5c, 0],
    ["TokenCharacter", String.raw`'\x41'`, 65, 0],
    ["TokenStringLiteral", String.raw`"a\n\x42\""`, 4, 4],
  ] as const;
  let searchFrom = 0;
  for (const [kind, lexeme, value, length] of part2Tokens) {
    const tokenOffset = part2.indexOf(lexeme, searchFrom);
    if (tokenOffset < 0) throw new Error(`missing proof lexeme ${lexeme}`);
    result.push({
      kind,
      part: 2,
      offset: tokenOffset,
      line: 1,
      column: tokenOffset + 1,
      value,
      length,
    });
    searchFrom = tokenOffset + lexeme.length;
  }
  result.push({
    kind: "TokenNewline",
    part: 2,
    offset: part2.length - 2,
    line: 1,
    column: part2.length - 1,
  });

  result.push(
    { kind: "TokenLeftParen", part: 3, offset: 0, line: 1, column: 1 },
    { kind: "TokenNumber", part: 3, offset: 2, line: 2, column: 1, value: 1 },
    { kind: "TokenPlus", part: 3, offset: 4, line: 2, column: 3 },
    { kind: "TokenNumber", part: 3, offset: 6, line: 3, column: 1, value: 2 },
    { kind: "TokenRightParen", part: 3, offset: 8, line: 4, column: 1 },
    { kind: "TokenNewline", part: 3, offset: 9, line: 4, column: 2 },
    { kind: "TokenName", part: 3, offset: 20, line: 7, column: 2, length: 4 },
    { kind: "TokenNewline", part: 3, offset: 24, line: 7, column: 6 },
    { kind: "TokenEof", part: 3, offset: 24, line: 7, column: 6 },
  );
  return result;
};

describe("ground-up rewrite tokenizer", () => {
  it("publishes every token, payload, part, and byte position", async () => {
    const image = await assemble(
      path.join(rewriteDirectory, "r1-tokenizer-proof.asm"),
    );
    const program = parseIntelHex(image.hex);
    const entry = image.symbols.ProofStart;
    if (entry === undefined) throw new Error("missing ProofStart");
    const runtime = createZ80Runtime(
      { ...program, memory: program.memory.slice() },
      entry,
    );
    let instructions = 0;
    let cycles = 0;
    while (!runtime.isHalted() && instructions < 200_000) {
      const step = runtime.step();
      instructions += 1;
      cycles += step.cycles ?? 0;
    }
    expect(runtime.isHalted()).toBe(true);
    const memory = runtime.hardware.memory;
    expect(memory[image.symbols.ProofStatus ?? -1]).toBe(0xa5);
    expect(memory[image.symbols.DiagnosticCode ?? -1]).toBe(0);
    const count = memory[image.symbols.ProofTokenCount ?? -1] ?? 0;
    const expected = expectedTokens();
    expect(count).toBe(expected.length);
    const sourceParts = [
      `${keywords.join(" ")} variable i Print`,
      String.raw`name_1 = 65535'A', $fF, %1010 + - * / . < <= <> > >= 'A' '\0' '\n' '\r' '\t' '\'' '\"' '\\' '\x41' "a\n\x42\"" // ignored` +
        "\r\n",
      "(\n1 +\n2\n)\n\n// only\n\tlast",
    ].map((source) => new TextEncoder().encode(source));
    const base = image.symbols.ProofTokenBuffer ?? -1;
    const width = image.symbols.RewriteTokenRecordSize ?? -1;
    for (let index = 0; index < expected.length; index += 1) {
      const wanted = expected[index];
      if (wanted === undefined) continue;
      const address = base + index * width;
      const partBase = image.symbols[`ProofPart${wanted.part}`] ?? -1;
      const actualOffset = wordAt(memory, address + 4);
      expect(
        {
          kind: memory[address],
          part: memory[address + 3],
          offset: actualOffset,
          lexeme: wordAt(memory, address + 6),
        },
        `token ${index} ${wanted.kind}`,
      ).toEqual({
        kind: image.symbols[wanted.kind],
        part: wanted.part,
        offset: wanted.offset,
        lexeme: partBase + wanted.offset,
      });
      const bytes = sourceParts[wanted.part - 1] ?? new Uint8Array();
      expect(
        sourcePositionAtOffset(
          {
            id: wanted.part,
            name: `part-${wanted.part}.nu`,
            start: partBase,
            end: partBase + bytes.length,
            bytes,
          },
          actualOffset,
        ),
        `token ${index} source position`,
      ).toEqual({ line: wanted.line, column: wanted.column });
      if (wanted.value !== undefined) {
        expect(wordAt(memory, address + 1), `token ${index} payload`).toBe(
          wanted.value,
        );
      }
      if (
        wanted.kind === "TokenName" ||
        wanted.kind === "TokenStringLiteral" ||
        (wanted.kind.startsWith("Token") &&
          keywordKinds.includes(wanted.kind as (typeof keywordKinds)[number]))
      ) {
        expect(memory[address + 8], `token ${index} length`).toBe(
          wanted.length ?? 0,
        );
      }
    }
    expect(instructions).toBe(47_268);
    expect(cycles).toBe(452_675);
  }, 15_000);

  it("matches baseline lexical diagnostics through the Host API seam", async () => {
    const image = await assemble(
      path.join(rewriteDirectory, "r1-host-image.asm"),
    );
    const pair: NucleusCompilerImagePair = {
      normal: image,
      debug: image,
    };
    const selected: NucleusCompileOptions & NucleusCompilerImageSelection = {
      [nucleusCompilerImages]: pair,
    };
    const cases: readonly {
      readonly name: string;
      readonly sources: readonly NucleusSourcePart[];
    }[] = [
      { name: "unknown byte", sources: [{ name: "bad.nu", source: "@\n" }] },
      {
        name: "decimal-name fusion",
        sources: [{ name: "bad.nu", source: "0x2a\n" }],
      },
      {
        name: "decimal overflow",
        sources: [{ name: "bad.nu", source: "65536\n" }],
      },
      {
        name: "malformed character",
        sources: [{ name: "bad.nu", source: "'\\'\n" }],
      },
      {
        name: "malformed string escape",
        sources: [{ name: "bad.nu", source: '"\\q"\n' }],
      },
      {
        name: "unmatched delimiter",
        sources: [{ name: "bad.nu", source: ")\n" }],
      },
      {
        name: "lone carriage return",
        sources: [{ name: "bad.nu", source: "\r" }],
      },
      {
        name: "name capacity",
        sources: [{ name: "bad.nu", source: `${"a".repeat(256)}\n` }],
      },
      {
        name: "literal capacity",
        sources: [{ name: "bad.nu", source: `"${"a".repeat(256)}"\n` }],
      },
      {
        name: "empty hexadecimal",
        sources: [{ name: "bad.nu", source: "$\n" }],
      },
      { name: "invalid binary", sources: [{ name: "bad.nu", source: "%2\n" }] },
      {
        name: "embedded invalid binary digit",
        sources: [{ name: "bad.nu", source: "%12\n" }],
      },
      {
        name: "hexadecimal digit capacity",
        sources: [{ name: "bad.nu", source: "$00000\n" }],
      },
      {
        name: "binary digit capacity",
        sources: [{ name: "bad.nu", source: `%${"0".repeat(17)}\n` }],
      },
      {
        name: "based-name fusion",
        sources: [{ name: "bad.nu", source: "$1g\n" }],
      },
      {
        name: "CRLF position",
        sources: [{ name: "bad.nu", source: "\r\n@\n" }],
      },
    ];
    for (const { name, sources } of cases) {
      const baseline = await compileNucleus(sources);
      const replacement = await compileNucleus(sources, {}, selected);
      expect(baseline.success, name).toBe(false);
      expect(replacement.success, name).toBe(false);
      if (baseline.success || replacement.success) continue;
      expect(replacement.diagnostic, name).toEqual(baseline.diagnostic);
    }

    const incomplete = await compileNucleus(
      [{ name: "valid.nu", source: "sub main()\nend\n" }],
      {},
      selected,
    );
    expect(incomplete).toMatchObject({
      success: false,
      diagnostic: {
        code: 67,
        sourcePart: 1,
        sourceName: "valid.nu",
        offset: 15,
        line: 3,
        column: 1,
      },
    });
  }, 30_000);

  it("distinguishes exact lexical capacity and delimiter boundaries", async () => {
    const image = await assemble(
      path.join(rewriteDirectory, "r1-host-image.asm"),
    );
    const pair: NucleusCompilerImagePair = { normal: image, debug: image };
    const selected: NucleusCompileOptions & NucleusCompilerImageSelection = {
      [nucleusCompilerImages]: pair,
    };
    const escapedCharacters =
      String.raw`'\0' '\n' '\r' '\t' '\'' '\"' '\\' '\x41'` + "\n";
    const accepted = [
      { name: "255-byte name", source: `${"a".repeat(255)}\n`, offset: 256 },
      {
        name: "255-byte string",
        source: `"${"a".repeat(255)}"\n`,
        offset: 258,
      },
      { name: "four-digit hexadecimal", source: "$FFFF\n", offset: 6 },
      {
        name: "sixteen-digit binary",
        source: `%${"1".repeat(16)}\n`,
        offset: 18,
      },
      {
        name: "delimiter depth 255",
        source: `${"(".repeat(255)}${")".repeat(255)}\n`,
        offset: 511,
      },
      {
        name: "all character escapes including zero",
        source: escapedCharacters,
        offset: escapedCharacters.length,
      },
      {
        name: "horizontal tab inside a comment",
        source: "//\t\n",
        offset: 4,
      },
    ] as const;
    for (const testCase of accepted) {
      const result = await compileNucleus(
        [{ name: "accepted.nu", source: testCase.source }],
        {},
        selected,
      );
      expect(result, testCase.name).toMatchObject({
        success: false,
        diagnostic: {
          code: 67,
          sourcePart: 1,
          offset: testCase.offset,
          line: 2,
          column: 1,
        },
      });
    }

    const rejected = [
      {
        name: "delimiter depth 256",
        sources: [{ name: "depth.nu", source: "(".repeat(256) }],
        diagnostic: {
          code: 1,
          sourcePart: 1,
          offset: 255,
          line: 1,
          column: 256,
        },
      },
      {
        name: "unclosed delimiter",
        sources: [{ name: "open.nu", source: "(1\n" }],
        diagnostic: { code: 1, sourcePart: 1, offset: 3, line: 2, column: 1 },
      },
      {
        name: "delimiter across source parts",
        sources: [
          { name: "first.nu", source: "(" },
          { name: "second.nu", source: "1)\n" },
        ],
        diagnostic: { code: 1, sourcePart: 1, offset: 1, line: 1, column: 2 },
      },
      {
        name: "parenthesis closed as bracket",
        sources: [{ name: "mismatch.nu", source: "(]\n" }],
        diagnostic: { code: 1, sourcePart: 1, offset: 1, line: 1, column: 2 },
      },
      {
        name: "bracket closed as parenthesis",
        sources: [{ name: "mismatch.nu", source: "[)\n" }],
        diagnostic: { code: 1, sourcePart: 1, offset: 1, line: 1, column: 2 },
      },
      {
        name: "crossed nested delimiters",
        sources: [{ name: "mismatch.nu", source: "([)]\n" }],
        diagnostic: { code: 1, sourcePart: 1, offset: 2, line: 1, column: 3 },
      },
      ...[0x00, 0x01, 0x08, 0x0b, 0x0c, 0x0e, 0x1f, 0x7f, 0x80, 0xff].map(
        (byte) => ({
          name: `invalid source byte $${byte.toString(16)} inside comment`,
          sources: [
            {
              name: "comment.nu",
              source: new Uint8Array([0x2f, 0x2f, byte, 0x0a]),
            },
          ],
          diagnostic: { code: 1, sourcePart: 1, offset: 2, line: 1, column: 3 },
        }),
      ),
    ] as const;
    for (const testCase of rejected) {
      const result = await compileNucleus(testCase.sources, {}, selected);
      expect(result, testCase.name).toMatchObject({
        success: false,
        diagnostic: testCase.diagnostic,
      });
    }

    const scanFirstToken = (sourceData: Uint8Array) => {
      const program = parseIntelHex(image.hex);
      const runtime = createZ80Runtime(
        { ...program, memory: program.memory.slice() },
        image.symbols.RewriteTokenizerNext ?? -1,
      );
      const memory = runtime.hardware.memory;
      const source = 0x5100;
      memory.set(sourceData, source);
      memory[image.symbols.SourcePartId ?? -1] = 1;
      writeWord(
        memory,
        image.symbols.RewriteSourceDescriptorStart ?? -1,
        source,
      );
      writeWord(
        memory,
        image.symbols.RewriteSourceEnd ?? -1,
        source + sourceData.length,
      );
      writeWord(memory, image.symbols.RewriteSourceOffset ?? -1, 0);
      writeWord(memory, image.symbols.RewriteSourceCursor ?? -1, source);
      memory[image.symbols.RewriteSourcePartsRemaining ?? -1] = 0;
      memory[image.symbols.RewriteSourceLineHasToken ?? -1] = 0;
      memory[image.symbols.RewriteSourceDelimiterDepth ?? -1] = 0;
      memory[0x3000] = 0x76;
      writeWord(memory, 0x5e00, 0x3000);
      runtime.cpu.sp = 0x5e00;
      let instructions = 0;
      while (!runtime.isHalted() && instructions < 100_000) {
        runtime.step();
        instructions += 1;
      }
      expect(runtime.isHalted()).toBe(true);
      expect(runtime.cpu.flags.C).toBe(0);
      expect(runtime.cpu.sp).toBe(0x5e02);
      return { runtime, memory, source };
    };

    const maximumName = new Uint8Array(256).fill("a".charCodeAt(0));
    maximumName[255] = 0x0a;
    const scannedName = scanFirstToken(maximumName);
    expect(scannedName.runtime.cpu.a).toBe(image.symbols.TokenName);
    expect(scannedName.runtime.cpu.b).toBe(0);
    expect(scannedName.runtime.cpu.c).toBe(0);
    expect(scannedName.memory[image.symbols.TokenLength ?? -1]).toBe(255);
    expect(
      wordAt(scannedName.memory, image.symbols.TokenStartOffset ?? -1),
    ).toBe(0);
    expect(
      wordAt(scannedName.memory, image.symbols.TokenLexemePointer ?? -1),
    ).toBe(scannedName.source);

    const escapedMaximum = Uint8Array.from([
      0x22,
      ...Array.from({ length: 255 }, () => [0x5c, 0x30]).flat(),
      0x22,
      0x0a,
    ]);
    const scannedString = scanFirstToken(escapedMaximum);
    expect(scannedString.runtime.cpu.a).toBe(image.symbols.TokenStringLiteral);
    expect(scannedString.runtime.cpu.b).toBe(0);
    expect(scannedString.runtime.cpu.c).toBe(255);
    expect(scannedString.memory[image.symbols.TokenLength ?? -1]).toBe(255);
    expect(
      wordAt(scannedString.memory, image.symbols.TokenStartOffset ?? -1),
    ).toBe(0);
    expect(
      wordAt(scannedString.memory, image.symbols.TokenLexemePointer ?? -1),
    ).toBe(scannedString.source);

    const maximumParts = await compileNucleus(
      Array.from({ length: 8 }, (_, index) => ({
        name: `part-${index + 1}.nu`,
        source: "",
      })),
      {},
      selected,
    );
    expect(maximumParts).toMatchObject({
      success: false,
      diagnostic: {
        code: 67,
        sourcePart: 8,
        offset: 0,
        line: 1,
        column: 1,
      },
    });
  }, 30_000);

  it("executes the same diagnostic across the full address space", async () => {
    const directory = await mkdtemp(
      path.join(os.tmpdir(), "nucleus-r1-origin-"),
    );
    try {
      const imageInclude = path.join(rewriteDirectory, "compiler-image.asmi");
      const assembleAt = async (
        origin: number,
        workBase = 0x6000,
        adapterBase = 0xa000,
      ): Promise<AssembledImage> => {
        const sourcePath = path.join(
          directory,
          `rewrite-${origin.toString(16)}.asm`,
        );
        const relativeImage = path.relative(directory, imageInclude);
        await writeFile(
          sourcePath,
          [
            `CompilerWorkBase .equ $${workBase.toString(16)}`,
            "SourceBase .equ $5000",
            "SourceLimit .equ $5800",
            `RewriteAdapterBase .equ $${adapterBase.toString(16)}`,
            `RewriteAdapterLimit .equ $${(adapterBase + 0x100).toString(16)}`,
            "DebugHooks .equ 0",
            `.org $${origin.toString(16)}`,
            `.include ${JSON.stringify(relativeImage)}`,
            "",
          ].join("\n"),
          "utf8",
        );
        return await assemble(sourcePath);
      };
      const zero = await assembleAt(0);
      const coreBytes =
        (zero.symbols.CompilerCoreEnd ?? 0) -
        (zero.symbols.CompilerCodeStart ?? 0);
      const shellBytes =
        (zero.symbols.RewriteSourceCodeStart ?? 0) -
        (zero.symbols.RewriteCompilerCodeStart ?? 0);
      const sourceBytes =
        (zero.symbols.RewriteSourceCodeEnd ?? 0) -
        (zero.symbols.RewriteSourceCodeStart ?? 0);
      const tokenizerBytes =
        (zero.symbols.RewriteTokenizerCodeEnd ?? 0) -
        (zero.symbols.RewriteTokenizerCodeStart ?? 0);
      const keywordBytes =
        (zero.symbols.RewriteKeywordImmutableEnd ?? 0) -
        (zero.symbols.RewriteKeywordImmutableStart ?? 0);
      const operationBytes =
        (zero.symbols.RewriteOperationImmutableEnd ?? 0) -
        (zero.symbols.RewriteOperationImmutableStart ?? 0);
      const semanticBytes =
        (zero.symbols.RewriteSemanticCodeEnd ?? 0) -
        (zero.symbols.RewriteSemanticCodeStart ?? 0);
      const metadataBytes =
        (zero.symbols.RewriteMetadataCodeEnd ?? 0) -
        (zero.symbols.RewriteMetadataCodeStart ?? 0);
      const workspaceBytes =
        (zero.symbols.RewriteWorkspaceEnd ?? 0) -
        (zero.symbols.RewriteStateBase ?? 0);
      expect({
        shellBytes,
        sourceBytes,
        tokenizerBytes,
        keywordBytes,
        operationBytes,
        semanticBytes,
        metadataBytes,
        sourceTokenBytes: sourceBytes + tokenizerBytes + keywordBytes,
        coreBytes,
        workspaceBytes,
      }).toEqual({
        shellBytes: 93,
        sourceBytes: 94,
        tokenizerBytes: 821,
        keywordBytes: 184,
        operationBytes: 618,
        semanticBytes: 220,
        metadataBytes: 8_153,
        sourceTokenBytes: 1_099,
        coreBytes: 10_968,
        workspaceBytes: 3_414,
      });
      const layouts: readonly {
        readonly origin: number;
        readonly image?: AssembledImage;
        readonly workBase?: number;
        readonly adapterBase?: number;
      }[] = [
        { origin: 0, image: zero },
        { origin: 0x0100 },
        { origin: 0x6000, workBase: 0xa000, adapterBase: 0xb000 },
        { origin: 0x8000 },
        { origin: 0x1_0000 - coreBytes },
      ];
      const comprehensiveSource = new TextEncoder().encode(
        String.raw`var Name = ([65535, $fF, %1010, '\0', "\n"]) // comment` +
          "\r\n",
      );
      for (const layout of layouts) {
        const { origin } = layout;
        const image =
          layout.image ??
          (await assembleAt(origin, layout.workBase, layout.adapterBase));
        for (const [sourceData, diagnosticCode, diagnosticOffset] of [
          [new Uint8Array(["@".charCodeAt(0)]), 1, 0],
          [comprehensiveSource, 67, comprehensiveSource.length],
        ] as const) {
          const program = parseIntelHex(image.hex);
          const runtime = createZ80Runtime(
            { ...program, memory: program.memory.slice() },
            image.symbols.CompileTargetAggregateCallParts ?? -1,
          );
          const memory = runtime.hardware.memory;
          const descriptor = 0x5000;
          const source = 0x5100;
          memory[descriptor] = 1;
          writeWord(memory, descriptor + 1, source);
          writeWord(memory, descriptor + 3, source + sourceData.length);
          memory.set(sourceData, source);
          memory[0x3000] = 0x76;
          writeWord(memory, 0x5e00, 0x3000);
          runtime.cpu.sp = 0x5e00;
          runtime.cpu.a = 1;
          runtime.cpu.h = descriptor >>> 8;
          runtime.cpu.l = descriptor & 0xff;
          runtime.cpu.ix = 0x9e00;
          let instructions = 0;
          while (!runtime.isHalted() && instructions < 20_000) {
            runtime.step();
            instructions += 1;
          }
          expect(runtime.isHalted(), `origin $${origin.toString(16)}`).toBe(
            true,
          );
          expect(runtime.cpu.flags.C).toBe(1);
          expect(runtime.cpu.sp).toBe(0x5e02);
          expect(memory[image.symbols.DiagnosticCode ?? -1]).toBe(
            diagnosticCode,
          );
          expect(memory[image.symbols.DiagnosticPartId ?? -1]).toBe(1);
          expect(wordAt(memory, image.symbols.DiagnosticOffset ?? -1)).toBe(
            diagnosticOffset,
          );
        }
      }

      for (const partCount of [0, 9]) {
        const program = parseIntelHex(zero.hex);
        const runtime = createZ80Runtime(
          { ...program, memory: program.memory.slice() },
          zero.symbols.CompileTargetAggregateCallParts ?? -1,
        );
        const memory = runtime.hardware.memory;
        memory[0x3000] = 0x76;
        writeWord(memory, 0x5e00, 0x3000);
        runtime.cpu.sp = 0x5e00;
        runtime.cpu.a = partCount;
        runtime.cpu.h = 0x50;
        runtime.cpu.l = 0;
        runtime.cpu.ix = 0x9e00;
        let instructions = 0;
        while (!runtime.isHalted() && instructions < 20_000) {
          runtime.step();
          instructions += 1;
        }
        expect(runtime.isHalted(), `part count ${partCount}`).toBe(true);
        expect(runtime.cpu.flags.C).toBe(1);
        expect(memory[zero.symbols.DiagnosticCode ?? -1]).toBe(88);
        expect(memory[zero.symbols.DiagnosticPartId ?? -1]).toBe(0);
        expect(wordAt(memory, zero.symbols.DiagnosticOffset ?? -1)).toBe(0);
      }
    } finally {
      await rm(directory, { recursive: true, force: true });
    }
  }, 30_000);
});
