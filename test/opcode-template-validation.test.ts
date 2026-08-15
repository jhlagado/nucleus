import { readFileSync } from "node:fs";
import path from "node:path";

import { compileNext } from "@jhlagado/azm";
import { parseIntelHex } from "@jhlagado/debug80-runtime";
import { describe, expect, it } from "vitest";

import {
  debugCompilerHex,
  debugCompilerSymbols,
  normalCompilerHex,
  normalCompilerSymbols,
} from "../src/generated-compiler-images.js";

interface OpcodeTemplate {
  readonly file: string;
  readonly symbol: string;
  readonly source: string;
  readonly prefixLength: number;
}

const sink = "asm/vertical-slice/loop-z80-sink.asm";
const structured = "asm/vertical-slice/structured-control-z80.asm";
const aggregate = "asm/vertical-slice/aggregate-call-z80.asm";
const typed = "asm/vertical-slice/typed-expression-z80.asm";

const templates: readonly OpcodeTemplate[] = [
  {
    file: sink,
    symbol: "EmitPairLoadIXLTemplate",
    source: "LD L,(IX+0)",
    prefixLength: 2,
  },
  {
    file: sink,
    symbol: "EmitPairLoadIXHTemplate",
    source: "LD H,(IX+0)",
    prefixLength: 2,
  },
  {
    file: sink,
    symbol: "EmitPairStoreIXLTemplate",
    source: "LD (IX+0),L",
    prefixLength: 2,
  },
  {
    file: sink,
    symbol: "EmitPairStoreIXHTemplate",
    source: "LD (IX+0),H",
    prefixLength: 2,
  },
  {
    file: sink,
    symbol: "EmitPairPopHLLoadDETemplate",
    source: "POP HL\nLD DE,0",
    prefixLength: 2,
  },
  { file: sink, symbol: "CallLiteralCallOpcode", source: "CALL 0", prefixLength: 1 },
  {
    file: sink,
    symbol: "ExpressionLoadLocalIndexPrefix",
    source: "LD A,(IX+0)",
    prefixLength: 1,
  },
  {
    file: sink,
    symbol: "ExpressionStoreLocalIndexPrefix",
    source: "LD (IX+0),A",
    prefixLength: 1,
  },
  {
    file: sink,
    symbol: "ExpressionEntryJumpOpcode",
    source: "JP 0",
    prefixLength: 1,
  },
  {
    file: sink,
    symbol: "ArrayDataAddressOpcode",
    source: "LD HL,0",
    prefixLength: 1,
  },
  {
    file: structured,
    symbol: "StructuredFitJumpOpcode",
    source: "JP Z,0",
    prefixLength: 1,
  },
  {
    file: aggregate,
    symbol: "Stage7LoadBImmediate",
    source: "LD B,0",
    prefixLength: 1,
  },
  {
    file: aggregate,
    symbol: "Stage7LoadIXC",
    source: "LD C,(IX+0)",
    prefixLength: 2,
  },
  {
    file: typed,
    symbol: "EncodeProgramEntryJumpOpcode",
    source: "JP 0",
    prefixLength: 1,
  },
  {
    file: typed,
    symbol: "TypedStoreSPPrefix",
    source: "LD (0),SP",
    prefixLength: 2,
  },
  {
    file: typed,
    symbol: "TypedStoreIXPrefix",
    source: "LD (0),IX",
    prefixLength: 2,
  },
  {
    file: typed,
    symbol: "TypedLoadSPPrefix",
    source: "LD SP,(0)",
    prefixLength: 2,
  },
  {
    file: typed,
    symbol: "TypedLoadIXPrefix",
    source: "LD IX,(0)",
    prefixLength: 2,
  },
  {
    file: typed,
    symbol: "TypedLoadLocalLow",
    source: "LD L,(IX+0)",
    prefixLength: 2,
  },
  {
    file: typed,
    symbol: "TypedLoadLocalHigh",
    source: "LD H,(IX+0)",
    prefixLength: 2,
  },
];

const compilerImages = [
  {
    name: "normal",
    memory: parseIntelHex(normalCompilerHex).memory,
    symbols: normalCompilerSymbols,
  },
  {
    name: "debug",
    memory: parseIntelHex(debugCompilerHex).memory,
    symbols: debugCompilerSymbols,
  },
] as const;

describe("assembler-validated target opcode templates", () => {
  const root = path.resolve(import.meta.dirname, "..");

  for (const template of templates) {
    it(
      `matches ${template.symbol} to ${template.source.replaceAll("\n", "; ")}`,
      () => {
        const assembled = compileNext(template.source);
        expect(assembled.diagnostics).toEqual([]);
        const expected = Array.from(
          assembled.bytes.slice(0, template.prefixLength),
        );
        expect(expected).toHaveLength(template.prefixLength);
        expect(assembled.bytes.length).toBeGreaterThan(template.prefixLength);

        const source = readFileSync(path.join(root, template.file), "utf8");
        const labelAt = source.indexOf(`${template.symbol}:`);
        expect(
          labelAt,
          `${template.symbol} must exist in ${template.file}`,
        ).toBeGreaterThanOrEqual(0);
        const declaration =
          source.slice(labelAt).match(/\.db\s+([^;\r\n]+)/u)?.[1] ?? "";
        const declared = [
          ...declaration.matchAll(/\$([0-9a-f]{2})/giu),
        ].map((match) => Number.parseInt(match[1] ?? "", 16));
        expect(
          declared,
          `${template.symbol} must declare its retained prefix`,
        ).toEqual(expected);

        for (const image of compilerImages) {
          const address = image.symbols[template.symbol];
          if (address === undefined) continue;
          expect(
            Array.from(
              image.memory.slice(address, address + template.prefixLength),
            ),
            `${template.symbol} must match AZM in the ${image.name} image`,
          ).toEqual(expected);
        }
      },
    );
  }

  it("marks every retained hexadecimal byte template in the target backend", () => {
    const files = [
      "asm/vertical-slice/loop-z80-sink.asm",
      "asm/vertical-slice/structured-control-z80.asm",
      "asm/vertical-slice/aggregate-call-z80.asm",
      "asm/vertical-slice/typed-expression-z80.asm",
      "asm/vertical-slice/target-output.asm",
      "asm/vertical-slice/z80-slice-proof.asm",
    ];

    let markedPrefixes = 0;
    for (const file of files) {
      const lines = readFileSync(path.join(root, file), "utf8").split(/\r?\n/u);
      for (const [index, line] of lines.entries()) {
        expect(
          /\.dw\b[^;]*\$[0-9a-f]/iu.test(line),
          `${file}:${index + 1} must not encode an instruction operand as a raw word`,
        ).toBe(false);
        if (!/\.db\b[^;]*\$[0-9a-f]/iu.test(line)) continue;
        expect(
          line,
          `${file}:${index + 1} must identify and validate any raw opcode-template exception`,
        ).toContain("opcode-template prefix:");
        markedPrefixes += 1;
      }
    }
    expect(markedPrefixes).toBe(templates.length);
  });
});
