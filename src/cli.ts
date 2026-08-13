#!/usr/bin/env node

import { readFile, writeFile } from "node:fs/promises";
import path from "node:path";

import {
  compileNucleus,
  type NucleusFlatTarget,
  writeNucleusIntelHex,
} from "./compiler.js";

const usage = (): never => {
  console.error(
    "usage: nucleus build [-o program.nobj] [--hex-output program.hex] [--target-profile target.json] <source.nu> [more.nu ...]",
  );
  process.exit(2);
};

const targetServiceNames = [
  "readInputByte",
  "writeOutputByte",
  "readStorageByte",
  "rewindStorageInput",
  "writeStorageByte",
  "seekStorageOutput",
  "success",
  "unhandledFailure",
  "trap",
  "farCall",
  "farJump",
] as const;

const parseTargetProfile = (text: string): NucleusFlatTarget => {
  const value: unknown = JSON.parse(text);
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new Error("Nucleus target profile must be a JSON object");
  }
  const profile = value as Record<string, unknown>;
  if (
    profile.establishStack !== undefined &&
    typeof profile.establishStack !== "boolean"
  ) {
    throw new Error("Nucleus target establishStack must be Boolean");
  }
  if (
    typeof profile.services !== "object" ||
    profile.services === null ||
    Array.isArray(profile.services)
  ) {
    throw new Error("Nucleus target profile must define every service address");
  }
  const services = profile.services as Record<string, unknown>;
  for (const name of targetServiceNames) {
    if (services[name] === undefined) {
      throw new Error(`Nucleus target profile is missing service ${name}`);
    }
  }
  return value as NucleusFlatTarget;
};

const args = process.argv.slice(2);
if (args.shift() !== "build") usage();
let output: string | undefined;
let hexOutput: string | undefined;
let targetProfile: string | undefined;
const sources: string[] = [];
while (args.length > 0) {
  const argument = args.shift();
  if (argument === "-o" || argument === "--output") {
    output = args.shift() ?? usage();
  } else if (argument === "--hex-output") {
    hexOutput = args.shift() ?? usage();
  } else if (argument === "--target-profile") {
    targetProfile = args.shift() ?? usage();
  } else if (argument?.startsWith("-") === true) {
    usage();
  } else if (argument !== undefined) {
    sources.push(argument);
  }
}
if (sources.length === 0) usage();
output ??= `${sources[0]?.replace(/\.nu$/i, "") ?? "program"}.nobj`;
if (hexOutput !== undefined && targetProfile === undefined) {
  throw new Error("Intel HEX output requires --target-profile");
}

const target =
  targetProfile === undefined
    ? undefined
    : parseTargetProfile(await readFile(targetProfile, "utf8"));

const result = await compileNucleus(
  await Promise.all(
    sources.map(async (name) => ({ name, source: await readFile(name) })),
  ),
  target ?? {},
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
