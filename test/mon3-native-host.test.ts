import { describe, expect, it } from "vitest";

import {
  compileNucleusTo,
  type NucleusSourcePart,
  type NucleusTarget,
} from "../src/compiler.js";
import {
  mon3CompilerHex,
  mon3CompilerSymbols,
  mon3DebugCompilerSymbols,
} from "../src/generated-compiler-images.js";
import { parseIntelHex } from "@jhlagado/debug80-runtime";

const compile = async (
  hostTransport: "direct" | "mon3" | undefined,
  parts: readonly NucleusSourcePart[],
  target: NucleusTarget,
  debugMap = false,
  nativeObjectSource = false,
) => {
  const chunks: Uint8Array[] = [];
  let commits = 0;
  let aborts = 0;
  const result = await compileNucleusTo(
    parts,
    target,
    {
      write: (bytes) => chunks.push(bytes.slice()),
      commit: () => {
        commits += 1;
      },
      abort: () => {
        aborts += 1;
      },
    },
    { debugMap, hostTransport, nativeObjectSource },
  );
  return {
    result,
    bytes: Uint8Array.from(chunks.flatMap((chunk) => [...chunk])),
    commits,
    aborts,
  };
};

const expectSameCompile = async (
  parts: readonly NucleusSourcePart[],
  target: NucleusTarget,
  debugMap = false,
): Promise<void> => {
  const [direct, mon3] = await Promise.all([
    compile("direct", parts, target, debugMap),
    compile("mon3", parts, target, debugMap),
  ]);
  expect(mon3.result).toEqual(
    expect.objectContaining({ success: direct.result.success }),
  );
  expect(mon3.bytes).toEqual(direct.bytes);
  expect(mon3.commits).toBe(direct.commits);
  expect(mon3.aborts).toBe(direct.aborts);
  if (direct.result.success && mon3.result.success) {
    expect(mon3.result.object).toEqual(direct.result.object);
    expect(mon3.result.debugMapping).toEqual(direct.result.debugMapping);
  } else if (!direct.result.success && !mon3.result.success) {
    expect(mon3.result.diagnostic).toEqual(direct.result.diagnostic);
  }
};

