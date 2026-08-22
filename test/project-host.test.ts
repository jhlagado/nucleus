import { mkdtemp, mkdir, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";

import { describe, expect, it } from "vitest";

import {
  buildNucleusProject,
  prepareNucleusProject,
  type NucleusProjectCompiler,
} from "../src/project-host.js";

const target = {
  schema: "nucleus-target/v1",
  imageBase: 32768,
  imageCapacity: 8192,
  writableBase: 16384,
  writableCapacity: 4096,
  bankCount: 2,
  entryBank: 0,
  services: {
    readInputByte: 28672,
    writeOutputByte: 28675,
    readStorageByte: 28678,
    rewindStorageInput: 28681,
    writeStorageByte: 28684,
    seekStorageOutput: 28687,
    success: 28690,
    unhandledFailure: 28693,
    trap: 28696,
    farCall: 28699,
    farJump: 28702,
    packetService: 28705,
  },
};

const project = async (): Promise<string> => {
  const root = await mkdtemp(path.join(tmpdir(), "nucleus-project-host-"));
  await mkdir(path.join(root, "src"));
  await writeFile(path.join(root, "src/model.nu"), "const Value = 7\n");
  await writeFile(
    path.join(root, "src/main.nu"),
    '//% import "model.nu"\nsub main()\nend\n',
  );
  await writeFile(path.join(root, "target.json"), JSON.stringify(target));
  await writeFile(
    path.join(root, "nucleus-project.json"),
    JSON.stringify({
      schema: "nucleus-project/v2",
      root: ".",
      entry: "src/main.nu",
      sourceBanks: { "src/model.nu": 1 },
      target: "target.json",
      outputs: {
        nobj: "build/program.nobj",
        d8: "build/program.d8.json",
      },
    }),
  );
  return root;
};

describe("Nucleus project host", () => {
  it("prepares an ordered project and derives ordinal banks", async () => {
    const root = await project();
    const prepared = await prepareNucleusProject(
      path.join(root, "nucleus-project.json"),
      { requireServices: true },
    );
    expect(prepared.entry).toBe("src/main.nu");
    expect(prepared.sources.map(({ name }) => name)).toEqual([
      "src/model.nu",
      "src/main.nu",
    ]);
    expect(prepared.dependencies).toMatchObject([
      { name: "src/model.nu", imports: [], byteLength: 16 },
      { name: "src/main.nu", imports: ["src/model.nu"], byteLength: 37 },
    ]);
    expect("partBanks" in prepared.target && prepared.target.partBanks).toEqual(
      [1, 0],
    );
    expect(prepared.sourcePlan).toBe(
      "SP1 2\nP 1 12 src/model.nu\nP 0 11 src/main.nu\nEND\n",
    );
  });

  it("builds through an injected compiler with selected artifacts", async () => {
    const root = await project();
    let request: Parameters<NucleusProjectCompiler["build"]>[0] | undefined;
    const compiler: NucleusProjectCompiler = {
      async build(received) {
        request = received;
        return { success: false, kind: "execution", message: "sentinel" };
      },
    };
    const built = await buildNucleusProject(
      path.join(root, "nucleus-project.json"),
      { compiler },
    );
    expect(built.result).toEqual({
      success: false,
      kind: "execution",
      message: "sentinel",
    });
    expect(request?.sources.map(({ name }) => name)).toEqual([
      "src/model.nu",
      "src/main.nu",
    ]);
    expect(request?.artifacts).toEqual({ hex: false, d8: true });
  });
});
