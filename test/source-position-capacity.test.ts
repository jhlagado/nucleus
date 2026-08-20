import { describe, expect, it } from "vitest";

import { nucleusDiagnosticMessage } from "../src/diagnostics.js";
import {
  debugCompilerSymbols,
  normalCompilerSymbols,
} from "../src/generated-compiler-images.js";

describe("streaming source-position capacity", () => {
  it("reserves one stable diagnostic ordinal in both compiler layouts", () => {
    expect(normalCompilerSymbols.DiagnosticSourcePositionCapacity).toBe(101);
    expect(debugCompilerSymbols.DiagnosticSourcePositionCapacity).toBe(101);
    expect(nucleusDiagnosticMessage(101)).toBe(
      "source position capacity exceeded",
    );
  });
});
