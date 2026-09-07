import { describe, expect, it } from "vitest";

import {
  mapNucleusSourceBundleOffset,
  nucleusSourceByteCapacity,
  nucleusSourceFileCapacity,
  prepareNucleusSourceBundle,
} from "../src/source-bundle.js";

const bytes = (text: string): Uint8Array => new TextEncoder().encode(text);

describe("Nucleus source bundles", () => {
  it("concatenates ordered files and records inserted boundary newlines", () => {
    const bundle = prepareNucleusSourceBundle([
      { name: "lib.nu", source: "const Value = 1", bank: 1 },
      { name: "main.nu", source: "sub main()\r\nend\r\n", bank: 0 },
    ]);
    expect(new TextDecoder().decode(bundle.bytes)).toBe(
      "const Value = 1\nsub main()\r\nend\r\n",
    );
    expect(bundle.files).toMatchObject([
      { name: "lib.nu", start: 0, end: 15, addedNewline: true, bank: 1 },
      { name: "main.nu", start: 16, end: 33, addedNewline: false, bank: 0 },
    ]);
    expect(bundle.placement).toEqual([
      { start: 0, end: 16, bank: 1 },
      { start: 16, end: 33, bank: 0 },
    ]);
    expect(bundle.sha256).toMatch(/^[0-9a-f]{64}$/);
    expect(bundle.files.every((file) => /^[0-9a-f]{64}$/.test(file.sha256))).toBe(
      true,
    );
  });

  it("maps ordinary, CRLF, synthetic, and final positions to source files", () => {
    const bundle = prepareNucleusSourceBundle([
      { name: "first.nu", source: "a\r\nb" },
      { name: "last.nu", source: "xy\n" },
    ]);
    expect(mapNucleusSourceBundleOffset(bundle, 3)).toEqual({
      name: "first.nu",
      offset: 3,
      line: 2,
      column: 1,
      synthetic: false,
    });
    expect(mapNucleusSourceBundleOffset(bundle, 4)).toEqual({
      name: "first.nu",
      offset: 4,
      line: 2,
      column: 2,
      synthetic: true,
    });
    expect(mapNucleusSourceBundleOffset(bundle, bundle.byteLength)).toEqual({
      name: "last.nu",
      offset: 3,
      line: 2,
      column: 1,
      synthetic: false,
    });
  });

  it("merges adjacent placement ranges with the same bank", () => {
    const bundle = prepareNucleusSourceBundle([
      { name: "a.nu", source: "a", bank: 2 },
      { name: "b.nu", source: "b\n", bank: 2 },
      { name: "c.nu", source: "c", bank: 1 },
    ]);
    expect(bundle.placement).toEqual([
      { start: 0, end: 4, bank: 2 },
      { start: 4, end: 6, bank: 1 },
    ]);
  });

  it("accepts 255 small files and rejects 256 independently of bytes", () => {
    const accepted = Array.from({ length: nucleusSourceFileCapacity }, (_, index) => ({
      name: `f${index}.nu`,
      source: "",
    }));
    expect(prepareNucleusSourceBundle(accepted).files).toHaveLength(255);
    expect(() =>
      prepareNucleusSourceBundle([
        ...accepted,
        { name: "overflow.nu", source: "" },
      ]),
    ).toThrow("require 1..255 source files");
  });

  it("includes inserted newlines in the 65535-byte source capacity", () => {
    const exact = new Uint8Array(nucleusSourceByteCapacity).fill(0x20);
    exact[exact.length - 1] = 0x0a;
    expect(
      prepareNucleusSourceBundle([
        {
          name: "full.nu",
          source: exact,
        },
      ]).byteLength,
    ).toBe(nucleusSourceByteCapacity);
    expect(() =>
      prepareNucleusSourceBundle([
        {
          name: "overflow.nu",
          source: new Uint8Array(nucleusSourceByteCapacity).fill(0x20),
        },
        { name: "extra.nu", source: "" },
      ]),
    ).toThrow("capacity is 65535");
  });

  it.each([
    ["lone CR", bytes("a\r")],
    ["unsupported byte", Uint8Array.of(0)],
    ["literal", bytes('writeText("open')],
    ["delimiter", bytes("value = (1 + 2")],
    ["mismatched delimiter", bytes("value = (1]")],
  ])("rejects an invalid %s boundary", (_name, source) => {
    expect(() =>
      prepareNucleusSourceBundle([{ name: "bad.nu", source }]),
    ).toThrow();
  });

  it("does not treat comment text as literals or delimiters", () => {
    expect(() =>
      prepareNucleusSourceBundle([
        { name: "comment.nu", source: '// " [ ( complete comment' },
      ]),
    ).not.toThrow();
  });

  it("rejects duplicate, invalid, and invalid-bank inputs", () => {
    expect(() =>
      prepareNucleusSourceBundle([
        { name: "same.nu", source: "" },
        { name: "same.nu", source: "" },
      ]),
    ).toThrow("duplicate source name");
    expect(() =>
      prepareNucleusSourceBundle([{ name: "../bad.nu", source: "" }]),
    ).toThrow("normalized printable ASCII path identity");
    expect(() =>
      prepareNucleusSourceBundle([{ name: "bad.nu", source: "", bank: 256 }]),
    ).toThrow("bank outside 0..255");
  });
});
