import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { createZ80Runtime, parseIntelHex } from "@jhlagado/debug80-runtime";
import { beforeAll, describe, expect, it } from "vitest";
import { assembleNativeDiagnostics } from "../scripts/assemble-native-diagnostics.mjs";

type Image = Awaited<ReturnType<typeof assembleNativeDiagnostics>>;
const baseline = JSON.parse(readFileSync(new URL(
  "./fixtures/native-diagnostics/baseline.json", import.meta.url,
), "utf8")) as {
  revision: string;
  profiles: Record<string, {
    hex: string; bytes: string; sha256: string;
    symbols: Record<string, number>; addresses: Record<string, number>;
    highWater: number; finalCursor: number;
  }>;
};
const word = (memory: Uint8Array, pointer: number, value: number) => {
  memory[pointer] = value & 0xff;
  memory[pointer + 1] = value >>> 8;
};
const normalStack = 0x3100;
const abortStack = 0x3200;
const normalReturn = 0x3000;
const abortReturn = 0x3010;

describe.each([false, true])("canonical diagnostics, nonlocal=%s", nonlocal => {
  let image: Image;
  beforeAll(async () => { image = await assembleNativeDiagnostics(nonlocal); });
  const address = (name: string) => {
    const value = image.symbols[name];
    if (value === undefined) throw new Error(`missing diagnostic symbol ${name}`);
    return value;
  };
  const freshMemory = () => {
    const memory = parseIntelHex(image.hex).memory.slice();
    memory[normalReturn] = 0x76;
    memory[abortReturn] = 0x76;
    word(memory, normalStack, normalReturn);
    word(memory, abortStack, abortReturn);
    if (nonlocal) word(memory, address("CompilerAbortSp"), abortStack);
    return memory;
  };
  const run = (memory: Uint8Array, entry: number, configure: (
    runtime: ReturnType<typeof createZ80Runtime>
  ) => void, unwinds: boolean) => {
    const runtime = createZ80Runtime({ memory, startAddress: entry }, entry);
    runtime.cpu.sp = normalStack;
    runtime.cpu.ix = 0x4567;
    runtime.cpu.iy = 0x89ab;
    configure(runtime);
    let steps = 0;
    while (!runtime.isHalted() && steps++ < 100) runtime.step();
    expect(runtime.isHalted()).toBe(true);
    expect(runtime.getPC()).toBe((unwinds ? abortReturn : normalReturn) + 1);
    expect(runtime.cpu.sp).toBe((unwinds ? abortStack : normalStack) + 2);
    expect(runtime.cpu.ix).toBe(0x4567);
    expect(runtime.cpu.iy).toBe(0x89ab);
    return runtime;
  };

  it("preserves frozen prefix bytes, all symbols, and exact write coverage", () => {
    expect(baseline.revision).toBe("5764b04ee488684f323069bc2bce80dcb7cd4411");
    const expected = baseline.profiles[nonlocal ? "nonlocal" : "local"]!;
    const parsed = parseIntelHex(image.hex);
    expect(image.hex).toBe(expected.hex);
    expect(Buffer.from(parsed.memory.slice(0, expected.highWater)).toString("hex")).toBe(expected.bytes);
    expect(createHash("sha256").update(parsed.memory.slice(0, expected.highWater)).digest("hex"))
      .toBe(expected.sha256);
    expect(image.symbols).toEqual(expected.symbols);
    expect(image.addresses).toEqual(expected.addresses);
    expect(image.generation.highWater).toBe(nonlocal ? 33 : 29);
    expect(image.generation.finalCursor).toBe(expected.finalCursor);
    expect(Object.keys(image.symbols)).toHaveLength(nonlocal ? 817 : 674);
    expect(Object.keys(image.addresses)).toHaveLength(7);
  });

  it("publishes the exact diagnostic and source part without changing its full-width position", () => {
    const memory = freshMemory();
    const position = [0xfe, 0xff, 0xff, 0xff, 0x80, 0xfe];
    memory.set(position, address("TokenStartOffset"));
    memory[address("SourcePartId")] = 0xb7;
    memory[address("DiagnosticCode") - 1] = 0x61;
    memory[address("DiagnosticPartId") + 1] = 0x62;
    const workBase = address("CompilerWorkBase");
    const workEnd = address("CompilerWorkLimit");
    const expectedWork = memory.slice(workBase, workEnd);
    expectedWork[address("DiagnosticCode") - workBase] = 0xa5;
    expectedWork[address("DiagnosticPartId") - workBase] = 0xb7;
    const result = run(memory, address("CompilerSetDiagnostic"), active => {
      active.cpu.a = 0xa5;
      active.cpu.b = 0x13;
      active.cpu.c = 0x57;
      active.cpu.d = 0x24;
      active.cpu.e = 0x68;
      active.cpu.h = 0x9a;
      active.cpu.l = 0xbc;
      active.cpu.flags.C = 0;
      active.cpu.flags.Z = 1;
    }, nonlocal);
    expect(result.cpu.a).toBe(0xb7);
    expect(result.cpu.flags.C).toBe(1);
    expect(result.cpu.flags.Z).toBe(1);
    expect([result.cpu.b, result.cpu.c, result.cpu.d, result.cpu.e, result.cpu.h, result.cpu.l])
      .toEqual([0x13, 0x57, 0x24, 0x68, 0x9a, 0xbc]);
    expect(result.hardware.memory.slice(workBase, workEnd)).toEqual(expectedWork);
  });

  it("consumes the inline diagnostic byte and bypasses the abandoned continuation", () => {
    const memory = freshMemory();
    const entry = 0x3300;
    const audit = 0x3350;
    const inline = address("SetDiagInline");
    // CALL inline; DB diagnostic; then a continuation that must not execute.
    memory.set([0xcd, inline & 0xff, inline >>> 8, 0x65,
      0x3e, 0xee, 0x32, audit & 0xff, audit >>> 8, 0xc9], entry);
    memory[audit] = 0x5a;
    memory[address("SourcePartId")] = 0x29;
    const result = run(memory, entry, () => undefined, nonlocal);
    expect(result.hardware.memory[address("DiagnosticCode")]).toBe(0x65);
    expect(result.hardware.memory[address("DiagnosticPartId")]).toBe(0x29);
    expect(result.hardware.memory[audit]).toBe(0x5a);
    expect(result.cpu.flags.C).toBe(1);
  });

  it.each([
    "CompilerCopyTokenPosition", "CompilerCopyPosition", "CompilerRestoreTokenPosition",
  ].flatMap(entry => [0, 1].flatMap(carry => [0, 1].map(zero => ({ entry, carry, zero })))))
  ("copies six bytes through $entry preserving C=$carry Z=$zero", ({ entry, carry, zero }) => {
    const memory = freshMemory();
    const token = address("TokenStartOffset");
    const from = entry === "CompilerCopyTokenPosition" ? token : 0x3400;
    const to = entry === "CompilerRestoreTokenPosition" ? token : 0x3500;
    const record = [0xff, 0xff, 0x00, 0x80, 0xfe, 0xff];
    memory.fill(0xa5, from - 1, from + 7);
    memory.set(record, from);
    memory.fill(0x5a, to - 1, to + 7);
    const result = run(memory, address(entry), active => {
      active.cpu.a = 0x77;
      active.cpu.h = from >>> 8;
      active.cpu.l = from & 0xff;
      active.cpu.d = to >>> 8;
      active.cpu.e = to & 0xff;
      active.cpu.flags.C = carry;
      active.cpu.flags.Z = zero;
    }, false);
    expect([...result.hardware.memory.slice(from - 1, from + 7)]).toEqual([0xa5, ...record, 0xa5]);
    expect([...result.hardware.memory.slice(to - 1, to + 7)]).toEqual([0x5a, ...record, 0x5a]);
    expect(result.cpu.b * 256 + result.cpu.c).toBe(0);
    expect(result.cpu.h * 256 + result.cpu.l).toBe(from + 6);
    expect(result.cpu.d * 256 + result.cpu.e).toBe(to + 6);
    expect(result.cpu.a).toBe(0x77);
    expect(result.cpu.flags.C).toBe(carry);
    expect(result.cpu.flags.Z).toBe(zero);
  });

  it("uses the unchanged canonical diagnostic leaf and only official preprocessing blanks", () => {
    expect(image.project.parts.map(part => part.logicalIdentity))
      .toContain("asm/vertical-slice/compiler-diagnostics.asm");
    for (const part of image.project.parts) {
      expect(Buffer.from(part.originalBytes)).toEqual(readFileSync(
        new URL(`../${part.logicalIdentity}`, import.meta.url),
      ));
      expect(part.compilerBytes).toHaveLength(part.originalBytes.length);
      for (let i = 0; i < part.originalBytes.length; i++) {
        if (part.originalBytes[i] !== part.compilerBytes[i]) expect(part.compilerBytes[i]).toBe(32);
      }
    }
  });
});

