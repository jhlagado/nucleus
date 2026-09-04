import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { assembleImageInWorker } from "./assemble-image-worker.mjs";
import { parseIntelHex } from "@jhlagado/debug80-runtime";
for (const argument of process.argv.slice(2)) {
  if (argument !== "--check") throw new Error(`Unknown argument: ${argument}; generation uses ATOM only`);
}
const assembleSource = assembleImageInWorker;

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
const cpm22AssetsOutputPath = path.join(
  sourceDirectory,
  "cpm22-embedded-assets.asmi",
);

const assemble = (debug, native = false, mon3 = false) => {
  const name = mon3
    ? debug ? "native-target-mon3-debug-compiler.asm" : "native-target-mon3-compiler.asm"
    : native
      ? debug ? "native-target-debug-compiler.asm" : "native-target-compiler.asm"
      : debug ? "flat-target-debug-z80-slice-proof.asm" : "flat-target-z80-slice-proof.asm";
  return assembleSource(path.join(sourceDirectory, name));
};

const assembleNodeRunner = () => assembleSource(path.join(sourceDirectory, "node-nobj-consumer.asm"));

const assembleNativeImportResolver = () => assembleSource(path.join(sourceDirectory, "native-import-resolver-tool.asm"));

const runtimeProfiles = [
  { name: "node-default", runtimeBase: 0x8003, stateBase: 0x4024, packetService: 0x7021 },
  { name: "node-loaded-4000", runtimeBase: 0x4003, stateBase: 0x6024, packetService: 0x7021 },
  { name: "node-loaded-9000", runtimeBase: 0x8003, stateBase: 0x9024, packetService: 0x7021 },
  { name: "cpm22-loaded", runtimeBase: 0x0803, stateBase: 0x5824, packetService: 0x0128 },
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
    const entryPath = path.join(temporaryDirectory, "runtime-link.asm");
    await writeFile(
      entryPath,
      '.include "nucleus-runtime-link-context.asmi"\n' +
        ".org RuntimeLinkBase\nRuntimeCodeStart:\n" +
        '.include "target-z80-runtime.asm"\nRuntimeCodeEnd:\n',
      "utf8",
    );
    const { hex, symbols } = await assembleSource(entryPath);
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
      hex,
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

const { hex: cpm22ProviderHex, symbols: cpm22ProviderSymbols } = await assembleSource(
  path.join(sourceDirectory, "cpm22-program-provider-proof.asm"),
);
const cpm22Symbol = (name) => {
  const value = cpm22ProviderSymbols[name];
  if (value === undefined) throw new Error(`CP/M provider omitted ${name}`);
  return value;
};
const cpm22Runtime = runtimeCatalog.find(({ name }) => name === "cpm22-loaded");
if (cpm22Runtime === undefined) throw new Error("CP/M runtime profile is absent");
const cpm22Prefix = parseIntelHex(cpm22ProviderHex).memory.slice(
  cpm22Symbol("CpmProgramPrefixStart"),
  cpm22Symbol("CpmProgramPrefixEnd"),
);
const cpm22RuntimeBytes = parseIntelHex(cpm22Runtime.hex).memory.slice(
  cpm22Runtime.runtimeBase,
  cpm22Runtime.runtimeBase + cpm22Runtime.expectedLength,
);
const cpm22Initial = new Uint8Array(
  cpm22Runtime.vectorLength + cpm22Runtime.stateLength,
);
for (let ordinal = 0; ordinal < 11; ordinal += 1) {
  const destination = cpm22Symbol("CpmProgramServiceVector") + ordinal * 3;
  cpm22Initial[ordinal * 3] = 0xc3;
  cpm22Initial[ordinal * 3 + 1] = destination & 0xff;
  cpm22Initial[ordinal * 3 + 2] = destination >>> 8;
}
const packetGateway =
  cpm22Runtime.runtimeBase +
  cpm22Runtime.helperOffsets.PacketServiceGateway;
cpm22Initial[33] = 0xc3;
cpm22Initial[34] = packetGateway & 0xff;
cpm22Initial[35] = packetGateway >>> 8;
cpm22Initial[cpm22Runtime.vectorLength + cpm22Runtime.runStateOffset] =
  cpm22Runtime.runReady;
cpm22Initial[
  cpm22Runtime.vectorLength + cpm22Runtime.activationLimitOffset
] = cpm22Runtime.activationCapacity;

const asmiBytes = (name, bytes) => {
  const lines = [`${name}:`];
  for (let offset = 0; offset < bytes.length; offset += 16) {
    lines.push(
      `            .db ${Array.from(bytes.slice(offset, offset + 16)).join(",")}`,
    );
  }
  lines.push(`${name}End:`);
  return lines.join("\n");
};
const generatedCpm22Assets =
  "; Generated by scripts/generate-compiler-images.mjs. Do not edit.\n\n" +
  `${asmiBytes("CpmEmbeddedPrefix", cpm22Prefix)}\n\n` +
  `${asmiBytes("CpmEmbeddedRuntime", cpm22RuntimeBytes)}\n\n` +
  `${asmiBytes("CpmEmbeddedInitial", cpm22Initial)}\n`;

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
  let currentCpm22Assets = "";
  try {
    currentCpm22Assets = await readFile(cpm22AssetsOutputPath, "utf8");
  } catch {
    // The mismatch below reports a missing generated file.
  }
  if (currentCpm22Assets !== generatedCpm22Assets) {
    throw new Error(
      "generated CP/M embedded assets are stale; run npm run generate:compiler-images",
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
  await writeFile(cpm22AssetsOutputPath, generatedCpm22Assets, "utf8");
}
