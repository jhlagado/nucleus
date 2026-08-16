import { spawn } from "node:child_process";
import {
  access,
  mkdtemp,
  mkdir,
  readFile,
  readdir,
  rm,
  writeFile,
} from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repository = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);

const run = async (command, args, cwd, expectedCode = 0) => {
  return await new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      cwd,
      env: process.env,
      stdio: ["ignore", "pipe", "pipe"],
    });
    let stdout = "";
    let stderr = "";
    child.stdout.setEncoding("utf8");
    child.stderr.setEncoding("utf8");
    child.stdout.on("data", (chunk) => {
      stdout += chunk;
    });
    child.stderr.on("data", (chunk) => {
      stderr += chunk;
    });
    child.on("error", reject);
    child.on("close", (code) => {
      if (code === expectedCode) {
        resolve({ stdout, stderr, code });
        return;
      }
      reject(
        new Error(
          `${command} ${args.join(" ")} exited ${code}, expected ${expectedCode}\n${stdout}${stderr}`,
        ),
      );
    });
  });
};

const packageRoot = async (specifier, packageName) => {
  let directory = path.dirname(fileURLToPath(import.meta.resolve(specifier)));
  while (true) {
    try {
      const manifest = JSON.parse(
        await readFile(path.join(directory, "package.json"), "utf8"),
      );
      if (manifest.name === packageName) return directory;
    } catch (error) {
      if (error?.code !== "ENOENT") throw error;
    }
    const parent = path.dirname(directory);
    if (parent === directory) {
      throw new Error(`cannot locate package root for ${packageName}`);
    }
    directory = parent;
  }
};

const manifest = JSON.parse(
  await readFile(path.join(repository, "package.json"), "utf8"),
);
if (manifest.dependencies?.["@jhlagado/azm"] === undefined) {
  throw new Error("the packed CLI must declare @jhlagado/azm at runtime");
}
if (!manifest.files?.includes("examples/")) {
  throw new Error("the packed CLI must include its runnable examples");
}

const [azmRoot, runtimeRoot] = await Promise.all([
  packageRoot("@jhlagado/azm", "@jhlagado/azm"),
  packageRoot("@jhlagado/debug80-runtime", "@jhlagado/debug80-runtime"),
]);

