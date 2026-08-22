import { createHash } from "node:crypto";
import { readFile, realpath } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";
import { nucleusCompilerCapacities, } from "./compiler.js";
import { NucleusConfigurationError } from "./configuration.js";
import { isNucleusSourceIdentity, NUCLEUS_SOURCE_IDENTITY_REQUIREMENT, } from "./source-identity.js";
const importLine = /^[\t ]*\/\/%[\t ]+import[\t ]+"([^"\r\n]+)"[\t ]*$/;
const directiveLine = /^[\t ]*\/\/%/;
export const nucleusStandardLibraryRoot = fileURLToPath(new URL("../library/", import.meta.url));
const configurationFailure = (message, issuePath, issueMessage) => new NucleusConfigurationError(message, [
    { path: issuePath, message: issueMessage },
]);
const validateImportPath = (sourceName, line, imported) => {
    if (imported.length === 0 ||
        imported.includes("\\") ||
        path.posix.isAbsolute(imported) ||
        [...imported].some((character) => {
            const code = character.charCodeAt(0);
            return code < 0x20 || code > 0x7e;
        })) {
        throw configurationFailure("Invalid Nucleus import header", `${sourceName}:${line}`, "import path must be a nonempty relative path using '/' separators");
    }
};
export const parseNucleusImportHeader = (sourceName, source) => {
    const lines = Buffer.from(source).toString("latin1").split("\n");
    const imports = [];
    let inHeader = true;
    for (let index = 0; index < lines.length; index += 1) {
        const lineNumber = index + 1;
        const rawLine = lines[index];
        const line = index < lines.length - 1 && rawLine.endsWith("\r")
            ? rawLine.slice(0, -1)
            : rawLine;
        if (!inHeader) {
            if (directiveLine.test(line)) {
                throw configurationFailure("Invalid Nucleus import header", `${sourceName}:${lineNumber}`, "import directives must appear in the leading header");
            }
            continue;
        }
        if (/^[\t ]*$/.test(line))
            continue;
        if (directiveLine.test(line)) {
            const match = importLine.exec(line);
            if (match === null) {
                throw configurationFailure("Invalid Nucleus import header", `${sourceName}:${lineNumber}`, 'expected //% import "relative/path.nu"');
            }
            const imported = match[1];
            validateImportPath(sourceName, lineNumber, imported);
            imports.push(imported);
            continue;
        }
        if (line.replace(/^[\t ]*/, "").startsWith("//"))
            continue;
        inHeader = false;
    }
    return imports;
};
const within = (root, candidate) => {
    const relative = path.relative(root, candidate);
    return (relative === "" ||
        (relative !== ".." &&
            !relative.startsWith(`..${path.sep}`) &&
            !path.isAbsolute(relative)));
};
const logicalName = (domain, candidate) => `${domain.prefix}${path.relative(domain.root, candidate).split(path.sep).join("/")}`;
const canonicalRoot = async (requestedRoot, issuePath) => {
    try {
        return await realpath(requestedRoot);
    }
    catch (error) {
        throw configurationFailure("Nucleus source discovery failed", issuePath, error instanceof Error ? error.message : String(error));
    }
};
const errorCode = (error) => typeof error === "object" && error !== null && "code" in error
    ? error.code
    : undefined;
