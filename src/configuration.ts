import type { RuntimeServiceAddresses } from "./nobj.js";
import type { NucleusTarget } from "./compiler.js";

export const NUCLEUS_TARGET_PROFILE_SCHEMA = "nucleus-target/v1";

export interface NucleusConfigurationIssue {
  readonly path: string;
  readonly message: string;
}

export class NucleusConfigurationError extends Error {
  public readonly code = "NUCLEUS_CONFIGURATION";

  public constructor(
    message: string,
    public readonly issues: readonly NucleusConfigurationIssue[],
  ) {
    super(message);
    this.name = "NucleusConfigurationError";
  }
}

const targetKeys = new Set([
  "schema",
  "imageBase",
  "imageCapacity",
  "imageFill",
  "writableBase",
  "writableCapacity",
  "establishStack",
  "services",
  "bankCount",
  "entryBank",
  "partBanks",
]);

export const nucleusTargetServiceNames = [
  "readInputByte",
  "writeOutputByte",
  "readStorageByte",
  "rewindStorageInput",
  "writeStorageByte",
  "seekStorageOutput",
  "success",
  "unhandledFailure",
  "trap",
  "farCall",
  "farJump",
] as const satisfies readonly (keyof RuntimeServiceAddresses)[];

const wordFields = [
  "imageBase",
  "imageCapacity",
  "writableBase",
  "writableCapacity",
] as const;

const isObject = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value);

const issue = (
  issues: NucleusConfigurationIssue[],
  path: string,
  message: string,
): void => {
  issues.push({ path, message });
};

const validateWord = (
  issues: NucleusConfigurationIssue[],
  path: string,
  value: unknown,
): value is number => {
  if (
    !Number.isInteger(value) ||
    (value as number) < 0 ||
    (value as number) > 0xffff
  ) {
    issue(issues, path, "must be an integer in the range 0..65535");
    return false;
  }
  return true;
};

export interface ValidateNucleusTargetOptions {
  readonly requireServices?: boolean;
  readonly sourcePartCount?: number;
}

const validateNucleusTargetInternal = (
  value: unknown,
  options: ValidateNucleusTargetOptions,
  allowMissingPartBanks: boolean,
): readonly NucleusConfigurationIssue[] => {
  const issues: NucleusConfigurationIssue[] = [];
  if (!isObject(value)) {
    return [{ path: "$", message: "must be a JSON object" }];
  }
  const hasField = (field: string): boolean =>
    Object.prototype.hasOwnProperty.call(value, field);
  const banked = hasField("bankCount");

  for (const key of Object.keys(value)) {
    if (!targetKeys.has(key))
      issue(issues, `$.${key}`, "is not a recognised target field");
  }
  if (
    value.schema !== undefined &&
    value.schema !== NUCLEUS_TARGET_PROFILE_SCHEMA
  ) {
    issue(
      issues,
      "$.schema",
      `must be ${JSON.stringify(NUCLEUS_TARGET_PROFILE_SCHEMA)}`,
    );
  }
  for (const field of wordFields) {
    if (value[field] !== undefined)
      validateWord(issues, `$.${field}`, value[field]);
  }
  for (const field of ["imageCapacity", "writableCapacity"] as const) {
    if (value[field] === 0) issue(issues, `$.${field}`, "must be nonzero");
  }
  if (
    value.imageFill !== undefined &&
    (!Number.isInteger(value.imageFill) ||
      (value.imageFill as number) < 0 ||
      (value.imageFill as number) > 0xff)
  ) {
    issue(issues, "$.imageFill", "must be an integer in the range 0..255");
  }
  if (
    value.establishStack !== undefined &&
    typeof value.establishStack !== "boolean"
  ) {
    issue(issues, "$.establishStack", "must be Boolean");
  }

  const imageBase =
    typeof value.imageBase === "number" ? value.imageBase : 0x8000;
  const imageCapacity =
    typeof value.imageCapacity === "number" ? value.imageCapacity : 0x1000;
  const writableBase =
    typeof value.writableBase === "number" ? value.writableBase : 0x4000;
  const writableCapacity =
    typeof value.writableCapacity === "number"
      ? value.writableCapacity
      : 0x1000;
  if (
    Number.isInteger(imageBase) &&
    Number.isInteger(imageCapacity) &&
    imageBase + imageCapacity > 0x10000
  ) {
    issue(
      issues,
      "$.imageCapacity",
      "extends the image region beyond address 65535",
    );
  }
  if (
    Number.isInteger(writableBase) &&
    Number.isInteger(writableCapacity) &&
    writableBase + writableCapacity > 0x10000
  ) {
    issue(
      issues,
      "$.writableCapacity",
      "extends the writable region beyond address 65535",
    );
  }
  const imageEnd = imageBase + imageCapacity;
  const writableEnd = writableBase + writableCapacity;
  if (
    imageBase >= 0 &&
    imageCapacity >= 0 &&
    imageEnd <= 0x10000 &&
    writableBase >= 0 &&
    writableCapacity >= 0 &&
    writableEnd <= 0x10000
  ) {
    const regionsOverlap = imageBase < writableEnd && writableBase < imageEnd;
    const writableInsideImage =
      writableBase >= imageBase && writableEnd <= imageEnd;
    if (regionsOverlap && !writableInsideImage) {
      issue(
        issues,
        "$.writableBase",
        "must place the writable region wholly inside or wholly outside the image region",
      );
    }
    if (banked && regionsOverlap) {
      issue(
        issues,
        "$.writableBase",
        "must place banked writable storage wholly outside the bank window",
      );
    }
  }

  if (value.services === undefined) {
    if (options.requireServices === true) {
      issue(
        issues,
        "$.services",
        "must define every Nucleus system service address",
      );
    }
  } else if (!isObject(value.services)) {
    issue(issues, "$.services", "must be an object");
  } else {
    const knownServices = new Set<string>(nucleusTargetServiceNames);
    for (const key of Object.keys(value.services)) {
      if (!knownServices.has(key)) {
        issue(
          issues,
          `$.services.${key}`,
          "is not a recognised Nucleus service",
        );
      }
    }
    for (const name of nucleusTargetServiceNames) {
      const service = value.services[name];
      if (service === undefined) {
        issue(issues, `$.services.${name}`, "is required");
      } else {
        validateWord(issues, `$.services.${name}`, service);
      }
    }
  }

  if (!banked) {
    if (hasField("entryBank")) {
      issue(issues, "$.entryBank", "requires bankCount");
    }
    if (hasField("partBanks")) {
      issue(issues, "$.partBanks", "requires bankCount");
    }
  } else {
    const bankCount = value.bankCount;
    if (
      !Number.isInteger(bankCount) ||
      (bankCount as number) < 2 ||
      (bankCount as number) > 4
    ) {
      issue(issues, "$.bankCount", "must be an integer in the range 2..4");
    }
    if (
      !Number.isInteger(value.entryBank) ||
      (value.entryBank as number) < 0 ||
      (Number.isInteger(bankCount) &&
        (value.entryBank as number) >= (bankCount as number))
    ) {
      issue(issues, "$.entryBank", "must identify a bank within bankCount");
    }
    if (!Array.isArray(value.partBanks) && !allowMissingPartBanks) {
      issue(
        issues,
        "$.partBanks",
        "must be an array of source-part bank ordinals",
      );
    } else if (Array.isArray(value.partBanks)) {
      if (
        options.sourcePartCount !== undefined &&
        value.partBanks.length !== options.sourcePartCount
      ) {
        issue(
          issues,
          "$.partBanks",
          `must contain ${options.sourcePartCount} entries for this build`,
        );
      }
      value.partBanks.forEach((bank, index) => {
        if (
          !Number.isInteger(bank) ||
          (bank as number) < 0 ||
          (Number.isInteger(bankCount) &&
            (bank as number) >= (bankCount as number))
        ) {
          issue(
            issues,
            `$.partBanks[${index}]`,
            "must identify a bank within bankCount",
          );
        }
      });
    }
  }
  return issues;
};

