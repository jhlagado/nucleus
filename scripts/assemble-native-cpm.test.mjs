import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { fileURLToPath } from "node:url";
import test from "node:test";
import { parseIntelHex } from "@jhlagado/debug80-runtime";
import { assembleNativeCpmProof } from "./assemble-native-cpm.mjs";
import { assembleImageSource } from "./assemble-image-source.mjs";

test("production prefix generation uses the canonical native program proof", async () => {
  const source = fileURLToPath(new URL("../asm/vertical-slice/cpm22-program-provider-proof.asm", import.meta.url));
  const image = await assembleImageSource(source);
  const native = await assembleNativeCpmProof("cpm22-program-provider-proof.asm");
  assert.deepEqual(image, { hex: native.hex, symbols: native.symbols });
  assert.equal(Object.keys(image.symbols).length, 88);
  assert.equal(Object.hasOwn(image.symbols, "PGCLRLEN"), false);
  const parsed = parseIntelHex(image.hex);
  const ranges = [];
  for (const range of parsed.writeRanges) {
    const last = ranges.at(-1);
    if (last?.end === range.start) last.end = range.end;
    else ranges.push({ ...range });
  }
  assert.deepEqual(ranges, [
    { start: 0x100, end: 0x419 }, { start: 0x461, end: 0x46c },
    { start: 0x800, end: 0x803 },
  ]);
  const prefix = parsed.memory.slice(image.symbols.CpmProgramPrefixStart, image.symbols.CpmProgramPrefixEnd);
  assert.equal(prefix.length, 876);
  assert.equal(createHash("sha256").update(prefix).digest("hex"),
    "6d423cebffa3656fad983575276fa5065ea0d96c9daf446bcd0490bae048680c");
  const body = native.project.parts.find(part => part.logicalIdentity.endsWith("/cpm22-program-provider.asm"));
  assert.ok(body);
  assert.deepEqual(body.compilerBytes, body.originalBytes);
  const length = native.generation.symbols?.find(symbol => symbol.name === "PGCLRLEN")?.value;
  assert.equal(length, image.symbols.CpmProgramStorageState - image.symbols.CpmProgramInputCursor);
});

test("native CP/M boundary rejects unknown entries and path escapes", async () => {
  for (const entry of ["../cpm22-program-provider-proof.asm", "cpm22-native-compiler.asm", "unknown.asm"]) {
    await assert.rejects(assembleNativeCpmProof(entry), /Unsupported native CP\/M proof/);
  }
  await assert.rejects(assembleImageSource(fileURLToPath(new URL("../outside.asm", import.meta.url))),
    /outside the source tree/);
});
