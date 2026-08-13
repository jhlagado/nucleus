import { nucleusD8OutputPaths } from "./d8.js";
import { publishNucleusArtifactSetInternal, } from "./publication-internal.js";
export const publishNucleusD8OutputsInternal = async (requestedPath, mapping, previousPaths, hooks = {}) => {
    const outputs = nucleusD8OutputPaths(requestedPath, mapping).map(({ path, map }) => ({
        path,
        contents: `${JSON.stringify(map, null, 2)}\n`,
    }));
    return await publishNucleusArtifactSetInternal(outputs, previousPaths, hooks);
};
