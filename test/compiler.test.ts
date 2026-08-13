import path from "node:path";

import { parseIntelHex } from "@jhlagado/debug80-runtime";
import { describe, expect, it } from "vitest";

import {
  compileNucleus,
  defaultNucleusServices,
  writeNucleusIntelHex,
} from "../src/compiler.js";
import { runProofManifest } from "../src/proof.js";

const proof = (name: string): string =>
  path.resolve(import.meta.dirname, "..", "proofs", `${name}.json`);

const expectValidIntelHexChecksums = (hex: string): void => {
  for (const line of hex.trim().split("\n")) {
    const bytes = Array.from({ length: (line.length - 1) / 2 }, (_, index) =>
      Number.parseInt(line.slice(index * 2 + 1, index * 2 + 3), 16),
    );
    expect(bytes.reduce((sum, value) => (sum + value) & 0xff, 0)).toBe(0);
  }
};

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
    const hex = writeNucleusIntelHex(result);
    expectValidIntelHexChecksums(hex);
    const loaded = parseIntelHex(hex);
    const imageBase = result.materialized.parsed.begin.imageBase;
    const usedLength = result.materialized.parsed.map.banks[0]?.usedLength ?? 0;
    expect(loaded.startAddress).toBe(imageBase);
    expect(loaded.memory.slice(imageBase, imageBase + usedLength)).toEqual(
      result.materialized.flatImage?.slice(0, usedLength),
    );
    expect(
      loaded.writeRanges?.reduce(
        (total, range) => total + range.end - range.start,
        0,
      ),
    ).toBe(usedLength);
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

  it("links target service addresses and materializes a high flat layout", async () => {
    const result = await compileNucleus(
      [{ name: "main.nu", source: "sub main()\nend\n" }],
      {
        imageBase: 0xf000,
        imageCapacity: 0x1000,
        writableBase: 0x5000,
        writableCapacity: 0x1000,
        services: { ...defaultNucleusServices, writeOutputByte: 0x1234 },
      },
    );
    expect(result.success).toBe(true);
    if (!result.success) return;

    const parsed = result.materialized.parsed;
    expect(parsed.map.vectorBase).toBe(0x5000);
    const image = result.materialized.flatImage ?? new Uint8Array();
    const loadOffset = parsed.map.dataLoadAddress - parsed.begin.imageBase;
    expect(Array.from(image.slice(loadOffset + 3, loadOffset + 6))).toEqual([
      0xc3, 0x34, 0x12,
    ]);
    const hex = writeNucleusIntelHex(result);
    expectValidIntelHexChecksums(hex);
    const loaded = parseIntelHex(hex);
    const usedLength = parsed.map.banks[0]?.usedLength ?? 0;
    expect(loaded.startAddress).toBe(0xf000);
    expect(loaded.memory.slice(0xf000, 0xf000 + usedLength)).toEqual(
      image.slice(0, usedLength),
    );
  }, 30_000);
});
