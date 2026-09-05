import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { createZ80Runtime, parseIntelHex } from "@jhlagado/debug80-runtime";
import { beforeAll, describe, expect, it } from "vitest";
import { assembleNativeCpmHostVector, assembleNativeHostBindings } from "../scripts/assemble-native-host-bindings.mjs";
import * as shipped from "../src/generated-compiler-images.js";

type Image = Awaited<ReturnType<typeof assembleNativeHostBindings>>;
type Profile = {
  symbols: Record<string, number>; addresses: Record<string, number>;
  start: number; end: number; hex: string; sha256: string;
  highWater: number; finalCursor: number; bindings: Record<string, number>;
};
const load = (name: string) => JSON.parse(readFileSync(
  new URL(`./fixtures/native-host-bindings/${name}.json`, import.meta.url), "utf8",
)) as { revision: string; profiles: Record<string, Profile> };
const baseline = load("baseline"), cpmBaseline = load("cpm-baseline");
const revision = "5764b04";
const cases = [
  { name: "node", mon3: 0, debug: 0, symbols: shipped.nativeCompilerSymbols },
  { name: "node-debug", mon3: 0, debug: 1, symbols: shipped.nativeDebugCompilerSymbols },
  { name: "mon3", mon3: 1, debug: 0, symbols: shipped.mon3CompilerSymbols },
  { name: "mon3-debug", mon3: 1, debug: 1, symbols: shipped.mon3DebugCompilerSymbols },
] as const;
const points = (ranges: readonly { start: number; end: number }[]) =>
  ranges.flatMap(({ start, end }) => Array.from({ length: end - start }, (_, i) => start + i));
function equivalent(actual: Image, expected: Profile) {
  const parsed = parseIntelHex(actual.hex);
  expect(points(parsed.writeRanges ?? [])).toEqual(points([expected]));
  const bytes = parsed.memory.slice(expected.start, expected.end);
  expect(Buffer.from(bytes).toString("hex")).toBe(expected.hex);
  expect(createHash("sha256").update(bytes).digest("hex")).toBe(expected.sha256);
  expect(actual.symbols).toEqual(expected.symbols);
  expect(actual.addresses).toEqual(expected.addresses);
  expect(actual.generation.highWater).toBe(expected.highWater);
  expect(actual.generation.finalCursor).toBe(expected.finalCursor);
}
const word = (memory: Uint8Array, at: number, value: number) => {
  memory[at] = value & 255; memory[at + 1] = value >>> 8;
};
const stack = 0xf000, sentinel = 0xf100;
function machine(image: Image, port: (port: number, cpu: ReturnType<typeof createZ80Runtime>["cpu"]) => void) {
  const memory = parseIntelHex(image.hex).memory.slice();
  if (image.symbols.Mon3HostTransport) memory.set([0xd3, image.symbols.NativeHostMon3NodePort!, 0xc9], 0x10);
  let runtime!: ReturnType<typeof createZ80Runtime>;
  runtime = createZ80Runtime({ memory, startAddress: 0 }, 0, {
    write: p => port(p & 255, runtime.cpu),
  });
  return runtime;
}
function invoke(runtime: ReturnType<typeof createZ80Runtime>, entry: number, ix = 0) {
  runtime.hardware.memory[sentinel] = 0x76;
  word(runtime.hardware.memory, stack, sentinel);
  runtime.cpu.sp = stack; runtime.cpu.pc = entry; runtime.cpu.ix = ix; runtime.cpu.halted = false;
  for (let count = 0; !runtime.isHalted() && count < 10_000; count++) runtime.step();
  expect(runtime.isHalted()).toBe(true);
  expect(runtime.getPC()).toBe(sentinel + 1);
  expect(runtime.cpu.sp).toBe(stack + 2);
}

