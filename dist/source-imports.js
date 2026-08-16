import { readFile, realpath } from "node:fs/promises";
import path from "node:path";
import { nucleusCompilerCapacities } from "./compiler.js";
import { NucleusConfigurationError } from "./configuration.js";
import { isNucleusSourceIdentity, NUCLEUS_SOURCE_IDENTITY_REQUIREMENT, } from "./source-identity.js";
const importLine = /^[\t ]*\/\/%[\t ]+import[\t ]+"([^"\r\n]+)"[\t ]*$/;
const directiveLine = /^[\t ]*\/\/%/;
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
    const text = Buffer.from(source).toString("latin1");
    const lines = text.split("\n");
    const imports = [];
    let inHeader = true;
    for (let index = 0; index < lines.length; index += 1) {
        const lineNumber = index + 1;
        const line = index < lines.length - 1 && lines[index]?.endsWith("\r")
            ? lines[index].slice(0, -1)
            : lines[index];
        const horizontallyTrimmed = line.replace(/^[\t ]*/, "");
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
        if (horizontallyTrimmed.startsWith("//"))
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
const logicalName = (root, candidate) => path.relative(root, candidate).split(path.sep).join("/");
export const resolveNucleusImports = async (options) => {
    const root = path.resolve(options.root);
    let physicalRoot;
    try {
        physicalRoot = await realpath(root);
    }
    catch (error) {
        throw configurationFailure("Nucleus source discovery failed", "$.root", error instanceof Error ? error.message : String(error));
    }
    const state = new Map();
    const logicalByPhysical = new Map();
    const stack = [];
    const ordered = [];
    const visit = async (requestedPath) => {
        const requested = path.resolve(requestedPath);
        const requestedLogical = logicalName(root, requested);
        if (!within(root, requested)) {
            throw configurationFailure("Nucleus source discovery failed", requestedLogical, "source lies outside the project root");
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
        if (!within(physicalRoot, physical)) {
            throw configurationFailure("Nucleus source discovery failed", requestedLogical, "source resolves outside the project root");
        }
        const previousLogical = logicalByPhysical.get(physical);
        if (previousLogical !== undefined && previousLogical !== requestedLogical) {
            throw configurationFailure("Nucleus source discovery failed", requestedLogical, `${requestedLogical} and ${previousLogical} resolve to the same physical source`);
        }
        logicalByPhysical.set(physical, requestedLogical);
        if (state.get(physical) === "done")
            return;
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
        state.set(physical, "visiting");
        stack.push({ physical, logical: requestedLogical });
        const imports = parseNucleusImportHeader(requestedLogical, source);
        for (const imported of imports) {
            await visit(path.resolve(path.dirname(requested), imported));
        }
        stack.pop();
        state.set(physical, "done");
        ordered.push({ name: requestedLogical, source });
    };
    await visit(path.resolve(root, options.entry));
    if (ordered.length > nucleusCompilerCapacities.sourceParts) {
        throw configurationFailure("Nucleus source discovery failed", "$.entry", `dependency graph contains ${ordered.length} source parts; capacity is ${nucleusCompilerCapacities.sourceParts}`);
    }
    const sourceBytes = ordered.reduce((total, part) => total + part.source.length, 0);
    const windowBytes = sourceBytes +
        ordered.length * nucleusCompilerCapacities.sourceDescriptorBytesPerPart;
    if (windowBytes > nucleusCompilerCapacities.sourceWindowBytes) {
        throw configurationFailure("Nucleus source discovery failed", "$.entry", `resolved sources require ${windowBytes} bytes in the ${nucleusCompilerCapacities.sourceWindowBytes}-byte host source window`);
    }
    return ordered;
};
