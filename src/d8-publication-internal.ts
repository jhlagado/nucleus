import { nucleusD8OutputPaths, type NucleusDebugMapping } from "./d8.js";
import {
  publishNucleusArtifactSetInternal,
  type NucleusPublicationInternalHooks,
} from "./publication-internal.js";

export const publishNucleusD8OutputsInternal = async (
  requestedPath: string,
  mapping: NucleusDebugMapping,
  previousPaths: readonly string[],
  hooks: NucleusPublicationInternalHooks = {},
): Promise<readonly string[]> => {
  const outputs = nucleusD8OutputPaths(requestedPath, mapping).map(
    ({ path, map }) => ({
      path,
      contents: `${JSON.stringify(map, null, 2)}\n`,
    }),
  );
  return await publishNucleusArtifactSetInternal(outputs, previousPaths, hooks);
};