describe("the MON3-compatible native compiler host", () => {
  it("uses the MON3 transport by default", async () => {
    const parts = [{ name: "main.nu", source: "sub main()\nend\n" }];
    const [implicit, explicit] = await Promise.all([
      compile(undefined, parts, {}),
      compile("mon3", parts, {}),
    ]);
    expect(implicit).toEqual(explicit);
  });

  it("keeps the normal and debug compiler images inside the 16 KiB bank", () => {
    expect(mon3CompilerSymbols.CompilerCoreBase).toBe(0x8000);
    expect(mon3CompilerSymbols.CompilerCoreEnd).toBeLessThanOrEqual(0xc000);
    expect(mon3CompilerSymbols.CompilerCoreEnd).toBe(0xbfba);
    expect(mon3DebugCompilerSymbols.CompilerCoreBase).toBe(0x8000);
    expect(mon3DebugCompilerSymbols.CompilerCoreEnd).toBeLessThanOrEqual(
      0xc000,
    );
    expect(mon3DebugCompilerSymbols.CompilerCoreEnd).toBe(0xbffc);
    expect(mon3CompilerSymbols.HostVectorBase).toBe(0x4000);
    expect(mon3CompilerSymbols.HostVectorEnd).toBe(0x43d5);
    expect(mon3CompilerSymbols.NativeHostWorkspaceEnd).toBe(
      mon3CompilerSymbols.NativeHostWorkspaceBase + 24,
    );

    const image = parseIntelHex(mon3CompilerHex).memory;
    expect([...image.slice(0x10, 0x13)]).toEqual([0, 0, 0]);
  });

  it("matches direct-host NOBJ for ROM, loaded, and banked targets", async () => {
    const parts = [
      {
        name: "main.nu",
        source: "var result as u8 = 3\nsub main()\nresult = result + 4\nend\n",
      },
    ];
    await expectSameCompile(parts, {});
    await expectSameCompile(parts, {
      imageBase: 0x4000,
      imageCapacity: 0x3000,
      writableBase: 0x6000,
      writableCapacity: 0x1000,
    });
    await expectSameCompile(
      parts,
      { bankCount: 2, entryBank: 1, partBanks: [1] },
      true,
    );
  }, 30_000);

  it("runs the Z80 SP1 reader, retained-name spool, and source streamer", async () => {
    const parts = [
      {
        name: "library/value.nu",
        source: "sub value() as u8\nreturn 41\nend\n",
      },
      {
        name: "main.nu",
        source:
          '//% import "library/value.nu"\nvar answer as u8\nsub main()\nanswer = value() + 1\nend\n',
      },
    ];
    const [compatibility, native] = await Promise.all([
      compile("mon3", parts, {}),
      compile("mon3", parts, {}, false, true),
    ]);
    expect(native.result).toEqual(
      expect.objectContaining({ success: compatibility.result.success }),
    );
    expect(native.bytes).toEqual(compatibility.bytes);
    expect(native.commits).toBe(1);
    expect(native.aborts).toBe(0);
    if (native.result.success && compatibility.result.success) {
      expect(native.result.object).toEqual(compatibility.result.object);
    }
  }, 30_000);

  it("writes byte-identical flat NOBJ in ROM and loaded modes", async () => {
    const parts = [
      {
        name: "main.nu",
        source:
          "var answer as u8 = 3\nvar initialized as u8[3] = [5, 6, 7]\nvar cleared as u16[2]\nconst lookup as u8[4] = [8, 9, 10, 11]\nsub value() as u8\nreturn 39\nend\nsub main()\nif answer < 4\nanswer = value() + initialized[1] + lookup[2]\nend\ncleared[0] = answer\nend\n",
      },
    ];
    for (const target of [
      { imageFill: 0xe5 },
      {
        imageBase: 0x4000,
        imageCapacity: 0x3000,
        imageFill: 0,
        writableBase: 0x6000,
        writableCapacity: 0x1000,
      },
    ]) {
      const [compatibility, native] = await Promise.all([
        compile("mon3", parts, target),
        compile("mon3", parts, target, false, true),
      ]);
      expect(native.result).toEqual(
        expect.objectContaining({ success: compatibility.result.success }),
      );
      expect(native.bytes).toEqual(compatibility.bytes);
      if (native.result.success && compatibility.result.success) {
        expect(native.result.object).toEqual(compatibility.result.object);
      }
    }
  }, 30_000);

  it("writes byte-identical banked NOBJ across source and empty banks", async () => {
    const parts = [
      {
        name: "library/value.nu",
        source:
          "const lookup as u8[3] = [40, 41, 42]\nsub value() as u8\nreturn lookup[1]\nend\n",
      },
      {
        name: "main.nu",
        source:
          '//% import "library/value.nu"\nvar answer as u8 = 1\nsub main()\nanswer = value() + answer\nend\n',
      },
    ];
    const target = {
      bankCount: 3,
      entryBank: 2,
      partBanks: [1, 2],
      imageFill: 0xa5,
    };
    const [compatibility, native] = await Promise.all([
      compile("mon3", parts, target),
      compile("mon3", parts, target, false, true),
    ]);
    expect(native.result).toEqual(
      expect.objectContaining({ success: compatibility.result.success }),
    );
    expect(native.bytes).toEqual(compatibility.bytes);
    if (native.result.success && compatibility.result.success) {
      expect(native.result.object).toEqual(compatibility.result.object);
      expect(native.result.object.begin.bankCount).toBe(3);
      expect(native.result.object.map.partBanks).toEqual([1, 2]);
    }
  }, 30_000);

  it("returns the same diagnostic and starts clean after a failed compile", async () => {
    await expectSameCompile([{ name: "bad.nu", source: "broken\n" }], {});
    await expectSameCompile(
      [{ name: "main.nu", source: "sub main()\nend\n" }],
      {},
      true,
    );
  }, 30_000);
});
