import { mkdtemp, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";

import { compile } from "@jhlagado/azm/compile";

const source = `.org $100

.routine in A out A,carry,zero clobbers sign,parity,halfCarry,HL
EmitByte:
        LD HL,0
        OR A
        RET

.routine noreturn
EmitByteInlineChecked:
        POP HL
        LD A,(HL)
        INC HL
        PUSH HL
        CALL EmitByte
        RET NC
        POP HL
        RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,HL
Caller:
        CALL EmitByteInlineChecked
        .db $42
        XOR A
        RET

AbortSp: .dw 0

.routine noreturn
CompilerAbort:
        LD SP,(AbortSp)
        SCF
        RET
`;

const directory = await mkdtemp(path.join(os.tmpdir(), "nucleus-azm-check-"));
const sourcePath = path.join(directory, "noreturn-inline-operand.asm");
const negativeSourcePath = path.join(directory, "returning-inline-operand.asm");

const toolchainError = (details) =>
  new Error(
    [
      "The resolved @jhlagado/azm cannot prove Nucleus's noreturn inline-operand convention.",
      "Link the current Debug80 AZM checkout with `npm link @jhlagado/azm`, then retry.",
      ...details,
    ].join("\n"),
  );

try {
  await writeFile(sourcePath, source, "utf8");
  await writeFile(
    negativeSourcePath,
    source.replace(".routine noreturn", ".routine"),
    "utf8",
  );
  const result = await compile(sourcePath, {
    emitBin: false,
    emitHex: false,
    emitD8m: false,
    registerContracts: "strict",
    emitRegisterReport: true,
    registerContractsReportFormat: "json",
  });
  const errors = result.diagnostics.filter(({ severity }) => severity === "error");
  if (errors.length > 0) {
    throw toolchainError(
      errors.map(
        ({ line, column, message }) =>
          `noreturn-inline-operand.asm:${line ?? "?"}:${column ?? "?"} ${message}`,
      ),
    );
  }
  const report = result.artifacts.find(
    (artifact) => artifact.kind === "register-contracts-report",
  );
  const summaries = report?.json?.summaries;
  const inlineSummary = summaries?.find(
    ({ name }) => name === "EmitByteInlineChecked",
  );
  const callerSummary = summaries?.find(({ name }) => name === "Caller");
  const abortSummary = summaries?.find(({ name }) => name === "CompilerAbort");
  if (
    inlineSummary?.noreturn !== true ||
    abortSummary?.noreturn !== true ||
    abortSummary?.stackBalanced !== true ||
    abortSummary.hasUnknownStackEffect !== false ||
    callerSummary?.stackBalanced !== true ||
    callerSummary.hasUnknownStackEffect !== false
  ) {
    throw toolchainError([
      "The strict register-contract report omitted a required noreturn, restored-SP, or balanced-caller proof.",
    ]);
  }

  const negativeResult = await compile(negativeSourcePath, {
    emitBin: false,
    emitHex: false,
    emitD8m: false,
    registerContracts: "strict",
  });
  if (!negativeResult.diagnostics.some(({ severity }) => severity === "error")) {
    throw toolchainError([
      "The negative control passed even though its inline-operand helper lacks a noreturn contract.",
    ]);
  }
} finally {
  await rm(directory, { recursive: true, force: true });
}
