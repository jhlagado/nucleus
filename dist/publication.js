import { existingNucleusD8OutputPaths } from "./d8-publication.js";
import { publishNucleusArtifactSetInternal } from "./publication-internal.js";
export const nucleusD8ArtifactOutputs = (requestedPath, artifacts) => {
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
export const publishNucleusArtifactSet = async (outputs, replacePaths = []) => await publishNucleusArtifactSetInternal(outputs, replacePaths);
export const publishNucleusBuildOutputs = async (paths, artifacts) => {
    const outputs = [
        { path: paths.nobj, contents: artifacts.nobj },
    ];
    if (paths.hex !== undefined) {
        if (artifacts.hex === undefined)
            throw new Error("Nucleus build omitted requested HEX");
        outputs.push({ path: paths.hex, contents: artifacts.hex });
    }
    let previousD8 = [];
    if (paths.d8 !== undefined) {
        if (artifacts.d8 === undefined)
            throw new Error("Nucleus build omitted requested D8");
        outputs.push(...nucleusD8ArtifactOutputs(paths.d8, artifacts.d8));
        previousD8 = await existingNucleusD8OutputPaths(paths.d8);
    }
    return await publishNucleusArtifactSet(outputs, previousD8);
};
