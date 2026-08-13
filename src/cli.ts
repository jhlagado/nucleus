#!/usr/bin/env node

import { readFile } from "node:fs/promises";
import path from "node:path";

import {
  NucleusConfigurationError,
  parseNucleusTargetProfile,
} from "./configuration.js";
import { formatNucleusDiagnostic } from "./diagnostics.js";
import { createNucleusCompiler, type NucleusBuildFailure } from "./host.js";
import { parseNucleusProject } from "./project.js";
import {
  publishNucleusBuildOutputs,
  type NucleusBuildOutputPaths,
} from "./publication.js";

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

class CliUsageError extends Error {}

interface BuildCliArguments {
  output?: string;
  hexOutput?: string;
  d8Output?: string;
  targetProfile?: string;
  project?: string;
  root?: string;
  diagnosticFormat: "text" | "json";
  quiet: boolean;
  sources: string[];
}

const valueAfter = (args: string[], option: string): string => {
  const value = args.shift();
  if (value === undefined)
    throw new CliUsageError(`${option} requires a value`);
  return value;
};

const parseBuildArguments = (args: string[]): BuildCliArguments => {
  const parsed: BuildCliArguments = {
    diagnosticFormat: "text",
    quiet: false,
    sources: [],
  };
  while (args.length > 0) {
    const argument = args.shift();
    if (argument === "-o" || argument === "--output") {
      parsed.output = valueAfter(args, argument);
    } else if (argument === "--hex-output") {
      parsed.hexOutput = valueAfter(args, argument);
    } else if (argument === "--d8-output") {
      parsed.d8Output = valueAfter(args, argument);
    } else if (argument === "--target-profile") {
      parsed.targetProfile = valueAfter(args, argument);
    } else if (argument === "--project") {
      parsed.project = valueAfter(args, argument);
    } else if (argument === "--root") {
      parsed.root = valueAfter(args, argument);
    } else if (argument === "--diagnostic-format") {
      const format = valueAfter(args, argument);
      if (format !== "text" && format !== "json") {
        throw new CliUsageError("--diagnostic-format must be text or json");
      }
      parsed.diagnosticFormat = format;
    } else if (argument === "--json") {
      parsed.diagnosticFormat = "json";
    } else if (argument === "--quiet") {
      parsed.quiet = true;
    } else if (argument === "--no-color") {
      // Output is currently uncoloured; accept the stable switch for hosts.
    } else if (argument === "-h" || argument === "--help") {
      console.log(help);
      process.exit(0);
    } else if (argument?.startsWith("-") === true) {
      throw new CliUsageError(`unknown option ${argument}`);
    } else if (argument !== undefined) {
      parsed.sources.push(argument);
    }
  }
  return parsed;
};

const sourceIdentity = (root: string, sourcePath: string): string => {
  const relative = path.relative(root, sourcePath);
  if (
    relative === "" ||
    relative === ".." ||
    relative.startsWith(`..${path.sep}`) ||
    path.isAbsolute(relative)
  ) {
    throw new NucleusConfigurationError(
      "Source lies outside the project root",
      [{ path: sourcePath, message: `is outside ${root}` }],
    );
  }
  return relative.split(path.sep).join("/");
};

const serializableFailure = (failure: NucleusBuildFailure): object => {
  if (failure.kind === "execution") {
    return { success: false, kind: failure.kind, message: failure.message };
  }
  return failure;
};

const reportFailure = (
  failure: NucleusBuildFailure,
  format: "text" | "json",
): void => {
  if (format === "json") {
    console.error(JSON.stringify(serializableFailure(failure)));
    return;
  }
  if (failure.kind === "source") {
    console.error(formatNucleusDiagnostic(failure.diagnostic));
  } else if (failure.kind === "configuration") {
    console.error(failure.message);
    for (const issue of failure.issues)
      console.error(`  ${issue.path}: ${issue.message}`);
  } else {
    console.error(`Nucleus compiler execution failed: ${failure.message}`);
  }
};

