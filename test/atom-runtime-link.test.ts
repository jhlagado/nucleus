import { describe, expect, it } from "vitest";

import { generatedRuntimeCatalog } from "../src/generated-runtime-catalog.js";
import {
  defaultRuntimeLinkContext,
  loadCanonicalRuntimeImage,
} from "../src/nucleus-runtime.js";
import { bundledRuntimeProvider } from "../src/runtime-catalog.js";

describe("ATOM development runtime link", () => {
  for (const entry of generatedRuntimeCatalog) {
    it(`reproduces the complete ${entry.name} runtime image`, async () => {
      const context = {
        ...defaultRuntimeLinkContext,
        runtimeBase: entry.runtimeBase,
        writableBase: entry.stateBase - entry.vectorLength,
        writableStateBase: entry.stateBase,
        vectorBase: entry.stateBase - entry.vectorLength,
        programDataBase: entry.stateBase + entry.stateLength,
        readOnlyBase: entry.runtimeBase + entry.expectedLength,
        services: {
          ...defaultRuntimeLinkContext.services,
          packetService: entry.packetService,
        },
      };
      const expected = bundledRuntimeProvider.get(entry.identity, context);
      expect(expected).toBeDefined();
      const actual = await loadCanonicalRuntimeImage(context);
      expect(actual).toEqual(expected);
      expect(actual.bytes).toHaveLength(entry.expectedLength);
    }, 30_000);
  }

  it("rejects invalid placement before assembly", async () => {
    await expect(
      loadCanonicalRuntimeImage({
        ...defaultRuntimeLinkContext,
        writableBase: -1,
      }),
    ).rejects.toThrow("writable base is outside 0..65535");
  });
});
