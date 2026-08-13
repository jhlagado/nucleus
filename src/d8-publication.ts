import { readdir } from "node:fs/promises";
import path from "node:path";

import { publishNucleusD8OutputsInternal } from "./d8-publication-internal.js";
import type { NucleusDebugMapping } from "./d8.js";

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

/** Replace the complete flat-or-banked D8 sidecar group with rollback. */
export const publishNucleusD8Outputs = async (
  requestedPath: string,
  mapping: NucleusDebugMapping,
): Promise<readonly string[]> => {
  const previousPaths = await existingNucleusD8OutputPaths(requestedPath);
  return await publishNucleusD8OutputsInternal(
    requestedPath,
    mapping,
    previousPaths,
  );
};
