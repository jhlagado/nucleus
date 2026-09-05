import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { assembleNativeProof, isNativeProofEntry } from "../scripts/assemble-native-proof.mjs";

const frozen = JSON.parse(readFileSync(
  new URL("./fixtures/native-early-proof-baseline.json", import.meta.url), "utf8",
)) as {
  revision: string;
  profiles: { entry: string; hex: string; symbols: Record<string, number>;
    addresses: Record<string, number>; definitions: Record<string, number> }[];
};
const entries = [
  "memory-map-proof.asm", "dispatcher-measurement.asm",
  "dispatcher-offset-direct-measurement.asm", "dispatcher-offset-trampoline-measurement.asm",
  "compiler-slice-proof.asm", "z80-slice-proof.asm", "loop-compiler-slice-proof.asm",
  "loop-z80-slice-proof.asm", "cpm22-compiler-layout-proof.asm",
];

describe("native ATOM early compiler and layout proofs", () => {
  it("pins the complete nine-entry pre-conversion baseline", () => {
    expect(frozen.revision).toBe("1cb0331e0802e4faca1d93621a498d62fa670b1e");
    expect(frozen.profiles.map(profile => profile.entry)).toEqual(entries);
    expect(isNativeProofEntry("toString")).toBe(false);
  });
  it("rejects unknown entries without a legacy fallback", async () => {
    await expect(assembleNativeProof("unknown.asm")).rejects.toThrow("Unsupported native proof entry");
  });
  for (const old of frozen.profiles) {
    it(`${old.entry}: preserves every byte, public binding and address classification`, async () => {
      const actual = await assembleNativeProof(old.entry);
      expect(actual.hex).toBe(old.hex);
      expect(actual.symbols).toEqual(old.symbols);
      expect(actual.addresses).toEqual(old.addresses);
      expect(actual.project.parts.map(part => part.logicalIdentity))
        .toContain(`asm/vertical-slice/${old.entry}`);
      for (const part of actual.project.parts) {
        expect(Buffer.from(part.originalBytes)).toEqual(readFileSync(
          new URL(`../${part.logicalIdentity}`, import.meta.url),
        ));
        expect(part.originalBytes.length).toBeLessThanOrEqual(0xffff);
        expect(part.compilerBytes.length).toBe(part.originalBytes.length);
        for (let index = 0; index < part.originalBytes.length; index++) {
          if (part.originalBytes[index] !== part.compilerBytes[index])
            expect(part.compilerBytes[index]).toBe(32);
        }
      }
    }, 180_000);
  }
});
