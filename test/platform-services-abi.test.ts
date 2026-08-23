import { compile } from "@jhlagado/azm/compile";
import { createZ80Runtime, parseIntelHex } from "@jhlagado/debug80-runtime";
import { describe, expect, it } from "vitest";

describe("the Z80 platform-services ABI", () => {
  it("preserves the contracted state across executable adapter stubs", async () => {
    const source = new URL(
      "../asm/vertical-slice/platform-services-abi-proof.asm",
      import.meta.url,
    ).pathname;
    const assembled = await compile(source, {
      emitHex: true,
      emitD8m: true,
      registerContracts: "strict",
    });
    expect(
      assembled.diagnostics.filter(({ severity }) => severity === "error"),
    ).toEqual([]);
    const hex = assembled.artifacts.find(({ kind }) => kind === "hex");
    const map = assembled.artifacts.find(({ kind }) => kind === "d8m");
    if (hex?.kind !== "hex" || map?.kind !== "d8m") {
      throw new Error("AZM omitted platform ABI proof artifacts");
    }
    const symbols = Object.fromEntries(
      map.json.symbols.flatMap((entry) => {
        const value = entry.address ?? entry.value;
        return value === undefined ? [] : [[entry.name, value]];
      }),
    );
    const memory = parseIntelHex(hex.text).memory;
    const runtime = createZ80Runtime(
      { memory, startAddress: symbols.ProofStart },
      symbols.ProofStart,
    );
    let guard = 0;
    while (!runtime.isHalted() && guard++ < 1_000) runtime.step();
    expect(runtime.isHalted()).toBe(true);
    const finalMemory = runtime.hardware.memory;
    expect(finalMemory[symbols.ProofResult]).toBe(0);
    expect(finalMemory[symbols.ProofPacketBc]).toBe(0x34);
    expect(finalMemory[symbols.ProofPacketBc + 1]).toBe(0x12);
    expect(finalMemory[symbols.ProofSelectedBank]).toBe(1);
  });
});