describe("native host bindings from canonical source", () => {
  const images = new Map<string, Image>();
  // Four fresh ATOM assemblies took 11 seconds on Linux CI. Use the same
  // host allowance as the isolated four-profile assembly below; guest limits
  // and every byte, register, flag and stack assertion remain unchanged.
  beforeAll(async () => {
    for (const config of cases) images.set(config.name, await assembleNativeHostBindings(config));
  }, 30_000);

  it("pins both transports and both debug profiles to the frozen revision", () => {
    expect(baseline.revision.startsWith(revision)).toBe(true);
    expect(Object.keys(baseline.profiles)).toEqual(cases.map(c => c.name));
  });

  it.each(cases)("preserves exact $name host bytes, all exports and five compiler links", config => {
    const actual = images.get(config.name)!, expected = baseline.profiles[config.name]!;
    equivalent(actual, expected);
    expect(expected.end - expected.start).toBe(config.mon3 ? 981 + 2 * config.debug : 913 + 2 * config.debug);
    expect(Object.keys(actual.symbols)).toHaveLength(config.mon3 ? 944 : 934);
    for (const [name, address] of Object.entries(expected.bindings)) {
      expect(actual.symbols[name], name).toBe(address);
      expect(config.symbols[name], `${name}: test-only link drifted from the real compiler`).toBe(address);
    }
    expect(Object.keys(expected.bindings).sort()).toEqual([
      "CompileTargetAggregateCallParts", "CompilerCopyPosition", "SetDiagInline",
      "SourceInitialize", "SourcePartCapacityFailure",
    ]);
    expect(actual.symbols.NativeHostWorkspaceEnd! - actual.symbols.NativeHostWorkspaceBase!)
      .toBe(config.mon3 ? 24 : 22);
  });

  it.each(cases)("uses original source and the vector/source/shell ordering for $name", config => {
    const actual = images.get(config.name)!;
    const parts = actual.project.parts;
    const order = ["native-host-state.asmi", "native-host-vector-body.asmi", "native-source-host.asm", "native-host-shell.asm", "native-host-vector.asmi"]
      .map(file => parts.findIndex(part => part.logicalIdentity === `asm/vertical-slice/${file}`));
    expect(order.every(index => index >= 0)).toBe(true);
    expect(order).toEqual([...order].sort((a, b) => a - b));
    for (const part of parts) {
      expect(Buffer.from(part.originalBytes)).toEqual(readFileSync(new URL(`../${part.logicalIdentity}`, import.meta.url)));
      expect(part.compilerBytes).toHaveLength(part.originalBytes.length);
      for (let i = 0; i < part.originalBytes.length; i++) {
        if (part.originalBytes[i] !== part.compilerBytes[i]) expect(part.compilerBytes[i]).toBe(32);
      }
    }
  });

  it.each(cases)("initializes and resets $name host state with exact return control", config => {
    const image = images.get(config.name)!, s = image.symbols;
    let aborts = 0, finishes = 0, failAbort = false;
    const runtime = machine(image, (port, cpu) => {
      const selector = config.mon3 ? cpu.c - s.NativeHostMon3ServiceBase! : port - s.NativeHostSourceNextChunkPort!;
      expect([13, 15]).toContain(selector);
      if (config.mon3) expect(port).toBe(s.NativeHostMon3NodePort);
      if (selector === 13) aborts++; else finishes++;
      cpu.a = selector === 13 && failAbort ? 3 : 0;
      cpu.flags.C = selector === 13 && failAbort ? 1 : 0;
    });
    const m = runtime.hardware.memory, start = s.NativeHostWorkspaceBase!, end = s.NativeHostWorkspaceEnd!;
    m.fill(0xa5, start, end); m[start - 1] = 0x5a; m[end] = 0xa5;
    invoke(runtime, s.NucleusHostInitialize!);
    expect([...m.slice(start, end)]).toEqual(Array(end - start).fill(0));
    expect([aborts, finishes]).toEqual([0, 0]);
    for (const failure of [false, true]) {
      failAbort = failure; m.fill(0xa5, start, end); m[s.NativeHostLaunchActive!] = 1;
      invoke(runtime, s.NucleusHostReset!);
      expect([...m.slice(start, end)]).toEqual(Array(end - start).fill(0));
      expect(runtime.cpu.a).toBe(failure ? 3 : 0);
      expect(runtime.cpu.flags.C).toBe(failure ? 1 : 0);
    }
    expect([aborts, finishes]).toEqual([2, 2]);
    expect([m[start - 1], m[end]]).toEqual([0x5a, 0xa5]);
  });

  it.each(cases)("rejects an invalid $name launch without calling the missing compiler", config => {
    const image = images.get(config.name)!, s = image.symbols;
    const runtime = machine(image, () => { throw new Error("invalid descriptor reached a provider"); });
    const m = runtime.hardware.memory, descriptor = 0xe000, result = 0xe020;
    invoke(runtime, s.NucleusHostInitialize!);
    m.fill(0, descriptor, descriptor + 14); word(m, descriptor + 8, result);
    m.fill(0xa5, result, result + 9); // Size zero is invalid; a result pointer is still supplied.
    invoke(runtime, s.NucleusHostCompile!, descriptor);
    expect([...m.slice(result, result + 9)]).toEqual([2, 4, 0, 0, 0, 0, 0, 0, 0]);
    expect([runtime.cpu.a, runtime.cpu.flags.C]).toEqual([2, 1]);
  });

  it("assembles all four host profiles with both historical translators blocked", () => {
    const refusal = "legacy host assembly disabled";
    const loader = `export async function resolve(s,c,next) {
    if (s.endsWith("atom-source.mjs") || s.endsWith("atom-source-translation.mjs")) throw new Error(${JSON.stringify(refusal)}); const r=await next(s,c); if (/\\/scripts\\/atom-source(?:-translation)?\\.mjs$/.test(r.url)) throw Error(${JSON.stringify(refusal)}); return r; }`;
    const helper = new URL("../scripts/assemble-native-host-bindings.mjs", import.meta.url).href;
    const legacy = new URL("../scripts/atom-source.mjs", import.meta.url).href;
    const script = `let blocked=false; try { await import(${JSON.stringify(legacy)}); } catch(e) { if(e.message!==${JSON.stringify(refusal)}) throw e; blocked=true; } if(!blocked) throw Error('guard inactive'); const {assembleNativeHostBindings}=await import(${JSON.stringify(helper)}); const out=[]; for(const mon3 of [0,1]) for(const debug of [0,1]) { const a=await assembleNativeHostBindings({mon3,debug}); out.push({hex:a.hex,symbols:a.symbols,addresses:a.addresses}); } process.stdout.write(JSON.stringify(out));`;
    const result = JSON.parse(execFileSync(process.execPath, ["--no-warnings", "--experimental-loader", `data:text/javascript,${encodeURIComponent(loader)}`, "--input-type=module", "--eval", script], { encoding: "utf8", timeout: 30_000, maxBuffer: 2 * 1024 * 1024 }));
    expect(result).toEqual(cases.map(c => {
      const { hex, symbols, addresses } = images.get(c.name)!; return { hex, symbols, addresses };
    }));
  }, 35_000);
});

