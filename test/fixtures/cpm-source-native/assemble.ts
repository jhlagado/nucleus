import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { assembleNativeCpmProof } from "../../../scripts/assemble-native-cpm.mjs";

export const repositoryRoot = fileURLToPath(new URL("../../../", import.meta.url));
const readJson = (relative: string) =>
  JSON.parse(readFileSync(new URL(relative, import.meta.url), "utf8"));
export const fixedBaseline = readJson("fixed-baseline.json") as {
  revision: string;
  origin: number;
  end: number;
  hex: string;
  sha256: string;
  bdosSha256: string;
  providerSha256: string;
  symbols: Record<string, number>;
};

export const fullSymbolBaseline = readJson("full-symbol-baseline.json") as {
  revision: string;
  symbols: Record<string, number>;
  addresses: Record<string, number>;
  commandOnlySymbols: string[];
};
export const frozenCommandSymbols = readJson("../cpm-native-fixed-baseline.json")
  .proofs.command.symbols as Record<string, number>;

export const assembleProviderProof = () => assembleNativeCpmProof("cpm22-source-provider-proof.asm");
