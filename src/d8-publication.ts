import { access, readdir, rename, rm, writeFile } from "node:fs/promises";
import path from "node:path";

import { nucleusD8OutputPaths, type NucleusDebugMapping } from "./d8.js";

let publicationOrdinal = 0;

const exists = async (filePath: string): Promise<boolean> => {
  try {
    await access(filePath);
    return true;
  } catch {
    return false;
  }
};

const escaped = (value: string): string =>
  value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

export const existingNucleusD8OutputPaths = async (
  requestedPath: string,
): Promise<string[]> => {
  const directory = path.dirname(requestedPath);
  const requestedName = path.basename(requestedPath);
  const suffix = ".d8.json";
  const baseName = requestedName.toLowerCase().endsWith(suffix)
    ? requestedName.slice(0, -suffix.length)
    : requestedName;
  const bankPattern = new RegExp(
    `^${escaped(baseName)}\\.bank-[0-9]+\\.d8\\.json$`,
  );
  let names: string[];
  try {
    names = await readdir(directory);
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "ENOENT") return [];
    throw error;
  }
  return names
    .filter((name) => name === requestedName || bankPattern.test(name))
    .map((name) => path.join(directory, name));
};

/** Atomically replace the complete flat-or-banked D8 sidecar group. */
export const publishNucleusD8Outputs = async (
  requestedPath: string,
  mapping: NucleusDebugMapping,
): Promise<readonly string[]> => {
  const generation = `${process.pid}-${Date.now()}-${(publicationOrdinal += 1)}`;
  const outputs = nucleusD8OutputPaths(requestedPath, mapping).map(
    (output) => ({
      ...output,
      temporaryPath: `${output.path}.nucleus-${generation}`,
    }),
  );
  const previousPaths = await existingNucleusD8OutputPaths(requestedPath);
  const backups = previousPaths.map((previousPath) => ({
    path: previousPath,
    backupPath: `${previousPath}.nucleus-backup-${generation}`,
  }));
  const promoted: string[] = [];
  const movedBackups: typeof backups = [];
  try {
    for (const output of outputs) {
      await writeFile(
        output.temporaryPath,
        `${JSON.stringify(output.map, null, 2)}\n`,
        "utf8",
      );
    }
    for (const backup of backups) {
      if (await exists(backup.path)) {
        await rename(backup.path, backup.backupPath);
        movedBackups.push(backup);
      }
    }
    for (const output of outputs) {
      await rename(output.temporaryPath, output.path);
      promoted.push(output.path);
    }
  } catch (error) {
    for (const promotedPath of promoted) {
      await rm(promotedPath, { force: true });
    }
    for (const backup of movedBackups) {
      if (await exists(backup.backupPath)) {
        await rename(backup.backupPath, backup.path);
      }
    }
    throw error;
  } finally {
    for (const output of outputs) {
      await rm(output.temporaryPath, { force: true });
    }
  }
  for (const backup of movedBackups) {
    await rm(backup.backupPath, { force: true });
  }
  return outputs.map((output) => output.path);
};
