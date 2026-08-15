import { mkdtemp, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";

import { compile } from "@jhlagado/azm/compile";
import { parseIntelHex } from "@jhlagado/debug80-runtime";
import { describe, expect, it } from "vitest";

const sourceDirectory = path.resolve(
  import.meta.dirname,
  "..",
  "asm",
  "vertical-slice",
);
const imageInclude = path.join(sourceDirectory, "flat-target-compiler-image.asmi");
const memoryMapInclude = path.join(sourceDirectory, "target-memory-map.asmi");
const runtimeIdentityInclude = path.join(sourceDirectory, "nucleus-runtime-identity.asmi");

interface RelocatedImage {
  readonly origin: number;
  readonly memory: Uint8Array;
  readonly addresses: ReadonlyMap<string, number>;
  readonly values: ReadonlyMap<string, number>;
}

const assembleAt = async (origin: number): Promise<RelocatedImage> => {
  const directory = await mkdtemp(path.join(os.tmpdir(), "nucleus-origin-proof-"));
  const sourcePath = path.join(directory, `compiler-${origin.toString(16)}.asm`);
  try {
    const relativeMemoryMap = path.relative(directory, memoryMapInclude);
    const relativeImage = path.relative(directory, imageInclude);
    const relativeRuntimeIdentity = path.relative(
      directory,
      runtimeIdentityInclude,
    );
    await writeFile(
      sourcePath,
      [
        "DebugHooks .equ 0",
        `.include ${JSON.stringify(relativeMemoryMap)}`,
        `.org $${origin.toString(16)}`,
        `.include ${JSON.stringify(relativeImage)}`,
        `.include ${JSON.stringify(relativeRuntimeIdentity)}`,
        "TargetSinkImageByte:",
        "TargetSinkBegin:",
        "TargetSinkPatchByte:",
        "TargetSinkRuntimeImage:",
        "TargetSinkRuntimeInitialImage:",
        "TargetSinkPatchWord:",
        "TargetSinkMapFlat:",
        "TargetSinkCommit:",
        "TargetSinkMapBanked:",
        "TargetSinkAbort:",
        "        RET",
        "",
      ].join("\n"),
      "utf8",
    );
    const result = await compile(sourcePath, {
      emitBin: false,
      emitHex: true,
      emitD8m: true,
    });
    const errors = result.diagnostics.filter(({ severity }) => severity === "error");
    expect(errors, `assembly at $${origin.toString(16)}`).toEqual([]);
    const hex = result.artifacts.find((artifact) => artifact.kind === "hex");
    const d8m = result.artifacts.find((artifact) => artifact.kind === "d8m");
    expect(hex?.kind).toBe("hex");
    expect(d8m?.kind).toBe("d8m");
    if (hex?.kind !== "hex" || d8m?.kind !== "d8m") {
      throw new Error("AZM omitted relocation-proof artifacts");
    }
    return {
      origin,
      memory: parseIntelHex(hex.text).memory,
      addresses: new Map(
        d8m.json.symbols.flatMap((entry) =>
          entry.address === undefined ? [] : [[entry.name, entry.address] as const],
        ),
      ),
      values: new Map(
        d8m.json.symbols.flatMap((entry) => {
          const value = entry.value ?? entry.address;
          return value === undefined ? [] : [[entry.name, value] as const];
        }),
      ),
    };
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
};

const wordAt = (memory: Uint8Array, address: number): number =>
  (memory[address] ?? 0) | ((memory[address + 1] ?? 0) << 8);

describe("compiler origin independence", () => {
  it("relocates full-width code addresses at CP/M, high, and top-fitting origins", async () => {
    const images = await Promise.all([0x0000, 0x0100, 0x8000, 0xc000].map(assembleAt));
    const baseline = images[0];
    expect(baseline).toBeDefined();
    if (baseline === undefined) return;

    const baselineStart = baseline.addresses.get("CompilerCodeStart");
    const baselineEnd = baseline.addresses.get("CompilerCoreEnd");
    expect(baselineStart).toBe(0);
    expect(baselineEnd).toBeGreaterThan(baselineStart ?? 0);
    if (baselineStart === undefined || baselineEnd === undefined) {
      return;
    }

    const coreBytes = baselineEnd - baselineStart;
    const prefetchAddress = baseline.addresses.get("TypedPrefetchBits");
    const prefetchedOperations = [
      20, 22, 32, 33, 34, 58, 59, 60, 67, 68, 69, 70, 71, 72, 74, 77, 82,
      83, 84, 86, 102, 103, 104, 105, 106, 110,
    ];
    const prefetchBytes = new Array<number>(12).fill(0);
    for (const operation of prefetchedOperations) {
      const index = operation - 20;
      prefetchBytes[index >> 3] |= 1 << (index & 7);
    }
    expect(prefetchAddress).toBeDefined();
    if (prefetchAddress !== undefined) {
      expect(
        Array.from(
          baseline.memory.slice(
            prefetchAddress,
            prefetchAddress + prefetchBytes.length,
          ),
        ),
      ).toEqual(prefetchBytes);
    }
    const addressTables = [
      {
        name: "semantic operation",
        table: "TypedOperationTable",
        count: "TypedOperationCount",
      },
      {
        name: "LL(1) action",
        table: "HybridLL1ActionDirectory",
        count: "HybridLL1ActionCount",
      },
    ] as const;
    for (const relocated of images.slice(1)) {
      const delta = relocated.origin - baseline.origin;
      expect(relocated.addresses.get("CompilerCodeStart")).toBe(relocated.origin);
      expect(relocated.addresses.get("CompilerCoreEnd")).toBe(
        relocated.origin + coreBytes,
      );
      expect(relocated.origin + coreBytes).toBeLessThanOrEqual(0x10000);
      if (prefetchAddress !== undefined) {
        const relocatedPrefetch = relocated.addresses.get("TypedPrefetchBits");
        expect(relocatedPrefetch).toBe(prefetchAddress + delta);
        if (relocatedPrefetch !== undefined) {
          expect(
            Array.from(
              relocated.memory.slice(
                relocatedPrefetch,
                relocatedPrefetch + prefetchBytes.length,
              ),
            ),
          ).toEqual(prefetchBytes);
        }
      }

      for (const [name, address] of baseline.addresses) {
        if (address >= baselineStart && address < baselineEnd) {
          expect(
            relocated.addresses.get(name),
            `${name} at $${relocated.origin.toString(16)}`,
          ).toBe(address + delta);
        }
      }

      for (const descriptor of addressTables) {
        const baselineTable = baseline.addresses.get(descriptor.table);
        const relocatedTable = relocated.addresses.get(descriptor.table);
        const count = baseline.values.get(descriptor.count);
        expect(baselineTable).toBeDefined();
        expect(relocatedTable).toBe(
          baselineTable === undefined ? undefined : baselineTable + delta,
        );
        expect(count).toBeGreaterThan(0);
        if (
          baselineTable === undefined ||
          relocatedTable === undefined ||
          count === undefined
        ) {
          continue;
        }
        for (let index = 0; index < count; index += 1) {
          const baselineHandler = wordAt(
            baseline.memory,
            baselineTable + index * 2,
          );
          const relocatedHandler = wordAt(
            relocated.memory,
            relocatedTable + index * 2,
          );
          expect(
            relocatedHandler,
            `${descriptor.name} ${index} at $${relocated.origin.toString(16)}`,
          ).toBe(baselineHandler + delta);
          expect(relocatedHandler).toBeGreaterThanOrEqual(relocated.origin);
          expect(relocatedHandler).toBeLessThan(relocated.origin + coreBytes);
        }
      }
    }
  }, 30_000);
});
