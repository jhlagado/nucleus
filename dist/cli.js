#!/usr/bin/env node
import { readFile } from "node:fs/promises";
import path from "node:path";
import { NucleusConfigurationError, parseNucleusTargetProfile, validateNucleusTargetLayoutProfileDocument, } from "./configuration.js";
import { formatNucleusDiagnostic } from "./diagnostics.js";
import { createNucleusCompiler, } from "./host.js";
import { buildNucleusProject } from "./project-host.js";
import { publishNucleusBuildOutputs, } from "./publication.js";
import { resolveNucleusImports } from "./source-imports.js";
const PACKAGE_VERSION = "0.1.0";
const help = `Nucleus ${PACKAGE_VERSION}

Usage:
  nucleus build [options] <source.nu> [more.nu ...]
  nucleus build --project <nucleus-project.json>
  nucleus target validate [--json] <target.json>
  nucleus capabilities [--json]

Build options:
  -o, --output <path>             NOBJ output path
      --hex-output <path>         flat Intel HEX output path
      --d8-output <path>          D8 source-map output path
      --target-profile <path>     target profile JSON
      --project <path>            versioned project JSON
      --root <path>               root for source identities
      --diagnostic-format <kind>  text or json
      --json                      alias for --diagnostic-format json
      --quiet                     suppress successful output messages
  -h, --help                      show help
      --version                   show the package version
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
const publishBuildResult = async (result, outputPaths, parsed) => {
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
    if (parsed.project !== undefined) {
        const built = await buildNucleusProject(path.resolve(parsed.project));
        return await publishBuildResult(built.result, built.prepared.outputs, parsed);
    }
    if (parsed.sources.length === 0)
        throw new CliUsageError("build requires a source file");
    const root = path.resolve(parsed.root ?? process.cwd());
    const sources = parsed.sources.length === 1
        ? await resolveNucleusImports({ root, entry: parsed.sources[0] })
        : await Promise.all(parsed.sources.map(async (name) => {
            const sourcePath = path.resolve(root, name);
            return {
                name: sourceIdentity(root, sourcePath),
                source: await readFile(sourcePath),
            };
        }));
    const targetProfilePath = parsed.targetProfile === undefined
        ? undefined
        : path.resolve(parsed.targetProfile);
    const defaultOutput = `${parsed.sources[0]?.replace(/\.nu$/i, "") ?? "program"}.nobj`;
    const outputPaths = {
        nobj: path.resolve(parsed.output ?? defaultOutput),
        ...(parsed.hexOutput === undefined
            ? {}
            : { hex: path.resolve(parsed.hexOutput) }),
        ...(parsed.d8Output === undefined
            ? {}
            : { d8: path.resolve(parsed.d8Output) }),
    };
    if (outputPaths.hex !== undefined && targetProfilePath === undefined) {
        throw new NucleusConfigurationError("Intel HEX output requires a target profile", [
            {
                path: "$.target",
                message: "supply --target-profile or a project target",
            },
        ]);
    }
    let target;
    if (targetProfilePath !== undefined) {
        const targetText = await readFile(targetProfilePath, "utf8");
        target = parseNucleusTargetProfile(targetText, {
            requireServices: outputPaths.hex !== undefined,
            sourcePartCount: sources.length,
        });
    }
    const compiler = createNucleusCompiler();
    const result = await compiler.build({
        sources,
        ...(target === undefined ? {} : { target }),
        artifacts: {
            hex: outputPaths.hex !== undefined,
            d8: outputPaths.d8 !== undefined,
        },
    });
    return await publishBuildResult(result, outputPaths, parsed);
};
const target = async (args) => {
    if (args.shift() !== "validate")
        throw new CliUsageError("expected target validate");
    const json = args[0] === "--json" ? (args.shift(), true) : false;
    const profilePath = args.shift();
    if (profilePath === undefined || args.length > 0) {
        throw new CliUsageError("target validate requires one target profile");
    }
    validateNucleusTargetLayoutProfileDocument(await readFile(profilePath, "utf8"), {
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