it("assembles the canonical diagnostic leaf without the transitional adapter", () => {
  const refusal = "diagnostic legacy adapter unavailable";
  const loader = `export async function resolve(specifier, context, nextResolve) {
    if (specifier.endsWith("atom-source.mjs") || specifier.endsWith("atom-source-translation.mjs")) throw new Error(${JSON.stringify(refusal)});
    const result = await nextResolve(specifier, context);
    if (result.url.endsWith("/scripts/atom-source.mjs") ||
        result.url.endsWith("/scripts/atom-source-translation.mjs")) throw new Error(${JSON.stringify(refusal)});
    return result;
  }`;
  const legacy = new URL("../scripts/atom-source.mjs", import.meta.url).href;
  const helper = new URL("../scripts/assemble-native-diagnostics.mjs", import.meta.url).href;
  const script = `
    let blocked = false;
    try { await import(${JSON.stringify(legacy)}); }
    catch (error) {
      if (error.message !== ${JSON.stringify(refusal)}) throw error;
      blocked = true;
    }
    if (!blocked) throw new Error("legacy guard inactive");
    const { assembleNativeDiagnostics } = await import(${JSON.stringify(helper)});
    process.stdout.write(JSON.stringify([
      (await assembleNativeDiagnostics(false)).hex, (await assembleNativeDiagnostics(true)).hex
    ]));
  `;
  const output = execFileSync(process.execPath, [
    "--no-warnings", "--experimental-loader", `data:text/javascript,${encodeURIComponent(loader)}`,
    "--input-type=module", "--eval", script,
  ], { encoding: "utf8", timeout: 30_000, maxBuffer: 1024 * 1024 });
  expect(JSON.parse(output)).toEqual([baseline.profiles.local!.hex, baseline.profiles.nonlocal!.hex]);
}, 35_000);
