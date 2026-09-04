// Copied to an isolated consumer directory by check-package.mjs.
import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import { readFile, writeFile, access } from "node:fs/promises";
import { createRequire } from "node:module";
import path from "node:path";
import { compileNucleus, runNucleusNobj } from "@jhlagado/nucleus";

const require = createRequire(import.meta.url);
for (const assembler of ["atom-z80", "@jhlagado/azm"]) {
  assert.throws(() => require.resolve(assembler), { code: "MODULE_NOT_FOUND" });
}
const packageRoot = path.resolve("node_modules/@jhlagado/nucleus");
const manifest = JSON.parse(
  await readFile(path.join(packageRoot, "package.json"), "utf8"),
);
for (const subpath of Object.keys(manifest.exports)) {
  await import(
    subpath === "." ? manifest.name : manifest.name + subpath.slice(1)
  );
}
await access(
  path.resolve(
    "node_modules/.bin",
    process.platform === "win32" ? "nucleus.cmd" : "nucleus",
  ),
);

const source =
  "sub main() fails\nvar value as u8 = readInputByte() else fail\nwriteOutputByte(value) else fail\nend\n";
const compiled = await compileNucleus([{ name: "echo.nu", source }]);
assert.equal(compiled.success, true);
const executed = runNucleusNobj(compiled.nobj, {}, { input: [82] });
assert.equal(executed.success, true);
assert.deepEqual([...executed.output], [82]);
assert.ok(executed.loaderInstructions > 0);
assert.ok(executed.programInstructions > 0);

await writeFile("echo.nu", source);
const cli = path.join(packageRoot, "dist/cli.js");
const options = { encoding: "utf8", timeout: 30_000 };
execFileSync(
  process.execPath,
  [cli, "build", "--quiet", "-o", "echo.nobj", "echo.nu"],
  options,
);
const good = await readFile("echo.nobj");
const run = spawnSync(process.execPath, [cli, "run", "echo.nobj"], {
  ...options,
  input: "R",
});
assert.equal(run.status, 0, run.stderr);
assert.equal(run.stdout, "R");
assert.equal(run.stderr, "");

await writeFile("bad.nu", "this is not a Nucleus program\n");
const rejected = spawnSync(
  process.execPath,
  [cli, "build", "--quiet", "-o", "echo.nobj", "bad.nu"],
  options,
);
assert.equal(rejected.status, 1);
assert.deepEqual(
  await readFile("echo.nobj"),
  good,
  "failed compilation replaced the previous object",
);
console.log(
  "Installed package: public exports, API and CLI execution, and failed-build preservation pass without assemblers.",
);
