import {
  isNucleusSourceIdentity,
  NUCLEUS_SOURCE_IDENTITY_REQUIREMENT,
} from "./source-identity.js";

export interface NucleusSourcePlanPart {
  readonly bank: number;
  readonly path: string;
}

export class NucleusSourcePlanError extends Error {
  public constructor(message: string) {
    super(message);
    this.name = "NucleusSourcePlanError";
  }
}

const unsignedByte = (value: string, field: string): number => {
  if (!/^(0|[1-9][0-9]*)$/.test(value)) {
    throw new NucleusSourcePlanError(`${field} must be canonical decimal`);
  }
  const parsed = Number(value);
  if (parsed > 0xff) {
    throw new NucleusSourcePlanError(`${field} must be in the range 0..255`);
  }
  return parsed;
};

const validatePlanPath = (value: string): void => {
  if (!isNucleusSourceIdentity(value)) {
    throw new NucleusSourcePlanError(
      `source path ${NUCLEUS_SOURCE_IDENTITY_REQUIREMENT}`,
    );
  }
};

export const parseNucleusSourcePlan = (
  source: string,
): readonly NucleusSourcePlanPart[] => {
  if (/\r(?!\n)/.test(source)) {
    throw new NucleusSourcePlanError(
      "source plan contains a lone carriage return",
    );
  }
  const normalized = source.replaceAll("\r\n", "\n");
  const lines = normalized.endsWith("\n")
    ? normalized.slice(0, -1).split("\n")
    : normalized.split("\n");
  const header = /^SP1 (0|[1-9][0-9]*)$/.exec(lines[0] ?? "");
  if (header === null) {
    throw new NucleusSourcePlanError("expected SP1 source-plan header");
  }
  const count = unsignedByte(header[1]!, "source-part count");
  if (count === 0) {
    throw new NucleusSourcePlanError(
      "source plan must contain at least one part",
    );
  }
  if (lines.length !== count + 2 || lines.at(-1) !== "END") {
    throw new NucleusSourcePlanError(
      "source plan must contain its declared records followed by END",
    );
  }

  const parts: NucleusSourcePlanPart[] = [];
  for (let index = 0; index < count; index += 1) {
    const record = /^P ([^ ]+) ([^ ]+) (.*)$/.exec(lines[index + 1] ?? "");
    if (record === null) {
      throw new NucleusSourcePlanError(`invalid P record ${index + 1}`);
    }
    const bank = unsignedByte(record[1]!, "bank ordinal");
    const declaredLength = unsignedByte(record[2]!, "source path length");
    const sourcePath = record[3]!;
    validatePlanPath(sourcePath);
    if (Buffer.byteLength(sourcePath, "ascii") !== declaredLength) {
      throw new NucleusSourcePlanError(
        `source path length mismatch in record ${index + 1}`,
      );
    }
    parts.push({ bank, path: sourcePath });
  }
  return parts;
};

export const serializeNucleusSourcePlan = (
  parts: readonly NucleusSourcePlanPart[],
): string => {
  if (parts.length < 1 || parts.length > 0xff) {
    throw new NucleusSourcePlanError(
      "source-part count must be in the range 1..255",
    );
  }
  const records = parts.map((part, index) => {
    if (!Number.isInteger(part.bank) || part.bank < 0 || part.bank > 0xff) {
      throw new NucleusSourcePlanError(
        `bank ordinal in record ${index + 1} must be in the range 0..255`,
      );
    }
    const pathLength = Buffer.byteLength(part.path, "ascii");
    if (pathLength > 0xff) {
      throw new NucleusSourcePlanError(
        "source path length must be in the range 1..255",
      );
    }
    validatePlanPath(part.path);
    return `P ${part.bank} ${pathLength} ${part.path}`;
  });
  return [`SP1 ${parts.length}`, ...records, "END", ""].join("\n");
};