export const validateNucleusTarget = (
  value: unknown,
  options: ValidateNucleusTargetOptions = {},
): readonly NucleusConfigurationIssue[] =>
  validateNucleusTargetInternal(value, options, false);

export const assertNucleusTarget = (
  value: unknown,
  options: ValidateNucleusTargetOptions = {},
): NucleusTarget => {
  const issues = validateNucleusTarget(value, options);
  if (issues.length > 0) {
    throw new NucleusConfigurationError(
      "Invalid Nucleus target profile",
      issues,
    );
  }
  const input = value as Record<string, unknown>;
  const target: Record<string, unknown> = {};
  for (const key of targetKeys) {
    if (key !== "schema" && input[key] !== undefined) target[key] = input[key];
  }
  return target as unknown as NucleusTarget;
};

export const parseNucleusTargetProfile = (
  text: string,
  options: ValidateNucleusTargetOptions = {},
): NucleusTarget => {
  const value = parseNucleusTargetProfileJson(text);
  return assertNucleusTarget(value, options);
};

const parseNucleusTargetProfileJson = (text: string): unknown => {
  let value: unknown;
  try {
    value = JSON.parse(text);
  } catch (error) {
    throw new NucleusConfigurationError("Invalid Nucleus target profile JSON", [
      {
        path: "$",
        message: error instanceof Error ? error.message : String(error),
      },
    ]);
  }
  return value;
};

export const validateNucleusTargetProfileDocument = (
  text: string,
  options: ValidateNucleusTargetOptions = {},
): void => {
  const value = parseNucleusTargetProfileJson(text);
  const issues = validateNucleusTarget(value, options);
  if (issues.length > 0) {
    throw new NucleusConfigurationError(
      "Invalid Nucleus target profile",
      issues,
    );
  }
};

export const validateNucleusTargetLayoutProfileDocument = (
  text: string,
  options: Pick<ValidateNucleusTargetOptions, "requireServices"> = {},
): void => {
  const value = parseNucleusTargetProfileJson(text);
  const issues = validateNucleusTargetInternal(value, options, true);
  if (issues.length > 0) {
    throw new NucleusConfigurationError(
      "Invalid Nucleus target profile",
      issues,
    );
  }
};
