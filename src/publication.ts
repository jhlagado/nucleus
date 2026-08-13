import { access, mkdir, rename, rm, writeFile } from "node:fs/promises";
import path from "node:path";

import { existingNucleusD8OutputPaths } from "./d8-publication.js";
import type { NucleusBuildArtifacts, NucleusD8Artifact } from "./host.js";

let publicationOrdinal = 0;

const exists = async (filePath: string): Promise<boolean> => {
  try {
    await access(filePath);
    return true;
  } catch {
    return false;
  }
};

export interface NucleusPublicationOutput {
  readonly path: string;
  readonly contents: string | Uint8Array;
}

export const nucleusD8ArtifactOutputs = (
  requestedPath: string,
  artifacts: readonly NucleusD8Artifact[],
): readonly NucleusPublicationOutput[] => {
  if (artifacts.length === 1) {
    return [{ path: requestedPath, contents: artifacts[0]?.json ?? "" }];
  }
  const suffix = ".d8.json";
  const base = requestedPath.toLowerCase().endsWith(suffix)
    ? requestedPath.slice(0, -suffix.length)
    : requestedPath;
  return artifacts.map((artifact) => ({
    path: `${base}.bank-${artifact.bank}.d8.json`,
    contents: artifact.json,
  }));
};

/** Replace a related artifact set as one recoverable filesystem transaction. */
export const publishNucleusArtifactSet = async (
  outputs: readonly NucleusPublicationOutput[],
  replacePaths: readonly string[] = [],
): Promise<readonly string[]> => {
  const generation = `${process.pid}-${Date.now()}-${(publicationOrdinal += 1)}`;
  const desired = new Set(outputs.map((output) => path.resolve(output.path)));
  if (desired.size !== outputs.length) {
    throw new Error("Nucleus artifact outputs must use distinct paths");
  }
  const affected = [
    ...desired,
    ...replacePaths.map((filePath) => path.resolve(filePath)),
  ].filter((filePath, index, all) => all.indexOf(filePath) === index);
  const staged = outputs.map((output) => ({
    ...output,
    path: path.resolve(output.path),
    temporaryPath: `${path.resolve(output.path)}.nucleus-${generation}`,
  }));
  const backups = affected.map((filePath) => ({
    path: filePath,
    backupPath: `${filePath}.nucleus-backup-${generation}`,
  }));
  const movedBackups: typeof backups = [];
  const promoted: string[] = [];
  try {
    for (const output of staged) {
      await mkdir(path.dirname(output.path), { recursive: true });
      await writeFile(output.temporaryPath, output.contents);
    }
    for (const backup of backups) {
      if (await exists(backup.path)) {
        await rename(backup.path, backup.backupPath);
        movedBackups.push(backup);
      }
    }
    for (const output of staged) {
      await rename(output.temporaryPath, output.path);
      promoted.push(output.path);
    }
  } catch (error) {
    for (const promotedPath of promoted)
      await rm(promotedPath, { force: true });
    for (const backup of movedBackups) {
      if (await exists(backup.backupPath)) {
        await rename(backup.backupPath, backup.path);
      }
    }
    throw error;
  } finally {
    for (const output of staged)
      await rm(output.temporaryPath, { force: true });
  }
  for (const backup of movedBackups)
    await rm(backup.backupPath, { force: true });
  return staged.map((output) => output.path);
};

export interface NucleusBuildOutputPaths {
  readonly nobj: string;
  readonly hex?: string;
  readonly d8?: string;
}

export const publishNucleusBuildOutputs = async (
  paths: NucleusBuildOutputPaths,
  artifacts: NucleusBuildArtifacts,
): Promise<readonly string[]> => {
  const outputs: NucleusPublicationOutput[] = [
    { path: paths.nobj, contents: artifacts.nobj },
  ];
  if (paths.hex !== undefined) {
    if (artifacts.hex === undefined)
      throw new Error("Nucleus build omitted requested HEX");
    outputs.push({ path: paths.hex, contents: artifacts.hex });
  }
  let previousD8: readonly string[] = [];
  if (paths.d8 !== undefined) {
    if (artifacts.d8 === undefined)
      throw new Error("Nucleus build omitted requested D8");
    outputs.push(...nucleusD8ArtifactOutputs(paths.d8, artifacts.d8));
    previousD8 = await existingNucleusD8OutputPaths(paths.d8);
  }
  return await publishNucleusArtifactSet(outputs, previousD8);
};
