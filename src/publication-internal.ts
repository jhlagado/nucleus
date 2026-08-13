import { access, mkdir, rename, rm, writeFile } from "node:fs/promises";
import path from "node:path";

let publicationOrdinal = 0;

const exists = async (filePath: string): Promise<boolean> => {
  try {
    await access(filePath);
    return true;
  } catch {
    return false;
  }
};

export interface NucleusPublicationInternalOutput {
  readonly path: string;
  readonly contents: string | Uint8Array;
}

export interface NucleusPublicationInternalHooks {
  readonly beforePromote?: (
    path: string,
    index: number,
  ) => void | Promise<void>;
}

export const publishNucleusArtifactSetInternal = async (
  outputs: readonly NucleusPublicationInternalOutput[],
  replacePaths: readonly string[] = [],
  hooks: NucleusPublicationInternalHooks = {},
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
    for (const [index, output] of staged.entries()) {
      await hooks.beforePromote?.(output.path, index);
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
    for (const output of staged) {
      await rm(output.temporaryPath, { force: true });
    }
  }
  for (const backup of movedBackups) {
    await rm(backup.backupPath, { force: true });
  }
  return staged.map((output) => output.path);
};
