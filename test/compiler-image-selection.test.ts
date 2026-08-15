import { describe, expect, it } from "vitest";

import {
  nucleusCompilerImages,
  productionCompilerImages,
  type NucleusCompilerImageSelection,
} from "../src/compiler-image-internal.js";
import {
  compileNucleus,
  type NucleusCompileOptions,
} from "../src/compiler.js";
import { isNucleusDebugPort } from "../src/d8.js";

const source = [{ name: "main.nu", source: "sub main()\nend\n" }] as const;

describe("internal compiler-image selection", () => {
  it("runs an explicitly paired test image without changing production selection", async () => {
    const productionWrites: number[] = [];
    const production = await compileNucleus(source, {}, {
      compilerIoWrite: (port) => productionWrites.push(port),
    });
    expect(production.success).toBe(true);
    expect(productionWrites).toEqual([]);

    const instrumentedWrites: number[] = [];
    const selectedOptions: NucleusCompileOptions &
      NucleusCompilerImageSelection = {
      compilerIoWrite: (port) => instrumentedWrites.push(port),
      [nucleusCompilerImages]: {
        normal: productionCompilerImages.debug,
        debug: productionCompilerImages.debug,
      },
    };
    const selected = await compileNucleus(source, {}, selectedOptions);
    expect(selected.success).toBe(true);
    expect(instrumentedWrites.length).toBeGreaterThan(0);
    expect(instrumentedWrites.every((port) => isNucleusDebugPort(port))).toBe(
      true,
    );
    if (!production.success || !selected.success) return;
    expect(selected.nobj).toEqual(production.nobj);
    expect(selected.materialized).toEqual(production.materialized);
  }, 30_000);
});
