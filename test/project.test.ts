import { describe, expect, it } from "vitest";

import { NucleusConfigurationError } from "../src/configuration.js";
import {
  NUCLEUS_PROJECT_SCHEMA,
  NUCLEUS_PROJECT_V2_SCHEMA,
  parseNucleusProject,
} from "../src/project.js";

describe("Nucleus project files", () => {
  it("preserves ordered multipart source paths", () => {
    const project = parseNucleusProject(
      JSON.stringify({
        schema: NUCLEUS_PROJECT_SCHEMA,
        root: ".",
        sources: ["src/model.nu", "src/main.nu"],
        target: "nucleus-target.json",
        outputs: {
          nobj: "build/program.nobj",
          hex: "build/program.hex",
          d8: "build/program.d8.json",
        },
      }),
    );
    expect(project.schema).toBe(NUCLEUS_PROJECT_SCHEMA);
    if (project.schema !== NUCLEUS_PROJECT_SCHEMA) throw new Error("not v1");
    expect(project.sources).toEqual(["src/model.nu", "src/main.nu"]);
  });

  it("rejects unversioned and incomplete projects", () => {
    expect(() =>
      parseNucleusProject(JSON.stringify({ sources: [], outputs: {} })),
    ).toThrowError(NucleusConfigurationError);
  });

  it("accepts a v2 entry and logical source-bank overrides", () => {
    const project = parseNucleusProject(
      JSON.stringify({
        schema: NUCLEUS_PROJECT_V2_SCHEMA,
        root: ".",
        entry: "src/main.nu",
        sourceBanks: {
          "src/lib/display.nu": 1,
          "src/main.nu": 0,
        },
        target: "nucleus-target.json",
        outputs: { nobj: "build/program.nobj" },
      }),
    );

    expect(project).toMatchObject({
      schema: NUCLEUS_PROJECT_V2_SCHEMA,
      entry: "src/main.nu",
      sourceBanks: {
        "src/lib/display.nu": 1,
        "src/main.nu": 0,
      },
    });
  });

  it("keeps v1 and v2 source selection mutually exclusive", () => {
    expect(() =>
      parseNucleusProject(
        JSON.stringify({
          schema: NUCLEUS_PROJECT_V2_SCHEMA,
          entry: "src/main.nu",
          sources: ["src/main.nu"],
          target: "target.json",
          outputs: { nobj: "program.nobj" },
        }),
      ),
    ).toThrowError(NucleusConfigurationError);

    expect(() =>
      parseNucleusProject(
        JSON.stringify({
          schema: NUCLEUS_PROJECT_V2_SCHEMA,
          entry: "src/main.nu",
          sourceBanks: { "../outside.nu": 0, "src/main.nu": 256 },
          target: "target.json",
          outputs: { nobj: "program.nobj" },
        }),
      ),
    ).toThrowError(NucleusConfigurationError);
  });

  it("requires every v2 logical source identity to fit SP1", () => {
    for (const entry of ["src/café.nu", `${"a".repeat(253)}.nu`]) {
      expect(() =>
        parseNucleusProject(
          JSON.stringify({
            schema: NUCLEUS_PROJECT_V2_SCHEMA,
            entry,
            target: "target.json",
            outputs: { nobj: "program.nobj" },
          }),
        ),
      ).toThrowError(NucleusConfigurationError);
    }

    expect(() =>
      parseNucleusProject(
        JSON.stringify({
          schema: NUCLEUS_PROJECT_V2_SCHEMA,
          entry: "src/main.nu",
          sourceBanks: { "src/control\u001fname.nu": 0 },
          target: "target.json",
          outputs: { nobj: "program.nobj" },
        }),
      ),
    ).toThrowError(NucleusConfigurationError);
  });
});
