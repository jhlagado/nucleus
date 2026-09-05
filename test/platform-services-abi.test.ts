import { createZ80Runtime, parseIntelHex } from "@jhlagado/debug80-runtime";
import { describe, expect, it } from "vitest";
import { assembleNativeNobj } from "../scripts/assemble-native-nobj.mjs";

describe("the Z80 platform-services ABI", () => {
  it("preserves the contracted state across executable adapter stubs", async () => {
    const assembled = await assembleNativeNobj(
      "platform-services-abi-proof.asm",
    );
    const symbols = assembled.symbols;
    const memory = parseIntelHex(assembled.hex).memory;
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
    expect(finalMemory[symbols.ProofObjectRequest + 4]).toBe(0x12);
    expect(finalMemory[symbols.ProofObjectRequest + 5]).toBe(0x34);
  });
});
