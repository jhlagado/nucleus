import { createZ80Runtime, parseIntelHex } from "@jhlagado/debug80-runtime";
import { assembleNativeNobj } from "../scripts/assemble-native-nobj.mjs";
import { describe, expect, it } from "vitest";

import { type RuntimeImageProvider } from "../src/nobj.js";
import { defaultNucleusServices } from "../src/compiler.js";
import {
  NodeRuntimeCatalogServices,
} from "../src/runtime-catalog-services.js";
import { NucleusSystemStatus } from "../src/object-services.js";

describe("the Node runtime-catalogue Z80 gateway", () => {
  it("returns bounded resolved chunks without replacing the Z80 client", async () => {
    const { hex, symbols } = await assembleNativeNobj(
      "runtime-catalog-services-node-proof.asm",
    );
    const provider: RuntimeImageProvider = {
      get: (identity) =>
        identity === 10
          ? {
              identity,
              bytes: Uint8Array.of(0x11, 0x22, 0x33, 0x44),
              initialBytes: Uint8Array.of(1, 2, 3, 4, 5),
              vectorBytes: Uint8Array.of(1, 2),
              currentBankOffset: 1,
            }
          : undefined,
    };
    const services = new NodeRuntimeCatalogServices(
      provider,
      defaultNucleusServices,
    );
    let runtime: ReturnType<typeof createZ80Runtime>;
    runtime = createZ80Runtime(
      {
        memory: parseIntelHex(hex).memory,
        startAddress: symbols.ProofStart,
      },
      symbols.ProofStart,
      {
        write: (port) => {
          expect(port & 0xff).toBe(symbols.RuntimeCatalogNodeGatewayPort);
          expect(runtime.cpu.c).toBe(symbols.NucleusServiceRuntimeCatalog);
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
  });
});
