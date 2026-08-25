import path from "node:path";
import { fileURLToPath } from "node:url";

import { compile } from "@jhlagado/azm/compile";
import { describe, expect, it } from "vitest";

const directory = path.dirname(fileURLToPath(import.meta.url));
const source = path.join(
  directory,
  "..",
  "asm",
  "vertical-slice",
  "cpm22-compiler-layout-proof.asm",
);

describe("native Nucleus CP/M 2.2 TPA layout", () => {
  it("retains every production compiler capacity beside a direct image candidate", async () => {
    const assembled = await compile(source, {
      emitD8m: true,
      registerContracts: "strict",
      registerContractsInterfaces: [
        path.join(
          directory,
          "..",
          "asm",
          "vertical-slice",
          "expression-generated-z80.asmi",
        ),
      ],
    });
    expect(
      assembled.diagnostics.filter(({ severity }) => severity === "error"),
    ).toEqual([]);
    const map = assembled.artifacts.find(({ kind }) => kind === "d8m");
    if (map?.kind !== "d8m") throw new Error("AZM omitted the CP/M layout map");
    const symbols = Object.fromEntries(
      map.json.symbols.flatMap((entry) => {
        const value = entry.address ?? entry.value;
        return value === undefined ? [] : [[entry.name, value]];
      }),
    );

    expect(symbols.CompilerCoreEnd - symbols.CompilerCodeStart).toBe(16_314);
    expect(symbols.CompilerCoreEnd).toBe(0x40ba);
    expect(symbols.CpmHostVectorStart).toBe(0x4100);
    expect(symbols.CpmHostVectorStart - symbols.CompilerCoreEnd).toBe(70);
    expect(symbols.CpmHostVectorTableEnd - symbols.CpmHostVectorStart).toBe(50);
    expect(symbols.CpmLayoutResidentEnd).toBeLessThanOrEqual(
      symbols.CpmHostResidentLimit,
    );

    expect(symbols.TargetWorkspaceEnd - symbols.CompilerWorkBase).toBe(3_922);
    expect(symbols.NativeSourceTokenLimit - symbols.NativeSourceTokenBase).toBe(
      1_280,
    );
    expect(symbols.NativeSourceChunkLimit - symbols.NativeSourceChunkBase).toBe(
      768,
    );
    expect(symbols.CpmOutputBufferLimit - symbols.CpmOutputBufferBase).toBe(
      23_808,
    );
    expect(symbols.StackTop - symbols.StackFloor).toBe(3_840);
    expect(symbols.StackTop).toBe(0xe400);

    expect(symbols.CpmTargetImageBase).toBe(0x0800);
    expect(symbols.CpmTargetImageLimit).toBe(0x6500);
    expect(symbols.CpmTargetWritableBase).toBe(0x5800);
    expect(symbols.CpmTargetWritableCapacity).toBe(3_328);
    expect(symbols.CpmOutputAddressDelta).toBe(0x7000);
  });
});
