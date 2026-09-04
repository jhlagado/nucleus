import assert from "node:assert/strict";
import test from "node:test";
import { spawnSync } from "node:child_process";
import { normalizeLine, scheduleEquates, prepareAtomSource, sparseIntelHex, assembleAtomSource } from "./atom-source.mjs";
import { assembleResolvedAtomProject } from "atom-z80";
import { parseIntelHex } from "@jhlagado/debug80-runtime";
import { sameGeneratedImages } from "./image-comparison.mjs";

const schedule = (...lines) => scheduleEquates(lines.map((text, i) => ({text, file: "fixture.asm", line: i + 1})));

test("assembly target and label map preserve a top-fitting physical image", async () => {
  const entry = "vertical-slice/nucleus-target-runtime-link.asm";
  const result = await assembleAtomSource(entry, {
    overrides: new Map([[entry, "ConstantValue .equ 7\n.org $FFFF\nLastByteLabel: .db 7\nPhysicalEnd:\n"]]),
    target: { start: 0xffff, capacity: 1 },
  });
  assert.equal(result.addresses.LastByteLabel, 0xffff);
  assert.equal(result.addresses.PhysicalEnd, 0);
  assert.equal(result.addresses.ConstantValue, undefined);
  assert.equal(result.symbols.ConstantValue, 7);
  assert.equal(result.generation.highWater, 0x10000);
  assert.deepEqual(parseIntelHex(result.hex).writeRanges, [{ start: 0xffff, end: 0x10000 }]);
});
test("the image generator rejects the retired AZM mode", () => {
  const result = spawnSync(process.execPath, ["scripts/generate-compiler-images.mjs", "--azm-oracle", "--check"], { encoding: "utf8" });
  assert.equal(result.status, 1);
  assert.match(result.stderr, /generation uses ATOM only/);
});
test("oracle comparison checks bytes, sparse writes and every symbol, not formatting", () => {
  const source = (hex, symbols) => `export const imageHex: string = ${JSON.stringify(hex)};\nexport const imageSymbols: Readonly<Record<string, number>> = ${JSON.stringify(symbols)};\n`;
  const combined = ":020100000102FA\n:00000001FF\n";
  const split = ":0101000001FD\n:0101010002FB\n:00000001FF\n";
  assert.ok(sameGeneratedImages(source(combined, {a: 1, b: 2}), source(split, {b: 2, a: 1})));
  assert.ok(!sameGeneratedImages(source(combined, {a: 1}), source(split, {a: 2})));
  assert.ok(!sameGeneratedImages(source(combined, {a: 1}), source(split, {a: 1, b: 2})));
  assert.ok(!sameGeneratedImages(source(":0101000000FE\n:00000001FF\n", {}), source(":00000001FF\n", {})));
  assert.ok(!sameGeneratedImages(source(combined, {}), source(":020100000103F9\n:00000001FF\n", {})));
});
test("normalization preserves strings, escaped quotes and alternate registers", () => {
  assert.equal(normalizeLine("SUB 'a'-'0' ; comment"), "SUB $61-$30");
  assert.equal(normalizeLine("EX AF,AF' ; comment"), "EX AF,AF'");
  assert.equal(normalizeLine('DB "a;b,c",\';\' ; comment'), 'DB "a;b,c",$3b');
  assert.throws(() => normalizeLine("DB 'abc"), /Unterminated/);
});
test("forward equates retain source provenance and move past their dependencies", () => {
  const output = schedule("Small EQU END-BASE", "BASE:", "DB Small", "END:");
  assert.deepEqual(output.map(line => line.text), ["BASE:", "DB Small", "END:", "Small EQU END-BASE"]);
  assert.equal(output.at(-1).line, 1);
});
test("equate chains resolve without host address evaluation", () => {
  const output = schedule("SIZE EQU LAST-FIRST", "COPY EQU SIZE", "FIRST:", "DB 1", "LAST:");
  assert.deepEqual(output.slice(-2).map(line => line.text), ["SIZE EQU LAST-FIRST", "COPY EQU SIZE"]);
});
test("forward multi-symbol tables use generated equates with no alias collision", () => {
  const output = schedule("X0000000 EQU 1", 'DB END-BASE,"a,b"', "BASE:", "DB 1", "END:");
  assert.equal(output[1].text, 'DB X0000001,"a,b"');
  assert.equal(output.at(-1).text, "X0000001 EQU END-BASE");
});
test("unknown and cyclic equates fail instead of disappearing", () => {
  assert.throws(() => schedule("VALUE EQU TYPO+1"), /fixture.asm:1: Unresolved/);
  assert.throws(() => schedule("LEFT EQU RIGHT", "RIGHT EQU LEFT"), /cyclic/);
  assert.throws(() => schedule("X EQU 1", "X EQU 2"), /Duplicate/);
});
test("forward immediate differences use an Atom equate, without host evaluation", () => {
  const output = schedule("LD C,LAST-FIRST+1", "FIRST:", "DB 0", "LAST:");
  assert.equal(output[0].text, "LD C,X0000000");
  assert.equal(output.at(-1).text, "X0000000 EQU LAST-FIRST+1");
  assert.equal(schedule("LD HL,  (LAST-FIRST)", "FIRST:", "LAST:")[0].text, "LD HL,  (LAST-FIRST)");
});
test("location-dependent equates stay at their original point or fail", () => {
  assert.deepEqual(schedule("BASE:", "DB 0", "SIZE EQU $-BASE").map(line => line.text), ["BASE:", "DB 0", "SIZE EQU $-BASE"]);
  assert.throws(() => schedule("SIZE EQU END-$", "END:"), /location-dependent/);
  assert.throws(() => schedule("DB END-BASE+$", "BASE:", "END:"), /location-dependent/);
});
test("numeric literals and LOW/HIGH are not symbol dependencies", () => {
  assert.equal(schedule("VALUE EQU $FF+0ABCDh+101b+LOW($1234)").length, 1);
});
test("generated contexts append collision-free aliases without changing source aliases", () => {
  const source = prepareAtomSource("vertical-slice/nucleus-target-runtime-link.asm", {
    overrides: new Map([["vertical-slice/nucleus-target-runtime-link.asm", "G0000000 .equ 1\nNewContextService .equ $7021\n.org $100\nJP NewContextService\n"]]),
  });
  assert.equal(source.aliases.get("NewContextService"), "G0000001");
  assert.equal(source.sourceSymbols.get("G0000001"), "NewContextService");
  assert.match(new TextDecoder().decode(source.parts[0].compilerBytes), /JP G0000001/);
});
test("real Atom executes scheduled forward expressions and keeps HEX gaps unwritten", async () => {
  const lines = schedule("SIZE EQU LAST-FIRST", "ORG $100", "FIRST:", "DB LAST-FIRST", "DB 3", "LAST:", "ORG $200", "DW SIZE", "LD C,AFTER-BEFORE+1", "LD DE,SMALL+SIZE", "SMALL EQU 4", "BEFORE:", "DB 0", "AFTER:");
  const bytes = new TextEncoder().encode(lines.map(line => line.text).join("\n") + "\n");
  const result = await assembleResolvedAtomProject({parts: [{ordinal: 0, bank: 0, logicalIdentity: "fixture.asm", originalBytes: bytes, compilerBytes: bytes}]}, {target: {start: 0, capacity: 65535}});
  const program = parseIntelHex(sparseIntelHex(result.generation));
  assert.deepEqual(program.writeRanges, [{start: 256, end: 258}, {start: 512, end: 520}]);
  assert.deepEqual([...program.memory.slice(256, 258)], [2, 3]);
  assert.deepEqual([...program.memory.slice(512, 520)], [2, 0, 0x0e, 2, 0x11, 6, 0, 0]);
});
test("real Atom resolves a forward label difference in a CP immediate", async () => {
  const lines = schedule("ORG $100", "CP LAST-FIRST", "FIRST:", "DB 0", "LAST:");
  const bytes = new TextEncoder().encode(lines.map(line => line.text).join("\n") + "\n");
  const result = await assembleResolvedAtomProject({parts: [{ordinal: 0, bank: 0, logicalIdentity: "compare.asm", originalBytes: bytes, compilerBytes: bytes}]}, {target: {start: 0, capacity: 65535}});
  const program = parseIntelHex(sparseIntelHex(result.generation));
  assert.deepEqual([...program.memory.slice(0x100, 0x103)], [0xfe, 1, 0]);
  assert.equal(schedule("CP (IX+LAST-FIRST)", "FIRST:", "LAST:")[0].text, "CP (IX+LAST-FIRST)");
});
test("current native source has complete mapped parts and no unresolved definitions", () => {
  const source = prepareAtomSource("vertical-slice/native-target-compiler.asm");
  assert.ok(source.parts.length > 1);
  assert.ok(source.parts.every(part => part.compilerBytes.length <= 65535));
  assert.equal(source.definitions.TargetStreamingOutput, 1);
  assert.equal(source.limits.AddressSpaceLimit, 65536);
  assert.ok([...source.sourceSymbols.values()].includes("EmitByte"));
  assert.ok([...source.sourceSymbols.values()].includes("Stage7ParameterSourceOffset._parameterSourceOffsetLoop"));
  assert.throws(() => prepareAtomSource("../../outside.asm"), /escapes/);
});