export const resolveNucleusImportGraph = async (options) => {
    const projectRoot = path.resolve(options.root);
    const standardRoot = path.resolve(options.standardLibraryRoot ?? nucleusStandardLibraryRoot);
    const projectDomain = {
        root: projectRoot,
        physicalRoot: await canonicalRoot(projectRoot, "$.root"),
        prefix: "",
    };
    const standardDomain = {
        root: standardRoot,
        physicalRoot: await canonicalRoot(standardRoot, "$.standardLibraryRoot"),
        prefix: "@nucleus/",
    };
    const state = new Map();
    const logicalByPhysical = new Map();
    const stack = [];
    const ordered = [];
    const dependencies = [];
    const visit = async (requestedPath, domain) => {
        const requested = path.resolve(requestedPath);
        const requestedLogical = logicalName(domain, requested);
        if (!within(domain.root, requested)) {
            throw configurationFailure("Nucleus source discovery failed", requestedLogical, "source lies outside its configured source root");
        }
        if (!isNucleusSourceIdentity(requestedLogical)) {
            throw configurationFailure("Nucleus source discovery failed", requestedLogical, `source identity ${NUCLEUS_SOURCE_IDENTITY_REQUIREMENT}`);
        }
        let physical;
        try {
            physical = await realpath(requested);
        }
        catch (error) {
            throw configurationFailure("Nucleus source discovery failed", requestedLogical, error instanceof Error ? error.message : String(error));
        }
        if (!within(domain.physicalRoot, physical)) {
            throw configurationFailure("Nucleus source discovery failed", requestedLogical, "source resolves outside its configured source root");
        }
        const previousLogical = logicalByPhysical.get(physical);
        if (previousLogical !== undefined && previousLogical !== requestedLogical) {
            throw configurationFailure("Nucleus source discovery failed", requestedLogical, `${requestedLogical} and ${previousLogical} resolve to the same physical source`);
        }
        logicalByPhysical.set(physical, requestedLogical);
        if (state.get(physical) === "done")
            return requestedLogical;
        if (state.get(physical) === "visiting") {
            const cycleStart = stack.findIndex((part) => part.physical === physical);
            const cycle = [
                ...stack.slice(cycleStart).map((part) => part.logical),
                requestedLogical,
            ];
            throw configurationFailure("Nucleus source discovery failed", requestedLogical, `import cycle: ${cycle.join(" -> ")}`);
        }
        let source;
        try {
            source = await readFile(physical);
        }
        catch (error) {
            throw configurationFailure("Nucleus source discovery failed", requestedLogical, error instanceof Error ? error.message : String(error));
        }
        if (source.length > nucleusCompilerCapacities.sourcePartBytes) {
            throw configurationFailure("Nucleus source discovery failed", requestedLogical, `source contains ${source.length} bytes; capacity is ${nucleusCompilerCapacities.sourcePartBytes}`);
        }
        state.set(physical, "visiting");
        stack.push({ physical, logical: requestedLogical });
        const importNames = [];
        for (const imported of parseNucleusImportHeader(requestedLogical, source)) {
            const local = path.resolve(path.dirname(requested), imported);
            if (!within(domain.root, local)) {
                throw configurationFailure("Nucleus source discovery failed", logicalName(domain, local), "source lies outside its configured source root");
            }
            try {
                await realpath(local);
                importNames.push(await visit(local, domain));
                continue;
            }
            catch (error) {
                if (error instanceof NucleusConfigurationError)
                    throw error;
                if (errorCode(error) !== "ENOENT" && errorCode(error) !== "ENOTDIR") {
                    throw configurationFailure("Nucleus source discovery failed", logicalName(domain, local), error instanceof Error ? error.message : String(error));
                }
            }
            const standard = path.resolve(standardDomain.root, imported);
            importNames.push(await visit(standard, standardDomain));
        }
        stack.pop();
        state.set(physical, "done");
        ordered.push({ name: requestedLogical, source });
        dependencies.push({
            name: requestedLogical,
            imports: [...new Set(importNames)],
            byteLength: source.length,
            sha256: createHash("sha256").update(source).digest("hex"),
        });
        return requestedLogical;
    };
    const entryPath = path.resolve(projectDomain.root, options.entry);
    const entry = await visit(entryPath, projectDomain);
    if (ordered.length > nucleusCompilerCapacities.sourceParts) {
        throw configurationFailure("Nucleus source discovery failed", "$.entry", `dependency graph contains ${ordered.length} source parts; capacity is ${nucleusCompilerCapacities.sourceParts}`);
    }
    return { entry, sources: ordered, dependencies };
};
export const resolveNucleusImports = async (options) => (await resolveNucleusImportGraph(options)).sources;
