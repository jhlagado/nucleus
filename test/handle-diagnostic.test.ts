import { describe, expect, it } from "vitest";

import { compileNucleus } from "../src/compiler.js";
import { nucleusDiagnosticMessage } from "../src/diagnostics.js";

const expectDiagnostic = async (
  name: string,
  source: string,
  expected: {
    readonly code: number;
    readonly offset: number;
    readonly line: number;
    readonly column: number;
  },
): Promise<void> => {
  const result = await compileNucleus([{ name, source }]);
  expect(result).toMatchObject({
    success: false,
    diagnostic: {
      ...expected,
      sourcePart: 1,
      sourceName: name,
    },
  });
};

describe("same-line handle diagnostics", () => {
  it("diagnoses detached and ineligible handlers at their exact source positions", async () => {
    await expectDiagnostic(
      "standalone.nu",
      "sub main()\nvar code as u8\nhandle code\nend\n",
      { code: 98, offset: 26, line: 3, column: 1 },
    );

    await expectDiagnostic(
      "next-infallible.nu",
      "sub noop()\nend\nsub main()\nvar code as u8\nnoop()\nhandle code\nend\n",
      { code: 98, offset: 48, line: 6, column: 1 },
    );

    await expectDiagnostic(
      "same-infallible.nu",
      "sub noop()\nend\nsub main()\nvar code as u8\nnoop() handle code\nend\n",
      { code: 98, offset: 48, line: 5, column: 8 },
    );

    await expectDiagnostic(
      "same-infallible-assignment.nu",
      "sub main()\nvar code as u8\nvar value as u8\nvalue = 1 handle code\nend\n",
      { code: 98, offset: 52, line: 4, column: 11 },
    );

    await expectDiagnostic(
      "failable-call.nu",
      "sub main()\nvar code as u8\nwriteOutputByte(1)\nhandle code\nend\n",
      { code: 98, offset: 44, line: 3, column: 19 },
    );

    await expectDiagnostic(
      "failable-assignment.nu",
      "sub main()\nvar code as u8\nvar value as u8\nvalue = readInputByte()\nhandle code\nend\n",
      { code: 98, offset: 65, line: 4, column: 24 },
    );

    await expectDiagnostic(
      "crlf.nu",
      "sub main()\r\nvar code as u8\r\nwriteOutputByte(1)\r\nhandle code\r\nend\r\n",
      { code: 98, offset: 46, line: 3, column: 19 },
    );
  }, 30_000);

  it("preserves the later multipart source identity for standalone handle", async () => {
    const result = await compileNucleus([
      { name: "library.nu", source: "sub noop()\nend\n" },
      { name: "main.nu", source: "sub main()\nvar code as u8\nnoop()\n" },
      { name: "detached.nu", source: "handle code\nend\n" },
    ]);
    expect(result).toMatchObject({
      success: false,
      diagnostic: {
        code: 98,
        sourcePart: 3,
        sourceName: "detached.nu",
        offset: 0,
        line: 1,
        column: 1,
      },
    });
  }, 30_000);

  it("keeps categorically unsupported local handling on the generic diagnostic", async () => {
    await expectDiagnostic(
      "local.nu",
      "sub main()\nvar code as u8\nvar value as u8 = readInputByte() handle code\nend\n",
      { code: 87, offset: 60, line: 3, column: 35 },
    );
  }, 30_000);

  it("preserves valid handlers, propagation, and recovery after rejection", async () => {
    const accepted = [
      [
        "handled-assignment.nu",
        [
          "sub main()",
          "var code as u8",
          "var value as u8",
          "value = readInputByte() handle code",
          "end",
          "end",
          "",
        ].join("\n"),
      ],
      [
        "handled-call.nu",
        [
          "sub main()",
          "var code as u8",
          "writeOutputByte(1) handle code",
          "end",
          "end",
          "",
        ].join("\n"),
      ],
      [
        "propagation.nu",
        [
          "sub relay() fails",
          "writeOutputByte(1) else fail",
          "end",
          "sub main() fails",
          "relay() else fail",
          "end",
          "",
        ].join("\n"),
      ],
    ] as const;

    for (const [name, source] of accepted) {
      expect((await compileNucleus([{ name, source }])).success).toBe(true);
    }

    await expectDiagnostic(
      "rejected.nu",
      "sub main()\nhandle code\nend\n",
      { code: 98, offset: 11, line: 2, column: 1 },
    );
    expect(
      (
        await compileNucleus([
          { name: "recovered.nu", source: "sub main()\nend\n" },
        ])
      ).success,
    ).toBe(true);
  }, 30_000);

  it("publishes the dedicated same-line wording", () => {
    expect(nucleusDiagnosticMessage(98)).toBe(
      "`handle NAME` must follow an eligible failable call on the same logical line",
    );
  });
});
