import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import path from "node:path";

import type { NucleusSourcePart, NucleusTarget } from "./compiler.js";
import {
  assertNucleusTarget,
  NucleusConfigurationError,
  parseNucleusTargetProfile,
} from "./configuration.js";
import {
  createNucleusCompiler,
  type NucleusBuildArtifactRequest,
  type NucleusBuildResult,
} from "./host.js";
import {
  NUCLEUS_PROJECT_V2_SCHEMA,
  parseNucleusProject,
  type NucleusProject,
} from "./project.js";
import type { NucleusBuildOutputPaths } from "./publication.js";
import {
  resolveNucleusImportGraph,
  type NucleusSourceDependency,
} from "./source-imports.js";
import { serializeNucleusSourcePlan } from "./source-plan.js";

const jsonObject = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value);

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

const dependency = (
  part: NucleusSourcePart,
  imports: readonly string[] = [],
): NucleusSourceDependency => {
  const source =
    typeof part.source === "string"
      ? new TextEncoder().encode(part.source)
      : part.source;
  return {
    name: part.name,
    imports,
    byteLength: source.length,
    sha256: createHash("sha256").update(source).digest("hex"),
  };
};

const outputPaths = (
  root: string,
  project: NucleusProject,
): NucleusBuildOutputPaths => ({
  nobj: path.resolve(root, project.outputs.nobj),
  ...(project.outputs.hex === undefined
    ? {}
    : { hex: path.resolve(root, project.outputs.hex) }),
  ...(project.outputs.d8 === undefined
    ? {}
    : { d8: path.resolve(root, project.outputs.d8) }),
});

const projectTarget = (
  targetText: string,
  project: NucleusProject,
  sources: readonly NucleusSourcePart[],
  entry: string | undefined,
  requireServices: boolean,
): NucleusTarget => {
  if (project.schema !== NUCLEUS_PROJECT_V2_SCHEMA) {
    return parseNucleusTargetProfile(targetText, {
      requireServices,
      sourcePartCount: sources.length,
    });
  }

  let targetValue: unknown;
  try {
    targetValue = JSON.parse(targetText);
  } catch (error) {
    throw new NucleusConfigurationError("Invalid Nucleus target profile JSON", [
      {
        path: "$",
        message: error instanceof Error ? error.message : String(error),
      },
    ]);
  }
  if (!jsonObject(targetValue)) {
    return assertNucleusTarget(targetValue, {
      requireServices,
      sourcePartCount: sources.length,
    });
  }

  const sourceBanks = project.sourceBanks;
  if (!Object.hasOwn(targetValue, "bankCount")) {
    if (Object.keys(sourceBanks ?? {}).length > 0) {
      throw new NucleusConfigurationError("Invalid Nucleus project", [
        {
          path: "$.sourceBanks",
          message: "requires a banked target profile",
        },
      ]);
    }
    return assertNucleusTarget(targetValue, {
      requireServices,
      sourcePartCount: sources.length,
    });
  }
  if (Object.hasOwn(targetValue, "partBanks")) {
    throw new NucleusConfigurationError("Invalid Nucleus project target", [
      {
        path: "$.partBanks",
        message: "project v2 derives partBanks from logical source identities",
      },
    ]);
  }

  const sourceNames = new Set(sources.map((source) => source.name));
  for (const name of Object.keys(sourceBanks ?? {})) {
    if (!sourceNames.has(name)) {
      throw new NucleusConfigurationError("Invalid Nucleus project", [
        {
          path: `$.sourceBanks.${name}`,
          message: "does not identify a discovered source part",
        },
      ]);
    }
  }
  const entryBank =
    typeof targetValue.entryBank === "number" ? targetValue.entryBank : 0;
  const partBanks = sources.map((source) =>
    sourceBanks !== undefined && Object.hasOwn(sourceBanks, source.name)
      ? sourceBanks[source.name]!
      : entryBank,
  );
  const entryIndex = sources.findIndex((source) => source.name === entry);
  if (entryIndex < 0 || partBanks[entryIndex] !== entryBank) {
    throw new NucleusConfigurationError("Invalid Nucleus project", [
      {
        path: `$.sourceBanks.${entry}`,
        message: "entry source must be assigned to entryBank",
      },
    ]);
  }
  return assertNucleusTarget(
    { ...targetValue, partBanks },
    { requireServices, sourcePartCount: sources.length },
  );
};

