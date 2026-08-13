#!/usr/bin/env node

import { readFile, writeFile } from "node:fs/promises";
import path from "node:path";

import { compileNucleus, writeNucleusIntelHex } from "./compiler.js";

const usage = (): never => {
  console.error(
    "usage: nucleus build [-o program.nobj] [--hex-output program.hex] <source.nu> [more.nu ...]",
  );
  process.exit(2);
};

const args = process.argv.slice(2);
if (args.shift() !== "build") usage();
let output: string | undefined;
let hexOutput: string | undefined;
const sources: string[] = [];
while (args.length > 0) {
  const argument = args.shift();
  if (argument === "-o" || argument === "--output") {
    output = args.shift() ?? usage();
  } else if (argument === "--hex-output") {
    hexOutput = args.shift() ?? usage();
  } else if (argument?.startsWith("-") === true) {
    usage();
  } else if (argument !== undefined) {
    sources.push(argument);
  }
}
if (sources.length === 0) usage();
output ??= `${sources[0]?.replace(/\.nu$/i, "") ?? "program"}.nobj`;

const result = await compileNucleus(
  await Promise.all(
    sources.map(async (name) => ({ name, source: await readFile(name) })),
  ),
);
if (!result.success) {
  const diagnostic = result.diagnostic;
  console.error(
    `${diagnostic.sourceName ?? `part ${diagnostic.sourcePart}`}:${diagnostic.line}:${diagnostic.column}: Nucleus diagnostic ${diagnostic.code}`,
  );
  process.exitCode = 1;
} else {
  await writeFile(output, result.nobj);
  console.log(`Wrote ${path.resolve(output)}`);
  if (hexOutput !== undefined) {
    await writeFile(hexOutput, writeNucleusIntelHex(result), "utf8");
    console.log(`Wrote ${path.resolve(hexOutput)}`);
  }
}
