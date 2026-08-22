import { mkdtemp, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";

import { describe, expect, it } from "vitest";

const cli = path.resolve("dist/cli.js");

const runCli = (cwd: string, args: readonly string[]) =>
  spawnSync(process.execPath, [cli, ...args], {
    cwd,
    encoding: "utf8",
  });

describe("Nucleus CLI diagnostics", () => {
  it("discovers imports from one entry source and preserves both D8 identities", async () => {
    const directory = await mkdtemp(path.join(tmpdir(), "nucleus-cli-import-"));
    await writeFile(
      path.join(directory, "value.nu"),
      "sub value() as u8\nreturn 7\nend\n",
    );
    await writeFile(
      path.join(directory, "main.nu"),
      '//% import "value.nu"\nvar result as u8\nsub main()\nresult = value()\nend\n',
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
    const d8 = JSON.parse(
      await readFile(path.join(directory, "build/program.d8.json"), "utf8"),
    );
    expect(Object.keys(d8.files)).toEqual(["value.nu", "main.nu"]);
    expect(d8.files["value.nu"].symbols).toEqual(
      expect.arrayContaining([expect.objectContaining({ name: "value" })]),
    );
    expect(d8.files["main.nu"].symbols).toEqual(
      expect.arrayContaining([expect.objectContaining({ name: "main" })]),
    );
  });

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

  it("can route the authoritative compiler through MON3 services", async () => {
    const directory = await mkdtemp(path.join(tmpdir(), "nucleus-cli-mon3-"));
    await writeFile(path.join(directory, "main.nu"), "sub main()\nend\n");
    const direct = runCli(directory, [
      "build",
      "--quiet",
      "-o",
      "direct.nobj",
      "main.nu",
    ]);
    const mon3 = runCli(directory, [
      "build",
      "--quiet",
      "--host-transport",
      "mon3",
      "-o",
      "mon3.nobj",
      "main.nu",
    ]);
    expect(direct.status).toBe(0);
    expect(mon3.status).toBe(0);
    expect(await readFile(path.join(directory, "mon3.nobj"))).toEqual(
      await readFile(path.join(directory, "direct.nobj")),
    );
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
});
