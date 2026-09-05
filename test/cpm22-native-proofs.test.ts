import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { parseIntelHex } from "@jhlagado/debug80-runtime";
import { describe, expect, it } from "vitest";
import { assembleNativeCpmProof } from "../scripts/assemble-native-cpm.mjs";
import { assembleNativeSource } from "../scripts/assemble-native-source.mjs";

type Baseline = {
  revision: string;
  proofs: Record<string, {
    symbols: Record<string, number>;
    segments: { start: number; end: number; hex: string; sha256: string }[];
    omittedInheritedSymbols: string[];
    addedProofContextSymbols: Record<string, number>;
  }>;
};
// One-time capture of corrected abbb2be proofs assembled by ATOM. These are
// preservation expectations, never regenerated from the source under test.
const baseline = JSON.parse(readFileSync(new URL(
  "./fixtures/cpm-native-fixed-baseline.json", import.meta.url,
), "utf8")) as Baseline;
const hash = (bytes: Uint8Array) => createHash("sha256").update(bytes).digest("hex");
const addresses = (ranges: readonly { start: number; end: number }[]) =>
  ranges.flatMap(({ start, end }) => Array.from({ length: end - start }, (_, i) => start + i));
const proofContext = {
  CpmSourceWorkspaceBase: 0x5858, SourcePartCapacity: 8,
  NativeSourceChunkBase: 0x7500, NucleusStatusInvalid: 1,
  NucleusStatusNotFound: 3, NucleusStatusCapacity: 4,
  NucleusStatusStorage: 6, NucleusStatusConflict: 7,
  CpmDirectWorkspaceBase: 0x5820, CpmOutputBufferBase: 0x7800,
  CpmOutputBufferLimit: 0xd500, CpmTargetImageBase: 0x0800,
  CpmTargetImageCapacity: 0x5d00, CpmTargetImageLimit: 0x6500,
  CpmOutputAddressDelta: 0x7000, CpmTargetWritableBase: 0x5800,
  CpmHostResidentLimit: 0x5800, CpmHostWorkspaceLimit: 0x6000,
};

