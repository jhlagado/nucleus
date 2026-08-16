import { createHash } from "node:crypto";
import { readFile, realpath } from "node:fs/promises";
import path from "node:path";

import type { NucleusSourcePart } from "./compiler.js";
import { nucleusCompilerCapacities } from "./compiler.js";
import { NucleusConfigurationError } from "./configuration.js";
import {
  isNucleusSourceIdentity,
  NUCLEUS_SOURCE_IDENTITY_REQUIREMENT,
} from "./source-identity.js";

const importLine = /^[\t ]*\/\/%[\t ]+import[\t ]+"([^"\r\n]+)"[\t ]*$/;
const directiveLine = /^[\t ]*\/\/%/;

const configurationFailure = (
  message: string,
  issuePath: string,
  issueMessage: string,
): NucleusConfigurationError =>
  new NucleusConfigurationError(message, [
    { path: issuePath, message: issueMessage },
  ]);

const validateImportPath = (
  sourceName: string,
  line: number,
  imported: string,
): void => {
  if (
    imported.length === 0 ||
    imported.includes("\\") ||
    path.posix.isAbsolute(imported) ||
    [...imported].some((character) => {
      const code = character.charCodeAt(0);
      return code < 0x20 || code > 0x7e;
    })
  ) {
    throw configurationFailure(
      "Invalid Nucleus import header",
      `${sourceName}:${line}`,
      "import path must be a nonempty relative path using '/' separators",
    );
  }
};

export const parseNucleusImportHeader = (
  sourceName: string,
  source: Uint8Array,
): readonly string[] => {
  const text = Buffer.from(source).toString("latin1");
  const lines = text.split("\n");
  const imports: string[] = [];
  let inHeader = true;

  for (let index = 0; index < lines.length; index += 1) {
    const lineNumber = index + 1;
    const line =
      index < lines.length - 1 && lines[index]?.endsWith("\r")
        ? lines[index]!.slice(0, -1)
        : lines[index]!;
    const horizontallyTrimmed = line.replace(/^[\t ]*/, "");

    if (!inHeader) {
      if (directiveLine.test(line)) {
        throw configurationFailure(
          "Invalid Nucleus import header",
          `${sourceName}:${lineNumber}`,
          "import directives must appear in the leading header",
        );
      }
      continue;
    }

    if (/^[\t ]*$/.test(line)) continue;
    if (directiveLine.test(line)) {
      const match = importLine.exec(line);
      if (match === null) {
        throw configurationFailure(
          "Invalid Nucleus import header",
          `${sourceName}:${lineNumber}`,
          'expected //% import "relative/path.nu"',
        );
      }
      const imported = match[1]!;
      validateImportPath(sourceName, lineNumber, imported);
      imports.push(imported);
      continue;
    }
    if (horizontallyTrimmed.startsWith("//")) continue;
    inHeader = false;
  }

  return imports;
};

export interface ResolveNucleusImportsOptions {
  readonly root: string;
  readonly entry: string;
}

export interface NucleusSourceDependency {
  readonly name: string;
  readonly imports: readonly string[];
  readonly byteLength: number;
  readonly sha256: string;
}

export interface NucleusResolvedImportGraph {
  readonly entry: string;
  readonly sources: readonly NucleusSourcePart[];
  readonly dependencies: readonly NucleusSourceDependency[];
}

const within = (root: string, candidate: string): boolean => {
  const relative = path.relative(root, candidate);
  return (
    relative === "" ||
    (relative !== ".." &&
      !relative.startsWith(`..${path.sep}`) &&
      !path.isAbsolute(relative))
  );
};

const logicalName = (root: string, candidate: string): string =>
  path.relative(root, candidate).split(path.sep).join("/");

