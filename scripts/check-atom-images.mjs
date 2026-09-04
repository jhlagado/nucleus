// This gate is deliberately separate from publication until every image agrees.
import { readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { parseIntelHex } from "@jhlagado/debug80-runtime";
import { assembleAtomSource } from "./atom-source.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const variants = {
  normal: ["flat-target-z80-slice-proof.asm", "normalCompiler", "generated-compiler-images.ts"],
  debug: ["flat-target-debug-z80-slice-proof.asm", "debugCompiler", "generated-compiler-images.ts"],
  native: ["native-target-compiler.asm", "nativeCompiler", "generated-compiler-images.ts"],
  "native-debug": ["native-target-debug-compiler.asm", "nativeDebugCompiler", "generated-compiler-images.ts"],
  mon3: ["native-target-mon3-compiler.asm", "mon3Compiler", "generated-compiler-images.ts"],
  "mon3-debug": ["native-target-mon3-debug-compiler.asm", "mon3DebugCompiler", "generated-compiler-images.ts"],
  runner: ["node-nobj-consumer.asm", "nodeNobjRunner", "generated-node-runner.ts"],
  resolver: ["native-import-resolver-tool.asm", "nativeImportResolver", "generated-native-import-resolver.ts"],
};

function coverage(program) {
  const bits = new Uint8Array(65536);
  for (const range of program.writeRanges) bits.fill(1, range.start, range.end);
  return bits;
}
function spans(addresses) {
  const result = [];
  for (const address of addresses) {
    if (result.at(-1)?.end === address) result.at(-1).end++;
    else result.push({start: address, end: address + 1});
  }
  return result;
}
const name = process.argv[2] ?? "native";
if (!variants[name]) throw new Error(`Unknown variant ${name}; choose ${Object.keys(variants).join(", ")}`);
const [entry, prefix, file] = variants[name];
const text = await readFile(path.join(root, "src", file), "utf8");
const expectedHex = JSON.parse(new RegExp(`${prefix}Hex: string = (.*);`).exec(text)[1]);
const expectedSymbols = JSON.parse(new RegExp(`${prefix}Symbols: Readonly<Record<string, number>> = (\\{[\\s\\S]*?\\});`).exec(text)[1]);
const result = await assembleAtomSource(`vertical-slice/${entry}`);
const actual = parseIntelHex(result.hex), expected = parseIntelHex(expectedHex);
const actualCoverage = coverage(actual), expectedCoverage = coverage(expected);
const byteDifferences = [], coverageDifferences = [];
for (let i = 0; i < 65536; i++) {
  if (actual.memory[i] !== expected.memory[i]) byteDifferences.push(i);
  if (actualCoverage[i] !== expectedCoverage[i]) coverageDifferences.push(i);
}
const symbolDifferences = Object.entries(expectedSymbols).filter(([symbol, value]) => result.symbols[symbol] !== value)
  .map(([symbol, expected]) => ({symbol, expected, actual: result.symbols[symbol] ?? null}));
const extraSymbols = Object.keys(result.symbols).filter(symbol => !(symbol in expectedSymbols));
const report = {
  variant: name, instructions: result.instructions,
  expectedSymbolCount: Object.keys(expectedSymbols).length, actualSymbolCount: Object.keys(result.symbols).length,
  byteDifferenceCount: byteDifferences.length, byteDifferenceSpans: spans(byteDifferences),
  coverageDifferenceCount: coverageDifferences.length, coverageDifferenceSpans: spans(coverageDifferences),
  symbolDifferences, extraSymbols,
};
console.log(JSON.stringify(report, null, 2));
const output = process.argv[3];
if (output) await writeFile(output, JSON.stringify({ report, hex: result.hex, symbols: result.symbols, images: result.generation.images.map(image => ({address: image.address, length: image.bytes.length, source: image.source})), layout: result.generation.layout }, null, 2) + "\n");
if (byteDifferences.length || coverageDifferences.length || symbolDifferences.length || extraSymbols.length) process.exitCode = 1;
