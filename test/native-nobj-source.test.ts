import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { parseIntelHex } from "@jhlagado/debug80-runtime";
import { beforeAll, describe, expect, it } from "vitest";
import { assembleNativeNobj, isNativeNobjEntry } from "../scripts/assemble-native-nobj.mjs";

const baseline = JSON.parse(readFileSync(new URL("./fixtures/native-nobj/fixed-baseline.json", import.meta.url), "utf8")) as {
  revision: string;
  entries: Record<string, { hex: string; symbols: Record<string, number>; addresses: Record<string, number>; highWater: number; finalCursor: number }>;
};
type Image = Awaited<ReturnType<typeof assembleNativeNobj>>;
const fresh = new Map<string, Image>();
beforeAll(async () => {
  for (const entry of Object.keys(baseline.entries)) fresh.set(entry, await assembleNativeNobj(entry));
}, 120_000);

const deployed = ["node-nobj-consumer", "nobj-consumer-flat-proof", "nobj-consumer-banked-proof", "nobj-consumer-control-top-proof"];

describe("native NOBJ production runner and service closure", () => {
  it("pins the complete eight-entry qualification matrix", () => {
    expect(Object.keys(baseline.entries)).toEqual([
      "node-nobj-consumer.asm",
      "nobj-consumer-flat-proof.asm",
      "nobj-consumer-banked-proof.asm",
      "nobj-consumer-control-top-proof.asm",
      "nobj-runner-proof.asm",
      "object-services-node-proof.asm",
      "runtime-catalog-services-node-proof.asm",
      "platform-services-abi-proof.asm",
    ]);
  });

  it.each(Object.keys(baseline.entries))("preserves every byte, export and address classification: %s", entry => {
    expect(baseline.revision).toBe("1cb0331e0802e4faca1d93621a498d62fa670b1e");
    const actual = fresh.get(entry)!;
    const expected = baseline.entries[entry]!;
    expect(actual.hex).toBe(expected.hex);
    expect(actual.symbols).toEqual(expected.symbols);
    expect(actual.addresses).toEqual(expected.addresses);
    expect(actual.generation.highWater).toBe(expected.highWater);
    expect(actual.generation.finalCursor).toBe(expected.finalCursor);
    const parsed = parseIntelHex(actual.hex);
    const old = parseIntelHex(expected.hex);
    expect(parsed.writeRanges).toEqual(old.writeRanges);
    expect(parsed.memory).toEqual(old.memory);
    const stem = entry.replace(/\.asm$/, "");
    const expectedParts = deployed.includes(stem) ? [
      `${stem}-layout.asmi`, "nobj-consumer-state.asmi",
      ...(stem === "node-nobj-consumer" ? ["platform-services-abi.asmi"] : []),
      `${stem}-start.asm`, "nobj-consumer.asm", `${stem}-tail.asm`, `${stem}.asm`,
    ] : entry === "nobj-runner-proof.asm" ? [entry] : ["platform-services-abi.asmi", entry];
    expect(actual.project.parts.map(part => part.logicalIdentity)).toEqual(expectedParts.map(name => `asm/vertical-slice/${name}`));
    for (const part of actual.project.parts) {
      const disk = readFileSync(new URL(`../${part.logicalIdentity}`, import.meta.url));
      expect(Buffer.from(part.originalBytes)).toEqual(disk);
      // Only ATOM's own dependency directives are blanked; input assembly is
      // already canonical, with neither aliases nor expressions rewritten.
      expect(Buffer.from(part.compilerBytes).toString()).toBe(disk.toString().replace(/^%INCLUDE[^\r\n]*/gm, line => " ".repeat(line.length)));
    }
  });

  it("keeps full-width host memory separate from the consumer's real zero sentinel", () => {
    const runner = fresh.get("nobj-runner-proof.asm")!;
    expect(runner.symbols.ProofMemoryEnd).toBe(65536);
    expect(runner.generation.symbols.find(symbol => symbol.name === "LPMEMEND")?.value).toBe(65535);
    expect(runner.symbols).not.toHaveProperty("LPLOGLEN");
    expect(runner.addresses).not.toHaveProperty("ProofMemoryEnd");
    expect(runner.addresses).not.toHaveProperty("LPLOGLEN");
    expect(runner.generation.symbols.find(symbol => symbol.name === "LPLOGLEN")?.value).toBe(20);
    const source = readFileSync(new URL("../asm/vertical-slice/nobj-runner-proof.asm", import.meta.url), "utf8");
    const uses = source.split(/\r?\n/).map(line => line.split(";")[0]!).filter(line => /\bLPMEMEND\b/.test(line));
    expect(uses).toEqual(["LPMEMEND   EQU $FFFF"]);
    expect(fresh.get("nobj-consumer-control-top-proof.asm")!.symbols.NobjConsumerControlLimit).toBe(0);
  });

  it("builds the production runner with both historical adaptation modules unavailable", () => {
    const refusal = "historical adaptation unavailable";
    const loader = `export async function resolve(specifier, context, nextResolve) {
      if (/\\/scripts\\/atom-source(?:-translation)?\\.mjs$/.test(specifier)) throw new Error(${JSON.stringify(refusal)});
      const resolved = await nextResolve(specifier, context);
      if (/\\/scripts\\/atom-source(?:-translation)?\\.mjs$/.test(resolved.url)) throw new Error(${JSON.stringify(refusal)});
      return resolved;
    }`;
    const helper = new URL("../scripts/assemble-native-nobj.mjs", import.meta.url).href;
    const legacy = new URL("../scripts/atom-source.mjs", import.meta.url).href;
    const script = `let blocked=false; try { await import(${JSON.stringify(legacy)}); } catch(error) {
      if(error.message!==${JSON.stringify(refusal)}) throw error; blocked=true;
    } if(!blocked) throw new Error("guard inactive");
    const {assembleNativeNobj}=await import(${JSON.stringify(helper)});
    const {hex,symbols}=await assembleNativeNobj("node-nobj-consumer.asm");
    process.stdout.write(JSON.stringify({hex,symbols}));`;
    const produced = JSON.parse(execFileSync(process.execPath, ["--no-warnings", "--experimental-loader", `data:text/javascript,${encodeURIComponent(loader)}`, "--input-type=module", "--eval", script], { encoding: "utf8", timeout: 30_000, maxBuffer: 1024 * 1024 }));
    expect(produced).toEqual({ hex: baseline.entries["node-nobj-consumer.asm"]!.hex, symbols: baseline.entries["node-nobj-consumer.asm"]!.symbols });
  }, 35_000);

  it("rejects unrelated entries without an assembler fallback", async () => {
    expect(Object.keys(baseline.entries).every(isNativeNobjEntry)).toBe(true);
    expect(isNativeNobjEntry("flat-target-compiler-image.asm")).toBe(false);
    await expect(assembleNativeNobj("flat-target-compiler-image.asm")).rejects.toThrow("Unsupported native NOBJ entry");
  });
});
