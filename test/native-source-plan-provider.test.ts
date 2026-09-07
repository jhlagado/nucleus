import { createHash } from "node:crypto";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
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
  readonly bank: number;
  readonly bytes: Uint8Array;
}

describe("the native Z80 SP1 source-plan provider", () => {
  const roots: string[] = [];
  afterEach(() => {
    for (const root of roots.splice(0))
      rmSync(root, { recursive: true, force: true });
  });

  it("assembles the provider from canonical sources with native ATOM", async () => {
    const proof = await assembleNativeSourcePlanProof();
    const parsed = parseIntelHex(proof.hex);
    const addresses = (ranges: readonly { start: number; end: number }[]) =>
      ranges.flatMap(({ start, end }) =>
        Array.from({ length: end - start }, (_, i) => start + i),
      );
    expect(addresses(parsed.writeRanges ?? [])).toEqual(addresses([
      { start: 0x0010, end: 0x0013 },
      { start: 0x4000, end: 0x4013 },
      { start: 0x4200, end: 0x4741 },
    ]));
    const bytes = Buffer.concat((parsed.writeRanges ?? []).map(({ start, end }) =>
      Buffer.from(parsed.memory.slice(start, end))));
    const hash = (value: Uint8Array | string) =>
      createHash("sha256").update(value).digest("hex");
    expect(bytes).toHaveLength(1_367);
    expect(hash(bytes)).toBe("6a4357647ac7f984bff225aa9b1a85fa864f2575eb0d37459d9188fe7dc9d9de");
    expect(Object.keys(proof.symbols)).toHaveLength(186);
    expect(hash(JSON.stringify(proof.symbols))).toBe("40bd722967de036b164a25368030a3c3ca464c96002697a3627edb361c990af0");
    expect(Object.keys(proof.addresses)).toHaveLength(69);
    expect(hash(JSON.stringify(proof.addresses))).toBe("fee5d3a09f85c46095abd4f3050f8829c1e9b651516268b533ea54c22a742867");
    expect(proof.symbols.ProofInitialize).toBe(0x4000);
    expect(proof.symbols.NativeSourceProviderCodeStart).toBe(0x4200);
    expect(proof.generation.highWater).toBe(0x4741);
    expect(proof.generation.finalCursor).toBe(0x4741);
    for (const part of proof.project.parts) {
      const original = new TextDecoder().decode(part.originalBytes);
      expect(new TextDecoder().decode(part.compilerBytes)).toBe(
        original.replace(/^%INCLUDE[^\r\n]*/gm, (line) =>
          " ".repeat(line.length),
        ),
      );
    }
  });

  it("streams one ordered source with banked chunks and inserted newlines", async () => {
    const { hex, symbols } = await assembleNativeSourcePlanProof();

    const root = mkdtempSync(path.join(tmpdir(), "nucleus-source-provider-"));
    roots.push(root);
    mkdirSync(path.join(root, ".nucleus"));
    writeFileSync(
      path.join(root, ".nucleus", "source-plan.sp1"),
      "SP1 2\nP 1 6 lib.nu\nP 2 7 main.nu\nEND\n",
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
          runtime.cpu.flags.C = status === NucleusSystemStatus.success ? 0 : 1;
        },
      },
    );

    const run = (entry: number): void => {
      const stack = 0x7f00;
      runtime.hardware.memory[stack] = symbols.ProofReturnSentinel & 0xff;
      runtime.hardware.memory[stack + 1] = symbols.ProofReturnSentinel >>> 8;
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
        bank: runtime.cpu.c,
        bytes:
          event === 0
            ? runtime.hardware.memory.slice(pointer, pointer + count)
            : new Uint8Array(),
      };
    };
    const events: SourceEvent[] = [next()];

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

    for (let ordinal = 0; ordinal < 4; ordinal += 1) events.push(next());
    expect(
      events.map(({ event, bank, bytes }) => [
        event,
        event === 1 ? null : bank,
        Buffer.from(bytes).toString("ascii"),
      ]),
    ).toEqual([
      [0, 1, "AB"],
      [0, 1, "\n"],
      [0, 2, "CDE"],
      [0, 2, "\n"],
      [1, null, ""],
    ]);
    run(symbols.ProofFinish);
    expect(services.openHandleCount).toBe(0);
    expect(
      symbols.NativeSourceProviderCodeEnd -
        symbols.NativeSourceProviderCodeStart,
    ).toBeLessThanOrEqual(0x1000);
  });
});
