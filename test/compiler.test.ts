import path from "node:path";

import { parseIntelHex } from "@jhlagado/debug80-runtime";
import { describe, expect, it } from "vitest";

import { compileNucleus, writeNucleusIntelHex } from "../src/compiler.js";
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
    const loaded = parseIntelHex(writeNucleusIntelHex(result));
    const imageBase = result.materialized.parsed.begin.imageBase;
    const usedLength = result.materialized.parsed.map.banks[0]?.usedLength ?? 0;
    expect(loaded.startAddress).toBe(imageBase);
    expect(loaded.memory.slice(imageBase, imageBase + usedLength)).toEqual(
      result.materialized.flatImage?.slice(0, usedLength),
    );
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
