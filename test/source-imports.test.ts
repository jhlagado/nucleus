import { mkdtemp, mkdir, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";

import { describe, expect, it } from "vitest";

import { NucleusConfigurationError } from "../src/configuration.js";
import {
  parseNucleusImportHeader,
  resolveNucleusImportGraph,
  resolveNucleusImports,
} from "../src/source-imports.js";

const bytes = (text: string): Uint8Array => new TextEncoder().encode(text);

describe("Nucleus import headers", () => {
  it("recognizes leading imports without changing the source bytes", () => {
    const source = bytes(
      '// ordinary comment\r\n\r\n //%  import  "lib/io.nu"\r\nsub main()\r\nend',
    );

    expect(parseNucleusImportHeader("src/main.nu", source)).toEqual([
      "lib/io.nu",
    ]);
    expect(new TextDecoder().decode(source)).toBe(
      '// ordinary comment\r\n\r\n //%  import  "lib/io.nu"\r\nsub main()\r\nend',
    );
  });

  it("rejects malformed and late import directives with source context", () => {
    expect(() =>
      parseNucleusImportHeader(
        "src/main.nu",
        bytes("//% import lib/io.nu\nsub main()\nend\n"),
      ),
    ).toThrowError(NucleusConfigurationError);

    try {
      parseNucleusImportHeader(
        "src/main.nu",
        bytes('sub main()\nend\n//% import "lib/io.nu"'),
      );
      throw new Error("expected late directive rejection");
    } catch (error) {
      expect(error).toBeInstanceOf(NucleusConfigurationError);
      expect((error as NucleusConfigurationError).issues).toEqual([
        {
          path: "src/main.nu:3",
          message: "import directives must appear in the leading header",
        },
      ]);
    }
  });

  it("does not treat a final lone carriage return as a valid header line", () => {
    expect(() =>
      parseNucleusImportHeader(
        "src/main.nu",
        bytes('//% import "lib/io.nu"\r'),
      ),
    ).toThrowError(NucleusConfigurationError);
  });
});

describe("Nucleus import resolution", () => {
  const project = async (): Promise<string> =>
    await mkdtemp(path.join(tmpdir(), "nucleus-imports-"));

  it("orders dependencies before importers and deduplicates diamonds", async () => {
    const root = await project();
    await mkdir(path.join(root, "lib"));
    await writeFile(
      path.join(root, "main.nu"),
      '//% import "lib/left.nu"\n//% import "lib/right.nu"\nsub main()\nend\n',
    );
    await writeFile(
      path.join(root, "lib/left.nu"),
      '//% import "shared.nu"\nconst Left = 1\n',
    );
    await writeFile(
      path.join(root, "lib/right.nu"),
      '//% import "shared.nu"\n//% import "shared.nu"\nconst Right = 2\n',
    );
    await writeFile(path.join(root, "lib/shared.nu"), "const Shared = 3\n");

    const resolved = await resolveNucleusImports({ root, entry: "main.nu" });

    expect(resolved.map(({ name }) => name)).toEqual([
      "lib/shared.nu",
      "lib/left.nu",
      "lib/right.nu",
      "main.nu",
    ]);
    expect(
      resolved.map(({ source }) =>
        new TextDecoder().decode(source as Uint8Array),
      ),
    ).toEqual([
      "const Shared = 3\n",
      '//% import "shared.nu"\nconst Left = 1\n',
      '//% import "shared.nu"\n//% import "shared.nu"\nconst Right = 2\n',
      '//% import "lib/left.nu"\n//% import "lib/right.nu"\nsub main()\nend\n',
    ]);
  });

  it("reports stable dependency edges and raw-byte hashes", async () => {
    const root = await project();
    await mkdir(path.join(root, "lib"));
    await writeFile(path.join(root, "lib/value.nu"), "const Value = 7\n");
    await writeFile(
      path.join(root, "main.nu"),
      '//% import "lib/value.nu"\n//% import "lib/value.nu"\nsub main()\nend\n',
    );

    const graph = await resolveNucleusImportGraph({
      root,
      entry: "main.nu",
    });

    expect(graph.entry).toBe("main.nu");
    expect(graph.dependencies).toEqual([
      {
        name: "lib/value.nu",
        imports: [],
        byteLength: 16,
        sha256:
          "729793768a53280b401152f524f9ace317ca5e0512042e6664e793c9403273e4",
      },
      {
        name: "main.nu",
        imports: ["lib/value.nu"],
        byteLength: 67,
        sha256: expect.stringMatching(/^[0-9a-f]{64}$/),
      },
    ]);
  });

  it("reports complete cycles and missing files as configuration failures", async () => {
    const root = await project();
    await writeFile(path.join(root, "a.nu"), '//% import "b.nu"\n');
    await writeFile(path.join(root, "b.nu"), '//% import "c.nu"\n');
    await writeFile(path.join(root, "c.nu"), '//% import "a.nu"\n');

    await expect(
      resolveNucleusImports({ root, entry: "a.nu" }),
    ).rejects.toMatchObject({
      issues: [
        {
          message: "import cycle: a.nu -> b.nu -> c.nu -> a.nu",
        },
      ],
    });

    await expect(
      resolveNucleusImports({ root, entry: "missing.nu" }),
    ).rejects.toBeInstanceOf(NucleusConfigurationError);
  });

  it("rejects root escapes and ambiguous physical aliases", async () => {
    const root = await project();
    const outside = await project();
    await writeFile(path.join(outside, "outside.nu"), "const Outside = 1\n");
    await writeFile(
      path.join(root, "main.nu"),
      '//% import "../outside.nu"\nsub main()\nend\n',
    );
    await expect(
      resolveNucleusImports({ root, entry: "main.nu" }),
    ).rejects.toBeInstanceOf(NucleusConfigurationError);

    await writeFile(path.join(root, "real.nu"), "const Real = 1\n");
    await symlink(path.join(root, "real.nu"), path.join(root, "alias.nu"));
    await writeFile(
      path.join(root, "main.nu"),
      '//% import "real.nu"\n//% import "alias.nu"\nsub main()\nend\n',
    );
    await expect(
      resolveNucleusImports({ root, entry: "main.nu" }),
    ).rejects.toMatchObject({
      issues: [
        {
          message: expect.stringContaining("same physical source"),
        },
      ],
    });
  });

  it("rejects a resolved graph beyond the compiler part capacity", async () => {
    const root = await project();
    for (let index = 0; index < 9; index += 1) {
      const next = index === 8 ? "" : `//% import \"part${index + 1}.nu\"\n`;
      await writeFile(path.join(root, `part${index}.nu`), `${next}// part\n`);
    }

    await expect(
      resolveNucleusImports({ root, entry: "part0.nu" }),
    ).rejects.toMatchObject({
      issues: [
        {
          message: "dependency graph contains 9 source parts; capacity is 8",
        },
      ],
    });
  });

  it("rejects a resolved logical identity that SP1 cannot encode", async () => {
    const root = await project();
    await writeFile(path.join(root, "café.nu"), "sub main()\nend\n");

    await expect(
      resolveNucleusImports({ root, entry: "café.nu" }),
    ).rejects.toMatchObject({
      issues: [
        {
          message: expect.stringContaining("printable ASCII"),
        },
      ],
    });
  });

  it("accepts an exact source-window fill and rejects the first excess byte", async () => {
    const root = await project();
    const sourcePath = path.join(root, "main.nu");
    await writeFile(sourcePath, Buffer.alloc(2043, 0x20));

    await expect(
      resolveNucleusImports({ root, entry: "main.nu" }),
    ).resolves.toHaveLength(1);

    await writeFile(sourcePath, Buffer.alloc(2044, 0x20));
    await expect(
      resolveNucleusImports({ root, entry: "main.nu" }),
    ).rejects.toMatchObject({
      issues: [
        {
          message:
            "resolved sources require 2049 bytes in the 2048-byte host source window",
        },
      ],
    });
  });
});
