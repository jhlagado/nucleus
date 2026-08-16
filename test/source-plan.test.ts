import { describe, expect, it } from "vitest";

import {
  parseNucleusSourcePlan,
  serializeNucleusSourcePlan,
} from "../src/source-plan.js";

describe("SP1 source plans", () => {
  it("round trips a canonical plan with paths containing spaces", () => {
    const parts = [
      { bank: 1, path: "src/lib/io.nu" },
      { bank: 0, path: "src/main program.nu" },
    ];
    const serialized = serializeNucleusSourcePlan(parts);

    expect(serialized).toBe(
      "SP1 2\nP 1 13 src/lib/io.nu\nP 0 19 src/main program.nu\nEND\n",
    );
    expect(parseNucleusSourcePlan(serialized)).toEqual(parts);
    expect(serializeNucleusSourcePlan(parseNucleusSourcePlan(serialized))).toBe(
      serialized,
    );
  });

  it("accepts CRLF but rejects malformed or truncated plans", () => {
    expect(
      parseNucleusSourcePlan("SP1 1\r\nP 0 11 src/main.nu\r\nEND\r\n"),
    ).toEqual([{ bank: 0, path: "src/main.nu" }]);

    for (const invalid of [
      "SP1 1\nP 0 11 src/main.nu\n",
      "SP1 2\nP 0 11 src/main.nu\nEND\n",
      "SP1 1\nP 0 10 src/main.nu\nEND\n",
      "SP1 1\nP 256 11 src/main.nu\nEND\n",
      "SP1 1\nP 0 12 src\\main.nu\nEND\n",
      "SP1 1\nP 0 10 ../main.nu\nEND\n",
      "SP1 1\nP 0 11 src/main.nu\nEND\nextra\n",
      "SP1 1\rP 0 11 src/main.nu\nEND\n",
    ]) {
      expect(() => parseNucleusSourcePlan(invalid)).toThrow();
    }
  });

  it("refuses to serialize a path whose byte length does not fit SP1", () => {
    expect(() =>
      serializeNucleusSourcePlan([{ bank: 0, path: `${"a".repeat(253)}.nu` }]),
    ).toThrow("source path length must be in the range 1..255");
  });
});
