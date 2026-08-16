import { mkdtemp, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";

import { describe, expect, it } from "vitest";

import { parseNobj } from "../src/nobj.js";

const cli = path.resolve("dist/cli.js");

const runCli = (cwd: string, args: readonly string[]) =>
  spawnSync(process.execPath, [cli, ...args], {
    cwd,
    encoding: "utf8",
  });

describe("Nucleus CLI diagnostics", () => {
  it("writes canonical NOBJ and a substantive D8 sidecar", async () => {
    const directory = await mkdtemp(path.join(tmpdir(), "nucleus-cli-"));
    await writeFile(
      path.join(directory, "main.nu"),
      "var result as u8\nsub main()\nresult = 7\nend\n",
    );
    const result = runCli(directory, [
      "build",
      "--json",
      "-o",
      "build/program.nobj",
      "--d8-output",
      "build/program.d8.json",
      "main.nu",
    ]);
    expect(result.status).toBe(0);
    expect(JSON.parse(result.stdout)).toMatchObject({ success: true });
    expect(
      (await readFile(path.join(directory, "build/program.nobj"))).length,
    ).toBeGreaterThan(0);
    const d8 = JSON.parse(
      await readFile(path.join(directory, "build/program.d8.json"), "utf8"),
    );
    expect(d8).toMatchObject({
      format: "d8-debug-map",
      files: {
        "main.nu": {
          segments: expect.arrayContaining([
            expect.objectContaining({ line: 3, kind: "code" }),
          ]),
          symbols: expect.arrayContaining([
            expect.objectContaining({ name: "main", kind: "label" }),
          ]),
        },
      },
    });
  });

  it("keeps JSON format for target-profile parse failures", async () => {
    const directory = await mkdtemp(path.join(tmpdir(), "nucleus-cli-"));
    await writeFile(path.join(directory, "main.nu"), "sub main()\nend\n");
    await writeFile(path.join(directory, "target.json"), "{");
    const result = runCli(directory, [
      "build",
      "--diagnostic-format",
      "json",
      "--target-profile",
      "target.json",
      "main.nu",
    ]);
    expect(result.status).toBe(2);
    expect(JSON.parse(result.stderr)).toMatchObject({
      success: false,
      kind: "configuration",
      message: "Invalid Nucleus target profile JSON",
    });
  });

  it("keeps JSON format for target validation and filesystem failures", async () => {
    const directory = await mkdtemp(path.join(tmpdir(), "nucleus-cli-"));
    await writeFile(path.join(directory, "target.json"), "{");
    const validation = runCli(directory, [
      "target",
      "validate",
      "--json",
      "target.json",
    ]);
    expect(validation.status).toBe(2);
    expect(JSON.parse(validation.stderr)).toMatchObject({
      success: false,
      kind: "configuration",
    });

    const missingSource = runCli(directory, ["build", "--json", "missing.nu"]);
    expect(missingSource.status).toBe(2);
    expect(JSON.parse(missingSource.stderr)).toMatchObject({
      success: false,
      kind: "configuration",
    });
  });

  it("validates a banked layout profile before project source banks are known", async () => {
    const directory = await mkdtemp(path.join(tmpdir(), "nucleus-cli-"));
    await writeFile(
      path.join(directory, "target.json"),
      JSON.stringify({
        schema: "nucleus-target/v1",
        imageBase: 32768,
        imageCapacity: 8192,
        writableBase: 16384,
        writableCapacity: 4096,
        bankCount: 2,
        entryBank: 0,
        services: {
          readInputByte: 28672,
          writeOutputByte: 28675,
          readStorageByte: 28678,
          rewindStorageInput: 28681,
          writeStorageByte: 28684,
          seekStorageOutput: 28687,
          success: 28690,
          unhandledFailure: 28693,
          trap: 28696,
          farCall: 28699,
          farJump: 28702,
        },
      }),
    );

    const result = runCli(directory, [
      "target",
      "validate",
      "--json",
      "target.json",
    ]);

    expect(result.status).toBe(0);
    expect(JSON.parse(result.stdout)).toMatchObject({ valid: true });
  });

  it("reports malformed JSON-mode usage as JSON", async () => {
    const directory = await mkdtemp(path.join(tmpdir(), "nucleus-cli-"));
    const result = runCli(directory, ["build", "--json", "--invented"]);
    expect(result.status).toBe(2);
    expect(JSON.parse(result.stderr)).toEqual({
      success: false,
      kind: "usage",
      message: "unknown option --invented",
    });
  });

  it("discovers one positional entry's imports without changing target output", async () => {
    const directory = await mkdtemp(path.join(tmpdir(), "nucleus-cli-"));
    await writeFile(path.join(directory, "model.nu"), "const Value = 7\n");
    await writeFile(
      path.join(directory, "main.nu"),
      '//% import "model.nu"\nvar result as u8\nsub main()\nresult = Value\nend\n',
    );

    const discovered = runCli(directory, [
      "build",
      "--json",
      "-o",
      "build/discovered.nobj",
      "--d8-output",
      "build/discovered.d8.json",
      "main.nu",
    ]);
    const explicit = runCli(directory, [
      "build",
      "--json",
      "-o",
      "build/explicit.nobj",
      "--d8-output",
      "build/explicit.d8.json",
      "model.nu",
      "main.nu",
    ]);

    expect(discovered.status).toBe(0);
    expect(explicit.status).toBe(0);
    expect(
      await readFile(path.join(directory, "build/discovered.nobj")),
    ).toEqual(await readFile(path.join(directory, "build/explicit.nobj")));
    expect(
      JSON.parse(
        await readFile(
          path.join(directory, "build/discovered.d8.json"),
          "utf8",
        ),
      ),
    ).toEqual(
      JSON.parse(
        await readFile(path.join(directory, "build/explicit.d8.json"), "utf8"),
      ),
    );
  }, 15_000);

  it("preserves exact diagnostics after a retained import comment", async () => {
    const directory = await mkdtemp(path.join(tmpdir(), "nucleus-cli-"));
    await writeFile(path.join(directory, "model.nu"), "const Value = 7\r\n");
    const prefix = '//% import "model.nu"\r\nsub main()\r\n';
    await writeFile(
      path.join(directory, "main.nu"),
      `${prefix}Missing = Value\r\nend\r\n`,
    );

    const result = runCli(directory, ["build", "--json", "main.nu"]);

    expect(result.status).toBe(1);
    expect(JSON.parse(result.stderr)).toMatchObject({
      success: false,
      kind: "source",
      diagnostic: {
        sourceName: "main.nu",
        offset: Buffer.byteLength(prefix),
        line: 3,
        column: 1,
      },
    });
  });

  it("builds a v2 project from its entry dependency graph", async () => {
    const directory = await mkdtemp(path.join(tmpdir(), "nucleus-cli-"));
    await writeFile(path.join(directory, "model.nu"), "const Value = 7\n");
    await writeFile(
      path.join(directory, "main.nu"),
      '//% import "model.nu"\nvar result as u8\nsub main()\nresult = Value\nend\n',
    );
    await writeFile(
      path.join(directory, "target.json"),
      JSON.stringify({ schema: "nucleus-target/v1" }),
    );
    await writeFile(
      path.join(directory, "project.json"),
      JSON.stringify({
        schema: "nucleus-project/v2",
        entry: "main.nu",
        target: "target.json",
        outputs: { nobj: "build/program.nobj" },
      }),
    );

    const result = runCli(directory, [
      "build",
      "--json",
      "--project",
      "project.json",
    ]);

    expect(result.status).toBe(0);
    expect(JSON.parse(result.stdout)).toMatchObject({ success: true });
  });

  it("preserves a v1 project's explicit source order", async () => {
    const directory = await mkdtemp(path.join(tmpdir(), "nucleus-cli-"));
    await writeFile(path.join(directory, "model.nu"), "const Value = 7\n");
    await writeFile(
      path.join(directory, "main.nu"),
      "var result as u8\nsub main()\nresult = Value\nend\n",
    );
    await writeFile(
      path.join(directory, "target.json"),
      JSON.stringify({ schema: "nucleus-target/v1" }),
    );
    await writeFile(
      path.join(directory, "project.json"),
      JSON.stringify({
        schema: "nucleus-project/v1",
        sources: ["model.nu", "main.nu"],
        target: "target.json",
        outputs: { nobj: "build/program.nobj" },
      }),
    );

    const result = runCli(directory, [
      "build",
      "--json",
      "--project",
      "project.json",
    ]);

    expect(result.status).toBe(0);
    expect(JSON.parse(result.stdout)).toMatchObject({ success: true });
  });

  it("reports v2 dependency cycles and late directives as configuration failures", async () => {
    const directory = await mkdtemp(path.join(tmpdir(), "nucleus-cli-"));
    await writeFile(path.join(directory, "target.json"), "{}");
    await writeFile(
      path.join(directory, "project.json"),
      JSON.stringify({
        schema: "nucleus-project/v2",
        entry: "main.nu",
        target: "target.json",
        outputs: { nobj: "build/program.nobj" },
      }),
    );
    await writeFile(
      path.join(directory, "main.nu"),
      '//% import "other.nu"\nsub main()\nend\n',
    );
    await writeFile(path.join(directory, "other.nu"), '//% import "main.nu"\n');

    const cycle = runCli(directory, [
      "build",
      "--json",
      "--project",
      "project.json",
    ]);
    expect(cycle.status).toBe(2);
    expect(JSON.parse(cycle.stderr)).toMatchObject({
      kind: "configuration",
      issues: [
        {
          message: "import cycle: main.nu -> other.nu -> main.nu",
        },
      ],
    });

    await writeFile(
      path.join(directory, "main.nu"),
      'sub main()\nend\n//% import "other.nu"\n',
    );
    const late = runCli(directory, [
      "build",
      "--json",
      "--project",
      "project.json",
    ]);
    expect(late.status).toBe(2);
    expect(JSON.parse(late.stderr)).toMatchObject({
      kind: "configuration",
      issues: [
        {
          path: "main.nu:3",
          message: "import directives must appear in the leading header",
        },
      ],
    });
  });

  it("derives bank ordinals from discovered logical source identities", async () => {
    const directory = await mkdtemp(path.join(tmpdir(), "nucleus-cli-"));
    await writeFile(path.join(directory, "model.nu"), "const Value = 7\n");
    await writeFile(
      path.join(directory, "main.nu"),
      '//% import "model.nu"\nvar result as u8\nsub main()\nresult = Value\nend\n',
    );
    await writeFile(
      path.join(directory, "target.json"),
      JSON.stringify({
        schema: "nucleus-target/v1",
        imageBase: 32768,
        imageCapacity: 8192,
        writableBase: 16384,
        writableCapacity: 4096,
        bankCount: 2,
        entryBank: 0,
      }),
    );
    await writeFile(
      path.join(directory, "project.json"),
      JSON.stringify({
        schema: "nucleus-project/v2",
        entry: "main.nu",
        sourceBanks: { "model.nu": 1, "main.nu": 0 },
        target: "target.json",
        outputs: { nobj: "build/program.nobj" },
      }),
    );

    const result = runCli(directory, [
      "build",
      "--json",
      "--project",
      "project.json",
    ]);

    expect(result.status).toBe(0);
    const parsed = parseNobj(
      await readFile(path.join(directory, "build/program.nobj")),
    );
    expect(parsed.map.partBanks).toEqual([1, 0]);
  });

  it("defaults source names that coincide with object prototype properties", async () => {
    const directory = await mkdtemp(path.join(tmpdir(), "nucleus-cli-"));
    await writeFile(path.join(directory, "constructor"), "const Value = 7\n");
    await writeFile(
      path.join(directory, "main.nu"),
      '//% import "constructor"\nvar result as u8\nsub main()\nresult = Value\nend\n',
    );
    await writeFile(
      path.join(directory, "target.json"),
      JSON.stringify({
        schema: "nucleus-target/v1",
        imageBase: 32768,
        imageCapacity: 8192,
        writableBase: 16384,
        writableCapacity: 4096,
        bankCount: 2,
        entryBank: 0,
      }),
    );
    await writeFile(
      path.join(directory, "project.json"),
      JSON.stringify({
        schema: "nucleus-project/v2",
        entry: "main.nu",
        sourceBanks: { "main.nu": 0 },
        target: "target.json",
        outputs: { nobj: "build/program.nobj" },
      }),
    );

    const result = runCli(directory, [
      "build",
      "--json",
      "--project",
      "project.json",
    ]);

    expect(result.status).toBe(0);
    expect(
      parseNobj(await readFile(path.join(directory, "build/program.nobj"))).map
        .partBanks,
    ).toEqual([0, 0]);
  });
});
