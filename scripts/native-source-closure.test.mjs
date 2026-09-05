import assert from "node:assert/strict";
import { existsSync, readdirSync, readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";
import { isNativeCompilerEntry } from "./assemble-native-compiler.mjs";
import { isNativeProofEntry } from "./assemble-native-proof.mjs";
import { isNativeNobjEntry } from "./assemble-native-nobj.mjs";

const root = fileURLToPath(new URL("../", import.meta.url));
function files(directory) {
  return readdirSync(directory, { withFileTypes: true }).flatMap(item => {
    const name = path.join(directory, item.name);
    return item.isDirectory() ? files(name) : [name];
  });
}

test("the source translator and obsolete migration compositions are absent", () => {
  for (const file of [
    "scripts/atom-source.mjs", "scripts/atom-source.d.mts",
    "scripts/atom-source-translation.mjs", "scripts/atom-source.test.mjs",
    "scripts/fixtures/atom-placement.asm",
    "asm/vertical-slice/compiler-profile-legacy.asmi",
    "asm/vertical-slice/nucleus-target-runtime-link.asm",
    "asm/vertical-slice/nucleus-runtime-link-context.asmi",
    "asm/vertical-slice/target-z80-runtime.asm",
  ]) assert.equal(existsSync(path.join(root, file)), false, file);
});

test("canonical assembly has native directives and explicitly short declarations", () => {
  for (const file of files(path.join(root, "asm")).filter(file => /\.(asm|asmi)$/.test(file))) {
    const text = readFileSync(file, "utf8");
    assert.ok(Buffer.byteLength(text) <= 0xffff, `Oversized ATOM source part: ${file}`);
    for (const [index, line] of text.split("\n").entries()) {
      const location = `${file}:${index + 1}`;
      assert.ok(!/^\s*(?:[A-Za-z_.$?][\w.$?]*:?\s+)?\.(?:include|if|else|endif|equ|org|db|dw|ds|routine|end)\b/i.test(line), location);
      const declaration = /^\s*([A-Za-z_.$?][\w.$?]*)\s*(?::|\s+EQU\b)/i.exec(line);
      // ATOM also supports short scoped locals (the native MON-3 pilot uses
      // .keys/.fail). Their enclosing public exports remain explicit.
      if (declaration) assert.match(declaration[1], /^(?:[A-Z][A-Z0-9_]{0,7}|\.[A-Za-z_][A-Za-z0-9_]{0,6})$/, location);
    }
  }
});

test("public output maps have no accidental public or native name collisions", () => {
  const names = new Map(), nativeNames = new Map();
  for (const file of readdirSync(path.join(root, "asm")).filter(file => /^atom-.*-symbols\.json$/.test(file))) {
    const map = JSON.parse(readFileSync(path.join(root, "asm", file), "utf8"));
    for (const [name, native] of Object.entries(map)) {
      assert.equal(names.has(name), false, `${file}: duplicate public name ${name}`);
      assert.equal(nativeNames.has(native), false, `${file}: duplicate native name ${native}`);
      assert.match(native, /^[A-Z][A-Z0-9_]{0,7}$/, `${file}: ${name}`);
      names.set(name, file); nativeNames.set(native, name);
    }
  }
});

test("every executable proof manifest has an explicit native assembly route", () => {
  const special = new Set(["tokenizer-trace-proof.asm", "stage7-ll1-engine-proof.asm"]);
  let count = 0;
  for (const file of files(path.join(root, "proofs")).filter(file => file.endsWith(".json"))) {
    const manifest = JSON.parse(readFileSync(file, "utf8"));
    if (typeof manifest.source !== "string") continue;
    const source = path.resolve(path.dirname(file), manifest.source);
    assert.equal(path.dirname(source), path.join(root, "asm/vertical-slice"), file);
    const entry = path.basename(source);
    assert.ok(isNativeCompilerEntry(entry) || isNativeProofEntry(entry) || isNativeNobjEntry(entry) || special.has(entry), `${file}: ${entry}`);
    count++;
  }
  assert.ok(count >= 30, "Proof inventory unexpectedly empty or incomplete");
});

test("production source and build utilities cannot import retired assembly adapters", () => {
  for (const file of [...files(path.join(root, "src")), ...files(path.join(root, "scripts"))]
    .filter(file => /\.(?:ts|mjs)$/.test(file) && !file.endsWith(".test.mjs"))) {
    const text = readFileSync(file, "utf8");
    assert.ok(!/["'][^"']*\/atom-source(?:-translation)?\.mjs["']/.test(text), file);
  }
});
