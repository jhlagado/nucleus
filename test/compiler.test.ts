import path from "node:path";

import { describe, expect, it } from "vitest";

import { compileNucleus } from "../src/compiler.js";
import { runProofManifest } from "../src/proof.js";

const proof = (name: string): string =>
  path.resolve(import.meta.dirname, "..", "proofs", `${name}.json`);

describe("emulator-backed compiler host", () => {
  it("matches the established flat-target NOBJ byte for byte", async () => {
    const baseline = await runProofManifest(
      proof("flat-target-z80-slice-proof"),
    );
    const result = await compileNucleus([
      {
        name: "main.nu",
        source: [
          "var value as u16 = 3",
          "var cleared as u8",
          "sub main()",
          "value = value * 2",
          "end",
          "",
        ].join("\n"),
      },
    ]);
    expect(result.success).toBe(true);
    if (!result.success) return;
    expect(result.nobj).toEqual(baseline.nobj?.serialized);
  }, 30_000);

  it("returns the exact source-part diagnostic position", async () => {
    const result = await compileNucleus([
      { name: "model.nu", source: "var value as u8\n" },
      { name: "main.nu", source: "sub main()\nvalue = 300\nend\n" },
    ]);
    expect(result).toMatchObject({
      success: false,
      diagnostic: {
        sourcePart: 2,
        sourceName: "main.nu",
        line: 2,
        column: 9,
      },
    });
  }, 30_000);
});
