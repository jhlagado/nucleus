import { createHash } from "node:crypto";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { parseIntelHex } from "@jhlagado/debug80-runtime";

import { assembleAtomSource } from "./atom-source.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const entry = "vertical-slice/cpm22-native-compiler.asm";
const [baseline, packageManifest] = await Promise.all(
  ["cpm22-release-baseline.json", "package.json"].map(async (name) =>
    JSON.parse(await readFile(path.join(root, name), "utf8")),
  ),
);
const atomDependency = packageManifest.devDependencies["atom-z80"];
const atomRevision = /#([0-9a-f]{40})$/u.exec(atomDependency)?.[1];
if (atomRevision === undefined) {
  throw new Error("atom-z80 must select one exact Git revision");
}

const assembled = await assembleAtomSource(entry);
const memory = parseIntelHex(assembled.hex).memory;
const loadAddress = assembled.symbols.CpmCompilerTransientStart;
const endAddress = assembled.symbols.CpmCompilerResidentEnd;
if (loadAddress !== 0x0100 || !Number.isInteger(endAddress)) {
  throw new Error("CP/M compiler omitted its fixed transient boundaries");
}
const bytes = memory.slice(loadAddress, endAddress);
const sha256 = createHash("sha256").update(bytes).digest("hex");
if (bytes.length !== baseline.bytes || sha256 !== baseline.sha256) {
  throw new Error(
    `NUC.COM differs from release baseline: ${bytes.length} bytes, ${sha256}`,
  );
}
if (packageManifest.version !== baseline.version) {
  throw new Error("CP/M release baseline and package versions differ");
}

const manifest = {
  format: "nucleus-cpm22-artifact-v1",
  artifact: "NUC.COM",
  version: baseline.version,
  bytes: bytes.length,
  sha256,
  assembler: { name: "atom-z80", revision: atomRevision },
  loadAddress,
  entryAddress: loadAddress,
  endAddress,
  source: `asm/${entry}`,
  contract: "docs/cpm22-command-line.md",
};
const outputDirectory = path.join(root, "dist");
await mkdir(outputDirectory, { recursive: true });
await Promise.all([
  writeFile(path.join(outputDirectory, "NUC.COM"), bytes),
  writeFile(
    path.join(outputDirectory, "NUC.manifest.json"),
    `${JSON.stringify(manifest, undefined, 2)}\n`,
  ),
]);
console.log(
  `Built NUC.COM: ${manifest.bytes} bytes, sha256 ${manifest.sha256}`,
);