describe("canonical native CP/M proof preservation", () => {
  it.each(Object.entries(baseline.proofs))(
    "preserves every emitted byte, relevant symbol and gap for %s", async (name, frozen) => {
      expect(baseline.revision).toBe("abbb2bea1b20d6ccfe11bdf936f48b525b0d88a6");
      const assembled = await assembleNativeCpmProof(`cpm22-${name}-proof.asm`);
      const parsed = parseIntelHex(assembled.hex);
      expect(addresses(parsed.writeRanges ?? [])).toEqual(addresses(frozen.segments));
      for (const segment of frozen.segments) {
        const bytes = parsed.memory.slice(segment.start, segment.end);
        expect(Buffer.from(bytes).toString("hex")).toBe(segment.hex);
        expect(hash(bytes)).toBe(segment.sha256);
      }
      expect(assembled.generation.highWater).toBe(frozen.segments.at(-1)!.end);
      expect(assembled.generation.finalCursor).toBe(frozen.segments.at(-1)!.end);

      // The snapshot lists omitted, unused imports from the old whole-machine
      // map/ABI. None may be an adapter's declaration or runtime identity.
      for (const omitted of frozen.omittedInheritedSymbols) {
        expect(omitted).not.toMatch(/^(CpmCommand|CpmPublish|CpmDirect|CpmSource|CpmProgram|CpmRuntime|NucleusRuntime(?!Catalog)|ZTS_CPM_)/);
        expect(Object.hasOwn(frozen.symbols, omitted)).toBe(true);
      }
      const retained = Object.fromEntries(Object.entries(frozen.symbols)
        .filter(([key]) => !frozen.omittedInheritedSymbols.includes(key)));
      expect(assembled.symbols).toEqual({ ...retained, ...frozen.addedProofContextSymbols });
      expect(assembled.symbols.PGCLRLEN).toBeUndefined();
      if (name !== "program-provider") {
        expect(assembled.symbols).toMatchObject(proofContext);
        expect(frozen.addedProofContextSymbols).toEqual(Object.fromEntries(
          Object.entries(proofContext).filter(([key]) => !Object.hasOwn(frozen.symbols, key)),
        ));
      } else {
        expect(frozen.omittedInheritedSymbols).toEqual([]);
        expect(frozen.addedProofContextSymbols).toEqual({});
        // Two adjacent unfilled DS36 FCBs are NOT source writes. The packed
        // generated prefix nevertheless contains zero-filled bytes there.
        expect(parsed.memory.slice(0x419, 0x461)).toEqual(new Uint8Array(72));
        expect(hash(parsed.memory.slice(0x100, 0x46c))).toBe(
          "6d423cebffa3656fad983575276fa5065ea0d96c9daf446bcd0490bae048680c",
        );
      }
      if (name === "publisher") {
        const zeroes = assembled.symbols.CpmPublishHexZeroes!;
        expect(parsed.memory.slice(zeroes, zeroes + 16)).toEqual(new Uint8Array(16));
        const written = new Set(addresses(parsed.writeRanges ?? []));
        expect(Array.from({ length: 16 }, (_, i) => written.has(zeroes + i))).toEqual(new Array(16).fill(true));
      }

      // Official ATOM alone consumes include headers. All remaining source,
      // including the publisher head/renderer/tail, reaches it byte-for-byte.
      for (const part of assembled.project.parts) {
        const original = new TextDecoder().decode(part.originalBytes);
        expect(new TextDecoder().decode(part.compilerBytes)).toBe(
          original.replace(/^%INCLUDE[^\r\n]*/gm, line => " ".repeat(line.length)),
        );
      }
    },
  );

  it("derives the private program clear length without publishing a new ABI key", async () => {
    const raw = await assembleNativeSource({
      root: fileURLToPath(new URL("../asm/", import.meta.url)),
      entry: "vertical-slice/cpm22-program-provider-proof.asm",
    });
    expect(raw.symbols.PGCLRLEN).toBe(8);
    expect(raw.symbols.PGCLRLEN).toBe(raw.symbols.PGSTATE! - raw.symbols.PGINCUR!);
  });

  it("checks all proof-only inputs against their actual map and ABI expressions", () => {
    const source = (name: string) => readFileSync(new URL(`../asm/vertical-slice/${name}`, import.meta.url), "utf8");
    const check = (file: string, expected: Record<string, string>) => {
      for (const [name, expression] of Object.entries(expected)) {
        expect(source(file).split("\n").some(line => {
          const fields = line.split(";")[0]!.trim().split(/\s+/);
          return fields[0] === name && [".equ", "EQU"].includes(fields[1]!) &&
            fields.slice(2).join("") === expression.replace(/\s/g, "");
        }), `${file}: proof input ${name} must track its complete expression`).toBe(true);
      }
    };
    check("cpm22-target-memory-map.asmi", {
      CompilerWorkBase: "$6000", SourceBase: "$7000", SourceLimit: "$7800",
      NativeSourceTokenLimit: "SourceBase+$0500", SRCCHUNK: "NativeSourceTokenLimit",
      CpmHostResidentLimit: "$5800", CpmHostWorkspaceBase: "$5800",
      CpmHostWorkspaceLimit: "CompilerWorkBase", DOWKBASE: "CpmHostWorkspaceBase+$0020",
      CSWKBASE: "CpmHostWorkspaceBase+$0058", DOIMG: "$0800", DOBUF: "SourceLimit",
      DOBUFEND: "$D500", DOIMGCAP: "DOBUFEND-DOBUF", DOIMGEND: "DOIMG+DOIMGCAP",
      DOOFFSET: "DOBUF-DOIMG", DOWRBASE: "$5800",
    });
    check("platform-services-abi.asmi", {
      NSTATINV: "1", NSTATNF: "3", NSTATCAP: "4", NSTATIO: "6", NSTATCF: "7",
    });
    check("aggregate-call-state.asmi", { SRCPARTS: "8" });
  });
});
