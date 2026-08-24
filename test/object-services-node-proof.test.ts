import { writeFileSync, mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";

import { compile } from "@jhlagado/azm/compile";
import { createZ80Runtime, parseIntelHex } from "@jhlagado/debug80-runtime";
import { describe, expect, it } from "vitest";

import {
  NodeNamedObjectServices,
  NucleusSystemStatus,
} from "../src/object-services.js";

describe("the Node named-object Z80 gateway", () => {
  it("executes the common request ABI without replacing the Z80 client", async () => {
    const source = new URL(
      "../asm/vertical-slice/object-services-node-proof.asm",
      import.meta.url,
    ).pathname;
    const assembled = await compile(source, {
      emitHex: true,
      emitD8m: true,
      registerContracts: "strict",
      registerContractsInterfaces: [
        new URL(
          "../asm/vertical-slice/node-platform-services.asmi",
          import.meta.url,
        ).pathname,
      ],
    });
    expect(
      assembled.diagnostics.filter(({ severity }) => severity === "error"),
    ).toEqual([]);
    const hex = assembled.artifacts.find(({ kind }) => kind === "hex");
    const map = assembled.artifacts.find(({ kind }) => kind === "d8m");
    if (hex?.kind !== "hex" || map?.kind !== "d8m") {
      throw new Error("AZM omitted named-object proof artifacts");
    }
    const symbols = Object.fromEntries(
      map.json.symbols.flatMap((entry) => {
        const value = entry.address ?? entry.value;
        return value === undefined ? [] : [[entry.name, value]];
      }),
    );
    const root = mkdtempSync(path.join(tmpdir(), "nucleus-object-gateway-"));
    writeFileSync(path.join(root, "source.nu"), "abcdef");
    const services = new NodeNamedObjectServices(root);
    let runtime: ReturnType<typeof createZ80Runtime>;
    runtime = createZ80Runtime(
      {
        memory: parseIntelHex(hex.text).memory,
        startAddress: symbols.ProofStart,
      },
      symbols.ProofStart,
      {
        write: (port) => {
          if ((port & 0xff) !== symbols.ObjectNodeGatewayPort) {
            throw new Error(`unexpected proof port ${port & 0xff}`);
          }
          expect(runtime.cpu.c).toBe(symbols.NucleusServiceObject);
          const request = (runtime.cpu.h << 8) | runtime.cpu.l;
          const status = services.dispatch(runtime.hardware.memory, request);
          runtime.cpu.a = status;
          runtime.cpu.flags.C =
            status === NucleusSystemStatus.success ? 0 : 1;
        },
      },
    );
    let guard = 0;
    while (!runtime.isHalted() && guard++ < 1_000) runtime.step();
    expect(runtime.isHalted()).toBe(true);
    expect(runtime.hardware.memory[symbols.ProofResult]).toBe(0);
    expect(
      Buffer.from(
        runtime.hardware.memory.subarray(
          symbols.ProofReadBuffer,
          symbols.ProofReadBuffer + 3,
        ),
      ).toString("ascii"),
    ).toBe("abc");
    expect(services.openHandleCount).toBe(0);
  });
});