export interface PrepareNucleusProjectOptions {
  readonly targetProfile?: string;
  readonly requireServices?: boolean;
}

export interface PreparedNucleusProject {
  readonly projectPath: string;
  readonly project: NucleusProject;
  readonly root: string;
  readonly entry?: string;
  readonly sources: readonly NucleusSourcePart[];
  readonly dependencies: readonly NucleusSourceDependency[];
  readonly targetProfilePath: string;
  readonly target: NucleusTarget;
  readonly outputs: NucleusBuildOutputPaths;
  readonly sourcePlan: string;
}

export const prepareNucleusProject = async (
  requestedProjectPath: string,
  options: PrepareNucleusProjectOptions = {},
): Promise<PreparedNucleusProject> => {
  const projectPath = path.resolve(requestedProjectPath);
  const project = parseNucleusProject(await readFile(projectPath, "utf8"));
  const root = path.resolve(path.dirname(projectPath), project.root ?? ".");

  let sources: readonly NucleusSourcePart[];
  let dependencies: readonly NucleusSourceDependency[];
  let entry: string | undefined;
  if (project.schema === NUCLEUS_PROJECT_V2_SCHEMA) {
    const graph = await resolveNucleusImportGraph({
      root,
      entry: project.entry,
    });
    sources = graph.sources;
    dependencies = graph.dependencies;
    entry = graph.entry;
  } else {
    sources = await Promise.all(
      project.sources.map(async (name) => {
        const sourcePath = path.resolve(root, name);
        return {
          name: sourceIdentity(root, sourcePath),
          source: await readFile(sourcePath),
        };
      }),
    );
    dependencies = sources.map((source) => dependency(source));
  }

  const outputs = outputPaths(root, project);
  const targetProfilePath = path.resolve(
    root,
    options.targetProfile ?? project.target,
  );
  const targetText = await readFile(targetProfilePath, "utf8");
  const requireServices = options.requireServices ?? outputs.hex !== undefined;
  const target = projectTarget(
    targetText,
    project,
    sources,
    entry,
    requireServices,
  );
  const partBanks =
    "partBanks" in target ? target.partBanks : sources.map(() => 0);
  const sourcePlan = serializeNucleusSourcePlan(
    sources.map((source, index) => ({
      bank: partBanks[index]!,
      path: source.name,
    })),
  );
  return {
    projectPath,
    project,
    root,
    ...(entry === undefined ? {} : { entry }),
    sources,
    dependencies,
    targetProfilePath,
    target,
    outputs,
    sourcePlan,
  };
};

export interface NucleusProjectCompiler {
  build(request: {
    readonly sources: readonly NucleusSourcePart[];
    readonly target: NucleusTarget;
    readonly artifacts: NucleusBuildArtifactRequest;
    readonly hostTransport?: "direct" | "mon3";
  }): Promise<NucleusBuildResult>;
}

export interface BuildNucleusProjectOptions extends PrepareNucleusProjectOptions {
  readonly artifacts?: NucleusBuildArtifactRequest;
  readonly hostTransport?: "direct" | "mon3";
  readonly compiler?: NucleusProjectCompiler;
}

export interface NucleusProjectBuild {
  readonly prepared: PreparedNucleusProject;
  readonly result: NucleusBuildResult;
}

export const buildNucleusProject = async (
  projectPath: string,
  options: BuildNucleusProjectOptions = {},
): Promise<NucleusProjectBuild> => {
  const requireServices = options.requireServices ?? options.artifacts?.hex;
  const prepared = await prepareNucleusProject(projectPath, {
    ...(options.targetProfile === undefined
      ? {}
      : { targetProfile: options.targetProfile }),
    ...(requireServices === undefined ? {} : { requireServices }),
  });
  const artifacts = options.artifacts ?? {
    hex: prepared.outputs.hex !== undefined,
    d8: prepared.outputs.d8 !== undefined,
  };
  const compiler = options.compiler ?? createNucleusCompiler();
  const result = await compiler.build({
    sources: prepared.sources,
    target: prepared.target,
    artifacts,
    ...(options.hostTransport === undefined
      ? {}
      : { hostTransport: options.hostTransport }),
  });
  return { prepared, result };
};
