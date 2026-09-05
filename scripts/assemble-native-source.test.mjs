import assert from "node:assert/strict";
import { mkdtemp, mkdir, readFile, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { parseIntelHex } from "@jhlagado/debug80-runtime";
import { assembleNativeSource } from "./assemble-native-source.mjs";

async function fixture(t, files) {
  const root = await mkdtemp(path.join(os.tmpdir(), "nucleus-native-source-"));
  t.after(() => rm(root, { recursive: true, force: true }));
  for (const [name, source] of Object.entries(files)) {
    const file = path.join(root, name);
    await mkdir(path.dirname(file), { recursive: true });
    await writeFile(file, source);
  }
  return options => assembleNativeSource({ root, entry: "entry.asm", ...options });
}

test("official ATOM resolves unchanged source, patches forwards and preserves sparse writes", async t => {
  const source = "CONST EQU 7\nSTART:\nDB 0\nDW FIN\nDS 3\nORG $200\nFIN:\nDB 9\nEND:\n";
  const assemble = await fixture(t, { "entry.asm": source });
  const result = await assemble({ target: { start: 0x100, capacity: 0x200 } });
  const parsed = parseIntelHex(result.hex);
  assert.deepEqual(parsed.writeRanges, [{ start: 0x100, end: 0x103 }, { start: 0x200, end: 0x201 }]);
  assert.deepEqual([...parsed.memory.slice(0x100, 0x103)], [0, 0, 2]);
  assert.equal(parsed.memory[0x200], 9);
  assert.equal(result.symbols.CONST, 7);
  assert.equal(result.addresses.CONST, undefined);
  assert.equal(result.addresses.START, 0x100);
  assert.equal(result.addresses.FIN, 0x200);
  assert.equal(result.generation.highWater, 0x201);
  assert.equal(result.generation.patches.length, 1);
  assert.ok(result.instructions > 0);
  const part = result.project.parts[0];
  assert.equal(new TextDecoder().decode(part.originalBytes), source);
  assert.deepEqual(part.compilerBytes, part.originalBytes);
  assert.equal(await readFile(path.join(part.physicalPath), "utf8"), source);
});

test("top-fitting label wraps while physical end and HEX remain non-wrapping", async t => {
  const assemble = await fixture(t, { "entry.asm": "VALUE EQU 7\nLAST:\nDB VALUE\nEND:\n" });
  const result = await assemble({ target: { start: 0xffff, capacity: 1 } });
  assert.equal(result.addresses.LAST, 0xffff);
  assert.equal(result.addresses.END, 0);
  assert.equal(result.symbols.VALUE, 7);
  assert.equal(result.addresses.VALUE, undefined);
  assert.equal(result.generation.highWater, 0x10000);
  assert.equal(result.generation.finalCursor, 0x10000);
  assert.equal(result.hex, ":01FFFF0007FA\n:00000001FF\n");
  assert.deepEqual(parseIntelHex(result.hex).writeRanges, [{ start: 0xffff, end: 0x10000 }]);
});

test("official dependency ordering and conditional definitions need no dialect preparation", async t => {
  const assemble = await fixture(t, {
    "entry.asm": '%INCLUDE "code.asm"\nEND:\n',
    "code.asm": "%IF DEBUG\nDBG:\nDB 3\n%ENDIF\nBODY:\nDB 4\n",
  });
  const exportMap = { DebugEntry: "DBG", RuntimeStart: "BODY", RuntimeEnd: "END" };
  const result = await assemble({ definitions: { DEBUG: 0 }, exportMap, requiredExports: ["RuntimeStart", "RuntimeEnd"] });
  assert.deepEqual(result.symbols, { RuntimeStart: 0, RuntimeEnd: 1 });
  assert.deepEqual(result.addresses, result.symbols);
  assert.equal(result.project.parts.length, 2);
  assert.ok(result.project.parts[0].logicalIdentity.endsWith("code.asm"));
  const debug = await assemble({ definitions: { DEBUG: 1 }, exportMap, requiredExports: ["DebugEntry"] });
  assert.deepEqual(debug.symbols, { RuntimeStart: 1, DebugEntry: 0, RuntimeEnd: 2 });
});

test("export map renames output only, preserves other keys and excludes EQU addresses", async t => {
  const assemble = await fixture(t, { "entry.asm": "COUNT EQU 7\nBEGIN:\nDB COUNT\nOTHER:\nDB 8\n" });
  const plain = await assemble();
  const mapped = await assemble({
    exportMap: { CompilerCodeStart: "BEGIN", CompilerCount: "COUNT" },
    requiredExports: ["CompilerCodeStart", "CompilerCount", "OTHER"],
  });
  assert.equal(mapped.hex, plain.hex);
  assert.deepEqual(mapped.symbols, { CompilerCodeStart: 0, CompilerCount: 7, OTHER: 1 });
  assert.deepEqual(mapped.addresses, { CompilerCodeStart: 0, OTHER: 1 });
  assert.deepEqual(mapped.project.parts[0].compilerBytes, plain.project.parts[0].compilerBytes);
  assert.equal(Object.hasOwn(mapped.symbols, "BEGIN"), false);
  assert.equal(Object.hasOwn(mapped.symbols, "COUNT"), false);
});

test("required exports distinguish intentional conditional absence from a typo", async t => {
  const assemble = await fixture(t, { "entry.asm": "START:\nDB 1\n" });
  await assert.rejects(assemble({ exportMap: { PublicStart: "TYPO" }, requiredExports: ["PublicStart"] }), /required export is missing: PublicStart/);
  await assert.rejects(assemble({ requiredExports: ["MISSING"] }), /required export is missing: MISSING/);
});

test("export collisions reject rather than overwrite either native value", async t => {
  const assemble = await fixture(t, { "entry.asm": "FIRST:\nDB 1\nSECOND:\nDB 2\n" });
  await assert.rejects(assemble({ exportMap: { SECOND: "FIRST" } }), /export collision: SECOND/);
  await assert.rejects(assemble({ exportMap: { SECOND: "TYPO" }, requiredExports: ["SECOND"] }), /export collision: SECOND/);
});

test("repeated local names are rejected as ambiguous flat dictionary keys", async t => {
  const assemble = await fixture(t, { "entry.asm": "FIRST:\n.loop:\nDB 1\nSECOND:\n.loop:\nDB 2\n" });
  await assert.rejects(assemble(), /export collision: \.LOOP/);
});

test("explicit multiple public names may share one native symbol without retaining its alias", async t => {
  const assemble = await fixture(t, { "entry.asm": "START:\nDB 1\n" });
  const result = await assemble({ exportMap: { PublicStart: "START", OldEntry: "START" } });
  assert.deepEqual(result.symbols, { PublicStart: 0, OldEntry: 0 });
  assert.deepEqual(result.addresses, result.symbols);
});

test("reserved storage alone produces no Intel HEX write records", async t => {
  const assemble = await fixture(t, { "entry.asm": "SPACE:\nDS 4\nEND:\n" });
  const result = await assemble({ target: { start: 0x100, capacity: 4 } });
  assert.equal(result.hex, ":00000001FF\n");
  assert.equal(result.generation.highWater, 0x104);
  assert.equal(result.addresses.END, 0x104);
});

test("source errors retain official filename and line provenance", async t => {
  const assemble = await fixture(t, {
    "entry.asm": '%INCLUDE "broken.asm"\n',
    "broken.asm": "START:\nJP MISSING\n",
  });
  await assert.rejects(assemble(), error => {
    assert.equal(error.name, "AtomAssemblyError");
    assert.equal(error.code, "undefined-symbol");
    assert.ok(error.diagnostic.logicalIdentity.endsWith("broken.asm"));
    assert.equal(error.diagnostic.line, 2);
    return true;
  });
});

test("mid-body textual include syntax is rejected by the official resolver", async t => {
  const assemble = await fixture(t, {
    "entry.asm": 'DB 1\n%INCLUDE "body.asm"\n',
    "body.asm": "DB 2\n",
  });
  await assert.rejects(assemble(), error => {
    assert.equal(error.code, "include-outside-header");
    assert.equal(error.location.line, 2);
    return true;
  });
});

test("oversized source fails instead of being silently split or normalized", async t => {
  const assemble = await fixture(t, { "entry.asm": ";" + " ".repeat(65535) });
  await assert.rejects(assemble(), error => {
    assert.equal(error.code, "source-capacity");
    return true;
  });
});

test("official resolution confines entry and dependency paths to the source root", async t => {
  const assemble = await fixture(t, { "entry.asm": '%INCLUDE "../outside.asm"\n' });
  await assert.rejects(assemble(), error => {
    assert.equal(error.code, "root-escape");
    assert.equal(error.location.line, 1);
    return true;
  });
  await assert.rejects(assemble({ entry: "../outside.asm" }), error => {
    assert.equal(error.code, "root-escape");
    return true;
  });
});
