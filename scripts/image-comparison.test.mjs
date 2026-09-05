import assert from "node:assert/strict";
import test from "node:test";
import { spawnSync } from "node:child_process";
import { sameGeneratedImages } from "./image-comparison.mjs";

test("the image generator rejects the retired AZM mode", () => {
  const result = spawnSync(process.execPath, ["scripts/generate-compiler-images.mjs", "--azm-oracle", "--check"], { encoding: "utf8" });
  assert.equal(result.status, 1);
  assert.match(result.stderr, /generation uses ATOM only/);
});

test("image comparison checks bytes, sparse writes and every symbol, not formatting", () => {
  const source = (hex, symbols) => `export const imageHex: string = ${JSON.stringify(hex)};\nexport const imageSymbols: Readonly<Record<string, number>> = ${JSON.stringify(symbols)};\n`;
  const combined = ":020100000102FA\n:00000001FF\n";
  const split = ":0101000001FD\n:0101010002FB\n:00000001FF\n";
  assert.ok(sameGeneratedImages(source(combined, { a: 1, b: 2 }), source(split, { b: 2, a: 1 })));
  assert.ok(!sameGeneratedImages(source(combined, { a: 1 }), source(split, { a: 2 })));
  assert.ok(!sameGeneratedImages(source(combined, { a: 1 }), source(split, { a: 1, b: 2 })));
  assert.ok(!sameGeneratedImages(source(":0101000000FE\n:00000001FF\n", {}), source(":00000001FF\n", {})));
  assert.ok(!sameGeneratedImages(source(combined, {}), source(":020100000103F9\n:00000001FF\n", {})));
});
