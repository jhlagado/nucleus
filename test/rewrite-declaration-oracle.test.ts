import { describe, expect, it } from "vitest";

import { compileNucleus } from "../src/compiler.js";

const source = (...lines: readonly string[]) => `${lines.join("\n")}\n`;

describe("frozen declaration-directory oracle", () => {
  it("locks shared names and independent declaration directories", async () => {
    const bindings = Array.from(
      { length: 11 },
      (_, index) => `var value${index} as u8`,
    );
    const records = [
      "record R0",
      "f00 as u8[1]",
      "f01 as u8[2]",
      "f02 as u8[3]",
      "end",
      "record R1",
      "f10 as u8",
      "f11 as u8",
      "f12 as u8",
      "end",
      "record R2",
      "f20 as u8",
      "f21 as u8",
      "f22 as u8",
      "end",
      "record R3",
      "f30 as u8",
      "f31 as u8",
      "end",
      "record R4",
      "f40 as u8",
      "end",
    ];
    const routines = Array.from({ length: 4 }, (_, routine) => [
      `sub routine${routine}()`,
      "end",
    ]).flat();
    const built = await compileNucleus(
      [
        {
          name: "capacity.nu",
          source: source(
            ...bindings,
            ...records,
            ...routines,
            "sub main()",
            "end",
          ),
        },
      ],
      {},
    );
    expect(built).toMatchObject({ success: true });

    const retainedParameters = await compileNucleus(
      [
        {
          name: "parameters.nu",
          source: source(
            ...Array.from({ length: 4 }, (_, routine) => [
              `sub routine${routine}(p${routine}a as u8, p${routine}b as u8, p${routine}c as u8, p${routine}d as u8)`,
              "end",
            ]).flat(),
            "sub main()",
            "end",
          ),
        },
      ],
      {},
    );
    expect(retainedParameters).toMatchObject({ success: true });
  });

  it("locks the independent first-overflow diagnostics", async () => {
    const cases = [
      {
        name: "binding",
        code: 56,
        source: source(
          ...Array.from(
            { length: 17 },
            (_, index) => `var value${index} as u8`,
          ),
          "sub main()",
          "end",
        ),
      },
      {
        name: "routine",
        code: 84,
        source: source(
          ...Array.from({ length: 5 }, (_, index) => [
            `sub routine${index}()`,
            "end",
          ]).flat(),
          "sub main()",
          "end",
        ),
      },
      {
        name: "parameter",
        code: 85,
        source: source(
          "sub routine0(p0a as u8, p0b as u8, p0c as u8, p0d as u8, p0e as u8)",
          "end",
          ...Array.from({ length: 3 }, (_, index) => index + 1)
            .map((routine) => [
              `sub routine${routine}(p${routine}a as u8, p${routine}b as u8, p${routine}c as u8, p${routine}d as u8)`,
              "end",
            ])
            .flat(),
          "sub main()",
          "end",
        ),
      },
    ] as const;

    for (const fixture of cases) {
      const built = await compileNucleus(
        [{ name: `${fixture.name}.nu`, source: fixture.source }],
        {},
      );
      expect(built.success, fixture.name).toBe(false);
      if (built.success) continue;
      expect(built.diagnostic.code, fixture.name).toBe(fixture.code);
    }
  });

  it("keeps the four-dimensional suffix boundary separate", async () => {
    const accepted = await compileNucleus(
      [
        {
          name: "suffix.nu",
          source: source(
            "var value as u8[1][1][1][1] = [[[[1]]]]",
            "sub main()",
            "end",
          ),
        },
      ],
      {},
    );
    expect(accepted.success).toBe(true);

    const rejected = await compileNucleus(
      [
        {
          name: "suffix.nu",
          source: source("var value as u8[1][1][1][1][1]", "sub main()", "end"),
        },
      ],
      {},
    );
    expect(rejected.success).toBe(false);
    if (rejected.success) return;
    expect(rejected.diagnostic).toEqual({
      code: 76,
      sourcePart: 1,
      sourceName: "suffix.nu",
      offset: 29,
      line: 1,
      column: 30,
    });
  });
});
