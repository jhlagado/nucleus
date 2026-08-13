import { describe, expect, it } from "vitest";

import {
  NUCLEUS_TARGET_PROFILE_SCHEMA,
  NucleusConfigurationError,
  parseNucleusTargetProfile,
  validateNucleusTarget,
} from "../src/configuration.js";

const services = {
  readInputByte: 0x7000,
  writeOutputByte: 0x7003,
  readStorageByte: 0x7006,
  rewindStorageInput: 0x7009,
  writeStorageByte: 0x700c,
  seekStorageOutput: 0x700f,
  success: 0x7012,
  unhandledFailure: 0x7015,
  trap: 0x7018,
  farCall: 0x701b,
  farJump: 0x701e,
};

describe("Nucleus target profiles", () => {
  it("parses the versioned flat profile", () => {
    expect(
      parseNucleusTargetProfile(
        JSON.stringify({ schema: NUCLEUS_TARGET_PROFILE_SCHEMA, services }),
        { requireServices: true, sourcePartCount: 1 },
      ),
    ).toEqual({ services });
  });

  it("reports every malformed service and unknown field", () => {
    const issues = validateNucleusTarget(
      {
        services: { ...services, trap: -1, invented: 3 },
        invented: true,
      },
      { requireServices: true },
    );
    expect(issues).toContainEqual({
      path: "$.services.trap",
      message: "must be an integer in the range 0..65535",
    });
    expect(issues.map(({ path }) => path)).toContain("$.services.invented");
    expect(issues.map(({ path }) => path)).toContain("$.invented");
  });

  it("validates bank assignments against the current source count", () => {
    const issues = validateNucleusTarget(
      { bankCount: 2, entryBank: 0, partBanks: [0], services },
      { sourcePartCount: 2 },
    );
    expect(issues).toContainEqual({
      path: "$.partBanks",
      message: "must contain 2 entries for this build",
    });
  });

  it("classifies malformed JSON as configuration failure", () => {
    expect(() => parseNucleusTargetProfile("{")).toThrowError(
      NucleusConfigurationError,
    );
  });
});
