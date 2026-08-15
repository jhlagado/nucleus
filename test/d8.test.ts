import { describe, expect, it } from "vitest";

import {
  assertNucleusSemanticOperationKeys,
  nucleusSemanticOperationKeys,
} from "../src/d8-internal.js";

describe("Nucleus D8 semantic transcript validation", () => {
  const fixedWidths = new Map<number, number>([
    ...[
      21, 31, 37, 38, 39, 40, 41, 42, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54,
      55, 64, 65, 66, 73, 78, 81, 85, 91, 92, 93, 94, 100, 101,
    ].map((operation) => [operation, 1] as const),
    ...[
      22, 25, 29, 33, 36, 58, 59, 60, 63, 67, 68, 69, 75, 76, 79, 80, 86, 88,
      102, 103, 105, 111, 114,
    ].map((operation) => [operation, 2] as const),
    ...[
      20, 24, 28, 30, 34, 35, 43, 44, 56, 57, 61, 62, 70, 74, 87, 89, 98, 99,
      106, 107, 113,
    ].map((operation) => [operation, 3] as const),
    ...[32, 71, 82, 83, 96, 97, 108, 109, 112].map(
      (operation) => [operation, 4] as const,
    ),
    ...[77, 95].map((operation) => [operation, 5] as const),
    [115, 6],
    [90, 7],
    [72, 9],
  ]);

  it("locks every fixed-width production operation", () => {
    for (const [operation, width] of fixedWidths) {
      const payload = new Uint8Array(width);
      payload[0] = operation;
      expect(nucleusSemanticOperationKeys(payload, 1)).toEqual([0]);
      for (let length = 1; length < width; length += 1) {
        expect(() =>
          nucleusSemanticOperationKeys(payload.subarray(0, length), 1),
        ).toThrow("extends beyond the transcript payload");
      }
    }
  });

  it("decodes exact production operation boundaries", () => {
    const payload = Uint8Array.of(106, 0, 0, 22, 0, 34, 1, 0, 28, 0, 0, 86, 0);
    expect(nucleusSemanticOperationKeys(payload, 5)).toEqual([0, 3, 5, 8, 11]);
  });

  it("distinguishes an operand offset from an operation boundary", () => {
    const payload = Uint8Array.of(106, 0, 0, 34, 1, 0, 86, 0);
    const expected = nucleusSemanticOperationKeys(payload, 3);
    const corruptedTrace = [0, 4, 6];
    expect(expected).toEqual([0, 3, 6]);
    expect(() =>
      assertNucleusSemanticOperationKeys(payload, 3, corruptedTrace),
    ).toThrow("semantic trace 1 used key 4, expected operation boundary 3");
  });

  it("decodes variable-width calls and handler destinations", () => {
    const sourceCall = Uint8Array.of(84, 1, 0, 0, 0, 0, 0, 0, 0, 0, 78);
    const serviceCall = Uint8Array.of(84, 0x80, 0, 0, 0, 0, 0, 78);
    const programHandler = Uint8Array.of(104, 1, 0x04, 0, 0, 105, 2);
    const localHandler = Uint8Array.of(104, 1, 0x08, 0, 105, 2);
    expect(nucleusSemanticOperationKeys(sourceCall, 2)).toEqual([0, 10]);
    expect(nucleusSemanticOperationKeys(serviceCall, 2)).toEqual([0, 7]);
    expect(nucleusSemanticOperationKeys(programHandler, 2)).toEqual([0, 5]);
    expect(nucleusSemanticOperationKeys(localHandler, 2)).toEqual([0, 4]);
  });

  it("distinguishes byte and word open-view argument payloads", () => {
    expect(nucleusSemanticOperationKeys(Uint8Array.of(110, 0, 7), 1)).toEqual([
      0,
    ]);
    expect(
      nucleusSemanticOperationKeys(Uint8Array.of(110, 2, 0x34, 0x12), 1),
    ).toEqual([0]);
    expect(() =>
      nucleusSemanticOperationKeys(Uint8Array.of(110, 2, 0x34), 1),
    ).toThrow("extends beyond the transcript payload");
  });

  it("rejects truncated or trailing final operations", () => {
    expect(() => nucleusSemanticOperationKeys(Uint8Array.of(72), 1)).toThrow(
      "extends beyond the transcript payload",
    );
    expect(() =>
      nucleusSemanticOperationKeys(Uint8Array.of(84, 0x80), 1),
    ).toThrow("extends beyond the transcript payload");
    for (const [payload, width] of [
      [Uint8Array.of(84, 0, 0, 0, 0, 0, 0, 0, 0, 0), 10],
      [Uint8Array.of(84, 0x80, 0, 0, 0, 0, 0), 7],
      [Uint8Array.of(104, 0, 0x04, 0, 0), 5],
      [Uint8Array.of(104, 0, 0x08, 0), 4],
    ] as const) {
      for (let length = 1; length < width; length += 1) {
        expect(() =>
          nucleusSemanticOperationKeys(payload.subarray(0, length), 1),
        ).toThrow("extends beyond the transcript payload");
      }
    }
    expect(() => nucleusSemanticOperationKeys(Uint8Array.of(21, 0), 1)).toThrow(
      "semantic transcript ends at 2, expected decoded end 1",
    );
  });

  it("rejects retired and unknown operation bytes", () => {
    for (const operation of [0, 23, 26, 27, 255]) {
      expect(() =>
        nucleusSemanticOperationKeys(Uint8Array.of(operation), 1),
      ).toThrow("is not in the production dispatch table");
    }
  });
});
