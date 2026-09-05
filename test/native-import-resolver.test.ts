import {
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";

import { afterAll, afterEach, beforeAll, describe, expect, it, vi } from "vitest";

import { runNativeImportResolver } from "../src/native-import-resolver.js";
import { assembleNativeImportResolver } from "../scripts/assemble-native-import-resolver.mjs";
import {
  NodeNamedObjectServices,
  NucleusSystemStatus,
} from "../src/object-services.js";

type ResolverImage = { readonly hex: string; readonly symbols: Readonly<Record<string, number>> };
let freshImage: ResolverImage;
let runFreshResolver: typeof runNativeImportResolver;

// Keep the real host wrapper, substituting only its image dependency. The
// statically imported bundled wrapper above retains its original image.
const resolverWithImage = async (image: ResolverImage): Promise<typeof runNativeImportResolver> => {
  vi.resetModules();
  vi.doMock("../src/generated-native-import-resolver.js", () => ({
    nativeImportResolverHex: image.hex,
    nativeImportResolverSymbols: image.symbols,
  }));
  try {
    return (await import("../src/native-import-resolver.js")).runNativeImportResolver;
  } finally {
    vi.doUnmock("../src/generated-native-import-resolver.js");
  }
};

beforeAll(async () => {
  freshImage = await assembleNativeImportResolver();
  runFreshResolver = await resolverWithImage(freshImage);
});
afterAll(() => {
  vi.doUnmock("../src/generated-native-import-resolver.js");
  vi.resetModules();
});

describe.each(["bundled", "fresh native source"])("the native Z80 import resolver (%s)", variant => {
  const resolve: typeof runNativeImportResolver = (services, entry) =>
    (variant === "bundled" ? runNativeImportResolver : runFreshResolver)(services, entry);
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

    const result = resolve(
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
    const result = resolve(
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
    expect(resolve(services, "a.nu")).toEqual(
      expect.objectContaining({ success: false, status: NucleusSystemStatus.invalid }),
    );
    expect(readFileSync(plan, "utf8")).toBe("prior plan\n");
    expect(services.openHandleCount).toBe(0);

    source(root, "late.nu", 'sub main()\nend\n//% import "a.nu"\n');
    expect(resolve(services, "late.nu").success).toBe(false);
    expect(readFileSync(plan, "utf8")).toBe("prior plan\n");
    expect(services.openHandleCount).toBe(0);

    source(root, "good.nu", "sub main()\nend\n");
    expect(resolve(services, "good.nu").success).toBe(true);
    expect(readFileSync(plan, "utf8")).toBe("SP1 1\nP 0 7 good.nu\nEND\n");
    expect(services.openHandleCount).toBe(0);
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
      resolve(
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

  if (variant === "fresh native source") {
    it("executes the selected fresh image, demonstrated by a private entry mutation", async () => {
      const root = project();
      source(root, "main.nu", "sub main()\nend\n");
      expect(resolve(new NodeNamedObjectServices(root), "main.nu").success).toBe(true);
      const plan = readFileSync(path.join(root, ".nucleus", "source-plan.sp1"), "utf8");
      const entry = freshImage.symbols.NativeImportResolve!;
      // LD A,capacity / SCF / RET. Append a checksummed HEX record to a private
      // string only; the source, generated image and frozen fixture stay intact.
      const record = [4, entry >>> 8, entry & 255, 0, 0x3e, 4, 0x37, 0xc9];
      record.push((-record.reduce((sum, byte) => sum + byte, 0)) & 255);
      const patch = ":" + record.map(byte => byte.toString(16).padStart(2, "0").toUpperCase()).join("");
      const mutatedHex = freshImage.hex.replace(/:00000001FF\s*$/, `${patch}\n:00000001FF\n`);
      expect(mutatedHex).not.toBe(freshImage.hex);
      const mutated = await resolverWithImage({ ...freshImage, hex: mutatedHex });
      const services = new NodeNamedObjectServices(root);
      expect(mutated(services, "main.nu")).toEqual({
        success: false, status: NucleusSystemStatus.capacity, instructions: 4,
      });
      expect(services.openHandleCount).toBe(0);
      expect(readFileSync(path.join(root, ".nucleus", "source-plan.sp1"), "utf8")).toBe(plan);
      // The two ordinary wrappers remain bound to their unmodified images.
      expect(resolve(new NodeNamedObjectServices(root), "main.nu").success).toBe(true);
      expect(runNativeImportResolver(new NodeNamedObjectServices(root), "main.nu").success).toBe(true);
    });
  }
});
