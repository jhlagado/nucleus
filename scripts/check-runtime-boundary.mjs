import { readdir, readFile } from "node:fs/promises";
import path from "node:path";

const distributionDirectory = path.resolve("dist");
const forbiddenBasenames = new Set([
  "nucleus-runtime.d.ts",
  "nucleus-runtime.js",
  "proof.d.ts",
  "proof.js",
]);
const failures = [];

const visit = async (directory) => {
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const file = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      await visit(file);
      continue;
    }
    if (forbiddenBasenames.has(entry.name)) {
      failures.push(`${path.relative(distributionDirectory, file)} is proof-only`);
    }
    if (!entry.name.endsWith(".js") && !entry.name.endsWith(".d.ts")) continue;
    if ((await readFile(file, "utf8")).includes("@jhlagado/azm")) {
      failures.push(`${path.relative(distributionDirectory, file)} imports AZM`);
    }
  }
};

await visit(distributionDirectory);
if (failures.length > 0) {
  throw new Error(`published runtime boundary failed:\n${failures.join("\n")}`);
}

console.log("published runtime boundary excludes AZM and proof-only modules");
