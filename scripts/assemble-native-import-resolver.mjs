// Canonical standalone Z80 tools: no input adaptation or runtime assembly.
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { assembleNativeSource } from "./assemble-native-source.mjs";

const root = fileURLToPath(new URL("../asm/", import.meta.url));
const exportMap = Object.assign({}, ...[
  "atom-runtime-symbols.json", "atom-cpm-source-symbols.json",
  "atom-cpm-program-symbols.json", "atom-cpm-adapters-symbols.json",
  "atom-resolver-symbols.json", "atom-memory-symbols.json",
].map(name => JSON.parse(readFileSync(new URL(`../asm/${name}`, import.meta.url), "utf8"))));

export const assembleNativeImportResolver = () => assembleNativeSource({
  root, entry: "vertical-slice/native-import-resolver-tool.asm", exportMap,
  target: { start: 0x8000, capacity: 0x8000 },
  requiredExports: [
    "NativeImportResolve", "NativeImportResolverCodeStart",
    "NativeImportResolverCodeEnd", "NativeImportResolverEnd", "NucleusServiceObject",
  ],
});

export const assembleNativeSourcePlanProof = () => assembleNativeSource({
  root, entry: "vertical-slice/native-source-plan-provider-proof.asm",
  exportMap: {
    ...exportMap,
    ObjectNodeGatewayPort: "PPGPORT", ObjectNodeGateway: "PPGATE",
    ProofInitialize: "PPINIT", ProofNext: "PPNEXT", ProofFinish: "PPFINISH",
    ProofRetainName: "PPRETAIN", ProofCompareName: "PPCMP",
    ProofMaterializeName: "PPMAT", ProofReturnSentinel: "PPRET",
    NativeSourceProviderCodeStart: "PPCODE", NativeSourceProviderCodeEnd: "PPEND",
  },
  requiredExports: ["ProofInitialize", "ProofReturnSentinel", "NativeSourceProviderCodeEnd"],
});
