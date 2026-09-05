#!/usr/bin/env node
import { readSync, writeSync } from "node:fs";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { NucleusConfigurationError, parseNucleusTargetProfile, } from "./configuration.js";
import { formatNucleusDiagnostic } from "./diagnostics.js";
import { createNucleusCompiler } from "./host.js";
import { prepareNucleusProject } from "./project-host.js";
import { publishNucleusBuildOutputs, } from "./publication.js";
import { resolveNucleusImports } from "./source-imports.js";
import { runNucleusNobj } from "./runner.js";
const PACKAGE_VERSION = JSON.parse(await readFile(new URL("../package.json", import.meta.url), "utf8")).version;
const help = `Nucleus ${PACKAGE_VERSION}

Usage:
  nucleus build [options] <source.nu> [more.nu ...]
  nucleus build --project <nucleus-project.json>
  nucleus run [options] <program.nobj>
  nucleus target validate [--json] <target.json>
  nucleus capabilities [--json]

Build options:
  -o, --output <path>             NOBJ output path
      --hex-output <path>         flat Intel HEX output path
      --d8-output <path>          D8 source-map output path
      --target-profile <path>     target profile JSON
      --project <path>            versioned project JSON
      --root <path>               root for source identities
      --host-transport <kind>     mon3 or direct proof transport (default: mon3)
      --diagnostic-format <kind>  text or json
      --json                      alias for --diagnostic-format json
      --quiet                     suppress successful output messages
  -h, --help                      show help
      --version                   show the package version
`;
const runHelp = `Run options:
      --target-profile <path>     deployment profile (default: Node profile)
      --input <path>              read standard input from a file
      --max-instructions <count>  execution limit (default: 5000000)
      --max-cycles <count>        T-state limit (default: 50000000)
  -h, --help                      show this help
`;
class CliUsageError extends Error {
}
const valueAfter = (args, option) => {
    const value = args.shift();
    if (value === undefined)
        throw new CliUsageError(`${option} requires a value`);
    return value;
};
const parseBuildArguments = (args) => {
    const parsed = {
        diagnosticFormat: "text",
        quiet: false,
        sources: [],
    };
    while (args.length > 0) {
        const argument = args.shift();
        if (argument === "-o" || argument === "--output") {
            parsed.output = valueAfter(args, argument);
        }
        else if (argument === "--hex-output") {
            parsed.hexOutput = valueAfter(args, argument);
        }
        else if (argument === "--d8-output") {
            parsed.d8Output = valueAfter(args, argument);
        }
        else if (argument === "--target-profile") {
            parsed.targetProfile = valueAfter(args, argument);
        }
        else if (argument === "--project") {
            parsed.project = valueAfter(args, argument);
        }
        else if (argument === "--root") {
            parsed.root = valueAfter(args, argument);
        }
        else if (argument === "--host-transport") {
            const transport = valueAfter(args, argument);
            if (transport !== "direct" && transport !== "mon3") {
                throw new CliUsageError("--host-transport must be direct or mon3");
            }
            parsed.hostTransport = transport;
        }
        else if (argument === "--diagnostic-format") {
            const format = valueAfter(args, argument);
            if (format !== "text" && format !== "json") {
                throw new CliUsageError("--diagnostic-format must be text or json");
            }
            parsed.diagnosticFormat = format;
        }
        else if (argument === "--json") {
            parsed.diagnosticFormat = "json";
        }
        else if (argument === "--quiet") {
            parsed.quiet = true;
        }
        else if (argument === "--no-color") {
            // Output is currently uncoloured; accept the stable switch for hosts.
        }
        else if (argument === "-h" || argument === "--help") {
            console.log(help);
            process.exit(0);
        }
        else if (argument?.startsWith("-") === true) {
            throw new CliUsageError(`unknown option ${argument}`);
        }
        else if (argument !== undefined) {
            parsed.sources.push(argument);
        }
    }
    return parsed;
};
const sourceIdentity = (root, sourcePath) => {
    const relative = path.relative(root, sourcePath);
    if (relative === "" ||
        relative === ".." ||
        relative.startsWith(`..${path.sep}`) ||
        path.isAbsolute(relative)) {
        throw new NucleusConfigurationError("Source lies outside the project root", [{ path: sourcePath, message: `is outside ${root}` }]);
    }
    return relative.split(path.sep).join("/");
};
const serializableFailure = (failure) => {
    if (failure.kind === "execution") {
        return { success: false, kind: failure.kind, message: failure.message };
    }
    return failure;
};
const reportFailure = (failure, format) => {
    if (format === "json") {
        console.error(JSON.stringify(serializableFailure(failure)));
        return;
    }
    if (failure.kind === "source") {
        console.error(formatNucleusDiagnostic(failure.diagnostic));
    }
    else if (failure.kind === "configuration") {
        console.error(failure.message);
        for (const issue of failure.issues)
            console.error(`  ${issue.path}: ${issue.message}`);
    }
    else {
        console.error(`Nucleus compiler execution failed: ${failure.message}`);
    }
};
const build = async (args) => {
    const parsed = parseBuildArguments(args);
    if (parsed.project !== undefined && parsed.sources.length > 0) {
        throw new CliUsageError("--project cannot be combined with positional sources");
    }
    if (parsed.project !== undefined &&
        [
            parsed.output,
            parsed.hexOutput,
            parsed.d8Output,
            parsed.targetProfile,
            parsed.root,
        ].some((value) => value !== undefined)) {
        throw new CliUsageError("--project contains its own root, target and output paths");
    }
    let root;
    let sources;
    let target;
    let targetProfilePath;
    let outputPaths;
    if (parsed.project !== undefined) {
        const prepared = await prepareNucleusProject(parsed.project);
        root = prepared.root;
        sources = prepared.sources;
        target = prepared.target;
        targetProfilePath = prepared.targetProfilePath;
        outputPaths = prepared.outputs;
    }
    else {
        if (parsed.sources.length === 0)
            throw new CliUsageError("build requires a source file");
        root = path.resolve(parsed.root ?? process.cwd());
        targetProfilePath =
            parsed.targetProfile === undefined
                ? undefined
                : path.resolve(root, parsed.targetProfile);
        const defaultOutput = `${parsed.sources[0]?.replace(/\.nu$/i, "") ?? "program"}.nobj`;
        outputPaths = {
            nobj: path.resolve(parsed.output ?? defaultOutput),
            ...(parsed.hexOutput === undefined
                ? {}
                : { hex: path.resolve(parsed.hexOutput) }),
            ...(parsed.d8Output === undefined
                ? {}
                : { d8: path.resolve(parsed.d8Output) }),
        };
        if (parsed.sources.length === 1) {
            sources = await resolveNucleusImports({
                root,
                entry: parsed.sources[0],
            });
        }
        else {
            const sourcePaths = parsed.sources.map((name) => path.resolve(root, name));
            sources = await Promise.all(sourcePaths.map(async (sourcePath) => ({
                name: sourceIdentity(root, sourcePath),
                source: await readFile(sourcePath),
            })));
        }
        target =
            targetProfilePath === undefined
                ? undefined
                : parseNucleusTargetProfile(await readFile(targetProfilePath, "utf8"), {
                    requireServices: outputPaths.hex !== undefined,
                    sourcePartCount: sources.length,
                });
    }
    if (outputPaths.hex !== undefined && targetProfilePath === undefined) {
        throw new NucleusConfigurationError("Intel HEX output requires a target profile", [
            {
                path: "$.target",
                message: "supply --target-profile or a project target",
            },
        ]);
    }
    const compiler = createNucleusCompiler();
    const result = await compiler.build({
        sources,
        ...(target === undefined ? {} : { target }),
        ...(parsed.hostTransport === undefined
            ? {}
            : { hostTransport: parsed.hostTransport }),
        artifacts: {
            hex: outputPaths.hex !== undefined,
            d8: outputPaths.d8 !== undefined,
        },
    });
    if (!result.success) {
        reportFailure(result, parsed.diagnosticFormat);
        return result.kind === "source" ? 1 : 2;
    }
    const published = await publishNucleusBuildOutputs(outputPaths, result.artifacts);
    if (parsed.diagnosticFormat === "json") {
        console.log(JSON.stringify({
            success: true,
            outputs: published,
            instructions: result.instructions,
            cycles: result.cycles,
        }));
    }
    else if (!parsed.quiet) {
        for (const output of published)
            console.log(`Wrote ${output}`);
    }
    return 0;
};
const positiveInteger = (text, option) => {
    const value = Number(text);
    if (!Number.isSafeInteger(value) || value <= 0) {
        throw new CliUsageError(`${option} must be a positive integer`);
    }
    return value;
};
const parseRunArguments = (args) => {
    const parsed = {};
    while (args.length > 0) {
        const argument = args.shift();
        if (argument === "--target-profile") {
            parsed.targetProfile = valueAfter(args, argument);
        }
        else if (argument === "--input") {
            parsed.input = valueAfter(args, argument);
        }
        else if (argument === "--max-instructions") {
            parsed.maxInstructions = positiveInteger(valueAfter(args, argument), argument);
        }
        else if (argument === "--max-cycles") {
            parsed.maxCycles = positiveInteger(valueAfter(args, argument), argument);
        }
        else if (argument === "-h" || argument === "--help") {
            console.log(runHelp);
            parsed.help = true;
            return parsed;
        }
        else if (argument?.startsWith("-") === true) {
            throw new CliUsageError(`unknown option ${argument}`);
        }
        else if (argument !== undefined && parsed.object === undefined) {
            parsed.object = argument;
        }
        else {
            throw new CliUsageError("run accepts one NOBJ file");
        }
    }
    return parsed;
};
const run = async (args) => {
    const parsed = parseRunArguments(args);
    if (parsed.object === undefined) {
        if (parsed.help === true)
            return 0;
        throw new CliUsageError("run requires one NOBJ file");
    }
    const object = await readFile(parsed.object);
    const target = parsed.targetProfile === undefined
        ? {}
        : parseNucleusTargetProfile(await readFile(parsed.targetProfile, "utf8"), { requireServices: true });
    const fileInput = parsed.input === undefined ? undefined : await readFile(parsed.input);
    const stdinByte = new Uint8Array(1);
    const result = runNucleusNobj(object, target, {
        ...(fileInput === undefined ? {} : { input: fileInput }),
        ...(fileInput !== undefined
            ? {}
            : {
                readInput: () => {
                    const count = readSync(process.stdin.fd, stdinByte, 0, 1, null);
                    return count === 1 ? stdinByte[0] : undefined;
                },
            }),
        writeOutput: (value) => {
            writeSync(process.stdout.fd, Uint8Array.of(value));
        },
        ...(parsed.maxInstructions === undefined
            ? {}
            : { maxInstructions: parsed.maxInstructions }),
        ...(parsed.maxCycles === undefined
            ? {}
            : { maxCycles: parsed.maxCycles }),
    });
    switch (result.outcome) {
        case "success":
            return 0;
        case "unhandledFailure":
        case "trap":
            console.error(`Nucleus program ${result.outcome}: reason ${result.trapReason}, error ${result.errorCode}, source offset ${result.trapOffset}`);
            return 1;
        case "loaderFailure":
            console.error(`NOBJ load failed: outcome ${result.loaderOutcome}, status ${result.status}, record ${result.recordOrdinal}`);
            return 2;
        case "executionLimit":
            console.error(`Nucleus ${result.phase} execution limit reached at $${result.programCounter.toString(16).padStart(4, "0")}`);
            return 2;
    }
};
const target = async (args) => {
    if (args.shift() !== "validate")
        throw new CliUsageError("expected target validate");
    const json = args[0] === "--json" ? (args.shift(), true) : false;
    const profilePath = args.shift();
    if (profilePath === undefined || args.length > 0) {
        throw new CliUsageError("target validate requires one target profile");
    }
    parseNucleusTargetProfile(await readFile(profilePath, "utf8"), {
        requireServices: true,
    });
    if (json)
        console.log(JSON.stringify({ valid: true, path: path.resolve(profilePath) }));
    else
        console.log(`Valid Nucleus target profile: ${path.resolve(profilePath)}`);
    return 0;
};
const main = async (args) => {
    if (args.length === 0 || args[0] === "-h" || args[0] === "--help") {
        console.log(help);
        return 0;
    }
    if (args[0] === "--version") {
        console.log(PACKAGE_VERSION);
        return 0;
    }
    const command = args.shift();
    if (command === "build")
        return await build(args);
    if (command === "run")
        return await run(args);
    if (command === "target")
        return await target(args);
    if (command === "capabilities") {
        const json = args[0] === "--json" ? (args.shift(), true) : false;
        if (args.length > 0)
            throw new CliUsageError("capabilities accepts only --json");
        const info = await createNucleusCompiler().info();
        console.log(json ? JSON.stringify(info) : JSON.stringify(info, null, 2));
        return 0;
    }
    throw new CliUsageError(`unknown command ${command ?? ""}`);
};
const requestedDiagnosticFormat = (args) => {
    for (let index = 0; index < args.length; index += 1) {
        if (args[index] === "--json")
            return "json";
        if (args[index] === "--diagnostic-format" && args[index + 1] === "json") {
            return "json";
        }
    }
    return "text";
};
const commandLine = process.argv.slice(2);
const topLevelFormat = requestedDiagnosticFormat(commandLine);
try {
    process.exitCode = await main(commandLine);
}
catch (error) {
    if (topLevelFormat === "json") {
        if (error instanceof CliUsageError) {
            console.error(JSON.stringify({
                success: false,
                kind: "usage",
                message: error.message,
            }));
        }
        else if (error instanceof NucleusConfigurationError) {
            console.error(JSON.stringify({
                success: false,
                kind: "configuration",
                message: error.message,
                issues: error.issues,
            }));
        }
        else {
            console.error(JSON.stringify({
                success: false,
                kind: "execution",
                message: error instanceof Error ? error.message : String(error),
            }));
        }
        process.exitCode = 2;
    }
    else if (error instanceof CliUsageError) {
        console.error(error.message);
        console.error("Run nucleus --help for usage.");
        process.exitCode = 2;
    }
    else if (error instanceof NucleusConfigurationError) {
        console.error(error.message);
        for (const issue of error.issues)
            console.error(`  ${issue.path}: ${issue.message}`);
        process.exitCode = 2;
    }
    else {
        console.error(error instanceof Error ? error.message : String(error));
        process.exitCode = 2;
    }
}
