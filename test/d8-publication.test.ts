import { mkdtemp, readFile, readdir, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";

import { afterEach, describe, expect, it } from "vitest";

import { publishNucleusD8Outputs } from "../src/d8-publication.js";
import type { NucleusD8DebugMap, NucleusDebugMapping } from "../src/d8.js";

const directories: string[] = [];

const debugMap = (bank: number): NucleusD8DebugMap => ({
  format: "d8-debug-map",
  version: 1,
  arch: "z80",
  addressWidth: 16,
  endianness: "little",
  files: {},
  lstText: [],
  segmentDefaults: { kind: "code", confidence: "high" },
  symbolDefaults: { kind: "label", scope: "global" },
  memory: {
    segments: [
      { name: `bank-${bank}`, start: 0, end: 1, kind: "banked", bank },
    ],
  },
  generator: { name: "Nucleus", tool: "nucleus" },
});

const mapping = (...banks: number[]): NucleusDebugMapping => ({
  maps: banks.map((bank) => ({ bank, map: debugMap(bank) })),
  sourceMarks: 0,
  declarationMarks: 0,
  semanticOperations: 0,
  imageBytes: 0,
});

const workspace = async (): Promise<{ root: string; requested: string }> => {
  const root = await mkdtemp(path.join(os.tmpdir(), "nucleus-d8-publication-"));
  directories.push(root);
  return { root, requested: path.join(root, "main.d8.json") };
};

afterEach(async () => {
  for (const directory of directories) {
    await rm(directory, { recursive: true, force: true });
  }
  directories.length = 0;
});

describe("D8 sidecar group publication", () => {
  it("removes obsolete banks when a banked generation shrinks", async () => {
    const { root, requested } = await workspace();
    await publishNucleusD8Outputs(requested, mapping(0, 1, 2));
    await publishNucleusD8Outputs(requested, mapping(0, 1));

    expect((await readdir(root)).sort()).toEqual([
      "main.bank-0.d8.json",
      "main.bank-1.d8.json",
    ]);
  });

  it("replaces banked and flat generations as complete groups", async () => {
    const { root, requested } = await workspace();
    await publishNucleusD8Outputs(requested, mapping(0, 1));
    await publishNucleusD8Outputs(requested, mapping(0));
    expect(await readdir(root)).toEqual(["main.d8.json"]);

    await publishNucleusD8Outputs(requested, mapping(0, 1, 2));
    expect((await readdir(root)).sort()).toEqual([
      "main.bank-0.d8.json",
      "main.bank-1.d8.json",
      "main.bank-2.d8.json",
    ]);
  });

  it("keeps the previous complete group when formatting fails", async () => {
    const { root, requested } = await workspace();
    await writeFile(requested, "previous\n", "utf8");
    const invalid = {
      ...mapping(0),
      maps: [{ bank: 0, map: { ...debugMap(0), invalid: 1n } }],
    } as unknown as NucleusDebugMapping;

    await expect(publishNucleusD8Outputs(requested, invalid)).rejects.toThrow();
    expect(await readFile(requested, "utf8")).toBe("previous\n");
    expect(await readdir(root)).toEqual(["main.d8.json"]);
  });
});
