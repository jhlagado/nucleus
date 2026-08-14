import { describe, expect, it } from "vitest";

import { createNucleusCompiler } from "../src/host.js";

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

describe("the stable in-process Nucleus host API", () => {
  it("returns NOBJ, HEX and D8 from the authoritative Z80 compiler", async () => {
    const result = await createNucleusCompiler().build({
      sources: [{ name: "src/main.nu", source: "sub main()\nend\n" }],
      target: { services },
      artifacts: { hex: true, d8: true },
    });
    expect(result.success).toBe(true);
    if (!result.success) return;
    expect(result.artifacts.nobj.length).toBeGreaterThan(0);
    expect(result.artifacts.hex).toMatch(/^:/);
    expect(result.artifacts.d8).toHaveLength(1);
    expect(result.artifacts.d8?.[0]?.map.format).toBe("d8-debug-map");
  }, 30_000);

  it("returns target configuration failures instead of throwing", async () => {
    const result = await createNucleusCompiler().build({
      sources: [{ name: "main.nu", source: "sub main()\nend\n" }],
      target: { services: { ...services, trap: -1 } },
      artifacts: { hex: true },
    });
    expect(result).toMatchObject({ success: false, kind: "configuration" });
  });

  it("publishes NOBJ, HEX and D8 for a loaded flat target", async () => {
    const result = await createNucleusCompiler().build({
      sources: [
        {
          name: "src/main.nu",
          source: "var result as u8\nsub main()\nresult = 7\nend\n",
        },
      ],
      target: {
        imageBase: 0x4000,
        imageCapacity: 0x3000,
        imageFill: 0xa5,
        writableBase: 0x6000,
        writableCapacity: 0x1000,
        services,
      },
      artifacts: { hex: true, d8: true },
    });
    expect(result.success).toBe(true);
    if (!result.success) return;
    expect(result.materialized.parsed.map.romMode).toBe(false);
    expect(result.materialized.parsed.begin.imageFill).toBe(0xa5);
    expect(result.materialized.parsed.map.dataLoadAddress).toBe(0x6000);
    expect(result.materialized.flatImage?.at(-1)).toBe(0xa5);
    expect(result.artifacts.hex).toMatch(/^:/);
    expect(result.artifacts.d8).toHaveLength(1);
    expect(result.artifacts.d8?.[0]?.map.files["src/main.nu"]).toBeDefined();
  }, 30_000);

  it("rejects colliding portable D8 source identities", async () => {
    for (const names of [
      ["same.nu", "same.nu"],
      ["source\\library.nu", "source/library.nu"],
    ]) {
      const result = await createNucleusCompiler().build({
        sources: names.map((name) => ({ name, source: "\n" })),
        artifacts: { d8: true },
      });
      expect(result).toMatchObject({
        success: false,
        kind: "configuration",
      });
      if (result.success || result.kind !== "configuration") continue;
      expect(result.issues).toContainEqual({
        path: "$.sources[1].name",
        message:
          "duplicates the portable D8 source identity of $.sources[0].name",
      });
    }
  });

  it("preserves source names that are JavaScript object properties", async () => {
    for (const name of ["__proto__", "constructor"]) {
      const result = await createNucleusCompiler().build({
        sources: [{ name, source: "sub main()\nend\n" }],
        artifacts: { d8: true },
      });
      expect(result.success).toBe(true);
      if (!result.success) continue;
      const map = result.artifacts.d8?.[0]?.map;
      expect(Object.prototype.hasOwnProperty.call(map?.files, name)).toBe(true);
      expect(map?.files[name]?.symbols?.map(({ name }) => name)).toEqual([
        "main",
      ]);
    }
  }, 30_000);

  it("classifies target-capacity diagnostics as configuration failures", async () => {
    const result = await createNucleusCompiler().build({
      sources: [{ name: "main.nu", source: "sub main()\nend\n" }],
      target: { imageCapacity: 1 },
    });
    expect(result).toMatchObject({ success: false, kind: "configuration" });
  }, 30_000);

  it("classifies host source-capacity failures as configuration failures", async () => {
    const tooMany = await createNucleusCompiler().build({
      sources: Array.from({ length: 9 }, (_, index) => ({
        name: `part-${index}.nu`,
        source: "\n",
      })),
    });
    expect(tooMany).toMatchObject({
      success: false,
      kind: "configuration",
    });

    const tooLarge = await createNucleusCompiler().build({
      sources: [{ name: "main.nu", source: " ".repeat(2044) }],
    });
    expect(tooLarge).toMatchObject({
      success: false,
      kind: "configuration",
    });
  });

  it("retains exact source diagnostics in the result union", async () => {
    const result = await createNucleusCompiler().build({
      sources: [{ name: "main.nu", source: "broken\n" }],
    });
    expect(result).toMatchObject({
      success: false,
      kind: "source",
      diagnostic: { sourceName: "main.nu", line: 1, column: 1 },
    });
  }, 30_000);

  it("publishes compiler identity and host limits", async () => {
    const info = await createNucleusCompiler().info();
    expect(info).toMatchObject({
      hostApiVersion: 1,
      languageVersion: "0.1",
      runtimeIdentity: 4,
      capacities: { sourceParts: 8, sourceWindowBytes: 2048, targetBanks: 4 },
      targets: { flat: true, banked: true, maxBanks: 4 },
    });
    expect(info.normalImageSha256).toMatch(/^[0-9a-f]{64}$/);
    expect(info.debugImageSha256).toMatch(/^[0-9a-f]{64}$/);
    expect(info.normalImageSha256).not.toBe(info.debugImageSha256);
  }, 30_000);
});
