import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { compile } from "@jhlagado/azm/compile";

await import("./check-azm-toolchain.mjs");

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const sourceDirectory = path.join(root, "asm", "vertical-slice");
const outputPath = path.join(root, "src", "generated-compiler-images.ts");
const runtimeCatalogOutputPath = path.join(
  root,
  "src",
  "generated-runtime-catalog.ts",
);
const nodeRunnerOutputPath = path.join(
  root,
  "src",
  "generated-node-runner.ts",
);
const nativeImportResolverOutputPath = path.join(
  root,
  "src",
  "generated-native-import-resolver.ts",
);

const assemble = async (debug, native = false, mon3 = false) => {
  const source = path.join(
    sourceDirectory,
    mon3
      ? debug
        ? "native-target-mon3-debug-compiler.asm"
        : "native-target-mon3-compiler.asm"
      : native
        ? debug
          ? "native-target-debug-compiler.asm"
          : "native-target-compiler.asm"
        : debug
          ? "flat-target-debug-z80-slice-proof.asm"
          : "flat-target-z80-slice-proof.asm",
  );
  const result = await compile(source, {
    emitBin: false,
    emitHex: true,
    emitD8m: true,
    registerContracts: "strict",
    registerContractsInterfaces: [
      path.join(sourceDirectory, "expression-generated-z80.asmi"),
      ...(mon3 ? [path.join(sourceDirectory, "mon3-host-services.asmi")] : []),
    ],
  });
  const errors = result.diagnostics.filter(
    ({ severity }) => severity === "error",
  );
  if (errors.length > 0) {
    throw new Error(
      errors
        .map(
          ({ sourceName, line, column, message }) =>
            `${sourceName ?? source}:${line ?? "?"}:${column ?? "?"} ${message}`,
        )
        .join("\n"),
    );
  }
  const hex = result.artifacts.find((artifact) => artifact.kind === "hex");
  const d8m = result.artifacts.find((artifact) => artifact.kind === "d8m");
  if (hex?.kind !== "hex" || d8m?.kind !== "d8m") {
    throw new Error(`AZM omitted generated compiler artifacts for ${source}`);
  }
  const symbols = Object.fromEntries(
    d8m.json.symbols.flatMap((entry) => {
      const value = entry.address ?? entry.value;
      return value === undefined ? [] : [[entry.name, value]];
    }),
  );
  return { hex: hex.text, symbols };
};

const assembleNodeRunner = async () => {
  const result = await compile(
    path.join(sourceDirectory, "node-nobj-consumer.asm"),
    {
      emitBin: false,
      emitHex: true,
      emitD8m: true,
      registerContracts: "strict",
      registerContractsInterfaces: [
        path.join(sourceDirectory, "nobj-consumer-platform.asmi"),
        path.join(sourceDirectory, "node-platform-services.asmi"),
      ],
    },
  );
  const errors = result.diagnostics.filter(({ severity }) => severity === "error");
  if (errors.length > 0) {
    throw new Error(errors.map(({ message }) => message).join("\n"));
  }
  const hex = result.artifacts.find((artifact) => artifact.kind === "hex");
  const d8m = result.artifacts.find((artifact) => artifact.kind === "d8m");
  if (hex?.kind !== "hex" || d8m?.kind !== "d8m") {
    throw new Error("AZM omitted Node NOBJ runner artifacts");
  }
  const symbols = Object.fromEntries(
    d8m.json.symbols.flatMap((entry) => {
      const value = entry.address ?? entry.value;
      return value === undefined ? [] : [[entry.name, value]];
    }),
  );
  return { hex: hex.text, symbols };
};

const assembleNativeImportResolver = async () => {
  const source = path.join(
    sourceDirectory,
    "native-import-resolver-tool.asm",
  );
  const result = await compile(source, {
    emitBin: false,
    emitHex: true,
    emitD8m: true,
    registerContracts: "strict",
    registerContractsInterfaces: [
      path.join(sourceDirectory, "node-platform-services.asmi"),
    ],
  });
  const errors = result.diagnostics.filter(({ severity }) => severity === "error");
  if (errors.length > 0) {
    throw new Error(errors.map(({ message }) => message).join("\n"));
  }
  const hex = result.artifacts.find((artifact) => artifact.kind === "hex");
  const d8m = result.artifacts.find((artifact) => artifact.kind === "d8m");
  if (hex?.kind !== "hex" || d8m?.kind !== "d8m") {
    throw new Error("AZM omitted native import resolver artifacts");
  }
  const symbols = Object.fromEntries(
    d8m.json.symbols.flatMap((entry) => {
      const value = entry.address ?? entry.value;
      return value === undefined ? [] : [[entry.name, value]];
    }),
  );
  return { hex: hex.text, symbols };
};

