import { createHash } from "node:crypto";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";

import { assembleNativeSourcePlanProof } from "../scripts/assemble-native-import-resolver.mjs";
import { createZ80Runtime, parseIntelHex } from "@jhlagado/debug80-runtime";
import { afterEach, describe, expect, it } from "vitest";

import {
  NodeNamedObjectServices,
  NucleusSystemStatus,
} from "../src/object-services.js";

interface SourceEvent {
  readonly event: number;
  readonly part: number;
  readonly bytes: Uint8Array;
}

const baseline = JSON.parse(readFileSync(new URL(
  "./fixtures/native-source-plan-baseline.json", import.meta.url,
), "utf8")) as {
  revision: string;
  symbols: Record<string, number>;
  addresses: Record<string, number>;
  highWater: number;
  finalCursor: number;
  segments: { start: number; end: number; hex: string; sha256: string }[];
};

describe("the native Z80 SP1 source-plan provider", () => {
  const roots: string[] = [];
  afterEach(() => {
    for (const root of roots.splice(0)) rmSync(root, { recursive: true, force: true });
  });

  it("preserves the original sparse image and every public symbol under native ATOM", async () => {
    const proof = await assembleNativeSourcePlanProof();
    const parsed = parseIntelHex(proof.hex);
    expect(baseline.revision).toBe("abbb2bea1b20d6ccfe11bdf936f48b525b0d88a6");
    const addresses = (ranges: readonly { start: number; end: number }[]) =>
      ranges.flatMap(({ start, end }) => Array.from({ length: end - start }, (_, i) => start + i));
    expect(baseline.segments.map(({ start, end }) => ({ start, end }))).toEqual([
      { start: 0x0010, end: 0x0013 },
      { start: 0x4000, end: 0x4013 },
      { start: 0x4200, end: 0x4724 },
    ]);
    expect(addresses(parsed.writeRanges ?? [])).toEqual(addresses(baseline.segments));
    for (const segment of baseline.segments) {
      const bytes = parsed.memory.slice(segment.start, segment.end);
      expect(Buffer.from(bytes).toString("hex")).toBe(segment.hex);
      expect(createHash("sha256").update(bytes).digest("hex")).toBe(segment.sha256);
    }
    expect(Object.keys(proof.symbols)).toHaveLength(181);
    expect(proof.symbols).toEqual(baseline.symbols);
    expect(Object.keys(proof.addresses)).toHaveLength(67);
    expect(proof.addresses).toEqual(baseline.addresses);
    expect(proof.generation.highWater).toBe(baseline.highWater);
    expect(proof.generation.finalCursor).toBe(baseline.finalCursor);
    expect(proof.generation.highWater).toBe(0x4724);
    for (const part of proof.project.parts) {
      const original = new TextDecoder().decode(part.originalBytes);
      expect(new TextDecoder().decode(part.compilerBytes)).toBe(
        original.replace(/^%INCLUDE[^\r\n]*/gm, line => " ".repeat(line.length)),
      );
    }
  });

  it("streams ordered named sources through the four-event compiler ABI", async () => {
    const { hex, symbols } = await assembleNativeSourcePlanProof();

    const root = mkdtempSync(path.join(tmpdir(), "nucleus-source-provider-"));
    roots.push(root);
    mkdirSync(path.join(root, ".nucleus"));
    writeFileSync(
      path.join(root, ".nucleus", "source-plan.sp1"),
      "SP1 2\nP 0 6 lib.nu\nP 0 7 main.nu\nEND\n",
    );
    writeFileSync(path.join(root, "lib.nu"), "AB");
    writeFileSync(path.join(root, "main.nu"), "CDE");
    const services = new NodeNamedObjectServices(root);
    const objectCalls: string[] = [];
    let runtime: ReturnType<typeof createZ80Runtime>;
    runtime = createZ80Runtime(
      {
        memory: parseIntelHex(hex).memory,
        startAddress: symbols.ProofInitialize,
      },
      symbols.ProofInitialize,
      {
        write: (port) => {
          if ((port & 0xff) !== symbols.ObjectNodeGatewayPort) {
            throw new Error(`unexpected proof port ${port & 0xff}`);
          }
          expect(runtime.cpu.c).toBe(symbols.NucleusServiceObject);
          const request = (runtime.cpu.h << 8) | runtime.cpu.l;
          const status = services.dispatch(runtime.hardware.memory, request);
          objectCalls.push(
            `${runtime.hardware.memory[request + 2]}:${status}:${runtime.hardware.memory[request + 14] | (runtime.hardware.memory[request + 15]! << 8)}`,
          );
          runtime.cpu.a = status;
          runtime.cpu.flags.C =
            status === NucleusSystemStatus.success ? 0 : 1;
        },
      },
    );

    const run = (entry: number): void => {
      const stack = 0x7f00;
      runtime.hardware.memory[stack] = symbols.ProofReturnSentinel & 0xff;
      runtime.hardware.memory[stack + 1] =
        symbols.ProofReturnSentinel >>> 8;
      runtime.cpu.sp = stack;
      runtime.cpu.pc = entry;
      runtime.cpu.halted = false;
      let guard = 0;
      while (!runtime.isHalted() && guard++ < 20_000) runtime.step();
      expect(runtime.isHalted()).toBe(true);
      expect(runtime.cpu.pc).toBe(symbols.ProofReturnSentinel + 1);
      expect(
        runtime.cpu.flags.C,
        `entry $${entry.toString(16)} failed with A=${runtime.cpu.a}; object calls ${objectCalls.join(",")}`,
      ).toBe(0);
      expect(runtime.cpu.sp).toBe(stack + 2);
    };

    run(symbols.ProofInitialize);
    const next = (): SourceEvent => {
      run(symbols.ProofNext);
      const event = runtime.cpu.a;
      const count = (runtime.cpu.d << 8) | runtime.cpu.e;
      const pointer = (runtime.cpu.h << 8) | runtime.cpu.l;
      return {
        event,
        part: runtime.cpu.c,
        bytes:
          event === 0
            ? runtime.hardware.memory.slice(pointer, pointer + count)
            : new Uint8Array(),
      };
    };
    const events: SourceEvent[] = [next(), next()];

    const tokenPointer = symbols.NativeSourceChunkBase;
    runtime.cpu.h = tokenPointer >>> 8;
    runtime.cpu.l = tokenPointer & 0xff;
    runtime.cpu.b = 2;
    runtime.cpu.c = 1;
    runtime.cpu.d = 0;
    runtime.cpu.e = 0;
    run(symbols.ProofRetainName);
    const retainedHandle = (runtime.cpu.h << 8) | runtime.cpu.l;
    expect(retainedHandle).not.toBe(0);
    expect(runtime.cpu.b).toBe(2);
    expect(runtime.cpu.c).toBe(1);
    expect((runtime.cpu.d << 8) | runtime.cpu.e).toBe(0);
    expect(
      runtime.hardware.memory[symbols.NativeSourceProviderNamesEnd] |
        (runtime.hardware.memory[symbols.NativeSourceProviderNamesEnd + 1]! <<
          8),
    ).toBe(6);

    runtime.cpu.h = retainedHandle >>> 8;
    runtime.cpu.l = retainedHandle & 0xff;
    runtime.cpu.ix = tokenPointer;
    runtime.cpu.b = 2;
    run(symbols.ProofCompareName);
    expect(runtime.cpu.flags.Z).toBe(1);

    runtime.hardware.memory.set(Buffer.from("AX"), 0x7400);
    runtime.cpu.h = retainedHandle >>> 8;
    runtime.cpu.l = retainedHandle & 0xff;
    runtime.cpu.ix = 0x7400;
    runtime.cpu.b = 2;
    run(symbols.ProofCompareName);
    expect(runtime.cpu.flags.Z).toBe(0);

    runtime.cpu.h = retainedHandle >>> 8;
    runtime.cpu.l = retainedHandle & 0xff;
    runtime.cpu.c = 0x55;
    runtime.cpu.d = 0x12;
    runtime.cpu.e = 0x34;
    run(symbols.ProofMaterializeName);
    const materialized = (runtime.cpu.h << 8) | runtime.cpu.l;
    expect(runtime.cpu.b).toBe(2);
    expect(runtime.cpu.c).toBe(0x55);
    expect((runtime.cpu.d << 8) | runtime.cpu.e).toBe(0x1234);
    expect(
      Buffer.from(
        runtime.hardware.memory.subarray(materialized, materialized + 2),
      ).toString("ascii"),
    ).toBe("AB");

    runtime.cpu.h = materialized >>> 8;
    runtime.cpu.l = materialized & 0xff;
    runtime.cpu.b = 2;
    runtime.cpu.c = 1;
    runtime.cpu.d = 0;
    runtime.cpu.e = 0;
    run(symbols.ProofRetainName);
    expect((runtime.cpu.h << 8) | runtime.cpu.l).toBe(retainedHandle);
    expect(
      runtime.hardware.memory[symbols.NativeSourceProviderNamesEnd] |
        (runtime.hardware.memory[symbols.NativeSourceProviderNamesEnd + 1]! <<
          8),
    ).toBe(6);

    for (let ordinal = 0; ordinal < 5; ordinal += 1) events.push(next());
    expect(
      events.map(({ event, part, bytes }) => [
        event,
        event === 3 ? null : part,
        Buffer.from(bytes).toString("ascii"),
      ]),
    ).toEqual([
      [1, 1, ""],
      [0, 1, "AB"],
      [2, 1, ""],
      [1, 2, ""],
      [0, 2, "CDE"],
      [2, 2, ""],
      [3, null, ""],
    ]);
    run(symbols.ProofFinish);
    expect(services.openHandleCount).toBe(0);
    expect(
      symbols.NativeSourceProviderCodeEnd -
        symbols.NativeSourceProviderCodeStart,
    ).toBeLessThanOrEqual(0x1000);
  });
});