const temporaryDirectory = await mkdtemp(
  path.join(os.tmpdir(), "nucleus-package-check-"),
);
try {
  const packDirectory = path.join(temporaryDirectory, "pack");
  const consumerDirectory = path.join(temporaryDirectory, "consumer");
  await mkdir(packDirectory);
  await mkdir(consumerDirectory);
  await run(
    "npm",
    ["pack", "--ignore-scripts", "--pack-destination", packDirectory],
    repository,
  );
  const archives = (await readdir(packDirectory)).filter((name) =>
    name.endsWith(".tgz"),
  );
  if (archives.length !== 1) {
    throw new Error(`expected one package archive, found ${archives.length}`);
  }
  const archive = path.join(packDirectory, archives[0]);
  await writeFile(
    path.join(consumerDirectory, "package.json"),
    `${JSON.stringify(
      {
        private: true,
        type: "module",
        dependencies: {
          "@jhlagado/azm": `file:${azmRoot}`,
          "@jhlagado/debug80-runtime": `file:${runtimeRoot}`,
          "@jhlagado/nucleus": `file:${archive}`,
        },
      },
      null,
      2,
    )}\n`,
  );
  await run(
    "npm",
    ["install", "--ignore-scripts", "--no-audit", "--no-fund"],
    consumerDirectory,
  );

  const nucleus = path.join(consumerDirectory, "node_modules/.bin/nucleus");
  const version = await run(nucleus, ["--version"], consumerDirectory);
  if (version.stdout.trim() !== manifest.version) {
    throw new Error(`packed CLI reported version ${version.stdout.trim()}`);
  }
  const capabilities = JSON.parse(
    (await run(nucleus, ["capabilities", "--json"], consumerDirectory)).stdout,
  );
  if (capabilities.hostApiVersion !== 1) {
    throw new Error("packed CLI returned invalid capabilities");
  }

  await access(
    path.join(
      consumerDirectory,
      "node_modules/@jhlagado/nucleus/examples/import-project/nucleus-project.json",
    ),
  );
  const installedExample = path.join(
    consumerDirectory,
    "node_modules/@jhlagado/nucleus/examples/import-project",
  );
  await run(
    nucleus,
    ["build", "--project", "nucleus-project.json", "--quiet"],
    installedExample,
  );

  const invalidSource = path.join(consumerDirectory, "invalid.nu");
  await writeFile(invalidSource, "sub main()\n@\nend\n");
  const sourceFailure = await run(
    nucleus,
    ["build", "--json", path.basename(invalidSource)],
    consumerDirectory,
    1,
  );
  if (JSON.parse(sourceFailure.stderr).kind !== "source") {
    throw new Error("packed CLI did not classify a source diagnostic");
  }
  const usageFailure = await run(
    nucleus,
    ["build", "--json", "--invented"],
    consumerDirectory,
    2,
  );
  if (JSON.parse(usageFailure.stderr).kind !== "usage") {
    throw new Error("packed CLI did not classify a usage failure");
  }

  const nobjPath = path.join(installedExample, "build/program.nobj");
  const hexPath = path.join(installedExample, "build/program.hex");
  const d8Path = path.join(installedExample, "build/program.d8.json");
  const targetPath = path.join(installedExample, "nucleus-target.json");
  const [nobj, hex, d8] = await Promise.all([
    readFile(nobjPath),
    readFile(hexPath, "utf8"),
    readFile(d8Path, "utf8"),
  ]);
  if (nobj.length === 0 || !hex.endsWith(":00000001FF\n")) {
    throw new Error("packed CLI did not publish valid NOBJ and HEX artifacts");
  }
  const debugMap = JSON.parse(d8);
  if (debugMap.format !== "d8-debug-map") {
    throw new Error("packed CLI did not publish a D8 source map");
  }

  const inspectScript = `
    import { readFile } from "node:fs/promises";
    import { createZ80Runtime } from "@jhlagado/debug80-runtime";
    import { materializeNobj, parseNobj } from "@jhlagado/nucleus/nobj";
    const parsed = parseNobj(await readFile(${JSON.stringify(nobjPath)}));
    const target = JSON.parse(await readFile(${JSON.stringify(targetPath)}, "utf8"));
    if (parsed.map.partBanks.length !== 2) process.exit(1);
    const materialized = materializeNobj(parsed);
    if (materialized.flatImage === undefined) process.exit(1);
    const memory = new Uint8Array(0x10000);
    memory.set(materialized.flatImage, parsed.begin.imageBase);
    const runtime = createZ80Runtime(
      { memory, startAddress: parsed.map.entryAddress },
      parsed.map.entryAddress,
    );
    runtime.hardware.memory.set(
      [0x3e, 0xa5, 0x76],
      target.services.success,
    );
    runtime.hardware.memory.set(
      [0x3e, 0xe1, 0x76],
      target.services.unhandledFailure,
    );
    runtime.hardware.memory.set(
      [0x3e, 0xe2, 0x76],
      target.services.trap,
    );
    let instructions = 0;
    while (!runtime.isHalted() && instructions < 100000) {
      runtime.step();
      instructions += 1;
    }
    if (!runtime.isHalted() || runtime.cpu.a !== 0xa5) process.exit(1);
    if (runtime.hardware.memory[parsed.map.bssBase] !== 7) process.exit(1);
  `;
  await run(
    process.execPath,
    ["--input-type=module", "--eval", inspectScript],
    consumerDirectory,
  );

  console.log(
    "Packed Nucleus CLI compiled and launched the import-directed example.",
  );
} finally {
  await rm(temporaryDirectory, { recursive: true, force: true });
}
