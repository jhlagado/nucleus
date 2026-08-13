import { mkdtemp, readFile, readdir, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";

import { afterEach, describe, expect, it } from "vitest";

import {
  publishNucleusArtifactSet,
  publishNucleusBuildOutputs,
} from "../src/publication.js";
import { publishNucleusArtifactSetInternal } from "../src/publication-internal.js";

const directories: string[] = [];

afterEach(async () => {
  await Promise.all(
    directories
      .splice(0)
      .map((directory) => rm(directory, { recursive: true, force: true })),
  );
});

describe("Nucleus artifact-set publication", () => {
  it("publishes NOBJ, HEX and a banked D8 group together", async () => {
    const root = await mkdtemp(path.join(os.tmpdir(), "nucleus-publication-"));
    directories.push(root);
    const outputs = await publishNucleusBuildOutputs(
      {
        nobj: path.join(root, "build", "program.nobj"),
        hex: path.join(root, "build", "program.hex"),
        d8: path.join(root, "build", "program.d8.json"),
      },
      {
        nobj: new Uint8Array([1, 2, 3]),
        hex: ":00000001FF\n",
        d8: [
          { bank: 0, map: {} as never, json: '{"bank":0}\n' },
          { bank: 1, map: {} as never, json: '{"bank":1}\n' },
        ],
      },
    );
    expect(outputs.map((output) => path.basename(output)).sort()).toEqual([
      "program.bank-0.d8.json",
      "program.bank-1.d8.json",
      "program.hex",
      "program.nobj",
    ]);
  });

  it("rejects duplicate destinations before replacing existing output", async () => {
    const root = await mkdtemp(path.join(os.tmpdir(), "nucleus-publication-"));
    directories.push(root);
    const output = path.join(root, "program.nobj");
    await writeFile(output, "previous");
    await expect(
      publishNucleusArtifactSet([
        { path: output, contents: "first" },
        { path: output, contents: "second" },
      ]),
    ).rejects.toThrow("distinct paths");
    expect(await readFile(output, "utf8")).toBe("previous");
    expect(await readdir(root)).toEqual(["program.nobj"]);
  });

  it("restores the previous artifact set after a failed promotion", async () => {
    const root = await mkdtemp(path.join(os.tmpdir(), "nucleus-publication-"));
    directories.push(root);
    const nobj = path.join(root, "program.nobj");
    const hex = path.join(root, "program.hex");
    await writeFile(nobj, "previous object");
    await writeFile(hex, "previous hex");

    await expect(
      publishNucleusArtifactSetInternal(
        [
          { path: nobj, contents: "next object" },
          { path: hex, contents: "next hex" },
        ],
        [],
        {
          beforePromote: (_path, index) => {
            if (index === 1) throw new Error("injected promotion failure");
          },
        },
      ),
    ).rejects.toThrow("injected promotion failure");

    expect(await readFile(nobj, "utf8")).toBe("previous object");
    expect(await readFile(hex, "utf8")).toBe("previous hex");
    expect((await readdir(root)).sort()).toEqual([
      "program.hex",
      "program.nobj",
    ]);
  });
});
