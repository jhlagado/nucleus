#!/usr/bin/env node

import { access, readFile, rename, rm, writeFile } from "node:fs/promises";
import path from "node:path";

import {
  compileNucleus,
  type NucleusTarget,
  type NucleusCompileSuccess,
  writeNucleusIntelHex,
} from "./compiler.js";
import { nucleusD8OutputPaths } from "./d8.js";

const usage = (): never => {
  console.error(
    "usage: nucleus build [-o program.nobj] [--hex-output program.hex] [--d8-output program.d8.json] [--target-profile target.json] <source.nu> [more.nu ...]",
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

const parseTargetProfile = (text: string): NucleusTarget => {
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
  return value as NucleusTarget;
};

const args = process.argv.slice(2);
if (args.shift() !== "build") usage();
let output: string | undefined;
let hexOutput: string | undefined;
let d8Output: string | undefined;
let targetProfile: string | undefined;
const sources: string[] = [];
while (args.length > 0) {
  const argument = args.shift();
  if (argument === "-o" || argument === "--output") {
    output = args.shift() ?? usage();
  } else if (argument === "--hex-output") {
    hexOutput = args.shift() ?? usage();
  } else if (argument === "--d8-output") {
    d8Output = args.shift() ?? usage();
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
    sources.map(async (name) => ({
      name: path
        .relative(process.cwd(), path.resolve(name))
        .split(path.sep)
        .join("/"),
      source: await readFile(name),
    })),
  ),
  target ?? {},
  { debugMap: d8Output !== undefined },
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
  if (d8Output !== undefined) {
    await writeD8Outputs(result, d8Output);
  }
}

async function writeD8Outputs(
  result: NucleusCompileSuccess,
  requestedPath: string,
): Promise<void> {
  if (result.debugMapping === undefined) {
    throw new Error("Nucleus compiler omitted requested D8 mapping data");
  }
  const generation = `${process.pid}-${Date.now()}`;
  const outputs = nucleusD8OutputPaths(requestedPath, result.debugMapping).map(
    (output) => ({
      ...output,
      temporaryPath: `${output.path}.nucleus-${generation}`,
      backupPath: `${output.path}.nucleus-backup-${generation}`,
    }),
  );
  const promoted: string[] = [];
  const backups: Array<{ path: string; backupPath: string }> = [];
  try {
    for (const output of outputs) {
      await writeFile(
        output.temporaryPath,
        `${JSON.stringify(output.map, null, 2)}\n`,
        "utf8",
      );
    }
    for (const output of outputs) {
      if (await exists(output.path)) {
        await rename(output.path, output.backupPath);
        backups.push({ path: output.path, backupPath: output.backupPath });
      }
    }
    for (const output of outputs) {
      await rename(output.temporaryPath, output.path);
      promoted.push(output.path);
    }
  } catch (error) {
    for (const path of promoted) await rm(path, { force: true });
    for (const backup of backups) {
      if (await exists(backup.backupPath)) {
        await rename(backup.backupPath, backup.path);
      }
    }
    throw error;
  } finally {
    for (const output of outputs)
      await rm(output.temporaryPath, { force: true });
  }
  for (const backup of backups) await rm(backup.backupPath, { force: true });
  for (const output of outputs) {
    console.log(`Wrote ${path.resolve(output.path)}`);
  }
}

async function exists(filePath: string): Promise<boolean> {
  try {
    await access(filePath);
    return true;
  } catch {
    return false;
  }
}