describe("native CP/M compiler host vector", () => {
  it.each([0x100, 0x8013])("preserves all 104 bytes and exports at origin %i", async origin => {
    const actual = await assembleNativeCpmHostVector({ origin });
    expect(cpmBaseline.revision.startsWith(revision)).toBe(true);
    equivalent(actual, cpmBaseline.profiles[origin]!);
    expect(Object.keys(actual.symbols)).toHaveLength(34);
    const s = actual.symbols;
    for (const [wrapper, provider] of [
      ["CpmCompilerPatchWord", "CpmDirectPatchWord"],
      ["CpmCompilerCommit", "CpmDirectCommit"],
      ["CpmCompilerAbort", "CpmDirectAbort"],
    ]) {
      const runtime = machine(actual, () => { throw new Error("CP/M wrapper used a host port"); });
      // Fake provider destroys every promised preserved pair, then returns A/flags.
      runtime.hardware.memory.set([0x01,0xbb,0xaa,0x11,0xdd,0xcc,0x21,0xff,0xee,0xdd,0x21,0x22,0x11,0xfd,0x21,0x44,0x33,0x3e,5,0xb7,0x37,0xc9], s[provider!]!);
      Object.assign(runtime.cpu, { b: 0x12, c: 0x34, d: 0x56, e: 0x78, h: 0x9a, l: 0xbc, iy: 0x4321 });
      invoke(runtime, s[wrapper!]!, 0xdef0);
      expect([runtime.cpu.b,runtime.cpu.c,runtime.cpu.d,runtime.cpu.e,runtime.cpu.h,runtime.cpu.l,runtime.cpu.ix,runtime.cpu.iy])
        .toEqual([0x12,0x34,0x56,0x78,0x9a,0xbc,0xdef0,0x4321]);
      expect([runtime.cpu.a,runtime.cpu.flags.C,runtime.cpu.flags.Z]).toEqual([5,1,0]);
    }
  });
});
