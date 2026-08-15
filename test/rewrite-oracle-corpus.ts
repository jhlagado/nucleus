import {
  defaultNucleusServices,
  type NucleusSourcePart,
  type NucleusTarget,
} from "../src/compiler.js";

export interface RewriteOracleSuccessCase {
  readonly name: string;
  readonly sources: readonly NucleusSourcePart[];
  readonly target: NucleusTarget;
}

export interface RewriteOracleDiagnosticCase {
  readonly name: string;
  readonly sources: readonly NucleusSourcePart[];
  readonly target?: NucleusTarget;
}

const featureSource = [
  "record Pair",
  "values as i16[2]",
  "end",
  'const greeting as string[8] = "Hi"',
  "var grid as u8[2][2] = [[1, 2], [3, 4]]",
  "var pair as Pair = ([-1, 2])",
  "var result as i16",
  "sub inspect(rows as u8[][2], text as string[]) as i16",
  "text.length = 2",
  "rows[0][1] = text[0]",
  "return i16(rows.length) + pair.values[0]",
  "end",
  "sub mayFail(value as i16) as i16 fails",
  "if value < 0",
  "fail 7",
  "end",
  "return value",
  "end",
  "sub main() fails",
  "var code as u8",
  "result = inspect(grid, greeting)",
  "result = mayFail(result) handle code",
  "result = result + i16(code)",
  "end",
  "end",
  "",
].join("\n");

const bankedLibrary = [
  "sub last(rows as u8[][2]) as u8",
  "return rows[rows.length - 1][1]",
  "end",
  "sub textLength(text as string[]) as u8",
  "return text.length",
  "end",
  "",
].join("\n");

const bankedMain = [
  "var grid as u8[2][2] = [[1, 2], [3, 4]]",
  'var text as string[5] = "hello"',
  "var observed as u8",
  "sub main()",
  "observed = last(grid) + textLength(text)",
  "end",
  "",
].join("\n");

export const rewriteOracleSuccessCases: readonly RewriteOracleSuccessCase[] = [
  {
    name: "flat-current-language",
    sources: [{ name: "features.nu", source: featureSource }],
    target: { services: defaultNucleusServices },
  },
  {
    name: "banked-multipart-open-views",
    sources: [
      { name: "library.nu", source: bankedLibrary },
      { name: "main.nu", source: bankedMain },
    ],
    target: {
      bankCount: 2,
      entryBank: 0,
      partBanks: [1, 0],
      imageBase: 0x8000,
      imageCapacity: 0x1000,
      writableBase: 0x4000,
      writableCapacity: 0x1000,
      services: { ...defaultNucleusServices, farCall: 0x7000, farJump: 0x7080 },
    },
  },
  {
    name: "multipart-crlf-and-synthesized-final-newline",
    sources: [
      {
        name: "library.nu",
        source: "sub value() as i8\r\nreturn -7\r\nend\r\n",
      },
      {
        name: "main.nu",
        source: "var result as i8\r\nsub main()\r\nresult = value()\r\nend",
      },
    ],
    target: { services: defaultNucleusServices },
  },
] as const;

const source = (text: string): readonly NucleusSourcePart[] => [
  { name: "diagnostic.nu", source: text },
];

export const rewriteOracleDiagnosticCases: readonly RewriteOracleDiagnosticCase[] = [
  {
    name: "lexical",
    sources: source("@\n"),
  },
  {
    name: "predictive-grammar",
    sources: source("broken\n"),
  },
  {
    name: "duplicate-name",
    sources: source("var value as u8\nvar value as u8\nsub main()\nend\n"),
  },
  {
    name: "unknown-name",
    sources: source("sub main()\nmissing = 1\nend\n"),
  },
  {
    name: "type-mismatch",
    sources: source("var value as boolean\nsub main()\nvalue = 1\nend\n"),
  },
  {
    name: "integer-range",
    sources: source("var value as i8 = 128\nsub main()\nend\n"),
  },
  {
    name: "constant-division-zero",
    sources: source("const bad = 1 / 0\nsub main()\nend\n"),
  },
  {
    name: "comparison-chain",
    sources: source("sub main()\nif 1 < 2 < 3\nend\nend\n"),
  },
  {
    name: "loop-context",
    sources: source("sub main()\nexit\nend\n"),
  },
  {
    name: "routine-flow",
    sources: source("sub value() as u8\nend\nsub main()\nend\n"),
  },
  {
    name: "initializer-shape",
    sources: source("var values as u8[2] = [1]\nsub main()\nend\n"),
  },
  {
    name: "open-view-placement",
    sources: source("var values as u8[]\nsub main()\nend\n"),
  },
  {
    name: "failure-context",
    sources: source("sub work() fails\nend\nsub main()\nwork()\nend\n"),
  },
  {
    name: "compile-time-assertion",
    sources: source("assert false\nsub main()\nend\n"),
  },
  {
    name: "read-only-assignment",
    sources: source(
      "const values as u8[2] = [1, 2]\nsub main()\nvalues[0] = 3\nend\n",
    ),
  },
  {
    name: "target-image-capacity",
    sources: source("sub main()\nend\n"),
    target: { imageCapacity: 1 },
  },
] as const;

export const rewriteOracleCoverage = {
  languageAndDiagnostics: [
    "test/language-specification.test.ts",
    "test/compiler.test.ts",
    "test/ll1-stage7.test.ts",
    "test/signed-integers.test.ts",
    "test/nested-arrays.test.ts",
    "test/open-array-parameters.test.ts",
    "test/open-string-parameters.test.ts",
    "test/string-construction.test.ts",
  ],
  targetsAndArtifacts: [
    "test/proof-harness.test.ts",
    "test/compiler-relocation.test.ts",
    "test/nobj.test.ts",
    "test/d8.test.ts",
    "test/host.test.ts",
  ],
  publishedCapacities: "docs/implementation-plan.md#capacity-ledger",
} as const;
