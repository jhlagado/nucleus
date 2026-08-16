import { describe, expect, it } from "vitest";

import {
  NUCLEUS_TARGET_PROFILE_SCHEMA,
  NucleusConfigurationError,
  parseNucleusTargetProfile,
  validateNucleusTargetLayoutProfileDocument,
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

  it("never asserts an incomplete banked authoring profile as a compiler target", () => {
    const incomplete = JSON.stringify({
      bankCount: 2,
      entryBank: 0,
      services,
    });

    expect(() =>
      parseNucleusTargetProfile(incomplete, {
        sourcePartCount: 2,
        ...({ allowMissingPartBanks: true } as object),
      }),
    ).toThrowError(NucleusConfigurationError);
    expect(() =>
      validateNucleusTargetLayoutProfileDocument(incomplete, {
        requireServices: true,
      }),
    ).not.toThrow();
  });

  it("reserves bank fields for targets with at least two banks", () => {
    expect(
      validateNucleusTarget({ bankCount: 1, entryBank: 0, partBanks: [0] }),
    ).toContainEqual({
      path: "$.bankCount",
      message: "must be an integer in the range 2..4",
    });
    expect(validateNucleusTarget({ bankCount: undefined })).toContainEqual({
      path: "$.bankCount",
      message: "must be an integer in the range 2..4",
    });
    expect(validateNucleusTarget({ entryBank: undefined })).toContainEqual({
      path: "$.entryBank",
      message: "requires bankCount",
    });
  });

  it("accepts loaded flat layouts and a configured image fill", () => {
    expect(
      validateNucleusTarget({
        imageBase: 0x4000,
        imageCapacity: 0x3000,
        imageFill: 0xa5,
        writableBase: 0x6000,
        writableCapacity: 0x1000,
      }),
    ).toEqual([]);
  });

  it("rejects partial image overlap and banked writable overlap", () => {
    const partial = validateNucleusTarget({
      imageBase: 0x4000,
      imageCapacity: 0x3000,
      writableBase: 0x6000,
      writableCapacity: 0x2000,
    });
    expect(partial.map(({ path }) => path)).toContain("$.writableBase");

    const banked = validateNucleusTarget({
      imageBase: 0x4000,
      imageCapacity: 0x3000,
      writableBase: 0x6000,
      writableCapacity: 0x1000,
      bankCount: 2,
      entryBank: 0,
      partBanks: [0],
    });
    expect(banked).toContainEqual({
      path: "$.writableBase",
      message:
        "must place banked writable storage wholly outside the bank window",
    });
  });

  it("rejects image fills outside one byte", () => {
    expect(validateNucleusTarget({ imageFill: 0x100 })).toContainEqual({
      path: "$.imageFill",
      message: "must be an integer in the range 0..255",
    });
  });

  it("rejects zero-length target regions before execution", () => {
    expect(validateNucleusTarget({ imageCapacity: 0 })).toContainEqual({
      path: "$.imageCapacity",
      message: "must be nonzero",
    });
    expect(validateNucleusTarget({ writableCapacity: 0 })).toContainEqual({
      path: "$.writableCapacity",
      message: "must be nonzero",
    });
  });

  it("classifies malformed JSON as configuration failure", () => {
    expect(() => parseNucleusTargetProfile("{")).toThrowError(
      NucleusConfigurationError,
    );
  });
});
