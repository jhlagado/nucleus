import { mkdtemp, readFile, readdir, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { describe, expect, it } from "vitest";

import {
  nodeFileNobjSpoolFactory,
  NodeFileNobjOutput,
} from "../src/nobj-file.js";
import {
  NobjGenerationSink,
  NobjGenerationStore,
  parseNobj,
  type NobjBegin,
  type NobjMap,
  type NobjSpoolFactory,
  type RuntimeImageProvider,
} from "../src/nobj.js";
import { commitNobjAdapterGenerationTo } from "../src/proof.js";

const emptyProvider: RuntimeImageProvider = { get: () => undefined };

const begin: NobjBegin = {
  banked: false,
  runtimeIdentity: 1,
  bankCount: 1,
  imageFill: 0xee,
  imageBase: 0x8000,
  imageCapacity: 0x100,
};

const map: NobjMap = {
  romMode: true,
  establishedStack: false,
  entryBank: 0,
  entryAddress: 0x8000,
  writableBase: 0x4000,
  writableCapacity: 0x100,
  vectorBase: 0x4000,
  vectorLength: 1,
  initializedRunBase: 0x4000,
  initializedRunLength: 1,
  bssBase: 0x4001,
  bssLength: 0,
  stackRequirement: 0,
  dataLoadBank: 0,
  dataLoadAddress: 0x8000,
  dataLoadLength: 1,
  partBanks: [0],
  banks: [
    {
      usedLength: 1,
      readOnlyBase: 0x8000,
      readOnlyLength: 1,
      aggregateConstantBase: 0,
      aggregateConstantLength: 0,
    },
  ],
};

const preparedSink = (spoolFactory?: NobjSpoolFactory): NobjGenerationSink => {
  const sink =
    spoolFactory === undefined
      ? new NobjGenerationSink(new NobjGenerationStore(), emptyProvider)
      : new NobjGenerationSink(
          new NobjGenerationStore(),
          emptyProvider,
          spoolFactory,
        );
  sink.begin(begin);
  sink.image(0, 0x8000, Uint8Array.of(0xc9));
  sink.map(map);
  return sink;
};

describe("Node NOBJ file output", () => {
  it("publishes the same bytes as the in-memory compatibility result", async () => {
    const directory = await mkdtemp(join(tmpdir(), "nucleus-nobj-"));
    const path = join(directory, "program.nobj");
    const expected = preparedSink().commit();
    const metadata = preparedSink(
      nodeFileNobjSpoolFactory(directory, 5),
    ).commitTo(new NodeFileNobjOutput(path));
    const actual = new Uint8Array(await readFile(path));
    expect(actual).toEqual(expected);
    expect(parseNobj(actual).commit).toEqual(metadata.commit);
    expect(await readdir(directory)).toEqual(["program.nobj"]);
  });

  it("leaves the previous object untouched when preflight fails", async () => {
    const directory = await mkdtemp(join(tmpdir(), "nucleus-nobj-"));
    const path = join(directory, "program.nobj");
    await writeFile(path, "previous generation");
    const sink = new NobjGenerationSink(
      new NobjGenerationStore(),
      emptyProvider,
      nodeFileNobjSpoolFactory(directory, 5),
      { lowMemoryPatchValidation: true },
    );
    sink.begin(begin);
    sink.image(0, 0x8000, Uint8Array.of(0xc9));
    sink.map({ ...map, entryAddress: 0x8100 });
    expect(() => sink.commitTo(new NodeFileNobjOutput(path))).toThrow(
      "entry address",
    );
    expect(await readFile(path, "utf8")).toBe("previous generation");
    expect(await readdir(directory)).toEqual(["program.nobj"]);
  });

  it("discards file spools when adapter replay fails", async () => {
    const directory = await mkdtemp(join(tmpdir(), "nucleus-nobj-"));
    const path = join(directory, "program.nobj");
    const producerMemory = Uint8Array.from([1, 0, 0, 0x80, 1, 0, 0xc9, 0xff]);
    await expect(
      commitNobjAdapterGenerationTo(
        {
          name: "failed-replay",
          producerMemory,
          start: 0,
          length: producerMemory.length,
          maxBytes: producerMemory.length,
          begin,
          map,
          spoolFactory: nodeFileNobjSpoolFactory(directory, 5),
          lowMemoryPatchValidation: true,
        },
        new NodeFileNobjOutput(path),
      ),
    ).rejects.toThrow("truncated NOBJ adapter operation");
    expect(await readdir(directory)).toEqual([]);
  });
});
