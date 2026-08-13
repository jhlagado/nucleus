import type { NucleusD8DebugMap } from "./d8.js";
import {
  compileNucleus,
  nucleusCompilerCapacities,
  nucleusCompilerInfo,
  type NucleusCompileSuccess,
  type NucleusDiagnostic,
  type NucleusSourcePart,
  type NucleusTarget,
  writeNucleusIntelHex,
} from "./compiler.js";
import {
  validateNucleusTarget,
  type NucleusConfigurationIssue,
} from "./configuration.js";
import { nucleusD8SourceName } from "./d8-internal.js";
import { nucleusDiagnosticMessage } from "./diagnostics.js";
import { sourcePartBytes } from "./d8.js";

export const NUCLEUS_HOST_API_VERSION = 1;

export interface NucleusBuildArtifactRequest {
  readonly hex?: boolean;
  readonly d8?: boolean;
}

export interface NucleusBuildRequest {
  readonly sources: readonly NucleusSourcePart[];
  readonly target?: NucleusTarget;
  readonly artifacts?: NucleusBuildArtifactRequest;
}

export interface NucleusD8Artifact {
  readonly bank: number;
  readonly map: NucleusD8DebugMap;
  readonly json: string;
}

export interface NucleusBuildArtifacts {
  readonly nobj: Uint8Array;
  readonly hex?: string;
  readonly d8?: readonly NucleusD8Artifact[];
}

export interface NucleusBuildSuccess {
  readonly success: true;
  readonly artifacts: NucleusBuildArtifacts;
  readonly materialized: NucleusCompileSuccess["materialized"];
  readonly instructions: number;
  readonly cycles: number;
}

export interface NucleusBuildSourceFailure {
  readonly success: false;
  readonly kind: "source";
  readonly message: string;
  readonly diagnostic: NucleusDiagnostic;
  readonly instructions: number;
  readonly cycles: number;
}

export interface NucleusBuildConfigurationFailure {
  readonly success: false;
  readonly kind: "configuration";
  readonly message: string;
  readonly issues: readonly NucleusConfigurationIssue[];
}

export interface NucleusBuildExecutionFailure {
  readonly success: false;
  readonly kind: "execution";
  readonly message: string;
  readonly cause?: unknown;
}

export type NucleusBuildFailure =
  | NucleusBuildSourceFailure
  | NucleusBuildConfigurationFailure
  | NucleusBuildExecutionFailure;

export type NucleusBuildResult = NucleusBuildSuccess | NucleusBuildFailure;

const configurationFailure = (
  issues: readonly NucleusConfigurationIssue[],
): NucleusBuildConfigurationFailure => ({
  success: false,
  kind: "configuration",
  message: "Invalid Nucleus build configuration",
  issues,
});

export class NucleusCompiler {
  public async info(): Promise<
    Awaited<ReturnType<typeof nucleusCompilerInfo>>
  > {
    return await nucleusCompilerInfo();
  }

  public async build(
    request: NucleusBuildRequest,
  ): Promise<NucleusBuildResult> {
    const target = request.target ?? {};
    const issues: NucleusConfigurationIssue[] = [
      ...validateNucleusTarget(target, {
        requireServices: request.artifacts?.hex === true,
        sourcePartCount: request.sources.length,
      }),
    ];
    if (request.sources.length === 0) {
      issues.push({
        path: "$.sources",
        message: "must contain at least one source part",
      });
    } else if (request.sources.length > nucleusCompilerCapacities.sourceParts) {
      issues.push({
        path: "$.sources",
        message: `must contain at most ${nucleusCompilerCapacities.sourceParts} source parts`,
      });
    }
    let sourceWindowUse = request.sources.length * 5;
    const d8SourceNames = new Map<string, number>();
    request.sources.forEach((part, index) => {
      if (typeof part.name !== "string" || part.name.length === 0) {
        issues.push({
          path: `$.sources[${index}].name`,
          message: "must be a nonempty source identity",
        });
      }
      if (!(
        typeof part.source === "string" || part.source instanceof Uint8Array
      )) {
        issues.push({
          path: `$.sources[${index}].source`,
          message: "must be a string or Uint8Array",
        });
      } else {
        sourceWindowUse += sourcePartBytes(part).length;
      }
      if (
        request.artifacts?.d8 === true &&
        typeof part.name === "string" &&
        part.name.length > 0
      ) {
        const d8Name = nucleusD8SourceName(part.name);
        const previous = d8SourceNames.get(d8Name);
        if (previous === undefined) {
          d8SourceNames.set(d8Name, index);
        } else {
          issues.push({
            path: `$.sources[${index}].name`,
            message: `duplicates the portable D8 source identity of $.sources[${previous}].name`,
          });
        }
      }
    });
    if (sourceWindowUse > nucleusCompilerCapacities.sourceWindowBytes) {
      issues.push({
        path: "$.sources",
        message: `requires ${sourceWindowUse} bytes in the ${nucleusCompilerCapacities.sourceWindowBytes}-byte host source window`,
      });
    }
    if (
      request.artifacts?.hex === true &&
      "bankCount" in target &&
      target.bankCount > 1
    ) {
      issues.push({
        path: "$.artifacts.hex",
        message: "requires a flat target",
      });
    }
    if (issues.length > 0) return configurationFailure(issues);

    try {
      const compiled = await compileNucleus(request.sources, target, {
        debugMap: request.artifacts?.d8 === true,
      });
      if (!compiled.success) {
        if (
          compiled.diagnostic.code === 95 ||
          compiled.diagnostic.code === 96
        ) {
          return configurationFailure([
            {
              path: "$.target",
              message: nucleusDiagnosticMessage(compiled.diagnostic.code),
            },
          ]);
        }
        if (compiled.diagnostic.code === 97) {
          return {
            success: false,
            kind: "execution",
            message: nucleusDiagnosticMessage(compiled.diagnostic.code),
          };
        }
        return {
          success: false,
          kind: "source",
          message: nucleusDiagnosticMessage(compiled.diagnostic.code),
          diagnostic: compiled.diagnostic,
          instructions: compiled.instructions,
          cycles: compiled.cycles,
        };
      }
      const d8 = compiled.debugMapping?.maps.map(({ bank, map }) => ({
        bank,
        map,
        json: `${JSON.stringify(map, null, 2)}\n`,
      }));
      return {
        success: true,
        artifacts: {
          nobj: compiled.nobj,
          ...(request.artifacts?.hex === true
            ? { hex: writeNucleusIntelHex(compiled) }
            : {}),
          ...(d8 === undefined ? {} : { d8 }),
        },
        materialized: compiled.materialized,
        instructions: compiled.instructions,
        cycles: compiled.cycles,
      };
    } catch (error) {
      return {
        success: false,
        kind: "execution",
        message: error instanceof Error ? error.message : String(error),
        cause: error,
      };
    }
  }
}

export const createNucleusCompiler = (): NucleusCompiler =>
  new NucleusCompiler();
