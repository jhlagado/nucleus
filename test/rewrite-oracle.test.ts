import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import path from "node:path";

import { describe, expect, it } from "vitest";

import {
  compileNucleus,
  nucleusCompilerInfo,
  writeNucleusIntelHex,
  type NucleusCompileSuccess,
} from "../src/compiler.js";
import { normalCompilerSymbols } from "../src/generated-compiler-images.js";
import {
  rewriteOracleCoverage,
  rewriteOracleDiagnosticCases,
  rewriteOracleSuccessCases,
} from "./rewrite-oracle-corpus.js";

const fixturePath = path.resolve(
  import.meta.dirname,
  "fixtures",
  "rewrite-oracle.json",
);
const implementationPlanPath = path.resolve(
  import.meta.dirname,
  "../docs/implementation-plan.md",
);

const sha256 = (value: string | Uint8Array): string =>
  createHash("sha256").update(value).digest("hex");

const d8Json = (map: unknown): string => `${JSON.stringify(map, null, 2)}\n`;

const readCapacityLedger = async () => {
  const source = await readFile(implementationPlanPath, "utf8");
  const heading = "## Capacity ledger";
  const start = source.indexOf(heading);
  if (start < 0)
    throw new Error(`missing ${heading} in ${implementationPlanPath}`);
  const remainder = source.slice(start + heading.length);
  const nextHeading = remainder.search(/\r?\n## /);
  const section = nextHeading < 0 ? remainder : remainder.slice(0, nextHeading);
  const lines = section.split(/\r?\n/);
  const table = lines.filter((line) => line.startsWith("|"));
  if (table.length < 3) {
    throw new Error(`missing capacity table in ${implementationPlanPath}`);
  }
  return table.slice(2).map((line) => {
    const cells = line
      .split("|")
      .slice(1, -1)
      .map((cell) => cell.trim());
    if (cells.length !== 5) {
      throw new Error(`invalid capacity row: ${line}`);
    }
    return { account: cells[0], limit: cells[1], evidence: cells[4] };
  });
};

const artifactExpectation = (result: NucleusCompileSuccess) => ({
  nobjLength: result.nobj.length,
  nobjSha256: sha256(result.nobj),
  begin: result.materialized.parsed.begin,
  map: result.materialized.parsed.map,
  ...(result.materialized.flatImage === undefined
    ? {}
    : {
        flatImage: {
          length: result.materialized.flatImage.length,
          sha256: sha256(result.materialized.flatImage),
          hexSha256: sha256(writeNucleusIntelHex(result)),
        },
      }),
  banks: result.materialized.banks?.map((bank, index) => ({
    bank: index,
    length: bank.length,
    sha256: sha256(bank),
  })),
  d8: result.debugMapping?.maps.map(({ bank, map }) => ({
    bank,
    sha256: sha256(d8Json(map)),
  })),
});

const collectOracle = async () => {
  const info = await nucleusCompilerInfo();
  const successes = [];
  for (const testCase of rewriteOracleSuccessCases) {
    const normal = await compileNucleus(testCase.sources, testCase.target);
    const debug = await compileNucleus(testCase.sources, testCase.target, {
      debugMap: true,
    });
    if (!normal.success) {
      throw new Error(`${testCase.name} normal: ${JSON.stringify(normal)}`);
    }
    if (!debug.success) {
      throw new Error(`${testCase.name} debug: ${JSON.stringify(debug)}`);
    }
    if (!normal.success || !debug.success) continue;
    expect(debug.nobj, `${testCase.name} normal/debug NOBJ`).toEqual(
      normal.nobj,
    );
    expect(debug.materialized, `${testCase.name} normal/debug image`).toEqual(
      normal.materialized,
    );
    successes.push({
      name: testCase.name,
      expectation: artifactExpectation(debug),
      baselineMetrics: {
        normal: { instructions: normal.instructions, cycles: normal.cycles },
        debug: { instructions: debug.instructions, cycles: debug.cycles },
      },
    });
  }

  const diagnostics = [];
  for (const testCase of rewriteOracleDiagnosticCases) {
    const normal = await compileNucleus(
      testCase.sources,
      testCase.target ?? {},
    );
    const debug = await compileNucleus(
      testCase.sources,
      testCase.target ?? {},
      { debugMap: true },
    );
    expect(normal.success, testCase.name).toBe(false);
    expect(debug.success, testCase.name).toBe(false);
    if (normal.success || debug.success) continue;
    expect(
      debug.diagnostic,
      `${testCase.name} normal/debug diagnostic`,
    ).toEqual(normal.diagnostic);
    diagnostics.push({
      name: testCase.name,
      expectation: normal.diagnostic,
      baselineMetrics: {
        normal: { instructions: normal.instructions, cycles: normal.cycles },
        debug: { instructions: debug.instructions, cycles: debug.cycles },
      },
    });
  }

  return {
    format: "nucleus-rewrite-oracle",
    version: 1,
    baseline: {
      tag: "rewrite-baseline-2026-08-16",
      commit: "0382f73fe3bc29e86496b92334287139c2de92f1",
      normalImageSha256: info.normalImageSha256,
      debugImageSha256: info.debugImageSha256,
    },
    publicContract: {
      hostApiVersion: info.hostApiVersion,
      languageVersion: info.languageVersion,
      runtimeIdentity: info.runtimeIdentity,
      capacities: info.capacities,
      targets: info.targets,
    },
    capacityLedger: await readCapacityLedger(),
    measuredCompiler: {
      code: normalCompilerSymbols.CompilerCodeEnd,
      immutable:
        normalCompilerSymbols.CompilerImmutableEnd -
        normalCompilerSymbols.CompilerImmutableStart,
      core:
        normalCompilerSymbols.CompilerCoreEnd -
        normalCompilerSymbols.CompilerCodeStart,
      workspace:
        normalCompilerSymbols.HybridLL1WorkspaceEnd -
        normalCompilerSymbols.CompilerStateBase,
    },
    successes,
    diagnostics,
    coverage: rewriteOracleCoverage,
  };
};

describe("frozen compiler rewrite oracle", () => {
  it("preserves published contracts, artifacts, diagnostics, and source maps", async () => {
    const current = await collectOracle();
    if (process.env.NUCLEUS_UPDATE_REWRITE_ORACLE === "1") {
      await writeFile(
        fixturePath,
        `${JSON.stringify(current, null, 2)}\n`,
        "utf8",
      );
    }
    const expected = JSON.parse(
      await readFile(fixturePath, "utf8"),
    ) as typeof current;

    expect(expected.baseline).toEqual({
      tag: "rewrite-baseline-2026-08-16",
      commit: "0382f73fe3bc29e86496b92334287139c2de92f1",
      normalImageSha256:
        "6d0731c73073cd356d537fda326082eb8a3fcfa3a60dc3d17e657032487e012b",
      debugImageSha256:
        "4998a7b176dad368ffc2638a4bf861f634f89df76e9138e43e29ad65a97c5d7c",
    });
    expect(current).toEqual(expected);
  }, 30_000);
});
