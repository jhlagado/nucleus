import { assembleNativeCompiler } from "../scripts/assemble-native-compiler.mjs";
import { describe, expect, it } from "vitest";

describe("native Nucleus CP/M 2.2 TPA layout", () => {
  it("retains every production compiler capacity beside a direct image candidate", async () => {
    const { symbols } = await assembleNativeCompiler(
      "cpm22-native-compiler.asm",
    );

    expect(symbols.CompilerCoreEnd - symbols.CompilerCodeStart).toBe(16_314);
    expect(symbols.CompilerCoreEnd).toBe(0x40bd);
    expect(symbols.CpmCompilerHostVectorStart).toBe(0x4100);
    expect(symbols.CpmCompilerHostVectorStart - symbols.CompilerCoreEnd).toBe(67);
    expect(symbols.CpmCompilerHostVectorEnd - symbols.CpmCompilerHostVectorStart).toBe(50);
    expect(symbols.CpmCompilerResidentEnd).toBeLessThanOrEqual(
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
    // Native ATOM assembly runs on the host emulator; target sizes remain exact.
  }, 300_000);
});