export const resolveNucleusImportGraph = async (
  options: ResolveNucleusImportsOptions,
): Promise<NucleusResolvedImportGraph> => {
  const root = path.resolve(options.root);
  let physicalRoot: string;
  try {
    physicalRoot = await realpath(root);
  } catch (error) {
    throw configurationFailure(
      "Nucleus source discovery failed",
      "$.root",
      error instanceof Error ? error.message : String(error),
    );
  }

  const state = new Map<string, "visiting" | "done">();
  const logicalByPhysical = new Map<string, string>();
  const stack: { physical: string; logical: string }[] = [];
  const ordered: NucleusSourcePart[] = [];
  const dependencies: NucleusSourceDependency[] = [];

  const visit = async (requestedPath: string): Promise<void> => {
    const requested = path.resolve(requestedPath);
    const requestedLogical = logicalName(root, requested);
    if (!within(root, requested)) {
      throw configurationFailure(
        "Nucleus source discovery failed",
        requestedLogical,
        "source lies outside the project root",
      );
    }
    if (!isNucleusSourceIdentity(requestedLogical)) {
      throw configurationFailure(
        "Nucleus source discovery failed",
        requestedLogical,
        `source identity ${NUCLEUS_SOURCE_IDENTITY_REQUIREMENT}`,
      );
    }

    let physical: string;
    try {
      physical = await realpath(requested);
    } catch (error) {
      throw configurationFailure(
        "Nucleus source discovery failed",
        requestedLogical,
        error instanceof Error ? error.message : String(error),
      );
    }
    if (!within(physicalRoot, physical)) {
      throw configurationFailure(
        "Nucleus source discovery failed",
        requestedLogical,
        "source resolves outside the project root",
      );
    }

    const previousLogical = logicalByPhysical.get(physical);
    if (previousLogical !== undefined && previousLogical !== requestedLogical) {
      throw configurationFailure(
        "Nucleus source discovery failed",
        requestedLogical,
        `${requestedLogical} and ${previousLogical} resolve to the same physical source`,
      );
    }
    logicalByPhysical.set(physical, requestedLogical);

    if (state.get(physical) === "done") return;
    if (state.get(physical) === "visiting") {
      const cycleStart = stack.findIndex((part) => part.physical === physical);
      const cycle = [
        ...stack.slice(cycleStart).map((part) => part.logical),
        requestedLogical,
      ];
      throw configurationFailure(
        "Nucleus source discovery failed",
        requestedLogical,
        `import cycle: ${cycle.join(" -> ")}`,
      );
    }

    let source: Uint8Array;
    try {
      source = await readFile(physical);
    } catch (error) {
      throw configurationFailure(
        "Nucleus source discovery failed",
        requestedLogical,
        error instanceof Error ? error.message : String(error),
      );
    }

    state.set(physical, "visiting");
    stack.push({ physical, logical: requestedLogical });
    const imports = parseNucleusImportHeader(requestedLogical, source);
    const importedPaths = imports.map((imported) =>
      path.resolve(path.dirname(requested), imported),
    );
    for (const importedPath of importedPaths) {
      await visit(importedPath);
    }
    stack.pop();
    state.set(physical, "done");
    ordered.push({ name: requestedLogical, source });
    dependencies.push({
      name: requestedLogical,
      imports: [
        ...new Set(
          importedPaths.map((importedPath) => logicalName(root, importedPath)),
        ),
      ],
      byteLength: source.length,
      sha256: createHash("sha256").update(source).digest("hex"),
    });
  };

  const entryPath = path.resolve(root, options.entry);
  await visit(entryPath);

  if (ordered.length > nucleusCompilerCapacities.sourceParts) {
    throw configurationFailure(
      "Nucleus source discovery failed",
      "$.entry",
      `dependency graph contains ${ordered.length} source parts; capacity is ${nucleusCompilerCapacities.sourceParts}`,
    );
  }
  const sourceBytes = ordered.reduce(
    (total, part) => total + (part.source as Uint8Array).length,
    0,
  );
  const windowBytes =
    sourceBytes +
    ordered.length * nucleusCompilerCapacities.sourceDescriptorBytesPerPart;
  if (windowBytes > nucleusCompilerCapacities.sourceWindowBytes) {
    throw configurationFailure(
      "Nucleus source discovery failed",
      "$.entry",
      `resolved sources require ${windowBytes} bytes in the ${nucleusCompilerCapacities.sourceWindowBytes}-byte host source window`,
    );
  }

  return {
    entry: logicalName(root, entryPath),
    sources: ordered,
    dependencies,
  };
};

export const resolveNucleusImports = async (
  options: ResolveNucleusImportsOptions,
): Promise<readonly NucleusSourcePart[]> =>
  (await resolveNucleusImportGraph(options)).sources;