const runtimeProfiles = [
  { name: "node-default", runtimeBase: 0x8003, stateBase: 0x4024, packetService: 0x7021 },
  { name: "node-loaded-4000", runtimeBase: 0x4003, stateBase: 0x6024, packetService: 0x7021 },
  { name: "node-loaded-9000", runtimeBase: 0x8003, stateBase: 0x9024, packetService: 0x7021 },
  { name: "cpm22-loaded", runtimeBase: 0x0803, stateBase: 0x5824, packetService: 0x0141 },
  { name: "test-banked", runtimeBase: 0x8003, stateBase: 0x4024, packetService: 0x70c6 },
  { name: "test-high", runtimeBase: 0xf003, stateBase: 0x5024, packetService: 0x7021 },
];

const runtimeHelperNames = [
  "ActivationPush",
  "ActivationPop",
  "ActivationClaim",
  "ActivationRelease",
  "CheckArrayIndex",
  "CheckStringLength",
  "CheckStringIndex",
  "CheckAggregateRegion",
  "InitializeBss",
  "MultiplyU8",
  "MultiplyU16",
  "DivideU16",
  "ModuloU16",
  "CompareU16",
  "ResizeString",
  "ConvertInteger",
  "CompareSigned",
  "DivideSigned",
  "SignedLoopStep",
  "RuntimePromoteI8Pair",
  "PacketServiceGateway",
];

const hexWord = (value) => `$${value.toString(16).padStart(4, "0")}`;