const build = async (args: string[]): Promise<number> => {
  const parsed = parseBuildArguments(args);
  if (parsed.project !== undefined && parsed.sources.length > 0) {
    throw new CliUsageError(
      "--project cannot be combined with positional sources",
    );
  }
  if (
    parsed.project !== undefined &&
    [
      parsed.output,
      parsed.hexOutput,
      parsed.d8Output,
      parsed.targetProfile,
      parsed.root,
    ].some((value) => value !== undefined)
  ) {
    throw new CliUsageError(
      "--project contains its own root, target and output paths",
    );
  }

  let root: string;
  let sourceNames: readonly string[];
  let targetProfilePath: string | undefined;
  let outputPaths: NucleusBuildOutputPaths;
  if (parsed.project !== undefined) {
    const projectPath = path.resolve(parsed.project);
    const project = parseNucleusProject(await readFile(projectPath, "utf8"));
    root = path.resolve(path.dirname(projectPath), project.root ?? ".");
    sourceNames = project.sources;
    targetProfilePath = path.resolve(root, project.target);
    outputPaths = {
      nobj: path.resolve(root, project.outputs.nobj),
      ...(project.outputs.hex === undefined
        ? {}
        : { hex: path.resolve(root, project.outputs.hex) }),
      ...(project.outputs.d8 === undefined
        ? {}
        : { d8: path.resolve(root, project.outputs.d8) }),
    };
  } else {
    if (parsed.sources.length === 0)
      throw new CliUsageError("build requires a source file");
    root = path.resolve(parsed.root ?? process.cwd());
    sourceNames = parsed.sources;
    targetProfilePath =
      parsed.targetProfile === undefined
        ? undefined
        : path.resolve(parsed.targetProfile);
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
  }

  if (outputPaths.hex !== undefined && targetProfilePath === undefined) {
    throw new NucleusConfigurationError(
      "Intel HEX output requires a target profile",
      [
        {
          path: "$.target",
          message: "supply --target-profile or a project target",
        },
      ],
    );
  }
  const sourcePaths = sourceNames.map((name) => path.resolve(root, name));
  const sources = await Promise.all(
    sourcePaths.map(async (sourcePath) => ({
      name: sourceIdentity(root, sourcePath),
      source: await readFile(sourcePath),
    })),
  );
  const target =
    targetProfilePath === undefined
      ? undefined
      : parseNucleusTargetProfile(await readFile(targetProfilePath, "utf8"), {
          requireServices: outputPaths.hex !== undefined,
          sourcePartCount: sources.length,
        });
  const compiler = createNucleusCompiler();
  const result = await compiler.build({
    sources,
    ...(target === undefined ? {} : { target }),
    artifacts: {
      hex: outputPaths.hex !== undefined,
      d8: outputPaths.d8 !== undefined,
    },
  });
  if (!result.success) {
    reportFailure(result, parsed.diagnosticFormat);
    return result.kind === "source" ? 1 : 2;
  }
  const published = await publishNucleusBuildOutputs(
    outputPaths,
    result.artifacts,
  );
  if (parsed.diagnosticFormat === "json") {
    console.log(
      JSON.stringify({
        success: true,
        outputs: published,
        instructions: result.instructions,
        cycles: result.cycles,
      }),
    );
  } else if (!parsed.quiet) {
    for (const output of published) console.log(`Wrote ${output}`);
  }
  return 0;
};

const target = async (args: string[]): Promise<number> => {
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
    console.log(
      JSON.stringify({ valid: true, path: path.resolve(profilePath) }),
    );
  else
    console.log(`Valid Nucleus target profile: ${path.resolve(profilePath)}`);
  return 0;
};

const main = async (args: string[]): Promise<number> => {
  if (args.length === 0 || args[0] === "-h" || args[0] === "--help") {
    console.log(help);
    return 0;
  }
  if (args[0] === "--version") {
    console.log(PACKAGE_VERSION);
    return 0;
  }
  const command = args.shift();
  if (command === "build") return await build(args);
  if (command === "target") return await target(args);
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

const requestedDiagnosticFormat = (
  args: readonly string[],
): "text" | "json" => {
  for (let index = 0; index < args.length; index += 1) {
    if (args[index] === "--json") return "json";
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
} catch (error) {
  if (topLevelFormat === "json") {
    if (error instanceof CliUsageError) {
      console.error(
        JSON.stringify({
          success: false,
          kind: "usage",
          message: error.message,
        }),
      );
    } else if (error instanceof NucleusConfigurationError) {
      console.error(
        JSON.stringify({
          success: false,
          kind: "configuration",
          message: error.message,
          issues: error.issues,
        }),
      );
    } else {
      console.error(
        JSON.stringify({
          success: false,
          kind: "execution",
          message: error instanceof Error ? error.message : String(error),
        }),
      );
    }
    process.exitCode = 2;
  } else if (error instanceof CliUsageError) {
    console.error(error.message);
    console.error("Run nucleus --help for usage.");
    process.exitCode = 2;
  } else if (error instanceof NucleusConfigurationError) {
    console.error(error.message);
    for (const issue of error.issues)
      console.error(`  ${issue.path}: ${issue.message}`);
    process.exitCode = 2;
  } else {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 2;
  }
}
