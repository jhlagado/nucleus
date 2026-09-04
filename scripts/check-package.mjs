import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import {
  copyFile,
  mkdir,
  mkdtemp,
  readFile,
  realpath,
  writeFile,
} from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
// Canonical paths avoid npm's Git-package cache issues through /tmp symlinks.
const temporary = await mkdtemp(
  path.join(await realpath(os.tmpdir()), "nucleus-package-"),
);
const consumer = path.join(temporary, "consumer");
await mkdir(consumer);
const npm = process.platform === "win32" ? "npm.cmd" : "npm";
const run = (command, args, cwd) =>
  execFileSync(command, args, {
    cwd,
    encoding: "utf8",
    timeout: 180_000,
    maxBuffer: 16 * 1024 * 1024,
  });

try {
  // The release gate builds and verifies dist first. Packing must not recurse
  // into lifecycle checks or regenerate the artifact under examination.
  const [packed] = JSON.parse(
    run(
      npm,
      ["pack", "--json", "--ignore-scripts", "--pack-destination", temporary],
      root,
    ),
  );
  assert.equal(typeof packed?.filename, "string");
  assert.equal(path.basename(packed.filename), packed.filename);
  const files = new Set(packed.files.map((file) => file.path));
  const manifest = JSON.parse(
    await readFile(path.join(root, "package.json"), "utf8"),
  );
  for (const target of Object.values(manifest.exports)) {
    assert.equal(
      typeof target,
      "string",
      "update package verification for conditional exports",
    );
    assert.ok(
      files.has(target.replace(/^\.\//, "")),
      `missing exported file: ${target}`,
    );
    if (target.endsWith(".js")) {
      assert.ok(
        files.has(target.replace(/^\.\//, "").replace(/\.js$/, ".d.ts")),
        `missing public types: ${target}`,
      );
    }
  }
  for (const file of ["dist/cli.js", "LICENSE", "library/console/output.nu"]) {
    assert.ok(files.has(file), `missing package file: ${file}`);
  }
  for (const file of files) {
    assert.ok(
      !/^(?:scripts|test|src)\//.test(file),
      `development source shipped: ${file}`,
    );
    assert.ok(
      !/^dist\/(?:proof|nucleus-runtime)\.(?:js|d\.ts)$/.test(file),
      `proof-only module shipped: ${file}`,
    );
  }
  await writeFile(
    path.join(consumer, "package.json"),
    JSON.stringify({ private: true, type: "module" }) + "\n",
  );
  await copyFile(
    path.join(root, "scripts/fixtures/installed-package-smoke.mjs"),
    path.join(consumer, "smoke.mjs"),
  );
  // Git runtime dependencies require their normal preparation scripts.
  run(
    npm,
    [
      "install",
      "--omit=dev",
      "--no-audit",
      "--no-fund",
      "--cache",
      path.join(temporary, "npm-cache"),
      path.join(temporary, packed.filename),
    ],
    consumer,
  );
  const result = execFileSync(process.execPath, ["smoke.mjs"], {
    cwd: consumer,
    encoding: "utf8",
    timeout: 120_000,
    maxBuffer: 4 * 1024 * 1024,
    // Prove the installed package without development import hooks or paths.
    env: { ...process.env, NODE_OPTIONS: "", NODE_PATH: "" },
  });
  console.log(result.trim());
  console.log(
    JSON.stringify(
      {
        tarball: path.join(temporary, packed.filename),
        integrity: packed.integrity,
        files: packed.entryCount,
        unpackedBytes: packed.unpackedSize,
      },
      null,
      2,
    ),
  );
} catch (error) {
  console.error(`Package verification failed; retained evidence: ${temporary}`);
  throw error;
}