const assembleRuntime = async (profile) => {
  const temporaryDirectory = await mkdtemp(
    path.join(os.tmpdir(), "nucleus-runtime-catalog-"),
  );
  try {
    const stateBase = profile.stateBase;
    await writeFile(
      path.join(temporaryDirectory, "nucleus-runtime-link-context.asmi"),
      `RuntimeLinkBase .equ ${hexWord(profile.runtimeBase)}\n` +
        `RuntimeWritableStateBase .equ ${hexWord(stateBase)}\n` +
        `RuntimeProgramDataBase .equ ${hexWord(stateBase + 41)}\n` +
        "RuntimeProgramDataCapacity .equ $0000\n" +
        `RuntimeReadOnlyBase .equ ${hexWord(profile.runtimeBase + 732)}\n` +
        "RuntimeReadOnlyCapacity .equ $0000\n" +
        `RuntimePacketService .equ ${hexWord(profile.packetService)}\n` +
        "StateBase .equ RuntimeWritableStateBase\n" +
        "RunState .equ StateBase+$00\nTrapNumber .equ StateBase+$01\n" +
        "TrapRoutine .equ StateBase+$02\nTrapOffset .equ StateBase+$03\n" +
        "TrapError .equ StateBase+$05\nActivationDepth .equ StateBase+$06\n" +
        "ActivationLimit .equ StateBase+$07\nScalarSlot .equ StateBase+$08\n" +
        "CurrentBank .equ ScalarSlot\nActivationArena .equ StateBase+$09\n" +
        "ActivationCapacity .equ 8\nRootSP .equ ActivationArena+ActivationCapacity\n" +
        "RootIX .equ RootSP+2\nFarReturnArena .equ RootIX+2\n" +
        "FarReturnCapacity .equ ActivationCapacity*2\n" +
        "RuntimeProgramDataBaseState .equ FarReturnArena+FarReturnCapacity\n" +
        "RuntimeProgramDataCapacityState .equ RuntimeProgramDataBaseState+2\n" +
        "StateEnd .equ RuntimeProgramDataCapacityState+2\n" +
        "RunReady .equ 1\nRunSucceeded .equ 2\nRunTrapped .equ 3\n" +
        "GeneratedRoDataBase .equ RuntimeReadOnlyBase\n" +
        "GeneratedRoDataCapacity .equ RuntimeReadOnlyCapacity\n" +
        "AggregateCallSlices .equ 1\n" +
        "ComparisonEqual .equ 0\nComparisonNotEqual .equ 1\n" +
        "ComparisonLess .equ 2\nComparisonLessEqual .equ 3\n" +
        "ComparisonGreater .equ 4\nComparisonGreaterEqual .equ 5\n",
      "utf8",
    );
    const interfacePath = path.join(
      temporaryDirectory,
      "nucleus-runtime-services.asmi",
    );
    await writeFile(
      interfacePath,
      "extern RuntimePacketService\nin A,BC,HL\nout A,carry,zero\n" +
        "clobbers B,C,D,E,H,L,sign,parity,halfCarry\npreserves IX,IY\nend\n",
      "utf8",
    );
    const entryPath = path.join(temporaryDirectory, "runtime-link.asm");
    await writeFile(
      entryPath,
      '.include "nucleus-runtime-link-context.asmi"\n' +
        ".org RuntimeLinkBase\nRuntimeCodeStart:\n" +
        '.include "target-z80-runtime.asm"\nRuntimeCodeEnd:\n',
      "utf8",
    );
    const result = await compile(entryPath, {
      includeDirs: [temporaryDirectory, sourceDirectory],
      emitBin: false,
      emitHex: true,
      emitD8m: true,
      registerContracts: "strict",
      registerContractsInterfaces: [interfacePath],
    });
    const errors = result.diagnostics.filter(({ severity }) => severity === "error");
    if (errors.length > 0) {
      throw new Error(errors.map(({ message }) => message).join("\n"));
    }
    const hex = result.artifacts.find((artifact) => artifact.kind === "hex");
    const d8m = result.artifacts.find((artifact) => artifact.kind === "d8m");
    if (hex?.kind !== "hex" || d8m?.kind !== "d8m") {
      throw new Error(`AZM omitted runtime catalog artifacts for ${profile.name}`);
    }
    const symbols = Object.fromEntries(
      d8m.json.symbols.flatMap((entry) => {
        const value = entry.address ?? entry.value;
        return value === undefined ? [] : [[entry.name, value]];
      }),
    );
    const symbol = (name) => {
      const value = symbols[name];
      if (value === undefined) {
        throw new Error(`runtime catalog assembly omitted ${name}`);
      }
      return value;
    };
    const start = symbol("RuntimeCodeStart");
    const end = symbol("RuntimeCodeEnd");
    const expectedLength = symbol("NucleusRuntimeExpectedLength");
    const vectorLength = symbol("NucleusRuntimeVectorLength");
    const stateLength = symbol("NucleusRuntimeStateLength");
    if (
      start !== profile.runtimeBase ||
      end - start !== expectedLength ||
      symbol("StateEnd") - symbol("StateBase") !== stateLength
    ) {
      throw new Error(`runtime catalog layout mismatch for ${profile.name}`);
    }
    const helperOffsets = Object.fromEntries(
      runtimeHelperNames.map((name) => {
        const offset = symbol(name) - start;
        const identityName = name.replace(/^Runtime/, "");
        if (offset !== symbol(`NucleusRuntime${identityName}Offset`)) {
          throw new Error(
            `runtime catalog helper mismatch for ${profile.name}: ${name}`,
          );
        }
        return [name, offset];
      }),
    );
    return {
      ...profile,
      identity: symbol("NucleusRuntimeIdentity"),
      expectedLength,
      vectorLength,
      stateLength,
      runStateOffset: symbol("NucleusRuntimeRunStateOffset"),
      activationLimitOffset: symbol("NucleusRuntimeActivationLimitOffset"),
      currentBankOffset: symbol("NucleusRuntimeCurrentBankOffset"),
      programDataBaseOffset: symbol("NucleusRuntimeProgramDataBaseOffset"),
      programDataCapacityOffset: symbol(
        "NucleusRuntimeProgramDataCapacityOffset",
      ),
      runReady: symbol("RunReady"),
      activationCapacity: symbol("ActivationCapacity"),
      helperOffsets,
      hex: hex.text,
    };
  } finally {
    await rm(temporaryDirectory, { recursive: true, force: true });
  }
};

const [normal, debug, nativeNormal, nativeDebug, mon3Normal, mon3Debug] =
  await Promise.all([
    assemble(false),
    assemble(true),
    assemble(false, true),
    assemble(true, true),
    assemble(false, true, true),
    assemble(true, true, true),
  ]);
