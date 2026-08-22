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
    if (project.schema !== NUCLEUS_PROJECT_SCHEMA) return;
    expect(project.sources).toEqual(["src/model.nu", "src/main.nu"]);
  });

  it("rejects unversioned and incomplete projects", () => {
    expect(() =>
      parseNucleusProject(JSON.stringify({ sources: [], outputs: {} })),
    ).toThrowError(NucleusConfigurationError);
  });

  it("accepts an import-directed entry and logical bank assignments", () => {
    const project = parseNucleusProject(
      JSON.stringify({
        schema: NUCLEUS_PROJECT_V2_SCHEMA,
        root: ".",
        entry: "src/main.nu",
        sourceBanks: { "src/library.nu": 1 },
        target: "nucleus-target.json",
        outputs: { nobj: "build/program.nobj" },
      }),
    );
    expect(project).toMatchObject({
      entry: "src/main.nu",
      sourceBanks: { "src/library.nu": 1 },
    });
  });
});
