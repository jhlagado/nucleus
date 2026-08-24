import {
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";

import { afterEach, describe, expect, it } from "vitest";

import { runNativeImportResolver } from "../src/native-import-resolver.js";
import {
  NodeNamedObjectServices,
  NucleusSystemStatus,
} from "../src/object-services.js";

describe("the native Z80 import resolver", () => {
  const roots: string[] = [];
  afterEach(() => {
    for (const root of roots.splice(0)) {
      rmSync(root, { recursive: true, force: true });
    }
  });

  const project = (): string => {
    const root = mkdtempSync(path.join(tmpdir(), "nucleus-native-resolver-"));
    roots.push(root);
    mkdirSync(path.join(root, ".nucleus"));
    return root;
  };

  const source = (root: string, name: string, text: string): void => {
    const destination = path.join(root, ...name.split("/"));
    mkdirSync(path.dirname(destination), { recursive: true });
    writeFileSync(destination, text);
  };

  it("orders a diamond, deduplicates it, and falls back to the standard library", () => {
    const root = project();
    source(
      root,
      "main.nu",
      [
        '//% import "lib/left.nu"',
        '//% import "lib/right.nu"',
        '//% import "console.nu"',
        "sub main()",
        "end",
        "",
      ].join("\n"),
    );
    source(root, "lib/left.nu", '//% import "shared.nu"\nconst Left = 1\n');
    source(root, "lib/right.nu", '//% import "shared.nu"\nconst Right = 2\n');
    source(root, "lib/shared.nu", "const Shared = 3\n");
    source(root, "@nucleus/console.nu", "sub print()\nend\n");

    const result = runNativeImportResolver(
      new NodeNamedObjectServices(root),
      "main.nu",
    );
    expect(result).toEqual(
      expect.objectContaining({
        success: true,
        status: NucleusSystemStatus.success,
      }),
    );
    expect(
      readFileSync(path.join(root, ".nucleus", "source-plan.sp1"), "utf8"),
    ).toBe(
      [
        "SP1 5",
        "P 0 13 lib/shared.nu",
        "P 0 11 lib/left.nu",
        "P 0 12 lib/right.nu",
        "P 0 19 @nucleus/console.nu",
        "P 0 7 main.nu",
        "END",
        "",
      ].join("\n"),
    );
  });

  it("refills while scanning headers and normalizes relative components", () => {
    const root = project();
    source(
      root,
      "dir/main.nu",
      `${`// ${"x".repeat(300)}\r\n`}//% import "../shared.nu"\r\nsub main()\r\nend\r\n`,
    );
    source(root, "shared.nu", "const Shared = 1\n");
    const result = runNativeImportResolver(
      new NodeNamedObjectServices(root),
      "dir/main.nu",
    );
    expect(result.success).toBe(true);
    expect(
      readFileSync(path.join(root, ".nucleus", "source-plan.sp1"), "utf8"),
    ).toContain("P 0 9 shared.nu\nP 0 11 dir/main.nu\n");
  });

  it("rejects cycles and late directives without replacing the prior plan", () => {
    const root = project();
    const plan = path.join(root, ".nucleus", "source-plan.sp1");
    writeFileSync(plan, "prior plan\n");
    source(root, "a.nu", '//% import "b.nu"\n');
    source(root, "b.nu", '//% import "a.nu"\n');
    const services = new NodeNamedObjectServices(root);
    expect(runNativeImportResolver(services, "a.nu")).toEqual(
      expect.objectContaining({ success: false, status: NucleusSystemStatus.invalid }),
    );
    expect(readFileSync(plan, "utf8")).toBe("prior plan\n");
    expect(services.openHandleCount).toBe(0);

    source(root, "late.nu", 'sub main()\nend\n//% import "a.nu"\n');
    expect(runNativeImportResolver(services, "late.nu").success).toBe(false);
    expect(readFileSync(plan, "utf8")).toBe("prior plan\n");
  });

  it("reports the eight-part dependency capacity through the common status", () => {
    const root = project();
    for (let index = 0; index < 9; index += 1) {
      source(
        root,
        `part${index}.nu`,
        index === 8 ? "const Last = 1\n" : `//% import "part${index + 1}.nu"\n`,
      );
    }
    expect(
      runNativeImportResolver(
        new NodeNamedObjectServices(root),
        "part0.nu",
      ),
    ).toEqual(
      expect.objectContaining({
        success: false,
        status: NucleusSystemStatus.capacity,
      }),
    );
  });
});