const generated = `// Generated by scripts/generate-compiler-images.mjs. Do not edit.\n\nexport const normalCompilerHex: string = ${JSON.stringify(normal.hex)};\nexport const normalCompilerSymbols: Readonly<Record<string, number>> = ${JSON.stringify(normal.symbols, null, 2)};\n\nexport const debugCompilerHex: string = ${JSON.stringify(debug.hex)};\nexport const debugCompilerSymbols: Readonly<Record<string, number>> = ${JSON.stringify(debug.symbols, null, 2)};\n\nexport const nativeCompilerHex: string = ${JSON.stringify(nativeNormal.hex)};\nexport const nativeCompilerSymbols: Readonly<Record<string, number>> = ${JSON.stringify(nativeNormal.symbols, null, 2)};\n\nexport const nativeDebugCompilerHex: string = ${JSON.stringify(nativeDebug.hex)};\nexport const nativeDebugCompilerSymbols: Readonly<Record<string, number>> = ${JSON.stringify(nativeDebug.symbols, null, 2)};\n\nexport const mon3CompilerHex: string = ${JSON.stringify(mon3Normal.hex)};\nexport const mon3CompilerSymbols: Readonly<Record<string, number>> = ${JSON.stringify(mon3Normal.symbols, null, 2)};\n\nexport const mon3DebugCompilerHex: string = ${JSON.stringify(mon3Debug.hex)};\nexport const mon3DebugCompilerSymbols: Readonly<Record<string, number>> = ${JSON.stringify(mon3Debug.symbols, null, 2)};\n`;

const runtimeCatalog = await Promise.all(runtimeProfiles.map(assembleRuntime));
const generatedRuntimeCatalog = `// Generated by scripts/generate-compiler-images.mjs. Do not edit.\n\nexport const generatedRuntimeCatalog = ${JSON.stringify(runtimeCatalog, null, 2)} as const;\n`;
const nodeRunner = await assembleNodeRunner();
const generatedNodeRunner = `// Generated by scripts/generate-compiler-images.mjs. Do not edit.\n\nexport const nodeNobjRunnerHex: string = ${JSON.stringify(nodeRunner.hex)};\nexport const nodeNobjRunnerSymbols: Readonly<Record<string, number>> = ${JSON.stringify(nodeRunner.symbols, null, 2)};\n`;
const nativeImportResolver = await assembleNativeImportResolver();
const generatedNativeImportResolver = `// Generated by scripts/generate-compiler-images.mjs. Do not edit.\n\nexport const nativeImportResolverHex: string = ${JSON.stringify(nativeImportResolver.hex)};\nexport const nativeImportResolverSymbols: Readonly<Record<string, number>> = ${JSON.stringify(nativeImportResolver.symbols, null, 2)};\n`;

if (process.argv.includes("--check")) {
  let current = "";
  try {
    current = await readFile(outputPath, "utf8");
  } catch {
    // The mismatch below reports a missing generated file.
  }
  if (current !== generated) {
    throw new Error(
      "generated Nucleus compiler images are stale; run npm run generate:compiler-images",
    );
  }
  let currentRuntimeCatalog = "";
  try {
    currentRuntimeCatalog = await readFile(runtimeCatalogOutputPath, "utf8");
  } catch {
    // The mismatch below reports a missing generated file.
  }
  if (currentRuntimeCatalog !== generatedRuntimeCatalog) {
    throw new Error(
      "generated Nucleus runtime catalog is stale; run npm run generate:compiler-images",
    );
  }
  let currentNodeRunner = "";
  try {
    currentNodeRunner = await readFile(nodeRunnerOutputPath, "utf8");
  } catch {
    // The mismatch below reports a missing generated file.
  }
  if (currentNodeRunner !== generatedNodeRunner) {
    throw new Error(
      "generated Node NOBJ runner is stale; run npm run generate:compiler-images",
    );
  }
  let currentNativeImportResolver = "";
  try {
    currentNativeImportResolver = await readFile(
      nativeImportResolverOutputPath,
      "utf8",
    );
  } catch {
    // The mismatch below reports a missing generated file.
  }
  if (currentNativeImportResolver !== generatedNativeImportResolver) {
    throw new Error(
      "generated native import resolver is stale; run npm run generate:compiler-images",
    );
  }
} else {
  await writeFile(outputPath, generated, "utf8");
  await writeFile(runtimeCatalogOutputPath, generatedRuntimeCatalog, "utf8");
  await writeFile(nodeRunnerOutputPath, generatedNodeRunner, "utf8");
  await writeFile(
    nativeImportResolverOutputPath,
    generatedNativeImportResolver,
    "utf8",
  );
}
